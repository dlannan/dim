
-- -----------------------------------------------------------------------------------------

require "core.strict"

local ffi           = require("ffi")
local uv            = require("luv")
local tinsert       = table.insert
local tremove       = table.remove

local common        = require "core.common"
local config        = require "core.config"

local msgpack       = require "lua.msgpack"
local mputils       = require "lua.msgpack-utils"

local running           = false

local files_writer_fd   = nil
local files_reader_fd   = nil

local PATHSEP           = nil
local BLOCK_SIZE        = 64 * 1024  -- 64 KB (not slow.. but not super fast either)
-- General use:
--   This service runs continuously and checks its reqd queue. 
--   When an item is queued then data is read from a file handle.
--   Upon read completion, the data is handed back to the main thread 
--     where a callback is called to the original caller.
-- -----------------------------------------------------------------------------------------

local file_queue    = {}
local current_file  = nil
local filereading   = nil


local function file_read_thread()

    if running then
        
        -- get next file if there are ones in the queue 
        if(current_file == nil and file_queue[1]) then 
            current_file = tremove(file_queue, 1)
            filereading = current_file
        end

        if(filereading and filereading.fhandle) then 
            local data = filereading.fhandle:read("*a")
            if(data) then 
                filereading.readcount = #data
                filereading.data = data
                -- if(#data < BLOCK_SIZE) then 
                    filereading.finished = true 
                    filereading.fhandle:close()
                -- end

                if(files_writer_fd) then 
                    filereading.fhandle = nil
                    mputils.write_chunk(files_writer_fd, filereading)
                    current_file = nil
                end
            end
        end
       
        uv.sleep( 1 ) -- might run without this. Will see.
    end
end

--------------------------------------------------------------------------------------------------
    
local function init(files_reader, files_writer)
    files_writer_fd = files_writer
    files_reader_fd = files_reader
    PATHSEP = package.config:sub(1, 1)
    running = true

    local read_comm = assert(uv.new_tcp())
    read_comm:open(files_reader_fd)
    -- Check for any incoming file requests
    mputils.read_chunk(read_comm, function(data)
        -- pprint("file to read from...", data)
        if(data.filename) then 
            local fhandle = io.open(data.filename, "rb")
            if(fhandle) then
                local new_fileread = {
                    filename    = data.filename, 
                    finished    = false,
                    readcount   = 0,
                    data        = "",
                    fhandle     = fhandle,
                }
                tinsert(file_queue, new_fileread)
            else 
                mputils.write_chunk(files_writer_fd, { filename = data.filename, data = nil })
            end
        end
    end)
end

-------------------------------------------------------------------------------------------------

local function run()
    file_read_thread()
end

--------------------------------------------------------------------------------------------------

local function stop()
    running = false
end

--------------------------------------------------------------------------------------------------

return {
    init        = init,
    run         = run,
    stop        = stop,
}

--------------------------------------------------------------------------------------------------
