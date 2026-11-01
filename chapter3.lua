-- beyy v103.00 | Chapter3 module | PlaceId 82626725163709
local __BEYY_MODULE = "Chapter3"
local __BEYY_SCRIPT_VERSION = "103.00"
local __BEYY_BOOT_T0 = os.clock()
if game.PlaceId ~= 82626725163709 then
    warn("[BeyyHub] Refusing to load Chapter3 module in another place")
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
    local sharedFarmPuzzleBusy = function() return false end
    local bossCombatActive = function() return false end
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
        AutoSolveRanchPuzzles=true, AutoGrabAttachUfoParts=false,
        AutoBossFight=false, AutoBossBodyHits=true, AutoBossVacuum=true,
        AutoBossAimVacuum=true, AutoBossFinish=false,
        AutoBossGrabEscape=true, BossDiagnostics=false,
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
    -- Match Chapter 2's startup hydration: active config and teleport data
    -- work even when Solara cannot read farming_inventory_shared.json.
    local farmTeleportKey = "BeyyHub_FarmTools_v103"
    local snapshot = __beyyConfigDecode(__beyyInitialConfig)
    local configElements = snapshot and (snapshot.__elements or snapshot)
    if type(configElements) == "table" then
        for key, default in pairs(sharedFarmDefaults) do
            local entry = configElements[key]
            local value = type(entry) == "table" and entry.__type and entry.value or entry
            if type(value) == type(default) then sharedFarmState[key] = value end
        end
    end
    local teleportOK, teleportSettings = pcall(function()
        return __BEYY_CONFIG_TELEPORT:GetTeleportSetting(farmTeleportKey)
    end)
    if teleportOK and type(teleportSettings) == "table" then
        for key, default in pairs(sharedFarmDefaults) do
            local value = teleportSettings[key]
            if type(value) == type(default) then sharedFarmState[key] = value end
        end
    end
    print("[BeyyHub Ranch Tools] Settings: TNT=" .. tostring(sharedFarmState.AutoUseTNT)
        .. " Pitchfork=" .. tostring(sharedFarmState.AutoUsePitchfork)
        .. " Drone=" .. tostring(sharedFarmState.AutoDeployDrone)
        .. " Vacuum=" .. tostring(sharedFarmState.AutoUseVacuum)
        .. " RuntimeUpgrade=" .. tostring(sharedFarmState.UpgVacRuntime)
        .. " CoolingUpgrade=" .. tostring(sharedFarmState.UpgVacCooling))
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

    end)(overviewTab,Registry,function()return not hubUnloaded end)
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
    farmToggle(needleTab,"AutoFindNeedle","Auto Find Needle")
    farmToggle(needleTab,"AutoPickupNeedle","Auto Pick Up Needle")
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
            or sharedFarmPuzzleBusy()
            or LocalPlayer:GetAttribute("NeedleInputLocked")==true
            or LocalPlayer:GetAttribute("CutsceneActive")==true
            or LocalPlayer:GetAttribute("HintViewerOpen")==true
    end
    local function exposedNeedle()
        local folder=Workspace:FindFirstChild("NeedleObjectiveServer")
        folder=folder and folder:FindFirstChild("Needle")
        if not folder then return nil end
        for _,item in ipairs(folder:GetDescendants()) do
            if item:IsA("BasePart") and item:GetAttribute("IsNeedleObjective")==true
                and item:GetAttribute("HIDDEN_WITHIN")==nil
                and type(item:GetAttribute("HayId"))=="number" then
                return item
            end
        end
    end
    local needleBusy=false
    local function needlePriority()
        if needleBusy then return true end
        if LocalPlayer:GetAttribute("NeedleOwned")==true then
            return sharedFarmState.AutoHandInNeedle or sharedFarmState.AutoPickupNeedle
        end
        return sharedFarmState.AutoPickupNeedle and exposedNeedle()~=nil
    end
    local function ranchToolBlockReason()
        if hubUnloaded then return "unloaded" end
        if needleBusy or needlePriority() or LocalPlayer:GetAttribute("NeedleOwned")==true then
            return "needle objective"
        end
        if sharedFarmPuzzleBusy() then return "Ranch puzzle input" end
        if LocalPlayer:GetAttribute("NeedleInputLocked")==true
            or LocalPlayer:GetAttribute("CutsceneActive")==true
            or LocalPlayer:GetAttribute("HintViewerOpen")==true then
            return "gameplay input locked"
        end
        return nil
    end
    local function closestInFolder(folderName,idName,limit)
        local folder=Workspace:FindFirstChild(folderName)
        local root=farmRoot()
        if not folder or not root then return nil,nil end
        local best,bestId,dist=nil,nil,limit
        for _,obj in ipairs(folder:GetChildren()) do
            local part=obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true)))
            if part then
                local id=part:GetAttribute(idName) or obj:GetAttribute(idName)
                if idName=="Dropped" then id=obj end
                local d=(part.Position-root.Position).Magnitude
                if id and d<dist then best,bestId,dist=part,id,d end
            end
        end
        return best,bestId
    end
    local function bagFull()
        return (tonumber(LocalPlayer:GetAttribute("HayHeld")) or 0)
            >= (tonumber(LocalPlayer:GetAttribute("HayCapacity")) or 25)
    end
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.1,tonumber(sharedFarmState.CollectInterval) or 0.5))
            needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            if needleFolder and not farmBlocked() and not needlePriority() then
                if (sharedFarmState.AutoPickHay or (sharedFarmState.AutoFindNeedle and not exposedNeedle())) and not bagFull() then
                    local hay,id=closestInFolder("HaystackClient","HayId",30)
                    if id then
                        local nearby={}
                        local radius=tonumber(LocalPlayer:GetAttribute("HayGrabRadius")) or 0
                        if radius>0 and hay then
                            local folder=Workspace:FindFirstChild("HaystackClient")
                            if folder then
                                for _,other in ipairs(folder:GetChildren()) do
                                    if other~=hay and other:IsA("BasePart")
                                        and other:GetAttribute("HayId")
                                        and (other.Position-hay.Position).Magnitude<=radius+1 then
                                        nearby[#nearby+1]=other:GetAttribute("HayId")
                                        if #nearby>=6 then break end
                                    end
                                end
                            end
                        end
                        sendFarmRemote("PickHay",id,nearby)
                    end
                end
                if sharedFarmState.AutoCollectDroppedHay and not bagFull() then
                    local _,d=closestInFolder("DroppedHay","Dropped",28)
                    if d then sendFarmRemote("PickDroppedHay",d) end
                end
                if sharedFarmState.AutoCollectGems then
                    local _,id=closestInFolder("GemsClient","GemId",35)
                    if id then sendFarmRemote("CollectGem",id) end
                end
            end
        end
    end)
    task.spawn(function()
        while not hubUnloaded do
            task.wait(1)
            needleFolder = needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
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
        local lastToolNote = -math.huge
        local lastEnabled = nil
        local function toolNote(note)
            if os.clock()-lastToolNote>=8 then
                lastToolNote=os.clock()
                print("[BeyyHub Ranch Tools] "..note)
            end
        end
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.ToolInterval) or 0.5))
            local enabled = sharedFarmState.AutoUsePitchfork
                or sharedFarmState.AutoDeployDrone or sharedFarmState.AutoUseTNT
            if enabled ~= lastEnabled then
                lastEnabled=enabled
                print("[BeyyHub Ranch Tools] Remote tools " .. (enabled and "ENABLED" or "OFF"))
            end
            if enabled and not bossCombatActive() then
                needleFolder=needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
                local reason=ranchToolBlockReason()
                if not needleFolder then
                    toolNote("Waiting for NeedleHaystack; Ranch may use a different tool remote layout")
                elseif reason then
                    toolNote("Paused: "..reason)
                else
                    local sent=false
                    if sharedFarmState.AutoUsePitchfork and LocalPlayer:GetAttribute("PitchforkOwned")==true then
                        local _,id=closestInFolder("HaystackClient","HayId",30)
                        if id then sent=sendFarmRemote("PitchforkDig",id) or sent end
                    end
                    if sharedFarmState.AutoDeployDrone and LocalPlayer:GetAttribute("DroneOwned")==true
                        and LocalPlayer:GetAttribute("DroneDeployed")~=true then
                        sent=sendFarmRemote("DeployDrone") or sent
                    end
                    if sent then
                        toolNote("Tool remote request sent; server acceptance not confirmed")
                    else
                        toolNote("No request: check Ranch remote layout, tool ownership, nearby hay, and toggles")
                    end
                end
            end
        end
    end)
    task.spawn(function()
        local nextTntLightAt=0
        while not hubUnloaded do
            task.wait(0.1)
            if sharedFarmState.AutoUseTNT and LocalPlayer:GetAttribute("TntOwned")==true
                and os.clock()>=nextTntLightAt then
                needleFolder=needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
                if needleFolder and not bossCombatActive() and not ranchToolBlockReason() then
                    local cooldown=tonumber(LocalPlayer:GetAttribute("TntCooldown")) or 20
                    nextTntLightAt=os.clock()+math.max(0.5,cooldown,tonumber(sharedFarmState.TntLightCooldown) or 0)
                    if sendFarmRemote("TntAction","light") then
                        task.wait(math.max(0,tonumber(sharedFarmState.TntThrowDelay) or 0.4))
                        if not hubUnloaded and sharedFarmState.AutoUseTNT and not bossCombatActive() and not ranchToolBlockReason() then
                            local camera=Workspace.CurrentCamera
                            if camera then
                                sendFarmRemote("TntAction","throw",camera.CFrame,
                                    camera.CFrame.LookVector*40+Vector3.new(0,8,0))
                            end
                        end
                    end
                end
            end
        end
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
        while not hubUnloaded do
            task.wait(0.08)
            needleFolder=needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            local bossVacuum=bossCombatActive() and sharedFarmState.AutoBossVacuum
            local active=(needleFolder or bossVacuum) and BEYY_CHAPTER~="Lobby"
                and (sharedFarmState.AutoUseVacuum or bossVacuum)
                and not ranchToolBlockReason() and hubWindow.Closed==true
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
                        -- The reference boss UI reports vacuum as BossEquippedSlot=5.
                        -- Keep the normal configurable slot outside boss combat.
                        local slot=bossVacuum and 5 or math.clamp(
                            math.floor(tonumber(sharedFarmState.VacuumHotbarSlot) or 5),1,9)
                        local key=hotbar[slot]
                        pcall(function() VirtualInputManager:SendKeyEvent(true,key,false,game) end)
                        task.wait(0.05)
                        pcall(function() VirtualInputManager:SendKeyEvent(false,key,false,game) end)
                        task.wait(0.15)
                        if not ranchToolBlockReason() and hubWindow.Closed then
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
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.NeedleInterval) or 1))
            if needleFolder and not farmBlocked() and sharedFarmState.AutoHandInNeedle
                and not needleBusy and not handInBusy
                and LocalPlayer:GetAttribute("NeedleOwned")==true then
                handInBusy = true
                local ok, err = pcall(function()
                    local root = farmRoot()
                    if not root then return end
                    if BEYY_CHAPTER == "Chapter2" then
                        local laser = Workspace:FindFirstChild("Laser")
                        if not (laser and laser:IsA("Model")) then
                            handInWarning("Workspace.Laser missing; waiting for the Chapter 2 hand-in location")
                            return
                        end
                        local destination = laser:GetPivot().Position - Vector3.new(0, 2.5, 0)
                        root.CFrame = CFrame.new(destination) * root.CFrame.Rotation
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                        task.wait(0.2)
                        if hubUnloaded or farmBlocked() or not sharedFarmState.AutoHandInNeedle
                            or LocalPlayer:GetAttribute("NeedleOwned") ~= true then return end
                        if not sendFarmRemote("NeedleHandIn") then
                            handInWarning("NeedleHandIn remote unavailable or send failed")
                            return
                        end
                        local deadline = os.clock() + 1.5
                        while not hubUnloaded and LocalPlayer:GetAttribute("NeedleOwned")==true
                            and os.clock() < deadline do
                            task.wait(0.05)
                        end
                        if not hubUnloaded and LocalPlayer:GetAttribute("NeedleOwned")==true then
                            handInWarning("no server confirmation; will retry from beneath Laser")
                        end
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
    task.spawn(function()
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.NeedleInterval) or 1))
            if needleFolder and not farmBlocked() and not needleBusy
                and sharedFarmState.AutoPickupNeedle and LocalPlayer:GetAttribute("NeedleOwned")~=true then
                local needle=exposedNeedle()
                local root=farmRoot()
                local camera=Workspace.CurrentCamera
                if needle and root and camera and hubWindow.Closed==true then
                    needleBusy=true
                    releaseSharedVacuum()
                    local previousRoot=root.CFrame
                    local previousCameraType=camera.CameraType
                    local previousCameraCF=camera.CFrame
                    local renderName="BeyySharedNeedleAim_"..tostring(LocalPlayer.UserId)
                    local bound=false
                    local mouseDown=false
                    local function clear()
                        if mouseDown then
                            mouseDown=false
                            local center=camera.ViewportSize/2
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            end)
                        end
                        if bound then pcall(function() RunService:UnbindFromRenderStep(renderName) end) end
                        if camera then
                            pcall(function()
                                camera.CameraType=previousCameraType
                                camera.CFrame=previousCameraCF
                            end)
                        end
                        if root and root.Parent then pcall(function() root.CFrame=previousRoot end) end
                        needleBusy=false
                    end
                    local ok,err=xpcall(function()
                        local id=needle:GetAttribute("HayId")
                        local spot=needle.Position+Vector3.new(2,2.5,0)
                        root.CFrame=CFrame.lookAt(spot,needle.Position)
                        camera.CameraType=Enum.CameraType.Scriptable
                        local cameraSpot=spot+Vector3.new(0,0,0.5)
                        camera.CFrame=CFrame.lookAt(cameraSpot,needle.Position)
                        RunService:BindToRenderStep(renderName,Enum.RenderPriority.Last.Value+30,function()
                            if needle.Parent then
                                camera.CFrame=CFrame.lookAt(cameraSpot,needle.Position)
                                LocalPlayer:SetAttribute("HoveredHayId",id)
                            end
                        end)
                        bound=true
                        task.wait(0.1)
                        for _=1,8 do
                            if hubUnloaded or farmBlocked() or not sharedFarmState.AutoPickupNeedle
                                or not needle.Parent or LocalPlayer:GetAttribute("NeedleOwned")==true then break end
                            local center=camera.ViewportSize/2
                            LocalPlayer:SetAttribute("HoveredHayId",id)
                            VirtualInputManager:SendMouseMoveEvent(center.X,center.Y,game)
                            task.wait(0.025)
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,true,game,0)
                            mouseDown=true
                            task.wait(0.1)
                            VirtualInputManager:SendMouseButtonEvent(center.X,center.Y,0,false,game,0)
                            mouseDown=false
                            task.wait(0.1)
                        end
                    end,function(e) return tostring(e) end)
                    clear()
                    if not ok then warn("[BeyyHub] Other-chapter needle pickup: "..tostring(err)) end
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
            needleFolder=needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
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
        local lastPermanentReady = nil
        while not hubUnloaded do
            task.wait(math.max(0.5,tonumber(sharedFarmState.PermInterval) or 0.5))
            needleFolder=needleFolder or ReplicatedStorage:FindFirstChild("NeedleHaystack")
            if not sharedUpgradeConfig then
                pcall(function()
                    local shared=ReplicatedStorage:FindFirstChild("Shared")
                    local configs=shared and shared:FindFirstChild("Configs")
                    local module=configs and configs:FindFirstChild("UpgradeConfig")
                    if module and module:IsA("ModuleScript") then
                        sharedUpgradeConfig=require(module)
                    end
                end)
            end
            local ready=sharedUpgradeConfig~=nil
            if ready~=lastPermanentReady then
                lastPermanentReady=ready
                print("[BeyyHub Ranch Upgrades] Permanent upgrade config "..(ready and "ready" or "unavailable; waiting for replication"))
            end
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
                upgrades.Tick()
                wake.Wait(0.05,upgrades.IsIdle(),upgrades.WaitKey())
            end
            wake.Stop()
        end)
    end


        -- Ranch GUI solver. The three GUI layouts and interactive controls
        -- were obtained from the live read-only Ranch JSON captures.
        -- Server-side puzzle remote arguments are NOT known. Normal solving
        -- uses real GUI dragging, not speculative remote requests.
        local ranchPuzzleNames = {
            "UfoWireMinigame", "UfoVentMinigame", "UfoAlignMinigame"
        }
        local ranchPuzzleInputBusy = false
        local ranchUfoBusy = false
        local ranchMouseHeld = false
        local ranchLastPuzzleGui = nil
        local ranchSession = nil
        local ranchAttempts = 0
        local ranchNextAttemptAt = 0
        local ranchInstantProbeActive = false

        local function ranchActivePuzzle()
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if not pg then return nil, nil end
            for _, name in ipairs(ranchPuzzleNames) do
                local gui = pg:FindFirstChild(name)
                if gui and gui:IsA("ScreenGui") and gui.Enabled then
                    local panel = gui:FindFirstChild("Panel")
                    if panel and panel:IsA("GuiObject") and panel.Visible then
                        return name, gui
                    end
                end
            end
            return nil, nil
        end
        local function ranchPuzzleAlive(gui)
            return gui ~= nil and gui.Parent ~= nil
                and gui:IsA("ScreenGui") and gui.Enabled == true
                and gui:FindFirstChild("Panel") ~= nil
        end
        sharedFarmPuzzleBusy = function()
            return ranchUfoBusy or ranchPuzzleInputBusy or ranchInstantProbeActive
                or ranchActivePuzzle() ~= nil
        end

        local function ranchPoint(element)
            local pos, size = element.AbsolutePosition, element.AbsoluteSize
            return Vector2.new(pos.X + size.X*0.5, pos.Y + size.Y*0.5)
        end
        local function ranchMouseMove(point)
            VirtualInputManager:SendMouseMoveEvent(math.floor(point.X+0.5),
                math.floor(point.Y+0.5), game)
        end
        local function ranchMouseButton(point, down)
            VirtualInputManager:SendMouseButtonEvent(math.floor(point.X+0.5),
                math.floor(point.Y+0.5), 0, down, game, 0)
        end
        local function ranchReleaseMouse()
            if not ranchMouseHeld then return end
            ranchMouseHeld = false
            local point = UserInputService:GetMouseLocation()
            pcall(function() ranchMouseButton(point, false) end)
        end
        -- Validated in standalone Ranch GUI pilot v6 (frame input for wire/align)
        -- and Vent Teleport pilot v2 (0.29 clip-height jump with GUI inset).
        -- This block is ONLY called by the existing AutoSolveRanchPuzzles loop.
        local function ranchGuiActive(gui)
            if not ranchPuzzleAlive(gui) then return false end
            local panel=gui:FindFirstChild("Panel")
            return panel and panel:IsA("GuiObject") and panel.Visible
        end
        local function ranchCanSolve(gui)
            return not hubUnloaded and sharedFarmState.AutoSolveRanchPuzzles
                and hubWindow.Closed and not ranchInstantProbeActive
                and ranchGuiActive(gui)
        end
        local function ranchWaitClosed(gui,seconds)
            local deadline=os.clock()+seconds
            while ranchGuiActive(gui) and os.clock()<deadline do
                if not ranchCanSolve(gui) then return false end
                task.wait(0.06)
            end
            return not ranchGuiActive(gui)
        end
        local function ranchGuiInsetY()
            local ok,top=pcall(function() return GuiService:GetGuiInset() end)
            return ok and top.Y or 0
        end
        local function ranchInsidePanel(panel,point)
            local p,s=panel.AbsolutePosition,panel.AbsoluteSize
            return point.X>=p.X-8 and point.X<=p.X+s.X+8
                and point.Y>=p.Y-8 and point.Y<=p.Y+s.Y+8
        end
        -- Every mouse hold has a corresponding release, even if input is
        -- interrupted by closing the hub, disabling the toggle or an error.
        -- mode="frame" is the tested wire/align gesture. mode="jump" is the
        -- tested Vent gesture, with ONE intermediate-free mouse move.
        -- mode="timed" preserves the proven GUI input as a fallback.
        local function ranchGuiDrag(gui,origin,goal,insetY,profile)
            if not ranchCanSolve(gui) then return false end
            local offset=Vector2.new(0,insetY or 0)
            local first,last=origin+offset,goal+offset
            local began=false
            local ok,err=pcall(function()
                ranchMouseMove(first)
                RunService.RenderStepped:Wait()
                if not ranchCanSolve(gui) then return end
                ranchMouseButton(first,true)
                began=true
                ranchMouseHeld=true
                if ranchSession and ranchSession.gui==gui then
                    ranchSession.drags+=1
                end
                RunService.RenderStepped:Wait()
                if profile.mode=="frame" then
                    if ranchCanSolve(gui) then
                        ranchMouseMove(first:Lerp(last,0.55))
                        RunService.RenderStepped:Wait()
                    end
                    if ranchCanSolve(gui) then
                        ranchMouseMove(last)
                        RunService.RenderStepped:Wait()
                    end
                elseif profile.mode=="jump" then
                    if ranchCanSolve(gui) then
                        ranchMouseMove(last)
                        RunService.RenderStepped:Wait()
                    end
                else
                    local steps=profile.steps or 20
                    local duration=profile.duration or 0.32
                    for i=1,steps do
                        if not ranchCanSolve(gui) then break end
                        ranchMouseMove(first:Lerp(last,i/steps))
                        task.wait(duration/steps)
                    end
                    if ranchCanSolve(gui) then
                        ranchMouseMove(last)
                        task.wait(profile.hold or 0.09)
                    end
                end
            end)
            if began then
                pcall(function() ranchMouseButton(last,false) end)
                ranchMouseHeld=false
            end
            if not ok then
                warn("[Ranch Puzzles] Mouse input error: "..tostring(err))
            end
            return ok and began
        end

        local ranchAlignProfiles={
            {mode="frame",window=1.33}, -- successful v6
            {mode="timed",duration=0.26,steps=15,hold=0.045,window=1.55},
            {mode="timed",duration=0.42,steps=22,hold=0.09,window=1.70},
        }
        local function ranchSolveLaser(gui,insetY,attempt)
            local panel=gui:FindFirstChild("Panel")
            local arrow=panel and panel:FindFirstChild("Arrow")
            local track=panel and panel:FindFirstChild("Track")
            if not arrow or not track or not arrow:IsA("GuiObject") then
                return false,"Laser Arrow/Track missing"
            end
            local cy=tonumber(track:GetAttribute("CenterY"))
            if not cy then return false,"Laser CenterY attribute missing" end
            local tpos,tsize=track.AbsolutePosition,track.AbsoluteSize
            local before=ranchPoint(arrow)
            local target=Vector2.new(math.clamp(before.X,tpos.X+4,
                tpos.X+tsize.X-4),tpos.Y+cy*tsize.Y)
            for index,profile in ipairs(ranchAlignProfiles) do
                if not ranchCanSolve(gui) then
                    return not ranchGuiActive(gui),"Laser input interrupted"
                end
                local start=ranchPoint(arrow)
                print(string.format(
                    "[Ranch Puzzles] ALIGN profile=%d mode=%s inset=%d targetY=%.1f",
                    index,profile.mode,insetY,target.Y))
                if not ranchGuiDrag(gui,start,target,insetY,profile) then
                    return false,"Laser GUI drag failed"
                end
                if ranchWaitClosed(gui,profile.window) then
                    return true,"Laser solved using "..profile.mode.." input"
                end
            end
            return false,"Laser still open after verified GUI profiles"
        end

        local ranchWireProfiles={
            {mode="frame",settle=0.075}, -- successful v6
            {mode="timed",duration=0.23,steps=14,hold=0.045,settle=0.12},
            {mode="timed",duration=0.38,steps=22,hold=0.09,settle=0.20},
        }
        local function ranchSolveWires(gui,insetY,attempt)
            local panel=gui:FindFirstChild("Panel")
            local left=panel and panel:FindFirstChild("Left")
            local right=panel and panel:FindFirstChild("Right")
            local lines=panel and panel:FindFirstChild("Lines")
            if not left or not right or not lines then
                return false,"Wire Left/Right/Lines missing"
            end
            local pairs={}
            for _,wire in ipairs(left:GetChildren()) do
                local color=wire:GetAttribute("Wire")
                local tip=wire:FindFirstChild("Tip")
                if type(color)=="string" and tip and tip:IsA("GuiObject") then
                    for _,other in ipairs(right:GetChildren()) do
                        if other:GetAttribute("Wire")==color then
                            local matching=other:FindFirstChild("Tip")
                            if matching and matching:IsA("GuiObject") then
                                pairs[#pairs+1]={color=color,source=tip,target=matching}
                                break
                            end
                        end
                    end
                end
            end
            if #pairs~=4 then
                return false,"Expected four wire pairs; got "..#pairs
            end
            table.sort(pairs,function(x,y)
                return x.source.AbsolutePosition.Y<y.source.AbsolutePosition.Y
            end)
            local completeCount=#pairs+1 -- one native Lines child is a template
            local last=#lines:GetChildren()
            local connected=0
            for _,pair in ipairs(pairs) do
                if not ranchGuiActive(gui) then return true,"Wire GUI closed" end
                if not ranchCanSolve(gui) then return false,"Wire input interrupted" end
                if #lines:GetChildren()>=completeCount then break end
                local registered=false
                for index,profile in ipairs(ranchWireProfiles) do
                    if not ranchCanSolve(gui) then
                        return not ranchGuiActive(gui),"Wire input interrupted"
                    end
                    -- Exact matching Tip centers: no extra 45-94px overshoot.
                    local from,to=ranchPoint(pair.source),ranchPoint(pair.target)
                    if not ranchGuiDrag(gui,from,to,insetY,profile) then
                        return false,"Wire drag failed: "..pair.color
                    end
                    task.wait(profile.settle)
                    if not ranchGuiActive(gui) then
                        return true,"Wire GUI closed after "..pair.color
                    end
                    local count=#lines:GetChildren()
                    if count>last then
                        connected+=count-last
                        last=count
                        registered=true
                        print("[Ranch Puzzles] WIRE "..pair.color..
                            " connected; profile="..index.." lines="..count)
                        break
                    end
                end
                if not registered and #lines:GetChildren()<completeCount then
                    return false,"Wire "..pair.color.." did not connect after three profiles"
                end
            end
            if #lines:GetChildren()>=completeCount then
                if ranchWaitClosed(gui,1.45) then
                    return true,"All four wires connected and GUI closed"
                end
                return true,"All four wires connected; waiting for native finish"
            end
            return false,"Wires incomplete; lines="..#lines:GetChildren()
        end

        local ranchVentProfiles={
            {label="PREFERRED-JUMP",fraction=0.29,mode="jump"},
            {label="EXTENDED-JUMP",fraction=0.34,mode="jump"},
            {label="PROVEN-DRAG",fraction=0.34,mode="timed",
                duration=0.32,steps=20,hold=0.09},
        }
        local function ranchVentCount(clip)
            local counter=clip:FindFirstChild("Counter")
            local text=counter and counter:IsA("TextLabel") and counter.Text or ""
            return tonumber(text:match("^(%d+)")),text
        end
        local function ranchVentSnapshot(strands)
            local sample={}
            for _,obj in ipairs(strands:GetChildren()) do
                if obj:IsA("GuiObject") then
                    local grab=obj:FindFirstChild("Grab")
                    if grab and grab:IsA("GuiObject") then
                        sample[obj]={position=ranchPoint(grab),
                            visible=obj.Visible,grabVisible=grab.Visible}
                    end
                end
            end
            return sample
        end
        local function ranchVentCandidates(strands,pulled)
            local list={}
            for obj,state in pairs(ranchVentSnapshot(strands)) do
                if state.visible and state.grabVisible and not pulled[obj] then
                    local grab=obj:FindFirstChild("Grab")
                    if grab then list[#list+1]={strand=obj,grab=grab} end
                end
            end
            table.sort(list,function(x,y)
                if x.strand.ZIndex==y.strand.ZIndex then
                    return x.strand.Name>y.strand.Name
                end
                return x.strand.ZIndex>y.strand.ZIndex
            end)
            return list
        end
        local function ranchVentTarget(panel,clip,from,fraction)
            local d=clip.AbsoluteSize.Y*fraction
            local p,s=panel.AbsolutePosition,panel.AbsoluteSize
            local margin=8
            local options={
                Vector2.new(math.clamp(from.X+d,p.X+margin,p.X+s.X-margin),from.Y),
                Vector2.new(math.clamp(from.X-d,p.X+margin,p.X+s.X-margin),from.Y),
                Vector2.new(from.X,math.clamp(from.Y+d,p.Y+margin,p.Y+s.Y-margin)),
                Vector2.new(from.X,math.clamp(from.Y-d,p.Y+margin,p.Y+s.Y-margin)),
            }
            local target,distance=options[1],-1
            for _,option in ipairs(options) do
                local n=(option-from).Magnitude
                if n>distance then target,distance=option,n end
            end
            return target,distance/math.max(1,clip.AbsoluteSize.Y)
        end
        local function ranchSolveVent(gui,insetY,attempt)
            local panel=gui:FindFirstChild("Panel")
            local clip=panel and panel:FindFirstChild("Clip")
            local strands=clip and clip:FindFirstChild("Strands")
            if not clip or not strands then
                return false,"Vent Clip/Strands missing"
            end
            local initial=select(1,ranchVentCount(clip))
            if not initial then return false,"Vent counter unreadable" end
            local pulled,visits={},{}
            local progress,failures=0,0
            local opened=os.clock()
            for trial=1,math.max(initial*3,45) do
                if not ranchGuiActive(gui) then return true,"Vent GUI closed" end
                if not ranchCanSolve(gui) then return false,"Vent input interrupted" end
                if os.clock()-opened>=27 then
                    return false,"Vent safety window elapsed, progress="..progress
                end
                local before=select(1,ranchVentCount(clip))
                if before and before<=0 then
                    print("[Ranch Puzzles] VENT all "..initial..
                        " strands removed in "..string.format("%.2f",os.clock()-opened).."s")
                    return true,"Vent counter reached zero"
                end
                local selected,least=nil,math.huge
                for _,candidate in ipairs(ranchVentCandidates(strands,pulled)) do
                    local point=ranchPoint(candidate.grab)
                    local n=visits[candidate.strand] or 0
                    if ranchInsidePanel(panel,point)
                        and n<#ranchVentProfiles and n<least then
                        selected,least=candidate,n
                        if n==0 then break end
                    end
                end
                if not selected then
                    return false,"No eligible Vent strand; remaining="..tostring(before)
                end
                local piece=selected.strand
                local profileIndex=(visits[piece] or 0)+1
                visits[piece]=profileIndex
                local profile=ranchVentProfiles[profileIndex]
                local from=ranchPoint(selected.grab)
                local goal,pull=ranchVentTarget(panel,clip,from,profile.fraction)
                if pull<=0.205 then
                    visits[piece]=#ranchVentProfiles
                else
                    local prior=ranchVentSnapshot(strands)
                    if not ranchGuiDrag(gui,from,goal,insetY,profile) then
                        return false,"Vent "..piece.Name.." input failed"
                    end
                    local after=select(1,ranchVentCount(clip))
                    local deadline=os.clock()+0.22
                    while ranchGuiActive(gui) and
                        (not after or not before or after>=before)
                        and os.clock()<deadline do
                        if not ranchCanSolve(gui) then break end
                        task.wait(0.015)
                        after=select(1,ranchVentCount(clip))
                    end
                    if after and before and after<before then
                        progress+=before-after
                        -- Overlapping hitboxes can intercept the pointer;
                        -- identify the real pulled strand by movement instead
                        -- of assuming it was the candidate we clicked.
                        local now=ranchVentSnapshot(strands)
                        for obj,old in pairs(prior) do
                            if not pulled[obj] then
                                local newer=now[obj]
                                local shift=newer and
                                    (newer.position-old.position).Magnitude or 0
                                local hidden=old.visible and
                                    (not newer or not newer.visible)
                                if shift>85 or hidden then pulled[obj]=true end
                            end
                        end
                        print("[Ranch Puzzles] VENT "..profile.label..
                            " progress="..progress.."/"..initial)
                        task.wait(0.025)
                    else
                        failures+=1
                        print("[Ranch Puzzles] VENT "..profile.label..
                            " missed "..piece.Name.."; retrying alternate strand")
                        task.wait(0.21)
                        if not ranchInsidePanel(panel,ranchPoint(selected.grab)) then
                            visits[piece]=#ranchVentProfiles
                        end
                    end
                end
            end
            return false,"Vent attempt limit, progress="..progress..
                " misses="..failures
        end

        local ranchSolvers={
            UfoWireMinigame=ranchSolveWires,
            UfoVentMinigame=ranchSolveVent,
            UfoAlignMinigame=ranchSolveLaser,
        }
        task.spawn(function()
            while not hubUnloaded do
                task.wait(0.18)
                local name,gui=ranchActivePuzzle()
                if ranchSession and gui~=ranchSession.gui then
                    local past=ranchSession
                    local elapsed=os.clock()-past.openedAt
                    print(string.format(
                        "[Ranch Puzzles] %s closed after %.1fs | autoAttempts=%d | GUI drags=%d | instantRequests=%d | autoAtOpen=%s; closure alone does not prove server completion",
                        past.name,elapsed,past.autoAttempts,past.drags,
                        past.instantRequests,tostring(past.autoEnabledAtOpen)))
                    if past.autoAttempts==0 and past.drags==0 then
                        print("[Ranch Puzzles] No automatic GUI dragging occurred in this session; possible built-in idle completion or manual input")
                    end
                    ranchSession=nil
                end
                if not gui then
                    ranchLastPuzzleGui=nil
                    ranchAttempts=0
                    ranchNextAttemptAt=0
                elseif gui~=ranchLastPuzzleGui then
                    ranchLastPuzzleGui=gui
                    ranchAttempts=0
                    ranchNextAttemptAt=0
                    ranchSession={
                        gui=gui,name=name,openedAt=os.clock(),
                        autoEnabledAtOpen=sharedFarmState.AutoSolveRanchPuzzles,
                        autoAttempts=0,drags=0,instantRequests=0
                    }
                    print("[Ranch Puzzles] Opened "..name
                        .." | AutoSolve="..tostring(sharedFarmState.AutoSolveRanchPuzzles))
                end
                if gui and sharedFarmState.AutoSolveRanchPuzzles
                    and hubWindow.Closed and not ranchPuzzleInputBusy
                    and not ranchInstantProbeActive
                    and ranchAttempts<3 and os.clock()>=ranchNextAttemptAt then
                    ranchAttempts+=1
                    ranchNextAttemptAt=os.clock()+8
                    ranchPuzzleInputBusy=true
                    if ranchSession and ranchSession.gui==gui then
                        ranchSession.autoAttempts+=1
                    end
                    local solver=ranchSolvers[name]
                    local attempt=ranchAttempts
                    task.spawn(function()
                        -- All three verified solvers need the correct inset immediately.
                        local insetY=ranchGuiInsetY()
                        print(string.format("[Ranch Puzzles] %s GUI solve attempt %d (inset=%d)",
                            name,attempt,insetY))
                        local ok,submitted,details=pcall(solver,gui,insetY,attempt)
                        ranchReleaseMouse()
                        ranchPuzzleInputBusy=false
                        if not ok then
                            warn("[Ranch Puzzles] Solver failed: "..tostring(submitted))
                        else
                            print("[Ranch Puzzles] "..tostring(details))
                            if not submitted then
                                warn("[Ranch Puzzles] Puzzle still needs manual action: "..tostring(details))
                            end
                        end
                        task.wait(0.65)
                        if not ranchPuzzleAlive(gui) then
                            print("[Ranch Puzzles] "..name.." GUI closed after solve; verify puzzle progression")
                        elseif attempt>=3 then
                            warn("[Ranch Puzzles] "..name.." still open after three drag attempts; stopped automatic retries")
                        end
                    end)
                end
            end
            ranchReleaseMouse()
        end)

        local function ranchInstantCompletionProbe()
            if ranchInstantProbeActive or ranchPuzzleInputBusy then
                warn("[Ranch Puzzles] Input already busy; instant test skipped")
                return
            end
            local name,gui=ranchActivePuzzle()
            if not name or not gui then
                warn("[Ranch Puzzles] Open a wire, vent or laser GUI before testing instant completion")
                return
            end
            local folder=ReplicatedStorage:FindFirstChild("UfoCrash")
            local remotes=folder and folder:FindFirstChild("Remotes")
            local remote=remotes and remotes:FindFirstChild("PuzzleDone")
            if not remote or not remote:IsA("RemoteEvent") then
                warn("[Ranch Puzzles] PuzzleDone RemoteEvent not available")
                return
            end
            ranchInstantProbeActive=true
            pcall(function() hubWindow:Close() end)
            task.spawn(function()
                task.wait(0.2)
                if not ranchPuzzleAlive(gui) or hubUnloaded then
                    ranchInstantProbeActive=false
                    warn("[Ranch Puzzles] Instant test aborted: puzzle closed or module unloaded")
                    return
                end
                -- Exactly ONE no-argument request. The diagnostic only
                -- identifies the remote, not its expected payload. This
                -- test cannot prove whether other payloads are accepted.
                local ok,err=pcall(function() remote:FireServer() end)
                if ranchSession and ranchSession.gui==gui and ok then
                    ranchSession.instantRequests+=1
                end
                print(string.format("[Ranch Puzzles] Instant test: %s PuzzleDone() sent=%s",
                    name,tostring(ok)))
                if not ok then warn("[Ranch Puzzles] Instant test error: "..tostring(err)) end
                task.wait(2.0)
                local closed=not ranchPuzzleAlive(gui)
                if closed then
                    warn("[Ranch Puzzles] Instant test: GUI CLOSED after PuzzleDone(); promising but server puzzle completion is NOT proven. Verify UFO progression.")
                else
                    warn("[Ranch Puzzles] Instant test: GUI STILL OPEN after PuzzleDone(); no-argument completion not confirmed (other payloads remain unknown).")
                end
                ranchInstantProbeActive=false
            end)
        end

        -- Ranch UFO-part objective, independent of the hay/needle remotes.
        -- Diagnostics show UfoSplitted piece flags (Revealed, Returned,
        -- HeldBy), CarryingUfoPart on LocalPlayer, and PartsReturned on the
        -- UFO model. Only these replicated state changes confirm progress.
        -- Isolate UFO automation helpers into their own Luau function scope.
        -- Chapter 3's shared module already has many local variables; keeping
        -- these helpers in the enclosing block risks the compiler's 200-local
        -- limit even though each pickup helper is independently small.
        local function runRanchUfoAutomation()
        local ranchUfoNextActionAt = 0
        local ranchUfoFailedUntil = {}
        local ranchUfoFailureCount = {}
        local ranchUfoLastNotice = -math.huge
        local function ranchUfoNotice(message, warning)
            if warning and os.clock()-ranchUfoLastNotice < 6 then return end
            if warning then
                ranchUfoLastNotice=os.clock()
                warn("[Ranch UFO] "..tostring(message))
            else
                print("[Ranch UFO] "..tostring(message))
            end
        end
        local function ranchUfoModel()
            local model=Workspace:FindFirstChild("UfoSplitted")
            return model and model:IsA("Model") and model or nil
        end
        local function ranchUfoReturned(model)
            return model and tonumber(model:GetAttribute("PartsReturned")) or 0
        end
        local function ranchUfoModelPiece(model,name)
            if not model or type(name)~="string" then return nil end
            local p=model:FindFirstChild(name,true)
            return p and p:IsA("BasePart") and p or nil
        end
        local function ranchUfoCarried()
            local name=LocalPlayer:GetAttribute("CarryingUfoPart")
            if type(name)=="string" and #name>0 then return name end
            -- Replication can deliver HeldBy before CarryingUfoPart. Do not
            -- misclassify a completed pickup as a failed pickup.
            local model=Workspace:FindFirstChild("UfoSplitted")
            if model then
                for _,p in ipairs(model:GetDescendants()) do
                    if p:IsA("BasePart") and p:GetAttribute("Returned")~=true then
                        local held=p:GetAttribute("HeldBy")
                        if held==LocalPlayer.UserId or held==tostring(LocalPlayer.UserId) then
                            return p.Name
                        end
                    end
                end
            end
            return nil
        end
        local function ranchUfoExposedPart(model)
            if not model then return nil end
            local root=farmRoot()
            local best,score=nil,math.huge
            -- The true revealed UFO pieces live in UfoSplitted; Scatter
            -- proxies are NOT the collectible objects.
            for _,piece in ipairs(model:GetDescendants()) do
                if piece:IsA("BasePart") and
                    piece:GetAttribute("UfoPiece")==true
                    and piece:GetAttribute("Revealed")==true
                    and piece:GetAttribute("Returned")~=true
                    and piece:GetAttribute("HeldBy")==nil then
                    local distance=root and (root.Position-piece.Position).Magnitude or 0
                    local untilAt=ranchUfoFailedUntil[piece.Name] or 0
                    if os.clock()>=untilAt and distance<score then
                        best,score=piece,distance
                    end
                end
            end
            return best
        end
        local function ranchUfoMainPart(model)
            local main=model and model:FindFirstChild("Main")
            if not main then return nil end
            if main:IsA("BasePart") then return main end
            -- Prefer the click-detector surface if one exists. The previous
            -- largest-part heuristic could aim at an inert decorative hull.
            for _,desc in ipairs(main:GetDescendants()) do
                if desc:IsA("ClickDetector") and desc.Parent
                    and desc.Parent:IsA("BasePart") then
                    return desc.Parent
                end
            end
            if main:IsA("Model") and main.PrimaryPart then return main.PrimaryPart end
            local best,volume=nil,0
            for _,part in ipairs(main:GetDescendants()) do
                if part:IsA("BasePart") and part.Transparency<1 then
                    local v=part.Size.X*part.Size.Y*part.Size.Z
                    if v>volume then best,volume=part,v end
                end
            end
            return best or main:FindFirstChildWhichIsA("BasePart",true)
        end
        local function ranchUfoRemote(name,...)
            local folder=ReplicatedStorage:FindFirstChild("UfoCrash")
            local remotes=folder and folder:FindFirstChild("Remotes")
            local remote=remotes and remotes:FindFirstChild(name)
            if not remote or not remote:IsA("RemoteEvent") then return false end
            local args=table.pack(...)
            local ok,err=pcall(function()
                remote:FireServer(table.unpack(args,1,args.n))
            end)
            if not ok then ranchUfoNotice(name.." failed: "..tostring(err),true) end
            return ok -- Local send only; never interpreted as server acceptance.
        end
        local function ranchUfoSafeToMove()
            return not hubUnloaded and sharedFarmState.AutoGrabAttachUfoParts
                and hubWindow.Closed and not needleBusy and not needlePriority()
                and not ranchInstantProbeActive and not ranchPuzzleInputBusy
                and ranchActivePuzzle()==nil
                and LocalPlayer:GetAttribute("NeedleInputLocked")~=true
                and LocalPlayer:GetAttribute("CutsceneActive")~=true
                and LocalPlayer:GetAttribute("HintViewerOpen")~=true
        end
        local function ranchUfoWaitFor(check,timeout)
            local deadline=os.clock()+timeout
            repeat
                if check() then return true end
                if not ranchUfoSafeToMove() then return false end
                task.wait(0.04)
            until os.clock()>=deadline
            return check()
        end

        -- Click from several CAMERA and ROOT angles. The old routine used
        -- a fixed diagonal position and blindly clicked screen center, even
        -- if a hay bale or decorative UFO part obscured the actual target.
        -- UFO pickups use VIEWPORT pixel coordinates, exactly as the
        -- working Chapter 1/2 needle pickup routines do. WorldToScreenPoint
        -- adds the GUI inset and can miss small exposed UFO parts. Attachment
        -- retains its already-working cursor targeting, unchanged.
        local function ranchUfoWorldClick(target,root,camera,check,stage)
            if not target or not target.Parent or not root or not camera then
                return false,"missing target/root/camera"
            end
            if check() then return true,"already confirmed" end
            local character=LocalPlayer.Character
            local center=target.Position
            local relative=root.Position-center
            local base=math.atan2(relative.Z,relative.X)
            local angles={0,math.pi/3,-math.pi/3,2*math.pi/3,
                -2*math.pi/3,math.pi}
            local attempts,occluded=0,0
            local lookHeight=stage=="attach" and 1.8 or 1.0
            for index,rotation in ipairs(angles) do
                if check() then return true,"confirmed between angles" end
                if not ranchUfoSafeToMove() or not target.Parent
                    or not root.Parent or camera~=Workspace.CurrentCamera then
                    return false,"interrupted"
                end
                local theta=base+rotation
                local direction=Vector3.new(math.cos(theta),0,math.sin(theta))
                local reach=stage=="attach" and 3.1 or 2.35
                local stand=center+direction*reach+Vector3.new(0,1.15,0)
                local aim=center
                local cameraReach=math.max(reach+0.8,
                    math.min(9.5,target.Size.Magnitude*0.50+1.3))
                -- Try elevated camera views on the later angles as well:
                -- an exposed piece can still sit behind a tall hay clump
                -- when viewed from every horizontal side.
                local height=index>=4
                    and (stage=="attach" and 3.1 or 3.5) or lookHeight
                local camPos=center+direction*cameraReach+
                    Vector3.new(0,height,0)
                -- Keep avatar upright; avoid placing the root directly into
                -- the part. Angles are relative to the avatar's initial side.
                root.CFrame=CFrame.lookAt(stand,
                    Vector3.new(center.X,stand.Y,center.Z))
                root.AssemblyLinearVelocity=Vector3.zero
                root.AssemblyAngularVelocity=Vector3.zero
                camera.CameraType=Enum.CameraType.Scriptable
                camera.CFrame=CFrame.lookAt(camPos,aim)
                -- The server validates proximity against replicated player
                -- position. One render frame was too short for this to settle:
                -- do not click until the moved root has had network time.
                task.wait(0.12)
                if check() then return true,"confirmed after approach" end
                if not ranchUfoSafeToMove() then return false,"interrupted" end
                local rootError=(root.Position-stand).Magnitude
                if rootError>5 then
                    print(string.format(
                        "[Ranch UFO] %s %s angle=%d root moved %.1f studs away from requested position; click may fail proximity validation",
                        tostring(stage),target.Name,index,rootError))
                end
                camera.CFrame=CFrame.lookAt(camPos,aim)
                local screen,visible
                if stage=="pickup" then
                    screen,visible=camera:WorldToViewportPoint(aim)
                else
                    screen,visible=camera:WorldToScreenPoint(aim)
                end
                local params=RaycastParams.new()
                params.FilterType=Enum.RaycastFilterType.Exclude
                if character then params.FilterDescendantsInstances={character} end
                params.IgnoreWater=true
                local ray=Workspace:Raycast(camPos,(aim-camPos)*1.05,params)
                local hit=ray and ray.Instance
                local clear=not hit or hit==target
                    or (stage=="attach" and target.Parent and
                        hit:IsDescendantOf(target.Parent))
                if not clear then
                    occluded+=1
                    print(string.format("[Ranch UFO] %s %s angle=%d obstructed by %s",
                        tostring(stage),target.Name,index,hit:GetFullName()))
                elseif visible then
                    local pos=Vector2.new(screen.X,screen.Y)
                    if stage~="pickup" then
                        -- Preserved attachment input from the previously
                        -- working release; do NOT modify its click semantics.
                        local down=false
                        local sent,err=pcall(function()
                            VirtualInputManager:SendMouseMoveEvent(
                                math.floor(pos.X+0.5),math.floor(pos.Y+0.5),game)
                            RunService.RenderStepped:Wait()
                            if not ranchUfoSafeToMove() then return end
                            VirtualInputManager:SendMouseButtonEvent(
                                math.floor(pos.X+0.5),math.floor(pos.Y+0.5),
                                0,true,game,0)
                            down=true
                            task.wait(0.06)
                        end)
                        if down then
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(
                                    math.floor(pos.X+0.5),math.floor(pos.Y+0.5),
                                    0,false,game,0)
                            end)
                        end
                        if not sent then
                            ranchUfoNotice("World click error: "..tostring(err),true)
                        end
                        if down then
                            attempts+=1
                            if ranchUfoWaitFor(check,0.33) then
                                print(string.format(
                                    "[Ranch UFO] %s %s confirmed via angle=%d clicks=%d",
                                    tostring(stage),target.Name,index,attempts))
                                return true,"click confirmed"
                            end
                        end
                    else
                        -- Chapter 1/2 pickup method: viewport center,
                        -- stable Scriptable camera and short repeated clicks.
                        local atCenter=(pos-camera.ViewportSize*0.5).Magnitude
                        if atCenter>18 then
                            print(string.format(
                                "[Ranch UFO] pickup %s angle=%d off-center %.1fpx",
                                target.Name,index,atCenter))
                        else
                            for pressIndex=1,2 do
                                if check() then return true,"confirmed before re-click" end
                                if not ranchUfoSafeToMove() then
                                    return false,"interrupted"
                                end
                                camera.CameraType=Enum.CameraType.Scriptable
                                camera.CFrame=CFrame.lookAt(camPos,aim)
                                local down=false
                                local sent,err=pcall(function()
                                    VirtualInputManager:SendMouseMoveEvent(
                                        math.floor(pos.X+0.5),math.floor(pos.Y+0.5),game)
                                    RunService.RenderStepped:Wait()
                                    if not ranchUfoSafeToMove() then return end
                                    camera.CameraType=Enum.CameraType.Scriptable
                                    camera.CFrame=CFrame.lookAt(camPos,aim)
                                    VirtualInputManager:SendMouseButtonEvent(
                                        math.floor(pos.X+0.5),math.floor(pos.Y+0.5),
                                        0,true,game,0)
                                    down=true
                                    task.wait(0.085)
                                end)
                                if down then
                                    pcall(function()
                                        VirtualInputManager:SendMouseButtonEvent(
                                            math.floor(pos.X+0.5),math.floor(pos.Y+0.5),
                                            0,false,game,0)
                                    end)
                                end
                                if not sent then
                                    ranchUfoNotice("Pickup click failed: "..tostring(err),true)
                                end
                                if down then
                                    attempts+=1
                                    if ranchUfoWaitFor(check,0.14) then
                                        print(string.format(
                                            "[Ranch UFO] pickup %s confirmed angle=%d click=%d viewport=(%.0f,%.0f)",
                                            target.Name,index,attempts,pos.X,pos.Y))
                                        return true,"click confirmed"
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(0.04)
            end
            ranchUfoNotice(string.format(
                "%s %s no state confirmation across %d angles (clicks=%d, occluded=%d)",
                tostring(stage),target.Name,#angles,attempts,occluded),true)
            return check(),"unconfirmed after angle sweep"
        end
        local function ranchUfoPickup(part,root,camera)
            local name=part.Name
            local function received()
                return ranchUfoCarried()==name
                    or part:GetAttribute("HeldBy")==LocalPlayer.UserId
                    or part:GetAttribute("HeldBy")==tostring(LocalPlayer.UserId)
            end
            if received() then return true end
            -- The native UfoPartsClient sends PickUpPart(part INSTANCE),
            -- not PickUpPart(part.Name). It checks UfoPiece, Revealed,
            -- Returned, HeldBy, and a character-to-part range of 14 studs.
            -- Try the authentic remote first, after allowing the character's
            -- teleported position to settle. Confirm replicated ownership;
            -- successful FireServer delivery alone is NOT completion.
            local eligible=part.Parent and part:GetAttribute("UfoPiece")==true
                and part:GetAttribute("Revealed")==true
                and part:GetAttribute("Returned")~=true
                and part:GetAttribute("HeldBy")==nil
            if not eligible then
                print("[Ranch UFO] Pickup "..name.." no longer eligible")
                return received()
            end
            if root and root.Parent and ranchUfoSafeToMove() then
                local center=part.Position
                local offset=root.Position-center
                local flat=Vector3.new(offset.X,0,offset.Z)
                local direction=flat.Magnitude>0.01 and flat.Unit or Vector3.new(1,0,0)
                local positions={
                    direction,
                    Vector3.new(-direction.Z,0,direction.X),
                }
                for index,bearing in ipairs(positions) do
                    if received() then return true end
                    if not ranchUfoSafeToMove() or not root.Parent or not part.Parent then
                        return received()
                    end
                    if part:GetAttribute("Revealed")~=true
                        or part:GetAttribute("Returned")==true
                        or part:GetAttribute("HeldBy")~=nil then
                        return received()
                    end
                    center=part.Position
                    local stand=center+bearing*3+Vector3.new(0,1.15,0)
                    root.CFrame=CFrame.lookAt(stand,
                        Vector3.new(center.X,stand.Y,center.Z))
                    root.AssemblyLinearVelocity=Vector3.zero
                    root.AssemblyAngularVelocity=Vector3.zero
                    task.wait(0.15)
                    if received() then return true end
                    if not ranchUfoSafeToMove() then return received() end
                    local range=(root.Position-part.Position).Magnitude
                    if range<=13.5 then
                        local sent=ranchUfoRemote("PickUpPart",part)
                        if sent and ranchUfoWaitFor(received,0.65) then
                            print(string.format(
                                "[Ranch UFO] PICKUP CONFIRMED %s using native instance remote; angle=%d range=%.1f",
                                name,index,range))
                            return true
                        end
                        print(string.format(
                            "[Ranch UFO] Pickup %s instance request not confirmed; angle=%d range=%.1f",
                            name,index,range))
                    else
                        print(string.format(
                            "[Ranch UFO] Pickup %s angle=%d too far after teleport: %.1f studs",
                            name,index,range))
                    end
                end
            end
            if not ranchUfoSafeToMove() then return received() end
            -- Chapter 2's reliable key pickup disables nearby hay queries
            -- and collisions JUST during targeting. A revealed UFO piece
            -- can overlap the same hay. Restore everything without exception
            -- before returning so normal farming remains unaffected.
            local filtered={}
            local filteredCount=0
            local function suppressHayBlockers()
                for _,folderName in ipairs({"HaystackClient","HaystackCollision"}) do
                    local folder=Workspace:FindFirstChild(folderName)
                    if folder then
                        for _,obj in ipairs(folder:GetDescendants()) do
                            if filteredCount>=48 then break end
                            if obj:IsA("BasePart") and obj~=part
                                and obj:GetAttribute("IsNeedleObjective")~=true
                                and (obj.CanQuery or obj.CanCollide)
                                and (obj.Position-part.Position).Magnitude <=
                                    7+math.min(obj.Size.Magnitude*0.5,4) then
                                local wasQuery,wasCollide=obj.CanQuery,obj.CanCollide
                                local ok=pcall(function()
                                    obj.CanCollide=false
                                    obj.CanQuery=false
                                end)
                                if ok then
                                    filtered[obj]={query=wasQuery,collide=wasCollide}
                                    filteredCount+=1
                                else
                                    pcall(function()
                                        obj.CanQuery=wasQuery
                                        obj.CanCollide=wasCollide
                                    end)
                                end
                            end
                        end
                    end
                end
            end
            local function restoreHayBlockers()
                for obj,was in pairs(filtered) do
                    if obj.Parent then
                        pcall(function()
                            obj.CanQuery=was.query
                            obj.CanCollide=was.collide
                        end)
                    end
                end
                table.clear(filtered)
            end
            local clickDetector=part:FindFirstChildWhichIsA("ClickDetector",true)
            ranchUfoNotice(string.format(
                "Revealed part %s: query=%s detector=%s (using Chapter 2-style viewport aim)",
                name,tostring(part.CanQuery),
                tostring(clickDetector and clickDetector:GetFullName() or "none")))
            local callOK,clicked,why=xpcall(function()
                suppressHayBlockers()
                if filteredCount>0 then
                    print("[Ranch UFO] Filtered "..filteredCount..
                        " nearby hay blockers for pickup of "..name)
                end
                return ranchUfoWorldClick(part,root,camera,received,"pickup")
            end,function(err) return tostring(err) end)
            restoreHayBlockers()
            if not callOK then
                ranchUfoNotice("Pickup camera failed: "..tostring(clicked),true)
                return received()
            end
            if clicked or received() then return true end
            if why=="interrupted" then return false end
            -- Only one existing remote fallback; delivery is NOT treated as
            -- successful unless the replicated carrying state confirms it.
            if ranchUfoSafeToMove() then
                -- Native remote also takes the part Instance on fallback.
                local sent=ranchUfoRemote("PickUpPart",part)
                if sent and ranchUfoWaitFor(received,0.65) then return true end
            end
            return received()
        end
        local function ranchUfoAttach(model,root,camera)
            local carrying=ranchUfoCarried()
            if not carrying then return false end
            local before=ranchUfoReturned(model)
            local piece=ranchUfoModelPiece(model,carrying)
            local function attached()
                return ranchUfoReturned(model)>before
                    or (piece and piece:GetAttribute("Returned")==true)
            end
            local main=ranchUfoMainPart(model)
            if not main then
                ranchUfoNotice("UFO Main attach surface not found",true)
                return false
            end
            ranchUfoNotice("Carrying "..carrying.."; attaching from alternate angles")
            local clicked,why=ranchUfoWorldClick(main,root,camera,attached,"attach")
            if clicked then return true end
            if why=="interrupted" then return false end
            -- No FireServer call is regarded as a confirmed attachment.
            if ranchUfoSafeToMove() then
                local sent=ranchUfoRemote("ReturnPart",carrying)
                if sent and ranchUfoWaitFor(attached,0.75) then return true end
            end
            return attached()
        end
        task.spawn(function()
            while not hubUnloaded do
                task.wait(0.10)
                if sharedFarmState.AutoGrabAttachUfoParts and not ranchUfoBusy
                    and os.clock()>=ranchUfoNextActionAt and ranchUfoSafeToMove() then
                    local model=ranchUfoModel()
                    if model and model:GetAttribute("Repaired")~=true
                        and ranchUfoReturned(model) <
                            (tonumber(model:GetAttribute("PartsTotal")) or 7) then
                        local carrying=ranchUfoCarried()
                        local piece=not carrying and ranchUfoExposedPart(model) or nil
                        if carrying or piece then
                            ranchUfoBusy=true
                            releaseSharedVacuum()
                            local root=farmRoot()
                            local camera=Workspace.CurrentCamera
                            local originalRoot=root and root.CFrame
                            local originalCamType=camera and camera.CameraType
                            local originalCamSubject=camera and camera.CameraSubject
                            local originalCamCF=camera and camera.CFrame
                            local attached=false
                            local pickedUp=false
                            local label=carrying or (piece and piece.Name) or "unknown"
                            local ok,err=xpcall(function()
                                if not root or not camera then return end
                                if carrying then
                                    attached=ranchUfoAttach(model,root,camera)
                                elseif piece then
                                    pickedUp=ranchUfoPickup(piece,root,camera)
                                    if pickedUp and ranchUfoSafeToMove() then
                                        -- Keep camera/root in-place while
                                        -- attaching so the server sees a
                                        -- contiguous carried-part sequence.
                                        attached=ranchUfoAttach(model,root,camera)
                                    end
                                end
                            end,function(e) return tostring(e) end)
                            if camera and camera.Parent then
                                pcall(function()
                                    camera.CameraSubject=originalCamSubject
                                    camera.CameraType=originalCamType
                                    camera.CFrame=originalCamCF
                                end)
                            end
                            if root and root.Parent and originalRoot then
                                pcall(function()
                                    root.CFrame=originalRoot
                                    root.AssemblyLinearVelocity=Vector3.zero
                                    root.AssemblyAngularVelocity=Vector3.zero
                                end)
                            end
                            ranchUfoBusy=false
                            if not ok then
                                ranchUfoNotice("Pickup/attach error: "..tostring(err),true)
                            end
                            local stillCarrying=ranchUfoCarried()
                            if attached then
                                ranchUfoFailureCount[label]=nil
                                ranchUfoFailedUntil[label]=nil
                                ranchUfoNotice(string.format(
                                    "UFO piece %s ATTACHED (PartsReturned=%d)",
                                    label,ranchUfoReturned(model)))
                                ranchUfoNextActionAt=os.clock()+0.60
                            elseif stillCarrying or pickedUp then
                                -- Pickup succeeded: do NOT mark as a failure
                                -- or apply the per-part pickup cooldown.
                                ranchUfoFailureCount[label]=nil
                                ranchUfoFailedUntil[label]=nil
                                ranchUfoNextActionAt=os.clock()+0.35
                                ranchUfoNotice(label..
                                    " PICKED UP; attachment pending (held="..
                                    tostring(stillCarrying)..")")
                            elseif not ranchUfoSafeToMove() then
                                -- Cutscene, puzzle opening, toggle OFF, or
                                -- user opening the menu is not a pickup fail.
                                ranchUfoNextActionAt=os.clock()+0.40
                            else
                                local failures=(ranchUfoFailureCount[label] or 0)+1
                                ranchUfoFailureCount[label]=failures
                                local cooldown=math.min(12,2*failures)
                                ranchUfoFailedUntil[label]=os.clock()+cooldown
                                ranchUfoNextActionAt=os.clock()+math.min(2,cooldown)
                                ranchUfoNotice(string.format(
                                    "%s pickup still unconfirmed (attempt=%d, retry=%ds, carried=%s, returned=%d)",
                                    label,failures,cooldown,tostring(stillCarrying),
                                    ranchUfoReturned(model)),true)
                            end
                        end
                    end
                end
            end
        end)

        end
        runRanchUfoAutomation()

        local tab=hubWindow:Tab({Title="Chapter 3 / Ranch",Icon="construction"})
        tab:Section({Title="UFO part collection"})
        farmToggle(tab,"AutoGrabAttachUfoParts","Auto Grab & Attach UFO Parts",
            "Automatically picks up revealed UFO pieces, approaches the UFO and attaches them. Confirms ownership and PartsReturned; starts OFF for testing.")
        tab:Section({Title="UFO puzzle automation"})
        farmToggle(tab,"AutoSolveRanchPuzzles","Auto Solve Ranch Puzzles",
            "Auto-drag matching wires, remove vent hay, and align laser when puzzle opens. OFF lets you test whether the game completes idle puzzles on its own.")
        tab:Button({
            Title="Test Instant Puzzle Completion (once)",
            Callback=ranchInstantCompletionProbe,
        })
        tab:Paragraph({
            Title="Ranch Puzzle Status",
            Desc="Use Auto Solve OFF and leave a puzzle untouched to measure built-in idle completion. Console logs time open, automated drags and instant probes. PuzzleDone() without arguments was not confirmed by tests.",
        })
        tab:Button({
            Title="Inspect Ranch puzzle and boss objects",
            Callback=function()
                local names={}
                for _, root in ipairs({Workspace,ReplicatedStorage}) do
                    for _, obj in ipairs(root:GetChildren()) do
                        if obj.Name:lower():find("puzzle",1,true)
                            or obj.Name:lower():find("boss",1,true)
                            or obj.Name:lower():find("ranch",1,true)
                            or obj.Name:lower():find("combat",1,true) then
                            names[#names+1]=root.Name.."."..obj.Name.." ("..obj.ClassName..")"
                        end
                    end
                end
                print("[BeyyHub Ranch] Discovery roots: "..(#names>0 and table.concat(names," | ") or "none found; run detailed Ranch dump"))
            end,
        })

    -- Chapter 3 boss combat (isolated): the reference script uses the game's
    -- PitchforkDig("Boss", headPosition, directionUnit) at live weak-point Bones.
    -- The existing vacuum worker holds Mouse1 independently, so the two attacks
    -- can run concurrently without competing simulated mouse-button workers.
    -- Boss head TNT and grab timing adapted from sceneton/script.
-- Owns TNT during boss combat; existing hay TNT runs outside the encounter.
local function createBossHeadTnt(options)
    local player,world=options.Player,options.World
    local pending,nextLightAt,lastStatus=nil,0,nil
    local connectedRemote,connection
    local function status(message)
        if message~=lastStatus then lastStatus=message; options.Status(message) end
    end
    local function locked()
        for _,flag in ipairs({"CutsceneActive","NeedleInputLocked","BossHeld","BossRagdolled","BossRagdollRecovering","BossKnockdownCamera"}) do
            if player:GetAttribute(flag)==true then return true end
        end
        return world:GetServerTimeNow()<(tonumber(player:GetAttribute("BossStunnedUntil")) or 0)
    end
    local function ready(boss)
        return options.Enabled() and not locked() and boss and boss:GetAttribute("BossWeakPoint")=="Head"
            and boss:GetAttribute("BossWeakPointDizzy")==true and boss:GetAttribute("BossVulnerable")==true
            and (tonumber(boss:GetAttribute("BossHealth")) or 0)>0
    end
    local function windowEnd(boss)
        return tonumber(boss and boss:GetAttribute("BossStunEndsAt"))
    end
    local function bind(remote)
        if remote==connectedRemote then return end
        if connection then connection:Disconnect() end
        connectedRemote=remote; connection=nil
        if remote then
            connection=remote.OnClientEvent:Connect(function(kind,payload)
                local now=world:GetServerTimeNow()
                if kind=="lit" and pending and pending.stage=="lighting" then
                    pending.stage="lit"; pending.litAt=now
                    nextLightAt=now+pending.cooldown
                    status("Lit; preparing vulnerable-head throw")
                    options.Record("tnt_lit",{at=now,slot=player:GetAttribute("BossEquippedSlot")})
                elseif kind=="denied" and pending then
                    pending=nil; nextLightAt=math.max(nextLightAt,now+math.max(0.5,tonumber(payload) or 1))
                    status("Server denied TNT; waiting for retry")
                    options.Record("tnt_denied",{retry=payload})
                end
            end)
        end
    end
    local function trajectory(origin,target,minSpeed,maxSpeed,gravity)
        local delta=target-origin
        -- Earliest feasible ballistic path within the replicated throw-speed limits.
        for index=3,24 do
            local flight=index*0.025
            local velocity=delta/flight+Vector3.new(0,gravity*flight*0.5,0)
            if velocity.Magnitude>=minSpeed and velocity.Magnitude<=maxSpeed then return velocity,flight end
        end
    end
    local controller={}
    function controller.Tick()
        local remote=options.Remote()
        bind(remote)
        if not remote then status("Waiting for TNT remote"); return end
        local now=world:GetServerTimeNow()
        local boss=options.Boss()
        if pending and pending.boss~=boss then pending=nil end
        if pending then
            if pending.stage=="lighting" then
                if now-pending.requestAt>2 then
                    pending=nil; status("Lighting response timeout; waiting for cooldown")
                end
                return
            end
            if now>=pending.litAt+pending.fuse then pending=nil; status("Fuse elapsed; waiting for next window"); return end
            if not ready(boss) then status("Lit TNT: head window unavailable; throw withheld"); return end
            if now<pending.litAt+pending.lightTime then return end
            local head=player.Character and player.Character:FindFirstChild("Head")
            local root=boss:FindFirstChild("RootPart")
            local bone=root and root:FindFirstChild("Head",true)
            if not head or not bone or not bone:IsA("Bone") then status("Waiting for head geometry"); return end
            local origin=head.CFrame*CFrame.new(0.8,-0.8,-1.5)
            local target=bone.TransformedWorldCFrame.Position
            local velocity,flight=trajectory(origin.Position,target,pending.minSpeed,pending.maxSpeed,world.Gravity)
            if not velocity then status("Head outside feasible TNT trajectory"); return end
            local ends=windowEnd(boss)
            -- Reserve time for both impact and explosion, plus replication margin.
            local explosionAt=pending.litAt+pending.fuse
            if not ends or math.max(now+flight,explosionAt)+0.2>=ends then status("Window too short; throw withheld"); return end
            if now+flight>=explosionAt-0.1 then status("Fuse too short for head impact; throw withheld"); return end
            local ok,err=pcall(function() remote:FireServer("throw",origin,velocity) end)
            options.Record("tnt_throw",{sent=ok,error=not ok and tostring(err) or nil,flight=flight,
                fuseRemaining=explosionAt-now,windowRemaining=ends-now,slot=player:GetAttribute("BossEquippedSlot")})
            pending=nil
            status(ok and "Thrown at vulnerable head; awaiting hit feedback" or "TNT throw error")
            return
        end
        if not options.Enabled() then status("Boss TNT disabled / menu open"); return end
        if player:GetAttribute("TntOwned")~=true then status("TNT not owned"); return end
        if now<nextLightAt then status("Waiting for TNT cooldown"); return end
        if not ready(boss) then status("Waiting for vulnerable head"); return end
        local cfg=options.Config()
        local fuse=tonumber(options.BossConfig.TntFuse) or (cfg and tonumber(cfg.TNT_FUSE_TIME))
        local light=cfg and tonumber(cfg.TNT_LIGHT_TIME)
        local minSpeed=cfg and tonumber(cfg.TNT_MIN_THROW_SPEED)
        local maxSpeed=cfg and tonumber(cfg.TNT_MAX_THROW_SPEED)
        if not fuse or fuse<=0 or not light or light<0 or not minSpeed or not maxSpeed or maxSpeed<minSpeed then
            status("Waiting for replicated TNT timing / speed config"); return
        end
        local ends=windowEnd(boss)
        if not ends or now+fuse+0.4>=ends then status("Head window too short to light TNT"); return end
        local head=player.Character and player.Character:FindFirstChild("Head")
        local body=boss:FindFirstChild("RootPart")
        local bone=body and body:FindFirstChild("Head",true)
        if not head or not bone or not bone:IsA("Bone") then return end
        local origin=head.CFrame*CFrame.new(0.8,-0.8,-1.5)
        if not trajectory(origin.Position,bone.TransformedWorldCFrame.Position,minSpeed,maxSpeed,world.Gravity) then
            status("Head outside feasible TNT trajectory"); return
        end
        local cooldown=math.max(0.5,tonumber(player:GetAttribute("TntCooldown")) or tonumber(options.BossConfig.TntCooldown) or 10,
            tonumber(options.LightCooldown()) or 0)
        pending={stage="lighting",boss=boss,requestAt=now,fuse=fuse,
            lightTime=math.max(light,tonumber(options.ThrowDelay()) or 0),
            minSpeed=minSpeed,maxSpeed=maxSpeed,cooldown=cooldown}
        -- Reserve cooldown even if a reply is lost; never spam light while awaiting acknowledgement.
        nextLightAt=now+cooldown
        local ok,err=pcall(function() remote:FireServer("light") end)
        options.Record("tnt_light",{sent=ok,error=not ok and tostring(err) or nil,slot=player:GetAttribute("BossEquippedSlot")})
        if not ok then pending=nil end
        status(ok and "Lighting TNT; awaiting server acknowledgement" or "TNT light error")
    end
    function controller.Stop()
        pending=nil
        if connection then connection:Disconnect(); connection=nil end
    end
    return controller
end


    local function installChapter3BossCombat()
        local tab=hubWindow:Tab({Title="Chapter 3 Boss",Icon="swords"})
        farmToggle(tab,"AutoBossFight","Auto Boss Fight",
            "Cooldown-paced pitchfork hits at exposed boss weak points. Starts OFF.")
        farmToggle(tab,"AutoBossBodyHits","Hit Body Between Weak Points",
            "Attack Chest/Pelvis while no critical point is available.")
        farmToggle(tab,"AutoBossVacuum","Use Vacuum During Boss",
            "Keeps the existing single vacuum worker active during boss combat.")
        farmToggle(tab,"AutoBossAimVacuum","Aim Vacuum at Boss",
            "Keeps the camera centered on the boss during unlocked combat.")
        farmToggle(tab,"AutoBossFinish","Auto Grab Key & Trigger Cutscene",
            "After boss defeat, collect CarKey and enter the post-fight trigger area. OFF by default.")
        farmToggle(tab,"AutoBossGrabEscape","Auto Grab Escape",
            "Respond to server grab prompts at their replicated perfect timing.")
        farmToggle(tab,"BossDiagnostics","Boss Diagnostics",
            "Record bounded hit, TNT, vacuum and round-end diagnostics locally.")
        local tntLabel=tab:Paragraph({Title="Boss TNT Status",Desc="Waiting for vulnerable head"})
        local vacuumLabel=tab:Paragraph({Title="Boss Vacuum Status",Desc="Waiting for boss"})
        local roundLabel=tab:Paragraph({Title="Round End Status",Desc="Waiting for completion"})
        local status=tab:Paragraph({Title="Boss Combat Status",Desc="Auto Boss Fight is OFF"})
        local bossFolder=ReplicatedStorage:FindFirstChild("BossFight")
        local feedback=bossFolder and bossFolder:FindFirstChild("Feedback")
        local listeners={}
        local alive=true
        local currentBoss=nil
        local bones={}
        local nextSend=0
        local lastStatus=""
        local lastStatusAt=0
        local sent=0
        local confirmed=0
        local criticalHits=0
        local aimTarget=nil
        local aimAllowed=false
        local rangeNotice=0
        local renderName="BeyyBossVacuumAim_"..tostring(LocalPlayer.UserId)
        local weakExcluded={
            Intro=true,Sleeping=true,Rising=true,Falling=true,
            Returning=true,Unavailable=true,Defeated=true,
        }
        local function bossState()
            local boss=Workspace:FindFirstChild("HayGolem_Rig")
            if not boss then return nil,nil end
            return boss,boss:GetAttribute("BossState")
        end
        bossCombatActive=function()
            if hubUnloaded or not alive or not sharedFarmState.AutoBossFight then
                return false
            end
            local boss,state=bossState()
            return boss~=nil and type(state)=="string"
                and state~="" and not weakExcluded[state]
        end
        local function combatLocked()
            if not bossCombatActive() or not hubWindow.Closed
                or sharedFarmPuzzleBusy() or needleBusy or needlePriority()
                or LocalPlayer:GetAttribute("NeedleOwned")==true then
                return true
            end
            for _,name in ipairs({
                "NeedleInputLocked","CutsceneActive","HintViewerOpen",
                "BossHeld","BossRagdolled","BossRagdollRecovering",
                "BossKnockdownCamera",
            }) do
                if LocalPlayer:GetAttribute(name)==true then return true end
            end
            return Workspace:GetServerTimeNow()<
                (tonumber(LocalPlayer:GetAttribute("BossStunnedUntil")) or 0)
        end
        local function report(message,force)
            local now=os.clock()
            if not force and message==lastStatus and now-lastStatusAt<1.25 then return end
            lastStatus,lastStatusAt=message,now
            pcall(function()
                status:SetDesc(message..
                    string.format(" | requests=%d confirmed=%d crit=%d",
                        sent,confirmed,criticalHits))
            end)
            if force then print("[Beyy Boss] "..message) end
        end
        local function findBone(boss,name)
            if currentBoss~=boss then
                currentBoss=boss
                table.clear(bones)
            end
            local root=boss:FindFirstChild("RootPart")
            if not root then return nil end
            local hit=bones[name]
            if hit and hit:IsA("Bone") and hit:IsDescendantOf(root) then
                return hit
            end
            hit=root:FindFirstChild(name,true)
            if hit and hit:IsA("Bone") then
                bones[name]=hit
                return hit
            end
            return nil
        end
        if feedback and feedback:IsA("RemoteEvent") then
            listeners[#listeners+1]=feedback.OnClientEvent:Connect(function(kind,userId,amount,position,tool,grade)
                if not alive or kind~="Hit" or userId~=LocalPlayer.UserId then return end
                if tool=="Pitchfork" then
                    confirmed+=1
                    if grade=="Critical" or grade=="Crit" or grade=="Weak" then
                        criticalHits+=1
                    end
                    report(string.format("Confirmed pitchfork hit: %s (%s)",
                        tostring(amount),tostring(grade or "Normal")),true)
                elseif tool=="Vacuum" then
                    report("Confirmed vacuum hit: "..tostring(amount),false)
                end
            end)
        end
        -- Only steer camera in active, unlocked combat. The game's normal
        -- camera retains its type, so releasing the boss switch restores
        -- native camera control on the next frame.
        RunService:BindToRenderStep(renderName,
            Enum.RenderPriority.Last.Value+20,function()
                if not alive or not sharedFarmState.AutoBossVacuum
                    or not sharedFarmState.AutoBossAimVacuum
                    or not aimAllowed or not aimTarget then return end
                local cam=Workspace.CurrentCamera
                if not cam or cam.CameraType==Enum.CameraType.Scriptable then return end
                if (aimTarget-cam.CFrame.Position).Magnitude<0.1 then return end
                cam.CFrame=CFrame.lookAt(cam.CFrame.Position,aimTarget)
            end)
        -- Reference: sceneton/script Chapter 3 AutoBossFinish. The native
        -- neck key uses a ProximityPrompt; ownership is HasCarKey. The pig
        -- cutscene trigger requires moving around its location, not merely
        -- changing HumanoidRootPart.CFrame once. All activity is bounded and
        -- gated by the new toggle, and runs only AFTER boss defeat.
        local function installBossKeyFinish()
            local running=true
            local postFight=false
            local finalStage="idle"
            local startedAt=0
            local deadline=0
            local nextKeyAt=0
            local circleAttempts=0
            local watchedBoss=nil
            local watchedEncounter=nil
            local keyDown=nil
            local walkingHumanoid=nil
            local pigCenter=Vector3.new(-658.85,3.76,285.29)
            local pendingCause="none"
            local awaitCutsceneAt=0
            local function enabled()
                return running and alive and not hubUnloaded
                    and sharedFarmState.AutoBossFight
                    and sharedFarmState.AutoBossFinish
            end
            local function available()
                return enabled() and hubWindow.Closed
            end
            local function stopMoving()
                if walkingHumanoid then
                    local humanoid=walkingHumanoid
                    walkingHumanoid=nil
                    pcall(function()
                        humanoid:Move(Vector3.zero,false)
                        local root=LocalPlayer.Character
                            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if root then humanoid:MoveTo(root.Position) end
                    end)
                end
            end
            local function releaseKey()
                if keyDown then
                    local code=keyDown
                    keyDown=nil
                    pcall(function()
                        VirtualInputManager:SendKeyEvent(false,code,false,game)
                    end)
                end
            end
            local function reset()
                stopMoving()
                releaseKey()
                postFight=false
                finalStage="idle"
                startedAt=0
                deadline=0
                nextKeyAt=0
                circleAttempts=0
                awaitCutsceneAt=0
                pendingCause="none"
            end
            local function announce(message)
                print("[Beyy Boss Finish] "..message)
                report("Finish: "..message,true)
            end
            local function begin(reason)
                if not enabled() or postFight or finalStage=="done" then return end
                postFight=true
                finalStage="key"
                startedAt=os.clock()
                deadline=startedAt+60
                pendingCause=reason
                announce("Boss defeated ("..tostring(reason).."); finding CarKey neck prompt")
            end
            local function finishConfirmed()
                return LocalPlayer:GetAttribute("CutsceneActive")==true
                    or LocalPlayer:GetAttribute("NeedleRoundComplete")==true
            end
            local function keyAcquired()
                if not enabled() or LocalPlayer:GetAttribute("HasCarKey")~=true
                    or finishConfirmed() then return end
                if not postFight then begin("HasCarKey") end
                if postFight and finalStage=="key" then
                    finalStage="teleport"
                    deadline=os.clock()+120
                    announce("HasCarKey confirmed; moving to pig cutscene trigger now")
                end
            end
            listeners[#listeners+1]=LocalPlayer:GetAttributeChangedSignal("HasCarKey"):Connect(keyAcquired)
            local function safeForKey()
                if not available() then return false end
                for _,attribute in ipairs({
                    "CutsceneActive","NeedleInputLocked","BossHeld",
                    "BossRagdolled","BossRagdollRecovering",
                }) do
                    if LocalPlayer:GetAttribute(attribute)==true then return false end
                end
                return true
            end
            local function circlePig(character,root)
                local humanoid=character:FindFirstChildOfClass("Humanoid")
                if not humanoid or humanoid.Health<=0 then
                    return false,"Humanoid unavailable"
                end
                if not available() or not root.Parent then
                    return false,"Interrupted"
                end
                if finishConfirmed() then return true,"Cutscene already active" end
                local crossings={
                    Vector3.new(14,0,0),Vector3.new(0,0,14),
                    Vector3.new(10,0,10),Vector3.new(10,0,-10),
                }
                local expiry=os.clock()+35
                walkingHumanoid=humanoid
                announce("HasCarKey verified; crossing pig trigger with 28-stud passes")
                local completed=0
                for index,offset in ipairs(crossings) do
                    if not available() or LocalPlayer.Character~=character
                        or not root.Parent or humanoid.Health<=0 then
                        stopMoving()
                        return false,"Movement interrupted"
                    end
                    if finishConfirmed() then
                        stopMoving()
                        return true,"Cutscene confirmed before crossing"
                    end
                    local from=pigCenter+offset
                    local goal=pigCenter-offset
                    root.CFrame=CFrame.lookAt(from,goal,Vector3.yAxis)
                    root.AssemblyLinearVelocity=Vector3.zero
                    root.AssemblyAngularVelocity=Vector3.zero
                    task.wait(0.08)
                    if finishConfirmed() then
                        stopMoving()
                        return true,"Cutscene confirmed after positioning"
                    end
                    if not available() or LocalPlayer.Character~=character
                        or not root.Parent or humanoid.Health<=0 then
                        stopMoving()
                        return false,"Movement interrupted after positioning"
                    end
                    humanoid:MoveTo(goal)
                    local legEnd=math.min(expiry,os.clock()+5)
                    local arrived=false
                    repeat
                        if finishConfirmed() then
                            stopMoving()
                            return true,"Cutscene confirmed during trigger crossing "..index
                        end
                        if not available() or LocalPlayer.Character~=character
                            or not root.Parent or humanoid.Health<=0 then
                            stopMoving()
                            return false,"Movement interrupted"
                        end
                        local difference=root.Position-goal
                        arrived=Vector3.new(difference.X,0,difference.Z).Magnitude<=2
                        if arrived then break end
                        task.wait(0.05)
                    until os.clock()>=legEnd
                    if arrived then completed+=1
                    else announce("Trigger crossing "..index.." did not reach endpoint; trying next approach") end
                    if os.clock()>=expiry then break end
                end
                stopMoving()
                return completed>0,"Completed "..completed.." extended trigger crossings; awaiting server cutscene"
            end
            if feedback and feedback:IsA("RemoteEvent") then
                listeners[#listeners+1]=feedback.OnClientEvent:Connect(
                    function(kind,eventName)
                        if kind=="BossEvent" and eventName=="Defeated" then
                            begin("BossEvent")
                        end
                    end)
            end
            task.spawn(function()
                local ok,err=xpcall(function()
                    while running and alive and not hubUnloaded do
                        task.wait(0.10)
                        if not enabled() then
                            if postFight or finalStage~="idle" then reset() end
                            continue
                        end
                        local boss=Workspace:FindFirstChild("HayGolem_Rig")
                        local encounter=boss and boss:GetAttribute("Encounter")
                        -- Do not reset on a brief disappearance after defeat.
                        if boss and (boss~=watchedBoss
                            or encounter~=watchedEncounter) then
                            watchedBoss= boss
                            watchedEncounter=encounter
                            reset()
                        end
                        if boss and boss:GetAttribute("BossState")=="Defeated" then
                            begin("BossState")
                        end
                        keyAcquired()
                        if not postFight or finalStage=="done" then continue end
                        if os.clock()>deadline then
                            announce("Finish timed out at stage "..finalStage)
                            finalStage="done"
                            postFight=false
                            continue
                        end
                        if finalStage=="key" then
                            if os.clock()<nextKeyAt or not safeForKey() then
                                continue
                            end
                            local body=boss and boss:FindFirstChild("HayGolem_Body")
                            local key=body and body:FindFirstChild("CarKey")
                            local prompt=key and key:FindFirstChild("TakeKeyPrompt")
                            if not key or not key:IsA("BasePart")
                                or not prompt or not prompt:IsA("ProximityPrompt")
                                or not prompt.Enabled then
                                continue
                            end
                            local character=LocalPlayer.Character
                            local root=character and character:FindFirstChild("HumanoidRootPart")
                            if not root then continue end
                            nextKeyAt=os.clock()+1.5
                            local from=root.Position-key.Position
                            local flat=Vector3.new(from.X,0,from.Z)
                            local direction=flat.Magnitude>0.01
                                and flat.Unit or Vector3.new(1,0,0)
                            local reach=math.min(3,
                                math.max(0.5,prompt.MaxActivationDistance*0.5))
                            root.CFrame=CFrame.lookAt(key.Position+direction*reach,
                                key.Position)
                            root.AssemblyLinearVelocity=Vector3.zero
                            root.AssemblyAngularVelocity=Vector3.zero
                            task.wait(0.20)
                            if not safeForKey() or not prompt.Parent
                                or not root.Parent or root~=
                                    (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then
                                continue
                            end
                            if LocalPlayer:GetAttribute("HasCarKey")==true then continue end
                            if (root.Position-key.Position).Magnitude>
                                prompt.MaxActivationDistance then
                                announce("Key pickup out of prompt range after teleport")
                                continue
                            end
                            local success,error=pcall(function()
                                if type(fireproximityprompt)=="function" then
                                    fireproximityprompt(prompt)
                                else
                                    local button=prompt.KeyboardKeyCode
                                    keyDown=button
                                    VirtualInputManager:SendKeyEvent(true,button,false,game)
                                    task.wait(math.max(0,prompt.HoldDuration)+0.10)
                                end
                            end)
                            releaseKey()
                            announce(success and
                                "Activated TakeKeyPrompt; awaiting HasCarKey"
                                or ("Key prompt error: "..tostring(error)))
                        elseif finalStage=="teleport" then
                            if not available() then continue end
                            if finishConfirmed() then
                                finalStage="done"
                                postFight=false
                                announce("Post-boss cutscene confirmed")
                                continue
                            end
                            local character=LocalPlayer.Character
                            local root=character and character:FindFirstChild("HumanoidRootPart")
                            if not root then continue end
                            finalStage="walking"
                            circleAttempts+=1
                            local reached,reason=circlePig(character,root)
                            announce("Pig cutscene trigger: "..tostring(reason))
                            if finishConfirmed() then
                                finalStage="done"
                                postFight=false
                                announce("Post-boss cutscene confirmed")
                            elseif reached then
                                finalStage="awaitCutscene"
                                awaitCutsceneAt=os.clock()
                            elseif enabled() and circleAttempts<3 then
                                finalStage="retry"
                                nextKeyAt=os.clock()+0.35
                            else
                                announce("Pig trigger navigation stopped after "..
                                    circleAttempts.." attempt(s), no cutscene confirmed")
                                finalStage="done"
                                postFight=false
                            end
                        elseif finalStage=="retry" then
                            if os.clock()>=nextKeyAt then
                                finalStage="teleport"
                            end
                        elseif finalStage=="awaitCutscene" then
                            if finishConfirmed() then
                                finalStage="done"
                                postFight=false
                                announce("Post-boss cutscene confirmed")
                            elseif os.clock()-awaitCutsceneAt>=3 then
                                if circleAttempts<3 then
                                    announce("Cutscene not confirmed; retrying wider trigger crossing")
                                    finalStage="retry"
                                    nextKeyAt=os.clock()+0.35
                                else
                                    announce("No cutscene after three extended trigger attempts")
                                    finalStage="done"
                                    postFight=false
                                end
                            end
                        end
                    end
                end,function(e) return tostring(e) end)
                stopMoving()
                releaseKey()
                if not ok then
                    warn("[Beyy Boss Finish] Worker error: "..tostring(err))
                end
            end)
            return function()
                running=false
                stopMoving()
                releaseKey()
            end
        end
        local stopBossFinish=installBossKeyFinish()

        local player,WS,RS,Http=LocalPlayer,Workspace,ReplicatedStorage,game:GetService("HttpService")
        local fight=bossFolder
        local started=os.clock()
        local trace={version=1,source="sceneton/script boss updates",events={},vacuumSamples={},roundEndEvents={},
            grabInputs=0,confirmedHits=0,reportedDamage=0}
        local grabSession
        local nextVacuumSample=0
        local vacuumLastHeat,vacuumProgressAt,vacuumState
        local roundWatched={}
        local nextRoundSave=0
        local bossTnt
        local function log(message,details)
            if sharedFarmState.BossDiagnostics then print("[Beyy Boss] "..message) end
            if #trace.events<2048 then
                trace.events[#trace.events+1]={at=os.clock()-started,status=message,details=details}
            else trace.droppedEvents=(trace.droppedEvents or 0)+1 end
        end
        local function saveTrace(force)
            if not force and not sharedFarmState.BossDiagnostics then return end
            if type(writefile)=="function" then
                pcall(function()
                    if type(makefolder)=="function" then pcall(makefolder,"BeyyHub") end
                    writefile("BeyyHub/chapter3_boss_integrated.json",Http:JSONEncode(trace))
                end)
            end
        end
local function encodeRoundValue(value,depth,seen)
    depth=depth or 0; seen=seen or {}
    local kind=typeof(value)
    if kind=="nil" or kind=="boolean" then return value end
    if kind=="number" then return value==value and math.abs(value)<math.huge and value or tostring(value) end
    if kind=="string" then return value:sub(1,1000) end
    if kind=="Instance" then return {path=value:GetFullName(),class=value.ClassName} end
    if kind=="Vector3" then return {x=value.X,y=value.Y,z=value.Z} end
    if kind=="table" then
        if depth>=4 or seen[value] then return "[bounded table]" end
        seen[value]=true
        local result,count={},0
        for key,item in pairs(value) do
            count+=1; if count>40 then result.__truncated=true; break end
            result[tostring(key)]=encodeRoundValue(item,depth+1,seen)
        end
        seen[value]=nil; return result
    end
    return tostring(value)
end
local function recordRound(kind,path,payload)
    if not alive then return end
    local row={at=os.clock()-started,serverTime=WS:GetServerTimeNow(),kind=kind,path=path,payload=encodeRoundValue(payload)}
    if #trace.roundEndEvents<128 then trace.roundEndEvents[#trace.roundEndEvents+1]=row
    else trace.droppedRoundEvents=(trace.droppedRoundEvents or 0)+1 end
    pcall(function() roundLabel:SetDesc(kind..": "..path) end)
    if sharedFarmState.BossDiagnostics then print("[Round Monitor] "..kind..": "..path) end
    saveTrace()
end
local function monitorAttribute(obj,name)
    local entry=roundWatched[obj]
    if not entry then entry={}; roundWatched[obj]=entry end
    if entry[name] then return end
    entry[name]=true
    recordRound("attribute_initial",obj:GetFullName().."."..name,obj:GetAttribute(name))
    listeners[#listeners+1]=obj:GetAttributeChangedSignal(name):Connect(function()
        recordRound("attribute_changed",obj:GetFullName().."."..name,obj:GetAttribute(name))
    end)
end
local function monitorRemote(remote)
    if not remote or roundWatched[remote] or not remote:IsA("RemoteEvent") then return end
    roundWatched[remote]=true
    recordRound("listener_ready",remote:GetFullName(),nil)
    listeners[#listeners+1]=remote.OnClientEvent:Connect(function(...)
        recordRound("server_event",remote:GetFullName(),table.pack(...))
    end)
end
local function refreshRoundMonitors()
    monitorAttribute(player,"NeedleRoundComplete")
    local folder=RS:FindFirstChild("NeedleHaystack")
    if folder then
        monitorRemote(folder:FindFirstChild("NeedleRoundCompleted"))
        monitorAttribute(folder,"RoundFinishedElapsed")
        monitorAttribute(folder,"RoundStartedAt")
    end
    local finish=RS:FindFirstChild("TruckFinish")
    if finish then
        for _,name in ipairs({"Cutscene","Blocked","Skip"}) do monitorRemote(finish:FindFirstChild(name)) end
    end
end

local function tickGrab()
    if not sharedFarmState.AutoBossFight or not sharedFarmState.AutoBossGrabEscape or not hubWindow.Closed then return end
    local session=grabSession
    if not session or session.successes>=session.needed then return end
    if player:GetAttribute("BossHeld")~=true then return end
    local boss=WS:FindFirstChild("HayGolem_Rig")
    if not boss or boss:GetAttribute("GrabVictim")~=player.UserId then return end
    local remote=fight and fight:FindFirstChild("GrabInput")
    if not remote or not remote:IsA("RemoteEvent") then return end
    local now=WS:GetServerTimeNow()
    for index,prompt in ipairs(session.prompts) do
        if not session.sent[index] then
            local perfectAt=tonumber(prompt.perfectAt)
            local shownAt=tonumber(prompt.shownAt)
            if not perfectAt or not shownAt or type(prompt.key)~="string" then session.sent[index]="invalid"
            elseif now>perfectAt+session.good then session.sent[index]="expired"
            elseif now>=shownAt and now>=perfectAt then
                session.sent[index]=true
                local ok,err=pcall(function() remote:FireServer(session.id,index,prompt.key,now) end)
                if ok then trace.grabInputs+=1 end
                log(ok and "Sent timed grab response: "..prompt.key or "Grab request error: "..tostring(err),
                    {kind="grab_input",index=index,key=prompt.key,offset=now-perfectAt,sent=ok})
                return
            else return end
        end
    end
end

local function sampleVacuum()
    local now=WS:GetServerTimeNow()
    if now<nextVacuumSample then return end
    nextVacuumSample=now+0.25
    local heat=tonumber(player:GetAttribute("VacuumHeat"))
    local activeVacuum=player:GetAttribute("VacuumActive")
    local overheated=player:GetAttribute("VacuumOverheated")
    local slot=player:GetAttribute("BossEquippedSlot")
    local boss=WS:FindFirstChild("HayGolem_Rig")
    local state="unknown"
    local locked=player:GetAttribute("BossHeld")==true or player:GetAttribute("BossRagdolled")==true
        or player:GetAttribute("BossKnockdownCamera")==true or player:GetAttribute("CutsceneActive")==true
        or player:GetAttribute("NeedleInputLocked")==true or now<(tonumber(player:GetAttribute("BossStunnedUntil")) or 0)
    if slot~=5 then state="not equipped"
    elseif locked then state="combat input locked"
    elseif overheated==true then state="overheated"
    elseif activeVacuum==false then state="inactive"
    elseif activeVacuum==true and heat then
        state="active"
        if not vacuumLastHeat or not vacuumProgressAt or math.abs(heat-vacuumLastHeat)>=0.002 then
            vacuumLastHeat=heat; vacuumProgressAt=now
        elseif now-vacuumProgressAt>=4 then state="suspected frozen heat" end
    end
    if state~="active" and state~="suspected frozen heat" then vacuumLastHeat=nil; vacuumProgressAt=nil end
    if #trace.vacuumSamples<400 then
        trace.vacuumSamples[#trace.vacuumSamples+1]={at=os.clock()-started,state=state,heat=heat,
            active=activeVacuum,overheated=overheated,slot=slot,bossHealth=boss and boss:GetAttribute("BossHealth"),
            vacuumState=player:GetAttribute("VacuumState")}
    end
    if state~=vacuumState then
        vacuumState=state
        pcall(function() vacuumLabel:SetDesc(state..(heat and string.format(" | heat %.0f%%",heat*100) or "")) end)
        log("Vacuum monitor: "..state,{kind="vacuum_state",state=state,heat=heat})
    end
end

        tab:Button({Title="Export Boss Diagnostics",Callback=function()
            saveTrace(true)
            if type(setclipboard)=="function" then pcall(setclipboard,Http:JSONEncode(trace)) end
        end})
        if feedback and feedback:IsA("RemoteEvent") then
            listeners[#listeners+1]=feedback.OnClientEvent:Connect(function(kind,userId,amount,position,tool,grade)
                if not alive then return end
                if kind=="Hit" and userId==player.UserId then
                    trace.confirmedHits+=1
                    trace.reportedDamage+=tonumber(amount) or 0
                    log("Server hit: "..tostring(tool).." "..tostring(amount),
                        {kind="hit",tool=tool,amount=amount,grade=grade})
                elseif kind=="GrabPrompts" and type(userId)=="table" and type(userId.prompts)=="table" then
                    grabSession={id=userId.id,prompts=userId.prompts,good=tonumber(userId.good) or 0.3,
                        needed=tonumber(userId.needed) or 3,sent={},successes=0}
                    log("Grab prompts received",{kind="grab_prompts",id=grabSession.id})
                elseif kind=="AttackFX" and type(amount)=="table" and grabSession and amount.id==grabSession.id then
                    if userId=="GrabProgress" and amount.userId==player.UserId then
                        grabSession.successes=tonumber(amount.successes) or grabSession.successes
                        log("Server grab progress",{kind="grab_progress",grade=amount.grade,successes=grabSession.successes})
                    elseif userId=="Cancel" or ((userId=="GrabRelease" or userId=="GrabHurl") and amount.userId==player.UserId) then
                        grabSession=nil
                    end
                end
            end)
        end
        local bossConfig={}
        if bossFolder then
            local cfg=bossFolder:FindFirstChild("Config")
            if cfg then
                local ok,result=pcall(require,cfg)
                if ok and type(result)=="table" then bossConfig=result end
            end
        end
        bossTnt=createBossHeadTnt({
            Player=player,World=WS,BossConfig=bossConfig,
            Enabled=function()
                return alive and not hubUnloaded and sharedFarmState.AutoBossFight
                    and sharedFarmState.AutoUseTNT and not combatLocked()
            end,
            Boss=function() return WS:FindFirstChild("HayGolem_Rig") end,
            Remote=function()
                local folder=RS:FindFirstChild("NeedleHaystack")
                local remote=folder and folder:FindFirstChild("TntAction")
                return remote and remote:IsA("RemoteEvent") and remote or nil
            end,
            Config=function() return sharedGameConfig end,
            LightCooldown=function() return sharedFarmState.TntLightCooldown end,
            ThrowDelay=function() return sharedFarmState.TntThrowDelay end,
            Status=function(message) pcall(function() tntLabel:SetDesc(message) end) end,
            Record=function(kind,details) details.kind=kind;log(kind,details) end,
        })

        local oldCleanup=_G.__BEYY_HUB_CLEANUP
        local function stop()
            if not alive then return end
            alive=false
            if bossTnt then bossTnt.Stop() end
            grabSession=nil
            trace.duration=os.clock()-started
            saveTrace()
            stopBossFinish()
            bossCombatActive=function() return false end
            pcall(function() RunService:UnbindFromRenderStep(renderName) end)
            for _,connection in ipairs(listeners) do
                pcall(function() connection:Disconnect() end)
            end
            table.clear(listeners)
        end
        _G.__BEYY_HUB_CLEANUP=function()
            stop()
            if oldCleanup then pcall(oldCleanup) end
        end
        listeners[#listeners+1]=LocalPlayer.OnTeleport:Connect(stop)
        task.spawn(function()
            local ok,err=xpcall(function()
                while alive and not hubUnloaded do
                    task.wait(0.05)
                    aimAllowed=false
                    refreshRoundMonitors()
                    bossTnt.Tick()
                    tickGrab()
                    if bossCombatActive() then sampleVacuum() end
                    if os.clock()>=nextRoundSave then nextRoundSave=os.clock()+5;saveTrace() end
                    if not sharedFarmState.AutoBossFight then
                        aimTarget=nil
                        report("Auto Boss Fight is OFF")
                        continue
                    end
                    local boss,state=bossState()
                    if not boss or not bossCombatActive() then
                        aimTarget=nil
                        report("Waiting for active boss"..(state and (" ("..state..")") or ""))
                        continue
                    end
                    if combatLocked() then
                        aimTarget=nil
                        report("Boss combat input temporarily locked")
                        continue
                    end
                    local head=LocalPlayer.Character
                        and LocalPlayer.Character:FindFirstChild("Head")
                    if not head then
                        aimTarget=nil
                        report("Waiting for character head")
                        continue
                    end
                    local weakName=boss:GetAttribute("BossWeakPoint")
                    local now=Workspace:GetServerTimeNow()
                    local untilAt=tonumber(boss:GetAttribute("BossWeakPointEndsAt"))
                    local dizzy=boss:GetAttribute("BossWeakPointDizzy")==true
                    local exposed=type(weakName)=="string" and weakName~=""
                        and (not untilAt or now<untilAt or dizzy)
                    if not exposed and not sharedFarmState.AutoBossBodyHits then
                        aimTarget=nil
                        report("Waiting for next critical point")
                        continue
                    end
                    local targetName=exposed and weakName or "Chest"
                    local bone=findBone(boss,targetName)
                    if not bone and not exposed then
                        targetName="Pelvis"
                        bone=findBone(boss,targetName)
                    end
                    if not bone then
                        aimTarget=nil
                        report("Waiting for boss bone: "..tostring(targetName))
                        continue
                    end
                    local target=bone.TransformedWorldCFrame.Position
                    aimTarget=target
                    aimAllowed=true
                    if now<nextSend then continue end
                    local vector=target-head.Position
                    if vector.Magnitude<0.05 then continue end
                    local folder=ReplicatedStorage:FindFirstChild("NeedleHaystack")
                    local remote=folder and folder:FindFirstChild("PitchforkDig")
                    if not remote or not remote:IsA("RemoteEvent") then
                        report("Waiting for PitchforkDig remote")
                        continue
                    end
                    local cfg=bossFolder and bossFolder:FindFirstChild("Config")
                    local minReach=13
                    local cooldown=0.85
                    if cfg and cfg:IsA("ModuleScript") then
                        local success,values=pcall(require,cfg)
                        if success and type(values)=="table" then
                            minReach=tonumber(values.PitchforkRange) or 13
                            cooldown=tonumber(values.PitchforkCooldown) or 0.85
                        end
                    end
                    local range=math.clamp(
                        tonumber(LocalPlayer:GetAttribute("PitchforkReach")) or minReach,
                        minReach,24)
                    if vector.Magnitude>range then
                        if os.clock()-rangeNotice>1 then
                            rangeNotice=os.clock()
                            report(string.format("Move closer to %s (%.1f/%.1f studs)",
                                targetName,vector.Magnitude,range),true)
                        end
                        continue
                    end
                    local success,sendErr=pcall(function()
                        remote:FireServer("Boss",head.Position,vector.Unit)
                    end)
                    nextSend=now+math.max(0.1,
                        tonumber(LocalPlayer:GetAttribute("PitchforkCooldown")) or cooldown)
                    if success then
                        sent+=1
                        report((exposed and "Targeting CRITICAL: " or "Body hit: ")..
                            targetName,true)
                    else
                        report("Pitchfork request failed: "..tostring(sendErr),true)
                    end
                end
            end,function(e) return tostring(e) end)
            if not ok then
                warn("[Beyy Boss] Boss worker error: "..tostring(err))
            end
            stop()
        end)
    end
    installChapter3BossCombat()

    do
        local overview = overviewTab
local function cutsceneResultsVisible()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ending = pg and pg:FindFirstChild("NeedleEndingUI")
    return ending and ending:IsA("ScreenGui") and ending.Enabled == true
end
local function shouldYieldCutsceneBypass()
    return hubUnloaded or not hubWindow.Closed or needleBusy or sharedFarmPuzzleBusy() or cutsceneResultsVisible()
end
local function setCutsceneBypassActive(_) end
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
                warn("[BeyyHub] " .. BEYY_CHAPTER .. " default config unavailable: " .. tostring(cfg.Path))
                return
            end
            local ok, decoded = pcall(function() return httpService:JSONDecode(raw) end)
            if not ok or type(decoded) ~= "table" then
                warn("[BeyyHub] " .. BEYY_CHAPTER .. " default config is unreadable")
                return
            end
            local loadedOK, loaded, err = pcall(function() return cfg:Load() end)
            if not loadedOK or loaded == false or loaded == nil then
                warn("[BeyyHub] " .. BEYY_CHAPTER .. " default config load failed: " .. tostring(err or loaded))
                return
            end
            print("[BeyyHub] " .. BEYY_CHAPTER .. " latest default config loaded synchronously")
        end)
    else
        ConfigTab:Paragraph({ Title = "Configs unavailable", Desc = "Saving configs requires filesystem support in your environment." })
    end
    end

    task.defer(function()
        if not hubUnloaded then hideNonFarmMenu() end
    end)
    print("[BeyyHub] v103.00 " .. BEYY_CHAPTER .. " module loaded (RightControl to open)")
    print(("[BeyyHub Startup] %s controls and features registered after %.2fs in module"):format(
        BEYY_CHAPTER, os.clock() - __BEYY_BOOT_T0))
end

