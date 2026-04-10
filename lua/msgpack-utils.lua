
local msgpack           = require "lua.msgpack"

local TAG_START         = "MSGPACK_START"
local TAG_END           = "MSGPACK_END"

local TAG_START_LEN     = #TAG_START + 1
local TAG_END_LEN       = #TAG_END + 1

--------------------------------------------------------------------------------------------------

local function endsWith(str, suffix)
    return str:sub(-#suffix) == suffix
end

--------------------------------------------------------------------------------------------------

local function startsWith(str, suffix)
    return str:sub(1, #suffix) == suffix
end

--------------------------------------------------------------------------------------------------
-- Setup a read stream to process a message pack chunk of data
local function read_chunk(reader, output_func)

    assert(reader, "msgpack reader should not be nil!!")
    local reading       = 0
    local reading_done  = false
    local total         = ""

    reader:read_start(function(err, chunk)
        assert(not err, err)
        if chunk == nil then 
            return
        elseif startsWith(chunk, TAG_START) then
            chunk = string.sub(chunk, TAG_START_LEN)
            reading = 1
        elseif endsWith(chunk, TAG_END) then
            chunk = string.sub(chunk, 1, -TAG_END_LEN)
            reading_done = true
        else 
            reading = reading + 1
        end
        if(reading > 0) then 
            total = total..chunk
        end 
        if(reading_done == true) then 
            if(output_func) then output_func(msgpack.unpack(total)) end
            reading_done = false
            total = ""
            reading = 0
        end
    end)
end 

--------------------------------------------------------------------------------------------------

local function write_chunk( writer, data )
    assert(writer, "msgpack writer should not be nil!!")
    writer:write(TAG_START)
    writer:write(msgpack.pack(data))
    writer:write(TAG_END)
end

--------------------------------------------------------------------------------------------------

return {
    read_chunk          = read_chunk,
    write_chunk         = write_chunk,
}

--------------------------------------------------------------------------------------------------
