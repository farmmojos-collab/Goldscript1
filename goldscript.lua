
-- ============================================================
-- CONFIG GENERAL
--   AutoStartRuta : true = al cargar, empieza solo a recorrer la ruta (como tocar "Ruta: ON")
--   AutoStartDelay: segundos de espera antes de arrancar la ruta
-- ============================================================
ASTER_CONFIG = {
    AutoStartRuta = true,
    AutoStartDelay = 6,
}

-- ============================================================
-- 0. BASE / HELPERS
-- ============================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
TweenService = game:GetService("TweenService")
local plr = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
Settings = Settings
Window = Window
httpservice = game:GetService("HttpService")
function getAsterEnv()
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            return env
        end
    end
    error("[ASTER] getgenv() is required")
end

local __ASTER_RUNTIME = getAsterEnv().__ASTER_RUNTIME
if type(__ASTER_RUNTIME) ~= "table" then
    __ASTER_RUNTIME = { connections = {} }
    getAsterEnv().__ASTER_RUNTIME = __ASTER_RUNTIME
elseif type(__ASTER_RUNTIME.connections) ~= "table" then
    __ASTER_RUNTIME.connections = {}
end
__ASTER_RUNTIME.sessionId = (__ASTER_RUNTIME.sessionId or 0) + 1
local CURRENT_SESSION = __ASTER_RUNTIME.sessionId
__ASTER_RUNTIME.tribeCacheLoopStarted = false
__ASTER_RUNTIME.autoDropLoopStarted = false
__ASTER_RUNTIME.waypointDropdownLoopStarted = false
__ASTER_RUNTIME.combatTargetLoopStarted = false
__ASTER_RUNTIME.targetHighlightLoopStarted = false
__ASTER_RUNTIME.pathFinderRefreshStarted = false
__ASTER_RUNTIME.silentAimEngineReady = false
__ASTER_RUNTIME.autoShootLoopStarted = false
__ASTER_RUNTIME.packetIdAutoSyncStarted = false

function getAsterHiddenUI()
    if typeof(__ASTER_RUNTIME.hiddenUI) == "Instance" then
        return __ASTER_RUNTIME.hiddenUI
    end
    local ui
    if type(gethui) == "function" then
        pcall(function() ui = gethui() end)
    end
    if typeof(ui) ~= "Instance" then
        pcall(function() ui = game:GetService("CoreGui") end)
    end
    if typeof(ui) ~= "Instance" then
        local lp = game:GetService("Players").LocalPlayer
        ui = lp and (lp:FindFirstChild("PlayerGui") or lp:WaitForChild("PlayerGui", 2))
    end
    __ASTER_RUNTIME.hiddenUI = ui
    return ui
end

function getWorkspaceResources()
    local f = workspace:FindFirstChild("Resources")
    if f then return f end
    return nil
end

function isRuntimeSessionActive(session)
    local rt = getAsterEnv().__ASTER_RUNTIME
    if type(rt) ~= "table" then return false end
    return session == rt.sessionId
end

function autoDiscoverItemID(itemName)
    if not itemName or itemName == "" then return nil end

    if type(craftNameToID) == "table" then
        local cached = craftNameToID[itemName]
        if cached ~= nil then return cached end
    end

    do
        local Modules = ReplicatedStorage:FindFirstChild("Modules")
        if Modules then
            local ItemIDS = Modules:FindFirstChild("ItemIDS")
            if ItemIDS and ItemIDS:FindFirstChild(itemName) then
                local v = ItemIDS[itemName].Value
                if type(craftNameToID) == "table" then craftNameToID[itemName] = v end
                if type(craftItemIDs) == "table" then craftItemIDs[v] = itemName end
                return v
            end
        end
    end

    local inventoryScan = (type(scanInventoryForItemID) == "function") and scanInventoryForItemID or nil
    local craftScan = (type(scanCraftMenuForItemID) == "function") and scanCraftMenuForItemID or nil

    if inventoryScan then
        local inventoryID = inventoryScan(itemName)
        if inventoryID then
            if type(craftNameToID) == "table" then craftNameToID[itemName] = inventoryID end
            if type(craftItemIDs) == "table" then craftItemIDs[inventoryID] = itemName end
            return inventoryID
        end
    end

    if craftScan then
        local craftMenuID = craftScan(itemName)
        if craftMenuID then
            if type(craftNameToID) == "table" then craftNameToID[itemName] = craftMenuID end
            if type(craftItemIDs) == "table" then craftItemIDs[craftMenuID] = itemName end
            return craftMenuID
        end
    end

    return nil
end

-- Canal de paquetes del juego (equipar, comer, tirar, respawn, fuel)
local ByteNetReliable = ReplicatedStorage:FindFirstChild("ByteNetReliable")
if not ByteNetReliable then
    ByteNetReliable = ReplicatedStorage:WaitForChild("ByteNetReliable", 2)
end
if not ByteNetReliable then
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == "ByteNetReliable" and v:IsA("RemoteEvent") then
            ByteNetReliable = v
            break
        end
    end
end
if not ByteNetReliable then
    task.spawn(function()
        local deadline = tick() + 20
        while not ByteNetReliable and tick() < deadline do
            local found = ReplicatedStorage:FindFirstChild("ByteNetReliable")
            if found then
                ByteNetReliable = found
                break
            end
            task.wait(0.1)
        end
        if ByteNetReliable then return end
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v.Name == "ByteNetReliable" and v:IsA("RemoteEvent") then
                ByteNetReliable = v
                break
            end
        end
    end)
end

-- Deployables / PlantBox cache
function getWorkspaceDeployables()
    local cached = __ASTER_RUNTIME.deployablesFolder
    if cached and cached.Parent then
        return cached
    end
    local f = workspace:FindFirstChild("Deployables")
    if f then
        __ASTER_RUNTIME.deployablesFolder = f
        return f
    end
    return nil
end

function getPlantBoxPartCheap(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    local pp = model.PrimaryPart
    if pp then return pp end
    return model:FindFirstChildWhichIsA("BasePart")
end

_plantBoxItemId = nil
_plantBoxItemIdAt = 0

local function liveIndexDisconnect(prefix)
    local rt = __ASTER_RUNTIME
    if type(rt) ~= "table" then return end
    for _, suffix in ipairs({ "Add", "Rem" }) do
        local key = prefix .. suffix
        local conn = rt[key]
        if conn then
            pcall(function()
                if conn.Disconnect then conn:Disconnect() end
            end)
            rt[key] = nil
        end
    end
end

local function liveIndexAdd(prefix, inst)
    local rt = __ASTER_RUNTIME
    local index, list = rt[prefix .. "Index"], rt[prefix .. "List"]
    if type(index) ~= "table" or type(list) ~= "table" or not inst or index[inst] then return end
    local n = #list + 1
    list[n] = inst
    index[inst] = n
    rt[prefix .. "Gen"] = (rt[prefix .. "Gen"] or 0) + 1
end

local function liveIndexRemove(prefix, inst)
    local rt = __ASTER_RUNTIME
    local index, list = rt[prefix .. "Index"], rt[prefix .. "List"]
    if type(index) ~= "table" or type(list) ~= "table" or not inst then return end
    local i = index[inst]
    if not i then return end
    local n = #list
    local last = list[n]
    list[i] = last
    if last then index[last] = i end
    list[n] = nil
    index[inst] = nil
    rt[prefix .. "Gen"] = (rt[prefix .. "Gen"] or 0) + 1
end

local function ensureLiveFolderIndex(folder, prefix, matchFn)
    local rt = __ASTER_RUNTIME
    if not folder then return nil end
    if rt[prefix .. "Folder"] == folder and type(rt[prefix .. "List"]) == "table" then
        return rt[prefix .. "List"]
    end
    liveIndexDisconnect(prefix)
    rt[prefix .. "Folder"] = folder
    rt[prefix .. "List"] = {}
    rt[prefix .. "Index"] = {}
    rt[prefix .. "Gen"] = (rt[prefix .. "Gen"] or 0) + 1
    rt[prefix .. "Add"] = folder.ChildAdded:Connect(function(ch)
        if matchFn(ch) then liveIndexAdd(prefix, ch) end
    end)
    rt[prefix .. "Rem"] = folder.ChildRemoved:Connect(function(ch)
        liveIndexRemove(prefix, ch)
    end)
    task.spawn(function()
        local kids = folder:GetChildren()
        local i = 1
        local n = #kids
        while i <= n and rt[prefix .. "Folder"] == folder do
            local step = 0
            while step < 50 and i <= n do
                local ch = kids[i]
                if matchFn(ch) then liveIndexAdd(prefix, ch) end
                i = i + 1
                step = step + 1
            end
            task.wait()
        end
        table.clear(kids)
    end)
    return rt[prefix .. "List"]
end

function isPlantBoxNameFast(inst)
    if not inst then return false end
    local n = inst.Name
    return n == "Plant Box" or n == "PlantBox"
end

function getPlantBoxModelsCached()
    local dep = getWorkspaceDeployables()
    if not dep then return nil end
    return ensureLiveFolderIndex(dep, "plantBox", isPlantBoxNameFast)
end

-- Packet IDs (getPacketId / sync)
PACKET_IDS = {}

_packetDataStatic = { packets = PACKET_IDS }

function getPacketId(packetName)
    if not packetName or packetName == "" then return nil end
    local ids = PACKET_IDS or (_packetDataStatic and _packetDataStatic.packets)
    return ids and ids[packetName] or nil
end

local PACKET_IDS_CACHE_PATH = "ASTER/sys/c7/f2a91b.dat"
local PACKET_IDS_CACHE_LEGACY_PATH = "ASTER/Booga/packet_ids.json"
local PACKET_IDS_CACHE_OBFUSCATE_KEY = "A$t3rPk7_v2"
local PACKET_IDS_CACHE_META = {
    lastSync = 0,
    lastSave = 0,
    source = "none",
    changedCount = 0,
}

local function ensurePacketCacheFolder()
    if type(makefolder) ~= "function" then return end
    pcall(function()
        if type(isfolder) == "function" then
            if not isfolder("ASTER") then makefolder("ASTER") end
            if not isfolder("ASTER/sys") then makefolder("ASTER/sys") end
            if not isfolder("ASTER/sys/c7") then makefolder("ASTER/sys/c7") end
        else
            makefolder("ASTER")
            makefolder("ASTER/sys")
            makefolder("ASTER/sys/c7")
        end
    end)
end

local function getPacketHttp()
    return game:GetService("HttpService")
end

local function xorObfuscateString(text, key)
    if type(text) ~= "string" or text == "" then return "" end
    key = key or PACKET_IDS_CACHE_OBFUSCATE_KEY
    local keyLen = #key
    if keyLen < 1 then return text end
    local out = table.create(#text)
    for i = 1, #text do
        out[i] = string.char(bit32.bxor(string.byte(text, i), string.byte(key, ((i - 1) % keyLen) + 1)))
    end
    return table.concat(out)
end

local function encodePacketCacheBlob(jsonText)
    local http = getPacketHttp()
    local xored = xorObfuscateString(jsonText, PACKET_IDS_CACHE_OBFUSCATE_KEY)
    local ok, b64 = pcall(function()
        return http:Base64Encode(xored)
    end)
    if ok and type(b64) == "string" then
        return "AX1:" .. b64
    end

    return "AX0:" .. xored
end

local function decodePacketCacheBlob(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    local http = getPacketHttp()

    if string.sub(raw, 1, 4) == "AX1:" then
        local b64 = string.sub(raw, 5)
        local ok, decoded = pcall(function()
            return http:Base64Decode(b64)
        end)
        if not ok or type(decoded) ~= "string" then return nil end
        return xorObfuscateString(decoded, PACKET_IDS_CACHE_OBFUSCATE_KEY)
    end
    if string.sub(raw, 1, 4) == "AX0:" then
        return xorObfuscateString(string.sub(raw, 5), PACKET_IDS_CACHE_OBFUSCATE_KEY)
    end

    if string.sub(raw, 1, 1) == "{" then
        return raw
    end
    return nil
end

local function tryHidePacketCacheFile(path)

    pcall(function()
        if type(sethiddenfile) == "function" then
            sethiddenfile(path, true)
            return
        end
        if type(isfilehidden) == "function" and type(sethidden) == "function" then
            sethidden(path, true)
            return
        end
    end)
end

local function deleteLegacyPacketCache()
    if type(delfile) ~= "function" or type(isfile) ~= "function" then return end
    pcall(function()
        if isfile(PACKET_IDS_CACHE_LEGACY_PATH) then
            delfile(PACKET_IDS_CACHE_LEGACY_PATH)
        end
    end)
end

local function shallowCopyPacketMap(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for k, v in pairs(src) do
        if type(k) == "string" and type(v) == "number" and v == v and v > 0 then
            out[k] = v
        end
    end
    return out
end

local function packetMapsEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if b[k] ~= v then return false end
    end
    for k, v in pairs(b) do
        if a[k] ~= v then return false end
    end
    return true
end

local function diffPacketMaps(oldMap, newMap)
    local changes = {}
    oldMap = oldMap or {}
    newMap = newMap or {}
    for name, newId in pairs(newMap) do
        local oldId = oldMap[name]
        if oldId ~= newId then
            changes[#changes + 1] = {
                name = name,
                oldId = oldId,
                newId = newId,
            }
        end
    end
    for name, oldId in pairs(oldMap) do
        if newMap[name] == nil then
            changes[#changes + 1] = {
                name = name,
                oldId = oldId,
                newId = nil,
            }
        end
    end
    return changes
end

local function decodePacketCacheTable(raw)
    local jsonText = decodePacketCacheBlob(raw)
    if not jsonText then return nil end
    local ok, decoded = pcall(function()
        return getPacketHttp():JSONDecode(jsonText)
    end)
    if not ok or type(decoded) ~= "table" then
        return nil
    end
    local packets = decoded.packets
    if type(packets) ~= "table" then
        packets = decoded
    end
    local cleaned = shallowCopyPacketMap(packets)
    if next(cleaned) == nil then
        return nil
    end
    return cleaned, decoded
end

function loadPacketIdCache()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return nil
    end

    local function tryPath(path)
        if not isfile(path) then return nil end
        local ok, raw = pcall(readfile, path)
        if not ok or type(raw) ~= "string" then return nil end
        return decodePacketCacheTable(raw)
    end

    local cleaned, decoded = tryPath(PACKET_IDS_CACHE_PATH)
    if cleaned then

        deleteLegacyPacketCache()
        return cleaned, decoded
    end

    cleaned, decoded = tryPath(PACKET_IDS_CACHE_LEGACY_PATH)
    if cleaned then
        deleteLegacyPacketCache()
        return cleaned, decoded
    end

    deleteLegacyPacketCache()
    return nil
end

function savePacketIdCache(packetMap, meta)
    if type(writefile) ~= "function" then
        return false
    end
    ensurePacketCacheFolder()
    local payload = {
        version = 2,
        savedAt = os.time(),
        source = (meta and meta.source) or PACKET_IDS_CACHE_META.source or "live",
        packets = shallowCopyPacketMap(packetMap or PACKET_IDS),
    }
    local ok, jsonText = pcall(function()
        return getPacketHttp():JSONEncode(payload)
    end)
    if not ok or type(jsonText) ~= "string" then
        return false
    end
    local blob = encodePacketCacheBlob(jsonText)
    local writeOk = pcall(function()
        writefile(PACKET_IDS_CACHE_PATH, blob)
    end)
    if writeOk then
        PACKET_IDS_CACHE_META.lastSave = os.clock()
        PACKET_IDS_CACHE_META.source = payload.source
        tryHidePacketCacheFile(PACKET_IDS_CACHE_PATH)
        deleteLegacyPacketCache()
    end
    return writeOk
end

local function applyPacketMap(packetMap, source)
    if type(packetMap) ~= "table" then return 0 end
    local applied = 0
    for name, id in pairs(packetMap) do
        if type(name) == "string" and type(id) == "number" and id == id and id > 0 then
            if PACKET_IDS[name] ~= id then
                PACKET_IDS[name] = id
                applied = applied + 1
            elseif PACKET_IDS[name] == nil then
                PACKET_IDS[name] = id
                applied = applied + 1
            end
        end
    end
    if source then
        PACKET_IDS_CACHE_META.source = source
    end
    return applied
end

local function readPacketObjectId(packetObj)
    if type(packetObj) ~= "table" then return nil end
    for _, key in ipairs({ "id", "Id", "_id", "packetId", "packetID", "ID" }) do
        local v = packetObj[key]
        if type(v) == "number" and v == v and v > 0 then
            return v
        end
    end
    return nil
end

local function tryRequirePacketIDs(modulesFolder)
    local candidates = {}
    local function add(inst)
        if inst then
            table.insert(candidates, inst)
        end
    end

    local byteNet = modulesFolder:FindFirstChild("ByteNet")
    if byteNet then
        local packetsFolder = byteNet:FindFirstChild("packets")
        if packetsFolder then
            add(packetsFolder:FindFirstChild("packetIDs"))
            add(packetsFolder:FindFirstChild("packetIds"))
            add(packetsFolder:FindFirstChild("PacketIDs"))
        end
        add(byteNet:FindFirstChild("packetIDs"))
        add(byteNet:FindFirstChild("packetIds"))
    end
    add(modulesFolder:FindFirstChild("packetIDs"))
    add(modulesFolder:FindFirstChild("packetIds"))

    for _, inst in ipairs(candidates) do
        local ok, result = pcall(require, inst)
        if ok and type(result) == "table" then
            return result, inst:GetFullName()
        end
    end
    return nil, nil
end

local function discoverLivePacketMap()
    local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
        or ReplicatedStorage:WaitForChild("Modules", 10)
    if not modulesFolder then
        return nil, "Modules missing"
    end

    local packetsInst = modulesFolder:FindFirstChild("Packets")
        or modulesFolder:WaitForChild("Packets", 10)
    if not packetsInst then
        return nil, "Packets missing"
    end

    local okPackets, gamePackets = pcall(require, packetsInst)
    if not okPackets or type(gamePackets) ~= "table" then
        return nil, "Packets require failed"
    end

    local live = {}
    local packetIDs = tryRequirePacketIDs(modulesFolder)
    local resolved = {}

    local function applyId(name, id)
        if type(name) ~= "string" or name == "" then return end
        if type(id) ~= "number" or id ~= id or id <= 0 then return end
        if resolved[name] then return end
        resolved[name] = true
        live[name] = id
    end

    for name, packetObj in pairs(gamePackets) do
        local id = readPacketObjectId(packetObj)
        if id then
            applyId(name, id)
        end
    end

    if type(packetIDs) == "table" then
        for name, packetObj in pairs(gamePackets) do
            if type(packetObj) == "table" and not resolved[name] then
                for id, registeredPacket in pairs(packetIDs) do
                    if type(id) == "number" and registeredPacket == packetObj then
                        applyId(name, id)
                        break
                    end
                end
            end
        end
        for id, registeredPacket in ipairs(packetIDs) do
            if type(registeredPacket) == "table" then
                for name, packetObj in pairs(gamePackets) do
                    if packetObj == registeredPacket then
                        applyId(name, id)
                        break
                    end
                end
            end
        end
    end

    if next(live) == nil then
        return nil, "No live packet IDs resolved"
    end
    return live, nil
end

function syncPacketIDs(opts)
    opts = opts or {}
    local silent = opts.silent == true
    local forceSave = opts.forceSave == true

    local before = shallowCopyPacketMap(PACKET_IDS)
    local cacheMap = loadPacketIdCache()

    if opts.loadCache ~= false and cacheMap then
        applyPacketMap(cacheMap, "cache")
    end

    local liveMap, liveErr = discoverLivePacketMap()
    PACKET_IDS_CACHE_META.lastSync = os.clock()

    if not liveMap then
        if not silent then
            warn("[ASTER Packets] Live lookup failed:", liveErr or "unknown", "- using cache only")
        end
        if forceSave or (not cacheMap and next(PACKET_IDS) ~= nil) then
            savePacketIdCache(PACKET_IDS, { source = cacheMap and "cache" or "partial" })
        end
        return false, liveErr
    end

    local changes = diffPacketMaps(before, liveMap)

    local cacheChanges = diffPacketMaps(cacheMap or {}, liveMap)
    applyPacketMap(liveMap, "live")

    local shouldSave = forceSave or not cacheMap or not packetMapsEqual(cacheMap, liveMap)
    if shouldSave then
        savePacketIdCache(liveMap, { source = "live" })
        PACKET_IDS_CACHE_META.changedCount = #cacheChanges
    end

    return true, changes
end

function startPacketIdAutoSync(intervalSec)
    intervalSec = tonumber(intervalSec) or 30
    if intervalSec < 5 then intervalSec = 5 end
    local runtime = getAsterEnv and getAsterEnv().__ASTER_RUNTIME
    if type(runtime) == "table" then
        if runtime.packetIdAutoSyncStarted then return end
        runtime.packetIdAutoSyncStarted = true
    end
    task.spawn(function()
        local session = CURRENT_SESSION

        pcall(function()
            syncPacketIDs({ loadCache = true, silent = false })
        end)
        while true do
            if CURRENT_SESSION ~= session then
                break
            end
            task.wait(intervalSec)
            if CURRENT_SESSION ~= session then
                break
            end
            pcall(function()
                syncPacketIDs({ loadCache = false, silent = true })
            end)
        end
        if type(runtime) == "table" and CURRENT_SESSION ~= session then
            runtime.packetIdAutoSyncStarted = false
        end
    end)
end

task.spawn(function()
    startPacketIdAutoSync(30)
end)

-- ============================================================
-- 1. SETTINGS
-- ============================================================
Settings = {

    GoldCircuitEnabled = false,
    GoldAutoEquip = false,
    GoldHoeType = "Wood Hoe",
    recordedPositions = {},
    recordingPath = false,
    recordInterval = 1.0,
    GoldNoclip = false,
    GoldVisual = false,
    GoldSpeed = 20.9,
    GoldDelay = 0.75,
    GoldDetectRange = 14,
    GoldWaitUntilMined = true,
    GoldMaxWait = 20,
    MaxSlopeEnabled = false,
    WaterTweenEnabled = false,

    HealCPS = 80,
    AutoEatEnabled = false,
    EatThreshold = 99,
    EatFruit = "Bloodfruit",
    WasteFruit = "Bloodfruit",
    FruitsCapAmount = 100,
    WasteFruitsEnabled = false,
    EatCap = 100,
    EatCapEnabled = false,

    AutoDropEnabled = false,
    DropItem = "",
    DropAmount = "Infinite",
    PickupRange = 50,
    PickupDelay = 0.01,

    AutoFuelEnabled = false,
    FuelType = "All (Wood/Log/Leaves)",
    FuelThreshold = 200,

    TweenToPlantBox = false,
    TweenToBush = false,
    TweenToBushAndBox = false,

    AutoRespawnEnabled = false,

    recordInterval = 1.0,
    maxWalkAttemptTime = 2,
    WalkSpeedEnabled = false,
    WalkSpeed = 16,
    HipHeight = 2,

    GoldNoclip = false,
    GoldCircuitEnabled = false,
    GoldVisual = false,
    GoldDelay = 0.75,
    WaterTweenEnabled = false,
    recordedPositions = {},
    GoldSpeed = 21,
}

-- ============================================================
-- 2. PERSONAJE / COLISIONES / RAYCAST (usado por Gold & Paths)
-- ============================================================

rs = ReplicatedStorage
char = plr.Character
root = char and char:FindFirstChild("HumanoidRootPart")
hum = char and char:FindFirstChild("Humanoid")
runs = game:GetService("RunService")
httpservice = game:GetService("HttpService")

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

function resetCharacterPhysics()
    local character = plr.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local cbv = hrp:FindFirstChild("CircuitBodyVelocity")
        if cbv then cbv:Destroy() end
        local pbg = hrp:FindFirstChild("CircuitBodyGyro")
        if pbg then pbg:Destroy() end
        local pbv = hrp:FindFirstChild("PlantBodyVelocity")
        if pbv then pbv:Destroy() end
        local pgy = hrp:FindFirstChild("PlantBodyGyro")
        if pgy then pgy:Destroy() end
        hrp.Velocity = Vector3.new(0,0,0)
        hrp.RotVelocity = Vector3.new(0,0,0)
    end
end

if char then
    resetCharacterPhysics()
    captureCollisionState()
end

function onCharacterAdded(newChar)
    char = newChar
    root = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    if hum then hum.MaxSlopeAngle = Settings.MaxSlopeEnabled and 89 or 50 end
    captureCollisionState()
end

plr.CharacterAdded:Connect(onCharacterAdded)

function getlayout(name)
    if not name or name == "" then return nil end
    local mainGui = plr.PlayerGui:FindFirstChild("MainGui")
    if not mainGui then return nil end
    local right = mainGui:FindFirstChild("RightPanel")
    local inv = right and right:FindFirstChild("Inventory")
    local list = inv and inv:FindFirstChild("List")
    if not list then return nil end
    local lowerTarget = string.lower((tostring(name):match("^%s*(.-)%s*$") or ""))
    if lowerTarget == "" then return nil end
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("GuiObject") then
            local cn = string.lower((tostring(child.Name):match("^%s*(.-)%s*$") or ""))
            if cn == lowerTarget then
                return child.LayoutOrder
            end
        end
    end
    return nil
end

isTweening = false

rayParams = RaycastParams.new()

function updateRayParams()
    if plr.Character then rayParams.FilterDescendantsInstances = {plr.Character} end
end

plr.CharacterAdded:Connect(updateRayParams)

if plr.Character then updateRayParams() end

maxWalkAttemptTime = 3

-- ============================================================
-- 3. HEAL FRUITS / INVENTORY SCAN
-- ============================================================
craftItemIDs = craftItemIDs or {}
craftNameToID = craftNameToID or {}

-- Tabla nombre <-> ID de items (desde el modulo ItemIDS del juego)
do
    local itemIdModuleObj = ReplicatedStorage:FindFirstChild("Modules")
        and ReplicatedStorage.Modules:FindFirstChild("ItemIDS")

    local ok, ItemIDSModule = pcall(function()
        if itemIdModuleObj then
            return require(itemIdModuleObj)
        end
        return require(ReplicatedStorage:WaitForChild("Modules", 2):WaitForChild("ItemIDS", 2))
    end)

    if not ok or type(ItemIDSModule) ~= "table" then
        ItemIDSModule = {}
    end

    local isNameToID = false
    for k, v in pairs(ItemIDSModule) do
        if type(k) == "string" and type(v) == "number" then
            isNameToID = true
            break
        end
    end

    if isNameToID then
        for name, id in pairs(ItemIDSModule) do
            craftNameToID[name] = id
            craftItemIDs[id] = name
        end
    else
        for id, name in pairs(ItemIDSModule) do
            craftItemIDs[id] = name
            craftNameToID[name] = id
        end
    end
end
function scanInventoryForItemID(itemName)
    local mainGui = plr.PlayerGui:FindFirstChild("MainGui")
    if not mainGui then return nil end
    local rightPanel = mainGui:FindFirstChild("RightPanel")
    if not rightPanel then return nil end
    local invFrame = rightPanel:FindFirstChild("Inventory")
    if not invFrame then return nil end
    local inventory = invFrame:FindFirstChild("List")
    if not inventory then return nil end
    for _, item in ipairs(inventory:GetChildren()) do
        if item:IsA("ImageLabel") and item.Name == itemName then
            local itemID = item:GetAttribute("ItemID") or item:GetAttribute("itemID")
            if not itemID then
                for _, child in ipairs(item:GetChildren()) do
                    if child:IsA("IntValue") or child:IsA("NumberValue") then
                        itemID = child.Value
                        break
                    end
                end
            end
            return itemID
        end
    end
    return nil
end

function scanCraftMenuForItemID(itemName)
    local mainGui = plr.PlayerGui:FindFirstChild("MainGui")
    if not mainGui then return nil end
    local leftPanel = mainGui:FindFirstChild("LeftPanel")
    local craftMenuPaths = {
        mainGui:FindFirstChild("CraftingMenu"),
        mainGui:FindFirstChild("Crafting"),
        mainGui:FindFirstChild("Craft"),
        leftPanel and leftPanel:FindFirstChild("Crafting") or nil,
    }
    for _, menu in ipairs(craftMenuPaths) do
        if menu then
            for _, item in ipairs(menu:GetDescendants()) do
                if item:IsA("TextLabel") or item:IsA("TextButton") then
                    if item.Text == itemName or item.Name == itemName then
                        local parent = item.Parent
                        local itemID = parent and (parent:GetAttribute("ItemID") or parent:GetAttribute("itemID") or parent:GetAttribute("ID")) or nil
                        if itemID then return itemID end
                    end
                end
            end
        end
    end
    return nil
end

ALL_HEAL_FRUIT_NAMES = ALL_HEAL_FRUIT_NAMES or {
    "Apple", "Banana", "Barley", "Berry", "Bloodfruit", "Bluefruit", "Blossom",
    "Carrot", "Cloudberry", "Coconut", "Corn", "Cooked Meat", "Frostfruit",
    "Jelly", "Lemon", "Mango", "Oddberry", "Orange", "Prickly Pear", "Pumpkin",
    "Strangefruit", "Strawberry", "Sunfruit", "Watermelon",
}

fruittoitemid = {}

for _, fruitName in ipairs(ALL_HEAL_FRUIT_NAMES) do
    local id = autoDiscoverItemID(fruitName)
    if id == nil and craftNameToID then
        id = craftNameToID[fruitName]
    end
    fruittoitemid[fruitName] = (id ~= nil) and id or false
end

if craftNameToID then
    for name, _ in pairs(fruittoitemid) do
        if craftNameToID[name] then
            fruittoitemid[name] = craftNameToID[name]
        end
    end
end

do
    local _fuelMap = {
        ["Wood"] = autoDiscoverItemID("Wood"),
        ["Log"] = autoDiscoverItemID("Log"),
        ["Leaves"] = autoDiscoverItemID("Leaves"),
        ["Coal"] = autoDiscoverItemID("Coal"),
    }

    getAsterEnv()["fueltoitemid"] = _fuelMap
    fueltoitemid = _fuelMap
    fueltoitemid = _fuelMap

    if craftNameToID then
        for name, _ in pairs(_fuelMap) do
            if craftNameToID[name] then
                _fuelMap[name] = craftNameToID[name]
            end
        end
    end
end

healFruitData = fruittoitemid

TweenService = game:GetService("TweenService")

-- ============================================================
-- 4. GOLD AUTOTOOL EQUIP + SELECT HOE
-- ============================================================
do
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

local goldEquipActive = false

local function findNearbyPlantBox(hrp, range)
    range = range or 25
    if not hrp then return false end
    local rangeSq = range * range
    local hrpPos = hrp.Position
    local boxes = getPlantBoxModelsCached()
    if boxes then
        for i = 1, #boxes do
            local model = boxes[i]
            if model and model.Parent then
                local part = getPlantBoxPartCheap(model)
                if part then
                    local d = hrpPos - part.Position
                    if (d.X * d.X + d.Y * d.Y + d.Z * d.Z) <= rangeSq then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function startGoldEquipManager()
    if goldEquipActive then return end
    if not Settings.GoldAutoEquip then return end
    goldEquipActive = true
    task.spawn(function()
        local HOE_RANGE = 30
        while Settings.GoldAutoEquip and not ScriptKilled do
            pcall(function()
                local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local nearby = findNearbyPlantBox(hrp, HOE_RANGE)
                if nearby then
                    local hoeName = Settings.GoldHoeType or "Wood Hoe"
                    if not isToolEquipped(hoeName) then
                        equipItemPacket(hoeName)
                        task.wait(0.35)
                    end
                else
                    local pickName = "God Pick"
                    if not isToolEquipped(pickName) then
                        equipItemPacket(pickName)
                        task.wait(0.35)
                    end
                end
            end)
            task.wait(0.4)
        end
        goldEquipActive = false
    end)
end

end

-- ============================================================
-- 5. MINE AURA
-- ============================================================
task.spawn(function()

local CONFIG = {
	Range = 18,
	ScanScale = 3.5,
	MaxTargets = 2,
	SwingDelay = 0.02,
	StartEnabled = true,
	Targets = { "Critters", "Resources" },
	FaceTarget = false,
	SwingAnimation = false,
	Toggle = Enum.KeyCode.X,
}

if not game:IsLoaded() then game.Loaded:Wait() end

local cloneref = cloneref or function(x) return x end
local Players = cloneref(game:GetService("Players"))
local RS = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))
local UIS = cloneref(game:GetService("UserInputService"))
local CollectionService = cloneref(game:GetService("CollectionService"))

if getgenv().MineAuraStop then getgenv().MineAuraStop() end

repeat task.wait() until RS:FindFirstChild("GameLoaded")

local lp = Players.LocalPlayer
local gameFolder = RS:WaitForChild("Game")
local Packets = require(RS.Modules.Packets)
local GameUtil = require(RS.Modules.GameUtil)
local ItemData = require(RS.Modules.ItemData)
local Clock = require(RS.Modules.Clock)
local animations = require(gameFolder.animations)
local statusEffects = require(gameFolder.classes.statusEffects)

local toolTypes = {}
for _, m in ipairs(gameFolder:WaitForChild("tool"):GetChildren()) do
	local ok, mod = pcall(require, m)
	if ok then toolTypes[m.Name] = mod end
end

local weapons = { "Rock", "War Hammer", "Mace", "Club", "Battle Axe", "Crystal Stick", "God Rock", "Emerald Blade" }

local enabled = false
local lastSwing = 0
local lastScan = 0
local valid, checked = {}, {}
local isPlayingHit = false
local hitAnim1, hitAnim2

local function char() return lp.Character end
local function hrp() local c = char() return c and c:FindFirstChild("HumanoidRootPart") end

local function firepacket(name, ...)
	if not Packets[name] then return false end
	local ok, err = pcall(Packets[name].send, ...)
	if not ok then warn("packet failed:", name, err) end
	return ok
end

local function wants(name)
	return table.find(CONFIG.Targets, name) ~= nil
end

local function getTool()
	local c = char()
	if not c then return nil end
	local tools = c:FindFirstChild("Tools")
	if not tools then return nil end
	for _, t in ipairs(tools:GetChildren()) do
		if t:IsA("Model") and (table.find(weapons, t.Name) or t.Name:find("Axe") or t.Name:find("Pick")) then
			return t
		end
	end
end

local function scan()
	table.clear(valid)
	table.clear(checked)
	local c, root = char(), hrp()
	if not c or not root then return end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { c, workspace.Players, workspace.Terrain, workspace.Items }
	for _, o in ipairs(CollectionService:GetTagged("Contents")) do table.insert(ignore, o) end
	params.FilterDescendantsInstances = ignore

	local s = CONFIG.Range * CONFIG.ScanScale
	local parts = workspace:GetPartBoundsInBox(c:GetPivot(), Vector3.new(s, s, s), params)

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		if model and not checked[model] and model.Parent then
			local ok = false
			if wants("Resources") then
				local n = model.Name
				ok = model.Parent == workspace.Resources or model.Parent == workspace.Mounds
					or n == "Gold Node" or n == "Iron Node" or n == "Coal Node" or n == "Meteor Core"
					or n == "Crystal Meteor Core" or n == "Crystal Meteor Rock" or n == "Magnetite Meteor Rock"
					or n == "Small Rock" or n == "Meteor Rock"
			end
			if not ok and wants("Critters") then ok = model.Parent == workspace.Critters end
			if not ok and wants("Deployables") then ok = model.Parent == workspace.Deployables end
			if not ok and wants("Rubble") then ok = model.Parent == workspace.Rubble end
			if ok then
				checked[model] = true
				valid[#valid + 1] = model
			end
		end
	end
end

local function nearest()
	local root = hrp()
	if not root then return end
	local best, bestDist = nil, CONFIG.Range
	for _, m in ipairs(valid) do
		if m and m.Parent then
			local d = (m:GetPivot().Position - root.Position).Magnitude
			if d <= bestDist then best, bestDist = m, d end
		end
	end
	return best
end

local function playSwing()
	task.spawn(function()
		local data = ItemData[GameUtil.Data.toolbar[GameUtil.Data.equipped].name]
		if not data or not data.useType or not toolTypes[data.useType] then return end
		animations.stopCustomAnimations()
		local speed = data.speed
		if not speed then return end
		if statusEffects.playerHasEffect("Haste") and (data.toolType == "Axe" or data.toolType == "Pick") then
			speed -= speed * 0.1
		end
		local now = Clock.getServerTime(true)
		if speed <= now - GameUtil.Data.lastToolUse then
			GameUtil.Data.lastToolUse = now
			if isPlayingHit then
				if hitAnim1 then hitAnim1:Stop() hitAnim1 = nil end
				isPlayingHit = false
				hitAnim2 = animations.playAnimation("LSlash")
			else
				if hitAnim2 then hitAnim2:Stop() hitAnim2 = nil end
				isPlayingHit = true
				hitAnim1 = animations.playAnimation("Slash")
			end
		end
	end)
end

local function swing(target)
	if tick() - lastSwing < CONFIG.SwingDelay then return end
	if CONFIG.SwingAnimation then playSwing() end

	local ids, seen = {}, {}
	local function add(model)
		if not model or not model.Parent then return end
		local id = model:GetAttribute("EntityID")
		if not id then
			for _, d in ipairs(model:GetDescendants()) do
				id = d:GetAttribute("EntityID")
				if id then break end
			end
		end
		if id and not seen[id] then
			seen[id] = true
			ids[#ids + 1] = { entityID = id }
		end
	end

	local root = hrp()
	local list = {}
	for _, m in ipairs(valid) do
		if m and m.Parent then
			list[#list + 1] = { m = m, d = (m:GetPivot().Position - root.Position).Magnitude }
		end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	for i = 1, math.min(CONFIG.MaxTargets, #list) do
		add(list[i].m)
	end
	if #ids == 0 then return end

	lastSwing = tick()
	firepacket("SwingTool", {
		entityIDs = ids,
		cframe = char():GetPivot(),
		timestamp = Clock.getServerTime(true),
	})
end

local conn = RunService.Heartbeat:Connect(function()
	if not enabled then return end
	local c, root = char(), hrp()
	if not c or not root then return end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if not lp:GetAttribute("hasSpawned") then return end
	if not getTool() then return end

	if tick() - lastScan >= 0.1 then
		lastScan = tick()
		scan()
	end

	local target = nearest()
	if not target then return end

	if CONFIG.FaceTarget then
		local p = target:GetPivot().Position
		c:PivotTo(CFrame.lookAt(root.Position, Vector3.new(p.X, root.Position.Y, p.Z)))
	end
	swing(target)
end)

local function setEnabled(v)
	enabled = v
	__ASTER_RUNTIME.MineAuraEnabled = v

	pcall(function()
		local reg = Window.ElementRegistry["Mine Aura"]
		if reg and reg.SetValue then reg.SetValue(v) end
	end)
end
__ASTER_RUNTIME.MineAuraSet = setEnabled

local startValue = __ASTER_RUNTIME.MineAuraEnabled
if startValue == nil then startValue = CONFIG.StartEnabled end
setEnabled(startValue)

local keyConn = UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.Toggle then setEnabled(not enabled) end
end)

getgenv().MineAuraStop = function()
	enabled = false
	conn:Disconnect()
	keyConn:Disconnect()
	__ASTER_RUNTIME.MineAuraSet = nil
	getgenv().MineAuraStop = nil
end
end)

-- ============================================================
-- 6. FARM
-- ============================================================
__ASTER_RUNTIME.FarmLists = {
	FRUITS = { "Berry","Oddberry","Cloudberry","Bluefruit","Bloodfruit","Strawberry","Sunfruit","Strangefruit","Petrified Berry","Jelly","Frostfruit","Blossom","Banana","Apple","Lemon","Orange","Mango","Watermelon","Pumpkin","Pumpkins","Prickly Pear","Carrot","Carrots","Corn","Barley","Coconut" },
	ITEMS = { "All","Essence","Coin","Coin2","Coin Stack","Wood","Stone","Coal","Iron","Gold","Adurite","Magnetite","Emerald","Pink Diamond","Obsidian","Crystal Chunk","Spirit Key","Void Shard","Hide","Fire Hide","Leaves","Log","Sand","Glass","Scute","Lead","Cogs","Ice Cube","Raw Gold","Raw Iron","Raw Adurite","Raw Emerald","Raw Magnetite","Raw Pink Diamond","Steel","Steel Mix","Berry","Oddberry","Cloudberry","Bluefruit","Bloodfruit","Strawberry","Sunfruit","Strangefruit","Petrified Berry","Frostfruit","Blossom","Banana","Apple","Lemon","Orange","Mango","Watermelon","Pumpkin","Pumpkins","Carrot","Carrots","Corn","Barley","Coconut","Jelly","Egg","Eggs","Raw Meat","Raw Fish","Raw Morsel","Raw Crab","Raw Squid","Raw Eel","Raw Baracuda","Cooked Meat","Cooked Fish","Cooked Morsel","Cooked Crab","Cooked Squid","Cooked Eel","Cooked Baracuda","Cooked Egg","Bread","Pie","Fruit Cake","Cornbread","Fried Egg","Fried Cactus","Jelly Sandwich","Meat Sandwich","Cookies","Peppermints","Poison Potion","Splash Poison Potion","Swiftness Potion","Splash Swiftness Potion","Phantasm Potion","Splash Phantasm Potion","Haste Potion","Splash Haste Potion","Fire Resistance Potion","Splash Fire Resistance Potion","Strength Potion","Splash Strength Potion","Healing Potion","Splash Healing Potion","Harming Potion","Splash Harming Potion","Placebo Potion","Splash Placebo Potion" },
}
__ASTER_RUNTIME.FarmCfg = {
	-- Auto Farm (plantar / cosechar)
	AutoHarvest   = true,
	AutoPlant     = true,
	AutoMove      = false,   -- te mueve (teletransporte suave) hacia la siguiente caja/planta
	MoveSpeed     = 17,      -- studs/s (máx. del original: 17)
	FarmRange     = 125,     -- radio de búsqueda de cajas y plantas (original: 125)
	CacheInterval = 3,       -- cada cuántos segundos vuelve a buscar cajas y plantas
	ActionRange   = 25,      -- distancia a la que interactúa con caja/planta (original: 25)
	ActionDelay   = 0.05,    -- segundos entre tandas de plantar/cosechar (antes 0.1)
	ActionsPerTick = 3,      -- cuantas cajas/plantas procesa por tanda (antes 1)
	PlantCooldown = 0.6,     -- no vuelve a plantar la misma caja hasta que pase este tiempo
	PlantItems    = { "Bluefruit" },  -- semillas a plantar (se rotan si hay varias)

	-- Pickup Aura (recoger ítems del suelo)
	AutoPickup     = true,
	PickupRange    = 25,     -- studs (original: 5)
	PickupDelay    = 0,      -- segundos entre recogidas (original: 0)
	PickupTargets  = { "Gold" },  -- "All" o nombres de ítems: { "Wood", "Stone" }
	PickupChests   = true,   -- también recoger ítems dentro de cofres
	ScanInterval   = 0.25,   -- cada cuántos segundos busca ítems cercanos
}

-- ===== FARM: Auto Plant / Auto Harvest / Pickup Aura (se controla desde el menú Automation) =====
task.spawn(function()
-- Auto Plant + Auto Harvest + Pickup Aura independientes (extraído/reescrito de tu script Boo Hub)
-- NO PROBADO en el juego: si falla, mira la consola (F9) y pásame el error.
-- Los valores se pueden cambiar en vivo desde el executor, por ejemplo:
--   getgenv().FarmCfg.AutoPlant = false
--   getgenv().FarmCfg.PickupRange = 15
-- Para detenerlo por completo:  getgenv().FarmStop()
-- Los controles están en el menú: pestaña Automation > "Farm".

local CFG = __ASTER_RUNTIME.FarmCfg

if not game:IsLoaded() then game.Loaded:Wait() end

local cloneref = cloneref or function(x) return x end
local Players = cloneref(game:GetService("Players"))
local RS = cloneref(game:GetService("ReplicatedStorage"))
local CollectionService = cloneref(game:GetService("CollectionService"))
local Workspace = cloneref(game:GetService("Workspace"))

if getgenv().FarmStop then getgenv().FarmStop() end
getgenv().FarmCfg = CFG

repeat task.wait() until RS:FindFirstChild("GameLoaded")

local lp = Players.LocalPlayer
local Packets = require(RS.Modules.Packets)
local ItemIDS = require(RS.Modules.ItemIDS)
local okFn, functions = pcall(function() return require(RS.Game.functions) end)
if not okFn then functions = nil end

local running = true

local function char() return lp.Character end
local function hrp()
	local c = char()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function firepacket(name, ...)
	if not Packets[name] then return false end
	local ok, err = pcall(Packets[name].send, ...)
	if not ok then warn("[Farm] packet falló:", name, err) end
	return ok
end

local function toList(v)
	if type(v) == "string" then return { v } end
	if type(v) == "table" then return v end
	return {}
end

----------------------------------------------------------------------
-- Inventario (se lee de la interfaz, igual que el original)
----------------------------------------------------------------------
local inventory = {}
local function updateInventory()
	table.clear(inventory)
	pcall(function()
		local list = lp.PlayerGui.MainGui.RightPanel.Inventory.List
		for _, o in ipairs(list:GetChildren()) do
			if o:IsA("GuiObject") then inventory[o.Name] = o.LayoutOrder end
		end
	end)
end

local function availablePlantItems()
	local out = {}
	for _, name in ipairs(toList(CFG.PlantItems)) do
		if ItemIDS[name] and inventory[name] then table.insert(out, name) end
	end
	return out
end

----------------------------------------------------------------------
-- Auto Farm: caché de cajas de plantar y plantas
----------------------------------------------------------------------
local plantboxes, plants = {}, {}
local lastCache = 0
local lastAction = 0
local plantIndex = 0
local lastMove = tick()

local function refreshTable(list, isBox)
	local root = hrp()
	if not root then return end
	for i = #list, 1, -1 do
		local entry = list[i]
		local model = entry.Model
		if not model or not model.Parent then
			table.remove(list, i)
		else
			local pos
			if isBox then
				local cb = model:FindFirstChild("collisionBox")
				if not cb or model:FindFirstChild("Seed") then
					table.remove(list, i)
					continue
				end
				pos = cb.Position
			else
				pos = model:GetPivot().Position
			end
			entry.Position = pos
			entry.Distance = (pos - root.Position).Magnitude
			if entry.Distance > CFG.FarmRange then table.remove(list, i) end
		end
	end
	table.sort(list, function(a, b) return a.Distance < b.Distance end)
end

local function cacheFarm()
	lastCache = tick()
	table.clear(plantboxes)
	table.clear(plants)
	local c, root = char(), hrp()
	if not c or not root then return end

	local canPlant = #availablePlantItems() > 0

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = { c, Workspace.Terrain, Workspace.Items, Workspace.Rubble, Workspace.Resources, Workspace.Players }
	for _, t in ipairs(CollectionService:GetTagged("Contents")) do table.insert(filter, t) end
	params.FilterDescendantsInstances = filter

	local hip = 0
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then hip = hum.HipHeight end
	local center = CFrame.new(c:GetPivot().Position) - (Vector3.new(0, hip, 0) + Vector3.new(0, 2, 0))
	local size = Vector3.new(CFG.FarmRange * 2, 15, CFG.FarmRange * 2)
	local parts = Workspace:GetPartBoundsInBox(center, size, params)

	local seenBox, seenPlant = {}, {}
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		if not model then continue end

		-- cajas de plantar
		if CFG.AutoPlant and canPlant and model.Parent == Workspace.Deployables then
			if model.Name == "Plant Box" and model:FindFirstChild("collisionBox")
				and not model:FindFirstChild("Seed") and not seenBox[model] then
				local pos = model.collisionBox.Position
				local dist = (pos - root.Position).Magnitude
				if dist <= CFG.FarmRange then
					seenBox[model] = true
					table.insert(plantboxes, { Model = model, Position = pos, Distance = dist })
				end
			end
		end

		-- plantas para cosechar
		if CFG.AutoHarvest and not seenPlant[model]
			and model.Parent ~= Workspace.Resources and model.Parent ~= Workspace.Critters
			and model.Parent ~= Workspace.Deployables and model.Parent ~= Workspace.Rubble
			and model.Name ~= "Plant Box" then
			local lname = string.lower(model.Name)
			if lname:find("bush", 1, true) or lname:find("tree", 1, true)
				or lname:find("crop", 1, true) or lname:find("cacti", 1, true) then
				if model:GetAttribute("size") ~= "massive" then
					local pos = model:GetPivot().Position
					local dist = (pos - root.Position).Magnitude
					if dist <= CFG.FarmRange then
						seenPlant[model] = true
						table.insert(plants, { Model = model, Position = pos, Distance = dist })
					end
				end
			end
		end
	end

	refreshTable(plantboxes, true)
	refreshTable(plants, false)
end

local recentlyPlanted = {}

local function doHarvest(root, maxActions)
	maxActions = maxActions or 1
	local done = 0
	local remove = {}
	for i = 1, #plants do
		if done >= maxActions then break end
		local p = plants[i]
		local model = p and p.Model
		if model and model.Parent then
			if (model:GetPivot().Position - root.Position).Magnitude <= CFG.ActionRange then
				firepacket("Pickup", model:GetAttribute("EntityID"))
				remove[#remove + 1] = i
				done = done + 1
			end
		else
			remove[#remove + 1] = i
		end
	end
	for k = #remove, 1, -1 do table.remove(plants, remove[k]) end
	return #remove > 0
end

local function doPlant(root, maxActions)
	maxActions = maxActions or 1
	local items = availablePlantItems()
	if #items == 0 then return false end
	local now = tick()
	local done = 0
	local remove = {}
	for i = 1, #plantboxes do
		if done >= maxActions then break end
		local b = plantboxes[i]
		local model = b and b.Model
		local cb = model and model.Parent and model:FindFirstChild("collisionBox")
		if not cb or model:FindFirstChild("Seed") then
			remove[#remove + 1] = i
		elseif (cb.Position - root.Position).Magnitude <= CFG.ActionRange then
			local last = recentlyPlanted[model]
			if not last or now - last > (CFG.PlantCooldown or 0.6) then
				plantIndex = plantIndex + 1
				if plantIndex > #items then plantIndex = 1 end
				firepacket("InteractStructure", {
					entityID = model:GetAttribute("EntityID"),
					itemID = ItemIDS[items[plantIndex]],
				})
				recentlyPlanted[model] = now
				done = done + 1
			end
		end
	end
	for k = #remove, 1, -1 do table.remove(plantboxes, remove[k]) end
	for m, tt in pairs(recentlyPlanted) do
		if not m.Parent or now - tt > 5 then recentlyPlanted[m] = nil end
	end
	return done > 0 or #remove > 0
end

local function doMove(root)
	local pos
	if CFG.AutoPlant and plantboxes[1] and plantboxes[1].Model and plantboxes[1].Model.Parent then
		local cb = plantboxes[1].Model:FindFirstChild("collisionBox")
		if cb then pos = cb.Position end
	end
	if not pos and CFG.AutoHarvest and plants[1] and plants[1].Model and plants[1].Model.Parent then
		pos = plants[1].Model:GetPivot().Position
	end
	if not pos then
		lastMove = tick()
		return
	end
	local goal = pos + Vector3.new(0, 3, 0)
	local delta = goal - root.Position
	local mag = delta.Magnitude
	local now = tick()
	if mag > 0.1 then
		local step = math.min(CFG.MoveSpeed * math.clamp(now - lastMove, 0, 1 / 30), mag)
		local rot = root.CFrame - root.CFrame.Position
		root.CFrame = CFrame.new(root.Position + delta.Unit * step) * rot
	else
		root.CFrame = CFrame.new(goal) * (root.CFrame - root.CFrame.Position)
	end
	lastMove = now
end

----------------------------------------------------------------------
-- Pickup Aura
----------------------------------------------------------------------
local validItems = {}
local lastScan = 0
local lastPickup = 0
local recentlyPicked = {}

local function scanItems()
	lastScan = tick()
	table.clear(validItems)
	local c, root = char(), hrp()
	if not c or not root then return end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.MaxParts = 1000
	params.FilterDescendantsInstances = { c, Workspace.Players, Workspace.Terrain, Workspace.Resources, Workspace.Critters, Workspace.Rubble }

	local parts = Workspace:GetPartBoundsInBox(c:GetPivot(), Vector3.new(50, 50, 50), params)
	local seen = {}
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorWhichIsA("Model")
		local item
		if part.Parent == Workspace.Items then
			item = part
		elseif model and model.Parent == Workspace.Items then
			item = model
		elseif CFG.PickupChests then
			local contents = part:FindFirstAncestor("Contents")
			if contents then
				if part.Parent == contents then
					item = part
				elseif model and model.Parent == contents then
					item = model
				end
			end
		end
		if item and item.Parent and not seen[item] then
			seen[item] = true
			table.insert(validItems, item)
		end
	end
end

local function doPickup(root)
	local targets = {}
	for _, n in ipairs(toList(CFG.PickupTargets)) do targets[n] = true end
	local now = tick()
	for _, item in ipairs(validItems) do
		if item.Parent then
			local dist = (root.Position - item:GetPivot().Position).Magnitude
			if dist < CFG.PickupRange and (targets.All or targets[item.Name]) then
				local last = recentlyPicked[item]
				if (not last or now - last > 0.3) and CFG.PickupDelay < now - lastPickup then
					local canBear = true
					if functions and functions.canBearLoad then
						local ok, res = pcall(functions.canBearLoad, item)
						if ok then canBear = res end
					end
					if canBear then
						firepacket("Pickup", item:GetAttribute("EntityID"))
						recentlyPicked[item] = now
						lastPickup = now
					end
				end
			end
		end
	end
	-- limpieza del registro de ítems ya recogidos
	for item, t in pairs(recentlyPicked) do
		if not item.Parent or now - t > 5 then recentlyPicked[item] = nil end
	end
end

----------------------------------------------------------------------
-- Bucle principal
----------------------------------------------------------------------
task.spawn(function()
	while running do
		local root = hrp()
		local hum = char() and char():FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local now = tick()
			local farming = CFG.AutoPlant or CFG.AutoHarvest

			if farming then
				if now - lastCache >= CFG.CacheInterval then
					updateInventory()
					cacheFarm()
				end
				if CFG.AutoMove then doMove(root) end
				if now - lastAction >= CFG.ActionDelay then
					local did = false
					local batch = math.max(1, math.floor(tonumber(CFG.ActionsPerTick) or 1))
					if CFG.AutoHarvest then did = doHarvest(root, batch) end
					if CFG.AutoPlant then did = doPlant(root, batch) or did end
					if did then lastAction = now end
				end
			end

			if CFG.AutoPickup then
				if now - lastScan >= CFG.ScanInterval then scanItems() end
				doPickup(root)
			end
		end
		task.wait()
	end
end)

getgenv().FarmStop = function()
	running = false
	getgenv().FarmStop = nil
end

print("[Farm] cargado: AutoPlant=" .. tostring(CFG.AutoPlant) .. " AutoHarvest=" .. tostring(CFG.AutoHarvest) .. " AutoPickup=" .. tostring(CFG.AutoPickup))
end)

-- ============================================================
-- 7. AUTO EAT + WASTE FRUITS
-- ============================================================
do
autoHitSelection = "SwingHit"

end
do

local RunService = game:GetService("RunService")

function resolveHealFruitItemId(fruitName)
    if not fruitName or fruitName == "" then return nil end
    local cached = healFruitData[fruitName]
    if cached == false then cached = nil end
    if type(cached) == "number" and cached > 0 then return cached end
    local id = autoDiscoverItemID(fruitName)
    if id == nil and craftNameToID then
        id = craftNameToID[fruitName]
    end
    if type(id) == "number" and id > 0 then
        healFruitData[fruitName] = id
        return id
    end
    return nil
end

end
do

end
do

end
do
function getInventorySlotAndCount(itemName)
    local mainGui = plr.PlayerGui:FindFirstChild("MainGui")
    if not mainGui then return nil, nil end
    local inventory = mainGui.RightPanel and mainGui.RightPanel.Inventory and mainGui.RightPanel.Inventory.List
    if not inventory then return nil, nil end
    local item = inventory:FindFirstChild(itemName)
    if item then
        local slotID = item.LayoutOrder
        local count = 0
        local qtyImage = item:FindFirstChild("QuantityImage")
        if qtyImage then
            local qtyText = qtyImage:FindFirstChild("QuantityText")
            if qtyText and qtyText.Text ~= "" then
                local clean = qtyText.Text:gsub("%D", "")
                count = tonumber(clean) or 0
            end
        end
        if count == 0 then
             local attrCount = item:GetAttribute("Count") or item:GetAttribute("Amount")
             if attrCount then count = attrCount end
        end
        return slotID, count
    end
    return nil, nil
end

function eatDownToCap(fruitName, cap)
    local fruitID = resolveHealFruitItemId(fruitName)
    if not fruitID then return end
    cap = tonumber(cap) or 0
    local slotID, count = getInventorySlotAndCount(fruitName)

    if slotID and count then
        if count > cap then
            local toEat = count - cap
            if toEat > 20 then toEat = 20 end
            for i = 1, toEat do
                if not (Settings.WasteFruitsEnabled or Settings.EatCapEnabled) then break end
                pcall(function()
                    local actionId = getPacketId("UseBagItem")
                    local b = buffer.create(8)
                    buffer.writeu8(b, 0, 0)
                    buffer.writeu8(b, 1, actionId)
                    buffer.writeu32(b, 2, slotID)
                    buffer.writeu16(b, 6, fruitID)
                    if ByteNetReliable then ByteNetReliable:FireServer(b) end
                end)
                task.wait(0.25)
            end
        end
    end
end

function startEatCap()
    task.spawn(function()
        while Settings.WasteFruitsEnabled or Settings.EatCapEnabled do
            local wasteFruit = Settings.WasteFruit or "Bloodfruit"
            local cap = tonumber(Settings.FruitsCapAmount) or tonumber(Settings.EatCap) or 100
            if wasteFruit and cap then eatDownToCap(wasteFruit, cap) end
            task.wait(1)
        end
    end)
end

end
do
autoEatActive = false

function startAutoEat()
    if autoEatActive then return end
    autoEatActive = true
    task.spawn(function()
        while Settings.AutoEatEnabled do
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then

                local mainGui = plr.PlayerGui:FindFirstChild("MainGui")
                local hungerVal = 100
                if mainGui then
                    local bars = mainGui:FindFirstChild("Panels") and mainGui.Panels:FindFirstChild("Stats") and mainGui.Panels.Stats:FindFirstChild("Bars")
                    if bars then
                        local hungerLabel = bars:FindFirstChild("Hunger") and bars.Hunger:FindFirstChild("ValueLabel")
                        if hungerLabel and hungerLabel:IsA("TextLabel") then
                            local num = tonumber(hungerLabel.Text)
                            if num then hungerVal = num end
                        end
                    end
                end

                if hungerVal <= (Settings.EatThreshold or 70) then

                     local fruitName = Settings.EatFruit or "Bloodfruit"
                     local fruitID = resolveHealFruitItemId(fruitName)

                     if fruitID and mainGui then
                         local rightPanel = mainGui:FindFirstChild("RightPanel")
                         local inventory = rightPanel and rightPanel:FindFirstChild("Inventory")
                         local list = inventory and inventory:FindFirstChild("List")

                         local slotID = nil
                         if list then
                             for _, item in ipairs(list:GetChildren()) do
                                 if item:IsA("ImageLabel") and item.Name == fruitName then
                                     slotID = item.LayoutOrder
                                     break
                                 end
                             end
                         end

                         if slotID then
                             pcall(function()
                                 local actionId = getPacketId("UseBagItem")
                                 local b = buffer.create(8)
                                 buffer.writeu8(b, 0, 0)
                                 buffer.writeu8(b, 1, actionId)
                                 buffer.writeu32(b, 2, slotID)
                                 buffer.writeu16(b, 6, fruitID)
                                 if ByteNetReliable then ByteNetReliable:FireServer(b) end
                             end)
                             local delayTime = 1 / (Settings.HealCPS or 1)
                             task.wait(delayTime)
                         else

                             task.wait(1)
                         end
                     else
                         task.wait(1)
                     end
                else
                     task.wait(0.5)
                end
            else
                task.wait(1)
            end
        end
        autoEatActive = false
    end)
end

end

-- ============================================================
-- 8. GOLD & PATHS (backend completo: paths, tween, noclip, movimiento, circuito)
-- ============================================================
function getGoldPathList()
    local list = {"None"}
    local folder = "ASTERTween"
    if not isfolder(folder) then makefolder(folder) end
    for _, file in ipairs(listfiles(folder)) do
        if file:find(".json") then

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

    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")

    for i, pos in ipairs(Settings.recordedPositions) do

        if true then
            local p = Instance.new("Part", f)
            p.Size = Vector3.new(0.3, 0.3, 0.3)
            p.Position = Vector3.new(pos.X, pos.Y, pos.Z)
            p.Anchored = true
            p.CanCollide = false
            p.Color = Color3.fromRGB(255, 215, 0)
            p.Transparency = 0.5
            p.Material = Enum.Material.Neon

            local bg = Instance.new("BillboardGui", p)
            bg.Size = UDim2.new(0, 20, 0, 20)
            bg.StudsOffset = Vector3.new(0, 1.5, 0)
            bg.AlwaysOnTop = true

            local frame = Instance.new("Frame", bg)
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            frame.BackgroundTransparency = 0.3

            local corner = Instance.new("UICorner", frame)
            corner.CornerRadius = UDim.new(1, 0)

            local border = Instance.new("UIStroke", frame)
            border.Color = Color3.fromRGB(255, 215, 0)
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

currentWaypoint = 1
isTweening = false
walkingToWaypoint = false
isWaitingForWaypoint = false
waypointWaitStartTime = 0
alignPosition = nil
alignAttachment0 = nil
alignAttachment1 = nil
restoreCollision = nil
plantAlignPosition = nil
plantAttachment0 = nil
plantAttachment1 = nil
plantIsTweening = false

WALK_SPEED = 21
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
    if antiFlipGyro and antiFlipGyro.Parent ~= hrp then
        pcall(function() antiFlipGyro:Destroy() end)
        antiFlipGyro = nil
    end
    if not antiFlipGyro then
        antiFlipGyro = Instance.new("BodyGyro")
        antiFlipGyro.Name = "AntiFlipGyro"
        antiFlipGyro.MaxTorque = Vector3.new(math.huge, 0, math.huge)
        antiFlipGyro.P = 9000
        antiFlipGyro.CFrame = CFrame.new()
        antiFlipGyro.Parent = hrp
    end
end

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
do
local noclipWorldParts = {}
local noclipDepOverlap = OverlapParams.new()
noclipDepOverlap.FilterType = Enum.RaycastFilterType.Include

function disableWorldCollision(part)
    if not part or not part:IsA("BasePart") then return end
    if noclipWorldParts[part] ~= nil then return end
    noclipWorldParts[part] = part.CanCollide
    part.CanCollide = false
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
        if Settings.GoldNoclip and hrp and not (Settings.TweenToBushAndBox or Settings.TweenToPlantBox or Settings.TweenToBush) then
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
                    noclipDepOverlap.FilterDescendantsInstances = {deployables}
                    local nearby = workspace:GetPartBoundsInRadius(hrpPos, 40, noclipDepOverlap)
                    local cap = math.min(#nearby, 64)
                    for i = 1, cap do
                        disableWorldCollision(nearby[i])
                    end
                end
            end)
        end
    end
end

local _goldLogAt = {}
-- ¿este modelo es un gold node? (nombre con "gold node", EntityID 422, o recurso con "gold" en el nombre)
local function _isGoldModel(m)
    if not m or not m:IsA("Model") then return false end
    local lname = m.Name:lower()
    if lname:find("gold node", 1, true) or m:GetAttribute("EntityID") == 422 then return true end
    if lname:find("gold", 1, true) and (m.Parent == workspace:FindFirstChild("Resources") or m.Parent == workspace:FindFirstChild("Mounds")) then
        return true
    end
    return false
end

-- Misma detección que ASTER unificado: escanea una caja alrededor, sube por los modelos de cada parte
-- y mide la distancia hasta el centro del modelo. Las paredes y el techo no influyen.
function goldNodeNearby(pos)
    local radius = tonumber(Settings.GoldDetectRange) or 13

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
                if _isGoldModel(m) then
                    local okP, piv = pcall(function() return m:GetPivot().Position end)
                    if okP then
                        local d = (piv - pos).Magnitude
                        if d <= bestDist then best, bestDist = m, d end
                    end
                end
            end
            m = m.Parent
        end
    end

    if best then
        local now = tick()
        if not _goldLogAt[best] or now - _goldLogAt[best] > 3 then
            _goldLogAt[best] = now
            print(string.format("[GoldDelay] gold node detectado: %s a %.1f studs", best.Name, bestDist))
        end
        return true, best
    end

    -- respaldo: búsqueda por esfera, por nombre de la pieza o de su padre
    local okB, near = pcall(function() return workspace:GetPartBoundsInRadius(pos, radius) end)
    if okB and near then
        for _, p in ipairs(near) do
            local parentIsGold = p.Parent and (p.Parent.Name:lower():find("gold node") or p.Parent:GetAttribute("EntityID") == 422)
            local nameMatch = p.Name:lower():find("gold node") or parentIsGold
            if nameMatch then
                local node = parentIsGold and p.Parent or p
                print("[GoldDelay] gold node detectado (respaldo): " .. tostring(node.Name))
                return true, node
            end
        end
    end
    return false
end

function startMovementEngine()
    if movementConnection then return end
    positionHistory = {}
    local lastFramePos = nil
    local isWaitingForDelay = false
    local delayStartTime = 0
    local lastDecisionTick = 0
    local goldWaitNode = nil
    local cachedShouldTween = false
    local cachedTweenReason = ""
    local cachedWalkSpeed = 20
    movementConnection = runs.Heartbeat:Connect(function(deltaTime)
        if not Settings.GoldCircuitEnabled then
            if movementConnection then movementConnection:Disconnect() movementConnection = nil end
            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then removeBodyVelocity(hrp) end
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
                local foundGold, nodeModel = goldNodeNearby(hrp.Position)
                goldWaitNode = foundGold and nodeModel or nil
                print(string.format("[GoldDelay] waypoint %d | radio=%s | esperar hasta picar=%s | delay=%s | max=%s | gold=%s",
                    currentWaypoint, tostring(Settings.GoldDetectRange), tostring(Settings.GoldWaitUntilMined),
                    tostring(Settings.GoldDelay), tostring(Settings.GoldMaxWait), foundGold and tostring(nodeModel.Name) or "no encontrado"))

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
                -- espera mientras el gold node siga existiendo (se esta picando), con limite de seguridad
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

        hum.WalkSpeed = Settings.WalkSpeed or 16

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

do
    local old = __ASTER_RUNTIME.connections["goldNoclip"]
    if old and old.Disconnect then
        pcall(function() old:Disconnect() end)
        __ASTER_RUNTIME.connections["goldNoclip"] = nil
    end
end

function stopGoldCircuit()
    Settings.GoldCircuitEnabled = false
    pcall(function()
        if movementConnection then movementConnection:Disconnect() end
    end)
    movementConnection = nil
    pcall(function()
        local character = plr.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if hrp then
            removeBodyVelocity(hrp)
            hrp.Velocity = Vector3.new(0, 0, 0)
            hrp.RotVelocity = Vector3.new(0, 0, 0)
        end
        if hum and hrp then hum:MoveTo(hrp.Position) end
    end)
    pcall(removeAlignPosition)
    pcall(function()
        if antiFlipGyro then antiFlipGyro:Destroy() end
    end)
    antiFlipGyro = nil
    pcall(function()
        if restoreCollision then restoreCollision() end
    end)
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
    if goldActive and movementConnection then return end
    goldActive = true

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

    if Settings.GoldAutoEquip then
        startGoldEquipManager()
    end

    task.spawn(function()
        while Settings.GoldCircuitEnabled do task.wait(0.5) end
        goldActive = false
    end)
end
end

-- ============================================================
-- 9. AUTO DROP
-- ============================================================
function getQuantity(itemFrame)
    local qImage = itemFrame:FindFirstChild("QuantityImage")
    local qText = qImage and qImage:FindFirstChild("QuantityText")
    if qText and qText.Text ~= "" then
        local cleanString = qText.Text:gsub("%D", "")
        return tonumber(cleanString) or 0
    end
    return 0
end

do
local function getDropInventoryCount(targetName)
    local mainGui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("MainGui")
    local invList = mainGui and mainGui.RightPanel and mainGui.RightPanel.Inventory and mainGui.RightPanel.Inventory.List
    if not invList then return 0 end

    local lowerTarget = tostring(targetName or ""):lower():match("^%s*(.-)%s*$")
    if not lowerTarget or lowerTarget == "" then return 0 end

    for _, child in ipairs(invList:GetChildren()) do
        if child:IsA("GuiObject") then
            local childNameLower = child.Name:lower():match("^%s*(.-)%s*$")
            if childNameLower == lowerTarget then
                local attrCount = child:GetAttribute("Count") or child:GetAttribute("Amount") or child:GetAttribute("Quantity")
                if attrCount then return tonumber(attrCount) or 0 end

                local quantity = getQuantity(child)
                if quantity > 0 then return quantity end
                return 1
            end
        end
    end

    return 0
end

function dynamicDrop(targetName)
    local invList = game:GetService("Players").LocalPlayer.PlayerGui.MainGui.RightPanel.Inventory.List

    local function findItemFrame(nameToFind)
        local lowerTarget = nameToFind:lower():match("^%s*(.-)%s*$")
        if not lowerTarget or lowerTarget == "" then return nil end

        for _, child in ipairs(invList:GetChildren()) do
            if child:IsA("GuiObject") then
                local childNameLower = child.Name:lower():match("^%s*(.-)%s*$")
                if childNameLower == lowerTarget then
                    return child
                end
            end
        end
        return nil
    end

    local itemFrame = findItemFrame(targetName)
    if itemFrame then
        local quantity = getQuantity(itemFrame)
        if quantity <= 0 then quantity = 1 end

        local slotIndex = itemFrame.LayoutOrder
        if slotIndex then
            if ByteNetReliable then
                 local dropId = getPacketId("DropBagItem")
                 if dropId then
                     local b = buffer.create(4)
                     buffer.writeu8(b, 0, 0)
                     buffer.writeu8(b, 1, dropId)
                     buffer.writeu16(b, 2, slotIndex)
                     ByteNetReliable:FireServer(b)
                 end
            end

            if quantity <= 10 then
                return 0.2
            else
                return 0
            end
        end
    end
    return 0.5
end

local autoDropCounts = {}
local autoDropStartCounts = {}
local autoDropLastKey = nil

if not __ASTER_RUNTIME.autoDropLoopStarted then
    __ASTER_RUNTIME.autoDropLoopStarted = true
    local session = CURRENT_SESSION
    task.spawn(function()
        while isRuntimeSessionActive(session) do
            local waitTime = 0.5
            if Settings.AutoDropEnabled and Settings.DropItem and Settings.DropItem ~= "" then
             local parsedDropAmount = tonumber(Settings.DropAmount)
             local hasDropLimit = parsedDropAmount ~= nil and parsedDropAmount > 0
             local dropAmount = hasDropLimit and math.floor(parsedDropAmount) or math.huge
             local dropKey = tostring(Settings.DropItem or "") .. "|" .. (hasDropLimit and tostring(dropAmount) or "Infinite")
             if autoDropLastKey ~= dropKey then
                 table.clear(autoDropCounts)
                 table.clear(autoDropStartCounts)
                 autoDropLastKey = dropKey
             end
             local droppedAny = false
             for item in string.gmatch(Settings.DropItem, '([^,]+)') do
                 local cleanItem = item:match("^%s*(.-)%s*$")
                 if cleanItem ~= "" then
                     local itemKey = cleanItem:lower()
                     if hasDropLimit and autoDropStartCounts[itemKey] == nil then
                         autoDropStartCounts[itemKey] = getDropInventoryCount(cleanItem)
                     end

                     local droppedCount = 0
                     if hasDropLimit then
                         local currentCount = getDropInventoryCount(cleanItem)
                         droppedCount = math.max(0, (autoDropStartCounts[itemKey] or currentCount) - currentCount)
                         autoDropCounts[itemKey] = droppedCount
                     end

                     if droppedCount < dropAmount then
                         local delay = dynamicDrop(cleanItem)
                         if delay == 0 then
                             droppedAny = true

                             if hasDropLimit then task.wait(0.15) else task.wait() end
                         elseif delay == 0.2 then

                             task.wait(0.2)
                         end

                         if hasDropLimit and delay ~= 0.5 then
                             local currentCount = getDropInventoryCount(cleanItem)
                             autoDropCounts[itemKey] = math.max(0, (autoDropStartCounts[itemKey] or currentCount) - currentCount)
                         end
                     end
                 end
             end
             if droppedAny then waitTime = 0 else waitTime = 0.1 end
        else
             if autoDropLastKey ~= nil then
                 table.clear(autoDropCounts)
                 table.clear(autoDropStartCounts)
                 autoDropLastKey = nil
             end
        end
        task.wait(waitTime)
    end
    end)
end
end

-- ============================================================
-- 10. AUTO BED RESPAWN
-- ============================================================
do
respawnActive = false
function startAutoRespawn()
    if respawnActive then return end
    respawnActive = true
    local spawnMenuPos = Vector3.new(-1686.31201, -3, -2534.19409)
    local detectionRange = 5
    local lastAttempt = 0
    local attemptCooldown = 5
    task.spawn(function()
        while Settings.AutoRespawnEnabled do
            pcall(function()
                local char = plr.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local distance = (root.Position - spawnMenuPos).Magnitude
                    if distance <= detectionRange and (tick() - lastAttempt) > attemptCooldown then
                        lastAttempt = tick()
                        task.wait(2)
                        pcall(function()
                            if ByteNetReliable then
                                local b = buffer.create(4)
                                buffer.writeu8(b, 0, 0)
                                buffer.writeu8(b, 1, getPacketId("RequestBedSpawn"))
                                buffer.writeu16(b, 2, 128)
                                ByteNetReliable:FireServer(b)

                                task.wait(0.2)

                                local b2 = buffer.create(2)
                                buffer.writeu8(b2, 0, 0)
                                buffer.writeu8(b2, 1, getPacketId("RequestBedSpawn"))
                                ByteNetReliable:FireServer(b2)
                            end
                        end)
                        pcall(function()
                            local pGui = plr.PlayerGui
                            for _, gui in pairs(pGui:GetDescendants()) do
                                if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and gui.Visible then
                                    local text = gui:IsA("TextButton") and gui.Text:lower() or ""
                                    local name = gui.Name:lower()
                                    if name:find("bed") or text:find("bed") or name:find("spawn") or text:find("spawn") then
                                        if firesignal then firesignal(gui.MouseButton1Click) firesignal(gui.Activated) end
                                        break
                                    end
                                end
                            end
                        end)
                    end
                end
            end)
            task.wait(1)
        end
        respawnActive = false
    end)
end
end

-- ============================================================
-- 11. AUTO FUEL CAMPFIRE
-- ============================================================
do

local _fuelGuiActive = false
local function _fuelGuiVisible(o)
    local pg = plr:FindFirstChild("PlayerGui")
    local p = o
    while p and p ~= pg do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("ScreenGui") and not p.Enabled then return false end
        p = p.Parent
    end
    return p == pg
end
local function _fuelClick(btn)
    local fired = false
    for _, sig in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up"}) do
        if getconnections then
            local ok, conns = pcall(getconnections, btn[sig])
            if ok and type(conns) == "table" and #conns > 0 then
                for _, c in ipairs(conns) do pcall(function() c:Fire() end) end
                fired = true
                break
            end
        end
    end
    if not fired and firesignal then
        pcall(function() firesignal(btn.Activated) end)
        pcall(function() firesignal(btn.MouseButton1Click) end)
    end
end
local function _campfireFuel(fire)
    if not fire then return nil end
    for _, d in ipairs(fire:GetDescendants()) do
        if d:IsA("TextLabel") then
            local n = tonumber(d.Text)
            if n then return n end
        end
    end
    return nil
end
local function _aviso(t)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "AutoFuel", Text = tostring(t):sub(1, 200), Duration = 12})
    end)
end
local _fuelInfoShown = false

local function _openCampfireMenu(fire)
    local cd
    for _, d in ipairs(fire:GetDescendants()) do
        if d:IsA("ClickDetector") then cd = d break end
    end
    if cd and fireclickdetector then
        pcall(fireclickdetector, cd)
        return
    end
    local eid = fire:GetAttribute("EntityID")
    local pid = getPacketId("InteractStructure")
    if not _fuelInfoShown then
        _fuelInfoShown = true
        _aviso("Abriendo fogata: EntityID=" .. tostring(eid) .. " paquete=" .. tostring(pid))
    end
    if eid and pid and ByteNetReliable then
        local b = buffer.create(6)
        buffer.writeu8(b, 0, 0)
        buffer.writeu8(b, 1, pid)
        buffer.writeu32(b, 2, eid)
        ByteNetReliable:FireServer(b)
    end
end

local function _fireList(range)
    local out = {}
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    local dep = getWorkspaceDeployables()
    if not hrp or not dep then return out end
    for _, v in ipairs(dep:GetChildren()) do
        if v.Name == "Campfire" then
            local p = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if p then
                local d = (p.Position - hrp.Position).Magnitude
                if d <= range then out[#out + 1] = {fire = v, dist = d} end
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

local function _waitFuelUp(fire, before, maxWait)
    local t0 = os.clock()
    repeat
        task.wait(0.05)
        local now = _campfireFuel(fire)
        if now and now > before then return true end
    until os.clock() - t0 >= maxWait
    return false
end

function startAutoFuel()
    if _fuelGuiActive then return end
    _fuelGuiActive = true
    task.spawn(function()
        local handlers = {}
        local noted = false
        local cooldown, bad = {}, {}
        local menuFire, menuStart, lastOpen = nil, 0, 0
        local warnedItems = -1e9

        local function getGui()
            local gui = plr.PlayerGui:FindFirstChild("Campfire")
            local frame = gui and gui:FindFirstChild("Frame")
            return gui, frame and frame:FindFirstChild("List")
        end

        local function memorize(list)
            if not list or not getconnections or not debug or not debug.getupvalues then return end
            for _, b in ipairs(list:GetChildren()) do
                if b:IsA("GuiButton") and b.Name ~= "Exit" and not handlers[b.Name] then
                    pcall(function()
                        local conns = getconnections(b.Activated)
                        local f = conns[1] and conns[1].Function
                        if not f then return end
                        local st
                        for _, v in pairs(debug.getupvalues(f)) do
                            if type(v) == "table" and rawget(v, "selectionTarget") ~= nil then st = v break end
                        end
                        if st then
                            handlers[b.Name] = {f = f, st = st, kind = typeof(st.selectionTarget) == "Instance" and st.selectionTarget.ClassName or "?"}
                            if not noted then
                                noted = true
                                _aviso("Auto Fuel listo: ahora alimenta sin abrir el menu")
                            end
                        end
                    end)
                end
            end
        end

        local function availableNames()
            local want = Settings.FuelType or "All (Wood/Log/Leaves)"
            local names = (want:sub(1, 3) == "All") and {"Wood", "Log", "Leaves"} or {want}
            local avail = {}
            for _, n in ipairs(names) do
                if getlayout(n) then avail[#avail + 1] = n end
            end
            return avail
        end

        local function closeMenu()
            local gui, list = getGui()
            if menuFire and list then
                local exit = list.Parent:FindFirstChild("Exit") or list:FindFirstChild("Exit")
                if exit then _fuelClick(exit) end
            end
            menuFire = nil
            if gui and Settings.AutoFuelHideMenu then pcall(function() gui.Enabled = false end) end
        end

        local function feed(fire, feeds)
            local avail = availableNames()
            if #avail == 0 then return "noitems" end

            if Settings.AutoFuelDirect then
                local usable = {}
                for _, n in ipairs(avail) do
                    if handlers[n] then usable[#usable + 1] = handlers[n] end
                end
                if #usable > 0 then
                    for i = 1, feeds do
                        local h = usable[((i - 1) % #usable) + 1]
                        local target = fire
                        if h.kind ~= "Model" and h.kind ~= "Folder" then
                            target = fire.PrimaryPart or fire:FindFirstChildWhichIsA("BasePart") or fire
                        end
                        h.st.selectionTarget = target
                        task.spawn(function() pcall(h.f) end)
                    end
                    return true
                end
            end

            if not Settings.AutoFuelOpenMenu then return false end
            local gui, list = getGui()
            local ready = menuFire == fire and (os.clock() - menuStart) < 20
            if not ready then
                if os.clock() - lastOpen < 0.35 then return false end
                lastOpen = os.clock()
                _openCampfireMenu(fire)
                local t0 = os.clock()
                repeat
                    task.wait(0.05)
                    gui, list = getGui()
                until (list and _fuelGuiVisible(list)) or os.clock() - t0 > 1.2
                if not (list and _fuelGuiVisible(list)) then return false end
                menuFire, menuStart = fire, os.clock()
                memorize(list)
                if gui and Settings.AutoFuelHideMenu then pcall(function() gui.Enabled = false end) end
            end
            if not list then return false end
            for i = 1, feeds do
                local n = avail[((i - 1) % #avail) + 1]
                local b = list:FindFirstChild(n)
                if b and b:IsA("GuiButton") then _fuelClick(b) end
            end
            return true
        end

        while Settings.AutoFuelEnabled and not ScriptKilled do
            local busy = false
            pcall(function()
                local range = tonumber(Settings.FuelRange) or 30
                local threshold = Settings.FuelThreshold or 200
                local feeds = math.clamp(math.floor(tonumber(Settings.FuelFeeds) or 2), 1, 6)
                local fires = _fireList(range)
                if Settings.FuelAllNearby == false and #fires > 1 then fires = {fires[1]} end

                local gui, list = getGui()
                if list and _fuelGuiVisible(list) then
                    memorize(list)
                    if Settings.AutoFuelOpenMenu and Settings.AutoFuelHideMenu and next(handlers) and gui then
                        pcall(function() gui.Enabled = false end)
                    end
                end

                for _, e in ipairs(fires) do
                    if not Settings.AutoFuelEnabled then break end
                    local fire = e.fire
                    if fire and fire.Parent and (cooldown[fire] or 0) < os.clock() then
                        local fuel = _campfireFuel(fire)
                        if fuel and fuel < threshold then
                            busy = true

                            local guard = 0
                            while Settings.AutoFuelEnabled and guard < 60 and fire.Parent do
                                guard = guard + 1
                                local before = _campfireFuel(fire)
                                if not before or before >= threshold then break end
                                local sent = feed(fire, feeds)
                                if sent == "noitems" then
                                    cooldown[fire] = os.clock() + 5
                                    if os.clock() - warnedItems > 30 then
                                        warnedItems = os.clock()
                                        _aviso("Auto Fuel: no tenes " .. tostring(Settings.FuelType or "Wood/Log/Leaves") .. " en el inventario")
                                    end
                                    break
                                elseif not sent then
                                    cooldown[fire] = os.clock() + 3
                                    break
                                end
                                if _waitFuelUp(fire, before, 0.5) then
                                    bad[fire] = 0
                                else
                                    bad[fire] = (bad[fire] or 0) + 1
                                    if bad[fire] >= 3 then
                                        bad[fire] = 0
                                        cooldown[fire] = os.clock() + 15
                                        break
                                    end
                                end
                            end
                            if menuFire == fire then closeMenu() end
                        end
                    end
                end
            end)
            task.wait(busy and 0.02 or 0.2)
        end
        pcall(function() if menuFire then closeMenu() end end)
        _fuelGuiActive = false
    end)
end

end

-- ============================================================
-- 11b. SIN VENTANA (modo headless)
-- No se crea ninguna interfaz: las funciones corren con los mismos valores
-- por defecto que muestra la version con ventana. Solo queda el HUD de
-- Tiempo / FPS / Oro (seccion HUD), con su boton Ruta y Elegir cofre.
-- Los ajustes se cambian editando los numeros en el script.
-- ============================================================
ASTER = ASTER or {}
ASTER.Options = ASTER.Options or {}

do
    -- cierra una ventana vieja si quedo de una ejecucion anterior
    pcall(function()
        local parentUI = getAsterHiddenUI()
        for _, n in ipairs({ "ASTER_Window", "ASTER_Toggle" }) do
            local old = parentUI:FindFirstChild(n)
            if old then old:Destroy() end
        end
    end)

    Window = { Tabs = {}, ElementRegistry = {}, Headless = true }

    local function normSel(v)
        local sel = {}
        if type(v) == "table" then
            for k, x in pairs(v) do
                if type(k) == "number" then sel[x] = true elseif x then sel[k] = true end
            end
        end
        return sel
    end

    function Window:AddTab(opts)
        local tab = { Title = (opts and opts.Title) or "Tab" }
        table.insert(Window.Tabs, tab)

        function tab:AddLabel(text) return { Text = text } end

        -- sin ventana nadie puede tocar un boton (la ruta "5" ya se carga sola)
        function tab:AddButton(name, cb)
            return { Name = name }
        end

        function tab:AddToggle(name, default, cb)
            local state = (default == true)
            local api = {
                GetValue = function() return state end,
                SetValue = function(v) state = (v == true) end,
            }
            Window.ElementRegistry[name] = api
            return api
        end

        function tab:AddSlider(name, min, max, default, step, cb)
            local value = default
            local api = {
                GetValue = function() return value end,
                SetValue = function(v) value = v end,
            }
            Window.ElementRegistry[name] = api
            return api
        end

        function tab:AddInput(name, default, cb)
            local text = tostring(default or "")
            local api = {
                GetValue = function() return text end,
                SetValue = function(v) text = tostring(v or "") end,
            }
            Window.ElementRegistry[name] = api
            return api
        end

        local function buildDropdown(name, values, multi, initial)
            local value, sel = nil, {}
            if multi then sel = normSel(initial) else value = initial end
            local api = {}
            function api:SetValues(v) values = v or {} end
            function api:SetValue(v)
                if multi then sel = normSel(v) else value = v end
            end
            function api:GetValue()
                if multi then
                    local t = {}
                    for k, x in pairs(sel) do if x then t[k] = true end end
                    return t
                end
                return value
            end
            Window.ElementRegistry[name] = api
            return api
        end
        function tab:AddDropdown(name, values, default, cb)
            return buildDropdown(name, values, false, default)
        end
        function tab:AddMultiDropdown(name, values, default, cb)
            return buildDropdown(name, values, true, default)
        end

        return tab
    end

    ASTER.Tabs = {}
    ASTER.Tabs.Main = Window:AddTab({ Title = "Gold & Paths" })
    ASTER.Tabs.Automation = Window:AddTab({ Title = "Automation" })
    ASTER.Tabs.Combat = Window:AddTab({ Title = "Combat / PvP" })
    ASTER.Tabs.Pickup = Window:AddTab({ Title = "Loot & Chests" })
end


-- ============================================================
-- 11c. ITEM TOOLS (Item Deletion / Auto Craft / Items Into Chest)
-- Se maneja desde el menu: pestaña "Loot & Chests" y boton de cofre del HUD
-- ============================================================
ItemTools = {
    selecting = false,
    selectedChest = nil,
    status = "Cofre: ninguno seleccionado",
    statusLabel = nil,
    cfg = {
        deleteEnabled = true,
        deleteRange = 25,
        deleteTargets = "Log, Stone, Raw Iron, Coal, Wood, Leaves,",
        craftEnabled = true,
        craftUseAmount = false,
        craftObject = "Leaf Shirt",
        craftAmount = 1,
        craftDelay = 0.05,
        chestEnabled = true,
        chestTargets = "Raw Gold",
    },
}

do
    local IT = ItemTools
    local RS = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")

    local mods = {}
    local function getMods()
        if mods.ready then return mods end
        local modules = RS:FindFirstChild("Modules")
        if not modules then return mods end
        local okP, Packets = pcall(function() return require(modules:FindFirstChild("Packets")) end)
        local okG, GameUtil = pcall(function() return require(modules:FindFirstChild("GameUtil")) end)
        local okI, ItemIDS = pcall(function() return require(modules:FindFirstChild("ItemIDS")) end)
        if okP and okG and okI then
            mods.Packets, mods.GameUtil, mods.ItemIDS = Packets, GameUtil, ItemIDS
            mods.ready = true
        end
        return mods
    end

    local function sendPacket(name, ...)
        local m = getMods()
        local packet = m.Packets and m.Packets[name]
        if not packet or type(packet.send) ~= "function" then
            warn("[ItemTools] Packet no disponible:", name)
            return false
        end
        local ok, err = pcall(packet.send, ...)
        if not ok then warn("[ItemTools] Error enviando", name, err) end
        return ok
    end

    local function inventoryIndex(itemName)
        local gui = plr:FindFirstChildOfClass("PlayerGui")
        local main = gui and gui:FindFirstChild("MainGui")
        local right = main and main:FindFirstChild("RightPanel")
        local inv = right and right:FindFirstChild("Inventory")
        local list = inv and inv:FindFirstChild("List")
        local entry = list and list:FindFirstChild(itemName)
        return entry and entry.LayoutOrder
    end

    local function inventoryCount(itemName)
        local index = inventoryIndex(itemName)
        if not index then return 0 end
        local m = getMods()
        local data = m.GameUtil and m.GameUtil.Data and m.GameUtil.Data.inventory
        local entry = data and data[index]
        return entry and tonumber(entry.quantity) or 0
    end

    local function parseTargets(text)
        local result = {}
        for name in string.gmatch(text or "", "[^,]+") do
            name = name:match("^%s*(.-)%s*$")
            if name ~= "" then result[name] = true end
        end
        return result
    end

    local function getRoot()
        local c = plr.Character
        return c and c:FindFirstChild("HumanoidRootPart"), c
    end

    local function getWorldItems(root, char)
        local itemsFolder = workspace:FindFirstChild("Items")
        if not itemsFolder or not root then return {} end
        local ignore = {}
        if char then ignore[#ignore + 1] = char end
        for _, n in ipairs({ "Players", "Terrain", "Resources", "Critters", "Rubble" }) do
            local f = workspace:FindFirstChild(n)
            if f then ignore[#ignore + 1] = f end
        end
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.MaxParts = 1000
        params.FilterDescendantsInstances = ignore
        local parts = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(50, 50, 50), params)
        local found, seen = {}, {}
        for _, part in ipairs(parts) do
            local item = part
            if item.Parent ~= itemsFolder then
                local model = part:FindFirstAncestorWhichIsA("Model")
                if model and model.Parent == itemsFolder then item = model else item = nil end
            end
            if item and item.Parent and not seen[item] then
                seen[item] = true
                found[#found + 1] = item
            end
        end
        return found
    end

    local function itemPosition(item)
        if item:IsA("Model") then return item:GetPivot().Position end
        if item:IsA("BasePart") then return item.Position end
        return nil
    end

    -- ---------- estado / seleccion de cofre ----------
    function IT.setStatus(text)
        IT.status = text
        if IT.statusLabel then IT.statusLabel.Text = text end
    end

    function IT.setSelecting(v)
        IT.selecting = (v == true)
        pcall(function()
            local reg = Window and Window.ElementRegistry and Window.ElementRegistry["Select Chest (tap a chest)"]
            if reg and reg.SetValue then reg.SetValue(IT.selecting) end
        end)
        if IT.selecting then IT.setStatus("Toca un cofre en el mundo...") end
    end

    local function findChestModel(inst)
        local node = inst
        while node and node ~= workspace do
            if node:IsA("Model") and node.Name:lower():find("chest", 1, true) then return node end
            node = node.Parent
        end
        return nil
    end

    local function pickChestAt(input)
        local cam = workspace.CurrentCamera
        if cam then
            local _, char = getRoot()
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = char and { char } or {}
            local ray = cam:ScreenPointToRay(input.Position.X, input.Position.Y)
            local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
            local model = res and res.Instance and findChestModel(res.Instance)
            if model then return model end
        end
        local okM, target = pcall(function() return plr:GetMouse().Target end)
        if okM and target then return findChestModel(target) end
        return nil
    end

    local selConn = UIS.InputBegan:Connect(function(input, processed)
        if processed or not IT.selecting then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local model = pickChestAt(input)
        if not model then return end
        IT.selectedChest = model
        IT.setSelecting(false)
        IT.setStatus("Cofre: " .. model.Name .. " seleccionado")
    end)

    -- ---------- Auto Item Deletion ----------
    local lastDelete = 0
    local function runDeletion()
        if not IT.cfg.deleteEnabled or os.clock() - lastDelete < 0.35 then return end
        lastDelete = os.clock()
        local root, char = getRoot()
        if not root then return end
        local range = math.clamp(tonumber(IT.cfg.deleteRange) or 5, 1, 25)
        local targets = parseTargets(IT.cfg.deleteTargets)
        if next(targets) == nil then return end
        for _, item in ipairs(getWorldItems(root, char)) do
            local pos = itemPosition(item)
            if pos and (root.Position - pos).Magnitude <= range then
                if targets.All or targets[item.Name] then
                    pcall(function() item:Destroy() end)
                end
            end
        end
    end

    -- ---------- Auto Craft ----------
    local craftBusy = false
    local function stopCraft()
        IT.cfg.craftEnabled = false
        pcall(function()
            local reg = Window and Window.ElementRegistry and Window.ElementRegistry["Enable Auto Craft"]
            if reg and reg.SetValue then reg.SetValue(false) end
        end)
    end
    local function runCraft()
        if craftBusy or not IT.cfg.craftEnabled then return end
        local m = getMods()
        if not m.ready then return end
        craftBusy = true
        task.spawn(function()
            local itemName = IT.cfg.craftObject
            local itemId = m.ItemIDS[itemName]
            if not itemId then
                warn("[ItemTools] Objeto invalido:", itemName)
                craftBusy = false
                stopCraft()
                return
            end
            local delayTime = math.clamp(tonumber(IT.cfg.craftDelay) or 0.05, 0.01, 10)
            local useAmount = IT.cfg.craftUseAmount
            local amount = math.max(1, math.floor(tonumber(IT.cfg.craftAmount) or 1))
            local initial = inventoryCount(itemName)
            local targetCount = useAmount and (initial + amount) or math.huge
            while IT.cfg.craftEnabled and inventoryCount(itemName) < targetCount do
                local ok, canCraft = pcall(function()
                    return m.GameUtil.canCraftItem(itemName, nil, true)
                end)
                if ok and canCraft then sendPacket("CraftItem", itemId) end
                task.wait(delayTime)
            end
            craftBusy = false
            -- con "Use Amount" se craftea la cantidad pedida una sola vez y se apaga
            if useAmount and IT.cfg.craftEnabled then stopCraft() end
        end)
    end

    -- ---------- Items Into Chest ----------
    local chestBusy = false
    local function runChest()
        if chestBusy or not IT.cfg.chestEnabled then return end
        local chest = IT.selectedChest
        if not chest or not chest.Parent then
            IT.setStatus("Selecciona un cofre primero")
            return
        end
        local hitbox = chest:FindFirstChild("Hitbox")
        if not hitbox then
            IT.setStatus("El cofre no tiene Hitbox")
            return
        end
        local targets = parseTargets(IT.cfg.chestTargets)
        if next(targets) == nil then
            IT.setStatus("Elegi Targets o escribi All")
            return
        end
        chestBusy = true
        task.spawn(function()
            local root, char = getRoot()
            if root then
                for _, item in ipairs(getWorldItems(root, char)) do
                    if not IT.cfg.chestEnabled then break end
                    if item and item.Parent and (targets.All or targets[item.Name]) then
                        local pos = itemPosition(item)
                        local entityId = item:GetAttribute("EntityID")
                        if pos and entityId and (root.Position - pos).Magnitude <= 25 then
                            sendPacket("ForceInteract", entityId)
                            task.wait(0.12)
                            if item.Parent and chest and chest.Parent then
                                pcall(function()
                                    if item:IsA("Model") then
                                        if item.PrimaryPart and not item.PrimaryPart.Anchored then
                                            item:PivotTo(hitbox.CFrame)
                                        end
                                    elseif item:IsA("BasePart") and not item.Anchored then
                                        item:PivotTo(hitbox.CFrame)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
            chestBusy = false
        end)
    end

    -- ---------- bucle ligero ----------
    local acc = 0
    local loopConn = RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc < 0.2 then return end
        acc = 0
        pcall(runDeletion)
        pcall(runChest)
        if IT.cfg.craftEnabled and not craftBusy then pcall(runCraft) end
    end)

    local keep = __ASTER_RUNTIME.windowConns
    if type(keep) == "table" then
        keep[#keep + 1] = selConn
        keep[#keep + 1] = loopConn
    end
end


-- ============================================================
-- 12. UI / MENU
-- ============================================================
do
ASTER.Options.HealList = {}
for n, _ in pairs(healFruitData) do
    table.insert(ASTER.Options.HealList, n)
end
table.sort(ASTER.Options.HealList)

ASTER.Options.AllFruitList = {}
for _, name in ipairs(ALL_HEAL_FRUIT_NAMES or {}) do
    table.insert(ASTER.Options.AllFruitList, name)
end
table.sort(ASTER.Options.AllFruitList)

Settings.AutoEatEnabled = true
Settings.EatFruit = "Bluefruit"
Settings.EatThreshold = 1
Settings.WasteFruitsEnabled = true
Settings.EatCapEnabled = true
Settings.WasteFruit = "Bluefruit"
Settings.FruitsCapAmount = 100
Settings.EatCap = 100
local _wasteLoopOn = false
local function _startWasteOnce()
    if _wasteLoopOn then return end
    _wasteLoopOn = true
    startEatCap()
end

ASTER.Tabs.Combat:AddLabel("Auto Eat")
ASTER.Tabs.Combat:AddToggle("Auto Eat", true, function(v)
    Settings.AutoEatEnabled = v
    if v then startAutoEat() end
end)
ASTER.Tabs.Combat:AddDropdown("Eat Fruit", ASTER.Options.HealList, "Bluefruit", function(v)
    Settings.EatFruit = v
end)
ASTER.Tabs.Combat:AddSlider("Eat Threshold %", 1, 99, 1, 1, function(v)
    Settings.EatThreshold = v
end)

ASTER.Tabs.Combat:AddLabel("Waste Fruits")
ASTER.Tabs.Combat:AddToggle("Waste Fruits", true, function(v)
    Settings.WasteFruitsEnabled = v
    Settings.EatCapEnabled = v
    if v then _startWasteOnce() else _wasteLoopOn = false end
end)
ASTER.Tabs.Combat:AddDropdown("Waste Fruit", ASTER.Options.AllFruitList, "Bluefruit", function(v)
    Settings.WasteFruit = v
end)
ASTER.Tabs.Combat:AddInput("FruitsCap Amount", "100", function(v)
    local n = tonumber(v) or 100
    Settings.FruitsCapAmount = n
    Settings.EatCap = n
end)

ASTER.Tabs.Automation:AddLabel("Tools")
do
    local mineDefault = __ASTER_RUNTIME.MineAuraEnabled
    if mineDefault == nil then mineDefault = true end
    ASTER.Tabs.Automation:AddToggle("Mine Aura", mineDefault, function(v)
        __ASTER_RUNTIME.MineAuraEnabled = v == true
        if __ASTER_RUNTIME.MineAuraSet then __ASTER_RUNTIME.MineAuraSet(v == true) end
    end)
end

do
    Settings.OldBoardsPass = true
    local oldBoardParts = {}
    local running = false

    local function restoreBoards()
        for part, was in pairs(oldBoardParts) do
            if part and part.Parent then
                pcall(function() part.CanCollide = was end)
            end
        end
        oldBoardParts = {}
    end

    local function startBoards()
        if running then return end
        running = true
        task.spawn(function()
            while Settings.OldBoardsPass do
                pcall(function()
                    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    local resources = getWorkspaceResources()
                    if hrp and resources then
                        local hrpPos = hrp.Position
                        for _, model in ipairs(resources:GetChildren()) do
                            if model.Name == "Old Boards" then
                                for _, part in ipairs(model:GetDescendants()) do
                                    if part:IsA("BasePart") and oldBoardParts[part] == nil
                                        and (part.Position - hrpPos).Magnitude <= 55 then
                                        oldBoardParts[part] = part.CanCollide
                                        part.CanCollide = false
                                    end
                                end
                            end
                        end
                    end
                end)
                task.wait(0.25)
            end
            restoreBoards()
            running = false
        end)
    end

    ASTER.Tabs.Automation:AddToggle("Old Boards (atravesar)", true, function(v)
        Settings.OldBoardsPass = v == true
        if v then
            startBoards()
        end
    end)
    startBoards()
end

-- [[ FARM: Auto Plant / Auto Harvest / Pickup Aura (menú) ]] --
do
    local CFG = __ASTER_RUNTIME.FarmCfg
    local lists = __ASTER_RUNTIME.FarmLists
    local function selectedList(sel, order)
        local out = {}
        for _, name in ipairs(order) do
            if sel[name] then table.insert(out, name) end
        end
        return out
    end

    ASTER.Tabs.Automation:AddLabel("Farm (Plant / Harvest / Pickup)")
    ASTER.Tabs.Automation:AddToggle("Farm: Auto Plant", CFG.AutoPlant, function(v) CFG.AutoPlant = v == true end)
    ASTER.Tabs.Automation:AddToggle("Farm: Auto Harvest", CFG.AutoHarvest, function(v) CFG.AutoHarvest = v == true end)
    ASTER.Tabs.Automation:AddToggle("Farm: Auto Pickup", CFG.AutoPickup, function(v) CFG.AutoPickup = v == true end)
    ASTER.Tabs.Automation:AddToggle("Farm: Pickup Cofres", CFG.PickupChests, function(v) CFG.PickupChests = v == true end)
    ASTER.Tabs.Automation:AddToggle("Farm: Auto Move", CFG.AutoMove, function(v) CFG.AutoMove = v == true end)
    ASTER.Tabs.Automation:AddMultiDropdown("Farm: Fruta", lists.FRUITS, CFG.PlantItems, function(sel)
        CFG.PlantItems = selectedList(sel, lists.FRUITS)
    end)
    ASTER.Tabs.Automation:AddMultiDropdown("Farm: Items", lists.ITEMS, CFG.PickupTargets, function(sel)
        if sel.All then
            CFG.PickupTargets = { "All" }
        else
            CFG.PickupTargets = selectedList(sel, lists.ITEMS)
        end
    end)
    ASTER.Tabs.Automation:AddSlider("Farm: Rango recoger", 1, 25, CFG.PickupRange, 1, function(v) CFG.PickupRange = v end)
    ASTER.Tabs.Automation:AddSlider("Farm: Delay recoger", 0, 5, CFG.PickupDelay, 0.05, function(v) CFG.PickupDelay = v end)
    ASTER.Tabs.Automation:AddSlider("Farm: Acciones por tanda", 1, 8, CFG.ActionsPerTick, 1, function(v) CFG.ActionsPerTick = math.floor(v + 0.5) end)
    ASTER.Tabs.Automation:AddSlider("Farm: Delay plantar", 0.01, 0.5, CFG.ActionDelay, 0.01, function(v) CFG.ActionDelay = v end)
end
Settings.GoldAutoEquip = true
ASTER.Tabs.Automation:AddToggle("Gold AutoTool Equip", true, function(v)
    Settings.GoldAutoEquip = v == true
    if v then
        startGoldEquipManager()
    end
end)
local hoeOptions = { "Wood Hoe", "God Hoe", "Crystal Hoe" }
Settings.GoldHoeType = "Crystal Hoe"
local hoeDefault = Settings.GoldHoeType or "Wood Hoe"
local hoeListed = false
for _, h in ipairs(hoeOptions) do
    if h == hoeDefault then hoeListed = true break end
end
if not hoeListed then hoeDefault = "Wood Hoe" end
ASTER.Tabs.Automation:AddDropdown("Select Hoe", hoeOptions, hoeDefault, function(v)
    Settings.GoldHoeType = v
end)

ASTER.Tabs.Automation:AddLabel("Fuel / Utilities")
Settings.AutoFuelOpenMenu = true
Settings.AutoFuelHideMenu = true
Settings.AutoFuelDirect = true
ASTER.Tabs.Automation:AddToggle("Fuel Direct (sin menu)", true, function(v)
    Settings.AutoFuelDirect = v
end)
ASTER.Tabs.Automation:AddToggle("Auto Open Campfire Menu", true, function(v)
    Settings.AutoFuelOpenMenu = v
end)
ASTER.Tabs.Automation:AddToggle("Hide Campfire Menu", true, function(v)
    Settings.AutoFuelHideMenu = v
end)
Settings.AutoFuelEnabled = true
ASTER.Tabs.Automation:AddToggle("Auto Fuel Campfire", true, function(v)
    Settings.AutoFuelEnabled = v
    if v then startAutoFuel() end
end)
ASTER.Tabs.Automation:AddDropdown("Fuel Type", {"Wood", "Log", "Leaves", "Coal", "All (Wood/Log/Leaves)"}, "All (Wood/Log/Leaves)", function(v)
    Settings.FuelType = v
end)
Settings.FuelThreshold = 250
ASTER.Tabs.Automation:AddSlider("Fuel Threshold", 0, 250, 250, 1, function(v)
    Settings.FuelThreshold = v
end)
Settings.FuelFeeds = 2
Settings.FuelRange = 30
Settings.FuelAllNearby = true
ASTER.Tabs.Automation:AddSlider("Fuel Feeds At Once", 1, 6, 2, 1, function(v)
    Settings.FuelFeeds = math.floor(v + 0.5)
end)
ASTER.Tabs.Automation:AddSlider("Fuel Range (studs)", 10, 60, 30, 1, function(v)
    Settings.FuelRange = v
end)
ASTER.Tabs.Automation:AddToggle("Fuel All Nearby Campfires", true, function(v)
    Settings.FuelAllNearby = v
end)

task.defer(function()
    if Settings.AutoEatEnabled then startAutoEat() end
    if Settings.WasteFruitsEnabled then _startWasteOnce() end
    if Settings.GoldAutoEquip then pcall(startGoldEquipManager) end
    if Settings.AutoFuelEnabled then pcall(startAutoFuel) end
    if Settings.AutoRespawnEnabled then pcall(startAutoRespawn) end
end)

do
    local hudGui = Instance.new("ScreenGui")
    hudGui.Name = "ASTER_HUD"
    hudGui.ResetOnSpawn = false
    hudGui.DisplayOrder = 50
    hudGui.Parent = getAsterHiddenUI()
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 190)
    frame.Position = UDim2.new(0, 74, 0, 2)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = hudGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(150, 110, 255)
    stroke.Thickness = 1.2
    stroke.Parent = frame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 1, -88)
    label.Position = UDim2.new(0, 8, 0, 4)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(235, 225, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Font = Enum.Font.GothamBold
    label.TextSize = 19
    label.Text = "..."
    label.Parent = frame

    -- botón Ruta: ON = camina por la ruta (igual que "Start Tween" del menú), OFF = se detiene
    local routeBtn = Instance.new("TextButton")
    routeBtn.Size = UDim2.new(1, -16, 0, 30)
    routeBtn.Position = UDim2.new(0, 8, 1, -76)
    routeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    routeBtn.TextColor3 = Color3.new(1, 1, 1)
    routeBtn.Font = Enum.Font.GothamBold
    routeBtn.TextSize = 16
    routeBtn.AutoButtonColor = false
    routeBtn.Text = "Ruta: OFF"
    routeBtn.Parent = frame
    Instance.new("UICorner", routeBtn).CornerRadius = UDim.new(0, 6)

    -- boton para elegir el cofre (Items Into Chest)
    local chestBtn = Instance.new("TextButton")
    chestBtn.Size = UDim2.new(1, -16, 0, 30)
    chestBtn.Position = UDim2.new(0, 8, 1, -38)
    chestBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    chestBtn.TextColor3 = Color3.new(1, 1, 1)
    chestBtn.Font = Enum.Font.GothamBold
    chestBtn.TextSize = 15
    chestBtn.AutoButtonColor = false
    chestBtn.Text = "Elegir cofre"
    chestBtn.Parent = frame
    Instance.new("UICorner", chestBtn).CornerRadius = UDim.new(0, 6)
    local function refreshChestBtn()
        local IT = ItemTools
        if not IT then return end
        if IT.selecting then
            chestBtn.Text = "Toca un cofre..."
            chestBtn.BackgroundColor3 = Color3.fromRGB(110, 50, 190)
        elseif IT.selectedChest and IT.selectedChest.Parent then
            chestBtn.Text = "Cofre: " .. IT.selectedChest.Name
            chestBtn.BackgroundColor3 = Color3.fromRGB(50, 90, 60)
        else
            chestBtn.Text = "Elegir cofre"
            chestBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        end
    end
    chestBtn.Activated:Connect(function()
        local IT = ItemTools
        if not IT then return end
        IT.setSelecting(not IT.selecting)
        refreshChestBtn()
    end)
    local function routeReg()
        return Window and Window.ElementRegistry and Window.ElementRegistry["Start Tween"]
    end
    local function routeOn()
        local reg = routeReg()
        if reg and reg.GetValue then return reg.GetValue() == true end
        return Settings.GoldCircuitEnabled == true
    end
    local function refreshRouteBtn()
        local on = routeOn()
        routeBtn.Text = "Ruta: " .. (on and "ON" or "OFF")
        routeBtn.BackgroundColor3 = on and Color3.fromRGB(110, 50, 190) or Color3.fromRGB(35, 35, 40)
    end
    routeBtn.Activated:Connect(function()
        local want = not routeOn()
        local reg = routeReg()
        if reg and reg.SetValue then pcall(reg.SetValue, want) end
        if (Settings.GoldCircuitEnabled == true) ~= want then
            Settings.GoldCircuitEnabled = want
            if want then startGoldCircuit() else stopGoldCircuit() end
        end
        refreshRouteBtn()
    end)

    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, startPos = true, input.Position, frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    local frames, fps = 0, 0
    game:GetService("RunService").RenderStepped:Connect(function() frames = frames + 1 end)
    local t0 = os.clock()
    local fpsT = os.clock()
    local function fmtTime(sec)
        sec = math.floor(sec)
        return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
    end
    local function count(name)
        local ok, slot, n = pcall(getInventorySlotAndCount, name)
        if ok and slot then return n or 0 end
        return 0
    end
    local function fmtNum(n)
        local s = tostring(math.floor(n))
        local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
        if out:sub(1, 1) == "." then out = out:sub(2) end
        return out
    end
    task.spawn(function()
        while hudGui.Parent do
            local now = os.clock()
            if now - fpsT >= 1 then
                fps = math.floor(frames / (now - fpsT) + 0.5)
                frames, fpsT = 0, now
            end
            pcall(function()
                label.Text = "Tiempo: " .. fmtTime(now - t0)
                    .. "\nFPS: " .. fps
                    .. "\nOro: " .. fmtNum(count("Gold"))
                    .. "\nBluefruit: " .. fmtNum(count("Bluefruit"))
                refreshRouteBtn()
                refreshChestBtn()
            end)
            task.wait(0.5)
        end
    end)
    Settings.ShowHUD = true
    ASTER.Tabs.Automation:AddToggle("Show HUD (tiempo/FPS/items)", true, function(v)
        Settings.ShowHUD = v
        hudGui.Enabled = v
    end)
end

-- ============================================================
-- 12a. GOLD & PATHS UI (Gold Farm, Path Management, Waypoint Editor, Path Recorder)
-- ============================================================
ASTER.Tabs.Main:AddLabel("Gold Farm")

        ASTER.Tabs.Main:AddButton("LoadFreeGoldTween", function()

            local freeTweenData = [[
      {"positions":[{"Y":-35.001529693603519,"X":-111.23822784423828,"Z":-150.322998046875},{"Y":-33.06850051879883,"X":-150.28334045410157,"Z":-157.5271759033203,"waitTime":2.25},{"Y":-24.904457092285158,"X":-101.6497573852539,"Z":-176.8410186767578,"waitTime":2.25},{"Y":-16.217544555664064,"X":-129.49168395996095,"Z":-200.48655700683595,"waitTime":2.25},{"Y":-2.9872117042541506,"X":-109.68980407714844,"Z":-205.92343139648438},{"Y":-5.478652000427246,"X":-73.75923156738281,"Z":-165.41680908203126},{"Y":-2.54052996635437,"X":-47.84952926635742,"Z":-139.95700073242188},{"Y":-4.201225757598877,"X":-1.476401925086975,"Z":-114.92327880859375},{"Y":-3.000000476837158,"X":59.00017166137695,"Z":-83.25040435791016},{"Y":-3.594053030014038,"X":105.6518325805664,"Z":-41.69924545288086},{"Y":-3.0652363300323488,"X":134.2716522216797,"Z":-14.063572883605957},{"Y":-3.000000476837158,"X":222.952392578125,"Z":71.56534576416016},{"Y":-4.5299248695373539,"X":257.8995056152344,"Z":98.70545196533203},{"Y":-10.744340896606446,"X":293.61883544921877,"Z":121.47196960449219},{"Y":-3.8026249408721926,"X":344.6594543457031,"Z":153.6503143310547},{"Y":-3.000000476837158,"X":422.6432800292969,"Z":213.8682098388672},{"Y":-3.000000476837158,"X":441.91619873046877,"Z":227.66021728515626},{"Y":9.237739562988282,"X":450.6335754394531,"Z":233.390380859375},{"Y":13.820841789245606,"X":459.837646484375,"Z":248.66470336914063},{"Y":13.791736602783204,"X":473.9879150390625,"Z":208.55780029296876},{"Y":16.7873477935791,"X":477.49310302734377,"Z":191.6634979248047},{"Y":14.420902252197266,"X":468.1609191894531,"Z":154.39776611328126},{"Y":12.920480728149414,"X":500.728759765625,"Z":152.8026123046875},{"Y":-0.45536714792251589,"X":507.9001770019531,"Z":139.3783416748047},{"Y":-4.485151290893555,"X":526.7735595703125,"Z":107.79975128173828},{"Y":-11.092853546142579,"X":537.4927368164063,"Z":92.56905364990235},{"Y":-11.00516414642334,"X":559.0673217773438,"Z":41.365013122558597},{"Y":-11.543245315551758,"X":588.9154052734375,"Z":-32.28464889526367},{"Y":-8.54233169555664,"X":620.0653076171875,"Z":-105.294677734375},{"Y":-4.2826666831970219,"X":623.614013671875,"Z":-112.19488525390625},{"Y":-3.5430808067321779,"X":636.2014770507813,"Z":-146.62120056152345},{"Y":9.257548332214356,"X":640.1133422851563,"Z":-157.56373596191407},{"Y":23.890247344970704,"X":642.64013671875,"Z":-163.6774444580078},{"Y":31.053882598876954,"X":652.4203491210938,"Z":-172.4340057373047},{"Y":32.81493377685547,"X":663.3070068359375,"waitTime":0.22,"Z":-184.99884033203126},{"Y":48.18572235107422,"X":662.0396118164063,"Z":-194.4517364501953},{"Y":59.13154220581055,"X":649.7789306640625,"Z":-203.70794677734376},{"Y":69.12764739990235,"X":641.0880737304688,"Z":-210.55557250976563},{"Y":70.15151977539063,"X":638.1156005859375,"Z":-222.9108123779297},{"Y":68.10548400878906,"X":636.825439453125,"Z":-237.23130798339845},{"Y":60.8437614440918,"X":642.8209228515625,"Z":-253.01358032226563},{"Y":61.28973388671875,"X":652.2427978515625,"Z":-266.9076232910156},{"Y":60.53296661376953,"X":653.162109375,"Z":-282.9266052246094},{"Y":54.758602142333987,"X":648.52294921875,"Z":-302.2294921875},{"Y":52.903350830078128,"X":645.8076171875,"Z":-323.3299560546875},{"Y":53.815982818603519,"X":652.6668701171875,"Z":-347.0151062011719},{"Y":60.73252868652344,"X":663.3242797851563,"Z":-361.1748962402344},{"Y":73.63504028320313,"X":669.8377685546875,"Z":-369.90386962890627},{"Y":81.14241027832031,"X":677.5490112304688,"Z":-392.7919921875},{"Y":76.78495025634766,"X":661.2151489257813,"Z":-378.26605224609377},{"Y":64.52510833740235,"X":656.1217041015625,"Z":-376.3868408203125},{"Y":52.97677993774414,"X":645.702880859375,"Z":-371.31817626953127},{"Y":49.01122283935547,"X":631.9244384765625,"Z":-364.15716552734377},{"Y":41.84897994995117,"X":624.0087280273438,"Z":-362.3535461425781},{"Y":35.69752502441406,"X":615.4901733398438,"Z":-359.1184997558594},{"Y":29.094730377197267,"X":594.7220458984375,"Z":-362.3443298339844},{"Y":14.336801528930664,"X":584.0901489257813,"Z":-352.4488220214844},{"Y":10.334908485412598,"X":588.4595336914063,"Z":-351.7544860839844},{"Y":-4.860062599182129,"X":596.1582641601563,"Z":-349.16571044921877},{"Y":-7.396815776824951,"X":614.2924194335938,"waitTime":0.55,"Z":-357.3804626464844},{"Y":-3.537902593612671,"X":644.5868530273438,"Z":-365.5182189941406},{"Y":-7.571692943572998,"X":622.1827392578125,"Z":-382.667724609375},{"Y":-4.801229953765869,"X":613.672607421875,"Z":-391.78790283203127},{"Y":-4.90981912612915,"X":603.9226684570313,"Z":-382.5379638671875},{"Y":-1.5201094150543213,"X":586.2009887695313,"Z":-385.5180969238281},{"Y":6.9607014656066898,"X":573.9547729492188,"Z":-390.1113586425781},{"Y":12.069486618041993,"X":556.332763671875,"Z":-394.60400390625},{"Y":10.37628173828125,"X":540.7774658203125,"Z":-398.99322509765627},{"Y":4.5449981689453129,"X":529.14013671875,"Z":-400.5452880859375},{"Y":-3.019165515899658,"X":516.6317138671875,"Z":-400.4026794433594},{"Y":-4.804425239562988,"X":496.52886962890627,"Z":-398.82806396484377},{"Y":-10.353181838989258,"X":475.0547790527344,"Z":-400.9407958984375},{"Y":-10.959868431091309,"X":419.3533630371094,"Z":-581.047119140625},{"Y":-4.515384197235107,"X":447.6380615234375,"Z":-702.4669189453125},{"Y":-4.176120758056641,"X":435.8458251953125,"Z":-755.040283203125},{"Y":-15.457039833068848,"X":445.1316223144531,"Z":-753.1762084960938},{"Y":-28.351383209228517,"X":454.53192138671877,"Z":-759.3656616210938},{"Y":-32.352237701416019,"X":493.59033203125,"Z":-775.359130859375},{"Y":-35.03931427001953,"X":558.8375854492188,"Z":-757.4616088867188},{"Y":-33.095401763916019,"X":498.7996826171875,"Z":-777.1038208007813},{"Y":-32.94096755981445,"X":457.7084655761719,"Z":-757.65234375},{"Y":-20.382261276245118,"X":446.0972595214844,"Z":-754.4138793945313},{"Y":-4.416776180267334,"X":442.45281982421877,"Z":-754.048828125},{"Y":-3.0023162364959719,"X":422.19232177734377,"Z":-737.184814453125},{"Y":-5.76387882232666,"X":336.8083801269531,"Z":-715.814208984375},{"Y":-4.508203029632568,"X":177.21163940429688,"Z":-665.2991333007813},{"Y":-5.106081485748291,"X":94.67057800292969,"Z":-641.0780029296875},{"Y":-7.1703643798828129,"X":-72.0772476196289,"Z":-593.5692138671875},{"Y":-3.000000238418579,"X":-147.05799865722657,"Z":-620.1271362304688},{"Y":1.9939298629760743,"X":-192.12799072265626,"Z":-630.8121948242188},{"Y":22.409631729125978,"X":-206.55642700195313,"Z":-626.6513671875},{"Y":22.97821044921875,"X":-218.359130859375,"Z":-627.5806274414063},{"Y":5.354426860809326,"X":-226.0176544189453,"Z":-628.6981811523438},{"Y":-2.548158645629883,"X":-246.69288635253907,"Z":-623.3795166015625},{"Y":-3.0697176456451418,"X":-359.675537109375,"Z":-555.3429565429688},{"Y":-4.495460510253906,"X":-513.1705322265625,"Z":-502.7482604980469},{"Y":-4.86066198348999,"X":-617.6412353515625,"Z":-483.80157470703127},{"Y":-11.400009155273438,"X":-712.8392333984375,"Z":-457.2956237792969},{"Y":-7.471586227416992,"X":-811.6539306640625,"Z":-430.55804443359377},{"Y":-0.08951032161712647,"X":-846.9163818359375,"Z":-419.21368408203127},{"Y":9.093318939208985,"X":-875.843994140625,"Z":-419.2531433105469},{"Y":6.912939548492432,"X":-910.7113647460938,"Z":-404.67645263671877},{"Y":12.279690742492676,"X":-873.6814575195313,"Z":-419.9178161621094},{"Y":-7.145095348358154,"X":-834.7574462890625,"Z":-420.2413635253906},{"Y":-5.80037784576416,"X":-606.1832885742188,"Z":-474.835205078125},{"Y":-3.2188401222229006,"X":-419.3578796386719,"Z":-578.7322998046875},{"Y":-31.274709701538087,"X":-414.1717529296875,"Z":-574.5009765625},{"Y":-39.172325134277347,"X":-403.7130126953125,"Z":-550.8300170898438},{"Y":-43.13996505737305,"X":-390.6006164550781,"Z":-556.5234375},{"Y":-49.78067398071289,"X":-314.4368591308594,"Z":-569.5720825195313},{"Y":-56.79861068725586,"X":-253.19235229492188,"Z":-552.5960693359375},{"Y":-60.138118743896487,"X":-200.3426971435547,"Z":-535.1206665039063},{"Y":-62.65102767944336,"X":-161.09600830078126,"Z":-584.2384033203125},{"Y":-59.62028121948242,"X":-213.6802978515625,"Z":-633.1117553710938},{"Y":-63.866451263427737,"X":-176.5718536376953,"Z":-604.4242553710938},{"Y":-63.758480072021487,"X":-172.54689025878907,"Z":-581.6828002929688},{"Y":-63.337005615234378,"X":-175.91639709472657,"Z":-548.1791381835938},{"Y":-63.47652816772461,"X":-167.20986938476563,"Z":-526.0902099609375},{"Y":-63.031063079833987,"X":-169.10536193847657,"Z":-499.32818603515627},{"Y":-67.02882385253906,"X":-179.11900329589845,"Z":-475.46307373046877},{"Y":-70.55829620361328,"X":-179.87303161621095,"Z":-441.720947265625},{"Y":-77.9665298461914,"X":-174.41151428222657,"Z":-434.15374755859377},{"Y":-89.22174072265625,"X":-171.1572723388672,"Z":-438.45751953125},{"Y":-96.07298278808594,"X":-171.1572723388672,"Z":-438.45751953125},{"Y":-98.19011688232422,"X":-165.72308349609376,"Z":-449.9311218261719},{"Y":-102.99935150146485,"X":-153.114990234375,"Z":-461.7033386230469},{"Y":-99.103515625,"X":-154.4361114501953,"Z":-481.4436340332031},{"Y":-98.79793548583985,"X":-160.646240234375,"Z":-495.2094421386719},{"Y":-99.49816131591797,"X":-165.18618774414063,"Z":-503.30230712890627},{"Y":-103.00001525878906,"X":-186.71578979492188,"Z":-506.4983215332031},{"Y":-103.27188873291016,"X":-195.58457946777345,"Z":-496.19268798828127},{"Y":-103.44387817382813,"X":-191.13531494140626,"Z":-471.20703125},{"Y":-100.76580047607422,"X":-191.9467010498047,"waitTime":0.44,"Z":-449.3254089355469},{"Y":-103.40946197509766,"X":-190.7568817138672,"Z":-472.4533386230469},{"Y":-103.00000762939453,"X":-193.971435546875,"Z":-484.4539794921875},{"Y":-103.25475311279297,"X":-196.7699432373047,"Z":-495.9251708984375},{"Y":-103.09420776367188,"X":-185.9100799560547,"Z":-504.7077941894531},{"Y":-101.96617889404297,"X":-174.6333465576172,"Z":-506.0704650878906},{"Y":-98.9635009765625,"X":-167.57569885253907,"Z":-502.52386474609377},{"Y":-99.83893585205078,"X":-158.58596801757813,"Z":-497.6114807128906},{"Y":-97.93701934814453,"X":-145.60678100585938,"Z":-493.8856201171875},{"Y":-103.00001525878906,"X":-133.62059020996095,"Z":-493.56024169921877},{"Y":-103.00001525878906,"X":-115.6190414428711,"Z":-484.083984375},{"Y":-103.00001525878906,"X":-62.597782135009769,"Z":-468.059326171875},{"Y":-103.0001220703125,"X":-26.971569061279298,"Z":-446.7550048828125},{"Y":-102.93307495117188,"X":12.651388168334961,"Z":-416.4880676269531},{"Y":-99.44232177734375,"X":18.780681610107423,"Z":-406.5196838378906},{"Y":-99.00000762939453,"X":19.878032684326173,"Z":-388.8252868652344},{"Y":-99.25630950927735,"X":54.88884735107422,"waitTime":0.38,"Z":-351.56964111328127},{"Y":-99.00001525878906,"X":23.38662338256836,"Z":-383.5782775878906},{"Y":-99.28409576416016,"X":19.029319763183595,"Z":-404.92303466796877},{"Y":-103.00000762939453,"X":5.616722106933594,"Z":-416.9212951660156},{"Y":-103.24381256103516,"X":-46.93764877319336,"Z":-395.05572509765627},{"Y":-107.52904510498047,"X":-66.43094635009766,"Z":-381.4445495605469},{"Y":-103.82237243652344,"X":-86.76270294189453,"Z":-364.6119079589844},{"Y":-103.00001525878906,"X":-104.35830688476563,"Z":-347.22454833984377},{"Y":-99.75321960449219,"X":-109.04177856445313,"Z":-331.54412841796877},{"Y":-95.62533569335938,"X":-111.85131072998047,"Z":-313.1513671875},{"Y":-91.3089828491211,"X":-116.9298324584961,"Z":-291.8326110839844},{"Y":-87.29109191894531,"X":-135.14842224121095,"Z":-289.55859375},{"Y":-84.83995056152344,"X":-141.61415100097657,"Z":-291.59820556640627},{"Y":-84.6835708618164,"X":-152.28546142578126,"Z":-299.0233459472656},{"Y":-81.37537384033203,"X":-162.46849060058595,"Z":-311.5071716308594},{"Y":-76.61341094970703,"X":-167.87637329101563,"Z":-318.8341369628906},{"Y":-78.74473571777344,"X":-176.8583221435547,"Z":-317.3970947265625},{"Y":-77.18473815917969,"X":-185.7606201171875,"Z":-317.43902587890627},{"Y":-76.25244140625,"X":-198.16317749023438,"Z":-311.0343017578125},{"Y":-76.2488784790039,"X":-202.3442840576172,"Z":-305.9037170410156},{"Y":-76.32604217529297,"X":-212.91354370117188,"Z":-308.782958984375},{"Y":-78.92567443847656,"X":-221.00270080566407,"Z":-305.8204040527344},{"Y":-79.00000762939453,"X":-236.7618865966797,"Z":-314.0966796875},{"Y":-76.41073608398438,"X":-243.42208862304688,"Z":-326.4620361328125},{"Y":-79.00001525878906,"X":-260.8531799316406,"Z":-345.6808166503906},{"Y":-77.24800109863281,"X":-275.2143249511719,"Z":-350.6474914550781},{"Y":-76.12911987304688,"X":-294.4759826660156,"Z":-363.3056640625},{"Y":-79.00001525878906,"X":-319.6708984375,"Z":-370.8691101074219},{"Y":-76.38452911376953,"X":-294.5587463378906,"Z":-362.0054931640625},{"Y":-77.07986450195313,"X":-275.4173583984375,"Z":-349.7216796875},{"Y":-75.58771514892578,"X":-259.8752136230469,"Z":-332.2989807128906},{"Y":-76.162841796875,"X":-249.27874755859376,"Z":-317.2018127441406},{"Y":-76.66788482666016,"X":-239.51731872558595,"Z":-297.7491455078125},{"Y":-79.10919952392578,"X":-235.02456665039063,"Z":-282.1385803222656},{"Y":-83.05184936523438,"X":-227.9050750732422,"Z":-259.0917053222656},{"Y":-83.00000762939453,"X":-248.8055877685547,"waitTime":0.22,"Z":-238.42636108398438},{"Y":-81.55177307128906,"X":-238.601806640625,"Z":-231.60491943359376},{"Y":-89.23003387451172,"X":-230.36598205566407,"Z":-217.19810485839845},{"Y":-96.2680435180664,"X":-225.45082092285157,"Z":-211.4920196533203},{"Y":-100.04280090332031,"X":-219.2681884765625,"Z":-201.77084350585938},{"Y":-95.66956329345703,"X":-214.68360900878907,"Z":-181.3822479248047},{"Y":-95.41595458984375,"X":-216.781982421875,"Z":-159.4675750732422},{"Y":-95.87269592285156,"X":-231.07379150390626,"Z":-138.62875366210938},{"Y":-94.74500274658203,"X":-249.0113983154297,"Z":-118.37271118164063},{"Y":-99.81652069091797,"X":-261.99542236328127,"Z":-98.20941162109375},{"Y":-98.55552673339844,"X":-279.041259765625,"Z":-85.19420623779297},{"Y":-95.55258178710938,"X":-290.6869812011719,"Z":-82.38420104980469},{"Y":-95.81491088867188,"X":-310.9895935058594,"Z":-70.90158081054688},{"Y":-92.24469757080078,"X":-321.6689758300781,"Z":-61.269649505615237},{"Y":-91.01455688476563,"X":-348.47467041015627,"Z":-42.22124481201172},{"Y":-91.01564025878906,"X":-329.1878662109375,"Z":-60.129539489746097},{"Y":-89.2813720703125,"X":-327.09100341796877,"Z":-87.0484619140625},{"Y":-84.779296875,"X":-326.7738037109375,"Z":-105.6436767578125},{"Y":-81.99109649658203,"X":-313.77325439453127,"Z":-113.155517578125},{"Y":-76.67230987548828,"X":-306.28253173828127,"Z":-100.8621826171875},{"Y":-72.28472900390625,"X":-291.4124755859375,"Z":-92.3910903930664},{"Y":-69.98668670654297,"X":-270.7921447753906,"Z":-84.01844024658203},{"Y":-71.3525619506836,"X":-251.85108947753907,"Z":-76.48330688476563},{"Y":-71.50276184082031,"X":-227.06439208984376,"Z":-80.39768981933594},{"Y":-71.39520263671875,"X":-251.31092834472657,"Z":-76.3059310913086},{"Y":-71.77449035644531,"X":-267.32720947265627,"Z":-78.61320495605469},{"Y":-74.24156951904297,"X":-272.4139099121094,"Z":-71.63211059570313},{"Y":-95.11537170410156,"X":-272.41387939453127,"Z":-71.63219451904297},{"Y":-97.61564636230469,"X":-262.960693359375,"Z":-88.22897338867188},{"Y":-96.93684387207031,"X":-255.78611755371095,"Z":-105.40406036376953},{"Y":-95.53997802734375,"X":-245.83120727539063,"Z":-129.09695434570313},{"Y":-95.3421630859375,"X":-223.02499389648438,"Z":-128.52000427246095},{"Y":-95.39652252197266,"X":-194.21530151367188,"Z":-107.40668487548828},{"Y":-95.34446716308594,"X":-168.48194885253907,"Z":-81.80047607421875},{"Y":-95.1644515991211,"X":-135.31626892089845,"Z":-49.0128288269043},{"Y":-95.0000228881836,"X":-85.32303619384766,"Z":-29.351627349853517},{"Y":-94.53833770751953,"X":-46.698726654052737,"Z":-21.259023666381837},{"Y":-95.28936004638672,"X":-37.33900833129883,"Z":-5.386425018310547},{"Y":-91.03485107421875,"X":-16.075149536132814,"Z":2.6994011402130129},{"Y":-95.60102844238281,"X":-37.947628021240237,"Z":-5.051972389221191},{"Y":-95.2696762084961,"X":-45.24357986450195,"Z":-24.214237213134767},{"Y":-95.4957275390625,"X":-62.157100677490237,"Z":-41.16522979736328},{"Y":-91.04135131835938,"X":-66.486572265625,"Z":-51.317718505859378},{"Y":-84.86607360839844,"X":-69.42887878417969,"Z":-67.7758560180664},{"Y":-76.93339538574219,"X":-59.070919036865237,"Z":-74.51922607421875},{"Y":-75.00001525878906,"X":-43.24739456176758,"Z":-69.53412628173828},{"Y":-75.00153350830078,"X":-28.057456970214845,"Z":-52.418975830078128},{"Y":-76.69026184082031,"X":-20.81903648376465,"Z":-35.50608825683594},{"Y":-75.00000762939453,"X":7.851291179656982,"Z":-37.161190032958987},{"Y":-74.8431625366211,"X":10.23601245880127,"Z":-58.23441696166992},{"Y":-82.66648864746094,"X":1.4306410551071168,"waitTime":0.22,"Z":-77.75659942626953},{"Y":-76.63348388671875,"X":4.449407577514648,"Z":-93.93130493164063},{"Y":-70.80943298339844,"X":17.122955322265626,"Z":-111.96417236328125},{"Y":-74.87031555175781,"X":28.483449935913087,"Z":-117.97529602050781},{"Y":-75.06192779541016,"X":52.7962646484375,"Z":-134.030517578125},{"Y":-75.39938354492188,"X":71.35850524902344,"Z":-132.94090270996095},{"Y":-71.61602783203125,"X":78.34840393066406,"Z":-115.8716049194336},{"Y":-64.16116333007813,"X":81.9723129272461,"Z":-94.35904693603516},{"Y":-56.39702224731445,"X":78.27147674560547,"Z":-74.16580200195313},{"Y":-49.728294372558597,"X":71.36261749267578,"Z":-62.59131622314453},{"Y":-41.35995864868164,"X":55.369937896728519,"Z":-53.88125228881836},{"Y":-36.20464324951172,"X":43.80089569091797,"Z":-55.62546157836914},{"Y":-35.000003814697269,"X":9.312958717346192,"Z":-71.48139190673828},{"Y":-35.02860641479492,"X":-25.761381149291993,"Z":-86.60227966308594},{"Y":-35.22578811645508,"X":-57.334415435791019,"Z":-103.92764282226563},{"Y":-35.13738250732422,"X":-81.48953247070313,"Z":-135.73748779296876}]}
            ]]

            local success, decoded = pcall(function()
                return game:GetService("HttpService"):JSONDecode(freeTweenData)
            end)

            if success and decoded and decoded.positions then

                Settings.recordedPositions = decoded.positions

                if updateVisualNodes then
                    updateVisualNodes()
                end

                if ASTER.Options.WaypointDropdown and ASTER.getWaypointList then
                    ASTER.Options.WaypointDropdown:SetValues(ASTER.getWaypointList())
                    ASTER.Options.WaypointDropdown:SetValue("None")
                end
            else
                warn("Failed to load Free Tween coordinates. Make sure the JSON format is correct.")
            end
        end)

    ASTER.Tabs.Main:AddToggle("Start Tween", false, function(v)
            Settings.GoldCircuitEnabled = v
            if v then
                startGoldCircuit()
            else
                stopGoldCircuit()
            end
        end)
    ASTER.Tabs.Main:AddSlider("Tween Speed", 1, 21, 18, 1, function(v)
        Settings.GoldSpeed = v
        WALK_SPEED = v
    end)
WALK_SPEED = 18
Settings.GoldSpeed = 18
    ASTER.Tabs.Main:AddSlider("Gold Delay", 0, 2, 0.75, 0.01, function(v)
        Settings.GoldDelay = v
    end)
    ASTER.Tabs.Main:AddToggle("Gold Wait Until Mined", true, function(v)
        Settings.GoldWaitUntilMined = v == true
    end)
    ASTER.Tabs.Main:AddSlider("Gold Max Wait", 3, 60, 20, 1, function(v)
        Settings.GoldMaxWait = v
    end)
    Settings.GoldDetectRange = Settings.GoldDetectRange or 14
    ASTER.Tabs.Main:AddSlider("Gold Detect Range", 5, 80, 14, 1, function(v)
        Settings.GoldDetectRange = v
    end)
    ASTER.Tabs.Main:AddToggle("Visual Waypoints", false, function(v)
        Settings.GoldVisual = v
        updateVisualNodes()
    end)
    ASTER.Tabs.Main:AddToggle("Tween Only (Recommended)", false, function(v)
        Settings.TweenOnly = v
    end)
do
    ASTER.Tabs.Main:AddLabel("Path Management")

    local EMBEDDED_ROUTE_NAME = "5"
    local EMBEDDED_ROUTE_JSON = [==[{"positions":[{"Y":-35.200172424316409,"X":-127.11538696289063,"Z":-145.9087677001953},{"Y":-34.95144271850586,"X":-139.791015625,"Z":-166.66966247558595},{"Y":-33.932823181152347,"X":-143.31504821777345,"Z":-174.77394104003907},{"Y":-24.487215042114259,"X":-146.63343811035157,"Z":-183.0042266845703},{"Y":-21.80611228942871,"X":-145.8102264404297,"Z":-190.6520538330078},{"Y":-21.231874465942384,"X":-140.80636596679688,"Z":-194.6387481689453},{"Y":-30.700057983398439,"X":-134.4620361328125,"Z":-193.28271484375},{"Y":-34.18813705444336,"X":-119.94841003417969,"Z":-184.12782287597657},{"Y":-27.441862106323243,"X":-107.3861083984375,"Z":-179.36253356933595},{"Y":-35.000003814697269,"X":-111.82693481445313,"Z":-170.40472412109376},{"Y":-35.000003814697269,"X":-102.82891082763672,"Z":-158.1606903076172},{"Y":-35.04365539550781,"X":-79.27107238769531,"Z":-134.92593383789063},{"Y":-35.58470153808594,"X":-66.32879638671875,"Z":-122.1530990600586},{"Y":-35.5170783996582,"X":-53.25351333618164,"Z":-109.76818084716797},{"Y":-35.00183868408203,"X":-40.08299255371094,"Z":-97.22576141357422},{"Y":-34.93303298950195,"X":-27.127164840698243,"Z":-89.79827880859375},{"Y":-34.93351364135742,"X":-21.820457458496095,"Z":-86.93006896972656},{"Y":-36.629886627197269,"X":-9.874161720275879,"Z":-82.01268005371094},{"Y":-35.2569465637207,"X":-0.84139484167099,"Z":-78.3850326538086},{"Y":-35.000003814697269,"X":12.761099815368653,"Z":-73.31841278076172},{"Y":-35.06589126586914,"X":30.376258850097658,"Z":-66.28913116455078},{"Y":-35.70327377319336,"X":46.45375442504883,"Z":-59.88577651977539},{"Y":-36.68755340576172,"X":48.586692810058597,"Z":-57.912803649902347},{"Y":-39.489681243896487,"X":52.96553421020508,"Z":-58.15285873413086},{"Y":-40.93656921386719,"X":55.84183120727539,"Z":-56.82392501831055},{"Y":-43.84962463378906,"X":59.68125915527344,"Z":-55.80299377441406},{"Y":-47.0460205078125,"X":65.21498107910156,"Z":-57.58531951904297},{"Y":-49.59457778930664,"X":70.40747833251953,"Z":-62.61623764038086},{"Y":-52.42375183105469,"X":72.93911743164063,"Z":-68.62538146972656},{"Y":-55.58892822265625,"X":73.9955825805664,"Z":-74.4384994506836},{"Y":-58.48631286621094,"X":74.8619155883789,"Z":-82.25238037109375},{"Y":-60.21743392944336,"X":76.14430236816406,"Z":-88.4163589477539},{"Y":-62.76438522338867,"X":75.94927978515625,"Z":-93.9295654296875},{"Y":-67.4958267211914,"X":75.43405151367188,"Z":-102.33184051513672},{"Y":-71.19417572021485,"X":74.32842254638672,"Z":-111.22592163085938},{"Y":-72.6788558959961,"X":72.16184997558594,"Z":-120.27828979492188},{"Y":-74.59910583496094,"X":69.00929260253906,"Z":-127.80120849609375},{"Y":-75.33142852783203,"X":62.45353698730469,"Z":-132.5701446533203},{"Y":-75.06645965576172,"X":55.31161880493164,"Z":-133.96084594726563},{"Y":-75.02245330810547,"X":45.38873291015625,"Z":-131.2076416015625},{"Y":-75.00000762939453,"X":37.14619445800781,"Z":-127.24678039550781},{"Y":-75.06132507324219,"X":30.090946197509767,"Z":-121.66617584228516},{"Y":-73.72555541992188,"X":25.417375564575197,"Z":-115.65186309814453},{"Y":-71.57548522949219,"X":21.84725570678711,"Z":-111.4046859741211},{"Y":-71.01688385009766,"X":20.075679779052736,"Z":-108.45911407470703},{"Y":-73.89055633544922,"X":17.89089584350586,"Z":-105.94225311279297},{"Y":-75.9335708618164,"X":13.944907188415528,"Z":-101.83480072021485},{"Y":-77.35223388671875,"X":9.48249626159668,"Z":-96.1761474609375},{"Y":-80.29497528076172,"X":6.815572738647461,"Z":-91.34197235107422},{"Y":-82.97765350341797,"X":2.5394127368927,"Z":-85.17523956298828},{"Y":-82.46599578857422,"X":2.8963072299957277,"Z":-76.65235137939453},{"Y":-80.0101089477539,"X":3.762794256210327,"Z":-69.7983169555664},{"Y":-76.72052001953125,"X":5.379025936126709,"Z":-62.47624969482422},{"Y":-75.27288818359375,"X":10.099550247192383,"Z":-54.472476959228519},{"Y":-75.0504150390625,"X":10.720209121704102,"Z":-43.686126708984378},{"Y":-75.00001525878906,"X":6.5490264892578129,"Z":-36.033077239990237},{"Y":-75.04844665527344,"X":-3.812410831451416,"Z":-35.57367706298828},{"Y":-75.22642517089844,"X":-12.82418441772461,"Z":-36.81919860839844},{"Y":-76.13790130615235,"X":-21.805818557739259,"Z":-40.37363052368164},{"Y":-75.60755157470703,"X":-26.226736068725587,"Z":-44.738040924072269},{"Y":-75.00666809082031,"X":-29.206710815429689,"Z":-52.258182525634769},{"Y":-75.00523376464844,"X":-32.93906784057617,"Z":-58.117095947265628},{"Y":-75.00001525878906,"X":-38.69208908081055,"Z":-63.5067138671875},{"Y":-75.00001525878906,"X":-46.293087005615237,"Z":-69.7999038696289},{"Y":-75.03598022460938,"X":-51.871402740478519,"Z":-72.67539978027344},{"Y":-76.50691986083985,"X":-57.86912155151367,"Z":-74.39759826660156},{"Y":-76.768310546875,"X":-59.6989860534668,"Z":-72.07643127441406},{"Y":-81.54940795898438,"X":-62.4913444519043,"Z":-68.71109008789063},{"Y":-86.79821014404297,"X":-66.00936889648438,"Z":-63.43706512451172},{"Y":-89.3389892578125,"X":-65.81868743896485,"Z":-58.07548522949219},{"Y":-91.11959838867188,"X":-63.7754020690918,"Z":-52.084476470947269},{"Y":-93.72315979003906,"X":-58.788818359375,"Z":-41.79557800292969},{"Y":-95.0779800415039,"X":-55.731990814208987,"Z":-37.97810745239258},{"Y":-95.20124816894531,"X":-50.84624099731445,"Z":-30.932573318481447},{"Y":-94.88368225097656,"X":-42.435638427734378,"Z":-20.83847999572754},{"Y":-95.0985336303711,"X":-39.099605560302737,"Z":-14.353784561157227},{"Y":-92.96502685546875,"X":-27.13096046447754,"Z":-7.563878536224365},{"Y":-94.74370574951172,"X":-31.581300735473634,"Z":-8.698981285095215},{"Y":-95.64067077636719,"X":-38.631568908691409,"Z":-11.226015090942383},{"Y":-94.2427978515625,"X":-44.72114181518555,"Z":-17.788341522216798},{"Y":-94.14376068115235,"X":-46.72057342529297,"Z":-19.713825225830079},{"Y":-94.24919128417969,"X":-50.712520599365237,"Z":-20.590534210205079},{"Y":-95.43464660644531,"X":-56.897579193115237,"Z":-22.239702224731447},{"Y":-95.37749481201172,"X":-65.73574829101563,"Z":-24.502920150756837},{"Y":-95.30870056152344,"X":-94.8011703491211,"Z":-35.28067398071289},{"Y":-95.20991516113281,"X":-94.91608428955078,"Z":-35.32646179199219},{"Y":-95.54659271240235,"X":-110.13668823242188,"Z":-41.50413131713867},{"Y":-95.77704620361328,"X":-134.69406127929688,"Z":-53.21560287475586},{"Y":-95.22758483886719,"X":-143.59364318847657,"Z":-58.47604751586914},{"Y":-95.18110656738281,"X":-157.69981384277345,"Z":-67.83914184570313},{"Y":-95.3884506225586,"X":-172.64215087890626,"Z":-78.48036193847656},{"Y":-95.1025390625,"X":-185.25086975097657,"Z":-88.61800384521485},{"Y":-95.279052734375,"X":-197.35037231445313,"Z":-97.6330795288086},{"Y":-95.00225830078125,"X":-212.23028564453126,"Z":-102.74871063232422},{"Y":-92.31501007080078,"X":-217.47503662109376,"Z":-102.54165649414063},{"Y":-89.30288696289063,"X":-218.878173828125,"Z":-100.1025619506836},{"Y":-87.15621948242188,"X":-222.91090393066407,"Z":-95.8911361694336},{"Y":-86.59174346923828,"X":-227.68800354003907,"Z":-93.44901275634766},{"Y":-86.3244857788086,"X":-230.5103302001953,"Z":-94.38806915283203},{"Y":-85.25167083740235,"X":-234.1280517578125,"Z":-97.63946533203125},{"Y":-85.8358383178711,"X":-233.58213806152345,"Z":-96.22228240966797},{"Y":-87.38932037353516,"X":-236.42755126953126,"Z":-95.23226928710938},{"Y":-89.0209732055664,"X":-239.28489685058595,"Z":-94.67649841308594},{"Y":-92.06761932373047,"X":-242.1452178955078,"Z":-94.63947296142578},{"Y":-95.38704681396485,"X":-246.48294067382813,"Z":-92.98495483398438},{"Y":-95.4490966796875,"X":-253.81304931640626,"Z":-89.554931640625},{"Y":-95.61763000488281,"X":-259.5924072265625,"Z":-87.04479217529297},{"Y":-98.00439453125,"X":-265.4167785644531,"Z":-84.46880340576172},{"Y":-99.26764678955078,"X":-269.61334228515627,"Z":-83.14600372314453},{"Y":-99.02745056152344,"X":-276.0867919921875,"Z":-80.7872314453125},{"Y":-97.94589233398438,"X":-284.9393615722656,"Z":-76.22332763671875},{"Y":-98.90709686279297,"X":-286.6085510253906,"Z":-73.68739318847656},{"Y":-96.06635284423828,"X":-291.0561218261719,"Z":-73.28999328613281},{"Y":-95.18375396728516,"X":-295.9610595703125,"Z":-71.70403289794922},{"Y":-95.1768798828125,"X":-306.4212341308594,"Z":-69.60155487060547},{"Y":-94.3653793334961,"X":-314.003662109375,"Z":-65.5657958984375},{"Y":-91.01563262939453,"X":-332.88671875,"Z":-52.01259231567383},{"Y":-91.01563262939453,"X":-329.99700927734377,"Z":-56.00105285644531},{"Y":-91.6180191040039,"X":-326.5920104980469,"Z":-58.609588623046878},{"Y":-92.00896453857422,"X":-321.955810546875,"Z":-63.44392395019531},{"Y":-94.90386199951172,"X":-317.7585754394531,"Z":-65.9827880859375},{"Y":-94.92790985107422,"X":-312.8907775878906,"Z":-67.85557556152344},{"Y":-95.79222869873047,"X":-308.470947265625,"Z":-70.84195709228516},{"Y":-95.05797576904297,"X":-303.8531188964844,"Z":-75.67123413085938},{"Y":-95.10899353027344,"X":-300.6355895996094,"Z":-81.04539489746094},{"Y":-95.0165023803711,"X":-295.3440246582031,"Z":-87.11111450195313},{"Y":-95.09793853759766,"X":-288.1673889160156,"Z":-96.05264282226563},{"Y":-94.73368072509766,"X":-282.41986083984377,"Z":-105.43706512451172},{"Y":-93.48997497558594,"X":-278.531494140625,"Z":-110.31470489501953},{"Y":-95.09870910644531,"X":-275.50848388671877,"Z":-113.48338317871094},{"Y":-95.15406799316406,"X":-271.7240295410156,"Z":-117.23706817626953},{"Y":-95.0058364868164,"X":-265.0184631347656,"Z":-126.0241928100586},{"Y":-95.93844604492188,"X":-260.0666198730469,"Z":-132.5458984375},{"Y":-95.11720275878906,"X":-251.740234375,"Z":-139.45077514648438},{"Y":-95.04246520996094,"X":-243.68594360351563,"Z":-148.72842407226563},{"Y":-95.46965026855469,"X":-234.91351318359376,"Z":-157.98513793945313},{"Y":-95.31824493408203,"X":-226.44410705566407,"Z":-166.62222290039063},{"Y":-95.38156127929688,"X":-222.26589965820313,"Z":-172.7139892578125},{"Y":-95.42133331298828,"X":-220.82565307617188,"Z":-177.69717407226563},{"Y":-97.69954681396485,"X":-221.20355224609376,"Z":-183.7405242919922},{"Y":-99.82412719726563,"X":-225.7449951171875,"Z":-191.5548553466797},{"Y":-99.14374542236328,"X":-229.0948944091797,"Z":-197.26609802246095},{"Y":-97.5513916015625,"X":-231.59165954589845,"Z":-201.3795623779297},{"Y":-95.52567291259766,"X":-235.452392578125,"Z":-205.2772216796875},{"Y":-95.14883422851563,"X":-239.47412109375,"Z":-210.82508850097657},{"Y":-95.01182556152344,"X":-242.4380340576172,"Z":-219.77882385253907},{"Y":-95.62877655029297,"X":-244.51483154296876,"Z":-225.77154541015626},{"Y":-88.48075103759766,"X":-244.37945556640626,"Z":-230.17225646972657},{"Y":-87.98904418945313,"X":-244.45021057128907,"Z":-230.2062530517578},{"Y":-84.39086151123047,"X":-246.72763061523438,"Z":-234.84194946289063},{"Y":-83.00211334228516,"X":-247.86891174316407,"Z":-240.84666442871095},{"Y":-83.06329345703125,"X":-240.7316131591797,"Z":-246.23976135253907},{"Y":-83.09381866455078,"X":-230.1736297607422,"Z":-250.56680297851563},{"Y":-83.00857543945313,"X":-222.8251953125,"Z":-253.6243896484375},{"Y":-84.29207611083985,"X":-215.521728515625,"Z":-254.6692352294922},{"Y":-86.75212860107422,"X":-208.08596801757813,"Z":-255.16384887695313},{"Y":-87.35938262939453,"X":-190.8312530517578,"Z":-258.8103942871094},{"Y":-87.35938262939453,"X":-176.76171875,"Z":-261.3516845703125},{"Y":-87.35938262939453,"X":-170.90354919433595,"Z":-261.9703063964844},{"Y":-87.36454010009766,"X":-162.23074340820313,"Z":-262.0455322265625},{"Y":-87.30305480957031,"X":-156.0056610107422,"Z":-265.3402404785156},{"Y":-87.35938262939453,"X":-146.29310607910157,"Z":-271.3807067871094},{"Y":-87.35938262939453,"X":-137.57298278808595,"Z":-277.6025085449219},{"Y":-88.37824249267578,"X":-129.09967041015626,"Z":-283.6488342285156},{"Y":-90.63358306884766,"X":-125.04290771484375,"Z":-286.5411376953125},{"Y":-91.12584686279297,"X":-120.08241271972656,"Z":-292.30157470703127},{"Y":-92.5192642211914,"X":-118.89540100097656,"Z":-302.3857116699219},{"Y":-95.46027374267578,"X":-117.47434997558594,"Z":-313.2869567871094},{"Y":-96.96993255615235,"X":-118.33184814453125,"Z":-317.43243408203127},{"Y":-100.22528839111328,"X":-120.45807647705078,"Z":-328.4774475097656},{"Y":-102.96926879882813,"X":-122.14581298828125,"Z":-336.26666259765627},{"Y":-103.05770111083985,"X":-125.22838592529297,"Z":-346.6028137207031},{"Y":-103.00000762939453,"X":-136.71902465820313,"Z":-351.5445861816406},{"Y":-103.00000762939453,"X":-136.71902465820313,"Z":-351.5445861816406},{"Y":-103.00000762939453,"X":-144.86769104003907,"Z":-352.9888916015625},{"Y":-101.13612365722656,"X":-145.85133361816407,"Z":-360.3791198730469},{"Y":-98.49126434326172,"X":-146.59666442871095,"Z":-365.6459045410156},{"Y":-100.81442260742188,"X":-147.7924041748047,"Z":-369.94775390625},{"Y":-101.10242462158203,"X":-148.36695861816407,"Z":-375.2133483886719},{"Y":-103.00000762939453,"X":-149.88954162597657,"Z":-381.9173583984375},{"Y":-103.00000762939453,"X":-145.1403045654297,"Z":-400.9230651855469},{"Y":-103.00000762939453,"X":-142.0845184326172,"Z":-408.91766357421877},{"Y":-103.00000762939453,"X":-138.65945434570313,"Z":-416.47088623046877},{"Y":-100.76055908203125,"X":-144.7631378173828,"Z":-422.018798828125},{"Y":-97.20696258544922,"X":-150.52719116210938,"Z":-425.9935607910156},{"Y":-96.76589965820313,"X":-156.16510009765626,"Z":-429.43115234375},{"Y":-94.77669525146485,"X":-163.31300354003907,"Z":-431.4628601074219},{"Y":-95.30088806152344,"X":-168.51681518554688,"Z":-434.3735046386719},{"Y":-95.80716705322266,"X":-170.49996948242188,"Z":-437.097412109375},{"Y":-83.86056518554688,"X":-173.37893676757813,"Z":-439.1968688964844},{"Y":-76.04844665527344,"X":-175.99185180664063,"Z":-442.6613464355469},{"Y":-70.46123504638672,"X":-180.02688598632813,"Z":-441.8245544433594},{"Y":-69.2658462524414,"X":-181.22891235351563,"Z":-445.7892150878906},{"Y":-68.28211212158203,"X":-183.29376220703126,"Z":-449.6356201171875},{"Y":-67.24351501464844,"X":-186.4100799560547,"Z":-458.318603515625},{"Y":-66.74244689941406,"X":-189.03970336914063,"Z":-465.4115295410156},{"Y":-64.59182739257813,"X":-191.3179168701172,"Z":-471.6329345703125},{"Y":-63.7956657409668,"X":-193.5601806640625,"Z":-477.7341613769531},{"Y":-63.00299835205078,"X":-197.02984619140626,"Z":-486.9695129394531},{"Y":-62.678314208984378,"X":-198.73402404785157,"Z":-493.0776062011719},{"Y":-62.290645599365237,"X":-199.21775817871095,"Z":-500.0246887207031},{"Y":-60.178802490234378,"X":-200.62741088867188,"Z":-504.93548583984377},{"Y":-59.32793426513672,"X":-202.8759307861328,"Z":-510.2333984375},{"Y":-59.00151443481445,"X":-205.3984832763672,"Z":-514.712890625},{"Y":-59.0000114440918,"X":-207.84445190429688,"Z":-519.203857421875},{"Y":-59.00000762939453,"X":-210.44793701171876,"Z":-524.4611206054688},{"Y":-59.64311981201172,"X":-207.5582733154297,"Z":-531.1919555664063},{"Y":-59.82799530029297,"X":-205.5968017578125,"Z":-536.6119995117188},{"Y":-60.31904602050781,"X":-200.94775390625,"Z":-540.5704345703125},{"Y":-62.139793395996097,"X":-195.75204467773438,"Z":-544.42236328125},{"Y":-62.458988189697269,"X":-190.65121459960938,"Z":-548.85986328125},{"Y":-62.813838958740237,"X":-187.56002807617188,"Z":-551.7732543945313},{"Y":-63.66682052612305,"X":-181.9439239501953,"Z":-554.0645141601563},{"Y":-63.527862548828128,"X":-179.42190551757813,"Z":-558.3579711914063},{"Y":-63.352500915527347,"X":-177.41607666015626,"Z":-563.9832153320313},{"Y":-63.41073226928711,"X":-176.241455078125,"Z":-570.5111694335938},{"Y":-64.49991607666016,"X":-175.9480438232422,"Z":-577.015869140625},{"Y":-63.06900405883789,"X":-175.98338317871095,"Z":-585.5447387695313},{"Y":-62.73409652709961,"X":-177.16867065429688,"Z":-591.5563354492188},{"Y":-63.32291793823242,"X":-178.06787109375,"Z":-597.5197143554688},{"Y":-64.02328491210938,"X":-180.26329040527345,"Z":-603.1925048828125},{"Y":-63.814388275146487,"X":-185.46737670898438,"Z":-607.4746704101563},{"Y":-63.000003814697269,"X":-190.39285278320313,"Z":-611.1945190429688},{"Y":-61.1368408203125,"X":-198.29006958007813,"Z":-616.773681640625},{"Y":-61.19588851928711,"X":-211.95291137695313,"Z":-623.9490966796875},{"Y":-61.202476501464847,"X":-206.43112182617188,"Z":-622.0658569335938},{"Y":-62.23707580566406,"X":-201.0540008544922,"Z":-620.2713623046875},{"Y":-63.02888870239258,"X":-195.5946502685547,"Z":-618.2084350585938},{"Y":-63.56769943237305,"X":-191.4556427001953,"Z":-615.5661010742188},{"Y":-63.138919830322269,"X":-186.8408966064453,"Z":-612.2530517578125},{"Y":-64.28536987304688,"X":-180.99203491210938,"Z":-606.8514404296875},{"Y":-63.7240104675293,"X":-177.5050506591797,"Z":-600.517822265625},{"Y":-63.3953742980957,"X":-175.6982421875,"Z":-593.75244140625},{"Y":-63.077919006347659,"X":-174.42970275878907,"Z":-589.0972900390625},{"Y":-63.36560821533203,"X":-174.081787109375,"Z":-583.1607666015625},{"Y":-64.39920806884766,"X":-174.2303924560547,"Z":-574.9007568359375},{"Y":-63.23647689819336,"X":-175.58212280273438,"Z":-567.0382690429688},{"Y":-63.42551803588867,"X":-179.4842987060547,"Z":-557.9282836914063},{"Y":-63.25535202026367,"X":-183.52920532226563,"Z":-552.4226684570313},{"Y":-62.81668472290039,"X":-190.70440673828126,"Z":-547.7193603515625},{"Y":-61.94496536254883,"X":-196.6112060546875,"Z":-543.4088745117188},{"Y":-60.464542388916019,"X":-201.5054473876953,"Z":-540.1172485351563},{"Y":-59.615318298339847,"X":-206.31777954101563,"Z":-535.6041870117188},{"Y":-60.316322326660159,"X":-217.06204223632813,"Z":-538.336669921875},{"Y":-59.0000114440918,"X":-226.6914825439453,"Z":-540.95947265625},{"Y":-59.572731018066409,"X":-232.6551513671875,"Z":-544.1929931640625},{"Y":-58.89931869506836,"X":-243.751220703125,"Z":-548.5256958007813},{"Y":-57.34613037109375,"X":-250.2448272705078,"Z":-550.66552734375},{"Y":-56.45731735229492,"X":-255.5286102294922,"Z":-553.22021484375},{"Y":-56.15519714355469,"X":-261.39471435546877,"Z":-555.45458984375},{"Y":-56.505672454833987,"X":-269.15496826171877,"Z":-558.078125},{"Y":-57.65422058105469,"X":-275.9513854980469,"Z":-561.122802734375},{"Y":-56.96424865722656,"X":-284.8126220703125,"Z":-564.08642578125},{"Y":-56.983333587646487,"X":-284.9429626464844,"Z":-564.1267700195313},{"Y":-56.82405471801758,"X":-292.3406066894531,"Z":-565.6107177734375},{"Y":-55.00723648071289,"X":-302.4510192871094,"Z":-566.904541015625},{"Y":-54.15977478027344,"X":-307.3827819824219,"Z":-567.1519775390625},{"Y":-51.07828140258789,"X":-312.39459228515627,"Z":-568.4590454101563},{"Y":-49.016868591308597,"X":-315.4921569824219,"Z":-567.5194091796875},{"Y":-48.28683090209961,"X":-322.824951171875,"Z":-567.490234375},{"Y":-47.344970703125,"X":-331.6112060546875,"Z":-566.8800048828125},{"Y":-47.12678146362305,"X":-341.30462646484377,"Z":-566.5213012695313},{"Y":-47.0000114440918,"X":-349.1828308105469,"Z":-565.2504272460938},{"Y":-46.447654724121097,"X":-359.44329833984377,"Z":-563.3630981445313},{"Y":-43.81968307495117,"X":-374.18994140625,"Z":-559.7761840820313},{"Y":-43.89230728149414,"X":-369.431640625,"Z":-560.6578369140625},{"Y":-45.12745666503906,"X":-363.57623291015627,"Z":-563.3161010742188},{"Y":-46.59803771972656,"X":-359.2049560546875,"Z":-563.85205078125},{"Y":-47.0000114440918,"X":-352.8284912109375,"Z":-564.6251831054688},{"Y":-47.000003814697269,"X":-347.64923095703127,"Z":-565.5892944335938},{"Y":-47.13393020629883,"X":-341.6055603027344,"Z":-566.1532592773438},{"Y":-47.26200485229492,"X":-335.0334167480469,"Z":-568.0886840820313},{"Y":-47.44114685058594,"X":-329.3523254394531,"Z":-567.7783203125},{"Y":-48.1494255065918,"X":-324.7779235839844,"Z":-568.2584228515625},{"Y":-48.508460998535159,"X":-319.99627685546877,"Z":-568.1093139648438},{"Y":-49.13642120361328,"X":-315.4711608886719,"Z":-568.2352905273438},{"Y":-51.85264205932617,"X":-311.59716796875,"Z":-568.5387573242188},{"Y":-54.87385177612305,"X":-307.6493835449219,"Z":-568.1574096679688},{"Y":-55.3621940612793,"X":-302.8427734375,"Z":-568.4052734375},{"Y":-57.02554702758789,"X":-290.07720947265627,"Z":-565.860107421875},{"Y":-57.321537017822269,"X":-278.542236328125,"Z":-562.580078125},{"Y":-57.445152282714847,"X":-270.827392578125,"Z":-559.4599609375},{"Y":-56.286224365234378,"X":-264.66168212890627,"Z":-557.3670654296875},{"Y":-56.26775360107422,"X":-257.70947265625,"Z":-553.825439453125},{"Y":-57.17439651489258,"X":-251.8545379638672,"Z":-551.1435546875},{"Y":-57.640350341796878,"X":-247.33480834960938,"Z":-550.1499633789063},{"Y":-59.14896011352539,"X":-241.229736328125,"Z":-547.7415771484375},{"Y":-59.242088317871097,"X":-236.28579711914063,"Z":-545.7935180664063},{"Y":-59.37650680541992,"X":-230.28863525390626,"Z":-543.4661865234375},{"Y":-59.000003814697269,"X":-226.30740356445313,"Z":-540.4559326171875},{"Y":-59.612422943115237,"X":-220.17324829101563,"Z":-535.5726928710938},{"Y":-59.04669189453125,"X":-214.8605194091797,"Z":-531.0310668945313},{"Y":-59.01347732543945,"X":-211.8662872314453,"Z":-526.9235229492188},{"Y":-59.000003814697269,"X":-209.5055694580078,"Z":-522.4961547851563},{"Y":-59.000003814697269,"X":-207.05174255371095,"Z":-517.881103515625},{"Y":-59.264854431152347,"X":-203.041259765625,"Z":-510.9551696777344},{"Y":-60.10297775268555,"X":-200.97036743164063,"Z":-505.1920166015625},{"Y":-62.75037384033203,"X":-198.9687957763672,"Z":-499.4559020996094},{"Y":-63.24905776977539,"X":-193.30291748046876,"Z":-486.3470458984375},{"Y":-63.38013458251953,"X":-191.65655517578126,"Z":-481.4469909667969},{"Y":-64.10955810546875,"X":-189.9131317138672,"Z":-476.0428771972656},{"Y":-65.89789581298828,"X":-187.49147033691407,"Z":-469.1298828125},{"Y":-67.04338836669922,"X":-184.78468322753907,"Z":-465.32958984375},{"Y":-67.26687622070313,"X":-182.0261993408203,"Z":-460.62249755859377},{"Y":-67.74453735351563,"X":-180.1875762939453,"Z":-456.1526794433594},{"Y":-69.74339294433594,"X":-177.01202392578126,"Z":-449.2494812011719},{"Y":-79.74627685546875,"X":-173.9616241455078,"Z":-447.4073791503906},{"Y":-87.43121337890625,"X":-173.59518432617188,"Z":-447.42218017578127},{"Y":-97.65748596191406,"X":-171.7164764404297,"Z":-448.8951416015625},{"Y":-98.09590148925781,"X":-164.6468963623047,"Z":-453.08929443359377},{"Y":-101.65953826904297,"X":-158.0391387939453,"Z":-458.8531188964844},{"Y":-102.46603393554688,"X":-155.5732879638672,"Z":-465.1424255371094},{"Y":-100.82835388183594,"X":-154.70046997070313,"Z":-470.3881530761719},{"Y":-100.31939697265625,"X":-153.71163940429688,"Z":-477.1285705566406},{"Y":-99.27128601074219,"X":-154.0566864013672,"Z":-483.8548583984375},{"Y":-99.62100219726563,"X":-156.71546936035157,"Z":-491.1533203125},{"Y":-98.96883392333985,"X":-160.36277770996095,"Z":-495.5070495605469},{"Y":-99.79095458984375,"X":-163.8101806640625,"Z":-500.4339599609375},{"Y":-98.93743133544922,"X":-167.73947143554688,"Z":-502.4769287109375},{"Y":-100.14273071289063,"X":-171.01258850097657,"Z":-504.48211669921877},{"Y":-101.61492919921875,"X":-174.79689025878907,"Z":-504.9563903808594},{"Y":-103.00000762939453,"X":-180.6370849609375,"Z":-505.9040832519531},{"Y":-103.01583862304688,"X":-184.98912048339845,"Z":-505.07012939453127},{"Y":-103.61245727539063,"X":-189.76242065429688,"Z":-502.40545654296877},{"Y":-103.47999572753906,"X":-192.02926635742188,"Z":-498.1982421875},{"Y":-103.30896759033203,"X":-194.09228515625,"Z":-493.8262634277344},{"Y":-103.12577819824219,"X":-194.24163818359376,"Z":-488.2802429199219},{"Y":-103.00000762939453,"X":-193.27169799804688,"Z":-482.6933898925781},{"Y":-103.1325912475586,"X":-193.02549743652345,"Z":-476.7752685546875},{"Y":-103.92680358886719,"X":-188.04367065429688,"Z":-455.97003173828127},{"Y":-103.53252410888672,"X":-189.24998474121095,"Z":-463.944580078125},{"Y":-103.6652603149414,"X":-189.23426818847657,"Z":-461.74627685546877},{"Y":-103.40560150146485,"X":-190.54135131835938,"Z":-468.6949462890625},{"Y":-103.30650329589844,"X":-190.59259033203126,"Z":-473.95819091796877},{"Y":-103.11180114746094,"X":-191.74282836914063,"Z":-478.0567932128906},{"Y":-103.00000762939453,"X":-192.79946899414063,"Z":-484.1268310546875},{"Y":-103.21089935302735,"X":-194.37750244140626,"Z":-490.1123962402344},{"Y":-103.28922271728516,"X":-194.64759826660157,"Z":-495.2102355957031},{"Y":-103.33197021484375,"X":-188.67269897460938,"Z":-504.1286315917969},{"Y":-103.0000228881836,"X":-184.55014038085938,"Z":-506.5970153808594},{"Y":-103.00000762939453,"X":-180.38400268554688,"Z":-506.58123779296877},{"Y":-102.87371063232422,"X":-176.34750366210938,"Z":-506.178466796875},{"Y":-100.74671936035156,"X":-172.45008850097657,"Z":-505.1723327636719},{"Y":-99.36065673828125,"X":-169.1734161376953,"Z":-504.49017333984377},{"Y":-99.25971221923828,"X":-165.71566772460938,"Z":-502.1513366699219},{"Y":-100.14949798583985,"X":-162.4173583984375,"Z":-500.062255859375},{"Y":-100.26713562011719,"X":-160.0631561279297,"Z":-498.8113098144531},{"Y":-99.93343353271485,"X":-158.33229064941407,"Z":-498.0462341308594},{"Y":-102.15921783447266,"X":-156.21298217773438,"Z":-496.6521301269531},{"Y":-102.9714126586914,"X":-153.56703186035157,"Z":-494.7513427734375},{"Y":-102.12173461914063,"X":-149.4110565185547,"Z":-491.4580993652344},{"Y":-101.30577087402344,"X":-145.6412811279297,"Z":-490.9678649902344},{"Y":-97.20231628417969,"X":-143.7764892578125,"Z":-489.89031982421877},{"Y":-95.60545349121094,"X":-139.08172607421876,"Z":-488.4168701171875},{"Y":-102.31900024414063,"X":-135.48126220703126,"Z":-489.5281066894531},{"Y":-102.979248046875,"X":-133.2329559326172,"Z":-489.2873229980469},{"Y":-103.00001525878906,"X":-127.97173309326172,"Z":-487.975341796875},{"Y":-103.00001525878906,"X":-79.37040710449219,"Z":-469.1907043457031},{"Y":-102.1550521850586,"X":-66.7137680053711,"Z":-464.466064453125},{"Y":-103.00753784179688,"X":-33.53963851928711,"Z":-443.9488220214844},{"Y":-103.00001525878906,"X":-7.2169084548950199,"Z":-423.7174072265625},{"Y":-103.00001525878906,"X":5.645600318908691,"Z":-414.6301574707031},{"Y":-102.96369934082031,"X":10.715620994567871,"Z":-412.7769470214844},{"Y":-101.1667709350586,"X":14.230298042297364,"Z":-410.8058776855469},{"Y":-99.53105163574219,"X":17.176307678222658,"Z":-406.2011413574219},{"Y":-99.00833129882813,"X":19.262603759765626,"Z":-399.86529541015627},{"Y":-99.00000762939453,"X":21.457107543945314,"Z":-392.7776794433594},{"Y":-99.00000762939453,"X":23.818410873413087,"Z":-385.7351379394531},{"Y":-99.764404296875,"X":27.23123550415039,"Z":-380.1177062988281},{"Y":-99.1318130493164,"X":30.974790573120118,"Z":-376.6280517578125},{"Y":-99.14682006835938,"X":34.79861068725586,"Z":-372.4682312011719},{"Y":-99.02922821044922,"X":39.21270751953125,"Z":-369.3519287109375},{"Y":-99.00000762939453,"X":44.148197174072269,"Z":-366.4522399902344},{"Y":-99.00000762939453,"X":46.56171798706055,"Z":-365.0018005371094},{"Y":-99.01284790039063,"X":39.77490234375,"Z":-369.3465270996094},{"Y":-99.10360717773438,"X":34.365623474121097,"Z":-373.3647155761719},{"Y":-99.22843170166016,"X":30.29146957397461,"Z":-377.0910949707031},{"Y":-99.40595245361328,"X":25.668378829956056,"Z":-382.42327880859377},{"Y":-98.95723724365235,"X":22.92344856262207,"Z":-387.7895202636719},{"Y":-98.97080993652344,"X":20.7519474029541,"Z":-391.99932861328127},{"Y":-99.00000762939453,"X":20.534090042114259,"Z":-394.623779296875},{"Y":-99.00000762939453,"X":19.596723556518556,"Z":-398.92401123046877},{"Y":-99.1170654296875,"X":18.4244384765625,"Z":-402.33209228515627},{"Y":-99.90562438964844,"X":16.596240997314454,"Z":-407.9329833984375},{"Y":-101.84940338134766,"X":13.024261474609375,"Z":-411.8129577636719},{"Y":-103.0000228881836,"X":9.794367790222168,"Z":-414.4010925292969},{"Y":-103.00000762939453,"X":5.163547039031982,"Z":-415.0447692871094},{"Y":-103.00000762939453,"X":-0.8169200420379639,"Z":-413.1485595703125},{"Y":-103.00000762939453,"X":-8.876054763793946,"Z":-409.63836669921877},{"Y":-103.00000762939453,"X":-18.952497482299806,"Z":-406.2098388671875},{"Y":-103.00000762939453,"X":-28.91268539428711,"Z":-402.0211181640625},{"Y":-103.00000762939453,"X":-37.31935501098633,"Z":-398.632080078125},{"Y":-103.00000762939453,"X":-41.474361419677737,"Z":-397.76019287109377},{"Y":-103.76359558105469,"X":-45.41937255859375,"Z":-393.21075439453127},{"Y":-105.99127960205078,"X":-48.10205078125,"Z":-389.1835021972656},{"Y":-107.13615417480469,"X":-49.983612060546878,"Z":-384.22442626953127},{"Y":-107.13345336914063,"X":-49.83464431762695,"Z":-376.1189880371094},{"Y":-99.47006225585938,"X":-48.00266647338867,"Z":-374.5227966308594},{"Y":-93.28038024902344,"X":-44.70210647583008,"Z":-370.5268859863281},{"Y":-91.69461822509766,"X":-41.874755859375,"Z":-368.1977844238281},{"Y":-92.01753997802735,"X":-36.18212127685547,"Z":-364.0909423828125},{"Y":-92.3974380493164,"X":-30.00266456604004,"Z":-360.2303161621094},{"Y":-92.50655364990235,"X":-17.300344467163087,"Z":-351.6179504394531},{"Y":-92.63719177246094,"X":-4.8089094161987309,"Z":-344.04229736328127},{"Y":-91.33001708984375,"X":5.89284610748291,"Z":-337.8616027832031},{"Y":-91.00006103515625,"X":16.35256004333496,"Z":-332.51617431640627},{"Y":-88.78372192382813,"X":19.49407958984375,"Z":-331.183349609375},{"Y":-87.59981536865235,"X":23.87333869934082,"Z":-329.375732421875},{"Y":-85.31491088867188,"X":30.50506591796875,"Z":-326.5985107421875},{"Y":-85.1034927368164,"X":35.61722946166992,"Z":-324.2135009765625},{"Y":-85.4720230102539,"X":42.46598815917969,"Z":-322.36639404296877},{"Y":-85.97750854492188,"X":50.726444244384769,"Z":-322.1221618652344},{"Y":-85.48037719726563,"X":57.31975555419922,"Z":-322.4278564453125},{"Y":-86.45069122314453,"X":64.56475067138672,"Z":-322.33660888671877},{"Y":-87.36480712890625,"X":72.86872863769531,"Z":-322.92657470703127},{"Y":-88.13557434082031,"X":82.82614135742188,"Z":-323.2299499511719},{"Y":-88.36054229736328,"X":90.1399917602539,"Z":-323.8626403808594},{"Y":-88.57638549804688,"X":98.1268539428711,"Z":-325.11273193359377},{"Y":-88.92693328857422,"X":109.1222152709961,"Z":-326.0740966796875},{"Y":-91.00001525878906,"X":118.00956726074219,"Z":-327.6623229980469},{"Y":-91.0508804321289,"X":127.82832336425781,"Z":-329.6975402832031},{"Y":-91.294189453125,"X":136.45968627929688,"Z":-332.22021484375},{"Y":-91.26464080810547,"X":145.07260131835938,"Z":-336.8603515625},{"Y":-91.13737487792969,"X":158.0054168701172,"Z":-340.6458435058594},{"Y":-91.16543579101563,"X":158.15371704101563,"Z":-340.6817321777344},{"Y":-91.69536590576172,"X":165.78897094726563,"Z":-343.2317199707031},{"Y":-91.81916809082031,"X":173.3730926513672,"Z":-346.3667297363281},{"Y":-91.093505859375,"X":181.56753540039063,"Z":-349.87030029296877},{"Y":-88.51024627685547,"X":189.40992736816407,"Z":-354.0649108886719},{"Y":-87.0916976928711,"X":199.33592224121095,"Z":-359.0181579589844},{"Y":-85.81298065185547,"X":208.46507263183595,"Z":-364.5061950683594},{"Y":-83.01431274414063,"X":216.1343536376953,"Z":-369.0608825683594},{"Y":-81.1216049194336,"X":224.5341033935547,"Z":-373.32330322265627},{"Y":-75.70710754394531,"X":236.02658081054688,"Z":-381.904541015625},{"Y":-75.31632995605469,"X":242.0084228515625,"Z":-385.8116455078125},{"Y":-71.89549255371094,"X":249.60986328125,"Z":-391.6736145019531},{"Y":-71.40152740478516,"X":258.43353271484377,"Z":-395.08856201171877},{"Y":-71.42951965332031,"X":267.34393310546877,"Z":-398.74261474609377},{"Y":-71.56745147705078,"X":276.4364013671875,"Z":-402.27667236328127},{"Y":-71.31961822509766,"X":284.67913818359377,"Z":-406.3052062988281},{"Y":-71.47847747802735,"X":289.25799560546877,"Z":-408.5839538574219},{"Y":-71.45027923583985,"X":297.39898681640627,"Z":-415.04876708984377},{"Y":-72.05133819580078,"X":303.7857360839844,"Z":-420.0483093261719},{"Y":-73.68235778808594,"X":313.4743957519531,"Z":-423.6623840332031},{"Y":-71.80896759033203,"X":321.6365966796875,"Z":-426.8226623535156},{"Y":-71.10367584228516,"X":328.8031005859375,"Z":-431.0181884765625},{"Y":-71.00730895996094,"X":335.3143615722656,"Z":-438.2747497558594},{"Y":-71.01094818115235,"X":341.1527404785156,"Z":-447.8479309082031},{"Y":-71.6242904663086,"X":346.75933837890627,"Z":-456.5466613769531},{"Y":-71.29307556152344,"X":352.5870056152344,"Z":-466.1902770996094},{"Y":-70.86540222167969,"X":358.7362976074219,"Z":-475.7027893066406},{"Y":-68.39224243164063,"X":364.991943359375,"Z":-486.0800476074219},{"Y":-68.05561828613281,"X":368.867919921875,"Z":-492.71490478515627},{"Y":-66.1182632446289,"X":375.6039123535156,"Z":-498.4945373535156},{"Y":-65.57193756103516,"X":381.8541564941406,"Z":-507.0439147949219},{"Y":-64.65721893310547,"X":391.3791198730469,"Z":-516.1453857421875},{"Y":-63.941402435302737,"X":397.1769714355469,"Z":-525.44482421875},{"Y":-64.53570556640625,"X":400.4801330566406,"Z":-534.0413208007813},{"Y":-63.148372650146487,"X":407.1367492675781,"Z":-542.2803955078125},{"Y":-63.14043045043945,"X":415.5257873535156,"Z":-553.5704345703125},{"Y":-61.69130325317383,"X":419.8596496582031,"Z":-560.0626831054688},{"Y":-59.40192794799805,"X":425.5100402832031,"Z":-566.5234985351563},{"Y":-58.978965759277347,"X":432.128662109375,"Z":-572.3358764648438},{"Y":-59.00000762939453,"X":436.693115234375,"Z":-577.79052734375},{"Y":-56.82745361328125,"X":441.7837219238281,"Z":-581.4207153320313},{"Y":-55.06602096557617,"X":445.6024169921875,"Z":-587.9994506835938},{"Y":-54.60768127441406,"X":450.03228759765627,"Z":-595.1284790039063},{"Y":-53.208534240722659,"X":451.0924377441406,"Z":-603.5775146484375},{"Y":-53.11309814453125,"X":450.9548645019531,"Z":-609.203125},{"Y":-53.925682067871097,"X":451.69329833984377,"Z":-616.9981079101563},{"Y":-52.25180435180664,"X":452.1412353515625,"Z":-629.2201538085938},{"Y":-51.75102615356445,"X":452.6184997558594,"Z":-635.9013671875},{"Y":-52.380496978759769,"X":452.373779296875,"Z":-643.3695678710938},{"Y":-51.870059967041019,"X":452.90521240234377,"Z":-649.3681640625},{"Y":-51.356163024902347,"X":453.2222595214844,"Z":-656.0545654296875},{"Y":-51.7972412109375,"X":454.7962646484375,"Z":-662.0711669921875},{"Y":-52.7027702331543,"X":460.5776672363281,"Z":-667.1488647460938},{"Y":-53.161376953125,"X":466.97552490234377,"Z":-671.19287109375},{"Y":-52.10496520996094,"X":474.5755310058594,"Z":-676.9606323242188},{"Y":-51.94087219238281,"X":478.26922607421877,"Z":-682.6398315429688},{"Y":-51.41162109375,"X":481.71319580078127,"Z":-689.6708374023438},{"Y":-50.98004150390625,"X":484.9610595703125,"Z":-697.4990844726563},{"Y":-47.856300354003909,"X":487.9187316894531,"Z":-704.0797119140625},{"Y":-45.52083206176758,"X":492.315185546875,"Z":-709.850830078125},{"Y":-43.49981689453125,"X":495.3564758300781,"Z":-715.9573974609375},{"Y":-41.287471771240237,"X":501.4067077636719,"Z":-722.189697265625},{"Y":-39.37484359741211,"X":505.83203125,"Z":-723.9456787109375},{"Y":-36.90139389038086,"X":513.1641235351563,"Z":-724.67822265625},{"Y":-35.95829391479492,"X":518.325439453125,"Z":-723.7459716796875},{"Y":-35.15633010864258,"X":530.84326171875,"Z":-720.4002075195313},{"Y":-34.11772537231445,"X":540.21044921875,"Z":-721.3136596679688},{"Y":-35.0068359375,"X":547.15625,"Z":-723.103271484375},{"Y":-35.52475357055664,"X":552.67431640625,"Z":-730.8314819335938},{"Y":-35.41643142700195,"X":557.5183715820313,"Z":-740.511474609375},{"Y":-35.25937271118164,"X":558.8951416015625,"Z":-747.4848022460938},{"Y":-35.119415283203128,"X":558.0640258789063,"Z":-753.0870971679688},{"Y":-35.27024841308594,"X":554.7924194335938,"Z":-756.9083251953125},{"Y":-35.70045852661133,"X":550.3020629882813,"Z":-758.5770263671875},{"Y":-35.270591735839847,"X":541.8079223632813,"Z":-761.1456298828125},{"Y":-35.24140930175781,"X":540.473876953125,"Z":-761.3522338867188},{"Y":-33.37395477294922,"X":529.3583984375,"Z":-763.2202758789063},{"Y":-31.595523834228517,"X":524.3916625976563,"Z":-764.1766967773438},{"Y":-31.526243209838868,"X":520.3895263671875,"Z":-764.2965698242188},{"Y":-33.906646728515628,"X":514.0916748046875,"Z":-765.1187133789063},{"Y":-33.32465362548828,"X":510.3059997558594,"Z":-765.6875},{"Y":-34.70513153076172,"X":504.02935791015627,"Z":-767.7280883789063},{"Y":-33.90547180175781,"X":494.9452209472656,"Z":-768.2471923828125},{"Y":-32.00535583496094,"X":484.8426513671875,"Z":-769.9569702148438},{"Y":-31.999229431152345,"X":478.531494140625,"Z":-770.6214599609375},{"Y":-30.743398666381837,"X":472.7296142578125,"Z":-773.745361328125},{"Y":-25.965547561645509,"X":465.7404479980469,"Z":-777.3642578125},{"Y":-19.86446189880371,"X":461.5812683105469,"Z":-779.3087768554688},{"Y":-17.81456756591797,"X":457.8529357910156,"Z":-779.94970703125},{"Y":-12.650157928466797,"X":455.0748596191406,"Z":-781.0913696289063},{"Y":-6.708874225616455,"X":456.9185791015625,"Z":-783.9871826171875},{"Y":-3.000000238418579,"X":462.2825622558594,"Z":-794.510498046875},{"Y":-3.000000238418579,"X":469.63446044921877,"Z":-804.6605834960938},{"Y":-3.000000238418579,"X":478.5478515625,"Z":-817.6648559570313},{"Y":-4.501697063446045,"X":483.7603454589844,"Z":-826.3591918945313},{"Y":-8.203429222106934,"X":488.087646484375,"Z":-833.9395751953125},{"Y":-11.352645874023438,"X":502.91162109375,"Z":-858.2713012695313},{"Y":-11.242172241210938,"X":511.4459228515625,"Z":-870.2442016601563},{"Y":-8.193377494812012,"X":515.7507934570313,"Z":-877.2730712890625},{"Y":-9.70083236694336,"X":517.7582397460938,"Z":-880.806884765625},{"Y":-11.00100040435791,"X":523.3612670898438,"Z":-887.964599609375},{"Y":-10.97470474243164,"X":533.0726928710938,"Z":-904.9275512695313},{"Y":-9.464913368225098,"X":536.4889526367188,"Z":-910.5225830078125},{"Y":-11.018770217895508,"X":547.3228759765625,"Z":-927.0430297851563},{"Y":-11.150381088256836,"X":557.2415771484375,"Z":-942.1712646484375},{"Y":-11.896444320678711,"X":566.6336669921875,"Z":-955.8359375},{"Y":-11.027509689331055,"X":576.9169311523438,"Z":-972.0747680664063},{"Y":-11.325169563293457,"X":586.1551513671875,"Z":-986.0789184570313},{"Y":-11.077478408813477,"X":596.9349365234375,"Z":-1002.3939819335938},{"Y":-11.372899055480957,"X":605.9640502929688,"Z":-1015.9476928710938},{"Y":-11.158443450927735,"X":608.3058471679688,"Z":-1019.4918212890625},{"Y":-11.720073699951172,"X":613.87744140625,"Z":-1027.2177734375},{"Y":-11.001337051391602,"X":624.8228759765625,"Z":-1043.1484375},{"Y":-11.290741920471192,"X":634.1161499023438,"Z":-1056.8089599609376},{"Y":-11.250258445739746,"X":645.2544555664063,"Z":-1073.178466796875},{"Y":-11.229779243469239,"X":654.7074584960938,"Z":-1087.103271484375},{"Y":-11.337828636169434,"X":665.385986328125,"Z":-1102.854248046875},{"Y":-11.233678817749024,"X":676.199951171875,"Z":-1118.9642333984376},{"Y":-11.535783767700196,"X":685.3723754882813,"Z":-1132.1505126953126},{"Y":-11.083427429199219,"X":696.0269775390625,"Z":-1148.610107421875},{"Y":-11.160162925720215,"X":705.4916381835938,"Z":-1161.7620849609376},{"Y":-11.374567031860352,"X":717.2235107421875,"Z":-1177.548095703125},{"Y":-11.0975980758667,"X":727.350830078125,"Z":-1191.09228515625},{"Y":-11.011122703552246,"X":739.4559326171875,"Z":-1206.44287109375},{"Y":-11.56782341003418,"X":746.195068359375,"Z":-1214.8912353515626},{"Y":-11.495028495788575,"X":756.7872314453125,"Z":-1227.767333984375},{"Y":-11.10191535949707,"X":769.6500244140625,"Z":-1242.9005126953126},{"Y":-10.975688934326172,"X":780.580078125,"Z":-1255.6376953125},{"Y":-6.98110818862915,"X":794.5745239257813,"Z":-1269.6697998046876},{"Y":-7.000000476837158,"X":807.4129638671875,"Z":-1281.92529296875},{"Y":-7.003298759460449,"X":821.1651000976563,"Z":-1296.4827880859376},{"Y":-7.000000476837158,"X":835.0215454101563,"Z":-1310.464599609375},{"Y":-6.6458611488342289,"X":846.490478515625,"Z":-1322.7518310546876},{"Y":-5.35677433013916,"X":854.3775024414063,"Z":-1331.918212890625},{"Y":-3.686399221420288,"X":861.0867919921875,"Z":-1339.641357421875},{"Y":-3.000000238418579,"X":871.8590087890625,"Z":-1352.1998291015626},{"Y":-3.000000238418579,"X":885.2681884765625,"Z":-1366.4971923828126},{"Y":-3.000000238418579,"X":896.2650146484375,"Z":-1378.3973388671876},{"Y":-3.000000238418579,"X":905.998779296875,"Z":-1391.692626953125},{"Y":-3.000000238418579,"X":906.9058227539063,"Z":-1400.519287109375},{"Y":-1.2119704484939576,"X":910.1027221679688,"Z":-1416.7523193359376},{"Y":-2.2381768226623537,"X":919.7926025390625,"Z":-1432.140869140625},{"Y":-2.659698247909546,"X":928.902587890625,"Z":-1432.854248046875},{"Y":-2.7976460456848146,"X":947.8154296875,"Z":-1432.206787109375},{"Y":-2.649895429611206,"X":952.4456176757813,"Z":-1430.4639892578126},{"Y":-2.3820414543151857,"X":958.253173828125,"Z":-1424.1778564453126},{"Y":-2.85900616645813,"X":969.6964721679688,"Z":-1409.275146484375},{"Y":-3.000000238418579,"X":961.9251708984375,"Z":-1394.689453125},{"Y":-3.000000238418579,"X":958.8926391601563,"Z":-1380.3270263671876},{"Y":-3.000000238418579,"X":952.2139892578125,"Z":-1362.2230224609376},{"Y":-3.000000238418579,"X":945.599609375,"Z":-1344.6978759765626},{"Y":-3.000000238418579,"X":940.194091796875,"Z":-1330.591796875},{"Y":-4.755360126495361,"X":935.23681640625,"Z":-1316.885498046875},{"Y":-5.0298051834106449,"X":933.7337646484375,"Z":-1313.951904296875},{"Y":-6.547778129577637,"X":928.675537109375,"Z":-1299.78125},{"Y":-7.000876426696777,"X":921.6572265625,"Z":-1281.9378662109376},{"Y":-7.01521635055542,"X":915.368896484375,"Z":-1267.5189208984376},{"Y":-7.000477313995361,"X":907.8150024414063,"Z":-1250.269287109375},{"Y":-7.0953874588012699,"X":901.4647827148438,"Z":-1235.4512939453126},{"Y":-10.693129539489746,"X":894.6290283203125,"Z":-1218.532470703125},{"Y":-11.965152740478516,"X":888.7401733398438,"Z":-1202.764892578125},{"Y":-11.029088020324707,"X":882.8477783203125,"Z":-1185.1131591796876},{"Y":-11.829781532287598,"X":876.3084106445313,"Z":-1167.5145263671876},{"Y":-11.574332237243653,"X":870.866455078125,"Z":-1149.29052734375},{"Y":-11.666831016540528,"X":864.5748291015625,"Z":-1131.5377197265626},{"Y":-11.385823249816895,"X":858.6751708984375,"Z":-1113.6240234375},{"Y":-11.858357429504395,"X":853.1700439453125,"Z":-1095.6153564453126},{"Y":-11.52717399597168,"X":848.6248779296875,"Z":-1077.2791748046876},{"Y":-10.985555648803711,"X":844.6028442382813,"Z":-1058.776611328125},{"Y":-11.37242317199707,"X":841.0623779296875,"Z":-1039.828369140625},{"Y":-10.998750686645508,"X":837.857666015625,"Z":-1021.2538452148438},{"Y":-11.163287162780762,"X":833.6917114257813,"Z":-1002.8372802734375},{"Y":-11.033207893371582,"X":830.2470092773438,"Z":-984.1293334960938},{"Y":-11.035409927368164,"X":827.65869140625,"Z":-965.3280639648438},{"Y":-11.098771095275879,"X":824.180419921875,"Z":-946.6382446289063},{"Y":-11.082868576049805,"X":820.6552734375,"Z":-928.0114135742188},{"Y":-11.721946716308594,"X":817.3250122070313,"Z":-909.3287353515625},{"Y":-11.086326599121094,"X":813.9952392578125,"Z":-890.771484375},{"Y":-12.051880836486817,"X":810.8373413085938,"Z":-872.3380737304688},{"Y":-11.425790786743164,"X":806.7002563476563,"Z":-853.8916625976563},{"Y":-11.401237487792969,"X":799.5048828125,"Z":-836.3961791992188},{"Y":-11.041778564453125,"X":791.6893310546875,"Z":-818.9173583984375},{"Y":-11.559636116027832,"X":784.379150390625,"Z":-801.506591796875},{"Y":-8.16512393951416,"X":777.2324829101563,"Z":-784.2350463867188},{"Y":-6.104599952697754,"X":768.7140502929688,"Z":-767.3301391601563},{"Y":-2.999323606491089,"X":759.7495727539063,"Z":-750.8543090820313},{"Y":-3.0000016689300539,"X":750.3023071289063,"Z":-734.3012084960938},{"Y":-3.000000238418579,"X":741.6355590820313,"Z":-717.669921875},{"Y":-3.000000238418579,"X":732.68603515625,"Z":-700.9285278320313},{"Y":-3.000000238418579,"X":721.61328125,"Z":-685.4459838867188},{"Y":-3.0192923545837404,"X":709.812255859375,"Z":-670.7706298828125},{"Y":-3.077252149581909,"X":699.0205078125,"Z":-655.3389282226563},{"Y":-3.0000007152557375,"X":687.3123168945313,"Z":-640.474365234375},{"Y":-3.0000007152557375,"X":676.284912109375,"Z":-625.0216674804688},{"Y":-3.000000238418579,"X":666.2186279296875,"Z":-609.4817504882813},{"Y":-7.062930583953857,"X":656.98779296875,"Z":-593.6758422851563},{"Y":-10.501157760620118,"X":647.9185180664063,"Z":-577.907958984375},{"Y":-7.005224227905273,"X":639.069091796875,"Z":-562.1492309570313},{"Y":-5.561940670013428,"X":629.7415771484375,"Z":-545.92822265625},{"Y":-3.766352891921997,"X":623.7985229492188,"Z":-543.0624389648438},{"Y":-0.4673363268375397,"X":621.9937744140625,"Z":-537.9271850585938},{"Y":-0.35167768597602847,"X":621.740234375,"Z":-537.330078125},{"Y":5.057130336761475,"X":619.9124145507813,"Z":-532.19287109375},{"Y":7.829787731170654,"X":619.7307739257813,"Z":-527.3246459960938},{"Y":9.092573165893555,"X":619.7583618164063,"Z":-523.2546997070313},{"Y":12.150442123413086,"X":622.040283203125,"Z":-517.8245849609375},{"Y":14.891884803771973,"X":622.7608642578125,"Z":-512.5382080078125},{"Y":19.074649810791017,"X":623.3928833007813,"Z":-506.9125671386719},{"Y":21.744691848754884,"X":623.4166259765625,"Z":-500.30145263671877},{"Y":24.510648727416993,"X":623.9564819335938,"Z":-494.74554443359377},{"Y":27.20901870727539,"X":624.2123413085938,"Z":-489.7172546386719},{"Y":30.938596725463868,"X":625.2235717773438,"Z":-481.8025817871094},{"Y":33.46348190307617,"X":625.2006225585938,"Z":-473.52020263671877},{"Y":37.338661193847659,"X":625.090087890625,"Z":-462.8758239746094},{"Y":39.754634857177737,"X":625.243896484375,"Z":-454.42193603515627},{"Y":42.682464599609378,"X":624.1384887695313,"Z":-444.88360595703127},{"Y":48.505184173583987,"X":624.8445434570313,"Z":-435.7370300292969},{"Y":52.046512603759769,"X":633.6165771484375,"Z":-426.6548767089844},{"Y":56.14674377441406,"X":642.7672729492188,"Z":-418.947265625},{"Y":61.56560516357422,"X":647.9710083007813,"Z":-415.71063232421877},{"Y":66.90442657470703,"X":652.402099609375,"Z":-413.6093444824219},{"Y":68.83395385742188,"X":655.3088989257813,"Z":-414.68035888671877},{"Y":74.64297485351563,"X":658.4923706054688,"Z":-412.1120910644531},{"Y":79.21280670166016,"X":662.7669067382813,"Z":-407.84881591796877},{"Y":82.8696517944336,"X":667.7186889648438,"Z":-402.9017028808594},{"Y":81.72157287597656,"X":670.0193481445313,"Z":-396.92236328125},{"Y":79.73120880126953,"X":672.8555297851563,"Z":-389.2047119140625},{"Y":75.80992126464844,"X":666.6765747070313,"Z":-383.57257080078127},{"Y":74.29961395263672,"X":662.3096313476563,"Z":-380.9429016113281},{"Y":66.30169677734375,"X":658.3692626953125,"Z":-377.58404541015627},{"Y":54.23489761352539,"X":652.8509521484375,"Z":-375.7156066894531},{"Y":52.981605529785159,"X":646.2808837890625,"Z":-372.0798034667969},{"Y":52.543670654296878,"X":638.552734375,"Z":-368.2397155761719},{"Y":51.33763122558594,"X":634.8888549804688,"Z":-367.001953125},{"Y":46.14652633666992,"X":627.9397583007813,"Z":-365.9909973144531},{"Y":40.777610778808597,"X":621.4282836914063,"Z":-364.93994140625},{"Y":35.738006591796878,"X":615.6478271484375,"Z":-364.5306701660156},{"Y":34.590538024902347,"X":605.122802734375,"Z":-368.6657409667969},{"Y":32.76959991455078,"X":599.0675659179688,"Z":-366.048828125},{"Y":30.405012130737306,"X":593.724609375,"Z":-363.8085632324219},{"Y":25.67985725402832,"X":588.4216918945313,"Z":-359.5290222167969},{"Y":19.04341697692871,"X":585.6258544921875,"Z":-356.93426513671877},{"Y":7.903454303741455,"X":589.81494140625,"Z":-352.81524658203127},{"Y":0.2784448266029358,"X":591.1484375,"Z":-354.2201843261719},{"Y":-7.115119457244873,"X":596.0895385742188,"Z":-356.0409851074219},{"Y":-7.654308319091797,"X":605.006103515625,"Z":-358.0293273925781},{"Y":-7.34372091293335,"X":631.4721069335938,"Z":-374.9562683105469},{"Y":-7.577934741973877,"X":611.0699462890625,"Z":-377.0044860839844},{"Y":-6.304628849029541,"X":600.96826171875,"Z":-378.3658752441406},{"Y":-4.011232376098633,"X":591.3900146484375,"Z":-380.7434387207031},{"Y":0.07750910520553589,"X":583.5029296875,"Z":-384.8182373046875},{"Y":4.953723430633545,"X":576.4193725585938,"Z":-386.7500915527344},{"Y":7.893801212310791,"X":568.2106323242188,"Z":-385.67413330078127},{"Y":12.208050727844239,"X":563.7592163085938,"Z":-380.59246826171877},{"Y":12.238241195678711,"X":562.553466796875,"Z":-375.88818359375},{"Y":8.282784461975098,"X":561.587890625,"Z":-368.47979736328127},{"Y":5.471288204193115,"X":561.6419677734375,"Z":-363.56573486328127},{"Y":3.905642032623291,"X":561.962158203125,"Z":-359.9250793457031},{"Y":1.5343966484069825,"X":561.2229614257813,"Z":-354.60797119140627},{"Y":-2.3782637119293215,"X":559.2047119140625,"Z":-347.13177490234377},{"Y":-2.6067535877227785,"X":559.371337890625,"Z":-338.9902038574219},{"Y":-3.2687695026397707,"X":559.9981079101563,"Z":-331.1598205566406},{"Y":-3.522292375564575,"X":563.4826049804688,"Z":-314.94427490234377},{"Y":-3.3114078044891359,"X":568.5322265625,"Z":-293.76953125},{"Y":-3.367293119430542,"X":572.1756591796875,"Z":-277.33953857421877},{"Y":-3.367293119430542,"X":572.1756591796875,"Z":-277.33953857421877},{"Y":-4.186720848083496,"X":574.5633544921875,"Z":-266.6298522949219},{"Y":-7.164914131164551,"X":574.768798828125,"Z":-260.029296875},{"Y":-9.94495964050293,"X":574.2892456054688,"Z":-252.2447967529297},{"Y":-7.147627830505371,"X":577.6104125976563,"Z":-243.52622985839845},{"Y":-4.273177146911621,"X":579.8597412109375,"Z":-239.5366668701172},{"Y":-0.9811333417892456,"X":586.4988403320313,"Z":-238.30621337890626},{"Y":2.1979405879974367,"X":592.9362182617188,"Z":-235.26979064941407},{"Y":8.812777519226075,"X":596.9423828125,"Z":-233.41819763183595},{"Y":11.924480438232422,"X":598.7369995117188,"Z":-228.4697265625},{"Y":14.125399589538575,"X":601.9135131835938,"Z":-220.12728881835938},{"Y":19.10040283203125,"X":605.4279174804688,"Z":-212.10153198242188},{"Y":25.176088333129884,"X":608.4249267578125,"Z":-206.10357666015626},{"Y":27.94637107849121,"X":610.0440673828125,"Z":-200.43199157714845},{"Y":32.835933685302737,"X":612.1253662109375,"Z":-196.29925537109376},{"Y":32.44699478149414,"X":616.8167724609375,"Z":-190.21388244628907},{"Y":31.4786376953125,"X":623.2613525390625,"Z":-184.420166015625},{"Y":32.43003845214844,"X":630.2034912109375,"Z":-181.13832092285157},{"Y":30.99116325378418,"X":638.1097412109375,"Z":-180.41041564941407},{"Y":31.55504035949707,"X":645.4293823242188,"Z":-182.11007690429688},{"Y":32.66874313354492,"X":662.5979614257813,"Z":-184.5323486328125},{"Y":32.08937072753906,"X":655.0258178710938,"Z":-179.6757049560547},{"Y":27.894010543823243,"X":646.5903930664063,"Z":-173.59210205078126},{"Y":23.274242401123048,"X":644.79833984375,"Z":-168.70004272460938},{"Y":21.253787994384767,"X":644.7915649414063,"Z":-166.2505645751953},{"Y":11.417163848876954,"X":644.1526489257813,"Z":-159.72732543945313},{"Y":8.358539581298829,"X":644.7313232421875,"Z":-155.18092346191407},{"Y":2.302488088607788,"X":644.793701171875,"Z":-148.8055419921875},{"Y":-3.5806586742401125,"X":644.66748046875,"Z":-142.7395782470703},{"Y":-4.005170822143555,"X":646.4615478515625,"Z":-135.19970703125},{"Y":-4.697624206542969,"X":646.4005126953125,"Z":-127.2938003540039},{"Y":-4.32395076751709,"X":646.9248046875,"Z":-118.90447235107422},{"Y":-8.55913257598877,"X":647.2559814453125,"Z":-108.5077896118164},{"Y":-8.55596923828125,"X":647.2559814453125,"Z":-108.5077896118164},{"Y":-9.48869514465332,"X":646.9788208007813,"Z":-99.30377197265625},{"Y":-9.860228538513184,"X":646.4542236328125,"Z":-95.72547149658203},{"Y":-11.410893440246582,"X":645.562744140625,"Z":-91.26366424560547},{"Y":-11.09369945526123,"X":645.5185546875,"Z":-72.81805419921875},{"Y":-11.024950981140137,"X":644.992919921875,"Z":-59.21836853027344},{"Y":-11.382179260253907,"X":643.4741821289063,"Z":-40.31110382080078},{"Y":-11.03435230255127,"X":642.330078125,"Z":-25.709291458129884},{"Y":-11.497270584106446,"X":641.4555053710938,"Z":-7.056362152099609},{"Y":-11.871397972106934,"X":640.905517578125,"Z":8.268196105957032},{"Y":-11.010385513305664,"X":640.3984375,"Z":27.118892669677736},{"Y":-11.644389152526856,"X":638.3928833007813,"Z":45.681129455566409},{"Y":-11.106142044067383,"X":636.39013671875,"Z":64.61483001708985},{"Y":-11.362351417541504,"X":634.5814819335938,"Z":83.12220764160156},{"Y":-11.286349296569825,"X":632.938720703125,"Z":101.87014770507813},{"Y":-11.534514427185059,"X":632.2152099609375,"Z":120.7202377319336},{"Y":-11.391797065734864,"X":631.4008178710938,"Z":139.34609985351563},{"Y":-11.08894157409668,"X":630.65625,"Z":158.05442810058595},{"Y":-11.631275177001954,"X":629.3253173828125,"Z":176.9663543701172},{"Y":-11.266690254211426,"X":627.623291015625,"Z":195.33714294433595},{"Y":-11.183404922485352,"X":627.2799682617188,"Z":205.74514770507813},{"Y":-10.383576393127442,"X":626.8450317382813,"Z":223.91310119628907},{"Y":-11.213651657104493,"X":625.46630859375,"Z":243.0272979736328},{"Y":-10.98790454864502,"X":623.5809936523438,"Z":257.974609375},{"Y":-7.547183036804199,"X":622.4061889648438,"Z":265.16302490234377},{"Y":-4.007143020629883,"X":621.6611938476563,"Z":271.14862060546877},{"Y":-3.003608226776123,"X":618.7416381835938,"Z":280.0407409667969},{"Y":-3.000000238418579,"X":617.4258422851563,"Z":288.65008544921877},{"Y":-3.1499502658843996,"X":615.1802368164063,"Z":296.2956848144531},{"Y":1.6857802867889405,"X":613.0372314453125,"Z":303.2129821777344},{"Y":9.261282920837403,"X":611.2582397460938,"Z":309.311767578125},{"Y":9.940213203430176,"X":608.3661499023438,"Z":311.0730895996094},{"Y":11.64954948425293,"X":604.21435546875,"Z":313.6955871582031},{"Y":12.710599899291993,"X":600.55517578125,"Z":320.6769104003906},{"Y":14.434556007385254,"X":597.896728515625,"Z":336.1676330566406},{"Y":16.02308464050293,"X":595.77734375,"Z":346.8341369628906},{"Y":16.16950225830078,"X":594.2135620117188,"Z":352.7707824707031},{"Y":16.77914810180664,"X":591.7244262695313,"Z":358.9396057128906},{"Y":15.081442832946778,"X":589.6881103515625,"Z":367.18536376953127},{"Y":15.533287048339844,"X":588.573974609375,"Z":370.4232482910156},{"Y":14.071104049682618,"X":587.5665283203125,"Z":375.6051025390625},{"Y":12.988398551940918,"X":586.5177612304688,"Z":380.2956848144531},{"Y":11.829174041748047,"X":584.763916015625,"Z":385.9291687011719},{"Y":11.400152206420899,"X":583.8115844726563,"Z":389.6884765625},{"Y":11.619799613952637,"X":582.1160888671875,"Z":394.5209045410156},{"Y":11.747761726379395,"X":574.7791748046875,"Z":396.45928955078127},{"Y":10.251062393188477,"X":571.67626953125,"Z":394.7828063964844},{"Y":7.173548221588135,"X":568.2281494140625,"Z":393.0670166015625},{"Y":4.083191394805908,"X":562.7876586914063,"Z":390.0881652832031},{"Y":-3.051020860671997,"X":560.2130737304688,"Z":387.6810607910156},{"Y":-3.000000238418579,"X":552.68505859375,"Z":384.4348449707031},{"Y":-3.000000238418579,"X":542.7852783203125,"Z":378.5755310058594},{"Y":-3.000000238418579,"X":531.3385620117188,"Z":370.06646728515627},{"Y":-3.000000238418579,"X":510.285888671875,"Z":356.1575012207031},{"Y":-3,"X":496.8291015625,"Z":347.5400390625},{"Y":-3.1725375652313234,"X":469.9456787109375,"Z":331.68560791015627},{"Y":-3.956916570663452,"X":458.50860595703127,"Z":323.9751281738281},{"Y":-11.411989212036133,"X":444.0636901855469,"Z":314.89825439453127},{"Y":-11.143885612487793,"X":431.735595703125,"Z":306.84832763671877},{"Y":-11.65377426147461,"X":393.5716247558594,"Z":282.42352294921877},{"Y":-11.673539161682129,"X":382.6662902832031,"Z":274.0207824707031},{"Y":-11.194883346557618,"X":366.7513427734375,"Z":263.9967041015625},{"Y":-11.016196250915528,"X":355.5671081542969,"Z":256.60968017578127},{"Y":-11.547551155090332,"X":340.2814025878906,"Z":246.1788330078125},{"Y":-11.021678924560547,"X":325.8612060546875,"Z":237.08705139160157},{"Y":-11.890448570251465,"X":309.27197265625,"Z":228.5190887451172},{"Y":-11.739446640014649,"X":293.71710205078127,"Z":218.54505920410157},{"Y":-11.502012252807618,"X":277.497314453125,"Z":208.87095642089845},{"Y":-11.325456619262696,"X":261.4328308105469,"Z":199.32765197753907},{"Y":-11.078137397766114,"X":246.05137634277345,"Z":188.85401916503907},{"Y":-11.000089645385743,"X":230.20928955078126,"Z":178.47634887695313},{"Y":-11.665740013122559,"X":214.16583251953126,"Z":168.685302734375},{"Y":-8.946468353271485,"X":198.3385467529297,"Z":158.92544555664063},{"Y":-3.304403066635132,"X":182.470458984375,"Z":149.62533569335938},{"Y":-3.007824182510376,"X":175.86062622070313,"Z":144.8979949951172},{"Y":-3.0343470573425295,"X":166.01708984375,"Z":139.19546508789063},{"Y":-3.071733236312866,"X":153.43099975585938,"Z":132.7880859375},{"Y":-3.1186985969543459,"X":138.7176055908203,"Z":126.54630279541016},{"Y":-3.000000238418579,"X":117.83965301513672,"Z":115.89573669433594},{"Y":-3.000000238418579,"X":77.2156982421875,"Z":106.68091583251953},{"Y":-3.000000238418579,"X":70.66650390625,"Z":103.67533111572266},{"Y":-3.000000238418579,"X":63.50795364379883,"Z":97.91498565673828},{"Y":-3.000000238418579,"X":53.38089370727539,"Z":93.79129028320313},{"Y":-3.000000238418579,"X":40.25814437866211,"Z":88.00508880615235},{"Y":-3.000000238418579,"X":21.159679412841798,"Z":82.34745788574219},{"Y":-3.458693504333496,"X":-0.06456401199102402,"Z":79.6906967163086},{"Y":-6.174127101898193,"X":-14.922796249389649,"Z":77.94922637939453},{"Y":-7.076498508453369,"X":-26.608783721923829,"Z":76.34392547607422},{"Y":-7.111432075500488,"X":-40.46284484863281,"Z":74.24213409423828},{"Y":-7.0095953941345219,"X":-53.032432556152347,"Z":74.06696319580078},{"Y":-7.000001430511475,"X":-60.42548370361328,"Z":73.28680419921875},{"Y":-6.0251007080078129,"X":-67.35469055175781,"Z":74.40441131591797},{"Y":-3.140596389770508,"X":-71.56989288330078,"Z":74.41835021972656},{"Y":-3.0000007152557375,"X":-77.71530151367188,"Z":74.33600616455078},{"Y":-3.0839335918426515,"X":-85.92546844482422,"Z":74.2855224609375},{"Y":-5.552220821380615,"X":-94.31825256347656,"Z":71.78047943115235},{"Y":-8.15986442565918,"X":-96.9466552734375,"Z":65.30899810791016},{"Y":-10.660785675048829,"X":-98.4531021118164,"Z":61.374996185302737},{"Y":-13.750649452209473,"X":-99.42858123779297,"Z":56.4643440246582},{"Y":-16.038759231567384,"X":-97.95509338378906,"Z":50.31316375732422},{"Y":-16.743616104125978,"X":-93.68504333496094,"Z":40.87928009033203},{"Y":-23.146055221557618,"X":-91.07108306884766,"Z":34.73562240600586},{"Y":-27.000001907348634,"X":-93.15514373779297,"Z":25.18101692199707},{"Y":-28.540264129638673,"X":-95.5604476928711,"Z":16.29629898071289},{"Y":-30.207796096801759,"X":-97.37849426269531,"Z":13.972580909729004},{"Y":-35.0000114440918,"X":-101.88172149658203,"Z":6.114368915557861},{"Y":-35.0093879699707,"X":-106.10186767578125,"Z":-3.9213547706604006},{"Y":-35.24341583251953,"X":-111.19701385498047,"Z":-14.333916664123536},{"Y":-37.2166748046875,"X":-112.69361877441406,"Z":-18.16156005859375},{"Y":-49.20759582519531,"X":-114.88233184814453,"Z":-24.23019790649414},{"Y":-47.00000762939453,"X":-115.47897338867188,"Z":-30.973058700561525},{"Y":-47,"X":-120.17218780517578,"Z":-41.77866744995117},{"Y":-47,"X":-125.2392807006836,"Z":-107.58003234863281},{"Y":-44.04908752441406,"X":-125.94053649902344,"Z":-115.7935791015625},{"Y":-38.43821334838867,"X":-127.03827667236328,"Z":-120.39546966552735},{"Y":-35.865264892578128,"X":-126.82592010498047,"Z":-126.65568542480469}]}]==]
    do
        pcall(function()
            if type(isfolder) == "function" and type(writefile) == "function" then
                if not isfolder("ASTERTween") then makefolder("ASTERTween") end
                -- siempre se reescribe con la ruta incluida en el script (la ruta "5" fija)
                writefile("ASTERTween/" .. EMBEDDED_ROUTE_NAME .. ".json", EMBEDDED_ROUTE_JSON)
            end
        end)
        local routeJson = EMBEDDED_ROUTE_JSON
        local okR, dataR = pcall(function() return httpservice:JSONDecode(routeJson) end)
        if okR and type(dataR) == "table" and type(dataR.positions) == "table" then
            Settings.recordedPositions = dataR.positions
        end
    end
    local pathDefault = "None"
    pcall(function()
        for _, n in ipairs(getGoldPathList()) do
            if n == EMBEDDED_ROUTE_NAME then pathDefault = n end
        end
    end)
    ASTER.Options.GlobalPathDropdown = ASTER.Tabs.Main:AddDropdown("Select Path", getGoldPathList(), pathDefault, function(v)
        if v == "None" then
            Settings.recordedPositions = {}
            updateVisualNodes()
            if ASTER.Options.WaypointDropdown then
                ASTER.Options.WaypointDropdown:SetValues(ASTER.getWaypointList())
                ASTER.Options.WaypointDropdown:SetValue("None")
            end
        else
            if loadPath(v) then
                updateVisualNodes()
                if ASTER.Options.WaypointDropdown then
                    ASTER.Options.WaypointDropdown:SetValues(ASTER.getWaypointList())
                    ASTER.Options.WaypointDropdown:SetValue("None")
                end
            end
        end
    end)

    ASTER.Tabs.Main:AddInput("InputPath", "", function(v)
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

            if ASTER.Options.WaypointDropdown then
                ASTER.Options.WaypointDropdown:SetValues(ASTER.getWaypointList())
                ASTER.Options.WaypointDropdown:SetValue("None")
            end
        end
    end)

    ASTER.Tabs.Main:AddInput("New Path Name", "", function(v)
        Settings.CustomPathName = v
    end)

    ASTER.Tabs.Main:AddButton("Save/Create Path", function()
        local name = Settings.CustomPathName
        if not name or name == "" then
            name = "GoldCircuit_"..os.date("%H%M%S")
        end
        saveCurrentPath(name)
        if ASTER.Options.GlobalPathDropdown then ASTER.Options.GlobalPathDropdown:SetValues(getGoldPathList()) end
    end)

    ASTER.Tabs.Main:AddButton("Delete Selected Path", function()
        local pathName = ASTER.Options.GlobalPathDropdown:GetValue()
        if pathName and pathName ~= "None" then
            local pathFolder = "ASTERTween"
            local filePath = pathFolder .. "/" .. pathName .. ".json"
            if isfile(filePath) then
                if delfile then delfile(filePath) elseif deletefile then deletefile(filePath) end
                Settings.recordedPositions = {}
                updateVisualNodes()
                if ASTER.Options.GlobalPathDropdown then
                   ASTER.Options.GlobalPathDropdown:SetValues(getGoldPathList())
                   ASTER.Options.GlobalPathDropdown:SetValue("None")
                end
            end
        end
    end)

    ASTER.Tabs.Main:AddButton("Refresh Path List", function()
        if ASTER.Options.GlobalPathDropdown then ASTER.Options.GlobalPathDropdown:SetValues(getGoldPathList()) end
    end)
end

do
    ASTER.Tabs.Main:AddLabel("Waypoint Editor")
    function ASTER.getWaypointList()
        local t = {}
        if Settings.recordedPositions then
            for i=1, #Settings.recordedPositions do table.insert(t, tostring(i)) end
        end
        if #t == 0 then t = {"None"} end
        return t
    end

    ASTER.Options.WaypointDropdown = ASTER.Tabs.Main:AddDropdown("Select Waypoint", ASTER.getWaypointList(), "None", function(v)
        Settings.SelectedWaypointIndex = tonumber(v)
    end)

    ASTER.Tabs.Main:AddButton("Refresh Waypoint List", function()
        if ASTER.Options.WaypointDropdown then
            ASTER.Options.WaypointDropdown:SetValues(ASTER.getWaypointList())
            ASTER.Options.WaypointDropdown:SetValue("None")
        end
    end)

    ASTER.Tabs.Main:AddButton("Move Selected Waypoint Here", function()
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

    ASTER.Tabs.Main:AddButton("Delete Selected Waypoint", function()
        local idx = Settings.SelectedWaypointIndex
        if idx and Settings.recordedPositions and Settings.recordedPositions[idx] then
             table.remove(Settings.recordedPositions, idx)
             updateVisualNodes()
             if ASTER.Options.WaypointDropdown then
                ASTER.Options.WaypointDropdown:SetValues(ASTER.getWaypointList())
                ASTER.Options.WaypointDropdown:SetValue("None")
             end
        end
    end)

    ASTER.Tabs.Main:AddSlider("Waypoint Wait Time", 0, 10, 0, 0.01, function(v)
        Settings.WaypointWaitTime = v
    end)

    ASTER.Tabs.Main:AddButton("Set Wait to Selected Waypoint", function()
        local idx = Settings.SelectedWaypointIndex
        if idx and Settings.recordedPositions and Settings.recordedPositions[idx] then
             Settings.recordedPositions[idx].waitTime = Settings.WaypointWaitTime or 0
        end
    end)
end

do
    ASTER.Tabs.Main:AddLabel("Path Recorder")
    if not __ASTER_RUNTIME.waypointDropdownLoopStarted then
        __ASTER_RUNTIME.waypointDropdownLoopStarted = true
        local session = CURRENT_SESSION
        task.spawn(function()
            while isRuntimeSessionActive(session) do
                if Settings.needsDropdownUpdate then
                    Settings.needsDropdownUpdate = false
                    if ASTER.Options.WaypointDropdown then
                        ASTER.Options.WaypointDropdown:SetValues(ASTER.getWaypointList())
                    end
                end
                task.wait(2)
            end
        end)
    end

    ASTER.Tabs.Main:AddToggle("Auto Record Path", false, function(v)
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

    ASTER.Tabs.Main:AddSlider("Recording Interval", 0.1, 5, 1, 0.1, function(v)
        Settings.recordInterval = v
    end)

    ASTER.Tabs.Main:AddButton("Add Manual Waypoint", function()
         local player = game:GetService("Players").LocalPlayer
         local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
         if hrp then
             if not Settings.recordedPositions then Settings.recordedPositions = {} end
             table.insert(Settings.recordedPositions, {X = hrp.Position.X, Y = hrp.Position.Y, Z = hrp.Position.Z})
             if updateVisualNodes then updateVisualNodes() end
             Settings.needsDropdownUpdate = true
         end
    end)

    ASTER.Tabs.Main:AddButton("Clear Path", function()
        Settings.recordedPositions = {}
        updateVisualNodes()
    end)

end

        ASTER.Tabs.Pickup:AddToggle("Auto Drop", false, function(v)
        Settings.AutoDropEnabled = v
    end)
    ASTER.Tabs.Pickup:AddInput("Item to Drop", "", function(v)
        Settings.DropItem = v
    end)
    ASTER.Tabs.Pickup:AddInput("DropAmount", "Infinite", function(v)
        local amount = tonumber(v)
        if amount and amount > 0 then
            Settings.DropAmount = math.floor(amount)
        else
            Settings.DropAmount = "Infinite"
        end
    end)

    -- ===== ITEM TOOLS (menu) =====
    do
        local IT = ItemTools
        local tab = ASTER.Tabs.Pickup

        tab:AddLabel("Auto Item Deletion")
        tab:AddToggle("Enable Item Deletion", true, function(v) IT.cfg.deleteEnabled = (v == true) end)
        tab:AddSlider("Deletion Range", 1, 25, 25, 1, function(v) IT.cfg.deleteRange = v end)
        tab:AddInput("Deletion Targets (coma o All)", "Log, Stone, Raw Iron, Coal, Wood, Leaves,", function(v) IT.cfg.deleteTargets = v end)

        tab:AddLabel("Auto Craft")
        tab:AddToggle("Enable Auto Craft", true, function(v) IT.cfg.craftEnabled = (v == true) end)
        tab:AddToggle("Use Amount", false, function(v) IT.cfg.craftUseAmount = (v == true) end)
        tab:AddInput("Craft Object (nombre exacto)", "Leaf Shirt", function(v) IT.cfg.craftObject = v end)
        tab:AddInput("Craft Amount", "1", function(v) IT.cfg.craftAmount = tonumber(v) or 1 end)
        tab:AddSlider("Craft Delay", 0.01, 2, 0.05, 0.01, function(v) IT.cfg.craftDelay = v end)

        tab:AddLabel("Items Into Chest")
        tab:AddToggle("Select Chest (tap a chest)", false, function(v) IT.setSelecting(v == true) end)
        tab:AddToggle("Auto Insert Items", true, function(v) IT.cfg.chestEnabled = (v == true) end)
        tab:AddInput("Chest Targets (coma o All)", "Raw Gold", function(v) IT.cfg.chestTargets = v end)
        local st = tab:AddLabel(IT.status)
        st.TextSize = 12
        st.TextColor3 = Color3.fromRGB(170, 170, 170)
        IT.statusLabel = st
    end

ASTER.Tabs.Automation:AddLabel("Respawn")
Settings.AutoRespawnEnabled = true
ASTER.Tabs.Automation:AddToggle("Auto Bed Respawn", true, function(v)
    Settings.AutoRespawnEnabled = v
    if v then startAutoRespawn() end
end)

end

-- ============================================================
-- 12z. ANTI-AFK
-- Evita la desconexion por inactividad (20 min). Activado por defecto.
-- ============================================================
do
    Settings.AntiAFK = true
    if __ASTER_RUNTIME.antiAfkConn then
        pcall(function() __ASTER_RUNTIME.antiAfkConn:Disconnect() end)
        __ASTER_RUNTIME.antiAfkConn = nil
    end
    local function antiAfkPulse()
        if not Settings.AntiAFK then return end
        local VU = game:GetService("VirtualUser")
        pcall(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new(0, 0))
        end)
    end
    __ASTER_RUNTIME.antiAfkConn = plr.Idled:Connect(antiAfkPulse)
    -- respaldo: un pulso cada 5 minutos por si Idled no dispara
    task.spawn(function()
        while CURRENT_SESSION == __ASTER_RUNTIME.sessionId do
            task.wait(300)
            antiAfkPulse()
        end
    end)
    ASTER.Tabs.Automation:AddToggle("Anti AFK", true, function(v)
        Settings.AntiAFK = v == true
    end)
end

-- ============================================================
-- 13. AUTO-INICIO DE LA RUTA (ruta "5" cargada arriba)
-- ============================================================
task.spawn(function()
    if not (ASTER_CONFIG and ASTER_CONFIG.AutoStartRuta) then return end
    task.wait(tonumber(ASTER_CONFIG.AutoStartDelay) or 6)
    local tries = 0
    while not (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")) and tries < 60 do
        tries = tries + 1
        task.wait(0.5)
    end
    if not Settings.recordedPositions or #Settings.recordedPositions == 0 then
        warn("[ASTER] Auto-inicio: no hay ruta cargada")
        return
    end
    if Settings.GoldCircuitEnabled then return end
    pcall(function()
        local reg = Window and Window.ElementRegistry and Window.ElementRegistry["Start Tween"]
        if reg and reg.SetValue then reg.SetValue(true) end
    end)
    Settings.GoldCircuitEnabled = true
    startGoldCircuit()
    print("[ASTER] Ruta iniciada automaticamente (" .. #Settings.recordedPositions .. " puntos)")
end)
