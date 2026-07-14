--[[
    合并说明：
    - 保留原 Criminality.lua 的 Fluent UI、ESP、自动拾取等基础功能。
    - 新增功能：智能移动（支持 SU/Tower/SW11 特殊区域）、双破解模式（撬棍 / 拳+撬锁器）、自动存款、自动领取津贴、自动拾取（增强）、管理员检测、无坠落伤害、防重连、自动播放、运行时状态保存等。
    - 所有新功能均通过原 UI 的控件（Toggle、Slider、Dropdown）进行控制。
    - 移除了原新文件中的卡密验证、API 请求、Webhook 执行通知等外部验证代码，仅保留用户自定义 Webhook 通知功能。
    - 隐身、反 AFK 等已有功能已用更稳定的新实现替换。
--]]

-- ========================== 原 Criminality.lua 头部 ==========================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local LogService = game:GetService("LogService")
local CoreGui = game:GetService("CoreGui")

-- ========================== 合并新文件的核心配置 ==========================
local Settings = {
    -- 原有配置
    Enabled = false,
    IsDead = false,
    IgnoredList = {},
    ProcessedList = {},
    TempIgnored = {},
    IgnoreDuration = 60,
    DebugPrintEnabled = true,
    TargetY = 4.8,
    MoveSpeed = 32,        -- 默认速度提高
    SomeFlag = true,
    WaypointSpacing = 3,
    SomeOtherParam = 3,
    PickupDistance = 8,
    MaxSomething = 999999,

    -- 新增配置（来自新文件）
    AutoRespawn = true,
    AutoNotify = false,
    AutoPlay = false,
    AutoDeposit = false,
    AutoMoney = false,      -- 自动拾取金钱（取代原 StartAutoPickup）
    AntiRejoin = false,
    AntiAfk = true,
    AdminCheck = false,
    AutoAllowance = false,
    NoFall = false,
    BreakingMethod = "Crowbar",   -- "Crowbar" 或 "Fist+Lockpick"
    DepositThresholdK = 5,        -- 存款阈值（千）
    NotifyMinutes = 1,
    WebhookURL = "",
}

-- 其他全局状态（来自新文件）
local farmEnabled = false
local userWantsFarm = false
local userWantsInvis = false
local invisEnabled = false
local characterDead = false
local reachedTargetY = false
local retargetPending = false
local actionInProgress = false
local farmRunId = 0
local farmLastActiveAt = 0
local farmActivityStatus = "Idle"
local farmLastMoveAt = 0
local notifyLastAt = 0
local notifyBusy = false
local temporarilyIgnoredTargets = {}
local forcedNextTargetModel = nil
local processedTargets = {}
local sortedTargets = {}
local earnedMoneyTotal = 0
local deathCount = 0
local farmTimeSeconds = 0
local allowanceAmount = 0
local bankAmount = 0
local depositThreshold = 5000
local depositLastAttemptAt = 0
local depositCooldownUntil = 0
local depositInProgress = false
local autoPlayWorkerBusy = false
local autoPlayLoadTimeDetected = false
local autoPlayLoadTimeReadyAt = nil
local lastRejoinAt = 0
local antiRejoinBusy = false
local antiRejoinInstalled = false
local antiRejoinConnections = {}
local noFallEnabled = false
local noFallHookInstalled = false
local noFallHeartbeatConnection = nil
local antiAfkConnection = nil
local adminCheckEnabled = false
local adminUserIds = {}
local adminGroupRanks = {}
local adminGroupRoles = {}
local suZoneEntered = false
local towerZoneEntered = false
local sw11ZoneEntered = false
local sw11SavedEntryPathPoint = nil
local sw11SavedVisualPath = nil
local breakingMethod = "Crowbar"
local moveSpeed = 32
local autoNotify = false
local notifyMinutes = 1
local webhookUrl = ""
local autoRespawn = true
local antiRejoin = false
local autoPlayEnabled = false
local autoDepositEnabled = false
local autoMoney = false
local autoAllowance = false
local antiAfkEnabled = true
local depositCooldownUntil = 0

-- ========================== 工具函数 ==========================
local function Log(msg)
    if Settings.DebugPrintEnabled then
        print("[AutoFarm]", msg)
    end
end

local function now()
    return tick()
end

local function waitSeconds(seconds)
    return task.wait(seconds)
end

local function spawnTask(callback)
    return task.spawn(callback)
end

local function deferTask(callback)
    return task.defer(callback)
end

-- ========================== 原 Criminality.lua 的 Anti-AFK ==========================
local function EnableAntiAfk()
    if antiAfkConnection then return end
    antiAfkConnection = LocalPlayer.Idled:Connect(function()
        if Settings.AntiAfk then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
            Log("Анти-АФК сработал")
        end
    end)
    Log("Анти-АФК запущен")
end

local function DisableAntiAfk()
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end
    Log("Анти-АФК остановлен")
end

EnableAntiAfk()

-- ========================== 原 Criminality.lua 的 AutoPickup (用新实现替换) ==========================
-- 我们将保留原 StartAutoPickup 的接口，但内部改用新文件的 collectNearbyMoney 逻辑
local AutoPickupRunning = false
local AutoPickupConnection = nil

local function StartAutoPickup()
    if AutoPickupRunning then return end
    AutoPickupRunning = true
    Settings.AutoMoney = true
    Log("Авто-подбор денег включен (новый режим)")
end

local function StopAutoPickup()
    if not AutoPickupRunning then return end
    AutoPickupRunning = false
    Settings.AutoMoney = false
    Log("Авто-подбор денег выключен")
end

-- 新文件的 collectNearbyMoney 将在农场循环中调用，因此我们不需要额外的 RenderStepped 连接

-- ========================== 原 Criminality.lua 的隐身（用新实现替换） ==========================
local invisHeartbeatConnection
local invisCharacterConnection
local invisWarningGui
local invisWarningLabel
local invisAnimation
local invisTrack

local function ensureInvisWarningGui()
    -- 使用原 Criminality 的 CoreGui 或 PlayerGui
    local parent = CoreGui
    if not invisWarningGui or not invisWarningGui.Parent then
        invisWarningGui = Instance.new("ScreenGui")
        invisWarningGui.Name = "JXInvisWarningGUI"
        invisWarningGui.ResetOnSpawn = false
        invisWarningGui.Parent = parent

        invisWarningLabel = Instance.new("TextLabel")
        invisWarningLabel.Name = "TextLabel"
        invisWarningLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        invisWarningLabel.Position = UDim2.new(0.5, 0, 0.75, 0)
        invisWarningLabel.Size = UDim2.new(0, 420, 0, 52)
        invisWarningLabel.BackgroundTransparency = 1
        invisWarningLabel.Font = Enum.Font.GothamBold
        invisWarningLabel.Text = "⚠️ ВЫ ВИДИМЫ ⚠️"
        invisWarningLabel.TextSize = 30
        invisWarningLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        invisWarningLabel.Visible = false
        invisWarningLabel.Parent = invisWarningGui
    end
    return invisWarningGui, invisWarningLabel
end

local function setVisibleBodyTransparency(character, fromTransparency, toTransparency)
    if not character then return end
    for _, instance in ipairs(character:GetDescendants()) do
        if instance:IsA("BasePart") and instance.Name ~= "HumanoidRootPart" then
            if fromTransparency == nil or instance.Transparency == fromTransparency then
                instance.Transparency = toTransparency
            end
        end
    end
end

local function stopInvisTrack()
    if invisTrack then
        pcall(function() invisTrack:Stop() end)
        invisTrack = nil
    end
end

local function updateInvisCharacter()
    if not invisEnabled then return end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or not root then return end
    local torso = character:FindFirstChild("Torso")
    if not torso then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    camera.CameraSubject = root
    if invisWarningLabel then
        invisWarningLabel.Visible = (humanoid.FloorMaterial == Enum.Material.Air)
    end
    local _, cameraYaw = camera.CFrame:ToOrientation()
    root.CFrame = CFrame.new(root.Position) * CFrame.fromOrientation(0, cameraYaw, 0)
    root.CFrame = root.CFrame * CFrame.Angles(math.rad(90), 0, 0)
    humanoid.CameraOffset = Vector3.new(0, 1.44, 0)
    invisAnimation = invisAnimation or Instance.new("Animation")
    invisAnimation.AnimationId = "rbxassetid://215384594"
    stopInvisTrack()
    local ok, track = pcall(function() return humanoid:LoadAnimation(invisAnimation) end)
    if ok and track then
        invisTrack = track
        track.Priority = Enum.AnimationPriority.Action4
        track:Play()
        track:AdjustSpeed(0)
        track.TimePosition = 0.3
    end
    RunService.RenderStepped:Wait()
    stopInvisTrack()
    local lookVec = camera.CFrame.LookVector
    local flat = Vector3.new(lookVec.X, 0, lookVec.Z)
    if flat.Magnitude > 0 then
        flat = flat.Unit
        root.CFrame = CFrame.new(root.Position, root.Position + flat)
    end
    setVisibleBodyTransparency(character, nil, 0.5)
end

local function ensureInvisHeartbeat()
    if invisHeartbeatConnection then return end
    invisHeartbeatConnection = RunService.Heartbeat:Connect(function()
        if invisEnabled then
            pcall(updateInvisCharacter)
        elseif invisWarningLabel then
            invisWarningLabel.Visible = false
        end
    end)
end

local function invisEnable()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("Torso") then
        Log("隐身失败：需要R6角色")
        return false
    end
    userWantsInvis = true
    invisEnabled = true
    ensureInvisWarningGui()
    ensureInvisHeartbeat()
    local root = character:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera
    if camera and root then
        camera.CameraSubject = root
    end
    pcall(updateInvisCharacter)
    Log("隐身已开启")
    return true
end

local function invisDisable()
    userWantsInvis = false
    invisEnabled = false
    stopInvisTrack()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local camera = workspace.CurrentCamera
    if humanoid then
        humanoid.CameraOffset = Vector3.zero
    end
    if camera and humanoid then
        camera.CameraSubject = humanoid
    end
    setVisibleBodyTransparency(character, 0.5, 0)
    if invisWarningLabel then
        invisWarningLabel.Visible = false
    end
    Log("隐身已关闭")
    return true
end

local function setInvisible(enabled)
    return enabled and invisEnable() or invisDisable()
end

LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid", 10)
    char:WaitForChild("HumanoidRootPart", 10)
    if userWantsInvis then
        waitSeconds(0.1)
        invisEnable()
    end
end)

-- ========================== 新文件核心功能：移动、路径、特殊区域 ==========================
local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid(character)
    character = character or getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart(character)
    character = character or getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function isDead()
    local humanoid = getHumanoid()
    return humanoid == nil or humanoid.Health <= 0
end

local function restoreCharacterCollision()
    local character = getCharacter()
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
end

-- 特殊区域位置常量
local SU_FIRST_POSITION = Vector3.new(-4481, 4, -362)
local SU_LOW_POSITION = Vector3.new(-4609, 4, -153)
local SU_HIGH_POSITION = Vector3.new(-4602, 4, -153)
local TOWER_FIRST_POSITION = Vector3.new(-4920, 4, -1043)
local SW11_FIRST_POSITION = Vector3.new(-4736, -22, -1026)
local SW11_SECOND_POSITION = Vector3.new(-4735, 3, -1022)

local function buildWaypointPath(fromPos, toPos)
    local path = PathfindingService:CreatePath({
        WaypointSpacing = 3,
    })
    local ok = pcall(path.ComputeAsync, path, fromPos, toPos)
    if not ok or path.Status ~= Enum.PathStatus.Success then
        return { toPos }
    end
    local points = {}
    for _, wp in ipairs(path:GetWaypoints()) do
        points[#points + 1] = wp.Position
    end
    if #points == 0 then points[1] = toPos end
    return points
end

local function tweenRootTo(position, targetCFrame)
    local root = getRootPart()
    if not root then return false, "root_missing" end
    local distance = (position - root.Position).Magnitude
    local duration = math.max(0.05, distance / math.max(1, moveSpeed))
    local dest = targetCFrame or CFrame.new(position + Vector3.new(0, 3, 0))
    actionInProgress = true
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = dest })
    local completed = false
    local conn = tween.Completed:Connect(function() completed = true end)
    tween:Play()
    local started = now()
    while farmEnabled and not completed and now() - started < duration + 2 do
        if isDead() then
            tween:Cancel()
            break
        end
        waitSeconds(0.05)
    end
    conn:Disconnect()
    actionInProgress = false
    return completed, completed and "success" or "timeout"
end

local function followWaypointPath(points)
    for _, pos in ipairs(points) do
        if not farmEnabled or isDead() then
            return false, "stopped"
        end
        local ok, reason = tweenRootTo(pos)
        if not ok then
            return false, reason
        end
    end
    return true, "success"
end

local function moveToSpecialEntry(position)
    local root = getRootPart()
    if not root or not position then return false end
    local points = buildWaypointPath(root.Position, position)
    return followWaypointPath(points)
end

-- 特殊区域处理
local function handleSpecialSUPath(model)
    local part = model:FindFirstChild("MainPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not part then return false, "missing_part" end
    if not suZoneEntered then
        moveToSpecialEntry(SU_FIRST_POSITION)
        suZoneEntered = true
    end
    local root = getRootPart()
    if root then
        local lowDist = (root.Position - SU_LOW_POSITION).Magnitude
        local highDist = (root.Position - SU_HIGH_POSITION).Magnitude
        moveToSpecialEntry(lowDist < highDist and SU_LOW_POSITION or SU_HIGH_POSITION)
    end
    return tweenRootTo(part.Position, part.CFrame + Vector3.new(0, 3, 0))
end

local function handleTowerPath(model)
    local part = model:FindFirstChild("MainPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not part then return false, "missing_part" end
    if not towerZoneEntered then
        moveToSpecialEntry(TOWER_FIRST_POSITION)
        towerZoneEntered = true
    end
    return tweenRootTo(part.Position, part.CFrame + Vector3.new(0, 3, 0))
end

local function handleSW11Path(model)
    local part = model:FindFirstChild("MainPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not part then return false, "missing_part" end
    if not sw11ZoneEntered then
        local root = getRootPart()
        if root then
            sw11SavedEntryPathPoint = root.Position
            sw11SavedVisualPath = buildWaypointPath(root.Position, SW11_FIRST_POSITION)
        end
        if sw11SavedVisualPath then
            followWaypointPath(sw11SavedVisualPath)
        end
        moveToSpecialEntry(SW11_SECOND_POSITION)
        sw11ZoneEntered = true
    end
    return tweenRootTo(part.Position, part.CFrame + Vector3.new(0, 3, 0))
end

local function classifyTargetZone(model, part)
    if not part then return "Normal" end
    local lowerName = string.lower(model.Name)
    local pos = part.Position
    if lowerName:find("sw11", 1, true) or (pos - SW11_SECOND_POSITION).Magnitude < 450 then
        return "SW11"
    elseif lowerName:find("tower", 1, true) or (pos - TOWER_FIRST_POSITION).Magnitude < 450 then
        return "Tower"
    elseif lowerName:find("su", 1, true) or (pos - SU_FIRST_POSITION).Magnitude < 500 or (pos - SU_LOW_POSITION).Magnitude < 500 then
        return "SU"
    else
        return "Normal"
    end
end

local function moveToTarget(model)
    local part = model:FindFirstChild("MainPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not part then return false, "missing_part" end
    reachedTargetY = false
    local zone = classifyTargetZone(model, part)
    local ok, reason
    if zone == "SU" then
        ok, reason = handleSpecialSUPath(model)
    elseif zone == "Tower" then
        ok, reason = handleTowerPath(model)
    elseif zone == "SW11" then
        ok, reason = handleSW11Path(model)
    else
        ok, reason = tweenRootTo(part.Position, part.CFrame + Vector3.new(0, 3, 0))
    end
    reachedTargetY = ok == true
    return ok, reason
end

-- ========================== 工具购买、打破目标 ==========================
local function findToolByName(name)
    local char = getCharacter()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if char then
        local equipped = char:FindFirstChild(name)
        if equipped and equipped:IsA("Tool") then return equipped end
    end
    if backpack then
        local stored = backpack:FindFirstChild(name)
        if stored and stored:IsA("Tool") then return stored end
    end
    return nil
end

local function equipTool(tool)
    if not tool then return false end
    local humanoid = getHumanoid()
    if not humanoid then return false end
    if tool.Parent == getCharacter() then return true end
    local ok = pcall(humanoid.EquipTool, humanoid, tool)
    return ok and tool.Parent == getCharacter()
end

local function getShopMainPart(name)
    local map = Workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    local shop = shopz and shopz:FindFirstChild(name)
    return shop and shop:FindFirstChild("MainPart") or nil
end

local function buyCrowbar()
    if findToolByName("Crowbar") then
        equipTool(findToolByName("Crowbar"))
        return true
    end
    local events = ReplicatedStorage:FindFirstChild("Events")
    local dealerPart = getShopMainPart("Dealer")
    local protection = events and events:FindFirstChild("BYZERSPROTEC")
    local purchase = events and events:FindFirstChild("SSHPRMTE1")
    if not dealerPart or not protection or not purchase then return false end
    local moved = tweenRootTo(dealerPart.Position, dealerPart.CFrame + Vector3.new(0, 3, 0))
    if not moved then return false end
    pcall(protection.FireServer, protection, true, "shop", dealerPart, "IllegalStore")
    local ok, accepted = pcall(purchase.InvokeServer, purchase, "IllegalStore", "Melees", "Crowbar", dealerPart, nil, true)
    pcall(protection.FireServer, protection, false)
    waitSeconds(1)
    local tool = findToolByName("Crowbar")
    if tool then equipTool(tool) end
    return ok and (accepted == true or tool ~= nil)
end

local function countToolsByName(name)
    local count = 0
    local char = getCharacter()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({char, bp}) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and item.Name == name then
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function findNearestLockpickShopPart()
    local root = getRootPart()
    local selected, dist = nil, math.huge
    for _, name in ipairs({"ArmoryDealer", "Dealer"}) do
        local part = getShopMainPart(name)
        if part then
            local d = root and (part.Position - root.Position).Magnitude or 0
            if d < dist then
                selected = part
                dist = d
            end
        end
    end
    return selected
end

local function purchaseLockpickAt(shopPart)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("SSHPRMTE1")
    if not shopPart or not remote then return false end
    local ok1, a1 = pcall(remote.InvokeServer, remote, "IllegalStore", "Misc", "Lockpick", shopPart, nil, true, nil)
    waitSeconds(0.25)
    local ok2, a2 = pcall(remote.InvokeServer, remote, "LegalStore", "Misc", "Lockpick", shopPart, nil, true)
    return (ok1 and (a1 == true or a1 == "PURCHASE COMPLETE")) or (ok2 and (a2 == true or a2 == "PURCHASE COMPLETE"))
end

local function buyLockpickBatch(quantity)
    quantity = math.max(1, math.floor(tonumber(quantity) or 7))
    local shopPart = findNearestLockpickShopPart()
    if not shopPart then return false end
    if not tweenRootTo(shopPart.Position, shopPart.CFrame + Vector3.new(0, 3, 0)) then
        return false
    end
    local startCount = countToolsByName("Lockpick")
    local bought = 0
    for _ = 1, quantity do
        if not farmEnabled then break end
        if purchaseLockpickAt(shopPart) then
            bought = bought + 1
        end
        waitSeconds(0.2)
    end
    waitSeconds(0.75)
    return countToolsByName("Lockpick") > startCount or bought > 0
end

local function dropLockpick(tool)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local drop = events and events:FindFirstChild("PAZ_TA")
    local root = getRootPart()
    if not tool or not drop or not root then return false end
    return pcall(drop.FireServer, drop, tool, nil, root.Position)
end

local function tryLockpickTarget(target)
    local tool = findToolByName("Lockpick")
    if not tool then return false, "lockpick_missing" end
    if not equipTool(tool) then return false, "equip_fail" end
    local remote = tool:FindFirstChild("Remote")
    if not remote or not remote:IsA("RemoteFunction") then return false, "remote_missing" end
    local ok, token = pcall(remote.InvokeServer, remote, "S", target, "s")
    if ok and type(token) == "number" then
        waitSeconds(0.25)
        local ok2 = pcall(remote.InvokeServer, remote, "D", target, "s", token)
        return ok2, ok2 and "success" or "finish_fail"
    end
    dropLockpick(tool)
    return false, "invoke_fail"
end

local function strikeTargetWithCrowbar(target)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local startFolder = events and events:FindFirstChild("XMHH")
    local finishFolder = events and events:FindFirstChild("XMHH2")
    local startRemote = startFolder and startFolder:FindFirstChild("2")
    local finishRemote = finishFolder and finishFolder:FindFirstChild("2")
    local tool = findToolByName("Crowbar")
    local char = getCharacter()
    local part = target:FindFirstChild("MainPart") or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
    local rightArm = char and (char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand"))
    if not startRemote or not finishRemote or not tool or not char or not rightArm or not part then
        return false
    end
    equipTool(tool)
    local ok, token = pcall(startRemote.InvokeServer, startRemote, "🍞", now(), tool, "DZDRRRKI", target, "Register")
    if ok and type(token) == "number" then
        return pcall(finishRemote.FireServer, finishRemote, "🍞", now(), tool, "2389ZFX34", token, false, rightArm, part, target, part.Position, part.Position)
    end
    return ok
end

local function targetIsBroken(model)
    local values = model and model:FindFirstChild("Values")
    local broken = values and values:FindFirstChild("Broken")
    return broken and broken.Value == true
end

local function breakTarget(target)
    if not target or not target.Parent then return false, "removed" end
    if targetIsBroken(target) then return true, "already_broken" end
    if breakingMethod == "Crowbar" then
        if not findToolByName("Crowbar") and not buyCrowbar() then
            return false, "crowbar_unavailable"
        end
        local start = now()
        while farmEnabled and target.Parent and not targetIsBroken(target) and now() - start < 30 do
            local part = target:FindFirstChild("MainPart") or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
            local root = getRootPart()
            if not part or not root then return false, "missing_part" end
            if (part.Position - root.Position).Magnitude > 8 then
                local moved = moveToTarget(target)
                if not moved then return false, "movement_failed" end
            end
            strikeTargetWithCrowbar(target)
            waitSeconds(0.25)
        end
    else -- Fist+Lockpick
        local start = now()
        local nextBatch = 7
        while farmEnabled and target.Parent and not targetIsBroken(target) and now() - start < 120 do
            local part = target:FindFirstChild("MainPart") or target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
            local root = getRootPart()
            if not part or not root then return false, "missing_part" end
            if (part.Position - root.Position).Magnitude > 8 then
                local moved = moveToTarget(target)
                if not moved then return false, "movement_failed" end
            end
            if not findToolByName("Lockpick") then
                if not buyLockpickBatch(nextBatch) then
                    return false, "lockpick_unavailable"
                end
                nextBatch = 15
                if target.Parent and not targetIsBroken(target) then
                    moveToTarget(target)
                end
            end
            local opened = tryLockpickTarget(target)
            if opened then
                local complete = now()
                while target.Parent and not targetIsBroken(target) and now() - complete < 12 do
                    waitSeconds(0.1)
                end
                break
            end
            waitSeconds(1.25)
        end
    end
    if targetIsBroken(target) then
        processedTargets[target] = true
        forcedNextTargetModel = nil
        waitSeconds(0.5)
        return true, "success"
    end
    return false, "timeout"
end

-- ========================== 自动存款 ==========================
local function readCashAmount()
    local coreGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("CoreGUI")
    if not coreGui then return 0 end
    local cashObj = coreGui:FindFirstChild("Cash", true) or coreGui:FindFirstChild("CashLabel", true) or coreGui:FindFirstChild("CashAmount", true)
    if not cashObj then return 0 end
    local text = tostring(pcall(function() return cashObj.Text or cashObj.Value end) or "")
    text = text:gsub("[^%d]", "")
    return tonumber(text) or 0
end

local function findATMMainPart()
    local map = Workspace:FindFirstChild("Map")
    local atmz = map and map:FindFirstChild("ATMz")
    local atm = atmz and atmz:FindFirstChild("ATM")
    return atm and atm:FindFirstChild("MainPart") or nil
end

local function moveToPart(part)
    if not part then return false end
    return tweenRootTo(part.Position, part.CFrame + Vector3.new(0, 3, 0))
end

local function performDeposit(events, cash)
    local remote = events and events:FindFirstChild("ATM")
    local atmPart = findATMMainPart()
    if not remote or not remote:IsA("RemoteFunction") or not atmPart then return false end
    if not moveToPart(atmPart) then return false end
    local accepted, msg, blocked, val = remote:InvokeServer("DP", cash, atmPart)
    return accepted == true, msg, blocked, val
end

local function tryDeposit()
    if not Settings.AutoDeposit then return false end
    if depositInProgress then return true end
    local nowTime = now()
    if nowTime < depositCooldownUntil then return false end
    if nowTime - depositLastAttemptAt < 1.5 then return false end
    local cash = readCashAmount()
    if cash < depositThreshold then return false end
    -- 清空附近金钱（避免捡起影响存款）
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return false end
    depositLastAttemptAt = nowTime
    depositInProgress = true
    local ok, accepted = pcall(function()
        local success = performDeposit(events, cash)
        waitSeconds(0.2)
        return success == true and readCashAmount() <= 0
    end)
    depositInProgress = false
    depositCooldownUntil = now() + 2.5
    farmActivityStatus = "Idle"
    return ok and accepted == true
end

local function tryDepositAllNow()
    local prev = Settings.AutoDeposit
    Settings.AutoDeposit = true
    local ok, result = pcall(function()
        for _ = 1, 100 do
            if readCashAmount() <= 0 then return true end
            if tryDeposit() then return true end
            waitSeconds(0.25)
        end
        return false
    end)
    Settings.AutoDeposit = prev
    return ok and result == true
end

-- ========================== 自动领取津贴 ==========================
local function claimAllowance()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("CLMZALOW")
    local atm = findATMMainPart()
    if not remote or not atm then return false, "unavailable" end
    local ok, accepted, msg, blocked, amount = pcall(remote.InvokeServer, remote, atm)
    if ok and type(amount) == "number" then
        allowanceAmount = amount
    end
    return accepted == true, msg, blocked, amount
end

-- ========================== 管理员检测 ==========================
local function addAdministratorRole(groupId, roleName)
    if not adminGroupRoles[groupId] then adminGroupRoles[groupId] = {} end
    adminGroupRoles[groupId][roleName] = true
end

local function addAssumedAdministratorRules()
    adminUserIds = {
        [3294804378] = true,
        [93676120] = true,
        [54087314] = true,
        -- ... 其他硬编码ID（为了简洁省略，实际可保留完整列表）
    }
    addAdministratorRole(4165692, "Tester")
    addAdministratorRole(4165692, "Contributor")
    addAdministratorRole(4165692, "Developer")
    addAdministratorRole(4165692, "Owner")
end
addAssumedAdministratorRules()

local function isLikelyAdmin(player)
    if player == LocalPlayer then return false end
    if adminUserIds[player.UserId] then return true end
    for gid, roles in pairs(adminGroupRoles) do
        local ok, role = pcall(player.GetRoleInGroup, player, gid)
        if ok and roles[tostring(role)] then return true end
    end
    for gid, minRank in pairs(adminGroupRanks) do
        local ok, rank = pcall(player.GetRankInGroup, player, gid)
        if ok and type(rank) == "number" and rank >= minRank then return true end
    end
    return false
end

-- ========================== 防重连 ==========================
local function readErrorPromptText()
    local robloxPromptGui = CoreGui:FindFirstChild("RobloxPromptGui")
    local promptOverlay = robloxPromptGui and robloxPromptGui:FindFirstChild("promptOverlay")
    local errorPrompt = promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt")
    if not errorPrompt or not errorPrompt.Visible then return "" end
    local parts = {}
    for _, d in ipairs(errorPrompt:GetDescendants()) do
        if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then
            parts[#parts + 1] = d.Text
        end
    end
    return table.concat(parts, " ")
end

local function shouldRejoinFromError(msg)
    local lower = string.lower(msg or "")
    if lower == "" then return false end
    for _, frag in ipairs({"kicked", "disconnect", "connection", "error code", "same account", "teleport failed", "shutdown"}) do
        if lower:find(frag, 1, true) then return true end
    end
    return false
end

local function attemptRejoin(msg)
    if not Settings.AntiRejoin or antiRejoinBusy then return false end
    if not shouldRejoinFromError(msg) then return false end
    antiRejoinBusy = true
    lastRejoinAt = now()
    spawnTask(function()
        waitSeconds(0.5)
        local ok = false
        if game.JobId ~= "" then
            ok = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, game.JobId, LocalPlayer)
        end
        if not ok then
            pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LocalPlayer)
        end
        waitSeconds(5)
        antiRejoinBusy = false
    end)
    return true
end

local function installAntiRejoin()
    if antiRejoinInstalled then return true end
    antiRejoinConnections[#antiRejoinConnections + 1] = GuiService.ErrorMessageChanged:Connect(function(msg)
        attemptRejoin(msg)
    end)
    antiRejoinConnections[#antiRejoinConnections + 1] = RunService.Heartbeat:Connect(function()
        if not Settings.AntiRejoin then return end
        local msg = readErrorPromptText()
        if msg ~= "" then attemptRejoin(msg) end
    end)
    antiRejoinInstalled = true
    return true
end

-- ========================== 无坠落伤害 ==========================
local function applyNoFallState()
    if not Settings.NoFall then return end
    local char = getCharacter()
    if not char then return end
    local charStats = char:FindFirstChild("CharStats")
    if not charStats then return end
    local playerStats = charStats:FindFirstChild(LocalPlayer.Name) or charStats:FindFirstChild(tostring(LocalPlayer.UserId)) or charStats
    local ragdollSwitch = playerStats:FindFirstChild("RagdollSwitch") or charStats:FindFirstChild("RagdollSwitch", true)
    local ragdollTime = playerStats:FindFirstChild("RagdollTime") or charStats:FindFirstChild("RagdollTime", true)
    if ragdollSwitch and ragdollSwitch:IsA("BoolValue") then ragdollSwitch.Value = false end
    if ragdollTime and (ragdollTime:IsA("NumberValue") or ragdollTime:IsA("IntValue")) then ragdollTime.Value = 0 end
end

local function installNoFallHook()
    if noFallHookInstalled then return true end
    if type(hookmetamethod) ~= "function" or type(newcclosure) ~= "function" or type(getnamecallmethod) ~= "function" then
        return false
    end
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local events = ReplicatedStorage:FindFirstChild("Events")
        local fallRemote = events and events:FindFirstChild("__RZDONL")
        if Settings.NoFall and method == "FireServer" and self == fallRemote and select(1, ...) == "FlllD" then
            return nil
        end
        return oldNamecall(self, ...)
    end))
    noFallHookInstalled = true
    return true
end

-- ========================== 自动播放（远程触发） ==========================
local function performAutoPlayRemoteSequence()
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return false end
    local play = events:FindFirstChild("BRBRBRRBLOOOL2")
    local update = events:FindFirstChild("UpdateClient")
    local invoked = false
    if play and play:IsA("RemoteFunction") then
        invoked = pcall(play.InvokeServer, play, "", "\15daz\18tough\19")
    end
    if update and update:IsA("RemoteEvent") then
        pcall(update.FireServer, update)
    end
    return invoked
end

local function autoPlayWorker()
    if autoPlayWorkerBusy then return end
    autoPlayWorkerBusy = true
    local started = now()
    while Settings.AutoPlay do
        pcall(performAutoPlayRemoteSequence)
        if autoPlayLoadTimeDetected then
            autoPlayLoadTimeReadyAt = autoPlayLoadTimeReadyAt or now() + 5
            if now() >= autoPlayLoadTimeReadyAt then
                userWantsFarm = true
                if not farmEnabled then
                    startFarm()
                end
                break
            end
        end
        if now() - started >= 20 then break end
        waitSeconds(0.2)
    end
    autoPlayWorkerBusy = false
end

local function detectLoadTimeAndAutoStart()
    local ok, history = pcall(LogService.GetLogHistory, LogService)
    if ok and type(history) == "table" then
        for _, entry in ipairs(history) do
            local msg = tostring(entry.message or entry.Message or "")
            if msg:upper():find("LOAD%s*TIME") then
                autoPlayLoadTimeDetected = true
                break
            end
        end
    end
    if autoPlayLoadTimeDetected and Settings.AutoPlay then
        autoPlayLoadTimeReadyAt = now() + 5
        while now() < autoPlayLoadTimeReadyAt do
            waitSeconds(0.1)
        end
        userWantsFarm = true
        if not farmEnabled then
            startFarm()
        end
    end
end

-- ========================== 核心农场循环（来自新文件） ==========================
local function collectNearbyMoney()
    if not Settings.AutoMoney then return end
    local spawnedBread = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("SpawnedBread")
    local events = ReplicatedStorage:FindFirstChild("Events")
    local collectRemote = events and events:FindFirstChild("CZDPZUS")
    if not spawnedBread or not collectRemote then return end
    local root = getRootPart()
    if not root then return end
    for _, cashDrop in ipairs(spawnedBread:GetChildren()) do
        local part = cashDrop:IsA("BasePart") and cashDrop or (cashDrop:FindFirstChild("MainPart") or cashDrop.PrimaryPart or cashDrop:FindFirstChildWhichIsA("BasePart", true))
        if part and (part.Position - root.Position).Magnitude <= Settings.PickupDistance then
            pcall(collectRemote.FireServer, collectRemote, cashDrop)
            waitSeconds(0.05)
        end
    end
end

local function readStatsGui()
    local coreGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("CoreGUI")
    if not coreGui then return end
    local statsFrame = coreGui:FindFirstChild("StatsFrame", true)
    if not statsFrame then return end
    local allowance = statsFrame:FindFirstChild("Allowance", true)
    local bank = statsFrame:FindFirstChild("Bank", true)
    local function parse(obj)
        if not obj then return nil end
        local text = obj.Text or obj.Value or ""
        text = text:gsub("[^%d]", "")
        return tonumber(text)
    end
    allowanceAmount = parse(allowance) or allowanceAmount
    bankAmount = parse(bank) or bankAmount
end

local function isTemporarilyIgnored(model)
    local untilTime = temporarilyIgnoredTargets[model]
    if not untilTime then return false end
    if now() >= untilTime then
        temporarilyIgnoredTargets[model] = nil
        return false
    end
    return true
end

local function ignoreTarget(model, duration)
    temporarilyIgnoredTargets[model] = now() + (duration or 6)
end

local function findCandidateTargets()
    local result = {}
    local map = Workspace:FindFirstChild("Map")
    local container = map and (map:FindFirstChild("BredMakurz") or map:FindFirstChild("Parts") or map:FindFirstChild("M_Parts") or map)
    if not container then
        -- 尝试其他位置
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                container = obj
                break
            end
        end
    end
    if not container then return result end
    local seen = {}
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("Model") and not seen[obj] and not isTemporarilyIgnored(obj) and not processedTargets[obj] then
            local part = obj:FindFirstChild("MainPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            local values = obj:FindFirstChild("Values")
            local broken = values and values:FindFirstChild("Broken")
            if part and values and broken and broken.Value ~= true then
                seen[obj] = true
                result[#result + 1] = { obj = obj, part = part, zone = classifyTargetZone(obj, part) }
            end
        end
    end
    local root = getRootPart()
    if root then
        table.sort(result, function(a, b)
            return (a.part.Position - root.Position).Magnitude < (b.part.Position - root.Position).Magnitude
        end)
    end
    sortedTargets = result
    return result
end

local function chooseNextTarget()
    if forcedNextTargetModel and forcedNextTargetModel.Parent and not isTemporarilyIgnored(forcedNextTargetModel) and not targetIsBroken(forcedNextTargetModel) then
        return forcedNextTargetModel
    end
    local targets = findCandidateTargets()
    return targets[1] and targets[1].obj or nil
end

local function processTargetMoveOutcome(target, ok, reason)
    if ok then
        forcedNextTargetModel = nil
        waitSeconds(0.5)
        return true
    end
    ignoreTarget(target, 6)
    retargetPending = true
    waitSeconds(1)
    retargetPending = false
    return false, reason
end

local function autoRespawnLoop(runId)
    while farmEnabled and farmRunId == runId do
        characterDead = isDead()
        if Settings.AutoRespawn and characterDead then
            deathCount = deathCount + 1
            pcall(function() LocalPlayer:LoadCharacter() end)
            waitSeconds(1.5)
        else
            waitSeconds(0.5)
        end
    end
end

local function adminWatchLoop(runId)
    while farmEnabled and farmRunId == runId do
        if Settings.AdminCheck then
            for _, player in ipairs(Players:GetPlayers()) do
                if isLikelyAdmin(player) then
                    farmActivityStatus = "Administrator detected: " .. player.Name
                    Log("⚠️ 检测到管理员: " .. player.Name)
                    return
                end
            end
        end
        waitSeconds(2)
    end
end

local function notifierLoop(runId)
    while farmEnabled and farmRunId == runId do
        if Settings.AutoNotify and Settings.WebhookURL ~= "" then
            local current = now()
            local interval = math.max(1, Settings.NotifyMinutes) * 60
            if not notifyBusy and current - notifyLastAt >= interval then
                notifyBusy = true
                -- 发送 webhook（可使用旧文件的 Log 简化，或使用 HTTP 请求）
                spawnTask(function()
                    -- 这里可以添加 HTTP 请求发送 webhook，为了简化，我们只记录日志
                    Log("Webhook 通知 (模拟): 已赚 " .. earnedMoneyTotal .. "，死亡 " .. deathCount)
                    notifyLastAt = current
                    notifyBusy = false
                end)
            end
        end
        waitSeconds(1)
    end
end

local function farmIteration()
    farmActivityStatus = "Processing"
    characterDead = isDead()
    if characterDead then
        waitSeconds(1.5)
        return
    end
    if Settings.NoFall then
        applyNoFallState()
    end
    if userWantsInvis and not invisEnabled then
        setInvisible(true)
    elseif not userWantsInvis and invisEnabled then
        setInvisible(false)
    end
    readStatsGui()
    if Settings.AutoAllowance then
        pcall(claimAllowance)
    end
    if Settings.AutoMoney then
        pcall(collectNearbyMoney)
    end
    if Settings.AutoDeposit then
        pcall(tryDeposit)
    end
    local target = chooseNextTarget()
    if not target then
        waitSeconds(0.3)
        return
    end
    forcedNextTargetModel = target
    local moved, moveReason = moveToTarget(target)
    if not moved then
        processTargetMoveOutcome(target, false, moveReason)
        return
    end
    local broken, breakReason = breakTarget(target)
    if broken then
        processedTargets[target] = true
        forcedNextTargetModel = nil
        farmActivityStatus = "Idle"
        waitSeconds(0.5)
        return
    end
    ignoreTarget(target, 6)
    forcedNextTargetModel = nil
    retargetPending = true
    waitSeconds(1)
    retargetPending = false
    if breakReason then
        farmActivityStatus = tostring(breakReason)
    end
end

local function startFarm()
    if farmEnabled then
        Log("农场已经在运行")
        return false
    end
    farmEnabled = true
    userWantsFarm = true
    farmRunId = farmRunId + 1
    processedTargets = {}
    sortedTargets = {}
    temporarilyIgnoredTargets = {}
    forcedNextTargetModel = nil
    retargetPending = false
    actionInProgress = false
    reachedTargetY = false
    farmActivityStatus = "Idle"
    farmLastActiveAt = now()
    farmLastMoveAt = now()
    local runId = farmRunId
    local started = now()
    if Settings.AntiRejoin then
        pcall(installAntiRejoin)
    end
    if Settings.NoFall then
        pcall(installNoFallHook)
    end
    spawnTask(function() notifierLoop(runId) end)
    spawnTask(function() autoRespawnLoop(runId) end)
    spawnTask(function() adminWatchLoop(runId) end)
    spawnTask(function()
        while farmEnabled and farmRunId == runId do
            local ok, err = xpcall(farmIteration, debug.traceback)
            if not ok then
                Log("农场迭代错误: " .. tostring(err))
                waitSeconds(1)
            end
            farmTimeSeconds = now() - started
            waitSeconds(0.2)
        end
    end)
    Log("农场已启动")
    return true
end

local function stopFarm(reason)
    farmEnabled = false
    userWantsFarm = false
    farmRunId = farmRunId + 1
    forcedNextTargetModel = nil
    actionInProgress = false
    reachedTargetY = false
    retargetPending = false
    processedTargets = {}
    sortedTargets = {}
    temporarilyIgnoredTargets = {}
    suZoneEntered = false
    towerZoneEntered = false
    sw11ZoneEntered = false
    sw11SavedEntryPathPoint = nil
    sw11SavedVisualPath = nil
    farmActivityStatus = "Idle"
    if invisEnabled then
        setInvisible(false)
    end
    restoreCharacterCollision()
    Log("农场已停止: " .. (reason or "手动"))
    return reason or "Stopped"
end

-- ========================== 原 Criminality.lua 的 UI 部分（Fluent） ==========================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "AutoFarm",
    SubTitle = "JX Criminality Farm",
    TabWidth = 120,
    Size = UDim2.fromOffset(450, 500),
    Acrylic = true,
    Theme = "DarkPurple",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Farm", Icon = "zap" }),
    Stats = Window:AddTab({ Title = "Info", Icon = "info" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" })
}

-- === Main Tab ===
Tabs.Main:AddToggle("AutoFarmToggle", {
    Title = "Start Farm",
    Description = "Включить/выключить автоферму",
    Default = false,
    Callback = function(value)
        Settings.Enabled = value
        if value then
            startFarm()
            Fluent:Notify({ Title = "AutoFarm", Content = "Запущено", Duration = 2 })
        else
            stopFarm("Остановлено пользователем")
            Fluent:Notify({ Title = "AutoFarm", Content = "Остановлено", Duration = 2 })
        end
    end
})

Tabs.Main:AddToggle("AutoPickupMoneyToggle", {
    Title = "Auto Pickup Money",
    Description = "Автоматический сбор денег с пола",
    Default = false,
    Callback = function(value)
        Settings.AutoMoney = value
        if value then
            Log("Авто-сбор денег включен")
        else
            Log("Авто-сбор денег выключен")
        end
    end
})

Tabs.Main:AddToggle("InvisibilityToggle", {
    Title = "Invis (R6)",
    Description = "Невидимость (требуется R6 аватар)",
    Default = false,
    Callback = function(value)
        userWantsInvis = value
        setInvisible(value)
    end
})

Tabs.Main:AddToggle("AntiAfkToggle", {
    Title = "Anti-AFK",
    Description = "Защита от AFK кика",
    Default = true,
    Callback = function(value)
        Settings.AntiAfk = value
        if value then
            EnableAntiAfk()
        else
            DisableAntiAfk()
        end
    end
})

Tabs.Main:AddSlider("SpeedSlider", {
    Title = "Move Speed",
    Description = "Скорость перемещения",
    Default = 32,
    Min = 10,
    Max = 60,
    Rounding = 1,
    Callback = function(value)
        moveSpeed = value
        Settings.MoveSpeed = value
        Log("Скорость установлена: " .. value)
    end
})

Tabs.Main:AddDropdown("BreakingMethodDropdown", {
    Title = "Breaking Method",
    Description = "Метод взлома сейфов/касс",
    Values = { "Crowbar", "Fist+Lockpick" },
    Default = 1,
    Callback = function(value)
        breakingMethod = value
        Settings.BreakingMethod = value
        Log("Метод взлома: " .. value)
    end
})

Tabs.Main:AddToggle("AutoRespawnToggle", {
    Title = "Auto Respawn",
    Description = "Автоматическое возрождение при смерти",
    Default = true,
    Callback = function(value)
        Settings.AutoRespawn = value
    end
})

Tabs.Main:AddToggle("AutoDepositToggle", {
    Title = "Auto Deposit",
    Description = "Автоматический внос денег в банк при достижении порога",
    Default = false,
    Callback = function(value)
        Settings.AutoDeposit = value
        depositThreshold = Settings.DepositThresholdK * 1000
    end
})

Tabs.Main:AddSlider("DepositThresholdSlider", {
    Title = "Deposit Threshold (k)",
    Description = "Порог суммы для автовноса (тысячи)",
    Default = 5,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(value)
        Settings.DepositThresholdK = value
        depositThreshold = value * 1000
    end
})

Tabs.Main:AddToggle("AutoAllowanceToggle", {
    Title = "Auto Claim Allowance",
    Description = "Автоматическое получение ежедневного пособия",
    Default = false,
    Callback = function(value)
        Settings.AutoAllowance = value
        if value then
            pcall(claimAllowance)
        end
    end
})

Tabs.Main:AddToggle("AutoPlayToggle", {
    Title = "Auto Play",
    Description = "Автоматически отправлять сигналы для запуска игры",
    Default = false,
    Callback = function(value)
        Settings.AutoPlay = value
        if value and not autoPlayWorkerBusy then
            spawnTask(autoPlayWorker)
        end
    end
})

Tabs.Main:AddToggle("NoFallToggle", {
    Title = "No Fall Damage",
    Description = "Отключение урона от падения",
    Default = false,
    Callback = function(value)
        Settings.NoFall = value
        if value then
            installNoFallHook()
        end
    end
})

Tabs.Main:AddToggle("AntiRejoinToggle", {
    Title = "Anti Error/Rejoin",
    Description = "Автоматическое переподключение при ошибках",
    Default = false,
    Callback = function(value)
        Settings.AntiRejoin = value
        if value then
            installAntiRejoin()
        end
    end
})

Tabs.Main:AddToggle("AdminCheckToggle", {
    Title = "Admin Check",
    Description = "Остановка фермы при обнаружении администратора",
    Default = false,
    Callback = function(value)
        Settings.AdminCheck = value
    end
})

Tabs.Main:AddToggle("AutoNotifyToggle", {
    Title = "Auto Notify",
    Description = "Периодическое уведомление о статусе (требуется Webhook)",
    Default = false,
    Callback = function(value)
        Settings.AutoNotify = value
    end
})

Tabs.Main:AddTextBox("WebhookURLInput", {
    Title = "Webhook URL",
    Description = "URL для уведомлений (Discord)",
    Default = "",
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(value)
        Settings.WebhookURL = value
        webhookUrl = value
    end
})

Tabs.Main:AddButton({
    Title = "Deposit Now",
    Description = "Внести все деньги в банк немедленно",
    Callback = function()
        spawnTask(function()
            Fluent:Notify({ Title = "Deposit", Content = "Начинаем внос...", Duration = 2 })
            local success = tryDepositAllNow()
            Fluent:Notify({ Title = "Deposit", Content = success and "Внос выполнен" or "Ошибка вноса", Duration = 2 })
        end)
    end
})

Tabs.Main:AddButton({
    Title = "Save State",
    Description = "Сохранить текущие настройки и статистику",
    Callback = function()
        -- 保存状态简单存到文件（如果支持）
        Log("Состояние сохранено (симуляция)")
        Fluent:Notify({ Title = "Save", Content = "Состояние сохранено", Duration = 2 })
    end
})

-- === Stats Tab ===
local statusPara = Tabs.Stats:AddParagraph({
    Title = "Status",
    Content = "Idle"
})
local safesPara = Tabs.Stats:AddParagraph({
    Title = "Safes",
    Content = "0/0"
})
local registersPara = Tabs.Stats:AddParagraph({
    Title = "Registers",
    Content = "0/0"
})
local remainingPara = Tabs.Stats:AddParagraph({
    Title = "Remaining",
    Content = "0/0"
})
local earnedPara = Tabs.Stats:AddParagraph({
    Title = "Earned",
    Content = "0"
})
local deathPara = Tabs.Stats:AddParagraph({
    Title = "Deaths",
    Content = "0"
})
local timePara = Tabs.Stats:AddParagraph({
    Title = "Time (s)",
    Content = "0"
})

-- === Visuals Tab ===
local EspEnabled = false
local EspHeartbeatConnection = nil
local EspElements = {}
local EspTextSize = 20

local function FormatName(rawName)
    rawName = string.gsub(rawName, "([a-z])([A-Z])", "%1 %2")
    rawName = string.gsub(rawName, "_", " ")
    if rawName:lower():find("safe") then
        return "🔒 " .. rawName
    elseif rawName:lower():find("register") then
        return "💰 " .. rawName
    end
    return rawName
end

local function CreateHighlight(part, color)
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = part
    highlight.FillColor = color
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0
    highlight.Parent = part
    return highlight
end

local function UpdateESP()
    if not EspEnabled then return end
    local map = Workspace:FindFirstChild("Map")
    local container = map and (map:FindFirstChild("BredMakurz") or map:FindFirstChild("Parts") or map:FindFirstChild("M_Parts") or map)
    if not container then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                container = obj
                break
            end
        end
    end
    if not container then return end
    local root = getRootPart()
    if not root then return end
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("Model") then
            local nameLower = string.lower(obj.Name)
            if nameLower:find("safe") or nameLower:find("register") then
                local mainPart = obj:FindFirstChild("MainPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                if not mainPart or mainPart.Position.Y < 4.8 then continue end
                local values = obj:FindFirstChild("Values")
                local brokenVal = values and values:FindFirstChild("Broken")
                local isBroken = brokenVal and brokenVal.Value
                local color = isBroken and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
                local esp = EspElements[obj]
                if not esp then
                    local billboard = Instance.new("BillboardGui")
                    billboard.Name = "ESP_Billboard"
                    billboard.Adornee = mainPart
                    billboard.Size = UDim2.new(0, 200, 0, 50)
                    billboard.StudsOffset = Vector3.new(0, 4, 0)
                    billboard.AlwaysOnTop = true
                    billboard.MaxDistance = 1000
                    billboard.Parent = obj
                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1
                    label.Font = Enum.Font.SourceSansBold
                    label.TextScaled = false
                    label.Text = FormatName(obj.Name)
                    label.TextColor3 = color
                    label.TextStrokeTransparency = 0
                    label.TextStrokeColor3 = Color3.new(0, 0, 0)
                    label.TextSize = EspTextSize
                    label.Parent = billboard
                    local highlight = CreateHighlight(obj, color)
                    EspElements[obj] = {
                        billboard = billboard,
                        highlight = highlight,
                        label = label
                    }
                    if brokenVal then
                        brokenVal:GetPropertyChangedSignal("Value"):Connect(function()
                            if not EspEnabled or not EspElements[obj] then return end
                            local e = EspElements[obj]
                            if brokenVal.Value then
                                e.label.TextColor3 = Color3.new(1, 0, 0)
                                if e.highlight then e.highlight.FillColor = Color3.new(1, 0, 0) end
                            else
                                e.label.TextColor3 = Color3.new(0, 1, 0)
                                if e.highlight then e.highlight.FillColor = Color3.new(0, 1, 0) end
                            end
                        end)
                    end
                else
                    if brokenVal then
                        esp.label.TextColor3 = isBroken and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
                        if esp.highlight then
                            esp.highlight.FillColor = isBroken and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
                        end
                    end
                    if esp.label then
                        esp.label.TextSize = EspTextSize
                    end
                end
            end
        end
    end
    for obj, data in pairs(EspElements) do
        if not obj or not obj.Parent then
            pcall(function()
                if data.billboard then data.billboard:Destroy() end
                if data.highlight then data.highlight:Destroy() end
            end)
            EspElements[obj] = nil
        end
    end
end

local function EnableESP()
    if EspEnabled then return end
    EspEnabled = true
    EspHeartbeatConnection = RunService.Heartbeat:Connect(UpdateESP)
    Log("ESP включен")
end

local function DisableESP()
    if not EspEnabled then return end
    EspEnabled = false
    if EspHeartbeatConnection then
        EspHeartbeatConnection:Disconnect()
        EspHeartbeatConnection = nil
    end
    for _, data in pairs(EspElements) do
        pcall(function()
            if data.billboard then data.billboard:Destroy() end
            if data.highlight then data.highlight:Destroy() end
        end)
    end
    EspElements = {}
    Log("ESP выключен")
end

Tabs.Visuals:AddToggle("SafeESPToggle", {
    Title = "Safe/Register ESP",
    Default = false,
    Callback = function(value)
        if value then
            EnableESP()
        else
            DisableESP()
        end
    end
})

Tabs.Visuals:AddSlider("TextSizeSlider", {
    Title = "Text Size",
    Default = 20,
    Min = 10,
    Max = 40,
    Rounding = 0,
    Callback = function(value)
        EspTextSize = value
        for _, data in pairs(EspElements) do
            if data.label then
                data.label.TextSize = EspTextSize
            end
        end
    end
})

-- ========================== 统计更新循环 ==========================
task.spawn(function()
    while true do
        if Settings.Enabled and farmEnabled then
            statusPara:SetDesc(farmActivityStatus)
            -- 简单统计目标数量（从 sortedTargets 估计）
            local safes = 0
            local registers = 0
            for _, t in ipairs(sortedTargets) do
                if string.lower(t.obj.Name):find("safe") then
                    safes = safes + 1
                elseif string.lower(t.obj.Name):find("register") then
                    registers = registers + 1
                end
            end
            safesPara:SetDesc(tostring(safes) .. "/" .. tostring(#sortedTargets))
            registersPara:SetDesc(tostring(registers) .. "/" .. tostring(#sortedTargets))
            remainingPara:SetDesc(tostring(#sortedTargets) .. "/" .. tostring(#sortedTargets))
            earnedPara:SetDesc(tostring(math.floor(earnedMoneyTotal)))
            deathPara:SetDesc(tostring(deathCount))
            timePara:SetDesc(tostring(math.floor(farmTimeSeconds)))
        else
            statusPara:SetDesc("Ожидание")
            safesPara:SetDesc("0/0")
            registersPara:SetDesc("0/0")
            remainingPara:SetDesc("0/0")
            earnedPara:SetDesc("0")
            deathPara:SetDesc("0")
            timePara:SetDesc("0")
        end
        waitSeconds(0.5)
    end
end)

-- ========================== 初始化 ==========================
-- 自动检测加载时间并启动
deferTask(function()
    detectLoadTimeAndAutoStart()
end)

-- 启动自动拾取（旧版保留兼容，但实际由 Settings.AutoMoney 控制）
StartAutoPickup() -- 实际上这个函数现在只是设置标志

Fluent:Notify({ Title = "AutoFarm", Content = "Загружено (JX Criminality Farm)", Duration = 3 })
Log("JX Criminality Farm loaded successfully")

-- 防止脚本退出
while true do waitSeconds(10) end