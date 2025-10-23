------------------------------------------------------------------------------------------------------------

local tinsert = table.insert

------------------------------------------------------------------------------------------------------------

local ffi 			= require("ffi")

local gameobject	= require("engine.states.gameobjects.gameobject")

local geom 			= require("libs.gltfloader.geometry-utils")
local imageutils 	= require("libs.gltfloader.image-utils")

local b64 			= require("utils.base64")
local utils			= require("utils.utils")
local gltf      	= require("libs.gltfloader.gltf")
local hmm      		= require("hmm")

------------------------------------------------------------------------------------------------------------

local gltfloader = {
	gomeshname 		= "temp",
	goscriptname 	= "script",
	curr_factory 	= nil,
	temp_meshes 	= {},
}

------------------------------------------------------------------------------------------------------------

function gltfloader:setpool( meshpoolpath, nummeshes )

	-- Make a list of valid meshes
	for i=1, nummeshes do 
		local mpath = meshpoolpath..string.format("%03d", i)..".mesh"
		tinsert(gltfloader.temp_meshes, { path=mpath, used=false, go=nil } )
	end
end 

------------------------------------------------------------------------------------------------------------
-- Get a free temp mesh, nil if none available
function gltfloader:getfreetemp()
	for k,v in pairs(gltfloader.temp_meshes) do 
		if(v.used == false) then 
			v.used = true 
			return v 
		end 
	end 
	return nil
end

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
	gltfobj.aabb = gltfobj.aabb or { min = hmm.HMM_Vec3(0,0,0), max = hmm.HMM_Vec3(0,0,0) }
	if( aabbmin[1] < gltfobj.aabb.min.x ) then gltfobj.aabb.min.x = aabbmin[1] end
	if( aabbmin[2] < gltfobj.aabb.min.y ) then gltfobj.aabb.min.y = aabbmin[2] end
	if( aabbmin[3] < gltfobj.aabb.min.z ) then gltfobj.aabb.min.z = aabbmin[3] end
	if( aabbmax[1] > gltfobj.aabb.max.x ) then gltfobj.aabb.max.x = aabbmax[1] end
	if( aabbmax[2] > gltfobj.aabb.max.y ) then gltfobj.aabb.max.y = aabbmax[2] end
	if( aabbmax[3] > gltfobj.aabb.max.z ) then gltfobj.aabb.max.z = aabbmax[3] end
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
		
		if(acc_idx) then 
			local bv = acc_idx.bufferView
			local index_buffer_data = bv:get()

			-- Indices specific - this is default dataset for gltf (I think)
			if(acc_idx.componentType == 5125) then 
				indices = ffi.new("uint32_t[?]", acc_idx.count)
				ffi.copy(indices, ffi.string(index_buffer_data), acc_idx.count * 4)
				-- geomextension.setdataintstotable( 0, , index_buffer_data, indices)
			elseif(acc_idx.componentType == 5123 or acc_idx.componentType == 5122) then 
				indices = ffi.new("uint16_t[?]", acc_idx.count)
				ffi.copy(indices, ffi.string(index_buffer_data), acc_idx.count * 2)
				-- geomextension.setdatashortstotable( 0, acc_idx.count * 2, index_buffer_data, indices)
			elseif(acc_idx.componentType == 5120 or acc_idx.componentType == 5121) then 
				indices = ffi.new("uint8_t[?]", acc_idx.count)
				ffi.copy(indices, ffi.string(index_buffer_data), acc_idx.count)
				-- geomextension.setdatabytestotable( 0, acc_idx.count, index_buffer_data, indices)
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
			geom:makeMesh( primmesh, indices, verts, uvs, normals, aabb )
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
			local pnginfo = utils.getpngheader(stringbuffer)
			-- local bytes, w, h = png.decode_rgba(stringbuffer, false)
			pnginfo.type = "rgba"

			-- imageutils.defoldbufferimage(primmesh.mesh, bytes, pnginfo, tid )		
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
	
	return pobj
end

-- --------------------------------------------------------------------------------------------------------
-- This is a special version of load that allows the loading of a single mesh into a gameobject manager

function gltfloader:load_gltf( assetfilename, asset, disableaabb )

	-- Check for gltf - only support this at the moment. 
	print(assetfilename)
	local valid = string.match(assetfilename, ".+%."..asset.format)
	assert(valid)

	local basepath = assetfilename:match("(.*/)")
	
	-- Parse using geomext 
	local model = gltf.new( assetfilename )
	model.basepath = basepath

	if(model.animations) then 
		ozzanim.loadgltf( "--file="..assetfilename )
	end
	
	if(asset.format == "gltf" or asset.format == "glb") then 
		asset.go = gameobject.create( nil, asset.name )

		self:load( model, model.scenes[1], asset.go, asset.name)

		--		local mesh, scene = gltf:load(assetfilename, asset.go, asset.name)
		-- go.set_position(vmath.vector3(0, -999999, 0), asset.go)
	end

	if(model.aabb and disableaabb == nil) then 
		-- model.aabb.id = geomextension.addboundingbox( vmath.vector3(aabbmin.x, aabbmin.y, aabbmin.z), vmath.vector3(aabbmax.x, aabbmax.y, aabbmax.z), asset.go )
	else 
		print("[Error] Model has no aabb: "..assetfilename)
	end
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
