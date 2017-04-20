
local shared = ngx.shared

local _M = {}

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local KEY_RESPONSE_TIME   = 'avg_response_time'
local KEY_RESPONSE_LENGTH = 'avg_response_length'

local KEY_FETCH_TIME      = 'avg_http_fetch_image_time'
local KEY_PROCESSING_TIME = 'avg_image_processing_time'

local KEY_CACHE_HIT  = 'num_cache_hit'
local KEY_CACHE_MISS = 'num_cache_miss'
local KEY_REQUESTS   = 'num_requests'

local KEY_HTTP_SUCCESS      = 'upstream_http_success'
local KEY_HTTP_REDIRECT     = 'upstream_http_redirect'
local KEY_HTTP_CLIENT_ERROR = 'upstream_http_client_error'
local KEY_HTTP_SERVER_ERROR = 'upstream_http_server_error'

local NUM_AVG_SAMPLES = 1000.0

function _M.init(config)

    if not config.shm_name then
        return
    end

    _M.dict = shared[config.shm_name]
end

local function upstream_stats_key(stat_name)
    return 'stat:' .. stat_name
end

local function log_counter(dict, stat_name)

    local key = upstream_stats_key(stat_name)
    dict:incr(key, 1, 0)
end

local function log_average(dict, stat_name, value)

    local key = upstream_stats_key(stat_name)
    local prev_avg = dict:get(key) or value
    local new_avg = prev_avg * (NUM_AVG_SAMPLES - 1) / NUM_AVG_SAMPLES + value / NUM_AVG_SAMPLES

    dict:set(key, new_avg)
end

local function get_stat(dict, stat_name)
    local key = upstream_stats_key(stat_name)
    return (dict:get(key) or 0)
end


local function log_values(dict, values)

    log_counter(dict, KEY_REQUESTS)

    if values.response_time then
        log_average(dict, KEY_RESPONSE_TIME, values.response_time)
    end

    if values.response_length then
        log_average(dict, KEY_RESPONSE_LENGTH,  values.response_length)
    end

    if values.cache_status and values.cache_status == "HIT" then
        log_counter(dict, KEY_CACHE_HIT)
    else
        log_counter(dict, KEY_CACHE_MISS)
    end

    if values.response_status then

        if values.response_status >= 200 and values.response_status <= 299 then

            log_counter(dict, KEY_HTTP_SUCCESS)

        elseif values.response_status >= 300 and values.response_status <= 399 then

            log_counter(dict, KEY_HTTP_REDIRECT)

        elseif values.response_status >= 400 and values.response_status <= 499 then

            log_counter(dict, KEY_HTTP_CLIENT_ERROR)

        elseif values.response_status >= 500 and values.response_status <= 599 then

            log_counter(dict, KEY_HTTP_SERVER_ERROR)
        end
    end
end

function _M.log_fetch_time(val)

    local dict = _M.dict

    if not dict then
        return
    end

    log_average(dict, KEY_FETCH_TIME, val)
end

function _M.log_operating_time(val)

    local dict = _M.dict

    if not dict then
        return
    end

    log_average(dict, KEY_PROCESSING_TIME, val)
end

function _M.log_upstream_response(values)
    local dict = _M.dict

    if not dict then
        return
    end


    log_values(dict, values)
end

function _M.get_stats()

    local dict = _M.dict

    if not dict then
        return {}
    end

    local s = new_tab(0, 11)

    s[KEY_RESPONSE_TIME]   = get_stat(dict, KEY_RESPONSE_TIME)
    s[KEY_RESPONSE_LENGTH] = get_stat(dict, KEY_RESPONSE_LENGTH)
    -- Counters
    s[KEY_CACHE_HIT]         = get_stat(dict, KEY_CACHE_HIT)
    s[KEY_CACHE_MISS]        = get_stat(dict, KEY_CACHE_MISS)
    s[KEY_REQUESTS]          = get_stat(dict, KEY_REQUESTS)

    s[KEY_HTTP_SUCCESS]      = get_stat(dict, KEY_HTTP_SUCCESS)
    s[KEY_HTTP_REDIRECT]     = get_stat(dict, KEY_HTTP_REDIRECT)
    s[KEY_HTTP_CLIENT_ERROR] = get_stat(dict, KEY_HTTP_CLIENT_ERROR)
    s[KEY_HTTP_SERVER_ERROR] = get_stat(dict, KEY_HTTP_SERVER_ERROR)

    s[KEY_FETCH_TIME]       = get_stat(dict, KEY_FETCH_TIME)
    s[KEY_PROCESSING_TIME]  = get_stat(dict, KEY_PROCESSING_TIME)

    return s
end


return _M
