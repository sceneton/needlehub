-- Beyy Chapter 2 Papers Only v2: start on replicated puzzle readiness; verified haypile return.
-- Compatible with the Beyy Chapter 2 Papers Only v1 factory interface.
-- Returns a factory; the hub supplies movement, remote discovery and status callbacks.
return function(options)
    local api={Running=false,Phase="Ready",Code=nil,Requests=0,Returned=false}
    local alive=true
    local connections={}
    local context,state,feedback=nil,{},{}
    local deadline
    local function status(message)
        api.Phase=message
        if options.Status then pcall(options.Status,message)end
    end
    local function valid(code)return type(code)=="string"and #code==4 and code:match("^%d+$")~=nil end
    local function cleanup()
        for _,connection in ipairs(connections)do connection:Disconnect()end
        table.clear(connections)
    end
    local function guard()
        assert(alive,"Cancelled")
        assert(options.Now()<deadline,"Paper collection timed out")
        assert(not options.Protected(),"Character changed or ending protected")
    end
    local function waitFor(predicate,seconds)
        local untilAt=math.min(deadline,options.Now()+seconds)
        repeat
            guard()
            if predicate()then return true end
            options.Wait(0.05)
        until options.Now()>=untilAt
        guard()
        return predicate()
    end
    local function numberState()return type(state.NumberPuzzle)=="table"and state.NumberPuzzle or {}end
    local function observeCode(code)if valid(code)then api.Code=code end end
    local function requestState()
        guard()
        context.State:FireServer()
    end
    local function send(step,arg)
        guard()
        context.Action:FireServer("NumberPuzzle",step,arg)
        api.Requests+=1
    end
    local function returnHome()
        guard()
        options.ReturnHome(context)
        api.Returned=true
    end
    function api.Stop()
        if not alive then return end
        alive=false;api.Running=false
        cleanup()
        status("Stopped")
    end
    function api.Start()
        if not alive or api.Running then return end
        api.Running=true;deadline=options.Now()+90
        options.Spawn(function()
            local ok,err=pcall(function()
                status("Waiting for character, haypile and Number Puzzle")
                assert(waitFor(function()context=options.Resolve();return context~=nil end,20),"Number Puzzle/haypile unavailable")
                guard()
                connections[#connections+1]=context.State.OnClientEvent:Connect(function(snapshot)
                    if not alive or type(snapshot)~="table"then return end
                    state=snapshot
                    observeCode(numberState().code)
                end)
                if context.Feedback then
                    connections[#connections+1]=context.Feedback.OnClientEvent:Connect(function(puzzle,step,index,correct,code)
                        if not alive or puzzle~="NumberPuzzle"or step~="Poster"then return end
                        if correct==true then feedback[tonumber(index)or index]=true end
                        observeCode(code)
                    end)
                end
                status("Waiting for server Number Puzzle state")
                local nextStateRequest=0
                assert(waitFor(function()
                    if type(state.NumberPuzzle)=="table"then return true end
                    if options.Now()>=nextStateRequest then
                        nextStateRequest=options.Now()+0.5
                        requestState()
                    end
                    return type(state.NumberPuzzle)=="table"
                end,40),"No server puzzle state")
                if numberState().completed~=true then
                    local papers={}
                    status("Waiting for paper targets")
                    assert(waitFor(function()
                        if valid(api.Code)or numberState().completed==true then return true end
                        table.clear(papers)
                        for _,poster in ipairs(context.Posters:GetChildren())do
                            local index=poster:GetAttribute("PosterIndex")
                            if poster:IsA("BasePart")and type(index)=="number"then
                                papers[#papers+1]={Part=poster,Index=index}
                            end
                        end
                        return #papers>0
                    end,10),"Paper targets did not replicate")
                    table.sort(papers,function(a,b)return a.Index<b.Index end)
                    for _,paper in ipairs(papers)do
                        if valid(api.Code)or numberState().completed==true then break end
                        local function taken()
                            local t=numberState().taken
                            return feedback[paper.Index]==true or(type(t)=="table"and(t[paper.Index]==true or t[tostring(paper.Index)]==true))
                        end
                        if paper.Part.Parent and not taken()then
                            status("Collecting paper "..tostring(paper.Index))
                            options.MoveNear(paper.Part,false,context);guard()
                            for attempt=1,3 do
                                if taken()or valid(api.Code)or numberState().completed==true then break end
                                send("Poster",paper.Index)
                                if waitFor(function()return taken()or valid(api.Code)or numberState().completed==true end,0.7)then break end
                                requestState()
                            end
                        end
                    end
                    if not valid(api.Code)and numberState().completed~=true then
                        requestState()
                        assert(waitFor(function()return valid(api.Code)or numberState().completed==true end,2),"Server did not provide a complete four-digit code")
                    end
                    if numberState().completed~=true then
                        status("Code "..api.Code.." found; entering at keypad")
                        options.MoveNear(context.Keypad,true,context);guard()
                        for attempt=1,4 do
                            if numberState().completed==true then break end
                            send("Submit",api.Code)
                            if waitFor(function()return numberState().completed==true end,0.8)then break end
                            requestState()
                        end
                        assert(numberState().completed==true,"Number Puzzle submission was not confirmed")
                    end
                end
                status("Number Puzzle confirmed; returning to haypile")
                returnHome()
                status("Number Puzzle confirmed; returned to haypile"..(api.Code and(" | Code: "..api.Code)or ""))
            end)
            if not ok and alive then
                -- On failure, undo this mode's trip when it is still safe.
                if context and not options.Protected()then
                    local returned=pcall(function()options.ReturnHome(context)end)
                    api.Returned=returned
                end
                status("Failed: "..tostring(err)..(api.Returned and" | Returned to haypile"or ""))
            end
            cleanup();api.Running=false;alive=false
        end)
    end
    return api
end
