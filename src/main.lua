local ffi       = require("ffi")

-- -----------------------------------------------------------------------------------------
ARGS = arg 

VERSION     = "1.11"
PLATFORM    = ffi.os.." "..ffi.arch
SCALE       = sokol.get_hdpi()
EXEFILE     = arg[1]

-- -----------------------------------------------------------------------------------------

local core

xpcall(function()
    SCALE = tonumber(os.getenv("LITE_SCALE")) or SCALE
    PATHSEP = package.config:sub(1, 1)
    EXEDIR = EXEFILE:match("^(.+)[/\\\\].*$")
    package.path = EXEDIR .. '/data/?.lua;' .. package.path
    package.path = EXEDIR .. '/data/?/init.lua;' .. package.path
    core = require('core')
    core.init()
    core.run()
end, function(err)
    print('Error: ' .. tostring(err))
    print(debug.traceback(nil, 2))
    if core and core.on_error then
        pcall(core.on_error, err)
    end
    os.exit(1)
end)