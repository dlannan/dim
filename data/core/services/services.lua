-- Basic service setup and runtime tools
-- How it works:
--    the main_states run a seperate process for background services.
--    each service runs as a worker thread on this process.
--    data is piped in/out via process pipes (read and write).
--    a worker makes a new pipe to send to/from its worker to the main bgservices process
--    the tools here are to help with pipe setup, and worker setup.

local uv        = require('luv')

--------------------------------------------------------------------------------------------------

local function setup_pipes( fds, pipes )
    pipes.read = assert(uv.new_pipe())
    pipes.read:open(fds.read)
    pipes.write = assert(uv.new_pipe())
    pipes.write:open(fds.write)
end

--------------------------------------------------------------------------------------------------

local function setup_tcps( fds, tcps, no_read )
    tcps.read = assert(uv.new_tcp())
    tcps.read:open(fds[1])
    if(no_read == nil) then 
        tcps.write = assert(uv.new_tcp())
        tcps.write:open(fds[2])
    end
end

--------------------------------------------------------------------------------------------------

local function make_worker()

    local worker_id = uv.new_work(
    function(service_filename, base_path, pipes_read, pipes_write)
        
        package.path      = package.path..";"..base_path.."\\data\\?.lua"
        SCALE = 1.0

        local dirtools      = require("tools.vfs.dirtools").init("dim")
        local uv            = require('luv')
        local pp            = require("lua.pretty-print")
        local t             = uv.thread_self()

        require("src.system")
        require("src.platform")

        local worker_service  = require(service_filename) 
        worker_service.init(pipes_read, pipes_write)
        local idle = uv.new_idle()
        idle:start(function()
            worker_service.run()
        end)
        uv.run("default")
    end, function() 
        uv.walk(uv.close)
        uv.run() 
    end)
    return worker_id
end

--------------------------------------------------------------------------------------------------
-- pipes based service
local function new_pipes_service( rw )

    local pipes = nil 
    local fds = nil
    if(rw) then 
        local fds_in = assert(uv.pipe({nonblock=true}, {nonblock=true}))
        assert(uv.guess_handle(fds_in.read) == "pipe")
        assert(uv.guess_handle(fds_in.write) == "pipe")
        local fds_out = assert(uv.pipe({nonblock=true}, {nonblock=true}))
        assert(uv.guess_handle(fds_out.read) == "pipe")
        assert(uv.guess_handle(fds_out.write) == "pipe")
        fds = { out = fds_out, inp = fds_in }
        pipes = { out = {}, inp = {} }
        setup_pipes(fds_out, pipes.out)
        setup_pipes(fds_in, pipes.inp)
    else 
        fds = assert(uv.pipe({nonblock=true}, {nonblock=true}))
        assert(uv.guess_handle(fds.read) == "pipe")
        assert(uv.guess_handle(fds.write) == "pipe")
        pipes = {}
        setup_pipes(fds, pipes)
    end
    return { fds = fds, pipes = pipes }
end

--------------------------------------------------------------------------------------------------
-- tcp based service
local function new_tcp_service( rw )

    local tcps = nil 
    local fds = nil
    if(rw) then 
        local fds_in = assert(uv.socketpair("stream", nil, {nonblock=true}, {nonblock=true}))
        local fds_out = assert(uv.socketpair("stream", nil, {nonblock=true}, {nonblock=true}))
        fds = { out = fds_out, inp = fds_in }
        tcps = { out = {}, inp = {} }
        setup_tcps(fds_out, tcps.out)
        setup_tcps(fds_in, tcps.inp, true)
    else 
        fds = assert(uv.socketpair("stream", nil, {nonblock=true}, {nonblock=true}))
        tcps = {}
        setup_tcps(fds, tcps)
    end
    return { fds = fds, tcps = tcps }
end

--------------------------------------------------------------------------------------------------

return {

    new_pipes_service   = new_pipes_service,
    new_tcp_service   = new_tcp_service,

    make_worker         = make_worker,
}


--------------------------------------------------------------------------------------------------
