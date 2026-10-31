-- BeyyHub v103.00 | direct-branch loader with AFK replay recovery
-- Resolves the current revision and keeps validated AFK recovery caches.
local VERSION = "103.00"
local BASE = "https://raw.githubusercontent.com/sceneton/needlehub/main/"
local MODULES = {
    [77108422251420] = {file="lobby.lua", name="Lobby"},
    [108628039999641] = {file="chapter1.lua", name="Chapter1"},
    [83445806734780] = {file="chapter2.lua", name="Chapter2"},
    [82626725163709] = {file="chapter3.lua", name="Chapter3"},
    [102537610748607] = {file="chapter4.lua", name="Chapter4"},
}
local target = MODULES[game.PlaceId]
if not target then
    warn("[BeyyHub] Unsupported PlaceId: " .. tostring(game.PlaceId))
    return
end

local CACHE_FOLDER = "BeyyHub"
local LOADER_CACHE = CACHE_FOLDER.."/afk_replay_loader_v103.lua"
local moduleCache = (target.name=="Chapter1" or target.name=="Lobby")
    and (CACHE_FOLDER.."/afk_replay_module_v103_"..target.name..".lua") or nil
pcall(function()
    if type(makefolder)=="function" and (type(isfolder)~="function" or not isfolder(CACHE_FOLDER)) then makefolder(CACHE_FOLDER) end
end)
local function validRevision(value)
    return type(value)=="string" and #value==40 and value:match("^%x+$")~=nil
end
local selectedRevision=...
if not validRevision(selectedRevision) then
    local ok,info=pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet(
            "https://api.github.com/repos/sceneton/needlehub/commits/main?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000))))
    end)
    selectedRevision=ok and type(info)=="table" and info.sha or nil
end
local revisionPath=CACHE_FOLDER.."/afk_replay_revision_v103_sceneton.txt"
if validRevision(selectedRevision) then
    if type(writefile)=="function" then pcall(writefile,revisionPath,selectedRevision) end
elseif type(readfile)=="function" then
    local ok,value=pcall(readfile,revisionPath)
    selectedRevision=ok and validRevision(value) and value or nil
end
local DOWNLOAD_BASE=validRevision(selectedRevision)
    and ("https://raw.githubusercontent.com/sceneton/needlehub/"..selectedRevision.."/") or BASE
local begin = os.clock()
local requests, compileSeconds = 0, 0
local lastModuleFailure = nil
local function fetch(url)
    requests += 1
    return game:HttpGet(url .. "?refresh=" .. tostring(os.time()) .. "-" ..
        tostring(math.random(1,1000000000)))
end
local function validate(source)
    if type(source) ~= "string" or #source < 1500 then
        lastModuleFailure = "download returned incomplete source"
        return nil
    end
    if not source:find('local __BEYY_SCRIPT_VERSION = "' .. VERSION .. '"', 1, true)
        or not source:find('local __BEYY_MODULE = "' .. target.name .. '"', 1, true) then
        lastModuleFailure = "downloaded module failed version/chapter signature"
        return nil
    end
    if target.name=="Chapter1" and not source:find("createReplayRecovery",1,true) then
        lastModuleFailure = "Chapter1 replay recovery marker missing"
        return nil
    end
    local started = os.clock()
    local ok, fn, compileError = pcall(loadstring, source)
    compileSeconds += os.clock() - started
    if not ok or type(fn) ~= "function" then
        lastModuleFailure = "compile error: "..tostring(ok and compileError or fn)
        return nil
    end
    lastModuleFailure = nil
    return fn
end

local fn
for attempt = 1, 3 do
    local ok, source = pcall(fetch, DOWNLOAD_BASE .. target.file)
    if ok then
        fn = validate(source)
        if fn then
            if moduleCache and type(writefile)=="function" then pcall(writefile,moduleCache,source) end
            break
        end
    else
        lastModuleFailure = "download error: "..tostring(source)
    end
    if attempt < 3 then task.wait(0.25 * attempt) end
end
if not fn and moduleCache and type(readfile)=="function" then
    local ok,cached=pcall(readfile,moduleCache)
    if ok then
        fn=validate(cached)
        if fn then warn("[BeyyHub] Online AFK module unavailable; using the last validated recovery cache") end
    end
end
if not fn then
    warn("[BeyyHub] Could not download/compile " .. target.name ..
        " or validate its AFK recovery cache. Last reason: " ..
        tostring(lastModuleFailure or "unknown"))
    return
end

-- Warm the lobby backup once so a Chapter 1 watchdog can restart during an outage.
if target.name=="Chapter1" and type(writefile)=="function" then
    local path=CACHE_FOLDER.."/afk_replay_module_v103_Lobby.lua"
    local function validLobby(value)
        return type(value)=="string" and #value>=1500
            and value:find('local __BEYY_SCRIPT_VERSION = "'..VERSION..'"',1,true)
            and value:find('local __BEYY_MODULE = "Lobby"',1,true) and loadstring(value)
    end
    local cached
    if type(readfile)=="function" then local ok,value=pcall(readfile,path);if ok then cached=value end end
    if not validLobby(cached) then
        local ok,value=pcall(fetch,DOWNLOAD_BASE.."lobby.lua")
        if ok and validLobby(value) then pcall(writefile,path,value) end
    end
end

-- Keep a validated first-party router for queued reloads during a download outage.
if type(writefile)=="function" then
    local cached
    if type(readfile)=="function" then local ok,value=pcall(readfile,LOADER_CACHE);if ok then cached=value end end
    local validCache=type(cached)=="string" and cached:find("https://raw.githubusercontent.com/sceneton/needlehub/",1,true)
        and cached:find("afk_replay_loader_v103.lua",1,true)
        and cached:find('local VERSION = "'..VERSION..'"',1,true) and loadstring(cached)
    if not validCache then
        local ok,value=pcall(fetch,DOWNLOAD_BASE.."loader.lua")
        if ok and type(value)=="string" and value:find("https://raw.githubusercontent.com/sceneton/needlehub/",1,true)
            and value:find("afk_replay_loader_v103.lua",1,true)
            and value:find('local VERSION = "'..VERSION..'"',1,true) and loadstring(value) then
            pcall(writefile,LOADER_CACHE,value)
        end
    end
end

local env = _G
if type(getgenv) == "function" then
    local ok, candidate = pcall(getgenv)
    if ok and type(candidate) == "table" then env = candidate end
end
local queue = (type(queue_on_teleport) == "function" and queue_on_teleport)
    or (type(env.queue_on_teleport) == "function" and env.queue_on_teleport)
    or (type(env.queueonteleport) == "function" and env.queueonteleport)
    or (type(env.queue_on_tp) == "function" and env.queue_on_tp)
if queue and _G.__BEYY_SCENETON_NEEDLEHUB_RELOAD_JOB~=game.JobId then
    local payload = [==[
        local H=game:GetService("HttpService")
        local revision
        local resolved,info=pcall(function()
            return H:JSONDecode(game:HttpGet("https://api.github.com/repos/sceneton/needlehub/commits/main?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000))))
        end)
        if resolved and type(info)=="table" and type(info.sha)=="string" and #info.sha==40 and info.sha:match("^%x+$") then revision=info.sha end
        local url="https://raw.githubusercontent.com/sceneton/needlehub/"..(revision or "main").."/loader.lua"
        local body
        for attempt=1,3 do
            local ok,source=pcall(function()
                return game:HttpGet(url.."?refresh="..tostring(os.time()).."-"..tostring(math.random(1,1000000000)))
            end)
            if ok and type(source)=="string" and source:find("https://raw.githubusercontent.com/sceneton/needlehub/",1,true)
                and source:find('local VERSION = "103.00"',1,true)
                and source:find("afk_replay_loader_v103.lua",1,true) and loadstring(source) then body=source;break end
            if attempt<3 then task.wait(attempt*0.5) end
        end
        if not body and type(readfile)=="function" then
            local ok,cached=pcall(readfile,"BeyyHub/afk_replay_loader_v103.lua")
            if ok and type(cached)=="string" and cached:find("https://raw.githubusercontent.com/sceneton/needlehub/",1,true)
                and cached:find('local VERSION = "103.00"',1,true)
                and cached:find("afk_replay_loader_v103.lua",1,true) and loadstring(cached) then body=cached end
        end
        if not body then warn("[BeyyHub] No validated online or cached AFK router; reattach and rerun the loader");return end
        if type(writefile)=="function" then pcall(writefile,"BeyyHub/afk_replay_loader_v103.lua",body) end
        local compiled,compileError=loadstring(body)
        if not compiled then warn("[BeyyHub] Teleport loader compile error: "..tostring(compileError));return end
        local succeeded,runtimeError=pcall(compiled,revision)
        if not succeeded then warn("[BeyyHub] Teleport loader error: "..tostring(runtimeError)) end
    ]==]
    local ok, err = pcall(queue, payload)
    if ok then _G.__BEYY_SCENETON_NEEDLEHUB_RELOAD_JOB=game.JobId
    else warn("[BeyyHub] Teleport queue failed: " .. tostring(err)) end
elseif queue then
    print("[BeyyHub] Teleport reload already armed for this session")
else
    warn("[BeyyHub] queue_on_teleport unavailable; rerun after changing chapters")
end

print(string.format("[BeyyHub Fast Startup] %s source=revision-or-cache requests=%d compile=%.3fs loader=%.2fs",
    target.name, requests, compileSeconds, os.clock() - begin))
local moduleBegin = os.clock()
local ok, err = pcall(fn)
if not ok then warn("[BeyyHub] " .. target.name .. " error: " .. tostring(err)) end
print(string.format("[BeyyHub Fast Startup] %s module returned after %.2fs (module=%.2fs)",
    target.name, os.clock() - begin, os.clock() - moduleBegin))
