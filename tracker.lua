-- tracker.lua
-- Globals expected before loading:
--   _G.groupId    = <number>  -- your group (e.g. 32704720)
--   _G.groupName  = <string>  -- label (e.g. "My Team")
--   _G.minRank    = <number>  -- only include players at or above this rank

-- Services
local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local ContextActionSvc   = game:GetService("ContextActionService")

-- Main GUI container
local screenGui = Instance.new("ScreenGui")
screenGui.Name   = "GroupTracker"
screenGui.ResetOnSpawn = false
screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Utility: create rounded frame
local function makeRoundedFrame(parent, size, pos)
    local f = Instance.new("Frame")
    f.Size               = size
    f.Position           = pos
    f.BackgroundColor3   = Color3.fromRGB(30, 30, 30)
    f.BackgroundTransparency = 0.1
    f.AnchorPoint        = Vector2.new(0.5, 0)
    f.Parent             = parent

    local corner = Instance.new("UICorner")  -- smooth edges :contentReference[oaicite:5]{index=5}
    corner.CornerRadius   = UDim.new(0, 12)
    corner.Parent         = f

    return f
end

-- 1️⃣ Sliding Notification (persistent until X clicked)
local function showNotification(title, body)
    -- build
    local notif = makeRoundedFrame(screenGui, UDim2.new(0, 400, 0, 100), UDim2.new(0.5, 0, 0, -120))
    notif.ZIndex    = 10

    -- Title
    local tLab = Instance.new("TextLabel")
    tLab.Size              = UDim2.new(1, -40, 0, 30)
    tLab.Position          = UDim2.new(0, 20, 0, 10)
    tLab.BackgroundTransparency = 1
    tLab.Font              = Enum.Font.SourceSansBold
    tLab.TextSize          = 22
    tLab.TextColor3        = Color3.new(1,1,1)
    tLab.Text              = title
    tLab.TextXAlignment    = Enum.TextXAlignment.Left
    tLab.Parent            = notif

    -- Body
    local bLab = Instance.new("TextLabel")
    bLab.Size              = UDim2.new(1, -40, 1, -50)
    bLab.Position          = UDim2.new(0, 20, 0, 45)
    bLab.BackgroundTransparency = 1
    bLab.Font              = Enum.Font.SourceSans
    bLab.TextSize          = 16
    bLab.TextColor3        = Color3.new(1,1,1)
    bLab.TextWrapped       = true
    bLab.Text              = body
    bLab.TextXAlignment    = Enum.TextXAlignment.Left
    bLab.Parent            = notif

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size          = UDim2.new(0, 24, 0, 24)
    closeBtn.Position      = UDim2.new(1, -30, 0, 6)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font          = Enum.Font.SourceSansBold
    closeBtn.TextSize      = 18
    closeBtn.TextColor3    = Color3.new(1,0.3,0.3)
    closeBtn.Text          = "✕"
    closeBtn.Parent        = notif
    closeBtn.MouseButton1Click:Connect(function()
        notif:Destroy()
    end)

    -- slide in
    notif.Position = UDim2.new(0.5, 0, 0, -120)
    TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 20)
    }):Play()  -- smooth slide :contentReference[oaicite:6]{index=6}
end

-- Helper: determine watch criteria
local function isWatcher(plr)
    if not plr:IsInGroup(_G.groupId) then return false end
    local rankN = plr:GetRankInGroup(_G.groupId)
    if rankN < (_G.minRank or 0) then return false end
    return true, rankN, plr:GetRoleInGroup(_G.groupId)
end

-- Initial scan + notification
do
    local found = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, rankN, role = isWatcher(plr)
        if ok then
            table.insert(found, string.format("%s (%s #%d)", plr.Name, role, rankN))
        end
    end
    if #found>0 then
        showNotification(
            (_G.groupName or "Group").." Online",
            string.format("%d present:\n%s", #found, table.concat(found, "\n "))
        )
    end
end

-- Live join alerts
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Wait()
    local ok, rankN, role = isWatcher(plr)
    if ok then
        showNotification(
            (_G.groupName or "Group").." Joined",
            string.format("%s (%s #%d) has joined!", plr.Name, role, rankN)
        )
    end
end)

-- 2️⃣ Status Panel (toggle with K)
local panelOpen = false
local panel = makeRoundedFrame(screenGui, UDim2.new(0, 300, 0, 400), UDim2.new(0, 10, 0, 60))
panel.Visible = false

-- Close X for panel
local pClose = Instance.new("TextButton", panel)
pClose.Size = UDim2.new(0, 24, 0, 24)
pClose.Position = UDim2.new(1, -30, 0, 6)
pClose.BackgroundTransparency = 1
pClose.Font = Enum.Font.SourceSansBold
pClose.TextSize = 18
pClose.TextColor3 = Color3.new(1,0.3,0.3)
pClose.Text = "✕"
pClose.MouseButton1Click:Connect(function()
    panel.Visible = false
    panelOpen = false
end)

-- Title
local pTitle = Instance.new("TextLabel", panel)
pTitle.Size, pTitle.Position = UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 0, 10)
pTitle.BackgroundTransparency, pTitle.Font, pTitle.TextSize = 1, Enum.Font.SourceSansBold, 20
pTitle.TextColor3, pTitle.Text = Color3.new(1,1,1), (_G.groupName or "Group").." Status"

-- ScrollingFrame + auto-size children :contentReference[oaicite:7]{index=7}
local scroll = Instance.new("ScrollingFrame", panel)
scroll.Size, scroll.Position = UDim2.new(1, -20, 1, -60), UDim2.new(0, 10, 0, 50)
scroll.BackgroundTransparency, scroll.CanvasSize = 1, UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y  -- auto-resize content :contentReference[oaicite:8]{index=8}
scroll.ScrollBarImageTransparency = 0.5

local layout = Instance.new("UIListLayout", scroll)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)  -- spacing :contentReference[oaicite:9]{index=9}

-- Populate panel entries
local function updatePanel()
    -- clear old
    for _,c in ipairs(scroll:GetChildren()) do
        if c.Name=="Entry" then c:Destroy() end
    end

    local order = 1
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, rankN, role = isWatcher(plr)
        if ok then
            local entry = Instance.new("Frame")
            entry.Name, entry.Parent = "Entry", scroll
            entry.Size = UDim2.new(1, 0, 0, 36)
            entry.LayoutOrder = order
            order += 1
            -- bg & rounding
            entry.BackgroundTransparency = 0
            entry.BackgroundColor3 = Color3.fromRGB(50,50,50)
            local corn = Instance.new("UICorner", entry)
            corn.CornerRadius = UDim.new(0,6)

            -- text
            local t = Instance.new("TextLabel", entry)
            t.Size, t.Position = UDim2.new(0.7, -10, 1, 0), UDim2.new(0, 10, 0, 0)
            t.BackgroundTransparency, t.Font, t.TextSize = 1, Enum.Font.SourceSans, 16
            t.TextColor3 = Color3.new(1,1,1)
            t.Text = string.format("%s  [%d]\n%s #%d", plr.Name, plr.UserId, role, rankN)

            -- status icon (in-game = green ●)
            local icon = Instance.new("TextLabel", entry)
            icon.Size, icon.Position = UDim2.new(0, 24, 0, 24), UDim2.new(1, -34, 0, 6)
            icon.BackgroundTransparency, icon.Font, icon.TextSize = 1, Enum.Font.SourceSansBold, 24
            icon.TextColor3 = Color3.new(0.3,1,0.3)
            icon.Text = "●"
        end
    end
end

-- Keybind to toggle panel (K) :contentReference[oaicite:10]{index=10}
ContextActionSvc:BindAction("TogglePanel", function(name, state)
    if state==Enum.UserInputState.Begin then
        panelOpen = not panelOpen
        panel.Visible = panelOpen
        if panelOpen then updatePanel() end
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.K)

-- Also update panel live on join/leave
Players.PlayerAdded:Connect(function() if panelOpen then updatePanel() end end)
Players.PlayerRemoving:Connect(function() if panelOpen then updatePanel() end end)
