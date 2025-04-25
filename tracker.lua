-- tracker.lua
-- Globals: _G.groupId, _G.groupName, _G.minRank

local function main()
    print("[Tracker] main() starting")
    local Players      = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local ContextAS    = game:GetService("ContextActionService")
    local HttpService  = game:GetService("HttpService")
    local UserInput    = game:GetService("UserInputService")
    print("[Tracker] Services acquired")

    -- Create GUI
    local gui = Instance.new("ScreenGui")
    gui.Name = "GroupTracker"; gui.ResetOnSpawn = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    print("[Tracker] ScreenGui created")

    -- Utility for rounded frames
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

    -- Notification function
    local function notify(title, body)
        print("[Tracker] notify(): "..title)
        local nf = makeFrame(UDim2.new(0,450,0,120), UDim2.new(0.5,0,-0.5,0))
        -- [build labels omitted for brevity; same as before]
        -- OK button closes and slides out
        nf.ChildAdded:Connect(function(child) print("[Tracker] notif child added: "..child.ClassName) end)
        -- Slide in
        TweenService:Create(nf, TweenInfo.new(0.6), { Position = UDim2.new(0.5,0,0.2,0) }):Play()
    end

    -- Helper
    local function isWatcher(p)
        if not p:IsInGroup(_G.groupId) then return false end
        local r = p:GetRankInGroup(_G.groupId)
        if r < (_G.minRank or 0) then return false end
        return true, r, p:GetRoleInGroup(_G.groupId)
    end

    -- Initial scan
    print("[Tracker] Doing initial scan")
    local present = {}
    for _,p in ipairs(Players:GetPlayers()) do
        local ok, r, name = isWatcher(p)
        if ok then
            table.insert(present, p.Name.." ("..name.." #"..r..")")
        end
    end
    if #present > 0 then
        notify((_G.groupName or "Group").." Online", table.concat(present,"\n"))
    else
        print("[Tracker] No one present")
    end

    -- Live joins
    Players.PlayerAdded:Connect(function(p)
        print("[Tracker] PlayerAdded event: "..p.Name)
        local ok, r, name = isWatcher(p)
        if ok then
            notify((_G.groupName or "Group").." Joined",
                   p.Name.." ("..name.." #"..r..") joined")
        end
    end)

    -- Status panel toggle (L)
    print("[Tracker] Binding key L for status panel")
    ContextAS:BindAction("ToggleStatus", function(_,state)
        if state == Enum.UserInputState.Begin then
            print("[Tracker] L pressed – toggling panel")
            -- show/hide panel code here...
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.L)
    
    print("[Tracker] main() completed setup")
end

-- Run with error capture
local ok, err = xpcall(main, function(e) return debug.traceback(e) end)
if not ok then
    warn("[Tracker ERROR]:\n"..err)
end
