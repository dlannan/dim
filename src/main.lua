
-- -----------------------------------------------------------------------------------------

local dirtools  = require("tools.vfs.dirtools")
dirtools.init("dim")

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

local ffi       = require("ffi")

-- --------------------------------------------------------------------------------------

ARGS = arg 

VERSION     = "1.11"
PLATFORM    = ffi.os.." "..ffi.arch
SCALE       = sapp.sapp_dpi_scale()
EXEFILE     = dirtools.get_app_path()..dirtools.sep.."runner.exe"
-- This is kinda a fake runner name for the timebeing. Not sure if its really needed.
print(EXEFILE)

-- --------------------------------------------------------------------------------------
-- Load in the methods lites registers for rendering and io and such.
require("src.system")
require("src.renderer")

local core

-- --------------------------------------------------------------------------------------
local shell32   = ffi.load("shell32")

ffi.cdef[[
    void Sleep(uint32_t ms);
    void *  ShellExecuteA(const void * hwnd, const char * lpOperation, const char * lpFile, const char * lpParameters, char* lpDirectory, int nShowCmd);
    int ShowWindow(const void * hWnd, int nCmdShow);
]]

local SW_MAXIMIZE = 3

-- --------------------------------------------------------------------------------------
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
        print(status)
        print(err)
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
end

-- --------------------------------------------------------------------------------------
-- Global? yes.. so lite can access it.
app_has_focus = false 

LITE_EVENT = {}
LITE_EVENT[sapp.SAPP_EVENTTYPE_CHAR]        = "inputtext"
    
LITE_EVENT[sapp.SAPP_EVENTTYPE_KEY_DOWN]    = "keypressed"
LITE_EVENT[sapp.SAPP_EVENTTYPE_KEY_UP]      = "keyreleased"

LITE_EVENT[sapp.SAPP_EVENTTYPE_MOUSE_DOWN]  = "mousepressed"
LITE_EVENT[sapp.SAPP_EVENTTYPE_MOUSE_UP]    = "mousereleased"

LITE_EVENT[sapp.SAPP_EVENTTYPE_MOUSE_MOVE]  = "mousemoved"
LITE_EVENT[sapp.SAPP_EVENTTYPE_MOUSE_SCROLL] = "mousewheel"


local function input(event) 

    -- Only kick things off once the window is ready.
    if(event.type == sapp.SAPP_EVENTTYPE_RESIZED) then 
        local w         = sapp.sapp_widthf()
        local h         = sapp.sapp_heightf()   
        -- core resize?
    elseif ev.type == sapp.SAPP_EVENTTYPE_FOCUSED then
        sapp.sapp_show_mouse(true)
        app_has_focus = true
    elseif ev.type == sapp.SAPP_EVENTTYPE_UNFOCUSED then
        sapp.sapp_show_mouse(false)
        app_has_focus = false
    else 
        nk.snk_handle_event(event)
    end  

    if event.type == sapp.SAPP_EVENTTYPE_MOUSE_DOWN or
        event.type == sapp.SAPP_EVENTTYPE_MOUSE_UP then

        local x, y = event.mouse_x, event.mouse_y
        local button = event.button
        system.push_event({
            type = LITE_EVENT[event.type],
            a = x, b = y, c = button, d = -1
        })    

    elseif event.type == sapp.SAPP_EVENTTYPE_MOUSE_MOVE then
    
        local x, y = event.mouse_x, event.mouse_y
        local dx, dy = event.mouse_dx, event.mouse_dy
    
        -- print("Mouse event at", x, y, "delta", dx, dy, "button", button)
        system.push_event({
            type = LITE_EVENT[event.type],
            a = x, b = y, c = dx, d = dy
        })    

    elseif event.type == sapp.SAPP_EVENTTYPE_MOUSE_SCROLL then
    
        local x, y = event.mouse_x, event.mouse_y
        local dx, dy = event.mouse_dx, event.mouse_dy
    
        -- print("Mouse event at", x, y, "delta", dx, dy, "button", button)
        system.push_event({
            type = LITE_EVENT[event.type],
            a = x, b = y, c = dx, d = dy
        })    

    elseif event.type == sapp.SAPP_EVENTTYPE_KEY_DOWN or
        event.type == sapp.SAPP_EVENTTYPE_KEY_UP or 
        event.type == sapp.SAPP_EVENTTYPE_CHAR then
    
        local key = event.key_code
        local char = event.char_code
        local mods = event.modifiers
    
        print("Key event", key, "char", char, "mods", mods)
        system.push_event({
            type = LITE_EVENT[event.type],
            a = key, b = char, c = mods, d = -1
        })    
    end
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

local winrect       = ffi.new("struct nk_rect[1]", {{0, 0, 1000, 600}})
local function core_run(ctx)

    winrect[0].h = sapp.sapp_height()
    local window_flags =  bit.bor( nk.NK_WINDOW_MOVABLE, nk.NK_WINDOW_NO_SCROLLBAR, nk.NK_WINDOW_MINIMIZABLE) 
    if (nk.nk_begin(ctx, "Dim", winrect[0], window_flags) == true) then
        core.run()
        nk.nk_end(ctx)
    end
    return not nk.nk_window_is_closed(ctx, "Overview")    
end

-- --------------------------------------------------------------------------------------

local function frame()

    -- /* NOTE: the vs_params_t struct has been code-generated by the shader-code-gen */
    local w         = sapp.sapp_widthf()
    local h         = sapp.sapp_heightf()
    local t         = (sapp.sapp_frame_duration() * 60.0)

    local dt = sapp.sapp_frame_duration()
    local ctx = nk.snk_new_frame()

    renderer.ctx    = ctx 

    if(core == nil) then     
        ErrorCheck( pcall( core_init ) )
        nk.nk_style_show_cursor(ctx)   
    else
        ErrorCheck( pcall( core_run, ctx ) )
    end

    -- // the sokol_gfx draw pass
    local pass = ffi.new("sg_pass[1]")
    pass[0].action.colors[0].load_action = sg.SG_LOADACTION_CLEAR
    pass[0].action.colors[0].clear_value = { 0.25, 0.5, 0.7, 1.0 }
    pass[0].swapchain = slib.sglue_swapchain()
    sg.sg_begin_pass(pass)

    nk.snk_render(sapp.sapp_width(), sapp.sapp_height())
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

local app_desc = ffi.new("sapp_desc[1]")
app_desc[0].init_cb     = init
app_desc[0].frame_cb    = frame
app_desc[0].cleanup_cb  = cleanup
app_desc[0].event_cb    = input
app_desc[0].width       = width
app_desc[0].height      = height
app_desc[0].high_dpi    = true
app_desc[0].window_title = "Dim"
app_desc[0].fullscreen  = false
-- app_desc[0].icon.sokol_default = true 
app_desc[0].enable_clipboard = true
app_desc[0].ios_keyboard_resizes_canvas = false
app_desc[0].logger.func = slib.slog_func 

sapp.sapp_run( app_desc )

-- --------------------------------------------------------------------------------------

if(profile) then profile.stop() end

-- --------------------------------------------------------------------------------------