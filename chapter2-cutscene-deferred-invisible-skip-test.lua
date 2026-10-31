-- Beyy Chapter 2 Cutscene-Only Standalone v6 INVISIBLE DEFERRED SKIP TEST
-- Beyy Chapter 2 Indexed Cutscene Visuals v1
-- Intro: defer native Skip until puzzles finish, visually mask Skip GUI while keeping its native click enabled.
-- Non-final lever/puzzle cinematics: local camera/input/overlay recovery only.
-- No puzzle or lever actions, hay teleport, progression remotes, or final-ending bypass.
local LOBBY=77108422251420
local CHAPTER2=83445806734780
local URL="https://raw.githubusercontent.com/sceneton/needlehub/main/chapter2-cutscene-deferred-invisible-skip-test.lua"
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local env=_G
if type(getgenv)=="function" then
    local ok,res=pcall(getgenv)
    if ok and type(res)=="table" then env=res end
end

if game.PlaceId==LOBBY then
    local queue=(type(queue_on_teleport)=="function" and queue_on_teleport)
        or env.queue_on_teleport or env.queueonteleport or env.queue_on_tp
    if type(queue)~="function" and type(syn)=="table" then
        queue=syn.queue_on_teleport
    end
    if type(queue)~="function" then
        warn("[CH2 CUTSCENE] queue_on_teleport unavailable; run again upon joining Chapter 2.")
        return
    end
    local payload,reason=nil,"no response"
    for attempt=1,3 do
        local ok,body=pcall(function()
            return game:HttpGet(URL.."?preload=cutscene-v6-invisible-deferred-"..tostring(os.time())..
                "-"..tostring(math.random(10000,99999)).."-"..tostring(attempt))
        end)
        if ok and type(body)=="string"
            and body:find("Beyy Chapter 2 Cutscene-Only Standalone v6 INVISIBLE DEFERRED SKIP TEST",1,true) then
            local fn,err=loadstring(body)
            if fn then
                payload=body
                break
            end
            reason=tostring(err)
        else
            reason=ok and "wrong version/invalid source" or tostring(body)
        end
        task.wait(0.25)
    end
    if not payload then
        warn("[CH2 CUTSCENE] NOT queued; source failed preflight: "..reason)
        return
    end
    local ok,err=pcall(queue,payload)
    if ok then
        print("[CH2 CUTSCENE] Compiled and queued cutscene-only v6 INVISIBLE DEFERRED INTRO (Main controller + noclip). Enter Chapter 2.")
    else
        warn("[CH2 CUTSCENE] Queue failed: "..tostring(err))
    end
    return
end
if game.PlaceId~=CHAPTER2 then
    warn("[CH2 CUTSCENE] Only Chapter 2 or the lobby is supported.")
    return
end

if type(env.__BEYY_CH2_CUTSCENE_ONLY_STOP)=="function" then
    pcall(env.__BEYY_CH2_CUTSCENE_ONLY_STOP,"restarted")
end
local started=os.clock()
local alive=true
local player=Players.LocalPlayer
local events={}
local connections={}
local bindName="BeyyCh2CutsceneOnly_"..tostring(player and player.UserId or 0)
local outputPath="BeyyHub/chapter2_cutscene_only_result.txt"
local stopReason="running"
local introClicks=0
local nextClickAt=0
local firstSkipVisibleAt=nil
local deferrals=0
local lastDeferralLogAt=-math.huge
local skipDeferralLimit=6.0
local skipClickedAt=nil
local skipDeferredResult="not observed"
local deferredUntilSolved=false
local nativeSkipForced=false
-- Visual mask only. Preserve Visible, Active, Enabled, and the native button.
local skipMaskOriginal={}
local skipMaskApplies=0
local skipMaskRestoreCount=0
local skipMaskButtonName="none"
local skipMaskActive=false
local skipManualFallback=false
local introCameraActive=false
local introCameraFrames=0
local introCameraReleased=false
-- Preserve the player's actual pre-Skip view for the non-final camera handoff.
local introHandoffLook=nil
local introHandoffDistance=nil
local introBridgeActive=false
local introBridgeStartedAt=-math.huge
local puzzleReleasePrimed=false
local nonfinalGraceUntil=0
local lastSceneSignal="none"
local lastFlagState=nil
local lastPuzzleCount=nil
local lastLeverSolved=nil
local lastSignalLoggedAt=-math.huge
local introBlack=nil
local blackOriginal=nil
local introBlackHidden=false
local introBlackRestored=false
local bypassActive=false
local bypassCount=0
local bypassFrames=0
local inputRestores=0
local postReleaseCameraGuardUntil=0
local cameraGuardRecoveries=0
local cameraGuardPreviousRoot=nil
local cameraGuardPreviousEye=nil
local cameraGuardAvatarDistance=0
local cameraGuardCameraDistance=0
local cameraGuardLastFix=-math.huge
local bypassStartedAt=0
local releaseGraceUntil=0
local finalProtectedLogged=false
local masked={}
local lastMaskAt=-math.huge
local lastInputAt=-math.huge
local lastReportAt=-math.huge
local yaw,pitch=0,-0.18
local cameraDistance=4
local stop

local function seconds()
    return os.clock()-started
end
local function emit(kind,value)
    local msg=string.format("+%.3fs [%s] %s",seconds(),tostring(kind),tostring(value))
    events[#events+1]=msg
    if #events>240 then table.remove(events,1) end
    print("[CH2 CUTSCENE] "..msg)
end
local function hook(signal,callback)
    local connection=signal:Connect(callback)
    connections[#connections+1]=connection
    return connection
end
local function endingProtected()
    if not player then return true end
    if player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("NeedleOwned")==true then return true end
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local ending=gui and gui:FindFirstChild("NeedleEndingUI")
    local results=ending and ending:FindFirstChild("ReturnToLobby",true)
    if not (ending and ending:IsA("ScreenGui") and ending.Enabled
        and results and results:IsA("GuiObject")) then return false end
    local node=results
    while node and node~=ending do
        if node:IsA("GuiObject") and not node.Visible then return false end
        node=node.Parent
    end
    return node==ending
end
local function nativeIntroSkip()
    if not player or endingProtected()
        or player:GetAttribute("IntroCutsceneFinished")==true then return nil end
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local fade=gui and gui:FindFirstChild("CutsceneFade")
    local holder=fade and fade:FindFirstChild("SkipCutsceneButton",true)
    local button=holder and holder:FindFirstChild("Button",true)
    if not (fade and holder and button and button:IsA("GuiButton")
        and button.Visible and button.AbsoluteSize.X>8
        and button.AbsoluteSize.Y>8) then return nil end
    local obj=button
    while obj and obj~=gui do
        if obj:IsA("GuiObject") and not obj.Visible then return nil end
        if obj:IsA("ScreenGui") and not obj.Enabled then return nil end
        obj=obj.Parent
    end
    return obj==gui and button or nil
end

-- Hide Skip's *artwork*, not the interactive button. Setting Visible=false
-- would prevent nativeIntroSkip() from finding it and would stop normal click.
-- Restore exact originals at intro completion/cleanup.
local function maskIntroSkipArtwork(button)
    if not button or endingProtected() then return end
    local gui=player and player:FindFirstChildOfClass("PlayerGui")
    local fade=gui and gui:FindFirstChild("CutsceneFade")
    local holder=fade and fade:FindFirstChild("SkipCutsceneButton",true)
    if not (holder and button:IsDescendantOf(holder)) then return end
    local function maskObject(obj)
        for _,property in ipairs({"BackgroundTransparency","TextTransparency",
            "TextStrokeTransparency","ImageTransparency"}) do
            local ok,v=pcall(function()return obj[property] end)
            if ok and type(v)=="number" then
                if not skipMaskOriginal[obj] then skipMaskOriginal[obj]={} end
                if skipMaskOriginal[obj][property]==nil then
                    skipMaskOriginal[obj][property]=v
                end
                if v<1 then pcall(function()obj[property]=1 end) end
            end
        end
        if obj:IsA("UIStroke") then
            if not skipMaskOriginal[obj] then skipMaskOriginal[obj]={} end
            if skipMaskOriginal[obj].Transparency==nil then
                skipMaskOriginal[obj].Transparency=obj.Transparency
            end
            if obj.Transparency<1 then obj.Transparency=1 end
        end
    end
    maskObject(holder)
    for _,obj in ipairs(holder:GetDescendants()) do maskObject(obj) end
    skipMaskApplies+=1
    skipMaskButtonName=button:GetFullName()
    if not skipMaskActive then
        skipMaskActive=true
        emit("INTRO","Native Skip artwork transparent while its actual GuiButton remains visible/clickable")
    end
end
local function restoreIntroSkipArtwork()
    if not skipMaskActive then return end
    skipMaskActive=false
    skipMaskRestoreCount+=1
    for obj,properties in pairs(skipMaskOriginal) do
        if obj.Parent then
            for property,v in pairs(properties) do
                pcall(function()obj[property]=v end)
            end
        end
        skipMaskOriginal[obj]=nil
    end
end
local function hideIntroBlack()
    if not player or player:GetAttribute("IntroCutsceneFinished")==true
        or endingProtected() then return end
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local fade=gui and gui:FindFirstChild("CutsceneFade")
    local black=fade and fade:FindFirstChild("Black",true)
    if not (black and black:IsA("GuiObject")) then return end
    if black~=introBlack then
        introBlack=black
        blackOriginal=black.Visible
    end
    if black.Visible then
        local ok=pcall(function()black.Visible=false end)
        if ok and not introBlackHidden then
            introBlackHidden=true
            emit("INTRO","Blackout hidden; no game actions sent")
        end
    end
end
local function restoreIntroBlack()
    if introBlackRestored then return end
    introBlackRestored=true
    -- The game may leave CutsceneFade enabled after native Skip. Forcing the
    -- originally visible Black overlay back then would cover gameplay.
    -- During cleanup before Skip, however, undo our temporary intro mask.
    if player and player:GetAttribute("IntroCutsceneFinished")==true then
        emit("INTRO","Opening blackout retained hidden after native Skip")
        return
    end
    if introBlack and introBlack.Parent and blackOriginal~=nil then
        pcall(function()introBlack.Visible=blackOriginal end)
    end
end
-- Capture both direction and zoom; the previous handoff silently changed
-- a 4-stud third-person intro view into the bypass's 0.6-stud first-person default.
local function captureIntroView()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    introHandoffLook=cam.CFrame.LookVector
    local char=player and player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local head=char:FindFirstChild("Head")
        local eye=head and head.Position or (root.Position+Vector3.new(0,1.6,0))
        local d=(cam.CFrame.Position-eye).Magnitude
        if d>=0.2 and d<=22 then introHandoffDistance=d end
    end
end
local function clickIntroSkip(button)
    if not alive or not button or not nativeIntroSkip() then return end
    -- Release pre-Skip camera mouse lock before synthetic GUI input.
    if introCameraActive then
        introCameraActive=false
        introCameraReleased=true
        captureIntroView()
        introBridgeActive=true
        introBridgeStartedAt=os.clock()
        -- Keep Scriptable camera pointed at the player until the release
        -- controller takes over; unlock the cursor for the native GUI click.
        pcall(function()UserInputService.MouseBehavior=Enum.MouseBehavior.Default end)
        emit("CAMERA","Seamless intro camera bridge for native Skip button")
    end
    local centre=button.AbsolutePosition+button.AbsoluteSize/2
    local inset=GuiService:GetGuiInset()
    local p=centre+(introClicks==1 and inset or Vector2.zero)
    local pressed=false
    local ok,err=pcall(function()
        VirtualInputManager:SendMouseMoveEvent(p.X,p.Y,game)
        task.wait(0.035)
        if not alive or not nativeIntroSkip() then return end
        VirtualInputManager:SendMouseButtonEvent(p.X,p.Y,0,true,game,0)
        pressed=true
        task.wait(0.075)
    end)
    if pressed then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(p.X,p.Y,0,false,game,0)
        end)
    end
    if pressed then skipClickedAt=seconds() end
    emit("INTRO",ok and ("Native Skip click #"..introClicks.." sent="..tostring(pressed))
        or ("Native Skip click failed: "..tostring(err)))
end
local function restoreMasked()
    for obj,props in pairs(masked) do
        if obj.Parent then
            for property,value in pairs(props) do
                pcall(function()obj[property]=value end)
            end
        end
        masked[obj]=nil
    end
end
local function maskNonfinalVisuals()
    if os.clock()-lastMaskAt<0.18 or not player then return end
    lastMaskAt=os.clock()
    local gui=player:FindFirstChildOfClass("PlayerGui")
    if not gui then return end
    local function mask(obj,key)
        local ok,value=pcall(function()return obj[key] end)
        if not ok or type(value)~="number" or value>=1 then return end
        local saved=masked[obj]
        if not saved then saved={};masked[obj]=saved end
        if saved[key]==nil then saved[key]=value end
        pcall(function()obj[key]=1 end)
    end
    for _,screen in ipairs(gui:GetChildren()) do
        if screen:IsA("ScreenGui") then
            local name=screen.Name:lower()
            if (name=="cutscenefade" or name:find("cutscene",1,true)
                or name:find("cinematic",1,true)
                or name:find("chapter2release",1,true))
                and not name:find("needle",1,true)
                and not name:find("ending",1,true) then
                for _,obj in ipairs(screen:GetDescendants()) do
                    if obj:IsA("GuiObject") then
                        mask(obj,"BackgroundTransparency")
                        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                            mask(obj,"ImageTransparency")
                        elseif obj:IsA("TextLabel") or obj:IsA("TextButton")
                            or obj:IsA("TextBox") then
                            mask(obj,"TextTransparency")
                            mask(obj,"TextStrokeTransparency")
                        end
                    elseif obj:IsA("UIStroke") then
                        mask(obj,"Transparency")
                    end
                end
            end
        end
    end
end

-- This controller is copied from Chapter2 Main (launchCutsceneBypass),
-- with only its Main/UI dependencies replaced by standalone state.
-- It runs separately from the native intro Skip/blackout handler.
local finalEndingProtected=false
local needleBusy=false
local leverRunning=false
local colourRunning=false
local gemCutsceneCameraAim=nil
local hubWindow={Closed=true}
local leverBypassUntil=0
local puzzleBypassUntil=0
local cutsceneBypassRefresh=nil
local cutsceneBypassStop=nil
local puzzleNoclipActive=false
local puzzleNoclipUsed=false
local puzzleNoclipStartedAt=-math.huge
local puzzleNoclipUntil=-math.huge
local puzzleNoclipCharacter=nil
local puzzleNoclipSaved={}
local puzzleNoclipFloor=nil
local puzzleNoclipFloorY=nil
local puzzleNoclipFrames=0
local puzzleNoclipActivations=0

local function shouldYieldCutsceneBypass()
    return not alive or endingProtected() or introCameraActive
end
local function setCutsceneBypassActive(on)
    local was=bypassActive
    bypassActive=on==true
    if bypassActive then introBridgeActive=false end
    if bypassActive and not was then
        bypassCount+=1
        emit("MAIN CUTSCENE","Playable camera activated")
    elseif was and not bypassActive then
        emit("MAIN CUTSCENE",endingProtected() and
            "Released bypass; native final cinematic camera left untouched"
            or "Native camera restored")
    end
end

local function enableCamera()
    local char=player and player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local cam=Workspace.CurrentCamera
    if not (root and cam) then return false end
    local look=root.CFrame.LookVector
    yaw=math.atan2(look.X,look.Z)
    pitch=-0.18
    return true
end
local function restoreNativeCamera()
    -- When the key/ending begins, native cutscene code owns the camera.
    -- Changing CameraType back to Custom here can cancel that cutscene.
    if endingProtected() or finalEndingProtected then return end
    local cam=Workspace.CurrentCamera
    if cam then
        local char=player and player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function()cam.CameraSubject=hum end) end
        pcall(function()cam.CameraType=Enum.CameraType.Custom end)
    end
    pcall(function()UserInputService.MouseBehavior=Enum.MouseBehavior.Default end)
end
local function beginIntroCamera()
    if not alive or introCameraActive or introCameraReleased
        or bypassActive or not player or endingProtected()
        or player:GetAttribute("IntroCutsceneFinished")==true then return end
    if not enableCamera() then return end
    introCameraActive=true
    emit("CAMERA","Pre-Skip mouse camera enabled")
end
local function finishIntroCamera(reason)
    if not introCameraActive then return end
    captureIntroView()
    introCameraActive=false
    introCameraReleased=true
    if reason=="native intro Skip allowed" and not endingProtected() then
        introBridgeActive=true
        introBridgeStartedAt=os.clock()
        -- No intermediate Custom camera: the non-final controller will
        -- take ownership as soon as the native intro ends.
        pcall(function()UserInputService.MouseBehavior=Enum.MouseBehavior.Default end)
        emit("CAMERA","Seamless pre-Skip bridge armed")
    else
        introBridgeActive=false
        restoreNativeCamera()
    end
    emit("CAMERA","Pre-Skip camera released: "..tostring(reason))
end
local function driveCamera()
    if not alive or endingProtected() or
        (not introCameraActive and not introBridgeActive) then return end
    if introBridgeActive and (bypassActive or os.clock()-introBridgeStartedAt>2.5) then
        introBridgeActive=false
        if not bypassActive then
            local cam=Workspace.CurrentCamera
            local char=player and player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if cam then
                if hum then pcall(function()cam.CameraSubject=hum end) end
                pcall(function()cam.CameraType=Enum.CameraType.Custom end)
            end
        end
        return
    end
    local char=player and player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local cam=Workspace.CurrentCamera
    if not (root and cam) then return end
    local ok,delta=pcall(function()return UserInputService:GetMouseDelta()end)
    if introCameraActive and not UserInputService:GetFocusedTextBox() then
        pcall(function()UserInputService.MouseBehavior=Enum.MouseBehavior.LockCenter end)
        if ok and delta then
            yaw-=delta.X*0.004
            pitch=math.clamp(pitch-delta.Y*0.004,-1,0.85)
        end
    end
    local cp=math.cos(pitch)
    local dir=Vector3.new(math.sin(yaw)*cp,math.sin(pitch),math.cos(yaw)*cp)
    local focus=root.Position+Vector3.new(0,1.6,0)
    local desired=focus-dir*cameraDistance
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={char}
    params.RespectCanCollide=true
    local hit=Workspace:Raycast(focus,desired-focus,params)
    if hit then desired=focus-dir*math.max(0.45,(hit.Position-focus).Magnitude-0.3) end
    cam.CameraType=Enum.CameraType.Scriptable
    cam.CFrame=CFrame.lookAt(desired,focus,Vector3.yAxis)
    cam.Focus=CFrame.new(focus)
    introCameraFrames+=1
end

-- Non-final puzzle-release noclip only. Original collision state is
-- captured per avatar part and restored on release, ending, stop, or death.
-- A temporary local floor follows X/Z to prevent falling through the map.
local function endPuzzleNoclip(reason)
    if not puzzleNoclipActive and not puzzleNoclipFloor then return end
    puzzleNoclipActive=false
    for part,original in pairs(puzzleNoclipSaved) do
        if part.Parent then pcall(function()part.CanCollide=original end) end
        puzzleNoclipSaved[part]=nil
    end
    if puzzleNoclipFloor then
        pcall(function()puzzleNoclipFloor:Destroy()end)
        puzzleNoclipFloor=nil
    end
    puzzleNoclipCharacter=nil
    puzzleNoclipFloorY=nil
    emit("NOCLIP","OFF "..tostring(reason)..
        " frames="..tostring(puzzleNoclipFrames))
end
local function beginPuzzleNoclip(root)
    if puzzleNoclipActive or puzzleNoclipUsed
        or not alive or not player
        or player:GetAttribute("NeedleOwned")==true
        or player:GetAttribute("NeedleRoundComplete")==true
        or player:GetAttribute("IntroCutsceneFinished")~=true then return end
    local char=player.Character
    if not (char and root and root.Parent==char) then return end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    puzzleNoclipUsed=true
    puzzleNoclipActive=true
    puzzleNoclipCharacter=char
    puzzleNoclipStartedAt=os.clock()
    puzzleNoclipUntil=os.clock()+14
    puzzleNoclipFrames=0
    puzzleNoclipActivations+=1
    local floorY=root.Position.Y-(hum.HipHeight+root.Size.Y*0.5)
    local rayParams=RaycastParams.new()
    rayParams.FilterType=Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances={char}
    local hit=Workspace:Raycast(root.Position,Vector3.new(0,-9,0),rayParams)
    if hit and math.abs(hit.Position.Y-floorY)<4 then
        floorY=hit.Position.Y
    end
    puzzleNoclipFloorY=floorY
    local support=Instance.new("Part")
    support.Name="BeyyCh2_NoclipLocalFloor"
    support.Anchored=true
    support.CanCollide=true
    support.CanTouch=false
    -- Keep CanQuery at its default: Roblox requires it when CanCollide=true.
    support.Transparency=1
    support.Size=Vector3.new(4,0.3,4)
    support.CFrame=CFrame.new(root.Position.X,floorY-0.16,root.Position.Z)
    support.Parent=Workspace
    puzzleNoclipFloor=support
    emit("NOCLIP",string.format(
        "ON for puzzle-release cinematic, max 14s; floorY=%.2f; no teleport",
        floorY))
end
hook(RunService.Stepped,function()
    if not puzzleNoclipActive then return end
    local char=puzzleNoclipCharacter
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not alive or endingProtected()
        or not char or char~=player.Character or not root
        or os.clock()>=puzzleNoclipUntil then
        endPuzzleNoclip("expired, ending, or character changed")
        return
    end
    -- Keep every avatar collider disabled. Tools and map geometry are not
    -- touched, and every previous CanCollide value is restored afterward.
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            if puzzleNoclipSaved[obj]==nil then
                puzzleNoclipSaved[obj]=obj.CanCollide
            end
            if obj.CanCollide then obj.CanCollide=false end
        end
    end
    if puzzleNoclipFloor then
        puzzleNoclipFloor.CFrame=CFrame.new(
            root.Position.X,puzzleNoclipFloorY-0.16,root.Position.Z)
    end
    puzzleNoclipFrames+=1
end)


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
        local renderId = "BeyyCh2CutsceneOnly_MainCamera"
        local renderPriority = Enum.RenderPriority.Last.Value + 2000
        -- Avoid Scriptable/Custom camera ping-pong across brief cutscene flag gaps.
        local RECOVERY_GRACE_SECONDS = 0.75
        local INTRO_SETTLE_SECONDS = 0.12
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
            local puzzleFolder=ReplicatedStorage:FindFirstChild("Puzzles")
        local solved=puzzleFolder and (tonumber(puzzleFolder:GetAttribute("SolvedPuzzleCount")) or 0) or 0
        -- Skip the old intro settling delay once all three puzzles are
        -- confirmed, so the playable camera can take over immediately.
        if solved<3 and introConfirmedAt and os.clock()-introConfirmedAt<INTRO_SETTLE_SECONDS then return nil end
            if yieldingToEnding or finalEndingProtected then return nil end
            if player:GetAttribute("Chapter2ReleaseActive") == true
                or os.clock() < puzzleBypassUntil
                or (solved>=3 and player:GetAttribute("CutsceneActive")==true) then
                return "THREE PUZZLES"
            end
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
            if introHandoffLook and introHandoffLook.Magnitude > 0.5 then
                local handoff=introHandoffLook
                local flat=Vector3.new(handoff.X,0,handoff.Z)
                yaw=flat.Magnitude>0.01 and math.atan2(flat.X,flat.Z)
                    or (lastNormalYaw or math.atan2(planar.X,planar.Z))
                pitch=clamp(math.asin(clamp(handoff.Y,-0.99,0.99)),-1.20,1.05)
                introHandoffLook=nil
            else
                yaw = lastNormalYaw or math.atan2(planar.X, planar.Z)
                pitch = clamp(lastNormalPitch or -0.16, -1.20, 1.05)
            end
            if introHandoffDistance then
                lastNormalDistance=introHandoffDistance
                normalFirstPerson=introHandoffDistance<2.5
                introHandoffDistance=nil
            end
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
            if safe then bypassFrames+=1 end
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

        local function keepReleaseVisualsHidden()
            -- Native release GUI may outlive replicated cutscene flags.
            -- Hide ONLY non-final cinematic artwork until the key/ending begins.
            return puzzleReleasePrimed
                and player:GetAttribute("IntroCutsceneFinished")==true
                and player:GetAttribute("NeedleOwned")~=true
                and player:GetAttribute("NeedleRoundComplete")~=true
                and not finalEndingProtected and not yieldingToEnding
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
        -- Discover GUI membership once; refresh eligibility only after names/ancestry change.
        local function createCutsceneVisualIndex(options)
            local api={Candidates={}}
            local current,nodes,connections,dirty=nil,{},{},false
            local function keys(object)
                if object:IsA("GuiObject")then
                    local result={"BackgroundTransparency"}
                    if object:IsA("CanvasGroup")then result[#result+1]="GroupTransparency"end
                    if object:IsA("TextLabel")or object:IsA("TextButton")or object:IsA("TextBox")then
                        result[#result+1]="TextTransparency";result[#result+1]="TextStrokeTransparency"
                    end
                    if object:IsA("ImageLabel")or object:IsA("ImageButton")then result[#result+1]="ImageTransparency"end
                    return result
                elseif object:IsA("UIStroke")then return {"Transparency"}end
            end
            local function eligible(object)
                local node,cinematic=object,false
                while node and node~=current do
                    if node.Name=="NeedleEndingUI"then return false end
                    if node:IsA("ScreenGui")then return options.IsOverlay(node)or cinematic end
                    if node:IsA("GuiObject")then
                        local name=node.Name:lower()
                        cinematic=cinematic or name:find("letterbox",1,true)~=nil or name:find("cinematicbar",1,true)~=nil
                            or name:find("cutscenebar",1,true)~=nil or name:find("blackbar",1,true)~=nil
                            or name:find("dialogue",1,true)~=nil or name:find("dialogbox",1,true)~=nil or name:find("subtitle",1,true)~=nil
                    end
                    node=node.Parent
                end
                return false
            end
            local function refresh(object,entry)
                local matching=entry.Keys and eligible(object)
                if matching then api.Candidates[object]=entry.Keys
                elseif api.Candidates[object]then
                    api.Candidates[object]=nil
                    options.Restore(object)
                end
            end
            local function remove(object)
                local entry=nodes[object]
                if not entry then return end
                for _,connection in ipairs(entry.Connections)do connection:Disconnect()end
                nodes[object]=nil;api.Candidates[object]=nil
                options.Restore(object)
            end
            local function add(object)
                if nodes[object]then return end
                local entry={Keys=keys(object),Connections={}}
                nodes[object]=entry
                if object:IsA("GuiObject")or object:IsA("ScreenGui")then
                    entry.Connections[#entry.Connections+1]=object:GetPropertyChangedSignal("Name"):Connect(function()dirty=true end)
                end
                entry.Connections[#entry.Connections+1]=object.AncestryChanged:Connect(function()
                    if current and object:IsDescendantOf(current)then dirty=true else remove(object)end
                end)
                refresh(object,entry)
            end
            function api.Clear()
                for _,connection in ipairs(connections)do connection:Disconnect()end
                for _,entry in pairs(nodes)do for _,connection in ipairs(entry.Connections)do connection:Disconnect()end end
                table.clear(connections);table.clear(nodes);table.clear(api.Candidates)
                current=nil;dirty=false
            end
            function api.Bind(gui)
                if gui~=current then
                    api.Clear();current=gui
                    if gui then
                        connections[1]=gui.DescendantAdded:Connect(add)
                        connections[2]=gui.DescendantRemoving:Connect(remove)
                        for _,object in ipairs(gui:GetDescendants())do add(object)end
                    end
                end
                if dirty then
                    dirty=false
                    for object,entry in pairs(nodes)do refresh(object,entry)end
                end
            end
            return api
        end
        local function restoreIndexedVisual(object)
            local props=finalVisualBefore[object]
            if not props then return end
            if not endingProtected() and not finalEndingProtected and object.Parent then
                for key,original in pairs(props)do pcall(function()object[key]=original end)end
            end
            finalVisualBefore[object]=nil
        end
        local visualIndex=createCutsceneVisualIndex({IsOverlay=isFinalOverlay,Restore=restoreIndexedVisual})
        local function hideFinalCutsceneVisuals()
            if not finalVisualsEnabled or(not scene and not keepReleaseVisualsHidden())then return end
            local pg=player:FindFirstChildOfClass("PlayerGui")
            visualIndex.Bind(pg)
            if not pg then return end
            for object,keys in pairs(visualIndex.Candidates)do
                if object.Parent then
                    for _,key in ipairs(keys)do maskFinalProperty(object,key)end
                end
            end
        end
        local function restoreFinalCutsceneVisuals()
            visualIndex.Clear()
            -- Avoid resurrecting old puzzle-release bars/dialogue when the
            -- needle ending starts. The game's final UI must stay authoritative.
            if endingProtected() or finalEndingProtected then return end
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
            inputRestores+=1
        end
        local function alignCharacterFacing()
            if not alive or not enabled or not active or not faceCameraEnabled then return end
            -- The return controller owns character placement after 3/3.
            -- Never rotate HumanoidRootPart every render during puzzle release.
            if scene=="THREE PUZZLES" then return end
            local puzzles=ReplicatedStorage:FindFirstChild("Puzzles")
            if puzzles and (tonumber(puzzles:GetAttribute("SolvedPuzzleCount")) or 0)>=3 then return end
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
            local endingNow=endingProtected() or finalEndingProtected
            local cam = camera()
            if cam and not endingNow then
                local hum = humanoid()
                if hum then pcall(function() cam.CameraSubject = hum end) end
                pcall(function() cam.CameraType = Enum.CameraType.Custom end)
            elseif endingNow then
                emit("FINAL","Handoff without camera reset; final cinematic owns CameraType="..
                    tostring(cam and cam.CameraType))
            end
            local hum = humanoid()
            if hum and lastSavedRotate ~= nil then
                pcall(function() hum.AutoRotate = lastSavedRotate end)
            end
            local ctrl = getControls()
            if ctrl then pcall(function() ctrl:Enable() end) end
            if originalMouseBehavior then
                if not endingNow then
                    pcall(function() UserInputService.MouseBehavior = originalMouseBehavior end)
                end
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
            -- The game's client camera can be left Scriptable after native
            -- release flags go false. Watch the *actual camera* for a short
            -- window and only intervene when it stops following the avatar.
            if puzzleReleasePrimed and not endingProtected()
                and player:GetAttribute("Chapter2ReleaseActive")~=true
                and player:GetAttribute("CutsceneActive")~=true then
                postReleaseCameraGuardUntil=os.clock()+9
                cameraGuardPreviousRoot=nil
                cameraGuardPreviousEye=nil
                cameraGuardAvatarDistance=0
                cameraGuardCameraDistance=0
                emit("CAMERA","Release ended: post-cinematic camera ownership watchdog armed (9s)")
            end
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
                        local hum=humanoid()
                        if hum and lastSavedRotate~=nil then
                            pcall(function() hum.AutoRotate=lastSavedRotate end)
                        end
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
                if not keepReleaseVisualsHidden() then restoreFinalCutsceneVisuals() end
                unwatchLeverCamera()
                scene = nil
                recoveryEnd = now + RECOVERY_GRACE_SECONDS
                task.delay(RECOVERY_GRACE_SECONDS + 0.008, function()
                    if alive then updateScene() end
                end)
            end
            -- The 0.75s recovery grace may outlive the release and overlap
            -- the native final cutscene. Never run input/HUD/camera overrides
            -- even for one extra frame once the ending is protected.
            local shouldKeep = enabled and not endingProtected() and not finalEndingProtected
                and not yieldingToEnding and (current ~= nil or now < recoveryEnd)
            if shouldKeep then
                if not active then enablePlayableCamera("recovery / F7") end
                restoreInputs()
                showGameplayHud()
                hideFinalCutsceneVisuals()
            else
                if keepReleaseVisualsHidden() then
                    hideFinalCutsceneVisuals()
                else
                    restoreFinalCutsceneVisuals()
                end
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
        -- Defensive camera recovery after the native puzzle release. Do
        -- not force a new camera during puzzle work or the final needle ending.
        local lastGuardSample=-math.huge
        hook(RunService.Heartbeat:Connect(function()
            local now=os.clock()
            if now>=postReleaseCameraGuardUntil or now-lastGuardSample<0.20 then return end
            lastGuardSample=now
            if not alive or active or introCameraActive or introBridgeActive
                or endingProtected() or finalEndingProtected
                or player:GetAttribute("Chapter2ReleaseActive")==true
                or player:GetAttribute("CutsceneActive")==true then
                if endingProtected() or finalEndingProtected then
                    postReleaseCameraGuardUntil=0
                end
                return
            end
            local cam,rt,hum=camera(),root(),humanoid()
            if not cam or not rt or not hum then return end
            if cameraGuardPreviousRoot and cameraGuardPreviousEye then
                cameraGuardAvatarDistance+=(rt.Position-cameraGuardPreviousRoot).Magnitude
                cameraGuardCameraDistance+=(cam.CFrame.Position-cameraGuardPreviousEye).Magnitude
            end
            cameraGuardPreviousRoot=rt.Position
            cameraGuardPreviousEye=cam.CFrame.Position
            local scripted=cam.CameraType~=Enum.CameraType.Custom
            local frozen=(cameraGuardAvatarDistance>=14 and cameraGuardCameraDistance<1.4)
            if (scripted or frozen) and now-cameraGuardLastFix>1.2 then
                cameraGuardLastFix=now
                local oldType=tostring(cam.CameraType)
                local ok,err=pcall(function()
                    cam.CameraSubject=hum
                    if cam.CameraType==Enum.CameraType.Custom then
                        cam.CameraType=Enum.CameraType.Scriptable
                    end
                    cam.CameraType=Enum.CameraType.Custom
                end)
                if ok then
                    cameraGuardRecoveries+=1
                    emit("CAMERA",string.format(
                        "RECOVERED camera after release #%d oldType=%s frozen=%s avatarTravel=%.1f cameraTravel=%.1f",
                        cameraGuardRecoveries,oldType,tostring(frozen),
                        cameraGuardAvatarDistance,cameraGuardCameraDistance))
                else
                    emit("CAMERA","Post-release recovery error: "..tostring(err))
                end
                cameraGuardAvatarDistance=0
                cameraGuardCameraDistance=0
                cameraGuardPreviousRoot=nil
                cameraGuardPreviousEye=nil
            elseif cameraGuardAvatarDistance>=14 then
                cameraGuardAvatarDistance=0
                cameraGuardCameraDistance=0
            end
        end))
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
local function report()
    local list={
        "CHAPTER 2 CUTSCENE-ONLY STANDALONE v6 INVISIBLE DEFERRED SKIP TEST",
        "No lever/puzzle/needle remotes sent. No teleport performed.",
        "Intro Skip attempts: "..tostring(introClicks),
        "Intro Skip first visible: "..tostring(firstSkipVisibleAt),
        "Intro Skip clicked at: "..tostring(skipClickedAt),
        "Intro Skip defer samples: "..tostring(deferrals),
        "Intro Skip deferred until solved: "..tostring(deferredUntilSolved),
        "Intro Skip timeout fallback: "..tostring(nativeSkipForced),
        "Intro Skip defer outcome: "..tostring(skipDeferredResult),
        "Intro Skip visual mask active: "..tostring(skipMaskActive),
        "Intro Skip visual mask passes: "..tostring(skipMaskApplies),
        "Intro Skip visual mask restorations: "..tostring(skipMaskRestoreCount),
        "Intro Skip masked button: "..tostring(skipMaskButtonName),
        "Intro early camera frames: "..tostring(introCameraFrames),
        "Last non-final signal: "..tostring(lastSceneSignal),
        "Imported Chapter2 Main controller active: "..tostring(cutsceneBypassStop~=nil),
        "Main puzzle-release noclip activations: "..tostring(puzzleNoclipActivations),
        "Main puzzle-release noclip frames: "..tostring(puzzleNoclipFrames),
        "Main noclip currently active: "..tostring(puzzleNoclipActive),
        "Blackout hidden: "..tostring(introBlackHidden),
        "Non-final bypass activations: "..tostring(bypassCount),
        "Non-final camera frames: "..tostring(bypassFrames),
        "Movement restore passes: "..tostring(inputRestores),
        "Post-release camera watchdog recoveries: "..tostring(cameraGuardRecoveries),
        "Post-release camera watchdog until: "..tostring(math.max(0,postReleaseCameraGuardUntil-os.clock())),
        "Final ending protected: "..tostring(finalProtectedLogged),
        "Only local non-final cinematic visuals/input changed; server timers not modified.",
        "Stopped: "..stopReason,
        "=== EVENTS ===",
        table.concat(events,"\n"),
    }
    return table.concat(list,"\n")
end
local function save(copy)
    local body=report()
    if type(writefile)=="function" then
        if type(makefolder)=="function" then
            pcall(function()
                if type(isfolder)~="function" or not isfolder("BeyyHub") then
                    makefolder("BeyyHub")
                end
            end)
        end
        local ok,err=pcall(writefile,outputPath,body)
        if not ok then warn("[CH2 CUTSCENE] Report write failed: "..tostring(err)) end
    end
    if copy and type(setclipboard)=="function" then
        local ok=pcall(setclipboard,body)
        if ok then print("[CH2 CUTSCENE] F8 copied report to clipboard") end
    end
end
stop=function(reason)
    if not alive then return end
    stopReason=tostring(reason or "manual stop")
    alive=false
    restoreIntroSkipArtwork()
    endPuzzleNoclip("standalone stopped")
    if cutsceneBypassStop then
        pcall(cutsceneBypassStop)
        cutsceneBypassStop=nil
    end
    finishIntroCamera("cleanup")
    restoreIntroBlack()
    restoreNativeCamera()
    pcall(function()RunService:UnbindFromRenderStep(bindName)end)
    for _,connection in ipairs(connections) do
        pcall(function()connection:Disconnect()end)
    end
    table.clear(connections)
    emit("DONE",stopReason)
    save(false)
end
env.__BEYY_CH2_CUTSCENE_ONLY_STOP=stop
env.__BEYY_CH2_CUTSCENE_ONLY_REPORT=report
hook(UserInputService.InputBegan,function(input)
    if input.KeyCode==Enum.KeyCode.F8 then save(true) end
end)
pcall(function()RunService:UnbindFromRenderStep(bindName)end)
RunService:BindToRenderStep(bindName,Enum.RenderPriority.Last.Value+2100,driveCamera)
emit("READY","Cutscene-only v6 CINEFIX3: ending-safe handoff; no delayed Custom camera override or stale puzzle overlay restore; F8 report.")
if not launchCutsceneBypass() then
    emit("ERROR","Imported Chapter2 Main bypass failed to initialize")
end
if type(env.__BEYY_CH2_COMBO_STOP)=="function" then
    emit("WARNING","Another Chapter 2 combo puzzle controller is present; do not run Main and this standalone together.")
end
task.spawn(function()
    local wasNonfinal=false
    local lastSaveAt=0
    while alive and seconds()<480 do
        local ok,err=pcall(function()
            if not player then player=Players.LocalPlayer end
            if not player then return end
            if endingProtected() then
                restoreIntroSkipArtwork()
                if not finalProtectedLogged then
                    finalProtectedLogged=true
                    emit("FINAL","Final needle ending protected; no bypass or Skip clicks")
                end
                finalEndingProtected=true
            endPuzzleNoclip("final ending protected")
            if cutsceneBypassRefresh then cutsceneBypassRefresh() end
                restoreIntroBlack()
                return
            end
            local introDone=player:GetAttribute("IntroCutsceneFinished")==true
            local cutscene=player:GetAttribute("CutsceneActive")==true
            local release=player:GetAttribute("Chapter2ReleaseActive")==true
            local locked=player:GetAttribute("NeedleInputLocked")==true
            local folder=ReplicatedStorage:FindFirstChild("Puzzles")
            local solved=folder and tonumber(folder:GetAttribute("SolvedPuzzleCount")) or 0
            local leverSolved=folder and folder:GetAttribute("LeverPuzzleSolved")==true or false
            if solved>=3 and not puzzleReleasePrimed and not endingProtected() then
                puzzleReleasePrimed=true
                puzzleBypassUntil=math.max(puzzleBypassUntil,os.clock()+3.5)
                emit("NONFINAL","3/3 puzzles: local release bypass prearmed before native Skip")
            end
            if not introDone then
                hideIntroBlack()
                local skip=nativeIntroSkip()
                if skip and not skipManualFallback then maskIntroSkipArtwork(skip) end
                if skip and introClicks>=3 and skipClickedAt
                    and seconds()-skipClickedAt>=0.45 and not skipManualFallback then
                    skipManualFallback=true
                    restoreIntroSkipArtwork()
                    emit("INTRO","Skip confirmation missing after retries: native Skip button made visible for manual recovery")
                end
                if skip and firstSkipVisibleAt==nil then
                    firstSkipVisibleAt=seconds()
                    emit("INTRO",string.format(
                        "Native Skip visible at +%.3fs; delay only if puzzle worker is still running",
                        firstSkipVisibleAt))
                end
                -- v32 had a 71-stud native Skip snapback during Number
                -- paper collection. Defer ONLY the native intro click while
                -- a standalone solver is active. The original click still
                -- executes immediately once 3/3 is server replicated.
                -- Six seconds after the button first appears, fall back
                -- regardless of progress so the intro cannot hang.
                local puzzleBusy=env.__BEYY_CH2_COMBO_PUZZLE_RUNNING==true
                    and solved<3
                local skipVisibleFor=skip and
                    (seconds()-(firstSkipVisibleAt or seconds())) or 0
                local deferSkip=skip~=nil and puzzleBusy
                    and skipVisibleFor<skipDeferralLimit
                if skip and not deferSkip then
                    if introClicks==0 and puzzleBusy then
                        nativeSkipForced=true
                        skipDeferredResult="timeout fallback at "..string.format("%.2fs",skipVisibleFor)
                        emit("INTRO","Deferral timeout; native intro Skip fallback even though puzzles unfinished")
                    elseif introClicks==0 and deferrals>0 then
                        deferredUntilSolved=true
                        skipDeferredResult="3/3 done, click native Skip without disrupting active paper requests"
                        emit("INTRO","3/3 server puzzles complete, native intro Skip is now allowed")
                    elseif introClicks==0 then
                        skipDeferredResult="no active puzzle work, normal click"
                    end
                    finishIntroCamera("native intro Skip allowed")
                elseif skip and deferSkip then
                    deferrals+=1
                    -- Keep the existing early camera usable while we wait.
                    if seconds()-lastDeferralLogAt>=1.25 then
                        lastDeferralLogAt=seconds()
                        emit("INTRO",string.format(
                            "Deferring native Skip: solved=%d/3, running=%s, remaining=%.2fs; early camera retained",
                            solved,tostring(puzzleBusy),skipDeferralLimit-skipVisibleFor))
                    end
                elseif cutscene and player.Character
                    and not introCameraReleased then
                    beginIntroCamera()
                end
                if skip and not deferSkip and introClicks<5
                    and seconds()<42 and seconds()>=nextClickAt then
                    introClicks+=1
                    nextClickAt=seconds()+0.45
                    task.spawn(clickIntroSkip,skip)
                end
            else
                finishIntroCamera("IntroCutsceneFinished")
                restoreIntroSkipArtwork()
                restoreIntroBlack()
            end

            -- Watch replicated flags/puzzle progress without sending game actions.
            -- Short cinematics can pulse or overlap the intro.
            local state=tostring(introDone).."/"..tostring(cutscene).."/"..
                tostring(release).."/"..tostring(locked).."/"..
                tostring(solved).."/"..tostring(leverSolved)
            if state~=lastFlagState then
                if os.clock()-lastSignalLoggedAt>=0.16 then
                    emit("STATE","intro/cutscene/release/inputLock/solved/lever="..state)
                    lastSignalLoggedAt=os.clock()
                end
                lastFlagState=state
            end
            -- Main cutscene controller reads these native/replicated signals.
            -- We only extend a short local grace; no puzzle actions are sent.
            if introDone then
                local signal=nil
                if release then signal="Chapter2ReleaseActive"
                elseif cutscene then signal="CutsceneActive"
                elseif locked and (solved>0 or leverSolved) then
                    signal="NeedleInputLocked during puzzle/lever scene"
                elseif (lastPuzzleCount~=nil and solved>lastPuzzleCount)
                    or (lastLeverSolved==false and leverSolved) then
                    signal="replicated puzzle/lever completion"
                end
                if signal then
                    if release or solved>0 then
                        puzzleBypassUntil=math.max(puzzleBypassUntil,os.clock()+2.0)
                    else
                        leverBypassUntil=math.max(leverBypassUntil,os.clock()+2.0)
                    end
                    if signal~=lastSceneSignal then
                        lastSceneSignal=signal
                        emit("NONFINAL","Main bypass signal: "..signal)
                    end
                end
            end
            lastPuzzleCount=solved
            lastLeverSolved=leverSolved
            finalEndingProtected=endingProtected()
            -- Direct port of Main's single-use, bounded noclip behavior.
            -- Only trigger for the puzzle-release cinematic, never intro or
            -- final ending. It alters collisions locally, not server position.
            local puzzleReleaseWindow=introDone and
                (release or (solved>=3 and
                    (cutscene or os.clock()<puzzleBypassUntil)))
            if puzzleReleaseWindow and not finalEndingProtected
                and not puzzleNoclipUsed then
                local char=player.Character
                local root=char and char:FindFirstChild("HumanoidRootPart")
                if root then beginPuzzleNoclip(root) end
            end
            if puzzleNoclipActive and (finalEndingProtected
                or (not release and not cutscene
                    and os.clock()>=puzzleBypassUntil)) then
                endPuzzleNoclip(finalEndingProtected
                    and "final ending protected" or "puzzle release ended")
            end
            if cutsceneBypassRefresh then
                cutsceneBypassRefresh()
            end
            local nonfinal=introDone and
                (cutscene or release or os.clock()<puzzleBypassUntil
                    or os.clock()<leverBypassUntil)
            if wasNonfinal~=nonfinal then
                emit("STATE","Main cinematic window="..tostring(nonfinal)..
                    " cutscene="..tostring(cutscene)..
                    " release="..tostring(release)..
                    " solved="..tostring(solved))
                wasNonfinal=nonfinal
            end
        end)
        if not ok then
            emit("ERROR",tostring(err))
        end
        if seconds()-lastSaveAt>20 then
            lastSaveAt=seconds()
            save(false)
        end
        task.wait(seconds()<25 and 0.04 or 0.11)
    end
    if alive then stop("8-minute monitoring limit") end
end)
