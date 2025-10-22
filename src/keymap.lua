local sapp      = require("sokol_app")
local nk    = sg

-- Create a key mapping table from Sokol keycodes to human-readable key names
local key_map = {

    [sapp.SAPP_KEYCODE_INVALID]          = "\0",
    [sapp.SAPP_KEYCODE_SPACE]            = " ",
    [sapp.SAPP_KEYCODE_APOSTROPHE]       = "'",  
    [sapp.SAPP_KEYCODE_COMMA]            = ",",  
    [sapp.SAPP_KEYCODE_MINUS]            = "-",  
    [sapp.SAPP_KEYCODE_PERIOD]           = ".", 
    [sapp.SAPP_KEYCODE_SLASH]            = "/",  
    [sapp.SAPP_KEYCODE_0]                = "0",
    [sapp.SAPP_KEYCODE_1]                = "1",
    [sapp.SAPP_KEYCODE_2]                = "2",
    [sapp.SAPP_KEYCODE_3]                = "3",
    [sapp.SAPP_KEYCODE_4]                = "4",
    [sapp.SAPP_KEYCODE_5]                = "5",
    [sapp.SAPP_KEYCODE_6]                = "6",
    [sapp.SAPP_KEYCODE_7]                = "7",
    [sapp.SAPP_KEYCODE_8]                = "8",
    [sapp.SAPP_KEYCODE_9]                = "9",
    [sapp.SAPP_KEYCODE_SEMICOLON]        = ";",  
    [sapp.SAPP_KEYCODE_EQUAL]            = "=",  
    [sapp.SAPP_KEYCODE_A]                = "a",
    [sapp.SAPP_KEYCODE_B]                = "b",
    [sapp.SAPP_KEYCODE_C]                = "c",
    [sapp.SAPP_KEYCODE_D]                = "d",
    [sapp.SAPP_KEYCODE_E]                = "e",
    [sapp.SAPP_KEYCODE_F]                = "f",
    [sapp.SAPP_KEYCODE_G]                = "g",
    [sapp.SAPP_KEYCODE_H]                = "h",
    [sapp.SAPP_KEYCODE_I]                = "i",
    [sapp.SAPP_KEYCODE_J]                = "j",
    [sapp.SAPP_KEYCODE_K]                = "k",
    [sapp.SAPP_KEYCODE_L]                = "l",
    [sapp.SAPP_KEYCODE_M]                = "m",
    [sapp.SAPP_KEYCODE_N]                = "n",
    [sapp.SAPP_KEYCODE_O]                = "o",
    [sapp.SAPP_KEYCODE_P]                = "p",
    [sapp.SAPP_KEYCODE_Q]                = "q",
    [sapp.SAPP_KEYCODE_R]                = "r",
    [sapp.SAPP_KEYCODE_S]                = "s",
    [sapp.SAPP_KEYCODE_T]                = "t",
    [sapp.SAPP_KEYCODE_U]                = "u",
    [sapp.SAPP_KEYCODE_V]                = "v",
    [sapp.SAPP_KEYCODE_W]                = "w",
    [sapp.SAPP_KEYCODE_X]                = "x",
    [sapp.SAPP_KEYCODE_Y]                = "y",
    [sapp.SAPP_KEYCODE_Z]                = "z",
    [sapp.SAPP_KEYCODE_ENTER]            = "return",
    [sapp.SAPP_KEYCODE_SPACE]            = "space",
    [sapp.SAPP_KEYCODE_TAB]              = "tab",
    [sapp.SAPP_KEYCODE_BACKSPACE]        = "backspace",
    [sapp.SAPP_KEYCODE_ESCAPE]           = "escape",
    [sapp.SAPP_KEYCODE_F1]               = "f1",
    [sapp.SAPP_KEYCODE_F2]               = "f2",
    [sapp.SAPP_KEYCODE_F3]               = "f3",
    [sapp.SAPP_KEYCODE_F4]               = "f4",
    [sapp.SAPP_KEYCODE_F5]               = "f5",
    [sapp.SAPP_KEYCODE_F6]               = "f6",
    [sapp.SAPP_KEYCODE_F7]               = "f7",
    [sapp.SAPP_KEYCODE_F8]               = "f8",
    [sapp.SAPP_KEYCODE_F9]               = "f9",
    [sapp.SAPP_KEYCODE_F10]              = "f10",
    [sapp.SAPP_KEYCODE_F11]              = "f11",
    [sapp.SAPP_KEYCODE_F12]              = "f12",
    [sapp.SAPP_KEYCODE_UP]               = "up",
    [sapp.SAPP_KEYCODE_DOWN]             = "down",
    [sapp.SAPP_KEYCODE_LEFT]             = "left",
    [sapp.SAPP_KEYCODE_RIGHT]            = "right",
    [sapp.SAPP_KEYCODE_LEFT_BRACKET]     = "(",
    [sapp.SAPP_KEYCODE_RIGHT_BRACKET]    = ")",
    [sapp.SAPP_KEYCODE_BACKSLASH]        = "\\",
    [sapp.SAPP_KEYCODE_GRAVE_ACCENT]     = "~",
    [sapp.SAPP_KEYCODE_INSERT]           = "insert",
    [sapp.SAPP_KEYCODE_DELETE]           = "delete",
    [sapp.SAPP_KEYCODE_PAGE_UP]          = "pageup",
    [sapp.SAPP_KEYCODE_PAGE_DOWN]        = "pagedown",
    [sapp.SAPP_KEYCODE_HOME]             = "home",
    [sapp.SAPP_KEYCODE_END]              = "end",
}

-- --------------------------------------------------------------------------------------
local LITE_EVENT = {}
LITE_EVENT[sapp.SAPP_EVENTTYPE_CHAR]            = "textinput"
    
LITE_EVENT[sapp.SAPP_EVENTTYPE_KEY_DOWN]        = "keypressed"
LITE_EVENT[sapp.SAPP_EVENTTYPE_KEY_UP]          = "keyreleased"

LITE_EVENT[sapp.SAPP_EVENTTYPE_MOUSE_DOWN]      = "mousepressed"
LITE_EVENT[sapp.SAPP_EVENTTYPE_MOUSE_UP]        = "mousereleased"

LITE_EVENT[sapp.SAPP_EVENTTYPE_MOUSE_MOVE]      = "mousemoved"
LITE_EVENT[sapp.SAPP_EVENTTYPE_MOUSE_SCROLL]    = "mousewheel"

LITE_EVENT[sapp.SAPP_EVENTTYPE_RESIZED]         = "resized"
LITE_EVENT[sapp.SAPP_EVENTTYPE_RESUMED]         = "exposed"

LITE_EVENT[sapp.SAPP_EVENTTYPE_FILES_DROPPED]   = "filedropped"

-- --------------------------------------------------------------------------------------
local LITE_KEYMODS = {}

LITE_KEYMODS[sapp.SAPP_KEYCODE_LEFT_SHIFT]      = "left shift"
LITE_KEYMODS[sapp.SAPP_KEYCODE_LEFT_CONTROL]    = "left ctrl"
LITE_KEYMODS[sapp.SAPP_KEYCODE_LEFT_ALT]        = "left alt"
LITE_KEYMODS[sapp.SAPP_KEYCODE_LEFT_SUPER]      = "left super"

LITE_KEYMODS[sapp.SAPP_KEYCODE_RIGHT_SHIFT]     = "right shift"
LITE_KEYMODS[sapp.SAPP_KEYCODE_RIGHT_CONTROL]   = "right ctrl"
LITE_KEYMODS[sapp.SAPP_KEYCODE_RIGHT_ALT]       = "right alt"
LITE_KEYMODS[sapp.SAPP_KEYCODE_RIGHT_SUPER]     = "right super"

local LITE_BUTTONS = {}

LITE_BUTTONS[sapp.SAPP_MOUSEBUTTON_LEFT]        = "left"
LITE_BUTTONS[sapp.SAPP_MOUSEBUTTON_RIGHT]       = "right"
LITE_BUTTONS[sapp.SAPP_MOUSEBUTTON_MIDDLE]      = "middle"

-- --------------------------------------------------------------------------------------
-- Function to convert a Sokol keycode to a human-readable key name
local function sapp_key_to_name(keycode)
    return key_map[keycode] or "Unknown Key"
end

-- --------------------------------------------------------------------------------------

local function process_inputs(event)

    local eventtype = tonumber(event.type)
    local r = renderer.rect
    local system_push_event = system.push_event

    -- Only kick things off once the window is ready.
    if(eventtype == sapp.SAPP_EVENTTYPE_RESIZED) then 
        local w         = sapp.sapp_widthf()
        local h         = sapp.sapp_heightf()   
        system_push_event({
            type = LITE_EVENT[eventtype],
            a = w, b = h, c = nil, d = nil
        })  
    elseif(eventtype == sapp.SAPP_EVENTTYPE_RESUMED) then 
        system_push_event({
            type = LITE_EVENT[eventtype],
            a = nil, b = nil, c = nil, d = nil
        })  
    elseif(eventtype == sapp.SAPP_EVENTTYPE_FILES_DROPPED) then 
        local x, y = event.mouse_x, event.mouse_y
        -- process all dropped files?
        local num_files = tonumber(sapp.sapp_get_num_dropped_files())
        for i = 0, num_files-1 do
            local file = ffi.string(sapp.sapp_get_dropped_file_path(i))
            system_push_event({
                type = LITE_EVENT[eventtype],
                a = file, b = x - r.x, c = y - r.y, d = nil
            })  
        end
    elseif eventtype == sapp.SAPP_EVENTTYPE_FOCUSED then
        app_has_focus = true
    elseif eventtype == sapp.SAPP_EVENTTYPE_UNFOCUSED then
        app_has_focus = false
    elseif eventtype == sapp.SAPP_EVENTTYPE_MOUSE_ENTER then 
        sapp.sapp_show_mouse(false)
        renderer.ctx.style.cursor_visible = nk.nk_true
        local w         = sapp.sapp_widthf()
        local h         = sapp.sapp_heightf()   
        system_push_event({
            type = LITE_EVENT[eventtype],
            a = w, b = h, c = nil, d = nil
        })
    elseif eventtype == sapp.SAPP_EVENTTYPE_MOUSE_LEAVE then 
        sapp.sapp_show_mouse(true)
        renderer.ctx.style.cursor_visible = nk.nk_false
        local w         = sapp.sapp_widthf()
        local h         = sapp.sapp_heightf()   
        system_push_event({
            type = LITE_EVENT[eventtype],
            a = w, b = h, c = nil, d = nil
        })
    end  

    if eventtype == sapp.SAPP_EVENTTYPE_MOUSE_DOWN then

        local x, y = event.mouse_x, event.mouse_y
        local button = LITE_BUTTONS[event.mouse_button]
        system_push_event({
            type = LITE_EVENT[eventtype],
            a = button, b = x-r.x, c = y-r.y, d = 1
        })   

    elseif eventtype == sapp.SAPP_EVENTTYPE_MOUSE_UP then

        local x, y = event.mouse_x, event.mouse_y
        local button = LITE_BUTTONS[event.mouse_button]
        system_push_event({
            type = LITE_EVENT[eventtype],
            a = button, b = x-r.x, c = y-r.y, d = nil
        })    

    elseif eventtype == sapp.SAPP_EVENTTYPE_MOUSE_MOVE then

        local x, y = event.mouse_x, event.mouse_y
        local dx, dy = event.mouse_dx, event.mouse_dy

        -- print("Mouse event at", x, y, "delta", dx, dy, "button", button)
        system_push_event({
            type = LITE_EVENT[eventtype],
            a = x-r.x, b = y-r.y, c = dx, d = dy
        })    

    elseif eventtype == sapp.SAPP_EVENTTYPE_MOUSE_SCROLL then

        local x, y = event.mouse_x, event.mouse_y
        local dx, dy = event.scroll_x, event.scroll_y

        -- print("Mouse event at", x, y, "delta", dx, dy, "button", button)
        system_push_event({
            type = LITE_EVENT[eventtype],
            a = dy, b = nil, c = nil, d = nil
        })    

    elseif eventtype == sapp.SAPP_EVENTTYPE_KEY_UP then

        local key = tonumber(event.key_code)
        local mods = tonumber(event.modifiers)

        mods = LITE_KEYMODS[key]
        if(mods == nil) then mods = sapp_key_to_name(key) end

        system_push_event({
            type = LITE_EVENT[eventtype],
            a = mods, b = nil, c = nil, d = nil
        })    

    elseif eventtype == sapp.SAPP_EVENTTYPE_KEY_DOWN then

        local key = tonumber(event.key_code)
        local mods = tonumber(event.modifiers)

        mods = LITE_KEYMODS[key]
        if(mods == nil) then mods = sapp_key_to_name(key) end

        system_push_event({
            type = LITE_EVENT[eventtype],
            a = mods, b = nil, c = nil, d = nil
        })    

    elseif eventtype == sapp.SAPP_EVENTTYPE_CHAR then

        local key = tonumber(event.key_code)
        local char = string.char(event.char_code)
        local mods = tonumber(event.modifiers)

        mods = LITE_KEYMODS[key]
        if(mods == nil) then mods = char end

        system_push_event({
            type = LITE_EVENT[eventtype],
            a = mods, b = nil, c = nil, d = nil
        })    
    end

    nk.snk_handle_event(event)
end 

return {
    process_inputs          = process_inputs
}