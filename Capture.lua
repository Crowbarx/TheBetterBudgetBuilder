-- Every copper: each change in your gold becomes a ledger row tagged with
-- what caused it. The rows always add up to your real gold; a gap (the addon
-- was off, another client) is written as an "Unexplained" row, never hidden.
local _, ns = ...
local Bk, Lines = ns.BucketMath, ns.Lines

local open = {}   -- windows open right now (merchant, trainer, mail...)
local pending     -- a hint from a hook just before gold moves
local last        -- last known gold on this character

function ns.Pend(src, extra, secs)
  pending = extra or {}
  pending.src = src
  pending.exp = GetTime() + (secs or 3)
end

local function ItemInfo(link)
  if not link then return nil end
  local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not get then return nil end
  local id, _, sub, _, _, classID = get(link)
  return id, classID, sub
end
ns.ItemInfo = ItemInfo

local function NpcName()
  local n = UnitName("npc")
  return n
end

---------------------------------------------------------------------------
-- Writing rows
---------------------------------------------------------------------------
local function NewRow(d, src, info)
  local db = ns.db
  db.seq = db.seq + 1
  local row = { id = "r" .. db.seq, t = time(), day = ns.Today(), char = ns.CharKey(), d = d, src = src }
  if info then
    row.who, row.item, row.ic, row.isub, row.qty, row.note, row.link =
      info.who, info.item, info.ic, info.isub, info.qty, info.note, info.link
  end
  db.ledger[#db.ledger + 1] = row
  return row
end

-- Spending: the bucket that pays for this category gives first; if the
-- buckets then hold more gold than you have, the rest is dipped from them.
local function Spend(row)
  local line = ns.LineOf(row)
  local payFrom = Lines.BucketFor(line, ns.Cats())
  local plan = Bk.PlanSpend(ns.Buckets(), -row.d, ns.Gold(), payFrom)
  if #plan > 0 then
    row.a = Bk.Apply(ns.Buckets(), plan)
    local dips = Bk.Dips(plan)
    if #dips > 0 and row.src ~= "unexplained" then
      local parts = {}
      for _, p in ipairs(dips) do
        local b = ns.Bucket(p.id)
        parts[#parts + 1] = ns.Fmt(p.take, true) .. " from " .. (b and b.name or p.id)
      end
      ns.Print(("|cffff6b6bOver your safe gold:|r that %s took %s."):format(ns.Fmt(-row.d, true), table.concat(parts, ", ")))
    end
  end
end

local function Earn(row)
  local alloc = Bk.Earn(ns.Buckets(), row.d, ns.Goal)
  if next(alloc) then row.a = alloc end
end

-- Record a change. Exposed so a loan prompt can relabel the row it made.
function ns.Record(d, src, info)
  local row = NewRow(d, src, info)
  local kind = Lines.Kind(row)
  if kind == "spend" then Spend(row) elseif kind == "income" then Earn(row) end
  return row
end

-- Change a row's source after the fact (e.g. a trade turned out to be a loan).
-- Bucket effects are kept as they were.
function ns.Relabel(row, src) row.src = src; ns.Changed() end

---------------------------------------------------------------------------
-- What was that?
---------------------------------------------------------------------------
local function Classify(d)
  local spend = d < 0
  if pending and GetTime() <= pending.exp then
    local s = Lines.SOURCES[pending.src]
    local fits = s and (s.kind == "either" or (s.kind == "income") == not spend or (s.kind == "transfer"))
    if fits then
      local p = pending
      pending = nil
      if p.src == "transfer_out" and not spend then return "transfer_in", p end
      if p.src == "transfer_in" and spend then return "transfer_out", p end
      return p.src, p
    end
  end
  if spend then
    if open.trainer then return open.trainer, { who = open.who } end
    if open.merchant then return (InRepairMode and InRepairMode()) and "repair" or "vendor_buy", { who = open.who } end
    if open.taxi then return "flight", nil end
    if open.ah then return "ah_buy", nil end
    if open.trade then return ns.IsMine(open.trade) and "transfer_out" or "trade_out", { who = open.trade, class = open.tradeClass } end
    if open.mail then return "postage", nil end
    return "other", nil
  else
    if open.merchant then return "vendor_sell", { who = open.who } end
    if open.trade then return ns.IsMine(open.trade) and "transfer_in" or "trade_in", { who = open.trade, class = open.tradeClass } end
    if open.mail then return "mail_in", nil end
    if open.ah then return "ah_refund", nil end
    if open.quest then return "quest", { note = open.quest } end
    if open.loot then return "loot", nil end
    return "other_in", nil
  end
end

-- Play time per day, for gold per hour. Counted on gold changes, login and
-- logout only (no timers).
local mark
local function Tick()
  local now = GetTime()
  if mark then
    local c = ns.Char()
    local day = ns.Today()
    c.played[day] = (c.played[day] or 0) + math.max(0, math.min(now - mark, 3600))
  end
  mark = now
end

local function OnMoney()
  local now = GetMoney()
  local d = now - (last or now)
  last = now
  local c = ns.Char()
  c.money, c.seenAt = now, time()
  Tick()
  if d == 0 then return end
  local src, info = Classify(d)
  local row = ns.Record(d, src, info)
  if ns.AfterRecord then ns.AfterRecord(row, info) end
  ns.Changed()
end

---------------------------------------------------------------------------
-- Hooks that name what you bought
---------------------------------------------------------------------------
local function InstallHooks()
  if RepairAllItems then hooksecurefunc("RepairAllItems", function(guild)
    if not guild then ns.Pend("repair", { who = NpcName(), note = "Repair all" }) end
  end) end
  if BuybackItem then hooksecurefunc("BuybackItem", function(i)
    local link = GetBuybackItemLink and GetBuybackItemLink(i)
    local id, ic, sub = ItemInfo(link)
    ns.Pend("buyback", { who = NpcName(), item = id, ic = ic, isub = sub, link = link })
  end) end
  if BuyTrainerService then hooksecurefunc("BuyTrainerService", function(i)
    local name, rank = ns.ReadTrainerService(i)
    local prof = IsTradeskillTrainer and IsTradeskillTrainer()
    local label = name and ((rank and rank ~= "") and (name .. " (" .. rank .. ")") or name)
    ns.Pend(prof and "profession" or "training", { who = NpcName(), note = label })
    if not prof and name and ns.MarkTrained then
      ns.MarkTrained(name, rank)
      C_Timer.After(0.5, function() if ns.ScanTrainer then pcall(ns.ScanTrainer) end end)
    end
  end) end
  if TakeTaxiNode then hooksecurefunc("TakeTaxiNode", function(i)
    ns.Pend("flight", { note = TaxiNodeName and ("To " .. (TaxiNodeName(i) or "?")) or nil })
  end) end
  if SendMail then hooksecurefunc("SendMail", function(to)
    local money = GetSendMailMoney and GetSendMailMoney() or 0
    if money > 0 and ns.IsMine(to) then
      ns.Pend("transfer_out", { who = to, note = "Mailed to " .. to }, 10)
    elseif money > 0 then
      local loan = ns.FindLoan and ns.FindLoan(to)
      ns.Pend(loan and "loan_repay" or "mail_gift", { who = to, note = "Mailed to " .. to, loan = loan, amount = money }, 10)
    else
      ns.Pend("postage", { who = to, note = "To " .. (to or "?") }, 10)
    end
  end) end
  local function Inbox(index)
    local _, _, sender, subject, money = GetInboxHeaderInfo(index)
    if not money or money <= 0 then return end
    local invoice = GetInboxInvoiceInfo and GetInboxInvoiceInfo(index)
    local isAH = sender and sender:find("Auction", 1, true)
    if invoice == "seller" or (isAH and subject and (subject:find("successful", 1, true) or subject:find("sold", 1, true))) then
      ns.Pend("ah_sale", { note = subject and subject:match(":%s*(.+)$") or subject }, 5)
    elseif isAH then
      ns.Pend("ah_refund", { note = subject }, 5)
    elseif ns.IsMine(sender) then
      ns.Pend("transfer_in", { who = sender, note = "From " .. sender }, 5)
    else
      ns.Pend("mail_in", { who = sender, note = "From " .. (sender or "?") }, 5)
    end
  end
  if TakeInboxMoney then hooksecurefunc("TakeInboxMoney", Inbox) end
  if AutoLootMailItem then hooksecurefunc("AutoLootMailItem", Inbox) end
  -- Auction house (Forever has the modern C_AuctionHouse API)
  if C_AuctionHouse then
    for _, fn in ipairs({ "PostItem", "PostCommodity" }) do
      if C_AuctionHouse[fn] then hooksecurefunc(C_AuctionHouse, fn, function() ns.Pend("ah_fee", nil, 5) end) end
    end
    for _, fn in ipairs({ "PlaceBid", "ConfirmCommoditiesPurchase" }) do
      if C_AuctionHouse[fn] then hooksecurefunc(C_AuctionHouse, fn, function() ns.Pend("ah_buy", nil, 8) end) end
    end
  end
  if PostAuction then hooksecurefunc("PostAuction", function() ns.Pend("ah_fee", nil, 5) end) end
  if PlaceAuctionBid then hooksecurefunc("PlaceAuctionBid", function() ns.Pend("ah_buy", nil, 5) end) end
end

---------------------------------------------------------------------------
-- Old rows: after 120 days, rows of the same day, source and line fold into one.
---------------------------------------------------------------------------
local KEEP_DAYS = 120
local function Fold()
  local ledger = ns.db.ledger
  local cutoff = ns.Today() - KEEP_DAYS
  if not ledger[1] or (ledger[1].day or cutoff) >= cutoff then return end
  local out, groups = {}, {}
  for _, r in ipairs(ledger) do
    if (r.day or 0) < cutoff then
      local line = ns.LineOf(r)
      local key = r.day .. "|" .. r.src .. "|" .. line .. "|" .. (r.d < 0 and "-" or "+") .. "|" .. (r.char or "")
      local g = groups[key]
      if g then g.d = g.d + r.d; g.n = (g.n or 1) + 1
      else
        g = { id = r.id, t = r.t, day = r.day, char = r.char, d = r.d, src = r.src, line = line, folded = true, n = 1 }
        groups[key] = g
        out[#out + 1] = g
      end
    else
      out[#out + 1] = r
    end
  end
  ns.db.ledger = out
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- Some messages arrive after the gold does (fast auto-loot pays out before the
-- loot window opens; quest money lands before the turn-in event). If an
-- unlabeled income row was just written, give it the right source.
local function Explain(src, amount, extra)
  local led, now, me = ns.db.ledger, time(), ns.CharKey()
  for i = #led, math.max(1, #led - 5), -1 do
    local r = led[i]
    if r.char == me and r.src == "other_in" and now - (r.t or 0) <= 3 and (not amount or r.d == amount) then
      r.src = src
      if extra then for k, v in pairs(extra) do r[k] = v end end
      ns.Changed()
      return true
    end
  end
end

local function Open(key, v) open[key] = v or true; open[key .. "Closed"] = nil end
local function Close(key, secs)
  open[key .. "Closed"] = true
  C_Timer.After(secs or 1.5, function()
    if open[key .. "Closed"] then open[key] = nil; open[key .. "Closed"] = nil end
  end)
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_MONEY", "PLAYER_LEVEL_UP",
  "MERCHANT_SHOW", "MERCHANT_CLOSED", "TRAINER_SHOW", "TRAINER_CLOSED", "TAXIMAP_OPENED", "TAXIMAP_CLOSED",
  "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED",
  "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "QUEST_TURNED_IN", "QUEST_COMPLETE", "QUEST_FINISHED", "CHAT_MSG_MONEY" }) do
  pcall(ev.RegisterEvent, ev, e)
end

ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
  if event == "ADDON_LOADED" then
    if a1 == ns.ADDON then ns.InitDB() end
  elseif event == "PLAYER_LOGIN" then
    local c = ns.Char()
    local _, class = UnitClass("player")
    c.class, c.level, c.name = class, UnitLevel("player"), UnitName("player")
    local now = GetMoney()
    if c.money and c.money ~= now then
      local row = ns.Record(now - c.money, "unexplained", { note = "Gold changed while BBB wasn't watching" })
      row.auto = true
    end
    c.money, c.seenAt = now, time()
    last = now
    Tick()
    Fold()
    InstallHooks()
    if ns.InstallGuard then ns.InstallGuard() end
    ns.Changed()
  elseif event == "PLAYER_LOGOUT" then
    Tick()
    local c = ns.Char()
    c.money, c.seenAt = GetMoney(), time()
  elseif event == "PLAYER_MONEY" then
    OnMoney()
  elseif event == "PLAYER_LEVEL_UP" then
    local lvl = tonumber(a1) or UnitLevel("player")
    local c = ns.Char()
    c.level = lvl
    c.levels[lvl] = time()
    C_Timer.After(1, function() if ns.LevelUpReminder then ns.LevelUpReminder(lvl) end ns.Changed() end)
  elseif event == "MERCHANT_SHOW" then Open("merchant"); open.who = NpcName()
  elseif event == "MERCHANT_CLOSED" then Close("merchant")
  elseif event == "TRAINER_SHOW" then
    Open("trainer", (IsTradeskillTrainer and IsTradeskillTrainer()) and "profession" or "training")
    open.who = NpcName()
    C_Timer.After(0.2, function() if ns.ScanTrainer then pcall(ns.ScanTrainer) end end)
  elseif event == "TRAINER_CLOSED" then Close("trainer")
  elseif event == "TAXIMAP_OPENED" then Open("taxi")
  elseif event == "TAXIMAP_CLOSED" then Close("taxi", 3)
  elseif event == "AUCTION_HOUSE_SHOW" then Open("ah")
  elseif event == "AUCTION_HOUSE_CLOSED" then Close("ah")
  elseif event == "MAIL_SHOW" then Open("mail")
  elseif event == "MAIL_CLOSED" then Close("mail")
  elseif event == "TRADE_SHOW" then
    local n, realm = UnitName("NPC")
    if n and realm and realm ~= "" then n = n .. "-" .. realm end
    local _, class = UnitClass("NPC")
    Open("trade", n or "?")
    open.tradeClass = class
  elseif event == "TRADE_CLOSED" then Close("trade", 2)
  elseif event == "LOOT_OPENED" or event == "LOOT_READY" then Open("loot")
  elseif event == "LOOT_CLOSED" then Close("loot", 1)
  elseif event == "CHAT_MSG_MONEY" then
    if not Explain("loot") then ns.Pend("loot", nil, 2) end
  elseif event == "QUEST_TURNED_IN" then
    local money = tonumber(a3) or 0
    local title = type(open.quest) == "string" and open.quest or nil
    if money > 0 and not Explain("quest", money, { note = title }) then ns.Pend("quest", { note = title }, 3) end
  elseif event == "QUEST_COMPLETE" then Open("quest", GetTitleText and GetTitleText() or true)
  elseif event == "QUEST_FINISHED" then Close("quest", 1.5)
  end
end)

function ns.OpenWindows() return open end
