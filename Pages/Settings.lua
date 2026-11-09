-- Settings: look, the guard, bags, alts, categories and saved rules.
local _, ns = ...
local T, K = ns.T, ns.Kit

local page = { key = "settings", order = 8, nav = "Settings", title = "Settings", subtitle = "How the BBB looks and behaves." }
table.insert(ns.Pages, page)

local function S() return ns.db.settings end

local function ToggleRow(c, label, desc, key, after)
  local r = K.SettingRow(c, label, desc)
  local t = K.Toggle(r, function() return S()[key] end, function(v) S()[key] = v; if after then after(v) end end)
  t:SetPoint("RIGHT", -18, 0)
  return r
end

function page.build(p)
  local c = p.child
  p.lookHead = T.Section(c, "Look")
  p.look = {}
  local theme = K.SettingRow(c, "Theme", "The window's background.")
  theme.btn = T.Button(theme, "", 160, 30, function(self)
    T.Menu(self, T.THEMES, S().theme, function(v) S().theme = v; ns.Changed() end)
  end)
  theme.btn:SetPoint("RIGHT", -18, 0)
  T.widgets[#T.widgets + 1] = function()
    for _, t in ipairs(T.THEMES) do if t.value == S().theme then theme.btn:SetLabel(t.text .. T.CARET) end end
  end
  p.look[#p.look + 1] = theme
  p.look[#p.look + 1] = ToggleRow(c, "Class color accent", "Highlights in your class color.", "classAccent")
  local scale = K.SettingRow(c, "Window scale", "Size of the whole window.")
  scale.value = T.Bold(scale, 12); scale.value:SetPoint("RIGHT", -96, 0)
  local function Step(d)
    S().contentScale = math.max(0.5, math.min(1.3, math.floor((S().contentScale + d) * 20 + 0.5) / 20))
    ns.ApplyScale(); ns.Changed()
  end
  scale.minus = T.Button(scale, "-", 30, 26, function() Step(-0.05) end); scale.minus:SetPoint("RIGHT", -54, 0)
  scale.plus = T.Button(scale, "+", 30, 26, function() Step(0.05) end); scale.plus:SetPoint("RIGHT", -18, 0)
  T.widgets[#T.widgets + 1] = function() scale.value:SetText(math.floor(S().contentScale * 100 + 0.5) .. "%") end
  p.look[#p.look + 1] = scale
  local pic = K.SettingRow(c, "Wallpaper", "Which of your pictures to show.")
  pic.btn = T.Button(pic, "", 160, 30, function(self)
    T.Menu(self, ns.Wallpapers(), ns.Wallpaper().file, function(v) S().wallpaper = v; ns.Changed() end)
  end)
  pic.btn:SetPoint("RIGHT", -18, 0)
  T.widgets[#T.widgets + 1] = function()
    pic.btn:SetLabel(ns.Wallpaper().text .. T.CARET)
    pic:SetAlpha(S().theme == "wallpaper" and 1 or 0.4)
  end
  local acc = K.SettingRow(c, "Accent color", "Used when class color is off.")
  acc.btn = T.Button(acc, "", 160, 30, function(self)
    local choices = {}
    for _, a in ipairs(T.ACCENTS) do
      choices[#choices + 1] = { value = a.text, text = ("|cff%02x%02x%02x%s|r"):format(a.rgb[1] * 255, a.rgb[2] * 255, a.rgb[3] * 255, a.text) }
    end
    choices[#choices + 1] = { value = "custom", text = "Custom..." }
    T.Menu(self, choices, not S().classAccent and T.AccentName() or nil, function(v)
      if v == "custom" then T.PickAccentColor(); return end
      for _, a in ipairs(T.ACCENTS) do
        if a.text == v then S().accent = { a.rgb[1], a.rgb[2], a.rgb[3], 1 }; S().classAccent = false end
      end
      ns.Changed()
    end)
  end)
  acc.btn:SetPoint("RIGHT", -18, 0)
  acc.swatch = T.Fill(acc, "ARTWORK", 1, 1, 1, 1); acc.swatch:SetSize(14, 14)
  acc.swatch:SetPoint("RIGHT", acc.btn, "LEFT", -10, 0)
  T.widgets[#T.widgets + 1] = function()
    local a = S().accent
    acc.swatch:SetColorTexture(a[1], a[2], a[3], 1)
    acc.btn:SetLabel((S().classAccent and "Class color" or T.AccentName()) .. T.CARET)
    acc:SetAlpha(S().classAccent and 0.6 or 1)
  end
  local shadeRow = K.SettingRow(c, "Wallpaper shade", "Darker keeps text easy to read.")
  shadeRow.value = T.Bold(shadeRow, 12); shadeRow.value:SetPoint("RIGHT", -96, 0)
  local function Shade(d)
    S().artShade = math.max(0.4, math.min(0.92, math.floor(((S().artShade or 0.72) + d) * 100 + 0.5) / 100))
    ns.Changed()
  end
  shadeRow.minus = T.Button(shadeRow, "-", 30, 26, function() Shade(-0.04) end); shadeRow.minus:SetPoint("RIGHT", -54, 0)
  shadeRow.plus = T.Button(shadeRow, "+", 30, 26, function() Shade(0.04) end); shadeRow.plus:SetPoint("RIGHT", -18, 0)
  T.widgets[#T.widgets + 1] = function()
    shadeRow.value:SetText(math.floor((S().artShade or 0.72) * 100 + 0.5) .. "%")
    shadeRow:SetAlpha(S().theme == "wallpaper" and 1 or 0.4)
  end
  p.look[#p.look + 1] = acc
  p.look[#p.look + 1] = shadeRow
  p.look[#p.look + 1] = pic

  p.behaveHead = T.Section(c, "Behavior")
  p.behave = {
    ToggleRow(c, "Vendor guard", "Asks before a buy uses savings.", "guard"),
    ToggleRow(c, "Loan prompts", "Asks if gold traded was a loan.", "loanPrompts"),
    ToggleRow(c, "Count alts' gold", "One budget for every character.", "includeAlts"),
    ToggleRow(c, "Minimap button", "Left: the BBB. Right: Buckets.", "minimapShown", function(v) if ns.SetMinimapShown then ns.SetMinimapShown(v) end end),
  }
  p.bagHead = T.Section(c, "Bags (EllesmereUI)")
  p.bag = {
    ToggleRow(c, "Budget tab in bags", "A Budget row in the bag sidebar.", "bagRow", function() ReloadUI() end),
    ToggleRow(c, "Safe to spend by your gold", "Shown in the bag footer.", "bagFooter"),
    ToggleRow(c, "Hide my total gold", "Bags show only Safe to spend.", "hideBagGold"),
  }
  p.bag[1].sub:SetText("Sidebar row. Reloads your UI.")

  p.catHead = T.Section(c, "Spending categories")
  p.catRows = ns.Pool(function(parent)
    local r = T.Panel(parent, true)
    r:SetHeight(34)
    r.name = T.Bold(r, 12); r.name:SetPoint("LEFT", 16, 0)
    r.info = T.Med(r, 11); r.info:SetPoint("LEFT", r.name, "RIGHT", 12, 0)
    r.edit = T.Button(r, "Edit" .. T.CARET, 80, 24, function() end); r.edit:SetPoint("RIGHT", -10, 0)
    return r
  end)
  p.addCat = T.Button(c, "+ New category", 160, 30, function()
    ns.Ask("Name the new category:", "", function(t)
      if t and t ~= "" then table.insert(ns.Cats(), #ns.Cats(), { id = "c" .. time() .. math.random(100, 999), name = t }); ns.Changed() end
    end)
  end)
  p.ruleHead = T.Section(c, "Remembered sorting")
  p.ruleRows = ns.Pool(function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(26)
    r.text = T.Med(r, 11, T.TEXT); r.text:SetPoint("LEFT", 4, 0)
    r.del = T.Button(r, "Forget", 70, 22, function() end); r.del:SetPoint("RIGHT", -4, 0)
    return r
  end)
  p.dataHead = T.Section(c, "Data")
  p.reset = T.Button(c, "Start the ledger over", 220, 30, function()
    ns.Confirm("Erase every ledger row for all characters? Buckets, loans and categories stay.", function()
      ns.db.ledger = {}; ns.Changed()
    end)
  end)
end

local function CatMenu(cat)
  local ch = { { value = "rename", text = "Rename" } }
  if not cat.parent then ch[#ch + 1] = { value = "sub", text = "Add a sub-category" } end
  ch[#ch + 1] = { heading = true, text = "Paid from bucket" }
  ch[#ch + 1] = { value = "bucket:", text = "No bucket (safe gold)" }
  for _, b in ipairs(ns.Buckets()) do ch[#ch + 1] = { value = "bucket:" .. b.id, text = b.name } end
  if cat.id ~= "other" then ch[#ch + 1] = { value = "delete", text = "|cffff6b6bDelete|r" } end
  return ch
end

local function EditCat(cat, v)
  if v == "rename" then
    ns.Ask("Rename " .. cat.name .. ":", cat.name, function(t) if t and t ~= "" then cat.name = t; ns.Changed() end end)
  elseif v == "sub" then
    ns.Ask("Name the sub-category under " .. cat.name .. ":", "", function(t)
      if t and t ~= "" then
        local pos = #ns.Cats()
        for i, c in ipairs(ns.Cats()) do if c.id == cat.id or c.parent == cat.id then pos = i end end
        table.insert(ns.Cats(), pos + 1, { id = "c" .. time() .. math.random(100, 999), name = t, parent = cat.id }); ns.Changed()
      end
    end)
  elseif v:match("^bucket:") then
    local id = v:sub(8)
    cat.bucket = id ~= "" and id or nil
    ns.Changed()
  elseif v == "delete" then
    ns.Confirm(("Delete %s? Its purchases move to Other."):format(cat.name), function()
      local list = ns.Cats()
      for i = #list, 1, -1 do if list[i] == cat or list[i].parent == cat.id then table.remove(list, i) end end
      ns.Changed()
    end)
  end
end

local function Head(h, c, y)
  h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:SetPoint("RIGHT", c, "RIGHT")
  return y + 28
end

function page.refresh(p)
  local c = p.child
  local y = Head(p.lookHead, c, 0)
  y = y + K.Grid(p.look, c, y, 52, 2) + 22
  y = Head(p.behaveHead, c, y)
  y = y + K.Grid(p.behave, c, y, 52, 2) + 22
  y = Head(p.bagHead, c, y)
  y = y + K.Grid(p.bag, c, y, 52, 2) + 22

  y = Head(p.catHead, c, y)
  p.catRows:Reset()
  for _, cat in ipairs(ns.Cats()) do
    local r = p.catRows:Get(c)
    r:SetPoint("TOPLEFT", cat.parent and 28 or 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
    r.name:SetText(cat.name)
    local b = cat.bucket and ns.Bucket(cat.bucket)
    r.info:SetText(b and ("paid from " .. b.name) or "")
    r.edit:SetScript("OnClick", function(self) T.Menu(self, CatMenu(cat), nil, function(v) EditCat(cat, v) end) end)
    y = y + 36
  end
  p.addCat:ClearAllPoints(); p.addCat:SetPoint("TOPLEFT", 0, -(y + 4))
  y = y + 52

  p.ruleRows:Reset()
  local rules = {}
  for k, v in pairs(ns.db.rules) do rules[#rules + 1] = { k = k, v = v } end
  table.sort(rules, function(a, b) return a.k < b.k end)
  p.ruleHead:SetShown(#rules > 0)
  if #rules > 0 then
    y = Head(p.ruleHead, c, y)
    for _, e in ipairs(rules) do
      local r = p.ruleRows:Get(c)
      r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
      local kind, id = e.k:match("^(%a+):(.+)$")
      local what = id
      if kind == "item" then
        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(tonumber(id))
        what = name or ("item " .. id)
      end
      r.text:SetText(what .. "  |cff9a9aa0→|r  " .. ns.LineLabel(e.v))
      r.del:SetScript("OnClick", function() ns.db.rules[e.k] = nil; ns.Changed() end)
      y = y + 28
    end
    y = y + 22
  end

  y = Head(p.dataHead, c, y)
  p.reset:ClearAllPoints(); p.reset:SetPoint("TOPLEFT", 0, -y)
  return y + 44
end
