-- =====================================================
--  Criminality Farm Lite  (只含 赚钱 + 工资 + 存款)
--  用法：执行后会出现 UI，三个开关分别控制功能。
-- =====================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- UI 父级
local UiParent = (type(gethui) == "function" and pcall(gethui) and gethui()) or CoreGui

-- ==================== 常量 ====================
local PICKUP_REMOTE_NAME = "CZDPZUS"
local MONEY_SEARCH_RADIUS = 42
local MONEY_COLLECT_MAX_PASSES = 18
local IGNORE_DURATION = 6
local DEFAULT_MOVE_SPEED = 32
local FARM_TICK_SECONDS = 0.20
local FARM_IDLE_WAIT_SECONDS = 0.30
local FARM_DEAD_WAIT_SECONDS = 1.50
local FARM_RETRY_WAIT_SECONDS = 1.00
local FARM_BETWEEN_TARGETS_SECONDS = 0.50
local WAYPOINT_SPACING = 3
local DEPOSIT_THRESHOLD = 5000  -- 存款阈值（可调）

-- ==================== 全局状态 ====================
local farmEnabled = false
local allowanceEnabled = false
local depositEnabled = false
local farmRunId = 0
local processedTargets = {}
local temporarilyIgnoredTargets = {}
local forcedNextTargetModel = nil
local actionInProgress = false
local characterDead = false
local moveSpeed = DEFAULT_MOVE_SPEED
local breakingMethod = "Crowbar"  -- 或 "Fist + Lockpick"

-- ==================== 工具函数 ====================
local function now()
    return type(tick) == "function" and tick() or os.clock()
end

local function waitSeconds(s)
    return (type(task) == "table" and task.wait or wait)(s)
end

local function spawnTask(cb)
    return (type(task) == "table" and task.spawn or coroutine.wrap)(cb)()
end

local function deferTask(cb)
    return (type(task) == "table" and task.defer or spawnTask)(cb)
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid(char)
    char = char or getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(char)
    char = char or getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function isDead()
    local hum = getHumanoid()
    return hum == nil or hum.Health <= 0
end

local function showNotification(title, msg, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title or "JX"),
            Text = tostring(msg or ""),
            Duration = tonumber(dur) or 3,
        })
    end)
end

local function respawnCharacter()
    if isDead() then
        pcall(LocalPlayer.LoadCharacter, LocalPlayer)
    end
end

-- ==================== 自动拾取金钱 ====================
local function findMoneyContainer()
    local filter = workspace:FindFirstChild("Filter")
    return filter and filter:FindFirstChild("SpawnedBread")
end

local function getMoneyTargets(radius)
    radius = radius or MONEY_SEARCH_RADIUS
    local root = getRootPart()
    local container = findMoneyContainer()
    if not root or not container then return {} end
    local result = {}
    for _, model in ipairs(container:GetChildren()) do
        local part = model:FindFirstChild("MainPart")
        if part and part:IsA("BasePart") then
            local dist = (part.Position - root.Position).Magnitude
            if dist <= radius then
                table.insert(result, { model = model, part = part, distance = dist })
            end
        end
    end
    table.sort(result, function(a,b) return a.distance < b.distance end)
    return result
end

local function firePickupEvent(target)
    local events = ReplicatedStorage:FindFirstChild("Events") or workspace:FindFirstChild("Events")
    local remote = events and events:FindFirstChild(PICKUP_REMOTE_NAME, true)
    local obj = target and (target.model or target.part)
    if not remote or not remote:IsA("RemoteEvent") or not obj then return false end
    return pcall(remote.FireServer, remote, obj)
end

local function collectMoneyTarget(target)
    if not target or not target.part then return false end
    local root = getRootPart()
    if not root then return false end
    local moved = pcall(function()
        root.CFrame = target.part.CFrame + Vector3.new(0, 2, 0)
    end)
    if moved then waitSeconds(0.10) end
    return firePickupEvent(target)
end

local function collectNearbyMoney()
    for _ = 1, MONEY_COLLECT_MAX_PASSES do
        local targets = getMoneyTargets(MONEY_SEARCH_RADIUS)
        if #targets == 0 then break end
        for _, t in ipairs(targets) do
            if not farmEnabled then return end
            pcall(collectMoneyTarget, t)
        end
    end
end

-- ==================== 农场核心逻辑 ====================
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
    temporarilyIgnoredTargets[model] = now() + (duration or IGNORE_DURATION)
end

local function getTargetPart(model)
    if not model or not model.Parent then return nil end
    return model:FindFirstChild("MainPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function targetIsBroken(model)
    local vals = model and model:FindFirstChild("Values")
    local broken = vals and vals:FindFirstChild("Broken")
    return broken and broken.Value == true or false
end

local function findCandidateTargets()
    local result, seen = {}, {}
    local map = workspace:FindFirstChild("Map")
    local containers = {}
    if map then
        local parts = map:FindFirstChild("Parts")
        local mparts = map:FindFirstChild("M_Parts")
        if parts then table.insert(containers, parts) end
        if mparts and mparts ~= parts then table.insert(containers, mparts) end
        if #containers == 0 then table.insert(containers, map) end
    end
    for _, container in ipairs(containers) do
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("Model") and not seen[obj] and not isTemporarilyIgnored(obj) and not processedTargets[obj] then
                local part = getTargetPart(obj)
                local vals = obj:FindFirstChild("Values")
                local broken = vals and vals:FindFirstChild("Broken")
                if part and vals and broken and broken.Value ~= true then
                    seen[obj] = true
                    table.insert(result, { obj = obj, part = part })
                end
            end
        end
    end
    local root = getRootPart()
    if root then
        table.sort(result, function(a,b)
            return (a.part.Position - root.Position).Magnitude < (b.part.Position - root.Position).Magnitude
        end)
    end
    return result
end

-- 路径移动
local function tweenRootTo(position, targetCFrame)
    local root = getRootPart()
    if not root then return false end
    local dist = (position - root.Position).Magnitude
    local duration = math.max(0.05, dist / math.max(1, moveSpeed))
    local dest = targetCFrame or CFrame.new(position + Vector3.new(0, 3, 0))
    actionInProgress = true
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = dest })
    local completed = false
    local conn = tween.Completed:Connect(function() completed = true end)
    tween:Play()
    local started = now()
    while farmEnabled and not completed and now() - started < duration + 2 do
        if isDead() then tween:Cancel(); break end
        waitSeconds(0.05)
    end
    conn:Disconnect()
    actionInProgress = false
    return completed
end

local function moveToTarget(model)
    local part = getTargetPart(model)
    if not part then return false end
    return tweenRootTo(part.Position, part.CFrame + Vector3.new(0, 3, 0))
end

-- 破坏方法
local function findToolByName(name)
    local char = getCharacter()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if char then
        local eq = char:FindFirstChild(name)
        if eq and eq:IsA("Tool") then return eq end
    end
    if bp then
        local st = bp:FindFirstChild(name)
        if st and st:IsA("Tool") then return st end
    end
    return nil
end

local function equipTool(tool)
    if not tool then return false end
    local hum = getHumanoid()
    if not hum then return false end
    if tool.Parent == getCharacter() then return true end
    return pcall(hum.EquipTool, hum, tool) and tool.Parent == getCharacter()
end

local function getShopMainPart(name)
    local map = workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    local shop = shopz and shopz:FindFirstChild(name)
    return shop and shop:FindFirstChild("MainPart")
end

local function buyCrowbar()
    local existing = findToolByName("Crowbar")
    if existing then equipTool(existing); return true end
    local events = ReplicatedStorage:FindFirstChild("Events")
    local dealerPart = getShopMainPart("Dealer")
    local protRemote = events and events:FindFirstChild("BYZERSPROTEC")
    local buyRemote = events and events:FindFirstChild("SSHPRMTE1")
    if not dealerPart or not protRemote or not buyRemote then return false end
    if not tweenRootTo(dealerPart.Position, dealerPart.CFrame + Vector3.new(0,3,0)) then return false end
    pcall(protRemote.FireServer, protRemote, true, "shop", dealerPart, "IllegalStore")
    local ok = pcall(buyRemote.InvokeServer, buyRemote, "IllegalStore", "Melees", "Crowbar", dealerPart, nil, true)
    pcall(protRemote.FireServer, protRemote, false)
    waitSeconds(0.75)
    local tool = findToolByName("Crowbar")
    if tool then equipTool(tool) end
    return ok and tool ~= nil
end

local function countToolsByName(name)
    local count = 0
    local char = getCharacter()
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({char, bp}) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and item.Name == name then count = count + 1 end
            end
        end
    end
    return count
end

local function findNearestLockpickShop()
    local root = getRootPart()
    local best, bestDist
    for _, name in ipairs({"ArmoryDealer", "Dealer"}) do
        local part = getShopMainPart(name)
        if part then
            local dist = root and (part.Position - root.Position).Magnitude or 0
            if not bestDist or dist < bestDist then best = part; bestDist = dist end
        end
    end
    return best
end

local function purchaseLockpickAt(shopPart)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local buyRemote = events and events:FindFirstChild("SSHPRMTE1")
    if not shopPart or not buyRemote then return false end
    local ok1 = pcall(buyRemote.InvokeServer, buyRemote, "IllegalStore", "Misc", "Lockpick", shopPart, nil, true, nil)
    waitSeconds(0.25)
    local ok2 = pcall(buyRemote.InvokeServer, buyRemote, "LegalStore", "Misc", "Lockpick", shopPart, nil, true)
    return ok1 or ok2
end

local function buyLockpickBatch(qty)
    qty = math.max(1, math.floor(qty or 7))
    local shop = findNearestLockpickShop()
    if not shop then return false end
    if not tweenRootTo(shop.Position, shop.CFrame + Vector3.new(0,3,0)) then return false end
    local startCount = countToolsByName("Lockpick")
    for i = 1, qty do
        if not farmEnabled then break end
        purchaseLockpickAt(shop)
        waitSeconds(0.2)
    end
    waitSeconds(0.75)
    return countToolsByName("Lockpick") > startCount
end

local function dropLockpick(tool)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local dropRemote = events and events:FindFirstChild("PAZ_TA")
    local root = getRootPart()
    if not tool or not dropRemote or not root then return false end
    return pcall(dropRemote.FireServer, dropRemote, tool, nil, root.Position)
end

local function tryLockpickTarget(target)
    local tool = findToolByName("Lockpick")
    if not tool then return false, "no_lockpick" end
    if not equipTool(tool) then return false, "equip_fail" end
    local remote = tool:FindFirstChild("Remote")
    if not remote or not remote:IsA("RemoteFunction") then return false, "no_remote" end
    local ok, token = pcall(remote.InvokeServer, remote, "S", target, "s")
    if ok and type(token) == "number" then
        waitSeconds(0.25)
        return pcall(remote.InvokeServer, remote, "D", target, "s", token)
    end
    dropLockpick(tool)
    return false, "lockpick_fail"
end

local function strikeWithCrowbar(target)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local startFolder = events and events:FindFirstChild("XMHH")
    local finishFolder = events and events:FindFirstChild("XMHH2")
    local startRemote = startFolder and startFolder:FindFirstChild("2")
    local finishRemote = finishFolder and finishFolder:FindFirstChild("2")
    local tool = findToolByName("Crowbar")
    local char = getCharacter()
    local targetPart = getTargetPart(target)
    local arm = char and (char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand"))
    if not startRemote or not finishRemote or not tool or not char or not arm or not targetPart then return false end
    equipTool(tool)
    local ok, token = pcall(startRemote.InvokeServer, startRemote, "🍞", now(), tool, "DZDRRRKI", target, "Register")
    if ok and type(token) == "number" then
        return pcall(finishRemote.FireServer, finishRemote, "🍞", now(), tool, "2389ZFX34", token, false, arm, targetPart, target, targetPart.Position, targetPart.Position)
    end
    return false
end

local function breakTarget(target)
    if not target or not target.Parent then return false, "removed" end
    if targetIsBroken(target) then return true, "already" end

    if breakingMethod == "Crowbar" then
        if not findToolByName("Crowbar") and not buyCrowbar() then return false, "no_crowbar" end
        local started = now()
        while farmEnabled and target.Parent and not targetIsBroken(target) and now() - started < 30 do
            local part = getTargetPart(target)
            local root = getRootPart()
            if not part or not root then return false, "missing_part" end
            if (part.Position - root.Position).Magnitude > 8 then
                if not moveToTarget(target) then return false, "move_fail" end
            end
            strikeWithCrowbar(target)
            waitSeconds(0.25)
        end
    else
        local started = now()
        local batchSize = 7
        while farmEnabled and target.Parent and not targetIsBroken(target) and now() - started < 120 do
            local part = getTargetPart(target)
            local root = getRootPart()
            if not part or not root then return false, "missing_part" end
            if (part.Position - root.Position).Magnitude > 8 then
                if not moveToTarget(target) then return false, "move_fail" end
            end
            if not findToolByName("Lockpick") then
                if not buyLockpickBatch(batchSize) then return false, "no_lockpick" end
                batchSize = 15
                if target.Parent and not targetIsBroken(target) then moveToTarget(target) end
            end
            local opened = tryLockpickTarget(target)
            if opened then
                local completed = now()
                while target.Parent and not targetIsBroken(target) and now() - completed < 12 do
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
        waitSeconds(FARM_BETWEEN_TARGETS_SECONDS)
        return true, "success"
    end
    return false, "timeout"
end

-- 农场主循环
local function farmIteration()
    characterDead = isDead()
    if characterDead then
        respawnCharacter()
        waitSeconds(FARM_DEAD_WAIT_SECONDS)
        return
    end

    -- 自动拾取金钱（作为farm的一部分）
    collectNearbyMoney()

    -- 选择目标
    local targets = findCandidateTargets()
    local target = targets[1] and targets[1].obj
    if not target then
        waitSeconds(FARM_IDLE_WAIT_SECONDS)
        return
    end

    forcedNextTargetModel = target
    if not moveToTarget(target) then
        ignoreTarget(target, IGNORE_DURATION)
        waitSeconds(FARM_RETRY_WAIT_SECONDS)
        return
    end

    local broken, reason = breakTarget(target)
    if broken then
        processedTargets[target] = true
        forcedNextTargetModel = nil
        waitSeconds(FARM_BETWEEN_TARGETS_SECONDS)
    else
        ignoreTarget(target, IGNORE_DURATION)
        forcedNextTargetModel = nil
        waitSeconds(FARM_RETRY_WAIT_SECONDS)
    end
end

-- 启动/停止Farm
local function startFarm()
    if farmEnabled then return end
    farmEnabled = true
    farmRunId = farmRunId + 1
    processedTargets = {}
    temporarilyIgnoredTargets = {}
    forcedNextTargetModel = nil
    local runId = farmRunId
    showNotification("Farm", "Started", 2)

    spawnTask(function()
        while farmEnabled and farmRunId == runId do
            xpcall(farmIteration, debug.traceback)
            waitSeconds(FARM_TICK_SECONDS)
        end
    end)
end

local function stopFarm()
    farmEnabled = false
    farmRunId = farmRunId + 1
    showNotification("Farm", "Stopped", 2)
end

-- ==================== 工资领取 ====================
local function claimAllowance()
    if not allowanceEnabled then return end
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("CLMZALOW")
    local atm = findATMMainPart()
    if not remote or not atm then return end
    local ok = pcall(remote.InvokeServer, remote, atm)
    if ok then showNotification("Allowance", "Claimed", 1) end
end

-- ==================== 存款功能 ====================
local function findATMMainPart()
    local map = workspace:FindFirstChild("Map")
    local atmz = map and map:FindFirstChild("ATMz")
    local atm = atmz and atmz:FindFirstChild("ATM")
    local part = atm and atm:FindFirstChild("MainPart")
    if part and part:IsA("BasePart") then return part end
    return nil
end

local function moveToPart(part)
    if not part then return false end
    local root = getRootPart()
    if not root then return false end
    local dist = (part.Position - root.Position).Magnitude
    local duration = math.max(0.05, dist / math.max(1, moveSpeed))
    actionInProgress = true
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = part.CFrame + Vector3.new(0, 3, 0)
    })
    local completed = false
    local conn = tween.Completed:Connect(function() completed = true end)
    tween:Play()
    local started = now()
    while (farmEnabled or depositEnabled) and not completed and now() - started < duration + 2 do
        if isDead() then tween:Cancel(); break end
        waitSeconds(0.05)
    end
    conn:Disconnect()
    actionInProgress = false
    return completed
end

local function readCashAmount()
    local core = PlayerGui:FindFirstChild("CoreGUI")
    if not core then return 0 end
    local candidates = {"Cash", "CashLabel", "CashAmount", "Money", "MoneyLabel"}
    for _, name in ipairs(candidates) do
        local obj = core:FindFirstChild(name, true)
        if obj then
            local val = pcall(function()
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    return tonumber(obj.Text:gsub("[^%d]", "")) or 0
                end
                return tonumber(obj.Value) or 0
            end)
            if val and type(val) == "number" then return val end
        end
    end
    return 0
end

local function performDeposit()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("ATM")
    local atmPart = findATMMainPart()
    if not remote or not remote:IsA("RemoteFunction") or not atmPart then return false end
    if not moveToPart(atmPart) then return false end
    local cash = readCashAmount()
    if cash <= 0 then return false end
    local ok = pcall(remote.InvokeServer, remote, "DP", cash, atmPart)
    waitSeconds(0.2)
    return ok and readCashAmount() <= 0
end

local function tryDeposit()
    if not depositEnabled then return false end
    if readCashAmount() >= DEPOSIT_THRESHOLD then
        return performDeposit()
    end
    return false
end

-- ==================== UI 创建 ====================
local function createUI()
    -- 清除旧UI
    local old = UiParent:FindFirstChild("JXFarmLite")
    if old then old:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name = "JXFarmLite"
    screen.ResetOnSpawn = false
    screen.Parent = UiParent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 220)
    frame.Position = UDim2.new(0, 20, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screen

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -10, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "JX Farm Lite"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Position = UDim2.new(0, 5, 0, 2)

    local close = Instance.new("TextButton", frame)
    close.Size = UDim2.new(0, 30, 0, 30)
    close.Position = UDim2.new(1, -35, 0, 2)
    close.BackgroundColor3 = Color3.fromRGB(100, 40, 45)
    close.Text = "X"
    close.TextColor3 = Color3.new(1,1,1)
    close.Font = Enum.Font.GothamBold
    close.TextSize = 14
    close.BorderSizePixel = 0
    close.MouseButton1Click:Connect(function() screen.Enabled = false end)

    local function makeToggle(text, flag, default, yPos)
        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(0.9, 0, 0, 30)
        btn.Position = UDim2.new(0.05, 0, 0, yPos)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        btn.Text = text .. ": OFF"
        btn.TextColor3 = Color3.new(0.9,0.9,0.9)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false

        local state = default
        local function update()
            btn.Text = text .. ": " .. (state and "ON" or "OFF")
            btn.BackgroundColor3 = state and Color3.fromRGB(45, 105, 70) or Color3.fromRGB(35, 35, 45)
        end
        btn.MouseButton1Click:Connect(function()
            state = not state
            update()
            if flag == "Farm" then
                if state then startFarm() else stopFarm() end
            elseif flag == "Allowance" then
                allowanceEnabled = state
                if state then spawnTask(claimAllowance) end
            elseif flag == "Deposit" then
                depositEnabled = state
            end
        end)
        update()
        return btn
    end

    makeToggle("Farm", "Farm", false, 40)
    makeToggle("Allowance", "Allowance", false, 80)
    makeToggle("Deposit", "Deposit", false, 120)

    -- 状态提示
    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(0.9, 0, 0, 25)
    status.Position = UDim2.new(0.05, 0, 0, 170)
    status.BackgroundTransparency = 1
    status.Text = "Ready"
    status.TextColor3 = Color3.fromRGB(180,180,180)
    status.Font = Enum.Font.Gotham
    status.TextSize = 13
    status.TextXAlignment = Enum.TextXAlignment.Left

    -- 更新状态（可放在循环中，此处简化）
    spawnTask(function()
        while screen and screen.Parent do
            local s = "Farm: " .. (farmEnabled and "ON" or "OFF")
            s = s .. " | Allow: " .. (allowanceEnabled and "ON" or "OFF")
            s = s .. " | Dep: " .. (depositEnabled and "ON" or "OFF")
            status.Text = s
            waitSeconds(1)
        end
    end)
end

-- ==================== 启动 ====================
createUI()
showNotification("JX Farm Lite", "UI loaded. Toggle features.", 3)