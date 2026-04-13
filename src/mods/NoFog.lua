local NoFog = _G.offlineservice("NoFog")

local Lighting = game:GetService("Lighting")
local connections = {}
local originalFogEnd

local function disconnectLocks()
    for _, c in ipairs(connections) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(connections)
end

local function applyNoFog()
    Lighting.FogEnd = 1e10
end

function NoFog:toggle(enable)
    if enable then
        disconnectLocks()

        if originalFogEnd == nil then
            originalFogEnd = Lighting.FogEnd
        end

        applyNoFog()

        table.insert(connections, Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
            if _G.UI.settings.NoFog then
                applyNoFog()
            end
        end))
    else
        disconnectLocks()

        if originalFogEnd ~= nil then
            pcall(function()
                Lighting.FogEnd = originalFogEnd
            end)
            originalFogEnd = nil
        end
    end
end

_G.UI.addEventHandler("NoFog", function(state)
    NoFog:toggle(state)
end)

_G.UI.addStopHandler(function()
    if _G.UI.settings.NoFog then
        pcall(function()
            NoFog:toggle(false)
        end)
    else
        disconnectLocks()
    end
end)
