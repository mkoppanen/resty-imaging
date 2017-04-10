
local ffi = require "ffi"
local table_unpack = table.unpack
local string_len = string.len

-- Load VIPS
local libimaging = ffi.load("imaginghelpers")

-- vips definitions
ffi.cdef[[

typedef enum { 
    ResizeModeFill,
    ResizeModeFit,
    ResizeModeCrop
} ResizeMode;

typedef enum {
    GravityNorth,
    GravityNorthEast,
    GravityEast,
    GravitySouthEast,
    GravitySouth,
    GravitySouthWest,
    GravityWest,
    GravityNorthWest,
    GravityCenter,
    GravitySmart,
} Gravity;

typedef struct Imaging Imaging;

bool imaging_ginit(const char *name, int concurrency);

void imaging_gshutdown();

Imaging *Imaging_new_from_buffer(unsigned char *buf, size_t len);

int Imaging_width(Imaging *img);

int Imaging_height(Imaging *img);

bool Imaging_resize(Imaging *img, int width, int height, ResizeMode);

bool Imaging_crop(Imaging *img, int width, int height, Gravity);

bool Imaging_round(Imaging *img, int x, int y);

unsigned char *Imaging_to_buffer(Imaging *img, const char *format, int quality, bool strip, size_t *len);

void Imaging_gc(Imaging *img);

void Imaging_gc_buffer(void *buf);

]]

local mt = {

    -- resize mode to string
    ResizeMode = {
        fill = libimaging.ResizeModeFill,
        fit  = libimaging.ResizeModeFit,
        crop = libimaging.ResizeModeCrop,
    },

    -- Gravity to string
    Gravity = {
        n  = libimaging.GravityNorth,
        ne = libimaging.GravityNorthEast,
        e  = libimaging.GravityEast,
        se = libimaging.GravitySouthEast,
        s  = libimaging.GravitySouth,
        sw = libimaging.GravitySouthWest,
        w  = libimaging.GravityWest,
        nw = libimaging.GravityNorthWest,
        center = libimaging.GravityCenter,
        smart  = libimaging.GravitySmart,
    },


    -- static calls

    init = libimaging.imaging_ginit,
    shutdown = libimaging.imaging_gshutdown,

    new_from_buffer = function (str, len) 
        local buf = ffi.cast('void *', str)
        local rc  = libimaging.Imaging_new_from_buffer(buf, len)

        if rc == ffi.NULL then
            return nil, 'Error loading image'
        end

        return ffi.gc(
            rc,
            libimaging.Imaging_gc
        )
    end,

    -- methods
    width = libimaging.Imaging_width,
    height = libimaging.Imaging_height,

    resize = libimaging.Imaging_resize,
    crop   = libimaging.Imaging_crop,
    round  = libimaging.Imaging_round,

    to_buffer = function (o, format, quality, strip) 

        local suffix = "." .. format
        local buf_size = ffi.new'size_t[1]'
        local rc       = libimaging.Imaging_to_buffer (o, suffix, quality, strip, buf_size)

        if rc == ffi.NULL then
            return nil, 'Error writing image'
        end

        local buf = ffi.gc(
            rc,
            libimaging.Imaging_gc_buffer
        )

        return ffi.string(buf, buf_size[0])
    end
}
mt.__index = mt

Imaging = ffi.metatype('Imaging', mt)

-- higher level Lua interface
local _M = {
}

function _M.init(opts)
    assert (Imaging.init('resty-imaging', opts.max_concurrency or 8) == true)

    assert(opts.default_format)
    assert(opts.default_quality)
    assert(opts.default_strip)


    _M.opts = opts

end

local transform = {}

transform.resize = function (image, params)

    setmetatable(params, {__index={
        w = 0,
        h = 0,
        m = libimaging.ResizeModeFit,
    }})

    local width  = params.w
    local height = params.h
    local mode   = params.m

    if type (mode) == "string" then
        mode = Imaging.ResizeMode[mode] 
    end

    if not mode then
        return nil, 'unknown mode'
    end

    return image:resize(width or 0, height or 0, mode)

end

transform.crop = function (image, params)

    setmetatable(params, {__index={
        w = 0,
        h = 0,
        g = libimaging.GravityCenter,
    }})

    local width   = params.w
    local height  = params.h
    local gravity = params.g

    if type (gravity) == "string" then
        gravity = Imaging.Gravity[gravity] 
    end

    if not gravity then
        return nil, 'unknown gravity'
    end

    return image:crop(width or 0, height or 0, gravity)

end

transform.round = function (image, params)

    setmetatable(params, {__index={
        x = 0,
        y = 0,
        p = 0,
    }})

    local x = params.x
    local y = params.y
    local p = params.p

    if p > 0 then
        local width = image:width()
        local height = image:height()

        x = width / 2
        y = width / 2
    end

    return image:round(x, y)
end

function _M.operate(src_image, manifest)

    local image = Imaging.new_from_buffer(src_image, string_len(src_image))

    if not image then
        return nil, 'failed to read the image'
    end

    local format  = _M.opts.default_format
    local quality = _M.opts.default_quality
    local strip   = _M.opts.default_strip

    for _, entry in ipairs(manifest) do

        if entry.name == "format" then

            if entry.params.t then
                format  = entry.params.t
            end

            if entry.params.q then
                quality = entry.params.q
            end

            if entry.params.s then
                strip = entry.params.s
            end

        else
            local fn = transform[entry.name]
            assert(fn)

            if fn then
                local ok, err = fn(image, entry.params)

                if not ok then
                    return nil, 'failed to execute ' .. entry.name .. ': ' .. err
                end
            end
        end
    end

    return image:to_buffer(format, quality, strip), format
end



return _M
