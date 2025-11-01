local syntax = require "core.syntax"

syntax.add {
  files = "%.lua$",
  headers = "^#!.*[ /]lua",
  comment = "--",
  patterns = {
    { pattern = { '"', '"', '\\' },       type = "string"   },
    { pattern = { "'", "'", '\\' },       type = "string"   },
    { pattern = { "%[%[", "%]%]" },       type = "string"   },
    { pattern = { "%-%-%[%[", "%]%]"},    type = "comment"  },
    { pattern = "%-%-.-\n",               type = "comment"  },
    { pattern = "-?0x%x+",                type = "number"   },
    { pattern = "-?%d+[%d%.eE]*",         type = "number"   },
    { pattern = "-?%.?%d+",               type = "number"   },
    { pattern = "<%a+>",                  type = "keyword2" },
    { pattern = "%.%.%.?",                type = "operator" },
    { pattern = "[<>~=]=",                type = "operator" },
    { pattern = "[%+%-=/%*%^%%#<>]",      type = "operator" },
    { pattern = "[%a_][%w_]*%s*%f[(\"{]", type = "function" },
    { pattern = "::[%a_][%w_]*::",        type = "function" },
    { pattern = "[%(%)%[%]{}]",           type = "bracket"  },
    { pattern = "require",                type = "require"  },
    { pattern = " [%a_]+:",               type = "method"   },
    { pattern = "self",                   type = "self"     },
    { pattern = "\t",                     type = "tab"      },


    -- Match `foo.bar` → foo (variable.parent), .bar (variable.property)
    { pattern = "%.[%a_][%w_]*",  type = "variable.property" },

    -- Fallback single variable
    { pattern = "[%a_][%w_]*", type = "variable" },
  },
  symbols = {
    ["if"]       = "keyword2",
    ["then"]     = "keyword2",
    ["else"]     = "keyword2",
    ["elseif"]   = "keyword2",
    ["end"]      = "keyword2",
    ["do"]       = "keyword2",
    ["function"] = "keyword2",
    ["repeat"]   = "keyword2",
    ["until"]    = "keyword2",
    ["while"]    = "keyword2",
    ["for"]      = "keyword2",
    ["break"]    = "keyword2",
    ["return"]   = "keyword2",
    ["local"]    = "keyword",
    ["in"]       = "keyword",
    ["not"]      = "keyword",
    ["and"]      = "keyword",
    ["or"]       = "keyword",
    ["goto"]     = "keyword",
    ["self"]     = "self",
    ["true"]     = "literal",
    ["false"]    = "literal",
    ["nil"]      = "literal",
    ["require"]  = "require",
  },
}

