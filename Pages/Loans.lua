-- Loans: gold friends lent you, and gold you lent them.
local _, ns = ...
local T, K = ns.T, ns.Kit

local page = { key = "loans", order = 6, nav = "Loans", title = "Loans", subtitle = "Gold you owe friends, and gold they owe you." }
page.badge = function() local n = #ns.OpenLoans() + #ns.OpenLoans("out"); return n > 0 and tostring(n) or "" end
table.insert(ns.Pages, page)

local function Status(name)
  local key = name and (name:match("^([^%-]+)") or name):lower()
  if C_FriendList and C_FriendList.GetNumFriends then
    for i = 1, C_FriendList.GetNumFriends() or 0 do
      local info = C_FriendList.GetFriendInfoByIndex(i)
      if info and info.name and (info.name:match("^([^%-]+)") or info.name):lower() == key then return info.connected end
    end
  end
end

function page.build(p)
  local c = p.child
  p.rows = ns.Pool(function(parent)
    local r = T.Panel(parent, true)
    r:SetHeight(84)
    r.dot = T.Fill(r, "ARTWORK", 1, 1, 1, 1); r.dot:SetSize(7, 7); r.dot:SetPoint("TOPLEFT", 18, -21)
    r.name = T.Bold(r, 15); r.name:SetPoint("LEFT", r.dot, "RIGHT", 9, 0)
    r.owed = T.Bold(r, 15, T.BAD); r.owed:SetPoint("TOPRIGHT", -18, -14); r.owed:SetJustifyH("RIGHT")
    r.sub = T.Med(r, 11); r.sub:SetPoint("TOPLEFT", 34, -38); r.sub:SetPoint("RIGHT", -18, 0)
    r.whisper = T.Button(r, "Whisper", 90, 24, function() end); r.whisper:SetPoint("BOTTOMLEFT", 34, 10)
    r.repay = T.Button(r, "Paid back", 100, 24, function() end); r.repay:SetPoint("LEFT", r.whisper, "RIGHT", 6, 0)
    r.more = T.Button(r, "+ More", 80, 24, function() end); r.more:SetPoint("LEFT", r.repay, "RIGHT", 6, 0)
    r.del = T.Button(r, "Delete", 80, 24, function() end); r.del:SetPoint("BOTTOMRIGHT", -18, 10)
    return r
  end)
  p.oweHead = T.Section(c, "You owe")
  p.theyHead = T.Section(c, "Owed to you")
  p.formHead = T.Section(c, "Add a loan")
  p.form = T.Panel(c)
  p.form:SetHeight(104)
  p.dir = "in"
  p.dirPick = K.Segmented(p.form, { { value = "in", text = "They lent me" }, { value = "out", text = "I lent them" } },
    function() return p.dir end, function(v) p.dir = v end)
  p.dirPick:SetPoint("TOPLEFT", 14, -12)
  p.nameBox = T.Input(p.form, 180, 32, "Their name")
  p.nameBox:SetPoint("BOTTOMLEFT", 14, 14)
  p.amountBox = T.Input(p.form, 120, 32, "Amount (250g)")
  p.amountBox:SetPoint("LEFT", p.nameBox, "RIGHT", 8, 0)
  p.noteBox = T.Input(p.form, 200, 32, "Note (optional)")
  p.noteBox:SetPoint("LEFT", p.amountBox, "RIGHT", 8, 0)
  p.addBtn = T.Button(p.form, "Add", 90, 32, function()
    local v = ns.Money.Parse(p.amountBox:GetText())
    if p.nameBox:GetText() == "" or not v or v <= 0 then ns.Print("Enter a name and an amount, like 250 or 12g 50s.") return end
    ns.AddLoan(p.nameBox:GetText(), v, p.noteBox:GetText(), nil, p.dir)
    p.nameBox:SetText(""); p.amountBox:SetText(""); p.noteBox:SetText("")
  end, true)
  p.addBtn:SetPoint("LEFT", p.noteBox, "RIGHT", 8, 0)
  p.hint = T.Med(c, 11)
  p.hint:SetWordWrap(true)
  p.paidHead = T.Section(c, "Paid off")
  p.paid = ns.Pool(function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(24)
    r.text = T.Med(r, 11, T.MUTED); r.text:SetPoint("LEFT", 4, 0)
    r.amount = T.Med(r, 11, T.MUTED); r.amount:SetPoint("RIGHT", -4, 0)
    return r
  end)
end

local function Row(p, c, loan, y)
  local out = ns.LoanDir(loan) == "out"
  local r = p.rows:Get(c)
  r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
  r.name:SetText(loan.name)
  local token = loan.class
  local cc = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
  if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3]) end
  local online = Status(loan.name)
  if online then r.dot:SetColorTexture(T.GOOD[1], T.GOOD[2], T.GOOD[3], 1) else r.dot:SetColorTexture(0.5, 0.5, 0.5, online == false and 0.8 or 0.3) end
  local col = out and T.GOOD or T.BAD
  r.owed:SetTextColor(col[1], col[2], col[3])
  r.owed:SetText((out and "+" or "-") .. ns.Coins(ns.Remaining(loan), 14))
  local bits = { (online and "Online now  ·  " or "") .. (out and "Lent " or "Since ") .. K.Date(loan.date) }
  if (loan.paid or 0) > 0 then bits[#bits + 1] = (out and "they paid " or "paid ") .. ns.Fmt(loan.paid) .. " of " .. ns.Fmt(loan.amount) end
  if loan.note then bits[#bits + 1] = loan.note end
  r.sub:SetText(table.concat(bits, "   ·   "))
  r.whisper:SetScript("OnClick", function() ns.Whisper(loan) end)
  r.repay:SetLabel(out and "They paid" or "Paid back")
  r.repay:SetScript("OnClick", function()
    local q = out and ("How much did %s pay you back? (they owe %s)") or ("How much did you pay back %s? (you owe %s)")
    ns.AskMoney(q:format(loan.name, ns.Fmt(ns.Remaining(loan))), ns.Fmt(ns.Remaining(loan)), function(v) ns.Repay(loan, v) end)
  end)
  r.more:SetScript("OnClick", function()
    ns.AskMoney((out and "You lent %s more? How much?" or "%s lent you more? How much?"):format(loan.name), "",
      function(v) ns.AddLoan(loan.name, v, nil, nil, ns.LoanDir(loan)) end)
  end)
  r.del:SetScript("OnClick", function()
    local q = out and "Delete the loan to %s (%s they owe you)?" or "Delete the loan from %s (%s owed)?"
    ns.Confirm(q:format(loan.name, ns.Fmt(ns.Remaining(loan), true)), function() ns.DeleteLoan(loan) end)
  end)
  return y + 92
end

local function Head(h, c, y, title)
  h:Show(); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:SetPoint("RIGHT", c, "RIGHT")
  h:SetTitle(title)
  return y + 28
end

function page.refresh(p)
  local c = p.child
  local list, total = ns.OpenLoans()
  local theirs, theirTotal = ns.OpenLoans("out")
  local y = 0
  p.rows:Reset()
  p.oweHead:SetShown(#list > 0); p.theyHead:SetShown(#theirs > 0)
  if #list > 0 then
    y = Head(p.oweHead, c, y, "You owe " .. ns.Fmt(total))
    for _, loan in ipairs(list) do y = Row(p, c, loan, y) end
    y = y + 12
  end
  if #theirs > 0 then
    y = Head(p.theyHead, c, y, "Owed to you " .. ns.Fmt(theirTotal))
    for _, loan in ipairs(theirs) do y = Row(p, c, loan, y) end
    y = y + 12
  end
  list = #list + #theirs > 0 and { 1 } or {}
  if #list == 0 then y = y + 4 end
  p.formHead:ClearAllPoints(); p.formHead:SetPoint("TOPLEFT", 0, -y); p.formHead:SetPoint("RIGHT", c, "RIGHT")
  p.formHead:SetTitle(#list == 0 and "Nothing owed either way. Add a loan" or "Add a loan")
  y = y + 28
  p.form:ClearAllPoints(); p.form:SetPoint("TOPLEFT", 0, -y); p.form:SetPoint("RIGHT", c, "RIGHT")
  y = y + 114
  p.hint:ClearAllPoints(); p.hint:SetPoint("TOPLEFT", 2, -y); p.hint:SetPoint("RIGHT", c, "RIGHT")
  p.hint:SetText(ns.LoanLedgerOn() and "|cfffabf4dLoan Ledger is still on, so the BBB isn't asking about trades. Turn Loan Ledger off in your AddOns list.|r"
    or "When gold changes hands in a trade or the mail, the BBB asks whether it was a loan, either way. Gold you lend isn't counted as spending, and getting it back isn't counted as income.")
  y = y + p.hint:GetStringHeight() + 22
  local paid = {}
  for _, l in ipairs(ns.db.loans) do if ns.Remaining(l) == 0 then paid[#paid + 1] = l end end
  p.paidHead:SetShown(#paid > 0)
  p.paid:Reset()
  if #paid > 0 then
    p.paidHead:ClearAllPoints(); p.paidHead:SetPoint("TOPLEFT", 0, -y); p.paidHead:SetPoint("RIGHT", c, "RIGHT")
    y = y + 28
    for _, l in ipairs(paid) do
      local r = p.paid:Get(c)
      r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
      r.text:SetText((ns.LoanDir(l) == "out" and ("Lent to " .. l.name) or ("Borrowed from " .. l.name)) .. "  ·  paid off " .. K.Date(l.cleared))
      r.amount:SetText(ns.Fmt(l.amount))
      y = y + 24
    end
  end
  return y + 8
end
