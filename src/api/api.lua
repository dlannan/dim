local api = {}

api.renderer = {
  show_debug     = function(...) end,
  get_size       = function(...) end,
  begin_frame    = function(...) end,
  end_frame      = function(...) end,
  set_clip_rect  = function(x, y, w, h) end,
  draw_rect      = function(x, y, w, h, color) end,
  draw_text      = function(font, text, x, y, color) end,
}

api.renderer.font = {
  load          = function(path, size) end,
  set_tab_width = function(font, width) end,
  get_width     = function(font, text) return 0 end,
  get_height    = function(font) return 0 end,
  get_size      = function(font) return 0 end,
  set_size      = function(font, size) end,
  get_path      = function(font) return "" end,
  __gc          = function(font) end,
}

api.system = {
  poll_event         = function(...) end,
  wait_event         = function(timeout) return false end,
  set_cursor         = function(cursor_name) end,
  set_window_title   = function(title) end,
  set_window_mode    = function(mode, width, height) end,
  window_has_focus   = function() return false end,
  show_confirm_dialog= function(title, message) return false end,
  chdir              = function(path) end,
  list_dir           = function(path) return {} end,
  absolute_path      = function(path) return "" end,
  get_file_info      = function(path) return { modified=0, size=0, type="file" } end,
  get_clipboard      = function() return "" end,
  set_clipboard      = function(text) end,
  get_time           = function() return 0 end,
  sleep              = function(seconds) end,
  exec               = function(cmd) end,
  fuzzy_match        = function(str, pattern) return 0 end,
}

return api
