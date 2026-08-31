-- Add the editor path so that the older defold code can work as is.
package.path    = package.path..";./editor/?.lua"

local config = {}

config.project_scan_rate    = 5     -- 5 seconds
config.file_read_rate       = 0.1   -- a tenth a second to start a read
config.message_pump_rate    = 0.01  -- pump messages at 100x per second
config.fps                  = 60    -- expected display frame rate (may become automated)
config.max_log_items        = 80    -- Number of log items to allow (minimize output files)
config.message_timeout      = 3
config.mouse_wheel_scroll   = 50 * SCALE
config.file_size_limit      = 10    -- 10 MB files can be views with default DocView (custom ones can be much bigger)
config.ignore_files         = "^%.git"
config.symbol_pattern       = "[%a_][%w_]*"
config.non_word_chars       = " \t\n/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-"
config.undo_merge_timeout   = 0.3
config.max_undos            = 10000     -- Change this for larger or smaller undo buffers
config.highlight_current_line = true
config.line_height          = 1.2
config.indent_size          = 2
config.tab_type             = "soft"
config.line_limit           = 80
config.project_path         = "."
config.max_tabs             = 10

return config
