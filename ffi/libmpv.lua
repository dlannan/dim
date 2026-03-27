local ffi  = require( "ffi" )

local libmpv_filename = "libmpv"
local libs = {
   OSX     = { x64 = libmpv_filename.."_macos.so", arm64  = libmpv_filename.."_macos_arm64.so" },
   Windows = { x64 = libmpv_filename.."-2.dll" },
   Linux   = { x64 = "./bin/linux/lib"..libmpv_filename..".so", arm = "./bin/linux/lib"..libmpv_filename..".so" },
   BSD     = { x64 = libmpv_filename..".so" },
   POSIX   = { x64 = libmpv_filename..".so" },
   Other   = { x64 = libmpv_filename..".so" },
}

local lib  = libs[ ffi.os ][ ffi.arch ]
local libmpv   = ffi.load( lib )

-- load lcpp (ffi.cdef wrapper turned on per default)
local lcpp = require("tools.lcpp")

-- just use LuaJIT ffi and lcpp together
HEADER_PATH = HEADER_PATH or ""
ffi.cdef([[
#include "]]..HEADER_PATH..[[ffi/mpv/client.h" 
#include "]]..HEADER_PATH..[[ffi/mpv/render.h" 
]])

return libmpv