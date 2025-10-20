
local stb           = require("stb")
local nk            = sg

local utils         = require("lua.utils")

local ffi           = require("ffi")

local tinsert       = table.insert

-- --------------------------------------------------------------------------------------

table.unpack = unpack

-- --------------------------------------------------------------------------------------

local function checkstring(val)
    local t = type(val)
    if t == "string" then
        return val
    elseif t == "number" then
        return tostring(val)
    else
        error("bad argument: string or number expected, got " .. t, 2)
    end
end
  

-- --------------------------------------------------------------------------------------

renderer = {
    ctx             = nil,
    offx            = 0,
    offy            = 0,
}

renderer.font = {
    ctx             = nil,
}

-- --------------------------------------------------------------------------------------

local atlas     = ffi.new("struct nk_font_atlas[1]")
local fonts     = {}

-- --------------------------------------------------------------------------------------

local master_img_width = ffi.new("int[1]", 2048)
local master_img_height = ffi.new("int[1]", 2048)   

-- --------------------------------------------------------------------------------------

local function font_loader( atlas, font_file, font_size)

    local config = nk.nk_font_config(font_size)
    -- config.merge_mode = nk.nk_false
    local newfont = nk.nk_font_atlas_add_from_file(atlas, font_file, font_size, config)
    -- local image = nk.nk_font_atlas_bake(atlas, master_img_width, master_img_height, nk.NK_FONT_ATLAS_RGBA32)
    return nil, newfont
end

-- --------------------------------------------------------------------------------------

local function font_atlas_img( image, debug )
    local sg_img_desc = ffi.new("sg_image_desc[1]")
    sg_img_desc[0].width = master_img_width[0]
    sg_img_desc[0].height = master_img_height[0]
    sg_img_desc[0].pixel_format = sg.SG_PIXELFORMAT_RGBA8
    sg_img_desc[0].sample_count = 1
    
    sg_img_desc[0].data.subimage[0][0].ptr = image
    sg_img_desc[0].data.subimage[0][0].size = master_img_width[0] * master_img_height[0] * 4
    local new_img = sg.sg_make_image(sg_img_desc)

    -- // create a sokol-nuklear image object which associates an sg_image with an sg_sampler
    local img_desc = ffi.new("snk_image_desc_t[1]")
    img_desc[0].image = new_img

    local snk_img = nk.snk_make_image(img_desc)
    local nk_hnd = nk.snk_nkhandle(snk_img)

    if(debug) then 
        -- Dump the atlas to check it.
        stb.stbi_write_png( "data/fonts/atlas_font.png", master_img_width[0], master_img_height[0], 4, image, master_img_width[0] * 4)
    end

    return nk_hnd
end

-- --------------------------------------------------------------------------------------
-- Load font into a font pool - need to regen font atlas for this
local function load_font(font_path, font_size)

    if(font_size == 0.0) then font_size = 16.0 end
    local ctx = renderer.ctx
    if(ctx == nil) then return nil end
    -- Reset image 
    local image = nil
    local new_font = nil

    nk.nk_font_atlas_init_default(atlas)
    nk.nk_font_atlas_begin(atlas)
    
    -- image = nk.nk_font_atlas_bake(atlas, master_img_width, master_img_height, nk.NK_FONT_ATLAS_RGBA32)
    
    -- Reload previous fonts.
    for i, font in ipairs(fonts) do 
        image, fonts.font = font_loader(atlas, font.path, font.size)    
        atlas[0].config.range = nk.nk_font_default_glyph_ranges()
    end 

    -- local cfg = ffi.new("struct nk_font_config[1]", {nk.nk_font_config(font_size)})
    -- cfg[0].merge_mode = nk.nk_true
    -- cfg.coord_type = nk.NK_COORD_PIXEL

    image, new_font = font_loader(atlas, font_path, font_size)
    local new_font_tbl = { tab_width = 4, font = new_font, path = font_path, size = font_size, cfg = nil }
    tinsert(fonts, new_font_tbl)

    image = nk.nk_font_atlas_bake(atlas, master_img_width, master_img_height, nk.NK_FONT_ATLAS_RGBA32)

    print(master_img_width[0], master_img_height[0], 4)
    local nk_img = font_atlas_img(image, true)
    nk.nk_font_atlas_end(atlas, nk_img, nil)
    nk.nk_font_atlas_cleanup(atlas)
   
    nk.nk_style_load_all_cursors(ctx, atlas[0].cursors)
    nk.nk_style_set_font(ctx, new_font.handle)
    return new_font_tbl
end

-- --------------------------------------------------------------------------------------

renderer.font.load = function(path, size)
    local new_font = load_font(path, size)
    if(new_font == nil) then return nil end
    new_font.set_tab_width = function(self, width) return self.tab_width end
    new_font.get_width = function(self, text) 
        local text = tostring(text)
        return self.font.handle.width(self.font.handle.userdata, self.font.handle.height, text, #text)
    end
    new_font.get_height = function(self) return self.font.handle.height end
    new_font.get_size = function(self) return self.size end
    new_font.set_size = function(self, size) self.size = size end
    new_font.get_path = function(self) return self.path end
    new_font.get_handle = function(self) return self.font.handle end
    return setmetatable(new_font, { __index = new_font })
end      

-- --------------------------------------------------------------------------------------

renderer.show_debug     = function(...) 

end

-- --------------------------------------------------------------------------------------

renderer.get_size       = function() 
    local r = nk.nk_window_get_content_region(renderer.ctx)
    return r.w, r.h
end

-- --------------------------------------------------------------------------------------
-- Not really needed
renderer.begin_frame    = function()

end

-- --------------------------------------------------------------------------------------
-- Hrm.. needed?
renderer.end_frame      = function() 

end

-- --------------------------------------------------------------------------------------

renderer.set_clip_rect  = function(x, y, w, h) 
    local canvas = nk.nk_window_get_canvas(renderer.ctx)
    local r = nk.nk_window_get_content_region(renderer.ctx)
    local rect = nk.nk_rect(x + r.x, y + r.y, w, h)
    nk.nk_push_scissor(canvas, rect)
end

-- --------------------------------------------------------------------------------------

renderer.draw_rect      = function(x, y, w, h, color) 
    local canvas = nk.nk_window_get_canvas(renderer.ctx)
    local r = nk.nk_window_get_content_region(renderer.ctx)
    local ncol = nk.nk_rgba(color[1], color[2], color[3], color[4])
    -- print(x, y, w, h)
    -- nk.nk_layout_space_begin(renderer.ctx, nk.NK_STATIC, r.w, 1)
    -- nk.nk_layout_space_push(renderer.ctx, r)
    nk.nk_fill_rect(canvas, nk.nk_rect(x + r.x, y + r.y, w, h), 0, ncol)
    -- nk.nk_layout_space_end(renderer.ctx)
end

-- --------------------------------------------------------------------------------------

renderer.draw_text      = function(font, text, x, y, color) 
    local canvas = nk.nk_window_get_canvas(renderer.ctx)
    local hcolor = nk.nk_rgba(color[1], color[2], color[3], color[4])
    local r = nk.nk_window_get_content_region(renderer.ctx)
    local rect = nk.nk_rect(x + r.x, y + r.y, 1000, 100)
    local w = font:get_width(text)
    local font_handle = font.font.handle
    local text = checkstring(text)
    -- nk.nk_layout_space_begin(renderer.ctx, nk.NK_STATIC, r.w, 1)
    -- nk.nk_layout_space_push(renderer.ctx, r)
    nk.nk_draw_text(canvas, rect, text, #text, font_handle, hcolor, hcolor)
    -- nk.nk_layout_space_end(renderer.ctx)
    return w
end
  
-- --------------------------------------------------------------------------------------