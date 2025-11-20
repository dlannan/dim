
-- -----------------------------------------------------------------------------------------

local dirtools  = require("tools.vfs.dirtools").init("dim")

--SOKOL_DLL    = "sokol_debug_dll"
local sapp      = require("sokol_app")
sg              = require("sokol_gfx")
sg              = require("sokol_nuklear")
local nk        = sg
local slib      = require("sokol_libs") -- Warn - always after gfx!!

local hmm       = require("hmm")
local hutils    = require("hmm_utils")

local stb       = require("stb")
local utils     = require("utils")
local keymap    = require("src.keymap")

local imageutils = require("lua.gltfloader.image-utils")

local ffi       = require("ffi")

local binmgr 	= require("lua.geometry.bins")

local smgr      = require("lua.engine.statemanager")
local seq       = require("lua.engine.sequencer")

-- --------------------------------------------------------------------------------------

ARGS = arg

VERSION         = "1.11"
PLATFORM        = ffi.os
SCALE           = sapp.sapp_dpi_scale()
-- This is kinda a fake runner name for the timebeing. Not sure if its really needed.
APPPATH         = dirtools.get_app_path()
EXEFILE         = string.format("%s%s", APPPATH, dirtools.sep)

WINDOW_NAME     = "Dim v"..VERSION.."["..PLATFORM.."]"

CLEAR_COLOR     = { 0.118, 0.118, 0.118, 1.0 }

-- --------------------------------------------------------------------------------------
-- Load in the methods lites registers for rendering and io and such.
require("src.system")
require("src.renderer")
require("src.threed")

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
-- lite core setup
local core          = nil

-- --------------------------------------------------------------------------------------
local warmupState    = smgr:NewState()
local coreInitState  = smgr:NewState()
local runningState   = smgr:NewState()

-- --------------------------------------------------------------------------------------
-- To use luajits internal profiler - can be useful to find hotspots.
local enabled_profile   = arg[1] == "-profile"
local profile           = nil
if(enabled_profile) then
    profile = require("jit.profile")
    function cb(thread, samples, vmstate)
        print(profile.dumpstack(thread, "l\n", 1))
    end
    profile.start("fi4", cb)
end

-- --------------------------------------------------------------------------------------
--  Detect display size and use for width and height
local width, height = win.DetectDisplay()
if(arg[1] and arg[2]) then
    width = tonumber(arg[1])
    height = tonumber(arg[2])
end
print("Display: "..width .. " x ".. height)

-- --------------------------------------------------------------------------------------

local function ErrorCheck(status, err)
    if(status == false) then
        print("[Error] ", err)
        print(debug.traceback())
        os.exit()
    else
        return err
    end
end

-- --------------------------------------------------------------------------------------

local function init()

    local desc = ffi.new("sg_desc[1]")
    desc[0].environment = slib.sglue_environment()
    desc[0].logger.func = slib.slog_func
    desc[0].disable_validation = false

    desc[0].buffer_pool_size = 16384
    desc[0].image_pool_size = 8192
    desc[0].shader_pool_size = 1024
    desc[0].pipeline_pool_size = 4096
    sg.sg_setup( desc )

    local snk = ffi.new("snk_desc_t[1]")
    snk[0].dpi_scale = sapp.sapp_dpi_scale()
    snk[0].logger.func = slib.slog_func
    nk.snk_setup(snk)

    print("Sokol Is Valid: "..tostring(sg.sg_isvalid()))

    sapp.sapp_show_mouse(true)
    sapp.sapp_set_window_title(WINDOW_NAME)

    -- Begins the state sequence
    seq:Begin( { warmupState, coreInitState, runningState } )
end

-- --------------------------------------------------------------------------------------
-- Global? yes.. so lite can access it.

local function input(event)
    keymap.process_inputs(event)
end

-- -----------------------------------------------------------------------------------------
-- This is global too. But I dont think it needs to be. There are some potential
--     nk callbacks that might need it to be, so its here like this for the time being.
winrect         = ffi.new("struct nk_rect[1]", {{0, 0, 1000, 600}})

-- -----------------------------------------------------------------------------------------

local function core_run(ctx, core, winrect, custom)

    local window_flags =  bit.bor(nk.NK_WINDOW_NO_INPUT, nk.NK_WINDOW_NO_SCROLLBAR, nk.NK_WINDOW_BACKGROUND)
    if (nk.nk_begin(ctx, "Dim", winrect[0], window_flags) == true) then
        renderer.canvas = nk.nk_window_get_canvas(ctx)
        renderer.rect = nk.nk_window_get_content_region(ctx)
        if(custom) then custom() end
    end
    renderer.set_cursor()
    nk.nk_end(ctx)
    return not nk.nk_window_is_closed(ctx, "Dim")
end

-- --------------------------------------------------------------------------------------

local function core_init(ctx)

    SCALE = tonumber(os.getenv("LITE_SCALE")) or SCALE
    PATHSEP = package.config:sub(1, 1)
    EXEDIR = EXEFILE:match("^(.+)[/\\\\].*$")
    package.path = EXEDIR .. '/data/?.lua;' .. package.path
    package.path = EXEDIR .. '/data/?/init.lua;' .. package.path

    local core          = require('core')
    core.init()
    core.redraw = true
    core.ready = true

    local hwnd = sapp.sapp_win32_get_hwnd()
    win.ShowWindow(hwnd or WINDOW_NAME, 1)
    return core
end

-- --------------------------------------------------------------------------------------
-- Simple init flag. Core init needs some rendering, so the frame has to be running.

local function frame()

    -- /* NOTE: the vs_params_t struct has been code-generated by the shader-code-gen */
    local w         = sapp.sapp_width()
    local h         = sapp.sapp_height()
    local dt        = sapp.sapp_frame_duration()
    local t         = (dt * 60.0)

    winrect[0].w = w
    winrect[0].h = h

    smgr.dt = dt
    seq:Update()

    -- Only render if valid sizes and not iconified
    if (w > 0 and h > 0 and system.iconified == false) then
    -- // the sokol_gfx draw pass
    local pass = ffi.new("sg_pass[1]")
    pass[0].action.colors[0].load_action = sg.SG_LOADACTION_CLEAR
    pass[0].action.colors[0].clear_value = CLEAR_COLOR
    pass[0].swapchain = slib.sglue_swapchain()
    sg.sg_begin_pass(pass)

    seq:Render(w, h)

    sg.sg_end_pass()
    sg.sg_commit()
    end

    -- Display frame stats in console.
    -- hutils.show_stats()
end

-- --------------------------------------------------------------------------------------

local function cleanup()
    seq:Finish()
end

-- --------------------------------------------------------------------------------------

warmupState.Begin   = function(self)

    SCALE = sapp.sapp_dpi_scale()

    imageutils.make_defaults()
    binmgr.init()

    local hwnd = sapp.sapp_win32_get_hwnd()
    local dw, dh = width, height
    win.SetWindowPos(hwnd, dw/2 - 320, dh/2 - 100, 640, 200)

    self.frame_started = 0
end

-- --------------------------------------------------------------------------------------

warmupState.Update = function(self)

    local ctx = nk.snk_new_frame(0)
    renderer.ctx    = ctx

    if(self.frame_started >= 3) then
        seq:NextState()
    end

    -- Render stuff before core is started
    if(core == nil and self.frame_started < 3) then
        self.frame_started = self.frame_started + 1
    end

    -- Simple loading logo or image (no text, since fonts arent ready!)
    --
    core_run( ctx, nil, winrect, function()
        local res = nk.nk_style_set_cursor(ctx, 0)
        nk.nk_style_hide_cursor(ctx)

        local r = renderer.rect
        nk.nk_layout_row_static(ctx, r.h, r.w, 1)
        nk.nk_label(ctx, "loading dim...", nk.NK_TEXT_CENTERED)
    end)
end

-- --------------------------------------------------------------------------------------

warmupState.Render = function(self, w, h)

    nk.snk_render(w, h)
end

-- --------------------------------------------------------------------------------------

coreInitState.Update    = function(self)

    local ctx = nk.snk_new_frame(0)
    renderer.ctx    = ctx

    if(core == nil) then
        core = ErrorCheck( pcall( core_init, ctx, core ) )
    else
        seq:NextState()
    end
end

-- --------------------------------------------------------------------------------------

coreInitState.Render = function(self, w, h)

    nk.snk_render(w, h)
end

-- --------------------------------------------------------------------------------------

runningState.Update     = function(self)

    threed_renderer.load_models()

    -- This is a little messy. I had to split core run into run and render.
    -- The reason is I need to _know_ if lite needs to be rendered or not.
    -- If it doesnt, then we dont clear the buffer and nothing is drawn with core_run.
    -- Thus the last nuklear buffer is continued to be shown.
    local did_draw = true
    if(core) then
        did_draw = core.run(width, height)
    end

    local clearflag = 0
    if(did_draw == false) then clearflag = 1 end
    if(did_draw == true) then threed_renderer.render_queue = {} end

    local ctx = nk.snk_new_frame(clearflag)
    renderer.ctx    = ctx

    if(core and core.ready and did_draw == true) then
        ErrorCheck( pcall(core_run, ctx, core, winrect, function()
            core.render()
        end) )
    end
end

-- --------------------------------------------------------------------------------------

runningState.Render     = function(self, w, h)
    nk.snk_render(w, h)

    -- // Render 3D view rects here - will get rects from the docviews.
    threed_renderer.render_rects(self.dt)
end

-- --------------------------------------------------------------------------------------

runningState.Finish     = function(self)
    nk.snk_shutdown()
    sg.sg_shutdown()
    core.quit()
end

-- --------------------------------------------------------------------------------------

local app_desc = ffi.new("sapp_desc[1]")

app_desc[0].init_cb         = init
app_desc[0].frame_cb        = frame
app_desc[0].cleanup_cb      = cleanup
app_desc[0].event_cb        = input
app_desc[0].width           = 1
app_desc[0].height          = 0
app_desc[0].high_dpi        = true
app_desc[0].window_title    = "Dim"
app_desc[0].fullscreen      = false
app_desc[0].icon            = icon_desc

app_desc[0].enable_clipboard = true
app_desc[0].ios_keyboard_resizes_canvas = false
app_desc[0].logger.func = slib.slog_func

-- Drag and drop specific settings
app_desc[0].enable_dragndrop    = true
app_desc[0].max_dropped_files   = 8               -- default is 1
app_desc[0].max_dropped_file_path_length = 8192   -- in bytes, default is 2048

sapp.sapp_run( app_desc )

-- --------------------------------------------------------------------------------------

if(profile) then profile.stop() end
os.exit()

-- --------------------------------------------------------------------------------------
