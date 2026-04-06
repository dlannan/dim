-- Basic service setup and runtime tools
-- How it works:
--    the main_states run a seperate process for background services.
--    each service runs as a worker thread on this process.
--    data is piped in/out via process pipes (read and write).
--    a worker makes a new pipe to send to/from its worker to the main bgservices process
--    the tools here are to help with pipe setup, and worker setup.

local msgpack   = require "lua.msgpack"
local uv        = require('luv')

--------------------------------------------------------------------------------------------------

local function endsWith(str, suffix)
    return str:sub(-#suffix) == suffix
end

--------------------------------------------------------------------------------------------------

local function startsWith(str, suffix)
    return str:sub(1, #suffix) == suffix
end

--------------------------------------------------------------------------------------------------

local function setup_pipes( fds )
    local pipe_read = assert(uv.new_pipe())
    pipe_read:open(fds.read)
    local pipe_write = assert(uv.new_pipe())
    pipe_write:open(fds.write)
    return pipe_read, pipe_write
end

--------------------------------------------------------------------------------------------------

local function make_worker()
    return uv.new_work(function(service_filename, base_path, pipe_writer)
        
        package.path      = package.path..";"..base_path.."\\data\\?.lua"
        SCALE = 1.0

        local dirtools      = require("tools.vfs.dirtools").init("dim")
        local uv            = require('luv')
        local pp            = require("lua.pretty-print")

        require("src.system")
        require("src.platform")

        local file_check  = require(service_filename)
        file_check.init(pipe_writer)
        local idle = uv.new_idle()
        idle:start(function()
          file_check.run()
        end)
        uv.run("default")
    end, function() 
        uv.walk(uv.close)
        uv.run() 
    end)
end

--------------------------------------------------------------------------------------------------

local function make_reader_msgpack(reader, output_func)

    local reading       = 0
    local reading_done  = false
    local total         = ""

    reader:read_start(function(err, chunk)
        assert(not err, err)
        if chunk == nil then 
            return
        elseif startsWith(chunk, "MSGPACK_START") then
            pprint("[Info] Project directory starting scan.")
            chunk = string.sub(chunk, 14)
            reading = 1
        elseif endsWith(chunk, "MSGPACK_END") then
            pprint("[Info] Project directory scan complete.")
            chunk = string.sub(chunk, 1, -12)
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

return {
    setup_pipes         = setup_pipes,
    make_worker         = make_worker,

    make_reader_msgpack = make_reader_msgpack,
}


--------------------------------------------------------------------------------------------------
