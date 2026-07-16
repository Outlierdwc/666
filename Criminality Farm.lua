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

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local UiParent = CoreGui

if type(gethui) == "function" then
    local ok, result = pcall(gethui)

    if ok and result then
        UiParent = result
    end
end


local API_BASE = "https://getjx.onrender.com"
local expirationHours = nil
local keyless = false
local VERIFY_PATH = "/api/jx/keys/verify"
local PUBLIC_CONFIG_PATH = "/api/jx/public/config"
local WEBHOOK_PROXY_URL = "https://jx3e.onrender.com/webhook/discord"
local AUTH_TOKEN_URL = "https://jx3e.onrender.com/auth/token"
local DATA_DIRECTORY = "JX-CRIMINALITY-FARM"
local CONFIG_DIRECTORY = "JX-CRIMINALITY-FARM/Configs"
local ASSET_DIRECTORY = "JX-CRIMINALITY-FARM/Assets"
local EARN_MONEY_FILE = "JX-CRIMINALITY-FARM/JX_EarnMoney.txt"
local RUNTIME_STATE_FILE = "JX-CRIMINALITY-FARM/runtime_state.txt"
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

local API_KEY = ""
local PICKUP_REMOTE_NAME = "CZDPZUS"
local WINDOW_NAME = "JX | Criminality | FARM | Dsc.gg/getjxs"


local function firstFunction(...)
    local values = { ... }
    for _, value in ipairs(values) do
        if type(value) == "function" then
            return value
        end
    end
    return nil
end

local function resolveRequest()
    local synRequest = type(syn) == "table" and syn.request or nil
    local httpRequest = type(http) == "table" and http.request or nil
    return firstFunction(request, http_request, synRequest, httpRequest)
end

local executorRequest = resolveRequest()

local function jsonDecode(text)
    local ok, result = pcall(HttpService.JSONDecode, HttpService, text)
    if ok then
        return result
    end
    return nil
end

local function jsonEncode(value)
    local ok, result = pcall(HttpService.JSONEncode, HttpService, value)
    if ok then
        return result
    end
    return nil
end

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


local function performRequest(options)
    if not executorRequest then
        return nil, "executor_request_missing"
    end

    local ok, response = pcall(executorRequest, options)
    if not ok then
        return nil, tostring(response)
    end
    return response, nil
end

local function getHwid()
    local candidates = {
        rawget(_G, "gethwid"),
        rawget(_G, "get_hwid"),
    }

    for _, candidate in ipairs(candidates) do
        if type(candidate) == "function" then
            local ok, value = pcall(candidate)
            if ok and value ~= nil then
                return tostring(value)
            end
        end
    end

    local ok, analytics = pcall(game.GetService, game, "RbxAnalyticsService")
    if ok and analytics then
        local idOk, value = pcall(analytics.GetClientId, analytics)
        if idOk then
            return tostring(value)
        end
    end

    return "unknown-hwid"
end

local function fetchPublicConfig()
    local response, err = performRequest({
        Url = API_BASE .. PUBLIC_CONFIG_PATH,
        Method = "GET",
        Headers = {
            ["Content-Type"] = "application/json",
        },
    })

    if not response then
        return nil, err
    end

    local body = response.Body or response.body
    local decoded = type(body) == "string" and jsonDecode(body) or nil
    if type(decoded) == "table" then
        return decoded, nil
    end
    return nil, "invalid_public_config_response"
end

local function verifyKey(key)
    local requestId = HttpService:GenerateGUID(false)
    local hwid = getHwid()

    local body = jsonEncode({
        key = key,
        hwid = hwid,
        reqId = requestId,
    })

    if not body then
        return false, "json_encode_failed"
    end

    local response, err = performRequest({
        Url = API_BASE .. VERIFY_PATH,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
        },
        Body = body,
    })

    if not response then
        return false, err
    end

    local decoded = jsonDecode(response.Body or response.body or "")
    if type(decoded) ~= "table" then
        return false, "invalid_verify_response"
    end


    local valid = decoded.valid == true or decoded.ok == true
    if decoded.resId ~= nil and decoded.resId ~= requestId then
        valid = false
    end

    return valid, decoded
end

local function requestAuthToken()
    if API_KEY == "" then
        return nil, "api_key_missing"
    end

    local response, err = performRequest({
        Url = AUTH_TOKEN_URL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["X-API-Key"] = API_KEY,
        },
        Body = jsonEncode({
            userId = LocalPlayer.UserId,
            hwid = getHwid(),
        }),
    })

    if not response then
        return nil, err
    end

    local decoded = jsonDecode(response.Body or response.body or "")
    if type(decoded) == "table" and decoded.success then
        return decoded.token, nil
    end

    return nil, "token_request_failed"
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
    local decoded = jsonDecode(raw)
    return type(decoded) == "table" and tostring(decoded.country or "Unknown") or "Unknown"
end

local function postWebhook(payload, url, authorization)
    local headers = {
        ["Content-Type"] = "application/json",
    }
    if authorization then
        headers.Authorization = "Bearer " .. tostring(authorization)
    end

    return performRequest({
        Url = url,
        Method = "POST",
        Headers = headers,
        Body = jsonEncode(payload),
    })
end

local function sendExecutionWebhook()
    local token = requestAuthToken()
    if not token then
        return false
    end

    local thumbnail = "https://www.roblox.com/headshot-thumbnail/image?userId="
        .. tostring(LocalPlayer.UserId)
        .. "&width=420&height=420&format=png"

    local payload = {
        username = "JX-Bot",
        avatar_url = thumbnail,
        embeds = {
            {
                title = "Script Executed",
                description = "JX | Criminality | FARM",
                color = 0x64FF64,
                thumbnail = { url = thumbnail },
                fields = {
                    { name = "Username", value = LocalPlayer.Name, inline = true },
                    { name = "User ID", value = tostring(LocalPlayer.UserId), inline = true },
                    { name = "Account Age", value = tostring(LocalPlayer.AccountAge), inline = true },
                    { name = "Place ID", value = tostring(game.PlaceId), inline = true },
                    { name = "Job ID", value = "```" .. tostring(game.JobId) .. "```", inline = false },
                    { name = "Executor", value = getExecutorName(), inline = true },
                    { name = "Device", value = UserInputService.TouchEnabled and "Mobile" or "Desktop", inline = true },
                    { name = "Country", value = getCountry(), inline = true },
                },
                footer = { text = "JX-EXECUTED" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            },
        },
    }

    local response = postWebhook(payload, WEBHOOK_PROXY_URL, token)
    return response ~= nil
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

    return postWebhook(payload, webhookUrl) ~= nil
end

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

local function respawnCharacter()

    
    local character = getCharacter()
    local humanoid = getHumanoid(character)
    if humanoid and humanoid.Health > 0 then
        return true
    end

    local ok = pcall(function()
        LocalPlayer:LoadCharacter()
    end)
    return ok
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
                result[#result + 1] = {
                    model = model,
                    part = mainPart,
                    distance = distance,
                }
            end
        end
    end

    table.sort(result, function(a, b)
        return a.distance < b.distance
    end)
    return result
end

local function findRuntimeEventsContainer()
    local direct = ReplicatedStorage:FindFirstChild("Events") or workspace:FindFirstChild("Events")
    if direct then
        return direct
    end
    for _, container in ipairs({ ReplicatedStorage, workspace }) do
        local found = container:FindFirstChild("Events", true)
        if found then
            return found
        end
    end
    return nil
end

local function firePickupEvent(target)
    local events = findRuntimeEventsContainer()
    local remote = events and events:FindFirstChild(PICKUP_REMOTE_NAME, true)
    local cashDrop = target and (target.model or target.part)

    if not remote or not remote:IsA("RemoteEvent") or not cashDrop then
        return false, "pickup_remote_missing"
    end

    local ok = pcall(remote.FireServer, remote, cashDrop)
    return ok, ok and nil or "pickup_fire_failed"
end

local function collectMoneyTarget(target)
    if not target or not target.part then
        return false
    end

    local root = getRootPart()
    if not root then
        return false
    end

    local moved = pcall(function()
        root.CFrame = target.part.CFrame + Vector3.new(0, 2, 0)
    end)
    if moved then
        markMove()
        waitSeconds(0.10)
    end

    local fired = firePickupEvent(target)
    if fired then
        waitSeconds(0.05)
    end
    return moved or fired
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


local function parseCashTextToNumber(value)
    if type(value) == "number" then
        return value
    end

    local text = tostring(value or "")
    text = text:gsub(",", "")
    text = text:gsub("%$", "")
    text = text:gsub("%s+", "")

    local number = tonumber(text:match("%-?%d+%.?%d*"))
    return number or 0
end

local function findCashDisplayObject()
    local coreGui = PlayerGui:FindFirstChild("CoreGUI")
    if not coreGui then
        return nil
    end

    local candidates = {
        "Cash",
        "CashLabel",
        "CashAmount",
        "Money",
        "MoneyLabel",
        "CashAddedText",
    }

    for _, name in ipairs(candidates) do
        local object = coreGui:FindFirstChild(name, true)
        if object then
            return object
        end
    end

    return nil
end

local function readCashAmountText()
    local object = findCashDisplayObject()
    if not object then
        return ""
    end

    local ok, value = pcall(function()
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            return object.Text
        end
        if object:IsA("NumberValue") or object:IsA("IntValue") or object:IsA("StringValue") then
            return object.Value
        end
        return object.Text or object.Value
    end)

    return ok and tostring(value or "") or ""
end

local function readCashAmountValue()
    return parseCashTextToNumber(readCashAmountText())
end

local function hasFistsTool()
    local character = getCharacter()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

    local function containsFists(container)
        if not container then
            return false
        end

        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local lowerName = string.lower(item.Name)
                if string.find(lowerName, "fist", 1, true)
                    or string.find(lowerName, "lockpick", 1, true)
                then
                    return true
                end
            end
        end
        return false
    end

    return containsFists(character) or containsFists(backpack)
end


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

    local ok = pcall(humanoid.EquipTool, humanoid, tool)
    return ok and tool.Parent == character
end

local function getShopMainPart(name)
    local map = workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    local shop = shopz and shopz:FindFirstChild(name)
    return shop and shop:FindFirstChild("MainPart") or nil
end

local function buyCrowbar()
    local existing = findToolByName("Crowbar")

    if existing then
        equipTool(existing)
        return true
    end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local dealerPart = getShopMainPart("Dealer")
    local protectionRemote = events and events:FindFirstChild("BYZERSPROTEC")
    local purchaseRemote = events and events:FindFirstChild("SSHPRMTE1")

    if not dealerPart or not protectionRemote or not purchaseRemote then
        return false
    end

    local moved = tweenRootTo(
        dealerPart.Position,
        dealerPart.CFrame + Vector3.new(0, 3, 0)
    )

    if not moved then
        return false
    end

    pcall(
        protectionRemote.FireServer,
        protectionRemote,
        true,
        "shop",
        dealerPart,
        "IllegalStore"
    )

    local invokeOk, accepted, message = pcall(
        purchaseRemote.InvokeServer,
        purchaseRemote,
        "IllegalStore",
        "Melees",
        "Crowbar",
        dealerPart,
        nil,
        true
    )

    pcall(protectionRemote.FireServer, protectionRemote, false)
    waitSeconds(SHOP_POST_BUY_SECONDS)

    local tool = findToolByName("Crowbar")

    if tool then
        equipTool(tool)
    end

    return invokeOk
        and (accepted == true or message == "PURCHASE COMPLETE" or tool ~= nil)
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

    local illegalOk, illegalAccepted, illegalMessage = pcall(
        purchaseRemote.InvokeServer,
        purchaseRemote,
        "IllegalStore",
        "Misc",
        "Lockpick",
        shopPart,
        nil,
        true,
        nil
    )

    waitSeconds(0.25)

    local legalOk, legalAccepted, legalMessage = pcall(
        purchaseRemote.InvokeServer,
        purchaseRemote,
        "LegalStore",
        "Misc",
        "Lockpick",
        shopPart,
        nil,
        true
    )

    return illegalOk
        and (illegalAccepted == true or illegalMessage == "PURCHASE COMPLETE")
        or legalOk
        and (legalAccepted == true or legalMessage == "PURCHASE COMPLETE")
end

local function buyLockpickBatch(quantity)
    quantity = math.max(1, math.floor(tonumber(quantity) or 7))

    local shopPart = findNearestLockpickShopPart()

    if not shopPart then
        return false
    end

    if not tweenRootTo(
        shopPart.Position,
        shopPart.CFrame + Vector3.new(0, 3, 0)
    ) then
        return false
    end

    local startingCount = countToolsByName("Lockpick")
    local successfulPurchases = 0

    for _ = 1, quantity do
        if not farmEnabled then
            break
        end

        if purchaseLockpickAt(shopPart) then
            successfulPurchases = successfulPurchases + 1
        end

        waitSeconds(0.20)
    end

    waitSeconds(0.75)
    return countToolsByName("Lockpick") > startingCount or successfulPurchases > 0
end

local function dropLockpick(tool)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local dropRemote = events and events:FindFirstChild("PAZ_TA")
    local root = getRootPart()

    if not tool or not dropRemote or not root then
        return false
    end

    return pcall(
        dropRemote.FireServer,
        dropRemote,
        tool,
        nil,
        root.Position
    )
end

local function tryLockpickTarget(target)
    local tool = findToolByName("Lockpick")

    if not tool then
        return false, "lockpick_missing"
    end

    if not equipTool(tool) then
        return false, "lockpick_equip_failed"
    end

    local remote = tool:FindFirstChild("Remote")

    if not remote or not remote:IsA("RemoteFunction") then
        return false, "lockpick_remote_missing"
    end

    local startOk, token = pcall(
        remote.InvokeServer,
        remote,
        "S",
        target,
        "s"
    )

    if startOk and type(token) == "number" then
        waitSeconds(0.25)

        local finishOk = pcall(
            remote.InvokeServer,
            remote,
            "D",
            target,
            "s",
            token
        )

        return finishOk, finishOk and "lockpick_success" or "lockpick_finish_failed"
    end

    dropLockpick(tool)
    return false, "lockpick_failed"
end

local function strikeTargetWithCrowbar(target)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local startFolder = events and events:FindFirstChild("XMHH")
    local finishFolder = events and events:FindFirstChild("XMHH2")
    local startRemote = startFolder and startFolder:FindFirstChild("2")
    local finishRemote = finishFolder and finishFolder:FindFirstChild("2")
    local tool = findToolByName("Crowbar")
    local character = getCharacter()
    local targetPart = getTargetPart(target)
    local rightArm = character and (
        character:FindFirstChild("Right Arm")
        or character:FindFirstChild("RightHand")
    )

    if not startRemote
        or not finishRemote
        or not tool
        or not character
        or not rightArm
        or not targetPart
    then
        return false
    end

    equipTool(tool)

    local invokeOk, token = pcall(
        startRemote.InvokeServer,
        startRemote,
        "🍞",
        now(),
        tool,
        "DZDRRRKI",
        target,
        "Register"
    )

    if invokeOk and type(token) == "number" then
        return pcall(
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

    return invokeOk
end

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

            strikeTargetWithCrowbar(target)
            waitSeconds(0.25)
        end
    else
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

            local opened = tryLockpickTarget(target)

            if opened then
                local completedAt = now()

                while target.Parent
                    and not targetIsBroken(target)
                    and now() - completedAt < 12
                do
                    waitSeconds(0.10)
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

    return false, "break_timeout"
end

local function clearNearbyCashNoMove(radius)
    radius = tonumber(radius) or 15

    local root = getRootPart()
    local spawnedBread = findMoneyContainer()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local collectRemote = events and events:FindFirstChild("CZDPZUS")

    if not root or not spawnedBread or not collectRemote then
        return 0
    end

    local collected = 0

    for _, cashDrop in ipairs(spawnedBread:GetChildren()) do
        local part

        if cashDrop:IsA("BasePart") then
            part = cashDrop
        elseif cashDrop:IsA("Model") then
            part = cashDrop:FindFirstChild("MainPart")
                or cashDrop.PrimaryPart
                or cashDrop:FindFirstChildWhichIsA("BasePart", true)
        end

        if part and (part.Position - root.Position).Magnitude <= radius then
            local ok = pcall(collectRemote.FireServer, collectRemote, cashDrop)

            if ok then
                collected = collected + 1
            end
        end
    end

    return collected
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

    clearNearbyCashNoMove(15)

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

local startFarm, stopFarm


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
                    farmActivityStatus = "Administrator detected: " .. player.Name
                    sendNotification(
                        "JX",
                        "Administrator detected: " .. player.Name,
                        5
                    )
                    return
                end
            end
        end

        waitSeconds(2)
    end
end

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

local function performAutoPlayRemoteSequence()
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then
        return false
    end

    local playRemote = events:FindFirstChild("BRBRBRRBLOOOL2")
    local updateRemote = events:FindFirstChild("UpdateClient")
    local invoked = false

    if playRemote and playRemote:IsA("RemoteFunction") then
        local ok = pcall(
            playRemote.InvokeServer,
            playRemote,
            "",
            "\15daz\18tough\19"
        )
        invoked = ok
    end

    if updateRemote and updateRemote:IsA("RemoteEvent") then
        pcall(updateRemote.FireServer, updateRemote)
    end

    return invoked
end

local function autoPlayWorker()
    if autoPlayWorkerBusy then
        return
    end

    autoPlayWorkerBusy = true
    local startedAt = now()

    while autoPlayEnabled do
        pcall(performAutoPlayRemoteSequence)

        if autoPlayLoadTimeDetected then
            autoPlayLoadTimeReadyAt =
                autoPlayLoadTimeReadyAt
                or now() + 5

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
        print("LOAD TIME detected from console history. Auto Play starts in 5s.")
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


stopFarm = function(reason)
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

startFarm = function()
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
        breakingMethod = tostring(
            value or "Crowbar"
        )
    elseif name == "JXFarmWebhookURL" then
        webhookUrl = tostring(value or "")
    else
        return false
    end

    return true
end


local function createUiElement(className, properties, parent)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    instance.Parent = parent
    return instance
end

local function makeToggle(parent, text, flag, default)
    local value = default == true
    local button = createUiElement("TextButton", {
        Name = flag,
        Size = UDim2.new(1, -12, 0, 32),
        BackgroundColor3 = Color3.fromRGB(35, 35, 42),
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        AutoButtonColor = false,
    }, parent)

    local function render()
        button.Text = text .. ": " .. (value and "ON" or "OFF")
        button.BackgroundColor3 = value
            and Color3.fromRGB(45, 105, 70)
            or Color3.fromRGB(35, 35, 42)
    end

    button.MouseButton1Click:Connect(function()
        value = not value
        setFlag(flag, value)
        render()
    end)

    render()
    setFlag(flag, value)
    return button
end

local function makeTextbox(parent, text, flag, default, numeric)
    local holder = createUiElement("Frame", {
        Size = UDim2.new(1, -12, 0, 48),
        BackgroundColor3 = Color3.fromRGB(35, 35, 42),
        BorderSizePixel = 0,
    }, parent)

    createUiElement("TextLabel", {
        Size = UDim2.new(0.48, -6, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text,
    }, holder)

    local box = createUiElement("TextBox", {
        Position = UDim2.new(0.48, 0, 0, 7),
        Size = UDim2.new(0.52, -8, 1, -14),
        BackgroundColor3 = Color3.fromRGB(24, 24, 30),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Code,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        Text = tostring(default or ""),
    }, holder)

    local function commit()
        local value = box.Text
        if numeric then
            value = tonumber(value)
            if value == nil then
                box.Text = tostring(default or 0)
                return
            end
        end
        setFlag(flag, value)
    end

    box.FocusLost:Connect(commit)
    commit()
    return holder
end

local function makeDropdown(parent, text, flag, values, default)
    local index = 1

    for candidateIndex, value in ipairs(values) do
        if value == default then
            index = candidateIndex
            break
        end
    end

    local button = createUiElement("TextButton", {
        Name = flag,
        Size = UDim2.new(1, -12, 0, 32),
        BackgroundColor3 = Color3.fromRGB(35, 35, 42),
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        AutoButtonColor = false,
    }, parent)

    local function render()
        button.Text = text .. ": " .. tostring(values[index])
    end

    button.MouseButton1Click:Connect(function()
        index = index % #values + 1
        setFlag(flag, values[index])
        render()
    end)

    render()
    setFlag(flag, values[index])
    return button
end

local function makeAction(parent, text, callback)
    local button = createUiElement("TextButton", {
        Size = UDim2.new(1, -12, 0, 32),
        BackgroundColor3 = Color3.fromRGB(55, 65, 95),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = text,
        AutoButtonColor = true,
    }, parent)

    button.MouseButton1Click:Connect(function()
        spawnTask(function()
            pcall(callback)
        end)
    end)

    return button
end

local function createReadableUI()
    local old = UiParent:FindFirstChild("JXCriminalityFarm")
    if old then
        old:Destroy()
    end

    local screen = createUiElement("ScreenGui", {
        Name = "JXCriminalityFarm",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, UiParent)

    local main = createUiElement("Frame", {
        Name = "Main",
        Position = UDim2.new(0, 30, 0.5, -260),
        Size = UDim2.new(0, 360, 0, 520),
        BackgroundColor3 = Color3.fromRGB(18, 18, 23),
        BorderSizePixel = 0,
        Active = true,
        Draggable = true,
    }, screen)

    createUiElement("UICorner", {
        CornerRadius = UDim.new(0, 8),
    }, main)

    local title = createUiElement("TextLabel", {
        Size = UDim2.new(1, -44, 0, 38),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "  " .. WINDOW_NAME,
    }, main)

    local close = createUiElement("TextButton", {
        Position = UDim2.new(1, -38, 0, 4),
        Size = UDim2.new(0, 32, 0, 30),
        BackgroundColor3 = Color3.fromRGB(100, 40, 45),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Text = "X",
    }, main)

    close.MouseButton1Click:Connect(function()
        screen.Enabled = false
    end)

    local scrolling = createUiElement("ScrollingFrame", {
        Position = UDim2.new(0, 6, 0, 42),
        Size = UDim2.new(1, -12, 1, -48),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, main)

    createUiElement("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scrolling)

    makeToggle(scrolling, "Start Farm", "JXFarmEnabled", false)
    makeToggle(scrolling, "Auto Respawn", "JXFarmAutoRespawn", autoRespawn)
    makeToggle(scrolling, "Auto Pickup Money", "JXFarmAutoMoney", autoMoney)
    makeToggle(scrolling, "Auto Deposit", "JXFarmAutoDeposit", autoDepositEnabled)
    makeTextbox(scrolling, "Deposit At (thousands)", "JXFarmAutoDepositThresholdK", depositThreshold / 1000, true)
    makeAction(scrolling, "Deposit Now", tryDepositAllNow)
    makeToggle(scrolling, "Auto Claim Allowance", "JXFarmAutoAllowance", autoAllowance)
    makeDropdown(scrolling, "Breaking Method", "JXFarmBreakingMethod", { "Crowbar", "Fist + Lockpick" }, breakingMethod)
    makeTextbox(scrolling, "Move Speed", "JXFarmSpeedV2", moveSpeed, true)
    makeToggle(scrolling, "Hide Body", "JXFarmInvis", userWantsInvis)
    makeToggle(scrolling, "Anti Fall Damage", "CharacterAntiFallDamage", noFallEnabled)
    makeToggle(scrolling, "Anti-AFK", "JXFarmAntiAfk", antiAfkEnabled)
    makeToggle(scrolling, "Anti Error/kick", "JXFarmAntiRejoin", antiRejoin)
    makeToggle(scrolling, "Admin Check", "JXFarmAdminCheck", adminCheckEnabled)
    makeToggle(scrolling, "Auto Play", "JXFarmAutoPlay", autoPlayEnabled)
    makeToggle(scrolling, "Auto Notify", "JXFarmAutoNotify", autoNotify)
    makeTextbox(scrolling, "Notify Time (minutes)", "JXFarmNotifyTimeMinutes", notifyMinutes, true)
    makeTextbox(scrolling, "Webhook URL", "JXFarmWebhookURL", webhookUrl, false)
    makeAction(scrolling, "Save State", saveRuntimeState)
    makeAction(scrolling, "Show Body", invisDisable)
    return main
end

local function bootstrap()
    ensureDirectories()
    loadRuntimeState()
    setAntiAfk(antiAfkEnabled)

    local publicConfig = fetchPublicConfig()

    if type(publicConfig) == "table" then
        expirationHours =
            publicConfig.expirationHours
            or expirationHours

        if publicConfig.keyless ~= nil then
            keyless = publicConfig.keyless == true
        end

        rebuildAdminRules(publicConfig)
    end

    deferTask(detectLoadTimeAndAutoStart)

    deferTask(function()
        local ok, err = pcall(createReadableUI)

        if not ok then
            warn(
                "[JX Farm] UI reconstruction failed:",
                err
            )
        end
    end)

    print("JX-CRIMINALITY-FARM FULLY LOADED")
    return true
end

local bootstrapOk, bootstrapError = bootstrap()

if not bootstrapOk then
    warn(
        "[JX Farm] bootstrap failed:",
        bootstrapError
    )
end
