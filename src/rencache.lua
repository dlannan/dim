
local ffi   = require("ffi")

require("src.nuklear")

local tinsert       = table.insert
local tremove       = table.remove

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

ffi.cdef[[

enum { FREE_FONT, SET_CLIP, DRAW_TEXT, DRAW_RECT };

typedef struct RenImage RenImage;
typedef struct RenFont RenFont;

typedef struct { uint8_t b, g, r, a; } RenColor;
typedef struct { int x, y, width, height; } RenRect;

typedef struct Command {
    int type, size;
    RenRect rect;
    RenColor color;
    unsigned int font;
    int tab_width;
    char *text;
} Command;

]]

-- --------------------------------------------------------------------------------------

local CELLS_X       = 80
local CELLS_Y       = 50
local CELL_SIZE     = 96
-- local COMMAND_BUF_SIZE = (1024 * 512)

local cells_buf1 = ffi.new("unsigned int[?]", CELLS_X * CELLS_Y)
local cells_buf2 = ffi.new("unsigned int[?]", CELLS_X * CELLS_Y)
-- local cells_prev = ffi.new("unsigned int*", cells_buf1)
-- local cells = ffi.new("unsigned int*", cells_buf2)
local cells      = cells_buf2
local cells_prev = cells_buf1

local rect_buf  = {}
local command_buf = {}
local screen_rect = ffi.new("RenRect")
local show_debug = nil

-- --------------------------------------------------------------------------------------

local function min(a, b) if(a < b) then return a else return b end end
local function max(a, b) if(a > b) then return a else return b end end

-- --------------------------------------------------------------------------------------

local HASH_INITIAL = 2166136261
local HASH_PRIME  = 16777619

local function hash(h, data, size)
  local p = ffi.cast("const uint8_t*", data)

  for i = 0, size - 1 do
    h = bit.bxor(h, p[i])
    h = bit.tobit(h * HASH_PRIME)
  end

  return h
end

-- --------------------------------------------------------------------------------------

local function cell_idx(x, y) 
    return x + y * CELLS_X
end

local function rects_overlap( a, b ) 
    return b.x + b.width  >= a.x and b.x <= a.x + a.width
        and b.y + b.height >= a.y and b.y <= a.y + a.height
end

local function intersect_rects( a, b ) 
    local x1 = max(a.x, b.x)
    local y1 = max(a.y, b.y)
    local x2 = min(a.x + a.width, b.x + b.width)
    local y2 = min(a.y + a.height, b.y + b.height)
    return ffi.new("RenRect", { x1, y1, max(0, x2 - x1), max(0, y2 - y1) })
end

local function merge_rects( a, b ) 
    local x1 = min(a.x, b.x)
    local y1 = min(a.y, b.y)
    local x2 = max(a.x + a.width, b.x + b.width)
    local y2 = max(a.y + a.height, b.y + b.height)
    return ffi.new("RenRect", { x1, y1, x2 - x1, y2 - y1 } )
end

local function push_command(ctype, size) 
    local cmd = ffi.new("Command[1]")
    ffi.fill(cmd, 0, ffi.sizeof("Command"))
    cmd[0].type = ctype
    cmd[0].size = size
    tinsert(command_buf, cmd)
    return cmd
end

-- Just grab from the top
local key, val = nil, nil
local function next_command(start) 
    if(#command_buf == 0) then return nil end
    if(start) then key = nil end 
    key, val = next(command_buf, key)
    if key == nil then return nil end
    return val
end

local function pull_command() 
    return tremove(command_buf, 1)
end
  
local function rencache_show_debug(enable) 
    show_debug = enable
end
    
local function rencache_free_font(font) 
    local cmd = push_command(ffi.C.FREE_FONT, ffi.sizeof("Command"))
    if (cmd) then cmd[0].font = font end
end
  
  
local function rencache_set_clip_rect(x, y, w, h) 
    local rect = ffi.new("RenRect", { x, y, w, h })
    local cmd = push_command(ffi.C.SET_CLIP, ffi.sizeof("Command"))
    if (cmd) then cmd[0].rect = intersect_rects(rect, screen_rect) end
end

local function rencache_draw_rect(x, y, w, h, color) 
    local rect = ffi.new("RenRect", { x, y, w, h })
    if (rects_overlap(screen_rect, rect) == false) then return end
    local cmd = push_command(ffi.C.DRAW_RECT, ffi.sizeof("Command"))
    if (cmd) then
      cmd[0].rect = rect
      cmd[0].color = color
    end
end
  
local function rencache_draw_text(font, text, x, y, color) 
    text = checkstring(text)
    local rect = ffi.new("RenRect")
    rect.x = x
    rect.y = y
    rect.width = font:get_width(ffi.string(text))
    rect.height = font:get_height()

    if (rects_overlap(screen_rect, rect)== true) then
        
        local sz = #ffi.string(text) + 1
        local cmd = push_command(ffi.C.DRAW_TEXT, ffi.sizeof("Command") + sz)
        if (cmd) then
            cmd[0].text = ffi.new("char[?]", sz)
            ffi.copy(cmd[0].text, text, sz)
            cmd[0].color = color
            cmd[0].font = font:get_id()
            cmd[0].rect = rect
            cmd[0].tab_width = font:get_tab_width()
        end
    end

    return x + rect.width
end

local function rencache_invalidate() 
    ffi.fill(cells_prev, 0xff, ffi.sizeof("unsigned int") * CELLS_X * CELLS_Y)
end
  
  
local function rencache_begin_frame() 
    -- /* reset all cells if the screen width/height has changed */
    local w, h = nuklear_renderer.get_size()
    w, h = math.floor(w), math.floor(h)
    if (screen_rect.width ~= w or h ~= screen_rect.height) then
        screen_rect.width = w
        screen_rect.height = h
        rencache_invalidate()
    end
end
  

local function update_overlapping_cells(r, h) 
    local x1 = r.x / CELL_SIZE
    local y1 = r.y / CELL_SIZE
    local x2 = (r.x + r.width) / CELL_SIZE
    local y2 = (r.y + r.height) / CELL_SIZE

    local h_ptr = ffi.new("unsigned int[1]", {h})

    for y = y1, y2 do
        for x = x1, x2 do
            local idx = cell_idx(x, y)
            local addr_cells = tonumber(ffi.cast("uintptr_t", cells + idx))
            cells[idx] = hash(addr_cells, h_ptr, ffi.sizeof("unsigned int"))
        end
    end
end
  
  
local function push_rect( r, count) 
    -- /* try to merge with existing rectangle */
    for  i = count - 1, 0, -1 do
        local rp = rect_buf[i]
        if (rects_overlap(rp, r) == true) then
            rect_buf[i] = merge_rects(rp, r)
            return count
        end
    end
    -- /* couldn't merge with previous rectangle: push */
    rect_buf[count] = r
    count = count + 1
    return count
end
  
  
local function rencache_end_frame() 

    -- /* update cells from commands */
    local cr = screen_rect
    local cmd = next_command(true)
    while cmd  do
        if cmd[0].type == ffi.C.SET_CLIP then
            cr = cmd[0].rect
        end
        local r = intersect_rects(cmd[0].rect, cr)
        if r.width ~= 0 and r.height ~= 0 then
            local h = HASH_INITIAL
            h = hash(h, cmd, cmd[0].size)
            update_overlapping_cells(r, h)
        end
        cmd = next_command()
    end
  
    -- /* push rects for all cells changed from last frame, reset cells */
    local rect_count = 0
    local max_x = screen_rect.width / CELL_SIZE + 1
    local max_y = screen_rect.height / CELL_SIZE + 1
    local rect = ffi.new("RenRect", { 0, 0, 1, 1 })
    for y = 0, max_y-1 do
        for x = 0, max_x-1 do
            -- /* compare previous and current cell for change */
            local idx = cell_idx(x, y)
            if (cells[idx] ~= cells_prev[idx]) then
                rect.x, rect.y = x, y
                rect_count = push_rect(rect, rect_count)
            end
            cells_prev[idx] = HASH_INITIAL
        end
    end

    -- /* expand rects from cells to pixels */
    for i = 0, rect_count-1 do
        local r = rect_buf[i]
        r.x = r.x * CELL_SIZE
        r.y = r.y * CELL_SIZE
        r.width = r.width * CELL_SIZE
        r.height = r.height * CELL_SIZE
        r = intersect_rects(r, screen_rect)
    end
  
    -- /* redraw updated regions */
    for i = 0, rect_count-1 do
        -- /* draw */
        local r = rect_buf[i]
        nuklear_renderer.set_clip_rect(r.x, r.y, r.width, r.height)

        local cmd = pull_command()
        while (cmd) do
            if(cmd[0].type == ffi.C.FREE_FONT) then 
                has_free_commands = true
            elseif(cmd[0].type == ffi.C.SET_CLIP) then 
                local r = intersect_rects(cmd[0].rect, r)
                nuklear_renderer.set_clip_rect(r.x, r.y, r.width, r.height)
            elseif(cmd[0].type == ffi.C.DRAW_RECT) then 
                local r = cmd[0].rect
                nuklear_renderer.draw_rect(r.x, r.y, r.width, r.height, cmd[0].color)
            elseif(cmd[0].type == ffi.C.DRAW_TEXT) then
                local font = renderer.get_font(cmd[0].font)
                font:set_tab_width(cmd[0].tab_width)
                nuklear_renderer.draw_text(font, cmd[0].text, cmd[0].rect.x, cmd[0].rect.y, cmd[0].color)
            end
            cmd = pull_command()
        end
    
        -- if (show_debug) then
        --     local color = ffi.new("RenColor", { math.random(), math.random(), math.random(), 50 })
        --     nuklear_renderer.draw_rect(r.x, r.y, r.width, r.height, color)
        -- end
    end
  
    -- /* update dirty rects */
    if (rect_count > 0) then
        --   ren_update_rects(rect_buf, rect_count)
    end

    -- command_buf = {}
    -- rect_buf = {}

    -- /* free fonts */
    -- if (has_free_commands) then
    --     local cmd = next_command()
    --     while (cmd) do
    --         if (cmd[0].type == ffi.C.FREE_FONT) then
    --             ren_free_font(cmd[0].font)
    --         end
    --         cmd = next_command()
    --     end
    -- end
  
    -- /* swap cell buffer and reset */
    cells, cells_prev = cells_prev, cells
end

return {
    rencache_show_debug         = rencache_show_debug,
    rencache_free_font          = rencache_free_font,
    rencache_set_clip_rect      = rencache_set_clip_rect,
    rencache_draw_rect          = rencache_draw_rect,
    rencache_draw_text          = rencache_draw_text,
    rencache_invalidate         = rencache_invalidate,
    rencache_begin_frame        = rencache_begin_frame,
    rencache_end_frame          = rencache_end_frame,
} 