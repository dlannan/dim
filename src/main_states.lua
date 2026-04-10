

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
local mputils   = require "lua.msgpack-utils"

local uv        = require('luv')
local services  = require("data.core.services.services")

require("src.video")

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
        video         = nil, 
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
-- 
bg_services.run = function(core)
  
    bg_services.services.filecheck = services.new_tcp_service()
    bg_services.services.vidstream = services.new_tcp_service(true)
    -- pprint(bg_services.services.filecheck)
    -- pprint(bg_services.services.vidstream)
    
    local fc_output = bg_services.services.filecheck.tcps
    local vs_output = bg_services.services.vidstream.tcps.out
    local vs_input = bg_services.services.vidstream.tcps.inp
    local vs_input_fds = bg_services.services.vidstream.fds.inp

    -- Tell video renderer interface the pipe handles
    video_renderer.input_writer_fd = vs_input.read
    video_renderer.output_reader_fd = vs_output.write

    print("Making service workers...")
    -- Background Services
    bg_services.services.filecheck.wid = services.make_worker()
    bg_services.services.vidstream.wid = services.make_worker()

    print("Making service readers...")
    mputils.read_chunk(fc_output.read, function(data)
        pprint("Project files.. updating...")
        core.project_files = data
    end) 

    -- mputils.read_chunk(vs_output.read, function(data)
    --     pprint("video frame:")
    -- end)

    local base_path = dirtools.get_app_path()
    bg_services.services.filecheck.wid:queue("core.services.file_check", base_path, nil, fc_output.write)
    bg_services.services.vidstream.wid:queue("core.services.video_stream", base_path, vs_input_fds[2], vs_output.read)
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

    video_renderer.init()
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

    bins.update(renderer.dt)
end

-- --------------------------------------------------------------------------------------

runningState.Render     = function(self, w, h)

    video_renderer.poll()
    threed_renderer.render_rects(renderer.dt)

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