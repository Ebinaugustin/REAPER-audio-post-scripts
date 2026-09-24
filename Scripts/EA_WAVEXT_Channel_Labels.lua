-- @description Toggle overlay: WAVEXT labels in selected multichannel media items
-- @version 2.0
-- @about Draws WAVEXT channel names directly over selected item waveform lanes.
-- Requires ReaImGui and js_ReaScriptAPI (as used by TK_Trackname_in_Arrange).
local r = reaper
local SECTION, KEY = "WAVEXT_CHANNEL_LABELS", "overlay_running"
local _, _, section_id, command_id = r.get_action_context()
if r.GetExtState(SECTION, KEY) == "1" then r.SetExtState(SECTION, KEY, "0", false); return end
if not r.ImGui_GetBuiltinPath or not r.JS_Window_FindChildByID then
  r.MB("This overlay requires ReaImGui and js_ReaScriptAPI.", "WAVEXT labels", 0); return
end
package.path = r.ImGui_GetBuiltinPath() .. "/?.lua;" .. package.path
local im = require "imgui" "0.9.3"
local ctx = im.CreateContext("WAVEXT Channel Labels")
local arrange = r.JS_Window_FindChildByID(r.GetMainHwnd(), 0x3E8)
if not arrange then r.MB("Could not locate REAPER's arrange view.", "WAVEXT labels", 0); return end

local names = {[0]="L",[1]="R",[2]="C",[3]="LFE",[4]="Lb",[5]="Rb",[6]="Lc",[7]="Rc",[8]="Cs",[9]="Ls",[10]="Rs",[11]="Tc",[12]="Tfl",[13]="Tfc",[14]="Tfr",[15]="Tbl",[16]="Tbc",[17]="Tbr"}
local function root(src) while src and r.GetMediaSourceParent(src) do src=r.GetMediaSourceParent(src) end return src end
local function as_number(s)
  if not s then return end
  local h=s:match("0[xX]([%x]+)"); if h then return tonumber(h,16) end
  local n=s:match("^%s*([%+%-]?%d+)%s*$"); return n and tonumber(n)
end
local function wavext_mask_from_header(src)
  local path=r.GetMediaSourceFileName(src); local file=path~="" and io.open(path,"rb")
  if not file then return end
  local head=file:read(12)
  if not head or head:sub(1,4)~="RIFF" or head:sub(9,12)~="WAVE" then file:close(); return end
  while true do
    local chunk=file:read(8); if not chunk or #chunk<8 then break end
    local id,size=chunk:sub(1,4),string.unpack("<I4",chunk,5)
    if id=="fmt " then
      local data=file:read(size); file:close()
      if data and #data>=24 and string.unpack("<I2",data)==0xFFFE then return string.unpack("<I4",data,21) end
      return
    end
    file:seek("cur",size+(size%2))
  end
  file:close()
end
local function mask(src)
  local embedded=wavext_mask_from_header(src)
  if embedded and embedded~=0 then return embedded end
  local ok, keys=r.GetMediaFileMetadata(src, "")
  if ok then for key in keys:gmatch("[^\r\n]+") do
    local u=key:upper()
    if u:find("WAVEXT") and (u:find("CHANNEL") or u:find("CONFIG")) then
      local got,value=r.GetMediaFileMetadata(src,key); local m=got and as_number(value); if m then return m end
    end
  end end
  for _,key in ipairs({"WAVEXT:Channel Configuration","WAVEXT:CHANNEL_CONFIG","WAVEXT:CHANNEL_MASK"}) do
    local got,value=r.GetMediaFileMetadata(src,key); local m=got and as_number(value); if m then return m end
  end
end
local function channel_labels(src, count)
  local m=mask(src); if not m or m==0 then return end
  local out={}; for bit=0,31 do if (m & (1 << bit)) ~= 0 then out[#out+1]=names[bit] or ("Ch "..(bit+1)) end end
  return #out==count and out or nil
end
-- Cache the exact location and signed amplitude of the largest sample in each
-- channel. Accessors read the take audio pre-FX, matching the item waveform.
local peak_cache={}
local function peak_points(take, src, channels, item)
  local _, guid=r.GetSetMediaItemTakeInfo_String(take,"GUID","",false)
  if peak_cache[guid] then return peak_cache[guid] end
  local accessor=r.CreateTakeAudioAccessor(take)
  if not accessor then return end
  local rate=r.GetMediaSourceSampleRate(src); if rate<1 then rate=48000 end
  local start=math.max(r.GetAudioAccessorStartTime(accessor),r.GetMediaItemInfo_Value(item,"D_POSITION"))
  local finish=math.min(r.GetAudioAccessorEndTime(accessor),start+r.GetMediaItemInfo_Value(item,"D_LENGTH"))
  local block=8192; local buffer=r.new_array(block*channels); local best={}; local anchor={amp=0,time=start,values={}}
  for ch=1,channels do best[ch]={amp=0,time=start} end
  local at=start
  while at<finish do
    local count=math.min(block,math.max(1,math.floor((finish-at)*rate+.5)))
    if r.GetAudioAccessorSamples(accessor,rate,channels,at,count,buffer)>0 then
      for sample=0,count-1 do
        local sample_max=0
        for ch=1,channels do
          local v=buffer[sample*channels+ch]
          if math.abs(v)>math.abs(best[ch].amp) then best[ch]={amp=v,time=at+sample/rate} end
          sample_max=math.max(sample_max,math.abs(v))
        end
        -- One shared peak time keeps all channel labels aligned as a column.
        if sample_max>anchor.amp then
          anchor.amp=sample_max; anchor.time=at+sample/rate
          for ch=1,channels do anchor.values[ch]=buffer[sample*channels+ch] end
        end
      end
    end
    at=at+count/rate
  end
  r.DestroyAudioAccessor(accessor); peak_cache[guid]={best=best,anchor=anchor}; return peak_cache[guid]
end
local function items()
  local out={}
  for i=0,r.CountSelectedMediaItems(0)-1 do
    local item=r.GetSelectedMediaItem(0,i); local take=r.GetActiveTake(item)
    if take then local src=root(r.GetMediaItemTake_Source(take)); local n=src and r.GetMediaSourceNumChannels(src) or 0
      if n>1 then out[#out+1]={item=item,take=take,src=src,n=n,labels=channel_labels(src,n)} end
    end
  end
  return out
end
local function rgba(rr,gg,bb,aa) return (rr<<24)|(gg<<16)|(bb<<8)|aa end
local font=im.CreateFont("Arial",15); im.Attach(ctx,font)
r.SetExtState(SECTION,KEY,"1",false); r.SetToggleCommandState(section_id,command_id,1)
local function loop()
  if r.GetExtState(SECTION,KEY)~="1" then return end
  local _,nl,nt,nr,nb=r.JS_Window_GetRect(arrange)
  local left,top=im.PointConvertNative(ctx,nl,nt); local right,bottom=im.PointConvertNative(ctx,nr,nb)
  local dpi=r.ImGui_GetWindowDpiScale(ctx); local scroll=15*dpi; local width=right-left-scroll
  local flags=r.ImGui_WindowFlags_NoTitleBar()|r.ImGui_WindowFlags_NoResize()|r.ImGui_WindowFlags_NoMove()|r.ImGui_WindowFlags_NoSavedSettings()|r.ImGui_WindowFlags_NoInputs()|r.ImGui_WindowFlags_NoBackground()
  r.ImGui_SetNextWindowPos(ctx,left,top,r.ImGui_Cond_Always()); r.ImGui_SetNextWindowSize(ctx,math.max(1,width),math.max(1,bottom-top-scroll),r.ImGui_Cond_Always())
  local visible=r.ImGui_Begin(ctx,"WAVEXT Channel Labels",true,flags)
  if visible then
    local draw=r.ImGui_GetWindowDrawList(ctx); local wx,wy=r.ImGui_GetWindowPos(ctx); local start,finish=r.GetSet_ArrangeView2(0,false,0,0)
    r.ImGui_PushFont(ctx,font)
    for _,e in ipairs(items()) do
      local pos=r.GetMediaItemInfo_Value(e.item,"D_POSITION"); local len=r.GetMediaItemInfo_Value(e.item,"D_LENGTH"); local tr=r.GetMediaItem_Track(e.item)
      local y=r.GetMediaTrackInfo_Value(tr,"I_TCPY")/dpi; local h=r.GetMediaTrackInfo_Value(tr,"I_TCPH")/dpi
      local x1=wx+(pos-start)/(finish-start)*width; local x2=wx+(pos+len-start)/(finish-start)*width
      if x2>wx and x1<wx+width and h>=e.n*12 then
        local lane=h/e.n
        local peaks=peak_points(e.take,e.src,e.n,e.item)
        for ch=1,e.n do
          local label=e.labels and e.labels[ch] or ("Ch "..ch)
          local peak=peaks and peaks.best[ch] or {time=pos,amp=0}
          local anchor=peaks and peaks.anchor or peak
          local peak_x=wx+(anchor.time-start)/(finish-start)*width
          local tx=peak_x+6
          -- Keep every label centered in its own lane: waveform amplitude only
          -- chooses the shared horizontal peak location, never its text height.
          local ty=wy+y+(ch-.5)*lane-7
          if peak_x>=wx and peak_x<=wx+width and ty>=wy+y and ty+15<=wy+y+h and ty<=wy+bottom-top-scroll then
            r.ImGui_DrawList_AddText(draw,tx+1.5,ty+1.5,rgba(0,0,0,145),label)
            r.ImGui_DrawList_AddText(draw,tx,ty,e.labels and rgba(255,196,55,230) or rgba(230,115,80,220),label)
          end
        end
      end
    end
    r.ImGui_PopFont(ctx); r.ImGui_End(ctx)
  end
  r.defer(loop)
end
r.atexit(function() r.SetExtState(SECTION,KEY,"0",false); r.SetToggleCommandState(section_id,command_id,0); r.RefreshToolbar2(section_id,command_id) end)
loop()
