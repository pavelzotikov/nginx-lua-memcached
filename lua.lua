local json = require "cjson"
local memcached = require "resty.memcached"

local memc, err = memcached:new()
if not memc then
    ngx.log(ngx.INFO, "Memcached failed to instantiate memc: ", err)
    ngx.exec("@nolimit")
    return
end

memc:set_timeout(1000)

local ok, err = memc:connect("127.0.0.1", 11211)
if ok then
    ngx.log(ngx.INFO, "Memcached failed to connect: ", err)
    ngx.exec("@nolimit")
    return
end

local methods = {}

methods.get_tag_value = function(tag)
    local tag = "tag_" .. tag
    return methods.get(tag)
end

methods.get = function(key)
    local res, flags, err = memc:get(key)
    if not err then

        if res == nil then
            ngx.log(ngx.INFO, key .. ": " .. "Memcache response is empty")
            ngx.exec("@nolimit")
            return
        end

        local arr
        pcall(function (res) arr = json.decode(res) end, res)

        if arr then

            if arr.tags then
                ngx.log(ngx.INFO, key .. ": " .. "Response tags: ", json.encode(arr.tags))
                for tag,tag_stored_value in pairs(arr.tags) do
                    local tag_current_value = methods.get_tag_value(tag)
                    ngx.log(ngx.INFO, key .. ": " .. "tag_current_value: ", tag_current_value)
                    if tag_current_value ~= tag_stored_value then
                        ngx.log(ngx.INFO, key .. ": " .. "Memcache cache expired: true")
                        return
                    end
                end
                ngx.log(ngx.INFO, key .. ": " .. "Memcache cache expired: false")
            end

            return arr.data

        else
            ngx.log(ngx.INFO, key .. ": " .. "JSON.decode fail ", string.sub(res, 0, 10))
        end

    end
end

local cache
local cache_key = ngx.md5(ngx.var.cache_key)

pcall(function (methods, key) cache = methods.get(key) end, methods, cache_key)

if not cache then
    ngx.log(ngx.INFO, cache_key .. ": " .. "Cache not found")
    ngx.exec("@nolimit")
else
    ngx.say(cache)
end
