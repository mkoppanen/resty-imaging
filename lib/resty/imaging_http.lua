
local http     = require "resty.http"
local neturl   = require "net.url"
local lrucache = require "resty.lrucache"
local cjson    = require "cjson"

local tbl_concat = table.concat

local _M = {}

function _M.new(self, opts)

    if not opts then
        opts = {}
    end

    setmetatable(opts, {__index={
        keepalive_timeout      = 120,
        keepalive_pool_size    = 24,
        request_timeout        = 30,
        ssl_session_cache_size = 24,

        ssl_session_cache_ttl  = 120,
        max_redirects          = 3,
        max_body_size          = 25 * 1024 * 1024,
    }})

    opts.keepalive_timeout = opts.keepalive_timeout * 1000
    opts.request_timeout   = opts.request_timeout * 1000

    local ssl_cache = lrucache.new(opts.ssl_session_cache_size)
    return setmetatable({ opts = opts, ssl_cache = ssl_cache }, { __index = _M })
end


local function ssl_handshake(self, httpc, host, port)

    local cache_key    = host .. ':' .. port
    local prev_session = self.ssl_cache:get(cache_key)
    local session, err = httpc:ssl_handshake(prev_session, host, true)

    if not session then
        return nil, "failed to establish ssl connection: " .. err
    end

    self.ssl_cache:set(cache_key, session, self.opts.ssl_session_cache_ttl)
    return true, nil
end

local function read_response_body(res, max_body_size)

    local reader = res.body_reader

    if not reader then
        return nil, "no body to read"
    end

    local chunks = {}
    local c = 1

    local chunk, err
    repeat

        if c > max_body_size then
            return nil, "body size exceeds max_body_size"
        end

        chunk, err = reader()

        if err then
            return nil, err
        end

        if chunk then
            chunks[c] = chunk
            c = c + 1
        end

    until not chunk

    return tbl_concat(chunks)
end


function _M.get_url(self, image_url, redirects_left)

    local httpc = http.new()

    local u = neturl.parse(image_url)

    if not u or not u.host then
        return nil, "failed to parse url: " .. image_url
    end

    local host = u.host
    local port

    if u.port then
        port = u.port
    else
        if u.scheme == "https" then
            port = 443
        else
            port = 80
        end
    end

    local ok, err = httpc:connect(host, port)

    if not ok then
        return nil, 'failed to fetch ' .. image_url .. ": " .. err
    end

    if u.scheme == "https" then
        local ok, err = ssl_handshake(self, httpc, host, port)

        if not ok then
            return nil, err
        end
    end

    local req_path = u.path .. (u.query and "?" .. neturl.buildQuery(u.query) or "")

    local res, err = httpc:request{
        path = req_path,
        headers = {
            ['Host']       = host,
            ["User-Agent"] = "openresty/imaging",
            ["Connection"] = "Keep-Alive",
        },
    }

    if not res then
        return nil, err
    end

    if res.status >= 300 and res.status <= 399 then
        
        if redirects_left <= 0 then
            return nil, "too many redirects"
        end

        for name, value in pairs(res.headers) do
            if string.lower(name) == 'location' then
                return self:get_url(value, redirects_left - 1)
            end
        end

        return nil, "received redirect status code but no location header"
    end

    if res.status < 200 or res.status > 299 then
        return nil, "received status code " .. res.status
    end

    local buffer, err = read_response_body(res, self.opts.max_body_size)

    if not buffer then
        return nil, err
    end

    httpc:set_keepalive(self.opts.keepalive_timeout, self.opts.keepalive_pool_size)
    return buffer, nil
end

function _M.get(self, image_url)
    return self:get_url(image_url, self.opts.max_redirects)
end

return _M








