-- tracker.lua
-- Globals to set before loading:
--   _G.groupId    = <number>
--   _G.groupName  = <string>
--   _G.minRank    = <number>

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContextAS    = game:GetService("ContextActionService")
local HttpService  = game:GetService("HttpService")
local UserInput    = game:GetService("UserInputService")

-- Main ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name        = "GroupTracker"
gui.ResetOnSpawn = false
gui.Parent      = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Utility to make rounded frames
local function makeFrame(size, pos, parent)
    local f = Instance.new("Frame", parent)
    f.Size               = size
    f.Position           = pos
    f.AnchorPoint        = Vector2.new(0.5, 0.5)
    f.BackgroundColor3   = Color3.fromRGB(30, 30, 30)
    f.BackgroundTransparency = 0.1
    local uc = Instance.new("UICorner", f)
    uc.CornerRadius = UDim.new(0, 12)
    return f
end

-- 1) Sliding Notification
local function notify(title, body)
    local nf = makeFrame(UDim2.new(0, 450, 0, 120), UDim2.new(0.5, 0, -0.5, 0), gui)
    -- Title
    local titleLbl = Instance.new("TextLabel", nf)
    titleLbl.Size               = UDim2.new(1, -40, 0, 30)
    titleLbl.Position           = UDim2.new(0, 20, 0, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font               = Enum.Font.SourceSansBold
    titleLbl.TextSize           = 24
    titleLbl.TextColor3         = Color3.new(1, 1, 1)
    titleLbl.Text               = title
    titleLbl.TextXAlignment     = Enum.TextXAlignment.Left

    -- Body
    local bodyLbl = Instance.new("TextLabel", nf)
    bodyLbl.Size               = UDim2.new(1, -40, 1, -60)
    bodyLbl.Position           = UDim2.new(0, 20, 0, 50)
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Font               = Enum.Font.SourceSans
    bodyLbl.TextSize           = 18
    bodyLbl.TextColor3         = Color3.new(1, 1, 1)
    bodyLbl.TextWrapped        = true
    bodyLbl.Text               = body
    bodyLbl.TextXAlignment     = Enum.TextXAlignment.Left

    -- OK Button
    local okBtn = Instance.new("TextButton", nf)
    okBtn.Size               = UDim2.new(0, 60, 0, 30)
    okBtn.Position           = UDim2.new(1, -70, 1, -40)
    okBtn.Text               = "OK"
    okBtn.Font               = Enum.Font.SourceSansBold
    okBtn.TextSize           = 18
    okBtn.BackgroundColor3   = Color3.fromRGB(50, 50, 50)
    okBtn.BorderSizePixel    = 0
    local okCorner = Instance.new("UICorner", okBtn)
    okCorner.CornerRadius = UDim.new(0, 8)
    okBtn.MouseButton1Click:Connect(function()
        TweenService:Create(nf, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, -0.5, 0)
        }):Play():Completed:Wait()
        nf:Destroy()
    end)

    -- Slide In
    TweenService:Create(nf, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.2, 0)
    }):Play()
end

-- Helper: check if player should be tracked
local function isWatcher(plr)
    if not plr:IsInGroup(_G.groupId) then return false end
    local rankNum = plr:GetRankInGroup(_G.groupId)
    if rankNum < (_G.minRank or 0) then return false end
    return true, rankNum, plr:GetRoleInGroup(_G.groupId)
end

-- Initial “who’s here” notification
do
    local present = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, rankNum, roleName = isWatcher(plr)
        if ok then
            table.insert(present, string.format("%s (%s #%d)", plr.Name, roleName, rankNum))
        end
    end
    if #present > 0 then
        notify((_G.groupName or "Group").." Online",
               ("Present: %d\n%s"):format(#present, table.concat(present, "\n")))
    end
end

-- Live join alerts
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Wait()
    local ok, rankNum, roleName = isWatcher(plr)
    if ok then
        notify((_G.groupName or "Group").." Joined",
               string.format("%s (%s #%d) has joined!", plr.Name, roleName, rankNum))
    end
end)

-- 2) Status Panel

-- Panel frame
local panel = makeFrame(UDim2.new(0, 360, 0, 500), UDim2.new(0.5, 0, 0.5, 0), gui)
panel.Visible = false

-- Draggable setup
do
    local dragging, dragInput, dragStart, startPos
    panel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    panel.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInput.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Build panel contents
local function buildPanel()
    -- Clear old entries
    for _, child in ipairs(panel:GetChildren()) do
        if child.Name == "Entry" or child:IsA("ScrollingFrame") or child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    -- Close button
    local closeBtn = Instance.new("TextButton", panel)
    closeBtn.Name  = "Close"
    closeBtn.Size  = UDim2.new(0, 24, 0, 24)
    closeBtn.Position = UDim2.new(1, -30, 0, 6)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font  = Enum.Font.SourceSansBold
    closeBtn.Text  = "✕"
    closeBtn.TextColor3 = Color3.new(1, 0.5, 0.5)
    closeBtn.TextSize = 18
    closeBtn.MouseButton1Click:Connect(function()
        panel.Visible = false
    end)

    -- Title
    local title = Instance.new("TextLabel", panel)
    title.Size  = UDim2.new(1, -40, 0, 30)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Text = (_G.groupName or "Group").." Status"

    -- ScrollingFrame
    local scroll = Instance.new("ScrollingFrame", panel)
    scroll.Name                 = "Scroll"
    scroll.Size                 = UDim2.new(1, -20, 1, -60)
    scroll.Position             = UDim2.new(0, 10, 0, 40)
    scroll.BackgroundTransparency= 1
    scroll.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    scroll.ScrollBarImageTransparency = 0.5

    local layout = Instance.new("UIListLayout", scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, 6)

    -- Fetch and categorize via Groups API
    local members = {}
    local cursor
    repeat
        local url = ("https://groups.roblox.com/v1/groups/%d/users?limit=100%s")
            :format(_G.groupId, cursor and "&cursor="..cursor or "")
        local res  = game:HttpGet(url, true)
        local data = HttpService:JSONDecode(res)
        for _, m in ipairs(data.data) do
            table.insert(members, m)
        end
        cursor = data.nextPageCursor
    until not cursor

    -- Organize by role name
    local categories = {}
    for _, m in ipairs(members) do
        local role = m.role.name
        categories[role] = categories[role] or {}
        table.insert(categories[role], m)
    end

    -- Populate entries
    local order = 1
    for role, tbl in pairs(categories) do
        -- Category header
        local hdr = Instance.new("TextLabel", scroll)
        hdr.Name        = "Entry"
        hdr.LayoutOrder = order
        order = order + 1
        hdr.Size        = UDim2.new(1, 0, 0, 30)
        hdr.BackgroundTransparency = 1
        hdr.Font        = Enum.Font.SourceSansBold
        hdr.TextSize    = 18
        hdr.TextColor3  = Color3.new(0.8, 0.8, 1)
        hdr.Text        = role

        -- Each member
        for _, m in ipairs(tbl) do
            local frm = Instance.new("Frame", scroll)
            frm.Name        = "Entry"
            frm.LayoutOrder = order
            order = order + 1
            frm.Size        = UDim2.new(1, 0, 0, 40)
            frm.BackgroundTransparency = 0.2
            local uc = Instance.new("UICorner", frm)
            uc.CornerRadius = UDim.new(0, 6)

            -- Text label
            local lbl = Instance.new("TextLabel", frm)
            lbl.Size               = UDim2.new(0.8, -10, 1, 0)
            lbl.Position           = UDim2.new(0, 10, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font               = Enum.Font.SourceSans
            lbl.TextSize           = 16
            lbl.TextColor3         = Color3.new(1, 1, 1)
            lbl.Text               = ("%s [%d]"):format(m.user.username, m.user.id)

            -- Status icon
            local icon = Instance.new("TextLabel", frm)
            icon.Size               = UDim2.new(0, 24, 0, 24)
            icon.Position           = UDim2.new(1, -34, 0, 8)
            icon.BackgroundTransparency = 1
            icon.Font               = Enum.Font.SourceSansBold
            icon.TextSize           = 24

            local plrObj = Players:GetPlayerByUserId(m.user.id)
            if plrObj then
                icon.TextColor3 = Color3.new(0, 1, 0) -- online in game
                icon.Text       = "🟢"
            else
                icon.TextColor3 = Color3.new(0.5, 0.5, 0.5) -- offline
                icon.Text       = "⚪"
            end
        end
    end
end

-- Toggle panel with K
ContextAS:BindAction("ToggleStatus", function(_, state)
    if state == Enum.UserInputState.Begin then
        panel.Visible = not panel.Visible
        if panel.Visible then
            buildPanel()
            -- Slide in from top
            panel.Position = UDim2.new(0.5, 0, -0.5, 0)
            TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.5, 0)
            }):Play()
        else
            -- Slide out to top
            TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, -0.5, 0)
            }):Play():Completed:Wait()
        end
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.K)
