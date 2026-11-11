-- Page building blocks: stat cards, segmented pickers, toggles, setting rows.
local _, ns = ...
local T = ns.T
local K = {}
ns.Kit = K

-- A stat card: small caps label, big value, a muted line under it.
function K.Card(parent)
  local c = T.Panel(parent, true)
  c:SetHeight(78)
  c.label = T.Bold(c, 10, T.MUTED); c.label:SetPoint("TOPLEFT", 16, -14)
  c.value = T.Bold(c, 17, T.TEXT); c.value:SetPoint("TOPLEFT", c.label, "BOTTOMLEFT", 0, -9)
  c.sub = T.Med(c, 11, T.MUTED); c.sub:SetPoint("TOPLEFT", c.value, "BOTTOMLEFT", 0, -7)
  c.sub:SetPoint("RIGHT", c, "RIGHT", -12, 0)
  c.edge = T.Fill(c, "ARTWORK", 1, 1, 1, 1); c.edge:SetPoint("TOPLEFT"); c.edge:SetPoint("BOTTOMLEFT"); c.edge:SetWidth(2)
  c.edge:Hide()
  function c:Set(label, value, sub, color, accentEdge)
    self.label:SetText(label:upper())
    self.value:SetText(value)
    local col = color or T.TEXT
    self.value:SetTextColor(col[1], col[2], col[3])
    self.sub:SetText(sub or "")
    if accentEdge then local a = T.Accent(); self.edge:SetColorTexture(a[1], a[2], a[3], 1); self.edge:Show() else self.edge:Hide() end
  end
  return c
end

-- Lay out frames in a row of equal columns. Returns the height used.
function K.Columns(frames, parent, y, gap, h)
  local w = parent:GetWidth()
  local n = #frames
  local cw = (w - gap * (n - 1)) / n
  for i, f in ipairs(frames) do
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", (i - 1) * (cw + gap), -y)
    f:SetWidth(cw)
    if h then f:SetHeight(h) end
  end
  return h or frames[1]:GetHeight()
end

-- Segmented picker: choices = { { value, text } }; get() / set(v).
function K.Segmented(parent, choices, get, set)
  local f = CreateFrame("Frame", nil, parent)
  f.btns = {}
  local x = 0
  for i = #choices, 1, -1 do
    local ch = choices[i]
    local b = T.Button(f, ch.text, 10, 28, function() set(ch.value); T.Repaint() end)
    b:Fit(24)
    b:SetPoint("RIGHT", f, "RIGHT", -x, 0)
    x = x + b:GetWidth() + 4
    b.value = ch.value
    f.btns[#f.btns + 1] = b
  end
  f:SetSize(x, 28)
  T.widgets[#T.widgets + 1] = function()
    local cur = get()
    for _, b in ipairs(f.btns) do b.selected = b.value == cur; b.Paint(b:IsMouseOver()) end
  end
  return f
end

-- On/off switch.
function K.Toggle(parent, get, set)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(38, 20)
  local track = T.Fill(b, "ARTWORK", 1, 1, 1, 0.12); track:SetAllPoints()
  local knob = T.Fill(b, "OVERLAY", 0.85, 0.85, 0.88, 1); knob:SetSize(16, 16)
  local function Paint()
    local on = get()
    knob:ClearAllPoints()
    knob:SetPoint(on and "RIGHT" or "LEFT", on and -2 or 2, 0)
    if on then local a = T.Accent(); track:SetColorTexture(a[1], a[2], a[3], 0.8) else track:SetColorTexture(1, 1, 1, 0.12) end
  end
  b:SetScript("OnClick", function() set(not get()); Paint(); ns.Changed() end)
  T.widgets[#T.widgets + 1] = Paint
  Paint()
  return b
end

-- A KeyzenBars-style setting row: bold label, muted description, a control on the right.
function K.SettingRow(parent, label, desc)
  local r = T.Panel(parent, true)
  r:SetHeight(52)
  r.text = T.Bold(r, 13, T.TEXT, label); r.text:SetPoint("TOPLEFT", 18, -11)
  r.sub = T.Med(r, 11, T.MUTED, desc); r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -5)
  r.sub:SetPoint("RIGHT", r, "RIGHT", -150, 0)
  return r
end

-- Lay out rows two to a line. Returns height used.
function K.Grid(rows, parent, y, rowH, gap)
  local w = parent:GetWidth()
  local half = (w - gap) / 2
  local col, yy = 0, y
  for _, r in ipairs(rows) do
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", col * (half + gap), -yy)
    r:SetSize(half, rowH)
    if col == 1 then col = 0; yy = yy + rowH + gap else col = 1 end
  end
  if col == 1 then yy = yy + rowH + gap end
  return yy - y
end

-- Short date: "Nov 9" / with time "Nov 9 21:04".
function K.Date(t, withTime)
  if not t then return "" end
  local d = date("%b %d", t):gsub(" 0", " ")
  if withTime then d = d .. date("  %H:%M", t) end
  return d
end

-- A day number as "Nov 9".
function K.DayLabel(day)
  local y, m, d = ns.Period.CivilFromDay(day)
  return date("%b", time({ year = y, month = m, day = 15 })) .. " " .. d
end

function K.MonthLabel(day)
  local y, m = ns.Period.CivilFromDay(day)
  return date("%b", time({ year = y, month = m, day = 15 }))
end

-- The range picker used on Spending and Income.
K.RANGES = {
  { value = "day", text = "Day", group = "day", count = 1 },
  { value = "d7", text = "7 days", group = "day", count = 7 },
  { value = "d30", text = "30 days", group = "day", count = 30 },
  { value = "w12", text = "12 weeks", group = "week", count = 12 },
  { value = "m12", text = "12 months", group = "month", count = 12 },
}
function K.Range()
  local v = ns.db.settings.range or "d30"
  for _, r in ipairs(K.RANGES) do if r.value == v then return r end end
  return K.RANGES[2]
end
function K.RangePicker(parent)
  return K.Segmented(parent, K.RANGES, function() return K.Range().value end,
    function(v) ns.db.settings.range = v; ns.Changed() end)
end

function K.GroupLabel(start, group)
  if group == "month" then return K.MonthLabel(start) end
  return K.DayLabel(start)
end
