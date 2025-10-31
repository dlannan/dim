local style = require "core.style"
local common = require "core.common"

style.code_font = renderer.font.load(EXEDIR .. "/data/fonts/CascadiaMono-SemiBold.ttf", 15 * SCALE)

-- VSCode Dark+ palette
style.background   = { common.color "#1E1E1E" }  -- editor background
style.background2  = { common.color "#252526" }  -- secondary background
style.background3  = { common.color "#2D2D2D" }
style.text         = { common.color "#D4D4D4" }  -- default text
style.caret        = { common.color "#AEAFAD" }
style.accent       = { common.color "#007ACC" }  -- blue highlight
style.dim          = { common.color "#808080" }
style.divider      = { common.color "#333333" }
style.selection    = { common.color "#264F78" }
style.line_number  = { common.color "#858585" }
style.line_number2 = { common.color "#C6C6C6" }
style.line_highlight = { common.color "#2A2A2A" }
style.line_highlight = { common.color "#2A2A2A" }
style.scrollbar    = { common.color "#424242" }
style.scrollbar2   = { common.color "#686868" }

-- Syntax highlighting (based on VS Code Dark+)
style.syntax["normal"]   = { common.color "#D4D4D4" }
style.syntax["symbol"]   = { common.color "#D4D4D4" }
style.syntax["comment"]  = { common.color "#6A9955" }
style.syntax["keyword"]  = { common.color "#569CD6" }
style.syntax["keyword2"] = { common.color "#C586C0" } -- secondary keyword (e.g. class, type)
style.syntax["number"]   = { common.color "#B5CEA8" }
style.syntax["literal"]  = { common.color "#569CD6" }
style.syntax["string"]   = { common.color "#CE9178" }
style.syntax["operator"] = { common.color "#D4D4D4" }
style.syntax["function"] = { common.color "#DCDCAA" }
style.syntax["type"]     = { common.color "#4EC9B0" }
style.syntax["whitespace"] = { common.color "#404040" }

style.syntax["variable.parent"]   = { common.color "#9CDCFE" } -- light blue
style.syntax["variable.property"] = { common.color "#4EC9B0" } -- green
style.syntax["variable"]          = { common.color "#9CDCFE" } -- fallback

style.syntax["bracket"]     = { common.color "#DBD710" } -- VS Code yellow
style.syntax["return"]      = { common.color "#C586C0" }

return style
