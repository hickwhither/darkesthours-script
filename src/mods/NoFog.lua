local NoFog = _G.offlineservice("NoFog")

local Lighting = game:GetService("Lighting")
local connections = {}
local originalFogEnd
local originalFogStart

local function disconnectLocks()
    for _, c in ipairs(connections) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(connections)
end

local function applyNoFog()
    Lighting.FogEnd = 100000
    Lighting.FogStart = 99000
end

function NoFog:toggle(enable)
    if enable then
        disconnectLocks()

        if originalFogEnd == nil then
            originalFogEnd = Lighting.FogEnd
        end
        if originalFogStart == nil then
            originalFogStart = Lighting.FogStart
        end

        applyNoFog()

        table.insert(connections, Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
            if _G.UI.settings.NoFog then
                applyNoFog()
            end
        end))
        table.insert(connections, Lighting:GetPropertyChangedSignal("FogStart"):Connect(function()
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
        if originalFogStart ~= nil then
            pcall(function()
                Lighting.FogStart = originalFogStart
            end)
            originalFogStart = nil
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
