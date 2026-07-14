--[[
    Integrated Criminality.lua with all features from Criminality新.lua
    (except key verification and UI, using Fluent UI from original)
    All new features are optional and default off.
]]

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
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local LogService = game:GetService("LogService")
local CoreGui = game:GetService("CoreGui")

-- ===== Settings (extended) =====
local Settings = {
    Enabled = false,
    IsDead = false,
    IgnoredList = {},
    ProcessedList = {},
    TempIgnored = {},
    IgnoreDuration = 60,
    DebugPrintEnabled = true,
    TargetY = 4.8,
    MoveSpeed = 22,
    SomeFlag = true,
    WaypointSpacing = 3,
    SomeOtherParam = 3,
    PickupDistance = 8,
    MaxSomething = 999999,

    -- New settings
    AutoDeposit = false,
    DepositThresholdK = 5,
    AutoAllowance = false,
    NoFall = false,
    AdminCheck = false,
    AntiRejoin = false,
    AutoNotify = false,
    NotifyMinutes = 5,
    WebhookURL = "",
    BreakingMethod = "Crowbar", -- "Crowbar" or "Lockpick"
    AutoPlay = false,
    AutoMoney = true, -- keep original
}

-- ===== Global state =====
local PickupLock = {Lock = {Busy = false}}
local LastTick = tick()
local CurrentTargetPart = nil
local IsMovingToTarget = false
local SomeFlag2 = false
local SomeNil = nil
local StatusText = "Ожидание"
local AvailableSafesCount = 0
local AvailableRegistersCount = 0
local Unused1 = 0
local Unused2 = 0
local TotalSafesCount = 0
local TotalRegistersCount = 0
local AvailableSafes = {}
local AvailableRegisters = {}
local TotalAvailableTargets = 0
local SuggestionText = ""
local SomeNil2 = nil
local BrokenStatusMap = {}
local RetryCount = 0
local LastShopMainPart = nil
local IsRising = false
local SortedTargets = {}
local HasReachedTargetY = false

-- New state variables
local earnedMoneyTotal = 0
local deathCount = 0
local farmTimeSeconds = 0
local allowanceAmount = 0
local bankAmount = 0
local depositCooldownUntil = 0
local depositInProgress = false
local noFallHookInstalled = false
local antiRejoinInstalled = false
local antiRejoinBusy = false
local autoPlayLoadTimeDetected = false
local autoPlayLoadTimeReadyAt = nil
local autoPlayWorkerBusy = false
local notifyLastAt = 0
local notifyBusy = false
local farmRunId = 0
local farmEnabled = false
local userWantsFarm = false

-- ===== Helper functions =====
local function Log(msg)
    if Settings.DebugPrintEnabled then
        print("[AutoFarm]", msg)
    end
end

local function now()
    return tick()
end

local function waitSeconds(sec)
    task.wait(sec)
end

local function spawnTask(callback)
    task.spawn(callback)
end

-- ===== File I/O (optional) =====
local function safeRead(path)
    if type(isfile) == "function" and isfile(path) then
        local ok, data = pcall(readfile, path)
        if ok then return data end
    end
    return nil
end

local function safeWrite(path, content)
    if type(writefile) == "function" then
        pcall(writefile, path, tostring(content))
    end
end

local RUNTIME_STATE_FILE = "JX-CRIMINALITY-FARM/runtime_state.txt"
local EARN_MONEY_FILE = "JX-CRIMINALITY-FARM/JX_EarnMoney.txt"

local function loadRuntimeState()
    local text = safeRead(RUNTIME_STATE_FILE)
    if text then
        local earned = text:match("EarnMoney:(%d+%.?%d*)")
        if earned then earnedMoneyTotal = tonumber(earned) or 0 end
        local webhook = text:match("Webhook:([^\r\n]*)")
        if webhook then Settings.WebhookURL = webhook end
        local autoNotify = text:match("AutoNotify:(%d+)")
        if autoNotify then Settings.AutoNotify = autoNotify == "1" end
        local minutes = text:match("NotifyMinutes:(%d+%.?%d*)")
        if minutes then Settings.NotifyMinutes = math.floor(math.max(1, tonumber(minutes) or 5)) end
    end
    local earnedFile = safeRead(EARN_MONEY_FILE)
    if earnedFile then
        earnedMoneyTotal = tonumber(earnedFile) or earnedMoneyTotal
    end
end

local function saveRuntimeState()
    local content = string.format(
        "EarnMoney:%d\nWebhook:%s\nAutoNotify:%d\nNotifyMinutes:%d",
        math.floor(earnedMoneyTotal),
        Settings.WebhookURL:gsub("[\r\n]", ""),
        Settings.AutoNotify and 1 or 0,
        math.floor(math.max(1, Settings.NotifyMinutes))
    )
    safeWrite(RUNTIME_STATE_FILE, content)
    safeWrite(EARN_MONEY_FILE, tostring(math.floor(earnedMoneyTotal)))
end

-- ===== Anti-AFK (original) =====
local AntiAfkEnabled = true
local AntiAfkConnection = nil
local function EnableAntiAfk()
    if AntiAfkConnection then return end
    AntiAfkConnection = LocalPlayer.Idled:Connect(function()
        if AntiAfkEnabled then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            Log("Анти-АФК сработал")
        end
    end)
    Log("Анти-АФК запущен")
end

local function DisableAntiAfk()
    if AntiAfkConnection then
        AntiAfkConnection:Disconnect()
        AntiAfkConnection = nil
    end
    Log("Анти-АФК остановлен")
end
EnableAntiAfk()

-- ===== Auto Pickup Money (original) =====
local AutoPickupRunning = false
local AutoPickupConnection = nil

local function StartAutoPickup()
    if AutoPickupRunning then return end
    AutoPickupRunning = true
    if AutoPickupConnection then
        AutoPickupConnection:Disconnect()
        AutoPickupConnection = nil
    end
    AutoPickupConnection = RunService.RenderStepped:Connect(function()
        if not AutoPickupRunning or Settings.IsDead then return end
        local spawnedBreadFolder = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("SpawnedBread")
        local pickupEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("CZDPZUS")
        if not spawnedBreadFolder or not pickupEvent then return end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if PickupLock.Lock.Busy then return end
        local charPos = hrp.Position
        for _, breadPart in ipairs(spawnedBreadFolder:GetChildren()) do
            if (charPos - breadPart.Position).Magnitude <= Settings.PickupDistance then
                if not PickupLock.Lock.Busy then
                    PickupLock.Lock.Busy = true
                    pcall(function() pickupEvent:FireServer(breadPart) end)
                    task.wait(1.1)
                    PickupLock.Lock.Busy = false
                    break
                end
            end
        end
    end)
end

local function StopAutoPickup()
    if not AutoPickupRunning then return end
    AutoPickupRunning = false
    if AutoPickupConnection then
        AutoPickupConnection:Disconnect()
        AutoPickupConnection = nil
    end
    if PickupLock and PickupLock.Lock then
        PickupLock.Lock.Busy = false
    end
end
StartAutoPickup()
Log("Авто-подбор денег активирован")

-- ===== Invisibility (R6) =====
do
    repeat task.wait() until game:IsLoaded()
    local clonerefSafe = cloneref or function(...) return ... end
    local services = setmetatable({}, { __index = function(_, k) return clonerefSafe(game:GetService(k)) end })
    local localPlayer = services.Players.LocalPlayer
    local character, humanoid, hrp

    local function updateChar()
        character = localPlayer.Character
        if character then
            hrp = character:FindFirstChild("HumanoidRootPart")
            humanoid = character:FindFirstChildOfClass("Humanoid")
        else
            hrp = nil
            humanoid = nil
        end
    end
    updateChar()

    local heartbeat = RunService.Heartbeat
    local renderStepped = RunService.RenderStepped
    local coreGui = game:GetService("CoreGui")
    local starterGui = game:GetService("StarterGui")

    local InvisPossible = true
    if character and not character:FindFirstChild("Torso") then
        pcall(function() starterGui:SetCore("SendNotification", { Title = "Невидимость НЕ РАБОТАЕТ", Text = "Требуется R6 аватар", Duration = 5 }) end)
        InvisPossible = false
    end

    local warningGui = Instance.new("ScreenGui")
    warningGui.Name = "InvisWarningGUI"
    warningGui.Parent = coreGui
    warningGui.ResetOnSpawn = false
    warningGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local InvisWarningLabel = Instance.new("TextLabel", warningGui)
    InvisWarningLabel.Text = "⚠️ВЫ ВИДИМЫ⚠️"
    InvisWarningLabel.Visible = false
    InvisWarningLabel.Size = UDim2.new(0, 200, 0, 30)
    InvisWarningLabel.Position = UDim2.new(0.5, -100, 0.85, 0)
    InvisWarningLabel.BackgroundTransparency = 1
    InvisWarningLabel.Font = Enum.Font.GothamSemibold
    InvisWarningLabel.TextSize = 24
    InvisWarningLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    InvisWarningLabel.TextStrokeTransparency = 0.5
    InvisWarningLabel.ZIndex = 10

    local InvisActive = false
    local InvisAnim = Instance.new("Animation")
    InvisAnim.AnimationId = "rbxassetid://215384594"
    local InvisAnimTrack = nil

    local function isGrounded()
        return humanoid and humanoid:IsDescendantOf(workspace) and humanoid.FloorMaterial ~= Enum.Material.Air
    end

    local function loadInvisAnim()
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
            InvisAnimTrack = nil
        end
        if humanoid then
            local success, track = pcall(function() return humanoid:LoadAnimation(InvisAnim) end)
            if success then
                InvisAnimTrack = track
                InvisAnimTrack.Priority = Enum.AnimationPriority.Action4
            else
                InvisAnimTrack = nil
            end
        else
            InvisAnimTrack = nil
        end
    end

    local function disableInvis()
        if not InvisActive then return end
        InvisActive = false
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
        end
        if humanoid then
            workspace.CurrentCamera.CameraSubject = humanoid
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency == 0.5 then
                    part.Transparency = 0
                end
            end
        end
        if InvisWarningLabel then
            InvisWarningLabel.Visible = false
        end
    end

    local function enableInvis()
        if InvisActive or not InvisPossible then return end
        updateChar()
        if not character or not humanoid or not hrp then return end
        if not character:FindFirstChild("Torso") then
            pcall(function() starterGui:SetCore("SendNotification", { Title = "Невидимость НЕ РАБОТАЕТ", Text = "Требуется R6 аватар", Duration = 5 }) end)
            return
        end
        InvisActive = true
        workspace.CurrentCamera.CameraSubject = hrp
        loadInvisAnim()
    end

    local function toggleInvis()
        if InvisActive then
            disableInvis()
        else
            enableInvis()
        end
        return InvisActive
    end

    _G.Invis_Enable = enableInvis
    _G.Invis_Disable = disableInvis
    _G.Invis_Toggle = toggleInvis
    _G.IsInvisEnabled = function() return InvisActive end

    localPlayer.CharacterAdded:Connect(function(newChar)
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
            InvisAnimTrack = nil
        end
        task.wait()
        updateChar()
        if not humanoid then
            task.wait(0.5)
            updateChar()
            if not humanoid then
                InvisPossible = false
                if InvisActive then disableInvis() end
                pcall(function() starterGui:SetCore("SendNotification", { Title = "Ошибка невидимости", Text = "Не удалось определить тип персонажа", Duration = 5 }) end)
                return
            end
        end
        if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
            InvisPossible = false
            if InvisActive then disableInvis() end
            pcall(function() starterGui:SetCore("SendNotification", { Title = "Предупреждение", Text = "Обнаружен не-R6 аватар. Невидимость отключена", Duration = 5 }) end)
            return
        else
            InvisPossible = true
        end
        if InvisActive then
            if hrp then workspace.CurrentCamera.CameraSubject = hrp end
            loadInvisAnim()
        end
    end)

    localPlayer.CharacterRemoving:Connect(function()
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
            InvisAnimTrack = nil
        end
        if InvisWarningLabel then
            InvisWarningLabel.Visible = false
        end
    end)

    heartbeat:Connect(function(dt)
        if not InvisActive or not InvisPossible then
            if not InvisActive and character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Transparency == 0.5 then
                        part.Transparency = 0
                    end
                end
            end
            if InvisWarningLabel then
                InvisWarningLabel.Visible = false
            end
            return
        end
        if not character or not humanoid or not hrp or not humanoid:IsDescendantOf(workspace) or humanoid.Health <= 0 then
            if InvisWarningLabel then InvisWarningLabel.Visible = false end
            return
        end
        if InvisWarningLabel then
            InvisWarningLabel.Visible = not isGrounded()
        end

        local speed = 12
        if humanoid.MoveDirection.Magnitude > 0 then
            local move = humanoid.MoveDirection * speed * dt
            hrp.CFrame = hrp.CFrame + move
        end

        local originalCF = hrp.CFrame
        local originalCamOffset = humanoid.CameraOffset
        local _, cameraYaw = workspace.CurrentCamera.CFrame:ToOrientation()

        hrp.CFrame = CFrame.new(hrp.CFrame.Position) * CFrame.fromOrientation(0, cameraYaw, 0)
        hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(90), 0, 0)
        humanoid.CameraOffset = Vector3.new(0, 1.44, 0)

        if InvisAnimTrack then
            local success = pcall(function()
                if not InvisAnimTrack.IsPlaying then
                    InvisAnimTrack:Play()
                end
                InvisAnimTrack:AdjustSpeed(0)
                InvisAnimTrack.TimePosition = 0.3
            end)
            if not success then
                loadInvisAnim()
            end
        elseif humanoid and humanoid.Health > 0 then
            loadInvisAnim()
        end

        renderStepped:Wait()

        if humanoid and humanoid:IsDescendantOf(workspace) then
            humanoid.CameraOffset = originalCamOffset
        end
        if hrp and hrp:IsDescendantOf(workspace) then
            hrp.CFrame = originalCF
        end
        if InvisAnimTrack then
            pcall(function() InvisAnimTrack:Stop() end)
        end
        if hrp and hrp:IsDescendantOf(workspace) then
            local lookVec = workspace.CurrentCamera.CFrame.LookVector
            local flatLook = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
            if flatLook.Magnitude > 0.1 then
                hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flatLook)
            end
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency ~= 1 then
                    part.Transparency = 0.5
                end
            end
        end
    end)
end

-- ===== Disable collisions (original) =====
RunService.Stepped:Connect(function()
    if Settings.Enabled and LocalPlayer.Character then
        pcall(function()
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end
end)

local function DisableDoorsCollision()
    local map = Workspace:FindFirstChild("Map")
    if map then
        local doors = map:FindFirstChild("Doors")
        if doors then
            for _, door in ipairs(doors:GetDescendants()) do
                pcall(function() if door:IsA("BasePart") then door.CanCollide = false end end)
            end
        end
        Log("Коллизия дверей отключена")
    end
end
DisableDoorsCollision()

-- ===== Rise to Y (original) =====
local function RiseToTargetY()
    if HasReachedTargetY then return end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if hrp and humanoid and humanoid.Health > 0 and hrp.Position.Y < 4.7 and not IsRising then
        Log("Персонаж ниже 4.7, поднимаю по точкам до 4.8...")
        StatusText = "Подъём на 4.8"
        IsRising = true

        local startPos = hrp.Position
        local targetY = 4.8
        local startY = startPos.Y
        local deltaY = targetY - startY
        if deltaY <= 0 then
            IsRising = false
            StatusText = "Ожидание"
            return
        end

        local steps = math.max(3, math.floor(deltaY * 2))
        local waypoints = {}
        for i = 1, steps do
            local alpha = i / steps
            local y = startY + deltaY * alpha
            table.insert(waypoints, Vector3.new(startPos.X, y, startPos.Z))
        end

        for _, wp in ipairs(waypoints) do
            if not Settings.Enabled then break end
            local currentRot = hrp.CFrame - hrp.CFrame.Position
            local targetCF = CFrame.new(wp) * currentRot
            local dist = (wp - hrp.Position).Magnitude
            local duration = math.min(0.5, dist / 10)

            local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = targetCF })
            tween:Play()
            tween.Completed:Wait()
        end

        hrp.CFrame = CFrame.new(startPos.X, targetY, startPos.Z) * (hrp.CFrame - hrp.CFrame.Position)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        Log("Достиг 4.8, замираю на 3 секунды...")
        task.wait(3)
        Log("Замер завершён, продолжаю")

        IsRising = false
        HasReachedTargetY = true
        StatusText = "Ожидание"
    end
end

-- ===== Path and movement (original) =====
local PathVisualsFolder = Instance.new("Folder")
PathVisualsFolder.Name = "PathVisuals"
PathVisualsFolder.Parent = Workspace

local function ClearPathVisuals()
    for _, child in ipairs(PathVisualsFolder:GetChildren()) do
        pcall(function() child:Destroy() end)
    end
end

local function VisualizePath(waypoints, startPos)
    ClearPathVisuals()
    if not waypoints or #waypoints == 0 then return end
    for i, wp in ipairs(waypoints) do
        local part = Instance.new("Part")
        part.Name = "Waypoint" .. i
        part.Size = Vector3.new(2, 2, 2)
        part.Position = wp.Position
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromHSV(i / #waypoints, 1, 1)
        part.Transparency = 0.3
        part.Parent = PathVisualsFolder
    end
    local prevPos = startPos
    for i, wp in ipairs(waypoints) do
        local nextPos = wp.Position
        local dist = (nextPos - prevPos).Magnitude
        if dist > 0.5 then
            local line = Instance.new("Part")
            line.Name = "PathLine" .. i
            line.Anchored = true
            line.CanCollide = false
            line.Material = Enum.Material.Neon
            line.Color = Color3.new(0, 1, 0)
            line.Transparency = 0.5
            line.Size = Vector3.new(0.5, 0.5, dist)
            line.CFrame = CFrame.lookAt(prevPos + (nextPos - prevPos) / 2, nextPos)
            line.Parent = PathVisualsFolder
        end
        prevPos = nextPos
    end
end

local function ComputePath(startPos, endPos)
    local pathParamsList = {
        { Radius = 1, Height = 4, Spacing = 2 },
        { Radius = 1.2, Height = 4.5, Spacing = 2.5 },
        { Radius = 1.5, Height = 5, Spacing = 3 },
        { Radius = 2, Height = 5.5, Spacing = 4 },
        { Radius = 2.5, Height = 6, Spacing = 5 },
        { Radius = 3, Height = 6.5, Spacing = 5 },
        { Radius = 3.5, Height = 7, Spacing = 6 },
        { Radius = 4, Height = 7.5, Spacing = 6 },
        { Radius = 1, Height = 8, Spacing = 3 },
        { Radius = 5, Height = 5, Spacing = 5 },
        { Radius = 1.8, Height = 4.2, Spacing = 2.2 },
        { Radius = 2.2, Height = 5.8, Spacing = 4.5 },
        { Radius = 2.8, Height = 6.2, Spacing = 5.5 },
        { Radius = 3.2, Height = 6.8, Spacing = 5.8 },
        { Radius = 3.8, Height = 7.2, Spacing = 6.2 }
    }
    for _, params in ipairs(pathParamsList) do
        local pathParams = {
            AgentRadius = params.Radius,
            AgentHeight = params.Height,
            AgentCanJump = true,
            AgentCanClimb = true,
            WaypointSpacing = params.Spacing,
            CostCalibration = true
        }
        local path = PathfindingService:CreatePath(pathParams)
        local success, _ = pcall(function() path:ComputeAsync(startPos, endPos) end)
        if success and path.Status == Enum.PathStatus.Success then
            local rawWaypoints = path:GetWaypoints()
            if not rawWaypoints or #rawWaypoints < 2 then return rawWaypoints end
            local refinedWaypoints = {}
            local spacing = Settings.WaypointSpacing
            table.insert(refinedWaypoints, rawWaypoints[1])
            for i = 2, #rawWaypoints do
                local prev = rawWaypoints[i - 1].Position
                local curr = rawWaypoints[i].Position
                local dist = (curr - prev).Magnitude
                if dist <= spacing then
                    table.insert(refinedWaypoints, rawWaypoints[i])
                else
                    local steps = math.ceil(dist / spacing)
                    for j = 1, steps do
                        local alpha = j / steps
                        local pos = prev:Lerp(curr, alpha)
                        local action = (j == steps and rawWaypoints[i].Action) or Enum.PathWaypointAction.Walk
                        table.insert(refinedWaypoints, { Position = pos, Action = action })
                    end
                end
            end
            return refinedWaypoints
        end
        task.wait(0.05)
    end
    return nil
end

local function GetPositionInFrontOfTarget(targetPart, fromPos)
    if not targetPart then return nil end
    local success, cf = pcall(function() return targetPart.CFrame end)
    if not success then return nil end
    local lookVec = cf.LookVector
    lookVec = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
    if lookVec.Magnitude < 0.1 then
        lookVec = (fromPos - cf.Position).Unit
        lookVec = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
        if lookVec.Magnitude < 0.1 then lookVec = Vector3.new(1, 0, 0) end
    end
    return cf.Position + lookVec * 4
end

local function GetFootPosition()
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp.Position - Vector3.new(0, 2.5, 0)
end

local function MoveToTarget(targetPart)
    RiseToTargetY()
    local character = LocalPlayer.Character
    if not character then
        Log("Нет персонажа")
        return false
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then
        Log("Нет HRP или Humanoid")
        return false
    end
    if not targetPart or not targetPart:IsA("BasePart") then
        Log("Неверная цель")
        return false
    end
    CurrentTargetPart = targetPart
    IsMovingToTarget = true
    SomeFlag2 = false
    StatusText = "Путь к цели"
    local startPos = hrp.Position
    local targetFrontPos = GetPositionInFrontOfTarget(targetPart, startPos)
    if not targetFrontPos then
        Log("Не удалось вычислить позицию перед объектом")
        IsMovingToTarget = false
        StatusText = "Ожидание"
        return false
    end
    local endPos = targetFrontPos
    Log("Поиск пути к цели, расстояние " .. math.floor((endPos - startPos).Magnitude))
    local path = ComputePath(startPos, endPos)
    if not path then
        Log("Путь не найден, временно игнорирую цель")
        IsMovingToTarget = false
        StatusText = "Ожидание"
        return false
    end
    Log("Путь найден, точек: " .. #path)
    VisualizePath(path, startPos)
    for _, waypoint in ipairs(path) do
        if not Settings.Enabled then
            ClearPathVisuals()
            IsMovingToTarget = false
            StatusText = "Ожидание"
            return false
        end
        local footPos = GetFootPosition()
        if not footPos then continue end
        local targetPos = waypoint.Position
        local targetHRP = targetPos + Vector3.new(0, 2.5, 0)
        local currentRot = hrp.CFrame - hrp.CFrame.Position
        local targetCF = CFrame.new(targetHRP) * currentRot
        local dist = (targetHRP - hrp.Position).Magnitude
        if dist > 0.2 then
            local tween = TweenService:Create(hrp, TweenInfo.new(dist / Settings.MoveSpeed, Enum.EasingStyle.Linear), { CFrame = targetCF })
            tween:Play()
            tween.Completed:Wait()
            LastTick = tick()
        end
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
            task.wait(0.1)
        end
    end
    ClearPathVisuals()
    local finalPos = endPos
    local finalHRP = finalPos + Vector3.new(0, 2.5, 0)
    hrp.CFrame = CFrame.new(finalHRP) * CFrame.Angles(0, math.rad(90), 0)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    Log("Цель достигнута")
    IsMovingToTarget = false
    StatusText = "Ожидание"
    return true
end

-- ===== Tool functions (original + extended) =====
local function HasTool(toolName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    return (backpack and backpack:FindFirstChild(toolName)) or (character and character:FindFirstChild(toolName))
end

local function EquipTool(toolName)
    local tool = LocalPlayer:FindFirstChild("Backpack") and LocalPlayer.Backpack:FindFirstChild(toolName)
    if tool and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        pcall(function() LocalPlayer.Character.Humanoid:EquipTool(tool) end)
        task.wait(1)
        return true
    end
    return false
end

-- ===== Crowbar dealer (original) =====
local function FindCrowbarDealer()
    local map = Workspace:FindFirstChild("Map")
    if not map then
        Log("Карта не найдена")
        return nil
    end
    local shops = map:FindFirstChild("Shopz")
    if not shops then
        Log("Магазины не найдены")
        return nil
    end
    local character = LocalPlayer.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closestDealer = nil
    local closestDist = math.huge
    for _, shop in ipairs(shops:GetChildren()) do
        local stocks = shop:FindFirstChild("CurrentStocks")
        if stocks then
            local crowbarStock = stocks:FindFirstChild("Crowbar")
            if crowbarStock and crowbarStock.Value > 0 then
                local mainPart = shop:FindFirstChild("MainPart")
                if mainPart then
                    local dist = (hrp.Position - mainPart.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestDealer = shop
                    end
                end
            end
        end
    end
    if closestDealer then
        Log("Найден дилер с ломом, расстояние: " .. math.floor(closestDist))
    else
        Log("Дилер с ломом не найден")
    end
    return closestDealer
end

local function BuyCrowbar()
    local dealer = FindCrowbarDealer()
    if not dealer then return false end
    local mainPart = dealer:FindFirstChild("MainPart")
    if not mainPart then
        Log("У дилера нет MainPart")
        return false
    end
    StatusText = "Путь к дилеру"
    Log("Иду к дилеру за ломом")

    RetryCount = 0
    LastShopMainPart = mainPart
    local moveSuccess = MoveToTarget(mainPart)

    if not moveSuccess then
        RetryCount = RetryCount + 1
        Log("Путь не найден, попытка " .. RetryCount .. "/3")

        if RetryCount >= 3 then
            Log("Путь не найден 3 раза, поднимаюсь на высоту 4.8")
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = hrp.Position
                local tween = TweenService:Create(hrp, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = CFrame.new(pos.X, 4.8, pos.Z) })
                tween:Play()
                tween.Completed:Wait()
                task.wait(1)
                Log("Повторная попытка найти путь к дилеру")
                RetryCount = 0
                moveSuccess = MoveToTarget(mainPart)
                if not moveSuccess then
                    Log("Путь к дилеру всё ещё не найден, временно игнорирую")
                    StatusText = "Ожидание"
                    return false
                end
            end
        else
            StatusText = "Ожидание"
            return false
        end
    end

    StatusText = "Покупка лома"
    task.wait(1.5)
    local events = ReplicatedStorage:FindFirstChild("Events")
    if events then
        Log("Открываю магазин")
        pcall(function() events.BYZERSPROTEC:FireServer(true, "shop", mainPart, "IllegalStore") end)
        task.wait(1)
        Log("Покупаю лом")
        pcall(function() events.SSHPRMTE1:InvokeServer("IllegalStore", "Melees", "Crowbar", mainPart, nil, true) end)
        task.wait(20)
        Log("Закрываю магазин")
        pcall(function() events.BYZERSPROTEC:FireServer(false) end)
    end
    task.wait(2)
    local crowbar = HasTool("Crowbar")
    if crowbar then
        Log("Лом куплен успешно")
    else
        Log("Не удалось купить лом")
    end
    LastTick = tick()
    StatusText = "Ожидание"
    return crowbar
end

-- ===== Lockpick functions (new) =====
local function countToolsByName(name)
    local total = 0
    local character = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
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

local function getShopMainPart(name)
    local map = Workspace:FindFirstChild("Map")
    local shopz = map and map:FindFirstChild("Shopz")
    local shop = shopz and shopz:FindFirstChild(name)
    return shop and shop:FindFirstChild("MainPart") or nil
end

local function findNearestLockpickShopPart()
    local root = getRootPart()
    local selected, selectedDist = nil, math.huge
    for _, name in ipairs({ "ArmoryDealer", "Dealer" }) do
        local part = getShopMainPart(name)
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

local function purchaseLockpickAt(shopPart)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local purchaseRemote = events and events:FindFirstChild("SSHPRMTE1")
    if not shopPart or not purchaseRemote then return false end
    local illegalOk = pcall(purchaseRemote.InvokeServer, purchaseRemote, "IllegalStore", "Misc", "Lockpick", shopPart, nil, true)
    waitSeconds(0.25)
    local legalOk = pcall(purchaseRemote.InvokeServer, purchaseRemote, "LegalStore", "Misc", "Lockpick", shopPart, nil, true)
    return illegalOk or legalOk
end

local function buyLockpickBatch(quantity)
    quantity = math.max(1, math.floor(quantity or 7))
    local shopPart = findNearestLockpickShopPart()
    if not shopPart then return false end
    if not MoveToTarget(shopPart) then return false end
    local startCount = countToolsByName("Lockpick")
    for i = 1, quantity do
        if not Settings.Enabled then break end
        purchaseLockpickAt(shopPart)
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
    local tool = HasTool("Lockpick")
    if not tool then return false, "lockpick_missing" end
    if not EquipTool("Lockpick") then return false, "equip_failed" end
    local remote = tool:FindFirstChild("Remote")
    if not remote or not remote:IsA("RemoteFunction") then return false, "remote_missing" end
    local startOk, token = pcall(remote.InvokeServer, remote, "S", target, "s")
    if startOk and type(token) == "number" then
        waitSeconds(0.25)
        local finishOk = pcall(remote.InvokeServer, remote, "D", target, "s", token)
        return finishOk, finishOk and "success" or "finish_failed"
    end
    dropLockpick(tool)
    return false, "lockpick_failed"
end

local function strikeTargetWithCrowbar(target)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local startRemote = events and events:FindFirstChild("XMHH") and events.XMHH:FindFirstChild("2")
    local finishRemote = events and events:FindFirstChild("XMHH2") and events.XMHH2:FindFirstChild("2")
    local tool = HasTool("Crowbar")
    local character = LocalPlayer.Character
    local targetPart = target:FindFirstChild("MainPart") or target.PrimaryPart
    local rightArm = character and (character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand"))
    if not startRemote or not finishRemote or not tool or not character or not rightArm or not targetPart then return false end
    EquipTool("Crowbar")
    local invokeOk, token = pcall(startRemote.InvokeServer, startRemote, "🍞", tick(), tool, "DZDRRRKI", target, "Register")
    if invokeOk and type(token) == "number" then
        return pcall(finishRemote.FireServer, finishRemote, "🍞", tick(), tool, "2389ZFX34", token, false, rightArm, targetPart, target, targetPart.Position, targetPart.Position)
    end
    return invokeOk
end

-- ===== HackSafe (original modified to support breaking method) =====
local function HackSafe(safeObj)
    if Settings.BreakingMethod == "Lockpick" then
        -- Lockpick approach
        if not HasTool("Lockpick") then
            Log("Нет отмычек, покупаю...")
            if not buyLockpickBatch(7) then
                Log("Не удалось купить отмычки, пропускаю")
                return false
            end
        end
        EquipTool("Lockpick")
        local opened = false
        for attempt = 1, 10 do
            if not Settings.Enabled then break end
            local ok, reason = tryLockpickTarget(safeObj)
            if ok then
                opened = true
                break
            end
            waitSeconds(1.2)
        end
        if opened then
            Log("Сейф вскрыт отмычкой")
            return true
        else
            Log("Не удалось вскрыть отмычкой")
            return false
        end
    else
        -- Crowbar approach (original)
        if not HasTool("Crowbar") then
            Log("Нет лома для открытия сейфа, пробую купить...")
            local bought = BuyCrowbar()
            if not bought then
                Log("Не удалось купить лом, пропускаю сейф")
                return false
            end
        end
        if not LocalPlayer.Character:FindFirstChild("Crowbar") then
            Log("Лом в рюкзаке, экипирую...")
            EquipTool("Crowbar")
            task.wait(1)
        end
        if not HasTool("Crowbar") then
            Log("Лом так и не появился, пропускаю")
            return false
        end
        task.wait(1.5)
        local events = ReplicatedStorage:FindFirstChild("Events")
        if not events then
            Log("Папка Events не найдена")
            return false
        end
        local remote1 = events:FindFirstChild("XMHH.2")
        local remote2 = events:FindFirstChild("XMHH2.2")
        local mainPart = safeObj:FindFirstChild("MainPart") or safeObj.PrimaryPart
        if not remote1 or not remote2 then
            Log("Remote events для взлома не найдены")
            return false
        end
        if not mainPart then
            Log("У сейфа нет основной части")
            return false
        end
        Log("Начинаю взлом сейфа")
        StatusText = "Взлом сейфа"
        local startTime = tick()
        local hits = 0
        while Settings.Enabled and safeObj and safeObj.Parent do
            local values = safeObj:FindFirstChild("Values")
            if not values then break end
            local broken = values:FindFirstChild("Broken")
            if broken and broken.Value then
                Log("Сейф уже взломан")
                break
            end
            if tick() - startTime > 25 then
                Log("Таймаут взлома")
                break
            end
            task.wait(0.4)
            local crowbar = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Crowbar")
            if not crowbar then
                crowbar = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Crowbar")
                if crowbar then EquipTool("Crowbar") end
            end
            if not crowbar then break end
            local arm = LocalPlayer.Character:FindFirstChild("Right Arm") or LocalPlayer.Character:FindFirstChild("RightHand")
            if not arm then break end
            local success, result = pcall(function() return remote1:InvokeServer("🍞", tick(), crowbar, "DZDRRRKI", safeObj, "Register") end)
            if success and result then
                pcall(function() remote2:FireServer("🍞", tick(), crowbar, "2389ZFX34", result, false, arm, mainPart, safeObj, mainPart.Position, mainPart.Position) end)
                hits = hits + 1
            end
            if hits % 4 == 0 then task.wait(0.8) end
            LastTick = tick()
        end
        task.wait(2)
        Log("Взлом завершен, ударов: " .. hits)
        StatusText = "Ожидание"
        return true
    end
end

-- ===== Cleanup and target list (original) =====
local function CleanupTempIgnored()
    local nowTick = tick()
    for obj, expiry in pairs(Settings.TempIgnored) do
        if nowTick > expiry then
            Settings.TempIgnored[obj] = nil
            for i, v in ipairs(Settings.IgnoredList) do
                if v == obj then
                    table.remove(Settings.IgnoredList, i)
                    break
                end
            end
            Log("Игнорируемый объект разблокирован")
        end
    end
end

local function UpdateTargetsList()
    CleanupTempIgnored()
    local bredFolder = nil
    local map = Workspace:FindFirstChild("Map")
    if map then
        bredFolder = map:FindFirstChild("BredMakurz")
    end
    if not bredFolder then
        local filter = Workspace:FindFirstChild("Filter")
        if filter then
            bredFolder = filter:FindFirstChild("BredMakurz")
        end
    end
    if not bredFolder then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                bredFolder = obj
                break
            end
        end
    end
    if not bredFolder then
        Log("Папка BredMakurz не найдена")
        return 0, 0
    end
    local character = LocalPlayer.Character
    if not character then return 0, 0 end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0, 0 end
    local safes = {}
    local registers = {}
    TotalSafesCount = 0
    TotalRegistersCount = 0
    SortedTargets = {}
    for _, obj in ipairs(bredFolder:GetChildren()) do
        local nameLower = obj.Name:lower()
        if nameLower:find("safe") or nameLower:find("register") then
            if nameLower:find("safe") then
                TotalSafesCount = TotalSafesCount + 1
            else
                TotalRegistersCount = TotalRegistersCount + 1
            end
            if Settings.ProcessedList[obj] then continue end
            if Settings.TempIgnored[obj] then continue end
            local values = obj:FindFirstChild("Values")
            if values then
                local broken = values:FindFirstChild("Broken")
                if broken and not broken.Value then
                    local mainPart = obj:FindFirstChild("MainPart") or obj.PrimaryPart
                    if mainPart and mainPart.Position.Y >= 4.8 then
                        local targetInfo = { obj = obj, part = mainPart, pos = mainPart.Position }
                        if nameLower:find("safe") then
                            table.insert(safes, targetInfo)
                        else
                            table.insert(registers, targetInfo)
                        end
                        table.insert(SortedTargets, targetInfo)
                    end
                end
            end
        end
    end
    AvailableSafes = safes
    AvailableRegisters = registers
    table.sort(SortedTargets, function(a, b)
        return (a.pos - hrp.Position).Magnitude < (b.pos - hrp.Position).Magnitude
    end)
    AvailableSafesCount = #safes
    AvailableRegistersCount = #registers
    return AvailableSafesCount + AvailableRegistersCount, TotalSafesCount + TotalRegistersCount
end

local function AnalyzeTargetsCount()
    local available, total = UpdateTargetsList()
    TotalAvailableTargets = available
    Log("Всего доступно: " .. available .. "/" .. total .. " целей")
    if available < 20 then
        SuggestionText = "Мало целей (" .. available .. "), много конкурентов. Смени сервер."
        Log("⚠️ " .. SuggestionText)
        pcall(function()
            HttpService:SetCore("SendNotification", {
                Title = "Рекомендация",
                Text = SuggestionText,
                Duration = 10
            })
        end)
    else
        SuggestionText = "Достаточно целей (" .. available .. "), можно фармить."
    end
end
AnalyzeTargetsCount()

-- ===== Money collection near target (original) =====
local function FindMoneyNearTarget(targetObj)
    local mainPart = targetObj:FindFirstChild("MainPart") or targetObj.PrimaryPart
    if not mainPart then return {} end
    local spawnedBread = Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("SpawnedBread")
    if not spawnedBread then return {} end
    local moneyParts = {}
    for _, bread in ipairs(spawnedBread:GetChildren()) do
        pcall(function()
            if bread:IsA("Part") and bread.Transparency < 1 then
                if (bread.Position - mainPart.Position).Magnitude <= 25 then
                    table.insert(moneyParts, bread)
                end
            end
        end)
    end
    return moneyParts
end

local function CollectMoneyNearTarget(targetObj)
    local moneyParts = FindMoneyNearTarget(targetObj)
    if #moneyParts == 0 then return false end
    Log("Собираю " .. #moneyParts .. " пачек денег возле сейфа")
    StatusText = "Сбор денег"
    for _, money in ipairs(moneyParts) do
        if not Settings.Enabled then break end
        pcall(function()
            if money and money.Parent and money.Transparency < 1 then
                MoveToTarget(money)
                local pickupEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("CZDPZUS")
                if pickupEvent then
                    pcall(function() pickupEvent:FireServer(money) end)
                end
                task.wait(0.3)
            end
        end)
    end
    StatusText = "Ожидание"
    return #FindMoneyNearTarget(targetObj) > 0
end

-- ===== Respawn handling (original extended with autoRespawn) =====
local IsRespawning = false
local RespawnConnection = nil

local function PressE()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function StopRespawnHandler()
    if IsRespawning then
        IsRespawning = false
        if RespawnConnection then
            RespawnConnection:Disconnect()
            RespawnConnection = nil
        end
    end
end

local function StartRespawnHandler()
    if IsRespawning then return end
    IsRespawning = true
    Log("Смерть обнаружена - нажимаю E для возрождения")
    StatusText = "Смерть"
    RespawnConnection = RunService.Heartbeat:Connect(function()
        if not IsRespawning then
            if RespawnConnection then
                RespawnConnection:Disconnect()
                RespawnConnection = nil
            end
            return
        end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        if character and humanoid and humanoid.Health > 0 then
            StopRespawnHandler()
            StatusText = "Ожидание"
            return
        end
        pcall(PressE)
    end)
end

local function OnCharacterAdded(newChar)
    StopRespawnHandler()
    task.wait(3)
    IsRising = false
    HasReachedTargetY = false
    if Settings.Enabled then
        Settings.IsDead = false
        LastTick = tick()
        RiseToTargetY()
        Log("Персонаж возродился, продолжаю")
        StatusText = "Ожидание"
    end
    local humanoid = newChar:WaitForChild("Humanoid", 5)
    if humanoid then
        humanoid.Died:Connect(StartRespawnHandler)
    end
end

LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end

-- ===== New features: Deposit =====
local function readCashAmountValue()
    local coreGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("CoreGUI")
    if not coreGui then return 0 end
    local cashObj = coreGui:FindFirstChild("Cash", true) or coreGui:FindFirstChild("CashLabel", true) or coreGui:FindFirstChild("CashAmount", true)
    if cashObj then
        local text = cashObj.Text or cashObj.Value or ""
        local num = tonumber(text:gsub("[^%d.]", ""))
        return num or 0
    end
    return 0
end

local function findATMMainPart()
    local map = Workspace:FindFirstChild("Map")
    local atmz = map and map:FindFirstChild("ATMz")
    local atm = atmz and atmz:FindFirstChild("ATM")
    return atm and atm:FindFirstChild("MainPart") or nil
end

local function tryDeposit()
    if not Settings.AutoDeposit then return false end
    if depositInProgress then return true end
    local nowTime = now()
    if nowTime < depositCooldownUntil then return false end
    local cash = readCashAmountValue()
    local threshold = Settings.DepositThresholdK * 1000
    if cash < threshold then return false end

    local events = ReplicatedStorage:FindFirstChild("Events")
    local atmMain = findATMMainPart()
    local remote = events and events:FindFirstChild("ATM")
    if not remote or not atmMain then return false end

    depositInProgress = true
    if not MoveToTarget(atmMain) then
        depositInProgress = false
        return false
    end
    local success, accepted = pcall(remote.InvokeServer, remote, "DP", cash, atmMain)
    depositInProgress = false
    depositCooldownUntil = now() + 2.5
    return success and accepted == true
end

local function tryDepositAllNow()
    if not Settings.AutoDeposit then
        Settings.AutoDeposit = true
    end
    for i = 1, 10 do
        if readCashAmountValue() <= 0 then return true end
        if tryDeposit() then waitSeconds(0.2) else break end
    end
    return false
end

-- ===== New features: Allowance =====
local function claimAllowance()
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild("CLMZALOW")
    local atm = findATMMainPart()
    if not remote or not atm then return false end
    local ok, accepted, _, _, amount = pcall(remote.InvokeServer, remote, atm)
    if ok and type(amount) == "number" then allowanceAmount = amount end
    return ok and accepted == true
end

-- ===== New features: No Fall =====
local noFallEnabled = false
local noFallHeartbeat = nil
local function applyNoFall()
    local character = LocalPlayer.Character
    if not character then return end
    local charStats = character:FindFirstChild("CharStats")
    if not charStats then return end
    local playerStats = charStats:FindFirstChild(LocalPlayer.Name) or charStats:FindFirstChild(tostring(LocalPlayer.UserId)) or charStats
    local ragdollSwitch = playerStats:FindFirstChild("RagdollSwitch") or charStats:FindFirstChild("RagdollSwitch", true)
    local ragdollTime = playerStats:FindFirstChild("RagdollTime") or charStats:FindFirstChild("RagdollTime", true)
    if noFallEnabled then
        if ragdollSwitch and ragdollSwitch:IsA("BoolValue") then ragdollSwitch.Value = false end
        if ragdollTime and (ragdollTime:IsA("NumberValue") or ragdollTime:IsA("IntValue")) then ragdollTime.Value = 0 end
    end
end

local function installNoFallHook()
    if type(hookmetamethod) ~= "function" or type(newcclosure) ~= "function" then return false end
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
    return true
end

local function setNoFall(enabled)
    noFallEnabled = enabled
    if noFallHeartbeat then noFallHeartbeat:Disconnect() end
    if noFallEnabled then
        installNoFallHook()
        applyNoFall()
        noFallHeartbeat = RunService.Heartbeat:Connect(applyNoFall)
    end
end

-- ===== New features: Anti Rejoin =====
local antiRejoinEnabled = false
local antiRejoinBusy = false
local function attemptRejoin(message)
    if not antiRejoinEnabled or antiRejoinBusy then return false end
    local lower = string.lower(message or "")
    if lower == "" then return false end
    local keywords = {"kicked", "disconnect", "connection", "error code", "same account", "teleport failed", "server shut", "shutdown"}
    for _, kw in ipairs(keywords) do
        if lower:find(kw, 1, true) then
            antiRejoinBusy = true
            spawnTask(function()
                waitSeconds(0.5)
                pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, game.JobId, LocalPlayer)
                waitSeconds(5)
                antiRejoinBusy = false
            end)
            return true
        end
    end
    return false
end

local function installAntiRejoin()
    if antiRejoinEnabled then
        GuiService.ErrorMessageChanged:Connect(function(msg) attemptRejoin(msg) end)
        RunService.Heartbeat:Connect(function()
            if not antiRejoinEnabled then return end
            local robloxPrompt = CoreGui:FindFirstChild("RobloxPromptGui")
            local promptOverlay = robloxPrompt and robloxPrompt:FindFirstChild("promptOverlay")
            local errorPrompt = promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt")
            if errorPrompt and errorPrompt.Visible then
                local parts = {}
                for _, d in ipairs(errorPrompt:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then
                        table.insert(parts, d.Text)
                    end
                end
                local msg = table.concat(parts, " ")
                attemptRejoin(msg)
            end
        end)
    end
end

-- ===== New features: Admin Check =====
local adminUserIds = {
    3294804378, 93676120, 54087314, 81275825, 140837601, 1229486091,
    46567801, 418086275, 29706395, 3717066084, 1424338327, 5046662686,
    5046661126, 5046659439, 418199326, 1024216621, 1810535041, 63238912,
    111250044, 63315426, 730176906, 141193516, 194512073, 193945439,
    412741116, 195538733, 102045519, 955294, 957835150, 25689921,
    366613818, 281593651, 455275714, 208929505, 96783330, 156152502,
    93281166, 959606619, 142821118, 632886139, 175931803, 122209625,
    278097946, 142989311, 1517131734, 446849296, 87189764, 67180844,
    9212846, 47352513, 48058122, 155413858, 10497435, 513615792,
    55893752, 55476024, 151691292, 136584758, 16983447, 3111449,
    94693025, 271400893, 5005262660, 295331237, 64489098, 244844600,
    114332275, 25048901, 69262878, 50801509, 92504899, 42066711,
    50585425, 31365111, 166406495, 2457253857, 29761878, 21831137,
    948293345, 439942262, 38578487, 1163048, 7713309208, 3659305297,
    15598614, 34616594, 626833004, 198610386, 153835477, 3923114296,
    3937697838, 102146039, 119861460, 371665775, 1206543842, 93428604,
    1863173316, 90814576, 374665997, 423005063, 140172831, 42662179,
    9066859, 438805620, 14855669, 727189337, 1871290386, 608073286
}
local adminGroupRoles = {
    [4165692] = {Tester=true, Contributor=true, ["Tester+"]=true, Developer=true, ["Developer+"]=true, ["Community Manager"]=true, Manager=true, Owner=true},
    [32406137] = {Junior=true, Moderator=true, Senior=true, Administrator=true, Manager=true, Holder=true},
    [8024440] = {["reshape enjoyer"]=true, ["i heart reshape"]=true, ["reshape superfan"]=true},
    [14927228] = {["♞"]=true}
}
local adminGroupRanks = {}

local function isLikelyAdmin(player)
    if player == LocalPlayer then return false end
    if adminUserIds[player.UserId] then return true end
    for groupId, roles in pairs(adminGroupRoles) do
        local ok, role = pcall(player.GetRoleInGroup, player, groupId)
        if ok and roles[tostring(role)] then return true end
    end
    for groupId, minRank in pairs(adminGroupRanks) do
        local ok, rank = pcall(player.GetRankInGroup, player, groupId)
        if ok and rank >= minRank then return true end
    end
    return false
end

local function adminWatchLoop()
    while Settings.Enabled do
        if Settings.AdminCheck then
            for _, player in ipairs(Players:GetPlayers()) do
                if isLikelyAdmin(player) then
                    Log("Обнаружен администратор: " .. player.Name)
                    Settings.Enabled = false
                    StatusText = "Администратор обнаружен"
                    pcall(function()
                        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "JX", Text = "Администратор: " .. player.Name, Duration = 5 })
                    end)
                    return
                end
            end
        end
        waitSeconds(2)
    end
end

-- ===== New features: Webhook =====
local function sendFarmWebhook()
    if Settings.WebhookURL == "" then return end
    local payload = {
        username = "JX-CRIMINALITY-FARM",
        embeds = {{
            title = "Farm Status",
            color = 0x64FFC8,
            fields = {
                {name = "Earned", value = tostring(math.floor(earnedMoneyTotal)), inline = true},
                {name = "Allowance", value = tostring(math.floor(allowanceAmount)), inline = true},
                {name = "Bank", value = tostring(math.floor(bankAmount)), inline = true},
                {name = "Died", value = tostring(deathCount), inline = true},
                {name = "Time", value = tostring(math.floor(farmTimeSeconds)), inline = true},
            },
            footer = {text = "JX-CRIMINALITY-FARM"},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    }
    local ok, result = pcall(function()
        return game:GetService("HttpService"):PostAsync(Settings.WebhookURL, game:GetService("HttpService"):JSONEncode(payload), Enum.HttpContentType.ApplicationJson)
    end)
    return ok
end

local function notifierLoop()
    while Settings.Enabled do
        if Settings.AutoNotify and Settings.WebhookURL ~= "" then
            local nowTime = now()
            local interval = math.max(60, Settings.NotifyMinutes * 60)
            if not notifyBusy and nowTime - notifyLastAt >= interval then
                notifyBusy = true
                pcall(sendFarmWebhook)
                pcall(saveRuntimeState)
                notifyLastAt = nowTime
                notifyBusy = false
            end
        end
        waitSeconds(1)
    end
end

-- ===== New features: Auto Play =====
local function performAutoPlaySequence()
    local events = ReplicatedStorage:FindFirstChild("Events")
    if not events then return false end
    local playRemote = events:FindFirstChild("BRBRBRRBLOOOL2")
    local updateRemote = events:FindFirstChild("UpdateClient")
    local ok = false
    if playRemote and playRemote:IsA("RemoteFunction") then
        ok = pcall(playRemote.InvokeServer, playRemote, "", "\15daz\18tough\19")
    end
    if updateRemote then pcall(updateRemote.FireServer, updateRemote) end
    return ok
end

local function autoPlayWorker()
    if autoPlayWorkerBusy then return end
    autoPlayWorkerBusy = true
    local started = now()
    while Settings.AutoPlay do
        pcall(performAutoPlaySequence)
        if autoPlayLoadTimeDetected then
            autoPlayLoadTimeReadyAt = autoPlayLoadTimeReadyAt or now() + 5
            if now() >= autoPlayLoadTimeReadyAt then
                Settings.Enabled = true
                break
            end
        end
        if now() - started > 20 then break end
        waitSeconds(0.2)
    end
    autoPlayWorkerBusy = false
end

local function detectLoadTime()
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
end

-- ===== ESP (original) =====
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
    local bredFolder = nil
    local map = Workspace:FindFirstChild("Map")
    if map then bredFolder = map:FindFirstChild("BredMakurz") end
    if not bredFolder then
        local filter = Workspace:FindFirstChild("Filter")
        if filter then bredFolder = filter:FindFirstChild("BredMakurz") end
    end
    if not bredFolder then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then bredFolder = obj break end
        end
    end
    if not bredFolder then return end
    local hrp = getRootPart()
    if not hrp then return end
    for _, obj in ipairs(bredFolder:GetChildren()) do
        local nameLower = obj.Name:lower()
        if nameLower:find("safe") or nameLower:find("register") then
            local mainPart = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
            if not mainPart or mainPart.Position.Y < 4.8 then continue end
            local values = obj:FindFirstChild("Values")
            local brokenVal = values and values:FindFirstChild("Broken")
            local isBroken = brokenVal and brokenVal.Value
            local color = isBroken and Color3.new(1,0,0) or Color3.new(0,1,0)
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
                label.Size = UDim2.new(1,0,1,0)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.SourceSansBold
                label.TextScaled = false
                label.Text = FormatName(obj.Name)
                label.TextColor3 = color
                label.TextStrokeTransparency = 0
                label.TextStrokeColor3 = Color3.new(0,0,0)
                label.TextSize = EspTextSize
                label.Parent = billboard
                local highlight = CreateHighlight(obj, color)
                EspElements[obj] = {billboard = billboard, highlight = highlight, label = label}
                if brokenVal then
                    brokenVal:GetPropertyChangedSignal("Value"):Connect(function()
                        if not EspEnabled or not EspElements[obj] then return end
                        local e = EspElements[obj]
                        if brokenVal.Value then
                            e.label.TextColor3 = Color3.new(1,0,0)
                            if e.highlight then e.highlight.FillColor = Color3.new(1,0,0) end
                        else
                            e.label.TextColor3 = Color3.new(0,1,0)
                            if e.highlight then e.highlight.FillColor = Color3.new(0,1,0) end
                        end
                    end)
                end
            else
                if brokenVal then
                    esp.label.TextColor3 = isBroken and Color3.new(1,0,0) or Color3.new(0,1,0)
                    if esp.highlight then esp.highlight.FillColor = isBroken and Color3.new(1,0,0) or Color3.new(0,1,0) end
                end
                if esp.label then esp.label.TextSize = EspTextSize end
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
    Log("ESP для всех сейфов/касс ВКЛЮЧЕН")
end

local function DisableESP()
    if not EspEnabled then return end
    EspEnabled = false
    if EspHeartbeatConnection then
        EspHeartbeatConnection:Disconnect()
        EspHeartbeatConnection = nil
    end
    for obj, data in pairs(EspElements) do
        pcall(function()
            if data.billboard then data.billboard:Destroy() end
            if data.highlight then data.highlight:Destroy() end
        end)
    end
    EspElements = {}
    Log("ESP для всех сейфов/касс ВЫКЛЮЧЕН")
end

-- ===== Broken tracking (original) =====
local function SetupBrokenTracking()
    Log("Запуск анализа целей...")
    BrokenStatusMap = {}
    local bredFolder = nil
    local map = Workspace:FindFirstChild("Map")
    if map then bredFolder = map:FindFirstChild("BredMakurz") end
    if not bredFolder then
        local filter = Workspace:FindFirstChild("Filter")
        if filter then bredFolder = filter:FindFirstChild("BredMakurz") end
    end
    if not bredFolder then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                bredFolder = obj
                break
            end
        end
    end
    if bredFolder then
        for _, obj in ipairs(bredFolder:GetChildren()) do
            local values = obj:FindFirstChild("Values")
            if values then
                local broken = values:FindFirstChild("Broken")
                if broken then
                    BrokenStatusMap[obj] = broken.Value
                    broken:GetPropertyChangedSignal("Value"):Connect(function()
                        if Settings.Enabled then
                            BrokenStatusMap[obj] = broken.Value
                            UpdateTargetsList()
                            AnalyzeTargetsCount()
                            Log("Статус цели изменен: " .. obj.Name .. " теперь " .. tostring(broken.Value))
                        end
                    end)
                end
            end
        end
        Log("Анализ целей завершен, отслеживается " .. #BrokenStatusMap .. " объектов")
    end
end
SetupBrokenTracking()

-- ===== Main Farm Loop (original extended with new features) =====
local function MainFarmLoop()
    Log("Цикл автофермы запущен")
    RiseToTargetY()
    loadRuntimeState()
    spawnTask(notifierLoop)
    spawnTask(adminWatchLoop)
    while true do
        task.wait(1)
        if not Settings.Enabled then
            task.wait(1)
            continue
        end
        Log("=== Цикл фермы ===")
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        Settings.IsDead = (not humanoid) or (humanoid.Health <= 0)
        if Settings.IsDead then
            Log("Персонаж мертв, ожидание")
            deathCount = deathCount + 1
            task.wait(3)
            continue
        end

        -- New: NoFall
        if Settings.NoFall then setNoFall(true) end

        -- New: Auto Allowance
        if Settings.AutoAllowance then pcall(claimAllowance) end

        -- New: Auto Deposit
        if Settings.AutoDeposit then pcall(tryDeposit) end

        RiseToTargetY()

        -- Check tools based on breaking method
        if Settings.BreakingMethod == "Crowbar" then
            if not HasTool("Crowbar") then
                Log("Нет лома, пробую купить")
                local bought = BuyCrowbar()
                if not bought then
                    Log("Не удалось купить лом, жду 5 сек")
                    task.wait(5)
                    continue
                end
            else
                Log("Лом уже есть")
            end
        else -- Lockpick
            if not HasTool("Lockpick") then
                Log("Нет отмычек, покупаю...")
                if not buyLockpickBatch(7) then
                    Log("Не удалось купить отмычки, жду")
                    task.wait(5)
                    continue
                end
            else
                Log("Отмычки есть")
            end
        end

        local available, total = UpdateTargetsList()
        TotalAvailableTargets = available
        if available < 5 then
            Log("Осталось мало целей (" .. available .. "), рекомендую сменить сервер")
        end
        if available == 0 then
            Log("Нет доступных целей, жду 5 сек")
            task.wait(5)
            continue
        end
        local nextTarget = nil
        local minDist = math.huge
        for _, targetInfo in ipairs(SortedTargets) do
            if not Settings.TempIgnored[targetInfo.obj] then
                local dist = (targetInfo.pos - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nextTarget = targetInfo.obj
                end
            end
        end
        if not nextTarget then
            Log("Нет доступных целей, жду 5 сек")
            task.wait(5)
            continue
        end
        local mainPart = nextTarget:FindFirstChild("MainPart") or nextTarget.PrimaryPart
        if not mainPart then
            Log("У цели нет MainPart, пропускаю")
            Settings.ProcessedList[nextTarget] = true
            continue
        end
        Log("Движение к цели: " .. nextTarget.Name .. ", расстояние " .. math.floor((mainPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude))
        local moveSuccess = MoveToTarget(mainPart)
        if moveSuccess then
            if Settings.BreakingMethod == "Crowbar" then
                if not LocalPlayer.Character:FindFirstChild("Crowbar") then EquipTool("Crowbar") end
            else
                if not LocalPlayer.Character:FindFirstChild("Lockpick") then EquipTool("Lockpick") end
            end
            Log("Открываю сейф")
            local hackSuccess = HackSafe(nextTarget)
            if hackSuccess then
                Log("Сейф открыт, собираю деньги")
                local stillMoney = CollectMoneyNearTarget(nextTarget)
                local attempts = 5
                while stillMoney and attempts > 0 do
                    task.wait(2)
                    stillMoney = CollectMoneyNearTarget(nextTarget)
                    attempts = attempts - 1
                end
                Settings.ProcessedList[nextTarget] = true
                -- update earnings (rough estimate)
                earnedMoneyTotal = earnedMoneyTotal + 500 -- placeholder
                saveRuntimeState()
                Log("Сейф полностью обработан")
            else
                Log("Не удалось открыть сейф, временно игнорирую")
                Settings.TempIgnored[nextTarget] = tick() + Settings.IgnoreDuration
                table.insert(Settings.IgnoredList, nextTarget)
            end
        else
            Log("Не удалось достичь цели, временно игнорирую")
            Settings.TempIgnored[nextTarget] = tick() + Settings.IgnoreDuration
            table.insert(Settings.IgnoredList, nextTarget)
        end
        task.wait(2)
    end
end

-- ===== Fluent UI (original, extended with new toggles) =====
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "AutoFarm",
    SubTitle = "",
    TabWidth = 120,
    Size = UDim2.fromOffset(450, 500),
    Acrylic = true,
    Theme = "DarkPurple",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Farm", Icon = "zap" }),
    Stats = Window:AddTab({ Title = "Info", Icon = "info" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Advanced = Window:AddTab({ Title = "Advanced", Icon = "settings" })
}

Tabs.Main:AddToggle("AutoFarmToggle", {
    Title = "Start Farm",
    Description = "",
    Default = false,
    Callback = function(value)
        Settings.Enabled = value
        if value then
            Settings.IgnoredList = {}
            Settings.ProcessedList = {}
            Settings.TempIgnored = {}
            UpdateTargetsList()
            AnalyzeTargetsCount()
            RiseToTargetY()
            Log("Автоферма ВКЛЮЧЕНА")
            Fluent:Notify({ Title = "AutoFarm", Content = "Запущено", Duration = 2 })
            spawnTask(MainFarmLoop)
        else
            ClearPathVisuals()
            SomeFlag2 = false
            StatusText = "Ожидание"
            Log("Автоферма ВЫКЛЮЧЕНА")
            Fluent:Notify({ Title = "AutoFarm", Content = "Остановлено", Duration = 2 })
        end
    end
})

Tabs.Main:AddToggle("AutoPickupMoneyToggle", {
    Title = "Auto Money",
    Description = "",
    Default = true,
    Callback = function(value)
        if value then
            StartAutoPickup()
            Log("Авто-подбор денег ВКЛЮЧЕН")
        else
            StopAutoPickup()
            Log("Авто-подбор денег ВЫКЛЮЧЕН")
        end
    end
})

Tabs.Main:AddToggle("InvisibilityToggle", {
    Title = "Invis (R6)",
    Description = "",
    Default = false,
    Callback = function(value)
        if value then
            _G.Invis_Enable()
            Log("Невидимость ВКЛЮЧЕНА")
        else
            _G.Invis_Disable()
            Log("Невидимость ВЫКЛЮЧЕНА")
        end
    end
})

Tabs.Main:AddToggle("AntiAfkToggle", {
    Title = "Anti-AFK",
    Description = "",
    Default = true,
    Callback = function(value)
        AntiAfkEnabled = value
        if value then
            EnableAntiAfk()
            Log("Анти-АФК ВКЛЮЧЕН")
        else
            DisableAntiAfk()
            Log("Анти-АФК ВЫКЛЮЧЕН")
        end
    end
})

Tabs.Main:AddSlider("SpeedSlider", {
    Title = "Speed",
    Description = "",
    Default = 22,
    Min = 10,
    Max = 45,
    Rounding = 1,
    Callback = function(value)
        Settings.MoveSpeed = value
        Log("Скорость " .. value)
    end
})

-- New: Breaking Method Dropdown
Tabs.Main:AddDropdown("BreakingMethodDropdown", {
    Title = "Breaking Method",
    Description = "Crowbar or Lockpick",
    Values = {"Crowbar", "Lockpick"},
    Default = Settings.BreakingMethod,
    Callback = function(value)
        Settings.BreakingMethod = value
        Log("Метод взлома: " .. value)
    end
})

-- New: Auto Deposit
Tabs.Advanced:AddToggle("AutoDepositToggle", {
    Title = "Auto Deposit",
    Description = "Deposit cash when above threshold",
    Default = false,
    Callback = function(value)
        Settings.AutoDeposit = value
        Log("Автодепозит " .. (value and "ВКЛ" or "ВЫКЛ"))
    end
})
Tabs.Advanced:AddSlider("DepositThresholdSlider", {
    Title = "Deposit Threshold (k)",
    Description = "",
    Default = 5,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(value)
        Settings.DepositThresholdK = value
        Log("Порог депозита: " .. value .. "k")
    end
})
Tabs.Advanced:AddButton("DepositNowButton", {
    Title = "Deposit Now",
    Description = "",
    Callback = function()
        Fluent:Notify({ Title = "Deposit", Content = "Попытка депозита...", Duration = 2 })
        pcall(tryDepositAllNow)
    end
})

-- New: Auto Allowance
Tabs.Advanced:AddToggle("AutoAllowanceToggle", {
    Title = "Auto Claim Allowance",
    Description = "",
    Default = false,
    Callback = function(value)
        Settings.AutoAllowance = value
        Log("Автополучение пособия " .. (value and "ВКЛ" or "ВЫКЛ"))
        if value then pcall(claimAllowance) end
    end
})

-- New: Anti Fall Damage
Tabs.Advanced:AddToggle("NoFallToggle", {
    Title = "Anti Fall Damage",
    Description = "",
    Default = false,
    Callback = function(value)
        Settings.NoFall = value
        setNoFall(value)
        Log("Анти-падение " .. (value and "ВКЛ" or "ВЫКЛ"))
    end
})

-- New: Admin Check
Tabs.Advanced:AddToggle("AdminCheckToggle", {
    Title = "Admin Check",
    Description = "Stop farm if admin detected",
    Default = false,
    Callback = function(value)
        Settings.AdminCheck = value
        Log("Проверка администраторов " .. (value and "ВКЛ" or "ВЫКЛ"))
    end
})

-- New: Anti Rejoin
Tabs.Advanced:AddToggle("AntiRejoinToggle", {
    Title = "Anti Error/kick",
    Description = "Auto rejoin on disconnect",
    Default = false,
    Callback = function(value)
        antiRejoinEnabled = value
        if value then installAntiRejoin() end
        Log("Анти-вылет " .. (value and "ВКЛ" or "ВЫКЛ"))
    end
})

-- New: Auto Notify
Tabs.Advanced:AddToggle("AutoNotifyToggle", {
    Title = "Auto Webhook Notify",
    Description = "",
    Default = false,
    Callback = function(value)
        Settings.AutoNotify = value
        Log("Автоуведомления " .. (value and "ВКЛ" or "ВЫКЛ"))
    end
})
Tabs.Advanced:AddSlider("NotifyMinutesSlider", {
    Title = "Notify Interval (minutes)",
    Description = "",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Callback = function(value)
        Settings.NotifyMinutes = value
        Log("Интервал уведомлений: " .. value .. " мин")
    end
})
Tabs.Advanced:AddTextbox("WebhookTextbox", {
    Title = "Webhook URL",
    Description = "",
    Default = Settings.WebhookURL,
    Callback = function(value)
        Settings.WebhookURL = value
        saveRuntimeState()
        Log("Webhook установлен")
    end
})

-- New: Auto Play
Tabs.Advanced:AddToggle("AutoPlayToggle", {
    Title = "Auto Play",
    Description = "Auto start farm on load",
    Default = false,
    Callback = function(value)
        Settings.AutoPlay = value
        if value then
            detectLoadTime()
            spawnTask(autoPlayWorker)
        end
        Log("Автозапуск " .. (value and "ВКЛ" or "ВЫКЛ"))
    end
})

-- Visuals Tab (original)
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

-- Stats Tab (original + extended)
local statusPara = Tabs.Stats:AddParagraph({
    Title = "Статус",
    Content = "Загрузка..."
})
local safesPara = Tabs.Stats:AddParagraph({
    Title = "Сейфы",
    Content = "0/0"
})
local registersPara = Tabs.Stats:AddParagraph({
    Title = "Кассы",
    Content = "0/0"
})
local remainingPara = Tabs.Stats:AddParagraph({
    Title = "Осталось",
    Content = "0/0"
})
local suggestionPara = Tabs.Stats:AddParagraph({
    Title = "Совет",
    Content = "Загрузка..."
})
-- New stats
local earnedPara = Tabs.Stats:AddParagraph({
    Title = "Заработано",
    Content = "0"
})
local deathsPara = Tabs.Stats:AddParagraph({
    Title = "Смертей",
    Content = "0"
})
local timePara = Tabs.Stats:AddParagraph({
    Title = "Время фермы",
    Content = "0 сек"
})

task.spawn(function()
    while true do
        if Settings.Enabled then
            statusPara:SetDesc(StatusText)
            safesPara:SetDesc(AvailableSafesCount .. "/" .. TotalSafesCount)
            registersPara:SetDesc(AvailableRegistersCount .. "/" .. TotalRegistersCount)
            remainingPara:SetDesc((AvailableSafesCount + AvailableRegistersCount) .. "/" .. (TotalSafesCount + TotalRegistersCount))
            suggestionPara:SetDesc(SuggestionText)
            earnedPara:SetDesc(tostring(math.floor(earnedMoneyTotal)))
            deathsPara:SetDesc(tostring(deathCount))
            timePara:SetDesc(tostring(math.floor(farmTimeSeconds)) .. " сек")
        else
            statusPara:SetDesc("Ожидание")
            safesPara:SetDesc("0/0")
            registersPara:SetDesc("0/0")
            remainingPara:SetDesc("0/0")
            suggestionPara:SetDesc("Запусти ферму")
            earnedPara:SetDesc("0")
            deathsPara:SetDesc("0")
            timePara:SetDesc("0 сек")
        end
        task.wait(0.5)
    end
end)

Fluent:Notify({ Title = "AutoFarm", Content = "Загружено", Duration = 2 })

-- Start farm loop automatically if needed (but toggle will start it)
-- Main loop is spawned from toggle callback.