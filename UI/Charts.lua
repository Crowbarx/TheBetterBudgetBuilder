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
