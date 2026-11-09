-- The look, taken from Eric's KeyzenBars options window: Montserrat, flat
-- black-glass rows with 1px outlines, small-caps section heads with a rule, a
-- class-colored (or Midnight / Dark) gradient with fine grain, and an accent
-- that follows your class color by default.
local _, ns = ...
local T = {}
ns.T = T

T.FONT_BOLD = ns.MEDIA .. "Montserrat-Bold.ttf"
T.FONT_MED = ns.MEDIA .. "Montserrat-Medium.ttf"
T.FONT_BLACK = ns.MEDIA .. "Montserrat-Black.ttf"
T.CARET = "  |T" .. ns.MEDIA .. "Caret:10:10:0:-1|t" -- the font has no ▾ glyph
T.TEXT = { 0.95, 0.95, 0.95 }
T.MUTED = { 0.64, 0.64, 0.68 }
T.GOOD = { 0.42, 0.85, 0.6 }
T.WARN = { 0.98, 0.75, 0.3 }
T.BAD = { 0.96, 0.45, 0.45 }
T.GOLD = { 1, 0.82, 0.35 }

-- Chart series, fixed order (checked for colour blindness on dark grounds).
T.SERIES = {
  { 0.224, 0.529, 0.898 }, { 0.851, 0.349, 0.149 }, { 0.098, 0.620, 0.439 }, { 0.788, 0.522, 0.0 },
  { 0.835, 0.318, 0.506 }, { 0.0, 0.514, 0.0 }, { 0.565, 0.522, 0.914 },
}
T.MORE = { 0.42, 0.45, 0.52 }

T.THEMES = {
  { value = "classcolor", text = "Class colored" },
  { value = "midnight", text = "Midnight" },
  { value = "dark", text = "Dark" },
  { value = "wallpaper", text = "Wallpaper" },
}

-- Your wallpapers: BBB_WALLPAPERS from the BBB_Wallpaper folder's List.lua, or
-- just Wallpaper.tga.
function ns.Wallpapers()
  local list = {}
  for _, w in ipairs(type(BBB_WALLPAPERS) == "table" and BBB_WALLPAPERS or {}) do
    if type(w) == "table" and type(w.file) == "string" then
      list[#list + 1] = { value = w.file, text = w.name or w.file, file = w.file }
    end
  end
  if #list == 0 then list[1] = { value = "Wallpaper.tga", text = "Wallpaper", file = "Wallpaper.tga" } end
  return list
end

function ns.Wallpaper()
  local list = ns.Wallpapers()
  local want = ns.db and ns.db.settings.wallpaper
  for _, w in ipairs(list) do if w.file == want then return w end end
  return list[1]
end

T.widgets = {} -- repaint functions run after every change

function T.ClassRGB()
  local _, class = UnitClass("player")
  local c = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
    or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
  if c then return c.r, c.g, c.b end
  return 0.78, 0.61, 0.43
end

function T.Accent()
  local s = ns.db and ns.db.settings
  if not s or s.classAccent then
    local r, g, b = T.ClassRGB()
    return { r, g, b, 1 }
  end
  return s.accent
end

function T.Repaint() for _, fn in ipairs(T.widgets) do pcall(fn) end end

function T.SetFont(fs, path, size, color)
  if not fs:SetFont(path, size, "") then fs:SetFont(STANDARD_TEXT_FONT, size, "") end
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.9)
  if color then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
end

function T.Label(parent, path, size, color, text, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  T.SetFont(fs, path, size, color)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  if text then fs:SetText(text) end
  return fs
end
function T.Bold(parent, size, color, text) return T.Label(parent, T.FONT_BOLD, size, color or T.TEXT, text) end
function T.Med(parent, size, color, text) return T.Label(parent, T.FONT_MED, size, color or T.MUTED, text) end

function T.Fill(parent, layer, r, g, b, a, sublevel)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
  t:SetColorTexture(r, g, b, a)
  return t
end

-- 1px outline inside the frame's edges. Returns a recolor function.
function T.Outline(frame, r, g, b, a)
  local edges = {}
  for i = 1, 4 do edges[i] = frame:CreateTexture(nil, "BORDER") end
  edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
  edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
  edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
  edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
  local function Set(nr, ng, nb, na) for _, e in ipairs(edges) do e:SetColorTexture(nr, ng, nb, na or 1) end end
  Set(r, g, b, a)
  return Set
end

-- Flat button: black glass, white hairline, accent outline on hover.
-- primary = accent outline and text always.
function T.Button(parent, text, width, height, onClick, primary)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 120, height or 30)
  T.Fill(b, "BACKGROUND", 0, 0, 0, 0.5):SetAllPoints()
  local outline = T.Outline(b, 1, 1, 1, 0.16)
  b.text = T.Bold(b, 12, T.TEXT, text)
  b.text:SetPoint("CENTER")
  b.text:SetJustifyH("CENTER")
  local function Paint(hover)
    local a = T.Accent()
    if b.selected or primary or hover then outline(a[1], a[2], a[3], 1) else outline(1, 1, 1, 0.16) end
    if primary or b.selected then b.text:SetTextColor(a[1], a[2], a[3]) else b.text:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3]) end
  end
  b.Paint = Paint
  b:SetScript("OnEnter", function(self) Paint(true); if self.tip then self.tip(self) end end)
  b:SetScript("OnLeave", function() Paint(false); GameTooltip:Hide() end)
  b:SetScript("OnClick", onClick)
  function b:SetLabel(t) self.text:SetText(t) end
  function b:Fit(pad) self:SetWidth(self.text:GetStringWidth() + (pad or 28)) end
  T.widgets[#T.widgets + 1] = function() Paint(b:IsMouseOver()) end
  Paint(false)
  return b
end

-- Small caps section head with a rule, like KeyzenBars.
function T.Section(parent, title)
  local s = CreateFrame("Frame", nil, parent)
  s:SetHeight(18)
  s.text = T.Bold(s, 10, T.MUTED, title:upper())
  s.text:SetPoint("LEFT", 2, 0)
  s.rule = T.Fill(s, "ARTWORK", 1, 1, 1, 0.08)
  s.rule:SetHeight(1)
  s.rule:SetPoint("LEFT", s.text, "RIGHT", 12, 0)
  s.rule:SetPoint("RIGHT", s, "RIGHT")
  function s:SetTitle(t) self.text:SetText(t:upper()) end
  return s
end

-- A glass panel (row/card ground) with a hover wash.
function T.Panel(parent, hover)
  local p = CreateFrame("Frame", nil, parent)
  T.Fill(p, "BACKGROUND", 0, 0, 0, 0.4):SetAllPoints()
  if hover then
    local h = T.Fill(p, "BACKGROUND", 1, 1, 1, 0.03, 1)
    h:SetAllPoints(); h:Hide()
    p:EnableMouse(true)
    p:SetScript("OnEnter", function(self) h:Show(); if self.tip then self.tip(self) end end)
    p:SetScript("OnLeave", function() h:Hide(); GameTooltip:Hide() end)
  end
  return p
end

-- A progress bar: track + fill.
function T.Bar(parent, height)
  local track = T.Fill(parent, "ARTWORK", 1, 1, 1, 0.08)
  track:SetHeight(height or 4)
  local fill = parent:CreateTexture(nil, "OVERLAY")
  fill:SetTexture("Interface\\Buttons\\WHITE8x8")
  fill:SetHeight(height or 4)
  fill:SetPoint("TOPLEFT", track, "TOPLEFT")
  local bar = { track = track, fill = fill }
  function bar:Set(frac, color)
    frac = math.max(0, math.min(1, frac or 0))
    local w = self.track:GetWidth() or 0
    self.fill:SetWidth(math.max(0.01, w * frac))
    self.fill:SetShown(frac > 0)
    local c = color or T.Accent()
    self.fill:SetVertexColor(c[1], c[2], c[3], 1)
  end
  return bar
end

-- An edit box in the same glass.
function T.Input(parent, width, height, hint)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(width, height or 30)
  e:SetAutoFocus(false)
  e:SetFont(T.FONT_MED, 12, "")
  e:SetTextColor(T.TEXT[1], T.TEXT[2], T.TEXT[3])
  e:SetTextInsets(10, 10, 0, 0)
  T.Fill(e, "BACKGROUND", 0, 0, 0, 0.55):SetAllPoints()
  local outline = T.Outline(e, 1, 1, 1, 0.12)
  if hint then
    e.hint = T.Med(e, 12, T.MUTED, hint); e.hint:SetPoint("LEFT", 10, 0)
    e:HookScript("OnTextChanged", function(self) self.hint:SetShown(self:GetText() == "") end)
  end
  e:SetScript("OnEditFocusGained", function() local a = T.Accent(); outline(a[1], a[2], a[3], 0.9) end)
  e:SetScript("OnEditFocusLost", function() outline(1, 1, 1, 0.12) end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return e
end

-- A small icon with cropped edges.
function T.Icon(parent, size, texture)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(size, size)
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if texture then t:SetTexture(texture) end
  return t
end

-- A dropdown list under a button. choices = { { value, text } }.
local menu
function T.CloseMenu() if menu then menu:Hide() end end
function T.Menu(anchor, choices, current, pick)
  if not menu then
    menu = CreateFrame("Frame", "BBBMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    T.Fill(menu, "BACKGROUND", 0.06, 0.06, 0.07, 0.98):SetAllPoints()
    T.Outline(menu, 1, 1, 1, 0.16)
    menu.items = {}
    tinsert(UISpecialFrames, "BBBMenu")
  end
  for _, it in ipairs(menu.items) do it:Hide() end
  local w = math.max(anchor:GetWidth() * anchor:GetEffectiveScale() / UIParent:GetEffectiveScale(), 200)
  local y = -4
  for i, ch in ipairs(choices) do
    local it = menu.items[i]
    if not it then
      it = CreateFrame("Button", nil, menu)
      it:SetHeight(26)
      it.hl = T.Fill(it, "HIGHLIGHT", 1, 1, 1, 0.06); it.hl:SetAllPoints()
      it.text = T.Med(it, 12, T.TEXT); it.text:SetPoint("LEFT", 12, 0); it.text:SetPoint("RIGHT", -12, 0)
      menu.items[i] = it
    end
    it:ClearAllPoints()
    it:SetPoint("TOPLEFT", 1, y); it:SetPoint("TOPRIGHT", -1, y)
    if ch.heading then
      it.text:SetFont(T.FONT_BOLD, 10, ""); it.text:SetTextColor(T.MUTED[1], T.MUTED[2], T.MUTED[3])
      it.text:SetText(ch.text:upper()); it:SetScript("OnClick", nil); it.hl:SetAlpha(0)
    else
      it.text:SetFont(T.FONT_MED, 12, "")
      local a = T.Accent()
      local c = ch.value == current and a or T.TEXT
      it.text:SetTextColor(c[1], c[2], c[3])
      it.text:SetText((ch.indent and "    " or "") .. ch.text)
      it.hl:SetAlpha(1)
      it:SetScript("OnClick", function() menu:Hide(); pick(ch.value) end)
    end
    it:Show()
    y = y - 26
  end
  menu:SetSize(w, -y + 4)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  menu:Show()
end

-- Background gradient for a theme on a texture.
function T.ApplyTheme(wash, theme)
  local cr, cg, cb = T.ClassRGB()
  local function G(r1, g1, b1, r2, g2, b2)
    wash:SetGradient("VERTICAL", CreateColor(r1, g1, b1, 1), CreateColor(r2, g2, b2, 1))
  end
  if theme == "midnight" then G(0.01, 0.01, 0.04, 0.07, 0.08, 0.2)
  elseif theme == "dark" then G(0.03, 0.03, 0.03, 0.08, 0.08, 0.09)
  else G(cr * 0.04, cg * 0.04, cb * 0.04, cr * 0.32, cg * 0.32, cb * 0.32) end
end

-- Money with coin icons sized for the font.
function T.Coins(copper, size) return ns.Coins(copper, size or 12) end
