-------------------------------------------------------------------------------------------------
local utils = require("lua.utils")

local imageutils = {
	ctr = 0
}

-------------------------------------------------------------------------------------------------

function loadimage(goname, imagefilepath, tid )

	if(imagefilepath == nil) then 
		print("[Image Load Error] imagefilepath is nil.") 
		return nil
	end

	imagefilepath = utils.cleanstring( imagefilepath )
	
	local data = utils.loaddata( imagefilepath )
	if(data == nil) then 
		print("[Image Load Error] Cannot load imagefilepath data: "..imagefilepath) 
		return nil
	end
		
	--print(gltfobj.basepath..v.uri)
	local res, err = image.load(data)
	if(err) then 
		print("[Image Load Error] Cannot load image: "..v.uri.." #:"..err) 
		return nil
	end 

	-- TODO: This goes into image loader
	if(res.buffer ~= "") then
		rgbcount = 3
		if(res.type == "rgba") then res.format = resource.TEXTURE_FORMAT_RGBA; rgbcount = 4 end
		if(res.type == "rgb") then res.format = resource.TEXTURE_FORMAT_RGB; rgbcount = 3 end

		local buff = buffer.create(res.width * res.height, { 
			{	name=hash(res.type), type=buffer.VALUE_TYPE_UINT8, count=rgbcount } 
		})

		geomextension.setbufferbytes( buff, res.type, res.buffer )

		res.type=resource.TEXTURE_TYPE_2D	
		res.num_mip_maps=1

		-- create a cloned buffer resource from another resource buffer
		local new_path = "/imgbuffer_"..string.format("%d", imageutils.ctr)..".texturec"
		local newres = resource.create_texture(new_path, res)	
		imageutils.ctr = imageutils.ctr + 1
				
		-- Store the resource path so it can be used later 
		res.resource_path = hash(new_path)
		res.image_buffer = buff 

		resource.set_texture( new_path, res, buff )
		local tname = "texture"..tid
		go.set(goname, tname, hash(new_path))
		msg.post( goname, hash("mesh_texture") )
	end

	return res
end 

-------------------------------------------------------------------------------------------------

function bufferimage(goname, stringbuffer, binfo, tid )

	-- Default to rgb and albedo
	tid = tid or 0
	local restype = "rgba"
	if(binfo.type == 2) then restype = "rgb"
	elseif(binfo.type == 3) then restype = "grayscale" end
	assert(stringbuffer)
	
	local res = { buffer = stringbuffer, type = restype, width = binfo.width, height = binfo.height }

	-- TODO: This goes into image loader
	if(res.buffer ~= "") then
		local rgbcount = 3
		if(res.type == "rgba") then res.format = resource.TEXTURE_FORMAT_RGBA; rgbcount = 4 end
		if(res.type == "rgb") then res.format = resource.TEXTURE_FORMAT_RGB; rgbcount = 3 end
		if(res.type == "grayscale") then res.format = resource.TEXTURE_FORMAT_LUMINANCE; rgbcount = 1 end

		local buff = buffer.create(res.width * res.height, { 
			{	name=hash(res.type), type=buffer.VALUE_TYPE_UINT8, count=rgbcount } 
		})
		local stm = buffer.get_stream(buff, hash(res.type))
		-- for idx = 1, v.res.width * v.res.height * rgbcount do 
		-- 	stm[idx] = string.byte(v.res.buffer, idx )
		-- end
		geomextension.setbufferbytes( buff, res.type, res.buffer )

		res.type=resource.TEXTURE_TYPE_2D	
		res.num_mip_maps=1

		-- create a cloned buffer resource from another resource buffer
		local new_path = "/imgbuffer_"..string.format("%d", imageutils.ctr)..".texturec"
		local newres = resource.create_texture(new_path, res)	
		imageutils.ctr = imageutils.ctr + 1
		
		-- Store the resource path so it can be used later 
		res.resource_path = hash(new_path)	
		res.image_buffer = buff 

		resource.set_texture( resource_path, res, buff )
		go.set(goname, "texture"..tid, hash(new_path))

		msg.post( goname, hash("mesh_texture") )
	end

	return res
end 

-------------------------------------------------------------------------------------------------

function defoldbufferimage(goname, buff, binfo, tid )
	
	-- Default to rgb and albedo
	tid = tid or 0
	local restype = "rgba"
	if(binfo.type == 2) then restype = "rgb"
	elseif(binfo.type == 3) then restype = "grayscale" end
	
	local res = {type = restype, width = binfo.width, height = binfo.height }

	-- TODO: This goes into image loader
	if(res.buffer ~= "") then
		local rgbcount = 3
		if(res.type == "rgba") then res.format = resource.TEXTURE_FORMAT_RGBA; rgbcount = 4 end
		if(res.type == "rgb") then res.format = resource.TEXTURE_FORMAT_RGB; rgbcount = 3 end
		if(res.type == "grayscale") then res.format = resource.TEXTURE_FORMAT_LUMINANCE; rgbcount = 1 end


		res.type=resource.TEXTURE_TYPE_2D	
		res.num_mip_maps=1

		-- create a cloned buffer resource from another resource buffer
		local new_path = "/imgbuffer_"..string.format("%d", imageutils.ctr)..".texturec"
		local newres = resource.create_texture(new_path, res)	
		imageutils.ctr = imageutils.ctr + 1

		-- Store the resource path so it can be used later 
		res.resource_path = hash(new_path)	
		res.image_buffer = buff 

		resource.set_texture( hash(new_path), res, buff )
		go.set(goname, "texture"..tid, hash(new_path))

		msg.post( goname, hash("mesh_texture") )
	end

	return res
end 

-------------------------------------------------------------------------------------------------

imageutils.loadimage 	= loadimage
imageutils.bufferimage 	= bufferimage
imageutils.defoldbufferimage 	= defoldbufferimage

-------------------------------------------------------------------------------------------------

return imageutils

-------------------------------------------------------------------------------------------------