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
    { pattern = "[%(%)%[%]{}]",           type = "bracket" },
    { pattern = "return",                 type = "return" },

    -- Match `foo.bar` → foo (variable.parent), .bar (variable.property)
    { pattern = "%.[%a_][%w_]*",  type = "variable.property" },

    -- Fallback single variable
    { pattern = "[%a_][%w_]*", type = "variable" },   
  },
  symbols = {
    ["if"]       = "keyword",
    ["then"]     = "keyword",
    ["else"]     = "keyword",
    ["elseif"]   = "keyword",
    ["end"]      = "keyword",
    ["do"]       = "keyword",
    ["function"] = "keyword",
    ["repeat"]   = "keyword",
    ["until"]    = "keyword",
    ["while"]    = "keyword",
    ["for"]      = "keyword",
    ["break"]    = "keyword",
    ["return"]   = "return",
    ["local"]    = "keyword",
    ["in"]       = "keyword",
    ["not"]      = "keyword",
    ["and"]      = "keyword",
    ["or"]       = "keyword",
    ["goto"]     = "keyword",
    ["self"]     = "keyword2",
    ["true"]     = "literal",
    ["false"]    = "literal",
    ["nil"]      = "literal",
  },
}

