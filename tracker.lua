-- tracker.lua
-- expects these globals:
--   _G.groupId    = <number>  — the Group you want to track
--   _G.groupName  = <string>  — label for notifications
--   _G.minRank    = <number>  — optional: only alert for rank >= this

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local localPlayer  = Players.LocalPlayer
local playerGui    = localPlayer:WaitForChild("PlayerGui")

-- container for all toasts
local screenGui = Instance.new("ScreenGui")
screenGui.Name   = "GroupTrackerNotifications"
screenGui.Parent = playerGui

-- makes and plays a slide-in/out notification
local function showNotification(titleText, bodyText)
    local frame = Instance.new("Frame")
    frame.Size               = UDim2.new(0, 300, 0, 80)
    frame.Position           = UDim2.new(1, 310, 0, 50)
    frame.BackgroundColor3   = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.2
    frame.AnchorPoint        = Vector2.new(1, 0)
    frame.Parent             = screenGui

    local title = Instance.new("TextLabel")
    title.Size               = UDim2.new(1, -20, 0, 20)
    title.Position           = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Font               = Enum.Font.SourceSansBold
    title.TextSize           = 18
    title.TextColor3         = Color3.new(1,1,1)
    title.Text               = titleText
    title.TextXAlignment     = Enum.TextXAlignment.Left
    title.Parent             = frame

    local body = Instance.new("TextLabel")
    body.Size                = UDim2.new(1, -20, 1, -40)
    body.Position            = UDim2.new(0, 10, 0, 30)
    body.BackgroundTransparency = 1
    body.Font                = Enum.Font.SourceSans
    body.TextSize            = 14
    body.TextColor3          = Color3.new(1,1,1)
    body.TextWrapped         = true
    body.Text                = bodyText
    body.TextXAlignment      = Enum.TextXAlignment.Left
    body.Parent              = frame

    local tweenIn = TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -10, 0, 50)
    })
    tweenIn:Play()
    tweenIn.Completed:Wait()

    task.wait(3)

    local tweenOut = TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(1, 310, 0, 50)
    })
    tweenOut:Play()
    tweenOut.Completed:Wait()

    frame:Destroy()
end

-- returns true plus (rankNumber, roleName) if they meet your criteria
local function isWatcher(plr)
    local gid   = _G.groupId
    if not plr:IsInGroup(gid) then
        return false
