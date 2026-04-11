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
function UI.createButton(name, isToggle, defaultColor)
    if UI.settings[name] ~= nil then return end -- Tránh tạo trùng

    UI.buttonCount = UI.buttonCount + 1 -- Tăng số thứ tự mỗi khi tạo nút mới
    
    -- Khởi tạo trạng thái nếu là toggle
    if isToggle then UI.settings[name] = false end

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

    return btn
end

-- Dừng toàn bộ script
local function stopScript()
    _G.running = false
    for _, fn in ipairs(UI.stopHandlers) do task.spawn(pcall, fn) end
    if screenGui then screenGui:Destroy() end
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
    Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
})

mainFrame = create("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 220, 0, 320),
    Position = UDim2.new(1, -240, 0.5, -160),
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
    Size = UDim2.new(1, -20, 1, -100),
    Position = UDim2.new(0, 10, 0, 45),
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

UI.createButton("Flight", true)
UI.createButton("Fullbright", true)
UI.createButton("CaptureThePoint", true)
UI.createButton("Scrap", true)
UI.createButton("Entities", true)
UI.createButton("NPC", true)
UI.createButton("Player", true)

----------------------------------------------------------------
-- PHÍM TẮT
----------------------------------------------------------------

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Backquote then
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            stopScript()
        else
            toggleUI()
        end
    end
end)

print("✅ UI Loaded: [Backquote] để ẩn/hiện, [Ctrl + Backquote] để dừng.")

