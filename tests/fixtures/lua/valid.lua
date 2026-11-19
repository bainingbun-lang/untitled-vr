function _mod_init()
    if emit ~= nil then
        emit("mod_ready", {status = "ok"})
    end
    subscribe("ping", "on_ping")
end

function handle_event(event, payload)
    if event == "ping" then
        return 42
    end
    return nil
end

function on_ping(payload)
    print("Lua received ping")
end
