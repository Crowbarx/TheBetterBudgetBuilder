-- Overview: Safe to spend up front, your buckets, this week, and what's new.
local _, ns = ...
local T, K, Bk, St, Lines = ns.T, ns.Kit, ns.BucketMath, ns.Stats, ns.Lines

local page = { key = "overview", order = 1, nav = "Overview", title = "Overview" }
page.subtitle = function() return "Every copper " .. (UnitName("player") or "you") .. " earns and spends." end
table.insert(ns.Pages, page)

function page.build(p)
  local c = p.child
  p.cards = { K.Card(c), K.Card(c), K.Card(c), K.Card(c) }
  p.noteHead = T.Section(c, "Heads up")
  p.notes = ns.Pool(function(parent)
    local n = CreateFrame("Button", nil, parent)
    n:SetHeight(32)
    T.Fill(n, "BACKGROUND", 0, 0, 0, 0.4):SetAllPoints()
    n.bar = T.Fill(n, "ARTWORK", 1, 1, 1, 1); n.bar:SetPoint("TOPLEFT"); n.bar:SetPoint("BOTTOMLEFT"); n.bar:SetWidth(2)
    n.text = T.Med(n, 12, T.TEXT); n.text:SetPoint("LEFT", 14, 0); n.text:SetPoint("RIGHT", -14, 0)
    n.hl = T.Fill(n, "HIGHLIGHT", 1, 1, 1, 0.04); n.hl:SetAllPoints()
    return n
  end)
  p.bucketHead = T.Section(c, "Buckets")
  p.buckets = ns.Pool(function(parent)
    local r = T.Panel(parent, true)
    r:SetHeight(54)
    r.icon = T.Icon(r, 30); r.icon:SetPoint("LEFT", 14, 0)
    r.name = T.Bold(r, 13); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 12, -1)
    r.value = T.Bold(r, 12); r.value:SetPoint("TOPRIGHT", -14, -12); r.value:SetJustifyH("RIGHT")
    r.sub = T.Med(r, 10); r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 12, 1)
    r.bar = T.Bar(r, 3)
    r.bar.track:SetPoint("BOTTOMLEFT", 56, 8); r.bar.track:SetPoint("BOTTOMRIGHT", -14, 8)
    r.sub:SetPoint("BOTTOMLEFT", r.bar.track, "TOPLEFT", 0, 5)
    r:SetScript("OnMouseUp", function() ns.ShowPage("buckets") end)
    return r
  end)
  p.weekHead = T.Section(c, "This week")
  p.week = { K.Card(c), K.Card(c), K.Card(c), K.Card(c) }
  p.recentHead = T.Section(c, "Latest")
  p.recent = ns.Pool(function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(26)
    r.when = T.Med(r, 11); r.when:SetPoint("LEFT", 4, 0); r.when:SetWidth(110)
    r.what = T.Bold(r, 12); r.what:SetPoint("LEFT", r.when, "RIGHT", 6, 0)
    r.amount = T.Bold(r, 12); r.amount:SetPoint("RIGHT", -4, 0); r.amount:SetJustifyH("RIGHT")
    r.what:SetPoint("RIGHT", r.amount, "LEFT", -10, 0)
    r.rule = T.Fill(r, "ARTWORK", 1, 1, 1, 0.05); r.rule:SetHeight(1); r.rule:SetPoint("BOTTOMLEFT"); r.rule:SetPoint("BOTTOMRIGHT")
    return r
  end)
  p.fill = T.Button(p.footFrame, "Fill buckets to goals", 210, 34, function()
    local moved = Bk.FillAll(ns.Buckets(), math.max(0, ns.Safe()), ns.Goal)
    ns.Print(moved > 0 and ("Moved " .. ns.Fmt(moved, true) .. " into your buckets.") or "Nothing to move: no safe gold, or every goal is met.")
    ns.Changed()
  end)
  p.fill:SetPoint("LEFT")
end

local function Section(s, parent, y)
  s:ClearAllPoints()
  s:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
  s:SetPoint("RIGHT", parent, "RIGHT")
  return y + 28
end

function page.refresh(p)
  local c = p.child
  local gold, saved, owed, safe = ns.Gold(), Bk.Saved(ns.Buckets()), ns.Owed(), ns.Safe()
  p.cards[1]:Set("Safe to spend", ns.Coins(safe, 15), "Gold not in a bucket or owed", safe < 0 and T.BAD or T.TEXT, true)
  p.cards[2]:Set("Gold", ns.Coins(gold, 15), ns.db.settings.includeAlts and "All your characters" or "On this character")
  p.cards[3]:Set("In buckets", ns.Coins(saved, 15), #ns.Buckets() .. " savings bucket" .. (#ns.Buckets() == 1 and "" or "s"))
  local loans = ns.OpenLoans()
  local toMe = ns.OwedToMe()
  local sub = #loans == 0 and "All paid up" or (#loans .. " loan" .. (#loans == 1 and "" or "s"))
  if toMe > 0 then sub = sub .. "  ·  they owe you " .. ns.Fmt(toMe) end
  p.cards[4]:Set("Owed to friends", ns.Coins(owed, 15), sub, owed > 0 and T.BAD or T.TEXT)
  local y = K.Columns(p.cards, c, 0, 8, 78) + 22

  -- Notes
  p.notes:Reset()
  local notes = {}
  if safe < 0 then notes[#notes + 1] = { T.BAD, "Your buckets and loans add up to more than your gold. Take some out of a bucket.", "buckets" } end
  local unsorted = ns.Unsorted()
  if unsorted > 0 then notes[#notes + 1] = { T.WARN, ("%d purchase%s in Other. Click to sort them."):format(unsorted, unsorted == 1 and " is" or "s are"), "ledger", "unsorted" } end
  local spells = ns.TrainingSpells()
  if not spells then
    notes[#notes + 1] = { T.WARN, "Visit your class trainer once so the Training bucket knows your real costs.", "training" }
  else
    local tb = ns.Bucket("training")
    local ready = ns.Training.CostBy(spells, UnitLevel("player"))
    if tb and ready > 0 then
      notes[#notes + 1] = { tb.saved >= ready and T.GOOD or T.WARN, ("Training ready now costs %s. Your Training bucket has %s."):format(ns.Fmt(ready), ns.Fmt(tb.saved)), "training" }
    end
  end
  if ns.LoanLedgerOn() then notes[#notes + 1] = { T.WARN, "Loan Ledger is still enabled. Loans live in the BBB now, so turn Loan Ledger off in your AddOns list.", "loans" } end
  p.noteHead:SetShown(#notes > 0)
  if #notes > 0 then
    y = Section(p.noteHead, c, y)
    for _, n in ipairs(notes) do
      local f = p.notes:Get(c)
      f:SetPoint("TOPLEFT", 0, -y); f:SetPoint("RIGHT", c, "RIGHT")
      f.bar:SetColorTexture(n[1][1], n[1][2], n[1][3], 1)
      f.text:SetText(n[2])
      f:SetScript("OnClick", function() if n[4] then ns.ShowLedger(n[4]) else ns.ShowPage(n[3]) end end)
      y = y + 34
    end
    y = y + 18
  end

  -- Buckets
  y = Section(p.bucketHead, c, y)
  p.buckets:Reset()
  local level = UnitLevel("player") or 1
  for _, b in ipairs(ns.Buckets()) do
    local r = p.buckets:Get(c)
    r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
    r.icon:SetTexture(b.icon)
    r.name:SetText(b.name)
    local goal = ns.Goal(b)
    r.value:SetText(ns.Coins(b.saved, 12) .. (goal and ("  |cff9a9aa0of|r  " .. ns.Coins(goal, 12)) or ""))
    local bits = {}
    if (b.pct or 0) > 0 then bits[#bits + 1] = b.pct .. "% of income" end
    local per = goal and Bk.PerLevel(b, level, goal)
    if per and b.saved < goal then bits[#bits + 1] = ns.Fmt(per) .. " per level to hit level " .. b.dueLevel end
    if goal and b.saved >= goal then bits[#bits + 1] = "|cff6bd999Goal reached|r" end
    r.sub:SetText(table.concat(bits, "   ·   "))
    r.bar:Set(goal and goal > 0 and b.saved / goal or 0, goal and b.saved >= goal and T.GOOD or nil)
    y = y + 58
  end
  y = y + 18

  -- This week
  y = Section(p.weekHead, c, y)
  local today = ns.Today()
  local monday = St.GroupStart(today, "week")
  local rows = ns.Rows()
  local earned, spent = St.Totals(rows, monday, Lines.Kind)
  local ph = St.PerHour(earned, ns.Played(monday))
  p.week[1]:Set("Earned", ns.Coins(earned, 15), "Since Monday", T.GOOD)
  p.week[2]:Set("Spent", ns.Coins(spent, 15), "Since Monday", spent > 0 and T.BAD or T.TEXT)
  p.week[3]:Set("Net", ns.Coins(earned - spent, 15), earned >= spent and "Saving" or "Spending more than you earn", earned >= spent and T.TEXT or T.BAD)
  p.week[4]:Set("Gold per hour", ph and ns.Coins(ph, 15) or "—", "Earned per hour played")
  y = y + K.Columns(p.week, c, y, 8, 78) + 22

  -- Latest
  y = Section(p.recentHead, c, y)
  p.recent:Reset()
  local shown = 0
  for i = #rows, 1, -1 do
    local row = rows[i]
    local r = p.recent:Get(c)
    r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
    r.when:SetText(K.Date(row.t, true))
    local what = ns.SourceLabel(row.src)
    local extra = row.link or row.note or row.who
    r.what:SetText(what .. (extra and ("  |cff9a9aa0" .. extra .. "|r") or ""))
    r.amount:SetText((row.d > 0 and "+" or "") .. ns.Fmt(row.d))
    local col = Lines.Kind(row) == "transfer" and T.MUTED or (row.d < 0 and T.BAD or T.GOOD)
    r.amount:SetTextColor(col[1], col[2], col[3])
    y = y + 28
    shown = shown + 1
    if shown >= 8 then break end
  end
  if shown == 0 then
    local r = p.recent:Get(c)
    r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
    r.when:SetText(""); r.amount:SetText("")
    r.what:SetText("|cff9a9aa0Nothing yet. Every gold change from now on shows up here.|r")
    y = y + 28
  end
  return y + 10
end
