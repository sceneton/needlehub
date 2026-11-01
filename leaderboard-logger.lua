-- NeedleHub standalone leaderboard and clan dashboard recorder
local function createLeaderboardCapture(options)
    local api={}
    local specs={
        {Model="TotalWinsLeaderboard",Kind="WINS"},{Model="HayCollectedLeaderboard",Kind="HAY"},
        {Model="GardenLevelLeaderboard",Kind="GARDEN_LEVEL"},{Model="SeedsGrownLeaderboard",Kind="GARDEN_GROWN"},
        {Model="BiggestCropLeaderboard",Kind="GARDEN_BIGGEST"},
    }
    local function number(value)return type(value)=="number"and value==value and math.abs(value)<math.huge end
    local function call(category,action,args,validate)
        local last
        for attempt=1,3 do
            if not options.Alive()then return nil,"Cancelled"end
            local ok,result,fatal=options.Request(category,action,args)
            if ok then
                local valid,err=pcall(validate,result)
                if valid then return result end
                last=tostring(err)
            else last=tostring(result)end
            if fatal then return nil,last,true end
            if attempt<3 and options.Alive()then options.Wait(attempt*2)end
        end
        return nil,last
    end
    function api.Run(config,report)
        local jobs={}
        for _,spec in ipairs(specs)do for _,period in ipairs(config.Periods)do
            jobs[#jobs+1]={Category="StatBoard",Kind=spec.Kind,Model=spec.Model,Period=period,Args={spec.Kind,period}}
        end end
        for _,map in ipairs(config.Maps)do for _,difficulty in ipairs(config.Difficulties)do
            for _,period in ipairs(config.Periods)do for _,mode in ipairs(config.Modes)do
                jobs[#jobs+1]={Category="TimeBoard",Model="TimeRecordLeaderboard",Map=map,Difficulty=difficulty,
                    Period=period,Mode=mode,Args={map,difficulty,period,mode}}
            end end
        end end
        report.PlannedLeaderboardRequests=#jobs
        local function publish()options.Checkpoint(report)end
        local function failed(scope,reason)
            report.Errors[#report.Errors+1]={Scope=scope,Reason=tostring(reason),At=options.Timestamp()}
        end
        local function checkClan(value)
            assert(type(value)=="table"and value.ok==true,tostring(type(value)=="table"and value.reason or "Invalid clan response"))
        end
        -- These are the same read-only actions used by the native Clan menu.
        local state,stateErr=call("Clan","GetState",{},function(r)checkClan(r);assert(type(r.state)=="table","Missing clan state")end)
        local top,topErr=call("Clan","GetTop",{},function(r)
            checkClan(r);assert(type(r.list)=="table","Missing clan rankings")
            local ids={}
            for _,row in ipairs(r.list)do
                assert(type(row)=="table"and row.Id~=nil and number(row.Wins)and number(row.Rank)and row.Rank>0,"Invalid clan ranking")
                assert(not ids[tostring(row.Id)],"Duplicate clan identity");ids[tostring(row.Id)]=true
            end
        end)
        if not options.Alive()then return end
        local allTop={}
        if top then
            for _,row in ipairs(top.list)do allTop[#allTop+1]=row end
            table.sort(allTop,function(a,b)return a.Rank<b.Rank end)
            local rows={};for i=1,math.min(20,#allTop)do rows[#rows+1]=allTop[i]end
            report.TopClans={Status="ok",Period="UNSPECIFIED_BY_SERVER",RequestedCount=20,ReturnedCount=#allTop,
                CapturedCount=#rows,Rows=rows,ObservedAt=options.Timestamp()}
        else report.TopClans={Status="failed",Reason=topErr};failed("TopClans",topErr)end
        if state then
            local data=state.state
            if data.InClan==false then report.MyClan={Status="not_in_clan",ObservedAt=options.Timestamp()}
            elseif data.InClan==true and type(data.Clan)=="table"and type(data.Clan.Members)=="table"then
                local clan=data.Clan;local members={};local sum=0;local ids={};local malformed=false
                for _,member in ipairs(clan.Members)do
                    if type(member)~="table"or member.UserId==nil or not number(member.Wins)or ids[tostring(member.UserId)]then malformed=true;break end
                    ids[tostring(member.UserId)]=true;sum+=member.Wins
                    members[#members+1]={UserId=member.UserId,Name=member.Name,Wins=member.Wins,IsOwner=member.IsOwner,
                        IsAdmin=member.IsAdmin,Tokens=member.Tokens,Hay=member.Hay,JoinedAt=member.JoinedAt}
                end
                table.sort(members,function(a,b)if a.Wins~=b.Wins then return a.Wins>b.Wins end;return tostring(a.UserId)<tostring(b.UserId)end)
                report.MyClan={Status="ok",Id=clan.Id,Name=clan.Name,Tag=clan.Tag,Period="UNSPECIFIED_BY_SERVER",
                    MemberCount=clan.MemberCount,CapturedMemberCount=#members,Members=members,MemberWinsSum=sum,
                    OwnerId=clan.OwnerId,WeekHay=clan.WeekHay,WeekTokens=clan.WeekTokens,WeekChests=clan.WeekChests,
                    WeekEndsIn=data.WeekEndsIn,ObservedAt=options.Timestamp()}
                if malformed or tonumber(clan.MemberCount)~=#members then
                    report.MyClan.Status="partial";failed("MyClan.Members","Missing, duplicate or malformed member rows")
                end
                local official
                for _,row in ipairs(allTop)do if row.Id==clan.Id then official=row;break end end
                local source="ClanRequest.GetTop"
                if not official then
                    local found,findErr=call("Clan","Find",{clan.Name},function(r)checkClan(r);assert(type(r.list)=="table","Missing clan search results")end)
                    if found then for _,row in ipairs(found.list)do if row.Id==clan.Id and number(row.Wins)then official=row;break end end end
                    source="ClanRequest.Find"
                    if not official then failed("MyClan.Wins",findErr or "Clan search did not return the same clan ID");report.MyClan.Status="partial"end
                end
                if official then
                    report.MyClan.Wins=official.Wins;report.MyClan.WinsSource=source
                    report.MyClan.MemberSumMatchesReportedWins=official.Wins==sum
                end
            else report.MyClan={Status="failed",Reason="Incomplete clan state"};failed("MyClan","Incomplete clan state")end
        else report.MyClan={Status="failed",Reason=stateErr};failed("MyClan",stateErr)end
        publish()
        for index,job in ipairs(jobs)do
            if not options.Alive()then return end
            local started=options.Timestamp()
            local response,reason,requestFatal=call(job.Category,"GetBoard",job.Args,function(r)
                assert(type(r)=="table"and type(r.Rows)=="table","Missing board rows")
                assert(r.Period==job.Period,"Response period mismatch")
                if job.Category=="StatBoard"then assert(r.Kind==job.Kind,"Response stat mismatch")
                else assert(r.Map==job.Map and r.Difficulty==job.Difficulty and(r.Mode or "ALL")==job.Mode,"Response time-board filters mismatch")end
                for _,row in ipairs(r.Rows)do
                    assert(type(row)=="table"and number(row.Rank),"Invalid board rank")
                    assert(number(job.Category=="StatBoard"and row.Value or row.Seconds),"Invalid numeric board value")
                end
            end)
            if not options.Alive()then return end
            local entry={Board=job.Model,Category=job.Category,Kind=job.Kind,Map=job.Map,Difficulty=job.Difficulty,
                Period=job.Period,Mode=job.Mode,StartedAt=started,ObservedAt=options.Timestamp()}
            if response then
                entry.Status=#response.Rows>0 and "ok"or "empty";entry.Rows=response.Rows;entry.RowCount=#response.Rows
                -- Keep numeric values, duo identities, crop metadata and any future server row fields intact.
                local metadata={};for key,value in pairs(response)do if key~="Rows"then metadata[key]=value end end
                entry.ServerMetadata=metadata
            else entry.Status="failed";entry.Reason=reason;failed(job.Model..":"..table.concat(job.Args,":"),reason)end
            report.Leaderboards[#report.Leaderboards+1]=entry
            report.CompletedLeaderboardRequests=index
            options.Progress(index,#jobs,entry)
            if requestFatal then
                report.Status="partial";report.FinishedAt=options.Timestamp();publish();return
            end
            if index%5==0 then publish()end
        end
        report.Status=#report.Errors==0 and "complete"or "partial"
        report.FinishedAt=options.Timestamp();publish()
    end
    return api
end

local DASHBOARD_TEMPLATE=[====[<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>NeedleHub · Leaderboards</title>
<style>
:root{color-scheme:dark;--bg:#101419;--panel:#191f27;--line:#2b3542;--muted:#9caabd;--text:#ecf1f7;--accent:#a9e8bc;--gold:#edcb82}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 system-ui,Segoe UI,sans-serif}main{max-width:1680px;margin:auto;padding:32px}h1{font-size:32px;letter-spacing:-1px;margin:6px 0}h2{font-size:19px;margin:0}h3{font-size:16px;margin:0}p{margin:8px 0}.eyebrow{color:var(--accent);font-size:11px;letter-spacing:2px;font-weight:750}.muted,small{color:var(--muted)}.header,.section-title,.card-head,.summary,.toolbar{display:flex;gap:16px;align-items:center;justify-content:space-between}.header{align-items:flex-start;margin-bottom:24px}.summary{justify-content:flex-start;flex-wrap:wrap;margin:20px 0}.metric{background:var(--panel);border:1px solid var(--line);border-radius:12px;min-width:150px;padding:14px 20px}.metric strong{font-size:25px;display:block}.status{font-size:12px;color:var(--accent);background:#20362a;border:1px solid #34553e;padding:6px 12px;border-radius:20px;white-space:nowrap}.status.warn{color:var(--gold);background:#352f22;border-color:#645433}.toolbar{justify-content:flex-start;flex-wrap:wrap;position:sticky;top:0;z-index:2;background:#101419f2;padding:14px 0;border-bottom:1px solid var(--line);margin-bottom:24px;backdrop-filter:blur(12px)}input,select,button{font:inherit;color:var(--text);background:var(--panel);border:1px solid #3a4656;border-radius:8px;padding:9px 12px}input[type=search]{min-width:240px;flex:1}input[type=checkbox]{accent-color:var(--accent)}button{cursor:pointer}button:hover{border-color:var(--accent)}label{white-space:nowrap;color:var(--muted)}.section-title{margin:28px 0 14px}.clans{display:grid;grid-template-columns:1fr 1fr;gap:18px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(365px,1fr));gap:18px}.card{border:1px solid var(--line);border-radius:12px;background:var(--panel);overflow:hidden;min-width:0}.card-head{padding:17px 18px 12px;align-items:flex-start}.card-head small{display:block;margin-top:3px}.table-wrap{overflow:auto;max-height:500px}table{width:100%;border-collapse:collapse;font-size:13px;text-align:left}th{font-size:10px;letter-spacing:1px;text-transform:uppercase;color:var(--muted);font-weight:650;background:#1d2530;position:sticky;top:0}td,th{padding:9px 17px;border-top:1px solid var(--line)}td:first-child,th:first-child{width:42px;color:var(--muted)}td:last-child,th:last-child{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}.name{max-width:240px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.name small{display:block;font-size:11px}.gold td:first-child{color:var(--gold)}.foot{padding:12px 18px;color:var(--muted);font-size:12px;border-top:1px solid var(--line)}.foot button{padding:3px 9px;font-size:12px;float:right}.empty{padding:22px 18px;color:var(--muted)}.error{color:#f2b49e}.details{font-size:12px;color:var(--muted);max-width:900px}.notice{border-left:3px solid var(--gold);background:#25231d;padding:12px 16px;margin:16px 0;border-radius:6px}details{margin:18px 0}summary{cursor:pointer;color:var(--gold)}footer{margin-top:32px;color:var(--muted);font-size:12px}@media(max-width:800px){main{padding:18px}.clans{grid-template-columns:1fr}.grid{grid-template-columns:1fr}.header{display:block}.header .status{display:inline-block;margin-top:12px}.toolbar{position:static}.metric{min-width:130px;flex:1}h1{font-size:27px}}
.clans .table-wrap{max-height:300px}
</style></head><body><main>
<header class="header"><div><div class="eyebrow">NEEDLEHUB · LOCAL RECORDER</div><h1>Every leaderboard. One view.</h1><p class="muted" id="updated"></p></div><span class="status" id="status"></span></header>
<div class="summary" id="metrics"></div>
<div class="toolbar"><input id="search" type="search" placeholder="Search a player or clan…" aria-label="Search player or clan"><select id="period" aria-label="Period"><option value="">All periods</option></select><select id="category" aria-label="Board category"><option value="">All boards</option><option value="StatBoard">Stats only</option><option value="TimeBoard">Time records only</option></select><select id="map" aria-label="Map"><option value="">All maps</option></select><select id="difficulty" aria-label="Difficulty"><option value="">All difficulties</option></select><select id="mode" aria-label="Team mode"><option value="">All team sizes</option></select><label><input id="auto" type="checkbox" checked> Refresh page</label><button id="reload">Refresh now</button></div>
<div id="notice"></div><div class="section-title"><h2>Clans</h2><small>Clan totals keep the server’s original period meaning.</small></div><div class="clans" id="clans"></div>
<div class="section-title"><h2>Leaderboards</h2><small id="boardCount"></small></div><div class="grid" id="boards"></div>
<details id="errors"><summary id="errorSummary"></summary><div id="errorList" class="details"></div></details>
<footer>Local files only · Values are captured sequentially, not at one instant · Empty leaderboards are valid · Page refresh reloads this HTML file; Roblox must keep running the recorder to collect new data.</footer>
</main><script id="data" type="application/json">__LEADERBOARD_PAYLOAD__</script>
<script>
(()=>{'use strict';
const payload=JSON.parse(document.getElementById('data').textContent),report=payload.Capture||{},previous=payload.Previous||{};
const $=id=>document.getElementById(id),format=v=>typeof v==='number'?v.toLocaleString(undefined,{maximumFractionDigits:3}):String(v??'—');
const labels={WINS:'Wins',HAY:'Hay collected',GARDEN_LEVEL:'Garden level',GARDEN_GROWN:'Seeds grown',GARDEN_BIGGEST:'Biggest crop'};
const pretty=v=>String(v||'').replaceAll('_',' ').toLowerCase().replace(/\b\w/g,c=>c.toUpperCase());
const time=v=>{const ms=Math.round(Number(v)*1000),seconds=Math.floor(ms/1000);return `${Math.floor(seconds/3600).toString().padStart(2,'0')}:${Math.floor(seconds%3600/60).toString().padStart(2,'0')}:${(seconds%60).toString().padStart(2,'0')}${ms%1000?'.'+(ms%1000).toString().padStart(3,'0'):''}`};
const node=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n};
const key=b=>[b.Category,b.Kind,b.Map,b.Difficulty,b.Period,b.Mode].join('|');
const merged=new Map((previous.Leaderboards||[]).map(b=>[key(b),{...b,Cached:true}]));for(const b of report.Leaderboards||[])merged.set(key(b),b);
const boards=[...merged.values()];let stored={};try{stored=JSON.parse(localStorage.getItem('needle-leaderboard-view')||'{}')}catch{}
const inputs=['search','period','category','map','difficulty','mode'];
function choices(id,values){for(const value of [...new Set(values.filter(Boolean))]){const o=node('option',pretty(value));o.value=value;$(id).append(o)}}
choices('period',report.Configuration?.Periods||boards.map(b=>b.Period));choices('map',report.Configuration?.Maps||boards.map(b=>b.Map));choices('difficulty',report.Configuration?.Difficulties||boards.map(b=>b.Difficulty));choices('mode',report.Configuration?.Modes||boards.map(b=>b.Mode));
for(const id of inputs)if(typeof stored[id]==='string')$(id).value=stored[id];if(typeof stored.auto==='boolean')$('auto').checked=stored.auto;
const expanded=new Set(stored.expanded||[]);
function remember(){const state={auto:$('auto').checked,scroll:window.scrollY,expanded:[...expanded]};for(const id of inputs)state[id]=$(id).value;try{localStorage.setItem('needle-leaderboard-view',JSON.stringify(state))}catch{}}
const statusText=report.RecorderStopped?'Recorder stopped':report.Status==='running'?'Capturing':report.Status==='complete'?'Capture complete':pretty(report.Status||'Waiting');$('status').textContent=statusText;if(report.Status!=='complete')$('status').classList.add('warn');
$('updated').textContent=`Started ${report.StartedAt||'—'}${report.FinishedAt?' · Finished '+report.FinishedAt:''} · This page was saved ${payload.SavedAt||'—'}`;
function metric(value,title){const box=node('div',undefined,'metric');box.append(node('strong',value),node('span',title,'muted'));$('metrics').append(box)}
metric(`${report.CompletedLeaderboardRequests||0} / ${report.PlannedLeaderboardRequests||'—'}`,'Board combinations captured');metric(format(boards.reduce((n,b)=>n+(b.Rows?.length||0),0)),'Ranking rows available');metric(format((report.Errors||[]).length),'Capture errors');metric(payload.NextCaptureAt?new Date(payload.NextCaptureAt*1000).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'}):report.Status==='running'?'In progress':'Stopped','Next capture');
if(report.Status==='running')$('notice').append(node('div','Collection is in progress. Boards marked “previous capture” remain visible until their new results arrive. Requests are paced to avoid rapid retries.','notice'));
if(payload.RefreshSeconds===0&&report.Status!=='running')$('notice').append(node('div','This was a one-off capture. Run the script again for new data.','notice'));
function table(headers,rows){const table=node('table'),head=node('thead'),tr=node('tr');for(const h of headers)tr.append(node('th',h));head.append(tr);table.append(head);const body=node('tbody');for(const row of rows){const tr=node('tr');if(row[0]===1)tr.className='gold';for(let i=0;i<row.length;i++){const td=node('td');if(row[i] instanceof Node)td.append(row[i]);else td.textContent=format(row[i]);tr.append(td)}body.append(tr)}table.append(body);const wrap=node('div',undefined,'table-wrap');wrap.append(table);return wrap}
function nameCell(primary,secondary){const n=node('div',primary,'name');if(secondary)n.append(node('small',secondary));return n}
function card(title,subtitle){const c=node('article',undefined,'card'),head=node('div',undefined,'card-head'),text=node('div');text.append(node('h3',title),node('small',subtitle));head.append(text);c.append(head);return c}
function matches(row,q){return !q||JSON.stringify(row).toLowerCase().includes(q)}
function renderClans(q){$('clans').replaceChildren();const clan=report.MyClan||previous.MyClan||{},top=report.TopClans||previous.TopClans||{};
const mine=card(clan.Name?`${clan.Tag?'['+clan.Tag+'] ':''}${clan.Name}`:'Your clan',clan.Status==='not_in_clan'?'You are not in a clan.':`Reported wins: ${format(clan.Wins)} · Member wins sum: ${format(clan.MemberWinsSum)} · ${clan.CapturedMemberCount||0} members`);
if(clan.Status==='failed')mine.append(node('div',clan.Reason||'Clan capture failed.','empty error'));else if(clan.Members?.length){const rows=clan.Members.filter(r=>matches(r,q)).map((r,i)=>[i+1,nameCell(r.Name,r.IsOwner?'Owner':r.IsAdmin?'Admin':'Member'),r.Wins]);mine.append(table(['#','Member','Wins'],rows));if(clan.MemberSumMatchesReportedWins===false)mine.append(node('div','The reported total and member sum differ; the requests were taken at different moments.','foot'))}else mine.append(node('div','No member rows available.','empty'));
const ranking=card('Top 20 clans',`${top.CapturedCount||0} captured · Server ranking order`);if(top.Rows?.length)ranking.append(table(['Rank','Clan','Wins'],top.Rows.filter(r=>matches(r,q)).map(r=>[r.Rank,nameCell(`${r.Tag?'['+r.Tag+'] ':''}${r.Name}`,`${r.MemberCount??'—'} members`),r.Wins])));else ranking.append(node('div',top.Reason||'Waiting for clan rankings…','empty'));$('clans').append(mine,ranking)}
function render(){const q=$('search').value.trim().toLowerCase();renderClans(q);$('boards').replaceChildren();const selected=boards.filter(b=>(!$('period').value||b.Period===$('period').value)&&(!$('category').value||b.Category===$('category').value)&&(!$('map').value||b.Map===$('map').value)&&(!$('difficulty').value||b.Difficulty===$('difficulty').value)&&(!$('mode').value||b.Mode===$('mode').value));let shown=0;
for(const b of selected){const rows=(b.Rows||[]).filter(r=>matches(r,q));if(q&&!rows.length)continue;shown++;const title=b.Category==='TimeBoard'?`${pretty(b.Map)} · ${pretty(b.Difficulty)} · ${pretty(b.Mode)}`:labels[b.Kind]||b.Board;const c=card(title,`${pretty(b.Period)} · ${b.Cached?'Previous capture · ':''}${b.ObservedAt||''}`);
if(b.Status==='failed')c.append(node('div',b.Reason||'Request failed.','empty error'));else if(!rows.length)c.append(node('div','No records returned for this combination.','empty'));else{const visible=expanded.has(key(b))?rows:rows.slice(0,10);c.append(table(['Rank','Player',b.Category==='TimeBoard'?'Time':b.Kind==='GARDEN_BIGGEST'?'Weight':'Value'],visible.map(r=>{let value=r.Value;if(b.Category==='TimeBoard')value=time(r.Seconds);else if(b.Kind==='GARDEN_BIGGEST')value=format(value)+' kg';const names=r.Username||r.Name||(r.UserId?'User '+r.UserId:JSON.stringify(r.UserIds||r));const partner=r.PartnerUsername||r.PartnerName||r.Username2;return[r.Rank,nameCell(names,partner?'with '+partner:''),value]})));
const foot=node('div',`${rows.length} row${rows.length===1?'':'s'}${q?' matching search':''}`,'foot');if(rows.length>10){const button=node('button',expanded.has(key(b))?'Show top 10':'Show all '+rows.length);button.onclick=()=>{expanded.has(key(b))?expanded.delete(key(b)):expanded.add(key(b));remember();render()};foot.append(button)}c.append(foot)}$('boards').append(c)}
$('boardCount').textContent=`${shown} board combinations shown`;if(!shown)$('boards').append(node('div',report.Status==='running'?'Waiting for leaderboard responses…':'No boards match these filters.','empty'));remember()}
for(const id of inputs)$(id).addEventListener(id==='search'?'input':'change',render);$('auto').addEventListener('change',remember);$('reload').onclick=()=>{remember();location.reload()};window.addEventListener('beforeunload',remember);
const errors=report.Errors||[];$('errors').hidden=!errors.length;$('errorSummary').textContent=`${errors.length} capture error${errors.length===1?'':'s'}`;for(const e of errors)$('errorList').append(node('p',`${e.Scope}: ${e.Reason}`));
render();if(stored.scroll)requestAnimationFrame(()=>window.scrollTo(0,stored.scroll));setInterval(()=>{if($('auto').checked&&!document.hidden){remember();location.reload()}},15000);
})();
</script></body></html>
]====]
-- Standalone local leaderboard + clan recorder with an offline HTML dashboard.
-- Only verified native GetBoard, GetState, GetTop and Find read requests are used.
local SETTINGS={RequestSpacing=1.25,RequestTimeout=120,RefreshSeconds=300,Folder="BeyyHub"}
if game.PlaceId~=77108422251420 then warn("[Leaderboard Logger] Run this script in the lobby.");return end
local Http=game:GetService("HttpService")
local Storage=game:GetService("ReplicatedStorage")
local player=game:GetService("Players").LocalPlayer
if not player or type(writefile)~="function"then warn("[Leaderboard Logger] Requires a loaded player and writefile support.");return end
pcall(function()if type(makefolder)=="function"then makefolder(SETTINGS.Folder)end end)
local env=type(getgenv)=="function"and getgenv()or _G
local old=env.BeyyLeaderboardLogger
local inheritedReport=type(old)=="table"and old.Report or nil
local inheritedPending=type(old)=="table"and old.Pending or nil
if type(old)=="table"and type(old.Stop)=="function"then pcall(old.Stop)end
local run={Running=true,Capturing=false,RequestCount=0,HtmlPath=SETTINGS.Folder.."/leaderboards.html"}
env.BeyyLeaderboardLogger=run
local report,previous,inFlight=nil,inheritedReport,inheritedPending
local function alive()return run.Running and env.BeyyLeaderboardLogger==run and game.PlaceId==77108422251420 end
local function timestamp()return os.date("!%Y-%m-%dT%H:%M:%SZ")end
local function wait(seconds)
    local deadline=os.clock()+seconds
    while alive()and os.clock()<deadline do task.wait(math.max(0,math.min(0.1,deadline-os.clock())))end
end
local function save()
    if not report or env.BeyyLeaderboardLogger~=run then return false end
    report.RequestCount=run.RequestCount
    local ok,json=pcall(Http.JSONEncode,Http,report)
    if not ok then warn("[Leaderboard Logger] JSON export failed: "..tostring(json));return false end
    local written,err=pcall(writefile,run.Path,json)
    if not written then warn("[Leaderboard Logger] File save failed: "..tostring(err));return false end
    pcall(writefile,SETTINGS.Folder.."/leaderboards_last_attempt.json",json)
    if report.Status=="complete"then pcall(writefile,SETTINGS.Folder.."/leaderboards_latest.json",json)end
    local htmlOK,htmlError=pcall(function()
        local data=Http:JSONEncode({Capture=report,Previous=previous,SavedAt=timestamp(),
            RefreshSeconds=SETTINGS.RefreshSeconds,NextCaptureAt=run.NextCaptureAt,RecorderRunning=run.Running})
        -- Prevent server-provided names from closing the inert JSON script element.
        data=data:gsub("&","\\u0026"):gsub("<","\\u003c"):gsub(">","\\u003e")
        local html=DASHBOARD_TEMPLATE:gsub("__LEADERBOARD_PAYLOAD__",function()return data end,1)
        writefile(run.HtmlPath,html)
    end)
    if not htmlOK then warn("[Leaderboard Logger] HTML save failed: "..tostring(htmlError));return false end
    return true
end
local teleportConnection
function run.Stop()
    if not run.Running then return end
    run.Running=false;run.NextCaptureAt=nil
    if report then
        if run.Capturing then report.Status="cancelled";report.FinishedAt=timestamp()end
        report.RecorderStopped=true;save()
    end
    if teleportConnection then teleportConnection:Disconnect();teleportConnection=nil end
end
function run.Refresh()
    if run.Running and not run.Capturing then run.NextCaptureAt=0;return true end
    return false
end
function run.Copy()
    if not report or type(setclipboard)~="function"then return false end
    return pcall(function()setclipboard(Http:JSONEncode(report))end)
end
teleportConnection=player.OnTeleport:Connect(function(state)if state==Enum.TeleportState.Started then run.Stop()end end)
local nextRequest,fatal=0,false
local function request(category,action,args)
    if fatal then return false,"A request timed out; no more requests will be sent in this capture",true end
    if inFlight and not inFlight.Done then
        local untilAt=os.clock()+SETTINGS.RequestTimeout
        while alive()and not inFlight.Done and os.clock()<untilAt do task.wait(0.05)end
        if not inFlight.Done then fatal=true;return false,"A previous read request is still pending",true end
    end
    wait(math.max(0,nextRequest-os.clock()))
    if not alive()then return false,"Cancelled",true end
    local remote
    if category=="Clan"then
        local folder=Storage:FindFirstChild("ClanSystem");remote=folder and folder:FindFirstChild("ClanRequest")
    else
        local packages=Storage:FindFirstChild("Packages");local networker=packages and packages:FindFirstChild("Networker")
        local remotes=networker and networker:FindFirstChild("_remotes")
        local folder=remotes and remotes:FindFirstChild(category);remote=folder and folder:FindFirstChild("RemoteFunction")
    end
    if not remote or not remote:IsA("RemoteFunction")then return false,"Missing "..category.." read remote"end
    run.RequestCount+=1
    local job={Done=false,Category=category,Action=action,StartedAt=timestamp()};inFlight=job;run.Pending=job
    task.spawn(function()job.OK,job.Value=pcall(remote.InvokeServer,remote,action,table.unpack(args));job.Done=true end)
    local deadline=os.clock()+SETTINGS.RequestTimeout
    while alive()and not job.Done and os.clock()<deadline do task.wait(0.05)end
    nextRequest=os.clock()+SETTINGS.RequestSpacing
    if not alive()then return false,"Cancelled",true end
    if not job.Done then fatal=true;return false,category.." read timed out; request queue halted",true end
    return job.OK,job.Value
end
local function configuration()
    local shared=Storage:WaitForChild("Shared",15);assert(shared,"Shared configuration has not loaded")
    local configs=shared:WaitForChild("Configs",15);assert(configs,"Shared configuration has not loaded")
    local weeklyModule=configs:WaitForChild("WeeklyPeriod",15);local timeModule=configs:WaitForChild("TimeRecords",15)
    assert(weeklyModule and timeModule,"Leaderboard configuration is unavailable")
    local weekly=require(weeklyModule);local times=require(timeModule)
    local config={Periods=weekly.Periods,Maps=times.Maps,Difficulties=times.Difficulties,Modes=times.Modes}
    for _,key in ipairs({"Periods","Maps","Difficulties","Modes"})do
        assert(type(config[key])=="table"and #config[key]>0,"Invalid leaderboard configuration: "..key)
        for _,value in ipairs(config[key])do assert(type(value)=="string","Invalid leaderboard filter")end
    end
    return config
end
task.spawn(function()
    print("[Leaderboard Logger] Dashboard: "..run.HtmlPath.." | Collecting all filters; requests are paced and may take several minutes.")
    while alive()do
        local id=os.date("!%Y%m%d_%H%M%S").."_"..Http:GenerateGUID(false):sub(1,8)
        report={Schema=1,CaptureId=id,Status="running",PlaceId=game.PlaceId,StartedAt=timestamp(),Leaderboards={},Errors={},
            Interpretation="Native server responses captured sequentially, not an atomic snapshot. Empty boards are valid. Clan wins have no period label in the server response. MemberWinsSum is distinct from the clan's reported Wins."}
        run.Report=report;run.Path=SETTINGS.Folder.."/leaderboards_"..id..".json"
        run.RequestCount=0;run.Capturing=true;run.NextCaptureAt=nil;fatal=false
        save()
        local ok,err=pcall(function()
            local config=configuration();report.Configuration=config
            local boards=workspace:FindFirstChild("Leaderboards");local discovered,unknown={},{}
            local known={TotalWinsLeaderboard=true,HayCollectedLeaderboard=true,GardenLevelLeaderboard=true,
                SeedsGrownLeaderboard=true,BiggestCropLeaderboard=true,TimeRecordLeaderboard=true}
            if boards then for _,obj in ipairs(boards:GetChildren())do if obj:IsA("Model")and obj.Name:find("Leaderboard",1,true)then
                discovered[#discovered+1]=obj.Name;if not known[obj.Name]then unknown[#unknown+1]=obj.Name end
            end end end
            report.DiscoveredBoards=discovered;report.UnsupportedBoards=unknown
            for _,name in ipairs(unknown)do report.Errors[#report.Errors+1]={Scope=name,Reason="Unknown board type; request mapping needs an update"}end
            local capture=createLeaderboardCapture({Alive=alive,Request=request,Wait=wait,Timestamp=timestamp,Checkpoint=save,
                Progress=function(index,total,entry)
                    if index==1 or index%10==0 or index==total or entry.Status=="failed"then
                        print(string.format("[Leaderboard Logger] %d/%d | %s | %s",index,total,entry.Board,entry.Status))
                    end
                end})
            capture.Run(config,report)
        end)
        if not alive()then break end
        if not ok then report.Status="failed";report.Errors[#report.Errors+1]={Scope="Capture",Reason=tostring(err)}end
        report.FinishedAt=report.FinishedAt or timestamp();run.Capturing=false
        if SETTINGS.RefreshSeconds>0 then run.NextCaptureAt=os.time()+SETTINGS.RefreshSeconds end
        local written=save()
        print("[Leaderboard Logger] "..report.Status.." | "..#report.Leaderboards.." boards | "..#report.Errors.." errors | "..(written and run.HtmlPath or "SAVE FAILED"))
        -- Preserve the most recent full capture for display while the next one loads.
        if report.Status=="complete"then previous=report end
        if SETTINGS.RefreshSeconds<=0 then run.Running=false;break end
        while alive()and os.time()<(run.NextCaptureAt or 0)do task.wait(0.25)end
    end
    if teleportConnection then teleportConnection:Disconnect();teleportConnection=nil end
end)
