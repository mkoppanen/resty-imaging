
local util = require "resty.imaging_util"

local table_insert  = table.insert
local string_gmatch = string.gmatch
local string_match  = string.match
local to_number     = tonumber



local supported_formats = {
    png  = true,
    jpg  = true,
    jpeg = true,
    gif  = true,
    webp = true,
    tiff = true,
}

local supported_modes = {
    fit  = true,
    fill = true,
    crop = true,
}

local supported_gravity = {
    n      = true,
    ne     = true,
    e      = true,
    se     = true,
    s      = true,
    sw     = true,
    w      = true,
    nw     = true,
    center = true,
    smart  = true,
}

local _M = {
    named_ops = {}
}
local ops = {}


local function validate_always_valid()
    return true
end

local function to_boolean(str)

    if not str then
        return false
    end

    if str == "1" or str == "true" or str == "yes" then
        return true
    else
        return false
    end
end

local function validate_width(width)
    return width and width < _M.opts.max_width and width > 0
end

local function validate_height(height)
    return height and height < _M.opts.max_height and height > 0
end

local function validate_sigma(sigma)
    return sigma and sigma >= 0.0
end

local function validate_quality(quality)
    return quality and quality >= 1 and quality <= 100
end

local function validate_format(str)
    return str and supported_formats[str] ~= nil
end

local function validate_resize_mode(str)
    return str and supported_modes[str] ~= nil
end

local function validate_gravity(str)
    return str and supported_gravity[str] ~= nil
end

local function make_boolean_arg()
    return {
        convert_fn  = to_boolean,
        validate_fn = validate_always_valid
    }
end

local function make_number_arg(validate_fn)
    return {
        convert_fn  = to_number,
        validate_fn = validate_fn,
    }
end

local function make_string_arg(validate_fn)
    return { validate_fn = validate_fn, }
end

function _M.init(opts)

    assert (opts.max_width)
    assert (opts.max_height)
    assert (opts.max_operations)
    assert (opts.default_format)
    assert (opts.default_quality)
    assert (opts.default_strip)

    _M.opts = opts


    ops = {
        crop = {
            params = {
                w  = make_number_arg(validate_width),
                h  = make_number_arg(validate_height),
                g  = make_string_arg(validate_gravity),  -- gravity
            },
            validate_fn = function(p)
                if not p.w and not p.h then
                    return nil, 'missing w= and h= for crop'
                end
                return true
            end
        },

        blur = {
            params = {
                s  = make_number_arg(validate_sigma),
            },
            validate_fn = function(p)
                if not p.s then
                    return nil, 'missing both s= (sigma) for blur'
                end
                return true
            end
        },

        resize = {
            params = {
                w  = make_number_arg(validate_width),
                h  = make_number_arg(validate_height),
                m  = make_string_arg(validate_resize_mode),
            },
            validate_fn = function(p)
                if not p.w and not p.h then
                    return nil, 'missing both w= and h= for resize'
                end
                return true
            end
        },

        round = {
            params = {
                p = make_number_arg(validate_percentage),
                x = make_number_arg(validate_width),
                y = make_number_arg(validate_height),
            },
            validate_fn = function(p)
                if not p.p then
                    if not p.x and not p.y then
                        return nil, 'round needs either p= or both x= and y='
                    end
                end
                return true
            end
        },

        named = {
            params = {
                n = make_string_arg(validate_name)
            },
            validate_fn = function(p)
                return p.n and _M.named_ops[p.n] ~= nil
            end
        },

        format = {
            params = {
                t = make_string_arg(validate_format),
                q = make_number_arg(validate_percentage),
                s = make_boolean_arg()
            },
            get_default_params = function()
                return {
                    t = opts.default_format,
                    q = opts.default_quality,
                    s = opts.default_strip
                }
            end
        }
    }
    
    if opts.named_operations_file then
        local lines, err = util.file_get_lines(opts.named_operations_file)

        if not lines then
            return nil, err
        end

        for n, line in pairs(lines) do

            local name, operation = line:match('(.+)%s?:%s?(.+)')

            if not name or not operation then
                return nil, "Failed to parse line (" .. n .."): " .. err
            else

                local parsed, err = _M.parse(operation)

                if not parsed then
                    return nil, "Failed to parse named operation: " .. err
                else
                    _M.named_ops[name] = parsed
                end
            end
        end
    end

    return true


end



local function ordered_table()

    local key2val, nextkey, firstkey = {}, {}, {}
    nextkey[nextkey] = firstkey
 
    local function onext(self, key)
        while key ~= nil do
            key = nextkey[key]
            local val = self[key]
            if val ~= nil then return key, val end
        end
    end
 
    local selfmeta = firstkey
    selfmeta.__nextkey = nextkey
 
    function selfmeta:__newindex(key, val)
        rawset(self, key, val)
        if nextkey[key] == nil then -- adding a new key
            nextkey[nextkey[nextkey]] = key
            nextkey[nextkey] = key
        end
    end
 
    function selfmeta:__pairs() return onext, self, firstkey end
 
    return setmetatable(key2val, selfmeta)
end

function _M.parse(str)

    local parsed = ordered_table()
    local pos = 0
    local has_format = false

    for name, params in string_gmatch(str, '([^/]+)/([^/]+)') do

        if ops[name] then
            local fn_params = {}

            if ops[name].get_default_params then
                fn_params = ops[name].get_default_params()
            end

            -- Loop through recognised params
            for n, def in pairs(ops[name].params) do

                local value = string_match(params, n .. '=([^,/]+)')

                if value then
                    if def.convert_fn then
                        value = def.convert_fn(value)
                    end

                    if def.validate_fn then
                        if not def.validate_fn(value) then
                            return nil, name .. "->" .. n .. '(value: ' .. (value or 'nil') .. ') failed validation'
                        end
                    end
                    fn_params[n] = value
                end
            end

            if ops[name].validate_fn then
                local ok, err = ops[name].validate_fn(fn_params)

                if not ok then
                    return nil, err
                end
            end

            -- Return named operation if exists
            if name == "named" then
                return _M.named_ops[fn_params["n"]];
            end

            table_insert(parsed, {
                name   = name,
                params = fn_params
            })
        end

        if name == "format" then
            has_format = true
        end
    end

    if #parsed == 0 then
        return nil, 'did not find valid operations'
    end

    if #parsed > _M.opts.max_operations then
        return nil, 'amount of operations exceeds configured maximum'
    end

    if not has_format then
        table_insert(parsed, {
            name   = "format",
            params = ops["format"].get_default_params()
        })
    end

    return parsed, nil
end

return _M