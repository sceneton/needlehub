-- beyy v103.00 | Chapter2 module | PlaceId 83445806734780
local __BEYY_MODULE = "Chapter2"
local __BEYY_SCRIPT_VERSION = "103.00"
-- Confirmed parallel puzzle queues and native key pickup/turn-in.
local __BEYY_BOOT_T0 = os.clock()
if game.PlaceId ~= 83445806734780 then
    warn("[BeyyHub] Refusing to load Chapter2 module in another place")
    return
end

-- Chapter 2 integrated v33. This is the SAME four-module launcher as
-- chapter2-no-levers-cutscene-test.lua, embedded without an extra HTTP fetch.
-- Replaces the legacy 2,000-line v23 puzzle/cutscene controller entirely.
local __BEYY_CH2_NO_LEVERS_RUN = function(cancelled)
    cancelled = cancelled or function() return false end
-- Beyy Chapter 2 Standalone Integrated v33 (v32 puzzles / v6 invisible Skip / v9 return / v27 VacuumPower)
-- Canonical Chapter 2 standalone entry point; replaces legacy v26 workflow.
-- Same four components as the latest tested experiment:
-- v32 no-levers Picture/Color/Number, v6 deferred/invisible native intro Skip,
-- v9 immediate spawn return/snapback correction and v27 VacuumPower only.
-- Also embedded by BeyyHub Main to guarantee feature parity.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/BeyyTU/needlehub/main/chapter2-no-levers-cutscene-test.lua"
local Players=game:GetService("Players")
local paths={
    {name="CUTSCENE",file="chapter2-cutscene-deferred-invisible-skip-test.lua",
        marker="Beyy Chapter 2 Cutscene-Only Standalone v6 INVISIBLE DEFERRED SKIP TEST",
        cache="BeyyHub/chapter2_integrated_v33_cutscene_v6_cinefix1.lua"},
    {name="HOLD",file="chapter2-puzzle-position-diagnostic.lua",
        marker="Beyy Chapter 2 Teleport-Hold and Return Diagnostic v9",
        cache="BeyyHub/chapter2_integrated_v33_return_v9_jumpfix.lua"},
    {name="PUZZLES",file="chapter2-no-levers-puzzles-dual-range-test.lua",
        marker="Beyy Chapter 2 No-Levers Puzzle Worker v32 DUAL RANGE TEST",
        cache="BeyyHub/chapter2_integrated_v33_puzzles_v32.lua"},
    {name="UPGRADES",file="chapter2-auto-upgrades.lua",
        marker="Beyy Chapter 2 Auto Upgrades v27 (Vacuum Power only)",
        cache="BeyyHub/chapter2_integrated_v33_vacuum_v27.lua"},
}
local function log(line)
    print("[CH2 HOLD TEST] "..tostring(line))
end
local function fail(message)
    warn("[CH2 HOLD TEST] "..tostring(message))
end
local function valid(body,item)
    return type(body)=="string" and #body>3000
        and body:find(item.marker,1,true)~=nil
end
local function compile(body)
    local ok,fn,err=pcall(loadstring,body)
    if ok and type(fn)=="function" then return fn,nil end
    return nil,tostring(ok and err or fn)
end
local function request(item,attempt)
    return game:HttpGet("https://raw.githubusercontent.com/BeyyTU/needlehub/main/"..
        item.file.."?chapter2-integrated-v33="..tostring(os.time())..
        "-"..tostring(attempt))
end
local function fetch(item,allowCache)
    if cancelled() then return nil,"cancelled",nil end
    -- A lobby preflight saves the exact verified component to the executor's
    -- disk when available; Chapter 2 uses it without another network request.
    if allowCache and type(readfile)=="function" then
        local ok,data=pcall(readfile,item.cache)
        if ok and valid(data,item) then
            local fn,err=compile(data)
            if fn then return fn,"cached",data end
            fail(item.name.." cached source compile: "..tostring(err))
        end
    end
    local reason="no response"
    for attempt=1,3 do
        if cancelled() then return nil,"cancelled",nil end
        local ok,body=pcall(request,item,attempt)
        if ok and valid(body,item) then
            local fn,err=compile(body)
            if fn then return fn,"downloaded",body end
            reason="compile: "..tostring(err)
        else
            reason=ok and "invalid response/version" or tostring(body)
        end
        task.wait(0.25*attempt)
    end
    return nil,reason,nil
end
local function cache(item,body)
    if not body or type(writefile)~="function" then return end
    if type(makefolder)=="function" then
        pcall(function()
            if type(isfolder)~="function" or not isfolder("BeyyHub") then
                makefolder("BeyyHub")
            end
        end)
    end
    pcall(writefile,item.cache,body)
end
local env=_G
if type(getgenv)=="function" then
    local ok,val=pcall(getgenv)
    if ok and type(val)=="table" then env=val end
end
if game.PlaceId==LOBBY then
    -- Queue only the small bootstrap. Preflight validates all four modules
    -- separately rather than queuing their combined source in one payload.
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then
        queue=syn.queue_on_teleport
    end
    if type(queue)~="function" then
        fail("queue_on_teleport unavailable. Execute loader again in Chapter 2.")
        return
    end
    local allGood=true
    for _,item in ipairs(paths) do
        local fn,source,body=fetch(item,true)
        if fn then
            cache(item,body)
            log("Lobby preflight "..item.name.." compiled ("..source..")")
        else
            allGood=false
            fail("Lobby preflight "..item.name.." failed: "..source)
        end
    end
    if not allGood then
        fail("At least one module failed preflight. Nothing queued.")
        return
    end
    local fn,why,body=fetch({name="BOOTSTRAP",
        file="chapter2-no-levers-cutscene-test.lua",
        marker="Beyy Chapter 2 Standalone Integrated v33",
        cache="BeyyHub/chapter2_integrated_v33_bootstrap.lua"},false)
    if not fn then
        fail("Bootstrap failed preflight: "..tostring(why))
        return
    end
    local ok,err=pcall(queue,body)
    if not ok then
        fail("queue_on_teleport failed: "..tostring(err))
    else
        log("Four modules compiled and compact hold-test bootstrap queued. Enter Chapter 2.")
    end
    return
end
if game.PlaceId~=CHAPTER2 then
    fail("This script runs only from the lobby or Chapter 2.")
    return
end
local function launch(item)
    if cancelled() then return false end
    local fn,source=fetch(item,true)
    if cancelled() then return false end
    if not fn then
        fail(item.name.." could not start: "..tostring(source))
        return false
    end
    local ok,err=pcall(fn)
    if not ok then
        fail(item.name.." startup error: "..tostring(err))
        return false
    end
    log(item.name.." started ("..source..")")
    return true
end
-- Capture the genuine Chapter2 start before any controller moves our
-- character. Preserve its full CFrame, including facing direction.
local env=_G
if type(getgenv)=="function" then
    local ok,global=pcall(getgenv)
    if ok and type(global)=="table" then env=global end
end
local player=Players.LocalPlayer
local char=player and player.Character
local root=char and char:FindFirstChild("HumanoidRootPart")
if not root then
    local deadline=os.clock()+5
    repeat
        task.wait(0.05)
        player=Players.LocalPlayer
        char=player and player.Character
        root=char and char:FindFirstChild("HumanoidRootPart")
    until root or cancelled() or os.clock()>=deadline
end
if cancelled() then return false end
if root then
    env.__BEYY_CH2_HOLD_CAPTURE={Character=char,CFrame=root.CFrame}
    log("Original Chapter2 start saved: "..tostring(root.Position))
else
    fail("No root to capture original start; return-to-start may be unavailable")
end
env.__BEYY_CH2_HOLD_FOLLOW_SOLVER=true
log("INTEGRATED v33: v32 puzzles / v6 invisible deferred Skip / v9 instant return / v27 VacuumPower ONLY")
log("Loading: cutscene v6 INVISIBLE DEFERRED INTRO -> return v9 -> v32 unchanged solver -> Vacuum Power")
local okCutscene=launch(paths[1])
if cancelled() then return false end
local okHold=launch(paths[2])
if cancelled() then return false end
-- Do NOT wait 1.2s or force the diagnostic's 4/5 point. The existing
-- worker chooses its verified room anchor and v9 watches only large snapbacks.
local okPuzzle=launch(paths[3])
if cancelled() then return false end
local okUpgrade=launch(paths[4])
if cancelled() then return false end
if not okCutscene or not okHold or not okPuzzle or not okUpgrade then
    fail("Partial startup: cutscene="..tostring(okCutscene)..
        " hold="..tostring(okHold)..
        " puzzle="..tostring(okPuzzle)..
        " upgrades="..tostring(okUpgrade)..
        ". Check console for exact module error.")
    return false
else
    log("Four modules running: v32 native puzzles, visually hidden deferred intro Skip v6, v9 instant return, VacuumPower.")
    log("3/3: IMMEDIATE return to saved spawn even during cutscene; room snapback correction stays active.")
    log("F8: combined puzzle/hidden Skip/upgrade report; F9: return report; F12: cancel hold.")
end
return true
end
local __BEYY_CH2_NO_LEVERS_STARTED = false
local __BEYY_CH2_NO_LEVERS_DISABLED = false
local __BEYY_CH2_NO_LEVERS_FAILED = false
local __BEYY_CH2_NO_LEVERS_WANTED = false
local __BEYY_CH2_NO_LEVERS_LOADING = false
local __BEYY_CH2_NO_LEVERS_GENERATION = 0
local __BEYY_CH2_NO_LEVERS_ON_FAILURE
local function __BEYY_CH2_NO_LEVERS_SOLVING()
    if not __BEYY_CH2_NO_LEVERS_STARTED or __BEYY_CH2_NO_LEVERS_FAILED then return false end
    local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Puzzles")
    if not folder then return true end
    -- LeverPuzzleSolved is deliberately NOT part of the no-levers test gate.
    return (tonumber(folder:GetAttribute("SolvedPuzzleCount")) or 0) < 3
end
local function __BEYY_CH2_NO_LEVERS_CLEANUP()
    local env = _G
    if type(getgenv) == "function" then
        local ok, result = pcall(getgenv)
        if ok and type(result) == "table" then env = result end
    end
    -- The latest Chapter2 controller owns FOUR modules, not one.
    -- Stop in reverse startup order to avoid a surviving cutscene/HOLD
    -- worker trying to relocate the character after the hub is unloaded.
    for _, key in ipairs({
        "__BEYY_CH2_COMBO_STOP",
        "__BEYY_CH2_SPOT_STOP",
        "__BEYY_CH2_CUTSCENE_ONLY_STOP",
        "__BEYY_CH2_AUTO_UPGRADES_STOP",
    }) do
        local stop = env[key]
        if type(stop) == "function" then pcall(stop, "BeyyHub Chapter2 integrated controller stop") end
    end
    env.__BEYY_CH2_COMBO_PUZZLE_RUNNING = false
    env.__BEYY_CH2_HOLD_FOLLOW_SOLVER = nil
    env.__BEYY_CH2_HOLD_CAPTURE = nil
end
local function __BEYY_CH2_NO_LEVERS_STOP(permanent)
    __BEYY_CH2_NO_LEVERS_DISABLED = __BEYY_CH2_NO_LEVERS_DISABLED or permanent == true
    __BEYY_CH2_NO_LEVERS_WANTED = false
    __BEYY_CH2_NO_LEVERS_GENERATION += 1
    __BEYY_CH2_NO_LEVERS_STARTED = false
    __BEYY_CH2_NO_LEVERS_CLEANUP()
end
local function __BEYY_CH2_NO_LEVERS_START()
    if __BEYY_CH2_NO_LEVERS_DISABLED then return false end
    __BEYY_CH2_NO_LEVERS_WANTED = true
    __BEYY_CH2_NO_LEVERS_FAILED = false
    -- A stopped HTTP/module startup must finish cleanup before a replacement starts.
    if __BEYY_CH2_NO_LEVERS_STARTED or __BEYY_CH2_NO_LEVERS_LOADING then return true end
    __BEYY_CH2_NO_LEVERS_GENERATION += 1
    local generation = __BEYY_CH2_NO_LEVERS_GENERATION
    local function cancelled()
        return generation ~= __BEYY_CH2_NO_LEVERS_GENERATION
            or not __BEYY_CH2_NO_LEVERS_WANTED or __BEYY_CH2_NO_LEVERS_DISABLED
    end
    __BEYY_CH2_NO_LEVERS_STARTED = true
    __BEYY_CH2_NO_LEVERS_LOADING = true
    task.spawn(function()
        local ok,result=pcall(__BEYY_CH2_NO_LEVERS_RUN,cancelled)
        __BEYY_CH2_NO_LEVERS_LOADING = false
        if cancelled() then
            -- Catch stop hooks registered by a module that yielded during startup.
            __BEYY_CH2_NO_LEVERS_CLEANUP()
            if __BEYY_CH2_NO_LEVERS_WANTED and not __BEYY_CH2_NO_LEVERS_DISABLED then
                __BEYY_CH2_NO_LEVERS_START()
            end
        elseif not ok or result~=true then
            __BEYY_CH2_NO_LEVERS_FAILED = true
            warn("[BeyyHub Chapter2] Integrated v33 failed to start: "..tostring(result))
            __BEYY_CH2_NO_LEVERS_STOP(false)
            if __BEYY_CH2_NO_LEVERS_ON_FAILURE then __BEYY_CH2_NO_LEVERS_ON_FAILURE() end
        end
    end)
    print("[BeyyHub Chapter2] INTEGRATED v33: v32 puzzles, v6 invisible/deferred Skip, v9 instant hay return, v27 VacuumPower-only; key automation preserved")
    return true
end
-- Start only AFTER previous hub session cleanup, otherwise its cleanup
-- can stop freshly launched v33 cutscene/HOLD/puzzle workers.
local CACHE_FOLDER = "BeyyHub"

pcall(function()
    if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(CACHE_FOLDER)) then
        makefolder(CACHE_FOLDER)
    end
end)

local function safeRead(path)
    if type(readfile) ~= "function" then return nil end
    local ok, content = pcall(readfile, path)
    if ok and type(content) == "string" and #content > 0 then return content end
    return nil
end

local function safeWrite(path, content)
    if not content or #content == 0 or type(writefile) ~= "function" then return false end
    local ok, result = pcall(writefile, path, content)
    return ok and result ~= false
end

local __BEYY_CONFIG_PATH = "WindUI/BeyyHub/config/"
local __BEYY_CONFIG_TELEPORT_KEY = "BeyyHub_ActiveConfig_v103"
local __BEYY_CONFIG_HTTP = game:GetService("HttpService")
local __BEYY_CONFIG_TELEPORT = game:GetService("TeleportService")
local __BEYY_CONFIG_PLAYER_FOLDER = "__BeyyHubSessionConfigV103"
local __beyyConfigEnv = _G
if type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then __beyyConfigEnv = env end
end
if type(__beyyConfigEnv.__BEYY_CONFIG_SESSION_V103) ~= "table" then
    __beyyConfigEnv.__BEYY_CONFIG_SESSION_V103 = {}
end
local __beyyConfigSession = __beyyConfigEnv.__BEYY_CONFIG_SESSION_V103
local function __beyyConfigDecode(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    local ok, result = pcall(function() return __BEYY_CONFIG_HTTP:JSONDecode(raw) end)
    if ok and type(result) == "table" and type(result.__elements or result) == "table" then return result end
    return nil
end
local function __beyyPlayerConfigFolder(create)
    local player = game:GetService("Players").LocalPlayer
    if not player then return nil end
    local folder = player:FindFirstChild(__BEYY_CONFIG_PLAYER_FOLDER)
    if folder and not folder:IsA("Folder") then return nil end
    if not folder and create then
        folder = Instance.new("Folder")
        folder.Name = __BEYY_CONFIG_PLAYER_FOLDER
        folder.Parent = player
    end
    return folder
end
local function __beyyPlayerConfigValue(name, create)
    local folder = __beyyPlayerConfigFolder(create)
    if not folder then return nil end
    local value = folder:FindFirstChild(name)
    if value and not value:IsA("StringValue") then return nil end
    if not value and create then
        value = Instance.new("StringValue")
        value.Name = name
        value.Parent = folder
    end
    return value
end
local function __beyyReadConfig(name)
    if type(name) ~= "string" or not name:match("^[%w_%-%s]+$") then return nil, "invalid name" end
    local live = __beyyPlayerConfigValue(name, false)
    if live and __beyyConfigDecode(live.Value) then
        __beyyConfigSession[name] = live.Value
        return live.Value, "player-session"
    end
    local memory = __beyyConfigSession[name]
    if __beyyConfigDecode(memory) then return memory, "executor-session" end
    local ok, packet = pcall(function()
        return __BEYY_CONFIG_TELEPORT:GetTeleportSetting(__BEYY_CONFIG_TELEPORT_KEY)
    end)
    if ok and type(packet) == "table" and packet.name == name and __beyyConfigDecode(packet.json) then
        __beyyConfigSession[name] = packet.json
        return packet.json, "teleport"
    end
    local disk = safeRead(__BEYY_CONFIG_PATH .. name .. ".json")
    if __beyyConfigDecode(disk) then return disk, "disk" end
    return nil, "unavailable"
end
local function __beyyActiveConfigName()
    local folder = __beyyPlayerConfigFolder(false)
    local active = folder and folder:GetAttribute("ActiveName")
    if type(active) == "string" and active:match("^[%w_%-%s]+$") then return active end
    local ok, packet = pcall(function()
        return __BEYY_CONFIG_TELEPORT:GetTeleportSetting(__BEYY_CONFIG_TELEPORT_KEY)
    end)
    if ok and type(packet) == "table" and type(packet.name) == "string"
        and packet.name:match("^[%w_%-%s]+$") and __beyyConfigDecode(packet.json) then
        return packet.name
    end
    local disk = safeRead("BeyyHub/active_config.txt")
    if type(disk) == "string" and disk:match("^[%w_%-%s]+$") then return disk end
    return "default"
end
local function __beyyRememberConfig(name, raw)
    if not __beyyConfigDecode(raw) then return false, false end
    __beyyConfigSession[name] = raw
    local playerVerified = false
    local okPlayer, errorPlayer = pcall(function()
        local entry = __beyyPlayerConfigValue(name, true)
        if not entry then return end
        entry.Value = raw
        local folder = __beyyPlayerConfigFolder(false)
        if not folder then return end
        folder:SetAttribute("ActiveName", name)
        playerVerified = entry.Parent == folder and entry.Value == raw
            and folder:GetAttribute("ActiveName") == name
    end)
    if not okPlayer then
        warn("[BeyyHub Config] Player-session save failed: " .. tostring(errorPlayer))
    end
    local teleportOK, teleportError = pcall(function()
        __BEYY_CONFIG_TELEPORT:SetTeleportSetting(__BEYY_CONFIG_TELEPORT_KEY, {name = name, json = raw})
    end)
    if not teleportOK then
        warn("[BeyyHub Config] Teleport persistence unavailable: " .. tostring(teleportError))
    end
    return playerVerified, teleportOK
end
local function __beyySameJSON(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not __beyySameJSON(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local __beyyInitialConfig = __beyyReadConfig(__beyyActiveConfigName())

if _G.__BEYY_HUB_LOADED then
    pcall(function()
        if type(_G.__BEYY_HUB_CLEANUP) == "function" then _G.__BEYY_HUB_CLEANUP() end
    end)
    task.wait(0.5)
end
_G.__BEYY_HUB_LOADED = true
-- Preserve automatic startup unless the active config explicitly saved this toggle OFF.
do
    local enabled = true
    local config = __beyyConfigDecode(__beyyInitialConfig)
    local elements = config and (config.__elements or config)
    local entry
    if type(elements) == "table" then entry = elements.Chapter2AutoPuzzles end
    if type(entry) == "table" and entry.__type == "Toggle" and type(entry.value) == "boolean" then
        enabled = entry.value
    elseif type(entry) == "boolean" then
        enabled = entry
    end
    if enabled then __BEYY_CH2_NO_LEVERS_START() end
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local waited = 0
    while not Players.LocalPlayer and waited < 10 do
        task.wait(0.05)
        waited = waited + 0.05
    end
    LocalPlayer = Players.LocalPlayer
end
if not LocalPlayer then
    warn("[BeyyHub] LocalPlayer never became available.")
    return
end

print("[BeyyHub] LocalPlayer ready: ".. LocalPlayer.Name)

local BEYY_PLACE_IDS = {
    Lobby = 77108422251420,
    Chapter1 = 108628039999641,
    Chapter2 = 83445806734780,
    Chapter3 = 82626725163709,
}
local BEYY_CHAPTER = "Unknown"
for chapter, placeId in pairs(BEYY_PLACE_IDS) do
    if game.PlaceId == placeId then
        BEYY_CHAPTER = chapter
        break
    end
end
print(string.format("[BeyyHub] Place %s -> %s", tostring(game.PlaceId), BEYY_CHAPTER))


do
    local hubUnloaded = false
    local beyyAntiAfkConnection = LocalPlayer.Idled:Connect(function()
        if hubUnloaded then return end
        pcall(function()
            local virtualUser = game:GetService("VirtualUser")
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
    local hubWindow
    local hubNativeUI
    local hubRestoreAction = nil
    local hubCursorCleanup = nil
    _G.__BEYY_HUB_CLEANUP = function()
        hubUnloaded = true
        __BEYY_CH2_NO_LEVERS_STOP(true)
        beyyAntiAfkConnection:Disconnect()
        if hubRestoreAction then pcall(hubRestoreAction) end
        if hubCursorCleanup then pcall(hubCursorCleanup) end
        if hubWindow then pcall(function() hubWindow:Destroy() end) end
    end
    -- Beyy native UI. Embedded into each module; no remote UI dependency.
    local function createNativeUI()
        local UI = {}
        local input = game:GetService("UserInputService")
        local run = game:GetService("RunService")
        local http = game:GetService("HttpService")
        local colors = {bg=Color3.fromRGB(20,22,27), row=Color3.fromRGB(32,35,42), text=Color3.fromRGB(231,234,240), accent=Color3.fromRGB(58,104,153)}
        local function node(class, parent, props)
            local obj = Instance.new(class)
            for k,v in pairs(props or {}) do obj[k]=v end
            obj.Parent=parent
            return obj
        end
        local function label(parent, text, height)
            return node("TextLabel", parent, {Size=UDim2.new(1,0,0,height or 24), BackgroundTransparency=1, Text=tostring(text or ""), TextColor3=colors.text, TextSize=14, Font=Enum.Font.SourceSans, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left})
        end
        local function button(parent,text,size,pos)
            return node("TextButton",parent,{Size=size or UDim2.new(1,0,0,28),Position=pos or UDim2.new(),BackgroundColor3=colors.row,BorderSizePixel=0,AutoButtonColor=false,Text=tostring(text or ""),TextColor3=colors.text,TextSize=14,Font=Enum.Font.SourceSans})
        end
        local function layout(parent)
            node("UIListLayout",parent,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
            node("UIPadding",parent,{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8)})
        end
        local function configManager(folder)
            local manager={Path="WindUI/"..folder.."/config/"}
            if type(makefolder)=="function" then
                for _,path in ipairs({"WindUI","WindUI/"..folder,manager.Path}) do
                    pcall(function() if type(isfolder)~="function" or not isfolder(path) then makefolder(path) end end)
                end
            end
            function manager:AllConfigs()
                local names={}
                if type(listfiles)=="function" then
                    local ok,files=pcall(listfiles,self.Path)
                    if ok then for _,path in ipairs(files) do local name=path:match("([^/\\]+)%.json$"); if name then table.insert(names,name) end end end
                end
                return names
            end
            function manager:CreateConfig(name)
                assert(type(name)=="string" and name~="" and not name:find("[/\\]"),"Invalid config name")
                local cfg={Path=self.Path..name..".json",Elements={},CustomData={},Version=1.2,AutoLoad=false}
                function cfg:Register(key,el) self.Elements[key]=el end
                function cfg:Save()
                    assert(type(writefile)=="function","Config saving requires writefile")
                    local saved={__version=self.Version,__elements={},__custom=self.CustomData,__autoload=self.AutoLoad}
                    for key,el in pairs(self.Elements) do
                        local value=el.Value
                        if el.__type=="Slider" then value=value.Default end
                        saved.__elements[key]={__type=el.__type,value=value}
                    end
                    writefile(self.Path,http:JSONEncode(saved))
                    return saved
                end
                function cfg:Load()
                    if type(readfile)~="function" then return false,"Config loading requires readfile" end
                    local ok,data=pcall(function() return http:JSONDecode(readfile(self.Path)) end)
                    if not ok or type(data)~="table" then return false,"Failed to read config" end
                    for key,entry in pairs(data.__elements or data) do
                        local el=self.Elements[key]
                        if el and type(entry)=="table" and entry.__type==el.__type then
                            if el.__type=="Dropdown" then el:Select(entry.value) else el:Set(entry.value) end
                        end
                    end
                    self.CustomData=data.__custom or {}
                    return self.CustomData
                end
                return cfg
            end
            return manager
        end
        function UI:Notify(options)
            if self.Window and not self.Window.Destroyed then self.Window.Notice.Text=tostring(options.Title or "Beyy")..": "..tostring(options.Content or "") end
        end
        function UI:CreateWindow(options)
            local w={Closed=false,Destroyed=false,Connections={},Tabs={},ToggleKey=Enum.KeyCode.RightControl}
            self.Window=w
            local parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
            if type(gethui)=="function" then local ok,value=pcall(gethui); if ok and value then parent=value end end
            local gui=node("ScreenGui",parent,{Name="BeyyNativeHub",ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
            w.Gui=gui
            local root=node("Frame",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(640,480),BackgroundColor3=colors.bg,BorderSizePixel=0})
            node("UISizeConstraint",root,{MaxSize=Vector2.new(640,480),MinSize=Vector2.new(320,240)})
            -- UIScale keeps the fixed panel inside small screens, without layout animation.
            local scale=node("UIScale",root,{Scale=1})
            local function fit()
                local viewport=gui.AbsoluteSize
                scale.Scale=math.min(1,math.max(.1,(viewport.X-12)/640),math.max(.1,(viewport.Y-12)/480))
            end
            local function connect(signal,fn) local c=signal:Connect(fn); table.insert(w.Connections,c); return c end
            connect(gui:GetPropertyChangedSignal("AbsoluteSize"),fit); fit()
            local title=label(root,options.Title or "Beyy Hub",30); title.Position=UDim2.fromOffset(10,0); title.Size=UDim2.new(1,-48,0,30)
            title.Active=true
            local dragInput,dragX,dragY,dragPosition
            connect(title.InputBegan,function(event)
                if w.Closed or dragInput then return end
                if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
                    dragInput=event; dragX=event.Position.X; dragY=event.Position.Y; dragPosition=root.Position
                end
            end)
            connect(input.InputChanged,function(event)
                if not dragInput or w.Closed then return end
                local mouse=dragInput.UserInputType==Enum.UserInputType.MouseButton1
                if (mouse and event.UserInputType~=Enum.UserInputType.MouseMovement) or (not mouse and event~=dragInput) then return end
                local viewport=gui.AbsoluteSize
                local halfWidth,halfHeight=320*scale.Scale,240*scale.Scale
                local x=dragPosition.X.Scale*viewport.X+dragPosition.X.Offset+event.Position.X-dragX
                local y=dragPosition.Y.Scale*viewport.Y+dragPosition.Y.Offset+event.Position.Y-dragY
                x=math.clamp(x,halfWidth,math.max(halfWidth,viewport.X-halfWidth))
                y=math.clamp(y,halfHeight,math.max(halfHeight,viewport.Y-halfHeight))
                root.Position=UDim2.new(dragPosition.X.Scale,x-dragPosition.X.Scale*viewport.X,dragPosition.Y.Scale,y-dragPosition.Y.Scale*viewport.Y)
            end)
            connect(input.InputEnded,function(event)
                if event==dragInput or (dragInput and dragInput.UserInputType==Enum.UserInputType.MouseButton1 and event.UserInputType==Enum.UserInputType.MouseButton1) then dragInput=nil end
            end)
            local close=button(root,"X",UDim2.fromOffset(28,24),UDim2.new(1,-34,0,3))
            local sidebar=node("ScrollingFrame",root,{Position=UDim2.fromOffset(0,34),Size=UDim2.new(0,180,1,-72),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
            layout(sidebar)
            w.Notice=label(root,"",32); w.Notice.Position=UDim2.new(0,10,1,-34); w.Notice.Size=UDim2.new(1,-20,0,32)
            local bind="BeyyNativeCursor_"..tostring(game:GetService("Players").LocalPlayer.UserId)
            local previousBehavior,previousIcon,cursorBound
            local function releaseCursor()
                if cursorBound then return end
                previousBehavior,previousIcon=input.MouseBehavior,input.MouseIconEnabled
                cursorBound=true
                run:BindToRenderStep(bind,Enum.RenderPriority.Last.Value+100,function()
                    input.MouseBehavior=Enum.MouseBehavior.Default; input.MouseIconEnabled=true
                end)
            end
            local function restoreCursor()
                if not cursorBound then return end
                run:UnbindFromRenderStep(bind); cursorBound=false
                input.MouseBehavior=previousBehavior; input.MouseIconEnabled=previousIcon
            end
            function w:Open() if self.Destroyed then return end; self.Closed=false; gui.Enabled=true; releaseCursor() end
            function w:Close() self.Closed=true; gui.Enabled=false; self.Capture=nil; dragInput=nil; restoreCursor() end
            function w:SetToggleKey(key) self.ToggleKey=typeof(key)=="EnumItem" and key or Enum.KeyCode[tostring(key)] or Enum.KeyCode.RightControl end
            function w:EditOpenButton() end
            function w:Destroy()
                if self.Destroyed then return end
                self:Close(); self.Destroyed=true
                for _,c in ipairs(self.Connections) do c:Disconnect() end
                table.clear(self.Connections); gui:Destroy()
            end
            connect(close.Activated,function() w:Close() end)
            connect(input.InputBegan,function(event,processed)
                if w.Capture and event.UserInputType==Enum.UserInputType.Keyboard and event.KeyCode~=Enum.KeyCode.Unknown then
                    local capture=w.Capture; w.Capture=nil; capture:Set(event.KeyCode.Name); return
                end
                if not processed and not input:GetFocusedTextBox() and event.KeyCode==w.ToggleKey then if w.Closed then w:Open() else w:Close() end end
            end)
            w.ConfigManager=configManager(options.Folder or "BeyyHub")
            function w:Tab(opts)
                local tab={Window=self}
                local nav=button(sidebar,opts.Title)
                local page=node("ScrollingFrame",root,{Position=UDim2.fromOffset(184,34),Size=UDim2.new(1,-190,1,-72),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false})
                layout(page)
                tab.Page=page; tab.Nav=nav; table.insert(self.Tabs,tab)
                function tab:Select() for _,other in ipairs(w.Tabs) do other.Page.Visible=other==self; other.Nav.BackgroundColor3=other==self and colors.accent or colors.row end end
                connect(nav.Activated,function() tab:Select() end)
                if #self.Tabs==1 then tab:Select() end
                local function row(opts,height)
                    local frame=node("Frame",page,{Size=UDim2.new(1,-2,0,height or 42),BackgroundColor3=colors.row,BorderSizePixel=0})
                    local heading=label(frame,opts.Title,24); heading.Position=UDim2.fromOffset(8,2); heading.Size=UDim2.new(1,-160,0,24)
                    return frame
                end
                local function control(kind,opts,value)
                    local el={__type=kind,Value=value}
                    function el:Callback(v)
                        if opts.Callback then local ok,err=pcall(opts.Callback,v); if not ok then UI:Notify({Title="Control error",Content=tostring(err)}) end end
                    end
                    return el
                end
                function tab:Section(opts) return label(page,opts.Title,26) end
            function tab:CollapsibleGroup(opts)
                local title=tostring(opts.Title or "Settings")
                local expanded=opts.Opened==true
                local trigger=button(page,"",UDim2.new(1,-2,0,30))
                local body=node("Frame",page,{
                    Size=UDim2.new(1,-2,0,0),
                    AutomaticSize=Enum.AutomaticSize.Y,
                    BackgroundTransparency=1,Visible=expanded
                })
                layout(body)
                local function redraw()
                    trigger.Text=(expanded and "▼ " or "▶ ")..title
                    body.Visible=expanded
                end
                connect(trigger.Activated,function()
                    expanded=not expanded
                    redraw()
                end)
                redraw()
                local group={}
                for _,kind in ipairs({"Section","Paragraph","Button","Toggle","Slider","Input","Keybind","Dropdown"}) do
                    group[kind]=function(_,options)
                        local existing={}
                        for _,child in ipairs(page:GetChildren()) do existing[child]=true end
                        local element=tab[kind](tab,options)
                        for _,child in ipairs(page:GetChildren()) do
                            if not existing[child] and child:IsA("GuiObject") then
                                child.Parent=body
                            end
                        end
                        return element
                    end
                end
                return group
            end

                function tab:Paragraph(opts)
                    -- Static help paragraphs are omitted; live status panels remain.
                    local live=opts.Title=="Session" or tostring(opts.Title):find("Status",1,true)~=nil
                    if not live and opts.Title~="Configs unavailable" then
                        return {SetDesc=function() end,SetTitle=function() end}
                    end
                    local frame=node("Frame",page,{Size=UDim2.new(1,-2,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
                    layout(frame)
                    local heading=label(frame,opts.Title); heading.AutomaticSize=Enum.AutomaticSize.Y
                    local desc=label(frame,live and opts.Desc or ""); desc.AutomaticSize=Enum.AutomaticSize.Y
                    local el={}
                    function el:SetDesc(v) desc.Text=tostring(v or "") end
                    function el:SetTitle(v) heading.Text=tostring(v or "") end
                    return el
                end
                function tab:Button(opts)
                    local b=button(page,opts.Title)
                    connect(b.Activated,function() if opts.Callback then local ok,err=pcall(opts.Callback); if not ok then UI:Notify({Title="Action error",Content=tostring(err)}) end end end)
                    return b
                end
                function tab:Toggle(opts)
                    local el=control("Toggle",opts,opts.Value==true)
                    local frame=row(opts); local b=button(frame,"",UDim2.fromOffset(100,28),UDim2.new(1,-108,0,5))
                    local function redraw() b.Text=el.Value and "ON" or "OFF"; b.BackgroundColor3=el.Value and colors.accent or colors.bg end
                    function el:Set(v) self.Value=v==true; redraw(); self:Callback(self.Value) end
                    connect(b.Activated,function() el:Set(not el.Value) end); redraw(); return el
                end
                function tab:Slider(opts)
                local spec=opts.Value or {}
                local el=control("Slider",opts,{Min=spec.Min or 0,Max=spec.Max or 100,Default=spec.Default or 0})
                local step=tonumber(opts.Step) or 1
                local fraction=tostring(step):match("%.(%d+)")
                local decimals=math.min(6,fraction and #fraction or 0)
                local function displayNumber(value)
                    local shown=string.format("%."..decimals.."f",value)
                    if decimals>0 then
                        shown=shown:gsub("0+$","")
                        shown=shown:gsub("%.$","")
                    end
                    return shown
                end
                local frame=row(opts)
                local field=node("TextBox",frame,{
                    Size=UDim2.fromOffset(64,28),Position=UDim2.new(1,-100,0,5),
                    Text=displayNumber(el.Value.Default),BackgroundColor3=colors.bg,
                    TextColor3=colors.text,TextSize=14,Font=Enum.Font.SourceSans,
                    ClearTextOnFocus=false
                })
                function el:Set(v)
                    local n=tonumber(v)
                    if not n or n~=n or n==math.huge or n==-math.huge then
                        field.Text=displayNumber(self.Value.Default)
                        return
                    end
                    if step>0 then n=self.Value.Min+math.round((n-self.Value.Min)/step)*step end
                    n=math.clamp(n,self.Value.Min,self.Value.Max)
                    local shown=displayNumber(n)
                    self.Value.Default=tonumber(shown) or n
                    field.Text=shown
                    self:Callback(self.Value.Default)
                end
                local minus=button(frame,"-",UDim2.fromOffset(26,28),UDim2.new(1,-130,0,5))
                local plus=button(frame,"+",UDim2.fromOffset(26,28),UDim2.new(1,-32,0,5))
                connect(minus.Activated,function() el:Set(el.Value.Default-step) end)
                connect(plus.Activated,function() el:Set(el.Value.Default+step) end)
                connect(field.FocusLost,function() el:Set(field.Text) end)
                return el
            end
            function tab:Input(opts)
                    local el=control("Input",opts,tostring(opts.Value or "")); local frame=row(opts,70)
                    local field=node("TextBox",frame,{Position=UDim2.fromOffset(8,32),Size=UDim2.new(1,-16,0,28),Text=el.Value,PlaceholderText=opts.Placeholder or "",BackgroundColor3=colors.bg,TextColor3=colors.text,TextSize=14,Font=Enum.Font.SourceSans,ClearTextOnFocus=false})
                    function el:Set(v) self.Value=tostring(v or ""); field.Text=self.Value; self:Callback(self.Value) end
                    connect(field.FocusLost,function() el:Set(field.Text) end); return el
                end
                function tab:Keybind(opts)
                    local initial=opts.Value or "RightControl"; if typeof(initial)=="EnumItem" then initial=initial.Name end
                    local el=control("Keybind",opts,initial); local frame=row(opts)
                    local b=button(frame,initial,UDim2.fromOffset(140,28),UDim2.new(1,-148,0,5))
                    function el:Set(v) self.Value=typeof(v)=="EnumItem" and v.Name or tostring(v); b.Text=self.Value; self:Callback(self.Value) end
                    connect(b.Activated,function() w.Capture=el; b.Text="Press a key" end); return el
                end
                function tab:Dropdown(opts)
                    local el=control("Dropdown",opts,opts.Value or (opts.Multi and {} or ""))
                    local frame=row(opts); local b=button(frame,"",UDim2.fromOffset(140,28),UDim2.new(1,-148,0,5))
                    local choices=node("ScrollingFrame",page,{Size=UDim2.new(1,-2,0,160),Visible=false,BackgroundColor3=colors.bg,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y}); layout(choices)
                    local choiceButtons={}; local choiceConnections={}
                    local function selected(value) if type(el.Value)~="table" then return el.Value==value end; for k,v in pairs(el.Value) do if v==value or (k==value and v==true) then return true end end; return false end
                    local function redraw()
                        local values={}; if type(el.Value)=="table" then for k,v in pairs(el.Value) do table.insert(values,tostring(v==true and k or v)) end else table.insert(values,tostring(el.Value)) end
                        b.Text=#values>0 and table.concat(values,", ") or "Choose"
                        for value,cb in pairs(choiceButtons) do cb.Text=(selected(value) and "[x] " or "[ ] ")..tostring(value) end
                    end
                    function el:Select(v) self.Value=opts.Multi and (type(v)=="table" and table.clone(v) or {v}) or v; redraw(); self:Callback(self.Value) end
                    el.Set=el.Select
                    function el:Refresh(values)
                        for _,c in ipairs(choiceConnections) do
                            c:Disconnect()
                            local index=table.find(w.Connections,c)
                            if index then table.remove(w.Connections,index) end
                        end
                        table.clear(choiceConnections)
                        for _,cb in pairs(choiceButtons) do cb:Destroy() end; table.clear(choiceButtons)
                        for _,value in ipairs(values or {}) do
                            local cb=button(choices,tostring(value)); choiceButtons[value]=cb
                            local c=cb.Activated:Connect(function()
                                if opts.Multi then
                                    local nextValues={}; for _,candidate in ipairs(values) do if (candidate==value and not selected(candidate)) or (candidate~=value and selected(candidate)) then table.insert(nextValues,candidate) end end
                                    el:Select(nextValues)
                                else el:Select(value); choices.Visible=false end
                            end)
                            table.insert(choiceConnections,c); table.insert(w.Connections,c)
                        end
                        redraw()
                    end
                    connect(b.Activated,function() choices.Visible=not choices.Visible end); el:Refresh(opts.Values); return el
                end
                return tab
            end
            function w:Section(opts)
                label(sidebar,opts.Title,24)
                local group={}; function group:Tab(tabOpts) return w:Tab(tabOpts) end
                return group
            end
            w:Open()
            return w
        end
        return UI
    end
    hubNativeUI = createNativeUI()
    hubWindow = hubNativeUI:CreateWindow({
        Title = " Beyy Hub Main ",
        Author = "by beyy",
        Icon = "search",
        Folder = "BeyyHub",
        Size = UDim2.fromOffset(640, 480),
        Theme = "Dark",
        Transparent = false,
        Resizable = true,
        SideBarWidth = 200,
        HideSearchBar = true,
        OpenButton = { Enabled = false },
    })
    print(("[BeyyHub Startup] %s window constructed after %.2fs in module"):format(
        BEYY_CHAPTER, os.clock() - __BEYY_BOOT_T0))
    pcall(function() hubWindow:SetToggleKey(Enum.KeyCode.RightControl) end)
    pcall(function() hubWindow:EditOpenButton({ Enabled = false }) end)

    local function hideNonFarmMenu()
        if not hubUnloaded and hubWindow and not hubWindow.Closed then
            pcall(function() hubWindow:Close() end)
        end
    end
    hideNonFarmMenu()

    if BEYY_CHAPTER == "Chapter2" or BEYY_CHAPTER == "Chapter3" then
        hubCursorCleanup = function() hubWindow:Close() end
    end

    local overviewTab = hubWindow:Tab({ Title = "Overview & Settings", Icon = "house" })
    overviewTab:Section({ Title = "Detected chapter" })
    overviewTab:Paragraph({
        Title = BEYY_CHAPTER .. " (Place ID " .. tostring(game.PlaceId) .. ")",
        Desc = "Farming and Inventory are available in every chapter. Right Ctrl opens or closes the menu.",
    })
    overviewTab:Section({ Title = "Shared menu" })
    overviewTab:Keybind({
        Title = "Menu keybind", Value = "RightControl",
        Callback = function(value)
            local key = typeof(value) == "EnumItem" and value or Enum.KeyCode[value]
            if key then pcall(function() hubWindow:SetToggleKey(key) end) end
        end,
    })
    overviewTab:Button({
        Title = "Unload Hub",
        Callback = function() pcall(_G.__BEYY_HUB_CLEANUP) end,
    })

    local Registry = {}
    local autoCutsceneEnableAfterLevers
    local autoCutsceneDisableAfterHandIn
    local cutscenePlayable = false
    local cutsceneBypassRefresh = nil
    local gemCutsceneCameraAim = nil
    local autoCutsceneSignals = {}
    local sharedFarmPuzzleBusy = function() return false end
    local keyPuzzleCameraBusy = function() return sharedFarmPuzzleBusy() end
    local postPuzzleKeyPriority = false
    local keyObjectiveLatched = false
    local finalEndingProtected = false
    local puzzleReleaseObserved = LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true
    local leverBypassUntil = 0
    local puzzleBypassUntil = 0
    local keyObjectivePhase = function() return keyObjectiveLatched end
    local sharedFarmDefaults = {
        AutoPickHay=false, AutoCollectDroppedHay=false, AutoCollectGems=false, CollectInterval=0.5,
        AutoSellHay=false, SellThreshold=25, SellOnlyIfFull=false,
        AutoUseTNT=false, AutoUsePitchfork=false, AutoDeployDrone=false,
        TntLightCooldown=0, TntThrowDelay=0.4,
        AutoUseVacuum=false, VacuumHotbarSlot=5, ToolInterval=0.5,
        AutoFindNeedle=false, AutoPickupNeedle=false, AutoHandInNeedle=false, NeedleInterval=1,
        AutoBuyTools=false, BuyToolsList={"Pitchfork"}, BuyInterval=1,
        UpgBagSize=false, UpgExtraTake=false, UpgGemValue=false, UpgHayValue=false, PermInterval=0.5,
        UpgCapacity=false, UpgHandSpeed=false, UpgHandGrab=false, UpgHandHold=false,
        UpgTntLuck=false, UpgTntCooldown=false, UpgTntPower=false,
        UpgPitchCooldown=false, UpgPitchHold=false, UpgPitchSweep=false,
        UpgDroneSpeed=false, UpgDroneGrab=false, UpgDroneCapacity=false,
        UpgVacPower=false, UpgVacCooling=false, UpgVacRuntime=true,
    }
    local sharedFarmState = {}
    for key, value in pairs(sharedFarmDefaults) do sharedFarmState[key] = value end
    local sharedFarmPath = CACHE_FOLDER .. "/farming_inventory_shared.json"
    local httpService = game:GetService("HttpService")
    local function importSharedFarmSettings()
        local raw = safeRead(sharedFarmPath)
        if not raw then return end
        local ok, decoded = pcall(function() return httpService:JSONDecode(raw) end)
        if not ok or type(decoded) ~= "table" then return end
        local sourceSettings = decoded.__elements or decoded
        for key, default in pairs(sharedFarmDefaults) do
            local value = sourceSettings[key]
            if type(value) == "table" and value.__type then value = value.value end
            if type(default) == "boolean" and type(value) == "boolean" then
                sharedFarmState[key] = value
            elseif type(default) == "number" and type(value) == "number" then
                sharedFarmState[key] = value
            elseif type(default) == "table" and type(value) == "table" then
                sharedFarmState[key] = value
            end
        end
    end
    importSharedFarmSettings()
    -- Restore enabled tool toggles before workers start, even when Solara
    -- cannot read the separate shared-farming disk file.
    local farmTeleportKey = "BeyyHub_FarmTools_v103"
    local configSnapshot = __beyyConfigDecode(__beyyInitialConfig)
    local configElements = configSnapshot and (configSnapshot.__elements or configSnapshot)
    if type(configElements) == "table" then
        for key, default in pairs(sharedFarmDefaults) do
            local entry = configElements[key]
            local value = type(entry) == "table" and entry.__type and entry.value or entry
            if type(value) == type(default) then sharedFarmState[key] = value end
        end
    end
    local teleportOK, farmTeleportState = pcall(function()
        return __BEYY_CONFIG_TELEPORT:GetTeleportSetting(farmTeleportKey)
    end)
    if teleportOK and type(farmTeleportState) == "table" then
        for key, default in pairs(sharedFarmDefaults) do
            local value = farmTeleportState[key]
            if type(value) == type(default) then sharedFarmState[key] = value end
        end
    end
    print("[BeyyHub Tools] Restored state: TNT=" .. tostring(sharedFarmState.AutoUseTNT) ..
        " Pitchfork=" .. tostring(sharedFarmState.AutoUsePitchfork) ..
        " Drone=" .. tostring(sharedFarmState.AutoDeployDrone) ..
        " Vacuum=" .. tostring(sharedFarmState.AutoUseVacuum))
    local function saveSharedFarmSettings()
        pcall(function() safeWrite(sharedFarmPath, httpService:JSONEncode(sharedFarmState)) end)
        pcall(function() __BEYY_CONFIG_TELEPORT:SetTeleportSetting(farmTeleportKey, sharedFarmState) end)
    end
    local farmingSection = hubWindow:Section({ Title = "Farming", Icon = "wheat", Opened = true })
    local collectingTab = farmingSection:Tab({ Title = "Collecting", Icon = "wheat" })
    local sellingTab = farmingSection:Tab({ Title = "Selling", Icon = "coins" })
    local toolsTab = farmingSection:Tab({ Title = "Tools", Icon = "hammer" })
    local needleTab = farmingSection:Tab({ Title = "Needle", Icon = "search" })
    local inventorySection = hubWindow:Section({ Title = "Inventory", Icon = "backpack", Opened = true })
    local shopTab = inventorySection:Tab({ Title = "Shop Items", Icon = "shopping-cart" })
    local upgradesTab = inventorySection:Tab({ Title = "Upgrades", Icon = "trending-up" })
    local function farmToggle(tab, key, title, desc)
        local element = tab:Toggle({
            Title=title, Desc=desc, Value=sharedFarmState[key],
            Callback=function(enabled)
                sharedFarmState[key] = enabled == true
                saveSharedFarmSettings()
            end,
        })
        Registry[key] = element
        return element
    end
    local function farmSlider(tab, key, title, low, high, step, desc)
        local element = tab:Slider({
            Title=title, Desc=desc, Step=step,
            Value={Min=low, Max=high, Default=sharedFarmState[key]},
            Callback=function(value)
                sharedFarmState[key] = tonumber(value) or sharedFarmDefaults[key]
                saveSharedFarmSettings()
            end,
        })
        Registry[key] = element
        return element
    end
    collectingTab:Section({ Title="Resource Collecting" })
    farmToggle(collectingTab,"AutoPickHay","Auto Pick Hay")
    farmToggle(collectingTab,"AutoCollectDroppedHay","Auto Collect Dropped Hay")
    farmToggle(collectingTab,"AutoCollectGems","Auto Collect Gems")
    farmSlider(collectingTab,"CollectInterval","Loop Interval (s)",0.1,3,0.1)
    sellingTab:Section({ Title="Selling" })
    farmToggle(sellingTab,"AutoSellHay","Auto Sell Hay")
    farmSlider(sellingTab,"SellThreshold","Sell When Hay >=",1,250,1)
    farmToggle(sellingTab,"SellOnlyIfFull","Only Sell If Full")
    toolsTab:Section({ Title="Auto Tool Usage" })
    toolsTab:Paragraph({ Title="Tools operate when the chapter supplies the required hay and tool remotes." })
    farmToggle(toolsTab,"AutoUseTNT","Auto Use TNT")
    farmSlider(toolsTab,"TntLightCooldown","TNT Light Cooldown (s)",0,60,0.05)
    farmSlider(toolsTab,"TntThrowDelay","TNT Throw Delay After Lighting (s)",0,5,0.05)
    farmToggle(toolsTab,"AutoUsePitchfork","Auto Use Pitchfork")
    farmToggle(toolsTab,"AutoDeployDrone","Auto Deploy Drone")
    farmToggle(toolsTab,"AutoUseVacuum","Auto Use Vacuum (live heat + cooldown)",
        "Releases suction during menus, cutscenes and needle interactions.")
    farmSlider(toolsTab,"VacuumHotbarSlot","Vacuum Hotbar Slot (fallback)",1,9,1)
    farmSlider(toolsTab,"ToolInterval","Tool Interval (s)",0.2,5,0.1)
    needleTab:Section({ Title="Needle (TOP PRIORITY)" })
    needleTab:Paragraph({ Title="When a needle is exposed, harvesting pauses automatically." })
    farmToggle(needleTab,"AutoFindNeedle","Auto Find Needle","Also picks up an exposed key automatically (no separate pickup toggle required).")
    farmToggle(needleTab,"AutoPickupNeedle","Auto Pick Up Needle")
    local pickupStatus = needleTab:Paragraph({ Title="Key / Needle Pickup Status", Desc="Waiting for the next pickup scan." })
    local lastPickupStatus
    local function setPickupStatus(message)
        if message == lastPickupStatus then return end
        lastPickupStatus = message
        pcall(function() pickupStatus:SetDesc(message) end)
    end
    farmToggle(needleTab,"AutoHandInNeedle","Auto Hand In Needle")
    farmSlider(needleTab,"NeedleInterval","Needle Scan Interval (s)",0.2,3,0.1)
    shopTab:Section({ Title="Purchasing" })
    Registry.BuyToolsList = shopTab:Dropdown({
        Title="Buy Tools Selection",
        Values={"Pitchfork","TNT","Drone","Infinite Bag","Capacity Bag"},
        Value=sharedFarmState.BuyToolsList, Multi=true, AllowNone=true,
        Callback=function(value)
            sharedFarmState.BuyToolsList=value
            saveSharedFarmSettings()
        end,
    })
    farmToggle(shopTab,"AutoBuyTools","Auto Buy Selected Tools")
    farmSlider(shopTab,"BuyInterval","Buy Interval (s)",0.5,5,0.1)
    upgradesTab:Section({ Title="Permanent (Gems)" })
    farmToggle(upgradesTab,"UpgBagSize","Auto Upgrade Bag Size")
    farmToggle(upgradesTab,"UpgExtraTake","Auto Upgrade Hand Grab Amount")
    farmToggle(upgradesTab,"UpgGemValue","Auto Upgrade Gem Value")
    farmToggle(upgradesTab,"UpgHayValue","Auto Upgrade Hay Value")
    farmSlider(upgradesTab,"PermInterval","Permanent Loop (s)",0.5,5,0.1)
    upgradesTab:Section({ Title="Hand (Cash)" })
    farmToggle(upgradesTab,"UpgHandSpeed","Auto Hand Speed")
    farmToggle(upgradesTab,"UpgHandGrab","Auto Hand Grasp")
    farmToggle(upgradesTab,"UpgHandHold","Auto Hand Hold")
    upgradesTab:Section({ Title="TNT (Cash)" })
    farmToggle(upgradesTab,"UpgTntLuck","Auto TNT Lucky Blast")
    farmToggle(upgradesTab,"UpgTntCooldown","Auto TNT Cooldown")
    farmToggle(upgradesTab,"UpgTntPower","Auto TNT Power")
    upgradesTab:Section({ Title="Pitchfork (Cash)" })
    farmToggle(upgradesTab,"UpgPitchCooldown","Auto Pitchfork Cooldown")
    farmToggle(upgradesTab,"UpgPitchHold","Auto Pitchfork Hold")
    farmToggle(upgradesTab,"UpgPitchSweep","Auto Pitchfork Sweep")
    upgradesTab:Section({ Title="Drone (Cash)" })
    farmToggle(upgradesTab,"UpgDroneSpeed","Auto Drone Speed")
    farmToggle(upgradesTab,"UpgDroneGrab","Auto Drone Grasp")
    farmToggle(upgradesTab,"UpgDroneCapacity","Auto Drone Capacity")
    upgradesTab:Section({ Title="Vacuum (Cash)" })
    farmToggle(upgradesTab,"UpgVacPower","Auto Vacuum Power")
    farmToggle(upgradesTab,"UpgVacCooling","Auto Vacuum Cooling")
    farmToggle(upgradesTab,"UpgVacRuntime","Auto Vacuum Runtime")
    upgradesTab:Section({ Title="Capacity (Cash)" })
    farmToggle(upgradesTab,"UpgCapacity","Auto Upgrade Carry Capacity")

    local needleFolder = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    local sharedGameConfig, sharedUpgradeConfig
    if needleFolder then
        pcall(function() sharedGameConfig=require(needleFolder:WaitForChild("Config",2)) end)
        pcall(function()
            local shared=ReplicatedStorage:FindFirstChild("Shared")
            local configs=shared and shared:FindFirstChild("Configs")
            local module=configs and configs:FindFirstChild("UpgradeConfig")
            if module then sharedUpgradeConfig=require(module) end
        end)
    end
    local function farmRemote(name)
        local folder=ReplicatedStorage:FindFirstChild("NeedleHaystack")
        local result=folder and folder:FindFirstChild(name)
        return result and result:IsA("RemoteEvent") and result or nil
    end
    local function sendFarmRemote(name,...)
        local remote=farmRemote(name)
        if not remote then return false end
        local args=table.pack(...)
        return pcall(function() remote:FireServer(table.unpack(args,1,args.n)) end)
    end
    local function farmRoot()
        local character=LocalPlayer.Character
        return character and character:FindFirstChild("HumanoidRootPart")
    end
    local function farmBlocked()
        return hubUnloaded or BEYY_CHAPTER=="Lobby"
            or (BEYY_CHAPTER=="Chapter2" and (sharedFarmPuzzleBusy() or keyObjectivePhase()))
            or LocalPlayer:GetAttribute("NeedleInputLocked")==true
            or LocalPlayer:GetAttribute("CutsceneActive")==true
            or LocalPlayer:GetAttribute("HintViewerOpen")==true
    end
    local function keyInteractionBlocked()
        -- Release flags are normal while the exposed Chapter 2 key is ready.
        -- Keep lever/colour camera control and hint-viewer safety intact.
        local ready = BEYY_CHAPTER=="Chapter2" and keyObjectivePhase()
        return hubUnloaded or BEYY_CHAPTER=="Lobby" or keyPuzzleCameraBusy()
            or (not ready and LocalPlayer:GetAttribute("NeedleInputLocked")==true)
            or (not ready and LocalPlayer:GetAttribute("CutsceneActive")==true)
            or (not ready and LocalPlayer:GetAttribute("Chapter2ReleaseActive")==true)
            or LocalPlayer:GetAttribute("HintViewerOpen")==true
    end
    local cachedExposedNeedle = nil
    local nextNeedleFullScanAt = 0
    local lastKeyIdWarningAt = -math.huge
    local function keyHayId(part)
        if not part then return nil end
        local value = tonumber(part:GetAttribute("HayId"))
        if value ~= nil then return value end
        local parent = part.Parent
        if parent and parent:IsA("Model") then
            return tonumber(parent:GetAttribute("HayId"))
        end
        return nil
    end
    local function exposedNeedle()
        local rootFolder=Workspace:FindFirstChild("NeedleObjectiveServer")
        local folder=rootFolder
        local cached=cachedExposedNeedle
        if folder and cached and cached.Parent and cached:IsDescendantOf(folder) then
            local hidden=cached:GetAttribute("HIDDEN_WITHIN")
            if cached:GetAttribute("IsNeedleObjective")==true
                and (hidden == nil or hidden == false)
                and keyHayId(cached) ~= nil then
                return cached
            end
        end
        local now=os.clock()
        if now < nextNeedleFullScanAt then return nil end
        nextNeedleFullScanAt=now+(BEYY_CHAPTER=="Chapter2" and 0.01 or 0.14)
        cachedExposedNeedle=nil
        if not folder then return nil end
        for _,item in ipairs(folder:GetDescendants()) do
            if item:IsA("BasePart") and item:GetAttribute("IsNeedleObjective")==true then
                local hidden=item:GetAttribute("HIDDEN_WITHIN")
                if hidden == nil or hidden == false then
                    if keyHayId(item) ~= nil then
                        cachedExposedNeedle=item
                        return item
                    elseif now - lastKeyIdWarningAt >= 5 then
                        lastKeyIdWarningAt = now
                        print("[BeyyHub Key] Visible objective found; waiting for numeric HayId replication")
                    end
                end
            end
        end
    end
    keyObjectivePhase = function()
        if BEYY_CHAPTER~="Chapter2" then return false end
        -- Pending key hand-in stays prioritized even after bypass shutdown.
        if keyObjectiveLatched then return true end
        if finalEndingProtected then return false end
        -- NO-LEVERS TEST: even without the lever-release cinematic,
        -- start searching hay once all three replicated puzzles are solved.
        -- Key pickup and hand-in still require native objective/escape state.
        if not postPuzzleKeyPriority then
            local folder = ReplicatedStorage:FindFirstChild("Puzzles")
            if folder and (tonumber(folder:GetAttribute("SolvedPuzzleCount")) or 0)>=3 then
                postPuzzleKeyPriority=true
                print("[BeyyHub Key] No-levers test: 3 puzzles completed; searching for native key")
            end
        end
        -- Completed puzzles do NOT mean the key has emerged yet. Continue
        -- tool use to expose it; only preempt tools once exposed/owned.
        if (postPuzzleKeyPriority or puzzleReleaseObserved
            or LocalPlayer:GetAttribute("Chapter2ReleaseActive")==true)
            and (LocalPlayer:GetAttribute("NeedleOwned")==true or exposedNeedle()~=nil) then
            postPuzzleKeyPriority = true
            keyObjectiveLatched = true
            print("[BeyyHub Key] Objective exposed/owned; pausing tools for immediate pickup and hand-in")
            return true
        end
        return false
    end
    local needleBusy=false
    local function pickupRequested()
        return sharedFarmState.AutoFindNeedle == true or sharedFarmState.AutoPickupNeedle == true
            or keyObjectivePhase()
    end
    local function handInRequested()
        return sharedFarmState.AutoHandInNeedle == true or keyObjectivePhase()
    end
    local function needlePriority()
        if needleBusy or keyObjectivePhase() then return true end
        if LocalPlayer:GetAttribute("NeedleOwned")==true then
            return sharedFarmState.AutoHandInNeedle or sharedFarmState.AutoPickupNeedle
        end
        return pickupRequested() and exposedNeedle()~=nil
    end
    -- Tool remotes do not need the camera/mouse during Number and Picture.
    -- Full farmBlocked() includes allPuzzlesRunning, so auto-start otherwise
    -- prevents tools from EVER running before the key phase.
    local function toolBlockReason()
        if hubUnloaded or BEYY_CHAPTER=="Lobby" then return "hub inactive" end
        if BEYY_CHAPTER=="Chapter2" then
            if finalEndingProtected then return "final ending" end
            if LocalPlayer:GetAttribute("IntroCutsceneFinished")~=true then return "intro" end
            if keyPuzzleCameraBusy() then return "lever/colour camera" end
            if keyObjectivePhase() or needleBusy or LocalPlayer:GetAttribute("NeedleOwned")==true
                or needlePriority() then return "exposed key" end
            if LocalPlayer:GetAttribute("HintViewerOpen")==true then return "hint viewer" end
            -- CutsceneActive / Chapter2ReleaseActive are not themselves a
            -- reason to block remote tools while the key is still hidden.
            -- The lever/colour controllers and actual key pickup are protected.
            return nil
        end
        if farmBlocked() or needlePriority() then return "gameplay blocked" end
        return nil
    end
    -- Share the hay-list snapshot between nearby hay search and tool workers.
    -- An expired entry is ignored until refresh; no stale entry is interacted
    -- with because Parent/attribute checks below are still live.
    local hayChildrenSnapshot, haySnapshotFolder = nil, nil
    local nextHaySnapshotAt = -math.huge
    local recentKeyHayAttempts = {}
    local function closestInFolder(folderName,idName,limit,avoidRecent)
        local folder=Workspace:FindFirstChild(folderName)
        local root=farmRoot()
        if not folder or not root then return nil,nil end
        local now=os.clock()
        local children
        if folderName=="HaystackClient" then
            if haySnapshotFolder~=folder or now>=nextHaySnapshotAt then
                haySnapshotFolder=folder
                hayChildrenSnapshot=folder:GetChildren()
                nextHaySnapshotAt=now+0.65
            end
            children=hayChildrenSnapshot
        else
            children=folder:GetChildren()
        end
        local best,bestId,bestSquared=nil,nil,limit*limit
        local origin=root.Position
        for _,obj in ipairs(children) do
            if obj.Parent==folder then
                local part=obj:IsA("BasePart") and obj or
                    (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true)))
                if part and part.Parent then
                    local id=part:GetAttribute(idName) or obj:GetAttribute(idName)
                    if idName=="Dropped" then id=obj end
                    if id and (not avoidRecent or (recentKeyHayAttempts[id] or 0)<=now) then
                        local delta=part.Position-origin
                        local squared=delta:Dot(delta)
                        if squared<bestSquared then best,bestId,bestSquared=part,id,squared end
                    end
                end
            end
        end
        return best,bestId
    end
    local function bagFull()
        return (tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0)
            >= (tonumber(LocalPlayer:GetAttribute("HayCapacity")) or 25)
    end
    local function postPuzzleKeySearch()
        return BEYY_CHAPTER=="Chapter2" and not hubUnloaded and not finalEndingProtected
            and (postPuzzleKeyPriority or puzzleReleaseObserved)
            and LocalPlayer:GetAttribute("NeedleOwned") ~= true
            and not keyPuzzleCameraBusy() and not needlePriority()
            and LocalPlayer:GetAttribute("HintViewerOpen") ~= true
    end
    local lastKeySearchNotice = -math.huge
    local nextKeyHayRequestAt, nextKeySellRequestAt = 0, 0
    local lastKeyAttemptPruneAt, totalKeyHayRequests = 0, 0
    task.spawn(function()
        while not hubUnloaded do
            -- Keep key pickup on its separate fast 50ms loop. Hidden-key hay
            -- requests have a 650ms minimum to limit full-world scans.
            local interval = math.max(0.1, tonumber(sharedFarmState.CollectInterval) or 0.5)
            if BEYY_CHAPTER=="Chapter2" and (postPuzzleKeyPriority or puzzleReleaseObserved)
                and not finalEndingProtected then
                interval = math.min(interval, 0.35)
            end
            task.wait(interval)
            needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            local ordinaryFarm = not farmBlocked() and not needlePriority()
            local findHiddenKey = postPuzzleKeySearch()
            if needleFolder and (ordinaryFarm or findHiddenKey) then
                -- Finding a concealed key remains enabled after the puzzle
                -- cutscene, regardless of the separate AutoPickHay switch.
                -- Actual exposed-key pickup preempts this loop immediately.
                local now=os.clock()
                if findHiddenKey and bagFull() and now>=nextKeySellRequestAt then
                    nextKeySellRequestAt=now+1.5
                    sendFarmRemote("SellHay")
                end
                if findHiddenKey and now-lastKeyAttemptPruneAt>=8 then
                    lastKeyAttemptPruneAt=now
                    for hayId,expires in pairs(recentKeyHayAttempts) do
                        if expires<=now then recentKeyHayAttempts[hayId]=nil end
                    end
                end
                if ((ordinaryFarm and sharedFarmState.AutoPickHay)
                    or ((sharedFarmState.AutoFindNeedle or findHiddenKey) and not exposedNeedle()))
                    and not bagFull() and (not findHiddenKey or now>=nextKeyHayRequestAt) then
                    local hay,id=closestInFolder("HaystackClient","HayId",30,findHiddenKey)
                    if id then
                        local nearby={}
                        local radius=tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
                        if radius>0 and hay then
                            local folder=Workspace:FindFirstChild("HaystackClient")
                            if folder then
                                for _,other in ipairs(hayChildrenSnapshot or folder:GetChildren()) do
                                    if other.Parent==folder and other~=hay and other:IsA("BasePart")
                                        and other:GetAttribute("HayId")
                                        and (other.Position-hay.Position).Magnitude<=radius+1 then
                                        nearby[#nearby+1]=other:GetAttribute("HayId")
                                        if #nearby>=6 then break end
                                    end
                                end
                            end
                        end
                        if findHiddenKey then
                            nextKeyHayRequestAt=now+0.65
                            recentKeyHayAttempts[id]=now+1.8
                        end
                        if sendFarmRemote("PickHay",id,nearby) and findHiddenKey then
                            totalKeyHayRequests+=1
                        end
                    end
                end
                if findHiddenKey and now-lastKeySearchNotice>=15 then
                    lastKeySearchNotice=now
                    print("[BeyyHub Key] Hidden-key search active | hay requests=" ..
                        tostring(totalKeyHayRequests) .. " | exposed-key pickup remains on fast scan")
                end
                if ordinaryFarm and sharedFarmState.AutoCollectDroppedHay and not bagFull() then
                    local _,d=closestInFolder("DroppedHay","Dropped",28)
                    if d then sendFarmRemote("PickDroppedHay",d) end
                end
                if ordinaryFarm and sharedFarmState.AutoCollectGems then
                    local _,id=closestInFolder("GemsClient","GemId",35)
                    if id then sendFarmRemote("CollectGem",id) end
                end
            end
        end
    end)
    task.spawn(function()
        while not hubUnloaded do
            task.wait(1)
            if needleFolder and not farmBlocked() and not needlePriority() and sharedFarmState.AutoSellHay then
                local held=tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0
                local threshold=tonumber(sharedFarmState.SellThreshold) or 25
                if held>0 and ((sharedFarmState.SellOnlyIfFull and bagFull())
                    or (not sharedFarmState.SellOnlyIfFull and held>=threshold)) then
                    sendFarmRemote("SellHay")
                end
            end
        end
    end)
    task.spawn(function()
        local lastToolsNote = -math.huge
        local function toolNote(message)
            if os.clock() - lastToolsNote >= 8 then
                lastToolsNote = os.clock()
                print("[BeyyHub Tools] " .. message)
            end
        end
        local lastEnabled = nil
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.ToolInterval) or 0.5))
            local enabled = sharedFarmState.AutoUsePitchfork or sharedFarmState.AutoDeployDrone
                or sharedFarmState.AutoUseTNT
            if enabled ~= lastEnabled then
                lastEnabled = enabled
                print("[BeyyHub Tools] Remote tools " .. (enabled and "ENABLED" or "OFF") ..
                    " | TNT=" .. tostring(sharedFarmState.AutoUseTNT) ..
                    " Pitchfork=" .. tostring(sharedFarmState.AutoUsePitchfork) ..
                    " Drone=" .. tostring(sharedFarmState.AutoDeployDrone))
            end
            if enabled then
                needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
                local reason = toolBlockReason()
                if not needleFolder then
                    toolNote("Waiting for NeedleHaystack remotes")
                elseif reason then
                    toolNote("Paused: " .. reason)
                else
                    local attempted = false
                    if sharedFarmState.AutoUsePitchfork and LocalPlayer:GetAttribute("PitchforkOwned")==true then
                        local _,id=closestInFolder("HaystackClient","HayId",30)
                        if id then
                            attempted = sendFarmRemote("PitchforkDig",id) or attempted
                        end
                    end
                    if sharedFarmState.AutoDeployDrone and LocalPlayer:GetAttribute("DroneOwned")==true
                        and LocalPlayer:GetAttribute("DroneDeployed")~=true then
                        attempted = sendFarmRemote("DeployDrone") or attempted
                    end
                    if attempted then
                        toolNote("Tool remote request sent (server activation not yet confirmed)")
                    else
                        toolNote("No tool request: check tool ownership, nearby hay, and enabled toggles")
                    end
                end
            end
        end
    end)
    -- Chapter 2 TNT controller: wait for the *server's* "lit" reply before
    -- throwing. Previously a successful FireServer("light") was treated as
    -- confirmation and the post-light toolBlockReason() recheck could silently
    -- discard a lit TNT (often on the third/late use near puzzle release).
    -- The server's "denied" reply also supplies its actual retry cooldown.
    task.spawn(function()
        local remote,connection=nil,nil
        local phase="idle"
        local nextLightAt,pendingUntil,throwAt,fuseExpires=0,0,0,0
        local litSequence,throwSequence,deniedSequence=0,0,0
        local lastRemoteWarning=-math.huge
        local function validNumber(value)
            local number=tonumber(value)
            return number and number==number and number<math.huge
                and number>-math.huge and number or nil
        end
        local function cooldown()
            local gameCooldown=validNumber(LocalPlayer:GetAttribute("TntCooldown"))
            if not gameCooldown or gameCooldown<=0 then gameCooldown=20 end
            return math.max(0.5,gameCooldown,
                validNumber(sharedFarmState.TntLightCooldown) or 0)
        end
        local function clearPending(reason)
            if phase~="idle" then
                print("[BeyyHub TNT] "..reason..
                    " | phase="..phase.." lit="..litSequence..
                    " thrown="..throwSequence.." denied="..deniedSequence)
            end
            phase="idle"
            pendingUntil,throwAt,fuseExpires=0,0,0
        end
        local function bindRemote()
            local current=farmRemote("TntAction")
            if current==remote and connection and connection.Connected then
                return true
            end
            if connection then connection:Disconnect();connection=nil end
            if remote and remote~=current then clearPending("Remote replaced") end
            remote=current
            if not remote then return false end
            connection=remote.OnClientEvent:Connect(function(action,value)
                local now=os.clock()
                if action=="lit" and phase=="waiting" then
                    phase="lit"
                    litSequence+=1
                    local fuse=validNumber(value)
                    if not fuse or fuse<=0 then fuse=2.9 end
                    fuseExpires=now+fuse
                    local configured=math.max(0,validNumber(sharedFarmState.TntThrowDelay) or 0.4)
                    local delay=math.min(configured,math.max(0,fuse-0.12))
                    throwAt=now+delay
                    nextLightAt=now+cooldown()+0.05
                    print(string.format(
                        "[BeyyHub TNT] Server lit #%d; throw in %.2fs (fuse %.2fs)",
                        litSequence,delay,fuse))
                elseif action=="denied" and phase=="waiting" then
                    deniedSequence+=1
                    local remaining=validNumber(value)
                    if not remaining or remaining<0 then remaining=1 end
                    nextLightAt=now+math.max(0.25,remaining+0.05)
                    clearPending("Server denied light; retry in "..string.format("%.2f",nextLightAt-now).."s")
                end
            end)
            return true
        end
        while not hubUnloaded do
            task.wait(0.05)
            local now=os.clock()
            if not bindRemote() then
                if sharedFarmState.AutoUseTNT and now-lastRemoteWarning>8 then
                    lastRemoteWarning=now
                    warn("[BeyyHub TNT] Waiting for TntAction RemoteEvent")
                end
            elseif phase=="waiting" then
                if now>=pendingUntil then
                    clearPending("No server lighting reply within 2s; respecting cooldown")
                end
            elseif phase=="lit" then
                if now>=fuseExpires then
                    clearPending("Confirmed TNT fuse expired before throw")
                elseif hubUnloaded or not sharedFarmState.AutoUseTNT
                    or finalEndingProtected
                    or LocalPlayer:GetAttribute("NeedleOwned")==true then
                    clearPending("Throw cancelled by unload/toggle/final key state")
                elseif now>=throwAt then
                    -- A cutscene flag can change during the fuse. Once lighting
                    -- was confirmed, transient puzzle/camera/input gating must
                    -- not drop the throw; final/owned-key protection still wins.
                    local camera=Workspace.CurrentCamera
                    if camera then
                        local sent=sendFarmRemote("TntAction","throw",
                            camera.CFrame,
                            camera.CFrame.LookVector*40+Vector3.new(0,8,0))
                        if sent then
                            throwSequence+=1
                            print("[BeyyHub TNT] Throw sent #"..
                                throwSequence.." (server-confirmed lighting #"..
                                litSequence..")")
                            phase="idle"
                        else
                            throwAt=now+0.1 -- transient remote failure, retry while fuse lasts
                            if now-lastRemoteWarning>2 then
                                lastRemoteWarning=now
                                warn("[BeyyHub TNT] Throw FireServer failed; retrying before fuse expires")
                            end
                        end
                    end
                end
            elseif now>=nextLightAt and sharedFarmState.AutoUseTNT
                and LocalPlayer:GetAttribute("TntOwned")==true
                and not toolBlockReason() then
                phase="waiting"
                pendingUntil=now+2
                nextLightAt=now+cooldown()+0.05
                if not sendFarmRemote("TntAction","light") then
                    clearPending("TNT light FireServer failed")
                    nextLightAt=now+0.5
                end
            end
        end
        if connection then connection:Disconnect() end
        clearPending("TNT worker unloaded")
    end)
    local vacuumHeld=false
    local vacuumPoint=Vector2.zero
    local vacuumStart=0
    local vacuumCooldown=0
    local vacuumCooling=false
    local function releaseSharedVacuum()
        if vacuumHeld then
            vacuumHeld=false
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(vacuumPoint.X,vacuumPoint.Y,0,false,game,0)
            end)
        end
    end
    local oldCleanup=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        releaseSharedVacuum()
        if oldCleanup then pcall(oldCleanup) end
    end
    task.spawn(function()
        local hotbar={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three,
            Enum.KeyCode.Four,Enum.KeyCode.Five,Enum.KeyCode.Six,
            Enum.KeyCode.Seven,Enum.KeyCode.Eight,Enum.KeyCode.Nine}
        local lastVacuumEnabled = nil
        while not hubUnloaded do
            task.wait(0.08)
            needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            if sharedFarmState.AutoUseVacuum ~= lastVacuumEnabled then
                lastVacuumEnabled = sharedFarmState.AutoUseVacuum
                print("[BeyyHub Tools] Vacuum " .. (lastVacuumEnabled and "ENABLED" or "OFF"))
            end
            local active=needleFolder and BEYY_CHAPTER~="Lobby" and sharedFarmState.AutoUseVacuum
                and not toolBlockReason() and hubWindow.Closed==true
            if not active then
                releaseSharedVacuum()
            elseif os.clock()>=vacuumCooldown then
                local cam=Workspace.CurrentCamera
                local point=cam and cam.ViewportSize/2
                if point then
                    local gui=LocalPlayer:FindFirstChildOfClass("PlayerGui")
                    local hud=gui and gui:FindFirstChild("HUD")
                    local heat=hud and hud:FindFirstChild("Overheat")
                    local fill=heat and heat:FindFirstChild("Fill")
                    local level=fill and fill:IsA("GuiObject") and fill.Size.Y.Scale or nil
                    if level and level>=0.999 then
                        releaseSharedVacuum()
                        vacuumCooling=true
                    elseif vacuumCooling and (not level or level>0.001) then
                        releaseSharedVacuum()
                    elseif not vacuumHeld then
                        vacuumCooling=false
                        local slot=math.clamp(math.floor(tonumber(sharedFarmState.VacuumHotbarSlot) or 5),1,9)
                        local key=hotbar[slot]
                        pcall(function() VirtualInputManager:SendKeyEvent(true,key,false,game) end)
                        task.wait(0.05)
                        pcall(function() VirtualInputManager:SendKeyEvent(false,key,false,game) end)
                        task.wait(0.15)
                        if not toolBlockReason() and hubWindow.Closed and not needlePriority() then
                            vacuumPoint=point
                            local pressed=pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(point.X,point.Y,0,true,game,0)
                            end)
                            if pressed then vacuumHeld=true; vacuumStart=os.clock() end
                        end
                    elseif not level and os.clock()-vacuumStart>=30 then
                        releaseSharedVacuum()
                        vacuumCooldown=os.clock()+13.5
                    elseif level and level>=0.98 then
                        releaseSharedVacuum()
                        vacuumCooling=true
                    end
                end
            end
        end
        releaseSharedVacuum()
    end)
    local handInBusy = false
    local lastHandInWarning = -math.huge
    local function handInWarning(message)
        if os.clock() - lastHandInWarning >= 5 then
            lastHandInWarning = os.clock()
            warn("[BeyyHub] Needle turn-in: " .. tostring(message))
        end
    end
    -- Chapter 2 uses the native objective actions verified in fresh-round tests.
    -- Keep these locals in a separate scope to avoid the enclosing Luau local limit.
    local chapter2KeyActions = (function()
        local function waitUntil(predicate,seconds)
            local deadline=os.clock()+seconds
            repeat
                if predicate() then return true end
                if hubUnloaded then return false end
                task.wait(0.01)
            until os.clock()>=deadline
            return predicate()
        end
        local function handIn()
            if BEYY_CHAPTER~="Chapter2" or handInBusy or needleBusy or hubUnloaded
                or not handInRequested() or keyInteractionBlocked()
                or LocalPlayer:GetAttribute("NeedleOwned")~=true then return false end
            local puzzles=ReplicatedStorage:FindFirstChild("Puzzles")
            if not puzzles or puzzles:GetAttribute("EscapeReady")~=true then return false end
            local laser=Workspace:FindFirstChild("Laser")
            local root=farmRoot()
            local completedRemote=farmRemote("NeedleRoundCompleted")
            if not root or not laser or not laser:IsA("Model") or not completedRemote then return false end
            handInBusy=true
            local completed=false
            local connection=completedRemote.OnClientEvent:Connect(function(userId)
                if tonumber(userId)==LocalPlayer.UserId then completed=true end
            end)
            local started=os.clock()
            local attempts=0
            local ok,err=xpcall(function()
                releaseSharedVacuum()
                root.CFrame=CFrame.new(laser:GetPivot().Position-Vector3.new(0,2.5,0))*root.CFrame.Rotation
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
                task.wait(0.05)
                for attempt=1,3 do
                    if completed or hubUnloaded or not handInRequested() then break end
                    if keyInteractionBlocked() or farmRoot()~=root then break end
                    if LocalPlayer:GetAttribute("NeedleOwned")~=true then
                        waitUntil(function() return completed end,0.70)
                        break
                    end
                    -- Disable the existing bypass before sending the request
                    -- that starts the final cinematic.
                    if autoCutsceneDisableAfterHandIn then
                        autoCutsceneDisableAfterHandIn("NeedleHandIn requested")
                    else finalEndingProtected=true end
                    attempts=attempt
                    assert(sendFarmRemote("NeedleHandIn"),"NeedleHandIn remote unavailable")
                    if waitUntil(function() return completed end,0.70) then break end
                    if not hubUnloaded then task.wait(0.15) end
                end
            end,function(e) return tostring(e) end)
            connection:Disconnect()
            handInBusy=false
            if completed then
                finalEndingProtected=true
                postPuzzleKeyPriority=false
                keyObjectiveLatched=false
                print(("[BeyyHub Key] Turn-in confirmed by NeedleRoundCompleted in %.3fs (%d requests)"):format(os.clock()-started,attempts))
            elseif not hubUnloaded then
                handInWarning(ok and "native round-completion event not confirmed; waiting to retry" or tostring(err))
            end
            return completed
        end
        local function pickup(needle,root)
            if needleBusy or handInBusy or hubUnloaded or keyInteractionBlocked()
                or not pickupRequested() then return false end
            needleBusy=true
            local started=os.clock()
            local attempts=0
            local id=keyHayId(needle)
            local ok,err=xpcall(function()
                releaseSharedVacuum()
                root.CFrame=CFrame.new(needle.Position+Vector3.new(0,2.5,3))*root.CFrame.Rotation
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
                task.wait(0.05)
                for attempt=1,3 do
                    if LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                    if hubUnloaded or keyInteractionBlocked() or not pickupRequested() or farmRoot()~=root then break end
                    if not needle.Parent then break end
                    attempts=attempt
                    assert(sendFarmRemote("PickHay","Objective"),"PickHay remote unavailable")
                    if waitUntil(function() return LocalPlayer:GetAttribute("NeedleOwned")==true end,0.55) then break end
                end
            end,function(e) return tostring(e) end)
            needleBusy=false
            local collected=LocalPlayer:GetAttribute("NeedleOwned")==true
            if collected then
                setPickupStatus("Key collected; automatic turn-in ready")
                print(("[BeyyHub Key] Native objective pickup confirmed HayId=%s in %.3fs (%d requests)"):format(tostring(id),os.clock()-started,attempts))
                -- Chain directly into hand-in without another polling delay.
                if handInRequested() then handIn() end
            elseif not hubUnloaded then
                setPickupStatus(ok and "Pickup not confirmed; waiting to retry" or "Pickup error: "..tostring(err))
            end
            return collected
        end
        return {pickup=pickup,handIn=handIn}
    end)()

    task.spawn(function()
        while not hubUnloaded do
            task.wait(BEYY_CHAPTER=="Chapter2" and 0.01 or (handInRequested() and 0.12 or 0.5))
            if needleFolder and not keyInteractionBlocked() and handInRequested()
                and not needleBusy and not handInBusy
                and LocalPlayer:GetAttribute("NeedleOwned")==true then
                handInBusy = true
                local ok, err = pcall(function()
                    local root = farmRoot()
                    if not root then return end
                    if BEYY_CHAPTER == "Chapter2" then
                        -- The native controller owns its busy flag and verifies
                        -- NeedleRoundCompleted instead of ownership loss alone.
                        handInBusy=false
                        chapter2KeyActions.handIn()
                    else
                        local npc = Workspace:FindFirstChild("NPC")
                        local farmer = npc and npc:FindFirstChild("Farmer_NPC")
                        if farmer then
                            local location = farmer:GetPivot()
                            if (root.Position - location.Position).Magnitude > 15 then
                                root.CFrame = location * CFrame.new(0, 0, 4)
                            end
                            sendFarmRemote("NeedleHandIn")
                        end
                    end
                end)
                if not ok then handInWarning(err) end
                handInBusy = false
            end
        end
    end)
    local KEY_SCAN_ACTIVE = BEYY_CHAPTER=="Chapter2" and 0.01 or 0.05
    local KEY_SCAN_IDLE = BEYY_CHAPTER=="Chapter2" and 0.05 or 0.30
    local KEY_MOUSE_HOLD = 0.085
    local KEY_OWNERSHIP_WAIT = 0.10
    local lastKeyPickupFailureLogAt = -math.huge
    local lastKeyRemoteFallbackAt = -math.huge
    local function pickupBlockReason()
        if hubUnloaded then return "Hub unloaded" end
        if not pickupRequested() then return "Auto pickup / find is off" end
        if LocalPlayer:GetAttribute("NeedleOwned")==true then return "Key / needle collected" end
        if not needleFolder then return "Waiting for NeedleHaystack to replicate" end
        if keyPuzzleCameraBusy() then return "Waiting for an active lever/colour controller to release the camera" end
        if LocalPlayer:GetAttribute("CutsceneActive")==true and not keyObjectivePhase() then
            return "Waiting for CutsceneActive to clear"
        end
        if LocalPlayer:GetAttribute("Chapter2ReleaseActive")==true and not keyObjectivePhase() then
            return "Waiting for puzzle-release objective to appear"
        end
        if LocalPlayer:GetAttribute("NeedleInputLocked")==true and not keyObjectivePhase() then
            return "Waiting for NeedleInputLocked to clear"
        end
        if LocalPlayer:GetAttribute("HintViewerOpen")==true then return "Close the hint viewer to pick up the key" end
        if needleBusy then return "Pickup in progress" end
        return nil
    end
    task.spawn(function()
        while not hubUnloaded do
            task.wait((pickupRequested() or postPuzzleKeyPriority or puzzleReleaseObserved)
                and KEY_SCAN_ACTIVE or KEY_SCAN_IDLE)
            needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            local blocked = pickupBlockReason()
            if blocked then
                setPickupStatus(blocked)
            else
                local needle=exposedNeedle()
                local root=farmRoot()
                local camera=Workspace.CurrentCamera
                if not needle then
                    setPickupStatus("Waiting for an exposed objective with a numeric HayId")
                elseif not root or not camera then
                    setPickupStatus("Waiting for the character and camera")
                elseif BEYY_CHAPTER=="Chapter2" then
                    chapter2KeyActions.pickup(needle,root)
                else
                    needleBusy=true
                    local pickupStart=os.clock()
                    local clicksSent=0
                    releaseSharedVacuum()
                    local previousRoot=root.CFrame
                    local previousCameraType=camera.CameraType
                    local previousCameraCF=camera.CFrame
                    local previousHover=LocalPlayer:GetAttribute("HoveredHayId")
                    local renderName="BeyySharedNeedleAim_"..tostring(LocalPlayer.UserId)
                    local bound=false
                    local mouseDown=false
                    local moved=false
                    local cameraCaptured=false
                    local filteredParts = {}
                    local function restoreQueryFilter()
                        for part, old in pairs(filteredParts) do
                            if part.Parent then
                                pcall(function()
                                    part.CanQuery = old.query
                                    part.CanCollide = old.collide
                                end)
                            end
                            filteredParts[part] = nil
                        end
                    end
                    local function filterKeyBlockers()
                        local count = 0
                        for _, folderName in ipairs({"HaystackClient", "HaystackCollision"}) do
                            local folder = Workspace:FindFirstChild(folderName)
                            if folder then
                                for _, part in ipairs(folder:GetDescendants()) do
                                    if count >= 32 then break end
                                    if part:IsA("BasePart") and part ~= needle and part.CanQuery
                                        and part:GetAttribute("IsNeedleObjective") ~= true
                                        and (part.Position - needle.Position).Magnitude <=
                                            7 + math.min(part.Size.Magnitude * 0.5, 4) then
                                        local old = { query = part.CanQuery, collide = part.CanCollide }
                                        local ok = pcall(function()
                                            if part.CanCollide then part.CanCollide = false end
                                            part.CanQuery = false
                                        end)
                                        if ok and not part.CanQuery then
                                            filteredParts[part] = old
                                            count += 1
                                        else
                                            pcall(function()
                                                part.CanQuery = old.query
                                                part.CanCollide = old.collide
                                            end)
                                        end
                                    end
                                end
                            end
                        end
                        return count
                    end
                    local function clear()
                        restoreQueryFilter()
                        if mouseDown then
                            mouseDown=false
                            local center=camera.ViewportSize/2
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            end)
                        end
                        if bound then pcall(function() RunService:UnbindFromRenderStep(renderName) end) end
                        if cameraCaptured and camera then
                            pcall(function()
                                camera.CameraType=previousCameraType
                                camera.CFrame=previousCameraCF
                            end)
                        end
                        if moved and root and root.Parent then pcall(function() root.CFrame=previousRoot end) end
                        pcall(function() LocalPlayer:SetAttribute("HoveredHayId",previousHover) end)
                        needleBusy=false
                    end
                    local ok,err=xpcall(function()
                        if hubWindow.Closed~=true then
                            setPickupStatus("Closing the menu for key pickup")
                            hubWindow:Close()
                        end
                        local menuDeadline=os.clock()+1
                        repeat
                            RunService.RenderStepped:Wait()
                        until hubWindow.Closed==true or hubUnloaded or os.clock()>=menuDeadline
                        if hubWindow.Closed~=true then error("Menu did not close; pickup will retry") end
                        RunService.RenderStepped:Wait()
                        if hubUnloaded or keyInteractionBlocked() or not pickupRequested()
                            or not needle.Parent or not root.Parent then return end
                        if Workspace.CurrentCamera~=camera then error("Camera changed; pickup will retry") end
                        previousCameraType=camera.CameraType
                        previousCameraCF=camera.CFrame
                        cameraCaptured=true
                        setPickupStatus("Teleporting beside the key / needle")
                        local id=keyHayId(needle)
                        if id == nil then error("Key HayId not yet replicated; retrying") end
                        local forward=camera.CFrame.LookVector
                        local flat=Vector3.new(forward.X,0,forward.Z)
                        if flat.Magnitude < 0.05 then
                            forward=root.CFrame.LookVector
                            flat=Vector3.new(forward.X,0,forward.Z)
                        end
                        if flat.Magnitude < 0.05 then flat=Vector3.new(0,0,-1) end
                        flat=flat.Unit
                        local spot=needle.Position-flat*1.75+Vector3.new(0,2.3,0)
                        root.CFrame=CFrame.lookAt(spot,Vector3.new(needle.Position.X,spot.Y,needle.Position.Z))
                        moved=true
                        root.AssemblyLinearVelocity=Vector3.zero
                        root.AssemblyAngularVelocity=Vector3.zero
                        camera.CameraType=Enum.CameraType.Scriptable
                        local cameraSpot=needle.Position-flat*4+Vector3.new(0,3.3,0)
                        camera.CFrame=CFrame.lookAt(cameraSpot,needle.Position)
                        RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+1000,function()
                            if needle.Parent then
                                camera.CameraType=Enum.CameraType.Scriptable
                                camera.CFrame=CFrame.lookAt(cameraSpot,needle.Position)
                                LocalPlayer:SetAttribute("HoveredHayId",id)
                            end
                        end)
                        bound=true
                        RunService.RenderStepped:Wait()
                        local filtered=filterKeyBlockers()
                        RunService.RenderStepped:Wait()
                        local projected,onScreen=camera:WorldToViewportPoint(needle.Position)
                        local middle=camera.ViewportSize/2
                        if not onScreen or (Vector2.new(projected.X,projected.Y)-middle).Magnitude > 18 then
                            error("Key aim did not reach the centre of the viewport")
                        end
                        if filtered > 0 then
                            setPickupStatus("Cleared " .. filtered .. " temporary hay blockers before key pickup")
                        end
                        setPickupStatus("Clicking the objective; waiting for ownership confirmation")
                        for _=1,8 do
                            if hubUnloaded or keyInteractionBlocked() or not pickupRequested()
                                or not needle.Parent or LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                            local center=camera.ViewportSize/2
                            LocalPlayer:SetAttribute("HoveredHayId",id)
                            VirtualInputManager:SendMouseMoveEvent(center.X,center.Y,game)
                            RunService.RenderStepped:Wait()
                            if hubUnloaded or keyInteractionBlocked() or LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,true,game,0)
                            mouseDown=true
                            task.wait(KEY_MOUSE_HOLD)
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            mouseDown=false
                            clicksSent+=1
                            local confirmUntil=os.clock()+KEY_OWNERSHIP_WAIT
                            while os.clock()<confirmUntil and not hubUnloaded and not keyInteractionBlocked()
                                and pickupRequested() and needle.Parent
                                and LocalPlayer:GetAttribute("NeedleOwned")~=true do
                                task.wait(0.025)
                            end
                            if LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                            if clicksSent == 2 and not hubUnloaded and needle.Parent
                                and not keyInteractionBlocked()
                                and os.clock()-lastKeyRemoteFallbackAt>=1.5 then
                                -- Do not waste six further clicks before trying
                                -- the existing server-side pickup fallback.
                                lastKeyRemoteFallbackAt = os.clock()
                                if sendFarmRemote("PickHay", id, {}) then
                                    local fastConfirmUntil = os.clock()+0.12
                                    while os.clock()<fastConfirmUntil and not hubUnloaded
                                        and LocalPlayer:GetAttribute("NeedleOwned")~=true do
                                        task.wait(0.025)
                                    end
                                    if LocalPlayer:GetAttribute("NeedleOwned")==true then
                                        print("[BeyyHub Key] Early PickHay confirmed HayId="..tostring(id))
                                        break
                                    end
                                end
                            end
                        end
                        if not hubUnloaded and needle.Parent
                            and LocalPlayer:GetAttribute("NeedleOwned")~=true
                            and not keyInteractionBlocked()
                            and os.clock()-lastKeyRemoteFallbackAt>=1.5 then
                            -- If VIM does not register on an exposed key, try
                            -- the game's existing PickHay action once before
                            -- resetting the camera and retrying.
                            lastKeyRemoteFallbackAt=os.clock()
                            if sendFarmRemote("PickHay", id, {}) then
                                print("[BeyyHub Key] VIM pickup unconfirmed; trying PickHay for exposed HayId="..tostring(id))
                                task.wait(0.18)
                            end
                        end
                    end,function(e) return tostring(e) end)
                    clear()
                    local duration=os.clock()-pickupStart
                    if not ok then
                        setPickupStatus("Pickup error: "..tostring(err))
                        warn(("[BeyyHub Key] Pickup error after %.2fs (%d clicks): %s"):format(
                            duration,clicksSent,tostring(err)))
                    elseif LocalPlayer:GetAttribute("NeedleOwned")==true then
                        setPickupStatus("Key / needle collected")
                        print(("[BeyyHub Key] Picked up HayId=%s in %.2fs (%d clicks)"):format(
                            tostring(needle:GetAttribute("HayId")),duration,clicksSent))
                    else
                        setPickupStatus("Pickup not confirmed; retrying on the next scan")
                        if clicksSent>0 and os.clock()-lastKeyPickupFailureLogAt>=4 then
                            lastKeyPickupFailureLogAt=os.clock()
                            warn(("[BeyyHub Key] Not confirmed after %.2fs (%d clicks); will retry"):format(
                                duration,clicksSent))
                        end
                    end
                end
            end
        end
    end)
    local function owned(attr) return LocalPlayer:GetAttribute(attr)==true end
    local function cash()
        local ls=LocalPlayer:FindFirstChild("leaderstats")
        local value=ls and ls:FindFirstChild("Cash")
        return value and tonumber(value.Value) or 0
    end
    local function createWorkerWake(player)
        local api={}
        local alive=true
        local waiters,connections={},{}
        local cashFolder,cashValue,cashConnections=nil,nil,{}
        local function finish(token,cancelTimer)
            if token.Done then return end
            token.Done=true;waiters[token]=nil
            if cancelTimer and token.Timer then pcall(task.cancel,token.Timer)end
            task.defer(token.Thread)
        end
        function api.Wake(key)
            for token in pairs(waiters)do
                if key==nil or token.Key==key or(key=="upgrades"and token.Key=="upgrades-cash")then finish(token,true)end
            end
        end
        local function syncCash()
            local folder=player:FindFirstChild("leaderstats")
            local value=folder and folder:FindFirstChild("Cash")
            if folder==cashFolder and value==cashValue then return end
            for _,connection in ipairs(cashConnections)do connection:Disconnect()end
            table.clear(cashConnections);cashFolder,cashValue=folder,value
            if folder then
                cashConnections[#cashConnections+1]=folder.ChildAdded:Connect(function()syncCash();api.Wake("upgrades-cash")end)
                cashConnections[#cashConnections+1]=folder.ChildRemoved:Connect(function()syncCash();api.Wake("upgrades-cash")end)
            end
            if value then cashConnections[#cashConnections+1]=value:GetPropertyChangedSignal("Value"):Connect(function()api.Wake("upgrades-cash")end)end
        end
        connections[1]=player.AttributeChanged:Connect(function(name)
            if name:sub(1,10)=="HayUpgrade"or name=="UpgradeCostMultiplier"or name=="PitchforkUpgradeCostMultiplier"then api.Wake("upgrades")end
        end)
        connections[2]=player.ChildAdded:Connect(function(child)if child.Name=="leaderstats"then syncCash();api.Wake("upgrades")end end)
        connections[3]=player.ChildRemoved:Connect(function(child)if child==cashFolder then syncCash();api.Wake("upgrades")end end)
        function api.Wait(interval,idle,key)
            if not alive then return end
            if not idle then task.wait(interval);return end
            if key=="upgrades"or key=="upgrades-cash"then syncCash()end
            local token={Thread=coroutine.running(),Key=key}
            waiters[token]=true
            token.Timer=task.delay(1,function()finish(token,false)end)
            coroutine.yield()
        end
        function api.Stop()
            if not alive then return end
            alive=false
            for _,connection in ipairs(connections)do connection:Disconnect()end
            for _,connection in ipairs(cashConnections)do connection:Disconnect()end
            for token in pairs(waiters)do finish(token,true)end
            table.clear(connections);table.clear(cashConnections)
            cashFolder,cashValue=nil,nil
        end
        local previous=_G.__BEYY_HUB_CLEANUP
        _G.__BEYY_HUB_CLEANUP=function()api.Stop();if previous then previous()end end
        return api
    end
    
    
    local function createAutoUpgradeRuntime(options)
        local config, configModule, pending
        local idle,waitKey=true,"upgrades"
        local tracks = {
            {"UpgVacPower","VacuumPower"},{"UpgVacCooling","VacuumCooling"},
            {"UpgVacRuntime","VacuumRuntime"},
            {"UpgTntPower","TntPower"},{"UpgTntLuck","TntLuck"},
            {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},{"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
            {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},{"UpgPitchSweep","Pitchfork"},
            {"UpgDroneSpeed","DroneSpeed"},{"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
            {"UpgTntCooldown","TntCooldown"},
        }
        local lastStatus
        local function status(text)
            if text~=lastStatus then lastStatus=text;options.Status(text) end
        end
        local function level(name) return tonumber(options.Player:GetAttribute("HayUpgrade"..name)) or 1 end
        local function cost(name, entry)
            local price=tonumber(entry.Cost)
            if not price or price<0 or price~=price or price==math.huge then return nil end
            price*=tonumber(options.Player:GetAttribute("UpgradeCostMultiplier")) or 1
            if name:sub(1,9)=="Pitchfork" then price*=tonumber(options.Player:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1 end
            return math.round(price*100)/100
        end
        local function tick()
            idle,waitKey=true,"upgrades"
            local folder=options.Folder()
            local module=folder and folder:FindFirstChild("Config")
            local remote=folder and folder:FindFirstChild("BuyUpgrade")
            if not module or not remote or not remote:IsA("RemoteEvent") then status("Waiting for upgrade config / remote"); return end
            if configModule~=module or not config then
                local loaded=require(module)
                assert(type(loaded)=="table" and type(loaded.UPGRADE_TRACKS)=="table","Invalid upgrade config")
                config,configModule=loaded,module
                if options.OnConfig then options.OnConfig(loaded) end
            end
            if pending then
                idle=false
                local confirmedLevel=level(pending.Name)
                if confirmedLevel~=pending.Level or not options.State[pending.Flag] then
                    if confirmedLevel>pending.Level and options.OnConfirmed then options.OnConfirmed(pending,confirmedLevel) end
                    pending=nil
                elseif os.clock()<pending.Until then status("Waiting for "..pending.Name.." purchase confirmation"); return
                else
                    status("Server did not confirm "..pending.Name.."; retrying")
                    pending=nil
                end
            end
            local cash=tonumber(options.Cash()) or 0
            local selected, available, vacuum, power, earlyTnt, lateTnt=0,{},nil,nil,nil,nil
            for _,entry in ipairs(tracks) do
                if options.State[entry[1]] then
                    selected+=1
                    local track=config.UPGRADE_TRACKS[entry[2]]
                    local current=level(entry[2])
                    local nextLevel=track and track.Levels and track.Levels[current+1]
                    local price=nextLevel and cost(entry[2],nextLevel)
                    if price then
                        local target={Flag=entry[1],Name=entry[2],Level=current,Cost=price}
                        if entry[2]=="TntCooldown" then
                            -- Tracks start at L1: two purchases reach L3.
                            if current<3 then earlyTnt=target else lateTnt=target end
                        else
                            available[#available+1]=target
                        end
                        if entry[2]=="VacuumPower" then power=target end
                        if (entry[2]=="VacuumPower" or entry[2]=="VacuumCooling") and (not vacuum or price<vacuum.Cost) then vacuum=target end
                    end
                end
            end
            if selected==0 then status("No cash upgrades enabled"); return end
            if #available==0 and not earlyTnt and not lateTnt then status("Selected cash upgrades are maxed or unavailable"); return end
            local target
            if earlyTnt then
                if cash<earlyTnt.Cost then waitKey="upgrades-cash";status(string.format("Saving for TntCooldown: $%.2f / $%.2f",cash,earlyTnt.Cost)); return end
                target=earlyTnt
            elseif power then
                if cash<power.Cost then waitKey="upgrades-cash";status(string.format("Saving for VacuumPower: $%.2f / $%.2f",cash,power.Cost)); return end
                target=power
            elseif vacuum and cash>=vacuum.Cost*0.75 then
                if cash<vacuum.Cost then waitKey="upgrades-cash";status(string.format("Saving for %s: $%.2f / $%.2f",vacuum.Name,cash,vacuum.Cost)); return end
                target=vacuum
            else
                for _,entry in ipairs(available) do if cash>=entry.Cost then target=entry;break end end
                -- Remaining TNT speed levels wait until all other enabled tracks finish.
                if #available==0 and lateTnt and cash>=lateTnt.Cost then target=lateTnt end
            end
            if not target then
                waitKey="upgrades-cash"
                local cheapest=available[1] or lateTnt
                for _,entry in ipairs(available) do if entry.Cost<cheapest.Cost then cheapest=entry end end
                status(string.format("Waiting for cash: $%.2f / $%.2f (%s)",cash,cheapest.Cost,cheapest.Name)); return
            end
            idle=false
            -- Reserve before sending: replication may confirm the purchase immediately.
            pending={Name=target.Name,Flag=target.Flag,Level=target.Level,Started=os.clock(),Until=os.clock()+0.05}
            remote:FireServer(target.Name)
            if options.OnRequested then options.OnRequested(pending) end
            status(string.format("Requested %s L%d ($%.2f); awaiting confirmation",target.Name,target.Level+1,target.Cost))
        end
        return {IsIdle=function()return idle end,WaitKey=function()return waitKey end,Tick=function()
            local ok,err=pcall(tick)
            if not ok then config=nil; pending=nil; status("Upgrade error; retrying: "..tostring(err)) end
        end}
    end
    
    
    
    local upgradePurchaseAttempts={}
    local permanentPurchaseAttempts={}
    local lastUpgradeConfirmedAt
    local function logUpgradeConfirmation(category,name,pending,level)
        local now=os.clock()
        local spacing=lastUpgradeConfirmedAt and string.format(" interval=%.3fs",now-lastUpgradeConfirmedAt) or ""
        lastUpgradeConfirmedAt=now
        print(string.format("[BeyyHub Upgrade] %s %s L%d->L%d confirmed after %.3fs%s",
            category,name,pending.level,level,now-pending.at,spacing))
    end
    local function tryTrack(name)
        if __BEYY_CH2_NO_LEVERS_STARTED then return end
        if not sharedGameConfig then return end
        local track=sharedGameConfig.UPGRADE_TRACKS and sharedGameConfig.UPGRADE_TRACKS[name]
        if not track then return end
        local level=tonumber(LocalPlayer:GetAttribute("HayUpgrade"..name)) or 1
        local previous=upgradePurchaseAttempts[name]
        if previous and level~=previous.level then
            if level>previous.level then logUpgradeConfirmation("Cash",name,previous,level) end
            upgradePurchaseAttempts[name]=nil
        end
        if level>=#track.Levels then return end
        local nextLevel=track.Levels[level+1]
        if nextLevel then
            local price=(tonumber(nextLevel.Cost) or 0)*(tonumber(LocalPlayer:GetAttribute("UpgradeCostMultiplier")) or 1)
            if name:sub(1,9)=="Pitchfork" then price*=tonumber(LocalPlayer:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1 end
            if cash()<price then return end
            local now=os.clock()
            local pending=upgradePurchaseAttempts[name]
            if pending and pending.level==level and now-pending.at<0.05 then return end
            upgradePurchaseAttempts[name]={level=level,at=now}
            if not sendFarmRemote("BuyUpgrade",name) then upgradePurchaseAttempts[name]=nil end
        end
    end
    local function tryPermanent(name)
        if __BEYY_CH2_NO_LEVERS_STARTED then return end
        if not sharedUpgradeConfig then return end
        local ok,upgrade=pcall(function() return sharedUpgradeConfig.getUpgrade(name) end)
        if not ok or not upgrade then return end
        local level=tonumber(LocalPlayer:GetAttribute("Upgrade"..name)) or 0
        local previous=permanentPurchaseAttempts[name]
        if previous and level~=previous.level then
            if level>previous.level then logUpgradeConfirmation("Permanent",name,previous,level) end
            permanentPurchaseAttempts[name]=nil
        end
        local levelOK,maxLevel=pcall(function() return sharedUpgradeConfig:getMaxLevel(upgrade) end)
        if not levelOK or level>=maxLevel then return end
        local priceOK,price=pcall(function() return sharedUpgradeConfig:getPrice(upgrade,level) end)
        if priceOK and price and (tonumber(LocalPlayer:GetAttribute("Gems")) or 0)>=price then
            local now=os.clock()
            local pending=permanentPurchaseAttempts[name]
            if pending and pending.level==level and now-pending.at<0.25 then return end
            permanentPurchaseAttempts[name]={level=level,at=now}
            if not sendFarmRemote("BuyUpgrade",name) then permanentPurchaseAttempts[name]=nil end
        end
    end
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.5,tonumber(sharedFarmState.BuyInterval) or 1))
            if needleFolder and sharedFarmState.AutoBuyTools and BEYY_CHAPTER~="Lobby" then
                local selected=sharedFarmState.BuyToolsList or {}
                local choices={}
                for k,value in pairs(selected) do
                    if type(k)=="number" and type(value)=="string" then
                        choices[#choices+1]=value
                    elseif type(k)=="string" and value then
                        choices[#choices+1]=k
                    end
                end
                for _,name in ipairs(choices) do
                    if name=="Pitchfork" and not owned("PitchforkOwned") then
                        sendFarmRemote("BuyShopItem","Pitchfork")
                    elseif name=="TNT" and not owned("TntOwned") then
                        sendFarmRemote("BuyShopItem","Tnt")
                    elseif name=="Drone" and not owned("DroneOwned") then
                        sendFarmRemote("BuyShopItem","Drone")
                    elseif name=="Infinite Bag" and not owned("InfiniteBagOwned") then
                        sendFarmRemote("BuyShopItem","InfiniteBag")
                    elseif name=="Capacity Bag" then
                        tryTrack("Capacity")
                    end
                end
            end
        end
    end)
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.5,tonumber(sharedFarmState.PermInterval) or 0.5))
            if needleFolder and BEYY_CHAPTER~="Lobby" then
                local mapped={UpgBagSize="ExtraHoldAmount",UpgExtraTake="ExtraTakeAmount",
                    UpgGemValue="GemValue",UpgHayValue="ExtraHayValuePercentage"}
                for key,name in pairs(mapped) do
                    if sharedFarmState[key] then tryPermanent(name) end
                end
            end
        end
    end)
    do
        local upgrades=createAutoUpgradeRuntime({
            State=sharedFarmState,Player=LocalPlayer,Cash=cash,
            Folder=function()
                needleFolder=needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
                return needleFolder
            end,
            OnConfig=function(config)sharedGameConfig=config end,
            Status=function()end,
            OnConfirmed=function(pending,current)
                logUpgradeConfirmation("Cash",pending.Name,
                    {level=pending.Level,at=pending.Started},current)
            end
        })
        task.spawn(function()
            local wake=createWorkerWake(LocalPlayer)
            while not hubUnloaded do
                -- VacuumPower-only standalone v27 handles cash upgrades while
                -- integrated v33 is active; never send duplicate purchases.
                if not __BEYY_CH2_NO_LEVERS_STARTED then upgrades.Tick() end
                wake.Wait(0.05,upgrades.IsIdle(),upgrades.WaitKey())
            end
            wake.Stop()
        end)
    end


        -- Integrated Chapter 2 v33 owns all native puzzle actions and
        -- cutscene/teleport coordination. Main's legacy solver is removed.
        local leverRunning = false
        local colourRunning = false
        local function leverFolder()
            local puzzles = Workspace:FindFirstChild("Puzzles")
            local levers = puzzles and puzzles:FindFirstChild("LeverPuzzle")
            return levers and levers:FindFirstChild("Levers")
        end
        sharedFarmPuzzleBusy = __BEYY_CH2_NO_LEVERS_SOLVING
        keyPuzzleCameraBusy = __BEYY_CH2_NO_LEVERS_SOLVING
        local puzzleTab = hubWindow:Tab({ Title = "Puzzles", Icon = "puzzle" })
        puzzleTab:Section({ Title = "Chapter 2 Integrated v33" })
        puzzleTab:Paragraph({
            Title = "v32 Picture / Color / Number + instant hay return",
            Desc = "v6 invisible/deferred native intro Skip, v9 immediate return to spawn after 3/3, Vacuum Power-only v27. No lever requests; Main key pickup/hand-in remains.",
        })
        Registry.Chapter2AutoPuzzles = puzzleTab:Toggle({
            Title = "Auto Solve Puzzles",
            Value = __BEYY_CH2_NO_LEVERS_WANTED,
            Desc = "Run Picture, Color and Number puzzles with coordinated intro Skip, return and Vacuum Power upgrades. Turn off to stop all four workers.",
            Callback = function(enabled)
                if hubUnloaded then return end
                if enabled then
                    __BEYY_CH2_NO_LEVERS_START()
                else
                    __BEYY_CH2_NO_LEVERS_STOP(false)
                end
            end,
        })
        __BEYY_CH2_NO_LEVERS_ON_FAILURE = function()
            local toggle = Registry.Chapter2AutoPuzzles
            if not hubUnloaded and toggle and toggle.Value then toggle:Set(false) end
        end

    do
        local overview = overviewTab
local function cutsceneResultsVisible()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ending = pg and pg:FindFirstChild("NeedleEndingUI")
    if not (ending and ending:IsA("ScreenGui") and ending.Enabled) then return false end
    -- Some rounds keep NeedleEndingUI enabled before its actual ending
    -- controls become visible. Never suppress the puzzle bypass on that alone.
    local results = ending:FindFirstChild("ReturnToLobby", true)
    if not (results and results:IsA("GuiObject")) then return false end
    local node = results
    while node and node ~= ending do
        if node:IsA("GuiObject") and not node.Visible then return false end
        node = node.Parent
    end
    return node == ending
end
local function shouldYieldCutsceneBypass()
    if __BEYY_CH2_NO_LEVERS_STARTED then return true end
    if hubUnloaded or finalEndingProtected or not hubWindow.Closed
        or needleBusy or LocalPlayer:GetAttribute("NeedleOwned") == true
        or cutsceneResultsVisible() then return true end
    -- Levers are confirmed locally before the server's CutsceneActive flag
    -- necessarily replicates. A brief post-lever grace makes the bypass start
    -- immediately instead of being blocked by allPuzzlesRunning.
    local inUnskippable = LocalPlayer:GetAttribute("CutsceneActive") == true
        or LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true
        or os.clock() < leverBypassUntil or os.clock() < puzzleBypassUntil
    if inUnskippable then return leverRunning or colourRunning end
    return sharedFarmPuzzleBusy()
end
local function setCutsceneBypassActive(active)
    cutscenePlayable = active == true and not finalEndingProtected
end
local cutsceneBypassStop = nil
local function launchCutsceneBypass()
    if cutsceneBypassStop then return true end
    local ok, result = pcall(function()

        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local UserInputService = game:GetService("UserInputService")
        local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

        local env = _G
        if type(getgenv) == "function" then
            local ok, tbl = pcall(getgenv)
            if ok and type(tbl) == "table" then env = tbl end
        end
        local older = env.__BEYY_CUTSCENE_BYPASS_STOP or _G.__BEYY_CUTSCENE_BYPASS_STOP
        if type(older) == "function" then pcall(older) end

        local alive, enabled, active = true, true, false
        local scene = nil
        local recoveryEnd = 0
        local lastNormalDistance, lastNormalYaw, lastNormalPitch = 0.6, nil, nil
        local normalFirstPerson, cameraFirstPerson = true, true
        local yaw, pitch, distance = nil, -0.18, 0.6
        local lastSavedSpeed, lastSavedJump, lastSavedRotate = nil, nil, nil
        local controls, cachedCamera = nil, nil
        local originalMouseBehavior = nil
        local lastControlEnableAt = 0
        local connections = {}
        local hudEnabled = true
        local faceCameraEnabled = true
        local hudNormal, hudForced = {}, {}
        local headTransparencyBefore = {}
        local finalVisualsEnabled = true
        local finalVisualBefore = {}
        local cameraWatch = nil
        local inCameraWrite, cameraErrorWarned = false, false
        local renderId = "BeyyCutsceneCameraV103Last"
        local renderPriority = Enum.RenderPriority.Last.Value + 2000
        local RECOVERY_GRACE_SECONDS = 0.035
        local INTRO_SETTLE_SECONDS = 1.0
        local introConfirmedAt = player:GetAttribute("IntroCutsceneFinished") == true and (os.clock() - 2) or nil
        local introNeutralSeen = introConfirmedAt ~= nil and player:GetAttribute("CutsceneActive") ~= true
        local chapter2ReleaseSeen = player:GetAttribute("Chapter2ReleaseActive") == true
        local yieldingToEnding = false
        local lastEndingSkipScan, lastEndingSkipVisible = 0, false
        local skipCandidates = setmetatable({}, { __mode = "k" })
        local skipGui, skipGuiAddedConnection = nil, nil
        local lastSkipFallbackScan = 0
        local lastFinalVisualMaskAt = -math.huge
        local lastRenderTime = os.clock()

        local function log(s)
            if type(s) ~= "string" then return end
            if s:find("READY:", 1, true)
                or s:find("CUTSCENE DETECTED:", 1, true)
                or s:find("PLAYABLE CAMERA ENABLED:", 1, true)
                or s:find("ROBLOX CAMERA RETURNED:", 1, true)
                or s == "STOPPED" then
                print("[BeyyHub Cutscene] " .. s)
            end
        end
        local function hook(c)
            if c then connections[#connections+1] = c end
        end
        local function humanoid()
            local char = player.Character
            return char and char:FindFirstChildOfClass("Humanoid")
        end
        local function root()
            local char = player.Character
            return char and char:FindFirstChild("HumanoidRootPart")
        end
        local function camera()
            return workspace.CurrentCamera
        end
        local function getControls()
            if controls then return controls end
            local ps = player:FindFirstChild("PlayerScripts")
            local pm = ps and ps:FindFirstChild("PlayerModule")
            if not pm then return nil end
            local ok, mod = pcall(require, pm)
            if not ok or type(mod) ~= "table" then return nil end
            local ok2, obj = pcall(function() return mod:GetControls() end)
            if ok2 then controls = obj end
            return controls
        end
        local function rememberGameplay()
            local hum = humanoid()
            if hum then
                if hum.WalkSpeed > 0 then lastSavedSpeed = hum.WalkSpeed end
                if hum.JumpPower > 0 then lastSavedJump = hum.JumpPower end
                lastSavedRotate = hum.AutoRotate
            end
            local cam, rt = camera(), root()
            if cam and rt and cam.CameraType == Enum.CameraType.Custom then
                local look = cam.CFrame.LookVector
                if look.Magnitude > 0.5 then
                    local planar = Vector3.new(look.X, 0, look.Z)
                    if planar.Magnitude > 0.1 then
                        lastNormalYaw = math.atan2(planar.X, planar.Z)
                    end
                    lastNormalPitch = math.asin(math.max(-0.97, math.min(0.97, look.Y)))
                end
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                local eye = head and head.Position or (rt.Position + Vector3.new(0, 1.6, 0))
                local d = (cam.CFrame.Position - eye).Magnitude
                if d <= 22 then
                    lastNormalDistance = d
                    normalFirstPerson = (d < 2.5 or player.CameraMode == Enum.CameraMode.LockFirstPerson)
                end
            end
        end
        local function kind()
            if shouldYieldCutsceneBypass() then return nil end
            if player:GetAttribute("IntroCutsceneFinished") ~= true then return nil end
            if introConfirmedAt and os.clock() - introConfirmedAt < INTRO_SETTLE_SECONDS then return nil end
            if yieldingToEnding or finalEndingProtected then return nil end
            if player:GetAttribute("Chapter2ReleaseActive") == true
                or os.clock() < puzzleBypassUntil then return "THREE PUZZLES" end
            if player:GetAttribute("CutsceneActive") == true
                or os.clock() < leverBypassUntil then return "THREE LEVERS" end
            return nil
        end
        local function clamp(v, lo, hi)
            return math.max(lo, math.min(hi, v))
        end
        local function setupPlayableCamera()
            local rt = root()
            local facing = rt and rt.CFrame.LookVector or Vector3.new(0,0,-1)
            local planar = Vector3.new(facing.X, 0, facing.Z)
            if planar.Magnitude < 0.01 then planar = Vector3.new(0,0,-1) end
            yaw = lastNormalYaw or math.atan2(planar.X, planar.Z)
            pitch = clamp(lastNormalPitch or -0.16, -1.20, 1.05)
            cameraFirstPerson = normalFirstPerson or player.CameraMode == Enum.CameraMode.LockFirstPerson
            distance = clamp(lastNormalDistance or 0.6, 0.0, 22)
            log(string.format("Normal camera calibration: %s d=%.2f pitch=%.2f (no forced 6+ stud zoom)",
                cameraFirstPerson and "FIRST PERSON" or "THIRD PERSON", distance, pitch))
            cameraErrorWarned = false
            if originalMouseBehavior == nil then originalMouseBehavior = UserInputService.MouseBehavior end
        end
        local function lookVector()
            local cp = math.cos(pitch)
            return Vector3.new(math.sin(yaw)*cp, math.sin(pitch), math.cos(yaw)*cp)
        end
        local function hideHeadForFirstPerson()
            if not cameraFirstPerson then return end
            local char = player.Character
            if not char then return end
            local function hidePart(inst)
                if not inst or not inst:IsA("BasePart") then return end
                if headTransparencyBefore[inst] == nil then
                    headTransparencyBefore[inst] = inst.LocalTransparencyModifier
                end
                inst.LocalTransparencyModifier = 1
            end
            hidePart(char:FindFirstChild("Head"))
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Accessory") then
                    hidePart(item:FindFirstChild("Handle"))
                end
            end
        end
        local function restoreHeadTransparency()
            for part, before in pairs(headTransparencyBefore) do
                if part.Parent then
                    pcall(function() part.LocalTransparencyModifier = before end)
                end
                headTransparencyBefore[part] = nil
            end
        end
        local function forceCamera()
            if not alive or not enabled or not active or inCameraWrite or shouldYieldCutsceneBypass() then return end
            local cam, rt = camera(), root()
            if not cam or not rt or not yaw then return end
            inCameraWrite = true
            local safe, err = pcall(function()
                local vec = lookVector()
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
                local eye = head and head.Position or (rt.Position + Vector3.new(0, 1.6, 0))
                local result, focus
                if cameraFirstPerson then
                    result = CFrame.lookAt(eye, eye + vec * 8, Vector3.yAxis)
                    focus = eye + vec * 8
                    hideHeadForFirstPerson()
                else
                    local target = rt.Position + Vector3.new(0, 1.6, 0)
                    local desired = target - vec * distance
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = char and {char} or {}
                    params.RespectCanCollide = true
                    local hit = workspace:Raycast(target, desired - target, params)
                    if hit then
                        local hitDistance = (hit.Position - target).Magnitude
                        desired = target - vec * math.max(0.35, math.min(distance, hitDistance - 0.40))
                    end
                    result = CFrame.lookAt(desired, target, Vector3.yAxis)
                    focus = target
                end
                cam.CameraType = Enum.CameraType.Scriptable
                local hum = humanoid()
                if hum then cam.CameraSubject = hum end
                cam.CFrame = result
                cam.Focus = CFrame.new(focus)
            end)
            inCameraWrite = false
            if not safe and not cameraErrorWarned then
                cameraErrorWarned = true
                warn("[BeyyHub Cutscene] Camera write failed: " .. tostring(err))
            end
        end
        local function unwatchLeverCamera()
            if cameraWatch then pcall(function() cameraWatch:Disconnect() end) end
            cameraWatch, cachedCamera = nil, nil
        end
        local function watchLeverCamera()
            if not alive or not enabled or not active or scene ~= "THREE LEVERS" then
                unwatchLeverCamera()
                return
            end
            local cam = camera()
            if cam == cachedCamera and cameraWatch then return end
            unwatchLeverCamera()
            cachedCamera = cam
            if not cam then return end
            cameraWatch = cam:GetPropertyChangedSignal("CFrame"):Connect(function()
                if alive and enabled and active and scene == "THREE LEVERS" and not inCameraWrite then
                    forceCamera()
                end
            end)
        end
        hook(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if active and scene == "THREE LEVERS" then watchLeverCamera() end
        end))

        local SAFE_HUD_NAMES = { hud = true, needlehud = true, notifications = true }
        local function isGameplayHud(gui)
            if not gui:IsA("ScreenGui") then return false end
            local name = gui.Name:lower()
            if name:find("ending", 1, true) or name:find("cutscene", 1, true)
                or name:find("cinematic", 1, true) or name:find("intro", 1, true)
                or name:find("puzzle", 1, true) or name:find("skip", 1, true) then return false end
            return SAFE_HUD_NAMES[name] or name:find("hud", 1, true) ~= nil
                or name:find("hotbar", 1, true) ~= nil
                or name:find("inventory", 1, true) ~= nil
                or name:find("toolbar", 1, true) ~= nil
        end
        local function rememberGameplayHud()
            if active or scene then return end
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            for _, gui in ipairs(pg:GetChildren()) do
                if isGameplayHud(gui) and gui.Enabled then
                    local before = hudNormal[gui]
                    if not before or not before.enabled or before.order ~= gui.DisplayOrder then
                        hudNormal[gui] = { enabled = true, order = gui.DisplayOrder }
                    end
                end
            end
        end
        local lastHudDiscoveryAt = -math.huge
        local function showGameplayHud()
            if not hudEnabled then return end
            -- Newly recreated hotbar/HUD ScreenGuis may have been disabled by
            -- the server before the initial baseline could record them.
            local now = os.clock()
            if now - lastHudDiscoveryAt >= 0.35 then
                lastHudDiscoveryAt = now
                local pg = player:FindFirstChildOfClass("PlayerGui")
                if pg then
                    for _, gui in ipairs(pg:GetChildren()) do
                        if isGameplayHud(gui) and not hudNormal[gui] then
                            hudNormal[gui] = { enabled = true, order = gui.DisplayOrder }
                        end
                    end
                end
            end
            for gui, before in pairs(hudNormal) do
                if gui.Parent and before.enabled then
                    if not hudForced[gui] then hudForced[gui] = { enabled = gui.Enabled, order = gui.DisplayOrder } end
                    if not gui.Enabled then
                        pcall(function() gui.Enabled = true end)
                    end
                    local targetOrder = math.max(before.order or 0, 10000)
                    if gui.DisplayOrder ~= targetOrder then
                        pcall(function() gui.DisplayOrder = targetOrder end)
                    end
                end
            end
        end
        local function restoreGameplayHud()
            for gui, saved in pairs(hudForced) do
                if gui.Parent then
                    local wasNormal = hudNormal[gui]
                    pcall(function()
                        gui.DisplayOrder = saved.order
                        if wasNormal and wasNormal.enabled then gui.Enabled = true end
                    end)
                end
                hudForced[gui] = nil
            end
        end

        local function isFinalOverlay(gui)
            if not gui:IsA("ScreenGui") then return false end
            local name = gui.Name:lower()
            if name:find("ending", 1, true) or name:find("needle", 1, true) then return false end
            return name == "cutscenefade" or name:find("cutscene", 1, true) ~= nil
                or name:find("cinematic", 1, true) ~= nil
                or name:find("chapter2release", 1, true) ~= nil
        end
        local function maskFinalProperty(inst, key)
            local ok, previous = pcall(function() return inst[key] end)
            if not ok or type(previous) ~= "number" or previous >= 1 then return end
            local saved = finalVisualBefore[inst]
            if not saved then saved = {}; finalVisualBefore[inst] = saved end
            if saved[key] == nil then saved[key] = previous end
            pcall(function() inst[key] = 1 end)
        end
        local function hideFinalCutsceneVisuals()
            if not finalVisualsEnabled or not scene then return end
            -- Full overlay descendant scans are unnecessary every frame.
            -- The scene poll still catches dynamically added cutscene graphics.
            local now = os.clock()
            if now - lastFinalVisualMaskAt < 0.16 then return end
            lastFinalVisualMaskAt = now
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            for _, gui in ipairs(pg:GetChildren()) do
                if isFinalOverlay(gui) then
                    for _, el in ipairs(gui:GetDescendants()) do
                        if el:IsA("GuiObject") then
                            maskFinalProperty(el, "BackgroundTransparency")
                            if el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("TextBox") then
                                maskFinalProperty(el, "TextTransparency")
                                maskFinalProperty(el, "TextStrokeTransparency")
                            end
                            if el:IsA("ImageLabel") or el:IsA("ImageButton") then
                                maskFinalProperty(el, "ImageTransparency")
                            end
                        elseif el:IsA("UIStroke") then
                            maskFinalProperty(el, "Transparency")
                        end
                    end
                end
            end
        end
        local function restoreFinalCutsceneVisuals()
            for inst, props in pairs(finalVisualBefore) do
                if inst.Parent then
                    for key, original in pairs(props) do
                        pcall(function() inst[key] = original end)
                    end
                end
                finalVisualBefore[inst] = nil
            end
        end

        local function indexSkipCandidate(inst)
            if not inst then return end
            local btn = nil
            if inst:IsA("GuiButton") then
                btn = inst
            elseif inst:IsA("TextLabel") and inst.Text:lower():find("skip", 1, true) then
                local ancestor = inst.Parent
                while ancestor and not ancestor:IsA("GuiButton") do
                    ancestor = ancestor.Parent
                end
                btn = ancestor
            end
            if not btn then return end
            local name = btn.Name:lower()
            local text = btn:IsA("TextButton") and btn.Text:lower() or ""
            local marked = name:find("skip", 1, true) or text:find("skip", 1, true)
            if not marked then
                for _, child in ipairs(btn:GetChildren()) do
                    if child:IsA("TextLabel") and child.Text:lower():find("skip", 1, true) then
                        marked = true
                        break
                    end
                end
            end
            if marked then skipCandidates[btn] = true end
        end
        local function scanSkipCandidates(pg)
            for _, obj in ipairs(pg:GetDescendants()) do indexSkipCandidate(obj) end
        end
        local function watchSkipGui()
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if pg == skipGui and skipGuiAddedConnection then return pg end
            if skipGuiAddedConnection then pcall(function() skipGuiAddedConnection:Disconnect() end) end
            skipGuiAddedConnection, skipGui = nil, pg
            if pg then
                scanSkipCandidates(pg)
                skipGuiAddedConnection = pg.DescendantAdded:Connect(indexSkipCandidate)
            end
            return pg
        end
        local function skipButtonVisible(pg)
            local ending = pg:FindFirstChild("NeedleEndingUI")
            if not ending or not ending.Enabled then return false end
            for btn in pairs(skipCandidates) do
                if not btn.Parent or not btn:IsDescendantOf(pg) then
                    skipCandidates[btn] = nil
                elseif btn:IsDescendantOf(ending) then
                    local visible, parent = true, btn
                    while parent and parent ~= pg do
                        if parent:IsA("GuiObject") and not parent.Visible then visible = false; break end
                        if parent:IsA("ScreenGui") and not parent.Enabled then visible = false; break end
                        parent = parent.Parent
                    end
                    if visible then return true end
                end
            end
            return false
        end
        local function skipButtonOnScreen()
            -- The ending is not eligible until our hand-in starts. This
            -- avoids unrelated/early Skip elements suppressing puzzle bypass.
            if not finalEndingProtected then
                lastEndingSkipVisible = false
                return false
            end
            local now = os.clock()
            if now - lastEndingSkipScan < 0.08 then return lastEndingSkipVisible end
            lastEndingSkipScan = now
            local pg = watchSkipGui()
            if not pg then lastEndingSkipVisible = false; return false end
            lastEndingSkipVisible = skipButtonVisible(pg)
            local endingUI = pg:FindFirstChild("NeedleEndingUI")
            if not (endingUI and endingUI:IsA("ScreenGui") and endingUI.Enabled) then
                lastEndingSkipVisible = false
                return false
            end
            -- Ownership of the needle/key alone is not an ending cutscene.
            -- Added GUI objects are indexed immediately by DescendantAdded.
            local endingVisible = endingUI and endingUI.Enabled == true
            local fallbackEvery = endingVisible and 0.5 or (scene and 1.0 or 4.0)
            if not lastEndingSkipVisible and now - lastSkipFallbackScan >= fallbackEvery then
                lastSkipFallbackScan = now
                scanSkipCandidates(pg)
                lastEndingSkipVisible = skipButtonVisible(pg)
            end
            return lastEndingSkipVisible
        end
        local function releaseEndingCursor()
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
            pcall(function() UserInputService.MouseIconEnabled = true end)
        end

        local function restoreInputs()
            local hum = humanoid()
            if hum then
                if hum.PlatformStand then pcall(function() hum.PlatformStand = false end) end
                if hum.Sit then pcall(function() hum.Sit = false end) end
                if hum.WalkSpeed <= 0 then hum.WalkSpeed = lastSavedSpeed or 16 end
                if hum.JumpPower <= 0 then hum.JumpPower = lastSavedJump or 50 end
                if not faceCameraEnabled and lastSavedRotate ~= nil and hum.AutoRotate ~= lastSavedRotate then
                    hum.AutoRotate = lastSavedRotate
                end
            end
            local rt = root()
            if scene and rt and rt.Anchored then
                pcall(function() rt.Anchored = false end)
            end
            local ctrl = getControls()
            local now = os.clock()
            if ctrl and (ctrl.enabled == false or now - lastControlEnableAt >= 0.25) then
                lastControlEnableAt = now
                pcall(function() ctrl:Enable() end)
            end
            if player:GetAttribute("NeedleInputLocked") == true then
                pcall(function() player:SetAttribute("NeedleInputLocked", nil) end)
            end
        end
        local function alignCharacterFacing()
            if not alive or not enabled or not active or not faceCameraEnabled then return end
            local hum, rt = humanoid(), root()
            if not hum or not rt or rt.Anchored or not yaw then return end
            local forward = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
            local oldLook = rt.CFrame.LookVector
            local flatOld = Vector3.new(oldLook.X, 0, oldLook.Z)
            local dot = flatOld.Magnitude > 0.01 and flatOld.Unit:Dot(forward) or 0
            if hum.AutoRotate then hum.AutoRotate = false end
            if dot < 0.9995 then
                local desired = CFrame.lookAt(rt.Position, rt.Position + forward, Vector3.yAxis)
                pcall(function() rt.CFrame = rt.CFrame:Lerp(desired, 0.35) end)
            end
        end
        local function directMovement()
            local hum = humanoid()
            if not hum or UserInputService:GetFocusedTextBox() then return end
            local function down(key)
                return UserInputService:IsKeyDown(key)
            end
            local x = (down(Enum.KeyCode.D) and 1 or 0) - (down(Enum.KeyCode.A) and 1 or 0)
            local z = (down(Enum.KeyCode.W) and 1 or 0) - (down(Enum.KeyCode.S) and 1 or 0)
            if x ~= 0 or z ~= 0 then
                if not yaw then return end
                local front = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
                local right = Vector3.new(-front.Z, 0, front.X)
                local motion = front*z + right*x
                if motion.Magnitude > 1 then motion = motion.Unit end
                pcall(function() hum:Move(motion, false) end)
            end
            if down(Enum.KeyCode.Space) then pcall(function() hum.Jump = true end) end
        end
        local function restoreCamera()
            restoreHeadTransparency()
            local cam = camera()
            if cam then
                local hum = humanoid()
                if hum then pcall(function() cam.CameraSubject = hum end) end
                pcall(function() cam.CameraType = Enum.CameraType.Custom end)
            end
            local hum = humanoid()
            if hum and lastSavedRotate ~= nil then
                pcall(function() hum.AutoRotate = lastSavedRotate end)
            end
            local ctrl = getControls()
            if ctrl then pcall(function() ctrl:Enable() end) end
            if originalMouseBehavior then
                pcall(function() UserInputService.MouseBehavior = originalMouseBehavior end)
                originalMouseBehavior = nil
            end
        end
        local function enablePlayableCamera(reason)
            if active then return end
            setCutsceneBypassActive(true)
            active = true
            setupPlayableCamera()
            local ctrl = getControls()
            if ctrl then pcall(function() ctrl:Enable() end) end
            log("PLAYABLE CAMERA ENABLED: " .. tostring(reason))
            if scene == "THREE LEVERS" then watchLeverCamera() end
            forceCamera()
        end
        local function disablePlayableCamera(reason)
            unwatchLeverCamera()
            if not active then return end
            active = false
            restoreCamera()
            setCutsceneBypassActive(false)
            log("ROBLOX CAMERA RETURNED: " .. tostring(reason))
        end
        local function updateScene()
            if not alive then return end
            -- Needle and puzzle VIM routines own the camera. During Gem,
            -- recover cutscene movement/input and HUD, but NEVER restore or
            -- force a second camera over the Gem solver's targeting.
            if needleBusy or leverRunning or colourRunning then
                if colourRunning and enabled and not finalEndingProtected
                    and hubWindow.Closed == true then restoreInputs() end
                if active then showGameplayHud() end
                return
            end
            local now = os.clock()
            if player:GetAttribute("Chapter2ReleaseActive") == true then chapter2ReleaseSeen = true end
            local hasSkip = skipButtonOnScreen()
            if not hasSkip then yieldingToEnding = false end
            if hasSkip and not yieldingToEnding then
                yieldingToEnding = true
                recoveryEnd = 0
                log("SKIPPABLE NEEDLE ENDING DETECTED — camera bypass released; mouse unlocked for SKIP / hub AutoSkip")
            end
            local current = enabled and kind() or nil
            if current then
                if current ~= scene then
                    scene = current
                    if current == "THREE PUZZLES" then
                        unwatchLeverCamera()
                        log("CHAPTER 2 RELEASE: camera/movement override; optional transparency-only cutscene visual mask")
                    end
                    log("CUTSCENE DETECTED: " .. current)
                    if current == "THREE PUZZLES" then
                        print("[BeyyHub Cutscene] Puzzle-release cinematic bypass active (final needle ending remains protected)")
                    end
                    recoveryEnd = 0
                    if not active then enablePlayableCamera(current) end
                end
            elseif scene then
                log("CUTSCENE FLAG CLEARED: " .. scene .. " — restoring Roblox camera in " .. RECOVERY_GRACE_SECONDS .. "s")
                restoreFinalCutsceneVisuals()
                unwatchLeverCamera()
                scene = nil
                recoveryEnd = now + RECOVERY_GRACE_SECONDS
                task.delay(RECOVERY_GRACE_SECONDS + 0.008, function()
                    if alive then updateScene() end
                end)
            end
            local shouldKeep = enabled and not yieldingToEnding and (current ~= nil or now < recoveryEnd)
            if shouldKeep then
                if not active then enablePlayableCamera("recovery / F7") end
                restoreInputs()
                showGameplayHud()
                hideFinalCutsceneVisuals()
            else
                restoreFinalCutsceneVisuals()
                restoreGameplayHud()
                if active then disablePlayableCamera("recovered / bypass disabled") end
            end
            if yieldingToEnding and lastEndingSkipVisible then releaseEndingCursor() end
        end
        cutsceneBypassRefresh = function()
            if alive then updateScene() end
        end

        hook(UserInputService.InputBegan:Connect(function(input, processed)
            if processed or UserInputService:GetFocusedTextBox() or shouldYieldCutsceneBypass() then return end
            if input.KeyCode == Enum.KeyCode.F3 then
                finalVisualsEnabled = not finalVisualsEnabled
                if not finalVisualsEnabled then restoreFinalCutsceneVisuals() end
                log("F3: final cinematic visual masking " .. (finalVisualsEnabled and "ENABLED" or "DISABLED"))
            elseif input.KeyCode == Enum.KeyCode.F4 then
                faceCameraEnabled = not faceCameraEnabled
                local hum = humanoid()
                if hum and not faceCameraEnabled and lastSavedRotate ~= nil then
                    pcall(function() hum.AutoRotate = lastSavedRotate end)
                end
                log("F4: camera-facing character alignment " .. (faceCameraEnabled and "ENABLED" or "DISABLED"))
                if faceCameraEnabled then alignCharacterFacing() end
            elseif input.KeyCode == Enum.KeyCode.F5 then
                hudEnabled = not hudEnabled
                if not hudEnabled then restoreGameplayHud() end
                log("F5: gameplay HUD preservation " .. (hudEnabled and "ENABLED" or "DISABLED"))
            elseif input.KeyCode == Enum.KeyCode.F7 then
                recoveryEnd = 0
                log("F7: Roblox camera recovery requested")
                updateScene()
            end
        end))
        hook(UserInputService.InputChanged:Connect(function(input)
            if not active or shouldYieldCutsceneBypass() then return end
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                if not cameraFirstPerson then
                    distance = clamp(distance - input.Position.Z * 1.5, 0.4, 22)
                end
            end
        end))
        hook(player.AttributeChanged:Connect(function(attr)
            if attr == "IntroCutsceneFinished" then
                if player:GetAttribute("IntroCutsceneFinished") == true and not introConfirmedAt then
                    introConfirmedAt = os.clock()
                    introNeutralSeen = player:GetAttribute("CutsceneActive") ~= true
                    log("SKIPPABLE INTRO COMPLETED — waiting for clean lever trigger; intro ignored")
                elseif player:GetAttribute("IntroCutsceneFinished") ~= true then
                    introConfirmedAt, introNeutralSeen = nil, false
                    chapter2ReleaseSeen, yieldingToEnding = false, false
                    lastEndingSkipScan, lastEndingSkipVisible = 0, false
                end
            elseif attr == "CutsceneActive" and player:GetAttribute("CutsceneActive") ~= true
                and introConfirmedAt then
                introNeutralSeen = true
            end
            if attr == "CutsceneActive" or attr == "Chapter2ReleaseActive" or
                attr == "IntroCutsceneFinished" or attr == "NeedleInputLocked" or attr == "NeedleOwned" then
                task.defer(updateScene)
            end
        end))
        hook(player.CharacterAdded:Connect(function()
            controls, lastSavedSpeed, lastSavedJump, lastSavedRotate = nil, nil, nil, nil
            task.delay(0.4, function() if alive and not active then rememberGameplay() end end)
        end))

        local function handleCameraInput()
            if not alive or not enabled or not active or not yaw then return end
            pcall(function()
                if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                end
            end)
            local ok, md = pcall(function() return UserInputService:GetMouseDelta() end)
            if ok and md then
                if math.abs(md.X) > 0 or math.abs(md.Y) > 0 then
                    yaw = yaw - md.X * 0.004
                    pitch = clamp(pitch - md.Y * 0.004, -1.0, 0.85)
                end
            end
            local now = os.clock()
            local dt = clamp(now - lastRenderTime, 0, 0.08)
            lastRenderTime = now
            local function down(key) return UserInputService:IsKeyDown(key) end
            if not UserInputService:GetFocusedTextBox() then
                local h = (down(Enum.KeyCode.Right) and 1 or 0) - (down(Enum.KeyCode.Left) and 1 or 0)
                local v = (down(Enum.KeyCode.Up) and 1 or 0) - (down(Enum.KeyCode.Down) and 1 or 0)
                if h ~= 0 or v ~= 0 then
                    yaw = yaw - h * dt * 1.9
                    pitch = clamp(pitch + v * dt * 1.3, -1.0, 0.85)
                end
            end
        end
        RunService:BindToRenderStep(renderId, renderPriority, function()
            if alive and yieldingToEnding and skipButtonOnScreen() then
                if active then updateScene() end
                releaseEndingCursor()
            end
            if alive and enabled and colourRunning and not finalEndingProtected
                and hubWindow.Closed == true and not yieldingToEnding
                and (os.clock() < leverBypassUntil
                    or os.clock() < puzzleBypassUntil
                    or player:GetAttribute("CutsceneActive") == true
                    or player:GetAttribute("Chapter2ReleaseActive") == true) then
                -- This late render callback runs after the cinematic's camera
                -- script AND after Gem's normal aim callback, so Gem wins the
                -- camera contest without the bypass fighting its teleports.
                restoreInputs()
                if gemCutsceneCameraAim then gemCutsceneCameraAim() end
                showGameplayHud()
                lastRenderTime = os.clock()
            elseif alive and enabled and active and not yieldingToEnding and not shouldYieldCutsceneBypass() then
                -- Camera, input and HUD need last-render-priority enforcement
                -- during cinematic scripts; expensive descendant scans stay
                -- throttled in updateScene.
                restoreInputs()
                handleCameraInput()
                forceCamera()
                alignCharacterFacing()
                directMovement()
                showGameplayHud()
            else
                lastRenderTime = os.clock()
            end
        end)
        local simulationSignal = RunService.PreSimulation or RunService.Heartbeat
        hook(simulationSignal:Connect(function()
            if alive and enabled and active and not yieldingToEnding and not shouldYieldCutsceneBypass() then
                restoreInputs()
                directMovement()
            end
        end))

        local function stop()
            if not alive then return end
            cutsceneBypassRefresh = nil
            local wasActive = active
            alive, enabled, active = false, false, false
            pcall(function() RunService:UnbindFromRenderStep(renderId) end)
            unwatchLeverCamera()
            if skipGuiAddedConnection then pcall(function() skipGuiAddedConnection:Disconnect() end) end
            skipGuiAddedConnection = nil
            restoreGameplayHud()
            restoreFinalCutsceneVisuals()
            for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
            if wasActive then restoreCamera() end
            setCutsceneBypassActive(false)
            if env.__BEYY_CUTSCENE_BYPASS_STOP == stop then env.__BEYY_CUTSCENE_BYPASS_STOP = nil end
            if _G.__BEYY_CUTSCENE_BYPASS_STOP == stop then _G.__BEYY_CUTSCENE_BYPASS_STOP = nil end
            if lastEndingSkipVisible then releaseEndingCursor() end
            log("STOPPED")
        end

        rememberGameplay()
        rememberGameplayHud()
        updateScene()
        task.spawn(function()
            while alive do
                task.wait((active or scene) and 0.1 or 0.35)
                if not active and not scene then
                    rememberGameplay()
                    rememberGameplayHud()
                end
                updateScene()
            end
        end)
        log("READY: three-lever and three-puzzle cutscenes only; intro and needle ending excluded")
        log("F3 visual mask | F4 facing | F5 HUD | F7 restore | Exploit-tab toggle controls enable/disable")
        log("Mouse / arrows aim, WASD moves. Normal camera restores immediately after cutscenes.")
        log("Visual/client-side bypass only; no server cutscene timers or progression changed.")

        env.__BEYY_CUTSCENE_BYPASS_STOP = stop
        return stop
    end)
    if not ok or type(result) ~= "function" then
        warn("[BeyyHub] Cutscene bypass failed to start: " .. tostring(result))
        return false
    end
    cutsceneBypassStop = result
    return true
end
local function shutdownCutsceneBypass()
    local stopFn = cutsceneBypassStop
    cutsceneBypassStop = nil
    if stopFn then pcall(stopFn) end
end
local previousCutsceneHubCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    for _, connection in ipairs(autoCutsceneSignals) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(autoCutsceneSignals)
    shutdownCutsceneBypass()
    if previousCutsceneHubCleanup then pcall(previousCutsceneHubCleanup) end
end

    overview:Section({ Title = "Cutscenes" })
    Registry.CutsceneBypass = overview:Toggle({
        Title = "Unskippable Cutscene Bypass", Value = false,
        Desc = "Auto ON after all three levers; OFF BEFORE needle hand-in. No effect on the server's timer.",
        Callback = function(enabled)
            if enabled then
                if __BEYY_CH2_NO_LEVERS_STARTED then
                    print("[BeyyHub Cutscene] Integrated v33 owns non-final camera; duplicate bypass suppressed")
                    task.defer(function()
                        if Registry.CutsceneBypass and Registry.CutsceneBypass.Value == true then
                            Registry.CutsceneBypass:Set(false)
                        end
                    end)
                    return
                end
                if finalEndingProtected then
                    task.defer(function()
                        local toggle = Registry.CutsceneBypass
                        if toggle and toggle.Value == true then toggle:Set(false) end
                    end)
                    return
                end
                if not launchCutsceneBypass() then warn("[BeyyHub] Cutscene bypass could not start") end
            else shutdownCutsceneBypass() end
        end,
    })

    -- Run this small cutscene-cycle setup in its own Luau function scope.
    -- It had exceeded the enclosing Chapter2 function's 200-local limit.
    -- Synchronous call preserves all toggles, listeners and callbacks.
    do
        (function()
    local autoBypassCycleActive = false
    local ownedNeedleDuringCycle = LocalPlayer:GetAttribute("NeedleOwned") == true
    local needleOwnedPrevious = ownedNeedleDuringCycle

    autoCutsceneEnableAfterLevers = function(reason)
        if __BEYY_CH2_NO_LEVERS_STARTED then return end
        -- The coordinated solver has just confirmed all three levers.
        -- Do not let a prematurely replicated release flag suppress it.
        -- Generic CutsceneActive listeners are guarded separately.
        if hubUnloaded or autoBypassCycleActive or finalEndingProtected
            or postPuzzleKeyPriority
            or LocalPlayer:GetAttribute("NeedleOwned") == true
            or cutsceneResultsVisible() then return end
        leverBypassUntil = math.max(leverBypassUntil, os.clock() + 6.5)
        print("[BeyyHub Cutscene] Lever bypass grace started (6.5s); " .. tostring(reason))
        local toggle = Registry.CutsceneBypass
        if not toggle then return end
        if toggle.Value ~= true then toggle:Set(true) end
        if toggle.Value == true and type(cutsceneBypassStop) == "function" then
            autoBypassCycleActive = true
            ownedNeedleDuringCycle = LocalPlayer:GetAttribute("NeedleOwned") == true
            if cutsceneBypassRefresh then
                local okRefresh, refreshErr = pcall(cutsceneBypassRefresh)
                if not okRefresh then warn("[BeyyHub Cutscene] Lever activation refresh: "..tostring(refreshErr)) end
            end
            print("[BeyyHub Cutscene] AUTO ON after " .. tostring(reason))
        else
            warn("[BeyyHub Cutscene] Auto-enable failed; manual toggle remains available")
            if toggle.Value == true then toggle:Set(false) end
        end
    end

    autoCutsceneDisableAfterHandIn = function(reason)
        if hubUnloaded then return end
        finalEndingProtected = true
        leverBypassUntil = 0
        puzzleBypassUntil = 0
        local wasActive = autoBypassCycleActive
        autoBypassCycleActive = false
        ownedNeedleDuringCycle = false
        local toggle = Registry.CutsceneBypass
        if toggle and toggle.Value == true then toggle:Set(false)
        else shutdownCutsceneBypass() end
        print("[BeyyHub Cutscene] Final ending protected; bypass OFF after " ..
            tostring(reason) .. (wasActive and " (automatic cycle)" or ""))
    end

    table.insert(autoCutsceneSignals, LocalPlayer:GetAttributeChangedSignal("Chapter2ReleaseActive"):Connect(function()
        if LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true
            and not finalEndingProtected and LocalPlayer:GetAttribute("NeedleOwned") ~= true then
            puzzleReleaseObserved = true
            puzzleBypassUntil = math.max(puzzleBypassUntil, os.clock() + 6.5)
            print("[BeyyHub Cutscene] Puzzle-release flag observed; bypass grace 6.5s (final ending excluded)")
        end
    end))
    table.insert(autoCutsceneSignals, LocalPlayer:GetAttributeChangedSignal("CutsceneActive"):Connect(function()
        if __BEYY_CH2_NO_LEVERS_STARTED then return end
        if hubUnloaded or leverRunning or autoBypassCycleActive or finalEndingProtected
            or postPuzzleKeyPriority or puzzleReleaseObserved
            or LocalPlayer:GetAttribute("NeedleOwned") == true
            or cutsceneResultsVisible() then return end
        if LocalPlayer:GetAttribute("CutsceneActive") == true
            and LocalPlayer:GetAttribute("IntroCutsceneFinished") == true
            and LocalPlayer:GetAttribute("Chapter2ReleaseActive") ~= true
            and leverFolder() then
            autoCutsceneEnableAfterLevers("post-lever cutscene (manual levers)")
        end
    end))

    table.insert(autoCutsceneSignals, LocalPlayer:GetAttributeChangedSignal("NeedleOwned"):Connect(function()
        if hubUnloaded then return end
        local owned = LocalPlayer:GetAttribute("NeedleOwned") == true
        if autoBypassCycleActive then
            if owned then
                ownedNeedleDuringCycle = true
            elseif needleOwnedPrevious and ownedNeedleDuringCycle then
                local laser = Workspace:FindFirstChild("Laser")
                local root = farmRoot()
                local nearHandIn = laser and laser:IsA("Model") and root
                    and (root.Position - laser:GetPivot().Position).Magnitude <= 30
                if nearHandIn or cutsceneResultsVisible()
                    or LocalPlayer:GetAttribute("Chapter2ReleaseActive") == true then
                    finalEndingProtected = true
                    autoCutsceneDisableAfterHandIn("needle ownership cleared at hand-in")
                end
            end
        end
        needleOwnedPrevious = owned
    end))
        end)()
    end
    end

    do
        -- Keep config setup synchronous while isolating its locals from
        -- the near-limit Chapter 2 module scope.
        (function()
        local SettingsTab = overviewTab
        local ConfigManager = hubWindow.ConfigManager
        local function Header(tab, title) tab:Section({ Title = title }) end
        local function Notify(title, content, duration, icon)
            pcall(function() hubNativeUI:Notify({ Title=title, Content=content, Duration=duration or 3, Icon=icon }) end)
        end
    local ConfigTab = SettingsTab:CollapsibleGroup({ Title = "Config", Opened = false })
    local saveConfigName = "default"
    local selectedConfigName = nil
    local configDropdown = nil
    local EMPTY_CONFIG = "(No saved configs)"
    local configCache = {}
    local function buildConfig(name)
        local cfg = ConfigManager:CreateConfig(name)
        for key, element in pairs(Registry) do cfg:Register(key, element) end
        function cfg:Snapshot()
            local previous = __beyyConfigDecode(__beyyReadConfig(name))
            local saved = {
                __version = 1.2,
                __elements = {},
                __custom = previous and previous.__custom or self.CustomData or {},
                __autoload = previous and previous.__autoload == true or false,
            }
            if previous then
                for key, entry in pairs(previous.__elements or previous) do
                    if type(entry) == "table" and type(entry.__type) == "string" then
                        saved.__elements[key] = entry
                    end
                end
            end
            for key, el in pairs(self.Elements) do
                local value = el.Value
                if el.__type == "Slider" then
                    value = type(value) == "table" and value.Default or value
                end
                if type(value) == "boolean" or type(value) == "string" or type(value) == "number"
                    or type(value) == "table" then
                    saved.__elements[key] = {__type = el.__type, value = value}
                end
            end
            return saved
        end
        function cfg:Save()
            local saved = self:Snapshot()
            local raw = __BEYY_CONFIG_HTTP:JSONEncode(saved)
            local playerStored, teleportStored = __beyyRememberConfig(name, raw)
            local diskOK = false
            if safeWrite(self.Path, raw) then
                for attempt = 1, 4 do
                    local check = __beyyConfigDecode(safeRead(self.Path))
                    if check and __beyySameJSON(check, saved) then
                        diskOK = true
                        break
                    end
                    if attempt < 4 then task.wait(0.1) end
                end
            end
            local storage = diskOK and "disk" or (playerStored and "session"
                or (teleportStored and "teleport" or "runtime"))
            if not diskOK then
                warn("[BeyyHub Config] " .. name .. " disk write unverified; session=" ..
                    tostring(playerStored) .. " teleport=" .. tostring(teleportStored) ..
                    ". Export JSON before closing Roblox.")
            end
            print("[BeyyHub Config] Saved " .. name .. " (storage=" .. storage .. ")")
            return saved, storage
        end
        function cfg:Load()
            local raw, source = __beyyReadConfig(name)
            local data = __beyyConfigDecode(raw)
            if not data then return false, "No readable config: " .. name end
            local applied = 0
            for key, el in pairs(self.Elements) do
                local entry = (data.__elements or data)[key]
                if type(entry) == "table" and entry.__type == el.__type then
                    local ok, err = pcall(function()
                        if el.__type == "Dropdown" then el:Select(entry.value)
                        else el:Set(entry.value) end
                    end)
                    if ok then applied += 1
                    else warn("[BeyyHub Config] Could not restore " .. tostring(key) .. ": " .. tostring(err)) end
                end
            end
            self.CustomData = data.__custom or {}
            __beyyRememberConfig(name, raw)
            print("[BeyyHub Config] Loaded " .. name .. " from " .. source .. " (" .. applied .. " controls)")
            return self.CustomData, source
        end
        function cfg:Export()
            return __BEYY_CONFIG_HTTP:JSONEncode(self:Snapshot())
        end
        function cfg:Import(raw)
            if type(raw) ~= "string" or #raw > 250000 then return false, "Invalid JSON size" end
            local data = __beyyConfigDecode(raw)
            if not data then return false, "Invalid BeyyHub JSON" end
            __beyyRememberConfig(name, __BEYY_CONFIG_HTTP:JSONEncode(data))
            return self:Load()
        end
        return cfg
    end
    local function getConfigNames()
        local ok, names = pcall(function() return ConfigManager:AllConfigs() end)
        if not ok or type(names) ~= "table" then
            warn("[Config] Unable to list saved configs: ".. tostring(names))
            names = {}
        end
        local result, seen = {}, {}
        local sessionFolder = __beyyPlayerConfigFolder(false)
        if sessionFolder then
            for _, savedEntry in ipairs(sessionFolder:GetChildren()) do
                if savedEntry:IsA("StringValue") and __beyyConfigDecode(savedEntry.Value)
                    and not seen[savedEntry.Name] then
                    seen[savedEntry.Name] = true
                    table.insert(result, savedEntry.Name)
                end
            end
        end
        for rememberedName, rememberedJSON in pairs(__beyyConfigSession) do
            if __beyyConfigDecode(rememberedJSON) and not seen[rememberedName] then
                seen[rememberedName] = true
                table.insert(result, rememberedName)
            end
        end
        for _, name in ipairs(names) do
            if type(name) == "string" and #name > 0 and not seen[name] then
                seen[name] = true
                table.insert(result, name)
            end
        end
        table.sort(result, function(a, b) return a:lower() < b:lower() end)
        return result
    end
    local function containsConfig(list, name)
        for _, entry in ipairs(list) do if entry == name then return true end end
        return false
    end
    local function refreshConfigDropdown(preferredName)
        local names = getConfigNames()
        local chosen = nil
        if preferredName and containsConfig(names, preferredName) then
            chosen = preferredName
        elseif selectedConfigName and containsConfig(names, selectedConfigName) then
            chosen = selectedConfigName
        elseif containsConfig(names, "default") then
            chosen = "default"
        else
            chosen = names[1]
        end
        selectedConfigName = chosen
        if configDropdown then
            local values = #names > 0 and names or { EMPTY_CONFIG }
            local ok, err = pcall(function()
                configDropdown:Refresh(values)
                configDropdown:Select(chosen or EMPTY_CONFIG)
            end)
            if not ok then warn("[Config] Dropdown refresh failed: ".. tostring(err)) end
        end
        return #names
    end
    if ConfigManager then
        local saved = getConfigNames()
        local activeSavedName = __beyyActiveConfigName()
        local initialConfig = containsConfig(saved, activeSavedName) and activeSavedName
            or (containsConfig(saved, "default") and "default" or saved[1])
        selectedConfigName = initialConfig
        configDropdown = ConfigTab:Dropdown({
            Title = "Select Config to Load",
            Desc = "Choose from your saved config files",
            Values = #saved > 0 and saved or { EMPTY_CONFIG },
            Value = initialConfig or EMPTY_CONFIG,
            AllowNone = false,
            Callback = function(value)
                selectedConfigName = (type(value) == "string" and value ~= EMPTY_CONFIG) and value or nil
            end,
        })
        ConfigTab:Button({
            Title = "Refresh Config List",
            Callback = function()
                local count = refreshConfigDropdown()
                Notify("Config", "Found ".. tostring(count).. " saved config(s)", 3, "refresh-cw")
            end,
        })
        ConfigTab:Button({
            Title = "Load Selected Config",
            Callback = function()
                local name = selectedConfigName
                if not name or not containsConfig(getConfigNames(), name) then
                    Notify("Config", "Select an existing config first", 3, "x")
                    return
                end
                local ok, loaded, err = pcall(function() return buildConfig(name):Load() end)
                local success = ok and loaded ~= false and loaded ~= nil
                Notify("Config", success and ("Loaded: ".. name) or ("Failed: ".. tostring(ok and err or loaded)), 3, success and "check" or "x")
            end,
        })
        ConfigTab:Input({
            Title = "Save Config As", Value = saveConfigName, Placeholder = "default",
            Callback = function(value)
                if type(value) == "string" and value:match("%S") then saveConfigName = value end
            end,
        })
        ConfigTab:Button({
            Title = "Save Config",
            Callback = function()
                local name = saveConfigName
                if not name or not name:match("^[%w_%-%s]+$") then
                    Notify("Config", "Use letters, numbers, spaces, _ or -", 3, "x")
                    return
                end
                local ok, savedData, storage = pcall(function() return buildConfig(name):Save() end)
                local success = ok and type(savedData) == "table"
                if success then refreshConfigDropdown(name) end
                Notify("Config", success and (storage == "disk" and ("Saved to disk: ".. name)
                    or (storage == "session" and ("Session saved: ".. name .. " (copy JSON for restart)")
                    or ("Runtime/teleport only: " .. name .. " (copy JSON)")))
                    or ("Failed: ".. tostring(ok and storage or savedData)), 5, success and "check" or "x")
            end,
        })
        local pastedConfigJSON = ""
        ConfigTab:Input({
            Title = "Paste Config JSON for import", Value = "", Placeholder = "Paste exported JSON here",
            Callback = function(value) pastedConfigJSON = tostring(value or "") end,
        })
        ConfigTab:Button({
            Title = "Copy Config JSON",
            Callback = function()
                local name = saveConfigName
                local ok, raw = pcall(function() return buildConfig(name):Export() end)
                if not ok then Notify("Config", "Export failed: " .. tostring(raw), 4, "x"); return end
                if type(setclipboard) == "function" then
                    local copied = pcall(setclipboard, raw)
                    Notify("Config", copied and ("Copied " .. name .. " JSON; keep it outside Roblox for restarts.") or
                        "Could not copy JSON", 5, copied and "check" or "x")
                else
                    print("[BeyyHub Config Export] " .. raw)
                    Notify("Config", "Clipboard unavailable; JSON printed to console", 4)
                end
            end,
        })
        ConfigTab:Button({
            Title = "Import Config JSON",
            Callback = function()
                local raw = pastedConfigJSON
                if raw == "" and type(getclipboard) == "function" then
                    local ok, value = pcall(getclipboard)
                    if ok and type(value) == "string" then raw = value end
                end
                local name = saveConfigName
                local ok, result, detail = pcall(function() return buildConfig(name):Import(raw) end)
                local success = ok and result ~= false and result ~= nil
                if success then refreshConfigDropdown(name) end
                Notify("Config", success and ("Imported " .. name .. " for this session. Save to try disk.") or
                    ("Import failed: " .. tostring(ok and detail or result)), 5, success and "check" or "x")
            end,
        })
        task.defer(function()
            if hubUnloaded then return end
            local startConfig = __beyyActiveConfigName()
            local raw = __beyyReadConfig(startConfig)
            if not raw and startConfig ~= "default" then
                startConfig = "default"
                raw = __beyyReadConfig(startConfig)
            end
            local cfg = buildConfig(startConfig)
            if not raw then
                warn("[BeyyHub] Chapter 2 default config unavailable at " .. tostring(cfg.Path))
                return
            end
            local ok, decoded = pcall(function() return httpService:JSONDecode(raw) end)
            if not ok or type(decoded) ~= "table" then
                warn("[BeyyHub] Chapter 2 default config is unreadable")
                return
            end
            local loadedOK, loaded, err = pcall(function() return cfg:Load() end)
            if not loadedOK or loaded == false or loaded == nil then
                warn("[BeyyHub] Chapter 2 default config load failed: " .. tostring(err or loaded))
                return
            end
            print("[BeyyHub] Chapter 2 latest default config applied synchronously")
        end)
    else
        ConfigTab:Paragraph({ Title = "Configs unavailable", Desc = "Saving configs requires filesystem support in your environment." })
    end
        end)()
    end

    task.defer(function()
        if not hubUnloaded then hideNonFarmMenu() end
    end)
    print("[BeyyHub] v103.00 " .. BEYY_CHAPTER .. " module loaded (RightControl to open)")
    print(("[BeyyHub Startup] %s controls and features registered after %.2fs in module"):format(
        BEYY_CHAPTER, os.clock() - __BEYY_BOOT_T0))
end
