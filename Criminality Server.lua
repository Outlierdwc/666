local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Environment = getgenv and getgenv() or _G

Config = {
    apiBase = "https://getjx.onrender.com",
    service = "JX",
    prefix = "JX_",
    expirationHours = nil,
    keyless = false,
}

local Paths = {
    root = "RBX",
    device = "RBX/device.json",
    payloadRoot = "JX-CRIMINALITY-SERVER",
    payloadConfigs = "JX-CRIMINALITY-SERVER/Configs",
    payloadAssets = "JX-CRIMINALITY-SERVER/Assets",
}

local Urls = {
    library = "https://raw.githubusercontent.com/jianlobiano/Serotonin-Library-Modified/refs/heads/main/Library.lua",
    discord = "https://discord.gg/getjxs",
    token = "https://jx3e.onrender.com/auth/token",
    refresh = "https://jx3e.onrender.com/auth/refresh",
    webhook = "https://jx3e.onrender.com/webhook/discord",
    country = "http://ip-api.com/json",
}

local TelemetryApiKey = "sk_live_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p1"
local RejoinPlaceId = 4588604953

local Request = request
    or http_request
    or (syn and syn.request)
    or (http and http.request)

local SetClipboard = setclipboard
    or toclipboard
    or (syn and syn.set_clipboard)

local WriteFile = writefile
    or (syn and syn.write_file)

local ReadFile = readfile
    or (syn and syn.read_file)

local IsFile = isfile
    or (syn and syn.isfile)

local IsFolder = isfolder
    or (syn and syn.isfolder)

local MakeFolder = makefolder
    or (syn and syn.makefolder)

local function asBoolean(value)
    return value == true
end

local function safeCall(callback, ...)
    local arguments = table.pack(...)
    return pcall(function()
        return callback(table.unpack(arguments, 1, arguments.n))
    end)
end

local function notify(message, color)
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = message,
            Color = color or Color3.fromRGB(255, 255, 255),
        })
    end)
end

local function kick(message)
    pcall(function()
        LocalPlayer:Kick(message or "Dont Bypass It Please :C")
    end)
end

local function isLuaClosure(callback)
    if not callback then
        return false
    end

    if debug and debug.info then
        local ok, source = pcall(debug.info, callback, "s")
        if ok then
            return source ~= "[C]"
        end
    end

    if islclosure then
        local ok, result = pcall(islclosure, callback)
        return ok and result or false
    end

    return false
end

local function monitorRequestIntegrity()
    local originalGlobalRequest = request
    local originalResolvedRequest = Request
    local originalLooksLua = isLuaClosure(originalResolvedRequest)

    if not originalResolvedRequest then
        return
    end

    task.spawn(function()
        while task.wait(0.5) do
            local currentEnvironment = getgenv and getgenv() or Environment
            local currentResolvedRequest = currentEnvironment.request or originalResolvedRequest
            local currentGlobalRequest = request
            local valid = currentResolvedRequest ~= nil

            if currentResolvedRequest ~= originalResolvedRequest then
                valid = false
            end

            if currentGlobalRequest
                and currentGlobalRequest ~= originalGlobalRequest
                and currentGlobalRequest ~= originalResolvedRequest
            then
                valid = false
            end

            if not originalLooksLua and isLuaClosure(currentResolvedRequest) then
                valid = false
            end

            if not valid then
                kick("Dont Bypass It Please :C")
                return
            end
        end
    end)
end

local function ensureFolder(path)
    if not MakeFolder then
        return false
    end

    if IsFolder then
        local ok, exists = pcall(IsFolder, path)
        if ok and exists then
            return true
        end
    end

    return pcall(MakeFolder, path)
end

local function readDeviceFile()
    if not ReadFile or not IsFile then
        return nil
    end

    local existsOk, exists = pcall(IsFile, Paths.device)
    if not existsOk or not exists then
        return nil
    end

    local readOk, contents = pcall(ReadFile, Paths.device)
    if not readOk or type(contents) ~= "string" then
        return nil
    end

    local decodeOk, device = pcall(HttpService.JSONDecode, HttpService, contents)
    if not decodeOk or type(device) ~= "table" then
        return nil
    end

    return device
end

local function writeDeviceFile(device)
    if not WriteFile then
        return false
    end

    ensureFolder(Paths.root)

    local encodeOk, contents = pcall(HttpService.JSONEncode, HttpService, device)
    if not encodeOk then
        return false
    end

    return pcall(WriteFile, Paths.device, contents)
end

local function generateHwid()
    return HttpService:GenerateGUID(false):gsub("-", "") .. tostring(math.random(1000, 9999))
end

local function getOrCreateDevice()
    local device = readDeviceFile()
    if device and device.hwid then
        return device
    end

    device = {
        hwid = generateHwid(),
        createdAt = os.time(),
    }

    writeDeviceFile(device)
    return device
end

local function postJson(path, body)
    if not Request then
        return nil, "executor_request_missing"
    end

    local requestOk, response = pcall(Request, {
        Url = Config.apiBase .. path,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
        },
        Body = HttpService:JSONEncode(body or {}),
    })

    if not requestOk or not response then
        return nil, "no_response"
    end

    local decodeOk, decoded = pcall(
        HttpService.JSONDecode,
        HttpService,
        response.Body or "{}"
    )

    if not decodeOk then
        return nil, "bad_json"
    end

    return decoded, nil
end

local function requestKey(hwid)
    return postJson("/api/jx/keys/request", {
        hwid = hwid,
    })
end

local function verifyKey(hwid, key)
    local requestId = HttpService:GenerateGUID(false)
    local response, requestError = postJson("/api/jx/keys/verify", {
        hwid = hwid,
        key = key,
        reqId = requestId,
    })

    if response and response.resId ~= requestId .. "_jx_valid_response" then
        return nil, "spoof_detected"
    end

    return response, requestError
end

local function fetchPublicConfig()
    if not Request then
        return
    end

    local requestOk, response = pcall(Request, {
        Url = Config.apiBase .. "/api/jx/public/config",
        Method = "GET",
        Headers = {
            ["Content-Type"] = "application/json",
        },
    })

    if not requestOk or not response or not response.Body then
        return
    end

    local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not decodeOk or type(decoded) ~= "table" or not decoded.ok then
        return
    end

    local settings = decoded.settings
    if type(settings) ~= "table" then
        return
    end

    Config.prefix = settings.prefix or Config.prefix
    Config.expirationHours = settings.expirationHours
    Config.keyless = settings.keyless or false
end

local function verifyKeySafely(hwid, key)
    if not Request then
        return nil, "executor_request_missing"
    end

    if type(verifyKey) ~= "function" then
        return nil, "verify_fn_missing"
    end

    local ok, result, requestError = pcall(verifyKey, hwid, key)
    if not ok then
        return nil, "verify_fn_error"
    end

    return result, requestError
end

local function configureLphAliases()
    local mvCff = Environment.MV_CFF
    local mvEncFunc = Environment.MV_ENC_FUNC
    local identity = function(value)
        return value
    end

    Environment.LPH_JIT = MV_VM and function(callback)
        return MV_VM(callback)
    end or identity

    Environment.LPH_JIT_MAX = MV_VM and function(callback)
        return MV_VM(callback)
    end or identity

    Environment.LPH_NO_VIRTUALIZE = identity
    Environment.LPH_NO_UPVALUES = identity

    Environment.LPH_ENCSTR = MV_ENC_STR and function(value)
        return MV_ENC_STR(value)
    end or identity

    Environment.LPH_ENCNUM = identity
end

local function isMenuAvailable()
    local player = Players.LocalPlayer
    if not player then
        return false
    end

    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local hasMenuGui = playerGui and playerGui:FindFirstChild("MenuGUI") ~= nil
    local events = ReplicatedStorage:FindFirstChild("Events")
    local hasServerEvents = events
        and events:FindFirstChild("Play") ~= nil
        and events:FindFirstChild("Update") ~= nil

    return hasMenuGui or hasServerEvents or false
end

local function activateButton(button)
    if not button or not button:IsA("GuiButton") or button.Visible == false then
        return false
    end

    return pcall(function()
        button:Activate()
    end)
end

local function activatePlayButton()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return false
    end

    local firstButton
    pcall(function()
        firstButton = playerGui
            :FindFirstChild("MenuGUI")
            :FindFirstChild("Holder")
            :FindFirstChild("MainFrame")
            :FindFirstChild("PictureFrame")
            :FindFirstChild("StatsFrame")
            :FindFirstChild("ButtonFrame")
            :FindFirstChild("PlayButton")
    end)

    if activateButton(firstButton) then
        return true
    end

    local secondButton
    pcall(function()
        local menu = playerGui:FindFirstChild("MenuGUI")
        local root = menu and (menu:FindFirstChild("Frame") or menu:FindFirstChild("Holder") or menu)
        local buttons = root and root:FindFirstChild("ButtonsFrame", true)
        local playFrame = buttons and buttons:FindFirstChild("PlayFrame", true)
        secondButton = playFrame and playFrame:FindFirstChild("TextButton", true)
    end)

    return activateButton(secondButton)
end

local function waitForChild(parent, name, timeout)
    timeout = timeout or 10
    local startedAt = tick()

    while tick() - startedAt < timeout do
        local child = parent:FindFirstChild(name)
        if child then
            return child
        end
        task.wait(0.1)
    end

    return nil
end

local function isGameMenuGui(gui)
    if not gui or not gui:IsA("ScreenGui") then
        return false
    end

    local holder = gui:FindFirstChild("Holder", true)
    local mainFrame = gui:FindFirstChild("MainFrame", true)
    local playButton = gui:FindFirstChild("PlayButton", true)

    if holder and mainFrame and playButton and playButton:IsA("GuiButton") then
        return true
    end

    local buttonsFrame = gui:FindFirstChild("ButtonsFrame", true)
    local playFrame = gui:FindFirstChild("PlayFrame", true)
    local textButton = gui:FindFirstChild("TextButton", true)

    return buttonsFrame ~= nil
        and playFrame ~= nil
        and textButton ~= nil
        and textButton:IsA("GuiButton")
end

local function removeMenuObjects()
    local function removeMenuScene(container)
        if not container then
            return
        end

        for _, child in ipairs(container:GetChildren()) do
            if child.Name == "MenuScene" then
                Debris:AddItem(child, 0)
            end
        end
    end

    removeMenuScene(workspace)
    removeMenuScene(workspace:FindFirstChild("Filter"))

    for _, object in ipairs(workspace:GetDescendants()) do
        if object.Name == "MenuScene" then
            Debris:AddItem(object, 0)
        elseif object:IsA("PointLight")
            or object:IsA("SpotLight")
            or object:IsA("SurfaceLight")
        then
            local parent = object.Parent
            local belongsToMenu = parent
                and (parent.Name == "MenuScene"
                    or (parent.Parent and parent.Parent.Name == "MenuScene"))

            if belongsToMenu then
                object.Enabled = false
                Debris:AddItem(object, 0)
            end
        end
    end
end

local function restoreLighting()
    local defaultConfig = Lighting:FindFirstChild("DefaultLightingConfig")

    if defaultConfig then
        for _, valueObject in ipairs(defaultConfig:GetChildren()) do
            if valueObject:IsA("BoolValue")
                or valueObject:IsA("NumberValue")
                or valueObject:IsA("IntValue")
                or valueObject:IsA("StringValue")
                or valueObject:IsA("Color3Value")
            then
                pcall(function()
                    Lighting[valueObject.Name] = valueObject.Value
                end)
            end
        end
    end

    for _, child in ipairs(Lighting:GetChildren()) do
        local isPostEffect = child:GetAttribute("PostFX") == true
            or child:IsA("BloomEffect")
            or child:IsA("BlurEffect")
            or child:IsA("DepthOfFieldEffect")
            or child:IsA("SunRaysEffect")
            or child:IsA("ColorCorrectionEffect")

        if isPostEffect then
            pcall(function()
                child.Enabled = false
            end)
            pcall(function()
                child:Destroy()
            end)
        end
    end

    Lighting.Brightness = tonumber(Lighting.Brightness) or 2
    if Lighting.Brightness > 3 then
        Lighting.Brightness = 2
    end

    Lighting.ExposureCompensation = 0

    local ambientAverage = (Lighting.Ambient.R + Lighting.Ambient.G + Lighting.Ambient.B) / 3
    local outdoorAverage = (
        Lighting.OutdoorAmbient.R
        + Lighting.OutdoorAmbient.G
        + Lighting.OutdoorAmbient.B
    ) / 3

    if Lighting.Brightness > 0.5 and ambientAverage <= 0.08 and outdoorAverage <= 0.08 then
        Lighting.Brightness = math.max(Lighting.Brightness, 2)
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(90, 90, 90)

        if typeof(Lighting.ClockTime) ~= "number" then
            Lighting.ClockTime = 14
        end

        if Lighting.ClockTime < 6 or Lighting.ClockTime > 19 then
            Lighting.ClockTime = 14
        end

        Lighting.GlobalShadows = true
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
    end
end

local function setupGameEnvironment()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remoteFunction = events and events:FindFirstChild("BRBRBRRBLOOOL2")
    local updateClient = events and events:FindFirstChild("UpdateClient")

    if remoteFunction and remoteFunction:IsA("RemoteFunction") then
        pcall(function()
            remoteFunction:InvokeServer("", "\15daz\18tough\19")
        end)
    end

    if updateClient and updateClient:IsA("RemoteEvent") then
        pcall(function()
            updateClient:FireServer()
        end)
    end

    pcall(function()
        RunService:UnbindFromRenderStep("MenuCam")
    end)

    pcall(function()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
            return
        end

        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name == "MenuGUI" or isGameMenuGui(gui)) then
                gui.Enabled = false
            end
        end
    end)

    local camera = workspace.CurrentCamera
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
        or character:WaitForChild("Humanoid", 5)

    if camera and humanoid then
        pcall(function()
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid
        end)
    end

    pcall(removeMenuObjects)
    pcall(restoreLighting)

    return camera ~= nil and humanoid ~= nil
end

local function normalizeServerList(value)
    if type(value) ~= "table" then
        return {}
    end

    if #value > 0 then
        return value
    end

    local result = {}
    for _, server in pairs(value) do
        if type(server) == "table" then
            table.insert(result, server)
        end
    end

    return result
end

local function normalizeRegion(value)
    local upper = tostring(value or ""):upper()
    return upper:match("([A-Z][A-Z])") or upper
end

local function getServerId(server)
    return server.serverId
        or server.jobId
        or server.jobID
        or server.id
        or server.ServerId
        or server.ServerID
end

local function getPlayerCount(server)
    return tonumber(server.players or server.playerCount or server.Players) or 0
end

local function isTruthy(value)
    return value == true or value == 1 or value == "1"
end

local function runProtected(name, callback)
    local ok, message = xpcall(callback, debug.traceback)
    if not ok then
        warn(string.format("[JX:%s] %s", tostring(name), tostring(message)))
    end
end

local function loadMainPayload()
    configureLphAliases()

    local Library = loadstring(game:HttpGet(Urls.library))()

    Library.Folders = {
        Directory = Paths.payloadRoot,
        Configs = Paths.payloadConfigs,
        Assets = Paths.payloadAssets,
    }

    for _, path in pairs(Library.Folders) do
        ensureFolder(path)
    end

    local Window = Library:Window({
        Name = "JX-CRIMINALITY-SERVER | Dsc.gg/getjxs",
        Logo = "85279746515974",
        MobileButtonText = "JX",
    })

    local Watermark = Library:Watermark("JX-CRIMINALITY-SERVER")
    local KeybindList = Library:KeybindList()
    local TargetHud = Library:TargetHud()
    TargetHud:SetPlayer(LocalPlayer)

    local targetBar = TargetHud:AddBar(Color3.fromRGB(255, 0, 0))
    task.spawn(function()
        while task.wait(1.5) do
            targetBar:SetPercentage(math.random(1, 100))
        end
    end)

    local ServerPage = Window:Page({
        Name = "Server",
        Columns = 2,
    })

    Library:CreateSettingsPage(Window, KeybindList, Watermark)

    local GameModeSection = ServerPage:Section({
        Name = "Game Mode",
        Side = 1,
    })

    local RegionSection = ServerPage:Section({
        Name = "Region",
        Side = 2,
    })

    local ActionSection = ServerPage:Section({
        Name = "Action",
        Side = 1,
    })

    local FreezeSection = ServerPage:Section({
        Name = "Freeze",
        Side = 2,
    })

    task.spawn(function()
        runProtected("Setup", setupGameEnvironment)
    end)

    local RemoteInit
    local EventsPlay

    task.spawn(function()
        runProtected("RemoteInit", function()
            while task.wait(0.25) do
                if isMenuAvailable() and (not RemoteInit or not EventsPlay) then
                    RemoteInit = RemoteInit or waitForChild(ReplicatedStorage, "RemoteInit", 2)
                    local events = waitForChild(ReplicatedStorage, "Events", 2)
                    EventsPlay = EventsPlay or (events and waitForChild(events, "Play", 2))
                end
            end
        end)
    end)

    local State = {
        enabledRegions = {
            SG = true,
            US = true,
            AU = true,
            JP = true,
        },
        selectedGameModeName = "Casual",
        selectedGameMode = "Casual",
        joinHighestPlayers = true,
        freezeSeconds = 10,
        manualFreezeUntil = 0,
        autoConnect = false,
        autoPlay = false,
        autoRejoin = true,
        autoRejoinSeconds = 40,
        lastServerActionAt = 0,
        heartbeatDelta = 0,
        detectedFreezeUntil = 0,
    }

    RunService.Heartbeat:Connect(function(deltaTime)
        State.heartbeatDelta = tonumber(deltaTime) or 0
        if State.heartbeatDelta >= 1.5 then
            State.detectedFreezeUntil = os.clock() + 1
        end
    end)

    local GameModeMap = {
        Casual = "Casual",
        Standard = "Standard",
        ["Mobile Casual"] = "M-Casual",
    }

    local function isManualFreezeActive()
        return tick() < (State.manualFreezeUntil or 0)
    end

    local function isDetectedFreezeActive()
        return os.clock() < (State.detectedFreezeUntil or 0)
    end

    local function canRunServerAction()
        local now = tick()
        if now - State.lastServerActionAt < 2.5 then
            return false
        end
        State.lastServerActionAt = now
        return true
    end

    local function fetchServerList()
        if not isMenuAvailable() or not RemoteInit then
            return nil
        end

        local ok, servers = pcall(function()
            return RemoteInit:InvokeServer()
        end)

        if not ok or type(servers) ~= "table" then
            return nil
        end

        return servers
    end

    local function selectServer()
        local servers = normalizeServerList(fetchServerList())
        local candidates = {}

        for _, server in ipairs(servers) do
            local region = normalizeRegion(server.region)
            local regionEnabled = State.enabledRegions[region] == true
            local gameModeMatches = server.gameMode == nil
                or server.gameMode == State.selectedGameMode
            local serverId = getServerId(server)

            if serverId
                and regionEnabled
                and gameModeMatches
                and not isTruthy(server.locked)
                and not isTruthy(server.prime)
            then
                table.insert(candidates, {
                    serverId = tostring(serverId),
                    players = getPlayerCount(server),
                    region = region,
                })
            end
        end

        if #candidates == 0 then
            return nil
        end

        table.sort(candidates, function(left, right)
            if State.joinHighestPlayers then
                return left.players > right.players
            end
            return left.players < right.players
        end)

        return candidates[1]
    end

    local function invokePlay(action, serverId)
        if not isMenuAvailable() then
            return false, "Not in menu"
        end

        if not EventsPlay then
            return false, "Events.Play not found"
        end

        local ok, accepted, reason = pcall(function()
            return EventsPlay:InvokeServer(
                action,
                State.selectedGameMode,
                serverId,
                2
            )
        end)

        if not ok then
            return false, tostring(accepted)
        end

        if accepted == false then
            return false, tostring(reason or "Server refused connection")
        end

        return true
    end

    local function connectBestServer()
        if isManualFreezeActive() or not canRunServerAction() then
            return
        end

        local server = selectServer()
        if server then
            return invokePlay("connect", server.serverId)
        end
    end

    local function playRandomServer()
        if isManualFreezeActive() or not canRunServerAction() then
            return
        end

        return invokePlay("play", nil)
    end

    local function setAutoPlay(enabled)
        State.autoPlay = asBoolean(enabled)
        if State.autoPlay then
            State.autoConnect = false
        end
    end

    local function setAutoConnect(enabled)
        State.autoConnect = asBoolean(enabled)
        if State.autoConnect then
            State.autoPlay = false
        end
    end

    GameModeSection:Dropdown({
        Name = "Gamemode",
        Flag = "ServerGamemode",
        Default = "Casual",
        Items = {
            "Casual",
            "Standard",
            "Mobile Casual",
        },
        MaxSize = 100,
        Callback = function(value)
            State.selectedGameModeName = value
            State.selectedGameMode = GameModeMap[value] or "Casual"
        end,
    })

    GameModeSection:Toggle({
        Name = "Join Highest Player Posible",
        Flag = "JoinHighestPlayers",
        Default = true,
        Callback = function(value)
            State.joinHighestPlayers = asBoolean(value)
        end,
    })

    local regionDefaults = {
        SG = true,
        NL = false,
        DE = false,
        FR = false,
        BR = false,
        US = true,
        AU = true,
        JP = true,
        HK = false,
    }

    for _, region in ipairs({ "SG", "NL", "DE", "FR", "BR", "US", "AU", "JP", "HK" }) do
        RegionSection:Toggle({
            Name = region,
            Flag = "Region_" .. region,
            Default = regionDefaults[region],
            Callback = function(value)
                State.enabledRegions[region] = asBoolean(value)
            end,
        })
    end

    ActionSection:Toggle({
        Name = "Auto Connect Selected Server",
        Flag = "AutoConnectSelectedServer",
        Default = false,
        Callback = setAutoConnect,
    })

    ActionSection:Toggle({
        Name = "Auto Play Random Server",
        Flag = "AutoPlayRandomServer",
        Default = false,
        Callback = setAutoPlay,
    })

    ActionSection:Toggle({
        Name = "Auto Rejoin If Stuck",
        Flag = "AutoRejoinIfStuck",
        Default = true,
        Callback = function(value)
            State.autoRejoin = asBoolean(value)
        end,
    })

    ActionSection:Slider({
        Name = "Time",
        Flag = "AutoRejoinIfStuckTimeSeconds",
        Min = 1,
        Default = 40,
        Max = 59,
        Suffix = "s",
        Decimals = 1,
        Increment = 1,
        Callback = function(value)
            State.autoRejoinSeconds = math.clamp(
                math.floor((tonumber(value) or 40) + 0.5),
                1,
                59
            )
        end,
    })

    FreezeSection:Slider({
        Name = "Freeze Time",
        Flag = "FreezeTimeSeconds",
        Min = 1,
        Default = 10,
        Max = 59,
        Suffix = "s",
        Decimals = 1,
        Callback = function(value)
            State.freezeSeconds = math.clamp(
                math.floor((tonumber(value) or 10) + 0.5),
                1,
                59
            )
        end,
    })

    FreezeSection:Button({
        Name = "Start The Timer",
        Callback = function()
            local duration = math.clamp(tonumber(State.freezeSeconds) or 10, 1, 59)
            State.manualFreezeUntil = tick() + duration
            Library:Notification(
                "Freeze started for " .. tostring(duration) .. "s (joining paused)",
                2
            )

            task.spawn(function()
                local previousRemaining = -1
                while tick() < State.manualFreezeUntil do
                    local remaining = math.max(0, math.ceil(State.manualFreezeUntil - tick()))
                    if remaining ~= previousRemaining
                        and (remaining <= 5 or remaining % 5 == 0)
                    then
                        previousRemaining = remaining
                        Library:Notification("Freeze: " .. tostring(remaining) .. "s left", 1)
                    end
                    task.wait(0.25)
                end
                Library:Notification("Freeze ended", 2)
            end)
        end,
    })

    task.spawn(function()
        runProtected("AutoLoop", function()
            while task.wait(1) do
                if isMenuAvailable() then
                    if State.autoConnect and not isManualFreezeActive() then
                        connectBestServer()
                    elseif State.autoPlay and not isManualFreezeActive() then
                        playRandomServer()
                    end
                end
            end
        end)
    end)

    task.spawn(function()
        runProtected("AutoRejoinIfStuckLoop", function()
            local elapsed = 0
            local lastClock = os.clock()
            local lastTeleportAt = 0
            local lastShownSecond = -1
            local wasPaused = false

            while task.wait(0.2) do
                if not State.autoRejoin then
                    elapsed = 0
                    lastClock = os.clock()
                    lastShownSecond = -1
                    wasPaused = false
                else
                    local manualFreeze = isManualFreezeActive()
                    local detectedFreeze = isDetectedFreezeActive()

                    if manualFreeze or detectedFreeze then
                        if not wasPaused then
                            wasPaused = true
                            Library:Notification(
                                manualFreeze
                                    and "Auto Rejoin timer paused (Freeze active)"
                                    or "Auto Rejoin timer paused (freeze detected)",
                                2
                            )
                        end

                        elapsed = 0
                        lastClock = os.clock()
                        lastShownSecond = -1
                    else
                        if wasPaused then
                            wasPaused = false
                            Library:Notification(
                                "Freeze ended (Auto Rejoin timer restarted)",
                                2
                            )
                        end

                        local now = os.clock()
                        local deltaTime = math.max(0, now - lastClock)
                        lastClock = now
                        elapsed = elapsed + deltaTime

                        local timeout = math.clamp(
                            math.floor((tonumber(State.autoRejoinSeconds) or 40) + 0.5),
                            1,
                            59
                        )

                        local remaining = math.max(0, math.ceil(timeout - elapsed))
                        if remaining ~= lastShownSecond
                            and (remaining <= 5 or remaining % 5 == 0)
                        then
                            lastShownSecond = remaining
                            Library:Notification("Auto Rejoin in " .. tostring(remaining) .. "s", 1)
                        end

                        if elapsed >= timeout and now - lastTeleportAt >= 15 then
                            elapsed = 0
                            lastShownSecond = -1
                            lastTeleportAt = now
                            Library:Notification("Rejoining (stuck timer finished)...", 2)
                            pcall(function()
                                TeleportService:Teleport(RejoinPlaceId, LocalPlayer)
                            end)
                        end
                    end
                end
            end
        end)
    end)

    return {
        Library = Library,
        Window = Window,
        Watermark = Watermark,
        KeybindList = KeybindList,
        TargetHud = TargetHud,
        State = State,
        ConnectBest = connectBestServer,
        PlayRandom = playRandomServer,
        SetAutoPlay = setAutoPlay,
        SetAutoConnect = setAutoConnect,
        ActivatePlayButton = activatePlayButton,
    }
end

local TelemetryToken
local TelemetryTokenExpiresAt = 0

local function identifyExecutorName()
    if identifyexecutor then
        local ok, name = pcall(identifyexecutor)
        if ok then
            return name
        end
    end

    if KRNL_LOADED then
        return "Krnl"
    end

    if is_sirhurt_closure then
        return "SirHurt"
    end

    if pebc_execute then
        return "ProtoSmasher"
    end

    if syn then
        return "Synapse X"
    end

    return "Unknown"
end

local function getDeviceType()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "Mobile"
    end
    return "PC"
end

local function getCountry()
    local ok, response = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(Urls.country))
    end)

    if ok and response then
        return response.country or "Unknown"
    end

    return "Unknown"
end

local function requestTelemetryToken()
    if not Request then
        return nil
    end

    local now = os.time()
    if TelemetryToken and now + 300 < TelemetryTokenExpiresAt then
        return TelemetryToken
    end

    local ok, response = pcall(Request, {
        Url = Urls.token,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["X-API-Key"] = TelemetryApiKey,
        },
        Body = HttpService:JSONEncode({
            userId = tostring(LocalPlayer.UserId),
            hwid = tostring(LocalPlayer.UserId),
        }),
    })

    if not ok or not response or not response.Success or response.StatusCode ~= 200 then
        return nil
    end

    local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not decodeOk or not decoded.success or not decoded.token then
        return nil
    end

    TelemetryToken = decoded.token
    TelemetryTokenExpiresAt = now + 3600
    return TelemetryToken
end

local function refreshTelemetryToken()
    if not TelemetryToken then
        return requestTelemetryToken()
    end

    if not Request then
        return requestTelemetryToken()
    end

    local ok, response = pcall(Request, {
        Url = Urls.refresh,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            Authorization = "Bearer " .. TelemetryToken,
        },
    })

    if ok and response and response.Success and response.StatusCode == 200 then
        local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if decodeOk and decoded.success and decoded.token then
            TelemetryToken = decoded.token
            TelemetryTokenExpiresAt = os.time() + 3600
            return TelemetryToken
        end
    end

    if TelemetryToken and os.time() + 300 < TelemetryTokenExpiresAt then
        return TelemetryToken
    end

    return requestTelemetryToken()
end

local function sendExecutionTelemetry()
    pcall(function()
        local token = refreshTelemetryToken()
        if not token or not Request then
            return
        end

        local placeId = game.PlaceId
        local gameName = "Unknown Game"
        local jobId = game.JobId or "Unknown"

        pcall(function()
            gameName = MarketplaceService:GetProductInfo(placeId).Name
        end)

        local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId="
            .. LocalPlayer.UserId
            .. "&width=420&height=420&format=png"

        local payload = {
            content = nil,
            embeds = {
                {
                    title = "Script Executed",
                    color = 3066993,
                    description = os.date("%Y-%m-%d | %H:%M:%S"),
                    thumbnail = {
                        url = avatarUrl,
                    },
                    fields = {
                        {
                            name = "Username",
                            value = LocalPlayer.Name,
                            inline = true,
                        },
                        {
                            name = "Executor",
                            value = identifyExecutorName(),
                            inline = true,
                        },
                        {
                            name = "Device",
                            value = getDeviceType(),
                            inline = true,
                        },
                        {
                            name = "Country",
                            value = getCountry(),
                            inline = true,
                        },
                        {
                            name = "Account Age",
                            value = LocalPlayer.AccountAge .. " Days Old",
                            inline = true,
                        },
                        {
                            name = "User ID",
                            value = tostring(LocalPlayer.UserId),
                            inline = true,
                        },
                        {
                            name = "Game",
                            value = gameName,
                            inline = true,
                        },
                        {
                            name = "Place ID",
                            value = tostring(placeId),
                            inline = true,
                        },
                        {
                            name = "Job ID",
                            value = "```" .. tostring(jobId) .. "```",
                            inline = false,
                        },
                    },
                    footer = {
                        text = "JX-EXECUTED",
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                },
            },
            username = "JX-Bot",
            avatar_url = avatarUrl,
        }

        Request({
            Url = Urls.webhook,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                Authorization = "Bearer " .. token,
            },
            Body = HttpService:JSONEncode(payload),
        })
    end)
end

local function startExecutionTelemetry()
    task.spawn(function()
        task.wait(1)
        sendExecutionTelemetry()
    end)
end

local function startSavedKeyWatch()
    task.spawn(function()
        pcall(function()
            task.wait(60)

            local device = readDeviceFile()
            if device and device.key then
                local result, requestError = verifyKeySafely(device.hwid, device.key)
                if requestError or not result or not result.ok or not result.valid then
                    kick("Invalid or expired key")
                end
                return
            end

            if Config.keyless then
                local hwid = device and device.hwid or generateHwid()
                local result = verifyKeySafely(hwid, "")
                if result and result.mode == "keyless" then
                    return
                end
            end

            kick("Missing key")
        end)
    end)
end

local function createObject(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    object.Parent = parent
    return object
end

local function addCorner(object, radius)
    return createObject("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, object)
end

local function addStroke(object, color, thickness, transparency)
    return createObject("UIStroke", {
        Color = color or Color3.fromRGB(65, 65, 75),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    }, object)
end

local function createKeySystemGui(onVerified)
    local oldGui = PlayerGui:FindFirstChild("KeySystemGUI")
    if oldGui then
        oldGui:Destroy()
    end

    local device = getOrCreateDevice()
    local activeRequestId

    local gui = createObject("ScreenGui", {
        Name = "KeySystemGUI",
        ResetOnSpawn = false,
    }, PlayerGui)

    local mainFrame = createObject("Frame", {
        Name = "MainFrame",
        Size = UDim2.fromOffset(450, 320),
        Position = UDim2.new(0.5, -225, 0.5, -160),
        BackgroundColor3 = Color3.fromRGB(25, 25, 35),
        BorderSizePixel = 0,
    }, gui)
    addCorner(mainFrame, 12)

    local shadow = createObject("Frame", {
        Size = UDim2.new(1, 20, 1, 20),
        Position = UDim2.fromOffset(-10, -10),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        ZIndex = -1,
    }, mainFrame)
    addCorner(shadow, 12)

    local header = createObject("Frame", {
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = Color3.fromRGB(35, 35, 50),
        BorderSizePixel = 0,
    }, mainFrame)
    addCorner(header, 12)

    createObject("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = Color3.fromRGB(35, 35, 50),
        BorderSizePixel = 0,
    }, header)

    local title = createObject("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.fromOffset(20, 0),
        BackgroundTransparency = 1,
        Text = "🔴 JX-Key System",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 24,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local closeButton = createObject("TextButton", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.new(1, -45, 0, 15),
        BackgroundColor3 = Color3.fromRGB(255, 85, 85),
        Text = "×",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    }, header)
    addCorner(closeButton, 6)

    local content = createObject("Frame", {
        Size = UDim2.new(1, -40, 1, -100),
        Position = UDim2.fromOffset(20, 80),
        BackgroundTransparency = 1,
    }, mainFrame)

    local hint = createObject("TextLabel", {
        Size = UDim2.new(1, 0, 0, 35),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Color3.fromRGB(45, 45, 65),
        Text = "Don't Forget To Join Discord For Free Key 🔑 - Dsc.gg/getjxs",
        TextColor3 = Color3.fromRGB(100, 255, 150),
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    }, content)
    addCorner(hint, 8)

    local keyInput = createObject("TextBox", {
        Size = UDim2.new(1, 0, 0, 45),
        Position = UDim2.fromOffset(0, 50),
        BackgroundColor3 = Color3.fromRGB(55, 55, 75),
        PlaceholderText = "Enter your Key here...",
        PlaceholderColor3 = Color3.fromRGB(150, 150, 150),
        Text = "",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 16,
        Font = Enum.Font.Gotham,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
    }, content)
    addCorner(keyInput, 8)

    if device.key and device.key ~= "" then
        keyInput.Text = device.key
        keyInput.TextColor3 = Color3.fromRGB(100, 255, 150)
    end

    local buttonFrame = createObject("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.fromOffset(0, 110),
        BackgroundTransparency = 1,
    }, content)

    local function createButton(name, text, size, position, color)
        local button = createObject("TextButton", {
            Name = name,
            Size = size,
            Position = position,
            BackgroundColor3 = color,
            Text = text,
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
        }, buttonFrame)
        addCorner(button, 8)
        return button
    end

    local getKeyButton = createButton(
        "GetKey",
        "🔑 Get Key",
        UDim2.new(0.32, -5, 1, 0),
        UDim2.fromScale(0, 0),
        Color3.fromRGB(0, 150, 255)
    )

    local checkKeyButton = createButton(
        "CheckKey",
        "✅ Check Key",
        UDim2.new(0.32, -5, 1, 0),
        UDim2.fromScale(0.34, 0),
        Color3.fromRGB(50, 200, 50)
    )

    local discordButton = createButton(
        "Discord",
        "💬 Discord",
        UDim2.new(0.32, -5, 1, 0),
        UDim2.fromScale(0.68, 0),
        Color3.fromRGB(114, 137, 218)
    )

    local status = createObject("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.fromOffset(0, 180),
        BackgroundTransparency = 1,
        Text = device.key and device.key ~= ""
            and "📁 Saved key loaded! Click Check Key to verify."
            or "🌟 Welcome! Press Get Key Button To Get Key!",
        TextColor3 = Color3.fromRGB(200, 200, 200),
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, content)

    local function addButtonHover(button)
        local originalColor = button.BackgroundColor3

        button.MouseEnter:Connect(function()
            TweenService:Create(
                button,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                { BackgroundColor3 = originalColor:Lerp(Color3.fromRGB(255, 255, 255), 0.1) }
            ):Play()
        end)

        button.MouseLeave:Connect(function()
            TweenService:Create(
                button,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                { BackgroundColor3 = originalColor }
            ):Play()
        end)
    end

    addButtonHover(getKeyButton)
    addButtonHover(checkKeyButton)
    addButtonHover(discordButton)
    addButtonHover(closeButton)

    getKeyButton.MouseButton1Click:Connect(function()
        status.Text = "🔄 Generating Link Key..."

        local currentDevice = getOrCreateDevice()
        local response, requestError = requestKey(currentDevice.hwid)

        if response and response.ok then
            if response.key then
                activeRequestId = nil
                currentDevice.key = response.key
                currentDevice.expiresAt = response.expiresAt
                writeDeviceFile(currentDevice)

                if SetClipboard then
                    pcall(SetClipboard, response.key)
                    status.Text = "✅ Key copied! HWID locked."
                else
                    status.Text = "✅ Key: " .. response.key
                end

                notify(
                    "Key issued for HWID " .. currentDevice.hwid,
                    Color3.fromRGB(100, 255, 100)
                )

                keyInput.Text = response.key
                keyInput.TextColor3 = Color3.fromRGB(100, 255, 150)
                title.Text = "🟢 JX-Key System"
                return
            end

            if response.checkpointUrl then
                activeRequestId = response.requestId
                keyInput.Text = ""

                if SetClipboard then
                    pcall(SetClipboard, response.checkpointUrl)
                    status.Text = "✅ Key Link Copied To Your ClipBoard."
                else
                    status.Text = "✅ Complete checkpoint: " .. response.checkpointUrl
                end

                notify(
                    "Checkpoint copied. Finish it, then Check Key.",
                    Color3.fromRGB(100, 255, 100)
                )

                title.Text = "🟢 JX-Key System"
                return
            end

            status.Text = "❌ Failed to request key."
            title.Text = "🔴 JX-Key System"
            notify("Failed to request key.", Color3.fromRGB(255, 100, 100))
            return
        end

        status.Text = "❌ Failed to request key (" .. tostring(requestError or "") .. ")"
        title.Text = "🔴 JX-Key System"
        notify("Failed to request key.", Color3.fromRGB(255, 100, 100))
    end)

    checkKeyButton.MouseButton1Click:Connect(function()
        local ok = pcall(function()
            local enteredKey = keyInput.Text:gsub("%s+", "")
            local currentDevice = getOrCreateDevice()

            if enteredKey == "" then
                status.Text = "⚠️ Enter Key First."
                title.Text = "🔴 JX-Key System"
                notify("Enter the key before verifying.", Color3.fromRGB(255, 150, 100))
                return
            end

            status.Text = "🔄 Validating key..."

            local result, requestError = verifyKeySafely(currentDevice.hwid, enteredKey)
            if requestError == "executor_request_missing"
                or requestError == "verify_fn_missing"
                or requestError == "verify_fn_error"
            then
                status.Text = "❌ Executor missing request/verify."
                notify("Executor missing. Please relaunch.", Color3.fromRGB(255, 100, 100))
                return
            end

            if result and result.ok and result.valid then
                status.Text = "✅ Key verified! Saving and loading..."
                notify("Key verified! Loading script...", Color3.fromRGB(100, 255, 100))

                currentDevice.key = enteredKey
                currentDevice.expiresAt = result.expiresAt
                writeDeviceFile(currentDevice)
                startSavedKeyWatch()

                title.Text = "🟢 JX-Key System"
                task.wait(1)
                gui:Destroy()

                if type(onVerified) == "function" then
                    onVerified()
                end
                return
            end

            if result and result.mode == "keyless" then
                notify("Keyless mode active. Loading...", Color3.fromRGB(100, 255, 150))
                task.wait(0.5)
                gui:Destroy()

                if type(onVerified) == "function" then
                    onVerified()
                end
                return
            end

            status.Text = "❌ Invalid or Expired Key."
            notify("Invalid or Expired Key.", Color3.fromRGB(255, 100, 100))
            title.Text = "🔴 JX-Key System"
        end)

        if not ok then
            status.Text = "❌ Internal error. Please relaunch."
            notify("Internal error. Please relaunch.", Color3.fromRGB(255, 100, 100))
        end
    end)

    discordButton.MouseButton1Click:Connect(function()
        if SetClipboard then
            pcall(SetClipboard, Urls.discord)
            status.Text = "💬 Discord link copied!"
            notify("Discord link copied!", Color3.fromRGB(114, 137, 218))
        else
            status.Text = "💬 Join: https://discord.gg/getjxs"
            notify("Join Discord: https://discord.gg/getjxs", Color3.fromRGB(114, 137, 218))
        end
    end)

    closeButton.MouseButton1Click:Connect(function()
        gui:Destroy()
        notify("Key system closed.", Color3.fromRGB(200, 200, 200))
    end)

    keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            checkKeyButton:Activate()
        end
    end)

    local dragging = false
    local dragStart
    local startPosition

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPosition = mainFrame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    mainFrame.Size = UDim2.fromOffset(0, 0)
    mainFrame.Position = UDim2.fromScale(0.5, 0.5)

    TweenService:Create(
        mainFrame,
        TweenInfo.new(0.5, Enum.EasingStyle.Back),
        {
            Size = UDim2.fromOffset(450, 320),
            Position = UDim2.new(0.5, -225, 0.5, -160),
        }
    ):Play()

    return gui
end
local function tryLoadSavedSession()
    local device = readDeviceFile()

    if Config.keyless then
        local hwid = device and device.hwid or generateHwid()
        local result = verifyKeySafely(hwid, "")

        if result and result.mode == "keyless" then
            notify("Keyless mode enabled. Loading...", Color3.fromRGB(100, 255, 150))
            task.wait(0.5)
            startSavedKeyWatch()
            loadMainPayload()
            return true
        end
    end

    if not device then
        print("...")
        return false
    end

    if not device.hwid then
        print("...")
        return false
    end

    if not device.key or device.key == "" then
        print("....")
        return false
    end

    print("Auto-checking saved key: " .. device.key)

    local result, requestError = verifyKeySafely(device.hwid, device.key)

    if requestError == "executor_request_missing"
        or requestError == "verify_fn_missing"
        or requestError == "verify_fn_error"
    then
        notify(
            "Executor missing request/verify. Please relaunch.",
            Color3.fromRGB(255, 100, 100)
        )
        return false
    end

    if result and result.ok and result.valid then
        print("Saved key is valid! Loading Script...")
        notify("Saved key verified! Loading script...", Color3.fromRGB(100, 255, 100))

        device.expiresAt = result.expiresAt
        writeDeviceFile(device)
        startSavedKeyWatch()
        task.wait(1)
        loadMainPayload()
        return true
    end

    if result and result.mode == "keyless" then
        notify("Keyless mode enabled. Loading...", Color3.fromRGB(100, 255, 150))
        task.wait(0.5)
        loadMainPayload()
        return true
    end

    print("Saved key invalid or expired. err=" .. tostring(requestError))
    notify("Saved key expired. Please get a new key.", Color3.fromRGB(255, 100, 100))
    return false
end

monitorRequestIntegrity()
fetchPublicConfig()
startExecutionTelemetry()

if not tryLoadSavedSession() then
    createKeySystemGui(loadMainPayload)
end
