-- tracker.lua
-- Globals (set before loading):
--   _G.groupId    = <number>
--   _G.groupName  = <string>
--   _G.minRank    = <number>

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContextAS    = game:GetService("ContextActionService")
local HttpService  = game:GetService("HttpService")
local UserInput    = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

-- Main GUI container
local gui = Instance.new("ScreenGui")
gui.Name        = "GroupTracker"
gui.ResetOnSpawn = false
gui.Parent      = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Utility: create a rounded frame
local function makeFrame(parent, size, pos)
    local f = Instance.new("Frame", parent)
    f.Size               = size
    f.Position           = pos
    f.AnchorPoint        = Vector2.new(0.5, 0.5)
    f.BackgroundColor3   = Color3.fromRGB(30, 30, 30)
    f.BackgroundTransparency = 0.1
    local uc = Instance.new("UICorner", f)
    uc.CornerRadius      = UDim.new(0, 12)
    return f
end

-- Play a subtle ping sound
local function playPing()
    local sound = Instance.new("Sound", SoundService)
    sound.SoundId = "rbxassetid://142376088"
    sound.Volume  = 0.5
    sound:Play()
    game.Debris:AddItem(sound, 2)
end

-- 1) Sliding, persistent toast
local function showNotification(title, body)
    local nf = makeFrame(gui, UDim2.new(0, 320, 0, 100), UDim2.new(0.5, 0, -0.4, 0))
    -- timestamp
    local ts = os.date("%H:%M:%S")
    -- title label
    local t = Instance.new("TextLabel", nf)
    t.Size               = UDim2.new(1, -20, 0, 24)
    t.Position           = UDim2.new(0, 10, 0, 8)
    t.BackgroundTransparency = 1
    t.Font               = Enum.Font.SourceSansBold
    t.TextSize           = 20
    t.TextColor3         = Color3.new(1, 1, 1)
    t.Text               = ("[%s] %s"):format(ts, title)
    t.TextXAlignment     = Enum.TextXAlignment.Left
    -- body label
    local b = Instance.new("TextLabel", nf)
    b.Size               = UDim2.new(1, -20, 1, -60)
    b.Position           = UDim2.new(0, 10, 0, 40)
    b.BackgroundTransparency = 1
    b.Font               = Enum.Font.SourceSans
    b.TextSize           = 16
    b.TextColor3         = Color3.new(1, 1, 1)
    b.TextWrapped        = true
    b.TextXAlignment     = Enum.TextXAlignment.Left
    b.Text               = body
    -- OK button
    local ok = Instance.new("TextButton", nf)
    ok.Size               = UDim2.new(0, 60, 0, 28)
    ok.Position           = UDim2.new(1, -70, 1, -36)
    ok.Text               = "OK"
    ok.Font               = Enum.Font.SourceSansBold
    ok.TextSize           = 16
    ok.BackgroundColor3   = Color3.fromRGB(50, 50, 50)
    ok.BorderSizePixel    = 0
    local okc = Instance.new("UICorner", ok)
    okc.CornerRadius      = UDim.new(0, 6)
    ok.MouseButton1Click:Connect(function()
        TweenService:Create(nf, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, -0.4, 0)
        }):Play():Completed:Wait()
        nf:Destroy()
    end)
    -- slide in
    TweenService:Create(nf, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.18, 0)
    }):Play()
    playPing()
end

-- Check group membership and rank
local function isWatcher(plr)
    if not plr:IsInGroup(_G.groupId) then return false end
    local rank = plr:GetRankInGroup(_G.groupId)
    if rank < (_G.minRank or 0) then return false end
    return true, rank, plr:GetRoleInGroup(_G.groupId)
end

-- Initial “who’s here” toast
do
    local present = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local ok, r, role = isWatcher(p)
        if ok then
            table.insert(present, ("%s (%s #%d)"):format(p.Name, role, r))
        end
    end
    if #present > 0 then
        showNotification(
            (_G.groupName or "Group").." Online",
            ("%d present:\n%s"):format(#present, table.concat(present, "\n"))
        )
    end
end

-- Live join alerts
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Wait()
    local ok, r, role = isWatcher(p)
    if ok then
        showNotification(
            (_G.groupName or "Group").." Joined",
            ("%s (%s #%d) has joined!"):format(p.Name, role, r)
        )
    end
end)

-- 2) Draggable, toggleable status panel
local panel = makeFrame(gui, UDim2.new(0, 360, 0, 480), UDim2.new(0.5, 0, 0.5, 0))
panel.Visible = false

-- Drag logic
do
    local drag, startPos, startMouse
    panel.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            startMouse = i.Position
            startPos = panel.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    panel.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement then
            UserInput.InputChanged:Connect(function(mv)
                if drag and mv.UserInputType == Enum.UserInputType.MouseMovement then
                    local delta = mv.Position - startMouse
                    panel.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end
            end)
        end
    end)
end

-- Build panel contents
local function buildPanel()
    -- clear old
    for _,c in ipairs(panel:GetChildren()) do
        if c.Name == "Entry" or c:IsA("ScrollingFrame") or c:IsA("UIListLayout") then
            c:Destroy()
        end
    end
    -- Close button
    local close = Instance.new("TextButton", panel)
    close.Name, close.Size, close.Position = "Close", UDim2.new(0,24,0,24), UDim2.new(1, -30, 0, 6)
    close.BackgroundTransparency, close.Font, close.Text, close.TextSize = 1, Enum.Font.SourceSansBold, "✕", 18
    close.TextColor3 = Color3.new(1,0.5,0.5)
    close.MouseButton1Click:Connect(function() panel.Visible = false end)
    -- Title
    local title = Instance.new("TextLabel", panel)
    title.Size, title.Position = UDim2.new(1, -40, 0, 30), UDim2.new(0,20,0,0)
    title.BackgroundTransparency, title.Font, title.TextSize = 1, Enum.Font.SourceSansBold, 20
    title.TextColor3 = Color3.new(1,1,1)
    title.Text = (_G.groupName or "Group").." Members"
    title.TextXAlignment = Enum.TextXAlignment.Left
    -- ScrollingFrame
    local scroll = Instance.new("ScrollingFrame", panel)
    scroll.Size, scroll.Position = UDim2.new(1, -20, 1, -60), UDim2.new(0,10,0,40)
    scroll.BackgroundTransparency = 1
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarImageTransparency = 0.5
    local layout = Instance.new("UIListLayout", scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0,6)
    -- Fetch all group members
    local members, cursor = {}, nil
    repeat
        local url = ("https://groups.roblox.com/v1/groups/%d/users?limit=100%s")
            :format(_G.groupId, cursor and "&cursor="..cursor or "")
        local res  = game:HttpGet(url, true)
        local data = HttpService:JSONDecode(res)
        for _,m in ipairs(data.data) do table.insert(members, m) end
        cursor = data.nextPageCursor
    until not cursor
    -- Categorize and list
    local categories = {}
    for _, m in ipairs(members) do
        categories[m.role.name] = categories[m.role.name] or {}
        table.insert(categories[m.role.name], m)
    end
    local order = 1
    for roleName, tbl in pairs(categories) do
        -- Header
        local hdr = Instance.new("TextLabel", scroll)
        hdr.Name, hdr.LayoutOrder = "Entry", order; order += 1
        hdr.Size, hdr.BackgroundTransparency = UDim2.new(1, 0, 0, 28), 1
        hdr.Font, hdr.TextSize, hdr.TextColor3 = Enum.Font.SourceSansBold, 18, Color3.new(0.8,0.8,1)
        hdr.Text = roleName
        hdr.TextXAlignment = Enum.TextXAlignment.Left
        -- Entries
        for _, m in ipairs(tbl) do
            local ent = Instance.new("Frame", scroll)
            ent.Name, ent.LayoutOrder = "Entry", order; order += 1
            ent.Size, ent.BackgroundTransparency = UDim2.new(1, 0, 0, 36), 0.2
            local uc = Instance.new("UICorner", ent); uc.CornerRadius = UDim.new(0,6)
            -- Username & ID
            local lbl = Instance.new("TextLabel", ent)
            lbl.Size, lbl.Position = UDim2.new(0.75, 0, 1, 0), UDim2.new(0,8,0,0)
            lbl.BackgroundTransparency, lbl.Font, lbl.TextSize = 1, Enum.Font.SourceSans, 16
            lbl.TextColor3 = Color3.new(1,1,1)
            lbl.Text = ("%s [%d]"):format(m.user.username, m.user.id)
            -- Status icon
            local icon = Instance.new("TextLabel", ent)
            icon.Size               = UDim2.new(0,24,0,24)
            icon.Position           = UDim2.new(1, -32, 0, 6)
            icon.BackgroundTransparency = 1
            icon.Font               = Enum.Font.SourceSansBold
            icon.TextSize           = 24
            local online = Players:GetPlayerByUserId(m.user.id) ~= nil
            icon.TextColor3         = online and Color3.new(0,1,0) or Color3.new(0.6,0.6,0.6)
            icon.Text               = online and "🟢" or "⚪"
        end
    end
end

-- Toggle panel with L
ContextAS:BindAction("TogglePanel", function(_, state)
    if state == Enum.UserInputState.Begin then
        panel.Visible = not panel.Visible
        if panel.Visible then
            buildPanel()
            -- slide in
            panel.Position = UDim2.new(0.5, 0, -0.5, 0)
            TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.5, 0)
            }):Play()
        else
            -- slide out
            TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, -0.5, 0)
            }):Play():Completed:Wait()
        end
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.L)
