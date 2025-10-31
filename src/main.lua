
-- -----------------------------------------------------------------------------------------

local dirtools  = require("tools.vfs.dirtools").init("dim")

--_G.SOKOL_DLL    = "sokol_debug_dll"
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

-- --------------------------------------------------------------------------------------

ARGS = arg 

VERSION     = "1.11"
PLATFORM    = ffi.os.." "..ffi.arch
SCALE       = sapp.sapp_dpi_scale()
-- This is kinda a fake runner name for the timebeing. Not sure if its really needed.
APPPATH     = dirtools.get_app_path()
EXEFILE     = string.format("%s%s", APPPATH, dirtools.sep)

-- --------------------------------------------------------------------------------------
-- Load in the methods lites registers for rendering and io and such.
require("src.system")
require("src.renderer")
require("src.threed")

local core = nil

-- --------------------------------------------------------------------------------------
local shell32   = ffi.load("shell32")

-- TODO: Need equivalents for OSX and Linux - probably should go in a systems utils.
ffi.cdef[[
    void Sleep(uint32_t ms);
    void *  ShellExecuteA(const void * hwnd, const char * lpOperation, const char * lpFile, const char * lpParameters, char* lpDirectory, int nShowCmd);
    int ShowWindow(const void * hWnd, int nCmdShow);
]]

local SW_MAXIMIZE = 3

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

local width = 1920 
local height = 1080
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

    core = nil

    sapp.sapp_show_mouse(true)
    sapp.sapp_set_window_title("Dim v"..VERSION.."["..PLATFORM.."]")

    local hwnd = sapp.sapp_win32_get_hwnd()
    ffi.C.ShowWindow(hwnd, SW_MAXIMIZE)
    SCALE = sapp.sapp_dpi_scale()

    imageutils.make_defaults()
end

-- --------------------------------------------------------------------------------------
-- Global? yes.. so lite can access it.
app_has_focus = false 

local function input(event) 
    keymap.process_inputs(event)
end

-- -----------------------------------------------------------------------------------------

local function core_init(ctx)
    SCALE = tonumber(os.getenv("LITE_SCALE")) or SCALE
    PATHSEP = package.config:sub(1, 1)
    EXEDIR = EXEFILE:match("^(.+)[/\\\\].*$")
    package.path = EXEDIR .. '/data/?.lua;' .. package.path
    package.path = EXEDIR .. '/data/?/init.lua;' .. package.path
    core = require('core')
    core.init()
end

-- -----------------------------------------------------------------------------------------
-- This is global too. But I dont think it needs to be. There are some potential 
--     nk callbacks that might need it to be, so its here like this for the time being.
winrect         = ffi.new("struct nk_rect[1]", {{0, 0, 1000, 600}})

local function core_run(ctx)

    winrect[0].w = sapp.sapp_width()
    winrect[0].h = sapp.sapp_height()
    local window_flags =  bit.bor(nk.NK_WINDOW_NO_INPUT, nk.NK_WINDOW_NO_SCROLLBAR, nk.NK_WINDOW_BACKGROUND) 
    if (nk.nk_begin(ctx, "Dim", winrect[0], window_flags) == true) then
        renderer.canvas = nk.nk_window_get_canvas(ctx) 
        renderer.rect = nk.nk_window_get_content_region(ctx)
        core.render()
    end
    nk.nk_end(ctx)
    return not nk.nk_window_is_closed(ctx, "Dim")    
end

-- --------------------------------------------------------------------------------------
-- Simple init flag. Core init needs some rendering, so the frame has to be running.
local core_ready = nil 

local function frame()

    -- /* NOTE: the vs_params_t struct has been code-generated by the shader-code-gen */
    local w         = sapp.sapp_widthf()
    local h         = sapp.sapp_heightf()
    local t         = (sapp.sapp_frame_duration() * 60.0)

    local dt = sapp.sapp_frame_duration()

    threed_renderer.load_models()

    -- This is a little messy. I had to split core run into run and render.
    -- The reason is I need to _know_ if lite needs to be rendered or not.
    -- If it doesnt, then we dont clear the buffer and nothing is drawn with core_run.
    -- Thus the last nuklear buffer is continued to be shown.
    local did_draw = true
    if(core) then 
        did_draw = core.run(w, h)
    end

    local clearflag = 0
    if(did_draw == false) then clearflag = 1 end 
    if(did_draw == true) then threed_renderer.render_queue = {} end 

    local ctx = nk.snk_new_frame(clearflag)
    renderer.ctx    = ctx 

    if(core == nil) then     
        ErrorCheck( pcall( core_init ) )
        nk.nk_style_show_cursor(ctx)   
        core_ready = true
    end 
    if(core_ready and did_draw == true) then 
        ErrorCheck( pcall(core_run, ctx) )
    end

    -- // the sokol_gfx draw pass
    local pass = ffi.new("sg_pass[1]")
    pass[0].action.colors[0].load_action = sg.SG_LOADACTION_CLEAR
    pass[0].action.colors[0].clear_value = { 0.25, 0.5, 0.7, 1.0 }
    pass[0].swapchain = slib.sglue_swapchain()
    sg.sg_begin_pass(pass)
    nk.snk_render(sapp.sapp_width(), sapp.sapp_height())

    -- // Render 3D view rects here - will get rects from the docviews.
    threed_renderer.render_rects(dt, did_draw)

    sg.sg_end_pass()
    sg.sg_commit()

    -- Display frame stats in console.
    -- hutils.show_stats()
end

-- --------------------------------------------------------------------------------------

local function cleanup()
    nk.snk_shutdown()
    sg.sg_shutdown()
end

-- --------------------------------------------------------------------------------------
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

local app_desc = ffi.new("sapp_desc[1]")
app_desc[0].init_cb         = init
app_desc[0].frame_cb        = frame
app_desc[0].cleanup_cb      = cleanup
app_desc[0].event_cb        = input
app_desc[0].width           = width
app_desc[0].height          = height
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

-- --------------------------------------------------------------------------------------