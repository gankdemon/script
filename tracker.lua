-- tracker.lua
-- this is the code you host at:
-- https://raw.githubusercontent.com/YourUser/YourRepo/main/tracker.lua

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local localPlayer  = Players.LocalPlayer
local playerGui    = localPlayer:WaitForChild("PlayerGui")

-- one ScreenGui for all notifications
local screenGui = Instance.new("ScreenGui")
screenGui.Name   = "TrackerNotifications"
screenGui.Parent = playerGui

-- slide-in/out toaster
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

-- lookup by UserId against global tables
local function getRole(uid)
    if     table.find(_G.eventStaff  or {}, uid) then return "Event Staff" end
    if     table.find(_G.moderators  or {}, uid) then return "Moderator"   end
    if     table.find(_G.admins      or {}, uid) then return "Admin"       end
    return nil
end

-- initial scan
do
    local found = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local role = getRole(plr.UserId)
        if role then
            table.insert(found, string.format("[%s] %s", role, plr.Name))
        end
    end
    if #found > 0 then
        showNotification(
            "Tracked Users Online",
            string.format("%d in server:\n%s", #found, table.concat(found, ", "))
        )
    else
        showNotification("Tracked Users Online", "None of your tracked IDs are here.")
    end
end

-- listen for new joins
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Wait()
    local role = getRole(plr.UserId)
    if role then
        showNotification("Tracked User Joined", string.format("[%s] %s has joined!", role, plr.Name))
    end
end)
