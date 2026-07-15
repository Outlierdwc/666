-- ===================================================================
--  合并脚本：Criminality Farm + Server  (第1段/共4段)
--  说明：按 1→2→3→4 顺序复制拼接，然后整体执行。
-- ===================================================================

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
local LogService = game:GetService("LogService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Environment = getgenv and getgenv() or _G

local Request = request or http_request or (syn and syn.request) or (http and http.request)

local function jsonDecode(text)
    local ok, result = pcall(HttpService.JSONDecode, HttpService, text)
    return ok and result or nil
end
local function jsonEncode(value)
    local ok, result = pcall(HttpService.JSONEncode, HttpService, value)
    return ok and result or nil
end
local function now() return type(tick) == "function" and tick() or os.clock() end
local function waitSeconds(s) return (type(task) == "table" and task.wait or wait)(s) end
local function spawnTask(cb) return (type(task) == "table" and task.spawn or coroutine.wrap)(cb)() end
local function deferTask(cb) return (type(task) == "table" and task.defer or spawnTask)(cb) end

local function ensureFolder(path)
    if type(isfolder) == "function" and isfolder(path) then return true end
    if type(makefolder) ~= "function" then return false end
    return pcall(makefolder, path)
end
local function safeRead(path)
    if type(readfile) ~= "function" or type(isfile) ~= "function" or not isfile(path) then return nil end
    local ok, result = pcall(readfile, path)
    return ok and result or nil
end
local function safeWrite(path, content)
    if type(writefile) ~= "function" then return false end
    return pcall(writefile, path, tostring(content))
end

-- ===================== Server 核心 =====================
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

local SetClipboard = setclipboard or toclipboard or (syn and syn.set_clipboard)
local WriteFile = writefile or (syn and syn.write_file)
local ReadFile = readfile or (syn and syn.read_file)
local IsFile = isfile or (syn and syn.isfile)
local IsFolder = isfolder or (syn and syn.isfolder)
local MakeFolder = makefolder or (syn and syn.makefolder)

local function asBoolean(v) return v == true end
local function safeCall(cb, ...)
    local args = table.pack(...)
    return pcall(function() return cb(table.unpack(args, 1, args.n)) end)
end
local function notify(msg, color)
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = msg,
            Color = color or Color3.fromRGB(255, 255, 255)
        })
    end)
end
local function kick(msg)
    pcall(function() LocalPlayer:Kick(msg or "Dont Bypass It Please :C") end)
end

local function isLuaClosure(cb)
    if not cb then return false end
    if debug and debug.info then
        local ok, src = pcall(debug.info, cb, "s")
        if ok then return src ~= "[C]" end
    end
    if islclosure then
        local ok, res = pcall(islclosure, cb)
        return ok and res or false
    end
    return false
end

local function monitorRequestIntegrity()
    local origGlobal = request
    local origResolved = Request
    local origLua = isLuaClosure(origResolved)
    if not origResolved then return end
    task.spawn(function()
        while task.wait(0.5) do
            local env = getgenv and getgenv() or Environment
            local curResolved = env.request or origResolved
            local curGlobal = request
            local valid = curResolved ~= nil
            if curResolved ~= origResolved then valid = false end
            if curGlobal and curGlobal ~= origGlobal and curGlobal ~= origResolved then valid = false end
            if not origLua and isLuaClosure(curResolved) then valid = false end
            if not valid then kick("Dont Bypass It Please :C"); return end
        end
    end)
end

local function readDeviceFile()
    if not ReadFile or not IsFile then return nil end
    local ok, exists = pcall(IsFile, Paths.device)
    if not ok or not exists then return nil end
    local ok2, contents = pcall(ReadFile, Paths.device)
    if not ok2 or type(contents) ~= "string" then return nil end
    local ok3, dev = pcall(HttpService.JSONDecode, HttpService, contents)
    return ok3 and dev or nil
end
local function writeDeviceFile(dev)
    if not WriteFile then return false end
    ensureFolder(Paths.root)
    local ok, contents = pcall(HttpService.JSONEncode, HttpService, dev)
    if not ok then return false end
    return pcall(WriteFile, Paths.device, contents)
end
local function generateHwid() return HttpService:GenerateGUID(false):gsub("-", "") .. tostring(math.random(1000, 9999)) end
local function getOrCreateDevice()
    local dev = readDeviceFile()
    if dev and dev.hwid then return dev end
    dev = { hwid = generateHwid(), createdAt = os.time() }
    writeDeviceFile(dev)
    return dev
end

local function postJson(path, body)
    if not Request then return nil, "executor_request_missing" end
    local ok, resp = pcall(Request, {
        Url = Config.apiBase .. path,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = jsonEncode(body or {})
    })
    if not ok or not resp then return nil, "no_response" end
    local decoded = jsonDecode(resp.Body or "{}")
    return decoded, nil
end
local function requestKey(hwid) return postJson("/api/jx/keys/request", { hwid = hwid }) end
local function verifyKey(hwid, key)
    local reqId = HttpService:GenerateGUID(false)
    local resp, err = postJson("/api/jx/keys/verify", { hwid = hwid, key = key, reqId = reqId })
    if resp and resp.resId ~= reqId .. "_jx_valid_response" then return nil, "spoof_detected" end
    return resp, err
end
local function fetchPublicConfig()
    if not Request then return end
    local ok, resp = pcall(Request, {
        Url = Config.apiBase .. "/api/jx/public/config",
        Method = "GET",
        Headers = { ["Content-Type"] = "application/json" }
    })
    if not ok or not resp or not resp.Body then return end
    local decoded = jsonDecode(resp.Body)
    if type(decoded) ~= "table" or not decoded.ok then return end
    local settings = decoded.settings
    if type(settings) ~= "table" then return end
    Config.prefix = settings.prefix or Config.prefix
    Config.expirationHours = settings.expirationHours
    Config.keyless = settings.keyless or false
end
local function verifyKeySafely(hwid, key)
    if not Request then return nil, "executor_request_missing" end
    if type(verifyKey) ~= "function" then return nil, "verify_fn_missing" end
    local ok, res, err = pcall(verifyKey, hwid, key)
    if not ok then return nil, "verify_fn_error" end
    return res, err
end

local function configureLphAliases()
    local identity = function(v) return v end
    Environment.LPH_JIT = MV_VM and function(c) return MV_VM(c) end or identity
    Environment.LPH_JIT_MAX = MV_VM and function(c) return MV_VM(c) end or identity
    Environment.LPH_NO_VIRTUALIZE = identity
    Environment.LPH_NO_UPVALUES = identity
    Environment.LPH_ENCSTR = MV_ENC_STR and function(v) return MV_ENC_STR(v) end or identity
    Environment.LPH_ENCNUM = identity
end

local function isMenuAvailable()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local hasMenu = pg and pg:FindFirstChild("MenuGUI") ~= nil
    local events = ReplicatedStorage:FindFirstChild("Events")
    local hasSrv = events and events:FindFirstChild("Play") ~= nil and events:FindFirstChild("Update") ~= nil
    return hasMenu or hasSrv or false
end
local function activateButton(btn)
    if not btn or not btn:IsA("GuiButton") or btn.Visible == false then return false end
    return pcall(function() btn:Activate() end)
end
local function activatePlayButton()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return false end
    local b1
    pcall(function() b1 = pg:FindFirstChild("MenuGUI"):FindFirstChild("Holder"):FindFirstChild("MainFrame"):FindFirstChild("PictureFrame"):FindFirstChild("StatsFrame"):FindFirstChild("ButtonFrame"):FindFirstChild("PlayButton") end)
    if activateButton(b1) then return true end
    local b2
    pcall(function() local m = pg:FindFirstChild("MenuGUI"); local r = m and (m:FindFirstChild("Frame") or m:FindFirstChild("Holder") or m); local btns = r and r:FindFirstChild("ButtonsFrame", true); local pf = btns and btns:FindFirstChild("PlayFrame", true); b2 = pf and pf:FindFirstChild("TextButton", true) end)
    return activateButton(b2)
end
local function waitForChild(p, name, timeout)
    timeout = timeout or 10
    local st = tick()
    while tick() - st < timeout do
        local c = p:FindFirstChild(name)
        if c then return c end
        task.wait(0.1)
    end
    return nil
end
local function isGameMenuGui(gui)
    if not gui or not gui:IsA("ScreenGui") then return false end
    local h = gui:FindFirstChild("Holder", true)
    local mf = gui:FindFirstChild("MainFrame", true)
    local pb = gui:FindFirstChild("PlayButton", true)
    if h and mf and pb and pb:IsA("GuiButton") then return true end
    local bf = gui:FindFirstChild("ButtonsFrame", true)
    local pf = gui:FindFirstChild("PlayFrame", true)
    local tb = gui:FindFirstChild("TextButton", true)
    return bf ~= nil and pf ~= nil and tb ~= nil and tb:IsA("GuiButton")
end
local function removeMenuObjects()
    local function rm(c)
        if not c then return end
        for _, ch in ipairs(c:GetChildren()) do if ch.Name == "MenuScene" then Debris:AddItem(ch, 0) end end
    end
    rm(workspace)
    rm(workspace:FindFirstChild("Filter"))
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "MenuScene" then
            Debris:AddItem(obj, 0)
        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
            local p = obj.Parent
            if p and (p.Name == "MenuScene" or (p.Parent and p.Parent.Name == "MenuScene")) then
                obj.Enabled = false
                Debris:AddItem(obj, 0)
            end
        end
    end
end
local function restoreLighting()
    local dc = Lighting:FindFirstChild("DefaultLightingConfig")
    if dc then
        for _, v in ipairs(dc:GetChildren()) do
            if v:IsA("BoolValue") or v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("StringValue") or v:IsA("Color3Value") then
                pcall(function() Lighting[v.Name] = v.Value end)
            end
        end
    end
    for _, ch in ipairs(Lighting:GetChildren()) do
        local fx = ch:GetAttribute("PostFX") == true or ch:IsA("BloomEffect") or ch:IsA("BlurEffect") or ch:IsA("DepthOfFieldEffect") or ch:IsA("SunRaysEffect") or ch:IsA("ColorCorrectionEffect")
        if fx then
            pcall(function() ch.Enabled = false end)
            pcall(function() ch:Destroy() end)
        end
    end
    Lighting.Brightness = tonumber(Lighting.Brightness) or 2
    if Lighting.Brightness > 3 then Lighting.Brightness = 2 end
    Lighting.ExposureCompensation = 0
    local avgA = (Lighting.Ambient.R + Lighting.Ambient.G + Lighting.Ambient.B) / 3
    local avgO = (Lighting.OutdoorAmbient.R + Lighting.OutdoorAmbient.G + Lighting.OutdoorAmbient.B) / 3
    if Lighting.Brightness > 0.5 and avgA <= 0.08 and avgO <= 0.08 then
        Lighting.Brightness = math.max(Lighting.Brightness, 2)
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(90, 90, 90)
        if typeof(Lighting.ClockTime) ~= "number" then Lighting.ClockTime = 14 end
        if Lighting.ClockTime < 6 or Lighting.ClockTime > 19 then Lighting.ClockTime = 14 end
        Lighting.GlobalShadows = true
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
    end
end
local function setupGameEnvironment()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local rf = events and events:FindFirstChild("BRBRBRRBLOOOL2")
    local uc = events and events:FindFirstChild("UpdateClient")
    if rf and rf:IsA("RemoteFunction") then pcall(function() rf:InvokeServer("", "\15daz\18tough\19") end) end
    if uc and uc:IsA("RemoteEvent") then pcall(function() uc:FireServer() end) end
    pcall(function() RunService:UnbindFromRenderStep("MenuCam") end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return end
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") and (g.Name == "MenuGUI" or isGameMenuGui(g)) then g.Enabled = false end
        end
    end)
    local cam = workspace.CurrentCamera
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if cam and hum then pcall(function() cam.CameraType = Enum.CameraType.Custom; cam.CameraSubject = hum end) end
    pcall(removeMenuObjects)
    pcall(restoreLighting)
    return cam ~= nil and hum ~= nil
end
local function normalizeServerList(v)
    if type(v) ~= "table" then return {} end
    if #v > 0 then return v end
    local r = {}
    for _, s in pairs(v) do if type(s) == "table" then table.insert(r, s) end end
    return r
end
local function normalizeRegion(v)
    local u = tostring(v or ""):upper()
    return u:match("([A-Z][A-Z])") or u
end
local function getServerId(s) return s.serverId or s.jobId or s.jobID or s.id or s.ServerId or s.ServerID end
local function getPlayerCount(s) return tonumber(s.players or s.playerCount or s.Players) or 0 end
local function isTruthy(v) return v == true or v == 1 or v == "1" end
local function runProtected(name, cb)
    local ok, err = xpcall(cb, debug.traceback)
    if not ok then warn(string.format("[JX:%s] %s", tostring(name), tostring(err))) end
end

-- Telemetry
local TelemetryToken, TelemetryTokenExpiresAt
local function identifyExecutorName()
    if identifyexecutor then
        local ok, n = pcall(identifyexecutor)
        if ok then return n end
    end
    if KRNL_LOADED then return "Krnl" end
    if is_sirhurt_closure then return "SirHurt" end
    if pebc_execute then return "ProtoSmasher" end
    if syn then return "Synapse X" end
    return "Unknown"
end
local function getDeviceType()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "Mobile" end
    return "PC"
end
local function getCountry()
    local ok, resp = pcall(function() return jsonDecode(game:HttpGet(Urls.country)) end)
    if ok and resp then return resp.country or "Unknown" end
    return "Unknown"
end
local function requestTelemetryToken()
    if not Request then return nil end
    local nowT = os.time()
    if TelemetryToken and nowT + 300 < TelemetryTokenExpiresAt then return TelemetryToken end
    local ok, resp = pcall(Request, {
        Url = Urls.token,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json", ["X-API-Key"] = TelemetryApiKey },
        Body = jsonEncode({ userId = tostring(LocalPlayer.UserId), hwid = tostring(LocalPlayer.UserId) })
    })
    if not ok or not resp or not resp.Success or resp.StatusCode ~= 200 then return nil end
    local dec = jsonDecode(resp.Body)
    if not dec or not dec.success or not dec.token then return nil end
    TelemetryToken = dec.token
    TelemetryTokenExpiresAt = nowT + 3600
    return TelemetryToken
end
local function refreshTelemetryToken()
    if not TelemetryToken then return requestTelemetryToken() end
    if not Request then return requestTelemetryToken() end
    local ok, resp = pcall(Request, {
        Url = Urls.refresh,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json", Authorization = "Bearer " .. TelemetryToken }
    })
    if ok and resp and resp.Success and resp.StatusCode == 200 then
        local dec = jsonDecode(resp.Body)
        if dec and dec.success and dec.token then
            TelemetryToken = dec.token
            TelemetryTokenExpiresAt = os.time() + 3600
            return TelemetryToken
        end
    end
    if TelemetryToken and os.time() + 300 < TelemetryTokenExpiresAt then return TelemetryToken end
    return requestTelemetryToken()
end
local function sendExecutionTelemetry()
    pcall(function()
        local token = refreshTelemetryToken()
        if not token or not Request then return end
        local placeId = game.PlaceId
        local gameName = "Unknown Game"
        local jobId = game.JobId or "Unknown"
        pcall(function() gameName = MarketplaceService:GetProductInfo(placeId).Name end)
        local avatar = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"
        local payload = {
            embeds = { {
                title = "Script Executed",
                color = 3066993,
                description = os.date("%Y-%m-%d | %H:%M:%S"),
                thumbnail = { url = avatar },
                fields = {
                    { name = "Username", value = LocalPlayer.Name, inline = true },
                    { name = "Executor", value = identifyExecutorName(), inline = true },
                    { name = "Device", value = getDeviceType(), inline = true },
                    { name = "Country", value = getCountry(), inline = true },
                    { name = "Account Age", value = LocalPlayer.AccountAge .. " Days Old", inline = true },
                    { name = "User ID", value = tostring(LocalPlayer.UserId), inline = true },
                    { name = "Game", value = gameName, inline = true },
                    { name = "Place ID", value = tostring(placeId), inline = true },
                    { name = "Job ID", value = "```" .. tostring(jobId) .. "```", inline = false },
                },
                footer = { text = "JX-EXECUTED" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            } },
            username = "JX-Bot",
            avatar_url = avatar,
        }
        Request({
            Url = Urls.webhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json", Authorization = "Bearer " .. token },
            Body = jsonEncode(payload)
        })
    end)
end

-- Key System UI
local function createKeySystemGUI(onVerified)
    local old = PlayerGui:FindFirstChild("KeySystemGUI")
    if old then old:Destroy() end
    local device = getOrCreateDevice()
    local gui = Instance.new("ScreenGui")
    gui.Name = "KeySystemGUI"
    gui.ResetOnSpawn = false
    gui.Parent = PlayerGui

    local main = Instance.new("Frame")
    main.Size = UDim2.fromOffset(450, 320)
    main.Position = UDim2.new(0.5, -225, 0.5, -160)
    main.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    main.BorderSizePixel = 0
    main.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = main

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.fromOffset(-10, -10)
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.BackgroundTransparency = 0.8
    shadow.BorderSizePixel = 0
    shadow.ZIndex = -1
    shadow.Parent = main
    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0, 12)
    sc.Parent = shadow

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    header.BorderSizePixel = 0
    header.Parent = main
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0, 12)
    hc.Parent = header
    local hfill = Instance.new("Frame")
    hfill.Size = UDim2.new(1, 0, 0, 12)
    hfill.Position = UDim2.new(0, 0, 1, -12)
    hfill.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    hfill.BorderSizePixel = 0
    hfill.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.fromOffset(20, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔴 JX-Key System"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(30, 30)
    closeBtn.Position = UDim2.new(1, -45, 0, 15)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = header
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 6)
    cc.Parent = closeBtn

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -40, 1, -100)
    content.Position = UDim2.fromOffset(20, 80)
    content.BackgroundTransparency = 1
    content.Parent = main

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, 0, 0, 35)
    hint.Position = UDim2.fromOffset(0, 0)
    hint.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
    hint.Text = "Don't Forget To Join Discord For Free Key 🔑 - Dsc.gg/getjxs"
    hint.TextColor3 = Color3.fromRGB(100, 255, 150)
    hint.TextSize = 14
    hint.Font = Enum.Font.GothamBold
    hint.BorderSizePixel = 0
    hint.Parent = content
    local hc2 = Instance.new("UICorner")
    hc2.CornerRadius = UDim.new(0, 8)
    hc2.Parent = hint

    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, 0, 0, 45)
    keyInput.Position = UDim2.fromOffset(0, 50)
    keyInput.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
    keyInput.PlaceholderText = "Enter your Key here..."
    keyInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    keyInput.Text = ""
    keyInput.TextColor3 = Color3.new(1, 1, 1)
    keyInput.TextSize = 16
    keyInput.Font = Enum.Font.Gotham
    keyInput.BorderSizePixel = 0
    keyInput.ClearTextOnFocus = false
    keyInput.Parent = content
    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(0, 8)
    kc.Parent = keyInput

    if device.key and device.key ~= "" then
        keyInput.Text = device.key
        keyInput.TextColor3 = Color3.fromRGB(100, 255, 150)
    end

    local btnFrame = Instance.new("Frame")
    btnFrame.Size = UDim2.new(1, 0, 0, 50)
    btnFrame.Position = UDim2.fromOffset(0, 110)
    btnFrame.BackgroundTransparency = 1
    btnFrame.Parent = content

    local function createBtn(name, text, size, pos, color)
        local b = Instance.new("TextButton")
        b.Name = name
        b.Size = size
        b.Position = pos
        b.BackgroundColor3 = color
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextSize = 16
        b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        b.Parent = btnFrame
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = b
        return b
    end

    local getKeyBtn = createBtn("GetKey", "🔑 Get Key", UDim2.new(0.32, -5, 1, 0), UDim2.fromScale(0, 0), Color3.fromRGB(0, 150, 255))
    local checkKeyBtn = createBtn("CheckKey", "✅ Check Key", UDim2.new(0.32, -5, 1, 0), UDim2.fromScale(0.34, 0), Color3.fromRGB(50, 200, 50))
    local discordBtn = createBtn("Discord", "💬 Discord", UDim2.new(0.32, -5, 1, 0), UDim2.fromScale(0.68, 0), Color3.fromRGB(114, 137, 218))

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, 0, 0, 60)
    status.Position = UDim2.fromOffset(0, 180)
    status.BackgroundTransparency = 1
    status.Text = device.key and device.key ~= "" and "📁 Saved key loaded! Click Check Key to verify." or "🌟 Welcome! Press Get Key Button To Get Key!"
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.TextSize = 14
    status.Font = Enum.Font.Gotham
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.Parent = content

    local function addHover(btn)
        local orig = btn.BackgroundColor3
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundColor3 = orig:Lerp(Color3.fromRGB(255, 255, 255), 0.1) }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundColor3 = orig }):Play()
        end)
    end
    addHover(getKeyBtn)
    addHover(checkKeyBtn)
    addHover(discordBtn)
    addHover(closeBtn)

    getKeyBtn.MouseButton1Click:Connect(function()
        status.Text = "🔄 Generating Link Key..."
        local curDev = getOrCreateDevice()
        local resp, err = requestKey(curDev.hwid)
        if resp and resp.ok then
            if resp.key then
                curDev.key = resp.key
                curDev.expiresAt = resp.expiresAt
                writeDeviceFile(curDev)
                if SetClipboard then
                    pcall(SetClipboard, resp.key)
                    status.Text = "✅ Key copied! HWID locked."
                else
                    status.Text = "✅ Key: " .. resp.key
                end
                notify("Key issued for HWID " .. curDev.hwid, Color3.fromRGB(100, 255, 100))
                keyInput.Text = resp.key
                keyInput.TextColor3 = Color3.fromRGB(100, 255, 150)
                title.Text = "🟢 JX-Key System"
                return
            end
            if resp.checkpointUrl then
                if SetClipboard then
                    pcall(SetClipboard, resp.checkpointUrl)
                    status.Text = "✅ Key Link Copied To Your ClipBoard."
                else
                    status.Text = "✅ Complete checkpoint: " .. resp.checkpointUrl
                end
                notify("Checkpoint copied. Finish it, then Check Key.", Color3.fromRGB(100, 255, 100))
                title.Text = "🟢 JX-Key System"
                return
            end
            status.Text = "❌ Failed to request key."
            title.Text = "🔴 JX-Key System"
            notify("Failed to request key.", Color3.fromRGB(255, 100, 100))
        else
            status.Text = "❌ Failed to request key (" .. tostring(err or "") .. ")"
            title.Text = "🔴 JX-Key System"
            notify("Failed to request key.", Color3.fromRGB(255, 100, 100))
        end
    end)

    checkKeyBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local entered = keyInput.Text:gsub("%s+", "")
            local curDev = getOrCreateDevice()
            if entered == "" then
                status.Text = "⚠️ Enter Key First."
                title.Text = "🔴 JX-Key System"
                notify("Enter the key before verifying.", Color3.fromRGB(255, 150, 100))
                return
            end
            status.Text = "🔄 Validating key..."
            local res, err = verifyKeySafely(curDev.hwid, entered)
            if err == "executor_request_missing" or err == "verify_fn_missing" or err == "verify_fn_error" then
                status.Text = "❌ Executor missing request/verify."
                notify("Executor missing. Please relaunch.", Color3.fromRGB(255, 100, 100))
                return
            end
            if res and res.ok and res.valid then
                status.Text = "✅ Key verified! Saving and loading..."
                notify("Key verified! Loading script...", Color3.fromRGB(100, 255, 100))
                curDev.key = entered
                curDev.expiresAt = res.expiresAt
                writeDeviceFile(curDev)
                title.Text = "🟢 JX-Key System"
                task.wait(1)
                gui:Destroy()
                if type(onVerified) == "function" then onVerified() end
                return
            end
            if res and res.mode == "keyless" then
                notify("Keyless mode active. Loading...", Color3.fromRGB(100, 255, 150))
                task.wait(0.5)
                gui:Destroy()
                if type(onVerified) == "function" then onVerified() end
                return
            end
            status.Text = "❌ Invalid or Expired Key."
            notify("Invalid or Expired Key.", Color3.fromRGB(255, 100, 100))
            title.Text = "🔴 JX-Key System"
        end)
    end)

    discordBtn.MouseButton1Click:Connect(function()
        if SetClipboard then
            pcall(SetClipboard, Urls.discord)
            status.Text = "💬 Discord link copied!"
            notify("Discord link copied!", Color3.fromRGB(114, 137, 218))
        else
            status.Text = "💬 Join: https://discord.gg/getjxs"
            notify("Join Discord: https://discord.gg/getjxs", Color3.fromRGB(114, 137, 218))
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        notify("Key system closed.", Color3.fromRGB(200, 200, 200))
    end)

    keyInput.FocusLost:Connect(function(enter)
        if enter then checkKeyBtn:Activate() end
    end)

    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    main.Size = UDim2.fromOffset(0, 0)
    main.Position = UDim2.fromScale(0.5, 0.5)
    TweenService:Create(main, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(450, 320), Position = UDim2.new(0.5, -225, 0.5, -160) }):Play()
    return gui
end

-- ==================== 第1段结束 ====================
-- ===================================================================
--  合并脚本：Criminality Farm + Server  (第2段/共4段)
-- ===================================================================

-- 此段包含 Server 的完整 UI 和自动循环，必须紧接第1段之后。

function loadMainPayload()
    configureLphAliases()
    local Library = loadstring(game:HttpGet(Urls.library))()
    Library.Folders = {
        Directory = Paths.payloadRoot,
        Configs = Paths.payloadConfigs,
        Assets = Paths.payloadAssets,
    }
    for _, p in pairs(Library.Folders) do ensureFolder(p) end

    local Window = Library:Window({
        Name = "JX-CRIMINALITY-SERVER | Dsc.gg/getjxs",
        Logo = "85279746515974",
        MobileButtonText = "JX"
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

    local ServerPage = Window:Page({ Name = "Server", Columns = 2 })
    Library:CreateSettingsPage(Window, KeybindList, Watermark)

    local GameModeSection = ServerPage:Section({ Name = "Game Mode", Side = 1 })
    local RegionSection = ServerPage:Section({ Name = "Region", Side = 2 })
    local ActionSection = ServerPage:Section({ Name = "Action", Side = 1 })
    local FreezeSection = ServerPage:Section({ Name = "Freeze", Side = 2 })

    task.spawn(function()
        runProtected("Setup", setupGameEnvironment)
    end)

    local RemoteInit, EventsPlay
    task.spawn(function()
        runProtected("RemoteInit", function()
            while task.wait(0.25) do
                if isMenuAvailable() and (not RemoteInit or not EventsPlay) then
                    RemoteInit = RemoteInit or waitForChild(ReplicatedStorage, "RemoteInit", 2)
                    local ev = waitForChild(ReplicatedStorage, "Events", 2)
                    EventsPlay = EventsPlay or (ev and waitForChild(ev, "Play", 2))
                end
            end
        end)
    end)

    local State = {
        enabledRegions = { SG = true, US = true, AU = true, JP = true },
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

    RunService.Heartbeat:Connect(function(dt)
        State.heartbeatDelta = tonumber(dt) or 0
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
        local t = tick()
        if t - State.lastServerActionAt < 2.5 then return false end
        State.lastServerActionAt = t
        return true
    end

    local function fetchServerList()
        if not isMenuAvailable() or not RemoteInit then return nil end
        local ok, servers = pcall(function()
            return RemoteInit:InvokeServer()
        end)
        if not ok or type(servers) ~= "table" then return nil end
        return servers
    end

    local function selectServer()
        local servers = normalizeServerList(fetchServerList())
        local candidates = {}
        for _, s in ipairs(servers) do
            local region = normalizeRegion(s.region)
            if State.enabledRegions[region] and (s.gameMode == nil or s.gameMode == State.selectedGameMode) then
                local id = getServerId(s)
                if id and not isTruthy(s.locked) and not isTruthy(s.prime) then
                    table.insert(candidates, {
                        serverId = tostring(id),
                        players = getPlayerCount(s),
                        region = region
                    })
                end
            end
        end
        if #candidates == 0 then return nil end
        table.sort(candidates, function(a, b)
            return State.joinHighestPlayers and a.players > b.players or a.players < b.players
        end)
        return candidates[1]
    end

    local function invokePlay(action, serverId)
        if not isMenuAvailable() then return false, "Not in menu" end
        if not EventsPlay then return false, "Events.Play not found" end
        local ok, accepted, reason = pcall(function()
            return EventsPlay:InvokeServer(action, State.selectedGameMode, serverId, 2)
        end)
        if not ok then return false, tostring(accepted) end
        if accepted == false then return false, tostring(reason or "Server refused connection") end
        return true
    end

    local function connectBestServer()
        if isManualFreezeActive() or not canRunServerAction() then return end
        local s = selectServer()
        if s then
            return invokePlay("connect", s.serverId)
        end
    end

    local function playRandomServer()
        if isManualFreezeActive() or not canRunServerAction() then return end
        return invokePlay("play", nil)
    end

    local function setAutoPlay(v)
        State.autoPlay = asBoolean(v)
        if State.autoPlay then State.autoConnect = false end
    end
    local function setAutoConnect(v)
        State.autoConnect = asBoolean(v)
        if State.autoConnect then State.autoPlay = false end
    end

    GameModeSection:Dropdown({
        Name = "Gamemode",
        Flag = "ServerGamemode",
        Default = "Casual",
        Items = { "Casual", "Standard", "Mobile Casual" },
        MaxSize = 100,
        Callback = function(v)
            State.selectedGameModeName = v
            State.selectedGameMode = GameModeMap[v] or "Casual"
        end
    })

    GameModeSection:Toggle({
        Name = "Join Highest Player Posible",
        Flag = "JoinHighestPlayers",
        Default = true,
        Callback = function(v)
            State.joinHighestPlayers = asBoolean(v)
        end
    })

    local regionDefaults = {
        SG = true, NL = false, DE = false, FR = false,
        BR = false, US = true, AU = true, JP = true, HK = false
    }
    for _, r in ipairs({ "SG", "NL", "DE", "FR", "BR", "US", "AU", "JP", "HK" }) do
        RegionSection:Toggle({
            Name = r,
            Flag = "Region_" .. r,
            Default = regionDefaults[r],
            Callback = function(v)
                State.enabledRegions[r] = asBoolean(v)
            end
        })
    end

    ActionSection:Toggle({
        Name = "Auto Connect Selected Server",
        Flag = "AutoConnectSelectedServer",
        Default = false,
        Callback = setAutoConnect
    })

    ActionSection:Toggle({
        Name = "Auto Play Random Server",
        Flag = "AutoPlayRandomServer",
        Default = false,
        Callback = setAutoPlay
    })

    ActionSection:Toggle({
        Name = "Auto Rejoin If Stuck",
        Flag = "AutoRejoinIfStuck",
        Default = true,
        Callback = function(v)
            State.autoRejoin = asBoolean(v)
        end
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
        Callback = function(v)
            State.autoRejoinSeconds = math.clamp(math.floor((tonumber(v) or 40) + 0.5), 1, 59)
        end
    })

    FreezeSection:Slider({
        Name = "Freeze Time",
        Flag = "FreezeTimeSeconds",
        Min = 1,
        Default = 10,
        Max = 59,
        Suffix = "s",
        Decimals = 1,
        Increment = 1,
        Callback = function(v)
            State.freezeSeconds = math.clamp(math.floor((tonumber(v) or 10) + 0.5), 1, 59)
        end
    })

    FreezeSection:Button({
        Name = "Start The Timer",
        Callback = function()
            local dur = math.clamp(tonumber(State.freezeSeconds) or 10, 1, 59)
            State.manualFreezeUntil = tick() + dur
            Library:Notification("Freeze started for " .. tostring(dur) .. "s (joining paused)", 2)
            task.spawn(function()
                local prev = -1
                while tick() < State.manualFreezeUntil do
                    local rem = math.max(0, math.ceil(State.manualFreezeUntil - tick()))
                    if rem ~= prev and (rem <= 5 or rem % 5 == 0) then
                        prev = rem
                        Library:Notification("Freeze: " .. tostring(rem) .. "s left", 1)
                    end
                    task.wait(0.25)
                end
                Library:Notification("Freeze ended", 2)
            end)
        end
    })

    -- 自动循环
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
            local lastTeleport = 0
            local lastShown = -1
            local wasPaused = false
            while task.wait(0.2) do
                if not State.autoRejoin then
                    elapsed = 0
                    lastClock = os.clock()
                    lastShown = -1
                    wasPaused = false
                else
                    local manual = isManualFreezeActive()
                    local detected = isDetectedFreezeActive()
                    if manual or detected then
                        if not wasPaused then
                            wasPaused = true
                            Library:Notification(
                                manual and "Auto Rejoin timer paused (Freeze active)" or "Auto Rejoin timer paused (freeze detected)",
                                2
                            )
                        end
                        elapsed = 0
                        lastClock = os.clock()
                        lastShown = -1
                    else
                        if wasPaused then
                            wasPaused = false
                            Library:Notification("Freeze ended (Auto Rejoin timer restarted)", 2)
                        end
                        local nowT = os.clock()
                        elapsed = elapsed + math.max(0, nowT - lastClock)
                        lastClock = nowT
                        local timeout = math.clamp(math.floor((tonumber(State.autoRejoinSeconds) or 40) + 0.5), 1, 59)
                        local rem = math.max(0, math.ceil(timeout - elapsed))
                        if rem ~= lastShown and (rem <= 5 or rem % 5 == 0) then
                            lastShown = rem
                            Library:Notification("Auto Rejoin in " .. tostring(rem) .. "s", 1)
                        end
                        if elapsed >= timeout and nowT - lastTeleport >= 15 then
                            elapsed = 0
                            lastShown = -1
                            lastTeleport = nowT
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

-- ==================== 第2段结束 ====================
-- ===================================================================
--  合并脚本：Criminality Farm + Server  (第3段/共4段)
--  此段包含 Farm 的常量、变量、核心辅助函数。
-- ===================================================================

-- Farm 常量
local FARM_API_BASE = "https://getjx.onrender.com"
local FARM_VERIFY_PATH = "/api/jx/keys/verify"
local FARM_PUBLIC_CONFIG_PATH = "/api/jx/public/config"
local FARM_WEBHOOK_PROXY_URL = "https://jx3e.onrender.com/webhook/discord"
local FARM_AUTH_TOKEN_URL = "https://jx3e.onrender.com/auth/token"
local FARM_DATA_DIRECTORY = "JX-CRIMINALITY-FARM"
local FARM_CONFIG_DIRECTORY = "JX-CRIMINALITY-FARM/Configs"
local FARM_ASSET_DIRECTORY = "JX-CRIMINALITY-FARM/Assets"
local FARM_EARN_MONEY_FILE = "JX-CRIMINALITY-FARM/JX_EarnMoney.txt"
local FARM_RUNTIME_STATE_FILE = "JX-CRIMINALITY-FARM/runtime_state.txt"
local FARM_WAYPOINT_SPACING = 3
local FARM_PICKUP_DISTANCE = 8
local FARM_TICK_SECONDS = 0.20
local FARM_IDLE_WAIT_SECONDS = 0.30
local FARM_DEAD_WAIT_SECONDS = 1.50
local FARM_RETRY_WAIT_SECONDS = 1.00
local FARM_BETWEEN_TARGETS_SECONDS = 0.50
local FARM_RECOVERY_IDLE_SECONDS = 8.00
local FARM_SHOP_PRE_OPEN_SECONDS = 0.75
local FARM_SHOP_AFTER_OPEN_SECONDS = 0.45
local FARM_SHOP_BUY_POLL_SECONDS = 0.05
local FARM_SHOP_BUY_MAX_WAIT_SECONDS = 10.00
local FARM_SHOP_POST_BUY_SECONDS = 1.00
local FARM_MONEY_SEARCH_RADIUS = 42
local FARM_MONEY_COLLECT_MAX_PASSES = 18
local FARM_PATH_MAX_PARAM_ATTEMPTS = 19
local FARM_IGNORE_DURATION = 6
local FARM_TARGET_Y = 4.8
local FARM_DEFAULT_MOVE_SPEED = 32
local FARM_DEFAULT_NOTIFY_MINUTES = 1
local FARM_API_KEY = ""
local FARM_PICKUP_REMOTE_NAME = "CZDPZUS"
local FARM_WINDOW_NAME = "JX | Criminality | FARM | Dsc.gg/getjxs"

-- Farm 变量
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
local notifyMinutes = FARM_DEFAULT_NOTIFY_MINUTES
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
local moveSpeed = FARM_DEFAULT_MOVE_SPEED
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

-- Farm 基础函数
local function farmPostJson(path, body)
    if not Request then return nil, "executor_request_missing" end
    local ok, resp = pcall(Request, {
        Url = FARM_API_BASE .. path,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = jsonEncode(body or {})
    })
    if not ok or not resp then return nil, "no_response" end
    return jsonDecode(resp.Body or "{}"), nil
end
local function farmGetHwid()
    local candidates = { rawget(_G, "gethwid"), rawget(_G, "get_hwid") }
    for _, c in ipairs(candidates) do
        if type(c) == "function" then
            local ok, v = pcall(c)
            if ok and v ~= nil then return tostring(v) end
        end
    end
    local ok, analytics = pcall(game.GetService, game, "RbxAnalyticsService")
    if ok and analytics then
        local idOk, v = pcall(analytics.GetClientId, analytics)
        if idOk then return tostring(v) end
    end
    return "unknown-hwid"
end
local function farmParseRuntimeState(text)
    if type(text) ~= "string" then return end
    local savedAutoNotify = text:match("AutoNotify:(%d+)")
    local savedNotifyMinutes = text:match("NotifyMinutes:(%d+%.?%d*)")
    local savedEarnMoney = text:match("EarnMoney:(%d+%.?%d*)")
    local savedWebhook = text:match("Webhook:([^\r\n]*)")
    if savedAutoNotify then autoNotify = savedAutoNotify == "1" end
    if savedNotifyMinutes then notifyMinutes = math.floor(math.max(1, tonumber(savedNotifyMinutes) or FARM_DEFAULT_NOTIFY_MINUTES)) end
    if savedEarnMoney then earnedMoneyTotal = tonumber(savedEarnMoney) or 0 end
    if savedWebhook then webhookUrl = savedWebhook end
end
local function farmSerializeRuntimeState()
    return table.concat({
        "EarnMoney:" .. tostring(math.floor(earnedMoneyTotal)),
        "Webhook:" .. tostring(webhookUrl):gsub("[\r\n]", ""),
        "AutoNotify:" .. (autoNotify and "1" or "0"),
        "NotifyMinutes:" .. tostring(math.floor(math.max(1, notifyMinutes))),
    }, "\n")
end
local function farmLoadRuntimeState()
    farmParseRuntimeState(safeRead(FARM_RUNTIME_STATE_FILE))
    local earned = tonumber(safeRead(FARM_EARN_MONEY_FILE) or "")
    if earned then earnedMoneyTotal = earned end
end
local function farmSaveRuntimeState()
    ensureFolder(FARM_DATA_DIRECTORY)
    safeWrite(FARM_RUNTIME_STATE_FILE, farmSerializeRuntimeState())
    safeWrite(FARM_EARN_MONEY_FILE, tostring(math.floor(earnedMoneyTotal)))
end

local function farmGetCharacter() return LocalPlayer.Character end
local function farmGetHumanoid(char) char = char or farmGetCharacter(); return char and char:FindFirstChildOfClass("Humanoid") or nil end
local function farmGetRootPart(char) char = char or farmGetCharacter(); return char and char:FindFirstChild("HumanoidRootPart") or nil end
local function farmIsDead() local h = farmGetHumanoid(); return h == nil or h.Health <= 0 end
local function farmShowNotification(title, message, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "JX"),
            Text = tostring(message or ""),
            Duration = tonumber(duration) or 3
        })
    end)
end
local function farmRestoreCharacterCollision()
    local char = farmGetCharacter()
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
            obj.CanCollide = true
        end
    end
end

-- Invisibility (Farm)
local invisHeartbeatConnection, invisCharacterConnection, invisWarningGui, invisWarningLabel, invisAnimation, invisTrack
local function farmEnsureInvisWarningGui()
    if invisWarningGui and invisWarningGui.Parent then return invisWarningGui, invisWarningLabel end
    local existing = CoreGui:FindFirstChild("JXInvisWarningGUI") or CoreGui:FindFirstChild("InvisWarningGUI") or CoreGui:FindFirstChild("WarningGUI")
    if existing then
        invisWarningGui = existing
        invisWarningLabel = existing:FindFirstChildWhichIsA("TextLabel", true)
        return invisWarningGui, invisWarningLabel
    end
    invisWarningGui = Instance.new("ScreenGui")
    invisWarningGui.Name = "JXInvisWarningGUI"
    invisWarningGui.ResetOnSpawn = false
    invisWarningGui.Parent = CoreGui
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
local function farmSetVisibleBodyTransparency(char, from, to)
    if not char then return end
    for _, inst in ipairs(char:GetDescendants()) do
        if inst:IsA("BasePart") and inst.Name ~= "HumanoidRootPart" and (from == nil or inst.Transparency == from) then
            if from ~= nil or inst.Transparency ~= 1 then
                inst.Transparency = to
            end
        end
    end
end
local function farmStopInvisTrack()
    if invisTrack then
        pcall(function() invisTrack:Stop() end)
        invisTrack = nil
    end
end
local function farmUpdateInvisCharacter()
    if not invisEnabled then return end
    local char = farmGetCharacter()
    local hum = farmGetHumanoid(char)
    local root = farmGetRootPart(char)
    if not char or not hum or not root then return end
    local torso = char:FindFirstChild("Torso")
    if not torso then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    camera.CameraSubject = root
    if invisWarningLabel then invisWarningLabel.Visible = hum.FloorMaterial == Enum.Material.Air end
    local _, yaw = camera.CFrame:ToOrientation()
    root.CFrame = CFrame.new(root.Position) * CFrame.fromOrientation(0, yaw, 0)
    root.CFrame = root.CFrame * CFrame.Angles(math.rad(90), 0, 0)
    hum.CameraOffset = Vector3.new(0, 1.44, 0)
    invisAnimation = invisAnimation or Instance.new("Animation")
    invisAnimation.AnimationId = "rbxassetid://215384594"
    farmStopInvisTrack()
    local ok, track = pcall(function() return hum:LoadAnimation(invisAnimation) end)
    if ok and track then
        invisTrack = track
        track.Priority = Enum.AnimationPriority.Action4
        track:Play()
        track:AdjustSpeed(0)
        track.TimePosition = 0.3
    end
    RunService.RenderStepped:Wait()
    farmStopInvisTrack()
    local look = camera.CFrame.LookVector
    local horiz = Vector3.new(look.X, 0, look.Z)
    if horiz.Magnitude > 0 then
        horiz = horiz.Unit
        root.CFrame = CFrame.new(root.Position, root.Position + horiz)
    end
    farmSetVisibleBodyTransparency(char, nil, 0.5)
end
local function farmEnsureInvisHeartbeat()
    if invisHeartbeatConnection then return end
    invisHeartbeatConnection = RunService.Heartbeat:Connect(function()
        if invisEnabled then
            pcall(farmUpdateInvisCharacter)
        elseif invisWarningLabel then
            invisWarningLabel.Visible = false
        end
    end)
end
local function farmInvisEnable()
    local char = farmGetCharacter()
    if not char or not char:FindFirstChild("Torso") then return false end
    userWantsInvis = true
    invisEnabled = true
    farmEnsureInvisWarningGui()
    farmEnsureInvisHeartbeat()
    local root = farmGetRootPart(char)
    local camera = workspace.CurrentCamera
    if camera and root then camera.CameraSubject = root end
    pcall(farmUpdateInvisCharacter)
    return true
end
local function farmInvisDisable()
    userWantsInvis = false
    invisEnabled = false
    farmStopInvisTrack()
    local char = farmGetCharacter()
    local hum = farmGetHumanoid(char)
    local camera = workspace.CurrentCamera
    if hum then hum.CameraOffset = Vector3.zero end
    if camera and hum then camera.CameraSubject = hum end
    farmSetVisibleBodyTransparency(char, 0.5, 0)
    if invisWarningLabel then invisWarningLabel.Visible = false end
    return true
end
local function farmSetInvisible(enabled)
    return enabled and farmInvisEnable() or farmInvisDisable()
end
invisCharacterConnection = LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid", 10)
    char:WaitForChild("HumanoidRootPart", 10)
    if userWantsInvis then
        waitSeconds(0.1)
        farmInvisEnable()
    end
end)

-- No Fall (Farm)
local noFallHookInstalled = false
local noFallHeartbeatConnection
local function farmApplyNoFallCharacterState()
    local char = farmGetCharacter()
    if not char then return end
    local charStats = char:FindFirstChild("CharStats")
    if not charStats then return end
    local playerStats = charStats:FindFirstChild(LocalPlayer.Name) or charStats:FindFirstChild(tostring(LocalPlayer.UserId)) or charStats
    local ragdollSwitch = playerStats:FindFirstChild("RagdollSwitch") or charStats:FindFirstChild("RagdollSwitch", true)
    local ragdollTime = playerStats:FindFirstChild("RagdollTime") or charStats:FindFirstChild("RagdollTime", true)
    if noFallEnabled then
        if ragdollSwitch and ragdollSwitch:IsA("BoolValue") then ragdollSwitch.Value = false end
        if ragdollTime and (ragdollTime:IsA("NumberValue") or ragdollTime:IsA("IntValue")) then ragdollTime.Value = 0 end
    end
end
local function farmInstallNoFallHook()
    if noFallHookInstalled then return true end
    if type(hookmetamethod) ~= "function" or type(newcclosure) ~= "function" or type(getnamecallmethod) ~= "function" then return false end
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local events = ReplicatedStorage:FindFirstChild("Events")
        local fallRemote = events and events:FindFirstChild("__RZDONL")
        if noFallEnabled and method == "FireServer" and self == fallRemote and select(1, ...) == "FlllD" then
            return nil
        end
        return oldNamecall(self, ...)
    end))
    noFallHookInstalled = true
    return true
end
local function farmSetNoFall(enabled)
    noFallEnabled = enabled == true
    if noFallHeartbeatConnection then
        noFallHeartbeatConnection:Disconnect()
        noFallHeartbeatConnection = nil
    end
    if noFallEnabled then
        farmInstallNoFallHook()
        farmApplyNoFallCharacterState()
        noFallHeartbeatConnection = RunService.Heartbeat:Connect(function()
            pcall(farmApplyNoFallCharacterState)
        end)
    end
    return noFallEnabled
end

local function farmRespawnCharacter()
    local char = farmGetCharacter()
    local hum = farmGetHumanoid(char)
    if hum and hum.Health > 0 then return true end
    return pcall(function() LocalPlayer:LoadCharacter() end)
end
local function farmAutoRespawnLoop(runId)
    while farmEnabled and farmRunId == runId do
        characterDead = farmIsDead()
        if autoRespawn and characterDead then
            deathCount = deathCount + 1
            pcall(farmRespawnCharacter)
            waitSeconds(FARM_DEAD_WAIT_SECONDS)
        else
            waitSeconds(0.5)
        end
    end
end

-- Anti Rejoin (Farm)
local antiRejoinInstalled = false
local antiRejoinBusy = false
local antiRejoinConnections = {}
local function farmReadErrorPromptText()
    local robloxPromptGui = CoreGui:FindFirstChild("RobloxPromptGui")
    local promptOverlay = robloxPromptGui and robloxPromptGui:FindFirstChild("promptOverlay")
    local errorPrompt = promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt")
    if not errorPrompt or not errorPrompt.Visible then return "" end
    local parts = {}
    for _, desc in ipairs(errorPrompt:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Visible and desc.Text ~= "" then
            parts[#parts + 1] = desc.Text
        end
    end
    return table.concat(parts, " ")
end
local function farmShouldRejoinFromError(msg)
    local lower = tostring(msg or ""):lower()
    if lower == "" then return false end
    for _, f in ipairs({ "kicked", "disconnect", "connection", "error code", "same account", "teleport failed", "server shut", "shutdown" }) do
        if lower:find(f, 1, true) then return true end
    end
    return false
end
local function farmAttemptRejoin(msg)
    if not antiRejoin or antiRejoinBusy or not farmShouldRejoinFromError(msg) then return false end
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
local function farmInstallAntiRejoin()
    if antiRejoinInstalled then return true end
    antiRejoinConnections[#antiRejoinConnections + 1] = GuiService.ErrorMessageChanged:Connect(function(msg)
        farmAttemptRejoin(msg)
    end)
    antiRejoinConnections[#antiRejoinConnections + 1] = RunService.Heartbeat:Connect(function()
        if not antiRejoin then return end
        local msg = farmReadErrorPromptText()
        if msg ~= "" then farmAttemptRejoin(msg) end
    end)
    antiRejoinInstalled = true
    return true
end

-- ==================== 第3段结束 ====================
-- ===================================================================
--  合并脚本：Criminality Farm + Server  (第4段/共4段)  —— 最终段
--  包含 Farm 的核心破坏、移动、收集、UI 和启动函数。
-- ===================================================================

-- Farm 核心：金钱收集
local function farmFindMoneyContainer()
    local filter = workspace:FindFirstChild("Filter")
    return filter and filter:FindFirstChild("SpawnedBread") or nil
end
local function farmGetMoneyTargets(radius)
    radius = tonumber(radius) or FARM_MONEY_SEARCH_RADIUS
    local root = farmGetRootPart()
    local container = farmFindMoneyContainer()
    if not root or not container then return {} end
    local result = {}
    for _, model in ipairs(container:GetChildren()) do
        local mainPart = model:FindFirstChild("MainPart")
        if mainPart and mainPart:IsA("BasePart") then
            local dist = (mainPart.Position - root.Position).Magnitude
            if dist <= radius then
                table.insert(result, { model = model, part = mainPart, distance = dist })
            end
        end
    end
    table.sort(result, function(a, b) return a.distance < b.distance end)
    return result
end
local function farmFindRuntimeEventsContainer()
    local direct = ReplicatedStorage:FindFirstChild("Events") or workspace:FindFirstChild("Events")
    if direct then return direct end
    for _, c in ipairs({ ReplicatedStorage, workspace }) do
        local found = c:FindFirstChild("Events", true)
        if found then return found end
    end
    return nil
end
local function farmFirePickupEvent(target)
    local events = farmFindRuntimeEventsContainer()
    local remote = events and events:FindFirstChild(FARM_PICKUP_REMOTE_NAME, true)
    local cashDrop = target and (target.model or target.part)
    if not remote or not remote:IsA("RemoteEvent") or not cashDrop then
        return false, "pickup_remote_missing"
    end
    return pcall(remote.FireServer, remote, cashDrop)
end
local function farmCollectMoneyTarget(target)
    if not target or not target.part then return false end
    local root = farmGetRootPart()
    if not root then return false end
    local moved = pcall(function()
        root.CFrame = target.part.CFrame + Vector3.new(0, 2, 0)
    end)
    if moved then
        farmLastMoveAt = now()
        waitSeconds(0.10)
    end
    local fired = farmFirePickupEvent(target)
    if fired then waitSeconds(0.05) end
    return moved or fired
end
local function farmCollectNearbyMoney()
    if not autoMoney then return end
    for _ = 1, FARM_MONEY_COLLECT_MAX_PASSES do
        local targets = farmGetMoneyTargets(FARM_MONEY_SEARCH_RADIUS)
        if #targets == 0 then break end
        for _, t in ipairs(targets) do
            if not farmEnabled then return end
            pcall(farmCollectMoneyTarget, t)
        end
    end
end

-- Farm 目标相关
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

local function farmIsTemporarilyIgnored(model)
    local untilTime = temporarilyIgnoredTargets[model]
    if untilTime == nil then return false end
    if now() >= untilTime then
        temporarilyIgnoredTargets[model] = nil
        return false
    end
    return true
end
local function farmIgnoreTarget(model, duration)
    temporarilyIgnoredTargets[model] = now() + (duration or FARM_IGNORE_DURATION)
end
local function farmGetTargetPart(model)
    if not model or not model.Parent then return nil end
    return model:FindFirstChild("MainPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end
local function farmTargetIsBroken(model)
    local values = model and model:FindFirstChild("Values")
    local broken = values and values:FindFirstChild("Broken")
    return broken and broken.Value == true or false
end
local function farmClassifyTargetZone(model, part)
    if not part then return "Normal" end
    local lowerName = tostring(model.Name):lower()
    local position = part.Position
    if lowerName:find("sw11", 1, true) or (position - SW11_SECOND_POSITION).Magnitude < 450 then
        return "SW11"
    end
    if lowerName:find("tower", 1, true) or (position - TOWER_FIRST_POSITION).Magnitude < 450 then
        return "Tower"
    end
    if lowerName:find("su", 1, true) or (position - SU_FIRST_POSITION).Magnitude < 500 or (position - SU_LOW_POSITION).Magnitude < 500 then
        return "SU"
    end
    return "Normal"
end
local function farmFindCandidateTargets()
    local result = {}
    local seen = {}
    local map = workspace:FindFirstChild("Map")
    local containers = {}
    if map then
        local parts = map:FindFirstChild("Parts")
        local mappedParts = map:FindFirstChild("M_Parts")
        if parts then containers[#containers + 1] = parts end
        if mappedParts and mappedParts ~= parts then containers[#containers + 1] = mappedParts end
        if #containers == 0 then containers[#containers + 1] = map end
    end
    for _, container in ipairs(containers) do
        for _, object in ipairs(container:GetDescendants()) do
            if object:IsA("Model") and not seen[object] and not farmIsTemporarilyIgnored(object) and not processedTargets[object] then
                local part = farmGetTargetPart(object)
                local values = object:FindFirstChild("Values")
                local broken = values and values:FindFirstChild("Broken")
                if part and values and broken and broken.Value ~= true then
                    seen[object] = true
                    table.insert(result, {
                        obj = object,
                        part = part,
                        zone = farmClassifyTargetZone(object, part)
                    })
                end
            end
        end
    end
    local root = farmGetRootPart()
    if root then
        table.sort(result, function(a, b)
            return (a.part.Position - root.Position).Magnitude < (b.part.Position - root.Position).Magnitude
        end)
    end
    sortedTargets = result
    return result
end

local function farmTweenRootTo(position, targetCFrame)
    local root = farmGetRootPart()
    if not root then return false, "root_missing" end
    local distance = (position - root.Position).Magnitude
    local duration = math.max(0.05, distance / math.max(1, moveSpeed))
    local destination = targetCFrame or CFrame.new(position + Vector3.new(0, 3, 0))
    actionInProgress = true
    farmLastMoveAt = now()
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = destination })
    local completed = false
    local playbackState
    local connection = tween.Completed:Connect(function(state)
        playbackState = state
        completed = true
    end)
    tween:Play()
    local startedAt = now()
    while farmEnabled and not completed and now() - startedAt < duration + 2 do
        if farmIsDead() then
            tween:Cancel()
            break
        end
        waitSeconds(0.05)
    end
    connection:Disconnect()
    actionInProgress = false
    return completed and playbackState == Enum.PlaybackState.Completed, completed and "success" or "timeout"
end
local function farmBuildWaypointPath(fromPosition, toPosition)
    local path = PathfindingService:CreatePath({ WaypointSpacing = FARM_WAYPOINT_SPACING })
    local ok = pcall(path.ComputeAsync, path, fromPosition, toPosition)
    if not ok or path.Status ~= Enum.PathStatus.Success then return { toPosition } end
    local points = {}
    for _, waypoint in ipairs(path:GetWaypoints()) do
        points[#points + 1] = waypoint.Position
    end
    if #points == 0 then points[1] = toPosition end
    return points
end
local function farmFollowWaypointPath(points)
    for _, position in ipairs(points) do
        if not farmEnabled or farmIsDead() then return false, "stopped" end
        local ok, reason = farmTweenRootTo(position)
        if not ok then return false, reason end
    end
    return true, "success"
end
local function farmMoveToSpecialEntry(position)
    local root = farmGetRootPart()
    if not root or not position then return false end
    local points = farmBuildWaypointPath(root.Position, position)
    return farmFollowWaypointPath(points)
end
local function farmHandleSpecialSUPath(model)
    local targetPart = farmGetTargetPart(model)
    if not targetPart then return false, "missing_part" end
    if not suZoneEntered then
        farmMoveToSpecialEntry(SU_FIRST_POSITION)
        suZoneEntered = true
    end
    local root = farmGetRootPart()
    if root then
        local lowDist = (root.Position - SU_LOW_POSITION).Magnitude
        local highDist = (root.Position - SU_HIGH_POSITION).Magnitude
        farmMoveToSpecialEntry(lowDist < highDist and SU_LOW_POSITION or SU_HIGH_POSITION)
    end
    return farmTweenRootTo(targetPart.Position, targetPart.CFrame + Vector3.new(0, 3, 0))
end
local function farmHandleTowerPath(model)
    local targetPart = farmGetTargetPart(model)
    if not targetPart then return false, "missing_part" end
    if not towerZoneEntered then
        farmMoveToSpecialEntry(TOWER_FIRST_POSITION)
        towerZoneEntered = true
    end
    return farmTweenRootTo(targetPart.Position, targetPart.CFrame + Vector3.new(0, 3, 0))
end
local function farmHandleSW11Path(model)
    local targetPart = farmGetTargetPart(model)
    if not targetPart then return false, "missing_part" end
    if not sw11ZoneEntered then
        local root = farmGetRootPart()
        if root then
            sw11SavedEntryPathPoint = root.Position
            sw11SavedVisualPath = farmBuildWaypointPath(root.Position, SW11_FIRST_POSITION)
        end
        if sw11SavedVisualPath then farmFollowWaypointPath(sw11SavedVisualPath) end
        farmMoveToSpecialEntry(SW11_SECOND_POSITION)
        sw11ZoneEntered = true
    end
    return farmTweenRootTo(targetPart.Position, targetPart.CFrame + Vector3.new(0, 3, 0))
end
local function farmMoveToTarget(model)
    local targetPart = farmGetTargetPart(model)
    if not targetPart then return false, "missing_part" end
    reachedTargetY = false
    local zone = farmClassifyTargetZone(model, targetPart)
    local ok, reason
    if zone == "SU" then
        ok, reason = farmHandleSpecialSUPath(model)
    elseif zone == "Tower" then
        ok, reason = farmHandleTowerPath(model)
    elseif zone == "SW11" then
        ok, reason = farmHandleSW11Path(model)
    else
        ok, reason = farmTweenRootTo(targetPart.Position, targetPart.CFrame + Vector3.new(0, 3, 0))
    end
    reachedTargetY = ok == true
    return ok, reason
end
local function farmProcessTargetMoveOutcome(model, ok, reason)
    if ok then
        forcedNextTargetModel = nil
        waitSeconds(FARM_BETWEEN_TARGETS_SECONDS)
        return true
    end
    farmIgnoreTarget(model, FARM_IGNORE_DURATION)
    retargetPending = true
    waitSeconds(FARM_RETRY_WAIT_SECONDS)
    retargetPending = false
    return false, reason
end
local function farmChooseNextTarget()
    if forcedNextTargetModel and forcedNextTargetModel.Parent and not farmIsTemporarilyIgnored(forcedNextTargetModel) and not farmTargetIsBroken(forcedNextTargetModel) then
        return forcedNextTargetModel
    end
    local targets = farmFindCandidateTargets()
    local first = targets[1]
    return first and first.obj or nil
end

-- Farm 商店 / 工具 / 破坏
local function farmParseCashTextToNumber(value)
    if type(value) == "number" then return value end
    local text = tostring(value or ""):gsub(",", ""):gsub("%$", ""):gsub("%s+", "")
    return tonumber(text:match("%-?%d+%.?%d*")) or 0
end
local function farmFindCashDisplayObject()
    local coreGui = PlayerGui:FindFirstChild("CoreGUI")
    if not coreGui then return nil end
    local candidates = { "Cash", "CashLabel", "CashAmount", "Money", "MoneyLabel", "CashAddedText" }
    for _, name in ipairs(candidates) do
        local obj = coreGui:FindFirstChild(name, true)
        if obj then return obj end
    end
    return nil
end
local function farmReadCashAmountText()
    local obj = farmFindCashDisplayObject()
    if not obj then return "" end
    local ok, val = pcall(function()
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then return obj.Text end
        if obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("StringValue") then return obj.Value end
        return obj.Text or obj.Value
    end)
    return ok and tostring(val or "") or ""
end
local function farmReadCashAmountValue()
    return farmParseCashTextToNumber(farmReadCashAmountText())
end

local function farmFindToolByName(name)
    local char = farmGetCharacter()
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
local function farmEquipTool(tool)
    if not tool then return false end
    local char = farmGetCharacter()
    local hum = farmGetHumanoid(char)
    if not char or not hum then return false end
    if tool.Parent == char then return true end
    local ok = pcall(hum.EquipTool, hum, tool)
    return ok and tool.Parent == char
end
local function farmGetShopMainPart(name)
    local map = workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    local shop = shopz and shopz:FindFirstChild(name)
    return shop and shop:FindFirstChild("MainPart") or nil
end
local function farmBuyCrowbar()
    local existing = farmFindToolByName("Crowbar")
    if existing then
        farmEquipTool(existing)
        return true
    end
    local events = ReplicatedStorage:FindFirstChild("Events")
    local dealerPart = farmGetShopMainPart("Dealer")
    local protectionRemote = events and events:FindFirstChild("BYZERSPROTEC")
    local purchaseRemote = events and events:FindFirstChild("SSHPRMTE1")
    if not dealerPart or not protectionRemote or not purchaseRemote then return false end
    local moved = farmTweenRootTo(dealerPart.Position, dealerPart.CFrame + Vector3.new(0, 3, 0))
    if not moved then return false end
    pcall(protectionRemote.FireServer, protectionRemote, true, "shop", dealerPart, "IllegalStore")
    local invokeOk, accepted, message = pcall(purchaseRemote.InvokeServer, purchaseRemote, "IllegalStore", "Melees", "Crowbar", dealerPart, nil, true)
    pcall(protectionRemote.FireServer, protectionRemote, false)
    waitSeconds(FARM_SHOP_POST_BUY_SECONDS)
    local tool = farmFindToolByName("Crowbar")
    if tool then farmEquipTool(tool) end
    return invokeOk and (accepted == true or message == "PURCHASE COMPLETE" or tool ~= nil)
end
local function farmCountToolsByName(name)
    local total = 0
    local char = farmGetCharacter()
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    for _, container in ipairs({ char, backpack }) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and item.Name == name then total = total + 1 end
            end
        end
    end
    return total
end
local function farmFindNearestLockpickShopPart()
    local root = farmGetRootPart()
    local selected, selectedDist = nil, math.huge
    for _, name in ipairs({ "ArmoryDealer", "Dealer" }) do
        local part = farmGetShopMainPart(name)
        if part then
            local dist = root and (part.Position - root.Position).Magnitude or 0
            if dist < selectedDist then
                selected = part
                selectedDist = dist
            end
        end
    end
    return selected
end
local function farmPurchaseLockpickAt(shopPart)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local purchaseRemote = events and events:FindFirstChild("SSHPRMTE1")
    if not shopPart or not purchaseRemote then return false end
    local illegalOk, illegalAccepted, illegalMessage = pcall(purchaseRemote.InvokeServer, purchaseRemote, "IllegalStore", "Misc", "Lockpick", shopPart, nil, true, nil)
    waitSeconds(0.25)
    local legalOk, legalAccepted, legalMessage = pcall(purchaseRemote.InvokeServer, purchaseRemote, "LegalStore", "Misc", "Lockpick", shopPart, nil, true)
    return illegalOk and (illegalAccepted == true or illegalMessage == "PURCHASE COMPLETE") or legalOk and (legalAccepted == true or legalMessage == "PURCHASE COMPLETE")
end
local function farmBuyLockpickBatch(quantity)
    quantity = math.max(1, math.floor(tonumber(quantity) or 7))
    local shopPart = farmFindNearestLockpickShopPart()
    if not shopPart then return false end
    if not farmTweenRootTo(shopPart.Position, shopPart.CFrame + Vector3.new(0, 3, 0)) then return false end
    local startingCount = farmCountToolsByName("Lockpick")
    local successful = 0
    for _ = 1, quantity do
        if not farmEnabled then break end
        if farmPurchaseLockpickAt(shopPart) then successful = successful + 1 end
        waitSeconds(0.20)
    end
    waitSeconds(0.75)
    return farmCountToolsByName("Lockpick") > startingCount or successful > 0
end
local function farmDropLockpick(tool)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local dropRemote = events and events:FindFirstChild("PAZ_TA")
    local root = farmGetRootPart()
    if not tool or not dropRemote or not root then return false end
    return pcall(dropRemote.FireServer, dropRemote, tool, nil, root.Position)
end
local function farmTryLockpickTarget(target)
    local tool = farmFindToolByName("Lockpick")
    if not tool then return false, "lockpick_missing" end
    if not farmEquipTool(tool) then return false, "lockpick_equip_failed" end
    local remote = tool:FindFirstChild("Remote")
    if not remote or not remote:IsA("RemoteFunction") then return false, "lockpick_remote_missing" end
    local startOk, token = pcall(remote.InvokeServer, remote, "S", target, "s")
    if startOk and type(token) == "number" then
        waitSeconds(0.25)
        local finishOk = pcall(remote.InvokeServer, remote, "D", target, "s", token)
        return finishOk, finishOk and "lockpick_success" or "lockpick_finish_failed"
    end
    farmDropLockpick(tool)
    return false, "lockpick_failed"
end
local function farmStrikeTargetWithCrowbar(target)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local startFolder = events and events:FindFirstChild("XMHH")
    local finishFolder = events and events:FindFirstChild("XMHH2")
    local startRemote = startFolder and startFolder:FindFirstChild("2")
    local finishRemote = finishFolder and finishFolder:FindFirstChild("2")
    local tool = farmFindToolByName("Crowbar")
    local char = farmGetCharacter()
    local targetPart = farmGetTargetPart(target)
    local rightArm = char and (char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand"))
    if not startRemote or not finishRemote or not tool or not char or not rightArm or not targetPart then return false end
    farmEquipTool(tool)
    local invokeOk, token = pcall(startRemote.InvokeServer, startRemote, "🍞", now(), tool, "DZDRRRKI", target, "Register")
    if invokeOk and type(token) == "number" then
        return pcall(finishRemote.FireServer, finishRemote, "🍞", now(), tool, "2389ZFX34", token, false, rightArm, targetPart, target, targetPart.Position, targetPart.Position)
    end
    return invokeOk
end
local function farmBreakTarget(target)
    if not target or not target.Parent then return false, "target_removed" end
    if farmTargetIsBroken(target) then return true, "already_broken" end
    if breakingMethod == "Crowbar" then
        if not farmFindToolByName("Crowbar") and not farmBuyCrowbar() then
            return false, "crowbar_unavailable"
        end
        local started = now()
        while farmEnabled and target.Parent and not farmTargetIsBroken(target) and now() - started < 30 do
            local targetPart = farmGetTargetPart(target)
            local root = farmGetRootPart()
            if not targetPart or not root then return false, "missing_part" end
            if (targetPart.Position - root.Position).Magnitude > 8 then
                if not farmMoveToTarget(target) then return false, "movement_failed" end
            end
            farmStrikeTargetWithCrowbar(target)
            waitSeconds(0.25)
        end
    else
        local started = now()
        local nextBatch = 7
        while farmEnabled and target.Parent and not farmTargetIsBroken(target) and now() - started < 120 do
            local targetPart = farmGetTargetPart(target)
            local root = farmGetRootPart()
            if not targetPart or not root then return false, "missing_part" end
            if (targetPart.Position - root.Position).Magnitude > 8 then
                if not farmMoveToTarget(target) then return false, "movement_failed" end
            end
            if not farmFindToolByName("Lockpick") then
                if not farmBuyLockpickBatch(nextBatch) then return false, "lockpick_unavailable" end
                nextBatch = 15
                if target.Parent and not farmTargetIsBroken(target) then farmMoveToTarget(target) end
            end
            local opened = farmTryLockpickTarget(target)
            if opened then
                local completedAt = now()
                while target.Parent and not farmTargetIsBroken(target) and now() - completedAt < 12 do
                    waitSeconds(0.10)
                end
                break
            end
            waitSeconds(1.25)
        end
    end
    if farmTargetIsBroken(target) then
        processedTargets[target] = true
        forcedNextTargetModel = nil
        waitSeconds(FARM_BETWEEN_TARGETS_SECONDS)
        return true, "success"
    end
    return false, "break_timeout"
end

-- Farm 存款/统计/管理
local function farmClearNearbyCashNoMove(radius)
    radius = tonumber(radius) or 15
    local root = farmGetRootPart()
    local spawnedBread = farmFindMoneyContainer()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local collectRemote = events and events:FindFirstChild("CZDPZUS")
    if not root or not spawnedBread or not collectRemote then return 0 end
    local collected = 0
    for _, cashDrop in ipairs(spawnedBread:GetChildren()) do
        local part
        if cashDrop:IsA("BasePart") then
            part = cashDrop
        elseif cashDrop:IsA("Model") then
            part = cashDrop:FindFirstChild("MainPart") or cashDrop.PrimaryPart or cashDrop:FindFirstChildWhichIsA("BasePart", true)
        end
        if part and (part.Position - root.Position).Magnitude <= radius then
            local ok = pcall(collectRemote.FireServer, collectRemote, cashDrop)
            if ok then collected = collected + 1 end
        end
    end
    return collected
end
local function farmReadStatsGui()
    local coreGui = PlayerGui:FindFirstChild("CoreGUI")
    local statsFrame = coreGui and coreGui:FindFirstChild("StatsFrame", true)
    if not statsFrame then return end
    local allowance = statsFrame:FindFirstChild("Allowance", true)
    local bank = statsFrame:FindFirstChild("Bank", true)
    local function parseNumber(obj)
        if not obj then return nil end
        local text = obj.Text or obj.Value or ""
        return tonumber(tostring(text):gsub("[^%d%.%-]", ""))
    end
    allowanceAmount = parseNumber(allowance) or allowanceAmount
    bankAmount = parseNumber(bank) or bankAmount
end
local function farmFindATMMainPart()
    local map = workspace:FindFirstChild("Map")
    local atmz = map and map:FindFirstChild("ATMz")
    local atm = atmz and atmz:FindFirstChild("ATM")
    local mainPart = atm and atm:FindFirstChild("MainPart")
    if mainPart and mainPart:IsA("BasePart") then return mainPart end
    return nil
end
local function farmMoveToPart(part)
    local root = farmGetRootPart()
    if not root or not part then return false end
    actionInProgress = true
    farmLastMoveAt = now()
    local distance = (part.Position - root.Position).Magnitude
    local duration = math.max(0.05, distance / math.max(1, moveSpeed))
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = part.CFrame + Vector3.new(0, 3, 0) })
    local completed = false
    local connection = tween.Completed:Connect(function() completed = true end)
    tween:Play()
    local started = now()
    while (farmEnabled or depositInProgress) and not completed and now() - started < duration + 2 do
        if farmIsDead() then tween:Cancel(); break end
        waitSeconds(0.05)
    end
    connection:Disconnect()
    actionInProgress = false
    return completed
end
local function farmPerformDepositRequest(events, cash)
    local remote = events and events:FindFirstChild("ATM")
    local atmMainPart = farmFindATMMainPart()
    if not remote or not remote:IsA("RemoteFunction") or not atmMainPart then return false end
    if not farmMoveToPart(atmMainPart) then return false end
    local accepted, message, blocked, value = remote:InvokeServer("DP", cash, atmMainPart)
    return accepted == true, message, blocked, value
end
local function farmTryDeposit()
    if not autoDepositEnabled then return false end
    if depositInProgress then return true end
    local currentTime = now()
    if currentTime < (depositCooldownUntil or 0) then return false end
    if currentTime - (depositLastAttemptAt or 0) < 1.5 then return false end
    local cash = farmReadCashAmountValue()
    local threshold = depositThreshold or 5000
    if threshold <= 0 or cash < threshold then return false end
    farmClearNearbyCashNoMove(15)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return false end
    depositLastAttemptAt = now()
    depositInProgress = true
    local ok, accepted = pcall(function()
        local success = farmPerformDepositRequest(events, cash)
        waitSeconds(0.2)
        return success == true and farmReadCashAmountValue() <= 0
    end)
    depositInProgress = false
    depositCooldownUntil = now() + 2.5
    farmActivityStatus = "Idle"
    return ok and accepted == true
end
local function farmTryDepositAllNow()
    local previous = autoDepositEnabled
    autoDepositEnabled = true
    local ok, result = pcall(function()
        local attempts = 0
        while attempts < 100 do
            attempts = attempts + 1
            if farmReadCashAmountValue() <= 0 then return true end
            if farmTryDeposit() then return true end
            waitSeconds(0.25)
        end
        return false
    end)
    autoDepositEnabled = previous
    farmActivityStatus = "Idle"
    return ok and result == true
end
local function farmMaybeAutoDeposit()
    if not autoDepositEnabled then return false end
    return farmTryDeposit()
end

-- Farm 管理函数
local function farmClaimAllowance()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("CLMZALOW")
    local atm = farmFindATMMainPart()
    if not remote or not atm then return false, "allowance_unavailable" end
    local ok, accepted, message, blocked, amount = pcall(remote.InvokeServer, remote, atm)
    if not ok then return false, accepted end
    if type(amount) == "number" then allowanceAmount = amount end
    return accepted == true, message, blocked, amount
end

local function farmSetFlag(name, value)
    if name == "JXFarmEnabled" then
        if value == true then farmStartFarm() else farmStopFarm() end
        return true
    elseif name == "JXFarmAutoRespawn" then
        autoRespawn = value == true
    elseif name == "JXFarmAutoNotify" then
        autoNotify = value == true
    elseif name == "JXFarmAutoPlay" then
        -- 略
    elseif name == "JXFarmAutoDeposit" then
        autoDepositEnabled = value == true
    elseif name == "JXFarmAutoMoney" then
        autoMoney = value == true
    elseif name == "JXFarmAntiRejoin" then
        antiRejoin = value == true
        if antiRejoin then farmInstallAntiRejoin() end
    elseif name == "JXFarmAntiAfk" then
        -- 略
    elseif name == "JXFarmAdminCheck" then
        adminCheckEnabled = value == true
    elseif name == "JXFarmAutoAllowance" then
        autoAllowance = value == true
        if autoAllowance then pcall(farmClaimAllowance) end
    elseif name == "JXFarmInvis" then
        userWantsInvis = value == true
        farmSetInvisible(userWantsInvis)
    elseif name == "CharacterAntiFallDamage" then
        farmSetNoFall(value)
    elseif name == "JXFarmNotifyTimeMinutes" then
        local num = tonumber(value)
        if num then notifyMinutes = math.clamp(math.floor(num + 0.5), 1, 10) end
    elseif name == "JXFarmAutoDepositThresholdK" then
        local num = tonumber(value)
        if num then
            autoDepositThresholdK = math.clamp(math.floor(num + 0.5), 1, 100)
            depositThreshold = autoDepositThresholdK * 1000
        end
    elseif name == "JXFarmSpeedV2" then
        local num = tonumber(value)
        if num then moveSpeed = math.max(1, num) end
    elseif name == "JXFarmBreakingMethod" then
        breakingMethod = tostring(value or "Crowbar")
    elseif name == "JXFarmWebhookURL" then
        webhookUrl = tostring(value or "")
    else
        return false
    end
    return true
end

-- Farm 启动/停止
function farmStopFarm(reason)
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
    if invisEnabled then pcall(farmSetInvisible, false) end
    farmRestoreCharacterCollision()
    farmSaveRuntimeState()
    farmShowNotification("JX Farm", reason or "AutoFarm stopped", 2)
    return reason or "AutoFarm stopped"
end

local function farmIteration()
    farmLastActiveAt = now()
    characterDead = farmIsDead()
    if characterDead then
        waitSeconds(FARM_DEAD_WAIT_SECONDS)
        return
    end
    if noFallEnabled then farmApplyNoFallCharacterState() end
    if userWantsInvis and not invisEnabled then pcall(farmSetInvisible, true)
    elseif not userWantsInvis and invisEnabled then pcall(farmSetInvisible, false) end
    farmReadStatsGui()
    if autoAllowance then pcall(farmClaimAllowance) end
    if autoMoney then pcall(farmCollectNearbyMoney) end
    if autoDepositEnabled then pcall(farmMaybeAutoDeposit) end
    local target = farmChooseNextTarget()
    if not target then
        waitSeconds(FARM_IDLE_WAIT_SECONDS)
        return
    end
    forcedNextTargetModel = target
    local moved, moveReason = farmMoveToTarget(target)
    if not moved then
        farmProcessTargetMoveOutcome(target, false, moveReason)
        return
    end
    local broken, breakReason = farmBreakTarget(target)
    if broken then
        processedTargets[target] = true
        forcedNextTargetModel = nil
        farmActivityStatus = "Idle"
        waitSeconds(FARM_BETWEEN_TARGETS_SECONDS)
        return
    end
    farmIgnoreTarget(target, FARM_IGNORE_DURATION)
    forcedNextTargetModel = nil
    retargetPending = true
    waitSeconds(FARM_RETRY_WAIT_SECONDS)
    retargetPending = false
    if breakReason then farmActivityStatus = tostring(breakReason) end
end

function farmStartFarm()
    if farmEnabled then return false, "already_running" end
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
    if antiRejoin then pcall(farmInstallAntiRejoin) end
    if noFallEnabled then pcall(farmSetNoFall, true) end
    spawnTask(function() -- notifier
        while farmEnabled and farmRunId == runId do
            if autoNotify and webhookUrl ~= "" then
                local cur = now()
                local interval = math.max(1, notifyMinutes) * 60
                if not notifyBusy and cur - notifyLastAt >= interval then
                    notifyBusy = true
                    pcall(function() -- 发送webhook
                        local payload = {
                            username = "JX-CRIMINALITY-FARM",
                            embeds = { {
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
                            } }
                        }
                        if webhookUrl ~= "" then
                            Request({ Url = webhookUrl, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = jsonEncode(payload) })
                        end
                    end)
                    pcall(farmSaveRuntimeState)
                    notifyLastAt = cur
                    notifyBusy = false
                end
            end
            waitSeconds(1)
        end
    end)
    spawnTask(function() farmAutoRespawnLoop(runId) end)
    spawnTask(function()
        while farmEnabled and farmRunId == runId do
            local ok, err = xpcall(farmIteration, debug.traceback)
            if not ok then warn("[JX Farm] iteration error:", err); waitSeconds(FARM_RETRY_WAIT_SECONDS) end
            farmTimeSeconds = now() - startedAt
            waitSeconds(FARM_TICK_SECONDS)
        end
    end)
    farmShowNotification("JX Farm", "AutoFarm started", 2)
    return true
end

-- ==================== 创建 Farm UI ====================
local function farmCreateUI()
    local old = CoreGui:FindFirstChild("JXCriminalityFarm")
    if old then old:Destroy() end
    local screen = Instance.new("ScreenGui")
    screen.Name = "JXCriminalityFarm"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.Parent = CoreGui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Position = UDim2.new(0, 30, 0.5, -260)
    main.Size = UDim2.new(0, 360, 0, 520)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = screen
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -44, 0, 38)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "  " .. FARM_WINDOW_NAME
    title.Parent = main

    local close = Instance.new("TextButton")
    close.Position = UDim2.new(1, -38, 0, 4)
    close.Size = UDim2.new(0, 32, 0, 30)
    close.BackgroundColor3 = Color3.fromRGB(100, 40, 45)
    close.BorderSizePixel = 0
    close.Font = Enum.Font.GothamBold
    close.TextSize = 14
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.Text = "X"
    close.Parent = main
    close.MouseButton1Click:Connect(function() screen.Enabled = false end)

    local scrolling = Instance.new("ScrollingFrame")
    scrolling.Position = UDim2.new(0, 6, 0, 42)
    scrolling.Size = UDim2.new(1, -12, 1, -48)
    scrolling.BackgroundTransparency = 1
    scrolling.BorderSizePixel = 0
    scrolling.ScrollBarThickness = 5
    scrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrolling.Parent = main
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrolling

    -- 辅助函数创建控件
    local function makeToggle(text, flag, default)
        local value = default == true
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.AutoButtonColor = false
        btn.Parent = scrolling
        local function render()
            btn.Text = text .. ": " .. (value and "ON" or "OFF")
            btn.BackgroundColor3 = value and Color3.fromRGB(45, 105, 70) or Color3.fromRGB(35, 35, 42)
        end
        btn.MouseButton1Click:Connect(function()
            value = not value
            farmSetFlag(flag, value)
            render()
        end)
        render()
        farmSetFlag(flag, value)
        return btn
    end
    local function makeTextbox(text, flag, default, numeric)
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, -12, 0, 48)
        holder.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        holder.BorderSizePixel = 0
        holder.Parent = scrolling
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.48, -6, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = text
        label.Parent = holder
        local box = Instance.new("TextBox")
        box.Position = UDim2.new(0.48, 0, 0, 7)
        box.Size = UDim2.new(0.52, -8, 1, -14)
        box.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
        box.BorderSizePixel = 0
        box.ClearTextOnFocus = false
        box.Font = Enum.Font.Code
        box.TextSize = 13
        box.TextColor3 = Color3.fromRGB(240, 240, 240)
        box.Text = tostring(default or "")
        box.Parent = holder
        local function commit()
            local val = box.Text
            if numeric then
                val = tonumber(val)
                if val == nil then box.Text = tostring(default or 0); return end
            end
            farmSetFlag(flag, val)
        end
        box.FocusLost:Connect(commit)
        commit()
        return holder
    end
    local function makeDropdown(text, flag, values, default)
        local index = 1
        for i, v in ipairs(values) do if v == default then index = i; break end end
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.AutoButtonColor = false
        btn.Parent = scrolling
        local function render()
            btn.Text = text .. ": " .. tostring(values[index])
        end
        btn.MouseButton1Click:Connect(function()
            index = index % #values + 1
            farmSetFlag(flag, values[index])
            render()
        end)
        render()
        farmSetFlag(flag, values[index])
        return btn
    end
    local function makeAction(text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(55, 65, 95)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 14
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Text = text
        btn.AutoButtonColor = true
        btn.Parent = scrolling
        btn.MouseButton1Click:Connect(function() spawnTask(function() pcall(callback) end) end)
        return btn
    end

    -- 控件
    makeToggle("Start Farm", "JXFarmEnabled", false)
    makeToggle("Auto Respawn", "JXFarmAutoRespawn", autoRespawn)
    makeToggle("Auto Pickup Money", "JXFarmAutoMoney", autoMoney)
    makeToggle("Auto Deposit", "JXFarmAutoDeposit", autoDepositEnabled)
    makeTextbox("Deposit At (thousands)", "JXFarmAutoDepositThresholdK", depositThreshold / 1000, true)
    makeAction("Deposit Now", farmTryDepositAllNow)
    makeToggle("Auto Claim Allowance", "JXFarmAutoAllowance", autoAllowance)
    makeDropdown("Breaking Method", "JXFarmBreakingMethod", { "Crowbar", "Fist + Lockpick" }, breakingMethod)
    makeTextbox("Move Speed", "JXFarmSpeedV2", moveSpeed, true)
    makeToggle("Hide Body", "JXFarmInvis", userWantsInvis)
    makeToggle("Anti Fall Damage", "CharacterAntiFallDamage", noFallEnabled)
    makeToggle("Anti-AFK", "JXFarmAntiAfk", antiAfkEnabled)
    makeToggle("Anti Error/kick", "JXFarmAntiRejoin", antiRejoin)
    makeToggle("Admin Check", "JXFarmAdminCheck", adminCheckEnabled)
    makeToggle("Auto Play", "JXFarmAutoPlay", autoPlayEnabled)
    makeToggle("Auto Notify", "JXFarmAutoNotify", autoNotify)
    makeTextbox("Notify Time (minutes)", "JXFarmNotifyTimeMinutes", notifyMinutes, true)
    makeTextbox("Webhook URL", "JXFarmWebhookURL", webhookUrl, false)
    makeAction("Save State", farmSaveRuntimeState)
    makeAction("Show Body", farmInvisDisable)
    return main
end

-- ==================== 启动流程 ====================
local function tryLoadSavedSession()
    local device = readDeviceFile()
    if Config.keyless then
        local hwid = device and device.hwid or generateHwid()
        local result = verifyKeySafely(hwid, "")
        if result and result.mode == "keyless" then
            notify("Keyless mode enabled. Loading...", Color3.fromRGB(100, 255, 150))
            task.wait(0.5)
            return true
        end
    end
    if not device or not device.hwid or not device.key or device.key == "" then
        return false
    end
    local result, err = verifyKeySafely(device.hwid, device.key)
    if err == "executor_request_missing" or err == "verify_fn_missing" or err == "verify_fn_error" then
        notify("Executor missing request/verify. Please relaunch.", Color3.fromRGB(255, 100, 100))
        return false
    end
    if result and result.ok and result.valid then
        device.expiresAt = result.expiresAt
        writeDeviceFile(device)
        return true
    end
    if result and result.mode == "keyless" then
        notify("Keyless mode active. Loading...", Color3.fromRGB(100, 255, 150))
        task.wait(0.5)
        return true
    end
    notify("Saved key expired. Please get a new key.", Color3.fromRGB(255, 100, 100))
    return false
end

-- 最终入口
monitorRequestIntegrity()
fetchPublicConfig()
sendExecutionTelemetry()

if not tryLoadSavedSession() then
    createKeySystemGUI(function()
        -- 验证成功后加载
        task.spawn(function()
            loadMainPayload()
            farmLoadRuntimeState()
            farmCreateUI()
            print("JX 合并脚本已加载（Farm + Server）")
        end)
    end)
else
    -- 已有有效Key，直接加载
    task.spawn(function()
        loadMainPayload()
        farmLoadRuntimeState()
        farmCreateUI()
        print("JX 合并脚本已加载（Farm + Server）")
    end)
end

-- ==================== 全部4段结束 ====================