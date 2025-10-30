
local sapp          = require("sokol_app")
local nk            = sg
local stb           = require("stb")

local hmm           = require("hmm")
local hutils        = require("hmm_utils")

local ffi           = require("ffi")

local utils         = require("lua.utils")
local dirtools      = require("tools.vfs.dirtools")

local gltfloader    = require("lua.gltfloader.gltfloader")

local tinsert       = table.insert
local tremove       = table.remove

-- --------------------------------------------------------------------------------------

ffi.cdef[[
/* application state */
typedef struct internal_state {
    float rx, ry;
    sg_pipeline pip;
    sg_bindings* bind;
} internal_state;
]]

local MAX_STATES            = 1024
local state_array_index     = 0
local state_array   = ffi.new("internal_state[?]", MAX_STATES)

-- --------------------------------------------------------------------------------------

threed_renderer     = {
    render_queue        = {},
    model_load_queue    = {},

    -- A mapped list of model files by the file name
    --  These indicate whether a model is loaded, if it has an id and if it 
    --  has had its data initialised
    model_files         = {},
} 

-- --------------------------------------------------------------------------------------

local shc       = require("tools.shader_compiler.shc_compile").init( "dim", false )
local shader    = nil

-- --------------------------------------------------------------------------------------

threed_renderer.make_cube = function()

    shader    = shader or shc.compile("lua/engine/cube_simple.glsl")
    -- Make a fake model to use for testing
    local state = ffi.new("internal_state[1]")
    local binding = ffi.new("sg_bindings[1]", {})   

    local vertices = ffi.new("float[168]", {
        -1.0, -1.0, -1.0,   1.0, 0.0, 0.0, 1.0,
         1.0, -1.0, -1.0,   1.0, 0.0, 0.0, 1.0,
         1.0,  1.0, -1.0,   1.0, 0.0, 0.0, 1.0,
        -1.0,  1.0, -1.0,   1.0, 0.0, 0.0, 1.0,

        -1.0, -1.0,  1.0,   0.0, 1.0, 0.0, 1.0,
         1.0, -1.0,  1.0,   0.0, 1.0, 0.0, 1.0,
         1.0,  1.0,  1.0,   0.0, 1.0, 0.0, 1.0,
        -1.0,  1.0,  1.0,   0.0, 1.0, 0.0, 1.0,

        -1.0, -1.0, -1.0,   0.0, 0.0, 1.0, 1.0,
        -1.0,  1.0, -1.0,   0.0, 0.0, 1.0, 1.0,
        -1.0,  1.0,  1.0,   0.0, 0.0, 1.0, 1.0,
        -1.0, -1.0,  1.0,   0.0, 0.0, 1.0, 1.0,

        1.0, -1.0, -1.0,    1.0, 0.5, 0.0, 1.0,
        1.0,  1.0, -1.0,    1.0, 0.5, 0.0, 1.0,
        1.0,  1.0,  1.0,    1.0, 0.5, 0.0, 1.0,
        1.0, -1.0,  1.0,    1.0, 0.5, 0.0, 1.0,

        -1.0, -1.0, -1.0,   0.0, 0.5, 1.0, 1.0,
        -1.0, -1.0,  1.0,   0.0, 0.5, 1.0, 1.0,
         1.0, -1.0,  1.0,   0.0, 0.5, 1.0, 1.0,
         1.0, -1.0, -1.0,   0.0, 0.5, 1.0, 1.0,

        -1.0,  1.0, -1.0,   1.0, 0.0, 0.5, 1.0,
        -1.0,  1.0,  1.0,   1.0, 0.0, 0.5, 1.0,
         1.0,  1.0,  1.0,   1.0, 0.0, 0.5, 1.0,
         1.0,  1.0, -1.0,   1.0, 0.0, 0.5, 1.0
    }) 
    
    local buffer_desc           = ffi.new("sg_buffer_desc[1]")
    buffer_desc[0].data.ptr     = vertices
    buffer_desc[0].data.size    = ffi.sizeof(vertices)
    buffer_desc[0].label        = "cube-vertices"
    local vbuf = sg.sg_make_buffer(buffer_desc)

    local indices = ffi.new("uint16_t[36]", {
        0, 1, 2,  0, 2, 3,
        6, 5, 4,  7, 6, 4,
        8, 9, 10,  8, 10, 11,
        14, 13, 12,  15, 14, 12,
        16, 17, 18,  16, 18, 19,
        22, 21, 20,  23, 22, 20
    })

    local ibuffer_desc          = ffi.new("sg_buffer_desc[1]", {})
    ibuffer_desc[0].type        = sg.SG_BUFFERTYPE_INDEXBUFFER
    ibuffer_desc[0].data.ptr    = indices
    ibuffer_desc[0].data.size   = ffi.sizeof(indices) 
    ibuffer_desc[0].label       = "cube-indices"
    local ibuf = sg.sg_make_buffer(ibuffer_desc)
   
    -- local shader_desc = ffi.new("sg_shader_desc[1]")
    -- local desc = shader_desc[0]
    -- local vs_source_glsl410 = ffi.new("uint8_t[284]",{
    --     0x23,0x76,0x65,0x72,0x73,0x69,0x6f,0x6e,0x20,0x34,0x31,0x30,0x0a,0x0a,0x75,0x6e,
    --     0x69,0x66,0x6f,0x72,0x6d,0x20,0x76,0x65,0x63,0x34,0x20,0x76,0x73,0x5f,0x70,0x61,
    --     0x72,0x61,0x6d,0x73,0x5b,0x34,0x5d,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,
    --     0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x30,0x29,0x20,0x6f,0x75,
    --     0x74,0x20,0x76,0x65,0x63,0x34,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x6c,0x61,
    --     0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,
    --     0x31,0x29,0x20,0x69,0x6e,0x20,0x76,0x65,0x63,0x34,0x20,0x63,0x6f,0x6c,0x6f,0x72,
    --     0x30,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,
    --     0x6f,0x6e,0x20,0x3d,0x20,0x30,0x29,0x20,0x69,0x6e,0x20,0x76,0x65,0x63,0x34,0x20,
    --     0x70,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x0a,0x76,0x6f,0x69,0x64,0x20,
    --     0x6d,0x61,0x69,0x6e,0x28,0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x63,0x6f,0x6c,
    --     0x6f,0x72,0x20,0x3d,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x30,0x3b,0x0a,0x20,0x20,0x20,
    --     0x20,0x67,0x6c,0x5f,0x50,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x6d,
    --     0x61,0x74,0x34,0x28,0x76,0x73,0x5f,0x70,0x61,0x72,0x61,0x6d,0x73,0x5b,0x30,0x5d,
    --     0x2c,0x20,0x76,0x73,0x5f,0x70,0x61,0x72,0x61,0x6d,0x73,0x5b,0x31,0x5d,0x2c,0x20,
    --     0x76,0x73,0x5f,0x70,0x61,0x72,0x61,0x6d,0x73,0x5b,0x32,0x5d,0x2c,0x20,0x76,0x73,
    --     0x5f,0x70,0x61,0x72,0x61,0x6d,0x73,0x5b,0x33,0x5d,0x29,0x20,0x2a,0x20,0x70,0x6f,
    --     0x73,0x69,0x74,0x69,0x6f,0x6e,0x3b,0x0a,0x7d,0x0a,0x0a,0x00,
    -- })
        
    -- local fs_source_glsl410 = ffi.new("uint8_t[135]",{
    --     0x23,0x76,0x65,0x72,0x73,0x69,0x6f,0x6e,0x20,0x34,0x31,0x30,0x0a,0x0a,0x6c,0x61,
    --     0x79,0x6f,0x75,0x74,0x28,0x6c,0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,
    --     0x30,0x29,0x20,0x6f,0x75,0x74,0x20,0x76,0x65,0x63,0x34,0x20,0x66,0x72,0x61,0x67,
    --     0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x6c,0x61,0x79,0x6f,0x75,0x74,0x28,0x6c,
    --     0x6f,0x63,0x61,0x74,0x69,0x6f,0x6e,0x20,0x3d,0x20,0x30,0x29,0x20,0x69,0x6e,0x20,
    --     0x76,0x65,0x63,0x34,0x20,0x63,0x6f,0x6c,0x6f,0x72,0x3b,0x0a,0x0a,0x76,0x6f,0x69,
    --     0x64,0x20,0x6d,0x61,0x69,0x6e,0x28,0x29,0x0a,0x7b,0x0a,0x20,0x20,0x20,0x20,0x66,
    --     0x72,0x61,0x67,0x5f,0x63,0x6f,0x6c,0x6f,0x72,0x20,0x3d,0x20,0x63,0x6f,0x6c,0x6f,
    --     0x72,0x3b,0x0a,0x7d,0x0a,0x0a,0x00,
    -- })
        
    -- desc.vertex_func.source = vs_source_glsl410
    -- desc.vertex_func.entry = "main"
    -- desc.fragment_func.source = fs_source_glsl410
    -- desc.fragment_func.entry = "main"
    -- desc.attrs[0].glsl_name = "position"
    -- desc.attrs[1].glsl_name = "color0"
    -- desc.uniform_blocks[0].stage = sg.SG_SHADERSTAGE_VERTEX
    -- desc.uniform_blocks[0].layout = sg.SG_UNIFORMLAYOUT_STD140
    -- desc.uniform_blocks[0].size = 64
    -- desc.uniform_blocks[0].glsl_uniforms[0].type = sg.SG_UNIFORMTYPE_FLOAT4
    -- desc.uniform_blocks[0].glsl_uniforms[0].array_count = 4
    -- desc.uniform_blocks[0].glsl_uniforms[0].glsl_name = "vs_params"
    -- desc.label = "cube_shader"

    local shd = sg.sg_make_shader(shader)

    local pipe_desc = ffi.new("sg_pipeline_desc[1]", {})
    pipe_desc[0].layout.buffers[0].stride = 28
    pipe_desc[0].layout.attrs[0].format = sg.SG_VERTEXFORMAT_FLOAT3
    pipe_desc[0].layout.attrs[1].format = sg.SG_VERTEXFORMAT_FLOAT4
    pipe_desc[0].shader         = shd
    pipe_desc[0].index_type     = sg.SG_INDEXTYPE_UINT16
    pipe_desc[0].cull_mode      = sg.SG_CULLMODE_BACK
    pipe_desc[0].depth.write_enabled = true
    pipe_desc[0].depth.compare  = sg.SG_COMPAREFUNC_LESS_EQUAL
    pipe_desc[0].label          = "cube-pipeline"
    state[0].pip = sg.sg_make_pipeline(pipe_desc)

    binding[0].vertex_buffers[0] = vbuf
    binding[0].index_buffer     = ibuf
    state[0].bind               = binding

    return { state = state, binding = binding }
end


-- --------------------------------------------------------------------------------------

local function load_gltf(filename)

    local dir, fname, extension = dirtools.fileparts(filename)
    local asset = {
        path = "",
        folder = dir,
        name = fname,
        asset = fname,
        format = extension
    }

	-- print(asset.path)
	-- print(asset.asset)
	-- print(asset.folder)
	-- print(asset.format)

	local assetfilename = filename
	local gltf_data = gltfloader:load_gltf( assetfilename, asset, nil )

    -- Convert internal bind and pip to internal state array (for global acces by sokol)
    for i, state in ipairs(gltf_data.states_tbl) do 

        state_array[state_array_index].bind = state.bind
        state_array[state_array_index].pip = state.pip
        state_array[state_array_index].rx = 0
        state_array[state_array_index].ry = 0
        state.state_idx = state_array_index
        state_array_index = state_array_index + 1
    end 

    local ent = { 
		name = asset.name,
        id  = asset.go,
        model = nil,
        mesh = gltf_data,
		pos = {0, 0, 0}, 
		rot = { 0, 0, 0}, 
		scale = {1, 1, 1},
		etype = asset.folder,
		filename = assetfilename,
		format = asset.format,
	} 
    return ent
end    

-- --------------------------------------------------------------------------------------

local function render_model( t, model_rect )

    model_rect.sg_range = model_rect.sg_range or ffi.new("sg_range[1]")
    local all_states = model_rect.model.data.mesh.states_tbl
    local aabb = model_rect.model.data.mesh.aabb
    local maxx = aabb.max.x - aabb.min.x
    local maxy = aabb.max.y - aabb.min.y
    local maxz = aabb.max.z - aabb.min.z
    local maxsize = math.sqrt( maxx * maxx + maxy * maxy + maxz * maxz)

    for i, state_data in ipairs(all_states) do 

        local state     = state_array[state_data.state_idx]

        local pip       = state.pip
        local bind      = state.bind

        local w, h      = model_rect.w, model_rect.h

        local proj      = hmm.HMM_Perspective(60.0, w/h, 0.01, 10.0)
        local view      = hmm.HMM_LookAt(hmm.HMM_Vec3(0.0, 1.5, 6.0), hmm.HMM_Vec3(0.0, 0.0, 0.0), hmm.HMM_Vec3(0.0, 1.0, 0.0))
        local view_proj = hmm.HMM_MultiplyMat4(proj, view)
        state.rx        = 0.0
        state.ry        = state.ry + 1.0 * t

        local rxm       = hmm.HMM_Rotate(state.rx, hmm.HMM_Vec3(1.0, 0.0, 0.0))
        local rym       = hmm.HMM_Rotate(state.ry, hmm.HMM_Vec3(0.0, 1.0, 0.0))
        local model     = hmm.HMM_MultiplyMat4(rxm, rym)

        local sc = 3.0 / maxsize
        local scaler    = hmm.HMM_Scale(hmm.HMM_Vec3(sc, sc, sc))
        local model     = hmm.HMM_MultiplyMat4(model, scaler)
        local mvp       = hmm.HMM_MultiplyMat4(view_proj, model)

        sg.sg_apply_pipeline(pip)
        sg.sg_apply_bindings(bind)

        local vs_params = ffi.new("vs_params_t[1]")
        vs_params[0].mvp    = mvp
        model_rect.sg_range[0].ptr     = vs_params
        model_rect.sg_range[0].size    = ffi.sizeof(vs_params[0])
        sg.sg_apply_uniforms(0,  model_rect.sg_range)

        sg.sg_apply_viewport(model_rect.x, model_rect.y, model_rect.w, model_rect.h, true)
        sg.sg_apply_scissor_rect(model_rect.x, model_rect.y, model_rect.w, model_rect.h, true)
    
        sg.sg_draw(0, state_data.count, 1)
    end
end

-- --------------------------------------------------------------------------------------
-- This doesnt directly load a model in case it happens during an incorrent phase of rendering
threed_renderer.load_model = function(filename)

    -- Check first if it hasnt been loaded already! 
    local is_loaded = threed_renderer.model_load_queue[filename]
    if(is_loaded) then 
        return is_loaded
    end

    local new_model = { loaded = nil, filename = filename }
    threed_renderer.model_load_queue[filename] = new_model
    return new_model
end

-- --------------------------------------------------------------------------------------
-- Draw the model based on an xy rect position (not 3d space).
--  This queues model rects for drawing in the correct phase of the frame. 
threed_renderer.draw_model = function(model, x, y, w, h)

    if (model.loaded == true) then 
        tinsert(threed_renderer.render_queue, { model=model, x=x, y=y, w=w, h=h })
    end
end

-- --------------------------------------------------------------------------------------
-- Iterate the queued rects and render models into them
-- Rects should _not_ be here if they are hidden (ie in a hidden tab)
threed_renderer.load_models = function()

    -- print("queued models", count)
    for k,model_load in pairs(threed_renderer.model_load_queue) do
        if(model_load.loaded == nil) then
            model_load.data = load_gltf(model_load.filename)
            -- model_load.data = threed_renderer.make_cube()
            model_load.loaded = true
        end
    end
end

-- --------------------------------------------------------------------------------------
-- Iterate the queued rects and render models into them
-- Rects should _not_ be here if they are hidden (ie in a hidden tab)
threed_renderer.render_rects = function( t )

    local count = #threed_renderer.render_queue 
    -- print("queued models", count)
    for i=1, count do
        local model_rect = threed_renderer.render_queue[i]
        render_model(t, model_rect)
    end
end

-- --------------------------------------------------------------------------------------
