-- beyy v103.00 | Lobby module | PlaceId 77108422251420
local __BEYY_MODULE = "Lobby"
local __BEYY_SCRIPT_VERSION = "103.00"
local __BEYY_BOOT_T0 = os.clock()
if game.PlaceId ~= 77108422251420 then
    warn("[BeyyHub] Refusing to load Lobby module in another place")
    return
end

-- Capture weekly players and the current clan's member wins once per lobby execution.
do
    task.spawn(function()
        -- Collector v6: saves weekly players and your clan's member wins once per execution.
        -- Saves locally and uses the existing optional cloud upload configuration.
        if game.PlaceId ~= 77108422251420 then return end
        local H = game:GetService("HttpService")
        local player = game:GetService("Players").LocalPlayer
        assert(player and type(writefile) == "function", "Requires a player client with writefile")
        local env = type(getgenv) == "function" and getgenv() or _G
        local previousCollector=env.NeedleWeeklyCollector
        if type(previousCollector)=="table"and type(previousCollector.Stop)=="function"then pcall(previousCollector.Stop)end
        local run = {}
        env.NeedleWeeklyCollector = run
        local firstCapture = {startedAt = os.clock(), ready = false}
        env.NeedleWeeklyFirstCapture = firstCapture
        local function text(parent, name)
            local obj = parent:FindFirstChild(name, true)
            return obj and obj:IsA("TextLabel") and obj.Text or nil
        end
        local function save(name, data)
            local ok, err = pcall(function() writefile(name, H:JSONEncode(data)) end)
            if not ok then warn("[Needle tracker v6] Save failed: " .. tostring(err)) end
            return ok
        end
        local function uploadSavedCapture()
            if type(readfile) ~= "function" then return end
            local requestFn = (type(syn) == "table" and syn.request) or http_request or request
            if type(requestFn) ~= "function" then return end
            local configOk, config = pcall(function()
                return H:JSONDecode(readfile("needle-cloud-config.json"))
            end)
            if not configOk or type(config) ~= "table" or type(config.url) ~= "string"
                or type(config.key) ~= "string" then return end
            if not config.url:match("^https://") then return end
            local captureOk, body = pcall(readfile, "needle-weekly-live.json")
            if not captureOk or type(body) ~= "string" then return end
            local ok, response = pcall(requestFn, {
                Url = config.url:gsub("/$", "") .. "/upload",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json", Authorization = "Bearer " .. config.key },
                Body = body,
            })
            local status = ok and type(response) == "table" and (response.StatusCode or response.Status)
            if status == 202 then
                print("[Needle tracker v6] Capture sent to online bot.")
            else
                warn("[Needle tracker v6] Online upload failed; local capture retained for the next lobby visit.")
            end
        end

        -- Retry the previous saved capture before this execution makes a new one.
        task.spawn(uploadSavedCapture)
        local surfaceRoot,surfaces=nil,{}
        local surfaceConnections={}
        local function clearSurfaceIndex()
            for _,c in ipairs(surfaceConnections)do c:Disconnect()end
            table.clear(surfaceConnections);table.clear(surfaces);surfaceRoot=nil
        end
        local function surfaceIndex(gui)
            if gui~=surfaceRoot then
                clearSurfaceIndex();surfaceRoot=gui
                local function add(obj)if obj:IsA("SurfaceGui")then surfaces[obj]=true end end
                surfaceConnections[1]=gui.DescendantAdded:Connect(add)
                surfaceConnections[2]=gui.DescendantRemoving:Connect(function(obj)surfaces[obj]=nil end)
                for _,obj in ipairs(gui:GetDescendants())do add(obj)end
            end
            return surfaces
        end
        local diagnosticSignature,lastDiagnosticAt,pendingDiagnostic=nil,-math.huge,nil
        local function flushDiagnostic(force)
            local pending=pendingDiagnostic
            if not pending then return end
            local parts={pending.reason,tostring(#pending.rawRows)}
            for _,row in ipairs(pending.rawRows)do
                parts[#parts+1]=table.concat({row.frame or"",row.rankText or"",row.usernameText or"",row.winsText or""},"|")
            end
            local signature=table.concat(parts,";")
            if signature==diagnosticSignature or(not force and os.clock()-lastDiagnosticAt<10)then return end
            if save("needle-weekly-diagnostics.json",pending)then
                diagnosticSignature=signature;lastDiagnosticAt=os.clock()
            end
        end
        local function winsGui()
            local boards = workspace:FindFirstChild("Leaderboards")
            local board = boards and boards:FindFirstChild("TotalWinsLeaderboard")
            local display = board and board:FindFirstChild("DisplayPart")
            local gui
            for obj in pairs(surfaceIndex(player:WaitForChild("PlayerGui"))) do
                if display and obj:IsA("SurfaceGui") and obj.Adornee == display then
                    assert(not gui, "Multiple wins displays; waiting")
                    gui = obj
                end
            end
            assert(gui and gui.Enabled, "Wins display is not loaded/enabled")
            return gui, boards
        end
        local function ensureWeekly()
            for _ = 1, 4 do
                assert(env.NeedleWeeklyCollector == run, "Collector replaced")
                local gui = winsGui()
                local period = text(gui, "PeriodLabel")
                if period and period:upper():match("^%s*WEEKLY%s*$") then return end
                local frame = gui:FindFirstChild("PeriodFrame")
                local button = frame and frame:FindFirstChild("RightArrow")
                assert(button and button:IsA("GuiButton"), "Waiting for wins period selector")
                assert(type(firesignal) == "function", "Select WEEKLY manually; firesignal unavailable")
                -- This is the actual period button's event, observed in the lobby UI.
                firesignal(button.Activated)
                task.wait(1)
                local changed = text(gui, "PeriodLabel")
                if changed and changed:upper():match("^%s*WEEKLY%s*$") then
                    -- Let the game replace cached ALL TIME rows before the stable-read check.
                    task.wait(5)
                    return
                end
            end
            error("Could not select WEEKLY; waiting")
        end
        local function read()
            local gui, boards = winsGui()
            local period = text(gui, "PeriodLabel")
            assert(period and period:upper():match("^%s*WEEKLY%s*$"), "Select WEEKLY on the wins board")
            local scroll = gui:FindFirstChild("ScrollingFrame")
            local list = scroll and scroll:FindFirstChild("Players")
            assert(list, "Wins rows are not loaded")
            local rawRows = {}
            for _, row in ipairs(list:GetChildren()) do
                if row.Name:match("^Row%d+$") and row:IsA("GuiObject") and row.Visible then
                    local rankText = text(row, "Place") or ""
                    local usernameText = text(row, "PName") or ""
                    local winsText = text(row, "ValLabel") or ""
                    local image = row:FindFirstChild("Image")
                    table.insert(rawRows, {
                        frame = row.Name, path = row:GetFullName(), layoutOrder = row.LayoutOrder,
                        rankText = rankText, usernameText = usernameText, winsText = winsText,
                        avatar = image and image:IsA("ImageLabel") and image.Image or "",
                    })
                end
            end
            local rows, users, duplicates = {}, {}, 0
            local function fail(reason)
                pendingDiagnostic={
                    collectorVersion=6,observedAt=os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    period=period,reason=reason,rawRows=rawRows,
                }
                flushDiagnostic(false)
                error(reason .. "; diagnostics queued in needle-weekly-diagnostics.json",0)
            end
            for _, raw in ipairs(rawRows) do
                local rank = tonumber(raw.rankText:match("^%s*#(%d+)%s*$"))
                local username = raw.usernameText:match("^%s*@([%w_]+)%s*$")
                local numeric = raw.winsText:gsub("%s", "")
                local wins = numeric:match("^[%d,]+$") and tonumber((numeric:gsub(",", "")))
                if not rank or not username or not wins then fail("Incomplete row: " .. raw.frame) end
                local userKey = username:lower()
                local oldUser = users[userKey]
                if oldUser then
                    if oldUser.rank == rank and oldUser.wins == wins then
                        duplicates = duplicates + 1
                    else
                        fail("Conflicting duplicate: " .. raw.frame .. " " .. raw.rankText
                            .. " " .. raw.usernameText .. " wins=" .. raw.winsText)
                    end
                else
                    local row = {rank = rank, username = username, wins = wins}
                    users[userKey] = row
                    table.insert(rows, row)
                end
            end
            table.sort(rows, function(a,b)
                if a.rank ~= b.rank then return a.rank < b.rank end
                return a.username:lower() < b.username:lower()
            end)
            if #rows == 0 then fail("No loaded rankings") end
            local expectedRank, previousWins = 0, nil
            for i, row in ipairs(rows) do
                if i > 1 and rows[i-1].wins < row.wins then fail("Wins are not sorted") end
                if previousWins == nil or row.wins ~= previousWins then
                    expectedRank = expectedRank + 1
                end
                if row.rank ~= expectedRank then fail("Rank does not match tied wins at " .. row.username) end
                previousWins = row.wins
            end
            local timerRoot = boards and boards:FindFirstChild("WeeklyTimer")
            return {version = 1, collectorVersion = 6, status = "ok", period = "WEEKLY",
                captureId = H:GenerateGUID(false), collectionMode = "once-per-execution",
                placeId = game.PlaceId, observedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"), rows = rows,
                identicalDuplicatesSkipped = duplicates,
                resetCountdown = timerRoot and text(timerRoot, "Timer") or "unknown"}
        end
        local clanContext
        local function requestClanMembers()
            if clanContext then return end
            local pg = player:FindFirstChild("PlayerGui")
            local gui = pg and pg:FindFirstChild("ClanUI")
            local main = gui and gui:FindFirstChild("Main")
            local root = main and main:FindFirstChild("Root")
            local panel = root and root:FindFirstChild("Panel")
            local pages = panel and panel:FindFirstChild("Pages")
            local tabs = root and root:FindFirstChild("Tabs")
            local clan = tabs and tabs:FindFirstChild("Clan")
            if not (pages and clan and clan:IsA("GuiButton")) then return end
            local previous
            for _, page in ipairs(pages:GetChildren()) do
                if page:IsA("GuiObject") and page.Visible then
                    local tabName = (page.Name == "InClan" or page.Name == "NoClan") and "Clan" or page.Name
                    if tabs:FindFirstChild(tabName) then previous = tabName; break end
                end
            end
            clanContext = {root = root, pages = pages, tabs = tabs, previous = previous}
            -- Only the existing Clan tab is activated. Never touch Join, Kick, Admin, or settings.
            if type(firesignal) == "function" then firesignal(clan.Activated) end
        end
        local function restoreClanTab()
            if not clanContext or not clanContext.previous or clanContext.previous == "Clan" then return end
            local current = clanContext.pages:FindFirstChild("InClan")
            local noClan = clanContext.pages:FindFirstChild("NoClan")
            local previous = clanContext.tabs:FindFirstChild(clanContext.previous)
            if previous and type(firesignal) == "function" and ((current and current.Visible) or (noClan and noClan.Visible)) then
                pcall(firesignal, previous.Activated)
            end
        end
        local function readClanMembers()
            requestClanMembers()
            assert(clanContext, "Clan member UI is not loaded")
            local page = clanContext.pages:FindFirstChild("InClan")
            local noClan = clanContext.pages:FindFirstChild("NoClan")
            if noClan and noClan.Visible and not (page and page.Visible) then
                return {status = "not_in_clan", scope = "CLAN_MEMBERS", rows = {}, observedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")}
            end
            assert(page and page.Visible, "Clan member page is not ready")
            local info = page:FindFirstChild("Info")
            local clanName = info and text(info, "ClanName")
            local members = page:FindFirstChild("Members")
            local list = members and members:FindFirstChild("List")
            local expected = tonumber((members and text(members, "Title") or ""):match("MEMBERS%s*%((%d+)"))
            assert(list and clanName and clanName ~= "" and expected and expected > 0, "Clan members are still loading")
            local rows, identities = {}, {}
            for _, row in ipairs(list:GetChildren()) do
                if row:IsA("GuiObject") and row.Name ~= "Template" and row.Visible then
                    local name = text(row, "PlayerName")
                    local raw = (text(row, "Wins") or ""):gsub("%s", "")
                    local wins = raw:match("^[%d,]+$") and tonumber((raw:gsub(",", "")))
                    local avatar = row:FindFirstChild("Avatar", true)
                    local userId = avatar and avatar:IsA("ImageLabel") and avatar.Image:match("[?&]id=(%d+)")
                    assert(name and name ~= "" and wins and userId, "A clan member row is incomplete")
                    assert(not identities[userId], "Duplicate clan member identity")
                    identities[userId] = true
                    table.insert(rows, {userId = userId, displayName = name, role = text(row, "Role") or "MEMBER", wins = wins})
                end
            end
            assert(#rows == expected, "Clan member list is incomplete")
            table.sort(rows, function(a,b)
                if a.wins ~= b.wins then return a.wins > b.wins end
                return a.userId < b.userId
            end)
            return {status = "ok", scope = "CLAN_MEMBERS", period = "UNSPECIFIED", clanName = clanName,
                observedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"), rows = rows}
        end
        local function captureClanMembers()
            local deadline = os.clock() + 8
            local lastError = "Clan members not ready"
            while env.NeedleWeeklyCollector == run and os.clock() < deadline do
                local ok, value = pcall(function()
                    local first = readClanMembers()
                    task.wait(1.5)
                    local second = readClanMembers()
                    assert(first.status == second.status and first.clanName == second.clanName and #first.rows == #second.rows,
                        "Clan member list is changing")
                    for i, a in ipairs(first.rows) do
                        local b = second.rows[i]
                        assert(a.userId == b.userId and a.wins == b.wins and a.displayName == b.displayName and a.role == b.role,
                            "Clan member list is changing")
                    end
                    return second
                end)
                if ok then return value end
                lastError = tostring(value)
                task.wait(0.5)
            end
            warn("[Needle tracker v6] Clan members unavailable: " .. lastError)
            return {status = "unavailable", scope = "CLAN_MEMBERS", rows = {}}
        end
        local teleportConnection
        run.Stop=function()
            clearSurfaceIndex()
            if teleportConnection then teleportConnection:Disconnect();teleportConnection=nil end
            if env.NeedleWeeklyCollector==run then env.NeedleWeeklyCollector=nil end
        end
        teleportConnection=player.OnTeleport:Connect(function(state)
            if state==Enum.TeleportState.Started then
                run.Stop();if teleportConnection then teleportConnection:Disconnect();teleportConnection=nil end
            end
        end)
        print("[Needle tracker v6] Waiting for one weekly-player and clan-member capture.")
        task.spawn(function()
            local deadline = os.clock() + 60
            local failures,lastWarning,lastWarningAt=0,nil,-math.huge
            while env.NeedleWeeklyCollector == run and os.clock() < deadline do
                local ok, snapshot = pcall(function()
                    requestClanMembers()
                    ensureWeekly()
                    local first = read()
                    task.wait(3)
                    local second = read()
                    assert(#first.rows == #second.rows, "Rows are changing; waiting")
                    for i, a in ipairs(first.rows) do
                        local b = second.rows[i]
                        assert(a.rank == b.rank and a.username:lower() == b.username:lower()
                            and a.wins == b.wins, "Rows are changing; waiting")
                    end
                    second.clans = captureClanMembers()
                    return second
                end)
                if env.NeedleWeeklyCollector ~= run then break end
                if ok and save("needle-weekly-live.json", snapshot) then
                    task.spawn(uploadSavedCapture)
                    firstCapture.ready = true
                    restoreClanTab()
                    clearSurfaceIndex()
                    if teleportConnection then teleportConnection:Disconnect();teleportConnection=nil end
                    print("[Needle tracker v6] Saved " .. #snapshot.rows .. " weekly players and "
                        .. #(snapshot.clans.rows or {}) .. " clan members once; capture=" .. snapshot.captureId .. ". Collector stopped.")
                    return
                end
                if not ok and(lastWarning~=tostring(snapshot)or os.clock()-lastWarningAt>=10)then
                    lastWarning=tostring(snapshot);lastWarningAt=os.clock()
                    warn("[Needle tracker v6] Waiting: "..lastWarning)
                end
                -- Retry initialization or an incomplete board only until the first successful save.
                -- Never overwrite the last good input with a transient waiting/error packet.
                failures+=1
                task.wait(math.min(math.min(8,2^math.min(failures,3)),math.max(0,deadline-os.clock())))
            end
            flushDiagnostic(true)
            clearSurfaceIndex()
            if teleportConnection then teleportConnection:Disconnect();teleportConnection=nil end
            if env.NeedleWeeklyCollector == run then
                restoreClanTab()
                warn("[Needle tracker v6] No stable capture within 60 seconds; rerun in the lobby.")
            end
        end)
    end)
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
    local lobbyToolsTab = hubWindow:Tab({ Title = "Lobby Tools", Icon = "zap" })
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
    local function saveSharedFarmSettings()
        pcall(function() safeWrite(sharedFarmPath, httpService:JSONEncode(sharedFarmState)) end)
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
            or (BEYY_CHAPTER=="Chapter2" and sharedFarmPuzzleBusy())
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
        while not hubUnloaded do
            task.wait(math.max(0.2,tonumber(sharedFarmState.ToolInterval) or 0.5))
            if needleFolder and not farmBlocked() and not needlePriority() then
                if sharedFarmState.AutoUsePitchfork and LocalPlayer:GetAttribute("PitchforkOwned")==true then
                    local _,id=closestInFolder("HaystackClient","HayId",30)
                    if id then sendFarmRemote("PitchforkDig",id) end
                end
                if sharedFarmState.AutoDeployDrone and LocalPlayer:GetAttribute("DroneOwned")==true
                    and LocalPlayer:GetAttribute("DroneDeployed")~=true then
                    sendFarmRemote("DeployDrone")
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
                if needleFolder and not farmBlocked() and not needlePriority() then
                    local cooldown=tonumber(LocalPlayer:GetAttribute("TntCooldown")) or 20
                    nextTntLightAt=os.clock()+math.max(0.5,cooldown,tonumber(sharedFarmState.TntLightCooldown) or 0)
                    if sendFarmRemote("TntAction","light") then
                        task.wait(math.max(0,tonumber(sharedFarmState.TntThrowDelay) or 0.4))
                        if not hubUnloaded and sharedFarmState.AutoUseTNT and not farmBlocked() and not needlePriority() then
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
            local active=needleFolder and BEYY_CHAPTER~="Lobby" and sharedFarmState.AutoUseVacuum
                and not farmBlocked() and not needlePriority() and hubWindow.Closed==true
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
                        if not farmBlocked() and hubWindow.Closed and not needlePriority() then
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
    local function tryTrack(name)
        if not sharedGameConfig then return end
        local track=sharedGameConfig.UPGRADE_TRACKS and sharedGameConfig.UPGRADE_TRACKS[name]
        if not track then return end
        local level=tonumber(LocalPlayer:GetAttribute("HayUpgrade"..name)) or 1
        if level>=#track.Levels then return end
        local nextLevel=track.Levels[level+1]
        if nextLevel and cash()>=(nextLevel.Cost or 0) then
            sendFarmRemote("BuyUpgrade",name)
        end
    end
    local function tryPermanent(name)
        if not sharedUpgradeConfig then return end
        local ok,upgrade=pcall(function() return sharedUpgradeConfig.getUpgrade(name) end)
        if not ok or not upgrade then return end
        local level=tonumber(LocalPlayer:GetAttribute("Upgrade"..name)) or 0
        local levelOK,maxLevel=pcall(function() return sharedUpgradeConfig:getMaxLevel(upgrade) end)
        if not levelOK or level>=maxLevel then return end
        local priceOK,price=pcall(function() return sharedUpgradeConfig:getPrice(upgrade,level) end)
        if priceOK and price and (tonumber(LocalPlayer:GetAttribute("Gems")) or 0)>=price then
            sendFarmRemote("BuyUpgrade",name)
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
    task.spawn(function()
        local tracks={
            UpgCapacity="Capacity",UpgHandSpeed="Speed",UpgHandGrab="Grab",UpgHandHold="HandHold",
            UpgTntLuck="TntLuck",UpgTntCooldown="TntCooldown",UpgTntPower="TntPower",
            UpgPitchCooldown="PitchforkCooldown",UpgPitchHold="PitchforkHold",UpgPitchSweep="Pitchfork",
            UpgDroneSpeed="DroneSpeed",UpgDroneGrab="DroneGrab",UpgDroneCapacity="DroneCapacity",
            UpgVacPower="VacuumPower",UpgVacCooling="VacuumCooling",UpgVacRuntime="VacuumRuntime",
        }
        while not hubUnloaded do
            task.wait(0.05)
            if needleFolder and BEYY_CHAPTER~="Lobby" then
                for key,name in pairs(tracks) do
                    if sharedFarmState[key] then tryTrack(name) end
                end
            end
        end
    end)



        local sharedPath = CACHE_FOLDER .. "/autofarmwins_shared.txt"
        local afkPreferencePath = CACHE_FOLDER .. "/autofarmwins_preference_v2.txt"
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
            local value = (decoded.__elements or decoded).AutoFarmWins
            if type(value) == "table" then value = value.value end
            if type(value) == "boolean" then return value end
            return nil
        end

        local function saveAutoFarmPreference(value)
            if type(value) ~= "boolean" then return end
            local player = game:GetService("Players").LocalPlayer
            if player then player:SetAttribute("BeyyHub_AutoFarmWins_Live_v103", value) end
            writeTeleportAFK(value)
            local a = safeWrite(afkPreferencePath, tostring(value))
            local b = safeWrite(sharedPath, tostring(value))
            if not (a or b) then warn("[BeyyHub] Could not persist shared Auto Farm Wins preference") end
        end

        local function readAutoFarmPreference()
            local player = game:GetService("Players").LocalPlayer
            local live = player and player:GetAttribute("BeyyHub_AutoFarmWins_Live_v103")
            if type(live) == "boolean" then return live end
            local teleported = readTeleportAFK()
            if teleported ~= nil then return teleported end
            local fromConfig = configAutoFarmValue(__beyyActiveConfigName())
            if fromConfig ~= nil then return fromConfig end
            local persisted = safeRead(afkPreferencePath)
            if persisted == "true" then return true end
            if persisted == "false" then return false end
            local legacy = safeRead(sharedPath)
            if legacy == "true" then return true end
            if legacy == "false" then return false end
            return false
        end
        local HAY_PREFERENCE_PATH = CACHE_FOLDER .. "/autofarmhay_preference.txt"
        local HAY_TELEPORT_KEY = "BeyyHub_AutoFarmHay_v1"
        local function readAutoHayPreference()
            local ok,value=pcall(function() return TeleportService:GetTeleportSetting(HAY_TELEPORT_KEY) end)
            if ok and type(value)=="boolean" then return value end
            return safeRead(HAY_PREFERENCE_PATH)=="true"
        end
        local function saveAutoHayPreference(value)
            if type(value)~="boolean" then return end
            pcall(function() TeleportService:SetTeleportSetting(HAY_TELEPORT_KEY,value) end)
            safeWrite(HAY_PREFERENCE_PATH,tostring(value))
        end
        local startupHayPreference=readAutoHayPreference()
        local startupAFKPreference = readAutoFarmPreference()
        if startupHayPreference then startupAFKPreference=false end
        local lobbyState = { AutoFarmWins = startupAFKPreference, AutoFarmHay=startupHayPreference, ArcadeFarm = false,
            ClassRoller = false, ClassTarget = "The Chosen One", ClassRollInterval = 1.1 }
        local lobbyTab = overviewTab
        lobbyTab:Section({ Title = "Auto round creation" })
        lobbyTab:Paragraph({ Title = "Chapter 1 farming", Desc = "The lobby creates a Chapter 1 round if Auto Farm Wins is enabled. Farming and Inventory settings are accessible here." })
        Registry.AutoFarmWins = lobbyTab:Toggle({
            Title = "Auto Farm Wins (shared)", Value = lobbyState.AutoFarmWins,
            Desc = "Used by the lobby round creator and by Chapter 1 after teleport.",
            Callback = function(enabled)
                lobbyState.AutoFarmWins = enabled
                if enabled and lobbyState.AutoFarmHay then
                    lobbyState.AutoFarmHay=false
                    saveAutoHayPreference(false)
                    if Registry.AutoFarmHay then pcall(function() Registry.AutoFarmHay:Set(false) end) end
                end
                saveAutoFarmPreference(enabled == true)
            end,
        })
        Registry.AutoFarmHay = lobbyTab:Toggle({
            Title = "Auto Farm Hay (Impossible)", Value = lobbyState.AutoFarmHay,
            Desc = "Create Impossible rounds, clear every hay piece before needle hand-in, then Replay.",
            Callback = function(enabled)
                lobbyState.AutoFarmHay=enabled
                if enabled then
                    lobbyState.AutoFarmWins=false
                    saveAutoFarmPreference(false)
                    if Registry.AutoFarmWins then pcall(function() Registry.AutoFarmWins:Set(false) end) end
                end
                saveAutoHayPreference(enabled==true)
            end,
        })
        lobbyToolsTab:Section({ Title = "Lobby utilities" })
        Registry.ArcadeFarm = lobbyToolsTab:Toggle({ Title = "Arcade Gem Farm", Value = false,
            Callback = function(enabled) lobbyState.ArcadeFarm = enabled end })
        Registry.ClassRoller = lobbyToolsTab:Toggle({ Title = "Auto Class Roller", Value = false,
            Callback = function(enabled) lobbyState.ClassRoller = enabled end })
        Registry.ClassTarget = lobbyToolsTab:Dropdown({
            Title = "Target Class", Values = { "The Chosen One", "Ultimate Farmer", "Hoover", "Drone Specialist", "Prospector", "Beyond The Limits" },
            Value = "The Chosen One", Callback = function(value) lobbyState.ClassTarget = value end,
        })
        Registry.ClassRollInterval = lobbyToolsTab:Slider({ Title = "Class Roll Interval (s)", Step = 0.1,
            Value = { Min = 0.5, Max = 3, Default = 1.1 },
            Callback = function(value) lobbyState.ClassRollInterval = tonumber(value) or 1.1 end })

        local Unloaded = false
        local IN_GAME = false
        local function afkFarmModeActive()
            return (lobbyState.AutoFarmWins or lobbyState.AutoFarmHay) and not hubUnloaded
        end
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

do
    local autoCreating = false
    local occupiedCircles = {}
    local activeMonitor
    local stage = "idle"
    local nextAttempt = 0

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
        local container = findInTree(createUI, {"Main", "Container"})
        if not container then return false end
        local t = 0
        local walkTimeout = math.clamp((hrp.Position - target).Magnitude / math.max(hum.WalkSpeed, 1) + 3.5, 3.5, 15)
        while not container.Visible and t < walkTimeout do
            if hubUnloaded or not afkFarmModeActive() then return false end
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
            while running and not hubUnloaded do
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
        stage = "walking to party circle"
        if not walkToCircle(circle) then
            warn("[Round] Party UI did not open after walking to " .. circle.Name .. "; will retry")
            return false
        end
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local createUI = pg and pg:FindFirstChild("CreatePartyUI")
        local container = findInTree(createUI, {"Main", "Container"})
        if not container then return false end
        local stopMonitor = monitorCircle(circle)
        activeMonitor = stopMonitor
        stage = "configuring party"
        task.wait(0.2)
        local selectedDifficulty = findInTree(container, {"DifficultyChoosingFrame",
            lobbyState.AutoFarmHay and "ImpossibleMode" or "NormalMode"})
        if not selectedDifficulty and lobbyState.AutoFarmHay then
            local choices=findInTree(container,{"DifficultyChoosingFrame"})
            if choices then
                for _,option in ipairs(choices:GetDescendants()) do
                    if option:IsA("GuiButton") and
                        (option.Name:lower():find("impossible",1,true)
                        or (option:IsA("TextButton") and option.Text:lower():find("impossible",1,true))) then
                        selectedDifficulty=option
                        break
                    end
                end
            end
        end
        if lobbyState.AutoFarmHay and not selectedDifficulty then
            warn("[Beyy Hay] Impossible difficulty button missing; refusing Normal round")
            stopMonitor()
            return false
        end
        if selectedDifficulty then
            clickGuiObjectEarly(selectedDifficulty)
            task.wait(0.12)
        end
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
        stage = "creating party"
        local createBtn = container:FindFirstChild("Create")
        if createBtn then
            for _ = 1, 6 do
                if game.PlaceId ~= BEYY_PLACE_IDS.Lobby or not container.Visible then break end
                clickGuiObjectEarly(createBtn)
                local deadline = tick() + 0.9
                while tick() < deadline do
                    if game.PlaceId ~= BEYY_PLACE_IDS.Lobby or not container.Visible then break end
                    task.wait(0.05)
                end
                if game.PlaceId ~= BEYY_PLACE_IDS.Lobby or not container.Visible then
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
        if autoCreating or tick() < nextAttempt then return end
        if game.PlaceId ~= BEYY_PLACE_IDS.Lobby then return end
        autoCreating = true
        stage = "finding party circles"
        local ok, err = xpcall(function()
            local circles = getTeleportCircles()
            if #circles == 0 then
                stage = "waiting for character or party circles"
                return
            end
            for _, entry in ipairs(circles) do
                if hubUnloaded or not afkFarmModeActive()
                    or game.PlaceId ~= BEYY_PLACE_IDS.Lobby then return end
                local circle = entry.part
                if tick() >= (occupiedCircles[circle] or 0) then
                    if isCircleOccupied(circle) then
                        occupiedCircles[circle] = tick() + 15
                    else
                        if tryCreateFromCircle(circle) then return end
                        if activeMonitor then activeMonitor(); activeMonitor = nil end
                        occupiedCircles[circle] = tick() + 4
                    end
                end
            end
        end, function(message) return tostring(message) end)
        -- Always release the lock and movement worker, including after UI errors.
        if activeMonitor then pcall(activeMonitor); activeMonitor = nil end
        autoCreating = false
        nextAttempt = tick() + (ok and 1 or 5)
        if not ok then
            warn("[Round] Auto-create failed at " .. stage .. ": " .. tostring(err) .. "; retrying in 5 seconds")
        end
    end

    task.spawn(function()
        while not hubUnloaded do
            task.wait(0.5)
            if afkFarmModeActive() and game.PlaceId == BEYY_PLACE_IDS.Lobby then
                -- Give the initial weekly snapshot up to 20 seconds before leaving the lobby.
                local capture = __beyyConfigEnv.NeedleWeeklyFirstCapture
                if not capture or capture.ready or os.clock() - capture.startedAt >= 20 then
                    attemptAutoCreate()
                end
            end
        end
    end)
end

        local arcadeFolder = ReplicatedStorage:FindFirstChild("Arcade")
        local arcadeReport = arcadeFolder and arcadeFolder:FindFirstChild("ArcadeReport")
        local arcadeSession = arcadeFolder and arcadeFolder:FindFirstChild("ArcadeSession")
        local arcadeMachine = Workspace:FindFirstChild("Arcade Machine")
        local arcadePrompt = arcadeMachine and arcadeMachine:FindFirstChild("PlayPrompt", true)
        local classSystem = ReplicatedStorage:FindFirstChild("ClassSystem")
        local rollClass = classSystem and classSystem:FindFirstChild("RollClass")
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
    pcall(function() arcadeSession:FireServer("quit", 0, 0) end)
end

local function arcadeCycle()
    pcall(function() fireproximityprompt(arcadePrompt) end)
    for i = 1, KILLS_PER_CYCLE do
        pcall(function() arcadeReport:FireServer("kills", 40, 0) end)
    end
    fastLeave()
end

task.spawn(function()
    local cycles = 0
    while not hubUnloaded do
        if IN_GAME then

            if lobbyState.ArcadeFarm then
                lobbyState.ArcadeFarm = false
                warn("[Arcade] Lobby only.")
            end
            task.wait(0.1)
        elseif lobbyState.ArcadeFarm and arcadePrompt and arcadeReport then
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
            while not hubUnloaded do
                task.wait(lobbyState.ClassRollInterval)
                if lobbyState.ClassRoller and rollClass then
                    local ok, result = pcall(function() return rollClass:InvokeServer() end)
                    if ok and type(result) == "table" and result.success and result.className == lobbyState.ClassTarget then
                        print("[BeyyHub] Desired class found: " .. result.className)
                        lobbyState.ClassRoller = false
                    end
                end
            end
        end)

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
                if success then
                    safeWrite(activeConfigPath, name)
                    local savedAFK = configAutoFarmValue(name)
                    if savedAFK ~= nil and not lobbyState.AutoFarmHay then
                        lobbyState.AutoFarmWins = savedAFK
                        local toggle = Registry.AutoFarmWins
                        if toggle and type(toggle.Set) == "function" then
                            pcall(function() toggle:Set(savedAFK) end)
                        end
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
                    if type(currentAFK) ~= "boolean" then currentAFK = lobbyState.AutoFarmWins end
                    lobbyState.AutoFarmWins = currentAFK == true and not lobbyState.AutoFarmHay
                    saveAutoFarmPreference(lobbyState.AutoFarmWins)
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
            -- A shared JSON config may contain an older AFK value.
            -- Preserve the explicit manual setting through automatic config load.
            if type(startupAFKPreference) == "boolean" then
                if startupHayPreference then startupAFKPreference=false end
                local farmToggle = Registry.AutoFarmWins
                if farmToggle and farmToggle.Value ~= startupAFKPreference then
                    farmToggle:Set(startupAFKPreference)
                end
                lobbyState.AutoFarmWins = startupAFKPreference
                saveAutoFarmPreference(startupAFKPreference)
                print("[AutoFarmWins] Lobby restored latest session choice: " .. tostring(startupAFKPreference))
            end
            if startupHayPreference then
                local hayToggle=Registry.AutoFarmHay
                if hayToggle and lobbyState.AutoFarmHay~=true then
                    pcall(function() hayToggle:Set(true) end)
                end
                lobbyState.AutoFarmHay=true
                lobbyState.AutoFarmWins=false
                saveAutoFarmPreference(false)
                saveAutoHayPreference(true)
            end
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

