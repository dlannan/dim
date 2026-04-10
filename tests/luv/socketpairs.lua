
-- -----------------------------------------------------------------------------------------

-- local dirtools      = require("tools.vfs.dirtools").init("dim")
local uv            = require("luv")

-- -----------------------------------------------------------------------------------------
-- Simple read/write with tcp

print("starting test...")

local function setTimeout(timeout, callback)
    local timer = uv.new_timer()
    timer:start(timeout, 0, function()
        timer:stop()
        timer:close()
        callback()
    end)
    return timer
end

local function new_worker()
    local worker_id = uv.new_work(
    function(wid, sock_read, sock_write)
        local uv            = require("luv")
        local idle = uv.new_idle()

        local sock2_out = uv.new_tcp()
        sock2_out:open(sock_read)
    
        -- Creating a simple setInterval wrapper
        local function setInterval(interval, callback)
            local timer = uv.new_timer()
            timer:start(interval, interval, function ()
            callback(timer)
            end)
            return timer
        end

        sock2_out:read_start(function(err, chunk)
            assert(not err, err)
            print(string.format("[worker%d] Recv: %s", wid, chunk))
        end)

        local ctr  = wid * 5 -- only do this 5 times
        setInterval(500, function(timer)
            if(ctr > 0) then sock_write:write(string.format("[worker%d] Sent from worker\n", wid)) end
            ctr = ctr - 1
            if(ctr == 0) then timer:stop() end
        end)
        uv.run("default")
        return wid
    end, function(wid) 
        print(string.format("[worker%d] exiting.", wid))
    end)
    return worker_id 
end

local function run_main()
    
    -- read/write pair input (from child -> main)
    local fds = uv.socketpair(nil, nil, {nonblock=true}, {nonblock=true})
    local sock1 = uv.new_tcp()
    sock1:open(fds[1])
    local sock2 = uv.new_tcp()
    sock2:open(fds[2])

    -- read/write pair output (from main -> child)
    local fds_out = uv.socketpair(nil, nil, {nonblock=true}, {nonblock=true})
    local sock1_out = uv.new_tcp()
    sock1_out:open(fds_out[2])

    sock1:read_start(function(err, chunk)
        assert(not err, err)
        print("[main] Recv: ", chunk)
    end)

    local worker1 = new_worker()
    local worker2 = new_worker()

    worker1:queue( 1, fds_out[1], sock2 )
    worker2:queue( 2, fds_out[1], sock2 )

    setTimeout(1000, function() 
        sock1_out:write("[main] Sent from main\n") 
    end)
    setTimeout(1500, function() 
        sock1_out:write("[main] Sent from main\n") 
    end)
end

run_main()
uv.run("default")
-- -----------------------------------------------------------------------------------------
