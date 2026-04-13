local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local ESP = {
    Objects = {},
    Connections = {},
    Trackers = {},
    Enabled = true,
    ButtonGui = nil,
    ButtonUpdateConnection = nil,
}

local BUTTON_SIZE = Vector2.new(120, 24)
local DEFAULT_FILL_TRANSPARENCY = 0.7
local DEFAULT_OUTLINE_TRANSPARENCY = 0

local function ensureButtonGui()
    if ESP.ButtonGui and ESP.ButtonGui.Parent then
        return ESP.ButtonGui
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ESP_TeleportButtons"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    ESP.ButtonGui = gui
    return gui
end

local function updateTeleportButtonPositions()
    if not ESP.Enabled then return end

    local camera = Workspace.CurrentCamera
    if not camera then return end

    for obj, visuals in pairs(ESP.Objects) do
        local button = visuals.TeleportButton
        local adornee = visuals.Adornee
        if not button or not adornee then
            continue
        end

        if not obj:IsDescendantOf(workspace) or not adornee:IsDescendantOf(workspace) then
            button.Visible = false
            continue
        end

        local viewportPos, onScreen = camera:WorldToViewportPoint(adornee.Position + Vector3.new(0, 4, 0))

        if onScreen and viewportPos.Z > 0 then
            button.Position = UDim2.fromOffset(
                viewportPos.X - (BUTTON_SIZE.X / 2),
                viewportPos.Y - (BUTTON_SIZE.Y / 2)
            )
            button.Visible = true
        else
            button.Visible = false
        end
    end
end

local function clearTeleportButtonsFromGui()
    if not ESP.ButtonGui then
        return
    end

    for _, child in ipairs(ESP.ButtonGui:GetChildren()) do
        if child:IsA("TextButton") and child.Name == "ESP_Teleport" then
            pcall(function()
                child:Destroy()
            end)
        end
    end
end

local function ensureButtonUpdater()
    if ESP.ButtonUpdateConnection then
        return
    end

    ESP.ButtonUpdateConnection = RunService.RenderStepped:Connect(updateTeleportButtonPositions)
end

-- Hàm xác định Part để gắn ESP
local function resolveAdornee(target)
    if target:IsA("BasePart") then return target end
    if target:IsA("Model") then
        return target.PrimaryPart
            or target:FindFirstChild("ProxyPart")
            or target:FindFirstChildWhichIsA("BasePart")
    end
end

local function createTeleportButton(targetObj, labelText, color)
    local gui = ensureButtonGui()
    if not gui then
        return nil
    end

    local btn = Instance.new("TextButton")
    btn.Name = "ESP_Teleport"
    btn.Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y)
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Text = labelText or "Teleport"
    btn.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Visible = false
    btn.ZIndex = 100
    btn.Parent = gui

    btn.MouseButton1Click:Connect(function()
        _G.Utils.teleportToTarget(targetObj)
    end)

    return btn
end

local function createTextLabel(targetObj, labelText, color, adornee)
    local gui = Instance.new("BillboardGui")
    gui.Name = "ESP_Text"
    gui.Size = UDim2.fromOffset(180, 26)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.AlwaysOnTop = true
    gui.Adornee = adornee
    gui.Parent = targetObj

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.Text = labelText or targetObj.Name
    lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.4
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = gui

    return gui
end

-- Thêm ESP
function ESP.Add(obj, text, color, transparencyCheck, options)
    if not ESP.Enabled then return end
    if not obj or ESP.Objects[obj] then return end

    local adornee = resolveAdornee(obj)
    if not adornee then return end

    local visuals = {}

    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.FillTransparency = DEFAULT_FILL_TRANSPARENCY
    hl.OutlineColor = color
    hl.OutlineTransparency = DEFAULT_OUTLINE_TRANSPARENCY
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = obj
    hl.Parent = obj
    visuals.Highlight = hl

    visuals.Adornee = adornee
    visuals.Options = options or {
        Highlight = true,
        Text = true,
        TP = false,
    }
    visuals.TextGui = nil
    visuals.TeleportButton = nil

    visuals.Highlight.Enabled = visuals.Options.Highlight
    if visuals.Options.Text then
        visuals.TextGui = createTextLabel(obj, text, color, adornee)
    end
    if visuals.Options.TP then
        visuals.TeleportButton = createTeleportButton(obj, text, color)
    end

    ESP.Objects[obj] = visuals
    ESP.Connections[obj] = {}

    table.insert(ESP.Connections[obj], obj.AncestryChanged:Connect(function(_, parent)
        if not parent then
            ESP.Remove(obj)
        end
    end))

    if transparencyCheck and adornee:IsA("BasePart") then
        table.insert(ESP.Connections[obj], adornee:GetPropertyChangedSignal("Transparency"):Connect(function()
            if not ESP.Enabled then return end
            if adornee.Transparency ~= 0 then
                ESP.Remove(obj)
            end
        end))
    end

    ensureButtonUpdater()
    updateTeleportButtonPositions()
end

local function applyVisualOptionForObject(obj, optionName, enabled)
    local visuals = ESP.Objects[obj]
    if not visuals then return end

    visuals.Options = visuals.Options or {}
    visuals.Options[optionName] = enabled and true or false

    if optionName == "Highlight" and visuals.Highlight then
        visuals.Highlight.Enabled = visuals.Options.Highlight
    elseif optionName == "Text" then
        if visuals.Options.Text then
            if not visuals.TextGui and visuals.Adornee then
                visuals.TextGui = createTextLabel(obj, obj.Name, visuals.Highlight.FillColor, visuals.Adornee)
            end
        else
            if visuals.TextGui then
                pcall(function() visuals.TextGui:Destroy() end)
                visuals.TextGui = nil
            end
        end
    elseif optionName == "TP" then
        if visuals.Options.TP then
            if not visuals.TeleportButton then
                visuals.TeleportButton = createTeleportButton(obj, obj.Name, visuals.Highlight.FillColor)
            end
        else
            if visuals.TeleportButton then
                pcall(function() visuals.TeleportButton:Destroy() end)
                visuals.TeleportButton = nil
            end
            clearTeleportButtonsFromGui()
        end
        updateTeleportButtonPositions()
    end
end

-- Xóa ESP
function ESP.Remove(obj)
    if ESP.Objects[obj] then
        pcall(function() ESP.Objects[obj].Highlight:Destroy() end)
        pcall(function()
            if ESP.Objects[obj].TeleportButton then
                ESP.Objects[obj].TeleportButton:Destroy()
            end
        end)
        pcall(function()
            if ESP.Objects[obj].TextGui then
                ESP.Objects[obj].TextGui:Destroy()
            end
        end)
        ESP.Objects[obj] = nil
    end

    if ESP.Connections[obj] then
        for _, conn in ipairs(ESP.Connections[obj]) do
            pcall(function() conn:Disconnect() end)
        end
        ESP.Connections[obj] = nil
    end
end

-- Dừng toàn bộ
function ESP.StopAll()
    ESP.Enabled = false

    for _, tracker in pairs(ESP.Trackers) do
        tracker.Enabled = false
        for _, conn in ipairs(tracker.ActiveConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(tracker.ActiveConnections)
        for _, obj in ipairs(tracker.TrackedObjects) do
            ESP.Remove(obj)
        end
        table.clear(tracker.TrackedObjects)
    end

    for obj in pairs(ESP.Objects) do
        ESP.Remove(obj)
    end

    if ESP.ButtonUpdateConnection then
        pcall(function() ESP.ButtonUpdateConnection:Disconnect() end)
        ESP.ButtonUpdateConnection = nil
    end

    if ESP.ButtonGui then
        pcall(function() ESP.ButtonGui:Destroy() end)
        ESP.ButtonGui = nil
    end
end

-- Dọn dẹp
function ESP.ClearAll()
    ESP.StopAll()
end

if _G.UI and _G.UI.addStopHandler then
    _G.UI.addStopHandler(function()
        clearTeleportButtonsFromGui()
        ESP.ClearAll()
    end)
end

--------------------------------------------------
-- HỆ THỐNG TRACKER (Hỗ trợ Đệ quy)
--------------------------------------------------

local function CreateTracker(name, getFolderFunc, color, validateFunc, isScrap)
    local tracker = {
        Enabled = false,
        ActiveConnections = {},
        TrackedObjects = {},
        Options = {
            Highlight = false,
            Text = false,
            TP = false,
        }
    }
    ESP.Trackers[name] = tracker

    local function recursiveTrack(parentFolder, onObjectFound)
        if not ESP.Enabled or not tracker.Enabled then return end

        for _, child in ipairs(parentFolder:GetChildren()) do
            if not ESP.Enabled or not tracker.Enabled then return end

            if child:IsA("Folder") or child:IsA("Configuration") then
                recursiveTrack(child, onObjectFound)
            else
                onObjectFound(child)
            end
        end

        local conn = parentFolder.ChildAdded:Connect(function(child)
            if not ESP.Enabled or not tracker.Enabled then return end

            task.wait(0.1)

            if not ESP.Enabled or not tracker.Enabled then return end

            if child:IsA("Folder") or child:IsA("Configuration") then
                recursiveTrack(child, onObjectFound)
            else
                onObjectFound(child)
            end
        end)

        table.insert(tracker.ActiveConnections, conn)
    end

    local function stopTracker()
        tracker.Enabled = false

        for _, conn in ipairs(tracker.ActiveConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(tracker.ActiveConnections)

        for _, obj in ipairs(tracker.TrackedObjects) do
            ESP.Remove(obj)
        end
        table.clear(tracker.TrackedObjects)
    end

    local function startTracker()
        if tracker.Enabled then
            return
        end
        if not ESP.Enabled then
            return
        end

        tracker.Enabled = true
        local root = getFolderFunc()
        if not root then
            tracker.Enabled = false
            return
        end

        recursiveTrack(root, function(child)
            if not ESP.Enabled or not tracker.Enabled then return end

            if not validateFunc or validateFunc(child) then
                ESP.Add(child, child.Name, color, isScrap, tracker.Options)
                table.insert(tracker.TrackedObjects, child)
            end
        end)
    end

    local function refreshTrackerState()
        local shouldEnable = tracker.Options.Highlight or tracker.Options.Text or tracker.Options.TP
        if shouldEnable then
            startTracker()
        else
            stopTracker()
        end
    end

    _G.UI.addEventHandler(name .. "_Highlight", function(toggle)
        tracker.Options.Highlight = toggle and true or false
        if tracker.Enabled then
            for _, obj in ipairs(tracker.TrackedObjects) do
                applyVisualOptionForObject(obj, "Highlight", tracker.Options.Highlight)
            end
        end
        refreshTrackerState()
    end)

    _G.UI.addEventHandler(name .. "_Text", function(toggle)
        tracker.Options.Text = toggle and true or false
        if tracker.Enabled then
            for _, obj in ipairs(tracker.TrackedObjects) do
                applyVisualOptionForObject(obj, "Text", tracker.Options.Text)
            end
        end
        refreshTrackerState()
    end)

    _G.UI.addEventHandler(name .. "_TP", function(toggle)
        tracker.Options.TP = toggle and true or false
        if tracker.Enabled then
            for _, obj in ipairs(tracker.TrackedObjects) do
                applyVisualOptionForObject(obj, "TP", tracker.Options.TP)
            end
        end
        refreshTrackerState()
    end)
end

--------------------------------------------------
-- ĐĂNG KÝ
--------------------------------------------------

CreateTracker("Entities", function()
    return workspace:FindFirstChild("Entities")
end, Color3.fromRGB(255, 50, 50))

CreateTracker("CaptureThePoint", function()
    return workspace:FindFirstChild("MapFolder") and workspace.MapFolder:FindFirstChild("Round")
end, Color3.fromRGB(0, 255, 0))

CreateTracker("Scrap", function()
    return workspace:FindFirstChild("Debris")
end, Color3.fromRGB(242, 125, 0), function(child)
    local adornee = resolveAdornee(child)
    return adornee and adornee.Transparency == 0 and adornee.Name == "Scrap"
end, true)

CreateTracker("NPC", function()
    return workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild("NPC")
end, Color3.fromRGB(255, 0, 255))

CreateTracker("Player", function()
    return workspace:FindFirstChild("Characters") and workspace.Characters:FindFirstChild("Player")
end, Color3.fromRGB(50, 200, 255), function(child)
    return child:IsA("Model") and child.Name ~= Players.LocalPlayer.Name
end)
