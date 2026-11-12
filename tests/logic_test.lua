-- Unit tests for the WoW-free math. Run from the addon folder:
--   luajit tests/logic_test.lua
-- (Eric: %LOCALAPPDATA%\Programs\LuaJIT\bin\luajit.exe tests\logic_test.lua)
-- Not loaded by the game (the .toc doesn't list it).
local base = (arg and arg[0] or ""):match("^(.-)tests[/\\][^/\\]*$") or ""
local ns = {}
for _, f in ipairs({ "Logic/Money.lua", "Logic/Period.lua", "Logic/Lines.lua", "Logic/Buckets.lua", "Logic/Training.lua", "Logic/Stats.lua" }) do
  local chunk = assert(loadfile(base .. f))
  chunk("BetterBudgetBuilder", ns)
end
local M, P, L, Bk, Tr, St = ns.Money, ns.Period, ns.Lines, ns.BucketMath, ns.Training, ns.Stats

local passed, failed = 0, 0
local function eq(got, want, name)
  if got == want then passed = passed + 1
  else failed = failed + 1; print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want))) end
end

-- Money
eq(M.Format(1234567), "123g 45s 67c", "format")
eq(M.Format(0), "0c", "format zero")
eq(M.Format(-250), "-2s 50c", "format negative")
eq(M.Format(10000), "1g", "format whole gold")
eq(M.Format(12345678), "1,234g 56s 78c", "format commas")
eq(M.Parse("5"), 50000, "parse plain gold")
eq(M.Parse("12g 50s"), 125000, "parse g s")
eq(M.Parse("75s"), 7500, "parse silver")
eq(M.Parse("1,200g"), 12000000, "parse commas")
eq(M.Parse("2.5g"), 25000, "parse decimal")
eq(M.Parse("abc"), nil, "parse junk")
eq(M.Parse("5g junk"), nil, "parse trailing junk")
eq(M.CeilDiv(10, 3), 4, "ceildiv")
eq(M.CeilDiv(9, 3), 3, "ceildiv exact")

-- Period
local anchor = P.Day("2026-11-03")
eq(P.Ymd(anchor), "2026-11-03", "ymd roundtrip")
eq(P.Day("1970-01-01"), 0, "epoch")
eq(P.Weekday(anchor), 2, "2026-11-03 is a Tuesday")
eq(P.Id(P.Day("2026-11-09"), anchor, 7), "2026-11-03", "period of a day")
eq(P.Id(P.Day("2026-11-10"), anchor, 7), "2026-11-10", "next period")
eq(P.Id(P.Day("2026-11-02"), anchor, 7), "2026-10-27", "period before anchor")
eq(P.Until(P.Day("2026-11-03"), P.Day("2026-11-03"), 7), 1, "until same day")
eq(P.Until(P.Day("2026-11-03"), P.Day("2026-11-24"), 7), 4, "until 3 weeks later")
eq(P.Until(P.Day("2026-11-03"), P.Day("2026-11-01"), 7), 0, "until overdue")
eq(P.DaysLeft(P.Day("2026-11-09"), anchor, 7), 1, "days left last day")
eq(P.Ymd(P.Day("2028-02-29") + 1), "2028-03-01", "leap day")

-- Lines
local cats = L.DefaultCategories()
eq(L.LineFor({ src = "repair", d = -100 }, {}, cats), "cat:repairs", "repair default")
eq(L.LineFor({ src = "training", d = -100 }, {}, cats), "cat:training", "training")
eq(L.LineFor({ src = "vendor_buy", d = -100, ic = 0, isub = "Food & Drink" }, {}, cats), "cat:food", "food by subtype")
eq(L.LineFor({ src = "vendor_buy", d = -100, ic = 0, isub = "Scroll" }, {}, cats), "cat:consumables", "other consumable")
eq(L.LineFor({ src = "vendor_buy", d = -100, ic = 5 }, {}, cats), "cat:reagents", "reagent")
eq(L.LineFor({ src = "vendor_buy", d = -100, ic = 4 }, {}, cats), "cat:vendor", "armor = vendor purchases")
eq(L.LineFor({ src = "vendor_buy", d = -100, item = 7, ic = 4 }, { ["item:7"] = "cat:repairs" }, cats), "cat:repairs", "item rule")
eq(L.LineFor({ src = "vendor_buy", d = -100, who = "Bob" }, { ["npc:Bob"] = "cat:travel" }, cats), "cat:travel", "npc rule")
eq(L.LineFor({ src = "vendor_buy", d = -100, item = 7, line = "cat:travel" }, { ["item:7"] = "cat:repairs" }, cats), "cat:travel", "row pick beats rule")
eq(L.LineFor({ src = "vendor_buy", d = -100, item = 7 }, { ["item:7"] = "cat:gone" }, cats), "cat:vendor", "rule to deleted category ignored")
eq(L.LineFor({ src = "loot", d = 100 }, {}, cats), "income:loot", "income")
eq(L.LineFor({ src = "transfer_in", d = 100 }, {}, cats), "transfer", "transfer")
eq(L.LineFor({ src = "unexplained", d = -100 }, {}, cats), "cat:other", "unexplained loss")
eq(L.LineFor({ src = "unexplained", d = 100 }, {}, cats), "income:unexplained", "unexplained gain")
eq(L.TopOf("food", cats), "consumables", "top of sub-category")
eq(L.BucketFor("cat:training", cats), "training", "training paid by bucket")
eq(L.BucketFor("cat:food", cats), nil, "food has no bucket")

-- Buckets
local function bk() return {
  { id = "training", saved = 20000, pct = 25 },
  { id = "mount", saved = 500000, pct = 25 },
  { id = "fun", saved = 0, pct = 0 },
} end
local bs = bk()
eq(Bk.Saved(bs), 520000, "saved")
eq(Bk.Safe(600000, bs, 30000), 50000, "safe = gold - buckets - owed")
local goals = { training = 25000, mount = 10000000 }
local alloc = Bk.Earn(bs, 40000, function(b) return goals[b.id] end)
eq(alloc.training, 5000, "earn capped at goal")
eq(alloc.mount, 10000, "earn 25%")
eq(alloc.fun, nil, "0% takes nothing")
eq(bs[1].saved, 25000, "training full")
-- training costs 30000; training bucket has 20000, gold 100000 -> after 70000, buckets 520000
bs = bk()
local plan = Bk.PlanSpend(bs, 30000, 70000, "training")
eq(plan[1].id, "training", "paying bucket first")
eq(plan[1].take, 20000, "paying bucket gives what it has")
eq(plan[1].paid, true, "marked as the payer")
eq(plan[2].id, "mount", "then the bottom bucket with gold (fun is empty)")
eq(plan[2].take, 430000, "dip = held - gold left")
eq(#Bk.Dips(plan), 1, "one dip")
Bk.Apply(bs, plan)
eq(Bk.Saved(bs), 70000, "buckets now match gold")
-- a spend fully covered by safe gold touches nothing
bs = bk()
eq(#Bk.PlanSpend(bs, 1000, 600000, nil), 0, "no dip when safe covers it")
eq(Bk.PerLevel({ dueLevel = 60, saved = 0 }, 30, 10000000), 333334, "per level rounds up")
bs = bk()
eq(Bk.FillAll(bs, 100000, function(b) return goals[b.id] end), 100000, "fill top first until safe runs out"); eq(bs[1].saved, 25000, "training filled to goal")

-- Training
local spells = {
  { name = "A", lvl = 30, cost = 1000, used = true },
  { name = "B", lvl = 30, cost = 2000 },
  { name = "C", lvl = 32, cost = 3000 },
  { name = "D", lvl = 32, cost = 500, skip = true },
  { name = "E", lvl = 34, cost = 4000 },
}
eq((Tr.CostBy(spells, 30)), 2000, "ready now")
local nl, nc = Tr.NextLevel(spells, 30)
eq(nl, 32, "next level"); eq(nc, 3000, "next level cost (skip ignored)")
eq(Tr.Goal(spells, 30), 5000, "goal = now + next")
eq(Tr.Goal({}, 30), nil, "no scan, no goal")
eq(Tr.Goal(spells, 30, { [34] = true }), 9000, "pre-save a later level")
eq(Tr.Goal(spells, 30, { [32] = false }), 2000, "take the next level out")
eq(Tr.Goal(spells, 30, { [30] = false }), 5000, "ready spells always count")
eq(Tr.InGoal(34, 30, 32, nil), false, "later level out by default")

-- Stats
local today = P.Day("2026-11-09") -- a Monday
eq(St.GroupStart(today, "week"), today, "monday starts the week")
eq(St.GroupStart(P.Day("2026-11-15"), "week"), today, "sunday belongs to the week")
eq(P.Ymd(St.GroupStart(today, "month")), "2026-11-01", "month start")
local g = St.Groups(today, "month", 3)
eq(P.Ymd(g[1]), "2026-09-01", "3 months back")
local rows = {
  { day = today, d = -500, src = "repair" },
  { day = today - 1, d = -300, src = "repair" },
  { day = today - 7, d = -200, src = "flight" },
  { day = today, d = 1000, src = "loot" },
}
local ser = St.Series(rows, St.Groups(today, "week", 2), "week", function(r) return L.Kind(r) == "spend" and r.src or nil end, -1)
eq(ser.totals.repair, 800, "series total")
eq(ser.grid[2].repair, 500, "this week")
eq(ser.grid[1].repair, 300, "last week (sunday)")
eq(ser.grid[1].flight, 200, "last week flight")
eq(ser.sum, 1000, "series sum")
local ranked = St.Ranked({ a = 5, b = 9, c = 1 }, 2)
eq(ranked[1], "b", "ranked first"); eq(#ranked, 2, "ranked limit")
eq(St.PerHour(10000, 1800), 20000, "per hour")
local e, s2 = St.Totals(rows, today - 1, L.Kind)
eq(e, 1000, "earned"); eq(s2, 800, "spent")

-- Auto-fill never puts more in buckets than you have room for
local cb = { { id = "a", saved = 0, pct = 50 }, { id = "b", saved = 0, pct = 50 } }
local ca = Bk.Earn(cb, 10000, nil, 6000)
eq(ca.a, 5000, "room: first bucket"); eq(ca.b, 1000, "room: capped"); eq(Bk.Saved(cb), 6000, "room: total")
eq(next(Bk.Earn(cb, 10000, nil, 0)), nil, "no room, no fill")
-- Clamp takes the extra from the bottom of the list
local kb = { { id = "top", saved = 5000 }, { id = "low", saved = 3000 } }
eq(Bk.Clamp(kb, 6000), 2000, "clamp removed"); eq(kb[2].saved, 1000, "bottom first"); eq(kb[1].saved, 5000, "top kept")
eq(Bk.Clamp(kb, -50), 6000, "clamp to zero"); eq(Bk.Saved(kb), 0, "all out")

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
