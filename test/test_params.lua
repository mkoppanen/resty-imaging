
package.path = package.path .. ';../lib/?.lua;'

local luaunit = require "luaunit"
local params = require "resty.imaging_params"
local inspect = require "inspect"

local DEFAULT_QUALITY = 88
local DEFAULT_FORMAT  = "png"
local DEFAULT_STRIP   = true

local test_params = {
	
	{
		str = "/resize/w=100,h=100",

		expect = {
			format = {
		      	q = DEFAULT_QUALITY,
		      	t = DEFAULT_FORMAT,
		      	s = DEFAULT_STRIP
			},

			operations = { 
				{
			    	name = "resize",
			    	params = {
			      		h = 100,
			      		w = 100
			    	}
			    }
			}
		}
	},

	{
		str = "/resize/w=100,h=100/format/t=png,q=50,s=false",

		expect = {
			format = {
		      	q = 50,
		      	t = "png",
		      	s = false
		    },
		    operations = {
				{
				    name = "resize",
				    params = {
				      	h = 100,
				      	w = 100
				    }
				}
			}
		}
	},

	{
		str = "/resize/w=5,h=12/crop/w=100,h=120,g=center/round/p=100/format/s=false",

		expect = {
			format = {
		      	q = DEFAULT_QUALITY,
		      	t = DEFAULT_FORMAT,
				s = false
			},

			operations = {
				{
				    name = "resize",
				    params = {
				      	w = 5,
				      	h = 12,
				    }
				},
				{
				    name = "crop",
				    params = {
				      	w = 100,
				      	h = 120,
				      	g = "center",
				    }
				},
				{
					name = "round",
					params = {
						p = 100
					}
				}
			}
		}
	},

	{
		str = "/named/n=thumbnail",

		expect = {

			format = {
		      	q = DEFAULT_QUALITY,
		      	t = "webp",
				s = DEFAULT_STRIP
			},

			operations = {
				{
				    name = "resize",
				    params = {
				      	w = 500,
				      	h = 500,
				      	m = "fit"
				    }
				},
				{
				    name = "crop",
				    params = {
				      	w = 200,
				      	h = 200,
				      	g = "sw",
				    }
				}
			}
		}
	},

	{
		str = "/named/n=avatar",

		expect = {

			format = {
		      	q = DEFAULT_QUALITY,
		      	t = "jpg",
				s = DEFAULT_STRIP
			},


			operations = {
				{
				    name = "resize",
				    params = {
				      	w = 100,
				      	h = 100,
				      	m = "crop"
				    }
				},
				{
				    name = "round",
				    params = {
				      	p = 100,
				    }
				}
			}
		}
	},
}

local failing_params = {
	
	{
		str = "/named/n=doesnotexist"
	},

	{
		str = "/resize/w=sdsd"
	}
}


function testParsing()

	params.init({ 
		png = true,
		jpeg = true,
		jpg = true,
		webp = true

	}, {
		max_width      = 2000,
		max_height     = 2000,
		max_operations = 10,
		default_quality = DEFAULT_QUALITY,
		default_format  = DEFAULT_FORMAT,
		default_strip   = DEFAULT_STRIP,
		named_operations_file = "./test.ops"
	})

	for _, t in pairs(test_params) do

		local res, err = params.parse(t.str)

		if not res then
			print ('ERR=', res, err)
		end

		luaunit.assertEquals(res.format, t.expect.format)

		for k, _ in pairs(t.expect) do
			
		end
	end

	for _, t in pairs(failing_params) do

		local res, err = params.parse(t.str)

		luaunit.assertNil(res)
	end

end

os.exit( luaunit.LuaUnit.run() )