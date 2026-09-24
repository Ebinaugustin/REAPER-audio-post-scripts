-- @description SurroundScope Multimeter Dashboard (ReaImGui)
-- @version 1.5.0
-- @author Codex
-- @about
--   SuperVision-style multichannel meter dashboard for the paired
--   SurroundScope Multimeter Analyzer.jsfx.  Insert the JSFX on the audio
--   path, set both scripts to the same Analyzer Slot, then run this script.
--
--   This script requires ReaImGui. It reads the JSFX's gmem page only; it
--   does not alter audio, routing, automation, or project state.

local r = reaper

if not r.ImGui_CreateContext then
  r.MB('This dashboard needs the ReaImGui extension.\n\nInstall ReaImGui with ReaPack, then run the script again.', 'SurroundScope Multimeter', 0)
  return
end

local ctx = r.ImGui_CreateContext('SurroundScope Multimeter')
r.gmem_attach('SurroundScopeMultimeter')

local MAX_CHANNELS = 64
local WAVE_POINTS = 512
local WAVE_CHANNELS = 24
local SPECTRUM_BANDS = 48
local SLOT_SIZE = 14000
local MAGIC = 20260922
local STAT_BASE = 64
local STAT_STRIDE = 5
local WAVE_BASE = 512
local SPECTRUM_BASE = 13500

local C = {
  bg = 0x11171CFF, panel = 0x182128FF, panel2 = 0x202B33FF,
  line = 0x40515CFF, text = 0xE2ECF2FF, subdued = 0x93A5B0FF,
  cyan = 0x36BDEBFF, blue = 0x4C8DFFFF, green = 0x46D67AFF,
  yellow = 0xF5C84AFF, orange = 0xF18C42FF, red = 0xF25555FF,
  grid = 0x314049FF, waveform = 0xC187EDFF,
  wave_bg_top = 0x18212BFF, wave_bg_bottom = 0x0C1118FF,
  wave_grid = 0x9E6BDC18, wave_outer = 0x7442AB42,
  wave_mid = 0xA864DC8E, wave_core = 0xDDB9F6D6,
  playhead = 0xFFF6FFFF, playhead_halo = 0xD8BDFF48,
}

local state = {
  slot = 1,
  channel_order = 0, -- 0 = ITU, 1 = Film, 2 = SMPTE
  channel_format = 0, -- Auto, Stereo, 5.1, 7.1, 7.1.4
  meter_preset = 0, -- ITU, Film, SMPTE reference scales
  horizontal_meters = false,
  show_rms = true,
  vertical_waveform = false,
  peak_hold = true,
  loud_history = {},
  last_sequence = -1,
  last_wave_sequence = -1,
  wave_arrival = 0,
  wave_fraction = 0,
  transport_running = false,
  frozen_wave = nil,
  wave_theme = 1,
  wave_gradients = true,
  meter_response = 300,
  spectrum_smoothing = 3,
  spectrum_hold = 3,
  spectrum_holds = {},
  active_module = 1,
}

local order_names = { 'ITU', 'Film', 'SMPTE' }
local format_names = { 'Auto', 'Stereo', '5.1', '7.1', '7.1.4' }
local meter_names = { 'ITU EBU', 'Film', 'SMPTE' }
local module_names = { 'Meters', 'Waveform', 'Spectrum', 'Loudness', 'Scope', 'Details' }
local spectrum_smoothing_names = { 'Off', '1/24 oct', '1/12 oct', '1/6 oct', '1/3 oct', '1 oct' }
local spectrum_smoothing_radius = { 0, 0, 1, 2, 3, 5 }
local spectrum_hold_names = { 'Off', '1 s', '3 s', '5 s', '10 s', '30 s' }
local spectrum_hold_seconds = { 0, 1, 3, 5, 10, 30 }
local wave_themes = {
  { name = 'Violet', outer = 0x7442AB42, mid = 0xA864DC8E, core = 0xDDB9F6D6, flat = 0xBA79E3CE },
  { name = 'Ocean', outer = 0x2166A942, mid = 0x3D9DDF8E, core = 0xB8E9FFD6, flat = 0x52B4EECE },
  { name = 'Emerald', outer = 0x187A6042, mid = 0x3ABF858E, core = 0xB5F7D6D6, flat = 0x51D79CCE },
  { name = 'Amber', outer = 0x9B632A42, mid = 0xD29A498E, core = 0xFFE6B8D6, flat = 0xE4AD57CE },
  { name = 'Rose', outer = 0x96476642, mid = 0xD76E9A8E, core = 0xFFD0E2D6, flat = 0xE98AB2CE },
}

local channel_maps = {
  ITU = {
    [2] = {'L', 'R'},
    [6] = {'L', 'R', 'C', 'LFE', 'Ls', 'Rs'},
    [8] = {'L', 'R', 'C', 'LFE', 'Ls', 'Rs', 'Lrs', 'Rrs'},
    [12] = {'L', 'R', 'C', 'LFE', 'Ls', 'Rs', 'Lrs', 'Rrs', 'Ltf', 'Rtf', 'Ltr', 'Rtr'},
  },
  Film = {
    [2] = {'L', 'R'},
    [6] = {'L', 'C', 'R', 'Ls', 'Rs', 'LFE'},
    [8] = {'L', 'C', 'R', 'Ls', 'Rs', 'Lrs', 'Rrs', 'LFE'},
    [12] = {'L', 'C', 'R', 'Ls', 'Rs', 'Lrs', 'Rrs', 'LFE', 'Ltf', 'Rtf', 'Ltr', 'Rtr'},
  },
  SMPTE = {
    [2] = {'L', 'R'},
    [6] = {'L', 'R', 'C', 'LFE', 'Ls', 'Rs'},
    [8] = {'L', 'R', 'C', 'LFE', 'Ls', 'Rs', 'Lrs', 'Rrs'},
    [12] = {'L', 'R', 'C', 'LFE', 'Ls', 'Rs', 'Lrs', 'Rrs', 'Ltf', 'Rtf', 'Ltr', 'Rtr'},
  },
}

local function clamp(value, low, high)
  return math.min(high, math.max(low, value))
end

local function round(value)
  return math.floor(value + 0.5)
end

local function db_text(value)
  if not value or value <= -119.95 then return '-inf' end
  return string.format('%.1f', value)
end

local function metric_text(value, suffix)
  return db_text(value) .. (suffix or ' dB')
end

local function preset()
  if state.meter_preset == 0 then
    return { floor = -60, reference = -23, warning = -9, danger = -1, unit = 'LUFS / dBFS' }
  elseif state.meter_preset == 1 then
    return { floor = -60, reference = -20, warning = -6, danger = -2, unit = 'dBFS (Film)' }
  end
  return { floor = -60, reference = -20, warning = -6, danger = -1, unit = 'dBFS (SMPTE)' }
end

local function value_color(value, p)
  if value >= p.danger then return C.red end
  if value >= p.warning then return C.yellow end
  if value >= p.reference then return C.green end
  return C.cyan
end

local function selected_channels(actual_count)
  if state.channel_format == 1 then return 2 end
  if state.channel_format == 2 then return 6 end
  if state.channel_format == 3 then return 8 end
  if state.channel_format == 4 then return 12 end
  return actual_count
end

local function labels_for(actual_count)
  local count = selected_channels(actual_count)
  local mode = order_names[state.channel_order + 1]
  local source = channel_maps[mode][count] or {}
  local labels = {}
  for i = 1, count do labels[i] = source[i] or ('Ch ' .. i) end
  return labels, count
end

local function read_data()
  local base = (state.slot - 1) * SLOT_SIZE
  local data = { online = r.gmem_read(base) == MAGIC, channels = 0, spectrum = {}, wave = {}, stats = {} }
  if not data.online then return data end

  data.sequence = r.gmem_read(base + 1)
  data.channels = clamp(round(r.gmem_read(base + 2)), 1, MAX_CHANNELS)
  data.srate = r.gmem_read(base + 3)
  data.wave_write = clamp(round(r.gmem_read(base + 4)), 0, WAVE_POINTS - 1)
  data.peak = r.gmem_read(base + 5)
  data.rms = r.gmem_read(base + 6)
  data.momentary = r.gmem_read(base + 7)
  data.short_term = r.gmem_read(base + 8)
  data.integrated = r.gmem_read(base + 9)
  data.correlation = clamp(r.gmem_read(base + 10), -1, 1)
  data.crest = r.gmem_read(base + 11)
  data.wave_sequence = r.gmem_read(base + 13)
  data.wave_rate = clamp(round(r.gmem_read(base + 14)), 1, 1000)
  data.wave_channels = clamp(round(r.gmem_read(base + 15)), 0, WAVE_CHANNELS)
  local response_value = round(r.gmem_read(base + 16))
  data.meter_response = response_value > 0 and clamp(response_value, 10, 2000) or nil

  for channel = 1, data.channels do
    local address = base + STAT_BASE + (channel - 1) * STAT_STRIDE
    data.stats[channel] = {
      peak = r.gmem_read(address), rms = r.gmem_read(address + 1),
      hold = r.gmem_read(address + 2), crest = r.gmem_read(address + 3),
      sample_peak = r.gmem_read(address + 4),
    }
    if channel <= data.wave_channels then
      data.wave[channel] = {}
      local wave_base = base + WAVE_BASE + (channel - 1) * WAVE_POINTS
      for point = 1, WAVE_POINTS do data.wave[channel][point] = r.gmem_read(wave_base + point - 1) end
    end
  end
  for band = 1, SPECTRUM_BANDS do data.spectrum[band] = r.gmem_read(base + SPECTRUM_BASE + band - 1) end
  return data
end

local function update_history(data)
  if not data.online or data.sequence == state.last_sequence then return end
  state.last_sequence = data.sequence
  table.insert(state.loud_history, data.momentary)
  if #state.loud_history > 360 then table.remove(state.loud_history, 1) end
end

local function draw_panel(label, height)
  -- Keep module pages on the parent window. This avoids child-window stack
  -- differences across ReaImGui releases while preserving the full canvas.
  return true
end

local function end_panel()
  -- See draw_panel: there is no nested child window to close.
end

-- ReaImGui exposes draw-list operations as ReaScript functions rather than
-- object methods.  This small adapter keeps the view code below readable.
local function get_draw_list()
  local raw = r.ImGui_GetWindowDrawList(ctx)
  return {
    AddLine = function(_, ...) r.ImGui_DrawList_AddLine(raw, ...) end,
    AddRect = function(_, ...) r.ImGui_DrawList_AddRect(raw, ...) end,
    AddRectFilled = function(_, ...) r.ImGui_DrawList_AddRectFilled(raw, ...) end,
    AddRectFilledMultiColor = function(_, ...) r.ImGui_DrawList_AddRectFilledMultiColor(raw, ...) end,
    AddQuadFilled = function(_, ...) r.ImGui_DrawList_AddQuadFilled(raw, ...) end,
    AddCircle = function(_, ...) r.ImGui_DrawList_AddCircle(raw, ...) end,
    AddCircleFilled = function(_, ...) r.ImGui_DrawList_AddCircleFilled(raw, ...) end,
    AddText = function(_, ...) r.ImGui_DrawList_AddText(raw, ...) end,
    AddPolyline = function(_, points, color, flags, thickness)
      -- ReaImGui accepts a reaper_array here, not a standard Lua sequence.
      r.ImGui_DrawList_AddPolyline(raw, r.new_array(points), color, flags, thickness)
    end,
  }
end

local function draw_header(data)
  local p = preset()
  r.ImGui_TextColored(ctx, C.cyan, 'SURROUNDSCOPE MULTIMETER')
  if data.online then
    r.ImGui_TextColored(ctx, C.green, string.format('LIVE  •  %d ch  •  %.0f Hz', data.channels, data.srate))
  else
    r.ImGui_TextColored(ctx, C.orange, 'WAITING FOR ANALYZER')
  end

  if r.ImGui_CollapsingHeader(ctx, 'Options') then
  -- Fixed-size stepper controls scale cleanly and do not overflow a narrow UI.
  r.ImGui_TextDisabled(ctx, 'Analyzer Slot')
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '-##slot') then state.slot = math.max(1, state.slot - 1) end
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, tostring(state.slot))
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '+##slot') then state.slot = math.min(32, state.slot + 1) end

  r.ImGui_TextDisabled(ctx, 'Channel order')
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '-##order') then state.channel_order = (state.channel_order + #order_names - 1) % #order_names end
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, order_names[state.channel_order + 1])
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '+##order') then state.channel_order = (state.channel_order + 1) % #order_names end

  r.ImGui_TextDisabled(ctx, 'Channel format')
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '-##format') then state.channel_format = (state.channel_format + #format_names - 1) % #format_names end
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, format_names[state.channel_format + 1])
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '+##format') then state.channel_format = (state.channel_format + 1) % #format_names end

  r.ImGui_TextDisabled(ctx, 'Meter scale')
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '-##scale') then state.meter_preset = (state.meter_preset + #meter_names - 1) % #meter_names end
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, meter_names[state.meter_preset + 1])
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '+##scale') then state.meter_preset = (state.meter_preset + 1) % #meter_names end

  local changed
  changed, state.horizontal_meters = r.ImGui_Checkbox(ctx, 'Horizontal meters', state.horizontal_meters)
  r.ImGui_SameLine(ctx)
  changed, state.vertical_waveform = r.ImGui_Checkbox(ctx, 'Vertical waveform', state.vertical_waveform)
  r.ImGui_SameLine(ctx)
  changed, state.peak_hold = r.ImGui_Checkbox(ctx, 'Peak hold', state.peak_hold)

  if data.online and data.meter_response then state.meter_response = data.meter_response end
  r.ImGui_TextDisabled(ctx, 'Meter response / fall')
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '-##response') then state.meter_response = clamp(state.meter_response - 25, 10, 2000) end
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, string.format('%d ms', state.meter_response))
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '+##response') then state.meter_response = clamp(state.meter_response + 25, 10, 2000) end
  if data.online then r.gmem_write((state.slot - 1) * SLOT_SIZE + 16, state.meter_response) end

  if r.ImGui_Button(ctx, 'Reset analyzer meters') then
    r.gmem_write((state.slot - 1) * SLOT_SIZE + 12, r.time_precise())
    state.loud_history = {}
  end
  r.ImGui_TextDisabled(ctx, 'Scale: ' .. p.unit .. '  •  Input channel order is labelled only; audio is never reordered.')
  end
end

local function draw_meter_value(dl, x1, y1, x2, y2, value, p, vertical)
  local normal = clamp((value - p.floor) / -p.floor, 0, 1)
  if vertical then
    local top = y2 - (y2 - y1) * normal
    dl:AddRectFilled(x1, y1, x2, y2, C.bg, 2)
    if normal > 0 then dl:AddRectFilled(x1 + 2, top, x2 - 2, y2 - 2, value_color(value, p), 1) end
    for mark = math.ceil(p.floor / 12) * 12, 0, 12 do
      local y = y2 - (y2 - y1) * clamp((mark - p.floor) / -p.floor, 0, 1)
      dl:AddLine(x1, y, x2, y, C.grid, 1)
    end
  else
    local right = x1 + (x2 - x1) * normal
    dl:AddRectFilled(x1, y1, x2, y2, C.bg, 2)
    if normal > 0 then dl:AddRectFilled(x1 + 2, y1 + 2, right, y2 - 2, value_color(value, p), 1) end
    for mark = math.ceil(p.floor / 12) * 12, 0, 12 do
      local x = x1 + (x2 - x1) * clamp((mark - p.floor) / -p.floor, 0, 1)
      dl:AddLine(x, y1, x, y2, C.grid, 1)
    end
  end
  dl:AddRect(x1, y1, x2, y2, C.line, 2)
end

local function draw_rms_overlay(dl, x1, y1, x2, y2, value, p, vertical)
  local normal = clamp((value - p.floor) / -p.floor, 0, 1)
  if normal <= 0 then return end
  if vertical then
    local top = y2 - (y2 - y1) * normal
    local inset = math.max(3, (x2 - x1) * 0.25)
    dl:AddRectFilled(x1 + inset, top, x2 - inset, y2 - 2, C.blue, 1)
  else
    local right = x1 + (x2 - x1) * normal
    local inset = math.max(3, (y2 - y1) * 0.28)
    dl:AddRectFilled(x1 + 2, y1 + inset, right, y2 - inset, C.blue, 1)
  end
end

local function draw_channel_meters(data)
  local labels, requested_count = labels_for(data.channels)
  local count = math.min(requested_count, data.channels)
  local p = preset()
  r.ImGui_Text(ctx, 'CHANNEL PEAK / RMS')
  r.ImGui_SameLine(ctx)
  r.ImGui_TextDisabled(ctx, string.format('%s layout • %s scale', order_names[state.channel_order + 1], meter_names[state.meter_preset + 1]))
  local changed
  changed, state.show_rms = r.ImGui_Checkbox(ctx, 'Show RMS (blue inner meter)', state.show_rms)
  local avail_w, avail_h = r.ImGui_GetContentRegionAvail(ctx)
  r.ImGui_InvisibleButton(ctx, '##channel_meters', avail_w, math.max(170, avail_h - 5))
  local x0, y0 = r.ImGui_GetItemRectMin(ctx)
  local x2, y2 = r.ImGui_GetItemRectMax(ctx)
  local dl = get_draw_list()

  if not data.online then
    dl:AddText(x0 + 14, y0 + 14, C.orange, 'Insert “SurroundScope Multimeter Analyzer” JSFX, then select the matching Analyzer Slot.')
    return
  end
  if requested_count > data.channels then
    dl:AddText(x0 + 14, y0 + 14, C.orange, string.format('%s selected, but the analyzer currently receives %d channel(s).', format_names[state.channel_format + 1], data.channels))
  end

  if state.horizontal_meters then
    local row_h = math.max(22, math.min(42, (y2 - y0 - 20) / count))
    local label_w = 52
    local value_w = 54
    for ch = 1, count do
      local top = y0 + 18 + (ch - 1) * row_h
      local stat = data.stats[ch]
      dl:AddText(x0 + 5, top + 4, C.text, labels[ch])
      draw_meter_value(dl, x0 + label_w, top, x2 - value_w, top + row_h - 5, stat.peak, p, false)
      if state.show_rms then draw_rms_overlay(dl, x0 + label_w, top, x2 - value_w, top + row_h - 5, stat.rms, p, false) end
      if state.peak_hold then
        local held = clamp((stat.hold - p.floor) / -p.floor, 0, 1)
        local hx = x0 + label_w + (x2 - value_w - x0 - label_w) * held
        dl:AddLine(hx, top + 1, hx, top + row_h - 6, C.red, 2)
      end
      dl:AddText(x2 - value_w + 5, top + 4, value_color(stat.peak, p), db_text(stat.peak))
    end
  else
    local gap = 9
    local usable_w = x2 - x0 - gap * (count - 1)
    local meter_w = math.max(17, usable_w / count)
    local label_y = y2 - 23
    for ch = 1, count do
      local left = x0 + (ch - 1) * (meter_w + gap)
      local stat = data.stats[ch]
      draw_meter_value(dl, left, y0 + 19, left + meter_w, label_y - 5, stat.peak, p, true)
      if state.show_rms then draw_rms_overlay(dl, left, y0 + 19, left + meter_w, label_y - 5, stat.rms, p, true) end
      if state.peak_hold then
        local held = clamp((stat.hold - p.floor) / -p.floor, 0, 1)
        local hy = label_y - 5 - (label_y - 5 - y0 - 19) * held
        dl:AddLine(left + 2, hy, left + meter_w - 2, hy, C.red, 2)
      end
      dl:AddText(left + 2, y0 + 2, value_color(stat.peak, p), db_text(stat.peak))
      dl:AddText(left + 2, label_y, C.text, labels[ch])
    end
  end
end

local function waveform_point(data, channel, point)
  -- old-to-new order, because the JSFX writes into a circular buffer
  if not data.wave[channel] then return 0 end
  local stored_index = ((data.wave_write + point - 1) % WAVE_POINTS) + 1
  return data.wave[channel][stored_index] or 0
end

local function smoothed_wave_point(data, channel, position)
  -- A five-tap binomial filter turns the captured peak envelope into a
  -- visually continuous waveform while retaining its overall dynamics.
  local centre = clamp(math.floor(position + 0.5), 1, WAVE_POINTS)
  local function sample(offset)
    return waveform_point(data, channel, clamp(centre + offset, 1, WAVE_POINTS))
  end
  return clamp((sample(-2) + sample(2) + 4 * (sample(-1) + sample(1)) + 6 * sample(0)) / 16, 0, 1)
end

local function draw_horizontal_envelope(dl, x1, x2, centre, amplitude1, amplitude2, palette)
  local function layer(scale, color)
    local a1, a2 = amplitude1 * scale, amplitude2 * scale
    dl:AddQuadFilled(x1, centre - a1, x1, centre + a1, x2, centre + a2, x2, centre - a2, color)
  end
  if state.wave_gradients then
    layer(1.00, palette.outer)
    layer(0.70, palette.mid)
    layer(0.28, palette.core)
  else
    layer(1.00, palette.flat)
  end
end

local function draw_vertical_envelope(dl, y1, y2, centre, amplitude1, amplitude2, palette)
  local function layer(scale, color)
    local a1, a2 = amplitude1 * scale, amplitude2 * scale
    dl:AddQuadFilled(centre - a1, y1, centre + a1, y1, centre + a2, y2, centre - a2, y2, color)
  end
  if state.wave_gradients then
    layer(1.00, palette.outer)
    layer(0.70, palette.mid)
    layer(0.28, palette.core)
  else
    layer(1.00, palette.flat)
  end
end

local function wave_scroll_fraction(data, transport_running)
  if not transport_running then return state.wave_fraction end
  if data.wave_sequence ~= state.last_wave_sequence then
    state.last_wave_sequence = data.wave_sequence
    state.wave_arrival = r.time_precise()
  end
  state.wave_fraction = clamp((r.time_precise() - state.wave_arrival) * data.wave_rate, 0, 1)
  return state.wave_fraction
end

local function waveform_for_transport(data)
  local transport_running = (r.GetPlayState() & 5) ~= 0
  if transport_running then
    state.transport_running = true
    state.frozen_wave = nil
    return data, true
  end
  if state.transport_running then
    state.frozen_wave = { wave = data.wave, wave_write = data.wave_write, wave_rate = data.wave_rate }
    state.transport_running = false
  end
  return state.frozen_wave or data, false
end

local function draw_waveform(data)
  local labels, requested_count = labels_for(data.channels)
  local count = math.min(requested_count, data.channels, WAVE_CHANNELS)
  r.ImGui_Text(ctx, state.vertical_waveform and 'VERTICAL SCROLLING WAVEFORM' or 'SCROLLING WAVEFORM')
  r.ImGui_SameLine(ctx)
  r.ImGui_TextDisabled(ctx, 'centred playhead • smooth rolling envelope')
  r.ImGui_TextDisabled(ctx, 'Wave colour')
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '-##wave_theme') then state.wave_theme = (state.wave_theme + #wave_themes - 2) % #wave_themes + 1 end
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, wave_themes[state.wave_theme].name)
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '+##wave_theme') then state.wave_theme = state.wave_theme % #wave_themes + 1 end
  r.ImGui_SameLine(ctx)
  local changed
  changed, state.wave_gradients = r.ImGui_Checkbox(ctx, 'Gradients', state.wave_gradients)
  local avail_w, avail_h = r.ImGui_GetContentRegionAvail(ctx)
  r.ImGui_InvisibleButton(ctx, '##waveform', avail_w, math.max(180, avail_h - 5))
  local x0, y0 = r.ImGui_GetItemRectMin(ctx)
  local x2, y2 = r.ImGui_GetItemRectMax(ctx)
  local dl = get_draw_list()
  if not data.online then
    dl:AddText(x0 + 14, y0 + 14, C.orange, 'Waveform capture will appear when the analyzer is online.')
    return
  end
  if data.wave_channels == 0 then
    dl:AddText(x0 + 14, y0 + 14, C.orange, 'Waiting for the analyzer waveform buffer.')
    return
  end

  local wave_data, transport_running = waveform_for_transport(data)
  local fraction = wave_scroll_fraction(wave_data, transport_running)
  local seconds = WAVE_POINTS / wave_data.wave_rate
  local palette = wave_themes[state.wave_theme]

  if state.vertical_waveform then
    local column_w = (x2 - x0) / count
    local drawn_points = math.min(WAVE_POINTS, math.max(96, math.floor((y2 - y0) / 2.5)))
    for ch = 1, count do
      local left, right = x0 + (ch - 1) * column_w + 3, x0 + ch * column_w - 3
      local top, bottom = y0 + 18, y2 - 2
      dl:AddRectFilledMultiColor(left, top, right, bottom, C.wave_bg_top, C.wave_bg_top, C.wave_bg_bottom, C.wave_bg_bottom)
      local center = (left + right) / 2
      dl:AddLine(center, top, center, bottom, C.grid, 1)
      dl:AddText(left + 3, y0 + 2, C.text, labels[ch])
      for division = 1, 7 do
        local y = top + division / 8 * (bottom - top)
        dl:AddLine(left, y, right, y, C.wave_grid, 1)
      end
      local previous = smoothed_wave_point(wave_data, ch, 1) * (right - left) * 0.46
      for pixel = 1, drawn_points - 1 do
        local position = pixel / (drawn_points - 1) * (WAVE_POINTS - 1) + 1
        local current = smoothed_wave_point(wave_data, ch, position) * (right - left) * 0.46
        local y1 = top + (pixel - 1 - fraction) / (drawn_points - 1) * (bottom - top)
        local y2 = top + (pixel - fraction) / (drawn_points - 1) * (bottom - top)
        draw_vertical_envelope(dl, y1, y2, center, previous, current, palette)
        previous = current
      end
      local playhead = (top + bottom) / 2
      dl:AddLine(left, playhead - 1, right, playhead - 1, C.playhead_halo, 3)
      dl:AddLine(left, playhead, right, playhead, C.playhead, 1.5)
    end
    dl:AddText(x0 + 6, y0 + 2, C.subdued, string.format('%.1f s', seconds))
  else
    local row_h = (y2 - y0 - 3) / count
    local left_edge, right_edge = x0 + 33, x2 - 2
    local drawn_points = math.min(WAVE_POINTS, math.max(96, math.floor((right_edge - left_edge) / 2.5)))
    for ch = 1, count do
      local top, bottom = y0 + (ch - 1) * row_h + 2, y0 + ch * row_h - 2
      dl:AddRectFilledMultiColor(left_edge, top, right_edge, bottom, C.wave_bg_top, C.wave_bg_top, C.wave_bg_bottom, C.wave_bg_bottom)
      local center = (top + bottom) / 2
      dl:AddLine(left_edge, center, right_edge, center, C.grid, 1)
      dl:AddText(x0 + 2, center - 7, C.text, labels[ch])
      for division = 1, 7 do
        local x = left_edge + division / 8 * (right_edge - left_edge)
        dl:AddLine(x, top, x, bottom, C.wave_grid, 1)
      end
      local previous = smoothed_wave_point(wave_data, ch, 1) * (bottom - top) * 0.46
      for pixel = 1, drawn_points - 1 do
        local position = pixel / (drawn_points - 1) * (WAVE_POINTS - 1) + 1
        local current = smoothed_wave_point(wave_data, ch, position) * (bottom - top) * 0.46
        local x1 = left_edge + (pixel - 1 - fraction) / (drawn_points - 1) * (right_edge - left_edge)
        local x2 = left_edge + (pixel - fraction) / (drawn_points - 1) * (right_edge - left_edge)
        draw_horizontal_envelope(dl, x1, x2, center, previous, current, palette)
        previous = current
      end
      local playhead = (left_edge + right_edge) / 2
      dl:AddLine(playhead - 1, top, playhead - 1, bottom, C.playhead_halo, 3)
      dl:AddLine(playhead, top, playhead, bottom, C.playhead, 1.5)
    end
    dl:AddText(x0 + 38, y0 + 4, C.subdued, string.format('%.1f s visual buffer', seconds))
  end
end

local function smoothed_spectrum_value(data, band)
  local radius = spectrum_smoothing_radius[state.spectrum_smoothing]
  if radius == 0 then return clamp(data.spectrum[band] or -120, -120, 0) end
  local sum, count = 0, 0
  for neighbour = math.max(1, band - radius), math.min(SPECTRUM_BANDS, band + radius) do
    local value = clamp(data.spectrum[neighbour] or -120, -120, 0)
    sum = sum + 10 ^ (value / 10)
    count = count + 1
  end
  return clamp(10 * math.log(sum / math.max(1, count)) / math.log(10), -120, 0)
end

local function spectrum_frequency(band)
  return 20 * 1000 ^ ((band - 1) / (SPECTRUM_BANDS - 1))
end

local function frequency_text(frequency)
  return frequency >= 1000 and string.format('%.2f kHz', frequency / 1000) or string.format('%.0f Hz', frequency)
end

local function update_spectrum_holds(values)
  local now = r.time_precise()
  local duration = spectrum_hold_seconds[state.spectrum_hold]
  local holds = {}
  for band = 1, SPECTRUM_BANDS do
    local held = state.spectrum_holds[band] or { value = -120, time = now }
    if duration == 0 then
      held.value, held.time = values[band], now
    elseif values[band] >= held.value then
      held.value, held.time = values[band], now
    elseif now - held.time >= duration then
      held.value, held.time = values[band], now
    end
    state.spectrum_holds[band] = held
    holds[band] = held.value
  end
  return holds
end

local function draw_spectrum(data)
  r.ImGui_Text(ctx, 'SPECTRUM')
  r.ImGui_SameLine(ctx)
  r.ImGui_TextDisabled(ctx, '20 Hz – 20 kHz • mono analysis')
  r.ImGui_TextDisabled(ctx, 'Frequency smoothing')
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '-##spectrum_smoothing') then state.spectrum_smoothing = (state.spectrum_smoothing + #spectrum_smoothing_names - 2) % #spectrum_smoothing_names + 1 end
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, spectrum_smoothing_names[state.spectrum_smoothing])
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '+##spectrum_smoothing') then state.spectrum_smoothing = state.spectrum_smoothing % #spectrum_smoothing_names + 1 end
  r.ImGui_SameLine(ctx)
  r.ImGui_TextDisabled(ctx, 'Peak hold')
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '-##spectrum_hold') then state.spectrum_hold = (state.spectrum_hold + #spectrum_hold_names - 2) % #spectrum_hold_names + 1 end
  r.ImGui_SameLine(ctx)
  r.ImGui_Text(ctx, spectrum_hold_names[state.spectrum_hold])
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, '+##spectrum_hold') then state.spectrum_hold = state.spectrum_hold % #spectrum_hold_names + 1 end

  local values, held_values = {}, {}
  local peak_band, peak_value = 1, -120
  if data.online then
    for band = 1, SPECTRUM_BANDS do
      values[band] = smoothed_spectrum_value(data, band)
      if values[band] > peak_value then peak_band, peak_value = band, values[band] end
    end
    held_values = update_spectrum_holds(values)
    r.ImGui_TextColored(ctx, C.yellow, string.format('Peak: %s  •  %s dB', frequency_text(spectrum_frequency(peak_band)), db_text(peak_value)))
  else
    r.ImGui_TextDisabled(ctx, 'Peak: waiting for analyzer')
  end

  local avail_w, avail_h = r.ImGui_GetContentRegionAvail(ctx)
  r.ImGui_InvisibleButton(ctx, '##spectrum', avail_w, math.max(160, avail_h - 5))
  local x0, y0 = r.ImGui_GetItemRectMin(ctx)
  local x2, y2 = r.ImGui_GetItemRectMax(ctx)
  local dl = get_draw_list()
  for mark = -120, 0, 20 do
    local y = y2 - (mark + 120) / 120 * (y2 - y0 - 16)
    dl:AddLine(x0, y, x2, y, C.grid, 1)
    dl:AddText(x0 + 3, y - 14, C.subdued, tostring(mark))
  end
  if not data.online then return end
  local width = (x2 - x0) / SPECTRUM_BANDS
  for band = 1, SPECTRUM_BANDS do
    local value = values[band]
    local top = y2 - (value + 120) / 120 * (y2 - y0 - 4)
    local color = value > -12 and C.red or (value > -30 and C.yellow or C.cyan)
    dl:AddRectFilled(x0 + (band - 1) * width + 1, top, x0 + band * width - 1, y2 - 2, color, 1)
    if spectrum_hold_seconds[state.spectrum_hold] > 0 then
      local hold_top = y2 - (held_values[band] + 120) / 120 * (y2 - y0 - 4)
      dl:AddLine(x0 + (band - 1) * width + 1, hold_top, x0 + band * width - 1, hold_top, C.text, 1)
    end
  end
end

local function draw_loudness(data)
  local p = preset()
  r.ImGui_Text(ctx, 'LOUDNESS & PHASE')
  r.ImGui_SameLine(ctx)
  r.ImGui_TextDisabled(ctx, 'K-weighted estimates; use an approved meter for compliance delivery.')
  local values = {
    {'Momentary', data.momentary, 'LUFS'}, {'Short-term', data.short_term, 'LUFS'},
    {'Integrated', data.integrated, 'LUFS'}, {'Peak', data.peak, 'dBFS'},
    {'RMS', data.rms, 'dBFS'}, {'Crest', data.crest, 'dB'},
  }
  for i, item in ipairs(values) do
    if (i - 1) % 3 ~= 0 then r.ImGui_SameLine(ctx) end
    r.ImGui_BeginGroup(ctx)
    r.ImGui_TextDisabled(ctx, item[1])
    r.ImGui_TextColored(ctx, value_color(item[2], p), db_text(item[2]) .. ' ' .. item[3])
    r.ImGui_EndGroup(ctx)
    r.ImGui_SameLine(ctx, nil, 36)
  end
  r.ImGui_NewLine(ctx)
  r.ImGui_Text(ctx, 'L/R Correlation')
  r.ImGui_SameLine(ctx)
  r.ImGui_ProgressBar(ctx, (data.correlation + 1) / 2, 270, 18, string.format('%.2f', data.correlation))

  local avail_w, avail_h = r.ImGui_GetContentRegionAvail(ctx)
  r.ImGui_InvisibleButton(ctx, '##loudness_history', avail_w, math.max(130, avail_h - 5))
  local x0, y0 = r.ImGui_GetItemRectMin(ctx)
  local x2, y2 = r.ImGui_GetItemRectMax(ctx)
  local dl = get_draw_list()
  dl:AddRectFilled(x0, y0, x2, y2, C.bg, 2)
  for mark = -60, 0, 10 do
    local y = y2 - (mark + 60) / 60 * (y2 - y0)
    dl:AddLine(x0, y, x2, y, C.grid, 1)
    dl:AddText(x0 + 3, y - 14, C.subdued, tostring(mark))
  end
  if #state.loud_history > 1 then
    local points = {}
    for i, value in ipairs(state.loud_history) do
      points[#points + 1] = x0 + (i - 1) / (#state.loud_history - 1) * (x2 - x0)
      points[#points + 1] = y2 - clamp((value + 60) / 60, 0, 1) * (y2 - y0)
    end
    dl:AddPolyline(points, C.green, 0, 1.5)
  end
end

local speaker_positions = {
  L = {-132}, R = {-48}, C = {-90}, LFE = {90},
  Ls = {178}, Rs = {2}, Lrs = {142}, Rrs = {38},
  Ltf = {-118, true}, Rtf = {-62, true}, Ltr = {138, true}, Rtr = {42, true},
}

local function draw_scope(data)
  local labels, requested_count = labels_for(data.channels)
  local count = math.min(requested_count, data.channels)
  r.ImGui_Text(ctx, 'SURROUND FIELD SCOPE')
  r.ImGui_SameLine(ctx)
  r.ImGui_TextDisabled(ctx, 'speaker-position display • RMS energy')
  local avail_w, avail_h = r.ImGui_GetContentRegionAvail(ctx)
  local size = math.min(avail_w, math.max(220, avail_h - 5))
  r.ImGui_InvisibleButton(ctx, '##surround_field_scope', size, size)
  local x0, y0 = r.ImGui_GetItemRectMin(ctx)
  local x2, y2 = r.ImGui_GetItemRectMax(ctx)
  local dl = get_draw_list()
  local cx, cy = (x0 + x2) / 2, (y0 + y2) / 2
  local radius = size * 0.39
  dl:AddRectFilled(x0, y0, x2, y2, C.bg, 2)
  dl:AddCircle(cx, cy, radius, C.grid, 96, 1)
  dl:AddCircle(cx, cy, radius * 0.5, C.grid, 64, 1)
  dl:AddText(cx - 21, y0 + 5, C.subdued, 'FRONT')
  dl:AddText(x0 + 6, cy - 7, C.subdued, 'SURROUND L')
  dl:AddText(x2 - 82, cy - 7, C.subdued, 'SURROUND R')
  if not data.online then
    dl:AddText(x0 + 12, y2 - 24, C.orange, 'Waiting for SurroundScope Analyzer.')
    return
  end

  local p = preset()
  local total_energy, left_surround, right_surround = 0, 0, 0
  local centroid_x, centroid_y = 0, 0
  for channel = 1, count do
    local label = labels[channel]
    local position = speaker_positions[label]
    local stat = data.stats[channel]
    if position and stat then
      local angle = math.rad(position[1])
      local ux, uy = math.cos(angle), math.sin(angle)
      local speaker_x, speaker_y = cx + ux * radius, cy + uy * radius
      local level = clamp((stat.rms - p.floor) / -p.floor, 0, 1)
      local energy = 10 ^ (stat.rms / 10)
      local color = position[2] and C.blue or (label == 'LFE' and C.yellow or C.cyan)
      local beam = radius * level
      dl:AddLine(cx, cy, cx + ux * beam, cy + uy * beam, color, 3)
      dl:AddCircleFilled(cx + ux * beam, cy + uy * beam, 3 + 3 * level, color)
      dl:AddCircle(speaker_x, speaker_y, position[2] and 7 or 6, C.subdued, 16, 1)
      dl:AddText(speaker_x - 8, speaker_y - 7, C.text, label)
      dl:AddLine(cx, cy, speaker_x, speaker_y, C.grid, 1)
      total_energy = total_energy + energy
      centroid_x = centroid_x + ux * energy
      centroid_y = centroid_y + uy * energy
      if label:find('s') then
        if ux < 0 then left_surround = left_surround + energy else right_surround = right_surround + energy end
      end
    end
  end
  if total_energy > 0 then
    local centroid_length = math.sqrt(centroid_x * centroid_x + centroid_y * centroid_y) / total_energy
    local surround_total = left_surround + right_surround
    local width = surround_total > 0 and 200 * math.min(left_surround, right_surround) / surround_total or 0
    dl:AddLine(cx, cy, cx + centroid_x / total_energy * radius, cy + centroid_y / total_energy * radius, C.text, 2)
    dl:AddText(x0 + 8, y2 - 38, C.text, string.format('Surround width: %.0f%%', width))
    dl:AddText(x0 + 8, y2 - 20, C.subdued, string.format('Field focus: %.0f%%', clamp(centroid_length * 100, 0, 100)))
  end
end

local function draw_details(data)
  local labels, requested_count = labels_for(data.channels)
  local count = math.min(requested_count, data.channels)
  r.ImGui_Text(ctx, 'CHANNEL DETAILS')
  if not data.online then return end
  if r.ImGui_BeginTable(ctx, 'channel_stats', 6, r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_RowBg() | r.ImGui_TableFlags_SizingStretchProp()) then
    local headings = {'Channel', 'Peak', 'RMS', 'Hold', 'Crest', 'Sample peak'}
    for _, heading in ipairs(headings) do r.ImGui_TableSetupColumn(ctx, heading) end
    r.ImGui_TableHeadersRow(ctx)
    for channel = 1, count do
      local s = data.stats[channel]
      r.ImGui_TableNextRow(ctx)
      r.ImGui_TableSetColumnIndex(ctx, 0); r.ImGui_Text(ctx, labels[channel])
      r.ImGui_TableSetColumnIndex(ctx, 1); r.ImGui_Text(ctx, metric_text(s.peak))
      r.ImGui_TableSetColumnIndex(ctx, 2); r.ImGui_Text(ctx, metric_text(s.rms))
      r.ImGui_TableSetColumnIndex(ctx, 3); r.ImGui_Text(ctx, metric_text(s.hold))
      r.ImGui_TableSetColumnIndex(ctx, 4); r.ImGui_Text(ctx, metric_text(s.crest))
      r.ImGui_TableSetColumnIndex(ctx, 5); r.ImGui_Text(ctx, metric_text(s.sample_peak))
    end
    r.ImGui_EndTable(ctx)
  end
end

local function loop()
  local data = read_data()
  update_history(data)
  r.ImGui_SetNextWindowSize(ctx, 1160, 790, r.ImGui_Cond_FirstUseEver())
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), C.bg)
  local visible, open = r.ImGui_Begin(ctx, 'SurroundScope Multimeter', true)
  r.ImGui_PopStyleColor(ctx)
  if visible then
    draw_header(data)
    r.ImGui_Separator(ctx)
    for index, name in ipairs(module_names) do
      if index > 1 then r.ImGui_SameLine(ctx) end
      local is_active = index == state.active_module
      if is_active then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), C.blue) end
      if r.ImGui_Button(ctx, name) then state.active_module = index end
      if is_active then r.ImGui_PopStyleColor(ctx) end
    end
    r.ImGui_Separator(ctx)
    if state.active_module == 1 then draw_channel_meters(data)
    elseif state.active_module == 2 then draw_waveform(data)
    elseif state.active_module == 3 then draw_spectrum(data)
    elseif state.active_module == 4 then draw_loudness(data)
    elseif state.active_module == 5 then draw_scope(data)
    else draw_details(data)
    end
    -- This ReaImGui build opens a drawable window only when visible is true.
    -- Keep End inside the matching branch to preserve its strict window stack.
    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
