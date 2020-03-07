
local vips   = require "resty.imaging_vips"
local http   = require "resty.imaging_http"
local stats  = require "resty.imaging_stats"
local params = require "resty.imaging_params"
local pretty = require "resty.prettycjson"
local neturl = require "net.url"
local util   = require "resty.imaging_util"

local ngx_ctx = ngx.ctx
local shared = ngx.shared
local to_number = tonumber
local ngx_now = ngx.now
local ngx_var = ngx.var
local ngx_update_time = ngx.update_time
local get_time = os.clock
local table_concat = table.concat


local log_error = util.log_error
local log_warn  = util.log_warn
local log_info  = util.log_info

local _M = {}

local function getenv_table(var_name, default)
    local val = os.getenv(var_name)
    if val then
        local retval = {}
        for entry in string.gmatch(val, "%S+") do
            retval[entry] = true
        end
        return retval
    end
    return default
end

local function getenv_number(var_name, default)
    local v = os.getenv(var_name)
    return v and tonumber(v) or default
end

local function getenv_string(var_name, default)
    local v = os.getenv(var_name)
    return v and v or default
end

local function getenv_boolean(var_name, default)
    local v = os.getenv(var_name)
    if v then
        if str == "1" or str == "true" or str == "yes" then
            return true
        else
            return false
        end
    end

    return default
end

function _M.init(config)

    if not config then
        config = {}
    end

    setmetatable(config, {__index={
        shm_name              = "imaging",
        allowed_origins       = getenv_table('IMAGING_ALLOWED_ORIGINS',        {}),
        max_width             = getenv_number('IMAGING_MAX_WIDTH',             2048),
        max_height            = getenv_number('IMAGING_MAX_HEIGHT',            2048),
        max_operations        = getenv_number('IMAGING_MAX_OPERATIONS',        10),
        default_quality       = getenv_number('IMAGING_DEFAULT_QUALITY',       90),
        default_strip         = getenv_boolean('IMAGING_DEFAULT_STRIP',        true),
        default_format        = getenv_string('IMAGING_DEFAULT_FORMAT',        "png"),
        max_concurrency       = getenv_number('IMAGING_MAX_CONCURRENCY',       24),
        named_operations_file = getenv_string('IMAGING_NAMED_OPERATIONS_FILE', nil),
        default_params        = getenv_string('IMAGING_DEFAULT_PARAMS',        '/resize/w=1024,h=1024,m=fit'),
        send_etag             = getenv_boolean('IMAGING_SEND_ETAG',            true)
    }})

    -- Store config
    _M.config = config

    -- Init vips lib
    vips.init(config)

    local supported_formats = vips.get_formats()
    local ok, err = params.init(supported_formats, config)

    if not ok then
        util.log_error(err)
    end

    local formats = "supported formats: "

    for key, value in pairs(supported_formats) do
    	formats = formats .. ", " .. key 
		end

		util.log_info(formats)
    stats.init(config)

    -- HTTP client
    _M.http = http:new()
end

local function validate_allowed_origin(image_url)

	  local allowed_origins = _M.config.allowed_origins

		if not next(allowed_origins) then
	      return true
		end

    local u = neturl.parse(image_url)

    if not u or not u.host then
        return nil, 'failed to parse image url'
    end

    if not allowed_origins[u.host] then
        return nil, 'image host ' .. u.host .. ' is not included in allowed origins'
    end

    return true
end

function _M.access_phase()

    local url_params = ngx.var.imaging_params
    local image_url  = ngx.var.imaging_url

    if not url_params or url_params == '' then
        url_params = _M.config.default_params
    end

    if not url_params or url_params == '' then
        log_error('missing params')
        return ngx.exit(400)
    end

    if not image_url or image_url == '' then
        log_error('missing image url')
        return ngx.exit(400)
    end

    local ok, err = validate_allowed_origin(image_url)

    if not ok then
        log_warn('error validating origin: ', err)
        return ngx.exit(403)
    end

    local parsed, err = params.parse(url_params)

    if not parsed then
        log_error('unable to parse parameters: ', err)
        return ngx.exit(400)
    end

    ngx_ctx.imaging = {
        manifest = parsed,
        image_url = image_url
    }
end


local function _fetch_image(image_url)

    local image, err = _M.http:get(image_url)

    if not image then
        return nil, 'error loading image: ' .. err
    end
    return image
end

function _M.request_handler()

    local image_url = ngx_ctx.imaging.image_url
    local manifest = ngx_ctx.imaging.manifest

    local start_fetch = ngx_now()

    local fetched, err = _fetch_image(image_url)

    if not fetched then
        log_warn(err)
        return ngx.exit(500)
    end

    ngx_update_time()
    local start_processing = ngx_now()

    local image, format = vips.operate(fetched, manifest)

    if not image then
        log_warn(format)
        return ngx.exit(500)
    end

    ngx_update_time()
    local end_time = ngx_now()

    stats.log_fetch_time(start_processing - start_fetch)
    stats.log_operating_time(end_time - start_processing)

    ngx.header["content-type"] = 'image/' .. format
    ngx.say(image)

end


function _M.log_phase()
    local values = {
        connect_time    = to_number(ngx_var.upstream_connect_time),
        response_time   = to_number(ngx_var.upstream_response_time),
        response_status = to_number(ngx_var.upstream_status),
        cache_status    = ngx_var.upstream_cache_status,
        response_length = to_number(ngx_var.upstream_response_length),
    }
    stats.log_upstream_response(values)
end

function _M.status_page()

    local service_stats = stats.get_stats()

    ngx.header["content-type"]  = 'application/json'
    ngx.header["cache-control"] = "no-cache"

    ngx.say(pretty(service_stats, nil, "  "))
    return ngx.exit(200)

end
return _M