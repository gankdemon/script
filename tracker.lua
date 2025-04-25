-- tracker.lua
-- Globals expected before loading:
--   _G.groupId    = <number>
--   _G.groupName  = <string>
--   _G.minRank    = <number>

local Players    = game:GetService("Players")
local TweenSvc   = game:GetService("TweenService")
local ContextAS  = game:GetService("ContextActionService")
local HttpSvc    = game:GetService("HttpService")
local UserInput  = game:GetService("UserInputService")

-- Create main ScreenGui
local gui = Instance.new("ScreenGui")
gui.Name = "GroupTracker"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Utility: rounded frames
local function makeFrame(size, pos, parent)
    local f = Instance.new("Frame", parent)
    f.Size, f.Position = size, pos
    f.AnchorPoint = Vector2.new(0.5,0.5)
    f.BackgroundColor3 = Color3.fromRGB(30,30,30)
    f.BackgroundTransparency = 0.1
    local uc = Instance.new("UICorner", f)
    uc.CornerRadius = UDim.new(0,12)
    return f
end

-- 1) Notification
local function notify(title, body)
    local nf = makeFrame(UDim2.new(0,450,0,120), UDim2.new(0.5,0,-0.5,0), gui)
    local titleLbl = Instance.new("TextLabel", nf)
    titleLbl.Size = UDim2.new(1,-40,0,30)
    titleLbl.Position = UDim2.new(0,20,0,10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.Font = Enum.Font.SourceSansBold
    titleLbl.TextSize = 24
    titleLbl.TextColor3 = Color3.new(1,1,1)
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local bodyLbl = Instance.new("TextLabel", nf)
    bodyLbl.Size = UDim2.new(1,-40,1,-60)
    bodyLbl.Position = UDim2.new(0,20,0,50)
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Text = body
    bodyLbl.Font = Enum.Font.SourceSans
    bodyLbl.TextSize = 18
    bodyLbl.TextColor3 = Color3.new(1,1,1)
    bodyLbl.TextWrapped = true
    bodyLbl.TextXAlignment = Enum.TextXAlignment.Left

    local okBtn = Instance.new("TextButton", nf)
    okBtn.Size = UDim2.new(0,60,0,30)
    okBtn.Position = UDim2.new(1,-70,1,-40)
    okBtn.Text = "OK"
    okBtn.Font = Enum.Font.SourceSansBold
    okBtn.TextSize = 18
    okBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    okBtn.BorderSizePixel = 0
    local okCorner = Instance.new("UICorner", okBtn)
    okCorner.CornerRadius = UDim.new(0,8)
    okBtn.MouseButton1Click:Connect(function()
        TweenSvc:Create(nf, TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
            Position = UDim2.new(0.5,0,-0.5,0)
        }):Play():Completed:Wait()
        nf:Destroy()
    end)

    -- Slide in
    TweenSvc:Create(nf, TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
        Position = UDim2.new(0.5,0,0.2,0)
    }):Play()
end

-- 2) Fetch all group members (paginated)
local function fetchGroupMembers()
    local members = {}
    local cursor = nil
    repeat
        local url = ("https://groups.roblox.com/v1/groups/%d/users?limit=100"):format(_G.groupId)
        if cursor then url = url .. "&cursor=" .. cursor end
        local res = HttpSvc:GetAsync(url)
        local data = HttpSvc:JSONDecode(res)
        for _,m in ipairs(data.data) do
            table.insert(members, m)
        end
        cursor = data.nextPageCursor
    until not cursor
    return members
end

-- 3) Status Panel
local panel = makeFrame(UDim2.new(0,360,0,500), UDim2.new(0.5,0,0.5,0), gui)
panel.Visible = false

-- make draggable :contentReference[oaicite:10]{index=10}
do
    local dragging, dragInput, dragStart, startPos
    panel.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = inp.Position
            startPos = panel.Position
            inp.Changed:Connect(function()
                if inp.UserInputState==Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    panel.InputChanged:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseMovement then
            dragInput = inp
        end
    end)
    UserInput.InputChanged:Connect(function(inp)
        if inp==dragInput and dragging then
            local delta = inp.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X,
                                       startPos.Y.Scale, startPos.Y.Offset+delta.Y)
        end
    end)
end

-- Panel contents
local function buildPanel()
    panel:ClearAllChildren()
    local close = Instance.new("TextButton", panel)
    close.Size, close.Position = UDim2.new(0,24,0,24), UDim2.new(1,-30,0,6)
    close.BackgroundTransparency = 1
    close.Text, close.Font, close.TextSize = "✕", Enum.Font.SourceSansBold, 18
    close.TextColor3 = Color3.new(1,0.5,0.5)
    close.MouseButton1Click:Connect(function() panel.Visible=false end)

    local title = Instance.new("TextLabel", panel)
    title.Size, title.Position = UDim2.new(1,-40,0,30), UDim2.new(0,20,0,0)
    title.BackgroundTransparency = 1
    title.Font, title.TextSize = Enum.Font.SourceSansBold, 20
    title.TextColor3 = Color3.new(1,1,1)
    title.Text = (_G.groupName or "Group").." Status"

    local scroll = Instance.new("ScrollingFrame", panel)
    scroll.Size, scroll.Position = UDim2.new(1,-20,1,-60), UDim2.new(0,10,0,40)
    scroll.BackgroundTransparency = 1
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y :contentReference[oaicite:11]{index=11}
    scroll.ScrollBarImageTransparency = 0.5
    local layout = Instance.new("UIListLayout", scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder :contentReference[oaicite:12]{index=12}
    layout.Padding = UDim.new(0,6)

    -- Fetch and categorize
    local members = fetchGroupMembers()
    local cats = {}  -- e.g. {["Admins"]={},["Moderators"]={}}
    for _,m in ipairs(members) do
        local roleName = m.role.name
        cats[roleName] = cats[roleName] or {}
        table.insert(cats[roleName], m)
    end

    local y = 1
    for roleName, tbl in pairs(cats) do
        -- category header
        local header = Instance.new("TextLabel", scroll)
        header.Size, header.LayoutOrder = UDim2.new(1,0,0,30), y; y+=1
        header.BackgroundTransparency = 1
        header.Font, header.TextSize, header.TextColor3 =
            Enum.Font.SourceSansBold, 18, Color3.new(0.8,0.8,1)
        header.Text = roleName

        for _,m in ipairs(tbl) do
            -- entry
            local f = Instance.new("Frame", scroll)
            f.Size, f.LayoutOrder = UDim2.new(1,0,0,40), y; y+=1
            f.BackgroundTransparency = 0.2
            local uc = Instance.new("UICorner", f)
            uc.CornerRadius = UDim.new(0,6)

            local lbl = Instance.new("TextLabel", f)
            lbl.Size, lbl.Position = UDim2.new(0.8,0,1,0), UDim2.new(0,10,0,0)
            lbl.BackgroundTransparency = 1
            lbl.Font, lbl.TextSize = Enum.Font.SourceSans, 16
            lbl.TextColor3 = Color3.new(1,1,1)
            lbl.Text = ("%s [%d]"):format(m.user.username, m.user.id)

            local icon = Instance.new("TextLabel", f)
            icon.Size, icon.Position = UDim2.new(0,24,0,8), UDim2.new(1,-34,0,0)
            icon.BackgroundTransparency = 1
            icon.Font, icon.TextSize = Enum.Font.SourceSansBold = Enum.Font.SourceSansBold, 24
            -- status
            local inGame = Players:GetPlayerByUserId(m.user.id)~=nil
            icon.TextColor3 = inGame and Color3.new(0,1,0) or Color3.new(0.5,0.5,0.5)
            icon.Text = inGame and "🟢" or "⚪"
        end
    end
end

-- Toggle panel with K
ContextAS:BindAction("TogglePanel", function(_,state)
    if state==Enum.UserInputState.Begin then
        panel.Visible = not panel.Visible
        if panel.Visible then buildPanel() end
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.K)

-- 4) Loader-based server-hop: simply re-run loader on each injection

-- Initial notification: who’s here?
do
    local present = {}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr:IsInGroup(_G.groupId) and plr:GetRankInGroup(_G.groupId)>=(_G.minRank or 0) then
            table.insert(present, ("%s #%d"):format(plr.Name, plr:GetRankInGroup(_G.groupId)))
        end
    end
    if #present>0 then
        notify((_G.groupName or "Group").." Online",
               ("Present: %d\n%s"):format(#present, table.concat(present,"\n")))
    end
end

-- Live join alerts
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Wait()
    if plr:IsInGroup(_G.groupId) and plr:GetRankInGroup(_G.groupId)>=(_G.minRank or 0) then
        notify((_G.groupName or "Group").." Joined",
               ("%s #%d has joined!"):format(plr.Name, plr:GetRankInGroup(_G.groupId)))
    end
end)
