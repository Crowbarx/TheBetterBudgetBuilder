-- Spending and Income: where your gold went and where it came from, over
-- 7 days to 12 months, as stacked columns plus ranked lists. The Day tab
-- shows one day at a time as a ring chart, with arrows to step through days.
local _, ns = ...
local T, K, St, Lines, Charts = ns.T, ns.Kit, ns.Stats, ns.Lines, ns.Charts

local MAX_SERIES = 7
local viewDay -- the day the Day tab shows (nil = today); shared by both pages

-- One day's totals for the Day tab cards.
local function DayInfo(day)
  local earned, spent = 0, 0
  for _, r in ipairs(ns.Rows()) do
    if r.day == day then
      local k = Lines.Kind(r)
      if k == "income" then earned = earned + r.d elseif k == "spend" then spent = spent - r.d end
    end
  end
  local played, me = 0, ns.CharKey()
  for key, c in pairs(ns.db.chars) do
    if ns.db.settings.includeAlts or key == me then played = played + ((c.played or {})[day] or 0) end
  end
  local today = ns.Today()
  local label = day == today and "Today" or day == today - 1 and "Yesterday" or K.DayLabel(day)
  return { day = day, earned = earned, spent = spent, played = played, label = label }
end

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

function ns.PlayedText(sec)
  local h, m = math.floor(sec / 3600), math.floor(sec % 3600 / 60)
  return h > 0 and (h .. "h " .. m .. "m") or (m .. "m")
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
    -- Day tab: ring chart, a legend, and arrows to step through days
    p.donut = Charts.Donut(p.chartBg, 210, 34)
    p.donut:SetPoint("LEFT", 40, 0)
    p.legend = {}
    for i = 1, 8 do
      local l = CreateFrame("Frame", nil, p.chartBg); l:SetHeight(22)
      l.sw = T.Fill(l, "ARTWORK", 1, 1, 1, 1); l.sw:SetSize(10, 10); l.sw:SetPoint("LEFT")
      l.name = T.Med(l, 12, T.TEXT); l.name:SetPoint("LEFT", l.sw, "RIGHT", 10, 0)
      l.pct = T.Bold(l, 12, T.TEXT); l.pct:SetPoint("RIGHT"); l.pct:SetJustifyH("RIGHT")
      l.val = T.Med(l, 11, T.MUTED); l.val:SetPoint("RIGHT", l.pct, "LEFT", -14, 0); l.val:SetJustifyH("RIGHT")
      p.legend[i] = l
    end
    local function Step(d)
      local today = ns.Today()
      viewDay = math.min(today, (viewDay or today) + d)
      if viewDay == today then viewDay = nil end
      ns.Changed()
    end
    p.prev = T.Button(p.chartBg, "<", 30, 26, function() Step(-1) end)
    p.next = T.Button(p.chartBg, ">", 30, 26, function() Step(1) end)
    p.todayBtn = T.Button(p.chartBg, "Today", 64, 26, function() viewDay = nil; ns.Changed() end)
    p.dayLabel = T.Bold(p.chartBg, 13, T.TEXT)
    p.prev:SetPoint("TOPRIGHT", -14 - 30 - 6 - 64 - 6, -12)
    p.next:SetPoint("LEFT", p.prev, "RIGHT", 6, 0)
    p.todayBtn:SetPoint("LEFT", p.next, "RIGHT", 6, 0)
    p.dayLabel:SetPoint("RIGHT", p.prev, "LEFT", -12, 0)
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
    local isDay = r.value == "day"
    if viewDay and viewDay > today then viewDay = nil end
    local starts = isDay and { viewDay or today } or St.Groups(today, r.group, r.count)
    local last = isDay and starts[1] or today
    local info = isDay and DayInfo(starts[1]) or nil
    local rows = ns.Rows()
    local ser = St.Series(rows, starts, r.group, spec.keyFn, spec.sign)
    local ranked = St.Ranked(ser.totals)
    Charts.Assign(ranked)
    local function color(k) return k == "more" and T.MORE or Charts.ColorFor(k) end

    if isDay then spec.dayCards(p, ser, ranked, info) else spec.cards(p, ser, ranked, starts, r) end
    local y = K.Columns(p.cards, c, 0, 8, 78) + 22

    p.chartHead:ClearAllPoints(); p.chartHead:SetPoint("TOPLEFT", 0, -y); p.chartHead:SetPoint("RIGHT", c, "RIGHT")
    p.chartHead:SetTitle(spec.chartTitle .. "  ·  " .. (isDay and info.label or r.text))
    y = y + 28
    p.chartBg:ClearAllPoints(); p.chartBg:SetPoint("TOPLEFT", 0, -y); p.chartBg:SetPoint("RIGHT", c, "RIGHT"); p.chartBg:SetHeight(248)
    p.chart:SetShown(not isDay); p.donut:SetShown(isDay)
    for _, w in ipairs({ p.prev, p.next, p.todayBtn, p.dayLabel }) do w:SetShown(isDay) end
    for _, l in ipairs(p.legend) do l:Hide() end
    if isDay then
      local slices = {}
      for i, k in ipairs(ranked) do
        if i <= MAX_SERIES then
          slices[#slices + 1] = { key = k, value = ser.totals[k], color = color(k), label = spec.label(k) }
        else
          if not slices.more then slices.more = { key = "more", value = 0, color = T.MORE, label = "Everything else" }; end
          slices.more.value = slices.more.value + ser.totals[k]
        end
      end
      if slices.more then slices[#slices + 1] = slices.more end
      p.donut:SetData(slices, ser.sum, ser.sum > 0 and spec.ringCaption or "Nothing this day")
      p.dayLabel:SetText(info.label == K.DayLabel(info.day) and info.label or (info.label .. "  ·  " .. K.DayLabel(info.day)))
      p.next:SetAlpha(viewDay and 1 or 0.35); p.todayBtn:SetAlpha(viewDay and 1 or 0.35)
      local lx = 40 + 210 + 48
      for i, sl in ipairs(slices) do
        local l = p.legend[i]
        if not l then break end
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", p.chartBg, "TOPLEFT", lx, -50 - (i - 1) * 24)
        l:SetPoint("RIGHT", p.chartBg, "RIGHT", -24, 0)
        l.sw:SetColorTexture(sl.color[1], sl.color[2], sl.color[3], 1)
        l.name:SetText(sl.label)
        l.val:SetText(ns.Coins(sl.value, 11))
        l.pct:SetText(math.floor(sl.value / ser.sum * 100 + 0.5) .. "%")
        l:Show()
      end
      y = y + 248 + 22
    else
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
    end

    p.listHead:ClearAllPoints(); p.listHead:SetPoint("TOPLEFT", 0, -y); p.listHead:SetPoint("RIGHT", c, "RIGHT")
    y = y + 28
    local items = {}
    for _, k in ipairs(ranked) do
      items[#items + 1] = { key = k, label = spec.label(k), value = ser.totals[k], color = color(k),
        sub = spec.sub and spec.sub(k, ser) or nil, onClick = spec.click and function() spec.click(k) end,
        tip = spec.tip and function(self) spec.tip(self, k, rows, starts[1], last) end }
    end
    p.list:ClearAllPoints(); p.list:SetPoint("TOPLEFT", 0, -y); p.list:SetPoint("RIGHT", c, "RIGHT")
    if #items == 0 then
      items[1] = { label = isDay and "|cff9a9aa0Nothing on this day.|r" or "|cff9a9aa0Nothing in this range yet.|r", value = 0 }
    end
    y = y + p.list:SetData(items, ser.sum) + 18

    if spec.second then
      local list = spec.second.items(rows, starts[1], last)
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
  tip = function(self, k, rows, from, to)
    -- sub-category breakdown
    local subs, any = {}, false
    for _, row in ipairs(rows) do
      if row.day and row.day >= from and row.day <= to and CatKey(row) == k then
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
  ringCaption = "spent",
  dayCards = function(p, ser, ranked, d)
    local n = 0
    for _, v in pairs(ser.count) do n = n + v end
    local top = ranked[1] and ns.Cat(ranked[1])
    p.cards[1]:Set("Spent", ns.Coins(ser.sum, 15), d.label, ser.sum > 0 and T.BAD or T.TEXT, true)
    p.cards[2]:Set("Purchases", tostring(n), n == 1 and "One thing bought" or "Things bought")
    p.cards[3]:Set("Biggest", top and top.name or "—", top and ns.Fmt(ser.totals[ranked[1]]) or "")
    local pct = d.earned > 0 and math.floor(ser.sum / d.earned * 100 + 0.5) or nil
    p.cards[4]:Set("Of what you earned", pct and (pct .. "%") or "—", "Spent / earned that day", pct and pct > 100 and T.BAD or T.TEXT)
  end,
  second = {
    title = "Top items bought",
    items = function(rows, from, to)
      local byItem, out = {}, {}
      for _, row in ipairs(rows) do
        if row.day and row.day >= from and row.day <= to and row.item and row.d < 0 and Lines.Kind(row) == "spend" then
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
  ringCaption = "earned",
  dayCards = function(p, ser, ranked, d)
    local ph = St.PerHour(ser.sum, d.played)
    p.cards[1]:Set("Earned", ns.Coins(ser.sum, 15), d.label, T.GOOD, true)
    p.cards[2]:Set("Gold per hour", ph and ns.Coins(ph, 15) or "—", d.played > 0 and ("Over " .. ns.PlayedText(d.played) .. " played") or "No playtime that day")
    p.cards[3]:Set("Top source", ranked[1] and ns.SourceLabel(ranked[1]) or "—", ranked[1] and ns.Fmt(ser.totals[ranked[1]]) or "")
    p.cards[4]:Set("Kept", ns.Coins(ser.sum - d.spent, 15), "Earned minus spent", ser.sum >= d.spent and T.TEXT or T.BAD)
  end,
  second = {
    title = "Best sellers (AH and vendor)",
    items = function(rows, from, to)
      local by, out = {}, {}
      for _, row in ipairs(rows) do
        if row.day and row.day >= from and row.day <= to and row.d > 0 and (row.src == "ah_sale") and row.note then
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
