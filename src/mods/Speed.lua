local SpeedService = _G.offlineservice("Speed")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ENABLED_KEY = "Speed"
local DEFAULT_WALK_SPEED = 16

local localPlayer = Players.LocalPlayer
local heartbeatConnection
local characterAddedConnection
local Workspace = game:GetService("Workspace")

-- Khởi tạo giá trị mặc định nếu chưa có
_G.WALK_SPEED = _G.WALK_SPEED or 50
_G.UI.settings[ENABLED_KEY] = _G.UI.settings[ENABLED_KEY] or false

-- Lưu trạng thái tốc độ trước khi mod can thiệp để có thể restore
local originalWalkSpeedByHumanoid = setmetatable({}, { __mode = "k" })

local function getHumanoidFromCharacter(character)
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function getCurrentHumanoid()
    local character = localPlayer and localPlayer.Character
    if not character or not character.Parent then
        local charactersFolder = Workspace:FindFirstChild("Characters")
        local playersFolder = charactersFolder and charactersFolder:FindFirstChild("Player")
        if playersFolder and localPlayer then
            character = playersFolder:FindFirstChild(localPlayer.Name)
        end
    end
    return getHumanoidFromCharacter(character)
end

local function rememberOriginalWalkSpeed(humanoid)
    if humanoid and originalWalkSpeedByHumanoid[humanoid] == nil then
        originalWalkSpeedByHumanoid[humanoid] = humanoid.WalkSpeed
    end
end

local function applySpeedToHumanoid(humanoid)
    if not humanoid then return end
    rememberOriginalWalkSpeed(humanoid)
    humanoid.WalkSpeed = _G.WALK_SPEED
end

local function restoreWalkSpeed(humanoid)
    if not humanoid then return end

    local original = originalWalkSpeedByHumanoid[humanoid]
    if original == nil then
        original = DEFAULT_WALK_SPEED
    end

    humanoid.WalkSpeed = original
    originalWalkSpeedByHumanoid[humanoid] = nil
end

local function onHeartbeat()
    if not _G.UI.settings[ENABLED_KEY] then
        return
    end

    local humanoid = getCurrentHumanoid()
    if humanoid then
        applySpeedToHumanoid(humanoid)
    end
end

function SpeedService:enable()
    if heartbeatConnection then
        return
    end

    local humanoid = getCurrentHumanoid()
    if humanoid then
        applySpeedToHumanoid(humanoid)
    end

    heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
end

function SpeedService:disable()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    local humanoid = getCurrentHumanoid()
    if humanoid then
        restoreWalkSpeed(humanoid)
    end
end

function SpeedService:toggle(enabled)
    _G.UI.settings[ENABLED_KEY] = enabled

    if enabled then
        self:enable()
    else
        self:disable()
    end
end

function SpeedService:destroy()
    self:disable()

    if characterAddedConnection then
        characterAddedConnection:Disconnect()
        characterAddedConnection = nil
    end
end

-- UI Register
_G.UI.addEventHandler(ENABLED_KEY, function(enabled)
    SpeedService:toggle(enabled)
end)

_G.UI.addStopHandler(function()
    _G.UI.settings[ENABLED_KEY] = false
    SpeedService:destroy()
end)

-- Khi respawn, nếu vẫn bật Speed thì áp lại tốc độ
if localPlayer then
    characterAddedConnection = localPlayer.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")

        if _G.UI.settings[ENABLED_KEY] then
            applySpeedToHumanoid(humanoid)
        else
            originalWalkSpeedByHumanoid[humanoid] = nil
        end
    end)
end
