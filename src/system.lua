local dirtools  = require("tools.vfs.dirtools").init("dim")

-- --------------------------------------------------------------------------------------

local sapp        = require("sokol_app")
local stb         = require("stb")
local nk          = sg

local ffi         = require("ffi")

local tinsert     = table.insert

-- --------------------------------------------------------------------------------------

local function fuzzy_match(needle, haystack, file_mode)
  -- Convert to lowercase for case‑insensitive match
  local n = needle:lower()
  local h = haystack:lower()

  local nlen = #n
  local hlen = #h

  if nlen == 0 then
      return 1  -- empty needle matches with highest score
  end

  local score = 0
  local j = 1

  for i = 1, nlen do
      local c = n:sub(i,i)
      local found = h:find(c, j, true)
      if not found then
          return 0  -- no match
      end
      -- reward a match early in the haystack
      if found == j then
          score = score + 1
      end
      j = found + 1
  end

  -- normalize score: divide by the haystack length (or some heuristic)
  local norm = score / hlen
  return norm
end

-- --------------------------------------------------------------------------------------

system = {
	event_queue 		= {}
}

system.push_event = function( event )

	tinsert(system.event_queue, event)
end


system.poll_event = function()
    local i = 0
    local events = system.event_queue
    -- The iterator function to be called by 'for' with state and current index
    return function(_, lastIndex)
        local nextIndex = (lastIndex or 0) + 1
        local ev = events[nextIndex]
        if ev then
            return nextIndex, ev.type, ev.a, ev.b, ev.c, ev.d
        end
        return nil
    end, nil, 0
end


system.wait_event         = function(timeout) 
	-- blocking: wait for event, simplified with coroutine or a condition var
	local ticker_end = os.clock() + timeout
	while #system.event_queue == 0 and os.clock() < ticker_end do
		-- ffi.C.Sleep(1)
	end
	return system.poll_event()
end

system.set_cursor         = function(cursor_name) 
end

system.set_window_title   = function(title) 
    sapp.sapp_set_window_title(title)
end

-- Set fullscreen, minimized and maximized etc
system.set_window_mode    = function(mode, width, height) 
    -- sapp_is_fullscreen()
    -- sapp_toggle_fullscreen()
end

system.window_has_focus   = function() 
    return app_has_focus
end

system.show_confirm_dialog= function(title, message) 
    return false 
end

system.chdir              = function(path) 
    dirtools.change_dir(path)
end

system.list_dir           = function(path) 
    local files = dirtools.get_dirlist(path, true)
    local results = {}
    for i, file in pairs(files) do tinsert(results, file.name) end
    return results
end

system.absolute_path      = function(path) 
    return dirtools.get_folder(path)
end

system.get_file_info      = function(path) 
	return dirtools.get_fileinfo(path)
    -- return { modified=0, size=0, type="file" } 
end

system.get_clipboard      = function() 
    return  sapp.sapp_get_clipboard_string()
end

system.set_clipboard      = function(text) 
    sapp.sapp_set_clipboard_string(ffi.string(text))
end

system.get_time           = function() 
    return os.clock()
end

system.sleep              = function(seconds) 
    ffi.C.Sleep(seconds * 1000) 
end

system.exec               = function(cmd) 
    os.execute(cmd)
end

system.fuzzy_match        = function(str, pattern) 
    return fuzzy_match( pattern, str, false)
end

-- /* gets the total number of dropped files (after an SAPP_EVENTTYPE_FILES_DROPPED event) */
-- SOKOL_APP_API_DECL int sapp_get_num_dropped_files(void);
-- /* gets the dropped file paths */
-- SOKOL_APP_API_DECL const char* sapp_get_dropped_file_path(int index);