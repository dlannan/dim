
local nk            = sg
local stb           = require("stb")

local ffi           = require("ffi")

local utils         = require("lua.utils")
local dirtools      = require("tools.vfs.dirtools")
local gltfloader    = require("lua.gltfloader.gltfloader")
local mesh          = require("lua.geometry.meshes")

local tinsert       = table.insert
local tremove       = table.remove

-- --------------------------------------------------------------------------------------

ffi.cdef[[
/* application state */
typedef struct state {
    float rx, ry;
    sg_pipeline pip;
    sg_bindings* bind;
} state;
]]

-- --------------------------------------------------------------------------------------

threed_renderer     = {
    queue   = {},
}

local function load_gltf(filename)

    local dir, fname, extension = dirtools.fileparts(filename)
    local asset = {
        path = "",
        folder = dir,
        asset = fname,
        format = extension
    }

	-- print(asset.path)
	-- print(asset.asset)
	-- print(asset.folder)
	-- print(asset.format)

	local assetfilename = filename
	local gltf = gltfloader:load_gltf( assetfilename, asset, nil )

	-- Add asset to ECS (go will update pos and rot)
	local ent = { 
		name = asset.name,
        mesh = gltf,
        model = mesh.model( asset.name, gltf, nil),
		pos = {0, 0, 0}, 
		rot = { 0, 0, 0}, 
		scale = {1, 1, 1},
		etype = asset.folder,
		filename = assetfilename,
		format = asset.format,
		aabb = model.aabb,
	} 

    return ent
end    

-- --------------------------------------------------------------------------------------

local function render_model( model_rect )

    model_rect.state = model_rect.state or ffi.new("state[1]")
    state = model_rect.state

    local w, h      = model_rect.w, model_rect.h
    local t         = (sapp.sapp_frame_duration() * 60.0)

    local proj      = hmm.HMM_Perspective(60.0, w/h, 0.01, 10.0)
    local view      = hmm.HMM_LookAt(hmm.HMM_Vec3(0.0, 1.5, 6.0), hmm.HMM_Vec3(0.0, 0.0, 0.0), hmm.HMM_Vec3(0.0, 1.0, 0.0))
    local view_proj = hmm.HMM_MultiplyMat4(proj, view)
    state[0].rx     = state[0].rx + 1.0 * t
    state[0].ry     = state[0].ry + 2.0 * t

    local rxm       = hmm.HMM_Rotate(state[0].rx, hmm.HMM_Vec3(1.0, 0.0, 0.0))
    local rym       = hmm.HMM_Rotate(state[0].ry, hmm.HMM_Vec3(0.0, 1.0, 0.0))
    local model     = hmm.HMM_MultiplyMat4(rxm, rym)

    local mvp       = hmm.HMM_MultiplyMat4(view_proj, model)

    sg.sg_apply_pipeline(state[0].pip)
    sg.sg_apply_bindings(state[0].bind)

    local vs_params = ffi.new("vs_params_t[1]")
    vs_params[0].mvp    = mvp
    sg_range[0].ptr     = vs_params
    sg_range[0].size    = ffi.sizeof(vs_params[0])
    sg.sg_apply_uniforms(0, sg_range)
    
    sg.sg_draw(0, 36, 1)
end

-- --------------------------------------------------------------------------------------

threed_renderer.load_model = function(filename)

    return load_gltf(filename)
end

-- --------------------------------------------------------------------------------------
-- Draw the model based on an xy rect position (not 3d space).
--  This queues model rects for drawing in the correct phase of the frame. 
threed_renderer.draw_model = function(model, x, y, w, h)

    tinsert(threed_renderer.queue, { model=model, x=x, y=y, w=w, h=h })
end

-- --------------------------------------------------------------------------------------
-- Iterate the queued rects and render models into them
-- Rects should _not_ be here if they are hidden (ie in a hidden tab)
threed_renderer.render_rects = function()

    local count = #threed_renderer.queue 
    -- print("queued models", count)
    for i=1, count do
        local model_rect = threed_renderer.queue[i]
        render_model(model_rect)
    end
end
