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
    MaxSomething = 999999
}

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

local function Log(msg)
    if Settings.DebugPrintEnabled then
        print("[AutoFarm]", msg)
    end
end

local VirtualUser = game:GetService("VirtualUser")
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

local function CleanupTempIgnored()
    local now = tick()
    for obj, expiry in pairs(Settings.TempIgnored) do
        if now > expiry then
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

local function HackSafe(safeObj)
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
    local bredFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("BredMakurz") or Workspace:FindFirstChild("Filter") and Workspace.Filter:FindFirstChild("BredMakurz")
    if not bredFolder then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "BredMakurz" and obj:IsA("Folder") then
                bredFolder = obj
                break
            end
        end
    end
    if not bredFolder then return end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in ipairs(bredFolder:GetChildren()) do
        local nameLower = obj.Name:lower()
        if nameLower:find("safe") or nameLower:find("register") then
            local mainPart = obj.PrimaryPart or obj:FindFirstChildOfClass("BasePart")
            if not mainPart then continue end
            if mainPart.Position.Y < 4.8 then continue end
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
                            if e.highlight then
                                e.highlight.FillColor = Color3.new(1, 0, 0)
                            end
                        else
                            e.label.TextColor3 = Color3.new(0, 1, 0)
                            if e.highlight then
                                e.highlight.FillColor = Color3.new(0, 1, 0)
                            end
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

local function SetupBrokenTracking()
    Log("Запуск анализа целей...")
    BrokenStatusMap = {}
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

local function MainFarmLoop()
    Log("Цикл автофермы запущен")
    RiseToTargetY()
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
            task.wait(3)
            continue
        end
        RiseToTargetY()
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
            if not LocalPlayer.Character:FindFirstChild("Crowbar") then
                EquipTool("Crowbar")
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



-- ===== Criminality新 core features merged (key verification removed) =====
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


-- ===== Original Criminality UI =====

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "AutoFarm",
    SubTitle = "",
    TabWidth = 120,
    Size = UDim2.fromOffset(450, 400),
    Acrylic = true,
    Theme = "DarkPurple",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Farm", Icon = "zap" }),
    Stats = Window:AddTab({ Title = "Info", Icon = "info" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" })
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

task.spawn(function()
    while true do
        if Settings.Enabled then
            statusPara:SetDesc(StatusText)
            safesPara:SetDesc(AvailableSafesCount .. "/" .. TotalSafesCount)
            registersPara:SetDesc(AvailableRegistersCount .. "/" .. TotalRegistersCount)
            remainingPara:SetDesc((AvailableSafesCount + AvailableRegistersCount) .. "/" .. (TotalSafesCount + TotalRegistersCount))
            suggestionPara:SetDesc(SuggestionText)
        else
            statusPara:SetDesc("Ожидание")
            safesPara:SetDesc("0/0")
            registersPara:SetDesc("0/0")
            remainingPara:SetDesc("0/0")
            suggestionPara:SetDesc("Запусти ферму")
        end
        task.wait(0.5)
    end
end)

Fluent:Notify({ Title = "AutoFarm", Content = "Загружено", Duration = 2 })

task.spawn(MainFarmLoop)