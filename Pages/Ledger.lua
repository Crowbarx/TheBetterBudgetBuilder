-- Ledger: every gold change, newest first. Search, filter, and sort any
-- purchase into a category (once, or always for that item or vendor).
local _, ns = ...
local T, K, Lines = ns.T, ns.Kit, ns.Lines

local page = { key = "ledger", order = 4, nav = "Ledger", title = "Ledger", subtitle = "Every copper in and out, newest first." }
page.badge = function() local n = ns.Unsorted(); return n > 0 and tostring(n) or "" end
table.insert(ns.Pages, page)

local PAGE_SIZE = 150
local filter, search, limit = "all", "", PAGE_SIZE

function ns.ShowLedger(f)
  filter = f or "all"
  search, limit = "", PAGE_SIZE
  if page.searchBox then page.searchBox:SetText("") end
  ns.ShowPage("ledger")
end

-- Category choices for menus: top-level, then their sub-categories.
local function CatChoices()
  local list = {}
  for _, c in ipairs(ns.Cats()) do
    if not c.parent then
      list[#list + 1] = { value = "cat:" .. c.id, text = c.name }
      for _, s in ipairs(ns.Cats()) do
        if s.parent == c.id then list[#list + 1] = { value = "cat:" .. s.id, text = s.name, indent = true } end
      end
    end
  end
  return list
end

local function FilterChoices()
  local list = {
    { value = "all", text = "Everything" }, { value = "spend", text = "Spending" }, { value = "income", text = "Income" },
    { value = "transfer", text = "Transfers" }, { value = "unsorted", text = "Unsorted (Other)" },
    { heading = true, text = "Category" },
  }
  for _, ch in ipairs(CatChoices()) do list[#list + 1] = ch end
  list[#list + 1] = { heading = true, text = "Income source" }
  for _, src in ipairs(Lines.INCOME_ORDER) do list[#list + 1] = { value = "income:" .. src, text = ns.SourceLabel(src) } end
  return list
end

local function FilterLabel()
  for _, ch in ipairs(FilterChoices()) do if ch.value == filter then return ch.text end end
  return "Everything"
end

local function Matches(row, line)
  local kind = Lines.Kind(row)
  if filter == "spend" and kind ~= "spend" then return false end
  if filter == "income" and kind ~= "income" then return false end
  if filter == "transfer" and kind ~= "transfer" then return false end
  if filter == "unsorted" and not (kind == "spend" and Lines.IsUnsorted(line)) then return false end
  if filter:match("^cat:") then
    local want = filter:sub(5)
    local id = line:match("^cat:(.+)$")
    if not id or (id ~= want and Lines.TopOf(id, ns.Cats()) ~= want) then return false end
  end
  if filter:match("^income:") and line ~= filter then return false end
  if search ~= "" then
    local hay = table.concat({ ns.SourceLabel(row.src), row.note or "", row.who or "", row.link or "",
      ns.LineLabel(line), ns.Fmt(math.abs(row.d)) }, " "):lower()
    for word in search:gmatch("%S+") do if not hay:find(word, 1, true) then return false end end
  end
  return true
end

local function Filtered()
  local out = {}
  local rows = ns.Rows()
  for i = #rows, 1, -1 do
    local r = rows[i]
    local line = ns.LineOf(r)
    if Matches(r, line) then out[#out + 1] = { row = r, line = line } end
  end
  return out
end

-- Put a row in a category; offer to remember it for the item or vendor.
local function Assign(row, line)
  row.line = line
  ns.Changed()
  local key, what
  if row.item then key, what = "item:" .. row.item, row.link or "this item"
  elseif row.who then key, what = "npc:" .. row.who, row.who end
  if key then
    ns.Confirm(("Always put %s in %s?"):format(what, ns.LineLabel(line)), function()
      ns.db.rules[key] = line
      ns.Changed()
    end, nil, "Always", "Just this once")
  end
end

function page.build(p)
  local c = p.child
  p.searchBox = T.Input(c, 300, 32, "Search names, items or amounts")
  p.searchBox:SetScript("OnTextChanged", function(self)
    if self.hint then self.hint:SetShown(self:GetText() == "") end
    search, limit = self:GetText():lower(), PAGE_SIZE
    ns.RefreshWindow()
  end)
  p.filterBtn = T.Button(c, "Everything", 220, 32, function(self)
    T.Menu(self, FilterChoices(), filter, function(v) filter, limit = v, PAGE_SIZE; ns.RefreshWindow() end)
  end)
  p.count = T.Med(c, 11)
  p.rows = ns.Pool(function(parent)
    local r = T.Panel(parent, true)
    r:SetHeight(36)
    r.when = T.Med(r, 11); r.when:SetPoint("LEFT", 14, 0); r.when:SetWidth(96)
    r.what = T.Bold(r, 12); r.what:SetPoint("LEFT", r.when, "RIGHT", 8, 0)
    r.amount = T.Bold(r, 12); r.amount:SetPoint("RIGHT", -14, 0); r.amount:SetJustifyH("RIGHT"); r.amount:SetWidth(110)
    r.chip = CreateFrame("Button", nil, r)
    r.chip:SetHeight(22)
    r.chip:SetPoint("RIGHT", r.amount, "LEFT", -12, 0)
    r.chip.bg = T.Fill(r.chip, "BACKGROUND", 1, 1, 1, 0.08); r.chip.bg:SetAllPoints()
    r.chip.outline = T.Outline(r.chip, 1, 1, 1, 0.1)
    r.chip.text = T.Bold(r.chip, 10, T.TEXT); r.chip.text:SetPoint("CENTER")
    r.what:SetPoint("RIGHT", r.chip, "LEFT", -10, 0)
    r.chip:SetScript("OnEnter", function(self) local a = T.Accent(); self.outline(a[1], a[2], a[3], 0.9) end)
    r.chip:SetScript("OnLeave", function(self) self.outline(1, 1, 1, 0.1) end)
    return r
  end)
  p.more = T.Button(c, "Show more", 160, 30, function() limit = limit + PAGE_SIZE; ns.RefreshWindow() end)
  p.bulk = T.Button(p.toolsFrame, "Put these in…", 10, 30, function(self)
    local list = Filtered()
    local n = 0
    for _, e in ipairs(list) do if Lines.Kind(e.row) == "spend" then n = n + 1 end end
    if n == 0 then ns.Print("Nothing here to sort (only purchases can go in a category).") return end
    T.Menu(self, CatChoices(), nil, function(v)
      ns.Confirm(("Put these %d purchase%s in %s?"):format(n, n == 1 and "" or "s", ns.LineLabel(v)), function()
        for _, e in ipairs(list) do if Lines.Kind(e.row) == "spend" then e.row.line = v end end
        ns.Changed()
      end)
    end)
  end)
  p.bulk:Fit(28)
  p.bulk:SetPoint("RIGHT")
end

function page.refresh(p)
  local c = p.child
  p.searchBox:ClearAllPoints(); p.searchBox:SetPoint("TOPLEFT", 0, 0)
  p.filterBtn:ClearAllPoints(); p.filterBtn:SetPoint("LEFT", p.searchBox, "RIGHT", 8, 0)
  p.filterBtn:SetLabel(FilterLabel() .. T.CARET)
  local list = Filtered()
  local total = 0
  for _, e in ipairs(list) do if Lines.Kind(e.row) ~= "transfer" then total = total + e.row.d end end
  p.count:ClearAllPoints(); p.count:SetPoint("LEFT", p.filterBtn, "RIGHT", 14, 0)
  p.count:SetText(("%d row%s  ·  net %s"):format(#list, #list == 1 and "" or "s", ns.Fmt(total)))
  local y = 46
  p.rows:Reset()
  for i = 1, math.min(#list, limit) do
    local e = list[i]
    local row, line = e.row, e.line
    local r = p.rows:Get(c)
    r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
    r.when:SetText(K.Date(row.t, true))
    local extra = row.link or row.note or row.who
    if row.folded then extra = (row.n or 1) .. " changes that day" end
    r.what:SetText(ns.SourceLabel(row.src) .. (extra and ("  |cff9a9aa0" .. extra .. "|r") or ""))
    local kind = Lines.Kind(row)
    r.amount:SetText((row.d > 0 and "+" or "") .. ns.Coins(row.d, 11))
    local col = kind == "transfer" and T.MUTED or (row.d < 0 and T.BAD or T.GOOD)
    r.amount:SetTextColor(col[1], col[2], col[3])
    r.chip.text:SetText(ns.LineLabel(line))
    r.chip:SetWidth(r.chip.text:GetStringWidth() + 20)
    local unsorted = kind == "spend" and Lines.IsUnsorted(line)
    if unsorted then r.chip.bg:SetColorTexture(T.WARN[1], T.WARN[2], T.WARN[3], 0.22) else r.chip.bg:SetColorTexture(1, 1, 1, 0.08) end
    if kind == "spend" then
      r.chip:SetScript("OnClick", function(self) T.Menu(self, CatChoices(), line, function(v) Assign(row, v) end) end)
    else
      r.chip:SetScript("OnClick", nil)
    end
    r.tip = function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(ns.SourceLabel(row.src), 1, 1, 1)
      if row.link then GameTooltip:AddLine(row.link) end
      if row.note then GameTooltip:AddLine(row.note, 0.8, 0.8, 0.8, true) end
      if row.who then GameTooltip:AddDoubleLine("With", row.who, 0.7, 0.7, 0.7, 1, 1, 1) end
      GameTooltip:AddLine(date("%A %b %d, %H:%M", row.t), 0.6, 0.6, 0.6)
      if row.a then
        for id, v in pairs(row.a) do
          local b = ns.Bucket(id)
          GameTooltip:AddDoubleLine(row.d < 0 and ("From " .. (b and b.name or id)) or ("Into " .. (b and b.name or id)), ns.Fmt(v, true), 0.8, 0.8, 0.8)
        end
      end
      if kind == "spend" then GameTooltip:AddLine("Click the tag to sort it.", 0.6, 0.6, 0.6) end
      GameTooltip:Show()
    end
    y = y + 38
  end
  p.more:SetShown(#list > limit)
  if #list > limit then
    p.more:ClearAllPoints(); p.more:SetPoint("TOP", c, "TOPLEFT", c:GetWidth() / 2, -y - 6)
    y = y + 46
  end
  if #list == 0 then
    local r = p.rows:Get(c)
    r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
    r.when:SetText(""); r.amount:SetText(""); r.chip.text:SetText(""); r.chip:SetWidth(1); r.chip:SetScript("OnClick", nil)
    r.what:SetText("|cff9a9aa0Nothing matches.|r"); r.tip = nil
    y = y + 38
  end
  return y + 8
end
