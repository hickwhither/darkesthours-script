-- Fullbright.lua
local Fullbright = _G.offlineservice("Fullbright")

local Lighting = _G.services.Lighting

local connections = {}

--------------------------------------------------
-- UI REGISTER (giữ nguyên style của bạn)
--------------------------------------------------
_G.state.settings.Fullbright = false
_G.UI.addEventHandler("Fullbright", function(state)
    Fullbright.toggle(state)
end)
_G.UI.addStopHandler(function()
    if _G.state.settings.Fullbright then
        pcall(function()
            Fullbright.toggle(false)
        end)
    end
end)

--------------------------------------------------
-- save original
--------------------------------------------------
local function saveOriginal()
    if _G.state.originalLighting then return end

    _G.state.originalLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    }
end

--------------------------------------------------
-- apply fullbright
--------------------------------------------------
local function applyFullbright()
    Lighting.Brightness = 5
    Lighting.ClockTime = 12
    Lighting.FogEnd = 1e10
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
end

--------------------------------------------------
-- connect property locks
--------------------------------------------------
local function connectLocks()
    local props = {
        "Brightness",
        "ClockTime",
        "FogEnd",
        "GlobalShadows",
        "Ambient",
        "OutdoorAmbient",
    }

    for _, prop in ipairs(props) do
        local conn = Lighting:GetPropertyChangedSignal(prop):Connect(function()
            if _G.state.settings.Fullbright then
                applyFullbright()
            end
        end)
        table.insert(connections, conn)
        table.insert(_G.state.connections, conn)
    end
end

local function disconnectLocks()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(connections)
end

--------------------------------------------------
-- TOGGLE
--------------------------------------------------
function Fullbright.toggle(enable)
    if enable then
        saveOriginal()
        applyFullbright()
        connectLocks()
    else
        disconnectLocks()

        -- restore
        local orig = _G.state.originalLighting
        if orig then
            pcall(function()
                Lighting.Brightness = orig.Brightness
                Lighting.ClockTime = orig.ClockTime
                Lighting.FogEnd = orig.FogEnd
                Lighting.GlobalShadows = orig.GlobalShadows
                Lighting.Ambient = orig.Ambient
                Lighting.OutdoorAmbient = orig.OutdoorAmbient
            end)
            _G.state.originalLighting = nil
        end
    end
end
