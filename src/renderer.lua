
local stb           = require("stb")
local nk            = sg

local utils         = require("lua.utils")
local rencache      = require("src.rencache")
-- require("src.nuklear")

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
    elseif t == "cdata" then 
        return ffi.string(val)
    else
        error("bad argument: string or number expected, got " .. t, 2)
    end
end
  
-- --------------------------------------------------------------------------------------

renderer = {
    ctx             = nil,
    all_fonts       = {},
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

local function adjust_glyph(font_handle, unicode, width) 
    
    local font = ffi.cast("struct nk_font *", font_handle.ptr)
    local g = font.glyphs[unicode]
    g.xadvance = width
end

local function get_glyph_xadvance(font_handle, unicode) 
    
    local font = ffi.cast("struct nk_font *", font_handle.ptr)
    local g = font.glyphs[unicode]
    return g.xadvance
end

-- local function fix_tab_glyph(font, tab_spaces)
--     local space_advance = font.glyphs[32].xadvance
--     local g = font.glyphs[9]
--     g.codepoint = 9
--     g.xadvance = space_advance * tab_spaces
--     g.w, g.h = 0, 0
--     g.x0, g.y0, g.x1, g.y1 = 0, 0, 0, 0
--     g.u0, g.v0, g.u1, g.v1 = 0, 0, 0, 0
-- end

-- --------------------------------------------------------------------------------------

local function find_glyph(font, codepoint)
    local glyph_ptr = font.glyphs
    while glyph_ptr ~= nil and glyph_ptr[0].codepoint ~= 0 do
        if tonumber(glyph_ptr[0].codepoint) == codepoint then
            return glyph_ptr
        end
        glyph_ptr = glyph_ptr + 1
    end
    return nil
end

-- --------------------------------------------------------------------------------------

local function fix_tab_glyph(glyph, space)

    glyph[0].xadvance = space * 4
    glyph[0].w, glyph[0].h = 0, 0
    glyph[0].x0, glyph[0].y0, glyph[0].x1, glyph[0].y1 = 0, 0, 0, 0
    glyph[0].u0, glyph[0].v0, glyph[0].u1, glyph[0].v1 = 0, 0, 0, 0
end

-- --------------------------------------------------------------------------------------

local rune_ranges = ffi.new("nk_rune[9]", {
    0x0009, 0x000A, -- tab
    0x0020, 0x00FF, -- basic Latin + Latin-1
    0x2500, 0x2BFF, -- box-drawing, arrows
    0xE000, 0xF8FF, -- private use / Nerd Font symbols
    0
})

-- --------------------------------------------------------------------------------------

local function font_loader( atlas, font_file, font_size)

    local config = nk.nk_font_config(font_size)
    -- Special case where the glyphs need to be default
    if(string.match(font_file, "icons.ttf$")) then 
        config.range = nk.nk_font_default_glyph_ranges()
    else 
        config.range = rune_ranges
    end
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
        
        local glyph = find_glyph(font.font, 9)
        local space = get_glyph_xadvance(font.font.handle.userdata, 32)    
        if(glyph) then fix_tab_glyph(glyph, space) end
        
        -- atlas[0].config.range = rune_ranges -- nk.nk_font_default_glyph_ranges()
    end 

    -- local cfg = ffi.new("struct nk_font_config[1]", {nk.nk_font_config(font_size)})
    -- cfg[0].merge_mode = nk.nk_true
    -- cfg.coord_type = nk.NK_COORD_PIXEL

    image, new_font = font_loader(atlas, font_path, font_size)
    image = nk.nk_font_atlas_bake(atlas, master_img_width, master_img_height, nk.NK_FONT_ATLAS_RGBA32)
    local glyph = find_glyph(new_font, 9)
    local space = get_glyph_xadvance(new_font.handle.userdata, 32)    
    if(glyph) then fix_tab_glyph(glyph, space) end


    local nk_img = font_atlas_img(image, true)
    nk.nk_font_atlas_end(atlas, nk_img, nil)
    nk.nk_font_atlas_cleanup(atlas)
   
    nk.nk_style_load_all_cursors(ctx, atlas[0].cursors)
    nk.nk_style_set_font(ctx, new_font.handle)

    local tab_size = get_glyph_xadvance(new_font.handle.userdata, 9)

    -- print(master_img_width[0], master_img_height[0], tab_size)
    local new_font_tbl = { tab_width = tab_size, font = new_font, path = font_path, size = font_size, cfg = nil }
    tinsert(fonts, new_font_tbl)

    return new_font_tbl
end

-- --------------------------------------------------------------------------------------

renderer.get_font = function( font_id )
    return renderer.all_fonts[font_id]
end

-- --------------------------------------------------------------------------------------

renderer.font.load = function(path, size)
    local new_font = load_font(path, size)
    if(new_font == nil) then return nil end
    new_font.set_tab_width = function(self, width) 
        if(width == self.tab_width) then return end
        adjust_glyph( self.font.handle.userdata, 9, width )
        self.tab_width = width
    end
    new_font.get_tab_width = function(self, width)
        return self.tab_width 
    end
    new_font.get_width = function(self, text) 
        local text = checkstring(text)
        return self.font.handle.width(self.font.handle.userdata, self.font.handle.height, text, #text)
    end
    new_font.get_height = function(self) return self.font.handle.height end
    new_font.get_size = function(self) return self.size end
    new_font.set_size = function(self, size) self.size = size end
    new_font.get_path = function(self) return self.path end
    new_font.get_handle = function(self) return self.font.handle end

    local font_id = #renderer.all_fonts+1
    new_font.get_id = function(self) return font_id end

    tinsert(renderer.all_fonts, new_font)
    return setmetatable(new_font, { __index = new_font })
end      

-- --------------------------------------------------------------------------------------

renderer.show_debug     = function(enable) 
    -- rencache.rencache_show_debug(enable)
end

-- --------------------------------------------------------------------------------------

renderer.get_size       = function() 
    return nuklear_renderer.get_size()
end

-- --------------------------------------------------------------------------------------
-- Not really needed
renderer.begin_frame    = function()
    -- rencache.rencache_begin_frame()
end

-- --------------------------------------------------------------------------------------
-- Hrm.. needed?
renderer.end_frame      = function() 
    -- rencache.rencache_end_frame()
end

-- --------------------------------------------------------------------------------------

renderer.set_clip_rect  = function(x, y, w, h) 
    nuklear_renderer.set_clip_rect(x, y, w, h)
    -- rencache.rencache_set_clip_rect(x, y, w, h)
end

-- --------------------------------------------------------------------------------------

renderer.draw_rect      = function(x, y, w, h, color) 
    nuklear_renderer.draw_rect(x, y, w, h, color)
    -- rencache.rencache_draw_rect(x, y, w, h, color)
end

-- --------------------------------------------------------------------------------------

renderer.draw_text      = function(font, text, x, y, color) 
    return nuklear_renderer.draw_text(font, text, x, y, color)
    -- return rencache.rencache_draw_text(font, text, x, y, color)
end
  
-- --------------------------------------------------------------------------------------

renderer.load_image      = function(filename, no_ui) 
    local img, img_info = nuklear_renderer.load_image(filename, no_ui) 
    return img, img_info
    -- return rencache.rencache_draw_text(font, text, x, y, color)
end
  
-- --------------------------------------------------------------------------------------

renderer.load_image_buffer = function(name, buf, bufsize, no_ui) 
    local img, img_info = nuklear_renderer.load_image_buffer(name, buf, bufsize, no_ui) 
    return img, img_info
    -- return rencache.rencache_draw_text(font, text, x, y, color)
end
  
-- --------------------------------------------------------------------------------------

renderer.draw_image      = function(image, x, y, w, h) 
    return nuklear_renderer.draw_image(image, x, y, w, h) 
    -- return rencache.rencache_draw_text(font, text, x, y, color)
end
  
-- --------------------------------------------------------------------------------------

renderer.load_model      = function(filename) 
    return threed_renderer.load_model(filename) 
    -- return rencache.rencache_draw_text(font, text, x, y, color)
end

-- --------------------------------------------------------------------------------------

renderer.draw_model      = function(model, x, y, w, h) 

    return threed_renderer.draw_model(model, x, y, w, h)
end 

-- --------------------------------------------------------------------------------------
