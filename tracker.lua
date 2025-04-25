-- tracker.lua
-- Global configuration (set via your local loader before calling this):
--   _G.groupId    = <number>    -- Roblox Group ID to watch
--   _G.groupName  = <string>    -- Label for notifications
--   _G.minRank    = <number>    -- Optional: alert for ranks >= this (default 0)

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local HttpService   = game:GetService("HttpService")

local groupId       = _G.groupId
local groupName     = _G.groupName or ("Group " .. tostring(groupId))
local minRank       = _G.minRank or 0

local localPlayer   = Players.LocalPlayer
local playerGui     = localPlayer:WaitForChild("PlayerGui")

-- Persistent GUI container
local screenGui = Instance.new("ScreenGui")
screenGui.Name   = "GroupTracker"
screenGui.Parent = playerGui

-- Store last place for server-hop detection
local lastPlaceId = game.PlaceId

-- Notification factory
local function makeNotification(titleText, bodyText)
    -- Frame
    local frame = Instance.new("Frame")
    frame.Size               = UDim2.new(0, 350, 0, 100)
    frame.Position           = UDim2.new(1, 10, 0, 50)
    frame.AnchorPoint        = Vector2.new(1, 0)
    frame.BackgroundColor3   = Color3.fromRGB(25, 25, 25)
    frame.BackgroundTransparency = 0.1
    frame.Parent             = screenGui

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size               = UDim2.new(0, 20, 0, 20)
    closeBtn.Position           = UDim2.new(1, -25, 0, 5)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font               = Enum.Font.SourceSansBold
    closeBtn.TextSize           = 18
    closeBtn.TextColor3         = Color3.fromRGB(200, 200, 200)
    closeBtn.Text               = "✕"
    closeBtn.Parent             = frame
    closeBtn.MouseButton1Click:Connect(function()
        frame:Destroy()
    end)

    -- Title
    local title = Instance.new("TextLabel")
    title.Size               = UDim2.new(1, -40, 0, 25)
    title.Position           = UDim2.new(0, 10, 0, 5)
    title.BackgroundTransparency = 1
    title.Font               = Enum.Font.SourceSansBold
    title.TextSize           = 20
    title.TextColor3         = Color3.new(1,1,1)
    title.Text               = titleText
    title.TextXAlignment     = Enum.TextXAlignment.Left
    title.Parent             = frame

    -- Body
    local body = Instance.new("TextLabel")
    body.Size                = UDim2.new(1, -20, 1, -40)
    body.Position            = UDim2.new(0, 10, 0, 30)
    body.BackgroundTransparency = 1
    body.Font                = Enum.Font.SourceSans
    body.TextSize            = 16
    body.TextColor3          = Color3.new(1,1,1)
    body.TextWrapped         = true
    body.Text                = bodyText
    body.TextXAlignment      = Enum.TextXAlignment.Left
    body.Parent              = frame

    -- Tween in
    TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -10, 0, 50)
    }):Play()

    return frame
end

-- Check membership and rank+role
local function checkMember(plr)
    if not plr:IsInGroup(groupId) then return false end
    local rankNum  = plr:GetRankInGroup(groupId)
    if rankNum < minRank then return false end
    local roleName = plr:GetRoleInGroup(groupId)
    return true, rankNum, roleName
end

-- Initial scan or on-server-hop scan
do
    local found = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local ok, rnum, rname = checkMember(plr)
        if ok then
            table.insert(found, string.format("%s (%s #%d)", plr.Name, rname, rnum))
        end
    end
    local notif
    if #found > 0 then
        notif = makeNotification(groupName .. " Online", string.format("%d members here:\n%s", #found, table.concat(found, ", ")))
    else
        notif = makeNotification(groupName .. " Online", "None present.")
    end
    -- no auto destroy; user closes via X
end

-- Real-time join alerts
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Wait()
    local ok, rnum, rname = checkMember(plr)
    if ok then
        makeNotification(groupName .. " Join", string.format("%s (%s #%d) joined!", plr.Name, rname, rnum))
    end
end)

-- Server-hop detection
RunService.Heartbeat:Connect(function()
    if game.PlaceId ~= lastPlaceId then
        lastPlaceId = game.PlaceId
        -- re-run initial scan notification
        local found = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            local ok, rnum, rname = checkMember(plr)
            if ok then
                table.insert(found, string.format("%s (%s #%d)", plr.Name, rname, rnum))
            end
        end
        if #found > 0 then
            makeNotification(groupName .. " Online", string.format("%d members here:\n%s", #found, table.concat(found, ", ")))
        end
    end
end)

-- Status list GUI
local statusOpen = false
local listBtn = Instance.new("TextButton")
listBtn.Size               = UDim2.new(0, 150, 0, 30)
listBtn.Position           = UDim2.new(0, 10, 0, 10)
listBtn.BackgroundColor3   = Color3.fromRGB(50,50,50)
listBtn.Text              = groupName .. " Status"
listBtn.Parent             = screenGui

local listFrame = Instance.new("Frame")
listFrame.Size             = UDim2.new(0, 300, 0, 400)
listFrame.Position         = UDim2.new(0, 10, 0, 50)
listFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
listFrame.Visible          = false
listFrame.Parent           = screenGui

local scrolling = Instance.new("ScrollingFrame")
scrolling.Size             = UDim2.new(1, -10, 1, -10)
scrolling.Position         = UDim2.new(0,5,0,5)
scrolling.CanvasSize       = UDim2.new(0,0,0,0)
scrolling.ScrollBarThickness = 6
scrolling.Parent           = listFrame

listBtn.MouseButton1Click:Connect(function()
    statusOpen = not statusOpen
    listFrame.Visible = statusOpen
    if statusOpen then
        -- fetch and populate
        scrolling:ClearAllChildren()
        local y = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            local ok, _, _ = checkMember(plr)
            local lbl = Instance.new("TextLabel")
            lbl.Size               = UDim2.new(1, -10, 0, 25)
            lbl.Position           = UDim2.new(0, 5, 0, y)
            lbl.BackgroundTransparency = 1
            lbl.Font               = Enum.Font.SourceSans
            lbl.TextSize           = 16
            lbl.TextColor3         = ok and Color3.fromRGB(100,255,100) or Color3.fromRGB(200,200,200)
            lbl.Text               = string.format("%s - in-game: %s", plr.Name, ok and "Yes" or "No")
            lbl.Parent             = scrolling
            y = y + 25
        end
        scrolling.CanvasSize = UDim2.new(0,0,0,y)
    end
end)
