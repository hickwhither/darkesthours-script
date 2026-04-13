if _G.running then
    return
end
_G.running = true

local baseUrl = "https://github.com/hickwhither/darkesthours-script/raw/refs/heads/master/src/"

local function fetch(name)
    print(baseUrl .. name)
    local ok, res = pcall(function() return loadstring(game:HttpGet(baseUrl .. name))() end)
    if not ok then
        warn("Lỗi tải module " .. name .. ": " .. tostring(res))
    end
    return res
end

_G.class = fetch("pack/class.lua")
_G.offlineservice = fetch("pack/offlineservice.lua")

fetch("Utils.lua")
fetch("UI.lua")
fetch("ESP.lua")

fetch("mods/Fullbright.lua")
fetch("mods/Flight.lua")
fetch("mods/Speed.lua")
fetch("mods/Noclip.lua")
fetch("mods/ClickTP.lua")
fetch("mods/NoFog.lua")

print("✅ Modules loaded from " .. baseUrl)
