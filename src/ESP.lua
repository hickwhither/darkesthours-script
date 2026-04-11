local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ESP = {
    Objects = {},
    Connections = {},
    Trackers = {},
    Enabled = true,
}

-- Hàm xác định Part để gắn ESP
local function resolveAdornee(target)
    if target:IsA("BasePart") then return target end
    if target:IsA("Model") then
        return target.PrimaryPart
            or target:FindFirstChild("ProxyPart")
            or target:FindFirstChildWhichIsA("BasePart")
    end
end

-- Thêm ESP
function ESP.Add(obj, text, color, transparencyCheck)
    if not ESP.Enabled then return end
    if not obj or ESP.Objects[obj] then return end

    local adornee = resolveAdornee(obj)
    if not adornee then return end

    local visuals = {}

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_Tag"
    bb.Adornee = adornee
    bb.Size = UDim2.new(0, 200, 0, 40)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = obj

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0.5
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.Parent = bb
    visuals.Billboard = bb

    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.FillTransparency = 0.7
    hl.OutlineColor = color
    hl.Adornee = obj
    hl.Parent = obj
    visuals.Highlight = hl

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
end

-- Xóa ESP
function ESP.Remove(obj)
    if ESP.Objects[obj] then
        pcall(function() ESP.Objects[obj].Billboard:Destroy() end)
        pcall(function() ESP.Objects[obj].Highlight:Destroy() end)
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
end

-- Dọn dẹp
function ESP.ClearAll()
    ESP.StopAll()
end

if _G.UI and _G.UI.addStopHandler then
    _G.UI.addStopHandler(function()
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

    _G.UI.addEventHandler(name, function(toggle)
        if not ESP.Enabled and toggle then
            return
        end

        if toggle then
            tracker.Enabled = true
            local root = getFolderFunc()
            if not root then return end

            recursiveTrack(root, function(child)
                if not ESP.Enabled or not tracker.Enabled then return end

                if not validateFunc or validateFunc(child) then
                    ESP.Add(child, child.Name, color, isScrap)
                    table.insert(tracker.TrackedObjects, child)
                end
            end)
        else
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
end, Color3.fromRGB(200, 200, 200), function(child)
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