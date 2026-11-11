-- Charts drawn with plain textures: stacked columns per day/week/month and
-- ranked horizontal bars. Series keep their colour forever once given one, so
-- a filter or a new month never repaints a series.
local _, ns = ...
local T = ns.T
local C = {}
ns.Charts = C

-- A stable colour per series key, handed out in order of first use.
function C.ColorFor(key)
  local db = ns.db
  db.colors = db.colors or {}
  local i = db.colors[key]
  if not i then
    local used = {}
    for _, v in pairs(db.colors) do used[v] = true end
    for n = 1, #T.SERIES do if not used[n] then i = n; break end end
    if not i then return T.MORE end
    db.colors[key] = i
  end
  return T.SERIES[i] or T.MORE
end

-- Hand out colours by rank (biggest first) so the top series get the first colours.
function C.Assign(keys) for _, k in ipairs(keys) do C.ColorFor(k) end end

---------------------------------------------------------------------------
-- Stacked columns
---------------------------------------------------------------------------
function C.Columns(parent, height)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(height)
  f.segs, f.cols, f.labels, f.grid = {}, {}, {}, {}
  for i = 1, 4 do
    local g = T.Fill(f, "BACKGROUND", 1, 1, 1, 0.05, 2)
    g:SetHeight(1)
    f.grid[i] = g
    local t = T.Med(f, 9, T.MUTED)
    t:SetJustifyH("RIGHT")
    g.label = t
  end
  f.empty = T.Med(f, 12, T.MUTED, "Nothing here yet. It fills in as you play.")
  f.empty:SetPoint("CENTER")

  local segN = 0
  local function Seg()
    segN = segN + 1
    local s = f.segs[segN]
    if not s then s = f:CreateTexture(nil, "ARTWORK"); s:SetTexture("Interface\\Buttons\\WHITE8x8"); f.segs[segN] = s end
    s:Show()
    return s
  end

  -- starts: group start days; grid[i][key] = copper; keys: series in stack order
  -- (bottom first); colorFn(key); labelFn(i) -> axis label; tip(i, self)
  function f:SetData(starts, grid, keys, colorFn, labelFn, tip)
    segN = 0
    for _, s in ipairs(self.segs) do s:Hide() end
    for _, c in ipairs(self.cols) do c:Hide() end
    for _, l in ipairs(self.labels) do l:Hide() end
    local n = #starts
    local top = 0
    for i = 1, n do
      local sum = 0
      for _, k in ipairs(keys) do sum = sum + (grid[i][k] or 0) end
      if sum > top then top = sum end
    end
    self.empty:SetShown(top == 0)
    local W, H = self:GetWidth(), self:GetHeight()
    local axisW, labelH = 54, 16
    local plotW, plotH = W - axisW, H - labelH - 6
    if plotW <= 0 or n == 0 then return end
    -- nice scale in whole gold/silver steps
    local step = 1
    if top > 0 then
      local raw = top / 4
      local p = 10 ^ math.floor(math.log10(raw))
      for _, m in ipairs({ 1, 2, 2.5, 5, 10 }) do if p * m >= raw then step = p * m; break end end
    end
    local maxV = math.max(1, step * 4)
    for gi = 1, 4 do
      local g = self.grid[gi]
      local y = labelH + plotH * gi / 4
      g:ClearAllPoints()
      g:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", axisW, y)
      g:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, y)
      g.label:ClearAllPoints()
      g.label:SetPoint("RIGHT", g, "LEFT", -6, 0)
      g.label:SetText(top > 0 and ns.Fmt(step * gi) or "")
    end
    local slot = plotW / n
    local bw = math.max(2, math.min(28, slot * 0.66))
    local every = math.max(1, math.ceil(n / 10))
    for i = 1, n do
      local x = axisW + (i - 0.5) * slot
      local y = labelH
      for _, k in ipairs(keys) do
        local v = grid[i][k] or 0
        if v > 0 then
          local h = math.max(1, plotH * v / maxV)
          local s = Seg()
          local c = colorFn(k)
          s:SetVertexColor(c[1], c[2], c[3], 0.95)
          s:ClearAllPoints()
          s:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x - bw / 2, y)
          s:SetSize(bw, h)
          y = y + h
        end
      end
      -- hover target per column
      local col = self.cols[i]
      if not col then
        col = CreateFrame("Frame", nil, self)
        col.hl = T.Fill(col, "BACKGROUND", 1, 1, 1, 0.04, 3); col.hl:SetAllPoints(); col.hl:Hide()
        col:EnableMouse(true)
        col:SetScript("OnEnter", function(c2) c2.hl:Show(); if c2.tip then c2.tip(c2.i, c2) end end)
        col:SetScript("OnLeave", function(c2) c2.hl:Hide(); GameTooltip:Hide() end)
        self.cols[i] = col
      end
      col.i, col.tip = i, tip
      col:ClearAllPoints()
      col:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", axisW + (i - 1) * slot, 0)
      col:SetSize(slot, H)
      col:Show()
      if (n - i) % every == 0 then
        local l = self.labels[i]
        if not l then l = T.Med(self, 9, T.MUTED); l:SetJustifyH("CENTER"); self.labels[i] = l end
        l:ClearAllPoints()
        l:SetPoint("BOTTOM", self, "BOTTOMLEFT", x, 2)
        l:SetText(labelFn(i))
        l:Show()
      end
    end
  end
  return f
end

---------------------------------------------------------------------------
-- Ranked bars: a list of { key, label, value, sub, color, onClick }
---------------------------------------------------------------------------
function C.Ranked(parent)
  local f = CreateFrame("Frame", nil, parent)
  f.rows = {}
  local ROW = 34
  function f:SetData(items, total)
    local top = 0
    for _, it in ipairs(items) do if it.value > top then top = it.value end end
    for _, r in ipairs(self.rows) do r:Hide() end
    local y = 0
    for i, it in ipairs(items) do
      local r = self.rows[i]
      if not r then
        r = CreateFrame("Button", nil, self)
        r:SetHeight(ROW - 4)
        r.hl = T.Fill(r, "HIGHLIGHT", 1, 1, 1, 0.04); r.hl:SetAllPoints()
        r.swatch = T.Fill(r, "ARTWORK", 1, 1, 1, 1); r.swatch:SetSize(10, 10); r.swatch:SetPoint("TOPLEFT", 6, -5)
        r.label = T.Bold(r, 12, T.TEXT); r.label:SetPoint("LEFT", r.swatch, "RIGHT", 8, 0)
        r.value = T.Bold(r, 12, T.TEXT); r.value:SetPoint("TOPRIGHT", -6, -3); r.value:SetJustifyH("RIGHT")
        r.sub = T.Med(r, 10, T.MUTED); r.sub:SetPoint("RIGHT", r.value, "LEFT", -12, 0); r.sub:SetJustifyH("RIGHT")
        r.label:SetPoint("RIGHT", r.sub, "LEFT", -8, 0)
        r.track = T.Fill(r, "ARTWORK", 1, 1, 1, 0.06); r.track:SetHeight(3)
        r.track:SetPoint("BOTTOMLEFT", 24, 3); r.track:SetPoint("BOTTOMRIGHT", -6, 3)
        r.fill = r:CreateTexture(nil, "OVERLAY"); r.fill:SetTexture("Interface\\Buttons\\WHITE8x8"); r.fill:SetHeight(3)
        r.fill:SetPoint("BOTTOMLEFT", r.track, "BOTTOMLEFT")
        r:SetScript("OnEnter", function(self2) if self2.it and self2.it.tip then self2.it.tip(self2) end end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.rows[i] = r
      end
      r.it = it
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
      local c = it.color or T.MORE
      r.swatch:SetColorTexture(c[1], c[2], c[3], 1)
      r.fill:SetVertexColor(c[1], c[2], c[3], 0.9)
      r.label:SetText(it.label)
      r.value:SetText(ns.Coins(it.value, 11))
      local pct = (total and total > 0) and math.floor(it.value / total * 100 + 0.5) or nil
      r.sub:SetText(it.sub or (pct and (pct .. "%") or ""))
      local w = (self:GetWidth() or 200) - 30
      r.fill:SetWidth(math.max(0.01, w * (top > 0 and it.value / top or 0)))
      r:SetScript("OnClick", it.onClick)
      r:Show()
      y = y + ROW
    end
    self:SetHeight(math.max(1, y))
    return y
  end
  return f
end

---------------------------------------------------------------------------
-- Donut (ring) chart for a single day: a ring of thin rotated textures, each
-- coloured by the slice it falls in. The total sits in the middle.
---------------------------------------------------------------------------
local RING_SEGS = 180

function C.Donut(parent, size, thick)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  local r = (size - thick) / 2
  local arc = 2 * math.pi * r / RING_SEGS + 1.5
  f.segs = {}
  for i = 1, RING_SEGS do
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    local a = math.pi / 2 - (i - 0.5) * 2 * math.pi / RING_SEGS -- from the top, clockwise
    t:SetSize(thick, arc)
    t:SetPoint("CENTER", f, "CENTER", r * math.cos(a), r * math.sin(a))
    if t.SetRotation then t:SetRotation(a) end
    f.segs[i] = t
  end
  f.total = T.Bold(f, 18, T.TEXT); f.total:SetPoint("CENTER", 0, 8)
  f.caption = T.Med(f, 11, T.MUTED); f.caption:SetPoint("TOP", f.total, "BOTTOM", 0, -6)

  -- slices: { { key, value, color } } biggest first; total in copper
  function f:SetData(slices, total, caption)
    local sum = 0
    for _, sl in ipairs(slices) do sum = sum + sl.value end
    local idx, acc = 1, slices[1] and slices[1].value or 0
    for i, t in ipairs(self.segs) do
      if sum <= 0 then
        t:SetVertexColor(1, 1, 1, 0.08)
      else
        local at = (i - 0.5) / RING_SEGS * sum
        while slices[idx + 1] and at > acc do idx = idx + 1; acc = acc + slices[idx].value end
        local c = slices[idx].color
        t:SetVertexColor(c[1], c[2], c[3], 1)
      end
    end
    self.total:SetText(ns.Coins(total, 16))
    self.caption:SetText(caption or "")
  end
  return f
end
