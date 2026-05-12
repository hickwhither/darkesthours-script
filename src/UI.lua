local UI = _G.offlineservice("UI")

-- Services
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui") -- Dùng CoreGui để tránh bị xóa khi Reset/Clear log

-- Private State

UI.settings = {}
UI.handlers = {}
UI.stopHandlers = {}
UI.buttonCount = 0
UI._connections = {}
UI.buttonMeta = {}
UI.activeCategory = "Movement"

-- References
local screenGui, mainFrame, scrollingFrame

----------------------------------------------------------------
-- CÔNG CỤ TẠO NHANH (INTERNAL)
----------------------------------------------------------------

local function create(className, properties)
    local inst = Instance.new(className)
    for k, v in pairs(properties) do
        inst[k] = v
    end
    return inst
end

----------------------------------------------------------------
-- PHƯƠNG THỨC PUBLIC
----------------------------------------------------------------

-- Đăng ký sự kiện khi nhấn nút
function UI.addEventHandler(name, fn)
    if type(fn) ~= "function" then return end
    UI.handlers[name] = UI.handlers[name] or {}
    table.insert(UI.handlers[name], fn)
end

-- Đăng ký hành động khi dừng script
function UI.addStopHandler(fn)
    if type(fn) ~= "function" then return end
    table.insert(UI.stopHandlers, fn)
end

-- Hàm tạo nút chính
local function refreshButtonVisibility()
    for _, meta in pairs(UI.buttonMeta) do
        meta.button.Visible = meta.category == UI.activeCategory
    end
end

function UI.createButton(name, isToggle, defaultColor, category, defaultState)
    if UI.settings[name] ~= nil then return end -- Tránh tạo trùng

    UI.buttonCount = UI.buttonCount + 1 -- Tăng số thứ tự mỗi khi tạo nút mới
    category = category or "General"
    
    -- Khởi tạo trạng thái nếu là toggle
    if isToggle then UI.settings[name] = defaultState == true end

    local function getDisplayText()
        if isToggle then
            return name .. ": " .. (UI.settings[name] and "ON" or "OFF")
        end
        return name
    end

    local function getBtnColor()
        if isToggle and UI.settings[name] then
            return Color3.fromRGB(46, 204, 113) -- Xanh lá khi bật
        end
        return defaultColor or Color3.fromRGB(45, 45, 45)
    end

    local btn = create("TextButton", {
        Name = name,
        Parent = scrollingFrame,
        Size = UDim2.new(1, -10, 0, 32),
        BackgroundColor3 = getBtnColor(),
        BorderSizePixel = 0,
        Text = getDisplayText(),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        AutoButtonColor = true,
        LayoutOrder = UI.buttonCount
    })

    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
    create("UIStroke", { 
        Thickness = 1, 
        Color = Color3.new(1, 1, 1), 
        Transparency = 0.8, 
        Parent = btn 
    })

    btn.MouseButton1Click:Connect(function()
        if isToggle then
            UI.settings[name] = not UI.settings[name]
            btn.Text = getDisplayText()
            btn.BackgroundColor3 = getBtnColor()
        end

        -- Kích hoạt các handler
        local list = UI.handlers[name]
        if list then
            for _, fn in ipairs(list) do
                task.spawn(pcall, fn, UI.settings[name])
            end
        end
    end)

    UI.buttonMeta[name] = {
        button = btn,
        category = category
    }

    refreshButtonVisibility()
    return btn
end

function UI.createESPOptionRow(baseName, category)
    category = category or "ESP"

    UI.buttonCount = UI.buttonCount + 1
    local rowOrder = UI.buttonCount

    local row = create("Frame", {
        Name = baseName .. "_OptionsRow",
        Parent = scrollingFrame,
        Size = UDim2.new(1, -10, 0, 32),
        BackgroundTransparency = 1,
        LayoutOrder = rowOrder
    })

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = row
    })

    local function createInlineToggle(buttonName, label, defaultState)
        UI.settings[buttonName] = defaultState == true

        local function getBtnColor()
            if UI.settings[buttonName] then
                return Color3.fromRGB(46, 204, 113)
            end
            return Color3.fromRGB(45, 45, 45)
        end

        local width = math.clamp(22 + (#label * 6), 40, 140)

        local btn = create("TextButton", {
            Name = buttonName,
            Parent = row,
            Size = UDim2.new(0, width, 1, 0),
            BackgroundColor3 = getBtnColor(),
            BorderSizePixel = 0,
            Text = label,
            TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            AutoButtonColor = true,
        })

        create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
        create("UIStroke", {
            Thickness = 1,
            Color = Color3.new(1, 1, 1),
            Transparency = 0.8,
            Parent = btn
        })

        btn.MouseButton1Click:Connect(function()
            UI.settings[buttonName] = not UI.settings[buttonName]
            btn.Text = label
            btn.BackgroundColor3 = getBtnColor()

            local list = UI.handlers[buttonName]
            if list then
                for _, fn in ipairs(list) do
                    task.spawn(pcall, fn, UI.settings[buttonName])
                end
            end
        end)
    end

    createInlineToggle(baseName .. "_Highlight", baseName, false)
    createInlineToggle(baseName .. "_TP", "TP", false)
    createInlineToggle(baseName .. "_Line", "LINE", false)

    UI.buttonMeta[row.Name] = {
        button = row,
        category = category
    }

    refreshButtonVisibility()
    return row
end

-- Dừng toàn bộ script
local function stopScript()
    for _, fn in ipairs(UI.stopHandlers) do task.spawn(pcall, fn) end
    for _, conn in ipairs(UI._connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(UI._connections)
    if screenGui then screenGui:Destroy() end
    _G.running = false
end

-- Đóng/Mở UI
local function toggleUI()
    mainFrame.Visible = not mainFrame.Visible
end

----------------------------------------------------------------
-- KHỞI TẠO GIAO DIỆN
----------------------------------------------------------------

screenGui = create("ScreenGui", {
    Name = "Internal_UI",
    ResetOnSpawn = false,
    Parent = CoreGui
})

mainFrame = create("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 250, 0, 320),
    Position = UDim2.new(1, -270, 0.5, -160),
    BackgroundColor3 = Color3.fromRGB(25, 25, 25),
    Active = true,
    Draggable = true,
    Parent = screenGui
})

create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = mainFrame })
create("UIStroke", { Thickness = 2, Color = Color3.fromRGB(60, 60, 60), Parent = mainFrame })

local title = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 40),
    Text = "INTERNAL CONTROL",
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    Parent = mainFrame
})

scrollingFrame = create("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -135),
    Position = UDim2.new(0, 10, 0, 80),
    BackgroundTransparency = 1,
    ScrollBarThickness = 2,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = mainFrame
})

create("UIListLayout", {
    Padding = UDim.new(0, 6),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = scrollingFrame
})

local navBar = create("Frame", {
    Size = UDim2.new(1, -20, 0, 30),
    Position = UDim2.new(0, 10, 0, 45),
    BackgroundTransparency = 1,
    Parent = mainFrame
})

create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 6),
    Parent = navBar
})

local categoryButtons = {}
local categories = { "Movement", "Visual", "ESP" }

local function updateCategoryButtonStyles()
    for categoryName, button in pairs(categoryButtons) do
        local selected = categoryName == UI.activeCategory
        button.BackgroundColor3 = selected
            and Color3.fromRGB(46, 204, 113)
            or Color3.fromRGB(45, 45, 45)
    end
end

for _, categoryName in ipairs(categories) do
    local categoryBtn = create("TextButton", {
        Name = "Category_" .. categoryName,
        Size = UDim2.new(0, 70, 1, 0),
        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
        BorderSizePixel = 0,
        Text = categoryName,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        Parent = navBar
    })

    create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = categoryBtn })
    categoryBtn.MouseButton1Click:Connect(function()
        UI.activeCategory = categoryName
        updateCategoryButtonStyles()
        refreshButtonVisibility()
    end)

    categoryButtons[categoryName] = categoryBtn
end

updateCategoryButtonStyles()

-- Nút Stop phía dưới cùng
local stopBtn = create("TextButton", {
    Size = UDim2.new(1, -20, 0, 35),
    Position = UDim2.new(0, 10, 1, -45),
    BackgroundColor3 = Color3.fromRGB(150, 40, 40),
    Text = "STOP SCRIPT",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Parent = mainFrame
})
create("UICorner", { Parent = stopBtn })
stopBtn.MouseButton1Click:Connect(stopScript)

----------------------------------------------------------------
-- TẠO CÁC NÚT THEO YÊU CẦU
----------------------------------------------------------------

UI.createButton("Flight", true, nil, "Movement")
UI.createButton("Noclip", true, nil, "Movement")
UI.createButton("Speed", true, nil, "Movement")
UI.createButton("ClickTP", true, nil, "Movement")

UI.createButton("Fullbright", true, nil, "Visual")
UI.createButton("NoFog", true, nil, "Visual")

UI.createESPOptionRow("CaptureThePoint", "ESP")
UI.createESPOptionRow("Scrap", "ESP")
UI.createESPOptionRow("Entities", "ESP")
UI.createESPOptionRow("NPC", "ESP")
UI.createESPOptionRow("Player", "ESP")

----------------------------------------------------------------
-- PHÍM TẮT
----------------------------------------------------------------

table.insert(UI._connections, UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Backquote then
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            stopScript()
        else
            toggleUI()
        end
    end
end))

print("✅ UI Loaded: [Backquote] để ẩn/hiện, [Ctrl + Backquote] để dừng.")
