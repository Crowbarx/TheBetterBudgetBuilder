-- Spending and Income: where your gold went and where it came from, over
-- 7 days to 12 months, as stacked columns plus ranked lists.
local _, ns = ...
local T, K, St, Lines, Charts = ns.T, ns.Kit, ns.Stats, ns.Lines, ns.Charts

local MAX_SERIES = 7

-- Collapse everything past the top series into "more".
local function Fold(ser, ranked)
  local keep = {}
  for i, k in ipairs(ranked) do if i <= MAX_SERIES then keep[k] = true end end
  local grid = {}
  for i, g in ipairs(ser.grid) do
    local out = {}
    for k, v in pairs(g) do
      local key = keep[k] and k or "more"
      out[key] = (out[key] or 0) + v
    end
    grid[i] = out
  end
  -- the biggest series sits at the bottom of each column
  local stack = {}
  for i = 1, math.min(#ranked, MAX_SERIES) do stack[#stack + 1] = ranked[i] end
  if #ranked > MAX_SERIES then stack[#stack + 1] = "more" end
  return grid, stack
end

local function MakePage(spec)
  local page = { key = spec.key, order = spec.order, nav = spec.nav, title = spec.title, subtitle = spec.subtitle }
  table.insert(ns.Pages, page)

  function page.build(p)
    local c = p.child
    p.picker = K.RangePicker(p.toolsFrame)
    p.picker:SetPoint("RIGHT")
    p.cards = { K.Card(c), K.Card(c), K.Card(c), K.Card(c) }
    p.chartHead = T.Section(c, spec.chartTitle)
    p.chartBg = T.Panel(c)
    p.chart = Charts.Columns(p.chartBg, 220)
    p.chart:SetPoint("TOPLEFT", 14, -14); p.chart:SetPoint("TOPRIGHT", -14, -14)
    p.listHead = T.Section(c, spec.listTitle)
    p.list = Charts.Ranked(c)
    if spec.second then
      p.secondHead = T.Section(c, spec.second.title)
      p.second = Charts.Ranked(c)
    end
  end

  function page.refresh(p)
    local c = p.child
    local r = K.Range()
    local today = ns.Today()
    local starts = St.Groups(today, r.group, r.count)
    local rows = ns.Rows()
    local ser = St.Series(rows, starts, r.group, spec.keyFn, spec.sign)
    local ranked = St.Ranked(ser.totals)
    Charts.Assign(ranked)
    local function color(k) return k == "more" and T.MORE or Charts.ColorFor(k) end

    spec.cards(p, ser, ranked, starts, r)
    local y = K.Columns(p.cards, c, 0, 8, 78) + 22

    p.chartHead:ClearAllPoints(); p.chartHead:SetPoint("TOPLEFT", 0, -y); p.chartHead:SetPoint("RIGHT", c, "RIGHT")
    p.chartHead:SetTitle(spec.chartTitle .. "  ·  " .. r.text)
    y = y + 28
    p.chartBg:ClearAllPoints(); p.chartBg:SetPoint("TOPLEFT", 0, -y); p.chartBg:SetPoint("RIGHT", c, "RIGHT"); p.chartBg:SetHeight(248)
    local grid, stack = Fold(ser, ranked)
    p.chart:SetWidth(c:GetWidth() - 28)
    p.chart:SetData(starts, grid, stack, color, function(i) return K.GroupLabel(starts[i], r.group) end, function(i, col)
      GameTooltip:SetOwner(col, "ANCHOR_RIGHT")
      local label = K.GroupLabel(starts[i], r.group)
      if r.group == "week" then label = "Week of " .. label end
      GameTooltip:AddLine(label, 1, 1, 1)
      local sum = 0
      for j = #stack, 1, -1 do
        local k = stack[j]
        local v = grid[i][k] or 0
        if v > 0 then
          local cc = color(k)
          GameTooltip:AddDoubleLine("|T" .. "Interface\\Buttons\\WHITE8x8" .. ":10:10:0:0:8:8:0:8:0:8:" ..
            math.floor(cc[1] * 255) .. ":" .. math.floor(cc[2] * 255) .. ":" .. math.floor(cc[3] * 255) .. "|t  " ..
            (k == "more" and "Everything else" or spec.label(k)), ns.Fmt(v, true), 0.85, 0.85, 0.85)
          sum = sum + v
        end
      end
      GameTooltip:AddDoubleLine("Total", ns.Fmt(sum, true), 1, 1, 1)
      GameTooltip:Show()
    end)
    y = y + 248 + 22

    p.listHead:ClearAllPoints(); p.listHead:SetPoint("TOPLEFT", 0, -y); p.listHead:SetPoint("RIGHT", c, "RIGHT")
    y = y + 28
    local items = {}
    for _, k in ipairs(ranked) do
      items[#items + 1] = { key = k, label = spec.label(k), value = ser.totals[k], color = color(k),
        sub = spec.sub and spec.sub(k, ser) or nil, onClick = spec.click and function() spec.click(k) end,
        tip = spec.tip and function(self) spec.tip(self, k, rows, starts[1]) end }
    end
    p.list:ClearAllPoints(); p.list:SetPoint("TOPLEFT", 0, -y); p.list:SetPoint("RIGHT", c, "RIGHT")
    if #items == 0 then
      items[1] = { label = "|cff9a9aa0Nothing in this range yet.|r", value = 0 }
    end
    y = y + p.list:SetData(items, ser.sum) + 18

    if spec.second then
      local list = spec.second.items(rows, starts[1])
      p.secondHead:SetShown(#list > 0); p.second:SetShown(#list > 0)
      if #list > 0 then
        p.secondHead:ClearAllPoints(); p.secondHead:SetPoint("TOPLEFT", 0, -y); p.secondHead:SetPoint("RIGHT", c, "RIGHT")
        y = y + 28
        p.second:ClearAllPoints(); p.second:SetPoint("TOPLEFT", 0, -y); p.second:SetPoint("RIGHT", c, "RIGHT")
        y = y + p.second:SetData(list) + 18
      end
    end
    return y
  end
  return page
end

local function Days(starts, r)
  local today = ns.Today()
  return math.max(1, today - starts[1] + 1)
end

---------------------------------------------------------------------------
-- Spending
---------------------------------------------------------------------------
local function CatKey(row)
  if Lines.Kind(row) ~= "spend" then return nil end
  local id = ns.LineOf(row):match("^cat:(.+)$")
  return id and Lines.TopOf(id, ns.Cats()) or "other"
end

MakePage({
  key = "spending", order = 2, nav = "Spending", title = "Spending", subtitle = "Where your gold went.",
  chartTitle = "Spent", listTitle = "By category", keyFn = CatKey, sign = -1,
  label = function(k) local c = ns.Cat(k); return c and c.name or k end,
  sub = function(k, ser) local n = ser.count[k] or 0; return n .. (n == 1 and " purchase" or " purchases") end,
  click = function(k) ns.ShowLedger("cat:" .. k) end,
  tip = function(self, k, rows, from)
    -- sub-category breakdown
    local subs, any = {}, false
    for _, row in ipairs(rows) do
      if row.day and row.day >= from and CatKey(row) == k then
        local id = ns.LineOf(row):match("^cat:(.+)$")
        if id ~= k then subs[id] = (subs[id] or 0) - row.d; any = true end
      end
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local c = ns.Cat(k)
    GameTooltip:AddLine(c and c.name or k, 1, 1, 1)
    if any then for id, v in pairs(subs) do local sc = ns.Cat(id); GameTooltip:AddDoubleLine(sc and sc.name or id, ns.Fmt(v, true), 0.85, 0.85, 0.85) end end
    GameTooltip:AddLine("Click to see these in the ledger", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end,
  cards = function(p, ser, ranked, starts, r)
    local days = Days(starts, r)
    local top = ranked[1] and ns.Cat(ranked[1])
    p.cards[1]:Set("Spent", ns.Coins(ser.sum, 15), r.text, ser.sum > 0 and T.BAD or T.TEXT, true)
    p.cards[2]:Set("Per day", ns.Coins(math.floor(ser.sum / days), 15), "Average over " .. days .. " day" .. (days == 1 and "" or "s"))
    p.cards[3]:Set("Biggest", top and top.name or "—", top and ns.Fmt(ser.totals[ranked[1]]) or "")
    local earned = St.Totals(ns.Rows(), starts[1], Lines.Kind)
    local pct = earned > 0 and math.floor(ser.sum / earned * 100 + 0.5) or nil
    p.cards[4]:Set("Of what you earned", pct and (pct .. "%") or "—", "Spent / earned in this range", pct and pct > 100 and T.BAD or T.TEXT)
  end,
  second = {
    title = "Top items bought",
    items = function(rows, from)
      local byItem, out = {}, {}
      for _, row in ipairs(rows) do
        if row.day and row.day >= from and row.item and row.d < 0 and Lines.Kind(row) == "spend" then
          local e = byItem[row.item]
          if not e then e = { value = 0, n = 0, link = row.link }; byItem[row.item] = e end
          e.value = e.value - row.d
          e.n = e.n + 1
          e.link = e.link or row.link
        end
      end
      for id, e in pairs(byItem) do
        out[#out + 1] = { label = e.link or ("item " .. id), value = e.value, sub = e.n .. "x", color = T.MORE }
      end
      table.sort(out, function(a, b) return a.value > b.value end)
      for i = #out, 9, -1 do out[i] = nil end
      return out
    end,
  },
})

---------------------------------------------------------------------------
-- Income
---------------------------------------------------------------------------
MakePage({
  key = "income", order = 3, nav = "Income", title = "Income", subtitle = "Where your gold comes from, and how fast.",
  chartTitle = "Earned", listTitle = "By source", sign = 1,
  keyFn = function(row) return Lines.Kind(row) == "income" and row.src or nil end,
  label = ns.SourceLabel,
  sub = function(k, ser)
    local n = ser.count[k] or 0
    return n .. "x  ·  avg " .. ns.Fmt(math.floor((ser.totals[k] or 0) / math.max(1, n)))
  end,
  click = function(k) ns.ShowLedger("income:" .. k) end,
  cards = function(p, ser, ranked, starts, r)
    local days = Days(starts, r)
    local ph = St.PerHour(ser.sum, ns.Played(starts[1]))
    local best, bestV = nil, 0
    local daily = St.Series(ns.Rows(), St.Groups(ns.Today(), "day", days), "day",
      function(row) return Lines.Kind(row) == "income" and "x" or nil end, 1)
    for i, g in ipairs(daily.grid) do if (g.x or 0) > bestV then bestV = g.x; best = i end end
    local _, spent = St.Totals(ns.Rows(), starts[1], Lines.Kind)
    p.cards[1]:Set("Earned", ns.Coins(ser.sum, 15), r.text, T.GOOD, true)
    p.cards[2]:Set("Gold per hour", ph and ns.Coins(ph, 15) or "—", ph and ("Over " .. math.floor(ns.Played(starts[1]) / 3600 + 0.5) .. "h played") or "Play a bit to measure it")
    p.cards[3]:Set("Best day", best and ns.Coins(bestV, 15) or "—", best and K.DayLabel(ns.Today() - days + best) or "")
    p.cards[4]:Set("Kept", ns.Coins(ser.sum - spent, 15), "Earned minus spent", ser.sum >= spent and T.TEXT or T.BAD)
  end,
  second = {
    title = "Best sellers (AH and vendor)",
    items = function(rows, from)
      local by, out = {}, {}
      for _, row in ipairs(rows) do
        if row.day and row.day >= from and row.d > 0 and (row.src == "ah_sale") and row.note then
          local e = by[row.note] or { value = 0, n = 0 }
          e.value, e.n = e.value + row.d, e.n + 1
          by[row.note] = e
        end
      end
      for name, e in pairs(by) do out[#out + 1] = { label = name, value = e.value, sub = e.n .. "x", color = T.MORE } end
      table.sort(out, function(a, b) return a.value > b.value end)
      for i = #out, 9, -1 do out[i] = nil end
      return out
    end,
  },
})
