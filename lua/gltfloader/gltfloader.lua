------------------------------------------------------------------------------------------------------------

local tinsert = table.insert

------------------------------------------------------------------------------------------------------------

local ffi 			= require("ffi")

local gameobject	= require("lua.engine.gameobject")

local geom 			= require("lua.gltfloader.geometry-utils")
local meshes 		= require("lua.geometry.meshes")
local imageutils 	= require("lua.gltfloader.image-utils")

local b64 			= require("lua.base64")
local utils			= require("lua.utils")
local cgltf      	= require("ffi.sokol.cgltf")
local hmm      		= require("hmm")

------------------------------------------------------------------------------------------------------------

local gltfloader = {
	gomeshname 		= "temp",
	goscriptname 	= "script",
	curr_factory 	= nil,
	temp_meshes 	= {},
}

------------------------------------------------------------------------------------------------------------

function gltfloader:processmaterials( gltfobj, gochildname, thisnode )

	-- Get indices from accessor 
	local thismesh = thisnode.mesh
	local prims = thismesh.primitives	

	if(prims == nil) then print("No Primitives?"); return end 

	-- Iterate primitives in this mesh
	for k,prim in pairs(prims) do

		-- If it has a material, load it, and set the material 
		if(prim.material) then 

			local mat = prim.material
			local pbrmetallicrough = mat.pbrMetallicRoughness 
			local primmesh = { mesh = prim.primmesh, name = prim.primname }

			if(mat.alphaMode) then 
				-- Set material tag to include mask (for predicate rendering!)
				if(mat.alphaMode == "MASK") then 
					-- local maskmat = go.get("/material#tempmask", "material")
					-- go.set(prim.primmesh, "material", maskmat)
				end
				if(mat.alphaMode == "BLEND") then 
					-- local maskmat = go.get("/material#tempmask", "material")
					-- go.set(prim.primmesh, "material", maskmat)
				end
			end
			
			if (pbrmetallicrough) then 

				if(pbrmetallicrough.baseColorFactor) then 
					local bcolor = pbrmetallicrough.baseColorFactor
					-- TODO: Material gen with base color setting
					-- model.set_constant(prim.primmesh, "tint", vmath.vector4(bcolor[1], bcolor[2], bcolor[3], bcolor[4]) )
				end 
				
				if(pbrmetallicrough.baseColorTexture) then 
					local bcolor = pbrmetallicrough.baseColorTexture
					gltfloader:loadimages( gltfobj, primmesh, bcolor, 0 )
				end 

				if(pbrmetallicrough.metallicRoughnessTexture) then 
					local bcolor = pbrmetallicrough.metallicRoughnessTexture
					gltfloader:loadimages( gltfobj, primmesh, bcolor, 1 )
				end
			end
			local pbremissive = mat.emissiveTexture
			if(pbremissive) then 
				local bcolor = pbremissive
				gltfloader:loadimages( gltfobj, primmesh, bcolor, 2 )
			end
			local pbrnormal = mat.normalTexture
			if(pbrnormal) then  
				local bcolor = pbrnormal
				gltfloader:loadimages( gltfobj, primmesh, bcolor, 3 )
			end

			if(mat.doubleSided == true) then 

			end
		end 
	end
end 

------------------------------------------------------------------------------------------------------------
-- Combine AABB's of model with primitives. 
local function calcAABB( gltfobj, aabbmin, aabbmax )
	gltfobj.aabb = gltfobj.aabb or { 
		min = hmm.HMM_Vec3(math.huge,math.huge,math.huge), 
		max = hmm.HMM_Vec3(-math.huge,-math.huge,-math.huge) 
	}
	gltfobj.aabb.min.x = math.min(gltfobj.aabb.min.x, aabbmin[1])
	gltfobj.aabb.min.y = math.min(gltfobj.aabb.min.y, aabbmin[2])
	gltfobj.aabb.min.z = math.min(gltfobj.aabb.min.z, aabbmin[3])

	gltfobj.aabb.max.x = math.max(gltfobj.aabb.max.x, aabbmax[1])
	gltfobj.aabb.max.y = math.max(gltfobj.aabb.max.y, aabbmax[2])
	gltfobj.aabb.max.z = math.max(gltfobj.aabb.max.z, aabbmax[3])
end

------------------------------------------------------------------------------------------------------------

local function jointables(t1, t2)

	for k,v in pairs(t2) do 
		tinsert(t1, v)
	end
end

------------------------------------------------------------------------------------------------------------

function gltfloader:processdata( gltfobj, gochildname, thisnode, parent )

	--print(gltfobj)
	local thismesh = thisnode.mesh
	local prims = thismesh.primitives	

	if(prims == nil) then print("No Primitives?"); return end 

	local buffer_data = nil
	
	-- collate all primitives (we ignore material separate prims)
	for pid, prim in ipairs(prims) do

		local verts = nil
		local uvs = nil
		local normals = nil
		
		local acc_idx = prim.indices
		local indices = nil
		
		local itype = sg.SG_INDEXTYPE_UINT16

		if(acc_idx) then 
			local bv = acc_idx.bufferView
			local index_buffer_data = bv:get()

			-- Indices specific - this is default dataset for gltf (I think)
			if(acc_idx.componentType == 5125) then 
				indices = ffi.new("uint32_t[?]", acc_idx.count)
				ffi.copy(indices, ffi.string(index_buffer_data), acc_idx.count * 4)
				-- geomextension.setdataintstotable( 0, , index_buffer_data, indices)
				itype = sg.SG_INDEXTYPE_UINT32
				print("[Warning] 32 bit index buffer")
			elseif(acc_idx.componentType == 5123 or acc_idx.componentType == 5122) then 
				indices = ffi.new("uint16_t[?]", acc_idx.count)
				ffi.copy(indices, ffi.string(index_buffer_data), acc_idx.count * 2)
				-- geomextension.setdatashortstotable( 0, acc_idx.count * 2, index_buffer_data, indices)
			elseif(acc_idx.componentType == 5120 or acc_idx.componentType == 5121) then 
				indices = ffi.new("uint16_t[?]", acc_idx.count)
				local ptr = ffi.cast("uint8_t *", ffi.string(index_buffer_data))
				for i=0, acc_idx.count-1 do 
					indices[i] = ptr[i]
				end
				itype = sg.SG_INDEXTYPE_UINT16
				-- geomextension.setdatabytestotable( 0, acc_idx.count, index_buffer_data, indices)
				print("[Warning] 8 bit index buffer")
			else 
				print("[Error] Unhandled componentType: "..acc_idx.componentType)
			end
		else 
			print("[Error] No indices.")
			-- No indices generate a tristrip from position count
			local posidx = prim.attributes["POSITION"]
			-- Leave indices nil. The pipeline builder will use triangles by default

			-- geomextension.buildindicestotable( 0, posidx.count, 1, indices)
		end

		-- Get position accessor
		local aabb = nil
		local posidx = prim.attributes["POSITION"]
		if(posidx) then 
			local bv = posidx.bufferView
			buffer_data = bv:get()

			local offset = bv.byteOffset
			local length = bv.byteLength

			-- Get positions (or verts) 
			verts = ffi.new("float[?]", length * 3)
			local bufptr = ffi.cast("char * ", ffi.string(buffer_data))
			ffi.copy(verts, bufptr + offset, length * 3 * ffi.sizeof("float"))

			-- geomextension.setdataindexfloatstotable( buffer_data, verts, indices, 3)
			aabb = { posidx.min[1], posidx.min[2], posidx.min[3], posidx.max[1], posidx.max[2], posidx.max[3] }
			calcAABB( gltfobj, posidx.min, posidx.max )
		end

		-- Get uvs accessor
		local texidx = prim.attributes["TEXCOORD_0"]
		if(texidx) then 
			local bv = texidx.bufferView
			buffer_data = bv:get()

			local offset = bv.byteOffset
			local length = bv.byteLength			

			uvs = ffi.new("float[?]", length * 2)
			local bufptr = ffi.cast("char * ", ffi.string(buffer_data))
			ffi.copy(uvs, bufptr + offset, length * 2 * ffi.sizeof("float"))
			-- geomextension.setdataindexfloatstotable( buffer_data, uvs, indices, 2)
		end 

		-- Get normals accessor
		local normidx = prim.attributes["NORMAL"]
		if(normidx) then 
			local bv = normidx.bufferView
			buffer_data = bv:get()

			local offset = bv.byteOffset
			local length = bv.byteLength			

			normals = ffi.new("float[?]", length * 3)
			local bufptr = ffi.cast("char * ", ffi.string(buffer_data))
			ffi.copy(normals, bufptr + offset, length * 3 * ffi.sizeof("float"))			
			-- geomextension.setdataindexfloatstotable( buffer_data, normals, indices, 3)
		end 

		if(acc_idx) then 
			-- Reset indicies, because our buffers are all aligned!

			-- NOTE: Not sure if this is needed. Will need to check
			-- geomextension.buildindicestotable( 0, acc_idx.count, 1, indices)
		end
		
		-- 	local indices	= { 0, 1, 2, 0, 2, 3 }
		-- 	local verts		= { -sx + offx, 0.0, sy + offy, sx + offx, 0.0, sy + offy, sx + offx, 0.0, -sy + offy, -sx + offx, 0.0, -sy + offy }
		-- 	local uvs		= { 0.0, 0.0, uvMult, 0.0, uvMult, uvMult, 0.0, uvMult }
		-- 	local normals	= { 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0 }

		-- Make a submesh for each primitive. This is kinda bad, but.. well.
		-- print(gochildname)
		local primname = ffi.string(gochildname).."_prim_"..tostring(pid)
		prim.primname = ffi.string(gochildname)
		local primgo = gameobject.create( nil, primname )
		local primmesh = ffi.string(gameobject.goname(primgo)).."_temp"
		prim.primmesh = primmesh
		
		if(indices) then 

			local primdata = {
				itype = itype, 
				icount = acc_idx.count,
				indices = indices, 
				verts = verts, 
				uvs = uvs, 
				normals = normals, 
				aabb = aabb,
			}
			prim.mesh_buffers = geom:makeMesh( primmesh, primdata )
		end

		-- go.set_rotation(vmath.quat(), primgo)
		-- go.set_position(vmath.vector3(0,0,0), primgo)
		-- go.set_parent( primmesh, gochildname )
	end
end

------------------------------------------------------------------------------------------------------------

function gltfloader:makeNodeMeshes( gltfobj, parent, node )

	local thisnode = node
	
	-- Each node can have a mesh reference. If so, get the mesh data and make one, set its parent to the
	--  parent node mesh

	local parentname = gameobject.goname(parent)
	local gomeshname  = parentname.."/node_"..string.format("%s", node.name)
	gomeshname = gomeshname:gsub("%s+", "")
		
	local gochild = gameobject.create( nil, gomeshname )
	if(gochild == nil) then 
		print("[Error] Factory could not create mesh.")
		return 
	end 

	local gochildname = gameobject.goname(gochild)
	thisnode.goname = gochildname
	
	--print("Name:", gomeshname)	
	if(thisnode.mesh) then 
		
		-- Temp.. 
		gltfloader:processdata( gltfobj, gochildname, thisnode, parent )
		gltfloader:processmaterials( gltfobj, gochildname, thisnode )	
	end 

	-- Try children
	local rot = thisnode["rotation"]
	if(rot) then gameobject.set_rotation(gochild, hmm.HMM_Quaternion(rot[1], rot[2], rot[3], rot[4])) end
	local trans = thisnode["translation"]
	if(trans) then gameobject.set_position(gochild, hmm.HMM_Vec3(trans[1], trans[2], trans[3])) end

	local scale = thisnode["scale"]
	if(scale) then gameobject.set_scale(gochild, hmm.HMM_Vec3(math.abs(scale[1]), math.abs(scale[2]), math.abs(scale[3])) ) end
	
	-- Parent this mesh to the incoming node 
	gameobject.set_parent(gochild, parent)
	
	if(thisnode.children) then 
		for k, child in pairs(thisnode.children) do 
			self:makeNodeMeshes( gltfobj, gochild, child)
		end 
	end
end	

------------------------------------------------------------------------------------------------------------
-- Load images: This is horribly slow at the moment. Will improve.

function gltfloader:loadimages( gltfobj, primmesh, bcolor, tid )
	
	if(bcolor and bcolor.texture and bcolor.texture.source) then 
		tid = tid or 0
		-- Load in any images 
		if(bcolor.texture.source.uri) then 
			-- print("TID: "..tid.."   "..gltfobj.basepath..bcolor.texture.source.uri)
			imageutils.loadimage(primmesh.mesh, gltfobj.basepath..bcolor.texture.source.uri, tid )
		elseif(bcolor.texture.source.bufferView) then
			-- print("TID: "..tid.."   "..bcolor.texture.source.name.."  "..bcolor.texture.source.mimeType)
			local stringbuffer = bcolor.texture.source.bufferView:get()
			imageutils.loadimagebuffer(primmesh.mesh, stringbuffer, tid )

			-- imageutils.defoldbufferimage(primmesh.mesh, bytes, pnginfo, tid )		
		end
	end
end

------------------------------------------------------------------------------------------------------------
-- // parse the GLTF buffer definitions and start loading buffer blobs
function gltf_parse_buffers(model)
	
	local options = ffi.new("cgltf_options[1]", {})
	local result = cgltf.cgltf_load_buffers( options, model.data[0], model.filename)
	if(result ~= cgltf.cgltf_result_success) then 
		print("[Error] gltf_parse_buffers: cannot load buffers")
		return nil
	end

	-- Buffer views and buffers are now loaded ok. Ready for parsing.
end	

-- --------------------------------------------------------------------------------------------------------

local function build_transform_for_gltf_node(gltf, node) 
    parent_tform = mat44_identity()
    if (node.parent) then
        parent_tform = build_transform_for_gltf_node(gltf, node.parent)
	end
    if (node.has_matrix) then
        -- // needs testing, not sure if the element order is correct
        tform = *(mat44_t*)node.matrix -- this is a float ptr x 16 or 12
        return tform
    else 
        local mat44_t translate = mat44_identity()
        local mat44_t rotate = mat44_identity()
        local mat44_t scale = mat44_identity()
        if (node.has_translation) then
            translate = mat44_translation(node.translation[0], node.translation[1], node.translation[2])
		end
        if (node.has_rotation) then
            rotate = mat44_from_quat(vec4(node.rotation[0], node.rotation[1], node.rotation[2], node.rotation[3]))
		end
        if (node.has_scale) then
            scale = mat44_scaling(node.scale[0], node.scale[1], node.scale[2])
		end
        -- // NOTE: not sure if the multiplication order is correct
        return vm_mul(vm_mul(translate, vm_mul(rotate, scale)), parent_tform)
    end
end

-- --------------------------------------------------------------------------------------------------------

local function get_addr(ptr, off)
	off = off or 0
	return tostring(ffi.cast("uintptr_t", ptr) + off)
end

-- --------------------------------------------------------------------------------------------------------
-- Load images using our utils.
function gltf_parse_images(model)

	local image_map = {}
	model.images = {}
	local image_count = tonumber(model.data[0].images_count)
	for i=0, image_count -1 do 
		local img = model.data[0].images[i]
		local addr = get_addr(model.data[0].images, i)
		image_map[addr] = #model.images + 1
		local image = nil
		local imagename = ffi.string(img.name)
		if(img.uri ~= nil) then 
			local filepath = gltfobj.basepath..ffi.string(img.uri)
			image = imageutils.loadimage(imagename, filepath, i )
		else 
			local bv = img.buffer_view		
			local bufptr = nil
			if(bv[0].data ~= nil) then 
				bufptr = ffi.cast("uint8_t *", bv[0].data)
			else
				bufptr = cgltf.cgltf_buffer_view_data(bv)
			end
			image = imageutils.loadimagebuffer(imagename, bufptr, bv[0].size, i )
		end
		tinsert(model.images, image)
		collectgarbage("collect")
	end

	-- Loade images into texture slots! 
	model.textures = {}
	model.textures_map = {}
	for i = 0, tonumber(model.data[0].textures_count)-1 do
    	local tex = model.data[0].textures[i]
		local img_id = image_map[get_addr(tex.image, 0)]
		local tex_img = model.images[img_id]
		local texaddr = get_addr(model.data[0].textures, i)
		model.textures_map[texaddr] = tex_img
    	tinsert(model.textures, tex_img)
	end	
end

-- --------------------------------------------------------------------------------------------------------

function gltf_parse_materials(model)

	model.materials = {}
	model.materials_map = {}
	local gltf = model.data[0]
	local num_materials =  tonumber(gltf.materials_count)
    for i = 0, num_materials - 1 do
        local gltf_mat = gltf.materials[i]
        local scene_mat = {}
        scene_mat.is_metallic = gltf_mat.has_pbr_metallic_roughness
        if (scene_mat.is_metallic == 1) then
            local src = gltf_mat.pbr_metallic_roughness
            scene_mat.base_color = {
				src.base_color_factor[0], src.base_color_factor[1], src.base_color_factor[2], src.base_color_factor[3],
			}
			scene_mat.metallic_factor = src.metallic_factor
			scene_mat.roughness_factor = src.roughness_factor
			scene_mat.emissive_factor = {
				gltf_mat.emissive_factor[0], gltf_mat.emissive_factor[1], gltf_mat.emissive_factor[2],
			}

            scene_mat.images = {
                base_color = model.textures_map[get_addr(src.base_color_texture.texture, 0)],
                metallic_roughness = model.textures_map[get_addr(src.metallic_roughness_texture.texture,0)],
                normal = model.textures_map[get_addr(gltf_mat.normal_texture.texture, 0)],
                occlusion = model.textures_map[get_addr(gltf_mat.occlusion_texture.texture, 0)],
                emissive = model.textures_map[get_addr(gltf_mat.emissive_texture.texture, 0)]
            }
        end 
		model.materials_map[ get_addr(gltf.materials, i)] = scene_mat
		tinsert(model.materials, scene_mat)
	end

end

-- --------------------------------------------------------------------------------------------------------

function gltf_parse_meshes(model)

	model.scene = {}
	model.scene.meshes = {}
	local gltf = model.data[0]

    model.scene.num_meshes = tonumber(gltf.meshes_count)
    for mesh_index = 0, model.scene.num_meshes-1 do
        local gltf_mesh = gltf.meshes[mesh_index]

		local mesh = { primitives = {} }
        mesh.first_primitive = 1
        mesh.num_primitives = tonumber(gltf_mesh.primitives_count)
        for prim_index = 0,  mesh.num_primitives-1 do
            local gltf_prim = gltf_mesh.primitives[prim_index]
			local mat_handle = get_addr(gltf_prim.material)
            local prim = {
				prim = gltf_prim,
				material = model.materials_map[mat_handle],
				indices = gltf_prim.indices,
				type = gltf_prim.type,
				attribs = gltf_prim.attributes,
			}
			tinsert( mesh.primitives, prim )
        end 
		tinsert( model.scene.meshes, mesh )
    end
end

-- --------------------------------------------------------------------------------------------------------

function gltf_parse_nodes(model)

	model.scene.nodes = {}
	local gltf = model.data[0]

	model.scene.nodes_count  = gltf[0].nodes_count
	for node_index = 0, model.scene.nodes_count-1 do
        local gltf_node = gltf.nodes[node_index]
        -- // ignore nodes without mesh, those are not relevant since we
        -- // bake the transform hierarchy into per-node world space transforms
        if (gltf_node.mesh) then 
            local node = {}
            node.mesh = gltf_node.mesh
            node.transform = build_transform_for_gltf_node(gltf, gltf_node)
			tinsert(model.scene.nodes, node)
		end
    end
end

-- --------------------------------------------------------------------------------------------------------
-- A new loader method using a new loader from here: https://github.com/leonardus/lua-gltf
function gltfloader:load( model, scene, pobj, meshname )

	-- Note: Meshname is important for idenifying a mesh you want to be able to modify
	if(pobj == nil) then 
		pobj = gameobject.create( nil, meshname )
		return pobj
	end 

	model.goname = gltfloader.gomeshname
	model.goscript = gltfloader.goscriptname

	-- Iterate model scene and build meshes
	--   By default the model is collapsed to a series of meshes, and transforms and names are lost.
	--   An option will be added if the hierarchy needs to be retained.
	for n, node in ipairs(scene.nodes) do
		self:makeNodeMeshes( model, pobj, node)
	end

	-- This will free cgltf's own memory (we dont need it now)
	-- model.data = nil

	return pobj
end

-- --------------------------------------------------------------------------------------------------------
-- This is a special version of load that allows the loading of a single mesh into a gameobject manager

function gltfloader:load_gltf( assetfilename, asset, disableaabb )

	-- Check for gltf - only support this at the moment. 
	local valid = string.match(assetfilename, ".+%."..asset.format)
	assert(valid)

	local basepath = assetfilename:match("(.*[\\/])")
	
	-- Parse using geomext 

	local options = ffi.new("cgltf_options[1]", {})
	local data = ffi.new("cgltf_data *[1]", {nil})
	local result = cgltf.cgltf_parse_file(options, assetfilename, data)
	if (result == cgltf.cgltf_result_success) then
	
		-- Handle autodestruction when data is made nil
		ffi.gc(data, function(d)
			if d[0] ~= nil then cgltf.cgltf_free(d[0]); d[0] = nil end
		end)
		print("[Info] gltf loaded: ", assetfilename)
	else 
		print("[Error] Unable to load gltf: ", assetfilename)
	end

	local model = {
		filename = assetfilename,
		basepath = basepath,
		data = data,
	}

	gltf_parse_buffers(model)
	gltf_parse_images(model)
	gltf_parse_materials(model)
	gltf_parse_meshes(model)
	gltf_parse_nodes(model)

	-- if(model.animations) then 
	-- 	ozzanim.loadgltf( "--file="..assetfilename )
	-- end
	
	if(asset.format == "gltf" or asset.format == "glb") then 
		asset.go = gameobject.create( nil, asset.name )

		self:load( model, asset.go, asset.name)

		-- local mesh, scene = gltf:load(assetfilename, asset.go, asset.name)
		-- go.set_position(vmath.vector3(0, -999999, 0), asset.go)
	end

	if(model.aabb and disableaabb == nil) then 
		-- model.aabb.id = geomextension.addboundingbox( vmath.vector3(aabbmin.x, aabbmin.y, aabbmin.z), vmath.vector3(aabbmax.x, aabbmax.y, aabbmax.z), asset.go )
	else 
		print("[Error] Model has no aabb: "..assetfilename)
	end
	
	local states 	  = {}
	-- TODO: DOdgy override for a material atm. Will change.
    local material    = meshes.material(asset.go, "lua/engine/cube_simple.glsl")
	local prims       = {}

	-- Collect meshes together for rendering
	gltfloader:run_nodes(model, function(model, thisnode)
		if(thisnode.mesh) then 
			if(thisnode.mesh.primitives) then 
				for i, prim in ipairs(thisnode.mesh.primitives) do 
					if(prims[prim.primname] == nil) then 
            			prims[prim.primname] = { 
							index_count = prim.mesh_buffers.count,
							node = thisnode, prim = prim, 
							mesh = prim.mesh_buffers 
						}
					end
				end 
			end
		end
	end)

	for k, prim in pairs(prims) do 
		-- local geom_mesh = geom:GetMesh(prim.prim.primmesh)
		local state_tbl = meshes.state(prim.node.goname, prim.mesh, material)
		local state = { pip = state_tbl.pip, bind = state_tbl.bind, count = prim.index_count }
		tinsert(states, state)
	end

	model.states_tbl = states

	return model
end

------------------------------------------------------------------------------------------------------------

function gltfloader:run_node( model, thisnode, node_func)

	if(thisnode.children) then 
		for k,v in pairs(thisnode.children) do 
			self:run_node( model,  v, node_func)
		end 
	end

	if(node_func and thisnode) then 
		node_func(  model, thisnode )
	end
end

------------------------------------------------------------------------------------------------------------

function gltfloader:run_nodes( model, node_func )

	for n, node in ipairs(model.nodes) do

		self:run_node( model, node, node_func)
	end 
end

------------------------------------------------------------------------------------------------------------

return gltfloader

------------------------------------------------------------------------------------------------------------
