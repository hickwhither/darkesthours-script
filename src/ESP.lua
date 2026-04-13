local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local ESP = {
    Objects = {},
    Connections = {},
    Trackers = {},
    Enabled = true,
    RenderConnection = nil,
    MiddleClickConnection = nil,
    TPGui = nil,
}

local DEFAULT_FILL_TRANSPARENCY = 0.7
local DEFAULT_OUTLINE_TRANSPARENCY = 0

local function resolveAdornee(target)
    if target:IsA("BasePart") then return target end
    if target:IsA("Model") then
        return target.PrimaryPart
            or target:FindFirstChild("ProxyPart")
            or target:FindFirstChildWhichIsA("BasePart")
    end
end

local function ensureTPGui()
    if ESP.TPGui and ESP.TPGui.Parent then
        return ESP.TPGui
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ESP_TPLabels"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    ESP.TPGui = gui
    return gui
end

local function createTPLabel(adornee, text, color)
    local gui = ensureTPGui()
    if not gui or not adornee then
        return nil
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_TP"
    billboard.Size = UDim2.fromOffset(60, 20)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = adornee
    billboard.Enabled = false
    billboard.Parent = gui

    local text = Instance.new("TextLabel")
    text.Name = "Label"
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Text = text
    text.TextColor3 = color or Color3.new(1, 1, 1)
    text.TextStrokeTransparency = 0.35
    text.TextScaled = true
    text.Font = Enum.Font.GothamBold
    text.Parent = billboard

    return billboard
end

local function createLine(color)
    if not Drawing or not Drawing.new then
        return nil
    end

    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = color
    line.Thickness = 1.5
    line.Transparency = 1
    return line
end

local function getLocalOriginPart()
    local char = LocalPlayer and LocalPlayer.Character
    if not char then
        return nil
    end

    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Head")
        or char:FindFirstChildWhichIsA("BasePart")
end

local function updateLineForObject(obj, visuals)
    local line = visuals.Line
    local adornee = visuals.Adornee
    if not line then
        return
    end

    line.Visible = false

    if not ESP.Enabled or not visuals.Options.Line then
        return
    end

    if not obj:IsDescendantOf(workspace) or not adornee or not adornee:IsDescendantOf(workspace) then
        return
    end

    local camera = Workspace.CurrentCamera
    local originPart = getLocalOriginPart()
    if not camera or not originPart then
        return
    end

    local from, fromOnScreen = camera:WorldToViewportPoint(originPart.Position)
    local to, toOnScreen = camera:WorldToViewportPoint(adornee.Position)

    if fromOnScreen and toOnScreen and from.Z > 0 and to.Z > 0 then
        line.From = Vector2.new(from.X, from.Y)
        line.To = Vector2.new(to.X, to.Y)
        line.Visible = true
    end
end

local function updateTPLabelForObject(obj, visuals)
    local tpLabel = visuals.TPLabel
    local adornee = visuals.Adornee
    if not tpLabel then
        return
    end

    local canShow = ESP.Enabled
        and visuals.Options.TP
        and obj:IsDescendantOf(workspace)
        and adornee
        and adornee:IsDescendantOf(workspace)

    tpLabel.Adornee = adornee
    tpLabel.Enabled = canShow and true or false
end

local function updateAllVisuals()
    if not ESP.Enabled then return end

    for obj, visuals in pairs(ESP.Objects) do
        updateLineForObject(obj, visuals)
        updateTPLabelForObject(obj, visuals)
    end
end

local function ensureUpdater()
    if ESP.RenderConnection then
        return
    end

    ESP.RenderConnection = RunService.RenderStepped:Connect(updateAllVisuals)
end

local function tryTeleportByMouseTarget(targetPart)
    if not targetPart then
        return
    end

    for obj, visuals in pairs(ESP.Objects) do
        if visuals.Options.TP and obj:IsDescendantOf(workspace) then
            if targetPart == obj or targetPart:IsDescendantOf(obj) then
                _G.Utils.teleportToTarget(obj)
                return
            end
        end
    end
end

local function ensureMiddleClickTeleport()
    if ESP.MiddleClickConnection then
        return
    end

    ESP.MiddleClickConnection = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not ESP.Enabled then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseButton3 then
            return
        end

        local mouse = LocalPlayer:GetMouse()
        tryTeleportByMouseTarget(mouse and mouse.Target)
    end)
end

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
        TP = false,
        Line = false,
    }
    visuals.Line = createLine(color)
    visuals.TPLabel = createTPLabel(adornee, text, color)

    visuals.Highlight.Enabled = visuals.Options.Highlight

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

    ensureUpdater()
    ensureMiddleClickTeleport()
    updateLineForObject(obj, visuals)
    updateTPLabelForObject(obj, visuals)
end

local function applyVisualOptionForObject(obj, optionName, enabled)
    local visuals = ESP.Objects[obj]
    if not visuals then return end

    visuals.Options = visuals.Options or {}
    visuals.Options[optionName] = enabled and true or false

    if optionName == "Highlight" and visuals.Highlight then
        visuals.Highlight.Enabled = visuals.Options.Highlight
        return
    end

    if optionName == "TP" then
        updateTPLabelForObject(obj, visuals)
        return
    end

    if optionName == "Line" then
        updateLineForObject(obj, visuals)
        return
    end
end

function ESP.Remove(obj)
    if ESP.Objects[obj] then
        local visuals = ESP.Objects[obj]

        pcall(function() visuals.Highlight:Destroy() end)
        pcall(function()
            if visuals.Line then
                visuals.Line.Visible = false
                visuals.Line:Remove()
            end
        end)
        pcall(function()
            if visuals.TPLabel then
                visuals.TPLabel:Destroy()
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

    if ESP.RenderConnection then
        pcall(function() ESP.RenderConnection:Disconnect() end)
        ESP.RenderConnection = nil
    end

    if ESP.MiddleClickConnection then
        pcall(function() ESP.MiddleClickConnection:Disconnect() end)
        ESP.MiddleClickConnection = nil
    end

    if ESP.TPGui then
        pcall(function() ESP.TPGui:Destroy() end)
        ESP.TPGui = nil
    end
end

function ESP.ClearAll()
    ESP.StopAll()
end

if _G.UI and _G.UI.addStopHandler then
    _G.UI.addStopHandler(function()
        ESP.ClearAll()
    end)
end

local function CreateTracker(name, getFolderFunc, color, validateFunc, isScrap)
    local tracker = {
        Enabled = false,
        ActiveConnections = {},
        TrackedObjects = {},
        Options = {
            Highlight = false,
            TP = false,
            Line = false,
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
        if tracker.Enabled then return end
        if not ESP.Enabled then return end

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
        local shouldEnable = tracker.Options.Highlight or tracker.Options.TP or tracker.Options.Line
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

    _G.UI.addEventHandler(name .. "_TP", function(toggle)
        tracker.Options.TP = toggle and true or false
        if tracker.Enabled then
            for _, obj in ipairs(tracker.TrackedObjects) do
                applyVisualOptionForObject(obj, "TP", tracker.Options.TP)
            end
        end
        refreshTrackerState()
    end)

    _G.UI.addEventHandler(name .. "_Line", function(toggle)
        tracker.Options.Line = toggle and true or false
        if tracker.Enabled then
            for _, obj in ipairs(tracker.TrackedObjects) do
                applyVisualOptionForObject(obj, "Line", tracker.Options.Line)
            end
        end
        refreshTrackerState()
    end)
end

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
