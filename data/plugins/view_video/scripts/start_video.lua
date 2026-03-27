function my_fn(event)
    print("start of playback!")
end
mp.register_event("file-loaded", my_fn)

function on_pause_change(name, value)
    if value == true then
        mp.set_property("fullscreen", "no")
    end
end
mp.observe_property("pause", "bool", on_pause_change)

mp.set_property("display-width", "1280")
mp.set_property("display-height", "720")
