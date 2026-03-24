

local dirtools      = require("tools.vfs.dirtools").init("dim")

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

local cammgr    = require("lua.engine.camera_manager")
local bins 	    = require("lua.geometry.bins")

local smgr      = require("lua.engine.statemanager")
local seq       = require("lua.engine.sequencer")

local imageutils 	= require("lua.gltfloader.image-utils")

local msgpack   = require "lua.msgpack"
local uv        = require('luv')

-- --------------------------------------------------------------------------------------
-- lite core setup
local core          = nil
local profile       = nil
local profile_capture = nil

local function set_profile(p, cap) profile = p; profile_capture = cap end

-- --------------------------------------------------------------------------------------

local warmupState    = smgr:NewState()
local coreInitState  = smgr:NewState()
local runningState   = smgr:NewState()

--------------------------------------------------------------------------------------------------

local bg_services = {

    services    = {
        file_check    = nil,
        routing       = nil,
    },

    render      = {
        main_pass     = nil,
    },
}

CLEAR_COLOR         = { 0.118, 0.118, 0.118, 1.0 }
  
--------------------------------------------------------------------------------------------------
-- Create a new signal handler - catch the ctrl+c to exit nicely
local signal = uv.new_signal()
-- Define a handler function
uv.signal_start(signal, "sigint", function(signame)
      pprint("[Signal:" .. signame .. "] Exiting BG Service.")
      uv.walk(uv.close)
      uv.run() 
      os.exit(1)
end)

--------------------------------------------------------------------------------------------------

local function endsWith(str, suffix)
    return str:sub(-#suffix) == suffix
end
  
--------------------------------------------------------------------------------------------------

bg_services.run = function(core)
    uv.set_process_title("bg_services")
  
    bg_services.services.fds = assert(uv.pipe({nonblock=true}, {nonblock=true}))
    assert(uv.guess_handle(bg_services.services.fds.read) == "pipe")
    assert(uv.guess_handle(bg_services.services.fds.write) == "pipe")
    bg_services.services.pipe_read = assert(uv.new_pipe())
    bg_services.services.pipe_read:open(bg_services.services.fds.read)
    bg_services.services.pipe_write = assert(uv.new_pipe())
    bg_services.services.pipe_write:open(bg_services.services.fds.write)

    -- Background Services
    bg_services.services.file_check = uv.new_work(function(base_path, pipe_writer)
        
        package.path      = package.path..";"..base_path.."\\data\\?.lua"
        SCALE = 1.0

        local dirtools      = require("tools.vfs.dirtools").init("dim")
        local uv            = require('luv')
        local pp            = require("lua.pretty-print")

        require("src.system")
        require("src.platform")

        local file_check  = require("core.services.file_check")
        file_check.init(pipe_writer)
        local idle = uv.new_idle()
        idle:start(function()
          file_check.run()
        end)
        uv.run("default")
    end, function() uv.walk(uv.close); uv.run() end)

    local reading = 0
    local reading_done = false
    local total = ""
    bg_services.services.pipe_read:read_start(function(err, chunk)
        assert(not err, err)
        if chunk == nil then 
            return
        elseif endsWith(chunk, "MSGPACK_END") then
            pprint("[Info] Project directory scan complete.")
            chunk = string.sub(chunk, 1, -12)
            reading_done = true
        else 
            reading = reading + 1
        end
        if(reading > 0) then 
            total = total..chunk
        end 
        if(core and reading_done == true) then
            core.project_files = msgpack.unpack(total)
            total = ""
            reading_done = false
            reading = 0
        end
    end)

    local base_path = dirtools.get_app_path()
    uv.queue_work(bg_services.services.file_check, base_path, bg_services.services.pipe_write)
end

--------------------------------------------------------------------------------------------------

bg_services.stop = function(core)
    uv.stop()
end

-- --------------------------------------------------------------------------------------

local function ErrorCheck(status, err)
    if(status == false) then
        pprint("[Error] ", err)
        print(debug.traceback())
        if(profile) then
            print("[Profile data] profile_capture.log")
            local fh = io.open("logs/profile_capture.log", "w")
            if(fh) then 
                for i,v in ipairs(profile_capture) do 
                    fh:write(v)
                end 
                fh:close()
            end
        end
        os.exit()
    else
        return err
    end
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

-- -----------------------------------------------------------------------------------------

local function core_run(ctx, core, winrect, custom)

    local window_flags =  bit.bor(nk.NK_WINDOW_NO_INPUT, nk.NK_WINDOW_NO_SCROLLBAR, nk.NK_WINDOW_BACKGROUND)
    if (nk.nk_begin(ctx, WINDOW_NAME, winrect[0], window_flags) == true) then
        renderer.canvas = nk.nk_window_get_canvas(ctx)
        renderer.rect = nk.nk_window_get_content_region(ctx)
        if(custom) then custom() end
    end
    renderer.set_cursor()
    nk.nk_end(ctx)
    return not nk.nk_window_is_closed(ctx, WINDOW_NAME)
end

-- --------------------------------------------------------------------------------------

warmupState.Begin   = function(self)

    SCALE = sapp.sapp_dpi_scale()
    bins.init()

    local hwnd      = sapp.sapp_win32_get_hwnd()
    local dw, dh    = self.width, self.height
    win.SetWindowPos(hwnd, dw/2 - 320, dh/2 - 100, 640, 200)
    self.frame_started = 0

    -- Setup some default passes
    -- // the sokol_gfx draw pass   
    local main_pass = {
        action      = sg.SG_LOADACTION_CLEAR,
        clear       = CLEAR_COLOR,
    }

	if(imageutils.default_white_image == nil) then 
		imageutils.make_defaults()
	end     

    -- Should have some sort of default configh ere
    local newcam = cammgr.add("gui_camera", 60.0, 1, 0.01, 12.0) 
    bg_services.render.gui_passid = bins.pass_add(main_pass, bins.BTYPE_GUI)  
    cammgr.add_pass("gui_camera", bg_services.render.gui_passid)
    bins.camera_add(newcam.id)

    -- Add a gui bin pass render
    bins.bin_set_func(bins.BTYPE_GUI, function(w, h)
        nk.snk_render(w, h)
    end)
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
    core_run( ctx, nil, self.winrect, function()
        local res = nk.nk_style_set_cursor(ctx, 0)
        nk.nk_style_hide_cursor(ctx)

        local r = renderer.rect
        nk.nk_layout_row_static(ctx, r.h, r.w, 1)
        nk.nk_label(ctx, "loading "..WINDOW_NAME.."...", nk.NK_TEXT_CENTERED)
    end)
end


-- --------------------------------------------------------------------------------------

warmupState.Render = function(self, w, h)

    bins.render(w, h)
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

    bins.render(w, h)
end

-- --------------------------------------------------------------------------------------

runningState.Begin   = function(self)

    bg_services.run(core)

    core.recv_message( "PreRender" , runningState.PreRender)
    core.recv_message( "PostRender" , runningState.PostRender)

    -- bins.bin_set_func( bins.bintype.BTYPE_OPAQUE, function(w, h)
    --     nk.snk_render(w, h)
    -- end, 1)
end

-- --------------------------------------------------------------------------------------

runningState.PreRender     = function(msg)
    print("PreRender Called")
end

runningState.PostRender     = function(msg)
    print("PostRender Called")
    if(msg and msg.data and msg.data.func) then 
        msg.data.func(msg.data)
    end
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
        did_draw = core.run(self.width, self.height)
    end

    local clearflag = 0
    if(did_draw == false) then clearflag = 1 end
    if(did_draw == true) then threed_renderer.render_queue = {} end

    local ctx       = nk.snk_new_frame(clearflag)
    renderer.ctx    = ctx
    renderer.clearflag = clearflag

    if(core and core.ready and did_draw == true) then
        ErrorCheck( pcall(core_run, ctx, core, self.winrect, function()
            core.render()
        end) )
    end

    threed_renderer.render_rects(renderer.dt)
    bins.update(renderer.dt)
end

-- --------------------------------------------------------------------------------------

runningState.Render     = function(self, w, h)

    -- // Render 3D view rects here - will get rects from the docviews.
    bins.render(w, h)
end

-- --------------------------------------------------------------------------------------

runningState.Finish     = function(self)
    bg_services.stop()
    nk.snk_shutdown()
    sg.sg_shutdown()
    core.quit()
end

-- --------------------------------------------------------------------------------------

return {
    warmupState     = warmupState,
    coreInitState   = coreInitState,
    runningState    = runningState,
    set_profile     = set_profile,
}

-- --------------------------------------------------------------------------------------