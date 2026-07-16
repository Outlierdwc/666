-- ============================
--  JX-CRIMINALITY-FARM (Library UI) - Part 1/6
--  完整版：依赖、常量、文件读写、基础工具
-- ============================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local LogService = game:GetService("LogService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local UiParent = CoreGui

if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and result then
        UiParent = result
    end
end

-- ============================
--  常量配置
-- ============================
local LIBRARY_URL = "https://raw.githubusercontent.com/jianlobiano/Serotonin-Library-Modified/refs/heads/main/Library.lua"
local DATA_DIRECTORY = "JX-CRIMINALITY-FARM"
local CONFIG_DIRECTORY = "JX-CRIMINALITY-FARM/Configs"
local ASSET_DIRECTORY = "JX-CRIMINALITY-FARM/Assets"
local RUNTIME_STATE_FILE = "JX-CRIMINALITY-FARM/runtime_state.txt"
local EARN_MONEY_FILE = "JX-CRIMINALITY-FARM/JX_EarnMoney.txt"
local WAYPOINT_SPACING = 3
local PICKUP_DISTANCE = 8
local FARM_TICK_SECONDS = 0.20
local FARM_IDLE_WAIT_SECONDS = 0.30
local FARM_DEAD_WAIT_SECONDS = 1.50
local FARM_RETRY_WAIT_SECONDS = 1.00
local FARM_BETWEEN_TARGETS_SECONDS = 0.50
local RECOVERY_IDLE_SECONDS = 8.00
local SHOP_PRE_OPEN_SECONDS = 0.75
local SHOP_AFTER_OPEN_SECONDS = 0.45
local SHOP_BUY_POLL_SECONDS = 0.05
local SHOP_BUY_MAX_WAIT_SECONDS = 10.00
local SHOP_POST_BUY_SECONDS = 1.00
local MONEY_SEARCH_RADIUS = 42
local MONEY_COLLECT_MAX_PASSES = 18
local PATH_MAX_PARAM_ATTEMPTS = 19
local IGNORE_DURATION = 6
local TARGET_Y = 4.8
local DEFAULT_MOVE_SPEED = 32
local DEFAULT_NOTIFY_MINUTES = 1

local PICKUP_REMOTE_NAME = "CZDPZUS"
local WINDOW_NAME = "JX | Criminality | FARM | Dsc.gg/getjxs"

-- ============================
--  状态变量
-- ============================
local farmEnabled = false
local userWantsFarm = false
local userWantsInvis = false
local invisEnabled = false
local characterDead = false
local reachedTargetY = false
local retargetPending = false
local dynamicRetargetEnabled = true
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
local webhookUrl = ""
local autoNotify = false
local notifyMinutes = DEFAULT_NOTIFY_MINUTES
local autoRespawn = true
local antiRejoin = false
local autoPlayEnabled = false
local autoPlayWorkerBusy = false
local autoPlayLoadTimeDetected = false
local autoPlayLoadTimeReadyAt = nil
local autoDepositEnabled = false
local autoDepositThresholdK = 5
local autoMoney = false
local noFallEnabled = false
local breakingMethod = "Crowbar"
local moveSpeed = DEFAULT_MOVE_SPEED
local lastRejoinAt = 0
local lastTimeTick = os.clock()
local lastCashAddedText = ""
local autoAllowance = false
local antiAfkEnabled = false
local adminCheckEnabled = false
local adminUserIds = {}
local adminGroupRanks = {}
local adminGroupRoles = {}
local depositThreshold = 5000
local depositLastAttemptAt = 0
local depositCooldownUntil = 0
local depositInProgress = false

local function setAutoDepositEnabled(value)
    local enabled = value == true
    autoDepositEnabled = enabled
end

local function setAutoDepositThresholdK(value)
    local numeric = tonumber(value)
    if numeric == nil then
        return depositThreshold / 1000
    end
    local thousands = math.clamp(math.floor(numeric + 0.5), 1, 100)
    autoDepositThresholdK = thousands
    depositThreshold = thousands * 1000
    return thousands
end

local function now()
    if type(tick) == "function" then
        return tick()
    end
    return os.clock()
end

local function waitSeconds(seconds)
    if type(task) == "table" and type(task.wait) == "function" then
        return task.wait(seconds)
    end
    return wait(seconds)
end

local function spawnTask(callback)
    if type(task) == "table" and type(task.spawn) == "function" then
        return task.spawn(callback)
    end
    return coroutine.wrap(callback)()
end

local function deferTask(callback)
    if type(task) == "table" and type(task.defer) == "function" then
        return task.defer(callback)
    end
    return spawnTask(callback)
end

local unpackArgs = table.unpack or unpack

local function markActivity()
    farmLastActiveAt = now()
end

local function markMove()
    farmLastMoveAt = now()
end

-- ============================
--  文件读写
-- ============================
local function ensureFolder(path)
    if type(isfolder) == "function" and isfolder(path) then
        return true
    end
    if type(makefolder) ~= "function" then
        return false
    end
    local ok = pcall(makefolder, path)
    return ok
end

local function ensureDirectories()
    ensureFolder(DATA_DIRECTORY)
    ensureFolder(CONFIG_DIRECTORY)
    ensureFolder(ASSET_DIRECTORY)
end

local function safeIsFile(path)
    return type(isfile) == "function" and isfile(path) or false
end

local function safeRead(path)
    if type(readfile) ~= "function" or not safeIsFile(path) then
        return nil
    end
    local ok, result = pcall(readfile, path)
    return ok and result or nil
end

local function safeWrite(path, content)
    if type(writefile) ~= "function" then
        return false
    end
    local ok = pcall(writefile, path, tostring(content))
    return ok
end

local function parseRuntimeState(text)
    if type(text) ~= "string" then
        return
    end

    local savedAutoNotify = text:match("AutoNotify:(%d+)")
    local savedNotifyMinutes = text:match("NotifyMinutes:(%d+%.?%d*)")
    local savedEarnMoney = text:match("EarnMoney:(%d+%.?%d*)")
    local savedWebhook = text:match("Webhook:([^\r\n]*)")

    if savedAutoNotify then
        autoNotify = savedAutoNotify == "1"
    end

    if savedNotifyMinutes then
        notifyMinutes = math.floor(
            math.max(
                1,
                tonumber(savedNotifyMinutes)
                    or DEFAULT_NOTIFY_MINUTES
            )
        )
    end

    if savedEarnMoney then
        earnedMoneyTotal = tonumber(savedEarnMoney) or 0
    end

    if savedWebhook then
        webhookUrl = savedWebhook
    end
end

local function serializeRuntimeState()
    return table.concat({
        "EarnMoney:" .. tostring(math.floor(earnedMoneyTotal)),
        "Webhook:" .. tostring(webhookUrl):gsub("[\r\n]", ""),
        "AutoNotify:" .. (autoNotify and "1" or "0"),
        "NotifyMinutes:" .. tostring(math.floor(math.max(1, notifyMinutes))),
    }, "\n")
end

local function loadRuntimeState()
    parseRuntimeState(safeRead(RUNTIME_STATE_FILE))

    local earned = tonumber(safeRead(EARN_MONEY_FILE) or "")
    if earned then
        earnedMoneyTotal = earned
    end
end

local function saveRuntimeState()
    ensureDirectories()
    safeWrite(RUNTIME_STATE_FILE, serializeRuntimeState())
    safeWrite(EARN_MONEY_FILE, tostring(math.floor(earnedMoneyTotal)))
end

-- ============================
--  角色/游戏基础工具
-- ============================
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

local function showNotification(title, message, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore(
            "SendNotification",
            {
                Title = tostring(title or "JX"),
                Text = tostring(message or ""),
                Duration = tonumber(duration) or 3,
            }
        )
    end)
end

local function restoreCharacterCollision()
    local character = getCharacter()

    if not character then
        return
    end

    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart")
            and object.Name ~= "HumanoidRootPart"
        then
            object.CanCollide = true
        end
    end
end

local function readCashAmountValue()
    local coreGui = PlayerGui:FindFirstChild("CoreGUI")
    if not coreGui then
        return 0
    end

    local cash = coreGui:FindFirstChild("Cash", true)
    if not cash then
        return 0
    end

    local text = cash.Text or cash.Value or "0"
    return tonumber(text:gsub("[^%d]", "")) or 0
end

local function findMoneyContainer()
    local filter = workspace:FindFirstChild("Filter")
    return filter and filter:FindFirstChild("SpawnedBread") or nil
end

local function getMoneyTargets(radius)
    radius = tonumber(radius) or MONEY_SEARCH_RADIUS
    local root = getRootPart()
    local container = findMoneyContainer()
    if not root or not container then
        return {}
    end

    local result = {}
    for _, model in ipairs(container:GetChildren()) do
        local mainPart = model:FindFirstChild("MainPart")
        if mainPart and mainPart:IsA("BasePart") then
            local distance = (mainPart.Position - root.Position).Magnitude
            if distance <= radius then
                table.insert(result, {
                    model = model,
                    part = mainPart,
                    distance = distance,
                })
            end
        end
    end

    table.sort(result, function(a, b)
        return a.distance < b.distance
    end)
    return result
end

local function firePickupEvent(target)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild(PICKUP_REMOTE_NAME, true)
    local cashDrop = target and (target.model or target.part)

    if not remote or not remote:IsA("RemoteEvent") or not cashDrop then
        return false
    end

    return pcall(remote.FireServer, remote, cashDrop)
end

local function collectMoneyTarget(target)
    if not target or not target.part then
        return false
    end

    local root = getRootPart()
    if not root then
        return false
    end

    pcall(function()
        root.CFrame = target.part.CFrame + Vector3.new(0, 2, 0)
    end)
    waitSeconds(0.05)
    return firePickupEvent(target)
end

local function collectNearbyMoney()
    if not autoMoney then
        return
    end

    for _ = 1, MONEY_COLLECT_MAX_PASSES do
        local targets = getMoneyTargets(MONEY_SEARCH_RADIUS)
        if #targets == 0 then
            break
        end
        for _, target in ipairs(targets) do
            if not farmEnabled then
                return
            end
            pcall(collectMoneyTarget, target)
        end
    end
end
-- ============================
--  JX-CRIMINALITY-FARM (Library UI) - Part 2/6
--  隐形、防跌落、反AFK、商店购买
-- ============================

-- ============================
--  隐形功能
-- ============================
local invisHeartbeatConnection
local invisCharacterConnection
local invisWarningGui
local invisWarningLabel
local invisAnimation
local invisTrack

local function ensureInvisWarningGui()
    if invisWarningGui and invisWarningGui.Parent then
        return invisWarningGui, invisWarningLabel
    end

    local existing =
        UiParent:FindFirstChild("JXInvisWarningGUI")
        or UiParent:FindFirstChild("InvisWarningGUI")
        or UiParent:FindFirstChild("WarningGUI")
    if existing then
        invisWarningGui = existing
        invisWarningLabel = existing:FindFirstChildWhichIsA("TextLabel", true)
        return invisWarningGui, invisWarningLabel
    end

    invisWarningGui = Instance.new("ScreenGui")
    invisWarningGui.Name = "JXInvisWarningGUI"
    invisWarningGui.ResetOnSpawn = false
    invisWarningGui.Parent = UiParent

    invisWarningLabel = Instance.new("TextLabel")
    invisWarningLabel.Name = "TextLabel"
    invisWarningLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    invisWarningLabel.Position = UDim2.new(0.5, 0, 0.75, 0)
    invisWarningLabel.Size = UDim2.new(0, 420, 0, 52)
    invisWarningLabel.BackgroundTransparency = 1
    invisWarningLabel.Font = Enum.Font.GothamBold
    invisWarningLabel.Text = "VISIBLE WARNING"
    invisWarningLabel.TextSize = 30
    invisWarningLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
    invisWarningLabel.Visible = false
    invisWarningLabel.Parent = invisWarningGui

    return invisWarningGui, invisWarningLabel
end

local function setVisibleBodyTransparency(character, fromTransparency, toTransparency)
    if not character then
        return
    end

    for _, instance in ipairs(character:GetDescendants()) do
        if instance:IsA("BasePart")
            and instance.Name ~= "HumanoidRootPart"
            and (
                fromTransparency == nil
                or instance.Transparency == fromTransparency
            )
        then
            if fromTransparency ~= nil or instance.Transparency ~= 1 then
                instance.Transparency = toTransparency
            end
        end
    end
end

local function stopInvisTrack()
    if invisTrack then
        pcall(function()
            invisTrack:Stop()
        end)
        invisTrack = nil
    end
end

local function updateInvisCharacter()
    if not invisEnabled then
        return
    end

    local character = getCharacter()
    local humanoid = getHumanoid(character)
    local root = getRootPart(character)

    if not character or not humanoid or not root then
        return
    end

    local torso = character:FindFirstChild("Torso")
    if not torso then
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    camera.CameraSubject = root

    if invisWarningLabel then
        invisWarningLabel.Visible =
            humanoid.FloorMaterial == Enum.Material.Air
    end

    local _, cameraYaw = camera.CFrame:ToOrientation()
    root.CFrame =
        CFrame.new(root.Position)
        * CFrame.fromOrientation(0, cameraYaw, 0)

    root.CFrame = root.CFrame * CFrame.Angles(math.rad(90), 0, 0)
    humanoid.CameraOffset = Vector3.new(0, 1.44, 0)

    invisAnimation = invisAnimation or Instance.new("Animation")
    invisAnimation.AnimationId = "rbxassetid://215384594"

    stopInvisTrack()

    local ok, track = pcall(function()
        return humanoid:LoadAnimation(invisAnimation)
    end)

    if ok and track then
        invisTrack = track
        track.Priority = Enum.AnimationPriority.Action4
        track:Play()
        track:AdjustSpeed(0)
        track.TimePosition = 0.3
    end

    RunService.RenderStepped:Wait()
    stopInvisTrack()

    local lookVector = camera.CFrame.LookVector
    local horizontal = Vector3.new(lookVector.X, 0, lookVector.Z)

    if horizontal.Magnitude > 0 then
        horizontal = horizontal.Unit
        root.CFrame = CFrame.new(
            root.Position,
            root.Position + horizontal
        )
    end

    setVisibleBodyTransparency(character, nil, 0.5)
end

local function ensureInvisHeartbeat()
    if invisHeartbeatConnection then
        return
    end

    invisHeartbeatConnection = RunService.Heartbeat:Connect(function()
        if invisEnabled then
            pcall(updateInvisCharacter)
        elseif invisWarningLabel then
            invisWarningLabel.Visible = false
        end
    end)
end

local function invisEnable()
    local character = getCharacter()

    if not character or not character:FindFirstChild("Torso") then
        return false
    end

    userWantsInvis = true
    invisEnabled = true

    ensureInvisWarningGui()
    ensureInvisHeartbeat()

    local root = getRootPart(character)
    local camera = workspace.CurrentCamera

    if camera and root then
        camera.CameraSubject = root
    end

    pcall(updateInvisCharacter)
    return true
end

local function invisDisable()
    userWantsInvis = false
    invisEnabled = false

    stopInvisTrack()

    local character = getCharacter()
    local humanoid = getHumanoid(character)
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

    return true
end

local function setInvisible(enabled)
    if enabled == true then
        return invisEnable()
    end

    return invisDisable()
end

invisCharacterConnection = LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid", 10)
    character:WaitForChild("HumanoidRootPart", 10)

    if userWantsInvis then
        waitSeconds(0.1)
        invisEnable()
    end
end)

-- ============================
--  防跌落
-- ============================
local noFallHookInstalled = false
local noFallHeartbeatConnection

local function applyNoFallCharacterState()
    local character = getCharacter()
    if not character then
        return
    end

    local charStats = character:FindFirstChild("CharStats")
    if not charStats then
        return
    end

    local playerStats = charStats:FindFirstChild(LocalPlayer.Name)
        or charStats:FindFirstChild(tostring(LocalPlayer.UserId))
        or charStats

    local ragdollSwitch = playerStats:FindFirstChild("RagdollSwitch")
        or charStats:FindFirstChild("RagdollSwitch", true)

    local ragdollTime = playerStats:FindFirstChild("RagdollTime")
        or charStats:FindFirstChild("RagdollTime", true)

    if noFallEnabled then
        if ragdollSwitch and ragdollSwitch:IsA("BoolValue") then
            ragdollSwitch.Value = false
        end

        if ragdollTime and (
            ragdollTime:IsA("NumberValue")
            or ragdollTime:IsA("IntValue")
        ) then
            ragdollTime.Value = 0
        end
    end
end

local function installNoFallHook()
    if noFallHookInstalled then
        return true
    end

    if type(hookmetamethod) ~= "function"
        or type(newcclosure) ~= "function"
        or type(getnamecallmethod) ~= "function"
    then
        return false
    end

    local oldNamecall

    oldNamecall = hookmetamethod(
        game,
        "__namecall",
        newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local events = ReplicatedStorage:FindFirstChild("Events")
            local fallRemote = events and events:FindFirstChild("__RZDONL")

            if noFallEnabled
                and method == "FireServer"
                and self == fallRemote
                and select(1, ...) == "FlllD"
            then
                return nil
            end

            return oldNamecall(self, ...)
        end)
    )

    noFallHookInstalled = true
    return true
end

local function setNoFall(enabled)
    noFallEnabled = enabled == true

    if noFallHeartbeatConnection then
        noFallHeartbeatConnection:Disconnect()
        noFallHeartbeatConnection = nil
    end

    if noFallEnabled then
        installNoFallHook()
        applyNoFallCharacterState()

        noFallHeartbeatConnection =
            RunService.Heartbeat:Connect(function()
                pcall(applyNoFallCharacterState)
            end)
    end

    return noFallEnabled
end

-- ============================
--  反AFK
-- ============================
local antiAfkConnection

local function setAntiAfk(enabled)
    antiAfkEnabled = enabled == true

    if antiAfkConnection then
        antiAfkConnection:Disconnect()
        antiAfkConnection = nil
    end

    if not antiAfkEnabled then
        return
    end

    antiAfkConnection = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end

-- ============================
--  商店购买（撬棍、开锁器）
-- ============================
local function findToolByName(name)
    local character = getCharacter()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

    if character then
        local equipped = character:FindFirstChild(name)
        if equipped and equipped:IsA("Tool") then
            return equipped
        end
    end

    if backpack then
        local stored = backpack:FindFirstChild(name)
        if stored and stored:IsA("Tool") then
            return stored
        end
    end

    return nil
end

local function equipTool(tool)
    if not tool then
        return false
    end

    local character = getCharacter()
    local humanoid = getHumanoid(character)

    if not character or not humanoid then
        return false
    end

    if tool.Parent == character then
        return true
    end

    return pcall(humanoid.EquipTool, humanoid, tool)
end

local function getShopMainPart(name)
    local map = workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    local shop = shopz and shopz:FindFirstChild(name)
    return shop and shop:FindFirstChild("MainPart") or nil
end

local function buyCrowbar()
    if findToolByName("Crowbar") then
        return true
    end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local dealerPart = getShopMainPart("Dealer")
    local protectionRemote = events and events:FindFirstChild("BYZERSPROTEC")
    local purchaseRemote = events and events:FindFirstChild("SSHPRMTE1")

    if not dealerPart or not protectionRemote or not purchaseRemote then
        return false
    end

    local root = getRootPart()
    if not root then
        return false
    end

    local dur = math.max(0.1, (dealerPart.Position - root.Position).Magnitude / moveSpeed)
    TweenService:Create(root, TweenInfo.new(dur), {CFrame = dealerPart.CFrame + Vector3.new(0, 3, 0)}):Play()
    waitSeconds(dur + 0.3)

    pcall(protectionRemote.FireServer, protectionRemote, true, "shop", dealerPart, "IllegalStore")
    pcall(purchaseRemote.InvokeServer, purchaseRemote, "IllegalStore", "Melees", "Crowbar", dealerPart, nil, true)
    pcall(protectionRemote.FireServer, protectionRemote, false)
    waitSeconds(SHOP_POST_BUY_SECONDS)

    return findToolByName("Crowbar") ~= nil
end

local function countToolsByName(name)
    local total = 0
    local character = getCharacter()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

    for _, container in ipairs({ character, backpack }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and item.Name == name then
                    total = total + 1
                end
            end
        end
    end

    return total
end

local function findNearestLockpickShopPart()
    local root = getRootPart()
    local selected
    local selectedDistance = math.huge

    for _, name in ipairs({ "ArmoryDealer", "Dealer" }) do
        local part = getShopMainPart(name)

        if part then
            local distance = root and (part.Position - root.Position).Magnitude or 0

            if distance < selectedDistance then
                selected = part
                selectedDistance = distance
            end
        end
    end

    return selected
end

local function purchaseLockpickAt(shopPart)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local purchaseRemote = events and events:FindFirstChild("SSHPRMTE1")

    if not shopPart or not purchaseRemote then
        return false
    end

    local illegalOk = pcall(
        purchaseRemote.InvokeServer,
        purchaseRemote,
        "IllegalStore",
        "Misc",
        "Lockpick",
        shopPart,
        nil,
        true
    )

    waitSeconds(0.25)

    local legalOk = pcall(
        purchaseRemote.InvokeServer,
        purchaseRemote,
        "LegalStore",
        "Misc",
        "Lockpick",
        shopPart,
        nil,
        true
    )

    return illegalOk or legalOk
end

local function buyLockpickBatch(quantity)
    quantity = math.max(1, math.floor(tonumber(quantity) or 7))

    local shopPart = findNearestLockpickShopPart()

    if not shopPart then
        return false
    end

    local root = getRootPart()
    if not root then
        return false
    end

    local dur = math.max(0.1, (shopPart.Position - root.Position).Magnitude / moveSpeed)
    TweenService:Create(root, TweenInfo.new(dur), {CFrame = shopPart.CFrame + Vector3.new(0, 3, 0)}):Play()
    waitSeconds(dur + 0.3)

    local startingCount = countToolsByName("Lockpick")

    for _ = 1, quantity do
        if not farmEnabled then
            break
        end
        purchaseLockpickAt(shopPart)
        waitSeconds(0.15)
    end

    waitSeconds(0.75)
    return countToolsByName("Lockpick") > startingCount
end
-- ============================
--  JX-CRIMINALITY-FARM (Library UI) - Part 3/6
--  移动、寻路、目标查找
-- ============================

-- ============================
--  移动与寻路（核心）
-- ============================
local SU_FIRST_POSITION = Vector3.new(-4481, 4, -362)
local SU_NEARBY_LOWER_POSITION = Vector3.new(-4475, -22, -363)
local SU_LOW_POSITION = Vector3.new(-4609, 4, -153)
local SU_HIGH_POSITION = Vector3.new(-4602, 4, -153)
local CENTER_FALLBACK_POSITION = Vector3.new(-114, 3, -333)
local TOWER_FIRST_POSITION = Vector3.new(-4920, 4, -1043)
local TOWER_LOWER_POSITION = Vector3.new(-4915, -7, -96)
local SW11_FIRST_POSITION = Vector3.new(-4736, -22, -1026)
local SW11_SECOND_POSITION = Vector3.new(-4735, 3, -1022)
local EAST_FALLBACK_POSITION = Vector3.new(-4341, 3, -80)

local suZoneEntered = false
local towerZoneEntered = false
local sw11ZoneEntered = false
local sw11SavedEntryPathPoint = nil
local sw11SavedVisualPath = nil

local function isTemporarilyIgnored(model)
    local untilTime = temporarilyIgnoredTargets[model]

    if untilTime == nil then
        return false
    end

    if now() >= untilTime then
        temporarilyIgnoredTargets[model] = nil
        return false
    end

    return true
end

local function ignoreTarget(model, duration)
    temporarilyIgnoredTargets[model] =
        now() + (duration or IGNORE_DURATION)
end

local function getTargetPart(model)
    if not model or not model.Parent then
        return nil
    end

    return model:FindFirstChild("MainPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function targetIsBroken(model)
    local values = model and model:FindFirstChild("Values")
    local broken = values and values:FindFirstChild("Broken")
    return broken and broken.Value == true or false
end

local function classifyTargetZone(model, part)
    if not part then
        return "Normal"
    end

    local lowerName = tostring(model.Name):lower()
    local position = part.Position

    if lowerName:find("sw11", 1, true)
        or (position - SW11_SECOND_POSITION).Magnitude < 450
    then
        return "SW11"
    end

    if lowerName:find("tower", 1, true)
        or (position - TOWER_FIRST_POSITION).Magnitude < 450
    then
        return "Tower"
    end

    if lowerName:find("su", 1, true)
        or (position - SU_FIRST_POSITION).Magnitude < 500
        or (position - SU_LOW_POSITION).Magnitude < 500
    then
        return "SU"
    end

    return "Normal"
end

local function findCandidateTargets()
    local result = {}
    local seen = {}
    local map = workspace:FindFirstChild("Map")
    local containers = {}

    if map then
        local parts = map:FindFirstChild("Parts")
        local mappedParts = map:FindFirstChild("M_Parts")

        if parts then
            containers[#containers + 1] = parts
        end

        if mappedParts and mappedParts ~= parts then
            containers[#containers + 1] = mappedParts
        end

        if #containers == 0 then
            containers[#containers + 1] = map
        end
    end

    for _, container in ipairs(containers) do
        for _, object in ipairs(container:GetDescendants()) do
            if object:IsA("Model")
                and not seen[object]
                and not isTemporarilyIgnored(object)
                and not processedTargets[object]
            then
                local part = getTargetPart(object)
                local values = object:FindFirstChild("Values")
                local broken = values and values:FindFirstChild("Broken")

                if part
                    and values
                    and broken
                    and broken.Value ~= true
                then
                    seen[object] = true

                    result[#result + 1] = {
                        obj = object,
                        part = part,
                        zone = classifyTargetZone(object, part),
                    }
                end
            end
        end
    end

    local root = getRootPart()

    if root then
        table.sort(result, function(a, b)
            local aDistance =
                (a.part.Position - root.Position).Magnitude

            local bDistance =
                (b.part.Position - root.Position).Magnitude

            return aDistance < bDistance
        end)
    end

    sortedTargets = result
    return result
end

local function tweenRootTo(position, targetCFrame)
    local root = getRootPart()

    if not root then
        return false, "root_missing"
    end

    local distance = (position - root.Position).Magnitude
    local duration =
        math.max(0.05, distance / math.max(1, moveSpeed))

    local destination =
        targetCFrame
        or CFrame.new(position + Vector3.new(0, 3, 0))

    actionInProgress = true
    markMove()

    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = destination }
    )

    local completed = false
    local playbackState

    local connection = tween.Completed:Connect(function(state)
        playbackState = state
        completed = true
    end)

    tween:Play()
    local startedAt = now()

    while farmEnabled
        and not completed
        and now() - startedAt < duration + 2
    do
        if isDead() then
            tween:Cancel()
            break
        end

        waitSeconds(0.05)
    end

    connection:Disconnect()
    actionInProgress = false

    return completed
        and playbackState == Enum.PlaybackState.Completed,
        completed and "success" or "timeout"
end

local function buildWaypointPath(fromPosition, toPosition)
    local path = PathfindingService:CreatePath({
        WaypointSpacing = WAYPOINT_SPACING,
    })

    local ok = pcall(
        path.ComputeAsync,
        path,
        fromPosition,
        toPosition
    )

    if not ok or path.Status ~= Enum.PathStatus.Success then
        return {
            toPosition,
        }
    end

    local points = {}

    for _, waypoint in ipairs(path:GetWaypoints()) do
        points[#points + 1] = waypoint.Position
    end

    if #points == 0 then
        points[1] = toPosition
    end

    return points
end

local function followWaypointPath(points)
    for _, position in ipairs(points) do
        if not farmEnabled or isDead() then
            return false, "stopped"
        end

        local ok, reason = tweenRootTo(position)

        if not ok then
            return false, reason
        end
    end

    return true, "success"
end

local function moveToSpecialEntry(position)
    local root = getRootPart()

    if not root or not position then
        return false
    end

    local points = buildWaypointPath(root.Position, position)
    return followWaypointPath(points)
end

local function handleSpecialSUPath(model)
    local targetPart = getTargetPart(model)

    if not targetPart then
        return false, "missing_part"
    end

    if not suZoneEntered then
        moveToSpecialEntry(SU_FIRST_POSITION)
        suZoneEntered = true
    end

    local root = getRootPart()

    if root then
        local lowDistance =
            (root.Position - SU_LOW_POSITION).Magnitude

        local highDistance =
            (root.Position - SU_HIGH_POSITION).Magnitude

        moveToSpecialEntry(
            lowDistance < highDistance
                and SU_LOW_POSITION
                or SU_HIGH_POSITION
        )
    end

    return tweenRootTo(
        targetPart.Position,
        targetPart.CFrame + Vector3.new(0, 3, 0)
    )
end

local function handleTowerPath(model)
    local targetPart = getTargetPart(model)

    if not targetPart then
        return false, "missing_part"
    end

    if not towerZoneEntered then
        moveToSpecialEntry(TOWER_FIRST_POSITION)
        towerZoneEntered = true
    end

    return tweenRootTo(
        targetPart.Position,
        targetPart.CFrame + Vector3.new(0, 3, 0)
    )
end

local function handleSW11Path(model)
    local targetPart = getTargetPart(model)

    if not targetPart then
        return false, "missing_part"
    end

    if not sw11ZoneEntered then
        local root = getRootPart()

        if root then
            sw11SavedEntryPathPoint = root.Position
            sw11SavedVisualPath =
                buildWaypointPath(
                    root.Position,
                    SW11_FIRST_POSITION
                )
        end

        if sw11SavedVisualPath then
            followWaypointPath(sw11SavedVisualPath)
        end

        moveToSpecialEntry(SW11_SECOND_POSITION)
        sw11ZoneEntered = true
    end

    return tweenRootTo(
        targetPart.Position,
        targetPart.CFrame + Vector3.new(0, 3, 0)
    )
end

local function moveToTarget(model)
    local targetPart = getTargetPart(model)

    if not targetPart then
        return false, "missing_part"
    end

    reachedTargetY = false
    local zone = classifyTargetZone(model, targetPart)
    local ok
    local reason

    if zone == "SU" then
        ok, reason = handleSpecialSUPath(model)
    elseif zone == "Tower" then
        ok, reason = handleTowerPath(model)
    elseif zone == "SW11" then
        ok, reason = handleSW11Path(model)
    else
        ok, reason = tweenRootTo(
            targetPart.Position,
            targetPart.CFrame + Vector3.new(0, 3, 0)
        )
    end

    reachedTargetY = ok == true
    return ok, reason
end
-- ============================
--  JX-CRIMINALITY-FARM (Library UI) - Part 4/6
--  打破目标（核心战斗）、ATM存款、Allowance
-- ============================

-- ============================
--  打破目标（核心战斗逻辑）
-- ============================
local function breakTarget(target)
    if not target or not target.Parent then
        return false, "target_removed"
    end

    if targetIsBroken(target) then
        return true, "already_broken"
    end

    if breakingMethod == "Crowbar" then
        if not findToolByName("Crowbar") and not buyCrowbar() then
            return false, "crowbar_unavailable"
        end

        local startedAt = now()

        while farmEnabled
            and target.Parent
            and not targetIsBroken(target)
            and now() - startedAt < 30
        do
            local targetPart = getTargetPart(target)
            local root = getRootPart()

            if not targetPart or not root then
                return false, "missing_part"
            end

            if (targetPart.Position - root.Position).Magnitude > 8 then
                local moved = moveToTarget(target)

                if not moved then
                    return false, "movement_failed"
                end
            end

            local events = ReplicatedStorage:FindFirstChild("Events")
            local startFolder = events and events:FindFirstChild("XMHH")
            local finishFolder = events and events:FindFirstChild("XMHH2")
            local startRemote = startFolder and startFolder:FindFirstChild("2")
            local finishRemote = finishFolder and finishFolder:FindFirstChild("2")
            local tool = findToolByName("Crowbar")
            local character = getCharacter()
            local rightArm = character and (
                character:FindFirstChild("Right Arm")
                or character:FindFirstChild("RightHand")
            )

            if startRemote and finishRemote and tool and rightArm and targetPart then
                equipTool(tool)

                local ok, token = pcall(
                    startRemote.InvokeServer,
                    startRemote,
                    "🍞",
                    now(),
                    tool,
                    "DZDRRRKI",
                    target,
                    "Register"
                )

                if ok and type(token) == "number" then
                    pcall(
                        finishRemote.FireServer,
                        finishRemote,
                        "🍞",
                        now(),
                        tool,
                        "2389ZFX34",
                        token,
                        false,
                        rightArm,
                        targetPart,
                        target,
                        targetPart.Position,
                        targetPart.Position
                    )
                end
            end

            waitSeconds(0.25)
        end
    else -- Fist + Lockpick
        local startedAt = now()
        local nextBatchSize = 7

        while farmEnabled
            and target.Parent
            and not targetIsBroken(target)
            and now() - startedAt < 120
        do
            local targetPart = getTargetPart(target)
            local root = getRootPart()

            if not targetPart or not root then
                return false, "missing_part"
            end

            if (targetPart.Position - root.Position).Magnitude > 8 then
                local moved = moveToTarget(target)

                if not moved then
                    return false, "movement_failed"
                end
            end

            if not findToolByName("Lockpick") then
                if not buyLockpickBatch(nextBatchSize) then
                    return false, "lockpick_unavailable"
                end

                nextBatchSize = 15

                if target.Parent and not targetIsBroken(target) then
                    moveToTarget(target)
                end
            end

            local tool = findToolByName("Lockpick")
            if tool then
                equipTool(tool)
                local remote = tool:FindFirstChild("Remote")
                if remote and remote:IsA("RemoteFunction") then
                    local ok, token = pcall(
                        remote.InvokeServer,
                        remote,
                        "S",
                        target,
                        "s"
                    )
                    if ok and type(token) == "number" then
                        waitSeconds(0.25)
                        pcall(
                            remote.InvokeServer,
                            remote,
                            "D",
                            target,
                            "s",
                            token
                        )
                    end
                end
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

    return false, "break_timeout"
end

-- ============================
--  ATM存款
-- ============================
local function findATMMainPart()
    local map = workspace:FindFirstChild("Map")
    local atmz = map and map:FindFirstChild("ATMz")
    local atm = atmz and atmz:FindFirstChild("ATM")
    local mainPart = atm and atm:FindFirstChild("MainPart")
    if mainPart and mainPart:IsA("BasePart") then
        return mainPart
    end
    return nil
end

local function moveToPart(part)
    local root = getRootPart()
    if not root or not part then
        return false
    end

    actionInProgress = true
    markMove()

    local distance = (part.Position - root.Position).Magnitude
    local duration = math.max(0.05, distance / math.max(1, moveSpeed))
    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { CFrame = part.CFrame + Vector3.new(0, 3, 0) }
    )

    local completed = false
    local connection = tween.Completed:Connect(function()
        completed = true
    end)

    tween:Play()

    local started = now()
    while (farmEnabled or depositInProgress)
        and not completed
        and now() - started < duration + 2
    do
        if isDead() then
            tween:Cancel()
            break
        end
        waitSeconds(0.05)
    end

    connection:Disconnect()
    actionInProgress = false

    return completed
end

local function performDepositRequest(events, cash)
    local remote = events and events:FindFirstChild("ATM")
    local atmMainPart = findATMMainPart()

    if not remote or not remote:IsA("RemoteFunction") or not atmMainPart then
        return false
    end

    if not moveToPart(atmMainPart) then
        return false
    end

    local accepted, message, blocked, value =
        remote:InvokeServer("DP", cash, atmMainPart)

    return accepted == true, message, blocked, value
end

local function tryDeposit()
    if not autoDepositEnabled then
        return false
    end

    if depositInProgress then
        return true
    end

    local currentTime = now()

    if currentTime < (depositCooldownUntil or 0) then
        return false
    end

    if currentTime - (depositLastAttemptAt or 0) < 1.5 then
        return false
    end

    local cash = readCashAmountValue()
    local threshold = depositThreshold or 5000

    if threshold <= 0 or cash < threshold then
        return false
    end

    collectNearbyMoney()

    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then
        return false
    end

    depositLastAttemptAt = now()
    depositInProgress = true

    local ok, accepted = pcall(function()
        local success = performDepositRequest(events, cash)
        waitSeconds(0.2)
        return success == true and readCashAmountValue() <= 0
    end)

    depositInProgress = false
    depositCooldownUntil = now() + 2.5
    farmActivityStatus = "Idle"

    return ok and accepted == true
end

local function tryDepositAllNow()
    local previousEnabled = autoDepositEnabled
    autoDepositEnabled = true

    local ok, result = pcall(function()
        local attempts = 0

        while attempts < 100 do
            attempts = attempts + 1

            if readCashAmountValue() <= 0 then
                return true
            end

            if tryDeposit() then
                return true
            end

            waitSeconds(0.25)
        end

        return false
    end)

    autoDepositEnabled = previousEnabled
    farmActivityStatus = "Idle"

    return ok and result == true
end

local function maybeAutoDeposit()
    if not autoDepositEnabled then
        return false
    end

    return tryDeposit()
end

-- ============================
--  Allowance 领取
-- ============================
local function claimAllowance()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("CLMZALOW")
    local atm = findATMMainPart()

    if not remote or not atm then
        return false, "allowance_unavailable"
    end

    local ok, accepted, message, blocked, amount = pcall(
        remote.InvokeServer,
        remote,
        atm
    )

    if not ok then
        return false, accepted
    end

    if type(amount) == "number" then
        allowanceAmount = amount
    end

    return accepted == true, message, blocked, amount
end

local function readStatsGui()
    local coreGui = PlayerGui:FindFirstChild("CoreGUI")
    local statsFrame = coreGui and coreGui:FindFirstChild("StatsFrame", true)
    if not statsFrame then
        return
    end

    local allowance = statsFrame:FindFirstChild("Allowance", true)
    local bank = statsFrame:FindFirstChild("Bank", true)

    local function parseNumber(object)
        if not object then return nil end
        local text = object.Text or object.Value or ""
        local normalized = tostring(text):gsub("[^%d%.%-]", "")
        return tonumber(normalized)
    end

    allowanceAmount = parseNumber(allowance) or allowanceAmount
    bankAmount = parseNumber(bank) or bankAmount
end
-- ============================
--  JX-CRIMINALITY-FARM (Library UI) - Part 5/6
--  反踢重连、自动重生、农场主循环
-- ============================

-- ============================
--  反踢/重连
-- ============================
local antiRejoinInstalled = false
local antiRejoinBusy = false
local antiRejoinConnections = {}

local function readErrorPromptText()
    local robloxPromptGui = CoreGui:FindFirstChild("RobloxPromptGui")
    local promptOverlay = robloxPromptGui and robloxPromptGui:FindFirstChild("promptOverlay")
    local errorPrompt = promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt")

    if not errorPrompt or not errorPrompt.Visible then
        return ""
    end

    local parts = {}

    for _, descendant in ipairs(errorPrompt:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Visible and descendant.Text ~= "" then
            parts[#parts + 1] = descendant.Text
        end
    end

    return table.concat(parts, " ")
end

local function shouldRejoinFromError(message)
    local lower = tostring(message or ""):lower()

    if lower == "" then
        return false
    end

    for _, fragment in ipairs({
        "kicked",
        "disconnect",
        "connection",
        "error code",
        "same account",
        "teleport failed",
        "server shut",
        "shutdown",
    }) do
        if lower:find(fragment, 1, true) then
            return true
        end
    end

    return false
end

local function attemptRejoin(message)
    if not antiRejoin or antiRejoinBusy then
        return false
    end

    if not shouldRejoinFromError(message) then
        return false
    end

    antiRejoinBusy = true
    lastRejoinAt = now()

    spawnTask(function()
        waitSeconds(0.5)

        local ok = false

        if game.JobId ~= "" then
            ok = pcall(
                TeleportService.TeleportToPlaceInstance,
                TeleportService,
                game.PlaceId,
                game.JobId,
                LocalPlayer
            )
        end

        if not ok then
            pcall(
                TeleportService.Teleport,
                TeleportService,
                game.PlaceId,
                LocalPlayer
            )
        end

        waitSeconds(5)
        antiRejoinBusy = false
    end)

    return true
end

local function installAntiRejoin()
    if antiRejoinInstalled then
        return true
    end

    antiRejoinConnections[#antiRejoinConnections + 1] =
        GuiService.ErrorMessageChanged:Connect(function(message)
            attemptRejoin(message)
        end)

    antiRejoinConnections[#antiRejoinConnections + 1] =
        RunService.Heartbeat:Connect(function()
            if not antiRejoin then
                return
            end

            local message = readErrorPromptText()

            if message ~= "" then
                attemptRejoin(message)
            end
        end)

    antiRejoinInstalled = true
    return true
end

-- ============================
--  自动重生
-- ============================
local function respawnCharacter()
    local character = getCharacter()
    local humanoid = getHumanoid(character)
    if humanoid and humanoid.Health > 0 then
        return true
    end

    return pcall(LocalPlayer.LoadCharacter, LocalPlayer)
end

local function autoRespawnLoop(runId)
    while farmEnabled and farmRunId == runId do
        characterDead = isDead()
        if autoRespawn and characterDead then
            deathCount = deathCount + 1
            pcall(respawnCharacter)
            waitSeconds(FARM_DEAD_WAIT_SECONDS)
        else
            waitSeconds(0.5)
        end
    end
end

-- ============================
--  管理员检测
-- ============================
local function addAdministratorRole(groupId, roleName)
    local roles = adminGroupRoles[groupId]

    if not roles then
        roles = {}
        adminGroupRoles[groupId] = roles
    end

    roles[roleName] = true
end

local function addAssumedAdministratorRules()
    adminUserIds[3294804378] = true
    adminUserIds[93676120] = true
    adminUserIds[54087314] = true
    adminUserIds[81275825] = true
    adminUserIds[140837601] = true
    adminUserIds[1229486091] = true
    adminUserIds[46567801] = true
    adminUserIds[418086275] = true
    adminUserIds[29706395] = true
    adminUserIds[3717066084] = true
    adminUserIds[1424338327] = true
    adminUserIds[5046662686] = true
    adminUserIds[5046661126] = true
    adminUserIds[5046659439] = true
    adminUserIds[418199326] = true
    adminUserIds[1024216621] = true
    adminUserIds[1810535041] = true
    adminUserIds[63238912] = true
    adminUserIds[111250044] = true
    adminUserIds[63315426] = true
    adminUserIds[730176906] = true
    adminUserIds[141193516] = true
    adminUserIds[194512073] = true
    adminUserIds[193945439] = true
    adminUserIds[412741116] = true
    adminUserIds[195538733] = true
    adminUserIds[102045519] = true
    adminUserIds[955294] = true
    adminUserIds[957835150] = true
    adminUserIds[25689921] = true
    adminUserIds[366613818] = true
    adminUserIds[281593651] = true
    adminUserIds[455275714] = true
    adminUserIds[208929505] = true
    adminUserIds[96783330] = true
    adminUserIds[156152502] = true
    adminUserIds[93281166] = true
    adminUserIds[959606619] = true
    adminUserIds[142821118] = true
    adminUserIds[632886139] = true
    adminUserIds[175931803] = true
    adminUserIds[122209625] = true
    adminUserIds[278097946] = true
    adminUserIds[142989311] = true
    adminUserIds[1517131734] = true
    adminUserIds[446849296] = true
    adminUserIds[87189764] = true
    adminUserIds[67180844] = true
    adminUserIds[9212846] = true
    adminUserIds[47352513] = true
    adminUserIds[48058122] = true
    adminUserIds[155413858] = true
    adminUserIds[10497435] = true
    adminUserIds[513615792] = true
    adminUserIds[55893752] = true
    adminUserIds[55476024] = true
    adminUserIds[151691292] = true
    adminUserIds[136584758] = true
    adminUserIds[16983447] = true
    adminUserIds[3111449] = true
    adminUserIds[94693025] = true
    adminUserIds[271400893] = true
    adminUserIds[5005262660] = true
    adminUserIds[295331237] = true
    adminUserIds[64489098] = true
    adminUserIds[244844600] = true
    adminUserIds[114332275] = true
    adminUserIds[25048901] = true
    adminUserIds[69262878] = true
    adminUserIds[50801509] = true
    adminUserIds[92504899] = true
    adminUserIds[42066711] = true
    adminUserIds[50585425] = true
    adminUserIds[31365111] = true
    adminUserIds[166406495] = true
    adminUserIds[2457253857] = true
    adminUserIds[29761878] = true
    adminUserIds[21831137] = true
    adminUserIds[948293345] = true
    adminUserIds[439942262] = true
    adminUserIds[38578487] = true
    adminUserIds[1163048] = true
    adminUserIds[7713309208] = true
    adminUserIds[3659305297] = true
    adminUserIds[15598614] = true
    adminUserIds[34616594] = true
    adminUserIds[626833004] = true
    adminUserIds[198610386] = true
    adminUserIds[153835477] = true
    adminUserIds[3923114296] = true
    adminUserIds[3937697838] = true
    adminUserIds[102146039] = true
    adminUserIds[119861460] = true
    adminUserIds[371665775] = true
    adminUserIds[1206543842] = true
    adminUserIds[93428604] = true
    adminUserIds[1863173316] = true
    adminUserIds[90814576] = true
    adminUserIds[374665997] = true
    adminUserIds[423005063] = true
    adminUserIds[140172831] = true
    adminUserIds[42662179] = true
    adminUserIds[9066859] = true
    adminUserIds[438805620] = true
    adminUserIds[14855669] = true
    adminUserIds[727189337] = true
    adminUserIds[1871290386] = true
    adminUserIds[608073286] = true

    addAdministratorRole(4165692, "Tester")
    addAdministratorRole(4165692, "Contributor")
    addAdministratorRole(4165692, "Tester+")
    addAdministratorRole(4165692, "Developer")
    addAdministratorRole(4165692, "Developer+")
    addAdministratorRole(4165692, "Community Manager")
    addAdministratorRole(4165692, "Manager")
    addAdministratorRole(4165692, "Owner")
    addAdministratorRole(32406137, "Junior")
    addAdministratorRole(32406137, "Moderator")
    addAdministratorRole(32406137, "Senior")
    addAdministratorRole(32406137, "Administrator")
    addAdministratorRole(32406137, "Manager")
    addAdministratorRole(32406137, "Holder")
    addAdministratorRole(8024440, "reshape enjoyer")
    addAdministratorRole(8024440, "i heart reshape")
    addAdministratorRole(8024440, "reshape superfan")
    addAdministratorRole(14927228, "♞")
end

local function rebuildAdminRules(config)
    adminUserIds = {}
    adminGroupRanks = {}
    adminGroupRoles = {}

    if type(config) ~= "table" then
        addAssumedAdministratorRules()
        return
    end

    local userLists = {
        config.adminUserIds,
        config.AdminUserIds,
        config.admins,
        config.Admins,
    }

    for _, list in ipairs(userLists) do
        if type(list) == "table" then
            for key, value in pairs(list) do
                local userId = tonumber(type(key) == "number" and value or key)

                if userId then
                    adminUserIds[userId] = true
                end
            end
        end
    end

    local groupLists = {
        config.adminGroupIds,
        config.AdminGroupIds,
        config.adminGroups,
        config.AdminGroups,
    }

    for _, list in ipairs(groupLists) do
        if type(list) == "table" then
            for key, value in pairs(list) do
                local groupId
                local minimumRank = 1

                if type(value) == "table" then
                    groupId = tonumber(value.groupId or value.id or key)
                    minimumRank = tonumber(value.minimumRank or value.minRank or value.rank) or 1
                elseif type(key) == "number" then
                    groupId = tonumber(value)
                else
                    groupId = tonumber(key)
                    minimumRank = tonumber(value) or 1
                end

                if groupId then
                    adminGroupRanks[groupId] = minimumRank
                end
            end
        end
    end

    addAssumedAdministratorRules()
end

local function isLikelyAdmin(player)
    if player == LocalPlayer then
        return false
    end

    if adminUserIds[player.UserId] then
        return true
    end

    for groupId, roles in pairs(adminGroupRoles) do
        local ok, roleName = pcall(player.GetRoleInGroup, player, groupId)

        if ok and roles[tostring(roleName)] then
            return true
        end
    end

    for groupId, minimumRank in pairs(adminGroupRanks) do
        local ok, rank = pcall(player.GetRankInGroup, player, groupId)

        if ok and type(rank) == "number" and rank >= minimumRank then
            return true
        end
    end

    return false
end

local function adminWatchLoop(runId)
    while farmEnabled and farmRunId == runId do
        if adminCheckEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if isLikelyAdmin(player) then
                    farmActivityStatus = "Admin: " .. player.Name
                    showNotification("JX", "Admin detected: " .. player.Name, 5)
                    return
                end
            end
        end
        waitSeconds(2)
    end
end

-- ============================
--  农场主循环
-- ============================
local function farmIteration()
    markActivity()
    characterDead = isDead()

    if characterDead then
        waitSeconds(FARM_DEAD_WAIT_SECONDS)
        return
    end

    if noFallEnabled then
        applyNoFallCharacterState()
    end

    if userWantsInvis and not invisEnabled then
        pcall(setInvisible, true)
    elseif not userWantsInvis and invisEnabled then
        pcall(setInvisible, false)
    end

    readStatsGui()

    if autoAllowance then
        pcall(claimAllowance)
    end

    if autoMoney then
        pcall(collectNearbyMoney)
    end

    if autoDepositEnabled then
        pcall(maybeAutoDeposit)
    end

    local target = chooseNextTarget()

    if not target then
        waitSeconds(FARM_IDLE_WAIT_SECONDS)
        return
    end

    forcedNextTargetModel = target

    local moved, moveReason = moveToTarget(target)

    if not moved then
        processTargetMoveOutcome(
            target,
            false,
            moveReason
        )
        return
    end

    local broken, breakReason = breakTarget(target)

    if broken then
        processedTargets[target] = true
        forcedNextTargetModel = nil
        farmActivityStatus = "Idle"
        waitSeconds(FARM_BETWEEN_TARGETS_SECONDS)
        return
    end

    ignoreTarget(target, IGNORE_DURATION)
    forcedNextTargetModel = nil
    retargetPending = true
    waitSeconds(FARM_RETRY_WAIT_SECONDS)
    retargetPending = false

    if breakReason then
        farmActivityStatus = tostring(breakReason)
    end
end

local function chooseNextTarget()
    if forcedNextTargetModel
        and forcedNextTargetModel.Parent
        and not isTemporarilyIgnored(forcedNextTargetModel)
        and not targetIsBroken(forcedNextTargetModel)
    then
        return forcedNextTargetModel
    end

    local targets = findCandidateTargets()
    local first = targets[1]
    return first and first.obj or nil
end

local function processTargetMoveOutcome(model, ok, reason)
    if ok then
        forcedNextTargetModel = nil
        waitSeconds(FARM_BETWEEN_TARGETS_SECONDS)
        return true
    end

    ignoreTarget(model, IGNORE_DURATION)
    retargetPending = true
    waitSeconds(FARM_RETRY_WAIT_SECONDS)
    retargetPending = false
    return false, reason
end

-- ============================
--  startFarm / stopFarm
-- ============================
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
        pcall(setInvisible, false)
    end

    restoreCharacterCollision()
    saveRuntimeState()
    showNotification("JX Farm", reason or "AutoFarm stopped", 2)
    return reason or "AutoFarm stopped"
end

local function startFarm()
    if farmEnabled then
        return false, "already_running"
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
    lastTimeTick = now()

    local runId = farmRunId
    local startedAt = now()

    if antiRejoin then
        pcall(installAntiRejoin)
    end

    if noFallEnabled then
        pcall(setNoFall, true)
    end

    spawnTask(function()
        notifierLoop(runId)
    end)

    spawnTask(function()
        autoRespawnLoop(runId)
    end)

    spawnTask(function()
        adminWatchLoop(runId)
    end)

    spawnTask(function()
        while farmEnabled and farmRunId == runId do
            local ok, err = xpcall(
                farmIteration,
                debug.traceback
            )

            if not ok then
                warn("[JX Farm] iteration error:", err)
                waitSeconds(FARM_RETRY_WAIT_SECONDS)
            end

            farmTimeSeconds = now() - startedAt
            waitSeconds(FARM_TICK_SECONDS)
        end
    end)

    showNotification("JX Farm", "AutoFarm started", 2)
    return true
end

-- ============================
--  通知循环
-- ============================
local function notifierLoop(runId)
    while farmEnabled and farmRunId == runId do
        if autoNotify and webhookUrl ~= "" then
            local current = now()
            local interval = math.max(1, notifyMinutes) * 60
            if not notifyBusy
                and current - notifyLastAt >= interval then
                notifyBusy = true
                pcall(sendFarmWebhook)
                pcall(saveRuntimeState)
                notifyLastAt = current
                notifyBusy = false
            end
        end
        waitSeconds(1)
    end
end
-- ============================
--  JX-CRIMINALITY-FARM (Library UI) - Part 6/6
--  UI 加载（Serotonin-Library）+ Webhook + 启动
-- ============================

-- ============================
--  Webhook 发送（保留功能，删除密钥验证）
-- ============================
local function getExecutorName()
    if type(identifyexecutor) == "function" then
        local ok, name = pcall(identifyexecutor)
        if ok then
            return tostring(name)
        end
    end
    return "Unknown Executor"
end

local function getCountry()
    local ok, raw = pcall(game.HttpGet, game, "http://ip-api.com/json")
    if not ok then
        return "Unknown"
    end
    local decoded = HttpService:JSONDecode(raw)
    return type(decoded) == "table" and tostring(decoded.country or "Unknown") or "Unknown"
end

local function sendFarmWebhook()
    if webhookUrl == "" then
        return false
    end

    local payload = {
        username = "JX-CRIMINALITY-FARM",
        embeds = {
            {
                title = "Farm Status",
                color = 0x64FFC8,
                fields = {
                    { name = "Earned", value = tostring(math.floor(earnedMoneyTotal)), inline = true },
                    { name = "Allowance", value = tostring(math.floor(allowanceAmount)), inline = true },
                    { name = "Bank", value = tostring(math.floor(bankAmount)), inline = true },
                    { name = "Died", value = tostring(deathCount), inline = true },
                    { name = "Time", value = tostring(math.floor(farmTimeSeconds)), inline = true },
                },
                footer = { text = "JX-CRIMINALITY-FARM" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            },
        },
    }

    return pcall(function()
        HttpService:PostAsync(webhookUrl, HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
    end)
end

-- ============================
--  UI 加载（Serotonin-Library）
-- ============================
local function loadMainPayload()
    -- 配置LPH别名（兼容性）
    local env = getgenv() or _G
    env.LPH_JIT = env.MV_VM and function(cb) return env.MV_VM(cb) end or function(v) return v end
    env.LPH_JIT_MAX = env.LPH_JIT
    env.LPH_NO_VIRTUALIZE = function(v) return v end
    env.LPH_NO_UPVALUES = function(v) return v end

    local Library = loadstring(game:HttpGet(LIBRARY_URL))()
    Library.Folders = {
        Directory = DATA_DIRECTORY,
        Configs = CONFIG_DIRECTORY,
        Assets = ASSET_DIRECTORY
    }
    for _, p in pairs(Library.Folders) do
        ensureFolder(p)
    end

    local Window = Library:Window({
        Name = "JX-CRIMINALITY-FARM | Dsc.gg/getjxs",
        Logo = "85279746515974",
        MobileButtonText = "FARM"
    })
    local Watermark = Library:Watermark("JX-CRIMINALITY-FARM")
    local KeybindList = Library:KeybindList()
    Library:CreateSettingsPage(Window, KeybindList, Watermark)

    local MainPage = Window:Page({ Name = "Main", Columns = 2 })

    -- 左侧：控制
    local CtrlSec = MainPage:Section({ Name = "Control", Side = 1 })
    CtrlSec:Toggle({
        Name = "Start Farm",
        Flag = "FarmStart",
        Default = false,
        Callback = function(v)
            if v then
                startFarm()
            else
                stopFarm("User stopped")
            end
        end
    })
    CtrlSec:Toggle({
        Name = "Auto Respawn",
        Flag = "FarmAutoRespawn",
        Default = true,
        Callback = function(v) autoRespawn = v end
    })
    CtrlSec:Toggle({
        Name = "Auto Pickup Money",
        Flag = "FarmAutoMoney",
        Default = false,
        Callback = function(v) autoMoney = v end
    })
    CtrlSec:Toggle({
        Name = "Auto Deposit",
        Flag = "FarmAutoDeposit",
        Default = false,
        Callback = function(v) autoDepositEnabled = v end
    })
    CtrlSec:Slider({
        Name = "Deposit Threshold (k)",
        Flag = "FarmDepositK",
        Min = 1,
        Max = 100,
        Default = 5,
        Suffix = "k",
        Callback = function(v)
            depositThreshold = math.floor(v) * 1000
        end
    })
    CtrlSec:Button({
        Name = "Deposit Now",
        Callback = function()
            spawnTask(function()
                local prev = autoDepositEnabled
                autoDepositEnabled = true
                for _ = 1, 50 do
                    if readCashAmountValue() <= 0 then
                        break
                    end
                    tryDeposit()
                    waitSeconds(0.2)
                end
                autoDepositEnabled = prev
            end)
        end
    })
    CtrlSec:Toggle({
        Name = "Auto Allowance",
        Flag = "FarmAllowance",
        Default = false,
        Callback = function(v) autoAllowance = v end
    })
    CtrlSec:Dropdown({
        Name = "Breaking Method",
        Flag = "FarmBreakMethod",
        Default = "Crowbar",
        Items = { "Crowbar", "Fist + Lockpick" },
        Callback = function(v) breakingMethod = v end
    })
    CtrlSec:Slider({
        Name = "Move Speed",
        Flag = "FarmSpeed",
        Min = 5,
        Max = 80,
        Default = 32,
        Suffix = "",
        Callback = function(v) moveSpeed = math.max(1, v) end
    })

    -- 右侧：辅助
    local MiscSec = MainPage:Section({ Name = "Misc", Side = 2 })
    MiscSec:Toggle({
        Name = "Hide Body (Invis)",
        Flag = "FarmInvis",
        Default = false,
        Callback = function(v) setInvisible(v) end
    })
    MiscSec:Toggle({
        Name = "Anti Fall Damage",
        Flag = "FarmNoFall",
        Default = false,
        Callback = function(v) setNoFall(v) end
    })
    MiscSec:Toggle({
        Name = "Anti-AFK",
        Flag = "FarmAntiAfk",
        Default = false,
        Callback = function(v) setAntiAfk(v) end
    })
    MiscSec:Toggle({
        Name = "Anti Kick/Rejoin",
        Flag = "FarmAntiRejoin",
        Default = false,
        Callback = function(v)
            antiRejoin = v
            if v then
                installAntiRejoin()
            end
        end
    })
    MiscSec:Toggle({
        Name = "Admin Check",
        Flag = "FarmAdminCheck",
        Default = false,
        Callback = function(v) adminCheckEnabled = v end
    })
    MiscSec:Toggle({
        Name = "Auto Notify",
        Flag = "FarmNotify",
        Default = false,
        Callback = function(v) autoNotify = v end
    })
    MiscSec:Slider({
        Name = "Notify Time (min)",
        Flag = "FarmNotifyMin",
        Min = 1,
        Max = 10,
        Default = 1,
        Suffix = "min",
        Callback = function(v) notifyMinutes = math.floor(v) end
    })
    MiscSec:Textbox({
        Name = "Webhook URL",
        Flag = "FarmWebhook",
        Default = "",
        Callback = function(v) webhookUrl = tostring(v) end
    })

    -- Info 区域
    local InfoSec = MainPage:Section({ Name = "Info", Side = 1 })
    local lblStatus = InfoSec:Label("Status: Idle")
    local lblTime = InfoSec:Label("Time: 0s")
    local lblEarn = InfoSec:Label("Earned: 0")
    local lblBank = InfoSec:Label("Bank: $0")
    local lblDied = InfoSec:Label("Died: 0")
    local lblAllow = InfoSec:Label("Allowance: 0")

    spawnTask(function()
        while true do
            if lblStatus and lblStatus.SetText then
                lblStatus:SetText("Status: " .. farmActivityStatus)
            end
            if lblTime and lblTime.SetText then
                lblTime:SetText("Time: " .. math.floor(farmTimeSeconds) .. "s")
            end
            if lblEarn and lblEarn.SetText then
                lblEarn:SetText("Earned: " .. math.floor(earnedMoneyTotal))
            end
            if lblBank and lblBank.SetText then
                lblBank:SetText("Bank: $" .. math.floor(readCashAmountValue()))
            end
            if lblDied and lblDied.SetText then
                lblDied:SetText("Died: " .. deathCount)
            end
            if lblAllow and lblAllow.SetText then
                pcall(function()
                    local core = PlayerGui:FindFirstChild("CoreGUI")
                    local stats = core and core:FindFirstChild("StatsFrame", true)
                    local allow = stats and stats:FindFirstChild("Allowance", true)
                    if allow then
                        allowanceAmount = tonumber((allow.Text or "0"):gsub("[^%d]", "")) or 0
                    end
                    lblAllow:SetText("Allowance: " .. math.floor(allowanceAmount))
                end)
            end
            waitSeconds(1)
        end
    end)

    InfoSec:Button({
        Name = "Reset Stats",
        Callback = function()
            earnedMoneyTotal = 0
            deathCount = 0
            farmTimeSeconds = 0
            saveRuntimeState()
            Library:Notification("Stats reset", 2)
        end
    })

    -- 保存状态
    local SettingsPage = Window:Page({ Name = "Settings", Columns = 1 })
    local SaveSec = SettingsPage:Section({ Name = "Save", Side = 1 })
    SaveSec:Button({
        Name = "Save State",
        Callback = function()
            saveRuntimeState()
            Library:Notification("State saved", 2)
        end
    })
end

-- ============================
--  自动加载（删除密钥验证）
-- ============================
local function autoPlayWorker()
    if autoPlayWorkerBusy then
        return
    end

    autoPlayWorkerBusy = true
    local startedAt = now()

    while autoPlayEnabled do
        local events = ReplicatedStorage:FindFirstChild("Events")
        if events then
            local playRemote = events:FindFirstChild("BRBRBRRBLOOOL2")
            local updateRemote = events:FindFirstChild("UpdateClient")
            if playRemote and playRemote:IsA("RemoteFunction") then
                pcall(playRemote.InvokeServer, playRemote, "", "\15daz\18tough\19")
            end
            if updateRemote and updateRemote:IsA("RemoteEvent") then
                pcall(updateRemote.FireServer, updateRemote)
            end
        end

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

        if now() - startedAt >= 20 then
            break
        end

        waitSeconds(0.2)
    end

    autoPlayWorkerBusy = false
end

local function setAutoPlay(value)
    autoPlayEnabled = value == true
    if autoPlayEnabled and not autoPlayWorkerBusy then
        spawnTask(autoPlayWorker)
    end
end

local function detectLoadTimeAndAutoStart()
    local ok, history = pcall(LogService.GetLogHistory, LogService)
    if ok and type(history) == "table" then
        for _, entry in ipairs(history) do
            local message = tostring(entry.message or entry.Message or "")
            if message:upper():find("LOAD%s*TIME") then
                autoPlayLoadTimeDetected = true
                break
            end
        end
    end

    if autoPlayLoadTimeDetected and autoPlayEnabled then
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

-- ============================
--  setFlag 函数（UI 控件绑定）
-- ============================
local function setFlag(name, value)
    if name == "JXFarmEnabled" then
        if value == true then
            startFarm()
        else
            stopFarm()
        end
        return true
    elseif name == "JXFarmAutoRespawn" then
        autoRespawn = value == true
    elseif name == "JXFarmAutoNotify" then
        autoNotify = value == true
    elseif name == "JXFarmAutoPlay" then
        setAutoPlay(value)
    elseif name == "JXFarmAutoDeposit" then
        setAutoDepositEnabled(value)
    elseif name == "JXFarmAutoMoney" then
        autoMoney = value == true
    elseif name == "JXFarmAntiRejoin" then
        antiRejoin = value == true
        if antiRejoin then
            installAntiRejoin()
        end
    elseif name == "JXFarmAntiAfk" then
        setAntiAfk(value)
    elseif name == "JXFarmAdminCheck" then
        adminCheckEnabled = value == true
    elseif name == "JXFarmAutoAllowance" then
        autoAllowance = value == true
        if autoAllowance then
            pcall(claimAllowance)
        end
    elseif name == "JXFarmInvis" then
        userWantsInvis = value == true
        setInvisible(userWantsInvis)
    elseif name == "CharacterAntiFallDamage" then
        setNoFall(value)
    elseif name == "JXFarmNotifyTimeMinutes" then
        local numeric = tonumber(value)
        if numeric then
            notifyMinutes = math.clamp(
                math.floor(numeric + 0.5),
                1,
                10
            )
        end
    elseif name == "JXFarmAutoDepositThresholdK" then
        setAutoDepositThresholdK(value)
    elseif name == "JXFarmSpeedV2" then
        local numeric = tonumber(value)
        if numeric then
            moveSpeed = math.max(1, numeric)
        end
    elseif name == "JXFarmBreakingMethod" then
        breakingMethod = tostring(value or "Crowbar")
    elseif name == "JXFarmWebhookURL" then
        webhookUrl = tostring(value or "")
    else
        return false
    end

    return true
end

-- ============================
--  启动
-- ============================
loadRuntimeState()
setAntiAfk(false)
rebuildAdminRules({})

deferTask(detectLoadTimeAndAutoStart)

loadMainPayload()

print("JX-CRIMINALITY-FARM (Library UI) Full Loaded!")