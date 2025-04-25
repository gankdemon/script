-- tracker.lua
-- Globals before loading:
--   _G.groupId    = <number>
--   _G.groupName  = <string>
--   _G.minRank    = <number>

local function main()
    local Players      = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local ContextAS    = game:GetService("ContextActionService")
    local HttpService  = game:GetService("HttpService")
    local UserInput    = game:GetService("UserInputService")

    -- Create ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name        = "GroupTracker"
    gui.ResetOnSpawn = false
    gui.Parent      = Players.LocalPlayer:WaitForChild("PlayerGui")

    -- Utility: rounded frame
    local function makeFrame(size, pos)
        local f = Instance.new("Frame", gui)
        f.Size, f.Position = size, pos
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundColor3 = Color3.fromRGB(30,30,30)
        f.BackgroundTransparency = 0.1
        local uc = Instance.new("UICorner", f)
        uc.CornerRadius = UDim.new(0,12)
        return f
    end

    -- Notification
    local function notify(title, body)
        local nf = makeFrame(UDim2.new(0,450,0,120), UDim2.new(0.5,0,-0.5,0))
        -- Title
        local t = Instance.new("TextLabel", nf)
        t.Size, t.Position = UDim2.new(1,-40,0,30), UDim2.new(0,20,0,10)
        t.BackgroundTransparency = 1
        t.Font, t.TextSize, t.TextColor3 = Enum.Font.SourceSansBold, 24, Color3.new(1,1,1)
        t.Text, t.TextXAlignment = title, Enum.TextXAlignment.Left
        -- Body
        local b = Instance.new("TextLabel", nf)
        b.Size, b.Position = UDim2.new(1,-40,1,-60), UDim2.new(0,20,0,50)
        b.BackgroundTransparency = 1
        b.Font, b.TextSize, b.TextColor3 = Enum.Font.SourceSans, 18, Color3.new(1,1,1)
        b.TextWrapped, b.TextXAlignment = true, Enum.TextXAlignment.Left
        b.Text = body
        -- OK button
        local ok = Instance.new("TextButton", nf)
        ok.Size, ok.Position = UDim2.new(0,60,0,30), UDim2.new(1,-70,1,-40)
        ok.Text, ok.Font, ok.TextSize = "OK", Enum.Font.SourceSansBold, 18
        ok.BackgroundColor3, ok.BorderSizePixel = Color3.fromRGB(50,50,50), 0
        local oc = Instance.new("UICorner", ok)
        oc.CornerRadius = UDim.new(0,8)
        ok.MouseButton1Click:Connect(function()
            TweenService:Create(nf, TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
                Position = UDim2.new(0.5,0,-0.5,0)
            }):Play():Completed:Wait()
            nf:Destroy()
        end)
        -- Slide in
        TweenService:Create(nf, TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
            Position = UDim2.new(0.5,0,0.2,0)
        }):Play()
    end

    -- Helper
    local function isWatcher(plr)
        if not plr:IsInGroup(_G.groupId) then return false end
        local r = plr:GetRankInGroup(_G.groupId)
        if r < (_G.minRank or 0) then return false end
        return true, r, plr:GetRoleInGroup(_G.groupId)
    end

    -- Initial scan
    do
        local present = {}
        for _,p in ipairs(Players:GetPlayers()) do
            local ok,r,name = isWatcher(p)
            if ok then table.insert(present, string.format("%s (%s #%d)", p.Name, name, r)) end
        end
        if #present>0 then
            notify((_G.groupName or "Group").." Online",
                   ("Present: %d\n%s"):format(#present, table.concat(present,"\n")))
        end
    end

    -- Live joins
    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Wait()
        local ok,r,name = isWatcher(p)
        if ok then
            notify((_G.groupName or "Group").." Joined",
                   string.format("%s (%s #%d) has joined!", p.Name, name, r))
        end
    end)

    -- Status panel (omitted here for brevity—same as before but with key L)
    -- Toggle with L
    ContextAS:BindAction("ToggleStatus", function(_,state)
        if state==Enum.UserInputState.Begin then
            -- show/hide panel code...
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.L)  -- changed to L :contentReference[oaicite:0]{index=0}
end

-- Execute with error-trapping
local ok, err = xpcall(main, function(e) return debug.traceback(e) end)  -- xpcall+traceback 
if not ok then
    warn("[Tracker Error] "..err)  -- warn outputs to console :contentReference[oaicite:1]{index=1}
end
