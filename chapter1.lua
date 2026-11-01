-- beyy v103.00 | Chapter1 module | PlaceId 108628039999641
local __BEYY_MODULE = "Chapter1"
local __BEYY_SCRIPT_VERSION = "103.00"
local __BEYY_BOOT_T0 = os.clock()
if game.PlaceId ~= 108628039999641 then
    warn("[BeyyHub] Refusing to load Chapter1 module in another place")
    return
end

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

local afkPreferencePath = CACHE_FOLDER .. "/autofarmwins_preference_v2.txt"
local afkLegacyPath = CACHE_FOLDER .. "/autofarmwins_shared.txt"
local activeConfigPath = CACHE_FOLDER .. "/active_config.txt"
local TELEPORT_AFK_KEY = "BeyyHub_AutoFarmWins_v103"
local TeleportService = game:GetService("TeleportService")

local function readTeleportAFK()
    local ok, value = pcall(function() return TeleportService:GetTeleportSetting(TELEPORT_AFK_KEY) end)
    if ok and type(value) == "boolean" then return value end
    return nil
end

local function writeTeleportAFK(value)
    if type(value) ~= "boolean" then return false end
    local ok = pcall(function() TeleportService:SetTeleportSetting(TELEPORT_AFK_KEY, value) end)
    if not ok then warn("[BeyyHub] Teleport AFK setting unavailable; falling back to saved config/files") end
    return ok
end

local function configAutoFarmValue(name)
    if type(name) ~= "string" or not name:match("^[%w_%-%s]+$") then return nil end
    local data = __beyyReadConfig(name)
    if not data then return nil end
    local ok, decoded = pcall(function() return game:GetService("HttpService"):JSONDecode(data) end)
    if not ok or type(decoded) ~= "table" then return nil end
    local stored = (decoded.__elements or decoded).AutoFarmWins
    if type(stored) == "table" then stored = stored.value end
    if type(stored) == "boolean" then return stored end
    return nil
end

local function readAutoFarmPreference()
    local player = game:GetService("Players").LocalPlayer
    local live = player and player:GetAttribute("BeyyHub_AutoFarmWins_Live_v103")
    if type(live) == "boolean" then return live end
    local teleported = readTeleportAFK()
    if teleported ~= nil then return teleported end
    local stored = configAutoFarmValue(__beyyActiveConfigName())
    if stored ~= nil then return stored end
    local current = safeRead(afkPreferencePath)
    if current == "true" then return true end
    if current == "false" then return false end
    local legacy = safeRead(afkLegacyPath)
    if legacy == "true" then return true end
    if legacy == "false" then return false end
    return nil
end

local function saveAutoFarmPreference(value)
    if type(value) ~= "boolean" then return end
    local player = game:GetService("Players").LocalPlayer
    if player then player:SetAttribute("BeyyHub_AutoFarmWins_Live_v103", value) end
    writeTeleportAFK(value)
    local a = safeWrite(afkPreferencePath, tostring(value))
    local b = safeWrite(afkLegacyPath, tostring(value))
    if not (a or b) then warn("[BeyyHub] Could not save Auto Farm Wins across rounds") end
end

local hayPreference=(function()
    local key="BeyyHub_AutoFarmHay_v1"
    local path=CACHE_FOLDER.."/autofarmhay_preference.txt"
    return {
        read=function()
            local ok,value=pcall(function() return TeleportService:GetTeleportSetting(key) end)
            if ok and type(value)=="boolean" then return value end
            return safeRead(path)=="true"
        end,
        save=function(value)
            if type(value)~="boolean" then return end
            pcall(function() TeleportService:SetTeleportSetting(key,value) end)
            safeWrite(path,tostring(value))
        end
    }
end)()

if _G.__BEYY_HUB_LOADED then
    pcall(function()
        if type(_G.__BEYY_HUB_CLEANUP) == "function" then _G.__BEYY_HUB_CLEANUP() end
    end)
    task.wait(0.5)
end
_G.__BEYY_HUB_LOADED = true

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


local sharedAFKAtChapterEntry = readAutoFarmPreference()
local sharedHayAtChapterEntry = hayPreference.read()
if sharedHayAtChapterEntry then sharedAFKAtChapterEntry=false end
local restoringStartupAutoFarm = true
if not game:IsLoaded() then
    local t = os.clock()
    game.Loaded:Wait()
    print(("[BeyyHub Startup] Chapter1 waited %.2fs for Roblox game readiness"):format(os.clock() - t))
end
local NeedleHaystack = ReplicatedStorage:FindFirstChild("NeedleHaystack")
if not NeedleHaystack then
    print("[BeyyHub] Waiting for Chapter 1 replication before starting AFK farm...")
    NeedleHaystack = ReplicatedStorage:WaitForChild("NeedleHaystack", 30)
end
local IN_GAME = (NeedleHaystack ~= nil)
if not IN_GAME then
    warn("[BeyyHub] Chapter 1 replication timed out; retry the loader after the game loads.")
    return
end
print("[BeyyHub] IN_GAME = ".. tostring(IN_GAME))

local State = {}
local Registry = {}
-- Wake the Chapter 1 cash-upgrade worker when an Upgrades-tab toggle changes.
local notifyNormalUpgradesChanged
local Unloaded = false
local cutsceneBypassActive = false

_G.__BEYY_HUB_CLEANUP = function()
    print("[BeyyHub] Cleanup requested by new session")
    Unloaded = true
end

local function defaultState()
    return {
        AutoPickHay = false, AutoCollectDroppedHay = false, AutoCollectGems = false,
        CollectInterval = 0.5,
        AutoSellHay = false, SellThreshold = 25, SellOnlyIfFull = false,
        AutoUseTNT = false, AutoUsePitchfork = false, AutoDeployDrone = false,
        TntLightCooldown = 0, TntThrowDelay = 0.5,
        AutoUseVacuum = false, AutoFarmVacuum = true, VacuumHotbarSlot = 5,
        ToolInterval = 0.5,
        AutoFindNeedle = false, AutoPickupNeedle = false, AutoHandInNeedle = false,
        NeedleInterval = 1.0,
        AutoBuyTools = false, BuyToolsList = { "Pitchfork" }, BuyInterval = 1.0,
        UpgBagSize = false, UpgExtraTake = false, UpgGemValue = false, UpgHayValue = false,
        PermInterval = 0.5,
        UpgCapacity = false, UpgHandSpeed = false, UpgHandGrab = false, UpgHandHold = false,
        UpgTntLuck = false, UpgTntCooldown = false, UpgTntPower = false,
        UpgPitchCooldown = false, UpgPitchHold = false, UpgPitchSweep = false,
        UpgDroneSpeed = false, UpgDroneGrab = false, UpgDroneCapacity = false,
        UpgVacPower = false, UpgVacCooling = false, UpgVacRuntime = true,
        ArcadeFarm = false,
        ClassRoller = false,
        ClassTarget = "The Chosen One",
        ClassRollInterval = 1.1,
        AutoFarmWins = false, AutoFarmHay = false,
        HayFarmCleared = false, HayFarmTargetReady = false,
    }
end

State = defaultState()

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getTeleportCircles()
    local teleporter = Workspace:FindFirstChild("Teleporter")
    if not teleporter then return {} end
    local hrp = getHRP()
    if not hrp then return {} end
    local circles = {}
    for _, obj in ipairs(teleporter:GetChildren()) do
        if obj:IsA("BasePart") and obj.Name == "InnerCylinder" then
            table.insert(circles, { part = obj, dist = (obj.Position - hrp.Position).Magnitude })
        end
    end
    table.sort(circles, function(a, b) return a.dist < b.dist end)
    return circles
end

local function clickGuiObjectEarly(obj)
    if not obj or not obj:IsA("GuiObject") or not obj.Visible then return false end
    local absPos, absSize = obj.AbsolutePosition, obj.AbsoluteSize
    if absSize.X <= 0 or absSize.Y <= 0 then return false end
    local inset = GuiService:GetGuiInset()
    local cx = absPos.X + absSize.X / 2 + inset.X
    local cy = absPos.Y + absSize.Y / 2 + inset.Y
    pcall(function() VirtualInputManager:SendMouseMoveEvent(cx, cy, game) end)
    task.wait(0.02)
    pcall(function() VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0) end)
    task.wait(0.04)
    pcall(function() VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0) end)
    return true
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
local NativeUI = createNativeUI()

local Window = NativeUI:CreateWindow({
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
print("[BeyyHub] Window created")
print(("[BeyyHub Startup] Chapter1 window constructed after %.2fs in module"):format(
    os.clock() - __BEYY_BOOT_T0))
pcall(function() Window:SetToggleKey(Enum.KeyCode.RightControl) end)
pcall(function() Window:EditOpenButton({ Enabled = false }) end)

local function closeMenuOnStartup()
    if Unloaded then return false end
    if Window.Closed then return true end
    local ok, err = pcall(function() Window:Close() end)
    if not ok then
        warn("[BeyyHub] Startup close failed: " .. tostring(err))
        return false
    end
    print("[BeyyHub] Entire menu minimized immediately (RightControl to reopen)")
    return true
end

closeMenuOnStartup()
local menuCursorCleanup = function() Window:Destroy() end
local previousMenuCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    if menuCursorCleanup then pcall(menuCursorCleanup) end
    if previousMenuCleanup then pcall(previousMenuCleanup) end
end

local ConfigManager = Window.ConfigManager

local function Notify(title, content, duration, icon)
    pcall(function()
        NativeUI:Notify({ Title = title, Content = content, Duration = duration or 3, Icon = icon })
    end)
end

local function Header(tab, title)
    pcall(function() tab:Section({ Title = title }) end)
end

local function Info(tab, text)
    return tab:Paragraph({ Title = text })
end

local SAVE_WHITELIST = {
    AutoPickHay = true, AutoCollectDroppedHay = true, AutoCollectGems = true,
    CollectInterval = true,
    AutoSellHay = true, SellThreshold = true, SellOnlyIfFull = true,
    AutoUseTNT = true, AutoUsePitchfork = true, AutoDeployDrone = true,
    TntLightCooldown = true, TntThrowDelay = true,
    AutoUseVacuum = true, AutoFarmVacuum = true, VacuumHotbarSlot = true,
    ToolInterval = true,
    AutoFindNeedle = true, AutoPickupNeedle = true, AutoHandInNeedle = true,
    NeedleInterval = true,
    AutoBuyTools = true, BuyToolsList = true, BuyInterval = true,
    UpgBagSize = true, UpgExtraTake = true, UpgGemValue = true, UpgHayValue = true,
    PermInterval = true,
    UpgCapacity = true, UpgHandSpeed = true, UpgHandGrab = true, UpgHandHold = true,
    UpgTntLuck = true, UpgTntCooldown = true, UpgTntPower = true,
    UpgPitchCooldown = true, UpgPitchHold = true, UpgPitchSweep = true,
    UpgDroneSpeed = true, UpgDroneGrab = true, UpgDroneCapacity = true,
    UpgVacPower = true, UpgVacCooling = true, UpgVacRuntime = true,
    ClassRollInterval = true, AutoFarmWins = true, AutoFarmHay = true,
}

local function AddToggle(tab, key, title, default, desc, callback)
    State[key] = default and true or false
    local el = tab:Toggle({
        Title = title, Desc = desc, Value = State[key],
        Callback = function(v)
            State[key] = v
            if callback then pcall(callback, v) end
            if key:sub(1,3)=="Upg" and notifyNormalUpgradesChanged then
                notifyNormalUpgradesChanged()
            end
        end,
    })
    if SAVE_WHITELIST[key] then Registry[key] = el end
    return el
end

local function AddSlider(tab, key, title, min, max, default, step, desc)
    State[key] = default
    local el = tab:Slider({
        Title = title, Desc = desc, Step = step or 1,
        Value = { Min = min, Max = max, Default = default },
        Callback = function(v) State[key] = tonumber(v) or default end,
    })
    if SAVE_WHITELIST[key] then Registry[key] = el end
    return el
end

local GameConfig, UpgradeConfig
local BuyUpgrade, BuyShopItem, PickHay, PickDroppedHay, SellHay
local CollectGem, DeployDrone, PitchforkDig, TntAction, NeedleHandIn

if IN_GAME then
    GameConfig = require(NeedleHaystack:WaitForChild("Config"))
    UpgradeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("UpgradeConfig"))
    BuyUpgrade = NeedleHaystack:WaitForChild("BuyUpgrade")
    BuyShopItem = NeedleHaystack:WaitForChild("BuyShopItem")
    PickHay = NeedleHaystack:WaitForChild("PickHay")
    PickDroppedHay = NeedleHaystack:WaitForChild("PickDroppedHay")
    SellHay = NeedleHaystack:WaitForChild("SellHay")
    CollectGem = NeedleHaystack:WaitForChild("CollectGem")
    DeployDrone = NeedleHaystack:WaitForChild("DeployDrone")
    PitchforkDig = NeedleHaystack:WaitForChild("PitchforkDig")
    TntAction = NeedleHaystack:WaitForChild("TntAction")
    NeedleHandIn = NeedleHaystack:WaitForChild("NeedleHandIn")
end

local ArcadeFolder = ReplicatedStorage:FindFirstChild("Arcade")
local ArcadeReport = ArcadeFolder and ArcadeFolder:FindFirstChild("ArcadeReport")
local ArcadeSession = ArcadeFolder and ArcadeFolder:FindFirstChild("ArcadeSession")
local ArcadeMachine = Workspace:FindFirstChild("Arcade Machine")
local ArcadePrompt = ArcadeMachine and ArcadeMachine:FindFirstChild("PlayPrompt", true)

local ClassSystem = ReplicatedStorage:FindFirstChild("ClassSystem")
local RollClass = ClassSystem and ClassSystem:FindFirstChild("RollClass")

local HayFolder = Workspace:FindFirstChild("HaystackClient")
local DroppedFolder = Workspace:FindFirstChild("DroppedHay")
local GemsFolder = Workspace:FindFirstChild("GemsClient")

task.spawn(function()
    while not Unloaded do
        task.wait(5)
        if Unloaded then break end
        if not HayFolder or not HayFolder.Parent then HayFolder = Workspace:FindFirstChild("HaystackClient") end
        if not DroppedFolder or not DroppedFolder.Parent then DroppedFolder = Workspace:FindFirstChild("DroppedHay") end
        if not GemsFolder or not GemsFolder.Parent then GemsFolder = Workspace:FindFirstChild("GemsClient") end
    end
end)

local function getCash()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local cash = ls and ls:FindFirstChild("Cash")
    return cash and cash.Value or 0
end

local function getGems() return tonumber(LocalPlayer:GetAttribute("Gems")) or 0 end
local function getHayHeld() return tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0 end
local function getHayCapacity() return tonumber(LocalPlayer:GetAttribute("HayCapacity")) or 25 end
local function owns(attr) return LocalPlayer:GetAttribute(attr) == true end
local function isBagFull() return getHayHeld() >= getHayCapacity() end

local HayCache = { part = nil, id = nil, time = 0, ttl = 1.5 }

local function findHayById(hayId)
    if not hayId then return nil end
    local folder = HayFolder
    if not folder or not folder.Parent then HayFolder = Workspace:FindFirstChild("HaystackClient"); folder = HayFolder end
    if not folder then return nil end
    for _, inst in ipairs(folder:GetChildren()) do
        if inst:IsA("BasePart") and inst:GetAttribute("HayId") == hayId then return inst end
    end
    return nil
end

local function findClosestHayCached()
    local now=tick()
    local root=getHRP()
    if not root then return nil end
    local folder=HayFolder
    if not folder or not folder.Parent then folder=Workspace:FindFirstChild("HaystackClient");HayFolder=folder end
    if not folder then return nil end
    if HayCache.folder~=folder then HayCache.folder=folder;HayCache.part=nil;HayCache.time=0 end
    local part=HayCache.part
    if part and part.Parent==folder and part:GetAttribute("HayId")==HayCache.id
        and now-HayCache.time<HayCache.ttl and (part.Position-root.Position).Magnitude<30 then return part end
    if not part and HayCache.time>0 and now-HayCache.time<0.15 then return nil end
    local hovered=LocalPlayer:GetAttribute("HoveredHayId")
    local best,dist=nil,30
    for _,p in ipairs(folder:GetChildren()) do
        local id=p:IsA("BasePart") and p:GetAttribute("HayId")
        if type(id)=="number" then
            local distance=(p.Position-root.Position).Magnitude
            if distance<30 and id==hovered then best=p;break end
            if distance<dist then best=p;dist=distance end
        end
    end
    HayCache.part=best;HayCache.id=best and best:GetAttribute("HayId") or nil;HayCache.time=now
    return best
end

local function isPileHay(part)
    if not part or not part:IsA("BasePart") or part:GetAttribute("HayId") == nil then return false end
    if part:GetAttribute("IsHeld") == true or part:GetAttribute("Held") == true then return false end
    local character = LocalPlayer.Character
    local parent = part
    for _ = 1, 10 do
        if not parent then break end
        if character and parent == character then return false end
        if parent:IsA("Tool") or parent:IsA("Accessory") then return false end
        parent = parent.Parent
    end
    return true
end

-- The arithmetic mean of live hay parts shifts as uneven pieces stream in
-- or get collected. Use trimmed X/Z bounds as a stable map-space axis instead.
-- Limit the sample count for very large haystacks to avoid startup lag.
local function getHaystackCenter()
    local folder = HayFolder
    if not folder or not folder.Parent then HayFolder = Workspace:FindFirstChild("HaystackClient"); folder = HayFolder end
    if not folder then return nil, 0, 0 end
    local parts = folder:GetChildren()
    local step = math.max(1, math.ceil(#parts / 512))
    local xs, zs, ys = {}, {}, {}
    local lowest, highest = math.huge, -math.huge
    for i = 1, #parts, step do
        local part = parts[i]
        if isPileHay(part) then
            local p = part.Position
            xs[#xs+1], zs[#zs+1], ys[#ys+1] = p.X, p.Z, p.Y
            local half = part.Size.Y * 0.5
            lowest = math.min(lowest, p.Y-half)
            highest = math.max(highest, p.Y+half)
        end
    end
    local n = #xs
    if n == 0 then return nil, 0, 0 end
    table.sort(xs); table.sort(zs); table.sort(ys)
    local lo, hi = math.max(1, math.ceil(n*0.10)), math.min(n, math.ceil(n*0.90))
    local center = Vector3.new((xs[lo]+xs[hi])*0.5, ys[math.ceil(n*0.5)], (zs[lo]+zs[hi])*0.5)
    return center, n*step, highest-lowest
end

local function getGrabCandidates(centerPart, radiusHint)
    if not centerPart then return {} end
    local radius = radiusHint or tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
    if radius <= 0 then return {} end
    local out = {}
    local cp = centerPart.Position
    local folder = HayFolder
    if not folder or not folder.Parent then HayFolder = Workspace:FindFirstChild("HaystackClient"); folder = HayFolder end
    if not folder then return out end
    for _, inst in ipairs(folder:GetChildren()) do
        if inst ~= centerPart and inst:IsA("BasePart") and inst:GetAttribute("HayId") then
            if (inst.Position - cp).Magnitude <= radius + 1 then
                table.insert(out, inst:GetAttribute("HayId"))
                if #out >= 6 then break end
            end
        end
    end
    return out
end

local DroppedCache = { part = nil, time = 0, ttl = 1.5 }

local function findClosestDroppedCached()
    local now = tick()
    if DroppedCache.part and DroppedCache.part.Parent and (now - DroppedCache.time) < DroppedCache.ttl then return DroppedCache.part end
    local folder = DroppedFolder
    if not folder or not folder.Parent then DroppedFolder = Workspace:FindFirstChild("DroppedHay"); folder = DroppedFolder end
    if not folder then return nil end
    local hrp = getHRP()
    if not hrp then return nil end
    local best, bestDist = nil, 28
    for _, m in ipairs(folder:GetChildren()) do
        local part = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart")
        if part then
            local d = (part.Position - hrp.Position).Magnitude
            if d < bestDist then bestDist = d; best = part.Parent:IsA("BasePart") and part.Parent or m end
        end
    end
    DroppedCache.part = best; DroppedCache.time = now
    return best
end

local GemsCache = { part = nil, id = nil, time = 0, ttl = 1.5 }

local function findClosestGemCached()
    local now = tick()
    if GemsCache.part and GemsCache.part.Parent and (now - GemsCache.time) < GemsCache.ttl then return GemsCache.part, GemsCache.id end
    local root = GemsFolder
    if not root or not root.Parent then GemsFolder = Workspace:FindFirstChild("GemsClient"); root = GemsFolder end
    if not root then return nil, nil end
    local hrp = getHRP()
    if not hrp then return nil, nil end
    local best, bestDist, bestId = nil, 35, nil
    for _, mdl in ipairs(root:GetChildren()) do
        local p = mdl
        if mdl:IsA("Model") then p = mdl.PrimaryPart or mdl:FindFirstChildWhichIsA("BasePart") end
        if p and p:IsA("BasePart") then
            local gId = p:GetAttribute("GemId")
            if gId then
                local d = (p.Position - hrp.Position).Magnitude
                if d < bestDist then bestDist = d; best = p; bestId = gId end
            end
        end
    end
    GemsCache.part = best; GemsCache.id = bestId; GemsCache.time = now
    return best, bestId
end

local needlePickupActive = false
local autoUiMouseBusy = false

local introSkipPending = false
local function guiReallyVisible(obj)
    if not obj then return false end
    local node = obj
    while node do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        if node:IsA("PlayerGui") then return true end
        node = node.Parent
    end
    return false
end
local function roundEndingVisible()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ending = pg and pg:FindFirstChild("NeedleEndingUI")
    local results = ending and ending:FindFirstChild("ReturnToLobby")
    return guiReallyVisible(results)
end
local function findExposedNeedlePart()
    if not IN_GAME then return nil end
    local server = Workspace:FindFirstChild("NeedleObjectiveServer")
    local folder = server and server:FindFirstChild("Needle")
    if not folder then return nil end
    for _, part in ipairs(folder:GetDescendants()) do
        local hidden = part:IsA("BasePart") and part:GetAttribute("HIDDEN_WITHIN")
        if part:IsA("BasePart") and part:GetAttribute("IsNeedleObjective") == true
            and (hidden == nil or hidden == false) then return part end
    end
    return nil
end
local function needleHasPriority()
    if Unloaded or not IN_GAME then return false end
    if roundEndingVisible() then return false end
    if State.AutoFarmHay and not State.HayFarmCleared then return false end
    if needlePickupActive then return true end
    if LocalPlayer:GetAttribute("NeedleOwned") == true then
        return (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) or (State.AutoHandInNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared))
    end
    if not (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) then return false end
    return findExposedNeedlePart() ~= nil
end

local function trySell()
    if Unloaded or needleHasPriority() then return end
    pcall(function() SellHay:FireServer() end)
    task.spawn(function()
        local before = getHayHeld()
        task.wait(0.6)
        if not Unloaded and not needleHasPriority() and before > 0 and getHayHeld() == before then
            pcall(function() SellHay:FireServer() end)
        end
    end)
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
    -- Active Chapter 1 normal upgrades wait for replication events instead of
    -- sleeping through a confirmed purchase. Timeouts still preserve 0.05s
    -- polling when events are missing; other chapter workers retain Wait().
    function api.WaitResponsive(interval,key)
        if not alive then return end
        if key=="upgrades"or key=="upgrades-cash"then syncCash()end
        local token={Thread=coroutine.running(),Key=key}
        waiters[token]=true
        token.Timer=task.delay(interval,function()finish(token,false)end)
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
        {"UpgTntCooldown","TntCooldown"},{"UpgTntLuck","TntLuck"},
        {"UpgCapacity","Capacity"},{"UpgHandSpeed","Speed"},{"UpgHandGrab","Grab"},{"UpgHandHold","HandHold"},
        {"UpgPitchCooldown","PitchforkCooldown"},{"UpgPitchHold","PitchforkHold"},{"UpgPitchSweep","Pitchfork"},
        {"UpgDroneSpeed","DroneSpeed"},{"UpgDroneGrab","DroneGrab"},{"UpgDroneCapacity","DroneCapacity"},
        {"UpgTntPower","TntPower"},
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
                    if entry[2]=="TntPower" then
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
        if earlyTnt and cash>=earlyTnt.Cost then
            target=earlyTnt
        elseif power and cash>=power.Cost then
            target=power
        elseif vacuum and cash>=vacuum.Cost then
            target=vacuum
        else
            -- Keep priority among affordable tracks without blocking cheaper upgrades.
            for _,entry in ipairs(available) do if cash>=entry.Cost then target=entry;break end end
            if not target and lateTnt and cash>=lateTnt.Cost then target=lateTnt end
        end
        if not target then
            waitKey="upgrades-cash"
            local cheapest=earlyTnt or available[1] or lateTnt
            for _,entry in ipairs(available) do if entry.Cost<cheapest.Cost then cheapest=entry end end
            if lateTnt and lateTnt.Cost<cheapest.Cost then cheapest=lateTnt end
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



local function createVacuumUpgradePriority(state, getConfig, getCash, getLevel, send)
    local pending
    local lastConfirmedAt
    local function nextVacuum()
        local config=getConfig()
        local tracks=config and config.UPGRADE_TRACKS
        if not tracks then return nil end
        for _,entry in ipairs({{Flag="UpgVacPower",Name="VacuumPower"},{Flag="UpgVacCooling",Name="VacuumCooling"}}) do
            if state[entry.Flag] then
                local track=tracks[entry.Name]
                local level=getLevel(entry.Name)
                local nextLevel=track and track.Levels and track.Levels[level+1]
                local cost=nextLevel and tonumber(nextLevel.Cost or 0)
                if cost then cost=math.round(cost*(tonumber(LocalPlayer:GetAttribute("UpgradeCostMultiplier")) or 1)*100)/100 end
                if cost and cost>=0 and cost<math.huge then
                    return {Name=entry.Name,Level=level,Cost=cost}
                end
            end
        end
        return nil
    end
    local function awaiting()
        if pending then
            local currentLevel=getLevel(pending.Name)
            if currentLevel~=pending.Level or os.clock()>=pending.Until then
                if currentLevel>pending.Level and pending.Started then
                    local now=os.clock()
                    local gap=lastConfirmedAt and string.format(" interval=%.3fs",now-lastConfirmedAt) or ""
                    lastConfirmedAt=now
                    print(string.format("[BeyyHub Upgrade] Vacuum priority %s L%d->L%d confirmed after %.3fs%s",
                        pending.Name,pending.Level,currentLevel,now-pending.Started,gap))
                end
                pending=nil
            end
        end
        return pending~=nil
    end
    local priority={}
    function priority.Reserve()
        if awaiting() then return true end
        local target=nextVacuum()
        return target~=nil and (target.Name=="VacuumPower" or (tonumber(getCash()) or 0)>=target.Cost*0.75)
    end
    function priority.Purchase()
        if awaiting() then return false end
        local target=nextVacuum()
        if not target or (tonumber(getCash()) or 0)<target.Cost then return false end
        if send(target.Name) then
            pending={Name=target.Name,Level=target.Level,Started=os.clock(),Until=os.clock()+0.05}
            return true
        end
        return false
    end
    return priority
end

local upgradePurchaseAttempts = {}
local permanentPurchaseAttempts = {}
local upgradeAudit={cashRequests=0,permanentRequests=0,cashConfirmations=0,permanentConfirmations=0,cashRetries=0,permanentRetries=0,firstRequestLogged={}}
local lastUpgradeConfirmedAt
local function logUpgradeConfirmation(category,name,pending,level)
    local now=os.clock()
    local spacing=lastUpgradeConfirmedAt and string.format(" interval=%.3fs",now-lastUpgradeConfirmedAt) or ""
    lastUpgradeConfirmedAt=now
    local countKey=category=="Cash" and "cashConfirmations" or "permanentConfirmations"
    upgradeAudit[countKey]+=level-pending.level
    print(string.format("[BeyyHub Upgrade] %s %s L%d->L%d confirmed after %.3fs%s",
        category,name,pending.level,level,now-pending.time,spacing))
end
local function tryBuyTrack(trackName)
    if Unloaded or not IN_GAME or not GameConfig then return end
    local track = GameConfig.UPGRADE_TRACKS[trackName]
    if not track then return end
    local cur = tonumber(LocalPlayer:GetAttribute("HayUpgrade"..trackName)) or 1
    local previous=upgradePurchaseAttempts[trackName]
    if previous and cur~=previous.level then
        if cur>previous.level then logUpgradeConfirmation("Cash",trackName,previous,cur) end
        upgradePurchaseAttempts[trackName]=nil
    end
    if cur >= #track.Levels then return end
    local nxt = track.Levels[cur + 1]
    if not nxt then return end
    local price=(tonumber(nxt.Cost) or 0)*(tonumber(LocalPlayer:GetAttribute("UpgradeCostMultiplier")) or 1)
    if trackName:sub(1,9)=="Pitchfork" then price*=tonumber(LocalPlayer:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1 end
    if getCash() >= price then
        local now = os.clock()
        local pending = upgradePurchaseAttempts[trackName]
        if pending and pending.level == cur and now - pending.time < 0.05 then return end
        if pending and pending.level==cur then upgradeAudit.cashRetries+=1 end
        upgradePurchaseAttempts[trackName] = {level = cur, time = now}
        local ok = pcall(function() BuyUpgrade:FireServer(trackName) end)
        if ok then
            upgradeAudit.cashRequests+=1
            local key="Cash:"..trackName
            if not upgradeAudit.firstRequestLogged[key] then
                upgradeAudit.firstRequestLogged[key]=true
                print(string.format("[BeyyHub Upgrade] First Cash request %s L%d->L%d cost=%.2f cash=%.2f",
                    trackName,cur,cur+1,price,tonumber(getCash()) or 0))
            end
        else upgradePurchaseAttempts[trackName] = nil end
    end
end

local function tryBuyPermanent(id)
    if Unloaded or not IN_GAME or not UpgradeConfig then return end
    local u = UpgradeConfig.getUpgrade(id)
    if not u then return end
    local cur = tonumber(LocalPlayer:GetAttribute("Upgrade"..id)) or 0
    local previous=permanentPurchaseAttempts[id]
    if previous and cur~=previous.level then
        if cur>previous.level then logUpgradeConfirmation("Permanent",id,previous,cur) end
        permanentPurchaseAttempts[id]=nil
    end
    local max = UpgradeConfig:getMaxLevel(u)
    if cur >= max then return end
    local price = UpgradeConfig:getPrice(u, cur)
    if price and getGems() >= price then
        local now = os.clock()
        local pending = permanentPurchaseAttempts[id]
        if pending and pending.level == cur and now - pending.time < 0.25 then return end
        if pending and pending.level==cur then upgradeAudit.permanentRetries+=1 end
        permanentPurchaseAttempts[id] = {level = cur, time = now}
        local ok = pcall(function() BuyUpgrade:FireServer(id) end)
        if ok then
            upgradeAudit.permanentRequests+=1
            local key="Permanent:"..id
            if not upgradeAudit.firstRequestLogged[key] then
                upgradeAudit.firstRequestLogged[key]=true
                print(string.format("[BeyyHub Upgrade] First Permanent request %s L%d->L%d cost=%.2f gems=%.2f",
                    id,cur,cur+1,tonumber(price) or 0,getGems()))
            end
        else permanentPurchaseAttempts[id] = nil end
    end
end

task.spawn(function()
    local wasActive = false
    while not Unloaded do
        task.wait(0.05)
        if Unloaded then break end
        local active = needleHasPriority()
        if active ~= wasActive then
            wasActive = active
            if active then
                local reason = needlePickupActive and "pickup active" or
                    ((State.AutoHandInNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) and LocalPlayer:GetAttribute("NeedleOwned") == true and "hand-in pending" or "needle exposed")
                print("[Priority] NEEDLE FIRST: " .. reason .. "; AFK/UI clicks suspended")
            else
                print("[Priority] Needle phase ended; AFK farming resumed")
            end
        end
    end
end)

local vacuumSuctionActive = false
-- Standalone Wins releases any held vacuum mouse input before opening Replay.
-- The main vacuum worker installs the real release function below.
local releaseWinVacuumForReplay = function() end
local function farmLoopEnabled()
    return not Unloaded and not cutsceneBypassActive and not needleHasPriority() and not roundEndingVisible()
end

local function afkFarmModeActive()
    return State.AutoFarmWins == true and not cutsceneBypassActive
end
local function afkVacuumOrbitEnabled()
    return afkFarmModeActive() and State.AutoFarmVacuum == true
end
local function vacuumRequested()
    return State.AutoUseVacuum == true or afkVacuumOrbitEnabled()
        or (State.AutoFarmHay == true and not State.HayFarmCleared)
end

local AFK_CAMERA_BIND = "BeyyV103_00AFKCamera_" .. tostring(LocalPlayer.UserId)
local AFK_ORBIT_SPEED_DEG = 48.0
local AFK_ORBIT_BANDS = {
    { name = "base", radius = 22.0, standoff = 2.2, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5, heightOffset = 3.0 },
    { name = "base-transition", radius = 20.0, standoff = 2.1, characterInset = 1.5, cameraLift = 5.0, focusYOffset = 1.5, heightOffset = 2.0 },
    { name = "lower-middle", radius = 18.0, standoff = 2.0, characterInset = 1.5, cameraLift = 5.0, focusYOffset = -0.1 },
    { name = "middle-transition", radius = 16.0, standoff = 1.95, characterInset = 1.5, cameraLift = 5.1, focusYOffset = -0.8 },
    { name = "upper-middle", radius = 14.0, standoff = 1.9, characterInset = 1.5, cameraLift = 5.2, focusYOffset = -1.5 },
    { name = "upper-transition", radius = 11.0, standoff = 1.8, characterInset = 1.0, cameraLift = 5.6, focusYOffset = -0.75 },
    { name = "peak", radius = 8.0, standoff = 1.7, cameraLift = 6.0, focusYOffset = 0.0 },
    { name = "inner-peak", radius = 5.0, standoff = 1.6, cameraLift = 6.0, focusYOffset = 0.2 },
}
local afkOrbitLapProgress = 0
local afkOrbitLastAdvanceAt = os.clock()
local afkOrbitAngle = 0
local afkOrbitLap = 0
local afkOrbitRadius = 16

local afkSweepRadius = nil
local afkSweepSurfaceY = nil
local afkSweepFocusOffsetY = nil
local afkSweepCameraLift = nil
local afkBandSurfaceHeights = nil
local afkCameraPileTopY = nil
local afkVacuumTargetReady = false
local function afkCurrentBand()
    return AFK_ORBIT_BANDS[(afkOrbitLap % #AFK_ORBIT_BANDS) + 1]
end
local function afkCurrentRingRadius()
    return afkCurrentBand().radius
end
local function afkCurrentRingName()
    return afkCurrentBand().name
end
local afkCameraBound = false
local afkCameraSuspended = false
local afkCameraAnchor = nil
-- The Farmhouse physical pile stays at the same map X/Z between Replay rounds.
-- Never shift this axis to the centroid of surviving/recently streamed hay.
local afkPhysicalPileAnchor = nil
-- Orbit X/Z is calibrated once from map geometry, never from depleted hay.
local function afkPhysicalCenter()
    if GameConfig and typeof(GameConfig.PILE_CENTER)=="Vector3" then
        return GameConfig.PILE_CENTER, 1000000, "game-config"
    end
    for _,candidate in ipairs({
        {name="HayUnderMatClient",minimum=10000,isHay=false},
        {name="HaystackClient",minimum=12000,isHay=true},
    }) do
        local folder=Workspace:FindFirstChild(candidate.name)
        local children=folder and folder:GetChildren()
        if children and #children>=candidate.minimum then
            local xs,zs={},{}
            for _,part in ipairs(children) do
                if part:IsA("BasePart") and (not candidate.isHay or isPileHay(part)) then
                    local pos=part.Position
                    xs[#xs+1]=pos.X
                    zs[#zs+1]=pos.Z
                end
            end
            if #xs>=candidate.minimum then
                table.sort(xs)
                table.sort(zs)
                local lo=math.max(1,math.ceil(#xs*0.01))
                local hi=math.min(#xs,math.floor(#xs*0.99))
                local x=(xs[lo]+xs[hi])*0.5
                local z=(zs[lo]+zs[hi])*0.5
                return Vector3.new(x,0,z),#xs,candidate.name
            end
        end
    end
    return nil,0,"waiting-for-full-pile"
end

local afkLastOrbitDiagnosticAt = -math.huge
-- Replay can dismiss results while the next haystack is still replicating.
local afkReplayNeedsAnchor = false
local afkReplayResetAt = os.clock()
local afkReplayNextSampleAt = 0
local afkReplayCandidateCenter = nil
local afkReplayCandidateSource = nil
local afkReplayCandidateCount = 0
local afkReplayCandidateChecks = 0
local afkReplayCalibrationUntil = 0
local afkReplayLastCorrectAt = 0
local afkReplayAnchorCount = 0
local afkReplayAnchorSpan = 0
local afkPreviousCamera = nil
local afkPreviousType = nil
local afkPreviousSubject = nil
local afkPreviousCFrame = nil

local function releaseAfkCamera()
    if afkCameraBound then
        pcall(function() RunService:UnbindFromRenderStep(AFK_CAMERA_BIND) end)
        afkCameraBound = false
    end
    afkCameraSuspended = false
    if afkPreviousCamera and afkPreviousCamera.Parent then
        pcall(function()
            afkPreviousCamera.CameraType = afkPreviousType or Enum.CameraType.Custom
            if afkPreviousSubject and afkPreviousSubject.Parent then
                afkPreviousCamera.CameraSubject = afkPreviousSubject
            else
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then afkPreviousCamera.CameraSubject = hum end
            end
            if afkPreviousType == Enum.CameraType.Scriptable and afkPreviousCFrame then
                afkPreviousCamera.CFrame = afkPreviousCFrame
            end
        end)
    end
    afkPreviousCamera = nil
    afkPreviousType = nil
    afkPreviousSubject = nil
    afkPreviousCFrame = nil
    afkCameraAnchor = nil
    afkReplayCalibrationUntil = 0
    afkReplayAnchorCount = 0
    afkReplayAnchorSpan = 0
    afkSweepRadius = nil
    afkSweepSurfaceY = nil
    afkSweepFocusOffsetY = nil
    afkSweepCameraLift = nil
    afkBandSurfaceHeights = nil
    afkCameraPileTopY = nil
end

local function measureAfkBandSurfaces(center)
    -- Rendered hay can initially contain only the upper pieces, and shrinks as it is cleared.
    -- Use the chapter's configured pile bounds so fixed routes cannot float upward.
    if GameConfig and typeof(GameConfig.PILE_CENTER)=="Vector3"
        and tonumber(GameConfig.PILE_HEIGHT) and tonumber(GameConfig.PILE_HEIGHT)>0 then
        local floorY=GameConfig.PILE_CENTER.Y+(tonumber(GameConfig.PILE_BASE_Y)or 0)
        local height=tonumber(GameConfig.PILE_HEIGHT)
        local fractions = {0.12, 0.24, 0.36, 0.495, 0.63, 0.755, 0.88, 0.97}
        local surfaces,labels={},{}
        for i,band in ipairs(AFK_ORBIT_BANDS)do
            surfaces[i]=floorY+height*fractions[i]+(band.heightOffset or 0)
            labels[i]=string.format("%s=%.1f",band.name,surfaces[i])
        end
        surfaces[1]=surfaces[2]
        labels[1]=string.format("%s=%.1f",AFK_ORBIT_BANDS[1].name,surfaces[1])
        print("[AFK Orbit] Configured fixed level heights: "..table.concat(labels," "))
        return surfaces,floorY+height
    end
    local folder = HayFolder
    if not folder or not folder.Parent then
        folder = Workspace:FindFirstChild("HaystackClient")
        HayFolder = folder
    end
    local radialTops = {}
    for i = 1, #AFK_ORBIT_BANDS do radialTops[i] = {} end
    local floorY, highestY = math.huge, -math.huge
    if folder then
        for _, part in ipairs(folder:GetChildren()) do
            if isPileHay(part) then
                local p = part.Position
                local topY = p.Y + part.Size.Y * 0.5
                floorY = math.min(floorY, p.Y - part.Size.Y * 0.5)
                highestY = math.max(highestY, topY)
                local dx, dz = p.X - center.X, p.Z - center.Z
                local r = math.sqrt(dx * dx + dz * dz)
                for i, band in ipairs(AFK_ORBIT_BANDS) do
                    if math.abs(r - band.radius) <= 5.5 then
                        local values = radialTops[i]
                        values[#values + 1] = topY
                    end
                end
            end
        end
    end
    if floorY == math.huge then floorY = center.Y - 4 end
    if highestY == -math.huge then highestY = center.Y + 8 end
    local fractions = {0.12, 0.24, 0.36, 0.495, 0.63, 0.755, 0.88, 0.97}
    local surfaces = {}
    for i, samples in ipairs(radialTops) do
        local baseline = floorY + (highestY - floorY) * fractions[i]
        if #samples >= 6 then
            table.sort(samples)
            local observed = samples[math.max(1, math.ceil(#samples * 0.90))]

            surfaces[i] = math.clamp(observed, floorY, highestY)
        else
            surfaces[i] = baseline
        end
        if i > 1 then surfaces[i] = math.max(surfaces[i], surfaces[i - 1]) end
    end
    -- Apply intentional lower rings after the ascending surface calculation.
    for i, band in ipairs(AFK_ORBIT_BANDS) do surfaces[i] += band.heightOffset or 0 end
    surfaces[1]=surfaces[2]
    local heightLabels = {}
    for i, band in ipairs(AFK_ORBIT_BANDS) do heightLabels[i] = string.format("%s=%.1f", band.name, surfaces[i]) end
    print("[AFK Orbit] Fixed level heights: " .. table.concat(heightLabels, " "))
    return surfaces, highestY
end

local function estimateAfkOrbitRadius(center)
    local folder = HayFolder
    if not folder or not folder.Parent then
        folder = Workspace:FindFirstChild("HaystackClient")
        HayFolder = folder
    end
    if not folder then return 16 end
    local radii = {}
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part:GetAttribute("HayId") ~= nil then
            local dx, dz = part.Position.X - center.X, part.Position.Z - center.Z
            radii[#radii + 1] = math.sqrt(dx * dx + dz * dz)
        end
    end
    if #radii == 0 then return 16 end
    table.sort(radii)
    local outer = radii[math.max(1, math.ceil(#radii * 0.90))]
    return math.clamp(outer * 0.95, 9, 55)
end

local needleCameraMode = false
local function enterNeedleCamera()
    if needleCameraMode then return end
    needleCameraMode = true

    releaseAfkCamera()
    local camera = Workspace.CurrentCamera
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if camera then
        pcall(function()
            camera.CameraType = Enum.CameraType.Custom
            if humanoid then camera.CameraSubject = humanoid end
        end)
    end
    print("[Camera] Needle exposed; AFK overhead view OFF (normal camera)")
end
local function afkMayAdvanceOrbit()
    if not afkVacuumOrbitEnabled() then return true end
    local root=getHRP()
    if not root or not root.Parent or not afkCameraAnchor or not afkSweepRadius or not afkSweepSurfaceY then return false end
    local band=afkCurrentBand()
    local radius=afkSweepRadius-(band.characterInset or 0)
    local wanted=Vector3.new(afkCameraAnchor.X+math.cos(afkOrbitAngle)*radius,
        afkSweepSurfaceY+3.25,afkCameraAnchor.Z+math.sin(afkOrbitAngle)*radius)
    return (root.Position-wanted).Magnitude<=3
end
local function afkResetSweepToBase()
    local base=AFK_ORBIT_BANDS[1]
    afkSweepRadius=base.radius+base.standoff
    afkSweepSurfaceY=(afkBandSurfaceHeights and afkBandSurfaceHeights[1])
        or afkCameraPileTopY or afkCameraAnchor.Y
    afkSweepFocusOffsetY=base.focusYOffset
    afkSweepCameraLift=base.cameraLift
    afkVacuumTargetReady=false
end
local function bindAfkCameraView()
    local ok, err = pcall(function()
        RunService:BindToRenderStep(AFK_CAMERA_BIND, Enum.RenderPriority.Last.Value + 10, function(dt)
            if Unloaded or not IN_GAME or not afkFarmModeActive() or needleHasPriority() or roundEndingVisible() then return end
            local current = Workspace.CurrentCamera
            if not current or not afkCameraAnchor then return end
            local delta = math.max(0, math.min(dt, 0.25))
            local now=os.clock()
            local advance=afkMayAdvanceOrbit()
            if advance then
                afkOrbitLastAdvanceAt=now
            elseif afkVacuumOrbitEnabled()
                and afkOrbitLap%#AFK_ORBIT_BANDS >= #AFK_ORBIT_BANDS-2
                and now-afkOrbitLastAdvanceAt>=6 then
                afkOrbitLap+=#AFK_ORBIT_BANDS-(afkOrbitLap%#AFK_ORBIT_BANDS)
                afkOrbitLapProgress=0
                afkOrbitLastAdvanceAt=now
                afkResetSweepToBase()
                warn("[AFK Orbit] Upper route stalled for 6s; returning to base")
            end
            local orbitSpeed=afkCurrentBand()==AFK_ORBIT_BANDS[#AFK_ORBIT_BANDS]
                and AFK_ORBIT_SPEED_DEG*2 or AFK_ORBIT_SPEED_DEG
            local travel=math.rad(orbitSpeed)*(advance and delta or 0)
            local progress=afkOrbitLapProgress+travel
            local nextAngle=afkOrbitAngle+travel
            if progress>=2*math.pi then
                afkOrbitLap+=1
                if afkOrbitLap%#AFK_ORBIT_BANDS==0 then
                    afkResetSweepToBase()
                end
                local nextBand=afkCurrentBand()
                print(string.format("[AFK Orbit] Lap %d complete; next sceneton route %s (%.1f studs)",
                    afkOrbitLap,nextBand.name,nextBand.radius))
            end
            afkOrbitLapProgress=progress%(2*math.pi)
            afkOrbitAngle=nextAngle%(2*math.pi)
            if os.clock() - afkLastOrbitDiagnosticAt >= 30 then
                afkLastOrbitDiagnosticAt = os.clock()
                local root = getHRP()
                local playerRadius = root and Vector3.new(
                    root.Position.X-afkCameraAnchor.X, 0, root.Position.Z-afkCameraAnchor.Z).Magnitude or -1
                print(string.format("[AFK Orbit] Axis=(%.1f,%.1f) | band=%s | player radius=%.1f | camera bound=%s",
                    afkCameraAnchor.X, afkCameraAnchor.Z, afkCurrentRingName(),
                    playerRadius, tostring(afkCameraBound)))
            end
            local bandIndex = (afkOrbitLap % #AFK_ORBIT_BANDS) + 1
            local band = AFK_ORBIT_BANDS[bandIndex]
            -- The camera must keep the same four-band haystack sweep whenever
            -- Auto Farm Wins is enabled. Previously AutoFarmVacuum=false
            -- silently switched to a high overhead orbit; restoring saved
            -- configs could therefore make camera rotation look broken.
            -- Vacuum suction/character-follow remain independently gated by
            -- afkVacuumOrbitEnabled() in their own workers.
            local alpha = 1 - math.exp(-3.0 * delta)
            local wantedRadius = band.radius + band.standoff
            local wantedSurface = (afkBandSurfaceHeights and afkBandSurfaceHeights[bandIndex])
                or afkCameraPileTopY or afkCameraAnchor.Y
            afkSweepRadius = (afkSweepRadius or wantedRadius) + (wantedRadius - (afkSweepRadius or wantedRadius)) * alpha
            afkSweepSurfaceY = (afkSweepSurfaceY or wantedSurface) + (wantedSurface - (afkSweepSurfaceY or wantedSurface)) * alpha
            local wantedFocusOffsetY = band.focusYOffset
            afkSweepFocusOffsetY = (afkSweepFocusOffsetY or wantedFocusOffsetY)
                + (wantedFocusOffsetY - (afkSweepFocusOffsetY or wantedFocusOffsetY)) * alpha
            local radial = Vector3.new(math.cos(afkOrbitAngle), 0, math.sin(afkOrbitAngle))
            local camAt = Vector3.new(
                afkCameraAnchor.X + radial.X * (afkSweepRadius + 0.6),
                afkSweepSurfaceY + band.cameraLift,
                afkCameraAnchor.Z + radial.Z * (afkSweepRadius + 0.6)
            )
            local focus = Vector3.new(
                afkCameraAnchor.X + radial.X * math.max(0, afkSweepRadius - 5),
                afkSweepSurfaceY + afkSweepFocusOffsetY,
                afkCameraAnchor.Z + radial.Z * math.max(0, afkSweepRadius - 5)
            )
            current.CameraType = Enum.CameraType.Scriptable
            current.CFrame = CFrame.lookAt(camAt, focus, Vector3.yAxis)
        end)
    end)
    if ok then
        afkCameraBound = true
        afkCameraSuspended = false
        return true
    end
    warn("[Camera] Failed to bind stable 4-band orbit: " .. tostring(err))
    releaseAfkCamera()
    return false
end
local function startAfkCamera()
    if afkCameraBound or not IN_GAME or not afkFarmModeActive() then return end
    if afkCameraSuspended and afkCameraAnchor then
        bindAfkCameraView()
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local center, count, span
    if afkReplayNeedsAnchor or not afkPhysicalPileAnchor then
        local now = os.clock()
        if now < afkReplayNextSampleAt then return end
        afkReplayNextSampleAt = now + 0.45
        local source
        if afkPhysicalPileAnchor then
            -- Same physical map across Replay: reuse the verified center.
            local live, seen, height = getHaystackCenter()
            count, span = seen, height
            if live and seen >= 25 then
                center = Vector3.new(afkPhysicalPileAnchor.X, live.Y, afkPhysicalPileAnchor.Z)
            end
            source = "pinned-replay"
        else
            local physical, seen, kind = afkPhysicalCenter()
            count, source = seen, kind
            if physical then
                local live, _, liveSpan = getHaystackCenter()
                span = liveSpan or 0
                center = Vector3.new(physical.X, live and live.Y or physical.Y, physical.Z)
            end
        end
        if not center or count < 25 then
            afkReplayCandidateCenter, afkReplayCandidateSource, afkReplayCandidateChecks = nil, nil, 0
            return
        end
        if afkReplayCandidateCenter then
            local last = afkReplayCandidateCenter
            local shift = (Vector3.new(center.X-last.X, 0, center.Z-last.Z)).Magnitude
            local countChange = math.abs(count-afkReplayCandidateCount)
                / math.max(1, afkReplayCandidateCount)
            afkReplayCandidateChecks = (source == afkReplayCandidateSource
                and shift <= 0.75 and countChange <= 0.30)
                and (afkReplayCandidateChecks+1) or 1
        else
            afkReplayCandidateChecks = 1
        end
        afkReplayCandidateCenter, afkReplayCandidateCount, afkReplayCandidateSource = center, count, source
        -- Wait for two similar population/center snapshots, allowing a
        -- valid but slowly streaming pile after four seconds.
        if afkReplayCandidateChecks < 2 then return end
        afkReplayNeedsAnchor = false
        afkReplayCalibrationUntil = now + 16
        afkReplayLastCorrectAt = now
        afkReplayAnchorCount, afkReplayAnchorSpan = count, span
        print(string.format("[AFK Orbit] Physical center confirmed: source=%s parts=%s center=(%.2f, %.2f) samples=%d",
            tostring(source), tostring(count), center.X, center.Z, afkReplayCandidateChecks))
    else
        center, count, span = getHaystackCenter()
    end
    if not center then return end
    if not afkPhysicalPileAnchor then
        afkPhysicalPileAnchor = center
        print(string.format("[AFK Orbit] Physical pile axis captured: X=%.2f Z=%.2f (hay=%d, Y-span=%.2f)",
            center.X, center.Z, count or 0, span or 0))
    else
        local axis = afkPhysicalPileAnchor
        local offset = Vector3.new(center.X-axis.X, 0, center.Z-axis.Z).Magnitude
        center = Vector3.new(axis.X, center.Y, axis.Z)
        print(string.format("[AFK Orbit] Fixed replay axis reused: X=%.2f Z=%.2f | ignored live-hay shift %.2f studs (hay=%d)",
            axis.X, axis.Z, offset, count or 0))
    end
    afkCameraAnchor = center
    afkOrbitRadius = estimateAfkOrbitRadius(center)
    afkBandSurfaceHeights, afkCameraPileTopY = measureAfkBandSurfaces(center)
    afkSweepRadius = afkCurrentBand().radius + afkCurrentBand().standoff
    afkSweepSurfaceY = afkBandSurfaceHeights[(afkOrbitLap % #AFK_ORBIT_BANDS) + 1]
    afkSweepFocusOffsetY = afkCurrentBand().focusYOffset
    afkSweepCameraLift = afkCurrentBand().cameraLift
    afkOrbitLastAdvanceAt = os.clock()
    afkPreviousCamera = cam
    afkPreviousType = cam.CameraType
    afkPreviousSubject = cam.CameraSubject
    afkPreviousCFrame = cam.CFrame
    pcall(function() RunService:UnbindFromRenderStep(AFK_CAMERA_BIND) end)
    if bindAfkCameraView() then
        print(string.format("[Camera] Sceneton 8-route AFK sweep started: %.1f deg/s, %ds full sweep, last route 2x speed | AFK vacuum=%s",
            AFK_ORBIT_SPEED_DEG, math.floor(360 / AFK_ORBIT_SPEED_DEG * (#AFK_ORBIT_BANDS - 0.5) + 0.5),
            tostring(State.AutoFarmVacuum == true)))
    end
end

local previousHubCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    if previousHubCleanup then pcall(previousHubCleanup) end
    releaseAfkCamera()
end

local function doUnload()
    if _G.__BEYY_HUB_CLEANUP then pcall(_G.__BEYY_HUB_CLEANUP) end
    Unloaded = true
    pcall(function() if Window then Window:Destroy() end end)
end

task.spawn(function()
    while not Unloaded do
        task.wait(0.05)
        if Unloaded then break end
        if IN_GAME and afkFarmModeActive() then
            if needleHasPriority() then
                if not needleCameraMode then enterNeedleCamera() end
            else
                if needleCameraMode then
                    needleCameraMode = false
                    print("[Camera] Needle phase finished; AFK overhead view restored")
                end
                if not afkCameraBound then startAfkCamera() end
            end
        else
            needleCameraMode = false
            if afkCameraBound or afkCameraSuspended then releaseAfkCamera() end
        end
    end
    releaseAfkCamera()
end)

local afkPlayerAnchor = nil
local afkLastPositionAttempt = 0
local afkPositionConfirmed = false
local afkPositionCharacter = nil
local function afkHorizontalDistance(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end
local function afkLandingPosition(center)
    local highestTop = nil
    local folder = HayFolder
    if folder and folder.Parent then
        for _, part in ipairs(folder:GetChildren()) do
            if part:IsA("BasePart") and part:GetAttribute("HayId") ~= nil
                and afkHorizontalDistance(part.Position, center) <= 8 then
                local top = part.Position.Y + part.Size.Y * 0.5
                if not highestTop or top > highestTop then highestTop = top end
            end
        end
    end
    return Vector3.new(center.X, (highestTop or center.Y) + 3.0, center.Z)
end
task.spawn(function()
    while not Unloaded do
        task.wait(0.45)
        if Unloaded then break end
        if not IN_GAME or not afkFarmModeActive() then
            afkPlayerAnchor = nil
            afkPositionConfirmed = false
            afkPositionCharacter = nil
        elseif not afkVacuumOrbitEnabled() and not needleHasPriority() and not roundEndingVisible() then
            local char = LocalPlayer.Character
            local root = getHRP()
            if char and root then
                if afkPositionCharacter ~= char then
                    afkPositionCharacter = char
                    afkPositionConfirmed = false
                    afkPlayerAnchor = nil
                end
                afkPlayerAnchor = afkPlayerAnchor or afkCameraAnchor or getHaystackCenter()
                local center = afkPlayerAnchor
                if center then
                    local distance = afkHorizontalDistance(root.Position, center)
                    if not afkPositionConfirmed or distance > 13 then
                        if os.clock() - afkLastPositionAttempt >= 1.0 then
                            afkLastPositionAttempt = os.clock()
                            local destination = afkLandingPosition(center)
                            if distance <= 6 and math.abs(root.Position.Y - destination.Y) < 7 then
                                afkPositionConfirmed = true
                                print("[Hay] AFK character already on haypile")
                            else
                                local offset = root.CFrame:ToObjectSpace(char:GetPivot())
                                local forward = root.CFrame.LookVector
                                local horizontal = Vector3.new(forward.X, 0, forward.Z)
                                if horizontal.Magnitude < 0.1 then horizontal = Vector3.new(0, 0, -1) end
                                local wantedRoot = CFrame.lookAt(destination, destination + horizontal, Vector3.yAxis)
                                local succeeded, err = pcall(function()
                                    if needleHasPriority() then return end
                                    char:PivotTo(wantedRoot * offset)
                                    root.AssemblyLinearVelocity = Vector3.zero
                                    root.AssemblyAngularVelocity = Vector3.zero
                                end)
                                if succeeded and not needleHasPriority() then
                                    task.wait(0.12)
                                    if not needleHasPriority() and char.Parent and root.Parent and afkHorizontalDistance(root.Position, center) <= 6 then
                                        afkPositionConfirmed = true
                                        print(string.format("[Hay] AFK player moved onto pile (distance %.1f studs)", afkHorizontalDistance(root.Position, center)))
                                    else
                                        afkPositionConfirmed = false
                                        warn("[Hay] AFK player teleport did not stick; retrying")
                                    end
                                elseif not needleHasPriority() then
                                    afkPositionConfirmed = false
                                    warn("[Hay] AFK character teleport failed: " .. tostring(err))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    local scanBusy = false
    local lastHayReadinessScan = -math.huge
    local scanSamples, scanTotalMs, scanMaxMs, scannedHayParts = 0, 0, 0, 0
    local lastPerfReport = os.clock()
    while not Unloaded do
        task.wait(0.08)
        if Unloaded then break end
        if not IN_GAME or not afkVacuumOrbitEnabled() or needleHasPriority() or roundEndingVisible() then
            afkVacuumTargetReady = false
            lastHayReadinessScan = -math.huge
        else
            local character = LocalPlayer.Character
            local root = getHRP()
            local anchor = afkCameraAnchor
            local radius = afkSweepRadius
            if radius then radius -= afkCurrentBand().characterInset or 0 end
            local surface = afkSweepSurfaceY
            if character and root and anchor and radius and surface then
                local radial = Vector3.new(math.cos(afkOrbitAngle), 0, math.sin(afkOrbitAngle))
                local wanted = Vector3.new(
                    anchor.X + radial.X * radius,
                    surface + 3.25,
                    anchor.Z + radial.Z * radius
                )

                if (root.Position - wanted).Magnitude > 0.4 then
                    local charToRoot = root.CFrame:ToObjectSpace(character:GetPivot())
                    local facing = Vector3.new(anchor.X, wanted.Y - 1.25, anchor.Z)
                    local goalRoot = CFrame.lookAt(wanted, facing, Vector3.yAxis)
                    pcall(function()
                        if not Unloaded and not needleHasPriority() and not roundEndingVisible()
                            and character.Parent and root.Parent then
                            character:PivotTo(goalRoot * charToRoot)
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                        end
                    end)
                end

                local now = os.clock()
                if not scanBusy and now-lastHayReadinessScan >= 0.45 then
                    lastHayReadinessScan=now
                    scanBusy=true
                    local band=afkCurrentBand()
                    local angle=afkOrbitAngle
                    task.spawn(function()
                        local started=os.clock()
                        local slice=started
                        local cpuMs,checked,nearby=0,0,false
                        local ok,err=pcall(function()
                            local folder=Workspace:FindFirstChild("HaystackClient")
                            if not folder then return end
                            local probe=anchor+Vector3.new(math.cos(angle),0,math.sin(angle))*band.radius
                            for _,hay in ipairs(folder:GetChildren()) do
                                checked+=1
                                if hay.Parent==folder and hay:IsA("BasePart") then
                                    local position=hay.Position
                                    local dx,dz=position.X-probe.X,position.Z-probe.Z
                                    if dx*dx+dz*dz<=144 and math.abs(position.Y-surface)<=12
                                        and isPileHay(hay) then
                                        nearby=true
                                        break
                                    end
                                end
                                if checked%64==0 and os.clock()-slice>=0.001 then
                                    cpuMs+=(os.clock()-slice)*1000
                                    task.wait()
                                    slice=os.clock()
                                    if Unloaded or not IN_GAME or not afkVacuumOrbitEnabled()
                                        or needleHasPriority() or roundEndingVisible()
                                        or afkCameraAnchor~=anchor or afkCurrentBand()~=band then return end
                                end
                            end
                            if Unloaded or not afkVacuumOrbitEnabled() or needleHasPriority()
                                or roundEndingVisible() or afkCameraAnchor~=anchor or afkCurrentBand()~=band then return end
                            afkVacuumTargetReady=nearby
                            cpuMs+=(os.clock()-slice)*1000
                            scanSamples+=1
                            scannedHayParts+=checked
                            scanTotalMs+=cpuMs
                            scanMaxMs=math.max(scanMaxMs,cpuMs)
                            if os.clock()-lastPerfReport>=30 then
                                print(string.format("[Perf] AFK hay scans=%d parts=%d average=%.2fms CPU max=%.2fms CPU",
                                    scanSamples,scannedHayParts,scanTotalMs/math.max(1,scanSamples),scanMaxMs))
                                scanSamples,scannedHayParts,scanTotalMs,scanMaxMs=0,0,0,0
                                lastPerfReport=os.clock()
                            end
                        end)
                        scanBusy=false
                        if not ok then warn("[AFK Orbit] Hay scan failed: "..tostring(err)) end
                    end)
                end
            else
                afkVacuumTargetReady = false
            end
        end
    end
end)

local function resetAfkForReplay(reason)
    if Unloaded or not IN_GAME then return end
    releaseAfkCamera()
    afkOrbitAngle, afkOrbitLap, afkOrbitLapProgress = 0, 0, 0
    afkOrbitLastAdvanceAt = os.clock()
    afkVacuumTargetReady = false
    afkPlayerAnchor = nil
    afkPositionConfirmed = false
    afkPositionCharacter = nil
    HayFolder = Workspace:FindFirstChild("HaystackClient")
    DroppedFolder = Workspace:FindFirstChild("DroppedHay")
    GemsFolder = Workspace:FindFirstChild("GemsClient")
    HayCache.part, HayCache.time = nil, 0
    DroppedCache.part, DroppedCache.time = nil, 0
    GemsCache.part, GemsCache.time = nil, 0
    afkReplayNeedsAnchor = true
    afkReplayResetAt = os.clock()
    afkReplayNextSampleAt = 0
    afkReplayCandidateCenter, afkReplayCandidateCount, afkReplayCandidateSource, afkReplayCandidateChecks = nil, 0, nil, 0
    print("[AutoFarmWins] AFK round reset: " .. tostring(reason) ..
        " | enabled=" .. tostring(State.AutoFarmWins) ..
        " | fixed axis=" .. (afkPhysicalPileAnchor
            and string.format("(%.1f,%.1f)", afkPhysicalPileAnchor.X, afkPhysicalPileAnchor.Z)
            or "pending") .. " | waiting for new haystack layers")
    task.delay(3, function()
        if Unloaded or State.AutoFarmWins ~= true then return end
        print("[AutoFarmWins] Replay restart status: ending=" .. tostring(roundEndingVisible()) ..
            " priority=" .. tostring(needleHasPriority()) ..
            " bypass=" .. tostring(cutsceneBypassActive) ..
            " orbit=" .. tostring(afkCameraBound) ..
            " vacuumEnabled=" .. tostring(State.AutoFarmVacuum) ..
            " vacuumTarget=" .. tostring(afkVacuumTargetReady))
    end)
end

-- The new pile may continue replicating after initial sampling. Keep a
-- replay-only 16-second recalibration window, then freeze the center again.
-- Do not chase the centroid once vacuum farming begins removing individual hay.
task.spawn(function()
    while not Unloaded do
        task.wait(1.25)
        if Unloaded then break end
        local now = os.clock()
        if not Unloaded and afkCameraBound and afkCameraAnchor
            and afkReplayCalibrationUntil > now and afkFarmModeActive()
            and not needleHasPriority() and not roundEndingVisible()
            and now-afkReplayLastCorrectAt >= 1.1 then
            local updated, count, span = getHaystackCenter()
            if updated and count >= 25 then
                local old = afkCameraAnchor
                local distance = (Vector3.new(updated.X-old.X, 0, updated.Z-old.Z)).Magnitude
                local growth = count >= afkReplayAnchorCount*1.25
                local heightGrowth = span >= afkReplayAnchorSpan+3
                local mostlyIntact = count >= afkReplayAnchorCount*0.75
                if mostlyIntact and (growth or heightGrowth) then
                    -- Only refresh the vertical hay surfaces when new pieces
                    -- appear. The orbit's X/Z must NEVER follow the changing
                    -- centroid; camera and vacuum follower share one anchor.
                    afkReplayLastCorrectAt = now
                    afkReplayAnchorCount, afkReplayAnchorSpan = count, span
                    local axis = afkPhysicalPileAnchor or old
                    local pinned = Vector3.new(axis.X, old.Y, axis.Z)
                    afkCameraAnchor = pinned
                    afkBandSurfaceHeights, afkCameraPileTopY = measureAfkBandSurfaces(pinned)
                    afkPlayerAnchor = pinned
                    afkVacuumTargetReady = false
                    print(string.format("[AFK Orbit] Replay height refresh: hay=%d span=%.1f | ignored live-centroid drift=%.1f studs; axis pinned",
                        count, span, distance))
                elseif distance >= 3 and now-afkReplayLastCorrectAt >= 5 then
                    afkReplayLastCorrectAt = now
                    print(string.format("[AFK Orbit] Ignored live hay centroid drift=%.1f studs; fixed pile axis preserved", distance))
                end
            end
        end
    end
end)

local afkCharacterConnection = LocalPlayer.CharacterAdded:Connect(function()
    if Unloaded or not IN_GAME or State.AutoFarmWins ~= true then return end
    task.defer(function()
        if not Unloaded then resetAfkForReplay("character respawn") end
    end)
end)
local previousAfkRoundCleanup = _G.__BEYY_HUB_CLEANUP
_G.__BEYY_HUB_CLEANUP = function()
    afkCharacterConnection:Disconnect()
    if previousAfkRoundCleanup then pcall(previousAfkRoundCleanup) end
end

do
    local autoCreating = false
    local occupiedCircles = {}

    local function findInTree(root, path)
        local current = root
        for _, name in ipairs(path) do
            if not current then return nil end
            current = current:FindFirstChild(name)
        end
        return current
    end

    local function isCircleOccupied(circle)
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local otherHrp = char and char:FindFirstChild("HumanoidRootPart")
                if otherHrp then
                    local dx = otherHrp.Position.X - circle.Position.X
                    local dz = otherHrp.Position.Z - circle.Position.Z
                    if math.sqrt(dx*dx + dz*dz) < 5 then return true end
                end
            end
        end
        return false
    end

    local function walkToCircle(circle)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = getHRP()
        if not hum or not hrp then return false end
        local target = Vector3.new(circle.Position.X, hrp.Position.Y, circle.Position.Z)
        hum:MoveTo(target)
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local createUI = pg and pg:FindFirstChild("CreatePartyUI")
        local container = createUI and createUI.Main and createUI.Main.Container
        if not container then return false end
        local t = 0
        while not container.Visible and t < 3.5 do
            if (hrp.Position - target).Magnitude > 4 then hum:MoveTo(target) end
            task.wait(0.08)
            t += 0.08
        end
        pcall(function() hum:MoveTo(hrp.Position) end)
        return container.Visible
    end

    local function monitorCircle(circle)
        local running = true
        task.spawn(function()
            while running and not Unloaded do
                task.wait(0.3)
                local hrp = getHRP()
                if hrp then
                    local dx = hrp.Position.X - circle.Position.X
                    local dz = hrp.Position.Z - circle.Position.Z
                    if math.sqrt(dx*dx + dz*dz) > 4 then
                        local char = LocalPlayer.Character
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hum then hum:MoveTo(Vector3.new(circle.Position.X, hrp.Position.Y, circle.Position.Z)) end
                    end
                end
            end
        end)
        return function() running = false end
    end

    local function tryCreateFromCircle(circle)
        if not walkToCircle(circle) then return false end
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local createUI = pg and pg:FindFirstChild("CreatePartyUI")
        local container = createUI and createUI.Main and createUI.Main.Container
        if not container then return false end
        local stopMonitor = monitorCircle(circle)
        task.wait(0.2)
        local normalMode = findInTree(container, {"DifficultyChoosingFrame", "NormalMode"})
        if normalMode then clickGuiObjectEarly(normalMode); task.wait(0.12) end
        local numberLabel = container:FindFirstChild("Number")
        local minusBtn = container:FindFirstChild("Minus")
        if numberLabel and minusBtn then
            local attempts = 0
            while attempts < 6 do
                local n = tonumber(numberLabel.Text)
                if not n or n <= 1 then break end
                clickGuiObjectEarly(minusBtn)
                task.wait(0.1)
                attempts += 1
            end
        end
        local createBtn = container:FindFirstChild("Create")
        if createBtn then
            for _ = 1, 6 do
                if IN_GAME or not container.Visible then break end
                clickGuiObjectEarly(createBtn)
                local deadline = tick() + 0.9
                while tick() < deadline do
                    if IN_GAME or not container.Visible then break end
                    task.wait(0.05)
                end
                if IN_GAME or not container.Visible then
                    print("[Round] Create successful")
                    stopMonitor()
                    return true
                end
            end
        end
        stopMonitor()
        return false
    end

    local function attemptAutoCreate()
        if autoCreating then return end
        if IN_GAME then return end
        autoCreating = true
        local circles = getTeleportCircles()
        if #circles == 0 then autoCreating = false; return end
        for _, entry in ipairs(circles) do
            if IN_GAME then break end
            local circle = entry.part
            if isCircleOccupied(circle) then
                occupiedCircles[circle] = tick() + 15
            else
                if tryCreateFromCircle(circle) then autoCreating = false; return end
                occupiedCircles[circle] = tick() + 4
            end
        end
        autoCreating = false
    end

    task.spawn(function()
        while not Unloaded do
            task.wait(0.5)
        if Unloaded then break end
            if afkFarmModeActive() and not IN_GAME then
                pcall(attemptAutoCreate)
            end
        end
    end)
end

do
    -- Run the full Skip/Replay setup in a separate Luau function so its
    -- callback locals don't exhaust the enclosing module's 200 registers.
    -- Execute synchronously: no changes to Replay timing or worker order.
    (function()
    print("[AutoUI] Skip/Replay block starting (v103.00; hybrid native ReplayVote + stale-launch recovery 2026-10-28)")

    local lastIntroSkipTime = 0
    local lastReplayClickTime = 0
    local introSkipStreak = 0
    local replayClickStreak = 0
    local endSkipStreak = 0
    local lastEndSkipClickTime = 0
    local INTRO_SKIP_COOLDOWN = 1.5
    local INTRO_FAILSAFE_DELAY = 3.0
    local INTRO_FAILSAFE_COOLDOWN = 0.65
    local introSkipFirstSeenAt = nil
    local introFailsafeActive = false
    local SKIP_COOLDOWN = 1.0

    local replayFiredForThisEnding = false
    local hasOwnedNeedleThisRound = false

    local function getClickCoords(obj)
        if not obj or not obj:IsA("GuiObject") then return nil end
        if not obj.Visible then return nil end
        local absPos, absSize = obj.AbsolutePosition, obj.AbsoluteSize
        if absSize.X <= 0 or absSize.Y <= 0 then return nil end
        local inset = GuiService:GetGuiInset()
        return absPos.X + absSize.X / 2 + inset.X, absPos.Y + absSize.Y / 2 + inset.Y
    end

    local function vimClick(cx, cy)
        if needleHasPriority() then return false end
        local mouseDown = false
        local ok = pcall(function()
            VirtualInputManager:SendMouseMoveEvent(cx, cy, game)
            task.wait(0.03)
            if needleHasPriority() then return end
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            mouseDown = true
            task.wait(0.06)
        end)
        if mouseDown then
            pcall(function() VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0) end)
        end
        return ok and mouseDown and not needleHasPriority()
    end

    local function activateButton(obj)
        if not obj or needleHasPriority() or autoUiMouseBusy then return false end
        autoUiMouseBusy = true
        local ok, result = xpcall(function()
            local anyHit = false
            local cx, cy = getClickCoords(obj)
            if cx and cy then
                if not vimClick(cx, cy) then return false end
                anyHit = true
            end
            local function fireOn(o)
                if not o or needleHasPriority() then return end
                if firesignal then
                    pcall(function() firesignal(o.MouseButton1Click) end)
                    if needleHasPriority() then return end
                    pcall(function() firesignal(o.MouseButton1Down) end)
                    task.wait(0.03)
                    if needleHasPriority() then return end
                    pcall(function() firesignal(o.MouseButton1Up) end)
                    if needleHasPriority() then return end
                    pcall(function() firesignal(o.Activated) end)
                    anyHit = true
                end
            end
            if obj:IsA("TextButton") or obj:IsA("ImageButton") then fireOn(obj) end
            if needleHasPriority() then return anyHit end
            for _, child in ipairs(obj:GetDescendants()) do
                if needleHasPriority() then break end
                if child:IsA("TextButton") or child:IsA("ImageButton") then fireOn(child) end
            end
            return anyHit
        end, function(err) return tostring(err) end)
        autoUiMouseBusy = false
        if not ok then warn("[AutoUI] Button click failed: " .. tostring(result)) end
        return ok and result
    end

    local function collectVisibleText(obj)
        local parts = {}
        if obj:IsA("TextButton") or obj:IsA("TextLabel") then
            pcall(function() if obj.Text and obj.Text ~= "" then table.insert(parts, obj.Text) end end)
        end
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                pcall(function() if child.Text and child.Text ~= "" then table.insert(parts, child.Text) end end)
            end
        end
        return table.concat(parts, " "):lower()
    end

    local function contextFor(gui)
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local context = string.lower(gui.Name).. " ".. collectVisibleText(gui)
        local p = gui.Parent
        local hops = 0
        while p and p ~= pg and hops < 5 do
            context = context.. " ".. string.lower(p.Name)
            p = p.Parent
            hops = hops + 1
        end
        return context
    end

    local function findReplayButton()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return nil end
        local endingUI = pg:FindFirstChild("NeedleEndingUI")
        if not endingUI then return nil end
        local frame = endingUI:FindFirstChild("ReturnToLobby")
        if not frame then return nil end
        local replayBtn = frame:FindFirstChild("ReplayButton",State.AutoFarmWins==true)
        if replayBtn and guiReallyVisible(replayBtn) then
            if replayBtn:IsA("GuiButton") then return replayBtn end
            for _,child in ipairs(replayBtn:GetDescendants()) do
                if child:IsA("GuiButton") and guiReallyVisible(child) then return child end
            end
            if not State.AutoFarmWins then return replayBtn end
        elseif not State.AutoFarmWins then
            return nil
        end
        if State.AutoFarmWins then
            -- Standalone Wins also recognizes a rebuilt/nested native Replay
            -- control, never any Return To Lobby button.
            for _,child in ipairs(frame:GetDescendants()) do
                if child:IsA("GuiButton") and guiReallyVisible(child) then
                    local name=child.Name:lower()
                    local label=child:IsA("TextButton") and child.Text:lower() or ""
                    if name=="replay" or name=="replaybutton"
                        or label=="replay" or label:match("^replay%s+%d+%s*/%s*%d+") then
                        return child
                    end
                end
            end
        end
        return nil
    end

    local function findSkipButton()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return nil end
        local best, bestScore = nil, 0
        for _, gui in ipairs(pg:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) and guiReallyVisible(gui) then
                local context = contextFor(gui)
                if context:find("skip", 1, true) then
                    local score = 1
                    if score > bestScore then
                        best = gui
                        bestScore = score
                    end
                end
            end
        end
        return best
    end

    local function isEndingVisible()
        return roundEndingVisible()
    end

    local function createReplayRecovery(d)
        -- Server-owned replay launches normally teleport quickly; if one hangs,
        -- retry only the native ReplayVote signal, never a lobby teleport.
        local LAUNCH_STALL_SECONDS=25
        -- A new Chapter 1 instance can show results with Launching already
        -- true before this player voted or received any OnTeleport event.
        -- Treat that particular state as potentially stale much sooner.
        local UNOWNED_LAUNCH_STALL_SECONDS=8
        local VOTE_RETRY_SECONDS=15
        local MAX_STALLED_VOTE_RETRIES=3
        local RETRY_WINDOW_SECONDS=120
        local state={}
        local stopped=false
        local function now() return d.now and d.now() or os.clock() end
        local function reset()
            state={attempts=0,recoveries=0,nextAttempt=0}
        end
        reset()
        local function emit(phase,message)
            if state.phase~=phase or state.message~=message then
                state.phase,state.message=phase,message
                if d.status then pcall(d.status,message,{phase=phase,attempts=state.attempts,recoveries=state.recoveries}) end
            end
        end
        local self={}
        function self:Reset() reset() end
        function self:Stop() stopped=true reset() end
        function self:GetStatus()
            return {phase=state.phase,message=state.message,attempts=state.attempts,recoveries=state.recoveries,
                firstSeen=state.firstSeen,launchAt=state.launchAt,pending=state.pending,nextAttempt=state.nextAttempt,
                teleporting=state.teleporting,stalledSince=state.stalledSince,
                lastStallRetryAt=state.lastStallRetryAt}
        end
        function self:TeleportState(value)
            if stopped or not state.firstSeen then return end
            if tostring(value):find("Failed",1,true) then self:TeleportFailed(tostring(value)); return end
            state.teleporting=true
            state.launchAt=state.launchAt or now()
            emit("launching","Replay teleport in progress")
        end
        function self:TeleportFailed(message)
            if stopped or not state.firstSeen or not d.enabled() or not d.ending() then return end
            state.teleporting=false
            state.launchAt=nil
            state.nextAttempt=now()+15
            emit("retry","Replay teleport failed; staying in Chapter 1 and waiting to retry: "..tostring(message))
        end
        local function snapshot()
            local ok,value=pcall(d.snapshot)
            return ok and type(value)=="table" and value or nil
        end
        local function recoverStalledLaunch(t,phase,vote)
            local start=state.launchAt or state.confirmedAt or state.firstSeen or t
            local unownedLaunch=phase=="server launching" and vote and vote.voted==false
                and not state.confirmed and not state.teleporting
            local threshold=unownedLaunch and UNOWNED_LAUNCH_STALL_SECONDS or LAUNCH_STALL_SECONDS
            if t-start<threshold then return false end
            state.stalledSince=state.stalledSince or t
            -- Never exhaust recovery permanently during unattended farming:
            -- allow at most three native votes per two-minute window.
            if not state.retryWindowAt then state.retryWindowAt=t end
            if t-state.retryWindowAt>=RETRY_WINDOW_SECONDS then
                state.retryWindowAt=t
                state.recoveries=0
                state.lastExhaustedLogAt=nil
                state.lastStallRetryAt=nil
            end
            if state.lastStallRetryAt and t-state.lastStallRetryAt<VOTE_RETRY_SECONDS then return true end
            if state.recoveries<MAX_STALLED_VOTE_RETRIES then
                state.lastStallRetryAt=t
                state.recoveries+=1
                local attempted,accepted=pcall(d.retryVote)
                local resent=attempted and accepted==true
                warn(string.format("[AutoUI Hybrid] Replay launch stalled for %.1fs (%s; voted=%s, launching=%s, teleporting=%s, early=%s); native replay-vote recovery %d/%d %s",
                    t-start,phase,tostring(vote and vote.voted),tostring(vote and vote.launching),
                    tostring(state.teleporting),tostring(unownedLaunch),state.recoveries,MAX_STALLED_VOTE_RETRIES,
                    resent and "sent" or "unavailable"))
                if d.ensureReload then pcall(d.ensureReload) end
                emit("stalled",resent and "Replay launch stalled; native Replay vote retried" or
                    "Replay launch stalled; native vote retry unavailable")
            else
                if not state.lastExhaustedLogAt or t-state.lastExhaustedLogAt>=60 then
                    state.lastExhaustedLogAt=t
                    warn("[AutoUI Hybrid] Replay stalled after native vote retries; pausing until the next recovery window. Remaining in Chapter 1; no lobby fallback.")
                end
                emit("stalled","Server Replay still stalled; next in-match vote retry window pending")
            end
            return true
        end
        function self:Step(button,ready)
            if stopped then return end
            if not d.enabled() or not d.ending() then
                if state.firstSeen then reset() end
                return
            end
            local t=now()
            state.firstSeen=state.firstSeen or t
            local vote=snapshot()
            if not vote then emit("waiting","Replay state unavailable");return end
            -- A live server launch is authoritative; keep its vote and watch
            -- for an actual teleport instead of waiting forever.
            if vote.launching==true then
                state.launchAt=state.launchAt or t
                if recoverStalledLaunch(t,"server launching",vote) then return end
                emit("launching","Server launching Replay; waiting for next round")
                return
            end
            if state.launchAt and not state.teleporting then state.launchAt=nil end
            if state.button~=button then
                state.button=button
                -- The native Replay button can be replaced while votes replicate.
                state.buttonSeen=state.buttonSeen or t
            end
            local count,total
            if button then
                local text=""
                if button:IsA("TextButton") then text=button.Text end
                for _,child in ipairs(button:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        text=text.." "..child.Text
                    end
                end
                count,total=text:match("(%d+)%s*/%s*(%d+)")
                count,total=tonumber(count),tonumber(total)
            end
            if vote.voted==true or (total and total>0 and count and count>=total)
                or (state.confirmed and vote.voted~=false) then
                state.confirmed=true
                state.confirmedAt=state.confirmedAt or t
                if recoverStalledLaunch(t,"vote accepted, launch not completed",vote) then return end
                emit("voted","Replay vote registered; waiting for next round")
                return
            end
            if state.confirmed then
                if count==0 and vote.voted==false and t-(state.confirmedAt or t)>5 then
                    state.confirmed=false
                else
                    emit("voted","Replay vote registered; waiting for next round")
                    return
                end
            end
            if not button then emit("waiting","Waiting for native Replay button");return end
            if ready==false then emit("waiting","Waiting for hub menu to close");return end
            if t-(state.buttonSeen or t)<0.25 or t<state.nextAttempt then return end
            state.attempts+=1
            local before=count
            if d.ensureReload then pcall(d.ensureReload) end
            local methods={"click","raw-click","activated","mouse-signal"}
            local method=d.useStandaloneClicks and d.useStandaloneClicks()
                and methods[(state.attempts-1)%#methods+1] or "click"
            local ok,sent=pcall(d.fallback,button,method)
            local cooldown=state.attempts<2 and 0.8 or state.attempts<5 and 1.5
                or state.attempts<10 and 3 or 6
            state.nextAttempt=now()+cooldown
            if ok and sent==true then
                local deadline=os.clock()+0.8
                repeat
                    if not d.ending() then state.confirmed=true;break end
                    local updated=snapshot()
                    if updated and (updated.launching or updated.voted) then
                        state.confirmed=true
                        break
                    end
                    if before~=nil then
                        local labels={}
                        if button:IsA("TextButton") then labels[#labels+1]=button.Text end
                        for _,child in ipairs(button:GetDescendants()) do
                            if child:IsA("TextLabel") or child:IsA("TextButton") then
                                labels[#labels+1]=child.Text
                            end
                        end
                        local advanced=tonumber(table.concat(labels," "):match("(%d+)%s*/%s*%d+"))
                        if advanced and advanced>before then
                            state.confirmed=true
                            break
                        end
                    end
                    task.wait(0.05)
                until os.clock()>=deadline
                if state.confirmed then state.confirmedAt=now() end
            end
            emit(state.confirmed and "voted" or "requesting",
                string.format("Replay GUI click %d via %s (%s); shared votes=%s/%s",
                    state.attempts,method,state.confirmed and "confirmed" or
                    (ok and sent==true and "sent, awaiting confirmation" or "not sent"),
                    tostring(count),tostring(total)))
        end
        return self
    end    local function ensureReplayReload()
        if _G.__BEYY_NEEDLEHUB_RELOAD_JOB==game.JobId then return true end
        local env=_G
        if type(getgenv)=="function" then local ok,value=pcall(getgenv);if ok and type(value)=="table" then env=value end end
        local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
            or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
        if type(queue)~="function" then return false,"queue_on_teleport is unavailable" end
        -- Test-only AFK replay continuation. Normal releases still use the main loader.
        if env.__BEYY_AF_WINS_TEST_BRANCH == "test/sceneton-auto-farm-wins-port" then
            local sourceRef=env.__BEYY_AF_WINS_TEST_BRANCH
            local sourceUrl="https://raw.githubusercontent.com/BeyyTU/needlehub/"..sourceRef.."/chapter1.lua"
            local testPayload=string.format([==[
                local env=(type(getgenv)=="function" and getgenv()) or _G
                env.__BEYY_AF_WINS_TEST_BRANCH=%q
                local url=%q
                local ok,source=pcall(function()
                    return game:HttpGet(url.."?refresh="..tostring(os.time()))
                end)
                if not ok or type(source)~="string"
                    or not source:find('local __BEYY_MODULE = "Chapter1"',1,true) then
                    warn("[AFK Test] Branch chapter failed to load"); return
                end
                local fn,err=loadstring(source)
                if not fn then warn("[AFK Test] Compile failed: "..tostring(err));return end
                local success,runtimeError=pcall(fn)
                if not success then warn("[AFK Test] Runtime error: "..tostring(runtimeError)) end
            ]==],sourceRef,sourceUrl)
            local ok,err=pcall(queue,testPayload)
            if ok then _G.__BEYY_NEEDLEHUB_RELOAD_JOB=game.JobId end
            return ok,tostring(err)
        end
        local payload=[====[
        local H=game:GetService("HttpService")
        local revision
        local resolved,info=pcall(function()
            return H:JSONDecode(game:HttpGet("https://api.github.com/repos/BeyyTU/needlehub/commits/main?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000))))
        end)
        if resolved and type(info)=="table" and type(info.sha)=="string" and #info.sha==40 and info.sha:match("^%x+$") then revision=info.sha end
        local url="https://raw.githubusercontent.com/BeyyTU/needlehub/"..(revision or "main").."/loader.lua"
        local body
        for attempt=1,3 do
            local ok,source=pcall(function()
                return game:HttpGet(url.."?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000)))
            end)
            if ok and type(source)=="string" and source:find('local VERSION = "103.00"',1,true)
                and source:find("afk_replay_loader_v103.lua",1,true) and loadstring(source) then body=source;break end
            if attempt<3 then task.wait(attempt*0.5) end
        end
        if not body and type(readfile)=="function" then
            local ok,cached=pcall(readfile,"BeyyHub/afk_replay_loader_v103.lua")
            if ok and type(cached)=="string" and cached:find('local VERSION = "103.00"',1,true)
                and cached:find("afk_replay_loader_v103.lua",1,true) and loadstring(cached) then body=cached end
        end
        if not body then warn("[BeyyHub] No validated online or cached AFK router; reattach and rerun the loader");return end
        if type(writefile)=="function" then pcall(writefile,"BeyyHub/afk_replay_loader_v103.lua",body) end
        local compiled,compileError=loadstring(body)
        if not compiled then warn("[BeyyHub] Teleport loader compile error: "..tostring(compileError));return end
        local succeeded,runtimeError=pcall(compiled,revision)
        if not succeeded then warn("[BeyyHub] Teleport loader error: "..tostring(runtimeError)) end
]====]
        local ok,err=pcall(queue,payload)
        if ok then _G.__BEYY_NEEDLEHUB_RELOAD_JOB=game.JobId end
        return ok,tostring(err)
    end
    local function replayVoteRemote()
        local folder=game:GetService("ReplicatedStorage"):FindFirstChild("NeedleHaystack")
        local remote=folder and folder:FindFirstChild("ReplayVote")
        return remote and remote:IsA("RemoteEvent") and remote or nil
    end
    local function replaySnapshot()
        local remote=replayVoteRemote()
        return {available=remote~=nil,voted=LocalPlayer:GetAttribute("ReplayVoted")==true,
            launching=remote and remote:GetAttribute("Launching")==true or false}
    end
    local function replayActionAllowed()
        local state=replaySnapshot()
        return not Unloaded and (State.AutoFarmWins==true or State.AutoFarmHay==true) and isEndingVisible() and not state.voted and not state.launching
    end
    local function verifiedReplayActivation(button)
        if not replayActionAllowed() or type(getconnections)~="function" then return false end
        local ok,connections=pcall(getconnections,button.Activated)
        if not ok or type(connections)~="table" then return false end
        for _,connection in ipairs(connections) do
            local fn=connection.Function
            if connection.Enabled~=false and type(fn)=="function" then
                local ok,source=pcall(function() return debug.info(fn,"s") end)
                if ok and type(source)=="string" and source:find("ReplayButtonClient",1,true) then
                    if not replayActionAllowed() then return false end
                    return pcall(fn)
                end
            end
        end
        return false
    end
    local function replayFallback(button,method)
        if not button or not guiReallyVisible(button) or not replayActionAllowed() then return false end
        if State.AutoFarmWins then
            -- Standalone rejects wrapper frames and frees Mouse1 before Replay.
            if not button:IsA("GuiButton") then return false end
            pcall(releaseWinVacuumForReplay)
        end
        if State.AutoFarmWins and (method=="activated" or method=="mouse-signal") then
            if verifiedReplayActivation(button) then return true end
            if type(firesignal)~="function" or not replayActionAllowed() then return false end
            if method=="activated" then return pcall(firesignal,button.Activated) end
            return pcall(firesignal,button.MouseButton1Click)
        end
        if method=="activated" then return verifiedReplayActivation(button) end
        -- GUI Replay uses the game's native button; do not click while a launch is active.
        if autoUiMouseBusy or needlePickupActive or not Window.Closed then return false end
        local x,y=getClickCoords(button)
        if not x then return false end
        if State.AutoFarmWins and method=="raw-click" then
            local inset=GuiService:GetGuiInset()
            x-=inset.X
            y-=inset.Y
        end
        autoUiMouseBusy=true
        local down=false
        local ok=pcall(function()
            VirtualInputManager:SendMouseMoveEvent(x,y,game)
            if State.AutoFarmWins then task.wait(0.035)
            else RunService.RenderStepped:Wait() end
            if not replayActionAllowed() then return end
            VirtualInputManager:SendMouseButtonEvent(x,y,0,true,game,0)
            down=true
            task.wait(0.085)
        end)
        if down then pcall(function() VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,0) end) end
        autoUiMouseBusy=false
        return ok and down
    end

    local replayRecovery=createReplayRecovery({
        enabled=function() return not Unloaded and IN_GAME and (State.AutoFarmWins==true or State.AutoFarmHay==true) end,
        ending=isEndingVisible,snapshot=replaySnapshot,
        fallback=replayFallback,ensureReload=ensureReplayReload,
        useStandaloneClicks=function()return State.AutoFarmWins==true end,
        retryVote=function()
            -- Reissue the exact in-match vote; the server remains responsible
            -- for deciding whether to launch. Never teleport to the lobby.
            local remote=replayVoteRemote()
            if not remote then return false end
            return pcall(function() remote:FireServer() end)
        end,
        status=function(message,status)
            _G.__BEYY_HYBRID_REPLAY_STATUS=status
            print("[AutoUI Hybrid] "..message)
        end,
    })
    local replayTeleportConnection=LocalPlayer.OnTeleport:Connect(function(value)
        replayRecovery:TeleportState(tostring(value))
    end)
    local replayFailureConnection=TeleportService.TeleportInitFailed:Connect(function(who,result,message)
        if who==LocalPlayer then replayRecovery:TeleportFailed(message) end
    end)
    local previousReplayCleanup=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        replayRecovery:Stop()
        replayTeleportConnection:Disconnect()
        replayFailureConnection:Disconnect()
        if previousReplayCleanup then previousReplayCleanup() end
    end
    task.defer(function() if not Unloaded then ensureReplayReload() end end)

    local resultsScreenWasVisible = false
    local replayVoteLogged = false
    local replayVotesBeforeClick = nil
    local replayMenuCloseAt = nil
    local replayLastWaitLog = 0
    local replayButtonSeenAt = nil
    local trackedReplayButton = nil
    local replayFirstUnconfirmedAt = nil
    local replayLastStallWarningAt = -math.huge

    local replayWorkerLastError=-math.huge
    task.spawn(function()
        while not Unloaded do
            -- Standalone checks the results screen every 0.22s.
            -- Keep the older cadence for Auto Farm Hay.
            task.wait(State.AutoFarmWins and 0.22 or 0.35)
        if Unloaded then break end
            local stepOK,stepError=xpcall(function()
            if not IN_GAME then
                replayRecovery:Reset()
                hasOwnedNeedleThisRound = false
                replayFiredForThisEnding = false
                replayVoteLogged = false
                replayVotesBeforeClick = nil
                replayMenuCloseAt = nil
                replayButtonSeenAt = nil
                trackedReplayButton = nil
                resultsScreenWasVisible = false
                introSkipStreak = 0
                introSkipPending = false
                introSkipFirstSeenAt = nil
                introFailsafeActive = false
                replayClickStreak = 0
                replayFirstUnconfirmedAt = nil
                replayLastStallWarningAt = -math.huge
                endSkipStreak = 0
                lastReplayClickTime = 0
                lastEndSkipClickTime = 0
            else
                local now = tick()
                local endingVisible = isEndingVisible()
                if endingVisible then

                    introSkipPending = false
                    introSkipFirstSeenAt = nil
                    introFailsafeActive = false
                    if not resultsScreenWasVisible then
                        resultsScreenWasVisible = true
                        replayFiredForThisEnding = false
                        replayClickStreak = 0
                        replayFirstUnconfirmedAt = now
                        replayLastStallWarningAt = -math.huge
                        lastReplayClickTime = 0
                        replayVoteLogged = false
                        replayVotesBeforeClick = nil
                        replayMenuCloseAt = nil
                        replayButtonSeenAt = nil
                        trackedReplayButton = nil
                        if State.AutoFarmWins == true then
                            -- Standalone immediately stops vacuum input and
                            -- releases the orbit camera at round results.
                            pcall(releaseWinVacuumForReplay)
                            releaseAfkCamera()
                        end
                        print("[AutoUI] Results screen visible; replay enabled")
                    end

                    if State.AutoFarmWins == true or State.AutoFarmHay == true then
                        if State.AutoFarmWins == true then
                            -- Standalone treats the menu's actual open/closed
                            -- state as authoritative. Window.Gui.Enabled can
                            -- remain true even after the panel is closed, which
                            -- otherwise restarts the close grace period forever.
                            if Window and not Window.Destroyed and not Window.Closed then
                                local closeOK,closeErr=pcall(function() Window:Close() end)
                                if closeOK then replayMenuCloseAt=now
                                elseif now-replayLastWaitLog>=4 then
                                    replayLastWaitLog=now
                                    warn("[AutoUI] Could not close menu for Replay: "..tostring(closeErr))
                                end
                            end
                            local ready=Window and (Window.Closed==true)
                            replayRecovery:Step(findReplayButton(),ready)
                        else
                            -- Preserve Auto Farm Hay's existing menu/replay flow.
                            if Window and not Window.Destroyed
                                and (not Window.Closed or (Window.Gui and Window.Gui.Enabled)) then
                                local closeOK,closeErr=pcall(function() Window:Close() end)
                                if closeOK then replayMenuCloseAt=now
                                elseif now-replayLastWaitLog>=4 then
                                    replayLastWaitLog=now
                                    warn("[AutoUI] Could not close menu for Replay: "..tostring(closeErr))
                                end
                            end
                            local ready=not ((Window and not Window.Closed)
                                or (Window and Window.Gui and Window.Gui.Enabled)
                                or (replayMenuCloseAt and now-replayMenuCloseAt<0.45))
                            replayRecovery:Step(findReplayButton(),ready)
                        end
                    else replayRecovery:Reset() end
                else
                    replayRecovery:Reset()
                    if resultsScreenWasVisible then
                        print("[AutoUI] Results screen closed")
                        if State.AutoFarmWins == true then
                            resetAfkForReplay("Replay results dismissed")
                        end
                    end
                    resultsScreenWasVisible = false
                    replayFiredForThisEnding = false
                    replayVoteLogged = false
                    replayVotesBeforeClick = nil
                    replayMenuCloseAt = nil
                    replayButtonSeenAt = nil
                    trackedReplayButton = nil
                    replayClickStreak = 0
                    replayFirstUnconfirmedAt = nil
                    replayLastStallWarningAt = -math.huge
                    lastReplayClickTime = 0

                    local btn = nil
                    if not needleHasPriority() then btn = findSkipButton() end
                    if btn then
                        introSkipPending = true
                        if not introSkipFirstSeenAt then
                            introSkipFirstSeenAt = now
                            introFailsafeActive = false
                            print("[AutoUI] Intro Skip detected; reserving Mouse1 for skip")
                        end

                        if not introFailsafeActive and now - introSkipFirstSeenAt >= INTRO_FAILSAFE_DELAY then
                            introFailsafeActive = true
                            warn("[AutoUI] Intro Skip still visible after 3s; failsafe retries enabled")
                        end
                        local interval = introFailsafeActive and INTRO_FAILSAFE_COOLDOWN or INTRO_SKIP_COOLDOWN
                        if now - lastIntroSkipTime >= interval then
                            lastIntroSkipTime = now
                            introSkipStreak = introSkipStreak + 1
                            if not activateButton(btn) then

                                print("[AutoUI] Intro Skip input blocked; still pending")
                            end
                        end
                    else
                        if introSkipPending then
                            print("[AutoUI] Intro Skip button no longer visible; releasing input priority")
                        end
                        introSkipPending = false
                        introSkipFirstSeenAt = nil
                        introFailsafeActive = false
                    end
                end
            end
            end,function(message) return tostring(message) end)
            if not stepOK and os.clock()-replayWorkerLastError>=5 then
                replayWorkerLastError=os.clock()
                warn("[AutoUI] Replay/skip scan failed; worker will retry: "..tostring(stepError))
            end
        end
    end)
    end)()
end

-- Build menu controls in their own register scope; retain the startup-selected tab.
local CollectingTab = (function()
local MainTab = Window:Tab({ Title = "Overview & Settings", Icon = "house" })
local FarmingSection = Window:Section({ Title = "Farming", Icon = "wheat", Opened = true })
local CollectingTab = FarmingSection:Tab({ Title = "Collecting", Icon = "wheat" })
local SellingTab = FarmingSection:Tab({ Title = "Selling", Icon = "coins" })
local ToolsTab = FarmingSection:Tab({ Title = "Tools", Icon = "hammer" })
local NeedleTab = FarmingSection:Tab({ Title = "Needle", Icon = "search" })
local InventorySection = Window:Section({ Title = "Inventory", Icon = "backpack", Opened = true })
local ShopTab = InventorySection:Tab({ Title = "Shop Items", Icon = "shopping-cart" })
local UpgradesTab = InventorySection:Tab({ Title = "Upgrades", Icon = "trending-up" })
local ExploitTab = Window:Tab({ Title = "Exploit", Icon = "zap" })
local SettingsTab = MainTab

do
    Header(MainTab, "Dashboard")
    Info(MainTab, "Game: ".. (IN_GAME and "Chapter 1 (FARMHOUSE)" or "Lobby"))
    Info(MainTab, "Toggle UI: RightControl")

    AddToggle(MainTab, "AutoFarmWins", "Auto Farm Wins (AFK Farm Mode)", sharedAFKAtChapterEntry == true,
        "AFK round-create, sceneton 8-route sweep (22/20/18/16/14/11/8/5 studs; highest route 2x speed), and automatic vacuum when enabled below.",
        function(v)
            if not v then releaseAfkCamera() end
            if v and State.AutoFarmHay then
                State.AutoFarmHay=false
                hayPreference.save(false)
                if Registry.AutoFarmHay then pcall(function() Registry.AutoFarmHay:Set(false) end) end
            end
            if not restoringStartupAutoFarm then
                saveAutoFarmPreference(v == true)
                print("[Mode] AFK Farm Mode = ".. tostring(State.AutoFarmWins))
            end
        end)
    AddToggle(MainTab, "AutoFarmHay", "Auto Farm Hay (Impossible Mode)", sharedHayAtChapterEntry == true,
        "Repeat twelve adaptive hay rings (top two aim down), upgrade all tools, hand in only after zero hay, and in-match Replay.",
        function(v)
            if v and State.AutoFarmWins then
                State.AutoFarmWins=false
                saveAutoFarmPreference(false)
                if Registry.AutoFarmWins then pcall(function() Registry.AutoFarmWins:Set(false) end) end
            end
            if not v then State.HayFarmTargetReady=false;State.HayFarmCleared=false end
            hayPreference.save(v==true)
        end)
    AddToggle(MainTab, "AutoFarmVacuum", "Vacuum During Auto Farm Wins", true,
        "Use heat-bar-controlled suction while the character follows the sceneton's nine haystack routes.")

    local sessionPara = MainTab:Paragraph({ Title = "Session", Desc = "0s elapsed" })
    task.spawn(function()
        local s = 0
        while not Unloaded do
            task.wait(3); if Unloaded then break end; s += 3
            pcall(function()
                sessionPara:SetDesc(string.format(
                    "Session: %dm %ds | Cash: $%s | Gems: %s | Hay: %d/%d",
                    s // 60, s % 60, tostring(getCash()), tostring(getGems()),
                    getHayHeld(), getHayCapacity()
                ))
            end)
        end
    end)
end

do
    Header(CollectingTab, "Resource Collecting")
    AddToggle(CollectingTab, "AutoPickHay", "Auto Pick Hay", false)
    AddToggle(CollectingTab, "AutoCollectDroppedHay", "Auto Collect Dropped Hay", false)
    AddToggle(CollectingTab, "AutoCollectGems", "Auto Collect Gems", false)
    AddSlider(CollectingTab, "CollectInterval", "Loop Interval (s)", 0.1, 3, 0.5, 0.1)
end

do
    Header(SellingTab, "Selling")
    AddToggle(SellingTab, "AutoSellHay", "Auto Sell Hay", false)
    AddSlider(SellingTab, "SellThreshold", "Sell When Hay >=", 1, 250, 25, 1)
    AddToggle(SellingTab, "SellOnlyIfFull", "Only Sell If Full", false)
end

do
    Header(ToolsTab, "Auto Tool Usage")
    Info(ToolsTab, "Tools work independently of AFK mode. With AFK enabled, TNT targets remaining hay around the orbiting camera's current angle.")
    AddToggle(ToolsTab, "AutoUseTNT", "Auto Use TNT", false)
    AddSlider(ToolsTab, "TntLightCooldown", "TNT Light Cooldown (s)", 0, 60, 0, 0.05,
        "Minimum interval between lighting attempts; the game's actual TNT cooldown still applies.")
    AddSlider(ToolsTab, "TntThrowDelay", "TNT Throw Delay After Lighting (s)", 0, 5, 0.5, 0.05,
        "Wait after the server confirms TNT is lit before throwing. Lower values may be rejected by the game.")
    AddToggle(ToolsTab, "AutoUsePitchfork", "Auto Use Pitchfork", false)
    AddToggle(ToolsTab, "AutoDeployDrone", "Auto Deploy Drone", false)
    AddToggle(ToolsTab, "AutoUseVacuum", "Auto Use Vacuum (live heat + cooldown)", false,
        "Holds Mouse1 until the overheat bar reaches 100%, waits until it returns to 0%, and releases for needle pickup/results.")
    AddSlider(ToolsTab, "VacuumHotbarSlot", "Vacuum Hotbar Slot (fallback)", 1, 9, 5, 1,
        "Default: slot 5. Used when the vacuum is not a Roblox Tool in Backpack.")
    AddSlider(ToolsTab, "ToolInterval", "Tool Interval (s)", 0.2, 5, 0.5, 0.1)
end

do
    Header(NeedleTab, "Needle (TOP PRIORITY)")
    Info(NeedleTab, "When the needle is exposed, all farm loops pause automatically.")
    AddToggle(NeedleTab, "AutoFindNeedle", "Auto Find Needle", false)
    AddToggle(NeedleTab, "AutoPickupNeedle", "Auto Pick Up Needle", false)
    AddToggle(NeedleTab, "AutoHandInNeedle", "Auto Hand In Needle", false)
    AddSlider(NeedleTab, "NeedleInterval", "Needle Retry Delay (s)", 0.2, 3, 0.2, 0.1)
end

do
    Header(ShopTab, "Purchasing")
    State.BuyToolsList = { "Pitchfork" }
    local dd = ShopTab:Dropdown({
        Title = "Buy Tools Selection",
        Values = { "Pitchfork", "TNT", "Drone", "Infinite Bag", "Capacity Bag" },
        Value = { "Pitchfork" },
        Multi = true,
        AllowNone = true,
        Callback = function(v) State.BuyToolsList = v end,
    })
    Registry.BuyToolsList = dd
    AddToggle(ShopTab, "AutoBuyTools", "Auto Buy Selected Tools", false)
    AddSlider(ShopTab, "BuyInterval", "Buy Interval (s)", 0.5, 5, 1, 0.1)
end

do
    Header(UpgradesTab, "Permanent (Gems)")
    AddToggle(UpgradesTab, "UpgBagSize", "Auto Upgrade Bag Size", false)
    AddToggle(UpgradesTab, "UpgExtraTake", "Auto Upgrade Hand Grab Amount", false)
    AddToggle(UpgradesTab, "UpgGemValue", "Auto Upgrade Gem Value", false)
    AddToggle(UpgradesTab, "UpgHayValue", "Auto Upgrade Hay Value", false)
    AddSlider(UpgradesTab, "PermInterval", "Permanent Loop (s)", 0.5, 5, 0.5, 0.1)
    Header(UpgradesTab, "Hand (Cash)")
    AddToggle(UpgradesTab, "UpgHandSpeed", "Auto Hand Speed", false)
    AddToggle(UpgradesTab, "UpgHandGrab", "Auto Hand Grasp", false)
    AddToggle(UpgradesTab, "UpgHandHold", "Auto Hand Hold", false)
    Header(UpgradesTab, "TNT (Cash)")
    AddToggle(UpgradesTab, "UpgTntLuck", "Auto TNT Lucky Blast", false)
    AddToggle(UpgradesTab, "UpgTntCooldown", "Auto TNT Cooldown", false)
    AddToggle(UpgradesTab, "UpgTntPower", "Auto TNT Power", false)
    Header(UpgradesTab, "Pitchfork (Cash)")
    AddToggle(UpgradesTab, "UpgPitchCooldown", "Auto Pitchfork Cooldown", false)
    AddToggle(UpgradesTab, "UpgPitchHold", "Auto Pitchfork Hold", false)
    AddToggle(UpgradesTab, "UpgPitchSweep", "Auto Pitchfork Sweep", false)
    Header(UpgradesTab, "Drone (Cash)")
    AddToggle(UpgradesTab, "UpgDroneSpeed", "Auto Drone Speed", false)
    AddToggle(UpgradesTab, "UpgDroneGrab", "Auto Drone Grasp", false)
    AddToggle(UpgradesTab, "UpgDroneCapacity", "Auto Drone Capacity", false)
    Header(UpgradesTab, "Vacuum (Cash)")
    AddToggle(UpgradesTab, "UpgVacPower", "Auto Vacuum Power", false)
    AddToggle(UpgradesTab, "UpgVacCooling", "Auto Vacuum Cooling", false)
    AddToggle(UpgradesTab, "UpgVacRuntime", "Auto Vacuum Runtime", true)
    Header(UpgradesTab, "Capacity (Cash)")
    AddToggle(UpgradesTab, "UpgCapacity", "Auto Upgrade Carry Capacity", false)
end

do
    Header(ExploitTab, "Lobby Exploits")

    ExploitTab:Toggle({
        Title = "Arcade Gem Farm",
        Value = false,
        Callback = function(v) State.ArcadeFarm = v end,
    })

    ExploitTab:Toggle({
        Title = "Auto Class Roller",
        Value = false,
        Callback = function(v) State.ClassRoller = v end,
    })

    local targetDropdown = ExploitTab:Dropdown({
        Title = "Target Class",
        Values = { "The Chosen One", "Ultimate Farmer", "Hoover", "Drone Specialist", "Prospector", "Beyond The Limits" },
        Value = "The Chosen One",
        Callback = function(v) State.ClassTarget = v end,
    })
    Registry.ClassTarget = targetDropdown
    AddSlider(ExploitTab, "ClassRollInterval", "Roll Interval (s)", 0.5, 3, 1.1, 0.1)
end

do
    (function(tab,registry,isRunning)
local function createSceneryVisibility(world)
    local api={}
    local alive,grass,scenery=true,false,false
    local roots,hidden,connections={},{},{}
    local generation=0
    local assets={
        ["103217178175958"]=true,["102928738001465"]=true,["127886107848822"]=true,
        ["104323643416798"]=true,["110445097892661"]=true,["93443489140535"]=true,
        ["85884435633156"]=true,["77697391368219"]=true,["77965045617364"]=true,
    }
    -- Gameplay roots are pruned before discovery, including the very large hay folders.
    local gameplay={Camera=true,Terrain=true,NPC=true,RelicTablets=true,Sundial=true,SellModel=true,BarnShop=true,
        BreakableFences=true,Gate=true,InvisibleBorders=true,EndCutscenePath=true,BarnIntro=true,PotionScene=true,
        HaystackClient=true,HaystackCollision=true,DroppedHay=true,GemsClient=true,NeedleObjectiveServer=true,
        HiddenNeedleClient=true,HeldHayClient=true,LiveTnt=true,HayDrones=true,HayPets=true,Local=true,
        Puzzles=true,HayCandles=true,WhereToPlaceCandles=true,Leaderboards=true}
    local structural={"house","barn","building","wall","roof","floor","ground","road","gate","fence",
        "door","bridge","stair","platform","shed","silo","tower","vehicle","truck","car","windmill"}
    local gameplayWords={"boss","weakpoint","attack","hazard","projectile","trigger","hitbox","telegraph",
        "warning","snare","tablet","pickup","needle","potion","crank","portal","spawn","checkpoint",
        "ladder","button","lever","switch","objective","sell","shop","waypoint","zone","seat",
        "candle","key","paper","puzzle","ufo","vent","laser","barrier","reward","quest"}
    local identityAttributes={HayId=true,GemId=true,Ring=true,Revealed=true,Taken=true,Placed=true,BossWeakPoint=true,
        CandleId=true,KeyId=true,PaperId=true,UfoId=true,UFOId=true,PuzzleId=true,Interactable=true}
    local function rootOf(obj)
        local node=obj
        while node and node.Parent~=world do node=node.Parent end
        return node
    end
    local function excluded(root)
        local name=root.Name;local lower=name:lower()
        return gameplay[name]or lower:find("boss",1,true)or lower:find("effects",1,true)
            or lower:find("viewclient",1,true)or lower:find("debris",1,true)
            or lower:find("trigger",1,true)or lower:find("hitbox",1,true)
    end
    local function isGrass(obj)
        if obj:IsA("MeshPart")and assets[tostring(obj.MeshId):match("%d+$")]then return true end
        -- Other chapters can use different grass assets and nested grass models.
        local node=obj
        while node and node~=world do
            local name=node.Name:lower()
            if name=="grass"or name:match("^grass[%W_%d]")or name:match("^grasspatch")
                or name:match("^grasstuft")or name:match("^grassclump")then return true end
            node=node.Parent
        end
        return false
    end
    local function restore(obj)
        local saved=hidden[obj];if not saved then return end
        hidden[obj]=nil
        pcall(function()obj.LocalTransparencyModifier=saved.Transparency;obj.CastShadow=saved.Shadow end)
        for decal,value in pairs(saved.Decals)do pcall(function()decal.Transparency=value end)end
    end
    local function conceal(obj)
        if not hidden[obj]then
            hidden[obj]={Transparency=obj.LocalTransparencyModifier,Shadow=obj.CastShadow,Decals={}}
        end
        local saved=hidden[obj]
        obj.LocalTransparencyModifier=1;obj.CastShadow=false
        for _,child in ipairs(obj:GetChildren())do
            if child:IsA("Decal")or child:IsA("Texture")then
                if saved.Decals[child]==nil then saved.Decals[child]=child.Transparency end
                child.Transparency=1
            end
        end
    end
    local function releaseRoot(root)
        local entry=roots[root];if not entry then return end
        roots[root]=nil;entry.Alive=false
        for _,c in ipairs(entry.Connections)do c:Disconnect()end
        for _,c in pairs(entry.Watched)do c:Disconnect()end
        for obj in pairs(entry.Parts)do restore(obj)end
    end
    local queueRoot
    local function refresh(root,entry)
        if not alive or not(grass or scenery)or roots[root]~=entry or root.Parent~=world then return end
        local token=generation
        local nodes={root}
        for _,obj in ipairs(root:GetDescendants())do nodes[#nodes+1]=obj end
        local protected={}
        local function protect(obj)
            local part,model,node=nil,nil,obj
            while node and node~=world do
                if not part and node:IsA("BasePart")then part=node end
                if node:IsA("Model")and(node~=root or obj:IsA("Humanoid")or obj:IsA("Tool"))then model=node;break end
                node=node.Parent
            end
            protected[model or part or obj]=true
        end
        local started=os.clock()
        for i,obj in ipairs(nodes)do
            if not alive or token~=generation or roots[root]~=entry then return end
            if obj:IsA("ProximityPrompt")or obj:IsA("ClickDetector")or obj:IsA("TouchTransmitter")
                or obj:IsA("Humanoid")or obj:IsA("Tool")or obj:IsA("Script")or obj:IsA("LocalScript")
                or obj:IsA("SurfaceGui")or obj:IsA("BillboardGui")then protect(obj)end
            if obj:IsA("BasePart")or obj:IsA("Model")then
                for name in pairs(identityAttributes)do
                    if obj:GetAttribute(name)~=nil then protect(obj);break end
                end
            end
            if i%64==0 and os.clock()-started>=0.001 then task.wait();started=os.clock()end
        end
        local previous=entry.Parts;local parts={}
        local function guarded(obj)
            local node=obj
            while node and node~=world do
                if protected[node]then return true end
                local lower=node.Name:lower()
                for _,word in ipairs(gameplayWords)do if lower:find(word,1,true)then return true end end
                -- Preserve structural models, even when some facade pieces have CanCollide off.
                if node:IsA("Model")or node:IsA("BasePart")then
                    for _,word in ipairs(structural)do if lower:find(word,1,true)then return true end end
                end
                node=node.Parent
            end
            return false
        end
        for i,obj in ipairs(nodes)do
            if not alive or token~=generation or roots[root]~=entry then return end
            if obj:IsA("BasePart")and obj:IsDescendantOf(world)then
                parts[obj]=true
                if not entry.Watched[obj]then
                    local function propertyChanged()
                        -- Reveal a newly solid object immediately; recompute its eligibility afterwards.
                        if obj.CanCollide then restore(obj)end
                        queueRoot(root)
                    end
                    local collision=obj:GetPropertyChangedSignal("CanCollide"):Connect(propertyChanged)
                    local anchored=obj:GetPropertyChangedSignal("Anchored"):Connect(propertyChanged)
                    local attributes=obj.AttributeChanged:Connect(function(name)
                        if identityAttributes[name]then restore(obj);queueRoot(root)end
                    end)
                    entry.Watched[obj]={Disconnect=function()collision:Disconnect();anchored:Disconnect();attributes:Disconnect()end}
                end
                local safe=not guarded(obj)
                if safe and((grass and isGrass(obj))or(scenery and obj.CanCollide==false and obj.Anchored))then conceal(obj)
                else restore(obj)end
            end
            if i%64==0 and os.clock()-started>=0.001 then task.wait();started=os.clock()end
        end
        for obj in pairs(previous)do if not parts[obj]then restore(obj)end end
        for obj,c in pairs(entry.Watched)do if not parts[obj]then c:Disconnect();entry.Watched[obj]=nil end end
        entry.Parts=parts
    end
    queueRoot=function(root)
        if not alive or not(grass or scenery)or not root or root.Parent~=world or excluded(root)then return end
        local entry=roots[root]
        if not entry then entry={Parts={},Watched={},Connections={},Alive=true};roots[root]=entry end
        entry.Dirty=true
        if entry.Queued then return end
        entry.Queued=true
        task.defer(function()
            while alive and roots[root]==entry and entry.Dirty and(grass or scenery)do
                entry.Dirty=false
                local ok,err=pcall(refresh,root,entry)
                if not ok then warn("[BeyyHub scenery] "..tostring(err))end
            end
            entry.Queued=false
        end)
    end
    local function disconnect()
        for _,c in ipairs(connections)do c:Disconnect()end;table.clear(connections)
        for root,entry in pairs(roots)do
            releaseRoot(root)
        end
        for obj in pairs(hidden)do restore(obj)end
    end
    local function changed()
        generation+=1
        if not(grass or scenery)then disconnect();return end
        if #connections==0 then
            connections[1]=world.DescendantAdded:Connect(function(obj)queueRoot(rootOf(obj))end)
            connections[2]=world.DescendantRemoving:Connect(function(obj)
                local root=rootOf(obj)
                -- Restore before an object can leave a decorative hierarchy for a gameplay one.
                restore(obj)
                if obj==root then
                    releaseRoot(root)
                else queueRoot(root)end
            end)
        end
        for _,root in ipairs(world:GetChildren())do queueRoot(root)end
    end
    function api.SetEnabled(value)
        value=alive and value==true;if grass==value then return end
        grass=value;changed()
    end
    function api.SetScenery(value)
        value=alive and value==true;if scenery==value then return end
        scenery=value;changed()
    end
    function api.Stop()
        if not alive then return end
        grass=false;scenery=false;alive=false;generation+=1;disconnect()
    end
    return api
end

        local visibility=createSceneryVisibility(game:GetService("Workspace"))
        local http=game:GetService("HttpService")
        local teleport=game:GetService("TeleportService")
        local path=CACHE_FOLDER.."/scenery_visibility.json"
        local teleportKey="BeyyHub_SceneryVisibility_v1"
        local preferences={HideDecorativeGrass=false,HideNonSolidScenery=false}
        local env=_G
        if type(getgenv)=="function"then local ok,value=pcall(getgenv);if ok and type(value)=="table"then env=value end end
        local function apply(data)
            if type(data)~="table"then return end
            data=data.__elements or data
            for key in pairs(preferences)do
                local value=data[key]
                if type(value)=="table"then value=value.value end
                if type(value)=="boolean"then preferences[key]=value end
            end
        end
        local function read(path)
            if type(readfile)~="function"then return nil end
            local ok,value=pcall(function()return http:JSONDecode(readfile(path))end)
            return ok and type(value)=="table"and value or nil
        end
        -- Migrate the existing Chapter 5 values, then prefer the shared visibility preferences.
        apply(read(CACHE_FOLDER.."/farming_inventory_shared.json"))
        apply(read(path));apply(env.__BEYY_SCENERY_PREFERENCES)
        local ok,packet=pcall(teleport.GetTeleportSetting,teleport,teleportKey)
        if ok then apply(packet)end
        local function persist()
            local copy={HideDecorativeGrass=preferences.HideDecorativeGrass,HideNonSolidScenery=preferences.HideNonSolidScenery}
            env.__BEYY_SCENERY_PREFERENCES=copy
            pcall(teleport.SetTeleportSetting,teleport,teleportKey,copy)
            if type(writefile)=="function"then pcall(function()writefile(path,http:JSONEncode(copy))end)end
        end
        for _,spec in ipairs({{"HideDecorativeGrass","Hide Decorative Grass","Hide decorative grass locally. Switch off to restore."},
            {"HideNonSolidScenery","Hide Non-Solid Scenery","Hide non-colliding scenery. Keep solid structures, detected interactions, characters and gameplay warnings visible."}})do
            local key=spec[1]
            registry[key]=tab:Toggle({Title=spec[2],Desc=spec[3],Value=preferences[key],Callback=function(value)
                if not isRunning()then return end
                preferences[key]=value==true;persist()
                if key=="HideDecorativeGrass"then visibility.SetEnabled(preferences[key])else visibility.SetScenery(preferences[key])end
            end})
        end
        visibility.SetEnabled(preferences.HideDecorativeGrass)
        visibility.SetScenery(preferences.HideNonSolidScenery)
        local previous=_G.__BEYY_HUB_CLEANUP
        _G.__BEYY_HUB_CLEANUP=function()
            visibility.Stop()
            if previous then pcall(previous)end
        end

    end)(MainTab,Registry,function()return not Unloaded end)
end

do
    local overview = MainTab
local function cutsceneResultsVisible()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ending = pg and pg:FindFirstChild("NeedleEndingUI")
    return ending and ending:IsA("ScreenGui") and ending.Enabled == true
end
local function shouldYieldCutsceneBypass()
    return Unloaded or not Window.Closed or needleHasPriority() or roundEndingVisible() or cutsceneResultsVisible()
end
local function setCutsceneBypassActive(value)
    if value then releaseAfkCamera() end
    cutsceneBypassActive = value
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
        local lastRenderTime = os.clock()

        local function log(s)
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
            if player:GetAttribute("IntroCutsceneFinished") == false then return nil end
            if introConfirmedAt and os.clock() - introConfirmedAt < INTRO_SETTLE_SECONDS then return nil end
            if yieldingToEnding then return nil end
            if player:GetAttribute("Chapter2ReleaseActive") == true then return "THREE PUZZLES" end
            if player:GetAttribute("CutsceneActive") == true then return "THREE LEVERS" end
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
        local function rememberGameplayHud()
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if not pg then return end
            for _, gui in ipairs(pg:GetChildren()) do
                if gui:IsA("ScreenGui") and SAFE_HUD_NAMES[gui.Name:lower()] then
                    local before = hudNormal[gui]
                    if not before or before.enabled ~= gui.Enabled or before.order ~= gui.DisplayOrder then
                        hudNormal[gui] = { enabled = gui.Enabled, order = gui.DisplayOrder }
                    end
                end
            end
        end
        local function showGameplayHud()
            if not hudEnabled then return end
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
            for btn in pairs(skipCandidates) do
                if not btn.Parent or not btn:IsDescendantOf(pg) then
                    skipCandidates[btn] = nil
                else
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
            local now = os.clock()
            if now - lastEndingSkipScan < 0.08 then return lastEndingSkipVisible end
            lastEndingSkipScan = now
            local pg = watchSkipGui()
            if not pg then lastEndingSkipVisible = false; return false end
            lastEndingSkipVisible = skipButtonVisible(pg)
            local endingUI = pg:FindFirstChild("NeedleEndingUI")
            local endingLikely = player:GetAttribute("NeedleOwned") == true
                or player:GetAttribute("CutsceneActive") == true
                or (endingUI and endingUI.Enabled == true)
            local fallbackEvery = endingLikely and 0.1 or 4
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
                if hum.WalkSpeed <= 0 and lastSavedSpeed then hum.WalkSpeed = lastSavedSpeed end
                if hum.JumpPower <= 0 and lastSavedJump then hum.JumpPower = lastSavedJump end
                if not faceCameraEnabled and lastSavedRotate ~= nil and hum.AutoRotate ~= lastSavedRotate then
                    hum.AutoRotate = lastSavedRotate
                end
            end
            local ctrl = getControls()
            if ctrl and ctrl.enabled == false then
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
                        log("Final cinematic: preserve normal viewing distance and hide cutscene visuals only; ending AutoSkip UI untouched")
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
            if alive and enabled and active and not yieldingToEnding and not shouldYieldCutsceneBypass() then
                handleCameraInput()
                forceCamera()
                alignCharacterFacing()
                directMovement()
                showGameplayHud()
                if scene then hideFinalCutsceneVisuals() end
            else
                lastRenderTime = os.clock()
            end
        end)
        local simulationSignal = RunService.PreSimulation or RunService.Heartbeat
        hook(simulationSignal:Connect(function()
            if alive and enabled and active and not yieldingToEnding and not shouldYieldCutsceneBypass() then directMovement() end
        end))

        local function stop()
            if not alive then return end
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
    shutdownCutsceneBypass()
    if previousCutsceneHubCleanup then pcall(previousCutsceneHubCleanup) end
end

    overview:Section({ Title = "Cutscenes" })
    Registry.CutsceneBypass = overview:Toggle({
        Title = "Unskippable Cutscene Bypass", Value = false,
        Desc = "Keep local camera and movement during flagged unskippable scenes. Server timers still apply; menus, intro/skip screens and automation take priority.",
        Callback = function(enabled)
            if enabled then
                if not launchCutsceneBypass() then warn("[BeyyHub] Cutscene bypass could not start") end
            else shutdownCutsceneBypass() end
        end,
    })
end

do
    -- Keep settings/configuration temporaries out of the module register budget.
    (function()
    Header(SettingsTab, "Menu")
    SettingsTab:Keybind({
        Title = "Menu keybind", Value = "RightControl",
        Callback = function(v)
            pcall(function()
                local key = typeof(v) == "EnumItem" and v or Enum.KeyCode[v]
                Window:SetToggleKey(key)
            end)
        end,
    })
    SettingsTab:Button({
        Title = "Unload",
        Callback = function() doUnload() end,
    })

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
                if success then
                    safeWrite(activeConfigPath, name)
                    local savedAFK = configAutoFarmValue(name)
                    if savedAFK ~= nil and not State.AutoFarmHay then
                        local element = Registry.AutoFarmWins
                        if element and type(element.Set) == "function" then
                            pcall(function() element:Set(savedAFK) end)
                        end
                        State.AutoFarmWins = savedAFK
                        saveAutoFarmPreference(savedAFK)
                    end
                end
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
                if success then
                    refreshConfigDropdown(name)
                    safeWrite(activeConfigPath, name)
                    local farmToggle = Registry.AutoFarmWins
                    local currentAFK = farmToggle and farmToggle.Value
                    if type(currentAFK) ~= "boolean" then currentAFK = State.AutoFarmWins end
                    State.AutoFarmWins = currentAFK == true and not State.AutoFarmHay
                    saveAutoFarmPreference(State.AutoFarmWins)
                    print("[BeyyHub] Saved AutoFarmWins=".. tostring(currentAFK == true) ..
                        " in config " .. name)
                end
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
            if Unloaded then return end
            local activeName = __beyyActiveConfigName()
            local ok, loaded, err = pcall(function() return buildConfig(activeName):Load() end)
            if (not ok or loaded == false or loaded == nil) and activeName ~= "default" then
                warn("[BeyyHub] Active config " .. activeName .. " unavailable; trying default")
                activeName = "default"
                ok, loaded, err = pcall(function() return buildConfig(activeName):Load() end)
            end
            if ok and loaded ~= false and loaded ~= nil then
                local raw = __beyyReadConfig(activeName)
                local parseOK, configData = pcall(function()
                    return game:GetService("HttpService"):JSONDecode(raw)
                end)
                print("[BeyyHub] Latest " .. activeName .. " config loaded synchronously")
            elseif containsConfig(getConfigNames(), activeName) then
                warn("[BeyyHub] Config auto-load failed: " .. tostring(ok and err or loaded))
            end
            task.wait(0.75)
            if Unloaded then return end
            -- Restore the latest manually/teleport-selected AFK state, not an
            -- older AutoFarmWins value auto-loaded from shared JSON.
            local persistedAFK = sharedAFKAtChapterEntry
            if persistedAFK == nil then persistedAFK = readTeleportAFK() end
            if persistedAFK == nil then persistedAFK = configAutoFarmValue(activeName) end
            if sharedHayAtChapterEntry then persistedAFK=false end
            if persistedAFK ~= nil then
                local element = Registry.AutoFarmWins
                if element and type(element.Set) == "function" then
                    local setOK, setErr = pcall(function() element:Set(persistedAFK) end)
                    if not setOK then warn("[BeyyHub] Restore AutoFarmWins toggle failed: ".. tostring(setErr)) end
                end
                State.AutoFarmWins = persistedAFK
                saveAutoFarmPreference(persistedAFK)
            end
            if sharedHayAtChapterEntry then
                local hayToggle=Registry.AutoFarmHay
                if hayToggle and not State.AutoFarmHay then
                    pcall(function() hayToggle:Set(true) end)
                end
                State.AutoFarmHay=true
            end
            restoringStartupAutoFarm = false
            print("[BeyyHub] Startup AutoFarmWins=".. tostring(State.AutoFarmWins) ..
                " (persisted=" .. tostring(persistedAFK) ..
                ", teleport=" .. tostring(readTeleportAFK()) ..
                ", config=" .. tostring(configAutoFarmValue(activeName)) .. ")")
        end)
    else
        restoringStartupAutoFarm = false
        if sharedAFKAtChapterEntry ~= nil then saveAutoFarmPreference(sharedAFKAtChapterEntry) end
    end
    end)()
end
return CollectingTab
end)()

task.spawn(function()
    while not Unloaded do
        task.wait(State.AutoFarmWins and 0.3 or (tonumber(State.CollectInterval) or 0.5))
        if Unloaded then break end
        if not IN_GAME then break end
        local findingNeedle = (State.AutoFindNeedle or State.AutoFarmWins) and LocalPlayer:GetAttribute("NeedleOwned") ~= true
            and findExposedNeedlePart() == nil
        if farmLoopEnabled() and (State.AutoPickHay or findingNeedle) and not isBagFull() then
            HayCache.ttl = 1.5
            local hay = findClosestHayCached()
            if hay then
                local id = hay:GetAttribute("HayId")
                if id then
                    local radiusHint = tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
                    local candidates = getGrabCandidates(hay, radiusHint)
                    if not needleHasPriority() then pcall(function() PickHay:FireServer(id, candidates) end) end
                else
                    if not needleHasPriority() then pcall(function() PickDroppedHay:FireServer(hay) end) end
                end
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(State.AutoFarmWins and 0.3 or (tonumber(State.CollectInterval) or 0.5))
        if Unloaded then break end
        if not IN_GAME then break end
        if farmLoopEnabled() and (State.AutoCollectDroppedHay or State.AutoFarmWins) and not isBagFull() then
            DroppedCache.ttl = 1.5
            local d = findClosestDroppedCached()
            if d then
                pcall(function() PickDroppedHay:FireServer(d) end)
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.CollectInterval) or 0.5)
        if Unloaded then break end
        if not IN_GAME then break end
        if farmLoopEnabled() and State.AutoCollectGems then
            GemsCache.ttl = 1.5
            local gemPart, id = findClosestGemCached()
            if gemPart and id then
                pcall(function() CollectGem:FireServer(id) end)
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(1)
        if Unloaded then break end
        if not IN_GAME then break end
        if farmLoopEnabled() and (State.AutoSellHay or State.AutoFarmWins) then
            local held = getHayHeld()
            local thresh = tonumber(State.SellThreshold) or 25
            if (State.AutoFarmWins and isBagFull())
                or (State.AutoSellHay and ((State.SellOnlyIfFull and isBagFull())
                or (not State.SellOnlyIfFull and held >= thresh))) then
                if held > 0 then trySell() end
            end
        end
    end
end)

local function findOrbitHayTarget(anchor)
    local folder = HayFolder
    if not folder or not folder.Parent then
        folder = Workspace:FindFirstChild("HaystackClient")
        HayFolder = folder
    end
    if not folder then return nil end
    local aimX = anchor.X + math.cos(afkOrbitAngle) * afkOrbitRadius * 0.82
    local aimZ = anchor.Z + math.sin(afkOrbitAngle) * afkOrbitRadius * 0.82
    local closest, bestScore = nil, math.huge
    for _, part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") and part:GetAttribute("HayId") ~= nil then
            local dx, dz = part.Position.X - anchor.X, part.Position.Z - anchor.Z
            local distFromCentre = math.sqrt(dx * dx + dz * dz)
            if distFromCentre > 3 and distFromCentre <= afkOrbitRadius * 1.45 then
                local aimDx, aimDz = part.Position.X - aimX, part.Position.Z - aimZ
                local score = aimDx * aimDx + aimDz * aimDz
                if score < bestScore then
                    closest = part
                    bestScore = score
                end
            end
        end
    end
    return closest
end
local function afkTntThrow(root, anchor)
    local origin = root.Position + Vector3.new(0, 1.5, 0)
    local hay = findOrbitHayTarget(anchor)
    local target = anchor + Vector3.new(math.cos(afkOrbitAngle) * afkOrbitRadius * 0.82, 1, math.sin(afkOrbitAngle) * afkOrbitRadius * 0.82)
    if hay and hay.Parent then
        target = hay.Position + Vector3.new(0, math.max(0.5, hay.Size.Y * 0.5), 0)
    end
    local displacement = target - origin
    if displacement.Magnitude < 1.5 then
        local look = root.CFrame.LookVector
        local planar = Vector3.new(look.X, 0, look.Z)
        if planar.Magnitude < 0.1 then planar = Vector3.new(0, 0, -1) end
        target = origin + planar.Unit * 4 + Vector3.new(0, -2, 0)
        displacement = target - origin
    end
    local up = math.abs(displacement.Unit:Dot(Vector3.yAxis)) > 0.97 and Vector3.zAxis or Vector3.yAxis
    local fromCharacter = CFrame.lookAt(origin, target, up)
    local travelSeconds = 0.45
    local throwVelocity = displacement / travelSeconds + Vector3.new(0, 0.5 * Workspace.Gravity * travelSeconds, 0)
    return fromCharacter, throwVelocity
end
do
(function()
local function createTntController(d)
    local state={nextLight=0}
    local stopped=false
    local function now() return d.now and d.now() or os.clock() end
    local function allowed() return not stopped and d.enabled() end
    local self={}
    function self:Stop() stopped=true;state.pending=nil;state.throwAt=nil end
    function self:GetState() return {pending=state.pending,throwAt=state.throwAt,nextLight=state.nextLight} end
    function self:Reply(kind,value)
        if stopped or not state.pending then return end
        local t=now()
        if kind=="lit" then
            state.pending=nil
            state.throwAt=t+math.max(0,tonumber(d.lightTime()) or 0.50)
            state.nextLight=t+math.max(0.5,tonumber(d.cooldown()) or 20)
        elseif kind=="denied" then
            state.pending=nil;state.throwAt=nil
            state.nextLight=t+math.max(0.25,tonumber(value) or 1)
        end
    end
    function self:Step()
        local t=now()
        if not allowed() then state.pending=nil;state.throwAt=nil;return end
        if state.pending then
            if t-state.pending>=2 then state.pending=nil end
            return
        end
        if state.throwAt then
            if t<state.throwAt then return end
            state.throwAt=nil
            if allowed() then pcall(d.throw) end
            return
        end
        if t<state.nextLight then return end
        state.pending=t
        state.nextLight=t+math.max(0.5,tonumber(d.cooldown()) or 20)
        local ok,sent=pcall(d.light)
        if not ok or sent==false then state.pending=nil;state.nextLight=t+1 end
    end
    return self
end
    local function canUse()
        if Unloaded or not IN_GAME or not farmLoopEnabled() or not (State.AutoUseTNT or State.AutoFarmWins)
            or not owns("TntOwned") or LocalPlayer:GetAttribute("NeedleInputLocked") then return false end
        if not afkFarmModeActive() then return getHRP()~=nil and Workspace.CurrentCamera~=nil end
        local root=getHRP()
        local target=afkPlayerAnchor or afkCameraAnchor
        local maxDistance=afkVacuumOrbitEnabled() and (afkOrbitRadius+9) or 10
        return root~=nil and target~=nil and afkHorizontalDistance(root.Position,target)<=maxDistance
    end
    local controller=createTntController({
        enabled=canUse,
        cooldown=function()
            local serverCooldown=tonumber(LocalPlayer:GetAttribute("TntCooldown"))
                or (GameConfig and tonumber(GameConfig.TNT_COOLDOWN)) or 20
            return math.max(0.5, serverCooldown, tonumber(State.TntLightCooldown) or 0)
        end,
        lightTime=function() return tonumber(State.TntThrowDelay) or 0.5 end,
        light=function() return pcall(function() TntAction:FireServer("light") end) end,
        throw=function()
            if not canUse() then return end
            if afkFarmModeActive() then
                local root=getHRP()
                local target=afkPlayerAnchor or afkCameraAnchor
                if root and target then local cf,velocity=afkTntThrow(root,target);TntAction:FireServer("throw",cf,velocity) end
            else
                local camera=Workspace.CurrentCamera
                if camera then TntAction:FireServer("throw",camera.CFrame,camera.CFrame.LookVector*40+Vector3.new(0,8,0)) end
            end
        end,
    })
    local connection=TntAction.OnClientEvent:Connect(function(kind,value) controller:Reply(kind,value) end)
    local previousCleanup=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        controller:Stop();connection:Disconnect()
        if previousCleanup then pcall(previousCleanup) end
    end
    task.spawn(function()
        while not Unloaded do
            task.wait(0.05)
            if Unloaded then break end
            controller:Step()
        end
    end)
end)()
end

do
(function()
    local nextDig=0
    task.spawn(function()
        while not Unloaded do
            task.wait(0.05)
            if Unloaded then break end
            if IN_GAME and farmLoopEnabled() and (State.AutoUsePitchfork or State.AutoFarmWins) and owns("PitchforkOwned")
                and os.clock()>=nextDig then
                local hay=findClosestHayCached()
                local root=getHRP()
                local id=hay and hay:GetAttribute("HayId")
                local reach=tonumber(LocalPlayer:GetAttribute("PitchforkReach")) or 4.2
                if id and root and (hay.Position-root.Position).Magnitude<=reach+hay.Size.Magnitude*0.5 then
                    nextDig=os.clock()+math.max(0.1,tonumber(LocalPlayer:GetAttribute("PitchforkCooldown")) or tonumber(State.ToolInterval) or 0.5)
                    if not Unloaded and not needleHasPriority() then pcall(function() PitchforkDig:FireServer(id) end) end
                end
            end
        end
    end)
end)()
end

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.ToolInterval) or 0.5)
        if Unloaded then break end
        if not IN_GAME then break end
        if farmLoopEnabled() and (State.AutoDeployDrone or State.AutoFarmWins) and owns("DroneOwned") then
            if not LocalPlayer:GetAttribute("DroneDeployed") then
                pcall(function() DeployDrone:FireServer() end)
            end
        end
    end
end)

do
    -- Scope-isolate existing vacuum controller locals (Luau 200-local limit).
    -- Executes synchronously and retains the original controller body.
    (function()
    local HEAT_FULL = 1.0
    local HEAT_EMPTY = 0.001
    local HEAT_STALLED_SECONDS = 4.0
    local COOLDOWN_SAFETY = 0.5
    local RUNTIME_FALLBACK_EXTRA = 1.0
    local held = false
    local ownsInputLock = false
    local mouseX, mouseY = 0, 0
    local wasEnabled = false
    local coolingPending = false
    local readyAt = 0
    local cycle = 0
    local lastStallWarning = -math.huge
    local HOTBAR_KEYS = {
        Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
        Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
        Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
    }

    local function getUpgradeLevel(name)
        local raw = tonumber(LocalPlayer:GetAttribute("HayUpgrade" .. name))
        return math.max(0, math.floor(raw or 0))
    end

    local function getVacuumTimings()
        local runtimeLevel = getUpgradeLevel("VacuumRuntime")
        local coolingLevel = getUpgradeLevel("VacuumCooling")
        local runtimeSeconds = 30 + 3 * runtimeLevel
        local coolingSeconds = coolingLevel == 0 and 13 or math.max(7, 12 - coolingLevel)
        runtimeSeconds = tonumber(LocalPlayer:GetAttribute("VacuumHeatTime")) or runtimeSeconds
        coolingSeconds = tonumber(LocalPlayer:GetAttribute("VacuumCoolTime")) or coolingSeconds
        return math.max(0.1, runtimeSeconds), math.max(0.1, coolingSeconds), runtimeLevel, coolingLevel
    end

    local function readHeat()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local hud = playerGui and playerGui:FindFirstChild("HUD")
        local overheat = hud and hud:FindFirstChild("Overheat")
        local fill = overheat and overheat:FindFirstChild("Fill")
        local raw = tonumber(LocalPlayer:GetAttribute("VacuumHeat"))
        if raw and raw == raw and raw >= 0 and raw <= 1 then
            return raw, fill and fill:IsA("GuiObject") and fill or nil
        end
        if not fill or not fill:IsA("GuiObject") then return nil, nil end
        local value = fill.Size.Y.Scale
        if type(value) ~= "number" or value ~= value or value < -0.05 or value > 1.05 then
            return nil, nil
        end
        return math.clamp(value, 0, 1), fill
    end

    local function mousePoint()
        local camera = Workspace.CurrentCamera
        if not camera then return nil end
        local screen = camera.ViewportSize
        if screen.X <= 0 or screen.Y <= 0 then return nil end
        return screen.X / 2, screen.Y / 2
    end

    local function releaseVacuum()
        if held then
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 0)
            end)
            held = false
        end
        if ownsInputLock then
            autoUiMouseBusy = false
            ownsInputLock = false
        end
        vacuumSuctionActive = false
    end
    releaseWinVacuumForReplay = releaseVacuum

    local previousCleanup = _G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP = function()
        releaseVacuum()
        if previousCleanup then pcall(previousCleanup) end
    end

    local function mustReleaseForPriority()
        return Unloaded or not IN_GAME or not vacuumRequested() or not Window.Closed
            or introSkipPending or needleHasPriority() or roundEndingVisible() or needlePickupActive
            or LocalPlayer:GetAttribute("NeedleInputLocked") == true
            or getHRP() == nil or Workspace.CurrentCamera == nil
    end

    local function canVacuum()
        return not mustReleaseForPriority()
            and (State.AutoFarmHay and not State.HayFarmCleared and State.HayFarmTargetReady
                or (not State.AutoFarmHay and (not afkVacuumOrbitEnabled() or afkVacuumTargetReady)))
    end

    local function equipVacuum()
        local character = LocalPlayer.Character
        if not character then return false end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local vacuumTool = nil
        for _, container in ipairs({character, backpack}) do
            if container then
                for _, obj in ipairs(container:GetChildren()) do
                    if obj:IsA("Tool") and obj.Name:lower():find("vacuum", 1, true) then
                        vacuumTool = obj
                        break
                    end
                end
            end
            if vacuumTool then break end
        end
        if vacuumTool and vacuumTool.Parent == character then return true end

        local slot = math.clamp(math.floor(tonumber(State.VacuumHotbarSlot) or 5), 1, 9)
        local key = HOTBAR_KEYS[slot]
        local downOK, downErr = pcall(function()
            VirtualInputManager:SendKeyEvent(true, key, false, game)
        end)
        task.wait(0.07)
        local upOK, upErr = pcall(function()
            VirtualInputManager:SendKeyEvent(false, key, false, game)
        end)
        if not downOK or not upOK then
            warn("[Vacuum] Hotbar slot " .. tostring(slot) .. " input failed: " .. tostring(downOK and upErr or downErr))
            return false
        end
        if not canVacuum() then return false end
        task.wait(0.20)
        if not canVacuum() then return false end

        if vacuumTool and vacuumTool.Parent == backpack then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return false end
            local ok = pcall(function() humanoid:EquipTool(vacuumTool) end)
            if not ok then return false end
            task.wait(0.08)
        end
        return canVacuum()
    end

    task.spawn(function()
        while not Unloaded do
            task.wait(0.06)
        if Unloaded then break end
            if not IN_GAME then break end
            if not vacuumRequested() then
                releaseVacuum()
                wasEnabled = false
            else
                local runtime, cooling, runtimeLevel, coolingLevel = getVacuumTimings()
                local heat, heatFill = readHeat()
                if not wasEnabled then
                    wasEnabled = true

                    if heat == nil then
                        readyAt = os.clock() + cooling + COOLDOWN_SAFETY
                    end
                    print(string.format("[Vacuum] Heat HUD %s; Runtime L%d %.0fs / Cooling L%d %.0fs (fallback timings)",
                        heat ~= nil and "found (live control)" or "missing (timed fallback)",
                        runtimeLevel, runtime, coolingLevel, cooling))
                end

                if LocalPlayer:GetAttribute("VacuumState")=="Overheated" or (heat and heat >= HEAT_FULL) then
                    if not coolingPending then readyAt = os.clock() + cooling + COOLDOWN_SAFETY end
                    coolingPending = true
                end
                if coolingPending then
                    releaseVacuum()
                    if heat ~= nil then
                        if heat <= HEAT_EMPTY then
                            coolingPending = false
                            readyAt = 0
                            print("[Vacuum] Heat returned to 0%; ready to resume suction")
                        end
                    elseif os.clock() >= readyAt then

                        coolingPending = false
                        print("[Vacuum] Heat HUD missing; fallback cooldown completed")
                    end
                elseif os.clock() >= readyAt and canVacuum() and not autoUiMouseBusy then

                    if heat ~= nil and heat > HEAT_EMPTY then
                        task.wait(0.15)
                        local laterHeat = readHeat()
                        if laterHeat and laterHeat < heat - 0.001 then
                            coolingPending = true
                            print("[Vacuum] Existing cooldown detected; waiting for heat to reach 0%")
                        end
                    end
                    if not coolingPending and canVacuum() and not autoUiMouseBusy then
                        cycle += 1
                        vacuumSuctionActive = true
                        autoUiMouseBusy = true
                        ownsInputLock = true
                        local didHold, reachedFull, hadLiveHeat = false, false, false
                        local sizeConnection = nil
                        local success, err = xpcall(function()
                            if not canVacuum() or not equipVacuum() then return end
                            if not canVacuum() then return end
                            runtime, cooling, runtimeLevel, coolingLevel = getVacuumTimings()
                            local x, y = mousePoint()
                            if not x then return end
                            mouseX, mouseY = x, y

                            local startHeat, activeFill = readHeat()
                            hadLiveHeat = startHeat ~= nil
                            if startHeat and startHeat >= HEAT_FULL then
                                reachedFull = true
                                return
                            end
                            if activeFill then
                                local previousValue = startHeat
                                sizeConnection = activeFill:GetPropertyChangedSignal("Size"):Connect(function()
                                    local current = readHeat()
                                    if current == nil then return end

                                    if current >= HEAT_FULL or (previousValue and previousValue >= 0.95 and current < previousValue - 0.15) then
                                        reachedFull = true
                                        releaseVacuum()
                                    end
                                    previousValue = current
                                end)
                            end
                            local pressed = pcall(function()
                                VirtualInputManager:SendMouseMoveEvent(x, y, game)
                                VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
                            end)
                            if not pressed then return end
                            held = true
                            didHold = true
                            print(string.format("[Vacuum] Cycle %d: holding Mouse1 to 100%% heat (Runtime L%d)", cycle, runtimeLevel))

                            local started = os.clock()
                            local lastHeat = startHeat
                            local lastRisingAt = started

                            local fallbackDeadline = started + runtime + RUNTIME_FALLBACK_EXTRA
                            while held and not reachedFull and not mustReleaseForPriority() do
                                if LocalPlayer:GetAttribute("VacuumState")=="Overheated" then reachedFull=true;break end
                                local current, newFill = readHeat()
                                if current ~= nil then
                                    hadLiveHeat = true
                                    if current >= HEAT_FULL
                                        or (lastHeat and lastHeat >= 0.95 and current < lastHeat - 0.15) then
                                        reachedFull = true
                                        break
                                    end
                                    if lastHeat == nil or current > lastHeat + 0.0002 then
                                        lastRisingAt = os.clock()
                                    end
                                    lastHeat = current

                                    if os.clock() - lastRisingAt > HEAT_STALLED_SECONDS then
                                        if os.clock() - lastStallWarning > 30 then
                                            lastStallWarning = os.clock()
                                            warn("[Vacuum] Heat not increasing; releasing Mouse1 and retrying equip (not cooling)")
                                        end
                                        break
                                    end
                                elseif os.clock() >= fallbackDeadline then
                                    reachedFull = true
                                    break
                                end
                                task.wait(0.04)
                            end
                        end, function(e) return tostring(e) end)
                        if sizeConnection then sizeConnection:Disconnect() end
                        releaseVacuum()
                        if not success then warn("[Vacuum] Controller error: " .. tostring(err)) end
                        if reachedFull then
                            coolingPending = true
                            readyAt = os.clock() + cooling + COOLDOWN_SAFETY
                            if hadLiveHeat then
                                print(string.format("[Vacuum] Reached 100%% heat; Mouse1 released. Waiting for bar to reach 0%% (Cooling L%d)", coolingLevel))
                            else
                                print(string.format("[Vacuum] No heat HUD; timed fallback cooldown %.2fs", cooling + COOLDOWN_SAFETY))
                            end
                        elseif didHold then

                            readyAt = os.clock() + 0.3
                            print("[Vacuum] Suction interrupted below 100%; will resume from current heat")
                        else
                            readyAt = os.clock() + 1.0
                        end
                    end
                end
            end
        end
        releaseVacuum()
    end)
    end)()

end

do
    -- Scope-isolate the existing needle pickup callback locals (Luau 200-local limit).
    -- Executes synchronously and retains the original controller body.
    (function()
    local SETTINGS = { HeightAboveNeedle = 2.5, HorizontalOffsetStuds = 2.0, MaxClicks = 8, MousePressSeconds = 0.085, OwnershipWaitSeconds = 0.055, RetryDelay = 0.16,
        FilterRadiusPixels = 50, FilterNeedleRadiusStuds = 8, FilterMaxParts = 400 }
    local busy = false
    local lastAttempt = -math.huge
    local trackedNeedle = nil
    local confirmedNeedlePart, confirmedNeedleId = nil, nil
    local activeCleanup = nil
    local renderName = "BeyyV103_00NeedleAimHover_" .. tostring(LocalPlayer.UserId)
    local lastPrerequisiteWarnAt = -math.huge
    local lastPickupFailureWarnAt = -math.huge
    local function reportPrerequisite(reason)
        if os.clock() - lastPrerequisiteWarnAt >= 30 then
            lastPrerequisiteWarnAt = os.clock()
            warn("[Needle] Pickup waiting: " .. reason .. " (retrying automatically; warnings limited to once every 30s)")
        end
    end
    local function owned() return LocalPlayer:GetAttribute("NeedleOwned") == true end
    local function tryPickup(needle)
        if busy or Unloaded or roundEndingVisible() or not (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) or owned() or not needle or not needle.Parent then return false end
        busy = true
        needlePickupActive = true
        local started = os.clock()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local cam = Workspace.CurrentCamera
        local needleId = needle:GetAttribute("HayId")
        if not char or not char.Parent or not root or not root.Parent then
            reportPrerequisite("character or HumanoidRootPart unavailable")
            busy = false
            needlePickupActive = false
            return false
        end
        if not cam then
            reportPrerequisite("Workspace.CurrentCamera unavailable")
            busy = false
            needlePickupActive = false
            return false
        end
        if type(needleId) ~= "number" and needle:GetAttribute("IsNeedleObjective") ~= true then
            reportPrerequisite("needle HayId invalid (type=" .. type(needleId) .. "); refreshing target")
            trackedNeedle = nil
            busy = false
            needlePickupActive = false
            return false
        end
        local initialPivot = char:GetPivot()
        local originalHover = LocalPlayer:GetAttribute("HoveredHayId")
        local previousPickupCameraType, previousPickupCameraSubject, previousPickupCameraCFrame
        local pickupCameraCaptured = false
        local mouseDown, bound, cleaned, success = false, false, false, false
        local observedOwnership = false
        local clicks = 0
        local filteredParts = {}
        local queryStats = { filtered = 0 }
        local failureReason = "No NeedleOwned confirmation"
        local function restoreQueryFilter()
            for part, previous in pairs(filteredParts) do
                local ok = pcall(function()
                    if part.Parent then
                        part.CanQuery = previous.query
                        part.CanCollide = previous.collide
                    end
                end)
                filteredParts[part] = nil
            end
        end
        local function applyQueryFilter()
            local activeCamera = Workspace.CurrentCamera
            if not activeCamera or not needle.Parent then return end
            local screenSize = activeCamera.ViewportSize
            if screenSize.Y <= 0 then return end
            local middle = screenSize / 2
            local projectedNeedle = activeCamera:WorldToViewportPoint(needle.Position)
            local focalLength = screenSize.Y / (2 * math.tan(math.rad(activeCamera.FieldOfView / 2)))

            for pass = 1, 2 do
                if queryStats.filtered >= SETTINGS.FilterMaxParts then break end
                for _, folderName in ipairs({"HaystackClient", "HaystackCollision"}) do
                    local folder = Workspace:FindFirstChild(folderName)
                    if folder then
                        for _, part in ipairs(folder:GetDescendants()) do
                            if queryStats.filtered >= SETTINGS.FilterMaxParts then break end
                            if Unloaded or not (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) or observedOwnership then return end
                            if part:IsA("BasePart") and part ~= needle
                                and part:GetAttribute("IsNeedleObjective") ~= true
                                and part.CanQuery and not filteredParts[part] then
                                local nearNeedle = (part.Position - needle.Position).Magnitude
                                    <= SETTINGS.FilterNeedleRadiusStuds + math.min(part.Size.Magnitude * 0.5, 4)
                                local qualifies = (pass == 1 and nearNeedle)
                                if pass == 2 and not nearNeedle then
                                    local screen = activeCamera:WorldToViewportPoint(part.Position)
                                    if screen.Z > 0 and screen.Z < 45 then
                                        local radius = (part.Size.Magnitude * 0.5) * focalLength / screen.Z
                                        local distanceFromClick = (Vector2.new(screen.X, screen.Y) - middle).Magnitude
                                        local distanceFromNeedle = (Vector2.new(screen.X, screen.Y)
                                            - Vector2.new(projectedNeedle.X, projectedNeedle.Y)).Magnitude
                                        qualifies = distanceFromClick <= SETTINGS.FilterRadiusPixels + radius
                                            or (projectedNeedle.Z > 0 and distanceFromNeedle <= SETTINGS.FilterRadiusPixels + radius)
                                    end
                                end
                                if qualifies then
                                    local originalQuery, originalCollide = part.CanQuery, part.CanCollide
                                    local ok = pcall(function()
                                        if part.CanCollide then part.CanCollide = false end
                                        part.CanQuery = false
                                    end)
                                    if ok and not part.CanQuery then
                                        filteredParts[part] = { query = originalQuery, collide = originalCollide }
                                        queryStats.filtered += 1
                                    else
                                        pcall(function()
                                            part.CanQuery = originalQuery
                                            part.CanCollide = originalCollide
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local ownershipConnection
        local function captureOwnership()
            if not observedOwnership and owned() then
                observedOwnership = true
            end
        end
        ownershipConnection = LocalPlayer:GetAttributeChangedSignal("NeedleOwned"):Connect(captureOwnership)
        captureOwnership()
        local function releaseMouse()
            if not mouseDown then return end
            local center = cam.ViewportSize / 2
            pcall(function() VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0) end)
            mouseDown = false
        end
        local function waitForConfirmation(seconds)
            local deadline = os.clock() + seconds
            while not Unloaded and (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) and os.clock() < deadline do
                captureOwnership()
                if observedOwnership then return true end
                task.wait(0.025)
            end
            captureOwnership()
            return observedOwnership
        end
        local function cleanup()
            if cleaned then return end
            cleaned = true
            releaseMouse()
            if bound then
                pcall(function() RunService:UnbindFromRenderStep(renderName) end)
                bound = false
            end
            if pickupCameraCaptured and cam.Parent then
                pcall(function()

                    local restoreType = afkFarmModeActive() and Enum.CameraType.Custom
                        or previousPickupCameraType or Enum.CameraType.Custom
                    cam.CameraType = restoreType
                    if previousPickupCameraSubject and previousPickupCameraSubject.Parent then
                        cam.CameraSubject = previousPickupCameraSubject
                    else
                        local humanoid = char:FindFirstChildOfClass("Humanoid")
                        if humanoid then cam.CameraSubject = humanoid end
                    end
                    if restoreType == Enum.CameraType.Scriptable and previousPickupCameraCFrame then
                        cam.CFrame = previousPickupCameraCFrame
                    end
                end)
            end
            if ownershipConnection then
                ownershipConnection:Disconnect()
                ownershipConnection = nil
            end
            restoreQueryFilter()
            captureOwnership()
            success = success or observedOwnership
            pcall(function()
                if LocalPlayer:GetAttribute("HoveredHayId") == needleId then
                    LocalPlayer:SetAttribute("HoveredHayId", originalHover)
                end
            end)
            if success then
                confirmedNeedlePart, confirmedNeedleId = needle, needleId
            elseif char.Parent then
                pcall(function() char:PivotTo(initialPivot) end)
            end
            local elapsed = os.clock() - started
            if success then
                print(string.format("[Needle] Picked up HayId=%s in %.2fs (%d clicks)",
                    tostring(needleId), elapsed, clicks))
            elseif os.clock() - lastPickupFailureWarnAt >= 2 then
                lastPickupFailureWarnAt = os.clock()
                warn(string.format("[Needle] Pickup unconfirmed HayId=%s after %.2fs: %s (%d clicks); retrying",
                    tostring(needleId), elapsed, tostring(failureReason), clicks))
            end
            activeCleanup = nil
            busy = false
            needlePickupActive = false
            lastAttempt = os.clock()
        end
        activeCleanup = cleanup
        local ok, err = xpcall(function()

            if afkFarmModeActive() then enterNeedleCamera() end
            previousPickupCameraType = cam.CameraType
            previousPickupCameraSubject = cam.CameraSubject
            previousPickupCameraCFrame = cam.CFrame
            pickupCameraCaptured = true
            local inputDeadline = os.clock() + 0.8
            while autoUiMouseBusy and os.clock() < inputDeadline and not Unloaded do task.wait(0.01) end
            if autoUiMouseBusy then failureReason = "UI click still owns mouse"; return end
            if Unloaded or not (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) then failureReason = "Pickup cancelled before teleport"; return end
            local rootToPivot = root.CFrame:ToObjectSpace(char:GetPivot())

            local cameraForward = cam.CFrame.LookVector
            local horizontalForward = Vector3.new(cameraForward.X, 0, cameraForward.Z)
            if horizontalForward.Magnitude < 0.05 then
                local rootForward = root.CFrame.LookVector
                horizontalForward = Vector3.new(rootForward.X, 0, rootForward.Z)
            end
            if horizontalForward.Magnitude < 0.05 then
                horizontalForward = Vector3.new(0, 0, -1)
            end
            horizontalForward = horizontalForward.Unit
            local targetRootPosition = needle.Position - horizontalForward * SETTINGS.HorizontalOffsetStuds
                + Vector3.new(0, SETTINGS.HeightAboveNeedle, 0)
            local intendedDistance = (targetRootPosition - needle.Position).Magnitude
            local correctionLimit = intendedDistance + 0.35
            local retryLimit = intendedDistance + 0.80
            local function placeNearNeedle()

                local lookTarget = Vector3.new(needle.Position.X, targetRootPosition.Y, needle.Position.Z)
                local targetRoot = CFrame.lookAt(targetRootPosition, lookTarget)
                char:PivotTo(targetRoot * rootToPivot)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end

            -- Use the native objective protocol first; preserve click pickup as fallback.
            placeNearNeedle()
            task.wait(0.20)
            if Unloaded or not (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) or roundEndingVisible() or not needle.Parent then
                failureReason = "Pickup cancelled before native request"; return
            end
            captureOwnership()
            if observedOwnership then success = true; return end
            local pickupRemote = PickHay
            if pickupRemote then
                local sent = pcall(function() pickupRemote:FireServer("Objective") end)
                if sent and waitForConfirmation(0.50) then
                    success = true
                    return
                end
            end

            local cameraPosition = targetRootPosition - horizontalForward * 3.5
                + Vector3.new(0, 3.5, 0)
            local function aimAtNeedle()
                if Unloaded or not needle.Parent or observedOwnership or roundEndingVisible() then return end
                if Workspace.CurrentCamera ~= cam then return end
                cam.CameraType = Enum.CameraType.Scriptable
                cam.CFrame = CFrame.lookAt(cameraPosition, needle.Position, Vector3.yAxis)
            end
            placeNearNeedle()
            captureOwnership()
            if observedOwnership then success = true; return end
            local function forceHover()
                if not Unloaded and (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) and needle.Parent and not observedOwnership then
                    aimAtNeedle()
                    if LocalPlayer:GetAttribute("HoveredHayId") ~= needleId then
                        LocalPlayer:SetAttribute("HoveredHayId", needleId)
                    end
                end
            end
            LocalPlayer:SetAttribute("HoveredHayId", needleId)
            aimAtNeedle()
            RunService:BindToRenderStep(renderName, Enum.RenderPriority.Last.Value + 30, forceHover)
            bound = true
            RunService.RenderStepped:Wait()
            applyQueryFilter()

            RunService.RenderStepped:Wait()
            for i = 1, SETTINGS.MaxClicks do
                captureOwnership()
                if observedOwnership then success = true; break end
                if Unloaded or not (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) or roundEndingVisible() then failureReason = "Pickup cancelled at round end"; break end
                if not needle.Parent then failureReason = "Needle disappeared before confirmation"; break end
                if not char.Parent or not root.Parent then failureReason = "Character disappeared"; break end
                local distance = (root.Position - needle.Position).Magnitude
                if distance > correctionLimit then
                    placeNearNeedle()
                    distance = (root.Position - needle.Position).Magnitude
                end
                if distance > retryLimit then
                    failureReason = string.format("Root drifted beyond diagonal target (%.2f studs; target %.2f)", distance, intendedDistance)
                    break
                end
                forceHover()

                local center = cam.ViewportSize / 2
                pcall(function() VirtualInputManager:SendMouseMoveEvent(center.X, center.Y, game) end)
                RunService.RenderStepped:Wait()
                forceHover()
                local hoverMatches = LocalPlayer:GetAttribute("HoveredHayId") == needleId
                local projectedNeedle, onScreen = cam:WorldToViewportPoint(needle.Position)
                local screenOffset = onScreen and (Vector2.new(projectedNeedle.X, projectedNeedle.Y) - center).Magnitude or -1
                if not hoverMatches then
                    LocalPlayer:SetAttribute("HoveredHayId", needleId)
                    RunService.RenderStepped:Wait()
                    forceHover()
                    hoverMatches = LocalPlayer:GetAttribute("HoveredHayId") == needleId
                end
                if not hoverMatches then
                    failureReason = "HoveredHayId temporarily lost; re-aiming"
                    if i < SETTINGS.MaxClicks then continue end
                    break
                end
                if not onScreen or screenOffset > 15 then
                    failureReason = "Needle camera off-centre; re-aiming"
                    if i < SETTINGS.MaxClicks then
                        placeNearNeedle()
                        RunService.RenderStepped:Wait()
                        forceHover()
                        continue
                    end
                    break
                end
                local pressed, pressErr = pcall(function()
                    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                end)
                if not pressed then failureReason = "VIM press failed: " .. tostring(pressErr); break end
                clicks += 1
                mouseDown = true
                task.wait(i <= 2 and SETTINGS.MousePressSeconds or 0.10)
                releaseMouse()
                if waitForConfirmation(i <= 2 and SETTINGS.OwnershipWaitSeconds or 0.10) then success = true; break end
                if i == 4 then applyQueryFilter() end
            end
            captureOwnership()
            success = success or observedOwnership
        end, function(e) return tostring(e) end)
        if not ok then failureReason = "Runtime error: " .. tostring(err) end
        cleanup()
        return success
    end
    local previousCleanup = _G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP = function()
        if previousCleanup then pcall(previousCleanup) end
        if activeCleanup then pcall(activeCleanup) end
        pcall(function() RunService:UnbindFromRenderStep(renderName) end)
    end
    task.spawn(function()
        while not Unloaded do
            task.wait(0.05)
        if Unloaded then break end
            if not IN_GAME or roundEndingVisible() or not (State.AutoPickupNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) or owned() then
                trackedNeedle = nil
            else
                if not trackedNeedle or not trackedNeedle.Parent
                    or (trackedNeedle:GetAttribute("HIDDEN_WITHIN") ~= nil
                        and trackedNeedle:GetAttribute("HIDDEN_WITHIN") ~= false)
                    or trackedNeedle:GetAttribute("IsNeedleObjective") ~= true
                    then
                    trackedNeedle = findExposedNeedlePart()
                end
                if trackedNeedle and trackedNeedle == confirmedNeedlePart
                    and trackedNeedle:GetAttribute("HayId") == confirmedNeedleId then
                    continue
                end
                if trackedNeedle and not busy and (os.clock() - lastAttempt) >= (tonumber(State.NeedleInterval) or SETTINGS.RetryDelay) then
                    lastAttempt = os.clock()
                    local target = trackedNeedle
                    task.spawn(function() tryPickup(target) end)
                end
            end
        end
    end)
    end)()

end

do
(function()
    local nextRequest=0
    local settleUntil=0
    local positioned=false
    local character
    local connection=RunService.Heartbeat:Connect(function()
        if Unloaded or not IN_GAME then return end
        if not (State.AutoHandInNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) or needlePickupActive or roundEndingVisible() then return end
        if LocalPlayer:GetAttribute("NeedleOwned")~=true then nextRequest=0;settleUntil=0;positioned=false;character=nil;return end
        local root=getHRP()
        local npc=Workspace:FindFirstChild("NPC")
        local farmer=npc and npc:FindFirstChild("Farmer_NPC")
        if not root or not farmer then return end
        if character~=LocalPlayer.Character then character=LocalPlayer.Character;positioned=false end
        local t=os.clock()
        if not positioned or (root.Position-farmer:GetPivot().Position).Magnitude>8 then
            root.CFrame=farmer:GetPivot()*CFrame.new(0,0,4)
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
            positioned=true;settleUntil=t+0.20
            return
        end
        if t<settleUntil or t<nextRequest then return end
        nextRequest=t+0.25
        if not Unloaded and (State.AutoHandInNeedle or State.AutoFarmWins or (State.AutoFarmHay and State.HayFarmCleared)) and LocalPlayer:GetAttribute("NeedleOwned")==true then
            pcall(function() NeedleHandIn:FireServer() end)
        end
    end)
    local previousCleanup=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        connection:Disconnect()
        if previousCleanup then pcall(previousCleanup) end
    end
end)()
end

-- Chapter 4 uses explicit upgrade toggles. Preserve Chapter 1's existing
-- Auto Farm Hay upgrade-all mode, while preventing a separate shop purchase
-- worker from racing the confirmed-purchase upgrade queue.
local function chapter1AutoHayUpgradeAll()
    return State.AutoFarmHay==true and not State.HayFarmCleared
        and Window.Closed and not roundEndingVisible()
end
local function shopCapacitySelected()
    if not State.AutoBuyTools then return false end
    local selected=State.BuyToolsList
    if type(selected)~="table" then return false end
    for key,value in pairs(selected) do
        if (type(key)=="number" and value=="Capacity Bag")
            or (key=="Capacity Bag" and value==true) then return true end
    end
    return false
end
local upgradeState=setmetatable({}, {__index=function(_,flag)
    return State[flag]==true or State.AutoFarmWins==true or chapter1AutoHayUpgradeAll()
        or (flag=="UpgCapacity" and shopCapacitySelected())
end})
local vacuumUpgradePriority=createVacuumUpgradePriority(
    upgradeState,
    function()return GameConfig end,
    getCash,
    function(name)return tonumber(LocalPlayer:GetAttribute("HayUpgrade"..name)) or 1 end,
    function(name)
        if not BuyUpgrade then return false end
        return pcall(function()BuyUpgrade:FireServer(name)end)
    end
)

task.spawn(function()
    while not Unloaded do
        task.wait(State.AutoFarmWins and 1 or math.max(0.5,tonumber(State.BuyInterval) or 1))
        if Unloaded then break end
        if not IN_GAME then break end
        if State.AutoFarmWins and Window.Closed and not roundEndingVisible() then
            -- Match the standalone Wins preset without modifying BuyToolsList.
            for _,tool in ipairs({
                {name="Pitchfork",owned="PitchforkOwned"},
                {name="Tnt",owned="TntOwned"},
                {name="Drone",owned="DroneOwned"},
                {name="Vacuum",owned="VacuumOwned"},
            }) do
                if not owns(tool.owned) then
                    pcall(function() BuyShopItem:FireServer(tool.name) end)
                end
            end
        elseif State.AutoBuyTools and not vacuumUpgradePriority.Reserve() then
            local sel = State.BuyToolsList or {}
            local list = {}
            if type(sel) == "table" then
                for k, v in pairs(sel) do
                    if type(k) == "number" then
                        if type(v) == "string" then table.insert(list, v) end
                    elseif v then table.insert(list, k) end
                end
            end
            for _, name in ipairs(list) do
                if vacuumUpgradePriority.Reserve() then break end
                if name == "Pitchfork" and not owns("PitchforkOwned") then
                    pcall(function() BuyShopItem:FireServer("Pitchfork") end)
                elseif name == "TNT" and not owns("TntOwned") then
                    pcall(function() BuyShopItem:FireServer("Tnt") end)
                elseif name == "Drone" and not owns("DroneOwned") then
                    pcall(function() BuyShopItem:FireServer("Drone") end)
                elseif name == "Infinite Bag" and not owns("InfiniteBagOwned") then
                    pcall(function() BuyShopItem:FireServer("InfiniteBag") end)
                elseif name == "Capacity Bag" then
                    -- The central upgrade worker now buys Capacity; this shop
                    -- worker must not send duplicate requests for that level.
                end
            end
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(math.max(0.5,tonumber(State.PermInterval) or 0.5))
        if Unloaded then break end
        if not IN_GAME then break end
        if State.UpgBagSize or State.AutoFarmWins then tryBuyPermanent("ExtraHoldAmount") end
        if State.UpgExtraTake or State.AutoFarmWins then tryBuyPermanent("ExtraTakeAmount") end
        if State.UpgGemValue or State.AutoFarmWins then tryBuyPermanent("GemValue") end
        if State.UpgHayValue or State.AutoFarmWins then tryBuyPermanent("ExtraHayValuePercentage") end
    end
end)

do
    -- Match Chapter 4's 0.05s confirmed-purchase scheduler and refresh
    -- its remote/config every round. Auto Farm Hay retains upgrade-all.
    local lastUpgradeFolder
    local upgrades=createAutoUpgradeRuntime({
        State=upgradeState,Player=LocalPlayer,Cash=getCash,
        Folder=function()
            local current=ReplicatedStorage:FindFirstChild("NeedleHaystack")
            if current~=lastUpgradeFolder then
                lastUpgradeFolder=current
                if current then print("[BeyyHub Upgrade] Chapter 1 upgrade remote bound to current round")end
            end
            return current
        end,
        OnConfig=function(config)GameConfig=config end,
        Status=function()end,
        OnRequested=function(pending)
            upgradeAudit.cashRequests+=1
            local key="Cash:"..pending.Name
            if not upgradeAudit.firstRequestLogged[key] then
                upgradeAudit.firstRequestLogged[key]=true
                print(string.format("[BeyyHub Upgrade] First Cash request %s L%d->L%d",
                    pending.Name,pending.Level,pending.Level+1))
            end
        end,
        OnConfirmed=function(pending,current)
            logUpgradeConfirmation("Cash",pending.Name,
                {level=pending.Level,time=pending.Started},current)
        end
    })
    task.spawn(function()
        local wake=createWorkerWake(LocalPlayer)
        notifyNormalUpgradesChanged=function()wake.Wake("upgrades")end
        local ordinaryCashFlags={
            "UpgCapacity","UpgHandSpeed","UpgHandGrab","UpgHandHold",
            "UpgTntLuck","UpgTntCooldown","UpgTntPower",
            "UpgPitchCooldown","UpgPitchHold","UpgPitchSweep",
            "UpgDroneSpeed","UpgDroneGrab","UpgDroneCapacity",
            "UpgVacPower","UpgVacCooling","UpgVacRuntime",
        }
        local function ordinaryCashUpgradeEnabled()
            if State.AutoFarmWins==true or State.AutoFarmHay==true then return false end
            for _,flag in ipairs(ordinaryCashFlags) do
                if State[flag]==true then return true end
            end
            return false
        end
        while not Unloaded do
            if IN_GAME then upgrades.Tick() end
            if ordinaryCashUpgradeEnabled() then
                -- Use the upgrades-cash key: it wakes on both replicated upgrade
                -- levels and new cash. A confirmed level can immediately trigger
                -- the next eligible purchase without a fixed 50ms sleep.
                wake.WaitResponsive(0.05,"upgrades-cash")
            else
                -- Preserve the original Chapter 1 auto-farm/idle scheduler.
                wake.Wait(0.05,upgrades.IsIdle(),upgrades.WaitKey())
            end
        end
        notifyNormalUpgradesChanged=nil
        wake.Stop()
    end)
end

task.spawn(function()
    task.wait(2)
    while not Unloaded do
        if IN_GAME and GameConfig then
            local enabled=0
            local flags={"UpgCapacity","UpgHandSpeed","UpgHandGrab","UpgHandHold","UpgTntLuck","UpgTntCooldown","UpgTntPower",
                "UpgPitchCooldown","UpgPitchHold","UpgPitchSweep","UpgDroneSpeed","UpgDroneGrab","UpgDroneCapacity",
                "UpgVacPower","UpgVacCooling","UpgVacRuntime"}
            for _,flag in ipairs(flags) do if State[flag] then enabled+=1 end end
            local track=GameConfig.UPGRADE_TRACKS and GameConfig.UPGRADE_TRACKS.VacuumRuntime
            local level=tonumber(LocalPlayer:GetAttribute("HayUpgradeVacuumRuntime")) or 1
            local nextLevel=track and track.Levels and track.Levels[level+1]
            local price=nextLevel and (tonumber(nextLevel.Cost) or 0)*(tonumber(LocalPlayer:GetAttribute("UpgradeCostMultiplier")) or 1)
            local state=not State.UpgVacRuntime and "disabled" or not nextLevel and "maxed" or
                getCash()<(price or math.huge) and "unaffordable" or "eligible"
            print(string.format("[BeyyHub Upgrade] Audit v1 | cash=%.2f gems=%.2f enabledCash=%d runtime=%s L%d nextCost=%s cashRequests=%d cashConfirmed=%d cashRetries=%d permanentRequests=%d permanentConfirmed=%d permanentRetries=%d",
                tonumber(getCash()) or 0,getGems(),enabled,state,level,price and string.format("%.2f",price) or "max",
                upgradeAudit.cashRequests,upgradeAudit.cashConfirmations,upgradeAudit.cashRetries,
                upgradeAudit.permanentRequests,upgradeAudit.permanentConfirmations,upgradeAudit.permanentRetries))
        end
        task.wait(15)
    end
end)

do
(function()
    local fractions={0.04,0.13,0.22,0.31,0.40,0.49,0.58,0.67,0.76,0.85,0.93,0.99}
    local state={
        plan=nil,building=false,buildAt=0,generation=0,band=1,sweep=0,angle=0,
        lastRadii={},lastProgress=0,recovering=false,stalls=0,
        bound=false,camera=nil,cameraType=nil,cameraSubject=nil,cameraFrame=nil,
        remaining=nil,zeroChecks=0,lastQuery=0,queryPending=false,queryAt=0,
        lastSell=0,lastPurchases=0,lastTools=0,ending=false,lastLog=0,
        tntNext=0,tntThrowAt=0,tntPending=false
    }
    local renderName="BeyyV103_AutoFarmHay_"..tostring(LocalPlayer.UserId)
    local remoteState=NeedleHaystack and NeedleHaystack:FindFirstChild("GetHayState")
    local function running()
        return not Unloaded and IN_GAME and State.AutoFarmHay==true and Window.Closed
            and not roundEndingVisible()
    end
    local function stopCamera()
        if state.bound then pcall(function() RunService:UnbindFromRenderStep(renderName) end) end
        state.bound=false
        local camera=state.camera
        if camera and camera.Parent then
            pcall(function()
                camera.CameraType=state.cameraType or Enum.CameraType.Custom
                if state.cameraSubject and state.cameraSubject.Parent then
                    camera.CameraSubject=state.cameraSubject
                end
                if state.cameraType==Enum.CameraType.Scriptable and state.cameraFrame then
                    camera.CFrame=state.cameraFrame
                end
            end)
        end
        state.camera,state.cameraType,state.cameraSubject,state.cameraFrame=nil,nil,nil,nil
        State.HayFarmTargetReady=false
    end
    local function reset(reason)
        stopCamera()
        state.generation+=1
        state.plan=nil
        state.building=false
        state.band=1
        state.sweep=0
        state.angle=0
        state.lastRadii={}
        state.lastProgress=0
        state.recovering=false
        state.remaining=nil
        state.zeroChecks=0
        state.queryPending=false
        state.lastQuery=0
        state.tntPending=false
        state.tntThrowAt=0
        State.HayFarmCleared=false
        if reason then print("[AutoFarmHay] Reset: "..tostring(reason)) end
    end
    local function planRings()
        if not GameConfig or typeof(GameConfig.PILE_CENTER)~="Vector3" then return nil end
        local height=tonumber(GameConfig.PILE_HEIGHT)
        if not height or height<=0 then return nil end
        local center=GameConfig.PILE_CENTER
        local floor=center.Y+(tonumber(GameConfig.PILE_BASE_Y) or 0)
        local folder=Workspace:FindFirstChild("HaystackClient")
        if not folder then return nil end
        local children=folder:GetChildren()
        local bins={}
        for i=1,#fractions do bins[i]={} end
        local stride=math.max(1,math.ceil(#children/10000))
        for index=1,#children,stride do
            if Unloaded or State.AutoFarmHay~=true then return nil end
            local hay=children[index]
            if hay:IsA("BasePart") and hay:GetAttribute("HayId")~=nil
                and hay:GetAttribute("IsHeld")~=true and hay:GetAttribute("Held")~=true then
                local p=hay.Position
                local fraction=(p.Y-floor)/height
                local best,delta=1,math.huge
                for i,target in ipairs(fractions) do
                    local difference=math.abs(target-fraction)
                    if difference<delta then best,delta=i,difference end
                end
                local dx,dz=p.X-center.X,p.Z-center.Z
                bins[best][#bins[best]+1]=math.sqrt(dx*dx+dz*dz)
            end
            if index%1200<stride then task.wait() end
        end
        local plan={}
        for i,fraction in ipairs(fractions) do
            local radii=bins[i]
            local radius=state.lastRadii[i] or math.clamp(29-22*fraction,5,30)
            if #radii>=8 then
                table.sort(radii)
                radius=math.clamp(radii[math.max(1,math.ceil(#radii*0.95))]+2.8,4,34)
            end
            plan[i]={radius=radius,height=floor+height*fraction}
        end
        return {center=center,bands=plan}
    end
    local function target()
        local data=state.plan
        local band=data and data.bands[state.band]
        if not band then return nil end
        local center=data.center
        local radial=Vector3.new(math.cos(state.angle),0,math.sin(state.angle))
        local radius=band.radius
        local position=Vector3.new(center.X+radial.X*(radius-1.5),
            band.height+3.25,center.Z+radial.Z*(radius-1.5))
        return position,center,radial,radius,band
    end
    local function follow()
        local char=LocalPlayer.Character
        local root=getHRP()
        local destination,center=target()
        if not char or not root or not destination then
            State.HayFarmTargetReady=false
            return
        end
        if (root.Position-destination).Magnitude>0.4 then
            local offset=root.CFrame:ToObjectSpace(char:GetPivot())
            local facing=Vector3.new(center.X,destination.Y-1.25,center.Z)
            pcall(function()
                if running() and not State.HayFarmCleared and not needleHasPriority()
                    and char.Parent and root.Parent then
                    char:PivotTo(CFrame.lookAt(destination,facing,Vector3.yAxis)*offset)
                    root.AssemblyLinearVelocity=Vector3.zero
                    root.AssemblyAngularVelocity=Vector3.zero
                end
            end)
        end
        State.HayFarmTargetReady=true
    end
    local function bindCamera()
        if state.bound or not state.plan then return end
        local camera=Workspace.CurrentCamera
        if not camera then return end
        state.camera=camera
        state.cameraType,state.cameraSubject,state.cameraFrame=
            camera.CameraType,camera.CameraSubject,camera.CFrame
        local ok,err=pcall(function()
            RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+10,function(dt)
                if not running() or State.HayFarmCleared or needleHasPriority() then return end
                local destination,center,radial,radius,band=target()
                local root=getHRP()
                local cam=Workspace.CurrentCamera
                if not destination or not root or not cam then return end
                dt=math.clamp(dt,0,0.25)
                local now=os.clock()
                if state.lastProgress==0 then state.lastProgress=now end
                local distance=(root.Position-destination).Magnitude
                if distance<=3 then
                    state.recovering=false
                elseif not state.recovering and now-state.lastProgress>=8 then
                    state.recovering=true
                    state.stalls+=1
                    warn("[AutoFarmHay] Ring "..state.band.." stalled; continuing orbit to recover")
                end
                if distance<=3 or state.recovering then
                    state.angle=math.min(2*math.pi,state.angle+math.rad(64)*dt)
                    state.lastProgress=now
                end
                destination,center,radial,radius,band=target()
                if not destination then return end
                local cameraPosition=Vector3.new(center.X+radial.X*(radius+0.6),
                    band.height+5,center.Z+radial.Z*(radius+0.6))
                local down=state.band==12 and 4.5 or state.band==11 and 2.5 or 0
                local inset=state.band==12 and 7.5 or state.band==11 and 6.5 or 5
                local radiusAim=math.max(0,radius-inset)
                local aim=Vector3.new(center.X+radial.X*radiusAim,band.height-down,
                    center.Z+radial.Z*radiusAim)
                cam.CameraType=Enum.CameraType.Scriptable
                cam.CFrame=CFrame.lookAt(cameraPosition,aim,Vector3.yAxis)
                if state.angle>=2*math.pi then
                    state.band+=1
                    state.angle=0
                    state.lastProgress=now
                    state.recovering=false
                    State.HayFarmTargetReady=false
                    if state.band>#fractions then
                        state.plan=nil
                        state.band=1
                        stopCamera()
                        print("[AutoFarmHay] Sweep "..state.sweep.." complete; recalibrating")
                    end
                end
            end)
        end)
        if ok then state.bound=true
        else
            state.camera,state.cameraType,state.cameraSubject,state.cameraFrame=nil,nil,nil,nil
            warn("[AutoFarmHay] Could not bind camera: "..tostring(err))
        end
    end
    local connection
    if TntAction and TntAction:IsA("RemoteEvent") then
        connection=TntAction.OnClientEvent:Connect(function(kind,value)
            if not state.tntPending then return end
            if kind=="lit" then
                state.tntPending=false
                state.tntThrowAt=os.clock()+math.max(0.1,tonumber(State.TntThrowDelay) or 0.5)
                state.tntNext=os.clock()+math.max(0.5,tonumber(LocalPlayer:GetAttribute("TntCooldown")) or 20)
            elseif kind=="denied" then
                state.tntPending=false
                state.tntNext=os.clock()+math.max(0.5,tonumber(value) or 1)
            end
        end)
    end
    local previousCleanup=_G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP=function()
        stopCamera()
        if connection then connection:Disconnect() end
        if previousCleanup then pcall(previousCleanup) end
    end
    task.spawn(function()
        local activeBefore=false
        local endedBefore=false
        while not Unloaded do
            task.wait(0.06)
            if Unloaded then break end
            if State.AutoFarmHay~=true then
                if activeBefore then reset("toggle disabled") end
                activeBefore=false
                endedBefore=false
                continue
            end
            activeBefore=true
            local ending=roundEndingVisible()
            if ending then
                endedBefore=true
                if state.bound then stopCamera() end
                continue
            end
            if endedBefore then
                reset("Replay results dismissed")
                endedBefore=false
            end
            if not running() or State.HayFarmCleared or needleHasPriority()
                or LocalPlayer:GetAttribute("NeedleInputLocked")==true then
                if state.bound then stopCamera() end
                continue
            end
            if not state.plan then
                if state.building then
                    if os.clock()-state.buildAt>20 then
                        state.generation+=1
                        state.building=false
                        warn("[AutoFarmHay] Calibration timed out; retrying")
                    else
                        continue
                    end
                end
                state.building=true
                state.buildAt=os.clock()
                state.generation+=1
                local serial=state.generation
                task.spawn(function()
                    local ok,data=pcall(planRings)
                    if serial~=state.generation or Unloaded or State.AutoFarmHay~=true then return end
                    state.building=false
                    if not ok then warn("[AutoFarmHay] Calibration error: "..tostring(data));return end
                    if not data then return end
                    state.plan=data
                    for i,band in ipairs(data.bands) do state.lastRadii[i]=band.radius end
                    state.band=1
                    state.angle=0
                    state.lastProgress=os.clock()
                    state.sweep+=1
                    print("[AutoFarmHay] Sweep "..state.sweep.." ready (12 rings, 64 deg/s)")
                end)
                continue
            end
            if not state.bound then bindCamera() end
            if state.bound then follow() end
        end
        stopCamera()
    end)
    task.spawn(function()
        if not remoteState or not remoteState:IsA("RemoteFunction") then
            warn("[AutoFarmHay] GetHayState not available; needle hand-in remains locked")
            return
        end
        while not Unloaded do
            task.wait(1)
            if Unloaded then break end
            if not running() or State.HayFarmCleared then continue end
            local now=os.clock()
            if state.queryPending and now-state.queryAt<40 then continue end
            if now-state.lastQuery<15 then continue end
            state.queryPending=true
            state.queryAt=now
            state.lastQuery=now
            local serial=state.generation
            task.spawn(function()
                local ok,data=pcall(function() return remoteState:InvokeServer() end)
                if Unloaded or State.AutoFarmHay~=true or serial~=state.generation then return end
                state.queryPending=false
                if not ok or type(data)~="table" or type(data.remaining)~="number"
                    or data.remaining<0 then return end
                state.remaining=data.remaining
                if data.remaining==0 then
                    state.zeroChecks+=1
                    if state.zeroChecks>=2 then
                        State.HayFarmCleared=true
                        State.HayFarmTargetReady=false
                        stopCamera()
                        print("[AutoFarmHay] Server confirmed zero hay twice; needle pickup/hand-in unlocked")
                    end
                else
                    state.zeroChecks=0
                    if now-state.lastLog>=60 then
                        state.lastLog=now
                        print("[AutoFarmHay] Server hay remaining: "..tostring(data.remaining))
                    end
                end
            end)
        end
    end)
    task.spawn(function()
        local permanent={"ExtraHoldAmount","ExtraTakeAmount","GemValue","ExtraHayValuePercentage"}
        local tools={{"Pitchfork","PitchforkOwned"},{"Tnt","TntOwned"},
            {"Drone","DroneOwned"},{"Vacuum","VacuumOwned"}}
        while not Unloaded do
            task.wait(0.5)
            if Unloaded then break end
            if not running() or State.HayFarmCleared then continue end
            local now=os.clock()
            if getHayHeld()>=250 and now-state.lastSell>=5 then
                state.lastSell=now
                pcall(function() SellHay:FireServer() end)
            end
            if now-state.lastTools>=1.5 then
                state.lastTools=now
                for _,item in ipairs(tools) do
                    if not owns(item[2]) then
                        pcall(function() BuyShopItem:FireServer(item[1]) end)
                    end
                end
                if owns("DroneOwned") and not State.AutoDeployDrone
                    and LocalPlayer:GetAttribute("DroneDeployed")~=true then
                    pcall(function() DeployDrone:FireServer() end)
                end
                if owns("PitchforkOwned") and not State.AutoUsePitchfork then
                    local hay=findClosestHayCached()
                    local root=getHRP()
                    local id=hay and hay:GetAttribute("HayId")
                    local reach=tonumber(LocalPlayer:GetAttribute("PitchforkReach")) or 4.2
                    if id and root and (hay.Position-root.Position).Magnitude<=reach+hay.Size.Magnitude*0.5 then
                        pcall(function() PitchforkDig:FireServer(id) end)
                    end
                end
            end
            if TntAction and owns("TntOwned") and not State.AutoUseTNT then
                if state.tntThrowAt>0 and now>=state.tntThrowAt then
                    state.tntThrowAt=0
                    local root=getHRP()
                    local destination,center,radial,radius=target()
                    if root and destination then
                        local origin=root.Position+Vector3.new(0,1.5,0)
                        local targetPoint=destination-radial*math.min(5,radius*0.35)
                        local direction=targetPoint-origin
                        if direction.Magnitude>1 then
                            local up=math.abs(direction.Unit:Dot(Vector3.yAxis))>0.97 and Vector3.zAxis or Vector3.yAxis
                            local cf=CFrame.lookAt(origin,targetPoint,up)
                            local velocity=direction/0.45+Vector3.new(0,0.5*Workspace.Gravity*0.45,0)
                            pcall(function() TntAction:FireServer("throw",cf,velocity) end)
                        end
                    end
                elseif not state.tntPending and state.tntThrowAt==0 and now>=state.tntNext then
                    state.tntPending=true
                    state.tntNext=now+math.max(0.5,tonumber(LocalPlayer:GetAttribute("TntCooldown")) or 20)
                    pcall(function() TntAction:FireServer("light") end)
                end
            end
        end
    end)
    task.spawn(function()
        while not Unloaded do
            task.wait(0.5)
            if Unloaded then break end
            if running() and not State.HayFarmCleared then
                for _,name in ipairs(permanent) do pcall(tryBuyPermanent,name) end
            end
        end
    end)
end)()
end

task.spawn(function()
    while not Unloaded do
        task.wait(300)
        if Unloaded then break end
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping); hum.Jump = true end
        end)
    end
end)

do
-- Isolate remaining startup/background locals from the module register budget.
(function()
do
    local virtualUser = game:GetService("VirtualUser")
    local beyyAntiAfkConnection = LocalPlayer.Idled:Connect(function()
        if Unloaded then return end
        pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
    local previousCleanup = _G.__BEYY_HUB_CLEANUP
    _G.__BEYY_HUB_CLEANUP = function()
        beyyAntiAfkConnection:Disconnect()
        if previousCleanup then pcall(previousCleanup) end
    end
end

local KILLS_PER_CYCLE  = 6
local CYCLES_PER_YIELD = 10
local YIELD_DURATION   = 0.001

local function fastLeave()
    local sg = LocalPlayer.PlayerGui:FindFirstChild("ArcadeScreen")
    if sg then sg.Enabled = false end

    pcall(function()
        LocalPlayer:SetAttribute("ArcadePlaying", nil)
        LocalPlayer:SetAttribute("NeedleInputLocked", nil)
    end)

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
    end

    local cam = workspace.CurrentCamera
    if cam then cam.CameraType = Enum.CameraType.Custom end
    pcall(function() ArcadeSession:FireServer("quit", 0, 0) end)
end

local function arcadeCycle()
    pcall(function() fireproximityprompt(ArcadePrompt) end)
    for i = 1, KILLS_PER_CYCLE do
        pcall(function() ArcadeReport:FireServer("kills", 40, 0) end)
    end
    fastLeave()
end

task.spawn(function()
    local cycles = 0
    while not Unloaded do
        if IN_GAME then

            if State.ArcadeFarm then
                State.ArcadeFarm = false
                Notify("Arcade", "Lobby only.", 3, "x")
            end
            task.wait(0.1)
        elseif State.ArcadeFarm and ArcadePrompt and ArcadeReport then
            cycles = cycles + 1
            arcadeCycle()
            if cycles % CYCLES_PER_YIELD == 0 then
                task.wait(YIELD_DURATION)
            end
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while not Unloaded do
        task.wait(tonumber(State.ClassRollInterval) or 1.1)
        if Unloaded then break end
        if IN_GAME then
            if State.ClassRoller then State.ClassRoller = false; Notify("Roller", "Lobby only.", 3, "x") end
        else
            if State.ClassRoller and RollClass then
                local ok, result = pcall(function() return RollClass:InvokeServer() end)
                if ok and type(result) == "table" and result.success and result.className == State.ClassTarget then
                    Notify("Class Roller", "FOUND: "..result.className, 5, "check")
                end
            end
        end
    end
end)

pcall(function()
    task.defer(function()
        if not Unloaded then pcall(function() CollectingTab:Select() end) end

        if not Unloaded and not Window.Closed then closeMenuOnStartup() end
    end)
end)

print("[Needle] Loaded v103.00")
print(("[BeyyHub Startup] Chapter1 controls and features registered after %.2fs in module"):format(
    os.clock() - __BEYY_BOOT_T0))
-- Halt local automation after a real disconnect; do not attempt unauthenticated teleports.
task.spawn(function()
    while not Unloaded do
        task.wait(0.5)
        if Unloaded then break end
        local ok,message=pcall(function() return game:GetService("GuiService"):GetErrorMessage() end)
        if ok and type(message)=="string" and message~="" then
            warn("[Beyy] Connection lost; stopping automation: "..message)
            if _G.__BEYY_HUB_CLEANUP then pcall(_G.__BEYY_HUB_CLEANUP) end
            return
        end
    end
end)

end)()
end

