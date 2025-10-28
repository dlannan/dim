-------------------------------------------------------------------------------------------------

local utils = require("lua.utils")

local imageutils = {
	ctr 		= 0,
	images		= 	{}
}

-------------------------------------------------------------------------------------------------

function loadimage(goname, imagefilepath, tid )

	if(imagefilepath == nil) then 
		print("[Image Load Error] imagefilepath is nil.") 
		return nil
	end

	imagefilepath = utils.cleanstring( imagefilepath )
	local img, info, data = renderer.load_image(imagefilepath, true)	
	if(info == nil) then 
		print("[Image Load Error] Cannot load image: "..imagefilepath) 
		return nil
	end 

	local res = {
		id 		= tid,
		img 	= img, 
		info 	= info,
		data 	= data,
	}
	imageutils.images[tid] = res

	return res
end 

-------------------------------------------------------------------------------------------------

function loadimagebuffer(goname, buf, bufsize, tid )

	if(buf == nil) then 
		print("[Image Load Error] imagebuffer is nil.") 
		return nil
	end

	local img, info, data = renderer.load_image_buffer(goname, buf, bufsize, true)	
	if(info == nil) then 
		print("[Image Load Error] Cannot load image buffer: "..goname) 
		return nil
	end 

	local res = {
		id 		= tid,
		img 	= img, 
		info 	= info,
		data 	= data,
	}
	imageutils.images[tid] = res

	return res
end 

-------------------------------------------------------------------------------------------------

imageutils.loadimage 	= loadimage
imageutils.loadimagebuffer = loadimagebuffer
imageutils.bufferimage 	= bufferimage
imageutils.defoldbufferimage 	= defoldbufferimage

-------------------------------------------------------------------------------------------------

return imageutils

-------------------------------------------------------------------------------------------------