
-- -----------------------------------------------------------------------------------------

require "core.strict"

local ffi           = require("ffi")
local uv            = require("luv")
local tinsert       = table.insert

local common        = require "core.common"
local config        = require "core.config"

local msgpack       = require "lua.msgpack"
local mputils       = require "lua.msgpack-utils"

local running       = false
local project_files = {}
local project_files_json = ""
local files_writer_fd = nil

local PATHSEP = nil

local function project_scan_thread()
    local function diff_files(a, b)
        if #a ~= #b then return true end
        for i, v in ipairs(a) do
            if b[i].filename ~= v.filename
            or b[i].modified ~= v.modified then
            return true
            end
        end
    end
  
    local function compare_file(a, b)
      return a.filename < b.filename
    end
  
    local function get_files(path, t)
        t = t or {}
        local size_limit = config.file_size_limit * 10e5
        local all = system.list_dir(path) or {}
        local dirs, files = {}, {}

        for _, file in ipairs(all) do
            if not common.match_pattern(file, config.ignore_files) then
                local file = (path ~= "." and path .. PATHSEP or "") .. file
            --   local info = system.get_file_info(file)
                local info = uv.fs_stat(file)
                if info and info.size < size_limit then
                    info.filename = file
                    if(info.type == "directory") then info.type = "dir" end
                    table.insert( info.type == "dir" and dirs or files, info)
                end
            end
        end

        table.sort(dirs, compare_file)
        for _, f in ipairs(dirs) do
        table.insert(t, f)
        get_files(f.filename, t)
        end

        table.sort(files, compare_file)
        for _, f in ipairs(files) do
        table.insert(t, f)
        end

        return t, dirs
    end

    local redraw = false
    if running then
        -- every check disable redraw
        redraw = false

        -- get project files and replace previous table if the new table is
        -- different
        local t, dirs = get_files(config.project_path or ".")    
        if diff_files(project_files, t) == true then
            project_files = t
            redraw = true
        end

        if(redraw == true) then
            if(files_writer_fd) then 
                mputils.write_chunk(files_writer_fd, project_files)
            end
        end

        -- wait for next scan
        uv.sleep( config.project_scan_rate * 1000 )
    end
end

--------------------------------------------------------------------------------------------------
    
local function init(files_reader, files_writer)
    files_writer_fd = files_writer
    PATHSEP = package.config:sub(1, 1)
    running = true
end

-------------------------------------------------------------------------------------------------

local function run()
    project_scan_thread()
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
