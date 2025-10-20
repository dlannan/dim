
local stb           = require("stb")
local nk            = sg

local tinsert       = table.insert

-- --------------------------------------------------------------------------------------

table.unpack = unpack

-- --------------------------------------------------------------------------------------

local function get_nk_rgba(color)
    -- for k,v in pairs(color) do print(k,v, type(k)) end
    return ffi.new("struct nk_color", {color.r, color.g, color.b, color.a})
end

-- --------------------------------------------------------------------------------------

renderer = {
    ctx            = nil,
}

renderer.font = {
    ctx            = nil,
}

local atlas     = ffi.new("struct nk_font_atlas[1]")
local fonts     = {}

-- --------------------------------------------------------------------------------------

local master_img_width = ffi.new("int[1]", 0)
local master_img_height = ffi.new("int[1]", 0)   

local function font_loader( atlas, font_file, font_size, cfg)

    local newfont = nk.nk_font_atlas_add_from_file(atlas, font_file, font_size, cfg)
    local image = nk.nk_font_atlas_bake(atlas, master_img_width, master_img_height, nk.NK_FONT_ATLAS_RGBA32)
    return image, newfont
end

-- --------------------------------------------------------------------------------------

local function font_atlas_img( image )
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

    nk.nk_font_atlas_init_default(atlas)
    nk.nk_font_atlas_begin(atlas)
    
    image = nk.nk_font_atlas_bake(atlas, master_img_width, master_img_height, nk.NK_FONT_ATLAS_RGBA32)
    
    -- Reload previous fonts.
    for i, font in ipairs(fonts) do 
        print("reloading fonts...", font.path)
        image, fonts.font = font_loader(atlas, font.path, font.size, font.cfg)    
    end 

    local cfg = ffi.new("struct nk_font_config[1]", {nk.nk_font_config(font_size)})
    -- cfg[0].merge_mode = nk.nk_true
    -- cfg.coord_type = nk.NK_COORD_PIXEL

    print("new fonts...", font_path, font_size)
    -- This is the new font. 
    local new_font
    image, new_font = font_loader(atlas, font_path, font_size, cfg)
    local new_font_tbl = { tab_width = 4, font = new_font, path = font_path, size = font_size, cfg = cfg }
    tinsert(fonts, new_font_tbl)

    -- atlas[0].config.range = nk.nk_font_awesome_glyph_ranges()

    -- Dump the atlas to check it.
    stb.stbi_write_png( "data/fonts/atlas_font.png", master_img_width[0], master_img_height[0], 4, image, master_img_width[0] * 4)

    -- print(master_img_width[0], master_img_height[0], 4)
    local nk_img = font_atlas_img(image)
    nk.nk_font_atlas_end(atlas, nk_img, nil)
    nk.nk_font_atlas_cleanup(atlas)
   
    nk.nk_style_load_all_cursors(ctx, atlas[0].cursors)
    nk.nk_style_set_font(ctx, new_font.handle)
    return new_font_tbl
end

-- --------------------------------------------------------------------------------------

-- renderer.font.load          = function(path, size) end,
-- renderer.font.set_tab_width = function(font, width) end,
-- renderer.font.get_width     = function(font, text) return 0 end,
-- renderer.font.get_height    = function(font) return 0 end,
-- renderer.font.get_size      = function(font) return 0 end,
-- renderer.font.set_size      = function(font, size) end,
-- renderer.font.get_path      = function(font) return "" end,

-- renderer.font.__gc          = function(font) end,

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

renderer.show_debug     = function(...) end

renderer.get_size       = function() 
    local r = nk.nk_window_get_content_region(renderer.ctx)
    return r.w, r.h
end

-- Not really needed
renderer.begin_frame    = function()

end

-- Hrm.. needed?
renderer.end_frame      = function() 

end

renderer.set_clip_rect  = function(x, y, w, h) 
    local canvas = ffi.new("struct nk_command_buffer *", nk.nk_window_get_canvas(renderer.ctx))
    local rect = ffi.new("struct nk_rect", {x, y, w, h})
    nk.nk_push_scissor(canvas, rect)
end

renderer.draw_rect      = function(x, y, w, h, color) 
    local canvas = ffi.new("struct nk_command_buffer *", nk.nk_window_get_canvas(renderer.ctx))
    local rect = ffi.new("struct nk_rect", {x, y, w, h})
    local ncol = get_nk_rgba(color)
    nk.nk_fill_rect(canvas, rect, 5, ncol)
end

renderer.draw_text      = function(font, text, x, y, color) 
    local canvas = ffi.new("struct nk_command_buffer *", nk.nk_window_get_canvas(renderer.ctx))
    local hcolor = get_nk_rgba(color)
    local rect = ffi.new("struct nk_rect", {x, y, 1000, 100})
    local w = font:get_width(text)
    local font_handle = font:get_handle()
    local text = tostring(text)
    nk.nk_draw_text(canvas, rect, text, #text, font_handle, hcolor, hcolor)
    return w
end
  
