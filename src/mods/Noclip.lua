local Noclip = _G.offlineservice("Noclip")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ENABLED_KEY = "Noclip"

local localPlayer = Players.LocalPlayer
local stepConnection
local characterAddedConnection
local originalCollisionStates = {}

-- UI Register
_G.UI.addEventHandler(ENABLED_KEY, function(enabled)
    if enabled then
        Noclip:enable()
    else
        Noclip:disable()
    end
end)
_G.UI.addStopHandler(function()
    _G.UI.settings.Noclip = false
    Noclip:disable()
end)

-- Main Functions
local function getCharacter()
    if not localPlayer then
        return nil
    end

    local character = localPlayer.Character
    if character and character.Parent then
        return character
    end

    local charactersFolder = workspace:FindFirstChild("Characters")
    local playersFolder = charactersFolder and charactersFolder:FindFirstChild("Player")
    if playersFolder then
        return playersFolder:FindFirstChild(localPlayer.Name)
    end

    return nil
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
    _G.UI.settings.Noclip = enabled
    if enabled then
        self:enable()
    else
        self:disable()
    end
end

if localPlayer then
    characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
        if _G.UI.settings.Noclip then
            Noclip:enable()
        end
    end)

    _G.UI.addStopHandler(function()
        if characterAddedConnection then
            characterAddedConnection:Disconnect()
            characterAddedConnection = nil
        end
    end)
end
