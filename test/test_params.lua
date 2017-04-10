
package.path = package.path .. ';../lib/resty/?.lua'

local luaunit = require "luaunit"
local params = require "imaging_params"

local DEFAULT_QUALITY = 88
local DEFAULT_FORMAT  = "png"
local DEFAULT_STRIP   = true

local test_params = {
	
	{
		str = "/resize/w=100,h=100",

		expect = {
			{
			    name = "resize",
			    params = {
			      	h = 100,
			      	w = 100
			    }
			  }, {
			    name = "format",
			    params = {
			      	q = DEFAULT_QUALITY,
			      	t = DEFAULT_FORMAT,
			      	s = DEFAULT_STRIP
			    }
			}
		}
	},

	{
		str = "/resize/w=100,h=100/format/t=png,q=50,s=false",

		expect = {
			{
			    name = "resize",
			    params = {
			      	h = 100,
			      	w = 100
			    }
			  }, {
			    name = "format",
			    params = {
			      	q = 50,
			      	t = "png",
			      	s = false
			    }
			}
		}
	},

	{
		str = "/resize/w=5,h=12/crop/w=100,h=120,g=c/round/p=100/format/s=false",

		expect = {
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
			      	g = "c",
			    }
			},
			{
				name = "round",
				params = {
					p = 100
				}
			},
			{
				name = "format",
				params = {
			      	q = DEFAULT_QUALITY,
			      	t = DEFAULT_FORMAT,
					s = false
				}
			}
		}
	},
}

function testParsing()

	params.init({
		max_width      = 2000,
		max_height     = 2000,
		max_operations = 10,
		default_quality = DEFAULT_QUALITY,
		default_format  = DEFAULT_FORMAT,
		default_strip   = DEFAULT_STRIP
	})

	for _, t in pairs(test_params) do

		local res = params.parse(t.str)

		for k, _ in pairs(t.expect) do
			luaunit.assertEquals(res[k], t.expect[k])
		end
	end
end

os.exit( luaunit.LuaUnit.run() )