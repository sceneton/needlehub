-- Standalone needle pickup / hand-in latency recorder with teleport continuation.
local function createNeedleLatencyRecorder(options)
    local api={};local alive=true;local sequence=0;local ring={};local pending={};local cycles={};local cycle
    local counters={};local lastSnapshot;local cycleNumber=0
    function api.Record(kind,data)
        if not alive then return end
        local ok,clean=pcall(options.Serialize,data or{})
        if not ok then return end
        sequence+=1;counters[kind]=(counters[kind]or 0)+1
        local event={SessionId=options.SessionId,Sequence=sequence,At=options.Now(),WallTimeMs=options.WallTimeMs(),
            PlaceId=options.PlaceId,Kind=kind,Data=clean}
        ring[#ring+1]=event;if #ring>512 then table.remove(ring,1)end
        pending[#pending+1]=event
        -- Bound memory if disk writes stop working.
        if #pending>1024 then table.remove(pending,1);counters.EventsDroppedBeforeWrite=(counters.EventsDroppedBeforeWrite or 0)+1 end
    end
    local function begin(reason)
        cycleNumber+=1
        cycle={Index=cycleNumber,Reason=reason,Times={},PickupRequests=0,HandInRequests=0,MousePressAttempts=0}
        cycles[#cycles+1]=cycle;if #cycles>32 then table.remove(cycles,1)end
        return cycle
    end
    local function stamp(key)
        local current=cycle or begin("Started without observing exposure")
        current.Times[key]=current.Times[key]or options.Now()
        local times=current.Times
        if times.Exposed and times.FirstPickupRequest then current.ExposureToPickupRequestMs=(times.FirstPickupRequest-times.Exposed)*1000 end
        if times.FirstPickupRequest and times.OwnershipObserved then current.PickupRequestToOwnershipMs=(times.OwnershipObserved-times.FirstPickupRequest)*1000 end
        if times.Exposed and times.OwnershipObserved then current.ExposureToOwnershipMs=(times.OwnershipObserved-times.Exposed)*1000 end
        if times.OwnershipObserved and times.FirstHandInRequest then current.OwnershipToHandInRequestMs=(times.FirstHandInRequest-times.OwnershipObserved)*1000 end
        if times.FirstHandInRequest and times.OwnershipCleared then current.HandInRequestToOwnershipClearedMs=(times.OwnershipCleared-times.FirstHandInRequest)*1000 end
        if times.FirstHandInRequest and times.RoundCompleteObserved then current.HandInRequestToRoundCompleteMs=(times.RoundCompleteObserved-times.FirstHandInRequest)*1000 end
        return current
    end
    function api.Exposed(target)
        if not alive then return end
        begin("Needle exposure observed");cycle.Target=options.Serialize(target);stamp("Exposed")
        api.Record("NeedleExposed",{Target=target,Cycle=cycle.Index})
    end
    function api.Ownership(owned,initial)
        if not alive then return end
        if owned then
            local current=stamp("OwnershipObserved");current.OwnedAtStart=initial==true
            api.Record(initial and "OwnershipAlreadyPresentAtStart"or "OwnershipObserved",{Cycle=current.Index,Timings=current})
        else
            if cycle and cycle.Times.OwnershipObserved then stamp("OwnershipCleared")end
            api.Record("OwnershipCleared",{Timings=cycle})
        end
    end
    function api.Request(kind,data)
        if not alive then return end
        local current
        if kind=="Pickup"then current=stamp("FirstPickupRequest");current.PickupRequests+=1
        elseif kind=="HandIn"then current=stamp("FirstHandInRequest");current.HandInRequests+=1
        elseif kind=="MousePress"then current=cycle;if current then current.MousePressAttempts+=1 end end
        api.Record(kind.."Attempt",{Details=data,Timings=current})
    end
    function api.RoundComplete()
        if not alive then return end
        if cycle then stamp("RoundCompleteObserved")end
        api.Record("RoundCompleteObserved",{Timings=cycle})
    end
    function api.Sample(snapshot,force)
        if not alive then return end
        local ok,key=pcall(function()return options.Encode(options.Serialize(snapshot))end)
        if ok and(force or key~=lastSnapshot)then lastSnapshot=key;api.Record("State",snapshot)end
    end
    function api.Flush(extra)
        local batch=table.clone(pending)
        local ok,written=pcall(options.Write,batch,{Schema=1,SessionId=options.SessionId,PlaceId=options.PlaceId,
            TotalEvents=sequence,Counters=counters,Cycles=cycles,Events=ring,Current=options.Serialize(extra),
            Interpretation="Observed requests and input are attempts. NeedleOwned and round flags are client observations. Private gate labels are supplied only for a validated controller layout. Times are per-place monotonic; WallTimeMs links events across teleports."})
        if ok and written~=false then for _=1,#batch do table.remove(pending,1)end;return true end
        return false
    end
    function api.Stop(extra)if not alive then return end;api.Record("RecorderStopped",extra);api.Flush(extra);alive=false end
    function api.Cycle()return cycle end
    return api
end

-- Standalone observer: does not issue gameplay requests, clicks, teleports or attribute writes.
local ROOT="BeyyHub"
local SOURCE_URL="https://raw.githubusercontent.com/sceneton/needlehub/main/needle-latency-diagnostics.lua"
local CACHE_PATH=ROOT.."/needle_latency_recorder.lua"
local ENABLED_PATH=ROOT.."/needle_latency_enabled.txt"
local LOG_PATH=ROOT.."/needle_latency_events.jsonl"
local SUMMARY_PATH=ROOT.."/needle_latency_latest.json"
local FLAG="BeyyNeedleLatencyEnabled_v1"
local H=game:GetService("HttpService")
local Players=game:GetService("Players")
local World=game:GetService("Workspace")
local Storage=game:GetService("ReplicatedStorage")
local Teleport=game:GetService("TeleportService")
local RunService=game:GetService("RunService")
local Input=game:GetService("VirtualInputManager")
local boot=os.clock();local player=Players.LocalPlayer
while not player and os.clock()-boot<20 do task.wait(.1);player=Players.LocalPlayer end
if not player then warn("[Needle Trace] Local player did not load.");return end
if type(writefile)~="function"then warn("[Needle Trace] writefile is required.");return end
pcall(function()if type(makefolder)=="function"then makefolder(ROOT)end end)
local env=type(getgenv)=="function"and getgenv()or _G
local old=env.BeyyNeedleLatency
if type(old)=="table"and type(old.Stop)=="function"then pcall(old.Stop,"Replaced",true)end
local run={Running=true,SessionId=H:GenerateGUID(false),QueueInstalled=false,Hooks={}}
env.BeyyNeedleLatency=run
local connections,needleConnections={},{}
local needleFolder,needleParts=nil,{}
local pickRemote,handInRemote
local bindings={};local lastBindingScan=-math.huge
local sessionStart=os.clock()
local lastWorld,bytes,fallbackHistory=nil,0,nil
local function read(path)local ok,value=pcall(readfile,path);return ok and type(value)=="string"and value or nil end
local prior=read(LOG_PATH);bytes=prior and #prior or 0
if type(appendfile)~="function"then fallbackHistory=prior or""end
local function serialize(value,depth,seen)
    local kind=typeof(value)
    if kind=="nil"or kind=="boolean"then return value end
    if kind=="string"then return value:sub(1,1000)end
    if kind=="number"then return value==value and math.abs(value)<math.huge and value or tostring(value)end
    if kind=="Vector3"then return {X=value.X,Y=value.Y,Z=value.Z}end
    if kind=="CFrame"then return {Position=serialize(value.Position),Components={value:GetComponents()}}end
    if kind=="Instance"then local ok,path=pcall(value.GetFullName,value);return {Name=value.Name,Class=value.ClassName,Path=ok and path or nil}end
    if kind~="table"then return tostring(value)end
    depth=depth or 0;seen=seen or{};if depth>=7 or seen[value]then return "<bounded>"end
    seen[value]=true;local output,n={},0
    for key,child in pairs(value)do n+=1;if n>64 then output.Truncated=true;break end
        if type(key)=="string"or type(key)=="number"then output[key]=serialize(child,depth+1,seen)end
    end
    seen[value]=nil;return output
end
local function now()return os.clock()-sessionStart end
local function persistEnabled(value)
    pcall(writefile,ENABLED_PATH,value and "true"or"false")
    pcall(Teleport.SetTeleportSetting,Teleport,FLAG,value)
end
local recorder=createNeedleLatencyRecorder({SessionId=run.SessionId,PlaceId=game.PlaceId,Now=now,
    WallTimeMs=function()return DateTime.now().UnixTimestampMillis end,Serialize=serialize,Encode=function(t)return H:JSONEncode(t)end,
    Write=function(batch,summary)
        local lines={};for _,event in ipairs(batch)do lines[#lines+1]=H:JSONEncode(event)end
        local chunk=#lines>0 and(table.concat(lines,"\n").."\n")or""
        summary.TeleportQueueInstalled=run.QueueInstalled;summary.HookStatus=run.Hooks
        writefile(SUMMARY_PATH,H:JSONEncode(summary))
        if bytes+#chunk>8*1024*1024 then
            local previous=read(LOG_PATH);if previous then writefile(ROOT.."/needle_latency_events.previous.jsonl",previous)end
            writefile(LOG_PATH,"");bytes=0;fallbackHistory=fallbackHistory and""or nil
        end
        if #chunk>0 then
            if type(appendfile)=="function"then appendfile(LOG_PATH,chunk)
            else fallbackHistory=(fallbackHistory or"")..chunk;writefile(LOG_PATH,fallbackHistory)end
            bytes+=#chunk
        end
        return true
    end})
local function record(kind,data)recorder.Record(kind,data)end
local function hook(c)connections[#connections+1]=c;return c end
local function clear(list)for _,c in ipairs(list)do pcall(c.Disconnect,c)end;table.clear(list)end
local function currentNeedle()
    for part in pairs(needleParts)do
        local hidden=part:GetAttribute("HIDDEN_WITHIN")
        if part.Parent and part:GetAttribute("IsNeedleObjective")==true and(hidden==nil or hidden==false)then return part end
    end
end
local exposed
local function updateExposure()
    local current=currentNeedle()
    if current~=exposed then
        exposed=current
        if current then recorder.Exposed({Object=current,HayId=current:GetAttribute("HayId"),Position=current.Position})
        else record("NeedleNoLongerExposed")end
    end
end
local function bindNeedle()
    local server=World:FindFirstChild("NeedleObjectiveServer")
    local folder=server and server:FindFirstChild("Needle")
    if folder==needleFolder then return end
    clear(needleConnections);table.clear(needleParts);needleFolder=folder
    local function add(part)
        if not part:IsA("BasePart")or needleParts[part]then return end
        needleParts[part]=true
        needleConnections[#needleConnections+1]=part.AttributeChanged:Connect(function(name)
            if name=="HIDDEN_WITHIN"or name=="IsNeedleObjective"or name=="HayId"then
                record("NeedleAttribute",{Object=part,Attribute=name,Value=part:GetAttribute(name)});updateExposure()
            end
        end)
    end
    if folder then
        needleConnections[#needleConnections+1]=folder.DescendantAdded:Connect(function(obj)add(obj);updateExposure()end)
        needleConnections[#needleConnections+1]=folder.DescendantRemoving:Connect(function(obj)needleParts[obj]=nil;task.defer(updateExposure)end)
        for _,obj in ipairs(folder:GetDescendants())do add(obj)end
    end
    record("NeedleFolderChanged",{Folder=folder});updateExposure()
end
local function discoverControllers()
    if os.clock()-lastBindingScan<5 then return end
    lastBindingScan=os.clock();bindings={}
    if type(getconnections)~="function"or type(debug.getconstants)~="function"or type(debug.getupvalues)~="function"then return end
    local ok,list=pcall(getconnections,RunService.Heartbeat);if not ok then return end
    for _,connection in ipairs(list)do
        local fn=connection.Function
        if type(fn)=="function"then
            local good,constants=pcall(debug.getconstants,fn)
            if good then
                local owned,farmer=false,false
                for _,value in pairs(constants)do if value=="NeedleOwned"then owned=true elseif value=="Farmer_NPC"then farmer=true end end
                if owned and farmer then
                    local valid,values=pcall(debug.getupvalues,fn)
                    if valid then for _,value in pairs(values)do
                        if type(value)=="table"and type(rawget(value,"AutoPickupNeedle"))=="boolean"and type(rawget(value,"NeedleInterval"))=="number"then
                            bindings[#bindings+1]={Function=fn,Connection=connection,State=value};break
                        end
                    end end
                end
            end
        end
    end
end
local function controllerState()
    local result={CandidateCount=#bindings,Candidates={}}
    for _,binding in ipairs(bindings)do
        local state=binding.State;local row={Settings={}}
        for _,key in ipairs({"AutoPickupNeedle","AutoHandInNeedle","AutoFarmWins","AutoFarmHay","HayFarmCleared","NeedleInterval","AutoUseVacuum"})do row.Settings[key]=rawget(state,key)end
        local ok,uv=pcall(debug.getupvalues,binding.Function)
        if ok and type(uv[1])=="boolean"and type(uv[2])=="boolean"and uv[3]==state and type(uv[4])=="boolean"
            and uv[6]==player and type(uv[7])=="number"and type(uv[8])=="number"and type(uv[9])=="boolean"
            and uv[12]==World and uv[13]==handInRemote then
            row.Layout="Validated Chapter1 hand-in heartbeat"
            row.Unloaded=uv[1];row.InGame=uv[2];row.PickupStillActive=uv[4];row.Positioned=uv[9]
            row.NextRequestRemainingMs=math.max(0,uv[7]-os.clock())*1000
            row.PositionSettleRemainingMs=math.max(0,uv[8]-os.clock())*1000
            row.HandInBlockers={}
            if uv[1]then row.HandInBlockers[#row.HandInBlockers+1]="Hub unloaded"end
            if not uv[2]then row.HandInBlockers[#row.HandInBlockers+1]="Not in game"end
            if uv[4]then row.HandInBlockers[#row.HandInBlockers+1]="Pickup cleanup still active"end
            if row.NextRequestRemainingMs>0 then row.HandInBlockers[#row.HandInBlockers+1]="Retry timer"end
            if row.PositionSettleRemainingMs>0 then row.HandInBlockers[#row.HandInBlockers+1]="Farmer position settling"end
        else row.Layout="Unmapped controller; settings observed, private gates unavailable"end
        result.Candidates[#result.Candidates+1]=row
    end
    return result
end
local function snapshot(ray)
    local char=player.Character;local root=char and char:FindFirstChild("HumanoidRootPart");local hum=char and char:FindFirstChildOfClass("Humanoid")
    local camera=World.CurrentCamera;local npc=World:FindFirstChild("NPC");local farmer=npc and npc:FindFirstChild("Farmer_NPC")
    local flags={};for _,key in ipairs({"NeedleOwned","NeedleInputLocked","CutsceneActive","IntroCutsceneFinished","NeedleRoundComplete","HintViewerOpen","HoveredHayId","HayHeld","HayCapacity"})do flags[key]=player:GetAttribute(key)end
    local state={Flags=flags,Character=char,Root=root and root.CFrame,Anchored=root and root.Anchored,Health=hum and hum.Health,
        WalkSpeed=hum and hum.WalkSpeed,PlatformStand=hum and hum.PlatformStand,CameraType=camera and tostring(camera.CameraType),
        Camera=camera and camera.CFrame,Needle=exposed,NeedleId=exposed and exposed:GetAttribute("HayId"),
        NeedleDistance=root and exposed and(root.Position-exposed.Position).Magnitude,
        FarmerDistance=root and farmer and(root.Position-farmer:GetPivot().Position).Magnitude,Controllers=controllerState()}
    if ray and camera and exposed then
        local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={char,camera}
        local hit=World:Raycast(camera.CFrame.Position,camera.CFrame.LookVector*100,params)
        state.CenterRay={Hit=hit and hit.Instance,Position=hit and hit.Position,HitsNeedle=hit and hit.Instance==exposed or false}
        local screen,visible=camera:WorldToViewportPoint(exposed.Position)
        state.NeedleOnScreen=visible;state.NeedleScreenOffset=(Vector2.new(screen.X,screen.Y)-camera.ViewportSize/2).Magnitude
    end
    return state
end
local feedbackConnections={}
local function refreshRemotes()
    local folder=Storage:FindFirstChild("NeedleHaystack")
    local pick=folder and folder:FindFirstChild("PickHay");local hand=folder and folder:FindFirstChild("NeedleHandIn")
    if pick==pickRemote and hand==handInRemote then return end
    clear(feedbackConnections);pickRemote=pick;handInRemote=hand
    for _,remote in pairs({pick,hand})do if remote and remote:IsA("RemoteEvent")then
        feedbackConnections[#feedbackConnections+1]=remote.OnClientEvent:Connect(function(...)
            record("ObservedRemoteFeedback",{Remote=remote,Arguments=table.pack(...)})
        end)
    end end
    record("RemotesChanged",{PickHay=pick,NeedleHandIn=hand})
end
local interceptor=env.__BEYY_NEEDLE_LATENCY_INTERCEPTOR
if type(interceptor)~="table"or interceptor.JobId~=game.JobId or interceptor.PlaceId~=game.PlaceId then
    interceptor={JobId=game.JobId,PlaceId=game.PlaceId};env.__BEYY_NEEDLE_LATENCY_INTERCEPTOR=interceptor
    if type(hookmetamethod)=="function"and type(getnamecallmethod)=="function"then
        local original
        local wrapper=function(self,...)
            local observer=interceptor.Observe
            if observer and(self==interceptor.Pick or self==interceptor.Hand or self==Input)then
                local method=getnamecallmethod();pcall(observer,self,method,...)
            end
            return original(self,...)
        end
        local ok,value=pcall(function()return hookmetamethod(game,"__namecall",type(newcclosure)=="function"and newcclosure(wrapper)or wrapper)end)
        if ok then original=value;interceptor.Installed=true else interceptor.Error=tostring(value)end
    else interceptor.Error="Namecall observation is unavailable in this executor"end
end
run.Hooks.NamecallInstalled=interceptor.Installed==true;run.Hooks.NamecallError=interceptor.Error
interceptor.Observe=function(remote,method,...)
    if not run.Running then return end
    local args=table.pack(...)
    if method=="FireServer"and remote==pickRemote and(args[1]=="Objective"or exposed and args[1]==exposed:GetAttribute("HayId"))then
        recorder.Request("Pickup",{Remote=remote,Arguments=args,State=snapshot(true)})
    elseif method=="FireServer"and remote==handInRemote then
        recorder.Request("HandIn",{Remote=remote,Arguments=args,State=snapshot(false)})
    elseif remote==Input and method=="SendMouseButtonEvent"and(exposed or player:GetAttribute("NeedleOwned")==true)then
        recorder.Request(args[4]and "MousePress"or "MouseRelease",{X=args[1],Y=args[2],Button=args[3],State=snapshot(false)})
    end
end
local function bindRemoteObserver()refreshRemotes();interceptor.Pick=pickRemote;interceptor.Hand=handInRemote end
persistEnabled(true)
-- Queue a loader, not the hub. It respects Stop() without clearing other scripts' queued work.
local queuePayload=string.format([==[
task.spawn(function()
    local T=game:GetService("TeleportService");local enabled
    pcall(function()enabled=T:GetTeleportSetting(%q)end)
    if type(readfile)=="function"then local ok,v=pcall(readfile,%q);if ok and v=="false"then enabled=false elseif ok and v=="true"and enabled==nil then enabled=true end end
    if enabled==false then return end
    local ok,source=pcall(function()return game:HttpGet(%q)end)
    local fn=ok and type(source)=="string"and loadstring(source)
    if not fn and type(readfile)=="function"then ok,source=pcall(readfile,%q);if ok and type(source)=="string"then fn=loadstring(source)end end
    if fn then fn()else warn("[Needle Trace] Queued recorder could not load or compile.")end
end)
]==],FLAG,ENABLED_PATH,SOURCE_URL,CACHE_PATH)
local queue=(type(queue_on_teleport)=="function"and queue_on_teleport)or env.queue_on_teleport or queueonteleport or env.queueonteleport
if not queue and type(syn)=="table"then queue=syn.queue_on_teleport end
local stamp=tostring(game.PlaceId)..":"..game.JobId
if env.__BEYY_NEEDLE_TRACE_QUEUED_JOB==stamp then run.QueueInstalled=true
elseif type(queue)=="function"then
    local ok,result=pcall(queue,queuePayload)
    run.QueueInstalled=ok and result~=false
    if run.QueueInstalled then env.__BEYY_NEEDLE_TRACE_QUEUED_JOB=stamp else record("QueueFailed",{Error=tostring(result)})end
else record("QueueUnavailable")end
-- Keep a last known working copy for teleports where GitHub cannot be reached.
task.spawn(function()
    local ok,source=pcall(function()return game:HttpGet(SOURCE_URL)end)
    if ok and run.Running and type(source)=="string"and type(loadstring(source))=="function"then pcall(writefile,CACHE_PATH,source)end
end)
hook(player.AttributeChanged:Connect(function(name)
    if name=="NeedleOwned"then recorder.Ownership(player:GetAttribute(name)==true,false)
    elseif name=="NeedleRoundComplete"and player:GetAttribute(name)==true then recorder.RoundComplete()
    elseif name=="CutsceneActive"or name=="NeedleInputLocked"or name=="HintViewerOpen"or name=="HoveredHayId"then
        record("PlayerAttribute",{Attribute=name,Value=player:GetAttribute(name)})
    end
end))
hook(player.CharacterAdded:Connect(function(char)record("CharacterAdded",{Character=char})end))
hook(player.OnTeleport:Connect(function(state)
    record("Teleport",{State=tostring(state),QueueInstalled=run.QueueInstalled});recorder.Flush(lastWorld)
end))
function run.Stop(reason,keepEnabled)
    if not run.Running then return end
    run.Running=false;interceptor.Observe=nil;clear(connections);clear(needleConnections);clear(feedbackConnections)
    if not keepEnabled then persistEnabled(false)end
    recorder.Stop({Reason=reason or"Stopped by user",QueueDisabled=not keepEnabled})
end
function run.Export()return recorder.Flush(lastWorld)end
record("SessionStarted",{BootWaitMs=(os.clock()-boot)*1000,QueueInstalled=run.QueueInstalled,
    PriorSession=old and old.SessionId,HookStatus=run.Hooks,JobId=game.JobId})
bindRemoteObserver();bindNeedle();discoverControllers()
if player:GetAttribute("NeedleOwned")==true then recorder.Ownership(true,true)end
recorder.Flush(snapshot(false))
print("[Needle Trace] Standalone recording enabled | "..LOG_PATH.." | queue="..tostring(run.QueueInstalled))
task.spawn(function()
    local nextScan,nextSample,nextSave,nextRay=0,0,0,0
    while run.Running and env.BeyyNeedleLatency==run do
        local t=os.clock()
        local ok,err=pcall(function()
            if t>=nextScan then nextScan=t+.5;bindRemoteObserver();bindNeedle();discoverControllers();updateExposure()end
            local active=exposed~=nil or player:GetAttribute("NeedleOwned")==true
            if t>=nextSample then
                nextSample=t+(active and .1 or 1)
                local ray=active and t>=nextRay;if ray then nextRay=t+.5 end
                lastWorld=snapshot(ray);recorder.Sample(lastWorld,active)
            end
            if t>=nextSave then nextSave=t+5;recorder.Flush(lastWorld)end
        end)
        if not ok then record("ObserverError",{Error=tostring(err)})end
        task.wait(.05)
    end
end)
