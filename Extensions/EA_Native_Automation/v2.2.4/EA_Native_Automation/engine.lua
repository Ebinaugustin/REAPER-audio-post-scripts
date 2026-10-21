-- @description EA Native Automation - internal headless engine
-- @version 2.2.4
-- @author Ebin Augustin / Codex
-- @about Headless automation engine for the JUCE/C++ REAPER extension.
local R = reaper
local APP, TITLE = 'EA_Compact_Automation', 'Automation'
local E = { enabled = {}, scope = 'all', onstop = {}, gates = {}, preview = false,
  capture = nil, clipboard = nil, join = false, punch = nil, touched = {}, use_items = false,
  message = 'Right-click for options', message_until = 0, lastplay = 0, lastpos = 0 }
local GROUPS = {'plugin','vol','svol','pan','span','mute','smute'}
for _, k in ipairs(GROUPS) do E.enabled[k] = true end
local function valid(p, typ, proj) return p and R.ValidatePtr2(proj or 0, p, typ) end
local function notify(s) E.message, E.message_until = s, R.time_precise() + 5 end
local function chunk(env)
  local ok, text = R.GetEnvelopeStateChunk(env, '', false)
  if not ok then error('Cannot read envelope state') end
  return text
end
local function armed(env)
  local ok,state=R.GetSetEnvelopeInfo_String(env,'ARM','',false)
  if ok and (state=='0' or state=='1') then return state=='1' end
  return chunk(env):match('\nARM%s+(%d+)') == '1'
end
local function arm(env, state)
  local ok = R.GetSetEnvelopeInfo_String(env,'ARM',state and '1' or '0',true)
  if ok then return end
  local text = chunk(env)
  local nexttext, n = text:gsub('(\nARM%s+)%d+', '%1'..(state and '1' or '0'), 1)
  if n == 0 then nexttext = text:gsub('\n', '\nARM '..(state and '1' or '0')..'\n', 1) end
  if nexttext ~= text and not R.SetEnvelopeStateChunk(env, nexttext, false) then
    error('Cannot change envelope write-enable')
  end
end
local function envguid(env)
  local _, guid = R.GetSetEnvelopeInfo_String(env, 'GUID', '', false)
  return guid
end
local function tracks(selected)
  local out = {}
  if selected then
    for i = 0, R.CountSelectedTracks2(0, true)-1 do out[#out+1] = R.GetSelectedTrack2(0,i,true) end
  else
    out[1] = R.GetMasterTrack(0)
    for i = 0, R.CountTracks(0)-1 do out[#out+1] = R.GetTrack(0,i) end
  end
  return out
end
local function target_tracks() return tracks(E.scope == 'selected') end
local preserve_envelope_views -- also protects native side effects when entering/exiting Preview
local function fx_identity(tr, fx)
  local ok, id = R.TrackFX_GetNamedConfigParm(tr,fx,'fx_ident')
  if not ok or id == '' then local unused; unused, id = R.TrackFX_GetFXName(tr,fx,'') end
  return id
end
local function is_surround_fx(tr,fx)
  local _,display=R.TrackFX_GetFXName(tr,fx,'')
  local _,original=R.TrackFX_GetNamedConfigParm(tr,fx,'original_name')
  local identity=(fx_identity(tr,fx)..' '..(display or '')..' '..(original or '')):lower():gsub('[%s_%-]','')
  return identity:find('reasurround',1,true)~=nil
end
-- Descriptor matching uses native envelope identity, FX identity/instance/parameter,
-- and send destination identity. Localized display names are never native keys.
local function descriptor(tr, env)
  local _, fx, param = R.Envelope_GetParentTrack(env)
  local text = chunk(env)
  local tag = text:match('^%s*<([%w_]+)') or ''
  local _, name = R.GetEnvelopeName(env, '')
  local d = {tag=tag, name=name, guid=envguid(env), trguid=R.GetTrackGUID(tr)}
  local send, hw = R.GetEnvelopeInfo_Value(env,'I_SEND_IDX'), R.GetEnvelopeInfo_Value(env,'I_HWOUT_IDX')
  if send > 0 or hw > 0 then
    d.kind, d.cat, d.send = 'send', hw > 0 and 1 or 0, (hw > 0 and hw or send)-1
    d.group = tag:find('VOL') and 'svol' or tag:find('PAN') and 'span' or 'smute'
    local dest = R.GetTrackSendInfo_Value(tr,d.cat,d.send,'P_DESTTRACK')
    d.destguid = dest and d.cat == 0 and R.GetTrackGUID(dest) or ''
    d.channel = R.GetTrackSendInfo_Value(tr,d.cat,d.send,'I_DSTCHAN')
    d.sourcechannel = R.GetTrackSendInfo_Value(tr,d.cat,d.send,'I_SRCCHAN')
    d.ordinal = 1
    for i=0,d.send-1 do
      local other = R.GetTrackSendInfo_Value(tr,d.cat,i,'P_DESTTRACK')
      local match = d.cat == 1 or (other and R.GetTrackGUID(other) == d.destguid)
      if match and R.GetTrackSendInfo_Value(tr,d.cat,i,'I_DSTCHAN') == d.channel
        and R.GetTrackSendInfo_Value(tr,d.cat,i,'I_SRCCHAN') == d.sourcechannel then d.ordinal = d.ordinal+1 end
    end
  elseif fx and fx >= 0 then
    d.kind, d.fx, d.param, d.group = 'fx', fx, param, 'plugin'
    d.fxguid, d.fxid = R.TrackFX_GetFXGUID(tr,fx), fx_identity(tr,fx)
    local _, pname = R.TrackFX_GetParamName(tr,fx,param,'')
    d.pname = pname
    local identok, ident = R.TrackFX_GetParamIdent(tr,fx,param,'')
    d.pident = identok and ident or ''
    d.surround = is_surround_fx(tr,fx)
    if d.surround then d.group = 'pan' end
    d.ordinal = 1
    -- For containers, GUID matching always works on the same track. Cross-track
    -- fallback is resolved by walking the destination FX tree below.
    d.ordinal = 0
    local function walk_fx(base, indices)
      for _, index in ipairs(indices) do
        if fx_identity(tr,index) == d.fxid then d.ordinal = d.ordinal+1 end
        if index == fx then return true end
        local ok, count = R.TrackFX_GetNamedConfigParm(tr,index,'container_count')
        if ok then
          local children = {}
          for c=0,tonumber(count)-1 do
            local yes, child = R.TrackFX_GetNamedConfigParm(tr,index,'container_item.'..c)
            if yes then children[#children+1] = tonumber(child) end
          end
          if walk_fx(base,children) then return true end
        end
      end
    end
    local indices = {}
    for i=0,R.TrackFX_GetCount(tr)-1 do indices[#indices+1]=i end
    for i=0,R.TrackFX_GetRecCount(tr)-1 do indices[#indices+1]=0x1000000+i end
    walk_fx(0,indices)
  else
    d.kind = 'native'
    d.group = tag:find('VOL') and 'vol' or (tag:find('PAN') or tag:find('WIDTH')) and 'pan'
      or tag:find('MUTE') and 'mute' or 'plugin'
  end
  return d
end
local descriptor_cache={}
local function envelopes(tracklist)
  local out = {}
  for _, tr in ipairs(tracklist) do
    for i=0,R.CountTrackEnvelopes(tr)-1 do
      local env = R.GetTrackEnvelope(tr,i)
      local guid=envguid(env)
      local cached=descriptor_cache[env]
      local _,fx,param=R.Envelope_GetParentTrack(env)
      if not cached or cached.tr~=tr or cached.d.guid~=guid or cached.fx~=fx or cached.param~=param
        or R.time_precise()-cached.at>2 then
        cached={tr=tr,d=descriptor(tr,env),fx=fx,param=param,at=R.time_precise()};descriptor_cache[env]=cached
      end
      out[#out+1] = {env=env,tr=tr,d=cached.d}
    end
  end
  return out
end
local function evaluate(env,t)
  local _, value = R.Envelope_Evaluate(env,math.max(0,t),48000,1)
  return value
end
local function send_ui_index(tr,d)
  -- UI APIs put hardware outputs before normal sends, unlike category APIs.
  return d.send+(d.cat==0 and R.GetTrackNumSends(tr,1) or 0)
end
local function live_value(h,t)
  local d,tr = h.d,h.tr
  local value
  local tag=d.tag:gsub('^MASTER','')
  if d.kind == 'fx' then value = R.TrackFX_GetParam(tr,d.fx,d.param)
  elseif d.kind == 'send' then
    local key = d.group == 'svol' and 'D_VOL' or d.group == 'span' and 'D_PAN' or 'B_MUTE'
    if d.group=='smute' and R.GetTrackSendUIMute then
      local ok,mute=R.GetTrackSendUIMute(tr,send_ui_index(tr,d));if ok then value=mute and 0 or 1 end
    elseif R.GetTrackSendUIVolPan then
      local ok,vol,pan=R.GetTrackSendUIVolPan(tr,send_ui_index(tr,d))
      if ok then value=d.group=='svol' and vol or -pan end
    end
    if value==nil then
      value=R.GetTrackSendInfo_Value(tr,d.cat,d.send,key)
      if d.group=='smute' then value=value==1 and 0 or 1 elseif d.group=='span' then value=-value end
    end
  elseif tag=='VOLENV2' or tag=='PANENV2' then
    -- D_VOL/D_PAN can be the stored trim rather than the latch-preview value.
    if R.GetTrackUIVolPan then
      local ok,vol,pan=R.GetTrackUIVolPan(tr);if ok then value=tag=='VOLENV2' and vol or -pan end
    end
    if value==nil then value=R.GetMediaTrackInfo_Value(tr,tag=='VOLENV2' and 'D_VOL' or 'D_PAN');if tag=='PANENV2' then value=-value end end
  elseif tag=='WIDTHENV2' or tag=='DUALPANENVL2' or tag=='DUALPANENV2' then
    if R.GetTrackUIPan then
      local ok,pan1,pan2,mode=R.GetTrackUIPan(tr)
      if ok and (tag=='WIDTHENV2' and mode==5 or tag~='WIDTHENV2' and mode==6) then
        local ui=tag=='DUALPANENVL2' and pan1 or pan2
        if type(ui)=='number' then value=tag=='WIDTHENV2' and ui or -ui end
      end
    end
    if value==nil then
      value=R.GetMediaTrackInfo_Value(tr,tag=='WIDTHENV2' and 'D_WIDTH' or tag=='DUALPANENVL2' and 'D_DUALPANL' or 'D_DUALPANR')
      if tag~='WIDTHENV2' then value=-value end
    end
  elseif tag=='MUTEENV' then
    if R.GetTrackUIMute then local ok,mute=R.GetTrackUIMute(tr);if ok then value=mute and 0 or 1 end end
    if value==nil then value=R.GetMediaTrackInfo_Value(tr,'B_MUTE')==1 and 0 or 1 end
  end
  if value == nil then return evaluate(h.env,t) end
  return R.ScaleToEnvelopeMode(R.GetEnvelopeScalingMode(h.env),value)
end
local function set_live(h,raw)
  local d,tr = h.d,h.tr
  local tag=d.tag:gsub('^MASTER','')
  local v = R.ScaleFromEnvelopeMode(R.GetEnvelopeScalingMode(h.env),raw)
  if d.kind == 'fx' then R.TrackFX_SetParam(tr,d.fx,d.param,v)
  elseif d.kind == 'send' then
    if d.group=='span' then
      v=-v
      if R.SetTrackSendUIPan then R.SetTrackSendUIPan(tr,send_ui_index(tr,d),v,-1);return end
    elseif d.group=='svol' and R.SetTrackSendUIVol then R.SetTrackSendUIVol(tr,send_ui_index(tr,d),v,-1);return
    elseif d.group=='smute' then v=v<0.5 and 1 or 0 end
    R.SetTrackSendInfo_Value(tr,d.cat,d.send,d.group == 'svol' and 'D_VOL' or d.group == 'span' and 'D_PAN' or 'B_MUTE',v)
  elseif tag=='VOLENV2' then
    if R.SetTrackUIVolume then R.SetTrackUIVolume(tr,v,false,true,3) else R.SetMediaTrackInfo_Value(tr,'D_VOL',v) end
  elseif tag=='PANENV2' or tag=='DUALPANENVL2' then
    if R.SetTrackUIPan then R.SetTrackUIPan(tr,-v,false,true,3) else R.SetMediaTrackInfo_Value(tr,tag=='PANENV2' and 'D_PAN' or 'D_DUALPANL',-v) end
  elseif tag=='WIDTHENV2' or tag=='DUALPANENV2' then
    if R.SetTrackUIWidth then R.SetTrackUIWidth(tr,tag=='WIDTHENV2' and v or -v,false,true,3)
    else R.SetMediaTrackInfo_Value(tr,tag=='WIDTHENV2' and 'D_WIDTH' or 'D_DUALPANR',tag=='WIDTHENV2' and v or -v) end
  elseif tag=='MUTEENV' then
    if R.SetTrackUIMute then R.SetTrackUIMute(tr,v<0.5 and 1 or 0,3) else R.SetMediaTrackInfo_Value(tr,'B_MUTE',v<0.5 and 1 or 0) end
  end
end
local function undo(label,fn)
  R.Undo_BeginBlock2(0); R.PreventUIRefresh(1)
  local ok,result = xpcall(fn,debug.traceback)
  R.PreventUIRefresh(-1); R.Undo_EndBlock2(0,label,-1)
  if R.TrackList_AdjustWindows then R.TrackList_AdjustWindows(false) end
  R.UpdateArrange()
  if not ok then error(result,0) end
  return result
end
local function restore_gates()
  for env, entry in pairs(E.gates) do
    if valid(env,'TrackEnvelope*',entry.project) and envguid(env) == entry.guid then arm(env,entry.armed) end
  end
  E.gates = {}
end
local function activity(env)
  local ok,value=R.GetSetEnvelopeInfo_String(env,'ACTIVE','',false)
  if ok and (value=='0' or value=='1') then return tonumber(value) end
  return tonumber(chunk(env):match('\nACT%s+(%d+)'))
end
local function set_activity(env,on)
  if R.GetSetEnvelopeInfo_String(env,'ACTIVE',on and '1' or '0',true) then return end
  local text=chunk(env)
  local changed,n=text:gsub('(\nACT%s+)(%d+)',function(prefix,value)
    local flags=tonumber(value)
    return prefix..tostring((flags & ~1) | (on and 1 or 0))
  end,1)
  if n>0 and changed~=text and not R.SetEnvelopeStateChunk(env,changed,false) then error('Cannot change envelope bypass state') end
end
local function suspend_envelopes()
  local list={}
  for _,tr in ipairs(tracks(false)) do
    for i=0,R.CountTrackEnvelopes(tr)-1 do list[#list+1]=R.GetTrackEnvelope(tr,i) end
  end
  -- REAPER take envelopes have their own activation state; global track bypass
  -- alone does not cover them. Include all takes when the host provides the APIs.
  if R.CountMediaItems and R.GetMediaItem and R.CountTakes and R.GetTake and R.CountTakeEnvelopes and R.GetTakeEnvelope then
    for i=0,R.CountMediaItems(0)-1 do
      local item=R.GetMediaItem(0,i)
      for t=0,R.CountTakes(item)-1 do
        local take=R.GetTake(item,t)
        for e=0,R.CountTakeEnvelopes(take)-1 do list[#list+1]=R.GetTakeEnvelope(take,e) end
      end
    end
  end
  return list
end
local function restore_suspended()
  for env,entry in pairs(E.suspended_envelopes or {}) do
    if valid(env,'TrackEnvelope*',entry.project) and envguid(env)==entry.guid then set_activity(env,entry.active) end
  end
  E.suspended_envelopes={}
end
function E.enforce()
  local seen = {}
  local proj = R.EnumProjects(-1,'')
  for _, h in ipairs(envelopes(target_tracks())) do
    if not E.enabled[h.d.group] then
      seen[h.env] = true
      if not E.gates[h.env] then E.gates[h.env] = {armed=armed(h.env),guid=h.d.guid,project=proj} end
      if armed(h.env) then arm(h.env,false) end
    end
  end
  for env, entry in pairs(E.gates) do
    if not seen[env] then
      if valid(env,'TrackEnvelope*',entry.project) and envguid(env)==entry.guid then arm(env,entry.armed) end
      E.gates[env] = nil
    end
  end
  if E.suspended_override~=nil then
    R.SetGlobalAutomationOverride(5) -- Global bypass also protects newly created track automation.
    E.suspended_envelopes=E.suspended_envelopes or {}
    for _,env in ipairs(suspend_envelopes()) do
      local flags=activity(env)
      if flags then
        if not E.suspended_envelopes[env] then E.suspended_envelopes[env]={active=(flags & 1)~=0,guid=envguid(env),project=proj} end
        if (flags & 1)~=0 then set_activity(env,false) end
      end
    end
  end
  -- When any class is protected, prevent a newly auto-created envelope from
  -- writing a point before our next frame. Existing enabled envelopes still work.
  if R.SNM_GetIntConfigVar and R.SNM_SetIntConfigVar then
    local blocked = E.suspended_override~=nil
    for _, k in ipairs(GROUPS) do if not E.enabled[k] then blocked=true end end
    if blocked then
      if E.autoadd_saved == nil then E.autoadd_saved=R.SNM_GetIntConfigVar('env_autoadd',0) end
      local current=R.SNM_GetIntConfigVar('env_autoadd',0)
      R.SNM_SetIntConfigVar('env_autoadd',current & ~1)
    elseif E.autoadd_saved ~= nil then
      local current=R.SNM_GetIntConfigVar('env_autoadd',0)
      R.SNM_SetIntConfigVar('env_autoadd',(current & ~1) | (E.autoadd_saved & 1)); E.autoadd_saved=nil
    end
  end
end
function E.toggle_group(k)
  E.enabled[k]=not E.enabled[k]
  E.enforce()
  notify(k:upper()..(E.enabled[k] and ' write enabled' or ' write protected'))
end
function E.suspend()
  if E.suspended_override ~= nil then
    restore_suspended()
    R.SetGlobalAutomationOverride(E.suspended_override); E.suspended_override=nil;E.enforce()
    notify('Automation resumed')
  else
    E.end_punch()
    if E.preview then E.preview_toggle() end
    E.suspended_override=R.GetGlobalAutomationOverride();E.suspended_envelopes={};E.enforce()
    notify('All envelopes bypassed; automation writing suspended')
  end
  if R.TrackList_AdjustWindows then R.TrackList_AdjustWindows(false) end
  R.UpdateArrange()
end
local function snapshot(all,source_tracks,include_unarmed,require_latches)
  local out, active = {}, {}
  local t = (R.GetPlayState() & 1) ~= 0 and R.GetPlayPosition() or R.GetCursorPosition()
  for _, h in ipairs(envelopes(source_tracks or target_tracks())) do
    if E.enabled[h.d.group] and (include_unarmed or armed(h.env)) then
      h.value=live_value(h,t); out[#out+1]=h
      if (R.GetEnvelopeUIState(h.env) & 2) ~= 0 or E.touched[h.d.guid] then active[#active+1]=h end
    end
  end
  if not all and require_latches then return active end
  return not all and #active>0 and active or out
end
function E.capture_values(all,selected_only)
  local source=selected_only and tracks(true) or all and tracks(false) or nil
  E.capture=snapshot(all or selected_only,source,all or selected_only)
  E.capture_selected=selected_only and #E.capture>0 or false
  if #E.capture==0 then notify(selected_only and 'No enabled envelopes on selected tracks' or 'No enabled envelopes to capture'); E.capture=nil; return end
  notify('Captured '..#E.capture..' values'..(selected_only and ' on selected tracks' or ''))
end
local function save_modes()
  local saved={override=R.GetGlobalAutomationOverride(),tracks={},project=R.EnumProjects(-1,'')}
  for _, tr in ipairs(target_tracks()) do saved.tracks[tr]=R.GetMediaTrackInfo_Value(tr,'I_AUTOMODE') end
  R.SetGlobalAutomationOverride(-1)
  return saved
end
local function restore_modes(saved)
  if not saved then return end
  for tr, mode in pairs(saved.tracks) do if valid(tr,'MediaTrack*',saved.project) then R.SetTrackAutomationMode(tr,mode) end end
  R.SetGlobalAutomationOverride(saved.override)
end
function E.end_punch()
  if not E.punch then return end
  local p=E.punch
  for env,a in pairs(p.arms) do if valid(env,'TrackEnvelope*',p.project) then arm(env,a) end end
  restore_modes(p.modes); E.punch=nil
  E.enforce()
end
function E.preview_toggle()
  if E.suspended_override~=nil then notify('Resume automation before Preview');return end
  return preserve_envelope_views(function()
  E.end_punch()
  if E.preview then
    restore_modes(E.preview_modes); E.preview_modes=nil; E.preview=false; E.preview_paused=nil; E.touched={}
    R.SetGlobalAutomationOverride(-1)
    notify('Preview off')
  else
    E.preview_modes=save_modes(); E.preview=true; E.preview_paused=nil; E.touched={}
    for tr in pairs(E.preview_modes.tracks) do R.SetTrackAutomationMode(tr,5) end
    notify('Preview: tweak enabled armed controls')
  end
  end)
end
function E.preview_suspend()
  if not E.preview then notify('Enable Preview before suspending it');return end
  E.end_punch()
  local modes=E.preview_modes
  if not modes then return end
  return preserve_envelope_views(function()
  if E.preview_paused then
    local held=E.preview_paused;E.preview_paused=nil;E.touched=held.touched
    R.SetGlobalAutomationOverride(-1)
    for tr in pairs(modes.tracks) do if valid(tr,'MediaTrack*',modes.project) then R.SetTrackAutomationMode(tr,5) end end
    for _,h in ipairs(held.values) do
      if valid(h.env,'TrackEnvelope*',modes.project) and envguid(h.env)==h.d.guid and E.enabled[h.d.group] and armed(h.env) then set_live(h,h.value) end
    end
    notify('Preview resumed: held values restored')
  else
    local values=snapshot(false,nil,nil,true)
    E.preview_paused={values=values,touched=E.touched}
    R.SetGlobalAutomationOverride(-1)
    for tr in pairs(modes.tracks) do if valid(tr,'MediaTrack*',modes.project) then R.SetTrackAutomationMode(tr,1) end end
    local t=(R.GetPlayState() & 1)~=0 and R.GetPlayPosition() or R.GetCursorPosition()
    for _,h in ipairs(values) do
      if valid(h.env,'TrackEnvelope*',modes.project) and envguid(h.env)==h.d.guid then set_live(h,evaluate(h.env,t)) end
    end
    notify('Preview suspended: auditioning existing automation')
  end
  R.UpdateArrange()
  end)
end
function E.punch_values(source)
  if E.preview_paused then notify('Resume Preview before punching');return end
  source = source or E.capture or snapshot(false)
  if #source==0 then notify('Nothing to punch'); return end
  if E.suspended_override ~= nil then notify('Resume automation before punching'); return end
  E.end_punch()
  local p={modes=save_modes(),arms={},values=source,position=R.GetPlayPosition(),project=R.EnumProjects(-1,'')}
  local wanted, affected={},{ }
  for _,h in ipairs(source) do
    if valid(h.env,'TrackEnvelope*') and E.enabled[h.d.group] then wanted[h.env]=h; affected[h.tr]=true end
  end
  if not next(wanted) then restore_modes(p.modes); notify('Capture is no longer available'); return end
  for _,h in ipairs(envelopes(target_tracks())) do
    if affected[h.tr] then p.arms[h.env]=armed(h.env); arm(h.env,wanted[h.env] ~= nil) end
  end
  for tr in pairs(affected) do R.SetTrackAutomationMode(tr,3) end
  for _,h in pairs(wanted) do set_live(h,h.value) end
  E.punch=p
  if (R.GetPlayState() & 1)==0 then p.position=R.GetCursorPosition() end
  notify('Punched '..#source..' values; writing on playback')
end
function E.match()
  E.end_punch()
  if E.preview_paused then E.preview_paused.values={};E.preview_paused.touched={} end
  local targets=target_tracks()
  local selected={}
  for _,tr in ipairs(tracks(true)) do selected[tr]=true; R.SetTrackSelected(tr,false) end
  for _,tr in ipairs(targets) do R.SetTrackSelected(tr,true) end
  R.Main_OnCommand(42026,0) -- Native clear selected track envelope latches.
  for _,tr in ipairs(tracks(false)) do R.SetTrackSelected(tr,selected[tr] or false) end
  E.touched={}; notify('Matched back to underlying automation')
end
local function bounds()
  local a,b=R.GetSet_LoopTimeRange(false,false,0,0,false)
  if b>a then return a,b,true end
  return 0,math.max(R.GetProjectLength(0),R.GetCursorPosition(),1),false
end
-- Rewrite only POOLEDENVINST instance lines, preserving pool data and all other
-- state. Split crossing items by duplicating their instance line and adjusting
-- length/start offset. Consequently pooled siblings elsewhere remain unchanged.
local function clear_ai_interval(env,a,b)
  if R.CountAutomationItems(env)==0 then return end
  local text=chunk(env)
  local n=0
  local output={}
  for line in (text..'\n'):gmatch('(.-)\n') do
    if line:match('^%s*POOLEDENVINST%s') then
      n=n+1
      local fields={}; for f in line:gmatch('%S+') do fields[#fields+1]=f end
      local pos,len,offs,rate=tonumber(fields[3]),tonumber(fields[4]),tonumber(fields[5]),tonumber(fields[6])
      if not (pos and len and offs and rate) then error('Unrecognized automation item state; nothing pasted') end
      local finish=pos+len
      if pos>=b or finish<=a then output[#output+1]=line
      else
        local function piece(start,ending)
          local f={table.unpack(fields)}
          f[3],f[4],f[5]=('%.17g'):format(start),('%.17g'):format(ending-start),('%.17g'):format(offs+(start-pos)*rate)
          output[#output+1]=table.concat(f,' ')
        end
        if pos<a then piece(pos,a) end
        if finish>b then piece(b,finish) end
      end
    else output[#output+1]=line end
  end
  if n~=R.CountAutomationItems(env) then error('Automation item state mismatch; nothing pasted') end
  if not R.SetEnvelopeStateChunk(env,table.concat(output,'\n'),false) then error('Cannot split automation items') end
end
-- Remove only redundant linear/flat knots. Nonlinear shapes and actual jumps
-- remain intact. This turns sampled flat/linear automation into two endpoints.
local function compact_points(pts)
  local out={}
  local function same(x,y) return math.abs(x-y)<=1e-10*math.max(1,math.abs(x),math.abs(y)) end
  for _,p in ipairs(pts) do
    local q={t=p.t,v=p.v,s=p.s or 0,z=p.z or 0}
    local tail=out[#out]
    if tail and math.abs(tail.t-q.t)<=1e-12 and same(tail.v,q.v) then out[#out]=q
    else out[#out+1]=q end
    while #out>=3 do
      local x,y,z=out[#out-2],out[#out-1],out[#out]
      local flat=x.s<=1 and y.s<=1 and same(x.v,y.v) and same(y.v,z.v)
      local linear=false
      if x.s==0 and y.s==0 and z.t>x.t and y.t>x.t and z.t>y.t then
        local value=x.v+(z.v-x.v)*(y.t-x.t)/(z.t-x.t)
        linear=same(value,y.v)
      end
      if not (flat or linear) then break end
      table.remove(out,#out-1)
    end
  end
  return out
end
local function replace_curve(env,a,b,pts,source_mode,outside)
  if b<=a then return end
  local eps=math.min(0.000001,(b-a)/1000000)
  local before,after=evaluate(env,math.max(0,a-eps)),evaluate(env,b+eps)
  if outside then before,after=outside.before,outside.after end
  clear_ai_interval(env,a,b)
  local index=-1
  if E.use_items then
    index=R.InsertAutomationItem(env,-1,a,b-a)
    if index<0 then error('Cannot create independent automation item') end
    R.GetSetAutomationItemInfo(env,index,'D_LOOPSRC',0,true)
    R.GetSetAutomationItemInfo(env,index,'D_BASELINE',0.5,true)
    R.GetSetAutomationItemInfo(env,index,'D_AMPLITUDE',1,true)
    R.DeleteEnvelopePointRangeEx(env,index,a-eps,b+eps)
  else
    R.DeleteEnvelopePointRangeEx(env,-1,math.max(0,a-eps/2),b+eps/2)
  end
  pts=compact_points(pts)
  local dest_mode=R.GetEnvelopeScalingMode(env)
  local converted={}
  for _,p in ipairs(pts) do
    local v=p.v
    if source_mode~=nil and source_mode~=dest_mode then v=R.ScaleToEnvelopeMode(dest_mode,R.ScaleFromEnvelopeMode(source_mode,v)) end
    converted[#converted+1]={t=p.t,v=v,s=p.s,z=p.z}
  end
  local function insert(p)
    if not R.InsertEnvelopePointEx(env,index,p.t,p.v,p.s or 0,p.z or 0,false,true) then error('Cannot write envelope point') end
  end
  -- Only add an outside guard when it is needed to preserve a different value;
  -- a matching flat lane gets just the selection endpoints, not paired dots.
  if index==-1 and #converted>0 and a>eps and math.abs(before-converted[1].v)>1e-10 then
    insert({t=a-eps,v=before,s=1,z=0})
  end
  local end_guard=index==-1 and #converted>0 and math.abs(after-converted[#converted].v)>1e-10
  if end_guard then converted[#converted].s=1 end
  for _,p in ipairs(converted) do insert(p) end
  if end_guard then
    -- The end guard is one microsecond beyond the selection: return is a step,
    -- not a ramp toward an unrelated underlying/default value inside the paste.
    insert({t=b+eps,v=after,s=0,z=0})
  end
  R.Envelope_SortPointsEx(env,index)
end
local function next_break(env,t,limit)
  local nextt=limit
  for ai=-1,R.CountAutomationItems(env)-1 do
    for i=0,R.CountEnvelopePointsEx(env,ai)-1 do
      local ok,pt=R.GetEnvelopePointEx(env,ai,i)
      if ok and pt>t+0.0000001 and pt<nextt then nextt=pt end
    end
  end
  return nextt
end
local prepare_envelope
local function write_range(which,h,a,b,t,touch)
  local left,right=a,b
  if which=='start' then right=math.max(a,math.min(t,b))
  elseif which=='end' then left=math.max(a,math.min(t,b))
  elseif which=='punch' then left,right=math.min(t,E.touched[h.d.guid] or touch or E.firsttouch or E.pass_start or t),t
  elseif which=='next' then left=t;right=next_break(h.env,t,math.max(b,t+1)) end
  return left,right
end
-- Verify stored knots as well as evaluated samples: a brief dip at the cursor
-- must not be mistaken for a held value across the requested range.
local function flat_value(env,a,b,margin)
  local value=evaluate(env,(a+b)/2)
  for _,f in ipairs({.1,.25,.75,.9}) do
    if math.abs(evaluate(env,a+(b-a)*f)-value)>1e-8 then return nil end
  end
  margin=margin or 0
  local items=R.CountAutomationItems(env)
  for index=-1,items-1 do
    for i=0,R.CountEnvelopePointsEx(env,index)-1 do
      local ok,t,v=R.GetEnvelopePointEx(env,index,i)
      if ok and t>a+margin and t<b-margin then
        if items>0 then v=evaluate(env,t) end
        if math.abs(v-value)>1e-8 then return nil end
      end
    end
  end
  return value
end
local function point_signature(env)
  local parts={}
  for i=0,R.CountEnvelopePointsEx(env,-1)-1 do
    local ok,t,v,shape,tension=R.GetEnvelopePointEx(env,-1,i)
    if ok then parts[#parts+1]=('%.17g,%.17g,%d,%.17g'):format(t,v,shape,tension) end
  end
  return table.concat(parts,';')
end
local function commit_plan(h,left,right)
  local points={}
  for i=0,R.CountEnvelopePointsEx(h.env,-1)-1 do
    local ok,t,v,shape,tension,selected=R.GetEnvelopePointEx(h.env,-1,i)
    if ok then points[#points+1]={t=t,v=v,s=shape,z=tension,selected=selected} end
  end
  local eps=math.min(.000001,(right-left)/1000000)
  return {h=h,left=left,right=right,value=h.value,points=points,
    outside={before=evaluate(h.env,math.max(0,left-eps)),after=evaluate(h.env,right+eps)},
    signature=point_signature(h.env),ui=R.GetEnvelopeUIState(h.env)}
end
local function write_trace(plans,phase)
  if not R.GetResourcePath then return end
  pcall(function()
    local file=io.open(R.GetResourcePath()..'/UserPlugins/EA_Native_Automation/ManualWrite-diagnostics.txt','w')
    if not file then return end
    file:write('EA Native Automation 2.2.4\n',phase,'\nPreview: ',tostring(E.preview),' | Scope: ',E.scope,' | Envelopes: ',tostring(#plans),'\n')
    for index,c in ipairs(plans) do
      if index>64 then break end
      local env=c.h.env
      file:write(('Envelope %s | %s | UI flags %s | source %s | range %.17g .. %.17g | held %.17g\n'):format(
        c.h.d.trguid..' / '..c.h.d.guid,c.h.d.name,tostring(c.ui),c.source or 'snapshot',c.left,c.right,c.value))
      if valid(env,'TrackEnvelope*') then
        file:write('Current flags: ',tostring(R.GetEnvelopeUIState(env)),' | mode: ',tostring(R.GetMediaTrackInfo_Value(c.h.tr,'I_AUTOMODE')),'\n')
        for _,f in ipairs({.1,.5,.9}) do file:write(('  sample %.17g = %.17g\n'):format(c.left+(c.right-c.left)*f,evaluate(env,c.left+(c.right-c.left)*f))) end
        local shown=0
        for i=0,R.CountEnvelopePointsEx(env,-1)-1 do
          local ok,t,v,shape=R.GetEnvelopePointEx(env,-1,i)
          if ok and t>=c.left-.01 and t<=c.right+.01 then
            shown=shown+1;if shown>64 then break end
            file:write(('  point %.17g = %.17g shape %d\n'):format(t,v,shape))
          end
        end
      else file:write('Envelope is no longer valid\n') end
    end
    file:close()
  end)
end
local function write_native_latches(which,values,a,b,t,touch)
  local batches,wanted={},{}
  for _,h in ipairs(values) do
    if valid(h.env,'TrackEnvelope*') and E.enabled[h.d.group] and armed(h.env)
      and (R.GetEnvelopeUIState(h.env) & 2)~=0 then
      local left,right=write_range(which,h,a,b,t,touch)
      if right>left then
        local key=('%.17g:%.17g'):format(left,right)
        if not batches[key] then batches[key]={left=left,right=right,envs={}} end
        batches[key].envs[h.env]=commit_plan(h,left,right);wanted[h.env]=true
      end
    end
  end
  if not next(wanted) then return nil end
  -- UI volume/pan reads may include trims, whereas REAPER's native command reads
  -- the internal latched envelope value. Do not change modes, reapply UI values,
  -- or round-trip envelope chunks before it has committed those latches.
  local all=envelopes(tracks(false))
  -- Native commits can edit shared item pools; use the explicit isolated path
  -- when a target has automation items.
  for _,h in ipairs(values) do if wanted[h.env] and R.CountAutomationItems(h.env)>0 then return nil end end
  local arms={}
  local sela,selb=R.GetSet_LoopTimeRange(false,false,0,0,false)
  local loopa,loopb=R.GetSet_LoopTimeRange(false,true,0,0,false)
  local ok,result=xpcall(function()
    local count,plans=0,{}
    for _,batch in pairs(batches) do
      for _,h in ipairs(all) do
        local original=armed(h.env)
        if arms[h.env]==nil then arms[h.env]=original end
        local state=batch.envs[h.env]~=nil
        if original~=state then arm(h.env,state) end
      end
      R.GetSet_LoopTimeRange(true,false,batch.left,batch.right,false)
      R.Main_OnCommand(42013,0) -- Write current values for actively-writing envelopes to time selection.
      for _,c in pairs(batch.envs) do
        c.native_attempt=true
        -- Take the raw value from a genuine native plateau when available.
        -- A no-op or a cursor-only dip is not a successful range commit.
        local held=flat_value(c.h.env,c.left,c.right,math.min(.01,(c.right-c.left)*.01))
        if held and point_signature(c.h.env)~=c.signature then
          c.value=held;c.source='native plateau'
        else c.source='held snapshot; native range incomplete' end
        plans[#plans+1]=c;count=count+1
      end
    end
    return {count=count,plans=plans}
  end,debug.traceback)
  -- The time-selection/loop-link preference can also move the loop bounds.
  -- Restore both, including on a failed native action; never seek transport.
  R.GetSet_LoopTimeRange(true,false,sela,selb,false)
  R.GetSet_LoopTimeRange(true,true,loopa,loopb,false)
  for env,state in pairs(arms) do if valid(env,'TrackEnvelope*') and armed(env)~=state then arm(env,state) end end
  if not ok then error(result,0) end
  return result.count,result.plans
end
local function view_attribute(env,key)
  local ok,value=R.GetSetEnvelopeInfo_String(env,key,'',false)
  if ok and (value=='0' or value=='1') then return value end
  local text=chunk(env)
  local visible,lane=text:match('\nVIS%s+([01])%s+([01])')
  return key=='VISIBLE' and visible or lane
end
local function restore_view_attribute(env,key,value)
  if value==nil or view_attribute(env,key)==value then return end
  if R.GetSetEnvelopeInfo_String(env,key,value,true) then return end
  -- Read the CURRENT chunk: never replay a pre-write chunk containing old points.
  local text=chunk(env)
  local nexttext,n
  if key=='VISIBLE' then
    nexttext,n=text:gsub('(\nVIS%s+)[01]',function(prefix) return prefix..value end,1)
  else
    nexttext,n=text:gsub('(\nVIS%s+[01]%s+)[01]',function(prefix) return prefix..value end,1)
  end
  if n~=1 or not R.SetEnvelopeStateChunk(env,nexttext,false) then error('Cannot restore automation lane visibility') end
end
local function restore_envelope_views(saved,project)
  local failed,changed
  for _,entry in ipairs(saved) do
    if valid(entry.env,'TrackEnvelope*',project) and envguid(entry.env)==entry.guid then
      local restored,why=pcall(function()
        if view_attribute(entry.env,'SHOWLANE')~=entry.lane or view_attribute(entry.env,'VISIBLE')~=entry.visible then changed=true end
        restore_view_attribute(entry.env,'SHOWLANE',entry.lane)
        restore_view_attribute(entry.env,'VISIBLE',entry.visible)
      end)
      if not restored and not failed then failed=why end
    end
  end
  if failed then error(failed,0) end
  return changed
end
preserve_envelope_views=function(fn)
  local saved={}
  local project=R.EnumProjects(-1,'')
  -- A native write/automation-mode change can reveal lanes outside the target
  -- set. Preserve views for the complete current project, including the master.
  for _,tr in ipairs(tracks(false)) do
    for i=0,R.CountTrackEnvelopes(tr)-1 do
      local env=R.GetTrackEnvelope(tr,i)
      saved[#saved+1]={env=env,guid=envguid(env),visible=view_attribute(env,'VISIBLE'),lane=view_attribute(env,'SHOWLANE')}
    end
  end
  local previous_check=E.pending_write_check
  local ok,result=xpcall(fn,debug.traceback)
  local known={}
  for _,entry in ipairs(saved) do known[entry.guid]=true end
  -- Automation-mode transitions can auto-create native volume/pan lanes. They
  -- had no pre-operation visible state, so keep these new lanes hidden too.
  for _,tr in ipairs(tracks(false)) do
    for i=0,R.CountTrackEnvelopes(tr)-1 do
      local env=R.GetTrackEnvelope(tr,i);local guid=envguid(env)
      if not known[guid] then saved[#saved+1]={env=env,guid=guid,visible='0',lane=view_attribute(env,'SHOWLANE')};known[guid]=true end
    end
  end
  local restored,why=pcall(restore_envelope_views,saved,project)
  E.pending_view_check={views=saved,project=project,at=R.time_precise()+.08}
  if restored and why then
    if R.TrackList_AdjustWindows then R.TrackList_AdjustWindows(false) end
    R.UpdateArrange()
  end
  if E.pending_write_check and E.pending_write_check~=previous_check then E.pending_write_check.views=saved end
  if not ok then error(result,0) end
  if not restored then error(why,0) end
  return result
end
local function finish_manual(plans)
  -- Finish the host's live preview pass BEFORE editing its final curve. Native
  -- volume/send write buffers may otherwise replace edits when Preview exits.
  if E.preview then E.preview_toggle() end
  for _,c in ipairs(plans) do
    local env,why=prepare_envelope(c.h.env,false)
    if not env then error(why or 'Cannot activate envelope for Manual Write') end
    if c.native_attempt then
      -- Remove the native action's provisional points, including transition
      -- guards outside the selection, without a state-chunk reload. Retain all
      -- original outside knots, shapes, tensions and selection flags exactly.
      if not R.DeleteEnvelopePointRangeEx(env,-1,-1e100,1e100) then error('Cannot replace provisional native write') end
      for _,p in ipairs(c.points) do
        if not R.InsertEnvelopePointEx(env,-1,p.t,p.v,p.s,p.z,p.selected,true) then error('Cannot restore original automation boundary') end
      end
      R.Envelope_SortPointsEx(env,-1)
    end
    replace_curve(env,c.left,c.right,{{t=c.left,v=c.value,s=1,z=0},{t=c.right,v=c.value,s=1,z=0}},nil,c.outside)
    local held=flat_value(env,c.left,c.right)
    if held==nil or math.abs(held-c.value)>1e-8 then error('Manual Write range verification failed; Preview has been stopped') end
  end
  E.pending_write_check={plans=plans,at=R.time_precise()+.08,project=R.EnumProjects(-1,'')}
  write_trace(plans,'Committed after Preview exit; waiting for host readback')
  return #plans
end
function E.verify_manual_write()
  local view=E.pending_view_check
  if view and R.time_precise()>=view.at then
    E.pending_view_check=nil
    if R.EnumProjects(-1,'')==view.project and restore_envelope_views(view.views,view.project) then
      if R.TrackList_AdjustWindows then R.TrackList_AdjustWindows(false) end
      R.UpdateArrange()
    end
  end
  local pending=E.pending_write_check
  if not pending or R.time_precise()<pending.at then return end
  E.pending_write_check=nil
  if R.EnumProjects(-1,'')~=pending.project then return end
  if pending.views and restore_envelope_views(pending.views,pending.project) then
    if R.TrackList_AdjustWindows then R.TrackList_AdjustWindows(false) end
    R.UpdateArrange()
  end
  local failures=0
  for _,c in ipairs(pending.plans) do
    local held=valid(c.h.env,'TrackEnvelope*') and flat_value(c.h.env,c.left,c.right) or nil
    if held==nil or math.abs(held-c.value)>1e-8 then failures=failures+1 end
  end
  write_trace(pending.plans,failures==0 and 'Verified after host update' or 'FAILED after host update')
  notify(failures==0 and ('Verified '..#pending.plans..' envelopes; Preview off') or
    ('Manual Write changed after commit; '..failures..' failed. Diagnostics saved.'))
  return failures==0
end
function E.write(which, supplied, at, touch, manual)
  if E.suspended_override ~= nil then notify('Resume automation before writing'); return end
  local values=supplied or (E.preview and (E.preview_paused and E.preview_paused.values or snapshot(false,nil,nil,manual))) or E.capture or snapshot(false,nil,nil,manual)
  if #values==0 then
    local message=E.preview and 'No latched Preview values to write' or manual and 'No latched or captured values to write' or 'No enabled armed envelopes'
    notify(message);if manual then write_trace({},message) end
    return
  end
  local a,b,selection=bounds()
  if manual and which=='all' and not selection then
    local scope=E.scope=='selected' and 'Selected tracks' or 'All tracks'
    local answer=R.ShowMessageBox(
      'No time selection is set.\n\nIf you proceed, the current automation values will be written across the entire session (project range).\n\nTrack scope: '..scope..'.\n\nClick OK to proceed, or Cancel to keep the current automation.',
      'Automation: No time selection',1) -- Native OK / Cancel on all platforms.
    if answer~=1 then
      notify('Write cancelled: no time selection')
      write_trace({},'Cancelled entire-session write: no time selection')
      return 0
    end
  end
  local t=at or ((R.GetPlayState() & 1)~=0 and R.GetPlayPosition() or R.GetCursorPosition())
  local count=undo('Automation: write '..which,function()
    return preserve_envelope_views(function()
    if manual then
      local native,plans
      if not supplied and not E.use_items and not E.preview_paused and (E.preview or not E.capture) then
        native,plans=write_native_latches(which,values,a,b,t,touch)
      end
      if native==nil then
        plans={}
        for _,h in ipairs(values) do
          if valid(h.env,'TrackEnvelope*') and E.enabled[h.d.group] then
            local left,right=write_range(which,h,a,b,t,touch)
            if right>left then plans[#plans+1]=commit_plan(h,left,right) end
          end
        end
      end
      if #plans==0 then return 0 end
      return finish_manual(plans)
    end
    if not supplied and not E.use_items and not E.preview_paused and (E.preview or not E.capture) then
      local native=write_native_latches(which,values,a,b,t,touch)
      if native~=nil then return native end
    end
    local count=0
    for _,h in ipairs(values) do
      if valid(h.env,'TrackEnvelope*') and E.enabled[h.d.group] then
        local left,right=write_range(which,h,a,b,t,touch)
        if right>left then
          local env,why=prepare_envelope(h.env,false)
          if not env then error(why or 'Cannot activate envelope for Manual Write') end
          replace_curve(h.env,left,right,{{t=left,v=h.value,s=1,z=0},{t=right,v=h.value,s=1,z=0}})
          count=count+1
        end
      end
    end
    return count
    end)
  end)
  notify(count>0 and ('Wrote '..count..' envelopes'..(manual and '; verifying...' or '')) or 'No time range to write')
  return count
end
function E.manual_write(which)
  local count=E.write(which,nil,nil,nil,true)
  if count and count>0 and E.preview then
    E.preview_toggle()
    notify('Wrote '..count..' envelopes; Preview off')
  end
  return count
end
local function extent(list)
  local a,b=R.GetSet_LoopTimeRange(false,false,0,0,false)
  if b>a then return a,b end
  local low,high=math.huge,-math.huge
  for i=0,R.CountSelectedMediaItems(0)-1 do
    local item=R.GetSelectedMediaItem(0,i)
    local parent=R.GetMediaItemTrack(item)
    local in_source=false
    for _,tr in ipairs(list) do if parent==tr then in_source=true; break end end
    if in_source then
      local p=R.GetMediaItemInfo_Value(item,'D_POSITION')
      low=math.min(low,p); high=math.max(high,p+R.GetMediaItemInfo_Value(item,'D_LENGTH'))
    end
  end
  if high>low then return low,high end
  high=R.GetProjectLength(0)
  for _,h in ipairs(envelopes(list)) do
    local count=R.CountEnvelopePoints(h.env)
    if count>0 then local _,t=R.GetEnvelopePoint(h.env,count-1); high=math.max(high,t) end
    for ai=0,R.CountAutomationItems(h.env)-1 do
      high=math.max(high,R.GetSetAutomationItemInfo(h.env,ai,'D_POSITION',0,false)+R.GetSetAutomationItemInfo(h.env,ai,'D_LENGTH',0,false))
    end
  end
  return 0,math.max(high,1)
end
local function copy_curve(env,a,b)
  local pts={}
  local hasai=false
  for ai=0,R.CountAutomationItems(env)-1 do
    local p=R.GetSetAutomationItemInfo(env,ai,'D_POSITION',0,false)
    local l=R.GetSetAutomationItemInfo(env,ai,'D_LENGTH',0,false)
    if p<b and p+l>a then hasai=true end
  end
  local function add(t,v,s,z) pts[#pts+1]={t=t-a,v=v,s=s or 0,z=z or 0} end
  if not hasai then
    -- Preserve actual interior breakpoint shapes/tensions. Sample clipped nonlinear
    -- edge segments because a Bezier segment cannot be trimmed by moving its knot.
    local times={a,b}
    local native={}
    for i=0,R.CountEnvelopePoints(env)-1 do
      local ok,t,v,s,z=R.GetEnvelopePoint(env,i)
      if ok then native[#native+1]={t=t,v=v,s=s,z=z}; if t>a and t<b then times[#times+1]=t end end
    end
    table.sort(times)
    for i=1,#times-1 do
      local left,right=times[i],times[i+1]
      local start,ending
      for _,p in ipairs(native) do if p.t<=left then start=p end; if not ending and p.t>=right then ending=p end end
      local clipped=start and start.s>1 and (start.t<left or (ending and ending.t>right))
      if clipped then
        local steps=math.max(2,math.ceil((right-left)*120))
        if steps>250000 then error('Selection is too long to bake; copy a shorter range') end
        for j=0,steps-1 do local t=left+(right-left)*j/steps; add(t,evaluate(env,t),0,0) end
      else add(left,evaluate(env,left),start and start.s or 0,start and start.z or 0) end
    end
    add(b,evaluate(env,b),0,0)
  else
    -- Bake the audible composite, including pool loops, baseline/amplitude, muted
    -- items, and overlapping items. Independent result: no source pool coupling.
    local times={a,b}
    local steps=math.ceil((b-a)*120)
    if steps>250000 then error('Automation-item selection is too long; copy a shorter range') end
    for i=1,steps-1 do times[#times+1]=a+(b-a)*i/steps end
    for ai=-1,R.CountAutomationItems(env)-1 do
      for i=0,R.CountEnvelopePointsEx(env,ai)-1 do
        local ok,t=R.GetEnvelopePointEx(env,ai,i)
        if ok and t>a and t<b then times[#times+1]=math.max(a,t-0.000001); times[#times+1]=t end
      end
      if ai>=0 then
        local p=R.GetSetAutomationItemInfo(env,ai,'D_POSITION',0,false)
        local e=p+R.GetSetAutomationItemInfo(env,ai,'D_LENGTH',0,false)
        for _,t in ipairs({p,e}) do if t>a and t<b then times[#times+1]=t-0.000001;times[#times+1]=t end end
      end
    end
    table.sort(times)
    local prev=-math.huge
    for _,t in ipairs(times) do if t>prev+1e-9 then add(t,evaluate(env,t),0,0);prev=t end end
  end
  -- At an automation-item end, REAPER can return the underlying default rather
  -- than the outgoing item's value. Copy the left-hand limit of the source end.
  if hasai and #pts>0 then
    local edge=math.min(0.0000001,(b-a)/1000000)
    local v1,v2=evaluate(env,b-edge),evaluate(env,b-2*edge)
    pts[#pts].v=v1+(v1-v2)
  end
  return compact_points(pts),hasai
end
function E.copy(kind)
  local list=tracks(true)
  if #list==0 then notify('Select source tracks first'); return end
  local a,b=extent(list)
  local cb={duration=b-a,tracks={},kind=kind,baked=0}
  local count=0
  for _,tr in ipairs(list) do
    local row={guid=R.GetTrackGUID(tr),envs={}}
    for _,h in ipairs(envelopes({tr})) do
      if kind=='all' or kind=='pan' and h.d.group=='pan' or kind=='enabled' and E.enabled[h.d.group] then
        local pts,baked=copy_curve(h.env,a,b)
        local samples={}
        for pi=1,#pts-1 do
          if pts[pi].s>1 then
            local left,right=pts[pi].t,pts[pi+1].t
            local steps=math.max(2,math.ceil((right-left)*120))
            if steps>250000 then error('Nonlinear segment is too long; copy a shorter range') end
            local segment={}
            for j=0,steps do local t=left+(right-left)*j/steps;segment[#segment+1]={t=t,v=evaluate(h.env,a+t)} end
            samples[pi]=segment
          end
        end
        row.envs[#row.envs+1]={d=h.d,points=pts,samples=samples,scaling=R.GetEnvelopeScalingMode(h.env)}
        count=count+1; if baked then cb.baked=cb.baked+1 end
      end
    end
    cb.tracks[#cb.tracks+1]=row
  end
  if count==0 then notify('No matching track envelopes'); return end
  E.clipboard=cb
  notify(('Copied %d envelopes / %.2fs'):format(count,b-a))
end
local function fx_indices(tr)
  local result={}
  local function walk(index)
    result[#result+1]=index
    local ok,count=R.TrackFX_GetNamedConfigParm(tr,index,'container_count')
    if ok then for c=0,tonumber(count)-1 do
      local yes,child=R.TrackFX_GetNamedConfigParm(tr,index,'container_item.'..c)
      if yes then walk(tonumber(child)) end
    end end
  end
  for i=0,R.TrackFX_GetCount(tr)-1 do walk(i) end
  for i=0,R.TrackFX_GetRecCount(tr)-1 do walk(0x1000000+i) end
  return result
end
local NATIVE_DEFAULTS={VOLENV2=1,VOLENV=1,VOLENV3=1,PANENV2=0,PANENV=0,
  WIDTHENV2=1,WIDTHENV=1,MUTEENV=1,DUALPANENVL=1,DUALPANENV=-1,
  DUALPANENVL2=1,DUALPANENV2=-1,DUALPANENVR=-1}
local function native_tag(tr,tag)
  local base=tag:gsub('^MASTER','')
  if NATIVE_DEFAULTS[base]~=nil then
    return tr==R.GetMasterTrack(0) and tag or base
  end
  return tag
end
local function new_envelope_block(tag,value)
  local guid=R.genGuid and ('EGUID '..R.genGuid()..'\n') or ''
  local shape=tag:find('MUTE',1,true) and 1 or 0
  return ('<%s\n%sACT 1 -1\nVIS 1 1 1\nLANEHEIGHT 0 0\nARM 0\nDEFSHAPE %d -1 -1\nPT 0 %.17g %d\n>\n'):format(tag,guid,shape,value,shape)
end
prepare_envelope=function(env,reveal)
  if not env then return nil end
  local active=R.GetSetEnvelopeInfo_String(env,'ACTIVE','1',true)
  local visible=reveal==false or R.GetSetEnvelopeInfo_String(env,'VISIBLE','1',true)
  if active and visible then return env end
  local text=chunk(env)
  local nexttext,n=text:gsub('(\nACT%s+)[01]',function(prefix) return prefix..'1' end,1)
  if n==0 then nexttext=nexttext:gsub('\n','\nACT 1 -1\n',1) end
  if reveal~=false then
    nexttext,n=nexttext:gsub('(\nVIS%s+)[01]',function(prefix) return prefix..'1' end,1)
    if n==0 then nexttext=nexttext:gsub('\n','\nVIS 1 1 1\n',1) end
  end
  if nexttext~=text and not R.SetEnvelopeStateChunk(env,nexttext,false) then return nil,'Cannot activate destination envelope' end
  return env
end
local function native_baseline(tr,tag)
  tag=tag:gsub('^MASTER','')
  local keys={VOLENV2='D_VOL',PANENV2='D_PAN',WIDTHENV2='D_WIDTH',DUALPANENVL2='D_DUALPANL',DUALPANENV2='D_DUALPANR'}
  if keys[tag] then
    local value=R.GetMediaTrackInfo_Value(tr,keys[tag])
    return tag:find('PAN',1,true) and -value or value
  end
  if tag=='MUTEENV' then return R.GetMediaTrackInfo_Value(tr,'B_MUTE')==1 and 0 or 1 end
  return NATIVE_DEFAULTS[tag]
end
local function matching_send(tr,d)
  local ordinal=0
  for i=0,R.GetTrackNumSends(tr,d.cat)-1 do
    local dest=R.GetTrackSendInfo_Value(tr,d.cat,i,'P_DESTTRACK')
    local match=d.cat==1 or (dest and R.GetTrackGUID(dest)==d.destguid)
    if match and R.GetTrackSendInfo_Value(tr,d.cat,i,'I_DSTCHAN')==d.channel
      and R.GetTrackSendInfo_Value(tr,d.cat,i,'I_SRCCHAN')==d.sourcechannel then
      ordinal=ordinal+1;if ordinal==d.ordinal then return i end
    end
  end
end
local function send_plan(tr,entries)
  local plan,used,unique={},{},{}
  for _,entry in ipairs(entries) do
    local d=entry.d
    if d.kind=='send' then
      local key=d.cat..':'..d.send
      if not unique[key] then unique[key]=d end
    end
  end
  -- Reserve identity matches before any fallback, so unrelated source sends
  -- cannot accidentally overwrite each other's destination automation.
  local keys={};for key in pairs(unique) do keys[#keys+1]=key end
  table.sort(keys,function(a,b) local da,db=unique[a],unique[b];return da.cat==db.cat and da.send<db.send or da.cat<db.cat end)
  for _,key in ipairs(keys) do
    local d=unique[key];local index=matching_send(tr,d)
    if index~=nil and not used[d.cat..':'..index] then plan[key]=index;used[d.cat..':'..index]=true end
  end
  for _,key in ipairs(keys) do
    if plan[key]==nil then
      local d=unique[key];local count=R.GetTrackNumSends(tr,d.cat)
      local index=d.send<count and not used[d.cat..':'..d.send] and d.send or nil
      if index==nil then for i=0,count-1 do if not used[d.cat..':'..i] then index=i;break end end end
      if index~=nil then plan[key]=index;used[d.cat..':'..index]=true else plan[key]=false end
    end
  end
  return plan
end
local function create_send_envelope(tr,cat,index,group)
  local tag=group=='svol' and 'VOLENV' or group=='span' and 'PANENV' or 'MUTEENV'
  local host=cat==1 and tr or R.GetTrackSendInfo_Value(tr,cat,index,'P_DESTTRACK')
  if not host then return nil,'Existing send destination not found' end
  local ordinal=cat==1 and index+1 or 0
  if cat==0 then for i=0,index do if R.GetTrackSendInfo_Value(tr,0,i,'P_DESTTRACK')==host then ordinal=ordinal+1 end end end
  local source_id=math.floor(R.GetMediaTrackInfo_Value(tr,'IP_TRACKNUMBER'))-1
  local ok,text=R.GetTrackStateChunk(host,'',false)
  if not ok then return nil,'Cannot read destination send envelope' end
  local depth,seen,insert_at=0,0,nil
  for start,line,finish in text:gmatch('()([^\n]*)\n()') do
    local body=line:match('^%s*(.-)%s*$')
    if depth==1 then
      local source=body:match('^AUXRECV%s+([%-]?%d+)')
      if (cat==1 and body:match('^HWOUT%s')) or (cat==0 and tonumber(source)==source_id) then
        seen=seen+1;if seen==ordinal then insert_at=finish;break end
      end
    end
    if body:sub(1,1)=='<' then depth=depth+1 elseif body=='>' then depth=depth-1 end
  end
  if not insert_at then return nil,'Existing send route record not found' end
  local value=R.GetTrackSendInfo_Value(tr,cat,index,group=='svol' and 'D_VOL' or group=='span' and 'D_PAN' or 'B_MUTE')
  if group=='span' then value=-value elseif group=='smute' then value=value==1 and 0 or 1 end
  local block=new_envelope_block((cat==1 and 'HW' or 'AUX')..tag,value)
  text=text:sub(1,insert_at-1)..block..text:sub(insert_at)
  if not R.SetTrackStateChunk(host,text,false) then return nil,'Cannot create destination send envelope' end
  return R.GetTrackSendInfo_Value(tr,cat,index,'P_ENV:<'..tag)
end
local function resolve(tr,d,create,plan)
  if R.GetTrackGUID(tr)==d.trguid then
    local found=R.GetMediaTrackInfo_Value(tr,'P_ENV:'..d.guid)
    if found and valid(found,'TrackEnvelope*') then if create then return prepare_envelope(found) end;return found end
  end
  if d.kind=='native' then
    local tag=native_tag(tr,d.tag)
    local env=R.GetTrackEnvelopeByChunkName(tr,'<'..tag)
    if env then if create then return prepare_envelope(env) end;return env end
    if not create then return nil end
    if NATIVE_DEFAULTS[tag:gsub('^MASTER','')]==nil then return nil,'Missing track parameter: '..d.name end
    local ok,text=R.GetTrackStateChunk(tr,'',false)
    if not ok then return nil,'Cannot create native envelope' end
    local block=new_envelope_block(tag,native_baseline(tr,tag))
    text=text:gsub('>%s*$',block..'>\n',1)
    if not R.SetTrackStateChunk(tr,text,false) then return nil,'Cannot create envelope' end
    return R.GetTrackEnvelopeByChunkName(tr,'<'..tag)
  elseif d.kind=='fx' then
    local fx,ordinal=nil,0
    for _,i in ipairs(fx_indices(tr)) do
      if R.TrackFX_GetFXGUID(tr,i)==d.fxguid then fx=i;break end
      if fx_identity(tr,i)==d.fxid then ordinal=ordinal+1;if ordinal==d.ordinal then fx=i end end
    end
    if fx==nil then return nil,'Missing FX instance: '..d.fxid end
    local param=-1
    if d.pident~='' then param=R.TrackFX_GetParamFromIdent(tr,fx,d.pident) end
    if param<0 then
      local _,name=R.TrackFX_GetParamName(tr,fx,d.param,'')
      if name==d.pname then param=d.param else
        for i=0,R.TrackFX_GetNumParams(tr,fx)-1 do
          local _,pn=R.TrackFX_GetParamName(tr,fx,i,'')
          if pn==d.pname then param=i;break end
        end
      end
    end
    if param<0 then return nil,'Missing parameter: '..d.pname end
    local env=R.GetFXEnvelope(tr,fx,param,create)
    if create then return prepare_envelope(env) end;return env
  elseif d.kind=='send' then
    local index=plan and plan[d.cat..':'..d.send]
    if not plan then index=matching_send(tr,d);if index==nil and d.send<R.GetTrackNumSends(tr,d.cat) then index=d.send end end
    if index==nil or index==false then return nil,'Missing existing send for '..d.name..' (source send '..(d.send+1)..')' end
    local tag=d.group=='svol' and '<VOLENV' or d.group=='span' and '<PANENV' or '<MUTEENV'
    local env=R.GetTrackSendInfo_Value(tr,d.cat,index,'P_ENV:'..tag)
    if env then if create then return prepare_envelope(env) end;return env end
    if create then
      local created,why=create_send_envelope(tr,d.cat,index,d.group)
      return created,why or (not created and 'Missing send parameter: '..d.name or nil)
    end
    return nil,'Missing send envelope: '..d.name
  end
end
function E.paste(mode)
  local cb=E.clipboard
  if not cb then notify('Copy automation first'); return end
  if (R.GetPlayState() & 1)~=0 then notify('Stop playback before pasting'); return end
  local list=tracks(true)
  if #list==0 then notify('Select destination tracks'); return end
  if #cb.tracks>1 and #list~=#cb.tracks then notify('Select '..#cb.tracks..' destination tracks'); return end
  local a,b=R.GetSet_LoopTimeRange(false,false,0,0,false)
  if mode~='cursor' and b<=a then notify('Make a time selection first'); return end
  if mode=='cursor' then a=R.GetCursorPosition();b=a+cb.duration end
  local scale=mode=='fit' and (b-a)/cb.duration or 1
  local repeats=mode=='fill' and math.ceil((b-a)/cb.duration) or 1
  if repeats>10000 then notify('Selection is too long to repeat'); return end
  local done,skipped=0,{}
  undo('Paste automation: '..mode,function()
    for ti,tr in ipairs(list) do
      local source=cb.tracks[#cb.tracks==1 and 1 or ti]
      local plan=send_plan(tr,source.envs)
      for _,entry in ipairs(source.envs) do
        local env,why=resolve(tr,entry.d,true,plan)
        if env then
          local pts={}
          for rep=0,repeats-1 do
            for pi,p in ipairs(entry.points) do
              local t=a+rep*cb.duration+p.t*scale
              if t<=b+1e-9 then
                if rep>0 and pi==1 and #pts>0 and math.abs(pts[#pts].t-t)<1e-9 then
                  if math.abs(pts[#pts].v-p.v)<=1e-10 then table.remove(pts)
                  else pts[#pts].t=t-math.min(0.000001,cb.duration/1000000);pts[#pts].s=1 end
                end
                pts[#pts+1]={t=math.min(t,b),v=p.v,s=p.s,z=p.z}
              end
            end
          end
          -- Fill ends part-way through the source when the duration is not an
          -- exact multiple. Interpolate the clipped end using a source curve value.
          if #pts>0 and pts[#pts].t<b-1e-9 then
            local phase=(b-a)%cb.duration
            local last=entry.points[1]
            local value=last.v
            for pi,p in ipairs(entry.points) do
              if p.t>=phase then
                local f=p.t>last.t and (phase-last.t)/(p.t-last.t) or 0
                value=last.s==1 and last.v or last.v+(p.v-last.v)*f
                local sampled=entry.samples and entry.samples[pi-1]
                if sampled then
                  local base=a+(repeats-1)*cb.duration
                  pts[#pts].s=0
                  local preceding=sampled[1]
                  for si=2,#sampled do
                    local sp=sampled[si]
                    if sp.t>=phase then
                      local u=(phase-preceding.t)/(sp.t-preceding.t)
                      value=preceding.v+(sp.v-preceding.v)*u;break
                    end
                    pts[#pts+1]={t=base+sp.t,v=sp.v,s=0,z=0};preceding=sp
                  end
                end
                break
              end
              last=p;value=p.v
            end
            pts[#pts+1]={t=b,v=value,s=0,z=0}
          end
          replace_curve(env,a,b,pts,entry.scaling); done=done+1
        else skipped[#skipped+1]=why or entry.d.name end
      end
    end
  end)
  E.last_report=table.concat(skipped,'\n')
  notify(('Pasted %d / skipped %d'):format(done,#skipped))
  if #skipped>0 then R.ShowMessageBox(E.last_report,'Automation: unmatched envelopes',0) end
end
function E.poll()
  local proj=R.EnumProjects(-1,'')
  if E.project and E.project~=proj then
    E.end_punch();restore_gates();if E.preview then restore_modes(E.preview_modes) end
    if E.suspended_override~=nil then R.SetGlobalAutomationOverride(E.suspended_override);E.suspended_override=nil end
    E.preview=false;E.preview_modes=nil;E.preview_paused=nil;E.capture=nil;E.touched={};E.onstop={};E.join_saved=nil;descriptor_cache={}
    E.pass_values=nil;E.firsttouch=nil;E.join_pending=false;E.lastplay=0
  end
  E.project=proj
  local play=R.GetPlayState() & 1
  local pos=play~=0 and R.GetPlayPosition() or R.GetCursorPosition()
  if play~=0 and E.lastplay==0 then
    E.pass_start=pos;E.firsttouch=nil;E.pass_values=nil;E.touched={}
    if E.join and E.join_saved then E.join_pending=true end
  end
  if play~=0 then
    local active={}
    for _,h in ipairs(envelopes(target_tracks())) do
      if E.enabled[h.d.group] and armed(h.env) and (R.GetEnvelopeUIState(h.env) & 2)~=0 then
        h.value=live_value(h,pos);active[#active+1]=h
        if not E.touched[h.d.guid] then E.touched[h.d.guid]=pos end
        if not E.firsttouch then E.firsttouch=pos end
      end
    end
    if #active>0 then E.pass_values=active end
    if E.join_pending and pos>=E.join_saved.position and (E.lastpos<=E.join_saved.position or E.lastplay==0) then
      E.join_pending=false;E.punch_values(E.join_saved.values)
    end
  elseif E.lastplay~=0 then
    local values=E.pass_values
    if E.punch then
      values={}
      for _,h in ipairs(E.punch.values) do if valid(h.env,'TrackEnvelope*') then
        local copy={env=h.env,tr=h.tr,d=h.d,value=live_value(h,E.lastpos)};values[#values+1]=copy
      end end
    end
    if values and #values>0 and E.suspended_override==nil then
      E.join_saved={values=values,position=E.lastpos}
      -- Latch the exact time selection and touch position for this completed pass.
      for _,which in ipairs({'start','all','end','punch','next'}) do
        if E.onstop[which] then E.write(which,values,E.lastpos,E.firsttouch) end
      end
    end
    E.end_punch();E.join_pending=false
  end
  E.lastplay,E.lastpos=play,pos
end
function E.cleanup()
  E.end_punch(); restore_gates()
  if E.preview then restore_modes(E.preview_modes);E.preview=false;E.preview_modes=nil;E.preview_paused=nil end
  if E.suspended_override~=nil then restore_suspended();R.SetGlobalAutomationOverride(E.suspended_override);E.suspended_override=nil end
  if E.autoadd_saved~=nil and R.SNM_SetIntConfigVar then
    local current=R.SNM_GetIntConfigVar('env_autoadd',0)
    R.SNM_SetIntConfigVar('env_autoadd',(current & ~1) | (E.autoadd_saved & 1))
  end
end

-- UI follows the reference geometry: full-width Suspend, centered Plug In,
-- paired write-enable columns, 3+2 icon write sections,
-- Join/Match, split Preview/Capture rows. Clipboard additions are below.

E._test={descriptor=descriptor,resolve=resolve,replace_curve=replace_curve,copy_curve=copy_curve,
  clear_ai_interval=clear_ai_interval,live_value=live_value,set_live=set_live,snapshot=snapshot,compact_points=compact_points}
if rawget(_G,'EA_AUTOMATION_TEST') then return E end
local function native_available()
  return R.APIExists('EA_Native_Connect') and R.APIExists('EA_Native_NextCommand') and R.APIExists('EA_Native_Publish')
end
if not native_available() then R.ShowMessageBox('Install the native extension first, then restart REAPER.','EA Native Automation',0);return end
if R.GetExtState(APP,'running')=='1' then
  R.ShowMessageBox('Close the older Lua automation panel before opening the native panel.','EA Native Automation',0);return
end
if R.GetExtState(APP,'native_engine_running')=='1' then return end
R.SetExtState(APP,'native_engine_running','1',false)
E.scope=R.GetExtState(APP,'scope')=='selected' and 'selected' or 'all'
E.use_items=R.GetExtState(APP,'use_items')=='1'
local exiting=false
local function finish()
  if exiting then return end;exiting=true
  pcall(E.cleanup)
  R.SetExtState(APP,'scope',E.scope,true)
  R.DeleteExtState(APP,'native_engine_running',false)
  if native_available() then R.EA_Native_Connect(false) end
end
R.atexit(finish)
R.EA_Native_Connect(true)
local function command(text)
  local kind,value=text:match('^([^:]+):?(.*)$')
  if kind=='close' then return false end
  if kind=='group' then if E.enabled[value]~=nil then E.toggle_group(value) end
  elseif kind=='write' then if value=='start' or value=='all' or value=='end' or value=='punch' or value=='next' then E.manual_write(value) end
  elseif kind=='onstop' then if value=='start' or value=='all' or value=='end' or value=='punch' or value=='next' then E.onstop[value]=not E.onstop[value] end
  elseif kind=='copy' then if value=='all' or value=='pan' or value=='enabled' then E.copy(value) end
  elseif kind=='paste' then if value=='cursor' or value=='fit' or value=='fill' then E.paste(value) end
  elseif kind=='suspend' then E.suspend()
  elseif kind=='preview' then E.preview_toggle()
  elseif kind=='preview_suspend' then E.preview_suspend()
  elseif kind=='capture' then E.capture_values(false)
  elseif kind=='capture_all' then E.capture_values(true)
  elseif kind=='capture_selected' then E.capture_values(true,true)
  elseif kind=='punch' then E.punch_values()
  elseif kind=='punch_preview' then E.punch_values(snapshot(false))
  elseif kind=='match' then E.match()
  elseif kind=='join' then E.join=not E.join
  elseif kind=='clear_capture' then E.capture=nil;E.capture_selected=false
  elseif kind=='scope' or kind=='scope_toggle' then
    if kind=='scope_toggle' then value=E.scope=='all' and 'selected' or 'all' end
    if value=='all' or value=='selected' then E.scope=value;R.SetExtState(APP,'scope',value,true);E.enforce() end
  elseif kind=='items' then E.use_items=not E.use_items;R.SetExtState(APP,'use_items',E.use_items and '1' or '0',true)
  elseif kind=='mode' then
    local mode=tonumber(value)
    if mode and mode>=0 and mode<=5 and mode==math.floor(mode) then
      E.end_punch()
      if E.preview then E.preview_toggle() end
      undo('Set scoped automation mode',function() R.SetGlobalAutomationOverride(-1);for _,tr in ipairs(target_tracks()) do R.SetTrackAutomationMode(tr,mode) end end)
    end
  end
  return true
end
local function state()
  local rows={'version=2.2.4'}
  local function flag(key,value) rows[#rows+1]=key..'='..(value and '1' or '0') end
  for _,key in ipairs(GROUPS) do flag('enabled_'..key,E.enabled[key]) end
  for _,key in ipairs({'start','all','end','punch','next'}) do flag('onstop_'..key,E.onstop[key]) end
  flag('preview',E.preview);flag('capture',E.capture~=nil);flag('punch',E.punch~=nil);flag('join',E.join)
  flag('preview_suspended',E.preview_paused~=nil)
  flag('capture_selected',E.capture~=nil and E.capture_selected)
  flag('suspended',E.suspended_override~=nil);flag('items',E.use_items)
  rows[#rows+1]='scope='..E.scope
  local common,mixed=nil,false
  for _,tr in ipairs(target_tracks()) do
    local mode=R.GetMediaTrackInfo_Value(tr,'I_AUTOMODE')
    if common==nil then common=mode elseif common~=mode then mixed=true end
  end
  rows[#rows+1]='mode='..(common~=nil and not mixed and R.GetGlobalAutomationOverride()==-1 and tostring(math.floor(common)) or '')
  rows[#rows+1]='message='..(R.time_precise()<(E.message_until or 0) and E.message:gsub('[\r\n]',' ') or '')
  R.EA_Native_Publish(table.concat(rows,'\n'))
end
local last_guard=0
local function loop()
  if exiting then return end
  if not native_available() then finish();return end
  local keep=true
  local ok,err=xpcall(function()
    -- Keep commands bounded so a burst of clicks cannot starve REAPER's UI.
    for i=1,32 do
      local text=R.EA_Native_NextCommand()
      if text=='' then break end
      if not command(text) then keep=false;break end
    end
    if keep then
      E.poll()
      E.verify_manual_write()
      if R.time_precise()-last_guard>.05 then E.enforce();last_guard=R.time_precise() end
      state()
    end
  end,debug.traceback)
  if not ok then R.ShowMessageBox(err,'EA Native Automation stopped',0);keep=false end
  if not keep then finish();return end
  R.defer(loop)
end
R.defer(loop)
