-- @description Add WAVEXT speaker layout to selected WAV media files (with backups)
-- @version 1.0
-- @about
--   Select WAV media items, run the script, and choose a layout. The script
--   converts PCM/IEEE-float WAV fmt chunks to WAVEFORMATEXTENSIBLE and writes
--   the selected speaker mask. A .wavext-backup file is created first.

local r = reaper
local layouts = {
  { "Stereo — L R",                         0x00000003 },
  { "5.1 SMPTE — L R C LFE Ls Rs",          0x0000060F },
  { "7.1 — L R C LFE Lb Rb Ls Rs",          0x0000063F },
  { "7.1.2 — L R C LFE Lb Rb Ls Rs Tfl Tfr",0x0000563F },
  { "7.1.4 — L R C LFE Lb Rb Ls Rs Tfl Tfr Tbl Tbr", 0x0002D63F },
}

local function popcount(n)
  local count = 0
  while n ~= 0 do count=count+1; n=n & (n-1) end
  return count
end
local function copy_bytes(src, dst, count)
  while count > 0 do
    local data=src:read(math.min(count, 1024*1024)); if not data then return false end
    dst:write(data); count=count-#data
  end
  return true
end
local function copy_file(from_path, to_path)
  local src=io.open(from_path,"rb"); if not src then return false end
  local dst=io.open(to_path,"wb"); if not dst then src:close(); return false end
  local size=src:seek("end"); src:seek("set",0)
  local ok=copy_bytes(src,dst,size); src:close(); dst:close()
  return ok
end
local function free_name(base)
  local path, n=base, 1
  while true do
    local existing=io.open(path,"rb")
    if not existing then return path end
    existing:close(); path=base.."."..n; n=n+1
  end
end
local function wavext_copy_name(path)
  local stem=path:sub(1,-5); local candidate=stem.." WAVEXT.wav"; local n=2
  while true do
    local existing=io.open(candidate,"rb")
    if not existing then return candidate end
    existing:close(); candidate=stem.." WAVEXT "..n..".wav"; n=n+1
  end
end
local function inspect(path)
  local f=io.open(path,"rb"); if not f then return nil,"Cannot open file" end
  local head=f:read(12)
  if not head or head:sub(1,4)~="RIFF" or head:sub(9,12)~="WAVE" then f:close(); return nil,"Not a RIFF/WAVE file" end
  local riff_size=string.unpack("<I4",head,5)
  while true do
    local chunk=f:read(8); if not chunk or #chunk<8 then break end
    local id,size=chunk:sub(1,4),string.unpack("<I4",chunk,5)
    if id=="fmt " then
      local data=f:read(size); f:close()
      if not data or #data<16 then return nil,"Invalid fmt chunk" end
      local tag,ch,rate,byte_rate,align,bits=string.unpack("<I2I2I4I4I2I2",data)
      if tag~=1 and tag~=3 and tag~=0xFFFE then return nil,"Only PCM or IEEE-float WAV is supported" end
      return {riff_size=riff_size, fmt_size=size, fmt_data=data, tag=tag, channels=ch, rate=rate, byte_rate=byte_rate, align=align, bits=bits}
    end
    f:seek("cur", size+(size%2))
  end
  f:close(); return nil,"No fmt chunk found"
end
local function make_fmt(info, mask)
  local valid_bits, guid=info.bits, nil
  if info.tag==0xFFFE then
    if #info.fmt_data<40 then return nil,"Malformed WAVEFORMATEXTENSIBLE fmt chunk" end
    valid_bits=string.unpack("<I2",info.fmt_data,19)
    guid=info.fmt_data:sub(25,40)
  elseif info.tag==1 then
    guid="\1\0\0\0\0\0\16\0\128\0\0\170\0\56\155\113" -- PCM subtype GUID
  else
    guid="\3\0\0\0\0\0\16\0\128\0\0\170\0\56\155\113" -- IEEE float subtype GUID
  end
  return string.pack("<I2I2I4I4I2I2I2I2I4",0xFFFE,info.channels,info.rate,info.byte_rate,info.align,info.bits,22,valid_bits,mask)..guid
end
local function write_extended(path, info, mask)
  local fmt,err=make_fmt(info,mask); if not fmt then return false,err end
  local old_total=info.fmt_size+(info.fmt_size%2); local delta=40-old_total
  local input=io.open(path,"rb"); if not input then return false,"Cannot reopen source" end
  local temp=free_name(path..".wavext-temp")
  local output=io.open(temp,"wb"); if not output then input:close(); return false,"Cannot create temporary file" end
  local head=input:read(12)
  output:write("RIFF",string.pack("<I4",info.riff_size+delta),"WAVE")
  local replaced=false
  while true do
    local chunk=input:read(8); if not chunk or #chunk<8 then break end
    local id,size=chunk:sub(1,4),string.unpack("<I4",chunk,5)
    if id=="fmt " and not replaced then
      input:seek("cur",size+(size%2)); output:write("fmt ",string.pack("<I4",40),fmt); replaced=true
    else
      output:write(chunk)
      if not copy_bytes(input,output,size+(size%2)) then input:close(); output:close(); os.remove(temp); return false,"Unexpected end of file" end
    end
  end
  input:close(); output:close()
  if not replaced then os.remove(temp); return false,"No fmt chunk found while writing" end
  -- REAPER can keep selected source files open on Windows, which prevents a
  -- rename even when read/write access is allowed. Copy, then overwrite in place.
  local backup=free_name(path..".wavext-backup")
  if not copy_file(path,backup) then os.remove(temp); return false,"Could not create backup" end
  if not copy_file(temp,path) then
    -- Fall back to a new file when REAPER/OneDrive has the source locked.
    local replacement=wavext_copy_name(path)
    if not copy_file(temp,replacement) then os.remove(temp); return false,"Could not overwrite source or create replacement (backup is intact)" end
    os.remove(temp); return true,replacement,true
  end
  os.remove(temp)
  return true,path,false
end

local function apply_mask(mask)
local wanted_channels=popcount(mask)
local files,seen={},{}
for i=0,r.CountSelectedMediaItems(0)-1 do
  local take=r.GetActiveTake(r.GetSelectedMediaItem(0,i))
  if take then
    local src=r.GetMediaItemTake_Source(take); while r.GetMediaSourceParent(src) do src=r.GetMediaSourceParent(src) end
    local path=r.GetMediaSourceFileName(src)
    if path:lower():match("%.wav$") then
      if not seen[path] then seen[path]={path=path,source=src,takes={}}; files[#files+1]=seen[path] end
      seen[path].takes[#seen[path].takes+1]=take
    end
  end
end
if #files==0 then return "Select one or more WAV media items." end
local changed,problems=0,{}
-- SWS releases the actual file handle, letting Windows update the same source
-- file instead of forcing an alternate copy. (Used only when available.)
local can_release = r.CF_SetMediaSourceOnline ~= nil
if can_release then
  for _,entry in ipairs(files) do r.CF_SetMediaSourceOnline(entry.source,false) end
  r.UpdateArrange()
end
for _,entry in ipairs(files) do
  local path=entry.path
  local info,err=inspect(path)
  if not info then problems[#problems+1]=path.." — "..err
  elseif info.channels~=wanted_channels then problems[#problems+1]=path.." — has "..info.channels.." channels, mask has "..wanted_channels
  else
    local success,message,used_copy=write_extended(path,info,mask)
    if success then
      changed=changed+1
      if used_copy then
        local new_source=r.PCM_Source_CreateFromFile(message)
        if new_source then for _,take in ipairs(entry.takes) do r.SetMediaItemTake_Source(take,new_source) end end
        problems[#problems+1]=path.." — source was locked; selected item(s) now use "..message
      end
    else problems[#problems+1]=path.." — "..message end
  end
end
if can_release then
  for _,entry in ipairs(files) do r.CF_SetMediaSourceOnline(entry.source,true) end
end
r.UpdateArrange()
local report="WAVEXT added to "..changed.." file(s)."
if #problems>0 then report=report.."\n\nNotes / skipped / failed:\n"..table.concat(problems,"\n") end
return report
end

if not r.ImGui_GetBuiltinPath then r.MB("ReaImGui is required for this panel.","WAVEXT adder",0); return end
package.path=r.ImGui_GetBuiltinPath().."/?.lua;"..package.path
local im=require "imgui" "0.9.3"; local ctx=im.CreateContext("WAVEXT Channel Layout Adder")
local presets={
  {"Stereo",0x3,"L  R"},
  {"5.1 — SMPTE / ITU-R BS.775",0x60F,"L  R  C  LFE  Ls  Rs"},
  {"5.1 — Pro Tools WAV export",0x60F,"L  R  C  LFE  Ls  Rs"},
  {"7.1 — SMPTE / ITU",0x63F,"L  R  C  LFE  Lb  Rb  Ls  Rs"},
  {"7.1 — Pro Tools BWF/WAVEXT export",0x63F,"L  R  C  LFE  Lb  Rb  Ls  Rs"},
  {"Dolby Atmos bed 5.1.2",0x560F,"L  R  C  LFE  Ls  Rs  Tfl  Tfr"},
  {"Dolby Atmos bed 5.1.4",0x2D60F,"L  R  C  LFE  Ls  Rs  Tfl  Tfr  Tbl  Tbr"},
  {"Dolby Atmos bed 7.1.2",0x563F,"L  R  C  LFE  Lb  Rb  Ls  Rs  Tfl  Tfr"},
  {"Dolby Atmos bed 7.1.4",0x2D63F,"L  R  C  LFE  Lb  Rb  Ls  Rs  Tfl  Tfr  Tbl  Tbr"},
}
local selected,custom,status=2,"", "Select a layout, then click Apply to selected WAV items."
local function loop()
  r.ImGui_SetNextWindowSize(ctx,620,430,r.ImGui_Cond_FirstUseEver())
  local visible,open=r.ImGui_Begin(ctx,"WAVEXT Channel Layout Adder",true)
  if visible then
    r.ImGui_Text(ctx,"Embed a standard WAVEFORMATEXTENSIBLE speaker mask")
    r.ImGui_Separator(ctx)
    for i,p in ipairs(presets) do
      if r.ImGui_Selectable(ctx,p[1],selected==i) then selected=i; custom="" end
      if r.ImGui_IsItemHovered(ctx) then r.ImGui_SetTooltip(ctx,p[3].."\nMask: 0x"..string.format("%X",p[2])) end
    end
    r.ImGui_Separator(ctx)
    local changed; changed,custom=r.ImGui_InputText(ctx,"Custom mask (hex)",custom)
    if changed and custom~="" then selected=0 end
    if selected>0 then r.ImGui_TextColored(ctx,0x55DDAAFF,"Channels: "..popcount(presets[selected][2]).."   "..presets[selected][3]) end
    r.ImGui_TextWrapped(ctx,"Film/Dolby film-order permutations cannot be represented by WAVEXT: its channel order is fixed by mask bit significance. Pro Tools export presets above use the compatible BWF/WAVEXT order. Dolby Atmos ADM objects require ADM axml metadata, not WAVEXT.")
    r.ImGui_TextColored(ctx,0xFFB060FF,"9.0.4, 9.1.4 and 9.1.6 are intentionally not writable presets: they require Wide speaker positions, which have no standard WAVEXT channel-mask bits.")
    r.ImGui_Separator(ctx)
    if r.ImGui_Button(ctx,"Apply to selected WAV files",230,32) then
      local mask=selected>0 and presets[selected][2] or nil
      if not mask then local h=custom:match("0[xX]([%x]+)") or custom:match("^([%x]+)$"); mask=h and tonumber(h,16) end
      status=(mask and mask>0) and apply_mask(mask) or "Enter a valid non-zero hexadecimal mask."
    end
    r.ImGui_SameLine(ctx); if r.ImGui_Button(ctx,"Close",90,32) then open=false end
    r.ImGui_Separator(ctx); r.ImGui_TextWrapped(ctx,status)
    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) end
end
loop()
