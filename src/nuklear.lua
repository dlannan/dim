
local stb           = require("stb")
local nk            = sg
local ffi           = require("ffi")

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

nuklear_renderer = {}

-- --------------------------------------------------------------------------------------

nuklear_renderer.get_size       = function() 
    local r = nk.nk_window_get_content_region(renderer.ctx)
    -- print("get_size", r.w, r.h)
    return r.w, r.h
end

-- --------------------------------------------------------------------------------------

nuklear_renderer.set_clip_rect  = function(x, y, w, h) 
    local canvas = nk.nk_window_get_canvas(renderer.ctx)
    local r = nk.nk_window_get_content_region(renderer.ctx)
    local rect = nk.nk_rect(x + r.x, y + r.y, w, h)
    -- print("set_clip_rect", rect.x, rect.y, rect.w, rect.h)
    nk.nk_push_scissor(canvas, rect)
end

-- --------------------------------------------------------------------------------------

nuklear_renderer.draw_rect      = function(x, y, w, h, color) 
    local canvas = nk.nk_window_get_canvas(renderer.ctx)
    local r = nk.nk_window_get_content_region(renderer.ctx)
    -- local ncol = nk.nk_rgba(color.r, color.g, color.b, color.a)
    local ncol = nk.nk_rgba(color[1], color[2], color[3], color[4])
    -- print("draw_rect", x, y, w, h)
    -- nk.nk_layout_space_begin(renderer.ctx, nk.NK_STATIC, r.w, 1)
    -- nk.nk_layout_space_push(renderer.ctx, r)
    nk.nk_fill_rect(canvas, nk.nk_rect( x+r.x, y+r.y, w, h), 0, ncol)
    -- nk.nk_layout_space_end(renderer.ctx)
end

-- --------------------------------------------------------------------------------------

nuklear_renderer.draw_text      = function(font, text, x, y, color) 
    local canvas = nk.nk_window_get_canvas(renderer.ctx)
    -- local hcolor = nk.nk_rgba(color.r, color.g, color.b, color.a)
    local hcolor = nk.nk_rgba(color[1], color[2], color[3], color[4])
    local r = nk.nk_window_get_content_region(renderer.ctx)
    local w = font:get_width(text)
    local h = font:get_height()
    local rect = nk.nk_rect(x+r.x, y+r.y, w, h)
    local font_handle = font.font.handle
    local text = checkstring(text)
    -- print("draw_text", x, y, text)
    -- nk.nk_layout_space_begin(renderer.ctx, nk.NK_STATIC, r.w, 1)
    -- nk.nk_layout_space_push(renderer.ctx, r)
    font:set_tab_width( font.tab_width )
    nk.nk_draw_text(canvas, rect, text, #text, font_handle, hcolor, hcolor)
    -- nk.nk_layout_space_end(renderer.ctx)
    return w + x, h
end
  
-- --------------------------------------------------------------------------------------