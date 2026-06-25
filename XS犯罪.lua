print("欢迎使用xs犯罪")
local p = game.Players.LocalPlayer
print("您好用户: "..p.Name.." | UID: "..p.UserId)
print(" 当前时间: " .. os.date("%X"))
print(" XS : 脚本正在加载中...")
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

WindUI.TransparencyValue = 0.3
WindUI:SetTheme("Dark")

WindUI:Popup({
    Title = "XS脚本",
    Icon = "sparkles",
    Content = "尊贵的"..game.Players.LocalPlayer.Name.."，欢迎使用犯罪脚本",
    Buttons = {
        {
            Title = "启动",
            Icon = "arrow-right",
            Variant = "Primary",
            Callback = function() 
                print("XS犯罪脚本已启动")
            end
        }
    }
})

local plrs = game:GetService("Players")
local me = plrs.LocalPlayer
local input = game:GetService("UserInputService")
local run = game:GetService("RunService")
local camera = workspace.CurrentCamera
local tween = game:GetService("TweenService")
local light = game:GetService("Lighting")
local rp = game:GetService("ReplicatedStorage")

local functions = {
    Fullbright = false,
    AutoOpenDoors = false,
    NoBarriers = false,
    NoGrinder = false,
    FastPickup = false,
    AutoPickupScraps = false,
    AutoPickupTools = false,
    AutopickupCrates = false,
    AutoPickupMoney = false,
    Infstamina = false,
    Nofalldamage = false,
    Noclip = false,
    FakeDown = true,
    Stopneckmove = false,
    Unbreaklimbs = false,
    SilentAim = false,
    AimBot = false,
    Instantreload = false,
    Meleeaura = false,
    RageBot = false,
    TrigerBot = false,
    RocketControl = false,
    ESP = false,
    ArmsChams = false,
    ToolsChams = false,
}

local SectionSettings = {
    SilentAim = {
        Draw = false,
        DrawSize = 50,
        DrawColor = Color3.new(1, 1, 1),
        TargetParts = {"Head"},
        CheckDowned = false,
        CheckWall = false,
        CheckTeam = false,
        CheckWhiteList = false,
    },
    Aimbot = {
        Draw = false,
        DrawSize = 50,
        DrawColor = Color3.new(1, 1, 1),
        TargetParts = {"Head"},
        CheckDowned = false,
        CheckWall = false,
        CheckTeam = false,
        CheckWhiteList = false,
        Velocity = false,
        Smooth = false,
        SmoothSize = 0.5
    },
    MeleeAura = {
        ShowAnim = false,
        TargetParts = {"Head"},
        CheckDowned = false,
        CheckTeam = false,
        CheckWhiteList = false,
        Distance = 15,
    },
    RageBot = {
        CheckDowned = false,
        CheckWhiteList = false
    },
    ESP = {
        Name = false,
        Box = false,
        Weapon = false,
        Highlight = false,
    }
}

local Methods = {
    Fly = "Bypass",
    Infstamina = "Getgc"
}

local cockie = {
    SilentAimCircle = nil,
    SilentAim_body = nil,
    ESPHighlight = nil,
    AimBotCircle = nil,
    aimbot_button = nil,
    Aimbot_body = nil,
    MeleeAura_body = nil,
}

local RUNS = {
    cameraFOV = nil,
    JumpHeight = nil,
    AutoOpenDoors = nil,
    AutopickupScraps = nil,
    AutopickupTools = nil,
    AutopickupCrates = nil,
    AutopickupMoney = nil,
    Infstamina = nil,
    Fly = nil,
    Noclip = nil,
    Meleeaura = nil,
    ESP = nil,
}

local funcindex = {
    Fullbright = {
        oldClockTime = nil,
        oldBrightness = nil,
    }
}

local WhiteList = {}

function CharStats(plr)
    local folder = rp.CharStats[plr.Name]
    return folder
end

local Window = WindUI:CreateWindow({
    Title = "XS", 
    Icon = "shield", 
    Author = "XS v1.0", 
    Folder = "缝合", 
    Size = UDim2.fromOffset(600, 500), 
    Theme = "Dark", 
    
    User = {
        Enabled = true, 
        Anonymous = false, 
        Callback = function() 
            WindUI:Notify({
                Title = "XS",
                Content = "高级功能菜单",
                Duration = 3
            })
        end
    },
    SideBarWidth = 180, 
    ScrollBarEnabled = true 
})

Window:Tag({
    Title = "缝合",
    Color = Color3.fromHex("#ff3030")
})

Window:Tag({
    Title = "犯罪", 
    Color = Color3.fromHex("#ffffff")
})

local Tabs = {
    World = Window:Tab({ Title = "世界功能", Icon = "globe", Locked = false }),
    Player = Window:Tab({ Title = "玩家功能", Icon = "user", Locked = false }),
    Combat = Window:Tab({ Title = "战斗功能", Icon = "target", Locked = false }),
    Visual = Window:Tab({ Title = "视觉功能", Icon = "eye", Locked = false }),
    Misc = Window:Tab({ Title = "其他功能", Icon = "settings", Locked = false })
}

Tabs.World:Toggle({
    Title = "夜视",
    Description = "地图变亮",
    Default = functions.Fullbright,
    Callback = function(Value)
        functions.Fullbright = Value
        local Folder
        if Value then
            if #light:GetChildren() ~= 0 then
                Folder = Instance.new("Folder")
                Folder.Parent = rp
                Folder.Name = "Index"
                for _, a in pairs(light:GetChildren()) do
                    a.Parent = Folder
                end
            end
            funcindex.Fullbright.oldClockTime = light.ClockTime
            light.ClockTime = 14
            funcindex.Fullbright.oldBrightness = light.Brightness
            light.Brightness = 4
            light.ExposureCompensation = .7
        else
            Folder = rp:FindFirstChild("Index")
            if Folder ~= nil then
                for _, a in pairs(Folder:GetChildren()) do
                    a.Parent = light
                end
                Folder:Destroy()
                Folder = nil
            end
            light.ClockTime = funcindex.Fullbright.oldClockTime or 14
            light.Brightness = funcindex.Fullbright.oldBrightness or 1
            light.ExposureCompensation = 0
        end
    end
})

Tabs.World:Toggle({
    Title = "自动开门",
    Description = "自动打开附近的门",
    Default = functions.AutoOpenDoors,
    Callback = function(Value)
        functions.AutoOpenDoors = Value
        if Value then
            RUNS.AutoOpenDoors = run.RenderStepped:Connect(function()
                local function GetDoor()
                    local mapFolder = workspace:FindFirstChild("Map")
                    if not mapFolder then return nil end
                    local folderDoors = mapFolder:FindFirstChild("Doors")
                    if not folderDoors then return nil end

                    local closestDoor, dist = nil, 15
                    for _, door in pairs(folderDoors:GetChildren()) do
                        local doorBase = door:FindFirstChild("DoorBase")
                        if doorBase and me.Character:FindFirstChild("HumanoidRootPart") then
                            local distance = (me.Character.HumanoidRootPart.Position - doorBase.Position).Magnitude
                            if distance < dist then
                                dist = distance
                                closestDoor = door
                            end
                        end
                    end
                    return closestDoor
                end

                local door = GetDoor()
                if door then
                    local values = door:FindFirstChild("Values")
                    local events = door:FindFirstChild("Events")
                    if values and events then
                        local locked = values:FindFirstChild("Locked")
                        local openValue = values:FindFirstChild("Open")
                        local toggleEvent = events:FindFirstChild("Toggle")
                        if locked and openValue and toggleEvent then
                            if locked.Value == true then
                                toggleEvent:FireServer("Unlock", door.Lock)
                            elseif locked.Value == false and openValue.Value == false then
                                local knob1 = door:FindFirstChild("Knob1")
                                local knob2 = door:FindFirstChild("Knob2")
                                if knob1 and knob2 then
                                    local knob1pos = (me.Character.HumanoidRootPart.Position - knob1.Position).Magnitude
                                    local knob2pos = (me.Character.HumanoidRootPart.Position - knob2.Position).Magnitude
                                    local chosenKnob = (knob1pos < knob2pos) and knob1 or knob2
                                    toggleEvent:FireServer("Open", chosenKnob)
                                end
                            end
                        end
                    end
                end
            end)
        else
            if RUNS.AutoOpenDoors then
                RUNS.AutoOpenDoors:Disconnect()
                RUNS.AutoOpenDoors = nil
            end
        end
    end
})

Tabs.World:Toggle({
    Title = "无屏障",
    Description = "移除地图屏障",
    Default = functions.NoBarriers,
    Callback = function(Value)
        functions.NoBarriers = Value
        for _, a in pairs(workspace.Filter.Parts["F_Parts"]:GetDescendants()) do
            if a:IsA("Part") or a:IsA("MeshPart") then
                a.CanTouch = not a.CanTouch
            end
        end
    end
})

Tabs.World:Toggle({
    Title = "防研磨机",
    Description = "防止研磨机伤害",
    Default = functions.NoGrinder,
    Callback = function(Value)
        functions.NoGrinder = Value
        for _, a in pairs(workspace.Map.Parts.Grinders:GetDescendants()) do
            if a:IsA("Part") or a:IsA("MeshPart") then
                a.CanTouch = not a.CanTouch
            end
        end
        for _, a in pairs(workspace.Map.Parts.M_Parts:GetDescendants()) do
            if a:IsA("Part") and a.Name == "FirePart" then
                a.CanTouch = not a.CanTouch
            end
        end
    end
})

Tabs.World:Toggle({
    Title = "快速拾取",
    Description = "瞬间拾取物品",
    Default = functions.FastPickup,
    Callback = function(Value)
        functions.FastPickup = Value
        if Value then
            game.DescendantAdded:Connect(function(obj)
                if obj:IsA("ProximityPrompt") then
                    obj.HoldDuration = 0
                    obj:GetPropertyChangedSignal("HoldDuration"):Connect(function()
                        if functions.FastPickup then
                            obj.HoldDuration = 0
                        end
                    end)
                end
            end)
        end
    end
})

Tabs.World:Toggle({
    Title = "自动拾取废料",
    Description = "自动拾取附近的废料",
    Default = functions.AutoPickupScraps,
    Callback = function(Value)
        functions.AutoPickupScraps = Value
        local remote = rp.Events.PIC_PU
        local scrapsfolder = workspace.Filter.SpawnedPiles
        local canPickup = true
        local startTick = tick()

        if Value then
            RUNS.AutopickupScraps = run.RenderStepped:Connect(function()
                local function GetClosestScrap()
                    local maxdist = 15
                    local closest = nil

                    for _, a in pairs(scrapsfolder:GetChildren()) do
                        if a and (a.Name == "S1" or a.Name == "S2") then
                            if me.Character and me.Character.HumanoidRootPart then
                                local getdist = (me.Character.HumanoidRootPart.Position - a.MeshPart.Position).Magnitude
                                if getdist < maxdist then
                                    maxdist = getdist
                                    closest = a
                                end
                            end
                        end
                    end
                    maxdist = 15
                    return closest
                end

                local getscrap = GetClosestScrap()
                if getscrap then
                    if canPickup then
                        remote:FireServer(string.reverse(getscrap:GetAttribute("jzu")))
                        canPickup = false
                    end
                end
                if canPickup == false and tick() - startTick >= 4.5 then
                    canPickup = true
                    startTick = tick()
                end
            end)
        else
            if RUNS.AutopickupScraps then
                RUNS.AutopickupScraps:Disconnect()
                RUNS.AutopickupScraps = nil
            end
        end
    end
})

Tabs.World:Toggle({
    Title = "自动拾取工具",
    Description = "自动拾取附近的工具",
    Default = functions.AutoPickupTools,
    Callback = function(Value)
        functions.AutoPickupTools = Value
        local remote = rp.Events.PIC_TLO
        local toolsfolder = workspace.Filter.SpawnedTools
        local canPickup = true
        local startTick = tick()

        if Value then
            RUNS.AutopickupTools = run.RenderStepped:Connect(function()
                local function GetClosestTool()
                    local maxdist = 15
                    local closest = nil

                    for _, a in pairs(toolsfolder:GetChildren()) do
                        if a and me.Character and me.Character.HumanoidRootPart then
                            local handle = a:FindFirstChild("Handle") or a:FindFirstChild("WeaponHandle")
                            if handle and (handle:IsA("Part") or handle:IsA("MeshPart")) then
                                if me.Character and me.Character:FindFirstChild("HumanoidRootPart") then
                                    local getdist = (me.Character.HumanoidRootPart.Position - handle.Position).Magnitude
                                    if getdist < maxdist then
                                        maxdist = getdist
                                        closest = a
                                    end
                                end
                            end
                        end
                    end
                    maxdist = 15
                    return closest
                end

                local tool = GetClosestTool()
                if tool then
                    local Handle = tool:FindFirstChild("Handle") or tool:FindFirstChild("WeaponHandle")
                    if Handle then
                        if canPickup then
                            remote:FireServer(Handle)
                            canPickup = false
                        end
                    end
                end
                if canPickup == false and tick() - startTick >= 1.5 then
                    canPickup = true
                    startTick = tick()
                end
            end)
        else
            if RUNS.AutopickupTools then
                RUNS.AutopickupTools:Disconnect()
                RUNS.AutopickupTools = nil
            end
        end
    end
})

Tabs.World:Toggle({
    Title = "自动拾取金钱",
    Description = "自动拾取附近的金钱",
    Default = functions.AutoPickupMoney,
    Callback = function(Value)
        functions.AutoPickupMoney = Value
        local remote = rp.Events:FindFirstChild("CZDPZUS")
        local moneyfolder = workspace.Filter.SpawnedBread
        local canPickup = true
        local startTick = tick()

        if Value then
            RUNS.AutopickupMoney = run.RenderStepped:Connect(function()
                local function GetMoney()
                    local maxdist = 15
                    local closest = nil

                    for _, a in pairs(moneyfolder:GetChildren()) do
                        if a and me.Character and me.Character.HumanoidRootPart then
                            local getdist = (me.Character.HumanoidRootPart.Position - a.Position).Magnitude
                            if getdist < maxdist then
                                maxdist = getdist
                                closest = a
                            end
                        end
                    end
                    maxdist = 15
                    return closest
                end

                local foundmoney = GetMoney()
                if foundmoney then
                    if canPickup then
                        remote:FireServer(foundmoney)
                        canPickup = false
                    end
                end
                if canPickup == false and tick() - startTick >= 1 then
                    canPickup = true
                    startTick = tick()
                end
            end)
        else
            if RUNS.AutopickupMoney then
                RUNS.AutopickupMoney:Disconnect()
                RUNS.AutopickupMoney = nil
            end
        end
    end
})

Tabs.Player:Slider({
    Title = "FOV",
    Description = "调整相机视野",
    Default = camera.FieldOfView,
    Min = 70,
    Max = 120,
    Callback = function(Value)
        if RUNS.cameraFOV ~= nil then
            RUNS.cameraFOV:Disconnect()
            RUNS.cameraFOV = nil
        end
        RUNS.cameraFOV = run.RenderStepped:Connect(function()
            camera.FieldOfView = Value
        end)
    end
})

Tabs.Player:Slider({
    Title = "相机距离",
    Description = "调整相机最大距离",
    Default = me.CameraMaxZoomDistance,
    Min = 10,
    Max = 500,
    Callback = function(Value)
        me.CameraMaxZoomDistance = Value
    end
})

Tabs.Player:Slider({
    Title = "跳跃高度",
    Description = "调整跳跃高度",
    Default = 7.1,
    Min = 7.1,
    Max = 25,
    Callback = function(Value)
        if RUNS.JumpHeight then
            RUNS.JumpHeight:Disconnect()
            RUNS.JumpHeight = nil
        end
        RUNS.JumpHeight = run.RenderStepped:Connect(function()
            if me.Character and me.Character:FindFirstChild("Humanoid") then
                me.Character:FindFirstChild("Humanoid").UseJumpPower = false
                me.Character:FindFirstChild("Humanoid").JumpHeight = Value
            end
        end)
    end
})

Tabs.Player:Slider({
    Title = "重力",
    Description = "调整世界重力",
    Default = workspace.Gravity,
    Min = workspace.Gravity,
    Max = 75,
    Callback = function(Value)
        workspace.Gravity = Value
    end
})

Tabs.Player:Toggle({
    Title = "无限体力",
    Description = "字面意思",
    Default = functions.Infstamina,
    Callback = function(Value)
        functions.Infstamina = Value
        if Value then
            while functions.Infstamina do
                if Methods.Infstamina == "Getgc" then
                    local stamina = {}
                    function get()
                        for index, value in pairs(getgc(true)) do
                            if type(value) == "table" and rawget(value, "S") then
                                stamina[#stamina + 1] = value
                            end
                        end
                    end
                    local ss, nn = pcall(function()
                        get()
                    end)
                    if ss then
                        for _, a in pairs(stamina) do
                            a.S = 100
                        end
                    end
                elseif Methods.Infstamina == "low exploit" then
                    if me.Character then
                        local hum = me.Character:FindFirstChild("Humanoid")
                        if hum and not hum:GetAttribute("ZSPRN_M") then
                            hum:SetAttribute("ZSPRN_M", true)
                        end
                    end
                    me.CharacterAdded:Connect(function(char)
                        if functions.Infstamina then
                            if char and char:WaitForChild("Humanoid") then
                                local hum = char:FindFirstChild("Humanoid")
                                if hum and not hum:GetAttribute("ZSPRN_M") then
                                    hum:SetAttribute("ZSPRN_M", true)
                                end
                            end
                        end
                    end)
                end
                run.RenderStepped:Wait()
            end
        else
            if me.Character then
                local hum = me.Character:FindFirstChild("Humanoid")
                if hum then
                    local check = hum:GetAttribute("ZSPRN_M")
                    if check then
                        hum:SetAttribute("ZSPRN_M", nil)
                    end
                end
            end
        end
    end
})

Tabs.Player:Dropdown({
    Title = "无限体力方法",
    Description = "选择实现方法",
    Options = {"Getgc", "low exploit"},
    Default = Methods.Infstamina,
    Callback = function(Value)
        Methods.Infstamina = Value
    end
})

Tabs.Player:Toggle({
    Title = "无坠落伤害",
    Description = "防止坠落伤害",
    Default = functions.Nofalldamage,
    Callback = function(Value)
        functions.Nofalldamage = Value
        if Value then
            if me.Character then
                local ff = Instance.new("ForceField")
                ff.Parent = me.Character
                ff.Visible = false
            end
            me.CharacterAdded:Connect(function(char)
                if functions.Nofalldamage and char and char:WaitForChild("HumanoidRootPart") and char:WaitForChild("Humanoid") then
                    local ff = Instance.new("ForceField")
                    ff.Parent = char
                    ff.Visible = false
                end
            end)
        else
            if me.Character then
                for _, a in pairs(me.Character:GetChildren()) do
                    if a:IsA("ForceField") and a.Visible == false then
                        a:Destroy()
                    end
                end
            end
        end
    end
})

Tabs.Player:Toggle({
    Title = "穿墙模式",
    Description = "可以穿过墙壁",
    Default = functions.Noclip,
    Callback = function(Value)
        functions.Noclip = Value
        if Value then
            local function LoopNoclip()
                local char = me.Character
                if char then
                    for _, a in pairs(char:GetDescendants()) do
                        if a:IsA("BasePart") and a.CanCollide == true then
                            a.CanCollide = false
                        end
                    end
                end
            end

            RUNS.Noclip = run.RenderStepped:Connect(LoopNoclip)
        else
            if RUNS.Noclip then
                RUNS.Noclip:Disconnect()
                RUNS.Noclip = nil
            end
        end
    end
})

Tabs.Player:Toggle({
    Title = "伪装倒地",
    Description = "伪装成倒地状态",
    Default = functions.FakeDown,
    Callback = function(Value)
        functions.FakeDown = Value
        if Value then
            local getvalue = CharStats(me).Downed
            getvalue.Value = true
            getvalue:GetPropertyChangedSignal("Value"):Connect(function()
                if functions.FakeDown then
                    getvalue.Value = true
                end
            end)
        else
            CharStats(me).Downed.Value = false
        end
    end
})

Tabs.Player:Toggle({
    Title = "停止颈部移动",
    Description = "停止角色颈部移动",
    Default = functions.Stopneckmove,
    Callback = function(Value)
        functions.Stopneckmove = Value
        if Value then
            if me.Character then
                me.Character:SetAttribute("NoNeckMovement", true)
            end
            me.CharacterAdded:Connect(function(char)
                if char and char:FindFirstChild("Humanoid") then
                    if functions.Stopneckmove then
                        char:SetAttribute("NoNeckMovement", true)
                    end
                else
                    repeat wait() until char and char:FindFirstChild("Humanoid")
                    if functions.Stopneckmove then
                        char:SetAttribute("NoNeckMovement", true)
                    end
                end
            end)
        else
            if me.Character then
                local get = me.Character:GetAttribute("NoNeckMovement")
                if get then
                    me.Character:SetAttribute("NoNeckMovement", nil)
                end
            end
        end
    end
})

Tabs.Player:Toggle({
    Title = "肢体不碎",
    Description = "防止肢体断裂",
    Default = functions.Unbreaklimbs,
    Callback = function(Value)
        functions.Unbreaklimbs = Value
        local limbsfolder = CharStats(me).HealthValues
        for _, a in pairs(limbsfolder:GetChildren()) do
            for _, i in pairs(a:GetChildren()) do
                if i and i.Name == "Broken" then
                    if functions.Unbreaklimbs then
                        i.Value = false
                        i:GetPropertyChangedSignal("Value"):Connect(function()
                            if functions.Unbreaklimbs then
                                i.Value = false
                            end
                        end)
                    end
                end
            end
        end
        limbsfolder.ChildAdded:Connect(function()
            for _, a in pairs(limbsfolder:GetChildren()) do
                for _, i in pairs(a:GetChildren()) do
                    if i and i.Name == "Broken" then
                        if functions.Unbreaklimbs then
                            i.Value = false
                            i:GetPropertyChangedSignal("Value"):Connect(function()
                                if functions.Unbreaklimbs then
                                    i.Value = false
                                end
                            end)
                        end
                    end
                end
            end
        end)
    end
})

Tabs.Combat:Toggle({
    Title = "静默瞄准",
    Description = "自动瞄准敌人",
    Default = functions.SilentAim,
    Callback = function(Value)
        functions.SilentAim = Value
        if Value then
            cockie.SilentAimCircle = Drawing.new("Circle")
            cockie.SilentAimCircle.Color = Color3.new(1, 1, 1)
            cockie.SilentAimCircle.Thickness = 2
            cockie.SilentAimCircle.NumSides = 50
            cockie.SilentAimCircle.Radius = SectionSettings.SilentAim.DrawSize
            cockie.SilentAimCircle.Filled = false
            cockie.SilentAimCircle.Visible = true

            cockie.SilentAimCircle.Position = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)

            local target = nil

            local function GetClosest()
                target = nil
                local shortest = SectionSettings.SilentAim.DrawSize
                for _, a in pairs(plrs:GetPlayers()) do
                    if a ~= me and a.Character then

                        if SectionSettings.SilentAim.CheckDowned and CharStats(a).Downed.Value == true then
                            continue
                        end

                        if SectionSettings.SilentAim.CheckTeam and a.Team == me.Team then
                            continue
                        end

                        if SectionSettings.SilentAim.CheckWhiteList and table.find(WhiteList, a) then
                            continue
                        end

                        local hrp = a.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local screenpos, onScreen = camera:WorldToViewportPoint(hrp.Position)
                            if onScreen then
                                local dist = (Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2) - Vector2.new(screenpos.X, screenpos.Y)).Magnitude
                                if dist < shortest then
                                    target = a
                                end
                            end
                        end
                    end
                end
            end

            run.RenderStepped:Connect(GetClosest)

            local VisualizeEvent = rp.Events2.Visualize
            local DamageEvent = rp.Events["ZFKLF__H"]

            VisualizeEvent.Event:Connect(function(_, ShotCode, _, Gun, _, StartPos, BulletsPerShot)
                if not functions.SilentAim then return end
                if not Gun or not target or not target.Character or not target.Character:FindFirstChild("Humanoid") or target.Character:FindFirstChild("Humanoid").Health == 0 then return end
                if not me.Character or not me.Character:FindFirstChildOfClass("Tool") then return end

                local parts = SectionSettings.SilentAim.TargetParts[math.random(1, #SectionSettings.SilentAim.TargetParts)] or SectionSettings.SilentAim.TargetParts[1] or "Head"
                local targetPart = target.Character:FindFirstChild(parts)
                if not targetPart then return end

                local partPos = targetPart.Position
                local Bullets = {}
                for i = 1, math.clamp(#BulletsPerShot, 1, 100) do
                    table.insert(Bullets, CFrame.new(StartPos, partPos).LookVector)
                end
                task.wait(0.005)
                for i, dir in pairs(Bullets) do
                    DamageEvent:FireServer("🧈", Gun, ShotCode, i, targetPart, partPos, dir)
                end

                if Gun:FindFirstChild("Hitmarker") then
                    Gun.Hitmarker:Fire(targetPart)
                end
            end)
        else
            if cockie.SilentAimCircle then
                cockie.SilentAimCircle:Remove()
                cockie.SilentAimCircle = nil
            end
        end
    end
})

Tabs.Combat:Slider({
    Title = "静默瞄准范围",
    Description = "调整瞄准范围大小",
    Default = SectionSettings.SilentAim.DrawSize,
    Min = 20,
    Max = 500,
    Callback = function(Value)
        SectionSettings.SilentAim.DrawSize = math.floor(Value)
        if cockie.SilentAimCircle then
            cockie.SilentAimCircle.Radius = SectionSettings.SilentAim.DrawSize
        end
    end
})

Tabs.Combat:Toggle({
    Title = "检查倒地状态",
    Description = "忽略倒地的玩家",
    Default = SectionSettings.SilentAim.CheckDowned,
    Callback = function(Value)
        SectionSettings.SilentAim.CheckDowned = Value
    end
})

Tabs.Combat:Toggle({
    Title = "检查队伍",
    Description = "忽略同队伍玩家",
    Default = SectionSettings.SilentAim.CheckTeam,
    Callback = function(Value)
        SectionSettings.SilentAim.CheckTeam = Value
    end
})

Tabs.Combat:Toggle({
    Title = "自瞄",
    Description = "自动瞄准敌人",
    Default = functions.AimBot,
    Callback = function(Value)
        functions.AimBot = Value
        if Value == true then
            cockie.aimbot_button = Instance.new("TextButton")
            cockie.aimbot_button.Parent = game.CoreGui
            cockie.aimbot_button.Name = "Aim"
            cockie.aimbot_button.BackgroundColor3 = Color3.new(0, 0, 0)
            cockie.aimbot_button.Position = UDim2.new(0.689, 0, 0.521, 0)
            cockie.aimbot_button.Size = UDim2.new(0, 40, 0, 40)
            cockie.aimbot_button.TextSize = 10
            cockie.aimbot_button.TextColor3 = Color3.new(1, 1, 1)
            cockie.aimbot_button.Text = "Aim"
            cockie.aimbot_button.Visible = true

            local target = nil
            local pressed = false
            local aimtarget
            local canusing = false
            local FirstPerson = true
            local predict = 15

            local part
            local randpart = nil
            local LastTick = tick()

            cockie.AimBotCircle = Drawing.new("Circle")
            cockie.AimBotCircle.Color = Color3.new(1, 1, 1)
            cockie.AimBotCircle.Thickness = 2
            cockie.AimBotCircle.NumSides = 50
            cockie.AimBotCircle.Radius = SectionSettings.Aimbot.DrawSize
            cockie.AimBotCircle.Filled = false
            cockie.AimBotCircle.Visible = true

            local centerScreen = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
            cockie.AimBotCircle.Position = centerScreen

            local function getClosestTarget()
                local closest, closestDist = nil, SectionSettings.Aimbot.DrawSize
                for _, player in pairs(plrs:GetPlayers()) do
                    if player ~= me and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then

                        local count = #SectionSettings.Aimbot.TargetParts

                        if count == 0 then
                            part = "Head"
                        elseif count == 1 then
                            part = SectionSettings.Aimbot.TargetParts[count]
                        elseif count > 1 then
                            if tick() - LastTick >= .5 then
                                local rand = math.random(1, count)
                                randpart = SectionSettings.Aimbot.TargetParts[rand]
                                LastTick = tick()
                            end
                            part = randpart or SectionSettings.Aimbot.TargetParts[1]
                        end

                        local pos, onScreen = camera:WorldToViewportPoint(player.Character:FindFirstChild(part).Position)
                        if onScreen then
                            if SectionSettings.Aimbot.CheckTeam and player.Team == me.Team then
                                continue
                            end
                            if SectionSettings.Aimbot.CheckWhiteList and table.find(WhiteList, player) then
                                continue
                            end

                            local centerScreen = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                            local distance = (Vector2.new(pos.X, pos.Y) - centerScreen).Magnitude
                            if distance < closestDist then
                                closestDist = distance
                                closest = player
                            end
                        end
                    end
                end
                return closest
            end

            cockie.aimbot_button.MouseButton1Click:Connect(function()
                pressed = not pressed
                aimtarget = getClosestTarget() or nil
            end)

            run.RenderStepped:Connect(function()
                if FirstPerson then
                    local magnitude = (camera.Focus.p - camera.CFrame.p).Magnitude
                    canusing = magnitude <= 1.5
                end
                if functions.AimBot and pressed and aimtarget and aimtarget.Character then
                    local head = aimtarget.Character:FindFirstChild(part)
                    local humanoid = aimtarget.Character:FindFirstChild("Humanoid")
                    if head and humanoid and humanoid.Health ~= 0 and canusing then
                        local targetPosition = head.Position

                        if SectionSettings.Aimbot.CheckDowned and CharStats(target).Downed.Value == true then
                            return
                        end

                        if SectionSettings.Aimbot.Velocity then
                            targetPosition = targetPosition + head.Velocity / predict
                        end
                        camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.p, targetPosition), 0.9)
                    end
                end
            end)

        else
            if cockie.AimBotCircle then 
                cockie.AimBotCircle:Remove() 
                cockie.AimBotCircle = nil
            end
            if cockie.aimbot_button then 
                cockie.aimbot_button:Destroy()
                cockie.aimbot_button = nil
            end
        end
    end
})

Tabs.Combat:Toggle({
    Title = "近战光环",
    Description = "最好别乱用",
    Default = functions.Meleeaura,
    Callback = function(Value)
        functions.Meleeaura = Value
        if Value then
            local remote1 = rp.Events["XMHH.2"]
            local remote2 = rp.Events["XMHH2.2"]

            local part
            local randpart = nil

            local LastTick = tick()
            local AttachTick = tick()

            local attach = false
            local attachcd = .1

            local AttachCD = {
                ["Fists"] = .05,
                ["Knuckledusters"] = .05,
                ["Nunchucks"] = 0.05,
                ["Shiv"] = .05,
                ["Bat"] = 1,
                ["Metal-Bat"] = 1,
                ["Chainsaw"] = 2.5,
                ["Balisong"] = .05,
                ["Rambo"] = .3,
                ["Shovel"] = 3,
                ["Sledgehammer"] = 2,
                ["Katana"] = .1,
                ["Wrench"] = .1,
                ["FireAxe"] = 2.6
            }

            local function Attack(target)
                if not (target and target:FindFirstChild("Head")) then return end

                local mychar = me.Character
                if not mychar then return end
                local TOOL = mychar:FindFirstChildOfClass("Tool")
                if not TOOL then return end
                local AnimFolder = TOOL:FindFirstChild("AnimsFolder")
                if not AnimFolder then return end
                local anim = AnimFolder:FindFirstChild("Slash1")
                if not anim then return end

                if tick() - AttachTick >= attachcd then
                    local result = remote1:InvokeServer("🍞", tick(), TOOL, "43TRFWX", "Normal", tick(), true)

                    attachcd = AttachCD[TOOL.Name] or 1/2

                    if SectionSettings.MeleeAura.ShowAnim then
                        local load = me.Character:FindFirstChildOfClass("Humanoid"):FindFirstChild("Animator"):LoadAnimation(anim)
                        load:Play()
                        load:AdjustSpeed(1.3)
                    end

                    task.wait(0.3 + math.random() * 0.2)

                    if TOOL then
                        local Handle = TOOL:FindFirstChild("WeaponHandle") or TOOL:FindFirstChild("Handle") or me.Character:FindFirstChild("Right Arm")
                        local arg2 = {
                            "🍞",
                            tick(),
                            TOOL,
                            "2389ZFX34",
                            result,
                            true,
                            Handle,
                            target:FindFirstChild(part),
                            target,
                            me.Character.HumanoidRootPart.Position,
                            target:FindFirstChild(part).Position
                        }
                        if TOOL.Name == "Chainsaw" then
                            for i = 1, 15 do
                                remote2:FireServer(unpack(arg2)) 
                            end
                        else
                            remote2:FireServer(unpack(arg2))
                        end
                        AttachTick = tick()
                    else
                        return
                    end
                end
            end

            while functions.Meleeaura do
                local mychar = me.Character or me.CharacterAdded:Wait()
                if mychar then
                    local myhrp = mychar:FindFirstChild("HumanoidRootPart")
                    if myhrp then
                        for _, a in ipairs(plrs:GetPlayers()) do
                            if a ~= me then
                                local char = a.Character
                                if char then
                                    local hrp = char:FindFirstChild("HumanoidRootPart")
                                    if hrp then
                                        local distance = (myhrp.Position - hrp.Position).Magnitude
                                        if distance < SectionSettings.MeleeAura.Distance and a.Character:FindFirstChildOfClass("Humanoid").Health ~= 0 and not char:FindFirstChildOfClass("ForceField") then

                                            if SectionSettings.MeleeAura.CheckWhiteList and table.find(WhiteList, a) then
                                                continue
                                            end

                                            if SectionSettings.MeleeAura.CheckTeam and a.Team == me.Team then
                                                continue
                                            end

                                            if SectionSettings.MeleeAura.CheckDowned and CharStats(a).Downed.Value == true then
                                                continue
                                            end

                                            local count = #SectionSettings.MeleeAura.TargetParts

                                            if count == 0 then
                                                part = "Head"
                                            elseif count == 1 then
                                                part = SectionSettings.MeleeAura.TargetParts[#SectionSettings.MeleeAura.TargetParts]
                                            elseif count > 1 then
                                                if tick() - LastTick >= .2 then
                                                    local rand = math.random(1, count)
                                                    randpart = SectionSettings.MeleeAura.TargetParts[rand]
                                                    LastTick = tick()
                                                end
                                                part = randpart or SectionSettings.MeleeAura.TargetParts[1]
                                            end

                                            Attack(char)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                run.Heartbeat:Wait()
            end
        end
    end
})

Tabs.Combat:Toggle({
    Title = "显示动画",
    Description = "显示攻击动画",
    Default = SectionSettings.MeleeAura.ShowAnim,
    Callback = function(Value)
        SectionSettings.MeleeAura.ShowAnim = Value
    end
})

Tabs.Combat:Toggle({
    Title = "愤怒机器人",
    Description = "自动射击附近敌人",
    Default = functions.RageBot,
    Callback = function(Value)
        functions.RageBot = Value
        if Value then
            local function RandomString(length)
                local res = ""
                for i = 1, length do
                    res = res .. string.char(math.random(97, 122))
                end
                return res
            end

            local function GetClosestEnemy()
                if not me.Character 
                    or not me.Character:FindFirstChild("HumanoidRootPart") 
                then return nil end

                local closestEnemy = nil
                local shortestDistance = 100

                for _, player in pairs(plrs:GetPlayers()) do
                    if player == me then continue end

                    local character = player.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

                    if character 
                        and rootPart 
                        and humanoid 
                        and humanoid.Health > 15 
                        and not character:FindFirstChildOfClass("ForceField") 
                    then
                        if SectionSettings.RageBot.CheckWhiteList and table.find(WhiteList, player) then
                            continue
                        end

                        local distance = (rootPart.Position - me.Character.HumanoidRootPart.Position).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestEnemy = player
                        end
                    end
                end
                return closestEnemy
            end

            local function Shoot(target)
                if not target or not target.Character then return end

                local head = target.Character:FindFirstChild("Head")
                if not head then return end

                local tool = me.Character and me.Character:FindFirstChildOfClass("Tool")
                if not tool then return end

                local values = tool:FindFirstChild("Values")
                local hitMarker = tool:FindFirstChild("Hitmarker")
                if not values or not hitMarker then return end

                local ammo = values:FindFirstChild("SERVER_Ammo")
                local storedAmmo = values:FindFirstChild("SERVER_StoredAmmo")
                if not ammo or not storedAmmo then return end

                local hitPosition = head.Position
                local hitDirection = (hitPosition - camera.CFrame.Position).unit
                local randomKey = RandomString(30) ..0

                if tool.Name == "Beretta" or tool.Name == "TEC-9" then
                    if ammo.Value > 0 then
                        rp.Events.GNX_S:FireServer(
                            tick(),
                            randomKey,
                            tool,
                            "FDS9I83",
                            camera.CFrame.Position,
                            {hitDirection},
                            false
                        )

                        task.delay(0.00001, function()
                            rp.Events["ZFKLF__H"]:FireServer(
                                "🧈",
                                tool,
                                randomKey,
                                1,
                                head,
                                hitPosition,
                                hitDirection
                            )

                            ammo.Value = math.max(ammo.Value - 1, 0)
                            hitMarker:Fire(head)
                            storedAmmo.Value = values:FindFirstChild("SERVER_StoredAmmo").Value
                            rp.Events.GNX_R:FireServer(tick(), "KLWE89U0", tool)
                        end)
                    end
                end
            end

            local function RageBotLoop()
                while functions.RageBot do
                    if me.Character and me.Character:FindFirstChildOfClass("Tool") then
                        local target = GetClosestEnemy()
                        if target then
                            Shoot(target)
                        end
                    end
                    run.RenderStepped:Wait()
                end
            end
            RageBotLoop()
        end
    end
})

Tabs.Combat:Toggle({
    Title = "瞬间换弹",
    Description = "瞬间完成换弹",
    Default = functions.Instantreload,
    Callback = function(Value)
        functions.Instantreload = Value
        local gunR_remote = rp.Events.GNX_R
        if Value then
            local charme = me.Character
            if charme then
                local tool = charme:FindFirstChildOfClass("Tool")
                if tool and tool:FindFirstChild("IsGun") then
                    local value = tool:FindFirstChild("Values"):FindFirstChild("SERVER_Ammo")
                    local value2 = tool:FindFirstChild("Values"):FindFirstChild("SERVER_StoredAmmo")
                    value2:GetPropertyChangedSignal("Value"):Connect(function()
                        if functions.Instantreload then
                            gunR_remote:FireServer(tick(), "KLWE89U0", tool);
                        end
                    end)
                    if value2.Value ~= 0 then
                        if functions.Instantreload then
                            gunR_remote:FireServer(tick(), "KLWE89U0", tool);
                        end
                    end
                    value:GetPropertyChangedSignal("Value"):Connect(function()
                        if functions.Instantreload and value2.Value ~= 0 then
                            gunR_remote:FireServer(tick(), "KLWE89U0", tool);
                        end
                    end)
                else
                    charme.ChildAdded:Connect(function(obj)
                        if obj:IsA("Tool") and obj:FindFirstChild("IsGun") then
                            local value = obj:FindFirstChild("Values"):FindFirstChild("SERVER_Ammo")
                            local value2 = obj:FindFirstChild("Values"):FindFirstChild("SERVER_StoredAmmo")
                            value2:GetPropertyChangedSignal("Value"):Connect(function()
                                if functions.Instantreload then
                                    gunR_remote:FireServer(tick(), "KLWE89U0", obj);
                                end
                            end)
                            if value2.Value ~= 0 then
                                if functions.Instantreload then
                                    gunR_remote:FireServer(tick(), "KLWE89U0", obj);
                                end
                            end
                            value:GetPropertyChangedSignal("Value"):Connect(function()
                                if functions.Instantreload and value2.Value ~= 0 then
                                    gunR_remote:FireServer(tick(), "KLWE89U0", obj);
                                end
                            end)
                        end
                    end)
                end
                me.CharacterAdded:Connect(function(charr)
                    repeat wait() until charr and charr.Parent
                    charr.ChildAdded:Connect(function(obj)
                        if obj:IsA("Tool") and obj:FindFirstChild("IsGun") then
                            local value = obj:FindFirstChild("Values"):FindFirstChild("SERVER_Ammo")
                            local value2 = obj:FindFirstChild("Values"):FindFirstChild("SERVER_StoredAmmo")
                            value2:GetPropertyChangedSignal("Value"):Connect(function()
                                if functions.Instantreload then
                                    gunR_remote:FireServer(tick(), "KLWE89U0", obj);
                                end
                            end)
                            if value2.Value ~= 0 then
                                if functions.Instantreload then
                                    gunR_remote:FireServer(tick(), "KLWE89U0", obj);
                                end
                            end
                            value:GetPropertyChangedSignal("Value"):Connect(function()
                                if functions.Instantreload and value2.Value ~= 0 then
                                    gunR_remote:FireServer(tick(), "KLWE89U0", obj);
                                end
                            end)
                        end
                    end)
                end)
            end
        end
    end
})

Tabs.Visual:Toggle({
    Title = "ESP",
    Description = "显示玩家轮廓",
    Default = functions.ESP,
    Callback = function(Value)
        functions.ESP = Value
        if Value then
            RUNS.ESP = run.Heartbeat:Connect(function()
                if SectionSettings.ESP.Highlight then
                    local function Update()
                        for _, a in pairs(plrs:GetPlayers()) do
                            if a ~= me then
                                local char = a.Character
                                if char and not char:FindFirstChild("Highlight") then
                                    local hg = Instance.new("Highlight")
                                    hg.Parent = char
                                    hg.FillTransparency = 1
                                end
                            end
                        end
                    end
                    Update()

                    plrs.PlayerAdded:Connect(function(player)
                        if functions.ESP then
                            local char = player.Character or player.CharacterAdded:Wait()
                            if char and SectionSettings.ESP.Highlight and not char:FindFirstChild("Highlight") then
                                local hg = Instance.new("Highlight")
                                hg.Parent = char
                                hg.FillTransparency = 1
                            end
                        end
                    end)
                else
                    for _, a in pairs(plrs:GetPlayers()) do
                        if a ~= me then
                            local char = a.Character
                            if char then
                                local h = char:FindFirstChild("Highlight")
                                if h then h:Destroy() end
                            end
                        end
                    end
                end
            end)
        else
            if RUNS.ESP then
                RUNS.ESP:Disconnect()
                RUNS.ESP = nil
            end
            for _, a in pairs(plrs:GetPlayers()) do
                if a ~= me then
                    local char = a.Character
                    if char then
                        local h = char:FindFirstChild("Highlight")
                        if h then h:Destroy() end
                    end
                end
            end
        end
    end
})

Tabs.Visual:Toggle({
    Title = "高亮显示",
    Description = "高亮显示其他玩家",
    Default = SectionSettings.ESP.Highlight,
    Callback = function(Value)
        SectionSettings.ESP.Highlight = Value
    end
})

Tabs.Visual:Toggle({
    Title = "手臂特效",
    Description = "改变手臂材质",
    Default = functions.ArmsChams,
    Callback = function(Value)
        functions.ArmsChams = Value
        local viewfolder = camera:WaitForChild("ViewModel")
        if Value == true then
            viewfolder["Left Arm"].Material = Enum.Material.ForceField
            viewfolder["Right Arm"].Material = Enum.Material.ForceField
        else
            viewfolder["Left Arm"].Material = Enum.Material.Plastic
            viewfolder["Right Arm"].Material = Enum.Material.Plastic
        end
        me.CharacterAdded:Connect(function(char)
            repeat wait() until char and char.Parent
            local viewfolder = camera:WaitForChild("ViewModel")
            if functions.ArmsChams == true then
                viewfolder["Left Arm"].Material = Enum.Material.ForceField
                viewfolder["Right Arm"].Material = Enum.Material.ForceField
            else
                viewfolder["Left Arm"].Material = Enum.Material.Plastic
                viewfolder["Right Arm"].Material = Enum.Material.Plastic
            end
        end)
    end
})

Tabs.Misc:Button({
    Title = "清理效果",
    Description = "清理所有视觉效果",
    Callback = function()
        if cockie.SilentAimCircle then
            cockie.SilentAimCircle:Remove()
            cockie.SilentAimCircle = nil
        end
        
        if cockie.AimBotCircle then
            cockie.AimBotCircle:Remove()
            cockie.AimBotCircle = nil
        end
        
        if cockie.aimbot_button then
            cockie.aimbot_button:Destroy()
            cockie.aimbot_button = nil
        end
        
        for _, player in pairs(plrs:GetPlayers()) do
            if player ~= me then
                local char = player.Character
                if char then
                    local h = char:FindFirstChild("Highlight")
                    if h then h:Destroy() end
                end
            end
        end
        
        WindUI:Notify({
            Title = "清理完成",
            Content = "所有视觉效果已清理",
            Duration = 3
        })
    end
})

Tabs.Misc:Button({
    Title = "重置设置",
    Description = "重置所有功能设置",
    Callback = function()
        for key, _ in pairs(functions) do
            functions[key] = false
        end
        
        for key, connection in pairs(RUNS) do
            if connection then
                connection:Disconnect()
                RUNS[key] = nil
            end
        end
        
        WindUI:Notify({
            Title = "重置完成",
            Content = "所有设置已重置",
            Duration = 3
        })
    end
})

WindUI:Notify({
    Title = "XS Mobile",
    Content = "XS功能菜单已加载完成！",
    Duration = 5
})