local function test_write_files(image, name, t)

    local basename = "test/t_".. name .. "_" .. t

    local op = io.open(basename .. ".jpg", "wb")
    op:write(image:to_buffer("jpg"))

    local op = io.open(basename .. ".png", "wb")
    op:write(image:to_buffer("png"))

end

local function run_test(name)

    local fp = io.open("test/" .. name, "rb")
    local str = fp:read("*all")

    local image = Imaging.new_from_buffer(str, string_len(str))
    image:resize(200, 200, libimaging.ResizeModeFill)

    test_write_files(image, name, "resize_fill")


    local image = Imaging.new_from_buffer(str, string_len(str))
    image:resize(200, 200, libimaging.ResizeModeFit)

    test_write_files(image, name, "resize_fit")


    local image = Imaging.new_from_buffer(str, string_len(str))
    image:round(100, 100)
    test_write_files(image, name, "round_100")


    local image = Imaging.new_from_buffer(str, string_len(str))
    image:resize(400, 400, libimaging.ResizeModeFit)
    image:crop(200, 200, libimaging.GravitySmart)

    test_write_files(image, name, "resize_fit_crop_smart")


end

local function test()

    Imaging.init("test", 8)

    run_test("face.jpg")
    run_test("landscape.png")
    run_test("landscape2.jpg")
    run_test("smart_test.png")

    Imaging.shutdown()
end

test()