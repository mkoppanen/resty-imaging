
package.path = package.path .. ';../lib/?.lua;'

local lib = require "resty.imaging_vips"
local luaunit = require "luaunit"

local Imaging = lib.Imaging

local function file_get_contents(name)
    local fp = io.open(name, "rb")
    return fp:read("*all")
end

local function test_write_files(name, image)

    local jpg_output, err = image:to_buffer("jpg", 100, true)
    
    local op = io.open("test_output_" .. name .. ".jpg", "wb")
    op:write(jpg_output)

    local png_output, err = image:to_buffer("png", 100, true)

    local op = io.open("test_output_" .. name .. ".png", "wb")
    op:write(png_output)

end

function testBackgroundColour()

    local src = file_get_contents("landscape.png")

    local image, err = Imaging.new_from_buffer(src, src:len())
    luaunit.assertNil(err)

    local rc = image:set_background_colour(255, 0, 255)
    luaunit.assertTrue(rc)

    test_write_files("background_colour1", image)

    local rc = image:resize(200, 200, Imaging.ResizeMode.fill)
    luaunit.assertTrue(rc)

    test_write_files("background_colour2", image)
end

lib.init({
    default_format  = "png",
    default_quality = 100,
    default_strip   = false
})

os.exit( luaunit.LuaUnit.run() )
