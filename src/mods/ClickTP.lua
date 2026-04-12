local ClickTP = _G.offlineservice("ClickTP")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ENABLED_KEY = "ClickTP"

local localPlayer = Players.LocalPlayer
local inputConnection

local function getCharacter()
    if not localPlayer then
        return nil
    end

    local character = localPlayer.Character
    if character and character.Parent then
        return character
    end

    local charactersFolder = Workspace:FindFirstChild("Characters")
    local playersFolder = charactersFolder and charactersFolder:FindFirstChild("Player")
    if playersFolder then
        return playersFolder:FindFirstChild(localPlayer.Name)
    end

    return nil
end

local function teleportToMouseHit()
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local mousePos = UserInputService:GetMouseLocation()
    local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local character = getCharacter()
    if character then
        rayParams.FilterDescendantsInstances = { character }
    end

    local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 5000, rayParams)
    if not result then
        return
    end

    _G.Utils.teleportToPosition(result.Position)
end

function ClickTP:enable()
    if inputConnection then
        return
    end

    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not _G.UI.settings[ENABLED_KEY] then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton3 then
            teleportToMouseHit()
        end
    end)
end

function ClickTP:disable()
    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end
end

function ClickTP:toggle(enabled)
    _G.UI.settings[ENABLED_KEY] = enabled

    if enabled then
        self:enable()
    else
        self:disable()
    end
end

_G.UI.addEventHandler(ENABLED_KEY, function(enabled)
    ClickTP:toggle(enabled)
end)

_G.UI.addStopHandler(function()
    _G.UI.settings[ENABLED_KEY] = false
    ClickTP:disable()
end)
