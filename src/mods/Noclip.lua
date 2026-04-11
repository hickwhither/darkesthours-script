local Noclip = _G.offlineservice("Noclip")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ENABLED_KEY = "Noclip"

local localPlayer = Players.LocalPlayer
local stepConnection
local originalCollisionStates = {}

-- UI Register
_G.state.settings.Noclip = false
_G.UI.addEventHandler(ENABLED_KEY, function(enabled)
    if enabled then
        Noclip:enable()
    else
        Noclip:disable()
    end
end)
_G.UI.addStopHandler(function()
    _G.state.settings.Noclip = false
    Noclip:disable()
end)

-- Main Functions
local function getCharacter()
    return localPlayer and localPlayer.Character
end

local function saveOriginalStates()
    local character = getCharacter()
    if not character then return end

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") and originalCollisionStates[descendant] == nil then
            originalCollisionStates[descendant] = descendant.CanCollide
        end
    end
end

local function restoreOriginalStates()
    for part, originalState in pairs(originalCollisionStates) do
        -- Check if the part still exists before trying to modify it
        if part and part.Parent then
            part.CanCollide = originalState
        end
    end
    table.clear(originalCollisionStates)
end

function Noclip:enable()
    if stepConnection then
        stepConnection:Disconnect()
    end

    -- Save states ONCE before we start overriding them every frame
    saveOriginalStates()

    -- RunService.Stepped fires right before the physics simulation
    stepConnection = RunService.Stepped:Connect(function()
        local character = getCharacter()
        if character then
            for _, descendant in ipairs(character:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    descendant.CanCollide = false
                end
            end
        end
    end)
end

function Noclip:disable()
    if stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
    end

    restoreOriginalStates()
end

function Noclip:toggle(enabled)
    _G.state.settings.Noclip = enabled
    if enabled then
        self:enable()
    else
        self:disable()
    end
end
