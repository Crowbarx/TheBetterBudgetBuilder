-- Loans (what Loan Ledger did, now part of the BBB), both ways:
--   dir "in"  (or nil): a friend lent you gold. What you owe comes out of Safe to spend.
--   dir "out": you lent a friend gold. Shown as owed to you; not counted as spending
--              when you hand it over, or as income when they pay it back.
local _, ns = ...

local function Key(name) return name and ((name:match("^([^%-]+)") or name):lower()) or nil end

function ns.Remaining(loan) return math.max(0, (loan.amount or 0) - (loan.paid or 0)) end

local function Dir(l) return l.dir or "in" end
ns.LoanDir = Dir

-- Open loans one way ("in" = you owe, "out" = owed to you; default "in").
function ns.OpenLoans(dir)
  dir = dir or "in"
  local list, total = {}, 0
  for _, l in ipairs(ns.db.loans) do
    local r = ns.Remaining(l)
    if r > 0 and Dir(l) == dir then list[#list + 1] = l; total = total + r end
  end
  table.sort(list, function(a, b) return ns.Remaining(a) > ns.Remaining(b) end)
  return list, total
end

function ns.FindLoan(name, dir)
  local k = Key(name)
  if not k then return nil end
  dir = dir or "in"
  for _, l in ipairs(ns.db.loans) do
    if Key(l.name) == k and ns.Remaining(l) > 0 and Dir(l) == dir then return l end
  end
end

function ns.OwedToMe() local _, t = ns.OpenLoans("out"); return t end

function ns.AddLoan(name, copper, note, class, dir)
  name = name and name:gsub("^%s+", ""):gsub("%s+$", "")
  if not name or name == "" or not copper or copper <= 0 then return end
  name = name:sub(1, 1):upper() .. name:sub(2)
  dir = dir or "in"
  local loan = ns.FindLoan(name, dir)
  if loan then
    loan.amount = loan.amount + copper
  else
    loan = { name = name, amount = copper, paid = 0, date = time(), note = (note ~= "" and note) or nil, class = class, history = {},
      dir = dir ~= "in" and dir or nil }
    table.insert(ns.db.loans, loan)
  end
  table.insert(loan.history, { t = time(), kind = "lent", amount = copper })
  if dir == "out" then
    ns.Print(("You lent %s %s. They owe you %s."):format(loan.name, ns.Fmt(copper, true), ns.Fmt(ns.Remaining(loan), true)))
  else
    ns.Print(("%s lent you %s. You owe them %s."):format(loan.name, ns.Fmt(copper, true), ns.Fmt(ns.Remaining(loan), true)))
  end
  ns.Changed()
  return loan
end

function ns.Repay(loan, copper)
  if not loan or not copper or copper <= 0 then return end
  copper = math.min(copper, ns.Remaining(loan))
  loan.paid = (loan.paid or 0) + copper
  table.insert(loan.history, { t = time(), kind = "repaid", amount = copper })
  local out = Dir(loan) == "out"
  if ns.Remaining(loan) == 0 then
    loan.cleared = time()
    ns.Print(out and ("%s paid you back in full."):format(loan.name) or ("Paid off %s."):format(loan.name))
  elseif out then
    ns.Print(("%s paid you %s. They still owe you %s."):format(loan.name, ns.Fmt(copper, true), ns.Fmt(ns.Remaining(loan), true)))
  else
    ns.Print(("Paid %s %s. %s left."):format(loan.name, ns.Fmt(copper, true), ns.Fmt(ns.Remaining(loan), true)))
  end
  ns.Changed()
end

function ns.DeleteLoan(loan)
  for i, l in ipairs(ns.db.loans) do if l == loan then table.remove(ns.db.loans, i); break end end
  ns.Changed()
end

function ns.Whisper(loan)
  if ChatFrame_SendTell then ChatFrame_SendTell(loan.name) end
end

-- Loan Ledger asks about trades and mail too; while it's enabled, stay quiet
-- so you don't get two prompts.
function ns.LoanLedgerOn()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  return loaded and loaded("LoanLedger") and true or false
end

local function Prompts() return ns.db.settings.loanPrompts and not ns.LoanLedgerOn() end

-- After a row is written: ask whether a trade or mail was a loan.
local function Unfill(row)
  -- Borrowed or repaid gold isn't income: give back what auto-fill put in buckets.
  for id, v in pairs(row.a or {}) do
    local b = ns.Bucket(id)
    if b then b.saved = math.max(0, b.saved - v) end
  end
  row.a = nil
end

function ns.AfterRecord(row, info)
  if not Prompts() then return end
  local who = row.who
  if row.src == "trade_in" and who then
    local mine = ns.FindLoan(who, "out")
    if mine then
      ns.Confirm(("%s traded you %s.\nCount it as paying back what they owe you (%s)?"):format(mine.name, ns.Fmt(row.d, true), ns.Fmt(ns.Remaining(mine), true)), function()
        Unfill(row)
        ns.Repay(mine, row.d)
        ns.Relabel(row, "loan_back")
      end, nil, "Yes, paid back", "No")
      return
    end
    ns.Confirm(("%s traded you %s.\nWas it a loan you need to pay back?"):format(who, ns.Fmt(row.d, true)), function()
      Unfill(row)
      ns.AddLoan(who, row.d, nil, info and info.class)
      ns.Relabel(row, "loan_in")
    end, nil, "Yes, a loan", "No")
  elseif (row.src == "trade_out" or row.src == "mail_gift") and who then
    local loan = ns.FindLoan(who)
    local how = row.src == "trade_out" and "traded" or "mailed"
    if loan then
      ns.Confirm(("You %s %s to %s.\nCount it as paying back your loan?"):format(how, ns.Fmt(-row.d, true), loan.name), function()
        ns.Repay(loan, -row.d)
        ns.Relabel(row, "loan_repay")
      end)
    else
      ns.Confirm(("You %s %s to %s.\nWas it a loan they'll pay you back?"):format(how, ns.Fmt(-row.d, true), who), function()
        ns.AddLoan(who, -row.d, nil, info and info.class, "out")
        ns.Relabel(row, "loan_out")
      end, nil, "Yes, a loan", "No")
    end
  elseif row.src == "mail_in" and who then
    local mine = ns.FindLoan(who, "out")
    if mine then
      ns.Confirm(("%s mailed you %s.\nCount it as paying back what they owe you?"):format(mine.name, ns.Fmt(row.d, true)), function()
        Unfill(row)
        ns.Repay(mine, row.d)
        ns.Relabel(row, "loan_back")
      end, nil, "Yes, paid back", "No")
    end
  elseif row.src == "loan_repay" then
    local loan = info and info.loan or ns.FindLoan(who)
    if loan then
      local amount = info and info.amount or -row.d
      ns.Confirm(("You mailed %s to %s.\nCount it as paying back your loan?"):format(ns.Fmt(amount, true), loan.name), function()
        ns.Repay(loan, amount)
      end, function() ns.Relabel(row, "mail_gift") end)
    end
  end
end

-- "X has come online" while you owe them.
local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:SetScript("OnEvent", function(_, _, msg)
  if not ns.db or ns.LoanLedgerOn() then return end
  local who = type(msg) == "string" and msg:match("|Hplayer:([^|:]+)")
  if who and msg:find("online", 1, true) and not msg:find("offline", 1, true) then
    local loan = ns.FindLoan(who)
    if loan then ns.Print(("%s is online. You still owe them %s."):format(loan.name, ns.Fmt(ns.Remaining(loan), true))) end
    local mine = ns.FindLoan(who, "out")
    if mine then ns.Print(("%s is online. They still owe you %s."):format(mine.name, ns.Fmt(ns.Remaining(mine), true))) end
  end
end)
