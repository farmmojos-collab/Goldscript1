--[[
  ASTER Hub (Toby) — 3 scripts en uno, sin ventana de opciones:
    • Waypoints  (Gold Circuit / waypoints, con la ruta ya cargada)
    • Boo Lite   (pickup, mine aura, auto eat, farm, craft, campfire, delete)
    • AutoEquip  (hoe si hay Plant Box cerca, pico si no)
  Todo arranca solo con la config por defecto. Lo unico visible es la ventana "Toby"
  (FPS / tiempo / Gold / Bluefruit) con los botones "Seleccionar cofre" y "Start Waypoint".
]]

--========================================================================
-- ASTER HUB (sin ventana): mismas funciones y config, pero sin interfaz.
-- Cada "pestaña" solo guarda los valores y ejecuta los callbacks.
--========================================================================
local Hub = (function()
    local LP = game:GetService("Players").LocalPlayer
    local H = { TabList = {}, OnClose = {} }

    local function guiParent()
        local ok, ui = pcall(function() return gethui and gethui() end)
        if ok and ui then return ui end
        local ok2, core = pcall(function() return game:GetService("CoreGui") end)
        if ok2 and core then
            local probe = Instance.new("Folder")
            local okp = pcall(function() probe.Parent = core end)
            probe:Destroy()
            if okp then return core end
        end
        return LP:WaitForChild("PlayerGui")
    end

    H.Parent = guiParent()
    -- si quedó una ventana vieja de una ejecución anterior, se borra
    local oldHub = H.Parent:FindFirstChild("AsterHubGui")
    if oldHub then oldHub:Destroy() end

    function H:Close()
        for _, fn in ipairs(H.OnClose) do pcall(fn) end
    end

    function H:CreateTab(name)
        local Tab = { Options = {}, Registry = {}, Name = name }
        table.insert(H.TabList, Tab)

        local function safe(cb, ...)
            if not cb then return end
            local ok, err = pcall(cb, ...)
            if not ok then warn("[Hub:" .. name .. "] " .. tostring(err)) end
        end

        function Tab:AddLabel(text)
            return { Text = tostring(text) }
        end

        function Tab:AddToggle(tname, default, cb)
            local state = default and true or false
            local reg = {}
            -- cambia solo el estado (no dispara el callback)
            function reg.SetValue(a, c)
                local v = a
                if type(a) == "table" then v = c end
                state = v and true or false
            end
            function reg.GetValue() return state end
            -- cambia el estado y ejecuta el callback (como si se tocara el boton)
            function reg.Fire(v)
                state = v and true or false
                safe(cb, state)
            end
            Tab.Registry[tname] = reg
            return reg
        end

        function Tab:AddSlider(sname, min, max, default, step, cb)
            local current = tonumber(default) or min
            local obj = {}
            function obj:GetValue() return current end
            function obj:SetValue(v)
                current = tonumber(v) or current
                safe(cb, current)
            end
            Tab.Registry[sname] = obj
            return obj
        end

        function Tab:AddButton(bname, cb)
            Tab.Registry[bname] = { Fire = function() safe(cb) end }
        end

        function Tab:AddInput(iname, default, cb)
            local current = default or ""
            local obj = {}
            function obj:GetValue() return current end
            function obj:SetValue(v)
                current = v
                safe(cb, v)
            end
            Tab.Registry[iname] = obj
            return obj
        end

        function Tab:AddDropdown(dname, values, default, cb)
            local vals = values or {}
            local current = default
            local obj = {}
            function obj:SetValues(v) vals = v or {} end
            function obj:SetValue(v)
                current = v
                safe(cb, v)
            end
            function obj:GetValue() return current end
            Tab.Registry[dname] = obj
            return obj
        end

        return Tab
    end

    return H
end)()

local TabWaypoints = Hub:CreateTab("Waypoints")
local TabBoo = Hub:CreateTab("Boo Lite")
local TabEquip = Hub:CreateTab("AutoEquip")



--========================================================================
-- VENTANA "TOBY": FPS / tiempo / Gold / Bluefruit + botones (cofre y waypoint)
--========================================================================
task.spawn(function()
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local startTime = tick()

    local C_BTN = Color3.fromRGB(55, 55, 55)
    local C_ON = Color3.fromRGB(40, 110, 60)

    local old = Hub.Parent:FindFirstChild("AsterStatsGui")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "AsterStatsGui"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 998
    sg.Parent = Hub.Parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(300, 250)
    frame.Position = UDim2.new(1, -320, 0, 120)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    -- titulo chico: Toby
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -8, 0, 16)
    title.Position = UDim2.fromOffset(8, 3)
    title.BackgroundTransparency = 1
    title.Text = "Toby"
    title.TextColor3 = Color3.fromRGB(255, 215, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    -- stats con letra mas grande
    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -16, 0, 112)
    body.Position = UDim2.fromOffset(8, 22)
    body.BackgroundTransparency = 1
    body.Text = ""
    body.TextColor3 = Color3.new(1, 1, 1)
    body.Font = Enum.Font.Gotham
    body.TextSize = 22
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top
    body.Parent = frame

    local function makeButton(text, y)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -16, 0, 44)
        b.Position = UDim2.fromOffset(8, y)
        b.BackgroundColor3 = C_BTN
        b.BorderSizePixel = 0
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 19
        b.Text = text
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end
    local chestBtn = makeButton("Seleccionar cofre", 140)
    local startBtn = makeButton("Start Waypoint", 193)

    local function chestReg() return TabBoo.Registry["Select Chest (click chest)"] end
    local function startReg() return TabWaypoints.Registry["Start Tween"] end

    local function refreshButtons()
        local c, w = chestReg(), startReg()
        local choosing = c and c.GetValue()
        chestBtn.Text = choosing and "Toca un cofre..." or "Seleccionar cofre"
        chestBtn.BackgroundColor3 = choosing and C_ON or C_BTN
        local running = w and w.GetValue()
        startBtn.Text = running and "Stop Waypoint" or "Start Waypoint"
        startBtn.BackgroundColor3 = running and C_ON or C_BTN
    end

    -- Seleccionar cofre: activa el modo "elegir cofre", despues toca un Chest / Reinforced Chest
    chestBtn.Activated:Connect(function()
        local c = chestReg()
        if not c then return end
        c.Fire(not c.GetValue())
        refreshButtons()
    end)

    -- Start Waypoint: empieza / detiene el recorrido por la ruta
    startBtn.Activated:Connect(function()
        local w = startReg()
        if not w then return end
        w.Fire(not w.GetValue())
        refreshButtons()
    end)

    -- arrastrar (mouse y touch)
    local dragging, dragStart, startPos = false, nil, nil
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    local dragConn = UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    -- FPS
    local frames, fps = 0, 0
    local fpsConn = RunService.RenderStepped:Connect(function() frames = frames + 1 end)

    local alive = true
    table.insert(Hub.OnClose, function()
        alive = false
        if dragConn then dragConn:Disconnect() end
        if fpsConn then fpsConn:Disconnect() end
        sg:Destroy()
    end)

    local function qty(name)
        local b = getgenv and getgenv().BooLite
        if not b or not b.getQuantity then return "-" end
        local ok, v = pcall(b.getQuantity, name)
        if ok and v ~= nil then return tostring(v) end
        return "-"
    end

    local lastT = tick()
    while alive do
        task.wait(0.5)
        local now = tick()
        fps = math.floor(frames / math.max(now - lastT, 0.001) + 0.5)
        frames, lastT = 0, now

        local t = math.floor(now - startTime)
        body.Text = string.format("FPS: %d\nTiempo: %02d:%02d:%02d\nGold: %s\nBluefruit: %s",
            fps, math.floor(t / 3600), math.floor(t / 60) % 60, t % 60, qty("Gold"), qty("Bluefruit"))
        refreshButtons()
    end
end)



--========================================================================
-- PESTAÑA 1: WAYPOINTS / GOLD CIRCUIT (ASTERWaypoints.lua, sin su UI)
--========================================================================
local function loadWaypoints()
    WaypointUI = TabWaypoints  -- la UI de esta pestaña reemplaza a la de ASTER

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
TweenService = game:GetService("TweenService")
local plr = Players.LocalPlayer
runs = game:GetService("RunService")
httpservice = game:GetService("HttpService")

-- ===== Dependencias (copiadas del script original; solo se crean si no existen) =====
if type(isRuntimeSessionActive) ~= "function" then
    function getAsterEnv()
        if type(getgenv) == "function" then
            local ok, env = pcall(getgenv)
            if ok and type(env) == "table" then
                return env
            end
        end
        error("[ASTER] getgenv() is required")
    end

    __ASTER_RUNTIME = getAsterEnv().__ASTER_RUNTIME
    if type(__ASTER_RUNTIME) ~= "table" then
        __ASTER_RUNTIME = { connections = {} }
        getAsterEnv().__ASTER_RUNTIME = __ASTER_RUNTIME
    elseif type(__ASTER_RUNTIME.connections) ~= "table" then
        __ASTER_RUNTIME.connections = {}
    end
    -- Bump session on each execution so stale background loops exit after reinject.
    __ASTER_RUNTIME.sessionId = (__ASTER_RUNTIME.sessionId or 0) + 1
    CURRENT_SESSION = __ASTER_RUNTIME.sessionId
    __ASTER_RUNTIME.waypointDropdownLoopStarted = false

    function isRuntimeSessionActive(session)
        local rt = getAsterEnv().__ASTER_RUNTIME
        if type(rt) ~= "table" then return false end
        return session == rt.sessionId
    end

    function trackConnection(key, conn)
        local rt = getAsterEnv().__ASTER_RUNTIME
        if type(rt) ~= "table" then
            return conn
        end
        if type(rt.connections) ~= "table" then
            rt.connections = {}
        end
        local old = rt.connections[key]
        if old and old.Disconnect then
            pcall(function() old:Disconnect() end)
        end
        rt.connections[key] = conn
        return conn
    end

    -- Canonical world folders (Booga workspace layout).
    function getWorkspaceResources()
        local f = workspace:FindFirstChild("Resources")
        if f then return f end
        return nil
    end
    function getWorkspaceDeployables()
        local f = workspace:FindFirstChild("Deployables")
        if f then return f end
        return nil
    end

    originalCollision = originalCollision or {}
    function captureCollisionState()
        originalCollision = {}
        if plr.Character then
            for _, part in pairs(plr.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    originalCollision[part] = part.CanCollide
                end
            end
        end
    end
    if plr.Character then captureCollisionState() end
    plr.CharacterAdded:Connect(function() task.wait(1) captureCollisionState() end)

    -- Settings usados por este modulo (valores iniciales)
    Settings = Settings or {}
    Settings.GoldCircuitEnabled = Settings.GoldCircuitEnabled or false
    Settings.recordedPositions = Settings.recordedPositions or {}
    Settings.recordingPath = Settings.recordingPath or false
    Settings.recordInterval = Settings.recordInterval or 1.0
    Settings.GoldNoclip = Settings.GoldNoclip or false
    Settings.GoldVisual = Settings.GoldVisual or false
    Settings.GoldSpeed = Settings.GoldSpeed or 19
    if Settings.GoldDelay == nil then Settings.GoldDelay = 0 end
    if Settings.GoldWaitUntilMined == nil then Settings.GoldWaitUntilMined = true end
    Settings.GoldMaxWait = Settings.GoldMaxWait or 20
    Settings.WaterTweenEnabled = Settings.WaterTweenEnabled or false
end

-- ===== Gold Detect Range y dependencias (valores por defecto) =====
Settings = Settings or {}
Settings.GoldDetectRange = tonumber(Settings.GoldDetectRange) or 14
if Settings.GoldWaitUntilMined == nil then Settings.GoldWaitUntilMined = true end
Settings.GoldMaxWait = tonumber(Settings.GoldMaxWait) or 20

function getGoldPathList()
    local list = {"None"}
    local folder = "ASTERTween"
    if not isfolder(folder) then makefolder(folder) end
    for _, file in ipairs(listfiles(folder)) do
        if file:find(".json") then
            -- Use exact filename matching to prevent partial matches
            table.insert(list, file:match("([^/\\]+)%.json$"))
        end
    end
    return list
end

function saveCurrentPath(name)
    if #Settings.recordedPositions == 0 then return false end
    local folder = "ASTERTween"
    if not isfolder(folder) then makefolder(folder) end
    writefile(folder .. "/" .. name .. ".json", httpservice:JSONEncode({positions=Settings.recordedPositions}))
    return true
end

function loadPath(name)
    if name == "None" then return false end
    local path = "ASTERTween/" .. name .. ".json"
    if not isfile(path) then return false end
    local success, data = pcall(function() return httpservice:JSONDecode(readfile(path)) end)
    if success and data then Settings.recordedPositions = data.positions return true end
    return false
end

function updateVisualNodes()
    local f = workspace:FindFirstChild("GoldNodes")
    if not Settings.GoldVisual then if f then f:Destroy() end return end
    if not f then f = Instance.new("Folder", workspace) f.Name = "GoldNodes" end
    f:ClearAllChildren()
    -- Render Optimization: Only show waypoints near the player
    local RENDER_DISTANCE = 300 
    
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    local playerPos = hrp and hrp.Position or Vector3.new(0,0,0)

    for i, pos in ipairs(Settings.recordedPositions) do
        -- Show ALL waypoints (Distance check removed as requested)
        if true then
            local p = Instance.new("Part", f)
            p.Size = Vector3.new(0.3, 0.3, 0.3)
            p.Position = Vector3.new(pos.X, pos.Y, pos.Z)
            p.Anchored = true
            p.CanCollide = false
            p.Color = Color3.fromRGB(255, 215, 0)
            p.Transparency = 0.5
            p.Material = Enum.Material.Neon
            
            -- Add floating number (Restored Circular Style)
            local bg = Instance.new("BillboardGui", p)
            bg.Size = UDim2.new(0, 20, 0, 20)
            bg.StudsOffset = Vector3.new(0, 1.5, 0)
            bg.AlwaysOnTop = true
            
            local frame = Instance.new("Frame", bg)
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            frame.BackgroundTransparency = 0.3
            
            local corner = Instance.new("UICorner", frame)
            corner.CornerRadius = UDim.new(1, 0) -- Circular
            
            local border = Instance.new("UIStroke", frame)
            border.Color = Color3.fromRGB(255, 215, 0) -- Gold border
            border.Thickness = 1.5
            border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            
            local tl = Instance.new("TextLabel", frame)
            tl.Size = UDim2.new(1, 0, 1, 0)
            tl.BackgroundTransparency = 1
            tl.Text = tostring(i)
            tl.TextColor3 = Color3.new(1, 1, 1)
            tl.TextSize = 10
            tl.Font = Enum.Font.GothamBold
        end
    end
end

function initializeCircuit()
    local pathFolder = "ASTERTween"
    local fileName = "GoldCircuit.json"
    local filePath = pathFolder .. "/" .. fileName
    -- 1. ONLY run this if the folder doesn't exist yet
    if not isfolder(pathFolder) then

        makefolder(pathFolder)

        -- 2. Your coordinate string (Paste inside the [[ ]])
        local rawData = [[
            
        ]] 

        if rawData ~= " " and rawData ~= "" then
            local success, decoded = pcall(function() 
                return httpservice:JSONDecode(rawData) 
            end)
            
            if success and decoded then
                writefile(filePath, rawData) -- Save it so we skip the string next time
                Settings.recordedPositions = decoded.positions

            else

            end
        end
    else
        -- 3. If folder exists, we skip the long string and just load the file
        if isfile(filePath) then

            local success, data = pcall(function() 
                return httpservice:JSONDecode(readfile(filePath)) 
            end)
            if success and data then
                Settings.recordedPositions = data.positions
            end
        end
    end
end

-- MOVEMENT & GOLD LOGIC
currentWaypoint = 1
isTweening = false
walkingToWaypoint = false
isWaitingForWaypoint = false -- New: Track if waiting at a waypoint
waypointWaitStartTime = 0 -- New: Track when wait started
alignPosition = nil
alignAttachment0 = nil
alignAttachment1 = nil
restoreCollision = nil

rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
function updateRayParams()
    if plr.Character then rayParams.FilterDescendantsInstances = {plr.Character} end
end
plr.CharacterAdded:Connect(updateRayParams)
if plr.Character then updateRayParams() end

GOLD_SPEED_MAX = 30 -- velocidad maxima permitida en el slider (antes 16)
WALK_SPEED = 16
NEAR_GOLD_SPEED = 16
SPEED_VARIANCE = 0.05
SPEED_CHANGE_INTERVAL = 0.5
lastSpeedChange = tick()
currentSpeedMultiplier = 1

function getRandomizedSpeed(baseSpeed)
    if tick() - lastSpeedChange > SPEED_CHANGE_INTERVAL then
        if baseSpeed <= 0 then return baseSpeed end
        local minSpeed = baseSpeed - 0.5
        local maxSpeed = baseSpeed
        local chosenSpeed = minSpeed + (math.random() * (maxSpeed - minSpeed))
        currentSpeedMultiplier = chosenSpeed / baseSpeed
        lastSpeedChange = tick()
    end
    return baseSpeed * currentSpeedMultiplier
end

function hasLineOfSight(startPos, endPos)
    local direction = (endPos - startPos)
    local distance = direction.Magnitude
    if distance < 1 then return true end
    local rayResult = workspace:Raycast(startPos + Vector3.new(0, 2, 0), direction, rayParams)
    if rayResult then
        local hitDist = (rayResult.Position - startPos).Magnitude
        if hitDist < (distance * 0.9) then return false end
    end
    return true
end

function wouldTweenHitTerrain(startPos, endPos)
    local sampleCount = 3 
    local direction = (endPos - startPos)
    for i = 0, sampleCount do
        local t = i / sampleCount
        local samplePos = startPos + (direction * t)
        local ray = workspace:Raycast(samplePos, Vector3.new(0, -5, 0), rayParams)
        if not ray then continue end
        if ray and samplePos.Y < ray.Position.Y then return true, samplePos end
    end
    return false
end

function isPathClearToTarget(startPos, endPos)
    local direction = (endPos - startPos)
    local distance = direction.Magnitude
    if distance < 1 then return true end
    direction = direction.Unit
    local rayOrigin = startPos + Vector3.new(0, 2, 0)
    local rayDirection = (endPos + Vector3.new(0, 2, 0)) - rayOrigin
    local ray = workspace:Raycast(rayOrigin, rayDirection, rayParams)
    if ray then
        local hitDistance = (ray.Position - rayOrigin).Magnitude
        local targetDistance = (endPos - startPos).Magnitude
        if hitDistance < (targetDistance * 0.9) then return false, ray.Position end
    end
    return true
end

function hasGroundBeneath(position)
    local ray = workspace:Raycast(position, Vector3.new(0, -100, 0), rayParams)
    if ray then
        local hitPart = ray.Instance
        if hitPart and hitPart:IsA("BasePart") then
            local distance = (position - ray.Position).Magnitude
            return true, distance, ray.Position
        end
    end
    return false, 999, nil
end

function isAboveWater(position)
    if position.Y > 100 then return false end 
    local ray = workspace:Raycast(position, Vector3.new(0, -200, 0), rayParams)
    if ray and ray.Instance and ray.Instance:IsA("Terrain") then
        local region = Region3.new(ray.Position - Vector3.new(4, 4, 4), ray.Position + Vector3.new(4, 4, 4))
        region = region:ExpandToGrid(4)
        local materials, sizes = workspace.Terrain:ReadVoxels(region, 4)
        local size = materials.Size
        for x = 1, size.X do
            for y = 1, size.Y do
                for z = 1, size.Z do
                    if materials[x][y][z] == Enum.Material.Water then return true end
                end
            end
        end
    end
    return false
end

function findNearestAccessibleWaypoint(currentPos)
    if Settings.recordedPositions and #Settings.recordedPositions > 0 then
        local biasCandidates = {}
        table.insert(biasCandidates, currentWaypoint)
        local prev = currentWaypoint - 1
        if prev < 1 then prev = #Settings.recordedPositions end
        if prev ~= currentWaypoint then table.insert(biasCandidates, prev) end

        for _, idx in ipairs(biasCandidates) do
            local pos = Settings.recordedPositions[idx]
            if pos then
                local waypoint = Vector3.new(pos.X, pos.Y, pos.Z)
                local dist = (waypoint - currentPos).Magnitude
                if dist < 60 then
                    local hasLOS = hasLineOfSight(currentPos, waypoint)
                    local wouldHitTerrain = wouldTweenHitTerrain(currentPos, waypoint)
                    if hasLOS and not wouldHitTerrain then
                        return idx, dist, true
                    end
                end
            end
        end
    end

    local closestIndex = currentWaypoint
    local closestDist = math.huge
    local foundAccessible = false
    if not Settings.recordedPositions or #Settings.recordedPositions == 0 then return currentWaypoint, math.huge, false end
    for idx, pos in ipairs(Settings.recordedPositions) do
        if pos and pos.X and pos.Y and pos.Z then
            local waypoint = Vector3.new(pos.X, pos.Y, pos.Z)
            local dist = (waypoint - currentPos).Magnitude
            if dist < closestDist then
                if dist > 150 then continue end
                local hasLOS = hasLineOfSight(currentPos, waypoint)
                local wouldHitTerrain = wouldTweenHitTerrain(currentPos, waypoint)
                if hasLOS and not wouldHitTerrain then
                    closestDist = dist
                    closestIndex = idx
                    foundAccessible = true
                end
            end
        end
    end
    if not foundAccessible then
        closestDist = math.huge
        for idx, pos in ipairs(Settings.recordedPositions) do
            if pos and pos.X and pos.Y and pos.Z then
                local waypoint = Vector3.new(pos.X, pos.Y, pos.Z)
                local dist = (waypoint - currentPos).Magnitude
                if dist < closestDist then closestDist = dist closestIndex = idx end
            end
        end
    end
    return closestIndex, closestDist, foundAccessible
end

function createAlignPosition(hrp)
    if alignPosition then alignPosition:Destroy() end
    if alignAttachment0 then alignAttachment0:Destroy() end
    if alignAttachment1 then alignAttachment1:Destroy() end
    alignAttachment0 = Instance.new("Attachment") alignAttachment0.Parent = hrp
    alignAttachment1 = Instance.new("Attachment") alignAttachment1.Parent = workspace.Terrain
    alignPosition = Instance.new("AlignPosition")
    alignPosition.Attachment0 = alignAttachment0
    alignPosition.Attachment1 = alignAttachment1
    alignPosition.MaxForce = 400000 
    alignPosition.MaxVelocity = 100
    alignPosition.Responsiveness = 200
    alignPosition.ApplyAtCenterOfMass = true
    alignPosition.Parent = hrp
    return alignPosition, alignAttachment1
end

function removeAlignPosition()
    if alignPosition then alignPosition:Destroy() alignPosition = nil end
    if alignAttachment0 then alignAttachment0:Destroy() alignAttachment0 = nil end
    if alignAttachment1 then alignAttachment1:Destroy() alignAttachment1 = nil end
end

function removeBodyVelocity(hrp)
    local bv = hrp:FindFirstChild("CircuitBodyVelocity")
    if bv then bv:Destroy() end
    local bg = hrp:FindFirstChild("CircuitBodyGyro")
    if bg then bg:Destroy() end
end

function tweenToWaypoint(hrp, hum, target, speed)
    removeBodyVelocity(hrp)
    hum:ChangeState(Enum.HumanoidStateType.Freefall) 
    if not alignPosition then createAlignPosition(hrp) end
    alignAttachment1.WorldPosition = target
    alignPosition.MaxVelocity = speed
    isTweening = true
end

function walkToWaypoint(hrp, hum, target, speed)
    local bv = hrp:FindFirstChild("CircuitBodyVelocity")
    local bg = hrp:FindFirstChild("CircuitBodyGyro")
    if not bv then bv = Instance.new("BodyVelocity") bv.Name = "CircuitBodyVelocity" bv.Parent = hrp end
    if not bg then bg = Instance.new("BodyGyro") bg.Name = "CircuitBodyGyro" bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge) bg.P = 9000 bg.Parent = hrp end
    local direction = (target - hrp.Position)
    local flatDirection = Vector3.new(direction.X, 0, direction.Z)
    if flatDirection.Magnitude > 0 then
        flatDirection = flatDirection.Unit
        bv.MaxForce = Vector3.new(math.huge, 0, math.huge)
        bv.Velocity = flatDirection * speed
        local lookDirection = Vector3.new(direction.X, 0, direction.Z)
        if lookDirection.Magnitude > 0 then
            lookDirection = lookDirection.Unit
            bg.CFrame = CFrame.new(hrp.Position, hrp.Position + lookDirection)
        end
    end
    if tick() % 0.5 < 0.05 then hum:MoveTo(target) end
end

antiFlipGyro = nil
function enableAntiFlip(hrp)
    if not antiFlipGyro then
        antiFlipGyro = Instance.new("BodyGyro")
        antiFlipGyro.Name = "AntiFlipGyro"
        antiFlipGyro.MaxTorque = Vector3.new(math.huge, 0, math.huge)
        antiFlipGyro.P = 9000
        antiFlipGyro.CFrame = CFrame.new()
        antiFlipGyro.Parent = hrp
    end
end
function disableAntiFlip() if antiFlipGyro then antiFlipGyro:Destroy() antiFlipGyro = nil end end

restoreCollision = function()
    if plr.Character then
        local character = plr.Character
        local hum = character:FindFirstChild("Humanoid")
        local hrp = character:FindFirstChild("HumanoidRootPart")
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                local wanted = originalCollision[part]
                if wanted ~= nil then part.CanCollide = wanted end
            end
        end
        if hum then hum:ChangeState(Enum.HumanoidStateType.Running) hum.PlatformStand = false hum.Sit = false hum.AutoRotate = true end
        if hrp then hrp.Velocity = Vector3.new(0, 0, 0) hrp.RotVelocity = Vector3.new(0, 0, 0) end
    end
end

movementConnection = nil
walkAttemptTimer = 0
maxWalkAttemptTime = 3
stuckCheckWaypoint = nil
stuckCheckStartDistance = nil
stuckCheckTimer = 0
STUCK_CHECK_INTERVAL = 3
MINIMUM_PROGRESS = 2
waterTweenActive = false
positionHistory = {}
maxHistorySize = 5

noclipTimer = 0
local noclipWorldParts = {}

function disableWorldCollision(part)
    if not part or not part:IsA("BasePart") then return end
    if noclipWorldParts[part] ~= nil then return end
    noclipWorldParts[part] = part.CanCollide
    part.CanCollide = false
end

function restoreWorldNoclip()
    for part, wanted in pairs(noclipWorldParts) do
        if part and part.Parent then
            part.CanCollide = wanted
        end
    end
    noclipWorldParts = {}
end

function noclip()
    if not Settings.GoldNoclip and not isTweening then return end
    local waitTime = 0.15
    if Settings.GoldNoclip and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        waitTime = 0.3
    end
    if tick() - noclipTimer < waitTime then return end
    noclipTimer = tick()
    if plr.Character then
        local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
        for _, part in pairs(plr.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                if isTweening then
                    part.CanCollide = false
                else
                    if not (part.Name:find("Leg") or part.Name:find("Foot")) then
                        part.CanCollide = false
                    end
                end
            end
        end
        if Settings.GoldNoclip and hrp then
            pcall(function()
                local hrpPos = hrp.Position
                local radiusSq = 55 * 55
                local resources = getWorkspaceResources()
                if resources then
                    for _, model in ipairs(resources:GetChildren()) do
                        if model.Name == "Old Boards" then
                            local union = model:FindFirstChild("Union")
                            if union and union:IsA("BasePart") then
                                local d = union.Position - hrpPos
                                if d.X * d.X + d.Y * d.Y + d.Z * d.Z <= radiusSq then
                                    disableWorldCollision(union)
                                end
                            end
                        end
                    end
                end
                local deployables = getWorkspaceDeployables()
                if deployables then
                    for _, item in ipairs(deployables:GetChildren()) do
                        local pos
                        if item:IsA("BasePart") then
                            pos = item.Position
                        elseif item:IsA("Model") then
                            local ok, pivotPos = pcall(function() return item:GetPivot().Position end)
                            if ok then pos = pivotPos end
                        end
                        if pos then
                            local d = pos - hrpPos
                            if d.X * d.X + d.Y * d.Y + d.Z * d.Z <= 40 * 40 then
                                if item:IsA("BasePart") then
                                    disableWorldCollision(item)
                                else
                                    for _, p in ipairs(item:GetDescendants()) do
                                        if p:IsA("BasePart") then disableWorldCollision(p) end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end

function startMovementEngine()
    if movementConnection then return end
    positionHistory = {}
    local lastFramePos = nil
    local isWaitingForDelay = false
    local delayStartTime = 0
    local goldWaitNode = nil -- gold node que se está picando mientras esperamos
    -- ¿este modelo es un gold node? (nombre con "gold node", EntityID 422, o recurso con "gold" en el nombre)
    local function isGoldNodeModel(m)
        if not m or not m:IsA("Model") then return false end
        local lname = m.Name:lower()
        if lname:find("gold node", 1, true) or m:GetAttribute("EntityID") == 422 then return true end
        if lname:find("gold", 1, true) and (m.Parent == workspace:FindFirstChild("Resources") or m.Parent == workspace:FindFirstChild("Mounds")) then
            return true
        end
        return false
    end
    -- mismo método que el Mine Aura: escanea una caja alrededor, sube por los modelos de cada parte
    -- y mide la distancia hasta el centro del modelo. Las paredes y el techo no influyen.
    local function findNearbyGoldNode(pos, radius)
        local ignore = { workspace.Terrain }
        local playersFolder = workspace:FindFirstChild("Players")
        if playersFolder then table.insert(ignore, playersFolder) end
        local itemsFolder = workspace:FindFirstChild("Items")
        if itemsFolder then table.insert(ignore, itemsFolder) end
        if plr.Character then table.insert(ignore, plr.Character) end
        for _, o in ipairs(game:GetService("CollectionService"):GetTagged("Contents")) do table.insert(ignore, o) end
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore
        local side = radius * 2 + 4
        local parts = workspace:GetPartBoundsInBox(CFrame.new(pos), Vector3.new(side, side, side), params)
        local best, bestDist, seen = nil, radius, {}
        for _, part in ipairs(parts) do
            local m = part
            while m and m ~= workspace do
                if m:IsA("Model") and not seen[m] then
                    seen[m] = true
                    if isGoldNodeModel(m) then
                        -- distancia al punto mas cercano de la caja del modelo (sirve para nodos grandes o arriba)
                        local d
                        local okB, bcf, bsize = pcall(function() return m:GetBoundingBox() end)
                        if okB and bcf and bsize then
                            local lp = bcf:PointToObjectSpace(pos)
                            local h = bsize / 2
                            d = Vector3.new(math.max(math.abs(lp.X) - h.X, 0), math.max(math.abs(lp.Y) - h.Y, 0), math.max(math.abs(lp.Z) - h.Z, 0)).Magnitude
                        else
                            local okP, piv = pcall(function() return m:GetPivot().Position end)
                            if okP then d = (piv - pos).Magnitude end
                        end
                        if d and d <= bestDist then best, bestDist = m, d end
                    end
                end
                m = m.Parent
            end
        end
        return best, bestDist
    end
    -- diagnostico: si no detecta nada, imprime (F9) que hay con "gold" cerca y a que distancia
    local lastDiagTick = 0
    local goldLogAt = {}
    local function diagnoseGold(pos, radius)
        if tick() - lastDiagTick < 3 then return end
        lastDiagTick = tick()
        local ignore = { workspace.Terrain }
        if plr.Character then table.insert(ignore, plr.Character) end
        local playersFolder = workspace:FindFirstChild("Players")
        if playersFolder then table.insert(ignore, playersFolder) end
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore
        local okS, parts = pcall(function()
            return workspace:GetPartBoundsInBox(CFrame.new(pos), Vector3.new(120, 120, 120), params)
        end)
        if not okS then return end
        local best, bestD, bestPart = nil, math.huge, nil
        for _, part in ipairs(parts) do
            local m = part
            while m and m ~= workspace do
                if m.Name:lower():find("gold", 1, true) then
                    local d = (part.Position - pos).Magnitude
                    if d < bestD then best, bestD, bestPart = m, d, part end
                    break
                end
                m = m.Parent
            end
        end
        if best then
            print(string.format("[GoldDelay] NO detectado (radio %d). Mas cercano con 'gold': %s [%s] padre=%s a %.1f studs, altura dy=%.1f",
                radius, best.Name, best.ClassName, best.Parent and best.Parent.Name or "?", bestD, bestPart.Position.Y - pos.Y))
        else
            print(string.format("[GoldDelay] NO detectado (radio %d). No hay nada con 'gold' en el nombre a 60 studs", radius))
        end
    end
    local lastDecisionTick = 0
    local cachedShouldTween = false
    local cachedTweenReason = ""
    local cachedWalkSpeed = 20
    movementConnection = runs.Heartbeat:Connect(function(deltaTime)
        if not Settings.GoldCircuitEnabled then
            if movementConnection then movementConnection:Disconnect() movementConnection = nil end
            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then removeBodyVelocity(hrp) end
            local hum0 = plr.Character and plr.Character:FindFirstChild("Humanoid")
            if hum0 then hum0.WalkSpeed = Settings.WalkSpeed or 16 end
            if hrp and not isTweening then table.insert(positionHistory, hrp.Position) if #positionHistory > maxHistorySize then table.remove(positionHistory, 1) end end
            restoreCollision()
            isTweening = false walkingToWaypoint = false walkAttemptTimer = 0 stuckCheckWaypoint = nil stuckCheckStartDistance = nil stuckCheckTimer = 0 isWaitingForWaypoint = false
            isWaitingForDelay = false delayStartTime = 0 goldWaitNode = nil
            lastFramePos = nil
            return
        end
        
        if #Settings.recordedPositions == 0 then return end
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local hum = plr.Character and plr.Character:FindFirstChild("Humanoid")
        if not hrp or not hum then return end
        
        local currentPos = hrp.Position
        if lastFramePos then
            local distMoved = (currentPos - lastFramePos).Magnitude
            if distMoved > 10 then 
                local closestIndex, closestDist = findNearestAccessibleWaypoint(currentPos)
                if closestIndex then
                    currentWaypoint = closestIndex
                    walkingToWaypoint = false
                    isTweening = false
                    if alignPosition then removeAlignPosition() end
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Running) end
                    walkAttemptTimer = 0
                end
            end
        end
        lastFramePos = currentPos

        enableAntiFlip(hrp)
        if (hum.PlatformStand or hum.Sit or hum:GetState() == Enum.HumanoidStateType.FallingDown or hum:GetState() == Enum.HumanoidStateType.Ragdoll) and not isTweening then 
            hum.PlatformStand = false hum.Sit = false hum:ChangeState(Enum.HumanoidStateType.Running) 
        end
        if currentWaypoint > #Settings.recordedPositions then currentWaypoint = 1 walkingToWaypoint = false walkAttemptTimer = 0 removeBodyVelocity(hrp) removeAlignPosition() isTweening = false if hum then hum:ChangeState(Enum.HumanoidStateType.Running) hum.PlatformStand = false end stuckCheckWaypoint = nil stuckCheckStartDistance = nil stuckCheckTimer = 0 isWaitingForWaypoint = false return end
        local targetPos = Settings.recordedPositions[currentWaypoint]
        if not targetPos then currentWaypoint = 1 return end
        local target = Vector3.new(targetPos.X, targetPos.Y, targetPos.Z)
        local currentPos = hrp.Position
        local direction = (target - currentPos)
        local distance = direction.Magnitude
        if walkingToWaypoint and not isTweening then local velocity = hrp.Velocity.Magnitude if velocity < 0.5 and distance > 5 then walkAttemptTimer = walkAttemptTimer + deltaTime if walkAttemptTimer > 1.0 then shouldTween = true walkingToWaypoint = false walkAttemptTimer = 0 end else if velocity > 1 then walkAttemptTimer = 0 end end end
        if not isTweening then
            if stuckCheckWaypoint ~= currentWaypoint then stuckCheckWaypoint = currentWaypoint stuckCheckStartDistance = distance stuckCheckTimer = 0 else
                stuckCheckTimer = stuckCheckTimer + deltaTime
                if stuckCheckTimer >= STUCK_CHECK_INTERVAL then
                    local progressMade = stuckCheckStartDistance - distance
                    if progressMade < MINIMUM_PROGRESS then
                        local closestIndex, closestDist, foundAccessible = findNearestAccessibleWaypoint(hrp.Position)
                        if closestIndex and closestIndex ~= currentWaypoint and foundAccessible then currentWaypoint = closestIndex else currentWaypoint = currentWaypoint + 1 end
                        walkingToWaypoint = false walkAttemptTimer = 0 removeBodyVelocity(hrp) removeAlignPosition() positionHistory = {} stuckCheckWaypoint = nil stuckCheckStartDistance = nil stuckCheckTimer = 0 task.wait(0.5) return
                    else stuckCheckStartDistance = distance stuckCheckTimer = 0 end
                end
            end
        end
        if distance <= 3 then
            -- Waypoint Wait Logic
            local currentWPData = Settings.recordedPositions[currentWaypoint]
            if currentWPData and currentWPData.waitTime and currentWPData.waitTime > 0 then
                if not isWaitingForWaypoint then
                     isWaitingForWaypoint = true
                     waypointWaitStartTime = tick()
                     if isTweening then removeAlignPosition() isTweening = false hum:ChangeState(Enum.HumanoidStateType.Running) if not Settings.GoldNoclip then restoreCollision() end end
                     removeBodyVelocity(hrp)
                     hrp.Velocity = Vector3.new(0,0,0)
                     hum:MoveTo(hrp.Position)
                     return
                else
                     if tick() - waypointWaitStartTime < currentWPData.waitTime then
                         return
                     else
                         isWaitingForWaypoint = false
                     end
                end
            else
                isWaitingForWaypoint = false
            end


            if not isWaitingForDelay then
                local foundGold = false
                goldWaitNode = nil
                local searchRadius = tonumber(Settings.GoldDetectRange) or 13
                local nodeModel, nodeDist = findNearbyGoldNode(hrp.Position, searchRadius)
                if nodeModel then
                    foundGold = true
                    goldWaitNode = nodeModel
                    local now = tick()
                    if not goldLogAt[nodeModel] or now - goldLogAt[nodeModel] > 3 then
                        goldLogAt[nodeModel] = now
                        print(string.format("[GoldDelay] gold node detectado: %s a %.1f studs", nodeModel.Name, nodeDist))
                    end
                else
                    local checkParts = workspace:GetPartBoundsInRadius(hrp.Position, searchRadius)
                    for _, p in pairs(checkParts) do
                        local parentIsGold = p.Parent and (p.Parent.Name:lower():find("gold node") or p.Parent:GetAttribute("EntityID") == 422)
                        local nameMatch = p.Name:lower():find("gold node") or parentIsGold
                        if nameMatch then
                            foundGold = true
                            goldWaitNode = parentIsGold and p.Parent or p
                            break
                        end
                    end
                end

                if not foundGold then diagnoseGold(hrp.Position, searchRadius) end

                print(string.format("[GoldDelay] waypoint %d | radio=%s | esperar hasta picar=%s | delay=%s | max=%s | gold=%s",
                    currentWaypoint, tostring(searchRadius), tostring(Settings.GoldWaitUntilMined),
                    tostring(Settings.GoldDelay), tostring(Settings.GoldMaxWait),
                    foundGold and tostring(goldWaitNode and goldWaitNode.Name) or "no encontrado"))

                if foundGold and (Settings.GoldDelay > 0 or Settings.GoldWaitUntilMined) then
                    isWaitingForDelay = true
                    delayStartTime = tick()
                    if isTweening then removeAlignPosition() isTweening = false hum:ChangeState(Enum.HumanoidStateType.Running) if not Settings.GoldNoclip then restoreCollision() end end
                    removeBodyVelocity(hrp)
                    hrp.Velocity = Vector3.new(0,0,0)
                    return
                end
            else
                local waited = tick() - delayStartTime
                -- espera mientras el gold node siga existiendo (se está picando), con límite de seguridad
                local stillMining = Settings.GoldWaitUntilMined
                    and goldWaitNode ~= nil
                    and goldWaitNode.Parent ~= nil
                    and goldWaitNode:IsDescendantOf(workspace)
                    and waited < (tonumber(Settings.GoldMaxWait) or 20)
                if waited < Settings.GoldDelay or stillMining then
                    return
                else
                    print(string.format("[GoldDelay] fin de espera tras %.1fs | el nodo sigue en el mapa=%s",
                        waited, tostring(goldWaitNode ~= nil and goldWaitNode.Parent ~= nil)))
                    isWaitingForDelay = false
                    goldWaitNode = nil
                end
            end

            local nextIndex = currentWaypoint + 1
            if nextIndex > #Settings.recordedPositions then nextIndex = 1 end
            local currentAboveWater = Settings.WaterTweenEnabled and (isAboveWater(currentPos) or isAboveWater(target))
            local nextAboveWater = false
            local nextPosData = Settings.recordedPositions[nextIndex]
            if nextPosData then local nextVec = Vector3.new(nextPosData.X, nextPosData.Y, nextPosData.Z) nextAboveWater = Settings.WaterTweenEnabled and isAboveWater(nextVec) end
            currentWaypoint = nextIndex walkingToWaypoint = false walkAttemptTimer = 0 stuckCheckWaypoint = nil stuckCheckStartDistance = nil stuckCheckTimer = 0 isWaitingForWaypoint = false
            if isTweening and nextPosData then local nextTarget = Vector3.new(nextPosData.X, nextPosData.Y, nextPosData.Z) tweenToWaypoint(hrp, hum, nextTarget, getRandomizedSpeed(WALK_SPEED)) waterTweenActive = true else
                if isTweening then removeAlignPosition() isTweening = false hum:ChangeState(Enum.HumanoidStateType.Running) if not Settings.GoldNoclip then restoreCollision() end else removeBodyVelocity(hrp) end waterTweenActive = false
            end
            return
        end
        if #positionHistory >= 3 and not isTweening then local previousPos = positionHistory[#positionHistory - 1] if previousPos then local horizontalPrev = Vector2.new(previousPos.X, previousPos.Z) local horizontalCurrent = Vector2.new(currentPos.X, currentPos.Z) local snapDistance = (horizontalCurrent - horizontalPrev).Magnitude if snapDistance > 10 then local closestIndex, closestDist = findNearestAccessibleWaypoint(hrp.Position) if closestIndex and closestIndex ~= currentWaypoint then currentWaypoint = closestIndex else currentWaypoint = currentWaypoint + 1 end positionHistory = {} walkingToWaypoint = false walkAttemptTimer = 0 removeBodyVelocity(hrp) removeAlignPosition() isTweening = false stuckCheckWaypoint = nil stuckCheckStartDistance = nil stuckCheckTimer = 0 task.wait(0.5) return end end end
        if isTweening then
            noclip()
            waterTweenActive = waterTweenActive or (Settings.WaterTweenEnabled and isAboveWater(currentPos))
            if alignPosition then alignPosition.MaxVelocity = getRandomizedSpeed(WALK_SPEED) end
            if stuckCheckStartDistance == nil then stuckCheckStartDistance = distance stuckCheckTimer = 0 end
            stuckCheckTimer = stuckCheckTimer + deltaTime
            if stuckCheckTimer > 5.0 then local progressMade = stuckCheckStartDistance - distance if progressMade < 1 then isTweening = false hum:ChangeState(Enum.HumanoidStateType.Running) removeAlignPosition() stuckCheckTimer = 0 else stuckCheckStartDistance = distance stuckCheckTimer = 0 end end
            return
        end
        if tick() - lastDecisionTick > 0.15 then
            lastDecisionTick = tick()
            local baseWalkSpeed = Settings.WalkSpeedEnabled and Settings.WalkSpeed or WALK_SPEED
            local walkSpeed = baseWalkSpeed
            local goldFound = false
            local nearbyParts = workspace:GetPartBoundsInRadius(hrp.Position, 2) for _, part in pairs(nearbyParts) do local nameMatch = part.Name:lower():find("gold node") or (part.Parent and part.Parent.Name:lower():find("gold node")) if nameMatch then goldFound = true break end end
            if not goldFound then local targetParts = workspace:GetPartBoundsInRadius(target, 2) for _, part in pairs(targetParts) do local nameMatch = part.Name:lower():find("gold node") or (part.Parent and part.Parent.Name:lower():find("gold node")) if nameMatch then goldFound = true break end end end
            if goldFound then walkSpeed = NEAR_GOLD_SPEED end
            cachedWalkSpeed = getRandomizedSpeed(walkSpeed)

            cachedShouldTween = false
            cachedTweenReason = ""
            
            -- FORCED TWEEN ONLY LOGIC FROM ASTERFarm.lua
            if Settings.TweenOnly then
                cachedShouldTween = true
                cachedTweenReason = "Forced"
            else
                local heightDiff = target.Y - currentPos.Y
                local horizontalDist = math.sqrt((target.X - currentPos.X)^2 + (target.Z - currentPos.Z)^2)
                local wouldHitTerrain, hitPoint = wouldTweenHitTerrain(currentPos, target)
                
                if wouldHitTerrain then cachedShouldTween = false elseif heightDiff < -2 then cachedShouldTween = false else
                    local pathClear, hitPos = isPathClearToTarget(currentPos, target)
                    if not pathClear then cachedShouldTween = true cachedTweenReason = "Path blocked" end
                    if heightDiff > 6 and horizontalDist < 10 then cachedShouldTween = true cachedTweenReason = "Steep climb" end
                    local hasGround, groundDistance = hasGroundBeneath(target)
                    if not hasGround or groundDistance > 15 then cachedShouldTween = true cachedTweenReason = "No ground" end
                    if isAboveWater(target) then cachedShouldTween = true cachedTweenReason = "Water" waterTweenActive = true end
                    local directionToTarget = (target - currentPos).Unit
                    local rayToTarget = workspace:Raycast(currentPos, directionToTarget * distance, rayParams)
                    if rayToTarget and rayToTarget.Instance and not rayToTarget.Instance:IsDescendantOf(plr.Character) then cachedShouldTween = true cachedTweenReason = "Wall" end
                end
            end
        end

        if walkingToWaypoint then 
            walkAttemptTimer = walkAttemptTimer + deltaTime 
            if walkAttemptTimer > maxWalkAttemptTime then 
                local horizontalDist = math.sqrt((target.X - currentPos.X)^2 + (target.Z - currentPos.Z)^2)
                local startDist = (Vector3.new(targetPos.X, currentPos.Y, targetPos.Z) - currentPos).Magnitude 
                if startDist > horizontalDist - 5 then cachedShouldTween = true cachedTweenReason = "Stuck walking" walkAttemptTimer = 0 end 
            end 
        end
        
        hum.WalkSpeed = Settings.WalkSpeed or cachedWalkSpeed
        
        if cachedShouldTween then
            if cachedTweenReason == "Water" then waterTweenActive = true end
            walkingToWaypoint = false walkAttemptTimer = 0 stuckCheckStartDistance = distance stuckCheckTimer = 0
            tweenToWaypoint(hrp, hum, target, cachedWalkSpeed)
        else
            if not walkingToWaypoint then walkingToWaypoint = true walkAttemptTimer = 0 end
            walkToWaypoint(hrp, hum, target, cachedWalkSpeed)
        end
    end)
end

local goldNoclipActive = false
do
    local old = __ASTER_RUNTIME.connections["goldNoclip"]
    if old and old.Disconnect then
        pcall(function() old:Disconnect() end)
        __ASTER_RUNTIME.connections["goldNoclip"] = nil
    end
end
function startGoldNoclip()
    if goldNoclipActive then return end
    goldNoclipActive = true
    task.spawn(function()
        local RunService = game:GetService("RunService")
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if not Settings.GoldNoclip then
                connection:Disconnect()
                return
            end
            noclip()
        end)
        trackConnection("goldNoclip", connection)
        while Settings.GoldNoclip do
            task.wait(0.5)
        end
        if connection then connection:Disconnect() end
        __ASTER_RUNTIME.connections["goldNoclip"] = nil
        goldNoclipActive = false
        restoreWorldNoclip()
        restoreCollision()
    end)
end

-- [ Shared Equip Logic ] --
function getToolSlot(toolName)
    local GameUtil = nil
    pcall(function() GameUtil = require(game:GetService("ReplicatedStorage").Modules.GameUtil) end)
    if not GameUtil then return nil end
    local toolbar = GameUtil.Data.toolbar
    if not toolbar then return nil end
    for i = 1, 6 do
        if toolbar[i] and toolbar[i].name == toolName then
            return i
        end
    end
    return nil
end

function equipItemPacket(name)
     if ByteNetReliable then
         local slot = getToolSlot(name)
         if slot then
             local equipPacketId = getPacketId("EquipTool")
             if not equipPacketId then return end
             local b = buffer.create(4)
             buffer.writeu8(b, 0, 0)
             buffer.writeu8(b, 1, equipPacketId)
             buffer.writeu16(b, 2, slot)
             ByteNetReliable:FireServer(b)
         else
             if plr.Character then
                 local tool = plr.Backpack:FindFirstChild(name)
                 if tool then plr.Character.Humanoid:EquipTool(tool) end
             end
         end
     else
         if plr.Character then
             local tool = plr.Backpack:FindFirstChild(name)
             if tool then plr.Character.Humanoid:EquipTool(tool) end
         end
     end
end

function isToolEquipped(toolName)
    local playersFolder = workspace:FindFirstChild("Players")
    if playersFolder then
        local plrFolder = playersFolder:FindFirstChild(plr.Name)
        if plrFolder then
            local toolsFolder = plrFolder:FindFirstChild("Tools")
            if toolsFolder and toolsFolder:FindFirstChild(toolName) then
                return true
            end
        end
    end
    if plr.Character and plr.Character:FindFirstChild(toolName) then
        return true
    end
    return false
end

function isAnyToolEquipped()
    local playersFolder = workspace:FindFirstChild("Players")
    if playersFolder then
        local plrFolder = playersFolder:FindFirstChild(plr.Name)
        if plrFolder then
            local toolsFolder = plrFolder:FindFirstChild("Tools")
            if toolsFolder and #toolsFolder:GetChildren() > 0 then
                return true
            end
        end
    end
    if plr.Character and plr.Character:FindFirstChildOfClass("Tool") then
        return true
    end
    return false
end

local goldActive = false
function stopGoldCircuit()
    Settings.GoldCircuitEnabled = false
    if movementConnection then
        movementConnection:Disconnect()
        movementConnection = nil
    end
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        removeBodyVelocity(hrp)
        removeAlignPosition()
    end
    if restoreCollision then restoreCollision() end
    local hum0 = plr.Character and plr.Character:FindFirstChild("Humanoid")
    if hum0 then hum0.WalkSpeed = Settings.WalkSpeed or 16 end
    isTweening = false
    walkingToWaypoint = false
    goldActive = false
    walkAttemptTimer = 0
    stuckCheckWaypoint = nil
    stuckCheckStartDistance = nil
    stuckCheckTimer = 0
    isWaitingForWaypoint = false
    isWaitingForDelay = false
    delayStartTime = 0
    lastFramePos = nil
end

function startGoldCircuit()
    if goldActive then return end
    goldActive = true
    Settings.GoldSpeed = math.clamp(tonumber(Settings.GoldSpeed) or 16, 1, GOLD_SPEED_MAX)
    Settings.GoldDelay = math.max(tonumber(Settings.GoldDelay) or 0, 0)
    WALK_SPEED = Settings.GoldSpeed
    
    -- Cleanup Old Boards
    local res = getWorkspaceResources()
    if res then
        for _, v in ipairs(res:GetChildren()) do
            if v.Name == "Old Boards" then
                v:Destroy()
            end
        end
    end

    updateRayParams()
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if hrp and Settings.recordedPositions and #Settings.recordedPositions > 0 then
        local closestIndex = 1
        local closestDist = math.huge
        for idx, pos in ipairs(Settings.recordedPositions) do
            local waypoint = Vector3.new(pos.X, pos.Y, pos.Z)
            local dist = (waypoint - hrp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestIndex = idx
            end
        end
        currentWaypoint = closestIndex
    end
    startMovementEngine()
    
    -- Start Auto Equip Manager separately to keep main loop pure
    if Settings.GoldAutoEquip then
        startGoldEquipManager()
    end
    
    task.spawn(function()
        while Settings.GoldCircuitEnabled do task.wait(0.5) end
        goldActive = false
    end)
end


do
    WaypointUI:AddLabel("Gold Farm")
    WaypointUI:AddToggle("Start Tween", false, function(v)
            Settings.GoldCircuitEnabled = v
            if v then
                startGoldCircuit()
            else
                stopGoldCircuit()
            end
        end)
    WaypointUI:AddSlider("Tween Speed", 1, GOLD_SPEED_MAX, math.clamp(tonumber(Settings.GoldSpeed) or 16, 1, GOLD_SPEED_MAX), 1, function(v)
        Settings.GoldSpeed = math.clamp(tonumber(v) or 16, 1, GOLD_SPEED_MAX)
        WALK_SPEED = Settings.GoldSpeed
    end)
    WaypointUI:AddSlider("Gold Delay", 0, 2, math.max(tonumber(Settings.GoldDelay) or 0, 0), 0.01, function(v) 
        Settings.GoldDelay = math.max(tonumber(v) or 0, 0)
    end)
    WaypointUI:AddToggle("Gold Wait Until Mined", Settings.GoldWaitUntilMined, function(v)
        Settings.GoldWaitUntilMined = v == true
    end)
    WaypointUI:AddSlider("Gold Max Wait", 3, 60, Settings.GoldMaxWait, 1, function(v)
        Settings.GoldMaxWait = v
    end)
    WaypointUI:AddSlider("Gold Detect Range", 5, 80, Settings.GoldDetectRange, 1, function(v)
        Settings.GoldDetectRange = v
    end)
    WaypointUI:AddToggle("Visual Waypoints", false, function(v)
        Settings.GoldVisual = v
        updateVisualNodes()
    end)
    WaypointUI:AddToggle("Tween Only (Recommended)", false, function(v)
        Settings.TweenOnly = v
    end)
end


do
    WaypointUI:AddLabel("Path Management")
    WaypointUI.Options.GlobalPathDropdown = WaypointUI:AddDropdown("Select Path", getGoldPathList(), "None", function(v)
        if v == "None" then
            Settings.recordedPositions = {}
            updateVisualNodes()
            if WaypointUI.Options.WaypointDropdown then 
                WaypointUI.Options.WaypointDropdown:SetValues(WaypointUI.getWaypointList())
                WaypointUI.Options.WaypointDropdown:SetValue("None")
            end
        else
            if loadPath(v) then 
                updateVisualNodes() 
                if WaypointUI.Options.WaypointDropdown then 
                    WaypointUI.Options.WaypointDropdown:SetValues(WaypointUI.getWaypointList())
                    WaypointUI.Options.WaypointDropdown:SetValue("None")
                end
            end
        end
    end)

    -- Paste waypoints directly instead of selecting a saved file. Accepts the full
    -- saved-path JSON ({"positions":[...]}), a bare array of points, or plain
    -- coordinate triples like "x,y,z x,y,z" / "Vector3.new(x,y,z), ...".
    WaypointUI:AddInput("InputPath", "", function(v)
        if not v or v == "" then return end
        local positions

        local ok, decoded = pcall(function() return httpservice:JSONDecode(v) end)
        if ok and type(decoded) == "table" then
            if type(decoded.positions) == "table" then
                positions = decoded.positions
            elseif decoded[1] ~= nil then
                positions = decoded
            end
        end

        if not positions then
            local nums = {}
            for n in tostring(v):gmatch("[-%d%.]+") do
                local num = tonumber(n)
                if num then nums[#nums + 1] = num end
            end
            if #nums >= 3 then
                positions = {}
                for i = 1, #nums - 2, 3 do
                    positions[#positions + 1] = { X = nums[i], Y = nums[i + 1], Z = nums[i + 2] }
                end
            end
        end

        local clean = {}
        if positions then
            for _, p in ipairs(positions) do
                if type(p) == "table" then
                    local x = tonumber(p.X or p.x)
                    local y = tonumber(p.Y or p.y)
                    local z = tonumber(p.Z or p.z)
                    if x and y and z then
                        local entry = { X = x, Y = y, Z = z }
                        local wt = tonumber(p.waitTime)
                        if wt then entry.waitTime = wt end
                        clean[#clean + 1] = entry
                    end
                end
            end
        end

        if #clean > 0 then
            Settings.recordedPositions = clean
            updateVisualNodes()
            -- NOTE: don't call GlobalPathDropdown:SetValue("None") here - SetValue fires
            -- its callback, whose "None" branch would wipe the positions we just loaded.
            if WaypointUI.Options.WaypointDropdown then
                WaypointUI.Options.WaypointDropdown:SetValues(WaypointUI.getWaypointList())
                WaypointUI.Options.WaypointDropdown:SetValue("None")
            end
        end
    end)



    WaypointUI:AddInput("New Path Name", "", function(v)
        Settings.CustomPathName = v
    end)

    WaypointUI:AddButton("Save/Create Path", function()
        local name = Settings.CustomPathName
        if not name or name == "" then
            name = "GoldCircuit_"..os.date("%H%M%S")
        end
        saveCurrentPath(name)
        if WaypointUI.Options.GlobalPathDropdown then WaypointUI.Options.GlobalPathDropdown:SetValues(getGoldPathList()) end
    end)

    WaypointUI:AddButton("Delete Selected Path", function()
        local pathName = WaypointUI.Options.GlobalPathDropdown:GetValue()
        if pathName and pathName ~= "None" then
            local pathFolder = "ASTERTween"
            local filePath = pathFolder .. "/" .. pathName .. ".json"
            if isfile(filePath) then
                if delfile then delfile(filePath) elseif deletefile then deletefile(filePath) end
                Settings.recordedPositions = {}
                updateVisualNodes()
                if WaypointUI.Options.GlobalPathDropdown then 
                   WaypointUI.Options.GlobalPathDropdown:SetValues(getGoldPathList()) 
                   WaypointUI.Options.GlobalPathDropdown:SetValue("None")
                end
            end
        end
    end)

    WaypointUI:AddButton("Refresh Path List", function()
        if WaypointUI.Options.GlobalPathDropdown then WaypointUI.Options.GlobalPathDropdown:SetValues(getGoldPathList()) end
    end)
end

do
    WaypointUI:AddLabel("Waypoint Editor")
    function WaypointUI.getWaypointList()
        local t = {}
        if Settings.recordedPositions then
            for i=1, #Settings.recordedPositions do table.insert(t, tostring(i)) end
        end
        if #t == 0 then t = {"None"} end
        return t
    end

    WaypointUI.Options.WaypointDropdown = WaypointUI:AddDropdown("Select Waypoint", WaypointUI.getWaypointList(), "None", function(v)
        Settings.SelectedWaypointIndex = tonumber(v)
    end)

    -- Buscar un waypoint por su numero: lo selecciona en el dropdown y muestra su posicion
    local searchInfo
    WaypointUI:AddInput("Buscar waypoint #", "", function(text)
        local list = Settings.recordedPositions
        local total = list and #list or 0
        local n = math.floor(tonumber(text) or 0)
        if n >= 1 and n <= total then
            if WaypointUI.Options.WaypointDropdown then
                WaypointUI.Options.WaypointDropdown:SetValues(WaypointUI.getWaypointList())
                WaypointUI.Options.WaypointDropdown:SetValue(tostring(n))
            end
            local pos = list[n]
            searchInfo.Text = string.format("#%d de %d  (%.0f, %.0f, %.0f)", n, total, pos.X, pos.Y, pos.Z)
        else
            searchInfo.Text = "No existe (hay " .. total .. ")"
        end
    end)
    searchInfo = WaypointUI:AddLabel("Resultado: -")
    
    WaypointUI:AddButton("Refresh Waypoint List", function()
        if WaypointUI.Options.WaypointDropdown then 
            WaypointUI.Options.WaypointDropdown:SetValues(WaypointUI.getWaypointList())
            WaypointUI.Options.WaypointDropdown:SetValue("None")
        end
    end)

    WaypointUI:AddButton("Move Selected Waypoint Here", function()
        local idx = Settings.SelectedWaypointIndex
        if idx and Settings.recordedPositions and Settings.recordedPositions[idx] then
             local character = game:GetService("Players").LocalPlayer.Character
             local hrp = character and character:FindFirstChild("HumanoidRootPart")
             if hrp then
                 Settings.recordedPositions[idx] = {X = hrp.Position.X, Y = hrp.Position.Y, Z = hrp.Position.Z}
                 updateVisualNodes()
             end
        end
    end)

    WaypointUI:AddButton("Delete Selected Waypoint", function()
        local idx = Settings.SelectedWaypointIndex
        if idx and Settings.recordedPositions and Settings.recordedPositions[idx] then
             table.remove(Settings.recordedPositions, idx)
             updateVisualNodes()
             if WaypointUI.Options.WaypointDropdown then 
                WaypointUI.Options.WaypointDropdown:SetValues(WaypointUI.getWaypointList())
                WaypointUI.Options.WaypointDropdown:SetValue("None")
             end
        end
    end)
    
    WaypointUI:AddSlider("Waypoint Wait Time", 0, 10, 0, 0.01, function(v)
        Settings.WaypointWaitTime = v
    end)

    WaypointUI:AddButton("Set Wait to Selected Waypoint", function()
        local idx = Settings.SelectedWaypointIndex
        if idx and Settings.recordedPositions and Settings.recordedPositions[idx] then
             Settings.recordedPositions[idx].waitTime = Settings.WaypointWaitTime or 0
        end
    end)
end

do
    WaypointUI:AddLabel("Path Recorder")
    if not __ASTER_RUNTIME.waypointDropdownLoopStarted then
        __ASTER_RUNTIME.waypointDropdownLoopStarted = true
        local session = CURRENT_SESSION
        task.spawn(function()
            while isRuntimeSessionActive(session) do
                if Settings.needsDropdownUpdate then
                    Settings.needsDropdownUpdate = false
                    if WaypointUI.Options.WaypointDropdown then 
                        WaypointUI.Options.WaypointDropdown:SetValues(WaypointUI.getWaypointList())
                    end
                end
                task.wait(2)
            end
        end)
    end

    WaypointUI:AddToggle("Auto Record Path", false, function(v)
        Settings.recordingPath = v
        if v then
            task.spawn(function()
                local player = game:GetService("Players").LocalPlayer
                while Settings.recordingPath do
                    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        if not Settings.recordedPositions then Settings.recordedPositions = {} end
                        local lastPos = Settings.recordedPositions[#Settings.recordedPositions]
                        local shouldAdd = true
                        if lastPos then
                            local dist = (Vector3.new(lastPos.X, lastPos.Y, lastPos.Z) - hrp.Position).Magnitude
                            if dist < 2 then shouldAdd = false end
                        end
                        if shouldAdd then
                            table.insert(Settings.recordedPositions, {X = hrp.Position.X, Y = hrp.Position.Y, Z = hrp.Position.Z})
                            if updateVisualNodes then updateVisualNodes() end
                            Settings.needsDropdownUpdate = true
                        end
                    end
                    task.wait(Settings.recordInterval or 1)
                end
            end)
        end
    end)

    WaypointUI:AddSlider("Recording Interval", 0.1, 5, 1, 0.1, function(v)
        Settings.recordInterval = v
    end)

    WaypointUI:AddButton("Add Manual Waypoint", function()
         local player = game:GetService("Players").LocalPlayer
         local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
         if hrp then
             if not Settings.recordedPositions then Settings.recordedPositions = {} end
             table.insert(Settings.recordedPositions, {X = hrp.Position.X, Y = hrp.Position.Y, Z = hrp.Position.Z})
             if updateVisualNodes then updateVisualNodes() end
             Settings.needsDropdownUpdate = true
         end
    end)

    WaypointUI:AddButton("Clear Path", function()
        Settings.recordedPositions = {}
        updateVisualNodes()
    end)



end

do
    WaypointUI:AddButton("5NodeTween", function()
        Settings.recordedPositions = {
            { Y = -3.000000476837158, X = 950.5995483398438, waitTime = 1.04, Z = -1387.773681640625 },
            { Y = -2.826885938644409, X = 969.7044067382813, waitTime = 1.04, Z = -1409.90087890625 },
            { Y = -2.7845659255981447, X = 948.4840698242188, waitTime = 1.04, Z = -1432.767578125 },
            { Y = -1.1912038326263428, X = 912.9176635742188, waitTime = 1.04, Z = -1426.2274169921876 },
            { Y = -3.000000238418579, X = 918.389892578125, waitTime = 1.04, Z = -1396.9947509765626 },
        }

        if updateVisualNodes then updateVisualNodes() end
        if WaypointUI.Options.WaypointDropdown and WaypointUI.getWaypointList then
            WaypointUI.Options.WaypointDropdown:SetValues(WaypointUI.getWaypointList())
            WaypointUI.Options.WaypointDropdown:SetValue("None")
        end
    end)

    WaypointUI:AddToggle("Start5NodeFarm", false, function(v)
        Settings.GoldCircuitEnabled = v
        if WaypointUI.Registry["Start Tween"] and WaypointUI.Registry["Start Tween"].SetValue then
            WaypointUI.Registry["Start Tween"].SetValue(v)
        end
        if v then startGoldCircuit() else stopGoldCircuit() end
    end)
end

-- ===== Ruta cargada automaticamente (657 waypoints) =====
do
    local EMBEDDED_ROUTE = [==[
{"positions":[
  {"Y":-36.097564697265625,"X":-17.87895965576172,"Z":-69.6917495727539},
  {"Y":-35.0615119934082,"X":-28.11099624633789,"Z":-79.33507537841797},
  {"Y":-35.717041015625,"X":-62.5265998840332,"Z":-111.12274932861328},
  {"Y":-35.180057525634766,"X":-78.44056701660156,"Z":-126.59168243408203},
  {"Y":-35.00108337402344,"X":-109.9499282836914,"Z":-151.14999389648438},
  {"Y":-34.513004302978516,"X":-140.97605895996094,"Z":-172.3174591064453},
  {"Y":-33.513004302978516,"X":-143.94281005859375,"Z":-179.9051055908203},
  {"Y":-26.047304153442383,"X":-146.2490234375,"Z":-185.53282165527344},
  {"Y":-17.297964096069336,"X":-145.8536376953125,"Z":-191.34654235839844},
  {"Y":-23.848613739013672,"X":-140.6541748046875,"Z":-190.62557983398438},
  {"Y":-32.70119857788086,"X":-135.28668212890625,"Z":-189.61473083496094},
  {"Y":-35.000003814697266,"X":-123.0405044555664,"Z":-184.02685546875},
  {"Y":-28.590084075927734,"X":-115.40453338623047,"Z":-181.65164184570312},
  {"Y":-34.08949279785156,"X":-112.33467864990234,"Z":-173.7101287841797},
  {"Y":-35.000003814697266,"X":-102.24323272705078,"Z":-155.57656860351562},
  {"Y":-35.718753814697266,"X":-58.51434326171875,"Z":-114.05269622802734},
  {"Y":-35.000003814697266,"X":-36.701656341552734,"Z":-93.55331420898438},
  {"Y":-34.922935485839844,"X":-25.06293487548828,"Z":-88.25690460205078},
  {"Y":-36.59028625488281,"X":-15.55826187133789,"Z":-84.41770935058594},
  {"Y":-35.23943328857422,"X":0.980724573135376,"Z":-77.46920776367188},
  {"Y":-35.545108795166016,"X":42.662105560302734,"Z":-61.125877380371094},
  {"Y":-36.4157829284668,"X":49.337745666503906,"Z":-59.37546920776367},
  {"Y":-39.165740966796875,"X":52.52009201049805,"Z":-58.21722412109375},
  {"Y":-40.74739074707031,"X":55.606178283691406,"Z":-57.11269760131836},
  {"Y":-44.67189025878906,"X":61.3894157409668,"Z":-56.68795394897461},
  {"Y":-48.53031539916992,"X":67.19034576416016,"Z":-63.01583480834961},
  {"Y":-52.8969612121582,"X":71.72045135498047,"Z":-70.34941864013672},
  {"Y":-56.65664291381836,"X":74.4097900390625,"Z":-78.0643310546875},
  {"Y":-59.7680778503418,"X":75.59027099609375,"Z":-87.4146499633789},
  {"Y":-63.792667388916016,"X":76.4576644897461,"Z":-95.5585708618164},
  {"Y":-68.42304229736328,"X":75.75611114501953,"Z":-104.64850616455078},
  {"Y":-72.80892181396484,"X":71.53912353515625,"Z":-121.32211303710938},
  {"Y":-73.77214813232422,"X":68.39056396484375,"Z":-126.51982116699219},
  {"Y":-75.22158813476562,"X":63.914005279541016,"Z":-129.9936065673828},
  {"Y":-75.02980041503906,"X":45.852882385253906,"Z":-132.12472534179688},
  {"Y":-74.53466033935547,"X":29.20977783203125,"Z":-115.6243667602539},
  {"Y":-71.06640625,"X":21.02118492126465,"Z":-108.1218490600586},
  {"Y":-74.80616760253906,"X":16.37548065185547,"Z":-104.5297622680664},
  {"Y":-76.826416015625,"X":11.101197242736816,"Z":-98.31232452392578},
  {"Y":-79.39002227783203,"X":8.299113273620605,"Z":-93.80474853515625},
  {"Y":-82.99874114990234,"X":1.7012484073638916,"Z":-84.38813018798828},
  {"Y":-79.98306274414062,"X":3.867070198059082,"Z":-69.81044006347656},
  {"Y":-76.74279022216797,"X":5.722278118133545,"Z":-62.838497161865234},
  {"Y":-75.76138305664062,"X":7.920065402984619,"Z":-56.74689483642578},
  {"Y":-75.03189086914062,"X":9.579243659973145,"Z":-42.71484375},
  {"Y":-75.00352478027344,"X":3.101607322692871,"Z":-36.630069732666016},
  {"Y":-75.31417846679688,"X":-15.877350807189941,"Z":-39.81624984741211},
  {"Y":-75.67532348632812,"X":-25.384572982788086,"Z":-43.171077728271484},
  {"Y":-75.009033203125,"X":-30.527376174926758,"Z":-52.40476608276367},
  {"Y":-75.00000762939453,"X":-37.75537872314453,"Z":-64.80815887451172},
  {"Y":-75.00035858154297,"X":-48.780609130859375,"Z":-70.68029022216797},
  {"Y":-75.79022216796875,"X":-56.188961029052734,"Z":-72.59537506103516},
  {"Y":-76.98753356933594,"X":-60.13935470581055,"Z":-71.52422332763672},
  {"Y":-83.00994110107422,"X":-63.805328369140625,"Z":-68.23323059082031},
  {"Y":-87.46012115478516,"X":-66.26478576660156,"Z":-62.35783386230469},
  {"Y":-91.19818115234375,"X":-60.143253326416016,"Z":-51.68317413330078},
  {"Y":-90.09002685546875,"X":-57.51213455200195,"Z":-46.46467971801758},
  {"Y":-90.40168762207031,"X":-54.99028015136719,"Z":-42.85733413696289},
  {"Y":-92.56724548339844,"X":-54.17765808105469,"Z":-40.33122634887695},
  {"Y":-95.67813873291016,"X":-47.8344612121582,"Z":-29.187332153320312},
  {"Y":-94.4976806640625,"X":-44.50448226928711,"Z":-23.03543472290039},
  {"Y":-95.11611938476562,"X":-39.32149887084961,"Z":-15.710384368896484},
  {"Y":-95.31110382080078,"X":-33.139915466308594,"Z":-9.770121574401855},
  {"Y":-93.09143829345703,"X":-27.177698135375977,"Z":-6.587636947631836},
  {"Y":-94.79756164550781,"X":-32.01369094848633,"Z":-9.01773738861084},
  {"Y":-95.26167297363281,"X":-38.61734390258789,"Z":-12.727347373962402},
  {"Y":-93.84127807617188,"X":-45.15901565551758,"Z":-18.667314529418945},
  {"Y":-94.40286254882812,"X":-49.78437805175781,"Z":-20.518037796020508},
  {"Y":-95.2190933227539,"X":-72.30226135253906,"Z":-28.39202308654785},
  {"Y":-95.14521789550781,"X":-107.11556243896484,"Z":-42.61137390136719},
  {"Y":-95.78980255126953,"X":-133.89031982421875,"Z":-54.370338439941406},
  {"Y":-95.38990020751953,"X":-186.22848510742188,"Z":-91.07901763916016},
  {"Y":-95.04875946044922,"X":-206.8849639892578,"Z":-100.27751159667969},
  {"Y":-95.01969909667969,"X":-213.45046997070312,"Z":-102.27188110351562},
  {"Y":-92.1510238647461,"X":-217.74807739257812,"Z":-103.16495513916016},
  {"Y":-89.34034729003906,"X":-219.48094177246094,"Z":-100.45182037353516},
  {"Y":-87.65755462646484,"X":-222.96820068359375,"Z":-97.5285415649414},
  {"Y":-86.400146484375,"X":-230.32107543945312,"Z":-94.32537841796875},
  {"Y":-85.56954193115234,"X":-234.49598693847656,"Z":-95.0248031616211},
  {"Y":-86.20861053466797,"X":-234.91062927246094,"Z":-96.36410522460938},
  {"Y":-87.54962158203125,"X":-236.72337341308594,"Z":-95.72245788574219},
  {"Y":-90.58854675292969,"X":-240.0164031982422,"Z":-95.6749267578125},
  {"Y":-92.67257690429688,"X":-243.13568115234375,"Z":-94.9742202758789},
  {"Y":-95.43948364257812,"X":-246.58038330078125,"Z":-93.223876953125},
  {"Y":-95.85417938232422,"X":-260.7976379394531,"Z":-87.19376373291016},
  {"Y":-99.03336334228516,"X":-275.30450439453125,"Z":-78.13667297363281},
  {"Y":-98.1904525756836,"X":-284.6153869628906,"Z":-76.1724853515625},
  {"Y":-96.21283721923828,"X":-287.86138916015625,"Z":-75.07992553710938},
  {"Y":-95.06410217285156,"X":-296.6695251464844,"Z":-72.2030258178711},
  {"Y":-95.13319396972656,"X":-308.9407958984375,"Z":-68.03433990478516},
  {"Y":-93.74494171142578,"X":-319.5994873046875,"Z":-62.044288635253906},
  {"Y":-91.98959350585938,"X":-325.0479431152344,"Z":-57.93803787231445},
  {"Y":-91.05609893798828,"X":-332.0805358886719,"Z":-51.68510055541992},
  {"Y":-91.8002700805664,"X":-326.35516357421875,"Z":-58.25112533569336},
  {"Y":-92.62725067138672,"X":-320.62811279296875,"Z":-63.44654083251953},
  {"Y":-94.87786865234375,"X":-316.7603454589844,"Z":-66.3921127319336},
  {"Y":-95.86964416503906,"X":-310.5828552246094,"Z":-71.18344116210938},
  {"Y":-95.15017700195312,"X":-300.8476867675781,"Z":-79.7458267211914},
  {"Y":-95.09049224853516,"X":-290.0814208984375,"Z":-93.76136016845703},
  {"Y":-94.68161010742188,"X":-282.2164306640625,"Z":-105.37223052978516},
  {"Y":-93.67344665527344,"X":-278.5527038574219,"Z":-109.21057891845703},
  {"Y":-94.9756088256836,"X":-275.8273010253906,"Z":-112.89608764648438},
  {"Y":-95.22782897949219,"X":-270.97662353515625,"Z":-118.80455017089844},
  {"Y":-95.2102279663086,"X":-235.69314575195312,"Z":-159.1427764892578},
  {"Y":-95.29962158203125,"X":-226.5478973388672,"Z":-166.99398803710938},
  {"Y":-94.96026611328125,"X":-223.95382690429688,"Z":-169.75721740722656},
  {"Y":-95.49082946777344,"X":-221.4545135498047,"Z":-174.29251098632812},
  {"Y":-95.51611328125,"X":-220.53163146972656,"Z":-178.19520568847656},
  {"Y":-95.64567565917969,"X":-223.80142211914062,"Z":-184.4515838623047},
  {"Y":-95.64767456054688,"X":-230.7017059326172,"Z":-194.28846740722656},
  {"Y":-95.6803207397461,"X":-237.29061889648438,"Z":-207.34483337402344},
  {"Y":-95.11738586425781,"X":-242.1846160888672,"Z":-218.36024475097656},
  {"Y":-95.8185806274414,"X":-241.7867889404297,"Z":-225.20693969726562},
  {"Y":-87.84711456298828,"X":-244.77288818359375,"Z":-229.85302734375},
  {"Y":-84.41264343261719,"X":-246.5354766845703,"Z":-235.0667724609375},
  {"Y":-83.07404327392578,"X":-242.14894104003906,"Z":-244.6227264404297},
  {"Y":-83.00675201416016,"X":-232.12010192871094,"Z":-255.237060546875},
  {"Y":-83.01465606689453,"X":-229.69158935546875,"Z":-260.97845458984375},
  {"Y":-82.55633544921875,"X":-229.381103515625,"Z":-265.1445007324219},
  {"Y":-80.41253662109375,"X":-230.74317932128906,"Z":-270.6502990722656},
  {"Y":-79.11243438720703,"X":-234.92308044433594,"Z":-295.65863037109375},
  {"Y":-78.79810333251953,"X":-236.6993408203125,"Z":-299.2177734375},
  {"Y":-78.9940414428711,"X":-237.94131469726562,"Z":-302.6437072753906},
  {"Y":-79.08631896972656,"X":-241.61131286621094,"Z":-319.5328674316406},
  {"Y":-77.45620727539062,"X":-241.92491149902344,"Z":-325.4241943359375},
  {"Y":-76.43376159667969,"X":-241.6328582763672,"Z":-329.8904724121094},
  {"Y":-76.98069763183594,"X":-240.27154541015625,"Z":-333.3515625},
  {"Y":-79.00000762939453,"X":-237.294921875,"Z":-338.5400085449219},
  {"Y":-78.17758178710938,"X":-232.32461547851562,"Z":-345.2692565917969},
  {"Y":-76.10971069335938,"X":-228.5795135498047,"Z":-349.49139404296875},
  {"Y":-75.36909484863281,"X":-223.65281677246094,"Z":-354.87237548828125},
  {"Y":-75.04910278320312,"X":-219.1317596435547,"Z":-360.1755065917969},
  {"Y":-74.00711059570312,"X":-213.7140350341797,"Z":-366.33935546875},
  {"Y":-72.24459075927734,"X":-210.28904724121094,"Z":-370.82293701171875},
  {"Y":-71.48782348632812,"X":-206.9502716064453,"Z":-377.5299072265625},
  {"Y":-71.27015686035156,"X":-203.58535766601562,"Z":-385.4100646972656},
  {"Y":-70.5815658569336,"X":-201.47410583496094,"Z":-391.9834899902344},
  {"Y":-69.34226989746094,"X":-199.81532287597656,"Z":-396.2769470214844},
  {"Y":-68.30485534667969,"X":-198.341552734375,"Z":-399.189453125},
  {"Y":-67.1475601196289,"X":-196.20648193359375,"Z":-405.96014404296875},
  {"Y":-67.27498626708984,"X":-193.59925842285156,"Z":-413.32391357421875},
  {"Y":-66.67404174804688,"X":-192.5446319580078,"Z":-417.9113464355469},
  {"Y":-66.74925231933594,"X":-191.64205932617188,"Z":-427.5824279785156},
  {"Y":-67.2940673828125,"X":-189.95240783691406,"Z":-437.8460998535156},
  {"Y":-67.02113342285156,"X":-189.29241943359375,"Z":-464.7947082519531},
  {"Y":-64.72180938720703,"X":-190.5485382080078,"Z":-471.30584716796875},
  {"Y":-63.72323226928711,"X":-193.30474853515625,"Z":-478.32415771484375},
  {"Y":-63.05461502075195,"X":-195.34823608398438,"Z":-484.8435974121094},
  {"Y":-62.89060592651367,"X":-197.6260986328125,"Z":-492.9736022949219},
  {"Y":-60.925601959228516,"X":-200.11380004882812,"Z":-501.9820861816406},
  {"Y":-59.842506408691406,"X":-201.3069305419922,"Z":-506.677734375},
  {"Y":-59.1169319152832,"X":-204.20997619628906,"Z":-511.79901123046875},
  {"Y":-59.000003814697266,"X":-206.43276977539062,"Z":-517.2422485351562},
  {"Y":-59.00811767578125,"X":-207.37051391601562,"Z":-530.5380249023438},
  {"Y":-59.436492919921875,"X":-206.40786743164062,"Z":-533.510009765625},
  {"Y":-60.48143005371094,"X":-203.9061737060547,"Z":-537.22314453125},
  {"Y":-61.2838020324707,"X":-198.30105590820312,"Z":-541.9625854492188},
  {"Y":-62.6893196105957,"X":-192.79458618164062,"Z":-546.874267578125},
  {"Y":-62.539974212646484,"X":-188.2182159423828,"Z":-551.2115478515625},
  {"Y":-63.674373626708984,"X":-183.96595764160156,"Z":-555.5897216796875},
  {"Y":-63.66203689575195,"X":-180.2412567138672,"Z":-559.8143310546875},
  {"Y":-63.51121139526367,"X":-178.34194946289062,"Z":-563.845458984375},
  {"Y":-63.217350006103516,"X":-177.01344299316406,"Z":-569.0462646484375},
  {"Y":-64.1656494140625,"X":-176.37693786621094,"Z":-574.5562744140625},
  {"Y":-63.631412506103516,"X":-176.43167114257812,"Z":-581.854736328125},
  {"Y":-63.00729751586914,"X":-176.70010375976562,"Z":-587.666748046875},
  {"Y":-62.93288803100586,"X":-177.0845184326172,"Z":-594.0775756835938},
  {"Y":-63.290523529052734,"X":-179.36814880371094,"Z":-600.0236206054688},
  {"Y":-63.781986236572266,"X":-183.57997131347656,"Z":-605.2738037109375},
  {"Y":-64.00740814208984,"X":-186.90322875976562,"Z":-608.8635864257812},
  {"Y":-63.06130599975586,"X":-191.77662658691406,"Z":-612.3721313476562},
  {"Y":-61.770748138427734,"X":-197.17019653320312,"Z":-616.0538940429688},
  {"Y":-61.75991439819336,"X":-202.64306640625,"Z":-619.3583984375},
  {"Y":-61.56159210205078,"X":-207.9905242919922,"Z":-622.8851928710938},
  {"Y":-61.64213180541992,"X":-202.5828857421875,"Z":-619.9781494140625},
  {"Y":-61.56515121459961,"X":-198.48252868652344,"Z":-617.7166748046875},
  {"Y":-63.20347213745117,"X":-193.93800354003906,"Z":-614.2801513671875},
  {"Y":-63.39158248901367,"X":-188.66493225097656,"Z":-609.9288940429688},
  {"Y":-63.56820297241211,"X":-184.14398193359375,"Z":-606.8274536132812},
  {"Y":-63.624149322509766,"X":-180.02938842773438,"Z":-602.0594482421875},
  {"Y":-63.32640075683594,"X":-177.2948455810547,"Z":-596.109130859375},
  {"Y":-62.874691009521484,"X":-176.69137573242188,"Z":-590.20068359375},
  {"Y":-63.38675308227539,"X":-175.41400146484375,"Z":-582.8316650390625},
  {"Y":-64.51220703125,"X":-175.260986328125,"Z":-576.8424072265625},
  {"Y":-63.42831802368164,"X":-175.95094299316406,"Z":-570.2713012695312},
  {"Y":-63.3984375,"X":-178.2561492919922,"Z":-565.19873046875},
  {"Y":-63.76296615600586,"X":-180.1190643310547,"Z":-559.640380859375},
  {"Y":-64.01393127441406,"X":-182.77403259277344,"Z":-555.7757568359375},
  {"Y":-63.05409622192383,"X":-186.2442169189453,"Z":-551.982421875},
  {"Y":-62.861412048339844,"X":-191.23175048828125,"Z":-547.4107055664062},
  {"Y":-62.38056182861328,"X":-195.63284301757812,"Z":-543.8690185546875},
  {"Y":-60.2612419128418,"X":-199.67115783691406,"Z":-542.5059814453125},
  {"Y":-59.831756591796875,"X":-207.3677215576172,"Z":-542.3101806640625},
  {"Y":-59.281829833984375,"X":-214.2286376953125,"Z":-542.9287719726562},
  {"Y":-59.03789520263672,"X":-221.3056640625,"Z":-543.8336791992188},
  {"Y":-59.08058166503906,"X":-226.54965209960938,"Z":-544.5911254882812},
  {"Y":-59.33436584472656,"X":-241.40237426757812,"Z":-546.768798828125},
  {"Y":-58.86677932739258,"X":-244.82855224609375,"Z":-548.1688232421875},
  {"Y":-57.11024475097656,"X":-250.6344451904297,"Z":-549.6515502929688},
  {"Y":-55.696990966796875,"X":-259.0316162109375,"Z":-552.6948852539062},
  {"Y":-56.581138610839844,"X":-264.017578125,"Z":-554.9091186523438},
  {"Y":-55.969913482666016,"X":-269.0810546875,"Z":-556.7428588867188},
  {"Y":-57.812992095947266,"X":-275.6255798339844,"Z":-558.3749389648438},
  {"Y":-56.87485122680664,"X":-280.85430908203125,"Z":-560.5892333984375},
  {"Y":-56.78207778930664,"X":-288.2280578613281,"Z":-562.4149169921875},
  {"Y":-56.15270233154297,"X":-296.9427490234375,"Z":-564.7374267578125},
  {"Y":-55.06346893310547,"X":-301.8452453613281,"Z":-566.1630859375},
  {"Y":-53.833702087402344,"X":-305.91009521484375,"Z":-566.3574829101562},
  {"Y":-49.61913299560547,"X":-312.7228088378906,"Z":-566.7962036132812},
  {"Y":-48.3958740234375,"X":-316.551025390625,"Z":-566.6005859375},
  {"Y":-47.83404541015625,"X":-326.1128234863281,"Z":-566.3486328125},
  {"Y":-47.28473663330078,"X":-336.4104919433594,"Z":-565.8798217773438},
  {"Y":-47.01621627807617,"X":-346.478759765625,"Z":-565.0870361328125},
  {"Y":-46.99626159667969,"X":-355.8282470703125,"Z":-563.5328979492188},
  {"Y":-45.375816345214844,"X":-361.52484130859375,"Z":-562.7321166992188},
  {"Y":-44.30445861816406,"X":-366.67950439453125,"Z":-561.8820190429688},
  {"Y":-44.01774597167969,"X":-369.08349609375,"Z":-561.7401733398438},
  {"Y":-44.986141204833984,"X":-363.77203369140625,"Z":-562.9739379882812},
  {"Y":-46.64341354370117,"X":-358.5207824707031,"Z":-563.5941772460938},
  {"Y":-47.000003814697266,"X":-350.8327941894531,"Z":-564.6366577148438},
  {"Y":-47.1435546875,"X":-342.3503723144531,"Z":-565.2587280273438},
  {"Y":-47.33792495727539,"X":-331.8656311035156,"Z":-566.7357177734375},
  {"Y":-48.27005386352539,"X":-322.7013854980469,"Z":-567.354736328125},
  {"Y":-48.38115692138672,"X":-316.8957824707031,"Z":-567.0587158203125},
  {"Y":-49.52067947387695,"X":-313.1713562011719,"Z":-566.9126586914062},
  {"Y":-54.88465881347656,"X":-308.2060852050781,"Z":-568.2576293945312},
  {"Y":-55.71764373779297,"X":-305.080810546875,"Z":-568.9219970703125},
  {"Y":-56.15403747558594,"X":-297.9307556152344,"Z":-567.2255249023438},
  {"Y":-57.020286560058594,"X":-284.7225341796875,"Z":-564.8006591796875},
  {"Y":-57.21599578857422,"X":-277.8568420410156,"Z":-563.0038452148438},
  {"Y":-57.80225372314453,"X":-271.36090087890625,"Z":-559.9007568359375},
  {"Y":-56.77184295654297,"X":-268.2525939941406,"Z":-558.3744506835938},
  {"Y":-56.460670471191406,"X":-263.7364196777344,"Z":-556.878662109375},
  {"Y":-55.87192153930664,"X":-260.0214538574219,"Z":-555.170654296875},
  {"Y":-56.31298065185547,"X":-256.2381286621094,"Z":-553.7573852539062},
  {"Y":-57.14905548095703,"X":-251.2534637451172,"Z":-551.7664184570312},
  {"Y":-57.801456451416016,"X":-245.72120666503906,"Z":-549.5245361328125},
  {"Y":-59.587711334228516,"X":-239.49424743652344,"Z":-546.03564453125},
  {"Y":-59.07588195800781,"X":-231.01361083984375,"Z":-540.78955078125},
  {"Y":-59.85810852050781,"X":-223.98020935058594,"Z":-536.6942138671875},
  {"Y":-59.32429122924805,"X":-218.5274200439453,"Z":-532.5496826171875},
  {"Y":-59.318973541259766,"X":-214.47142028808594,"Z":-528.6907958984375},
  {"Y":-59.000003814697266,"X":-205.77403259277344,"Z":-514.8250732421875},
  {"Y":-59.635501861572266,"X":-201.66891479492188,"Z":-507.802490234375},
  {"Y":-60.6660270690918,"X":-199.6327362060547,"Z":-503.5239562988281},
  {"Y":-63.018436431884766,"X":-195.99563598632812,"Z":-496.31402587890625},
  {"Y":-63.47124481201172,"X":-194.01144409179688,"Z":-490.2722473144531},
  {"Y":-63.150779724121094,"X":-192.33627319335938,"Z":-484.3065490722656},
  {"Y":-63.445621490478516,"X":-190.15048217773438,"Z":-480.2445373535156},
  {"Y":-64.37374114990234,"X":-187.79025268554688,"Z":-475.1167297363281},
  {"Y":-66.39417266845703,"X":-184.70257568359375,"Z":-470.7013854980469},
  {"Y":-67.04651641845703,"X":-180.10128784179688,"Z":-464.0059814453125},
  {"Y":-68.44478607177734,"X":-174.04037475585938,"Z":-459.1343688964844},
  {"Y":-69.00057220458984,"X":-170.7844696044922,"Z":-458.5052185058594},
  {"Y":-78.59272003173828,"X":-170.85076904296875,"Z":-456.0074768066406},
  {"Y":-88.7412109375,"X":-171.70973205566406,"Z":-458.27325439453125},
  {"Y":-96.18685913085938,"X":-168.58856201171875,"Z":-460.8108215332031},
  {"Y":-100.5133056640625,"X":-165.9183349609375,"Z":-466.1009826660156},
  {"Y":-99.71646118164062,"X":-167.10324096679688,"Z":-473.5707092285156},
  {"Y":-98.81915283203125,"X":-167.1954803466797,"Z":-477.0744934082031},
  {"Y":-99.6044921875,"X":-165.96986389160156,"Z":-481.63446044921875},
  {"Y":-99.95574188232422,"X":-162.99380493164062,"Z":-486.5502014160156},
  {"Y":-98.20748901367188,"X":-162.020751953125,"Z":-491.1322021484375},
  {"Y":-98.45223236083984,"X":-161.22610473632812,"Z":-494.90814208984375},
  {"Y":-100.04280853271484,"X":-162.77430725097656,"Z":-499.8187561035156},
  {"Y":-99.05226135253906,"X":-166.9684295654297,"Z":-502.5689697265625},
  {"Y":-99.72483825683594,"X":-170.27288818359375,"Z":-504.0333557128906},
  {"Y":-101.55168151855469,"X":-175.0640869140625,"Z":-504.6931457519531},
  {"Y":-102.8446044921875,"X":-181.4249267578125,"Z":-504.275146484375},
  {"Y":-103.38532257080078,"X":-186.8292999267578,"Z":-503.1620788574219},
  {"Y":-103.61190795898438,"X":-189.79571533203125,"Z":-500.06207275390625},
  {"Y":-103.22256469726562,"X":-192.6428985595703,"Z":-495.9230651855469},
  {"Y":-103.20774841308594,"X":-193.46253967285156,"Z":-491.5081787109375},
  {"Y":-103.00000762939453,"X":-192.6638946533203,"Z":-485.9336242675781},
  {"Y":-103.1484603881836,"X":-191.2968292236328,"Z":-477.20269775390625},
  {"Y":-103.46271514892578,"X":-190.2761688232422,"Z":-466.2491760253906},
  {"Y":-103.60044860839844,"X":-189.6810302734375,"Z":-462.7760314941406},
  {"Y":-103.08612823486328,"X":-190.93386840820312,"Z":-478.0238342285156},
  {"Y":-103.29718780517578,"X":-195.1613311767578,"Z":-495.3601379394531},
  {"Y":-103.84391784667969,"X":-190.9109344482422,"Z":-500.3244934082031},
  {"Y":-103.26763916015625,"X":-187.01072692871094,"Z":-504.1353454589844},
  {"Y":-103.00000762939453,"X":-182.21456909179688,"Z":-505.6050109863281},
  {"Y":-103.42952728271484,"X":-177.06646728515625,"Z":-506.1963806152344},
  {"Y":-101.2374496459961,"X":-173.15292358398438,"Z":-505.19012451171875},
  {"Y":-99.37002563476562,"X":-169.67352294921875,"Z":-503.92034912109375},
  {"Y":-99.18386840820312,"X":-166.0050811767578,"Z":-502.03753662109375},
  {"Y":-100.1380386352539,"X":-162.4307403564453,"Z":-499.90545654296875},
  {"Y":-100.0686264038086,"X":-160.14646911621094,"Z":-498.29754638671875},
  {"Y":-99.83262634277344,"X":-158.645751953125,"Z":-497.6225891113281},
  {"Y":-102.7552719116211,"X":-155.62728881835938,"Z":-495.708740234375},
  {"Y":-102.8098373413086,"X":-151.4722137451172,"Z":-492.8936462402344},
  {"Y":-102.41871643066406,"X":-146.07627868652344,"Z":-490.1046447753906},
  {"Y":-98.11237335205078,"X":-144.6497802734375,"Z":-490.2248229980469},
  {"Y":-96.05533599853516,"X":-139.55751037597656,"Z":-489.9093933105469},
  {"Y":-102.75867462158203,"X":-135.40403747558594,"Z":-490.0671081542969},
  {"Y":-103.00000762939453,"X":-128.996826171875,"Z":-486.8004150390625},
  {"Y":-103.00000762939453,"X":-86.85153198242188,"Z":-471.48431396484375},
  {"Y":-102.83710479736328,"X":-78.46856689453125,"Z":-466.96978759765625},
  {"Y":-101.96016693115234,"X":-75.67974853515625,"Z":-464.9782409667969},
  {"Y":-101.52145385742188,"X":-69.9902114868164,"Z":-461.5746765136719},
  {"Y":-100.27839660644531,"X":-67.62254333496094,"Z":-460.17779541015625},
  {"Y":-102.2340316772461,"X":-65.15495300292969,"Z":-460.4151306152344},
  {"Y":-103.00000762939453,"X":-41.906707763671875,"Z":-447.0376892089844},
  {"Y":-103.00704956054688,"X":-32.967735290527344,"Z":-441.931396484375},
  {"Y":-103.00000762939453,"X":3.7265403270721436,"Z":-414.25274658203125},
  {"Y":-100.8818359375,"X":15.071966171264648,"Z":-411.3806457519531},
  {"Y":-99.89068603515625,"X":16.625764846801758,"Z":-407.8677062988281},
  {"Y":-99.21542358398438,"X":17.921348571777344,"Z":-403.77264404296875},
  {"Y":-98.65266418457031,"X":22.046314239501953,"Z":-391.6380310058594},
  {"Y":-99.00000762939453,"X":25.051910400390625,"Z":-385.7096862792969},
  {"Y":-99.51049041748047,"X":29.444536209106445,"Z":-378.48150634765625},
  {"Y":-99.09060668945312,"X":35.02845764160156,"Z":-373.4461975097656},
  {"Y":-99.00000762939453,"X":41.340599060058594,"Z":-369.12310791015625},
  {"Y":-99.00000762939453,"X":44.15993118286133,"Z":-367.4710693359375},
  {"Y":-99.05789947509766,"X":38.43994140625,"Z":-371.1219177246094},
  {"Y":-99.01305389404297,"X":33.63816452026367,"Z":-375.5933837890625},
  {"Y":-99.69683074951172,"X":28.073333740234375,"Z":-381.40234375},
  {"Y":-98.99775695800781,"X":24.011993408203125,"Z":-386.8166198730469},
  {"Y":-98.53417205810547,"X":22.334383010864258,"Z":-391.8175964355469},
  {"Y":-99.00000762939453,"X":20.765003204345703,"Z":-397.4351806640625},
  {"Y":-99.18146514892578,"X":18.369617462158203,"Z":-403.4071044921875},
  {"Y":-100.1969223022461,"X":15.530204772949219,"Z":-408.36822509765625},
  {"Y":-102.43180847167969,"X":12.02324104309082,"Z":-412.1971435546875},
  {"Y":-103.00000762939453,"X":2.9556632041931152,"Z":-410.4751281738281},
  {"Y":-103.00000762939453,"X":-8.490689277648926,"Z":-407.6667175292969},
  {"Y":-103.00000762939453,"X":-34.45203399658203,"Z":-395.26318359375},
  {"Y":-103.252685546875,"X":-41.77769088745117,"Z":-392.8024597167969},
  {"Y":-104.76951599121094,"X":-45.72745895385742,"Z":-389.7296142578125},
  {"Y":-107.13170623779297,"X":-48.52360153198242,"Z":-385.35284423828125},
  {"Y":-107.39091491699219,"X":-49.988243103027344,"Z":-378.5714111328125},
  {"Y":-106.99885559082031,"X":-48.9948844909668,"Z":-374.84228515625},
  {"Y":-101.33196258544922,"X":-47.123111724853516,"Z":-371.840087890625},
  {"Y":-94.51768493652344,"X":-45.06036376953125,"Z":-370.23309326171875},
  {"Y":-93.10615539550781,"X":-43.68492126464844,"Z":-369.8830261230469},
  {"Y":-91.43245697021484,"X":-40.858848571777344,"Z":-367.45867919921875},
  {"Y":-91.60712432861328,"X":-33.056732177734375,"Z":-362.6321105957031},
  {"Y":-91.00153350830078,"X":12.012492179870605,"Z":-337.3138427734375},
  {"Y":-87.85481262207031,"X":20.849050521850586,"Z":-333.2263488769531},
  {"Y":-86.75531768798828,"X":24.74131202697754,"Z":-331.86138916015625},
  {"Y":-84.49986267089844,"X":29.52347755432129,"Z":-330.1281433105469},
  {"Y":-83.82085418701172,"X":35.02643585205078,"Z":-328.8303527832031},
  {"Y":-85.12468719482422,"X":44.25493240356445,"Z":-325.2322082519531},
  {"Y":-85.48255157470703,"X":52.482574462890625,"Z":-322.9123229980469},
  {"Y":-85.11820983886719,"X":60.28593063354492,"Z":-323.2423400878906},
  {"Y":-87.45380401611328,"X":74.68778228759766,"Z":-323.9905700683594},
  {"Y":-88.29585266113281,"X":88.11256408691406,"Z":-325.3638000488281},
  {"Y":-88.72117614746094,"X":101.85709381103516,"Z":-326.2945556640625},
  {"Y":-90.98450469970703,"X":116.00377655029297,"Z":-327.4949951171875},
  {"Y":-91.06583404541016,"X":128.3017578125,"Z":-328.7770690917969},
  {"Y":-91.06879425048828,"X":141.6127471923828,"Z":-335.6646423339844},
  {"Y":-91.27796173095703,"X":149.55735778808594,"Z":-338.4092102050781},
  {"Y":-91.55013275146484,"X":160.45973205566406,"Z":-341.1788330078125},
  {"Y":-91.98895263671875,"X":172.7015380859375,"Z":-346.0210266113281},
  {"Y":-91.54741668701172,"X":175.3884735107422,"Z":-347.12164306640625},
  {"Y":-91.1111831665039,"X":181.11997985839844,"Z":-349.6989440917969},
  {"Y":-87.95037078857422,"X":190.6151123046875,"Z":-355.0612487792969},
  {"Y":-87.08727264404297,"X":198.41522216796875,"Z":-359.5683288574219},
  {"Y":-86.61406707763672,"X":207.2825927734375,"Z":-363.96490478515625},
  {"Y":-83.54988098144531,"X":213.35821533203125,"Z":-367.4212341308594},
  {"Y":-82.61236572265625,"X":219.66802978515625,"Z":-370.9901123046875},
  {"Y":-80.18965911865234,"X":225.8492889404297,"Z":-374.7739562988281},
  {"Y":-77.98857879638672,"X":228.83462524414062,"Z":-376.8498840332031},
  {"Y":-76.35271453857422,"X":232.80177307128906,"Z":-379.5791015625},
  {"Y":-75.41687774658203,"X":238.99673461914062,"Z":-383.802001953125},
  {"Y":-75.36737060546875,"X":244.98672485351562,"Z":-388.02484130859375},
  {"Y":-72.5152587890625,"X":249.4670867919922,"Z":-390.2270812988281},
  {"Y":-71.29468536376953,"X":255.10031127929688,"Z":-392.75146484375},
  {"Y":-71.44283294677734,"X":267.40325927734375,"Z":-399.1216735839844},
  {"Y":-71.58580780029297,"X":274.3494567871094,"Z":-401.6815185546875},
  {"Y":-71.31790924072266,"X":283.3896179199219,"Z":-406.6034240722656},
  {"Y":-71.66345977783203,"X":293.1257019042969,"Z":-412.34912109375},
  {"Y":-71.61150360107422,"X":301.6584777832031,"Z":-416.8661193847656},
  {"Y":-73.13687896728516,"X":317.30029296875,"Z":-425.4315490722656},
  {"Y":-71.248046875,"X":323.3909606933594,"Z":-429.2738952636719},
  {"Y":-71.0307388305664,"X":328.58721923828125,"Z":-432.66766357421875},
  {"Y":-70.9549560546875,"X":332.32196044921875,"Z":-436.5557556152344},
  {"Y":-71.00000762939453,"X":338.4581604003906,"Z":-443.42138671875},
  {"Y":-71.33671569824219,"X":344.9645690917969,"Z":-453.1653137207031},
  {"Y":-71.43818664550781,"X":352.7499084472656,"Z":-464.8789978027344},
  {"Y":-70.8949203491211,"X":359.81854248046875,"Z":-476.35809326171875},
  {"Y":-68.60955810546875,"X":364.3243103027344,"Z":-484.84686279296875},
  {"Y":-67.56380462646484,"X":371.3843078613281,"Z":-493.7884826660156},
  {"Y":-66.02519226074219,"X":376.271728515625,"Z":-501.3860778808594},
  {"Y":-65.52554321289062,"X":381.2374267578125,"Z":-509.5525207519531},
  {"Y":-63.46936798095703,"X":387.53961181640625,"Z":-518.5033569335938},
  {"Y":-63.69522476196289,"X":392.78582763671875,"Z":-525.2867431640625},
  {"Y":-64.39662170410156,"X":398.08367919921875,"Z":-532.3944091796875},
  {"Y":-63.50368118286133,"X":403.20697021484375,"Z":-539.463623046875},
  {"Y":-63.14091491699219,"X":407.6586608886719,"Z":-545.7115478515625},
  {"Y":-63.140628814697266,"X":413.173828125,"Z":-553.541259765625},
  {"Y":-62.45137023925781,"X":418.0688171386719,"Z":-560.4927978515625},
  {"Y":-60.04181671142578,"X":423.03704833984375,"Z":-567.4292602539062},
  {"Y":-59.2119026184082,"X":426.392822265625,"Z":-570.9852294921875},
  {"Y":-58.391910552978516,"X":431.39501953125,"Z":-574.562255859375},
  {"Y":-58.5391960144043,"X":438.1629333496094,"Z":-579.6292724609375},
  {"Y":-55.799312591552734,"X":441.9357604980469,"Z":-583.5121459960938},
  {"Y":-54.70676040649414,"X":445.908203125,"Z":-589.20556640625},
  {"Y":-54.504154205322266,"X":449.6161193847656,"Z":-596.202392578125},
  {"Y":-53.392913818359375,"X":450.5801696777344,"Z":-601.468017578125},
  {"Y":-53.71951675415039,"X":451.4999694824219,"Z":-613.6271362304688},
  {"Y":-51.726993560791016,"X":452.08380126953125,"Z":-634.3920288085938},
  {"Y":-52.33588409423828,"X":451.81268310546875,"Z":-642.1153564453125},
  {"Y":-51.66029739379883,"X":452.8863830566406,"Z":-651.91796875},
  {"Y":-51.43056106567383,"X":454.2159729003906,"Z":-659.6134643554688},
  {"Y":-53.138755798339844,"X":465.1197814941406,"Z":-671.15234375},
  {"Y":-52.21376419067383,"X":471.9156494140625,"Z":-676.2056884765625},
  {"Y":-51.88432312011719,"X":476.91363525390625,"Z":-682.4304809570312},
  {"Y":-51.47580337524414,"X":480.2375793457031,"Z":-688.4600830078125},
  {"Y":-50.84123992919922,"X":485.443603515625,"Z":-696.1939086914062},
  {"Y":-47.667659759521484,"X":489.8533020019531,"Z":-703.0410766601562},
  {"Y":-44.84425354003906,"X":494.1472473144531,"Z":-708.5020751953125},
  {"Y":-42.40242004394531,"X":500.21405029296875,"Z":-715.4789428710938},
  {"Y":-39.907142639160156,"X":504.26312255859375,"Z":-720.9984741210938},
  {"Y":-37.426292419433594,"X":511.5397033691406,"Z":-723.7406005859375},
  {"Y":-34.88694763183594,"X":517.7926025390625,"Z":-722.4945678710938},
  {"Y":-35.786346435546875,"X":525.240478515625,"Z":-722.4901123046875},
  {"Y":-35.09760284423828,"X":533.0051879882812,"Z":-721.6177978515625},
  {"Y":-34.776100158691406,"X":539.272705078125,"Z":-719.8760375976562},
  {"Y":-35.01211929321289,"X":546.516357421875,"Z":-723.972900390625},
  {"Y":-35.24473571777344,"X":555.3798828125,"Z":-739.08642578125},
  {"Y":-35.713584899902344,"X":558.068603515625,"Z":-745.2341918945312},
  {"Y":-35.27496337890625,"X":557.7745971679688,"Z":-752.2593383789062},
  {"Y":-35.20258331298828,"X":554.815673828125,"Z":-755.6443481445312},
  {"Y":-35.203914642333984,"X":545.1451416015625,"Z":-760.0690307617188},
  {"Y":-33.5947151184082,"X":529.8575439453125,"Z":-762.5135498046875},
  {"Y":-32.19371795654297,"X":526.4688720703125,"Z":-763.1781616210938},
  {"Y":-31.417224884033203,"X":520.8681030273438,"Z":-764.229736328125},
  {"Y":-35.04903793334961,"X":515.293701171875,"Z":-766.5718383789062},
  {"Y":-34.771366119384766,"X":509.0710754394531,"Z":-767.3905029296875},
  {"Y":-34.33096694946289,"X":501.6406555175781,"Z":-767.68701171875},
  {"Y":-32.045658111572266,"X":484.2459716796875,"Z":-769.2265014648438},
  {"Y":-30.864042282104492,"X":478.3973693847656,"Z":-772.3704223632812},
  {"Y":-31.622493743896484,"X":470.46392822265625,"Z":-773.4134521484375},
  {"Y":-26.51738739013672,"X":465.7380065917969,"Z":-774.5406494140625},
  {"Y":-23.058670043945312,"X":460.8208923339844,"Z":-779.2946166992188},
  {"Y":-22.18145179748535,"X":456.3913269042969,"Z":-780.4681396484375},
  {"Y":-14.820878982543945,"X":458.2960510253906,"Z":-780.1739501953125},
  {"Y":-10.045060157775879,"X":455.3318176269531,"Z":-779.896240234375},
  {"Y":-5.0641679763793945,"X":457.1982421875,"Z":-785.5106201171875},
  {"Y":-3.17092227935791,"X":460.05169677734375,"Z":-790.1520385742188},
  {"Y":0.6992558240890503,"X":461.722412109375,"Z":-792.2465209960938},
  {"Y":-3.000000238418579,"X":470.4469909667969,"Z":-805.1152954101562},
  {"Y":-3.030179977416992,"X":480.0909729003906,"Z":-820.167724609375},
  {"Y":-5.368036270141602,"X":485.5069885253906,"Z":-827.7872314453125},
  {"Y":-10.285971641540527,"X":492.91497802734375,"Z":-839.5818481445312},
  {"Y":-11.141221046447754,"X":513.2621459960938,"Z":-864.178955078125},
  {"Y":-10.747920989990234,"X":524.4169921875,"Z":-877.8460083007812},
  {"Y":-11.404980659484863,"X":537.26123046875,"Z":-893.1806030273438},
  {"Y":-11.141646385192871,"X":552.4453735351562,"Z":-912.08837890625},
  {"Y":-12.008888244628906,"X":565.8240966796875,"Z":-928.4005126953125},
  {"Y":-11.304689407348633,"X":579.6270141601562,"Z":-944.4994506835938},
  {"Y":-11.63168716430664,"X":597.220458984375,"Z":-964.9895629882812},
  {"Y":-11.002983093261719,"X":613.4839477539062,"Z":-984.36376953125},
  {"Y":-11.692530632019043,"X":628.6997680664062,"Z":-1003.751953125},
  {"Y":-11.272380828857422,"X":657.9814453125,"Z":-1043.348876953125},
  {"Y":-11.102283477783203,"X":674.0638427734375,"Z":-1065.55126953125},
  {"Y":-10.767114639282227,"X":695.3516845703125,"Z":-1094.435302734375},
  {"Y":-11.811549186706543,"X":708.2864379882812,"Z":-1112.4573974609375},
  {"Y":-11.129387855529785,"X":723.0054931640625,"Z":-1131.6226806640625},
  {"Y":-11.931636810302734,"X":740.6757202148438,"Z":-1156.9210205078125},
  {"Y":-11.4698486328125,"X":755.2365112304688,"Z":-1176.3807373046875},
  {"Y":-11.221674919128418,"X":771.8770751953125,"Z":-1198.9136962890625},
  {"Y":-11.22555923461914,"X":787.12939453125,"Z":-1219.23876953125},
  {"Y":-11.00002670288086,"X":799.8909301757812,"Z":-1236.0626220703125},
  {"Y":-8.07883071899414,"X":811.117919921875,"Z":-1250.85107421875},
  {"Y":-7.010777950286865,"X":820.9105224609375,"Z":-1263.68017578125},
  {"Y":-7.0001325607299805,"X":834.0552978515625,"Z":-1280.9017333984375},
  {"Y":-7.001230716705322,"X":845.7407836914062,"Z":-1297.474609375},
  {"Y":-6.0939621925354,"X":863.5108642578125,"Z":-1323.879638671875},
  {"Y":-3.5840694904327393,"X":873.650390625,"Z":-1339.087158203125},
  {"Y":-3.000000238418579,"X":883.4424438476562,"Z":-1353.365478515625},
  {"Y":-3.000000238418579,"X":903.984375,"Z":-1388.2513427734375},
  {"Y":-1.805720567703247,"X":915.2468872070312,"Z":-1430.1007080078125},
  {"Y":-2.728649854660034,"X":950.0048828125,"Z":-1431.7740478515625},
  {"Y":-2.9486732482910156,"X":968.576904296875,"Z":-1407.77587890625},
  {"Y":-3.000000238418579,"X":957.7310791015625,"Z":-1378.613037109375},
  {"Y":-3.0774500370025635,"X":939.2338256835938,"Z":-1327.06884765625},
  {"Y":-4.949947834014893,"X":934.7735595703125,"Z":-1315.2174072265625},
  {"Y":-5.282273292541504,"X":931.3568725585938,"Z":-1307.1546630859375},
  {"Y":-7.695448875427246,"X":898.2717895507812,"Z":-1226.6763916015625},
  {"Y":-11.003393173217773,"X":831.3695678710938,"Z":-1011.8756713867188},
  {"Y":-11.056432723999023,"X":817.0744018554688,"Z":-965.164794921875},
  {"Y":-11.275833129882812,"X":798.0322875976562,"Z":-900.73388671875},
  {"Y":-11.161184310913086,"X":788.054931640625,"Z":-866.954833984375},
  {"Y":-11.462051391601562,"X":777.7346801757812,"Z":-829.2992553710938},
  {"Y":-11.12103271484375,"X":773.3329467773438,"Z":-812.5872802734375},
  {"Y":-10.258313179016113,"X":768.0633544921875,"Z":-791.3644409179688},
  {"Y":-6.628530025482178,"X":763.0335083007812,"Z":-773.1318969726562},
  {"Y":-3.550117015838623,"X":760.0989379882812,"Z":-761.4808349609375},
  {"Y":-3.000000238418579,"X":743.0086059570312,"Z":-724.6702270507812},
  {"Y":-3.0162200927734375,"X":694.4647827148438,"Z":-652.630126953125},
  {"Y":-3.000000238418579,"X":682.6077880859375,"Z":-636.3604125976562},
  {"Y":-3.000000238418579,"X":677.5992431640625,"Z":-629.8463745117188},
  {"Y":-3.305405855178833,"X":662.3897094726562,"Z":-603.7764282226562},
  {"Y":-6.77603006362915,"X":657.8972778320312,"Z":-595.91796875},
  {"Y":-8.475486755371094,"X":653.0084838867188,"Z":-588.3338012695312},
  {"Y":-10.240747451782227,"X":649.1417846679688,"Z":-577.76611328125},
  {"Y":-8.376097679138184,"X":642.802490234375,"Z":-565.6820068359375},
  {"Y":-6.025497913360596,"X":634.5487060546875,"Z":-548.2522583007812},
  {"Y":-1.7862539291381836,"X":629.5249633789062,"Z":-539.073486328125},
  {"Y":0.6893512010574341,"X":628.2838134765625,"Z":-533.9857177734375},
  {"Y":5.748163223266602,"X":626.4796752929688,"Z":-529.591796875},
  {"Y":8.201542854309082,"X":624.6881103515625,"Z":-524.04736328125},
  {"Y":11.110108375549316,"X":623.561279296875,"Z":-520.6100463867188},
  {"Y":14.130831718444824,"X":623.3159790039062,"Z":-513.29833984375},
  {"Y":18.671472549438477,"X":623.6087646484375,"Z":-507.65716552734375},
  {"Y":21.940242767333984,"X":623.5772705078125,"Z":-500.0639953613281},
  {"Y":24.366683959960938,"X":624.3175048828125,"Z":-495.27056884765625},
  {"Y":28.475650787353516,"X":624.5889282226562,"Z":-486.86798095703125},
  {"Y":32.14634704589844,"X":625.310791015625,"Z":-478.8609619140625},
  {"Y":34.517581939697266,"X":624.6640625,"Z":-470.4275817871094},
  {"Y":38.095458984375,"X":624.8303833007812,"Z":-460.66595458984375},
  {"Y":40.796791076660156,"X":624.9420166015625,"Z":-450.5560607910156},
  {"Y":43.939903259277344,"X":624.7047119140625,"Z":-442.2525329589844},
  {"Y":49.02988815307617,"X":627.56201171875,"Z":-437.8931579589844},
  {"Y":51.77692413330078,"X":630.420654296875,"Z":-435.1104736328125},
  {"Y":51.90930938720703,"X":634.3554077148438,"Z":-431.2475891113281},
  {"Y":52.366153717041016,"X":641.0646362304688,"Z":-424.90142822265625},
  {"Y":56.53355026245117,"X":645.445068359375,"Z":-421.09808349609375},
  {"Y":62.04644012451172,"X":649.8132934570312,"Z":-417.91766357421875},
  {"Y":68.08789825439453,"X":654.2450561523438,"Z":-414.143798828125},
  {"Y":73.24687957763672,"X":656.8256225585938,"Z":-412.3144226074219},
  {"Y":78.90837860107422,"X":662.0067138671875,"Z":-408.18597412109375},
  {"Y":82.98204803466797,"X":667.2230834960938,"Z":-402.8453369140625},
  {"Y":81.59259796142578,"X":669.4986572265625,"Z":-398.0979919433594},
  {"Y":79.89143371582031,"X":672.2779541015625,"Z":-389.16632080078125},
  {"Y":78.60698699951172,"X":668.2279052734375,"Z":-385.82470703125},
  {"Y":75.25519561767578,"X":665.3071899414062,"Z":-382.8462219238281},
  {"Y":69.9371566772461,"X":659.3328247070312,"Z":-380.6140441894531},
  {"Y":67.1477279663086,"X":658.0086669921875,"Z":-379.0574951171875},
  {"Y":61.42045974731445,"X":656.0389404296875,"Z":-376.83428955078125},
  {"Y":52.50547409057617,"X":651.2752685546875,"Z":-373.37554931640625},
  {"Y":52.408809661865234,"X":630.9236450195312,"Z":-374.9997253417969},
  {"Y":53.091304779052734,"X":614.1466064453125,"Z":-379.9891662597656},
  {"Y":51.134803771972656,"X":606.0718383789062,"Z":-382.7008056640625},
  {"Y":47.737369537353516,"X":600.2044067382812,"Z":-383.49114990234375},
  {"Y":45.21513366699219,"X":595.276123046875,"Z":-383.8108825683594},
  {"Y":40.619834899902344,"X":592.3655395507812,"Z":-382.5093688964844},
  {"Y":38.13515853881836,"X":589.0232543945312,"Z":-383.8357849121094},
  {"Y":32.977046966552734,"X":586.8980102539062,"Z":-386.8141784667969},
  {"Y":21.155057907104492,"X":588.70849609375,"Z":-390.8285827636719},
  {"Y":-2.654977321624756,"X":588.0673217773438,"Z":-381.6949157714844},
  {"Y":-7.684947967529297,"X":626.2705688476562,"Z":-379.62481689453125},
  {"Y":-7.4480977058410645,"X":626.1171875,"Z":-363.8872985839844},
  {"Y":-7.127583980560303,"X":599.4073486328125,"Z":-354.0350646972656},
  {"Y":-4.210725784301758,"X":593.4910888671875,"Z":-351.307373046875},
  {"Y":4.7147650718688965,"X":591.4130249023438,"Z":-353.0568542480469},
  {"Y":6.0018415451049805,"X":591.3334350585938,"Z":-348.1437683105469},
  {"Y":13.21908950805664,"X":589.8634033203125,"Z":-348.3128356933594},
  {"Y":14.621463775634766,"X":586.0955810546875,"Z":-344.2323303222656},
  {"Y":22.235395431518555,"X":585.5548095703125,"Z":-336.2389221191406},
  {"Y":29.133586883544922,"X":589.7534790039062,"Z":-334.7248840332031},
  {"Y":32.41560745239258,"X":594.5608520507812,"Z":-329.6348571777344},
  {"Y":36.17361068725586,"X":599.4071044921875,"Z":-323.5225830078125},
  {"Y":37.34553527832031,"X":603.885009765625,"Z":-317.0884704589844},
  {"Y":38.22057342529297,"X":609.7008666992188,"Z":-309.5472412109375},
  {"Y":39.61412048339844,"X":619.677734375,"Z":-308.6263122558594},
  {"Y":39.185874938964844,"X":627.0267333984375,"Z":-302.7242126464844},
  {"Y":37.633995056152344,"X":631.135009765625,"Z":-293.875},
  {"Y":41.56911849975586,"X":635.5157470703125,"Z":-287.10394287109375},
  {"Y":44.98186492919922,"X":637.4453125,"Z":-280.6021728515625},
  {"Y":48.226463317871094,"X":640.50830078125,"Z":-272.7751770019531},
  {"Y":49.14834213256836,"X":638.5109252929688,"Z":-264.9157409667969},
  {"Y":55.298587799072266,"X":633.8101196289062,"Z":-254.40452575683594},
  {"Y":57.48206329345703,"X":631.0281982421875,"Z":-248.45314025878906},
  {"Y":59.46984100341797,"X":629.8718872070312,"Z":-241.9771270751953},
  {"Y":59.10336685180664,"X":629.2981567382812,"Z":-236.8556365966797},
  {"Y":60.045406341552734,"X":629.8081665039062,"Z":-229.0498809814453},
  {"Y":57.956520080566406,"X":629.240966796875,"Z":-222.67181396484375},
  {"Y":55.02715301513672,"X":630.6521606445312,"Z":-216.2028045654297},
  {"Y":55.70802307128906,"X":633.6024780273438,"Z":-210.08348083496094},
  {"Y":55.84886169433594,"X":640.5601806640625,"Z":-205.1851043701172},
  {"Y":57.21739959716797,"X":645.3031616210938,"Z":-202.9598846435547},
  {"Y":57.01459503173828,"X":650.5020141601562,"Z":-201.03211975097656},
  {"Y":54.441917419433594,"X":652.9423828125,"Z":-197.86856079101562},
  {"Y":52.41732406616211,"X":655.8328247070312,"Z":-195.1513671875},
  {"Y":48.3479118347168,"X":657.3773803710938,"Z":-193.0382843017578},
  {"Y":47.34374237060547,"X":658.980712890625,"Z":-191.66871643066406},
  {"Y":41.47685623168945,"X":659.1843872070312,"Z":-190.9698944091797},
  {"Y":32.493106842041016,"X":660.2807006835938,"Z":-189.69837951660156},
  {"Y":31.84274673461914,"X":659.7451171875,"Z":-180.9114990234375},
  {"Y":31.443052291870117,"X":659.1201782226562,"Z":-172.5311737060547},
  {"Y":28.084840774536133,"X":658.114990234375,"Z":-165.79910278320312},
  {"Y":24.989084243774414,"X":658.1983642578125,"Z":-162.21621704101562},
  {"Y":19.10715103149414,"X":657.2141723632812,"Z":-160.3463592529297},
  {"Y":12.222146034240723,"X":656.5146484375,"Z":-156.4554901123047},
  {"Y":7.353592872619629,"X":655.711181640625,"Z":-151.46495056152344},
  {"Y":2.671508550643921,"X":655.4637451171875,"Z":-146.81991577148438},
  {"Y":-3.66068959236145,"X":655.377197265625,"Z":-139.4569549560547},
  {"Y":-3.001863718032837,"X":656.1939086914062,"Z":-130.7874755859375},
  {"Y":-4.399129867553711,"X":657.0941162109375,"Z":-121.9315414428711},
  {"Y":-8.273381233215332,"X":657.982666015625,"Z":-113.5490493774414},
  {"Y":-11.015195846557617,"X":627.111572265625,"Z":132.37071228027344},
  {"Y":-11.261136054992676,"X":609.791748046875,"Z":263.59271240234375},
  {"Y":-8.885579109191895,"X":609.5862426757812,"Z":267.20001220703125},
  {"Y":-7.859070777893066,"X":608.17529296875,"Z":272.2980651855469},
  {"Y":-4.2984795570373535,"X":606.0760498046875,"Z":280.3028869628906},
  {"Y":-3.569650411605835,"X":602.8991088867188,"Z":293.6758117675781},
  {"Y":4.513004302978516,"X":600.0526733398438,"Z":303.10076904296875},
  {"Y":10.150517463684082,"X":599.326416015625,"Z":305.887939453125},
  {"Y":12.984589576721191,"X":597.525390625,"Z":310.5730285644531},
  {"Y":12.223811149597168,"X":596.57958984375,"Z":320.5663757324219},
  {"Y":13.66270637512207,"X":595.28369140625,"Z":327.6494445800781},
  {"Y":15.206621170043945,"X":594.4208374023438,"Z":338.7000732421875},
  {"Y":16.844697952270508,"X":593.7723999023438,"Z":343.2518310546875},
  {"Y":16.258331298828125,"X":593.1474609375,"Z":350.281982421875},
  {"Y":16.2478084564209,"X":592.0800170898438,"Z":357.35394287109375},
  {"Y":14.113003730773926,"X":591.1690063476562,"Z":369.71044921875},
  {"Y":12.318377494812012,"X":590.0687866210938,"Z":377.34234619140625},
  {"Y":12.15611743927002,"X":589.71435546875,"Z":384.164794921875},
  {"Y":11.805913925170898,"X":588.4774169921875,"Z":393.35064697265625},
  {"Y":11.852266311645508,"X":579.8826293945312,"Z":397.20843505859375},
  {"Y":11.35152530670166,"X":572.998291015625,"Z":396.6087951660156},
  {"Y":7.906956672668457,"X":567.0726318359375,"Z":395.2830810546875},
  {"Y":5.366212368011475,"X":564.5574340820312,"Z":394.982666015625},
  {"Y":4.5040178298950195,"X":563.1307373046875,"Z":393.95660400390625},
  {"Y":0.68592369556427,"X":562.3555297851562,"Z":393.6614074707031},
  {"Y":-3.000000476837158,"X":557.0120849609375,"Z":392.62322998046875},
  {"Y":-3.3503262996673584,"X":466.2137756347656,"Z":335.6769104003906},
  {"Y":-5.709301471710205,"X":459.9606018066406,"Z":331.15557861328125},
  {"Y":-7.1692728996276855,"X":452.912353515625,"Z":325.5586242675781},
  {"Y":-11.154190063476562,"X":444.7742614746094,"Z":319.1195068359375},
  {"Y":-11.09679126739502,"X":431.4236145019531,"Z":308.0597839355469},
  {"Y":-11.850899696350098,"X":355.442138671875,"Z":242.17547607421875},
  {"Y":-11.206036567687988,"X":242.15707397460938,"Z":145.11749267578125},
  {"Y":-10.102027893066406,"X":233.57847595214844,"Z":139.0832061767578},
  {"Y":-7.379958152770996,"X":227.58407592773438,"Z":133.75682067871094},
  {"Y":-4.993008136749268,"X":221.8283233642578,"Z":129.26502990722656},
  {"Y":-3.156697988510132,"X":216.07904052734375,"Z":123.65445709228516},
  {"Y":-3.000000238418579,"X":122.92215728759766,"Z":62.1494255065918},
  {"Y":-3.000000238418579,"X":114.08106994628906,"Z":57.11045837402344},
  {"Y":-3.000000238418579,"X":102.61692810058594,"Z":52.13056564331055},
  {"Y":-3.000000238418579,"X":91.96932220458984,"Z":47.055320739746094},
  {"Y":-3.922480344772339,"X":84.23670196533203,"Z":42.97050476074219},
  {"Y":-7.297549247741699,"X":77.33952331542969,"Z":39.0709342956543},
  {"Y":-7.359339714050293,"X":70.72769165039062,"Z":35.33403778076172},
  {"Y":-7.548770904541016,"X":62.28034210205078,"Z":30.67314910888672},
  {"Y":-4.252251148223877,"X":55.44533157348633,"Z":27.477188110351562},
  {"Y":-3.000000238418579,"X":45.26575469970703,"Z":22.478870391845703},
  {"Y":-3.000000238418579,"X":35.68364334106445,"Z":18.31350326538086},
  {"Y":-3.000000238418579,"X":25.3939151763916,"Z":14.820062637329102},
  {"Y":-3.000000238418579,"X":15.17514705657959,"Z":11.12509536743164},
  {"Y":-3.000000238418579,"X":6.140575408935547,"Z":7.687087535858154},
  {"Y":-3.000000238418579,"X":-4.953854084014893,"Z":4.090693950653076},
  {"Y":-3.000000238418579,"X":-13.874646186828613,"Z":2.207000970840454},
  {"Y":-2.122081995010376,"X":-22.735958099365234,"Z":0.03000379540026188},
  {"Y":-1.7298052310943604,"X":-29.654523849487305,"Z":-2.045607089996338},
  {"Y":-4.8891191482543945,"X":-34.940025329589844,"Z":-3.7712810039520264},
  {"Y":-5.264278411865234,"X":-35.510555267333984,"Z":-3.957075595855713},
  {"Y":-8.225868225097656,"X":-40.052490234375,"Z":-7.571450710296631},
  {"Y":-12.569127082824707,"X":-37.999305725097656,"Z":-13.395605087280273},
  {"Y":-17.933578491210938,"X":-32.109413146972656,"Z":-21.22627830505371},
  {"Y":-20.773052215576172,"X":-28.30586814880371,"Z":-28.90558433532715},
  {"Y":-23.67477798461914,"X":-25.395116806030273,"Z":-37.545440673828125},
  {"Y":-27.3714599609375,"X":-22.878646850585938,"Z":-45.39448928833008},
  {"Y":-30.781057357788086,"X":-21.680158615112305,"Z":-52.233707427978516},
  {"Y":-33.658424377441406,"X":-20.34014320373535,"Z":-59.79917526245117}
]}
]==]
    local okR, dataR = pcall(function() return httpservice:JSONDecode(EMBEDDED_ROUTE) end)
    if okR and type(dataR) == "table" and type(dataR.positions) == "table" and #dataR.positions > 0 then
        Settings.recordedPositions = dataR.positions
        currentWaypoint = 1
        if updateVisualNodes then updateVisualNodes() end
        Settings.needsDropdownUpdate = true
    else
        warn("[Toby] No se pudo cargar la ruta embebida")
    end
end



end
local okW, errW = pcall(loadWaypoints)
if not okW then
    warn("[Hub] Waypoints: " .. tostring(errW))
    TabWaypoints:AddLabel("Error: " .. tostring(errW))
end


--========================================================================
-- PESTAÑA 2: BOO LITE (BooLite.lua, sin su menú)
--========================================================================
local function loadBoo()

--[[
 Versión completa (sin la UI library) de las 7 funciones:
 Pickup, Tp item chest, Mine aura, Auto eat, Auto plant/harvest, Auto craft, Auto campfire, Item deletion.

 - Todas las variables están definidas acá (servicios, módulos del juego, tablas de estado).
 - Los "library.flags.X" pasaron a una tabla simple: Boo.flags.X
 - Se controla con:   Boo.set("autopickup", true)    Boo.set("autopickup", false)
 - Selección de cofre: Boo.set("choosechest", true) y después click en un Chest / Reinforced Chest.
 - Auto craft:         Boo.flags.autocraftobject = "Steel"; Boo.set("autocraft", true)
 - Apagar todo:        Boo.unload()
]]

if getgenv().BooLite then getgenv().BooLite.unload() end
if not game:IsLoaded() then game.Loaded:Wait() end

------------------------------------------------------------
-- SERVICIOS
------------------------------------------------------------
local ReplicatedStorage   = cloneref(game:GetService("ReplicatedStorage"))
local Players             = cloneref(game:GetService("Players"))
local Workspace           = cloneref(game:GetService("Workspace"))
local CollectionService   = cloneref(game:GetService("CollectionService"))
local UserInputService    = cloneref(game:GetService("UserInputService"))
local RunService          = cloneref(game:GetService("RunService"))
local Stats               = cloneref(game:GetService("Stats"))
local StarterGui          = cloneref(game:GetService("StarterGui"))

repeat task.wait() until ReplicatedStorage:FindFirstChild("GameLoaded")

------------------------------------------------------------
-- JUGADOR / PERSONAJE
------------------------------------------------------------
local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

------------------------------------------------------------
-- MÓDULOS DEL JUEGO
------------------------------------------------------------
local game_ = ReplicatedStorage:FindFirstChild("Game")
local Packets      = require(ReplicatedStorage.Modules.Packets)
local GameUtil     = require(ReplicatedStorage.Modules.GameUtil)
local ItemIDS      = require(ReplicatedStorage.Modules.ItemIDS)
local ItemData     = require(ReplicatedStorage.Modules.ItemData)
local Clock        = require(ReplicatedStorage.Modules.Clock)
local animations   = require(game_.animations)
local inventory    = require(game_.inventory)
local functions    = require(game_.functions)
local rendering    = require(game_.rendering)
local statusEffects = require(game_.classes.statusEffects)
local interpolationBuffer = rendering.interpolationBuffer
local bufferWriter = require(ReplicatedStorage.Modules.ByteNet.process.bufferWriter)
local client       = require(ReplicatedStorage.Modules.ByteNet.process.client)

------------------------------------------------------------
-- CONFIG (reemplaza a library.flags)
------------------------------------------------------------
local Boo = { flags = {}, callbacks = {}, connections = {}, running = true }
getgenv().BooLite = Boo

local flags = Boo.flags
-- Pickup
flags.autopickup = false
flags.autopickuprange = 40
flags.autopickupdelay = 0
flags.autopickuptargets = { "Gold" }      -- "All" o lista de nombres: {"Wood","Stone"}
flags.autopickupchests = false
-- Tp item chest
flags.choosechest = false
flags.autochestitems = false
flags.autochesttargets = { "All" }
-- Mine aura
flags.resourceaura = false
flags.resourceaurasize = 20   -- rango del Mine Aura (antes 5)
flags.resourceauratargets = { "Critters", "Resources" }
flags.resourceauraisolate = false
flags.resourceauraface = false
flags.resourceauraswing = false
-- Auto eat
flags.autoeat = false
flags.autoeatthreshold = 1
flags.autoeatitem = { "Bluefruit" }
-- Auto farm
flags.autofarm = false
flags.autoharvest = false
flags.autoplant = false
flags.autofarmmove = false
flags.autofarmrange = 125
flags.autofarmcache = 3
flags.autofarmmovespeed = 17
flags.autoplantitem = { "Bluefruit" }
-- Auto craft
flags.autocraft = false
flags.autocraftobject = "None"
flags.autocraftuseamount = false
flags.autocraftamount = 0
flags.autocraftdelay = 0.05
-- Auto campfire
flags.autocampfire = false
flags.autocampfirerange = 20
flags.autocampfireitem = { "Leaves", "Log", "Wood" }
flags.autocampfirethreshold = 250
-- Item deletion
flags.autodelete = false
flags.autodeleterange = 25
flags.autodeletetargets = { "Wood", "Log", "Stone", "Raw Iron" }  -- la lista en la captura estaba cortada ("Raw..."); agrega aquí el resto

------------------------------------------------------------
-- UTILIDADES
------------------------------------------------------------
local function notify(text, extra)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Boo Lite", Text = text .. (extra and (" " .. extra) or ""), Duration = 4,
        })
    end)
    print("[BooLite]", text, extra or "")
end

local function ping()
    return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
end

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Boo.connections, c)
    return c
end

local function toSet(v)
    local set = {}
    if type(v) == "string" then
        set[v] = true
    elseif type(v) == "table" then
        for k, name in pairs(v) do
            if type(name) == "string" then set[name] = true
            elseif type(k) == "string" and name == true then set[k] = true end
        end
    end
    return set
end

local function toList(v, valid)
    local list = {}
    if type(v) == "string" then
        if valid(v) then table.insert(list, v) end
    elseif type(v) == "table" then
        for _, name in ipairs(v) do
            if valid(name) then table.insert(list, name) end
        end
    end
    return list
end

------------------------------------------------------------
-- ESTADO
------------------------------------------------------------
local state = {
    inventory = {},        -- nombre -> slot
    inventorylist = {},
    validitems = {},
    chestitems = {},
    checkeditems = {},
    validmineaura = {},
    checkedmineaura = {},
    plantboxes = {},
    plants = {},
    lastChestItemInteract = {},
    chestteleports = {},
    tooltypes = {},
    weapons = { "Rock", "War Hammer", "Mace", "Club", "Battle Axe", "Crystal Stick", "God Rock", "Emerald Blade" },
}

local flagsT = {            -- estados booleanos internos
    eating = false,
    crafting = false,
    autoChestItemsRunning = false,
    ismineauraing = false,
    isplayinghitanim = false,
}

local timers = {
    lastpickup = 0, lastresourceaura = 0, lastmineauracache = 0,
    lasteatcheck = 0, lastautofarmcache = 0, lastautofarmmove = 0,
    lastchestinteractcleanup = 0, lastcampfirecheck = 0,
}

local refs = {
    chosenchest = nil, chesthighlight = nil,
    autoeatIndex = nil, autoplantIndex = nil, autocampfireIndex = nil,
    hitanim1 = nil, hitanim2 = nil,
}

local restPoint = nil
do
    local path = "Boo/games/" .. game.PlaceId .. "/restpoints/" .. localPlayer.UserId .. "/restpoint.txt"
    if isfile and isfile(path) then
        local x, y, z = readfile(path):match("([^,]+),%s*([^,]+),%s*([^,]+)")
        x, y, z = tonumber(x), tonumber(y), tonumber(z)
        if x and y and z then restPoint = Vector3.new(x, y, z) end
    end
end

-- Tipos de herramienta (para la animación de swing)
local toolFolder = game_:FindFirstChild("tool")
for _, mod in ipairs(toolFolder:GetChildren()) do
    state.tooltypes[mod.Name] = require(mod)
end

------------------------------------------------------------
-- PACKETS
------------------------------------------------------------
-- Hook de sendReliable (igual que el script original)
if hookfunction and not getgenv().sendReliable then
    getgenv().sendReliable = hookfunction(client.sendReliable, function(a, b, c)
        if not getgenv().BooLite then return getgenv().sendReliable(a, b, c) end
        state.sendReliableTable = state.sendReliableTable
            or { cursor = 0, size = 256, ready = true, buff = buffer.create(256) }
        state.sendReliableTable = bufferWriter.load(state.sendReliableTable)
        bufferWriter.alloc(1)
        bufferWriter.u8(0)
        bufferWriter.alloc(1)
        bufferWriter.u8(a)
        b(c)
        state.sendReliableTable = bufferWriter.export()
        return getgenv().sendReliable(a, b, c)
    end)
end

local function firepacket(name, ...)
    if not Packets[name] then return false end
    local ok, err = pcall(function(...) Packets[name].send(...) end, ...)
    if not ok then warn("packet failed:", name, err) return false end
    return true
end

------------------------------------------------------------
-- INVENTARIO
------------------------------------------------------------
local function updateinventory()
    table.clear(state.inventory)
    local ordered, list = {}, {}
    local invList = localPlayer.PlayerGui.MainGui.RightPanel.Inventory.List
    for _, child in ipairs(invList:GetChildren()) do
        if child:IsA("GuiBase") then
            state.inventory[child.Name] = child.LayoutOrder
            table.insert(ordered, { item = child.Name, order = child.LayoutOrder })
        end
    end
    table.sort(ordered, function(a, b) return a.order < b.order end)
    for _, e in ipairs(ordered) do
        if not e.item:find("Chest") then table.insert(list, e.item) end
    end
    state.inventorylist = list
end
updateinventory()

Packets.ItemAdded.listen(function(d)
    inventory.itemAdded(ItemIDS[d.itemID], d.quantity, d.index)
    updateinventory()
end)
Packets.ItemChanged.listen(function(d)
    inventory.itemChanged(d.key, d.quantity)
    updateinventory()
end)
Packets.ItemRemoved.listen(function(d)
    inventory.itemRemoved(d)
    updateinventory()
end)

local function getinventoryquantity(name)
    local slot = state.inventory[name]
    if not slot then return 0 end
    local item = GameUtil.Data.inventory[slot]
    if not item or not item.quantity then return nil end
    return tonumber(item.quantity) or 0
end
Boo.getQuantity = getinventoryquantity

------------------------------------------------------------
-- ANIMACIÓN DE SWING
------------------------------------------------------------
local function playToolAnimation(toolData, hasSecondary)
    local useType = toolData.useType
    if useType and hasSecondary then
        if flagsT.isplayinghitanim then
            if refs.hitanim1 then refs.hitanim1:Stop() refs.hitanim1 = nil end
            flagsT.isplayinghitanim = false
            refs.hitanim2 = animations.playAnimation("LSlash")
        else
            if refs.hitanim2 then refs.hitanim2:Stop() refs.hitanim2 = nil end
            flagsT.isplayinghitanim = true
            refs.hitanim1 = animations.playAnimation("Slash")
        end
    elseif useType then
        animations.playAnimation(useType)
    end
end

local function swingAnimation()
    local tool = ItemData[GameUtil.Data.toolbar[GameUtil.Data.equipped].name]
    if not tool or not tool.useType or not state.tooltypes[tool.useType] then return end
    animations.stopCustomAnimations()
    local speed = tool.speed
    if not speed then return end
    if statusEffects.playerHasEffect("Haste") and (tool.toolType == "Axe" or tool.toolType == "Pick") then
        speed -= speed * 0.1
    end
    local now = Clock.getServerTime(true)
    if speed <= now - GameUtil.Data.lastToolUse then
        GameUtil.Data.lastToolUse = now
        local sec = character.Tools:FindFirstChild("Secondary")
        playToolAnimation(tool, sec and sec:FindFirstChild("ToolWeld2") and true or false)
    end
end

------------------------------------------------------------
-- ESCANEO DE ITEMS (Pickup / Deletion / Chest)
------------------------------------------------------------
local function scanItems()
    table.clear(state.validitems)
    table.clear(state.chestitems)
    table.clear(state.checkeditems)

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.MaxParts = 1000
    params.FilterDescendantsInstances = {
        character, Workspace.Players, Workspace.Terrain,
        Workspace.Resources, Workspace.Critters, Workspace.Rubble,
    }

    local parts = Workspace:GetPartBoundsInBox(character:GetPivot(), Vector3.new(50, 50, 50), params)
    for i = 1, #parts do
        local v = parts[i]
        local model = v and v:FindFirstAncestorWhichIsA("Model")
        local contents = v and v:FindFirstAncestor("Contents")

        if not (v and v.Parent == Workspace.Items) then
            if model and model.Parent == Workspace.Items then
                v = model
            elseif flags.autopickupchests and contents then
                if v.Parent ~= contents then
                    v = (model and model.Parent == contents) and model or nil
                else
                    v = v
                end
                if v then table.insert(state.chestitems, v) end
                v = nil -- los items de cofre van a chestitems (usados por pickup)
            else
                v = nil
            end
        end

        if v and not state.checkeditems[v] and v.Parent then
            state.validitems[#state.validitems + 1] = v
            state.checkeditems[v] = true
        end
    end
end

------------------------------------------------------------
-- 1) PICK UP
------------------------------------------------------------
local function doPickup()
    local targets = toSet(flags.autopickuptargets)

    local function try(item)
        local dist = (humanoidRootPart.Position - item:GetPivot().Position).Magnitude
        if dist < flags.autopickuprange and functions.canBearLoad(item) then
            if targets.All or targets[item.Name] then
                if flags.autopickupdelay < tick() - timers.lastpickup then
                    firepacket("Pickup", item:GetAttribute("EntityID"))
                    timers.lastpickup = tick()
                end
            end
        end
    end

    for _, item in pairs(state.validitems) do try(item) end
    if flags.autopickupchests then
        for _, item in pairs(state.chestitems) do try(item) end
    end
end

------------------------------------------------------------
-- 2) TP ITEM CHEST
------------------------------------------------------------
local function doChestItems()
    local chest = refs.chosenchest and refs.chosenchest.model
    if not chest or flagsT.autoChestItemsRunning then return end
    flagsT.autoChestItemsRunning = true

    task.spawn(function()
        local hitbox = chest:FindFirstChild("Hitbox")
        if not hitbox then flagsT.autoChestItemsRunning = false return end

        local targets = toSet(flags.autochesttargets)

        local function moveToChest(item)
            if item and item.Parent and hitbox and hitbox.Parent then
                if item:IsA("Model") then
                    if item.PrimaryPart and not item.PrimaryPart.Anchored then
                        item:PivotTo(hitbox.CFrame)
                    end
                elseif item:IsA("BasePart") and not item.Anchored then
                    item:PivotTo(hitbox.CFrame)
                end
            end
        end

        for _, item in pairs(state.validitems) do
            if item and item.Parent and (targets.All or targets[item.Name]) then
                local id = item:GetAttribute("EntityID")
                if id and not (state.lastChestItemInteract[id] and tick() - state.lastChestItemInteract[id] < 0.01) then
                    if (humanoidRootPart.Position - item:GetPivot().Position).Magnitude <= 25 then
                        state.lastChestItemInteract[id] = tick()

                        local anchored =
                            (item:IsA("Model") and item.PrimaryPart and item.PrimaryPart.Anchored)
                            or (item:IsA("BasePart") and item.Anchored)

                        if anchored then
                            local last = state.chestteleports[item]
                            if not (last and tick() - last > ping()) then
                                firepacket("ForceInteract", id)
                                state.chestteleports[item] = tick()
                                task.wait(ping())
                                state.chestteleports[item] = nil
                                moveToChest(item)
                            end
                        else
                            moveToChest(item)
                        end
                    end
                end
            end
        end
        flagsT.autoChestItemsRunning = false
    end)
end

-- Elegir el cofre con click
connect(UserInputService.InputBegan, function(input, processed)
    if processed or not flags.choosechest then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local target = mouse.Target
    if input.UserInputType == Enum.UserInputType.Touch then
        local ray = Workspace.CurrentCamera:ViewportPointToRay(input.Position.X, input.Position.Y)
        local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000)
        target = hit and hit.Instance
    end
    if not target then return end

    local model = target:FindFirstAncestorWhichIsA("Model")
    if not model or (model.Name ~= "Reinforced Chest" and model.Name ~= "Chest") then return end

    if refs.chosenchest then
        if refs.chosenchest.highlight then refs.chosenchest.highlight:Destroy() end
        if refs.chosenchest.model == model then
            refs.chosenchest = nil
            flags.choosechest = false
            return
        end
    end

    local hl = Instance.new("Highlight")
    hl.Adornee = model
    hl.Parent = model
    hl.DepthMode = Enum.HighlightDepthMode.Occluded
    hl.FillColor = Color3.fromRGB(255, 255, 255)
    refs.chesthighlight = hl
    refs.chosenchest = { model = model, highlight = hl }
    flags.choosechest = false
    notify("Cofre seleccionado", model.Name)
end)

------------------------------------------------------------
-- 3) MINE AURA
------------------------------------------------------------
local function getresource()
    local pos = humanoidRootPart.Position
    local best, bestDist = nil, flags.resourceaurasize
    for i = 1, #state.validmineaura do
        local r = state.validmineaura[i]
        if r and r.Parent then
            local d = (r:GetPivot().Position - pos).Magnitude
            if d <= bestDist then bestDist, best = d, r end
        end
    end
    return best, bestDist
end

local function resourceaura(target)
    if not target or not target.Parent then return end
    if tick() - timers.lastresourceaura < 0.05 then return end

    if flags.resourceauraswing then task.spawn(swingAnimation) end

    local entities, seen = {}, {}
    local function addmodel(model)
        if not model or not model.Parent then return end
        local id = model:GetAttribute("EntityID")
        if not id then
            for _, d in ipairs(model:GetDescendants()) do
                id = d:GetAttribute("EntityID")
                if id then break end
            end
        end
        if not id or seen[id] then return end
        local cid = model:IsDescendantOf(Workspace.Players) and model:GetAttribute("clientIdentifier")
        local critter = cid and rendering.critters[cid]
        entities[#entities + 1] = {
            entityID = id,
            buffer = critter and interpolationBuffer.getBuffer(critter.playerBuffer) or nil,
        }
        seen[id] = true
    end

    if flags.resourceauraisolate then
        addmodel(target)
    else
        for i = 1, #state.validmineaura do addmodel(state.validmineaura[i]) end
    end
    if #entities <= 0 then return end

    timers.lastresourceaura = tick()
    firepacket("SwingTool", {
        entityIDs = entities,
        cframe = character:GetPivot(),
        timestamp = Clock.getServerTime(true),
    })
end

local function cacheMineAura()
    table.clear(state.validmineaura)
    table.clear(state.checkedmineaura)

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filter = { character, Workspace.Players, Workspace.Terrain, Workspace.Items }
    for _, t in ipairs(CollectionService:GetTagged("Contents")) do table.insert(filter, t) end
    params.FilterDescendantsInstances = filter

    local s = flags.resourceaurasize * 2.5
    local parts = Workspace:GetPartBoundsInBox(character:GetPivot(), Vector3.new(s, s, s), params)

    local targets = flags.resourceauratargets
    local function wants(name)
        return targets == name or (type(targets) == "table" and table.find(targets, name))
    end

    for i = 1, #parts do
        local model = parts[i]:FindFirstAncestorWhichIsA("Model")
        if model and not state.checkedmineaura[model] and model.Parent and model:IsA("Model") then
            local ok = false
            if wants("Resources") then
                if model.Parent == Workspace.Resources or model.Parent == Workspace:FindFirstChild("Mounds")
                    or model.Name == "Gold Node" or model.Name == "Iron Node" or model.Name == "Coal Node"
                    or model.Name == "Meteor Core" or model.Name == "Crystal Meteor Core"
                    or model.Name == "Crystal Meteor Rock" or model.Name == "Magnetite Meteor Rock"
                    or model.Name == "Small Rock" or model.Name == "Meteor Rock" then
                    ok = true
                end
            end
            if not ok and wants("Critters")    and model.Parent == Workspace.Critters    then ok = true end
            if not ok and wants("Deployables") and model.Parent == Workspace.Deployables then ok = true end
            if not ok and wants("Rubble")      and model.Parent == Workspace.Rubble      then ok = true end

            if ok then
                state.checkedmineaura[model] = true
                state.validmineaura[#state.validmineaura + 1] = model
            end
        end
    end
end

local function doMineAura()
    -- herramienta equipada (arma, hacha o pico)
    local tools = character.Tools:GetChildren()
    local equipped
    if #tools == 1 then
        if tools[1]:IsA("Model") then equipped = tools[1] end
    elseif #tools > 1 then
        for _, t in ipairs(tools) do
            if t:IsA("Model") and (table.find(state.weapons, t.Name) or t.Name:find("Axe") or t.Name:find("Pick")) then
                equipped = t break
            end
        end
    end
    if not equipped then return end
    if not (table.find(state.weapons, equipped.Name) or equipped.Name:find("Axe") or equipped.Name:find("Pick")) then return end

    if #state.validmineaura > 0 then
        local res = getresource()
        if res then
            if flags.resourceauraface then
                local p = res:GetPivot().Position
                character:PivotTo(CFrame.lookAt(humanoidRootPart.Position,
                    Vector3.new(p.X, humanoidRootPart.Position.Y, p.Z)))
            end
            resourceaura(res)
            flagsT.ismineauraing = true
        else
            flagsT.ismineauraing = false
        end
    else
        flagsT.ismineauraing = false
    end

    if tick() - timers.lastmineauracache >= 0.1 then
        timers.lastmineauracache = tick()
        cacheMineAura()
    end
end

------------------------------------------------------------
-- 4) AUTO EAT
------------------------------------------------------------
local function autoEatLoop()
    while Boo.running and flags.autoeat do
        if tick() - timers.lasteatcheck >= 1 then
            timers.lasteatcheck = tick()
            if not flagsT.eating and GameUtil.Data.stats.food < flags.autoeatthreshold then
                flagsT.eating = true
                local list = toList(flags.autoeatitem, function(n) return ItemIDS[n] and state.inventory[n] end)
                if #list > 0 then
                    refs.autoeatIndex = (refs.autoeatIndex or 0) + 1
                    if #list < refs.autoeatIndex then refs.autoeatIndex = 1 end
                    local name = list[refs.autoeatIndex]
                    while true do
                        local slot = state.inventory[name]
                        if not slot then break end
                        firepacket("UseBagItem", slot)
                        task.wait(ping())
                        if not flags.autoeat or not Boo.running or GameUtil.Data.stats.food >= 100 then break end
                    end
                end
                flagsT.eating = false
            end
        end
        task.wait()
    end
    flagsT.eating = false
end

------------------------------------------------------------
-- 5) AUTO PLANT + AUTO HARVEST
------------------------------------------------------------
local function refreshautofarmtable(list, isPlantBox)
    for i = #list, 1, -1 do
        local entry = list[i]
        if not entry.Model or not entry.Model.Parent then
            table.remove(list, i)
        else
            local pos
            if isPlantBox then
                local box = entry.Model:FindFirstChild("collisionBox")
                if not box or entry.Model:FindFirstChild("Seed") then table.remove(list, i) continue end
                pos = box.Position
            else
                pos = entry.Model:GetPivot().Position
            end
            entry.Position = pos
            entry.Distance = (pos - humanoidRootPart.Position).Magnitude
            if entry.Distance > flags.autofarmrange then table.remove(list, i) end
        end
    end
    table.sort(list, function(a, b) return a.Distance < b.Distance end)
end

local function cacheautofarm()
    timers.lastautofarmcache = tick()
    table.clear(state.plantboxes)
    table.clear(state.plants)

    local seenBoxes, seenPlants = {}, {}

    local canPlant = #toList(flags.autoplantitem, function(n) return ItemIDS[n] and state.inventory[n] end) > 0

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filter = { character, Workspace.Terrain, Workspace.Items, Workspace.Rubble,
                     Workspace.Resources, Workspace.Players }
    for _, t in ipairs(CollectionService:GetTagged("Contents")) do table.insert(filter, t) end
    params.FilterDescendantsInstances = filter

    local range = flags.autofarmrange
    local center = CFrame.new(character:GetPivot().Position) - (Vector3.new(0, humanoid.HipHeight, 0) + Vector3.new(0, 2, 0))
    local parts = Workspace:GetPartBoundsInBox(center, Vector3.new(range * 2, 15, range * 2), params)

    for _, part in ipairs(parts) do
        local model = part:FindFirstAncestorWhichIsA("Model")
        if model then
            if flags.autoplant and canPlant and model.Parent == Workspace.Deployables then
                if model.Name == "Plant Box" and model:FindFirstChild("collisionBox")
                    and not model:FindFirstChild("Seed") and not seenBoxes[model] then
                    local pos = model.collisionBox.Position
                    local dist = (pos - humanoidRootPart.Position).Magnitude
                    if dist <= range then
                        seenBoxes[model] = true
                        table.insert(state.plantboxes, { Model = model, Position = pos, Distance = dist })
                    end
                end
            end

            if flags.autoharvest and not seenPlants[model]
                and model.Parent ~= Workspace.Resources and model.Parent ~= Workspace.Critters
                and model.Parent ~= Workspace.Deployables and model.Parent ~= Workspace.Rubble
                and model.Name ~= "Plant Box" then
                local n = string.lower(model.Name)
                if n:find("bush", 1, true) or n:find("tree", 1, true)
                    or n:find("crop", 1, true) or n:find("cacti", 1, true) then
                    local pos = model:GetPivot().Position
                    local dist = (pos - humanoidRootPart.Position).Magnitude
                    if dist <= range then
                        seenPlants[model] = true
                        table.insert(state.plants, { Model = model, Position = pos, Distance = dist })
                    end
                end
            end
        end
    end

    refreshautofarmtable(state.plantboxes, true)
    refreshautofarmtable(state.plants, false)
end

local function autoFarmLoop()
    cacheautofarm()
    timers.lastautofarmmove = tick()

    while Boo.running and flags.autofarm do
        if flags.autofarmcache <= tick() - timers.lastautofarmcache then
            cacheautofarm()
        end

        -- mover
        task.spawn(function()
            if not flags.autofarmmove then timers.lastautofarmmove = tick() return end
            local pos
            local box = flags.autoplant and state.plantboxes[1] and state.plantboxes[1].Model
            if box and box:FindFirstChild("collisionBox") then pos = box.collisionBox.Position end
            if not pos and flags.autoharvest and state.plants[1] and state.plants[1].Model
                and state.plants[1].Model.Parent then
                pos = state.plants[1].Model:GetPivot().Position
            end
            if not pos and restPoint then pos = restPoint end

            if pos then
                local goal = pos + Vector3.new(0, 3, 0)
                local cur = humanoidRootPart.Position
                local diff = goal - cur
                local mag = diff.Magnitude
                if mag > 0.1 then
                    local now = tick()
                    local step = math.min(flags.autofarmmovespeed * math.clamp(now - timers.lastautofarmmove, 0, 1/30), mag)
                    humanoidRootPart.CFrame = CFrame.new(cur + diff.Unit * step)
                    timers.lastautofarmmove = now
                else
                    humanoidRootPart.CFrame = CFrame.new(goal)
                    timers.lastautofarmmove = tick()
                end
            else
                timers.lastautofarmmove = tick()
            end
        end)

        -- cosechar
        task.spawn(function()
            if flags.autoharvest and #state.plants > 0 then
                for i = 1, #state.plants do
                    local p = state.plants[i]
                    if p and p.Model and p.Model.Parent then
                        if (p.Model:GetPivot().Position - humanoidRootPart.Position).Magnitude <= 25 then
                            firepacket("Pickup", p.Model:GetAttribute("EntityID"))
                            table.remove(state.plants, i)
                            refreshautofarmtable(state.plants, false)
                            return
                        end
                    else
                        table.remove(state.plants, i)
                        refreshautofarmtable(state.plants, false)
                        return
                    end
                end
            end
        end)

        -- plantar
        task.spawn(function()
            if flags.autoplant and #state.plantboxes > 0 then
                local found, idx
                for i = 1, #state.plantboxes do
                    local b = state.plantboxes[i]
                    if b and b.Model and b.Model.Parent and b.Model:FindFirstChild("collisionBox") then
                        if (b.Model.collisionBox.Position - humanoidRootPart.Position).Magnitude <= 25 then
                            found, idx = b, i
                            break
                        end
                    else
                        table.remove(state.plantboxes, i)
                        refreshautofarmtable(state.plantboxes, true)
                        return
                    end
                end

                if found then
                    local list = toList(flags.autoplantitem, function(n) return ItemIDS[n] and state.inventory[n] end)
                    if #list > 0 then
                        refs.autoplantIndex = (refs.autoplantIndex or 0) + 1
                        if #list < refs.autoplantIndex then refs.autoplantIndex = 1 end
                        local name = list[refs.autoplantIndex]
                        if not found.Model:FindFirstChild("Seed") then
                            firepacket("InteractStructure", {
                                entityID = found.Model:GetAttribute("EntityID"),
                                itemID = ItemIDS[name],
                            })
                        else
                            table.remove(state.plantboxes, idx)
                            refreshautofarmtable(state.plantboxes, true)
                        end
                    end
                end
            end
        end)

        task.wait()
    end
end

function Boo.setRestPoint()
    restPoint = character:GetPivot().Position
    if makefolder and writefile then
        local base = "Boo/games/" .. game.PlaceId .. "/restpoints/" .. localPlayer.UserId
        local acc = ""
        for part in string.gmatch(base, "[^/]+") do
            acc = acc == "" and part or acc .. "/" .. part
            if not isfolder(acc) then makefolder(acc) end
        end
        writefile(base .. "/restpoint.txt", restPoint.X .. ", " .. restPoint.Y .. ", " .. restPoint.Z)
    end
    notify("Rest point guardado")
end

------------------------------------------------------------
-- 6) AUTO CRAFT
------------------------------------------------------------
local function autoCraft()
    if flagsT.crafting then return end

    if flags.autocraftuseamount then
        local amount = tonumber(flags.autocraftamount)
        if not amount or amount <= 0 then flags.autocraft = false return end

        local itemName = flags.autocraftobject
        if not ItemIDS[itemName] then notify("Item inválido") flags.autocraft = false return end

        flagsT.crafting = true
        local start = getinventoryquantity(itemName)
        if not start then flagsT.crafting = false flags.autocraft = false return end

        local goal, current = start + amount, start
        while current < goal and Boo.running do
            if not GameUtil.canCraftItem(itemName, nil, true) then
                if flags.autocraftdelay > 0 then task.wait(flags.autocraftdelay) else task.wait() end
                current = getinventoryquantity(itemName) or 0
                if not flags.autocraft then flagsT.crafting = false return end
                continue
            end
            if not flags.autocraft then flagsT.crafting = false return end

            local before = current
            firepacket("CraftItem", ItemIDS[itemName])
            if flags.autocraftdelay > 0 then task.wait(flags.autocraftdelay) end

            local t0 = tick()
            while true do
                current = getinventoryquantity(itemName) or 0
                task.wait()
                if not flags.autocraft or current ~= before or tick() - t0 >= 3 then break end
            end
        end

        if flags.autocraft then
            notify("Crafteo terminado", itemName .. " x" .. math.max(current - start, 0))
        end
        flagsT.crafting = false
        flags.autocraft = false
    else
        flagsT.crafting = true
        while Boo.running and flags.autocraft do
            local itemName = flags.autocraftobject
            if not ItemIDS[itemName] then
                notify("Item inválido")
                flags.autocraft = false
                break
            end
            if GameUtil.canCraftItem(itemName, nil, true) then
                firepacket("CraftItem", ItemIDS[itemName])
            end
            if flags.autocraftdelay > 0 then task.wait(flags.autocraftdelay) else task.wait() end
        end
        flagsT.crafting = false
    end
end

------------------------------------------------------------
-- 8) AUTO CAMPFIRE
------------------------------------------------------------
local function campfireValue(fire)
    local ok, v = pcall(function()
        return tonumber(fire.Board.Billboard.Backdrop.TextLabel.Text)
    end)
    return ok and v or nil
end

local function feedCampfire(fire)
    local list = toList(flags.autocampfireitem, function(n) return ItemIDS[n] and state.inventory[n] end)
    if #list == 0 then return end
    while Boo.running and flags.autocampfire and fire.Parent do
        local value = campfireValue(fire)
        if not value or value >= flags.autocampfirethreshold then break end
        -- recalcular por si se acabó algún item
        list = toList(flags.autocampfireitem, function(n) return ItemIDS[n] and state.inventory[n] end)
        if #list == 0 then break end
        refs.autocampfireIndex = (refs.autocampfireIndex or 0) + 1
        if #list < refs.autocampfireIndex then refs.autocampfireIndex = 1 end
        local name = list[refs.autocampfireIndex]
        firepacket("InteractStructure", { entityID = fire:GetAttribute("EntityID"), itemID = ItemIDS[name] })
        task.wait(ping())
    end
end

local function autoCampfireLoop()
    while Boo.running and flags.autocampfire do
        if tick() - timers.lastcampfirecheck >= 1 then
            timers.lastcampfirecheck = tick()
            task.spawn(function()
                for _, child in ipairs(Workspace.Deployables:GetChildren()) do
                    if child.Name == "Campfire" and humanoidRootPart then
                        local dist = (child:GetPivot().Position - humanoidRootPart.Position).Magnitude
                        if dist <= flags.autocampfirerange then
                            local value = campfireValue(child)
                            if value and value < flags.autocampfirethreshold then
                                feedCampfire(child)
                            end
                        end
                    end
                end
            end)
        end
        task.wait()
    end
end

------------------------------------------------------------
-- 7) ITEM DELETION
------------------------------------------------------------
local function doDelete()
    local targets = toSet(flags.autodeletetargets)
    for k, item in pairs(state.validitems) do
        if item and item.Parent then
            local dist = (humanoidRootPart.Position - item:GetPivot().Position).Magnitude
            if dist < flags.autodeleterange and (targets.All or targets[item.Name]) then
                item:Destroy() -- solo local
                state.validitems[k] = nil
                state.checkeditems[item] = nil
            end
        end
    end
end

------------------------------------------------------------
-- LOOPS PRINCIPALES
------------------------------------------------------------
connect(RunService.Heartbeat, function()
    if not character or not character.Parent then return end
    if not humanoid or humanoid.Health <= 0 then return end
    if not humanoidRootPart or not humanoidRootPart.Parent then return end
    if not localPlayer:GetAttribute("hasSpawned") then return end

    if flags.autopickup or flags.autodelete or flags.autochestitems then
        scanItems()
    end

    if flags.autodelete then doDelete() end
    if flags.autochestitems then doChestItems() end
    if flags.autopickup then doPickup() end

    -- limpieza de cooldowns del cofre
    if tick() - timers.lastchestinteractcleanup >= 30 then
        timers.lastchestinteractcleanup = tick()
        local cutoff = tick() - 10
        for k, v in pairs(state.lastChestItemInteract) do
            if v < cutoff then state.lastChestItemInteract[k] = nil end
        end
    end
end)

connect(RunService.RenderStepped, function()
    if not character or not character.Parent then return end
    if not humanoid or humanoid.Health <= 0 then return end
    if not humanoidRootPart or not humanoidRootPart.Parent then return end
    if not localPlayer:GetAttribute("hasSpawned") then return end

    if flags.resourceaura then
        doMineAura()
    else
        flagsT.ismineauraing = false
    end
end)

-- Personaje nuevo al morir
connect(localPlayer.CharacterAdded, function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    humanoidRootPart = char:WaitForChild("HumanoidRootPart")
    flagsT.eating = false
end)

------------------------------------------------------------
-- API
------------------------------------------------------------
-- Callbacks que arrancan loops al prender el flag
Boo.callbacks.autoeat = function(on) if on then task.spawn(autoEatLoop) end end
Boo.callbacks.autofarm = function(on) if on then task.spawn(autoFarmLoop) end end
Boo.callbacks.autocraft = function(on) if on then task.spawn(autoCraft) end end
Boo.callbacks.autocampfire = function(on) if on then task.spawn(autoCampfireLoop) end end

function Boo.set(name, value)
    if flags[name] == nil then warn("flag inexistente:", name) return end
    flags[name] = value
    if Boo.callbacks[name] then Boo.callbacks[name](value) end
end

function Boo.unload()
    Boo.running = false
    for k, v in pairs(flags) do
        if type(v) == "boolean" then flags[k] = false end
    end
    for _, c in ipairs(Boo.connections) do pcall(function() c:Disconnect() end) end
    table.clear(Boo.connections)
    if refs.chosenchest and refs.chosenchest.highlight then refs.chosenchest.highlight:Destroy() end
    getgenv().BooLite = nil
end


notify("Boo Lite cargado")
return Boo
end

task.spawn(function()
    local okB, Boo = pcall(loadBoo)
    if not okB or type(Boo) ~= "table" then
        warn("[Hub] Boo Lite: " .. tostring(Boo))
        TabBoo:AddLabel("Error: " .. tostring(Boo))
        return
    end
    local flags = Boo.flags
    local syncs = {}

    -- Config por defecto (según tus capturas): toggles que arrancan en ON
    for _, name in ipairs({
        "autopickup", "autopickupchests", "resourceaura", "autoeat",
        "autofarm", "autoharvest", "autoplant", "autocampfire",
        "autodelete", "autochestitems",
    }) do
        Boo.set(name, true)
    end
    -- OFF por defecto: autofarmmove, resourceauraswing, choosechest
    flags.autopickupdelay = 0   -- delay del pickup en 0

    local function bToggle(label, flag)
        local reg = TabBoo:AddToggle(label, flags[flag], function(v) Boo.set(flag, v) end)
        syncs[#syncs + 1] = function() reg.SetValue(flags[flag]) end
    end

    local function bBox(label, flag, kind)
        local cur = flags[flag]
        local txt = type(cur) == "table" and table.concat(cur, ", ") or tostring(cur)
        TabBoo:AddInput(label, txt, function(t)
            if t == "" then return end
            if kind == "number" then
                local n = tonumber(t)
                if n then flags[flag] = n end
            elseif kind == "list" then
                local list = {}
                for name in string.gmatch(t, "[^,]+") do
                    list[#list + 1] = (name:gsub("^%s+", ""):gsub("%s+$", ""))
                end
                flags[flag] = list
            else
                flags[flag] = t
            end
        end)
    end

    bToggle("Pickup Aura", "autopickup")
    bBox("Pickup range", "autopickuprange", "number")
    bBox("Pickup items (Wood, Stone / All)", "autopickuptargets", "list")
    bToggle("Pickup chest items", "autopickupchests")
    bToggle("Mine Aura", "resourceaura")
    bBox("Mine range", "resourceaurasize", "number")
    bToggle("Mine swing anim", "resourceauraswing")
    bToggle("Auto Eat", "autoeat")
    bBox("Eat threshold", "autoeatthreshold", "number")
    bBox("Eat items (Bloodfruit, Apple)", "autoeatitem", "list")
    bToggle("Auto Farm", "autofarm")
    bToggle("Auto Harvest", "autoharvest")
    bToggle("Auto Plant", "autoplant")
    bToggle("Auto Move", "autofarmmove")
    bBox("Plant items (Bloodfruit, Berry)", "autoplantitem", "list")
    bBox("Farm range", "autofarmrange", "number")
    bToggle("Auto Campfire", "autocampfire")
    bBox("Campfire range", "autocampfirerange", "number")
    bBox("Campfire items (Leaves, Wood, Log, Coal)", "autocampfireitem", "list")
    bBox("Campfire threshold (50-250)", "autocampfirethreshold", "number")
    bToggle("Item Deletion", "autodelete")
    bBox("Delete range", "autodeleterange", "number")
    bBox("Delete items (Leaves, Sand)", "autodeletetargets", "list")
    bToggle("Select Chest (click chest)", "choosechest")
    bToggle("Auto Insert Items (chest)", "autochestitems")
    bBox("Chest items (Wood / All)", "autochesttargets", "list")
    bToggle("Auto Craft", "autocraft")
    bBox("Craft item (ej: Steel)", "autocraftobject", "text")
    bToggle("Craft usa cantidad", "autocraftuseamount")
    bBox("Craft cantidad", "autocraftamount", "number")
    TabBoo:AddButton("Set Rest Point", Boo.setRestPoint)

    table.insert(Hub.OnClose, function()
        local b = getgenv and getgenv().BooLite
        if b and b.unload then b.unload() end
    end)

    -- mantiene los toggles de la ventana sincronizados con los flags
    while Boo.running do
        for _, refresh in ipairs(syncs) do refresh() end
        task.wait(0.25)
    end
end)


--========================================================================
-- PESTAÑA 3: AUTO EQUIP (autoequip_autoexec.lua, sin autoarranque propio)
--========================================================================
local function loadAutoEquip()

-- AutoEquip (versión AUTOEXEC): hoe si hay Plant Box cerca, pico si no.
-- Poné este archivo en la carpeta autoexec. Se inicia solo al entrar al juego.

-- Esperar a que cargue el juego ANTES de buscar ByteNetReliable y los módulos
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(2)

-- AutoEquipTool (extraído del script, versión independiente)
-- Uso:
--   local AutoEquip = loadstring(readfile("autoequiptool.lua"))()
--   AutoEquip.equip("Shovel")            -- equipa una vez
--   AutoEquip.start("Stone Pickaxe")     -- mantiene la herramienta equipada
--   AutoEquip.stop()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer

local AutoEquip = {}
local running = false

-- [ ByteNetReliable ] --
local ByteNetReliable = ReplicatedStorage:FindFirstChild("ByteNetReliable")
    or ReplicatedStorage:WaitForChild("ByteNetReliable", 5)
if not ByteNetReliable then
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == "ByteNetReliable" and v:IsA("RemoteEvent") then
            ByteNetReliable = v
            break
        end
    end
end

-- [ Packet IDs: se descubren en vivo desde Modules.Packets ] --
local PACKET_IDS = {}

local function readPacketObjectId(obj)
    if type(obj) ~= "table" then return nil end
    for _, key in ipairs({ "id", "Id", "_id", "packetId", "packetID", "ID" }) do
        local v = obj[key]
        if type(v) == "number" and v == v and v > 0 then return v end
    end
    return nil
end

local function discoverPacketIds()
    local modules = ReplicatedStorage:FindFirstChild("Modules") or ReplicatedStorage:WaitForChild("Modules", 10)
    local packetsInst = modules and (modules:FindFirstChild("Packets") or modules:WaitForChild("Packets", 10))
    if not packetsInst then return end
    local ok, gamePackets = pcall(require, packetsInst)
    if not ok or type(gamePackets) ~= "table" then return end

    for name, obj in pairs(gamePackets) do
        local id = readPacketObjectId(obj)
        if type(name) == "string" and id then PACKET_IDS[name] = id end
    end

    -- Respaldo: buscar el ID en la tabla packetIDs de ByteNet
    local byteNet = modules:FindFirstChild("ByteNet")
    local folder = byteNet and byteNet:FindFirstChild("packets")
    local idsInst = (folder and (folder:FindFirstChild("packetIDs") or folder:FindFirstChild("packetIds")))
        or (byteNet and (byteNet:FindFirstChild("packetIDs") or byteNet:FindFirstChild("packetIds")))
        or modules:FindFirstChild("packetIDs")
    if idsInst then
        local okIds, packetIDs = pcall(require, idsInst)
        if okIds and type(packetIDs) == "table" then
            for name, obj in pairs(gamePackets) do
                if not PACKET_IDS[name] then
                    for id, reg in pairs(packetIDs) do
                        if type(id) == "number" and reg == obj then PACKET_IDS[name] = id break end
                    end
                end
            end
        end
    end
end

local function getPacketId(name)
    if next(PACKET_IDS) == nil then pcall(discoverPacketIds) end
    return PACKET_IDS[name]
end

-- [ Lógica de equip ] --
local function getToolSlot(toolName)
    local GameUtil
    pcall(function() GameUtil = require(ReplicatedStorage.Modules.GameUtil) end)
    local toolbar = GameUtil and GameUtil.Data and GameUtil.Data.toolbar
    if not toolbar then return nil end
    for i = 1, 6 do
        if toolbar[i] and toolbar[i].name == toolName then return i end
    end
    return nil
end

local function fallbackEquip(name)
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local tool = plr.Backpack and plr.Backpack:FindFirstChild(name)
    if hum and tool then hum:EquipTool(tool) end
end

function AutoEquip.equip(name)
    if not ByteNetReliable then return fallbackEquip(name) end
    local slot = getToolSlot(name)
    local packetId = getPacketId("EquipTool")
    if slot and packetId then
        local b = buffer.create(4)
        buffer.writeu8(b, 0, 0)          -- header
        buffer.writeu8(b, 1, packetId)   -- ID del paquete EquipTool
        buffer.writeu16(b, 2, slot)      -- slot del toolbar
        ByteNetReliable:FireServer(b)
    else
        fallbackEquip(name)
    end
end

function AutoEquip.isEquipped(name)
    local players = workspace:FindFirstChild("Players")
    local folder = players and players:FindFirstChild(plr.Name)
    local tools = folder and folder:FindFirstChild("Tools")
    if tools and tools:FindFirstChild(name) then return true end
    return plr.Character ~= nil and plr.Character:FindFirstChild(name) ~= nil
end

function AutoEquip.isAnyEquipped()
    local players = workspace:FindFirstChild("Players")
    local folder = players and players:FindFirstChild(plr.Name)
    local tools = folder and folder:FindFirstChild("Tools")
    if tools and #tools:GetChildren() > 0 then return true end
    return plr.Character ~= nil and plr.Character:FindFirstChildOfClass("Tool") ~= nil
end

-- Mantiene la herramienta equipada (el script original llama a startGoldEquipManager,
-- pero esa función no está definida en el archivo, así que este loop es una versión simple).
function AutoEquip.start(name, interval)
    if running then return end
    running = true
    task.spawn(function()
        while running do
            if not AutoEquip.isEquipped(name) then AutoEquip.equip(name) end
            task.wait(interval or 0.5)
        end
    end)
end

function AutoEquip.stop() running = false end

-- Diagnóstico: AutoEquip.debug("Shovel") e imprime en qué paso falla
function AutoEquip.debug(name)
    print("[AutoEquip] ByteNetReliable:", ByteNetReliable and ByteNetReliable:GetFullName() or "NO ENCONTRADO")
    local m = ReplicatedStorage:FindFirstChild("Modules")
    print("[AutoEquip] Modules:", m and "ok" or "NO ENCONTRADO")
    print("[AutoEquip] Modules.Packets:", (m and m:FindFirstChild("Packets")) and "ok" or "NO ENCONTRADO")
    local okD, errD = pcall(discoverPacketIds)
    print("[AutoEquip] discoverPacketIds:", okD and "ok" or errD)
    local count = 0
    for _ in pairs(PACKET_IDS) do count += 1 end
    print("[AutoEquip] paquetes encontrados:", count)
    print("[AutoEquip] ID de EquipTool:", PACKET_IDS["EquipTool"])
    print("[AutoEquip] slot de '" .. tostring(name) .. "':", getToolSlot(name))
    local GameUtil
    local okG, errG = pcall(function() GameUtil = require(ReplicatedStorage.Modules.GameUtil) end)
    print("[AutoEquip] GameUtil:", okG and "ok" or errG)
    if GameUtil and GameUtil.Data and GameUtil.Data.toolbar then
        for i = 1, 6 do
            local t = GameUtil.Data.toolbar[i]
            print("  slot", i, t and t.name or "(vacío)")
        end
    end
    print("[AutoEquip] equipada ahora:", AutoEquip.isEquipped(name))
end

-- [ Modo inteligente: hoe si hay Plant Box cerca, pico si no ] --
local PICK_PRIORITY = { "God Pick", "Void Pick", "Pink Diamond Pick", "Emerald Pick" }

local function toolNames()
    local names, seen = {}, {}
    local function add(n)
        if n and not seen[n] then seen[n] = true table.insert(names, n) end
    end
    local GameUtil
    pcall(function() GameUtil = require(ReplicatedStorage.Modules.GameUtil) end)
    local toolbar = GameUtil and GameUtil.Data and GameUtil.Data.toolbar
    if toolbar then
        for i = 1, 6 do if toolbar[i] then add(toolbar[i].name) end end
    end
    if plr.Backpack then for _, t in ipairs(plr.Backpack:GetChildren()) do add(t.Name) end end
    if plr.Character then
        for _, t in ipairs(plr.Character:GetChildren()) do if t:IsA("Tool") then add(t.Name) end end
    end
    return names
end

-- Hoe: la que digas, o la primera que tenga "hoe" (prefiere la de "crystal")
local function resolveHoe(custom)
    local names = toolNames()
    if custom then return custom end
    local any
    for _, n in ipairs(names) do
        local l = n:lower()
        if l:find("hoe", 1, true) then
            if l:find("crystal", 1, true) then return n end
            any = any or n
        end
    end
    return any
end

-- Pico: el que digas, o el mejor de la lista de prioridad, o cualquiera con "pick"
local function resolvePick(custom)
    if custom then return custom end
    local names = toolNames()
    local set = {}
    for _, n in ipairs(names) do set[n] = true end
    for _, n in ipairs(PICK_PRIORITY) do if set[n] then return n end end
    for _, n in ipairs(names) do
        if n:lower():find("pick", 1, true) then return n end
    end
    return nil
end

local function plantBoxNearby(range)
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    local deployables = workspace:FindFirstChild("Deployables")
    if not hrp or not deployables then return false end
    local rangeSq = range * range
    for _, model in ipairs(deployables:GetChildren()) do
        if model.Name:lower():find("plant box", 1, true) then
            local part = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
                or (model:IsA("BasePart") and model)
            if part then
                local d = hrp.Position - part.Position
                if d.X * d.X + d.Y * d.Y + d.Z * d.Z <= rangeSq then return true end
            end
        end
    end
    return false
end

-- opts: { hoe = "Nombre exacto" (opcional), pick = "Nombre exacto" (opcional),
--         range = 25, interval = 0.3, verbose = true }
function AutoEquip.startSmart(opts)
    opts = opts or {}
    if running then return end
    running = true
    local range = opts.range or 25
    local last
    task.spawn(function()
        while running do
            local wantHoe = plantBoxNearby(range)
            local target = wantHoe and resolveHoe(opts.hoe) or resolvePick(opts.pick)
            if target then
                if opts.verbose ~= false and target ~= last then
                    print("[AutoEquip] " .. (wantHoe and "Plant Box cerca -> " or "Sin Plant Box -> ") .. target)
                    last = target
                end
                if not AutoEquip.isEquipped(target) then AutoEquip.equip(target) end
            elseif opts.verbose ~= false and last ~= "none" then
                warn("[AutoEquip] No encontré " .. (wantHoe and "ninguna hoe" or "ningún pico") .. " en tu inventario")
                last = "none"
            end
            task.wait(opts.interval or 0.3)
        end
    end)
end


local env = (getgenv and getgenv()) or _G
if env.__AUTOEQUIP_RUNNING then
    pcall(function() env.__AUTOEQUIP_RUNNING.stop() end)
end
env.__AUTOEQUIP_RUNNING = AutoEquip
return AutoEquip
end

task.spawn(function()
    local okE, AE = pcall(loadAutoEquip)
    if not okE or type(AE) ~= "table" then
        warn("[Hub] AutoEquip: " .. tostring(AE))
        TabEquip:AddLabel("Error: " .. tostring(AE))
        return
    end
    local LPlayer = game:GetService("Players").LocalPlayer
    local cfg = { enabled = true, hoe = nil, pick = nil, range = 25 }
    local gen = 0

    -- reinicia el modo inteligente con la config actual (hoe si hay Plant Box cerca, pico si no)
    local function apply()
        gen = gen + 1
        local my = gen
        AE.stop()
        task.delay(0.5, function()
            if my ~= gen or not cfg.enabled then return end
            AE.startSmart({ hoe = cfg.hoe, pick = cfg.pick, range = cfg.range })
        end)
    end

    TabEquip:AddLabel("Auto Equip (hoe / pico)")
    TabEquip:AddToggle("Smart Equip", true, function(v) cfg.enabled = v apply() end)
    TabEquip:AddInput("Hoe (vacío = auto)", "", function(t)
        cfg.hoe = (t ~= "" and t) or nil
        apply()
    end)
    TabEquip:AddInput("Pico (vacío = auto)", "", function(t)
        cfg.pick = (t ~= "" and t) or nil
        apply()
    end)
    TabEquip:AddSlider("Rango Plant Box", 5, 100, 25, 1, function(v)
        cfg.range = v
        apply()
    end)

    table.insert(Hub.OnClose, function()
        cfg.enabled = false
        gen = gen + 1
        AE.stop()
    end)

    -- arranque automático (igual que la versión autoexec)
    repeat task.wait(0.5) until LPlayer.Character and LPlayer.Character:FindFirstChild("HumanoidRootPart")
    task.wait(3)
    apply()
end)


-- Al cerrar la ventana (X) se apaga todo
table.insert(Hub.OnClose, function()
    pcall(function()
        if Settings then Settings.recordingPath = false end
        if stopGoldCircuit then stopGoldCircuit() end
        if Settings then Settings.GoldVisual = false end
        if updateVisualNodes then updateVisualNodes() end
        local rt = getgenv().__ASTER_RUNTIME
        if type(rt) == "table" then rt.sessionId = (rt.sessionId or 0) + 1 end
    end)
end)
