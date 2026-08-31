-- protobuf_text.lua
--
-- Parser for Google's protobuf text format ("textproto").
--
-- Example:
--
--   local proto = require("protobuf_text")
--
--   local t = proto.parse([[
--       components {
--           id: "Airport.001_mesh"
--           component: "/data/foo.mesh"
--       }
--
--       embedded_components {
--           id: "collisionobject_4"
--           type: "collisionobject"
--           data: "mass: 0.0\n"
--           data: "friction: 0.1\n"
--       }
--   ]])
--
--   print(t.components[1].id)
--
-- Repeated fields are represented as arrays.
-- Nested messages are represented as tables.
--

local M = {}

----------------------------------------------------------------------
-- Lexer
----------------------------------------------------------------------

local Lexer = {}
Lexer.__index = Lexer

function Lexer.new(input)
    return setmetatable({
        input = input,
        pos = 1,
        len = #input,
        line = 1,
        col = 1,
    }, Lexer)
end

function Lexer:error(message)
    error(string.format(
        "protobuf text parse error at line %d, column %d: %s",
        self.line,
        self.col,
        message
    ), 0)
end

function Lexer:peek_char(offset)
    offset = offset or 0
    local p = self.pos + offset

    if p > self.len then
        return nil
    end

    return self.input:sub(p, p)
end

function Lexer:advance()
    local c = self:peek_char()

    if not c then
        return nil
    end

    self.pos = self.pos + 1

    if c == "\n" then
        self.line = self.line + 1
        self.col = 1
    else
        self.col = self.col + 1
    end

    return c
end

function Lexer:skip_whitespace_and_comments()
    while true do
        -- Whitespace
        while true do
            local c = self:peek_char()

            if c == " " or
               c == "\t" or
               c == "\r" or
               c == "\n" then
                self:advance()
            else
                break
            end
        end

        -- // comment
        if self:peek_char() == "/" and self:peek_char(1) == "/" then
            self:advance()
            self:advance()

            while self:peek_char() and self:peek_char() ~= "\n" do
                self:advance()
            end

        -- # comment
        elseif self:peek_char() == "#" then
            self:advance()

            while self:peek_char() and self:peek_char() ~= "\n" do
                self:advance()
            end

        -- /* comment */
        elseif self:peek_char() == "/" and self:peek_char(1) == "*" then
            self:advance()
            self:advance()

            while true do
                local c = self:peek_char()

                if not c then
                    self:error("unterminated block comment")
                end

                if c == "*" and self:peek_char(1) == "/" then
                    self:advance()
                    self:advance()
                    break
                end

                self:advance()
            end

        else
            break
        end
    end
end

local function is_identifier_start(c)
    return c and c:match("[A-Za-z_]") ~= nil
end

local function is_identifier_char(c)
    return c and c:match("[A-Za-z0-9_%.%-]") ~= nil
end

function Lexer:read_identifier()
    self:skip_whitespace_and_comments()

    local start = self.pos
    local first = self:peek_char()

    if not is_identifier_start(first) then
        self:error("expected identifier")
    end

    self:advance()

    while is_identifier_char(self:peek_char()) do
        self:advance()
    end

    return self.input:sub(start, self.pos - 1)
end

----------------------------------------------------------------------
-- String decoding
----------------------------------------------------------------------

local hex = {
    ["0"] = 0, ["1"] = 1, ["2"] = 2, ["3"] = 3,
    ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7,
    ["8"] = 8, ["9"] = 9,
    ["a"] = 10, ["b"] = 11, ["c"] = 12,
    ["d"] = 13, ["e"] = 14, ["f"] = 15,
    ["A"] = 10, ["B"] = 11, ["C"] = 12,
    ["D"] = 13, ["E"] = 14, ["F"] = 15,
}

local function utf8_encode(codepoint)
    if codepoint < 0x80 then
        return string.char(codepoint)

    elseif codepoint < 0x800 then
        return string.char(
            0xC0 + math.floor(codepoint / 0x40),
            0x80 + (codepoint % 0x40)
        )

    elseif codepoint < 0x10000 then
        return string.char(
            0xE0 + math.floor(codepoint / 0x1000),
            0x80 + (math.floor(codepoint / 0x40) % 0x40),
            0x80 + (codepoint % 0x40)
        )

    elseif codepoint <= 0x10FFFF then
        return string.char(
            0xF0 + math.floor(codepoint / 0x40000),
            0x80 + (math.floor(codepoint / 0x1000) % 0x40),
            0x80 + (math.floor(codepoint / 0x40) % 0x40),
            0x80 + (codepoint % 0x40)
        )
    end

    return ""
end

function Lexer:read_string()
    self:skip_whitespace_and_comments()

    local quote = self:peek_char()
    if quote ~= '"' and quote ~= "'" then
        self:error("expected quoted string")
    end
    self:advance()
    local out = {}
    while true do
        local c = self:peek_char()

        if not c then
            self:error("unterminated string")
        end

        if c == quote then
            self:advance()
            break
        end

        if c ~= "\\" then
            out[#out + 1] = self:advance()
        else
            self:advance()

            local e = self:peek_char()

            if not e then
                self:error("unterminated escape sequence")
            end

            self:advance()

            if e == "a" then
                out[#out + 1] = "\a"

            elseif e == "b" then
                out[#out + 1] = "\b"

            elseif e == "f" then
                out[#out + 1] = "\f"

            elseif e == "n" then
                out[#out + 1] = "\n"

            elseif e == "r" then
                out[#out + 1] = "\r"

            elseif e == "t" then
                out[#out + 1] = "\t"

            elseif e == "v" then
                out[#out + 1] = "\v"

            elseif e == "\\" then
                out[#out + 1] = "\\"

            elseif e == "'" then
                out[#out + 1] = "'"

            elseif e == '"' then
                out[#out + 1] = '"'

            elseif e == "x" then
                -- \xNN
                local h1 = self:peek_char()
                local h2 = self:peek_char(1)
                if not hex[h1] or not hex[h2] then
                    self:error("invalid hexadecimal escape")
                end
                self:advance()
                self:advance()
                out[#out + 1] =
                    string.char(hex[h1] * 16 + hex[h2])

            elseif e:match("[0-7]") then
                -- Octal escape: \NNN
                local value = tonumber(e, 8)
                for _ = 1, 2 do
                    local d = self:peek_char()

                    if d and d:match("[0-7]") then
                        value = value * 8 + tonumber(d, 8)
                        self:advance()
                    else
                        break
                    end
                end
                out[#out + 1] = string.char(value % 256)
            elseif e == "u" then
                -- \uXXXX
                local value = 0
                for _ = 1, 4 do
                    local h = self:peek_char()
                    if not h or not hex[h] then
                        self:error("invalid \\u escape")
                    end
                    value = value * 16 + hex[h]
                    self:advance()
                end
                out[#out + 1] = utf8_encode(value)
            elseif e == "U" then
                -- \UXXXXXXXX
                local value = 0
                for _ = 1, 8 do
                    local h = self:peek_char()

                    if not h or not hex[h] then
                        self:error("invalid \\U escape")
                    end

                    value = value * 16 + hex[h]
                    self:advance()
                end
                out[#out + 1] = utf8_encode(value)
            else
                -- Protobuf permits escaping punctuation.
                -- Preserve unknown escapes as the escaped character.
                out[#out + 1] = e
            end
        end
    end
    return table.concat(out)
end

----------------------------------------------------------------------
-- Bare tokens / numbers
----------------------------------------------------------------------

function Lexer:read_token()
    self:skip_whitespace_and_comments()
    local start = self.pos
    while true do
        local c = self:peek_char()
        if not c then
            break
        end
        if c:match("[%s,:;{}<>%[%]]") then
            break
        end
        self:advance()
    end
    if self.pos == start then
        self:error("expected value")
    end
    return self.input:sub(start, self.pos - 1)
end

local function convert_scalar(token)
    if token == "true" then
        return true
    end

    if token == "false" then
        return false
    end
    -- Protobuf special floating-point values.
    if token == "inf" or token == "Infinity" then
        return math.huge
    end
    if token == "-inf" or token == "-Infinity" then
        return -math.huge
    end
    if token == "nan" or token == "NaN" then
        return 0 / 0
    end
    -- Hex integer.
    local sign, hex_number = token:match("^([+-]?)[0xX]([0-9a-fA-F]+)$")
    if hex_number then
        local n = tonumber(hex_number, 16)

        if sign == "-" then
            n = -n
        end

        return n
    end
    -- Decimal integer / floating point.
    local n = tonumber(token)

    if n ~= nil then
        return n
    end
    -- Enum values and other identifiers remain strings.
    return token
end

----------------------------------------------------------------------
-- Parser
----------------------------------------------------------------------

local Parser = {}
Parser.__index = Parser

function Parser.new(input)
    return setmetatable({
        lexer = Lexer.new(input)
    }, Parser)
end

function Parser:error(message)
    self.lexer:error(message)
end

function Parser:skip_separators()
    self.lexer:skip_whitespace_and_comments()

    while true do
        local c = self.lexer:peek_char()

        if c == "," or c == ";" then
            self.lexer:advance()
            self.lexer:skip_whitespace_and_comments()
        else
            break
        end
    end
end

----------------------------------------------------------------------
-- Add a field to a Lua table.
--
-- Repeated fields become arrays:
--
--   data: 1
--   data: 2
--
-- becomes:
--
--   data = { 1, 2 }
--
-- A field occurring once remains scalar.
----------------------------------------------------------------------

function Parser:add_field(tbl, key, value)
    local old = tbl[key]
    if old == nil then
        tbl[key] = value
        return
    end
    -- Already repeated.
    if type(old) == "table" and old.__protobuf_repeated then
        old[#old + 1] = value
        return
    end
    -- Convert scalar -> repeated.
    local repeated = {
        __protobuf_repeated = true,
        old,
        value
    }
    tbl[key] = repeated
end

----------------------------------------------------------------------
-- Parse a message:
--
-- {
--     foo: 123
--     bar: "hello"
-- }
--
-- or:
--
-- <
--     foo: 123
-- >
----------------------------------------------------------------------

function Parser:parse_message()
    self.lexer:skip_whitespace_and_comments()
    local open = self.lexer:peek_char()
    if open ~= "{" and open ~= "<" then
        self:error("expected '{' or '<'")
    end
    local close = open == "{" and "}" or ">"
    self.lexer:advance()
    local result = {}
    while true do
        self:skip_separators()
        local c = self.lexer:peek_char()
        if not c then
            self:error("unexpected end of input")
        end
        if c == close then
            self.lexer:advance()
            return result
        end
        self:parse_field(result)
    end
end

----------------------------------------------------------------------
-- Parse a field name.
--
-- Supports:
--
--   foo
--   foo.bar
--   [type.googleapis.com/Foo]
--
----------------------------------------------------------------------

function Parser:parse_field_name()
    self.lexer:skip_whitespace_and_comments()
    if self.lexer:peek_char() == "[" then
        self.lexer:advance()
        local parts = {}
        while true do
            local c = self.lexer:peek_char()
            if not c then
                self:error("unterminated extension field")
            end
            if c == "]" then
                self.lexer:advance()
                break
            end
            parts[#parts + 1] = self.lexer:advance()
        end
        return "[" .. table.concat(parts) .. "]"
    end
    return self.lexer:read_identifier()
end

----------------------------------------------------------------------
-- Parse a value.
----------------------------------------------------------------------

function Parser:parse_value()
    self.lexer:skip_whitespace_and_comments()
    local c = self.lexer:peek_char()

    -- Nested message.
    if c == "{" or c == "<" then
        return self:parse_message()
    end

    -- Quoted string.
    if c == '"' or c == "'" then
        -- Protobuf allows adjacent strings:
        --
        --   "hello" "world"
        --
        local parts = {}
        while true do
            self.lexer:skip_whitespace_and_comments()
            c = self.lexer:peek_char()
            if c ~= '"' and c ~= "'" then
                break
            end
            parts[#parts + 1] = self.lexer:read_string()
        end
        return table.concat(parts)
    end
    -- Bare scalar / enum.
    local token = self.lexer:read_token()
    return convert_scalar(token)
end

----------------------------------------------------------------------
-- Parse:
--
--   foo: value
--
--   foo { ... }
--
--   foo: { ... }
--
----------------------------------------------------------------------

function Parser:parse_field(tbl)
    local key = self:parse_field_name()
    self.lexer:skip_whitespace_and_comments()

    local c = self.lexer:peek_char()
    if c == ":" then
        self.lexer:advance()
        local value = self:parse_value()
        self:add_field(tbl, key, value)
    elseif c == "{" or c == "<" then
        local value = self:parse_message()
        self:add_field(tbl, key, value)
    else
        self:error(
            "expected ':' or '{'/'<' after field '" .. key .. "'"
        )
    end
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

function M.parse(input)
    assert(type(input) == "string", "protobuf_text.parse expects a string")

    local parser = Parser.new(input)
    local result = {}

    while true do
        parser:skip_separators()
        local c = parser.lexer:peek_char()
        if not c then
            break
        end
        parser:parse_field(result)
    end

    return result
end

function M.load(filename)
    local f, err = io.open(filename, "rb")
    if not f then
        error("unable to open '" .. filename .. "': " .. err, 0)
    end
    local data = f:read("*a")
    f:close()
    return M.parse(data)
end

return M

