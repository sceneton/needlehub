-- Standalone, one-shot teleport queue cleanup.
-- Run before teleporting. Clears ALL queued payloads, including other scripts.
-- Running scripts can queue new payloads after this finishes.
local function clearQueuedTeleports(options)
    local result={Cleared=false,Verified=false,Errors={}}
    local function count()
        if type(options.GetQueue)~="function" then return nil end
        local ok,value=pcall(options.GetQueue)
        if ok and type(value)=="table" then return #value end
        return nil
    end
    result.Before=count()
    local seen={}
    for _,candidate in ipairs(options.Candidates) do
        local fn=candidate.Function
        if type(fn)=="function" and not seen[fn] then
            seen[fn]=true
            local ok,reply=pcall(fn)
            if ok and reply~=false then
                result.API=candidate.Name
                result.After=count()
                result.Cleared=result.After==nil or result.After==0
                result.Verified=result.After==0
                return result
            end
            table.insert(result.Errors,{API=candidate.Name,Error=ok and "API returned false" or tostring(reply)})
        end
    end
    result.Reason=next(seen) and "Every available queue-clear API failed" or "This executor has no supported queue-clear API"
    return result
end

local candidates={}
local getter
local function add(name,fn)
    if type(fn)=="function" then table.insert(candidates,{Name=name,Function=fn}) end
end
-- Direct names cover executors whose built-ins are inherited globals.
add("clearqueueonteleport",clearqueueonteleport)
add("clearteleportqueue",clearteleportqueue)
add("clear_teleport_queue",clear_teleport_queue)
if type(getteleportqueue)=="function" then getter=getteleportqueue end
local environments={_G}
if type(getgenv)=="function" then
    local ok,env=pcall(getgenv)
    if ok and type(env)=="table" and env~=_G then table.insert(environments,env) end
end
local function collect(env,label)
    for _,name in ipairs({"clearqueueonteleport","clearteleportqueue","clear_teleport_queue"}) do
        add(label.."."..name,env[name])
    end
    if not getter and type(env.getteleportqueue)=="function" then getter=env.getteleportqueue end
    if type(env.syn)=="table" then add(label..".syn.clear_teleport_queue",env.syn.clear_teleport_queue) end
end
for i,env in ipairs(environments) do collect(env,i==1 and "_G" or "getgenv()") end
if type(syn)=="table" then add("syn.clear_teleport_queue",syn.clear_teleport_queue) end

local result=clearQueuedTeleports({Candidates=candidates,GetQueue=getter})
if result.Cleared then
    print("[Teleport Cleanup] Queue-clear API succeeded: "..result.API)
    if result.Verified then
        print("[Teleport Cleanup] Verified queued scripts remaining: 0")
    else
        print("[Teleport Cleanup] Executor does not expose a readable queue count; empty state could not be independently verified.")
    end
    print("[Teleport Cleanup] Running scripts are still active and may queue new payloads.")
elseif result.API then
    warn("[Teleport Cleanup] Clear API returned, but "..tostring(result.After).." queued scripts are still reported.")
else
    warn("[Teleport Cleanup] "..result.Reason..". Nothing was confirmed cleared.")
    for _,failure in ipairs(result.Errors) do warn("[Teleport Cleanup] "..failure.API..": "..failure.Error) end
end
return result
