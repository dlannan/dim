if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

local pp            = require("lua.pretty-print")
local tinsert       = table.insert 

-- -----------------------------------------------------------------------------------------

local dirtools      = require("tools.vfs.dirtools").init("dim")

--SOKOL_DLL     = "sokol_debug_dll"
local sapp          = require("sokol_app")
sg                  = require("sokol_gfx")
sg                  = require("sokol_nuklear")
local nk            = sg
local slib          = require("sokol_libs") -- Warn - always after gfx!!

local hmm           = require("hmm")
local hutils        = require("hmm_utils")

local stb           = require("stb")
local utils         = require("utils")
local keymap        = require("src.keymap")

local imageutils    = require("lua.gltfloader.image-utils")

local ffi           = require("ffi")

local smgr          = require("lua.engine.statemanager")
local seq           = require("lua.engine.sequencer")

local mainstates    = require("src.main_states")

local uv            = require('luv')

local mpv           = require('ffi.libmpv')

-- package.path    = package.path..";.\\lua\\dynasm\\?.lua"
-- package.path    = package.path..";.\\lua\\dynasm\\?.dasl"
-- package.cpath   = package.cpath..";.\\lua\\dynasm\\bin\\mingw64\\?.dll"
-- print(package.cpath)
-- local asm_demo  = require("dynasm.dynasm_demo")

-- --------------------------------------------------------------------------------------

ARGS                = arg

VERSION             = "1.11"
PLATFORM            = ffi.os
SCALE               = sapp.sapp_dpi_scale()
-- This is kinda a fake runner name for the timebeing. Not sure if its really needed.
APPPATH             = dirtools.get_app_path()
EXEFILE             = string.format("%s%s", APPPATH, dirtools.sep)

WINDOW_NAME         = "dim v"..VERSION.." ["..PLATFORM.."]"

CLEAR_COLOR         = { 0.118, 0.118, 0.118, 1.0 }

-- -----------------------------------------------------------------------------------------
-- This is global too. But I dont think it needs to be. There are some potential
--     nk callbacks that might need it to be, so its here like this for the time being.
winrect             = ffi.new("struct nk_rect[1]", {{0, 0, 1000, 600}})

-- --------------------------------------------------------------------------------------
-- Load in the methods lites registers for rendering and io and such.
require("src.system")
require("src.renderer")
require("src.threed")
require("src.video")

require("src.platform")

-- --------------------------------------------------------------------------------------
-- Builtin app icons
local i16,icon16 = renderer.load_image("data/icons/dim_icon_cool_16x16.png")
local i32,icon32 = renderer.load_image("data/icons/dim_icon_cool_32x32.png")
local i64,icon64 = renderer.load_image("data/icons/dim_icon_cool_64x64.png")
local icon_desc = ffi.new("sapp_icon_desc", {
    images = {
        { width = 16, height = 16, pixels = { ptr=icon16[0].data.subimage[0][0].ptr, size=icon16[0].data.subimage[0][0].size } },
        { width = 32, height = 32, pixels = { ptr=icon32[0].data.subimage[0][0].ptr, size=icon32[0].data.subimage[0][0].size } },
        { width = 64, height = 64, pixels = { ptr=icon64[0].data.subimage[0][0].ptr, size=icon64[0].data.subimage[0][0].size } },
    }
})

-- --------------------------------------------------------------------------------------
-- To use luajits internal profiler - can be useful to find hotspots.
local frame_ctr         = 0
local enabled_profile   = arg[1] == "-profile"
local profile           = nil
local profile_capture   = {}

if(enabled_profile) then
    profile = require("jit.profile")
    function cb(thread, samples, vmstate)
        tinsert(profile_capture, string.format("frame: %06d\n", frame_ctr))
        tinsert(profile_capture, profile.dumpstack(thread, "F\tl\n", 10))
    end
    profile.start("fi4", cb)
end

mainstates.set_profile(profile, profile_capture)

-- --------------------------------------------------------------------------------------
--  Detect display size and use for width and height
local width, height = win.DetectDisplay()
if(arg[1] and arg[2]) then
    width = tonumber(arg[1])
    height = tonumber(arg[2])
end

pprint("Display: "..width .. " x ".. height)

-- --------------------------------------------------------------------------------------

local function init()

    local desc = ffi.new("sg_desc[1]")
    desc[0].environment                 = slib.sglue_environment()
    desc[0].logger.func                 = slib.slog_func
    desc[0].disable_validation          = true

    desc[0].buffer_pool_size            = 16384
    desc[0].image_pool_size             = 8192
    desc[0].shader_pool_size            = 1024
    desc[0].pipeline_pool_size          = 4096
    sg.sg_setup( desc )

    local snk = ffi.new("snk_desc_t[1]")
    snk[0].dpi_scale    = sapp.sapp_dpi_scale()
    snk[0].logger.func  = slib.slog_func
    nk.snk_setup(snk)

    pprint("Sokol Is Valid: "..tostring(sg.sg_isvalid()))

    sapp.sapp_show_mouse(true)
    sapp.sapp_set_window_title(WINDOW_NAME)

    -- Begins the state sequence
    mainstates.warmupState.winrect      = winrect
    mainstates.warmupState.width        = width 
    mainstates.warmupState.height       = height
    mainstates.runningState.winrect     = winrect
    mainstates.runningState.width       = width 
    mainstates.runningState.height      = height

    seq:Begin( { mainstates.warmupState, mainstates.coreInitState, mainstates.runningState } )
    -- pprint(jit.status())
end

-- --------------------------------------------------------------------------------------
-- Global? yes.. so lite can access it.

local function input(event)
    keymap.process_inputs(event)
end

-- --------------------------------------------------------------------------------------
-- Simple init flag. Core init needs some rendering, so the frame has to be running.

local function frame()

    -- /* NOTE: the vs_params_t struct has been code-generated by the shader-code-gen */
    local w         = sapp.sapp_width()
    local h         = sapp.sapp_height()
    local dt        = sapp.sapp_frame_duration()
    local t         = (dt * 60.0)
    renderer.dt     = dt

    winrect[0].w    = w
    winrect[0].h    = h

    -- Main proc loop
    uv.run("nowait")

    smgr.dt         = dt
    local ts = system.get_time()
    seq:Update()
    renderer.width, renderer.height = w, h
    renderer.update_dt = system.get_time() - ts

    -- Only render if valid sizes and not iconified
    if (w > 0 and h > 0 and system.iconified == false) then
        -- // the sokol_gfx draw pass   
        -- pass[0].action.colors[0].load_action = sg.SG_LOADACTION_CLEAR
        -- pass[0].action.colors[0].clear_value = CLEAR_COLOR
        -- pass[0].swapchain = slib.sglue_swapchain()
        -- sg.sg_begin_pass(pass)

        seq:Render(w, h)

        -- sg.sg_end_pass()
        -- sg.sg_commit()
        renderer.frame_ctr = frame_ctr
    end

    frame_ctr = frame_ctr + 1
    -- Display frame stats in console.
    -- hutils.show_stats()
end

-- --------------------------------------------------------------------------------------

local function cleanup()
    seq:Finish()
end

-- --------------------------------------------------------------------------------------

local app_desc = ffi.new("sapp_desc[1]")

app_desc[0].init_cb             = init
app_desc[0].frame_cb            = frame
app_desc[0].cleanup_cb          = cleanup
app_desc[0].event_cb            = input
app_desc[0].width               = 1
app_desc[0].height              = 0
app_desc[0].high_dpi            = true
app_desc[0].window_title        = WINDOW_NAME
app_desc[0].fullscreen          = false
app_desc[0].icon                = icon_desc

-- app_desc[0].swap_interval       = 0

app_desc[0].enable_clipboard    = true
app_desc[0].ios_keyboard_resizes_canvas = false
app_desc[0].logger.func         = slib.slog_func

-- Drag and drop specific settings
app_desc[0].enable_dragndrop    = true
app_desc[0].max_dropped_files   = 8               -- default is 1
app_desc[0].max_dropped_file_path_length = 8192   -- in bytes, default is 2048

sapp.sapp_run( app_desc )

-- --------------------------------------------------------------------------------------

uv.walk(uv.close)
uv.run()   

if(profile) then profile.stop() end
print("Exiting....")
os.exit()

-- --------------------------------------------------------------------------------------
