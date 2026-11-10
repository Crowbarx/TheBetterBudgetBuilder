-- The deep-dive window (/bbb), laid out like KeyzenBars' options: a sidebar of
-- pages, a big title, the page in a scrolling area, buttons along the foot.
-- Built the first time you open it, never at login.
local _, ns = ...
local T = ns.T

local WIDTH, HEIGHT = 1040, 700
local SIDEBAR = 220
local HEADER = 100
local FOOTER = 62
local PAD = 30

ns.Pages = ns.Pages or {}   -- filled by Pages/*.lua: { key, nav, title, subtitle, build(p), refresh(p) -> height }
local window, root, current
local built = {}

local function Version()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(ns.ADDON, "Version") or ""
end

local function PageByKey(key)
  for i, p in ipairs(ns.Pages) do if p.key == key then return p, i end end
end

local function MakeView(content, page)
  local scroll = CreateFrame("ScrollFrame", nil, content)
  scroll:SetPoint("TOPLEFT", PAD, -18)
  scroll:SetPoint("BOTTOMRIGHT", -PAD + 12, 10)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(1, 1)
  scroll:SetScrollChild(child)
  local thumb = T.Fill(scroll, "ARTWORK", 1, 1, 1, 0.22)
  thumb:SetWidth(3)
  page.scroll, page.child = scroll, child
  function page:UpdateScroll()
    local h, total = scroll:GetHeight(), child:GetHeight()
    local maxScroll = math.max(0, total - h)
    if scroll:GetVerticalScroll() > maxScroll then scroll:SetVerticalScroll(maxScroll) end
    if maxScroll <= 0 then thumb:Hide() return end
    local th = math.max(30, h * h / total)
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, -(scroll:GetVerticalScroll() / maxScroll) * (h - th))
    thumb:Show()
  end
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    T.CloseMenu()
    local maxScroll = math.max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 60)))
    page:UpdateScroll()
  end)
  scroll:SetScript("OnSizeChanged", function(_, w)
    child:SetWidth(w - 14)
    if page.shown then ns.RefreshWindow() end
  end)
  page.W = function() return child:GetWidth() end
end

local function Create()
  window = CreateFrame("Frame", "BBBWindow", UIParent)
  window:SetSize(WIDTH, HEIGHT)
  window:SetPoint("CENTER")
  window:SetFrameStrata("HIGH")
  window:SetToplevel(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:SetClampedToScreen(true)
  tinsert(UISpecialFrames, "BBBWindow")

  root = CreateFrame("Frame", nil, window)
  root:SetPoint("TOPLEFT")
  local function Scale()
    local s = ns.WindowScale()
    window:SetSize(WIDTH * s, HEIGHT * s)
    root:SetScale(s)
    root:SetSize(WIDTH, HEIGHT)
  end
  Scale()
  window.Scale = Scale

  -- Ground: dark tint, theme gradient, fine grain (KeyzenBars).
  T.Fill(root, "BACKGROUND", 0.02, 0.02, 0.04, 1, -8):SetAllPoints()
  -- Your own pictures live in Interface\\AddOns\\BBB_Wallpaper, a folder of its own
  -- so addon updates never delete them. Each is 2048x1024 with the image in the
  -- left 1521 px (this window's shape). BBB_Wallpaper\\List.lua can name several
  -- (BBB_WALLPAPERS); without it, Wallpaper.tga is used.
  local art = root:CreateTexture(nil, "BACKGROUND", nil, -7)
  art:SetAllPoints()
  art:SetTexCoord(0, 1521 / 2048, 0, 1) -- picture fills the left part of a 2048x1024 texture
  local shade = T.Fill(root, "BACKGROUND", 0.02, 0.02, 0.04, 0.72, -6)
  shade:SetAllPoints()
  local wash = root:CreateTexture(nil, "BACKGROUND", nil, -6)
  wash:SetAllPoints()
  wash:SetTexture("Interface\\Buttons\\WHITE8x8")
  local grain = root:CreateTexture(nil, "BACKGROUND", nil, -5)
  grain:SetAllPoints()
  grain:SetTexture(ns.MEDIA .. "Noise.tga", "REPEAT", "REPEAT")
  grain:SetHorizTile(true); grain:SetVertTile(true)
  grain:SetBlendMode("ADD"); grain:SetAlpha(0.025)
  T.Outline(root, 0, 0, 0, 1)
  T.widgets[#T.widgets + 1] = function()
    local st = ns.db.settings
    local pic = st.theme == "wallpaper"
    art:SetShown(pic); shade:SetShown(pic)
    wash:SetShown(not pic); grain:SetShown(not pic)
    if pic then art:SetTexture("Interface\\AddOns\\BBB_Wallpaper\\" .. ns.Wallpaper().file) end
    if pic then shade:SetColorTexture(0.02, 0.02, 0.04, st.artShade or 0.72)
    else T.ApplyTheme(wash, st.theme) end
  end

  -- Sidebar
  local side = CreateFrame("Frame", nil, root)
  side:SetPoint("TOPLEFT"); side:SetPoint("BOTTOMLEFT"); side:SetWidth(SIDEBAR)
  T.Fill(side, "BACKGROUND", 0, 0, 0, 0.5):SetAllPoints()
  local edge = T.Fill(side, "ARTWORK", 1, 1, 1, 0.07)
  edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
  local logo = T.Label(side, T.FONT_BLACK, 30, T.TEXT, "The BBB")
  logo:SetPoint("TOPLEFT", 24, -28)
  local tagline = T.Med(side, 11, T.MUTED, "Better Budget Builder")
  tagline:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 1, -8)
  local logoRule = T.Fill(side, "ARTWORK", 1, 1, 1, 0.08)
  logoRule:SetHeight(1)
  logoRule:SetPoint("TOPLEFT", 20, -HEADER + 4); logoRule:SetPoint("TOPRIGHT", -20, -HEADER + 4)
  local version = T.Med(side, 11, T.MUTED, "v" .. Version() .. "   /bbb")
  version:SetPoint("BOTTOMLEFT", 26, 22)

  -- Safe to spend, always in view under the logo
  local safe = CreateFrame("Frame", nil, side)
  safe:SetPoint("BOTTOMLEFT", 20, 52); safe:SetPoint("BOTTOMRIGHT", -20, 52); safe:SetHeight(58)
  T.Fill(safe, "BACKGROUND", 0, 0, 0, 0.4):SetAllPoints()
  local safeOutline = T.Outline(safe, 1, 1, 1, 0.1)
  safe.label = T.Bold(safe, 9, T.MUTED, "SAFE TO SPEND"); safe.label:SetPoint("TOPLEFT", 12, -10)
  safe.value = T.Bold(safe, 15, T.TEXT); safe.value:SetPoint("TOPLEFT", safe.label, "BOTTOMLEFT", 0, -7)
  T.widgets[#T.widgets + 1] = function()
    local v = ns.Safe()
    safe.value:SetText(ns.Coins(v, 14))
    local c = v < 0 and T.BAD or T.TEXT
    safe.value:SetTextColor(c[1], c[2], c[3])
    local a = T.Accent(); safeOutline(a[1], a[2], a[3], 0.5)
  end

  -- Header (drag handle)
  local drag = CreateFrame("Frame", nil, root)
  drag:SetPoint("TOPLEFT"); drag:SetPoint("TOPRIGHT"); drag:SetHeight(HEADER)
  drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart", function() window:StartMoving() end)
  drag:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
  local title = T.Bold(root, 30, T.TEXT)
  title:SetPoint("TOPLEFT", SIDEBAR + PAD, -28)
  local subtitle = T.Med(root, 13, T.MUTED)
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -8)
  local close = T.Button(root, "X", 34, 34, function() window:Hide() end)
  close:SetPoint("TOPRIGHT", -18, -18)
  close:SetFrameLevel(drag:GetFrameLevel() + 2)
  -- Draw the X from two lines instead of a font glyph, which could come up blank.
  close.lines = {}
  local rotates = close:CreateTexture().SetRotation ~= nil
  if rotates then close.text:SetText("") end
  for i, deg in ipairs(rotates and { 45, -45 } or {}) do
    local l = close:CreateTexture(nil, "OVERLAY")
    l:SetTexture("Interface\\Buttons\\WHITE8x8")
    l:SetSize(14, 2); l:SetPoint("CENTER")
    l:SetRotation(math.rad(deg))
    close.lines[i] = l
  end
  local paintClose = close.Paint
  close.Paint = function(hover)
    paintClose(hover)
    local c = hover and T.Accent() or T.TEXT
    for _, l in ipairs(close.lines) do l:SetVertexColor(c[1], c[2], c[3], 1) end
  end
  close:SetScript("OnEnter", function() close.Paint(true) end)
  close:SetScript("OnLeave", function() close.Paint(false) end)
  T.widgets[#T.widgets + 1] = function() close.Paint(close:IsMouseOver()) end
  close.Paint(false)
  local headRule = T.Fill(root, "ARTWORK", 1, 1, 1, 0.07)
  headRule:SetHeight(1)
  headRule:SetPoint("TOPLEFT", SIDEBAR, -HEADER); headRule:SetPoint("TOPRIGHT", 0, -HEADER)
  -- page-specific header controls go here (range pickers etc.)
  local tools = CreateFrame("Frame", nil, root)
  tools:SetPoint("BOTTOMRIGHT", root, "TOPRIGHT", -PAD, -HEADER + 14)
  tools:SetSize(500, 30)
  tools:SetFrameLevel(drag:GetFrameLevel() + 2)
  window.tools = tools

  -- Content and footer
  local content = CreateFrame("Frame", nil, root)
  content:SetPoint("TOPLEFT", SIDEBAR, -HEADER)
  content:SetPoint("BOTTOMRIGHT", 0, FOOTER)
  local footRule = T.Fill(root, "ARTWORK", 1, 1, 1, 0.07)
  footRule:SetHeight(1)
  footRule:SetPoint("BOTTOMLEFT", SIDEBAR, FOOTER); footRule:SetPoint("BOTTOMRIGHT", 0, FOOTER)
  local foot = CreateFrame("Frame", nil, root)
  foot:SetPoint("BOTTOMLEFT", SIDEBAR + PAD, 14); foot:SetPoint("BOTTOMRIGHT", -PAD, 14); foot:SetHeight(34)
  window.foot = foot
  local done = T.Button(foot, "Close", 150, 34, function() window:Hide() end, true)
  done:SetPoint("RIGHT")

  -- Navigation
  table.sort(ns.Pages, function(a, b) return (a.order or 50) < (b.order or 50) end)
  local nav = {}
  for i, page in ipairs(ns.Pages) do
    local nb = CreateFrame("Button", nil, side)
    nb:SetHeight(40)
    nb:SetPoint("TOPLEFT", 0, -HEADER - 16 - (i - 1) * 42)
    nb:SetPoint("TOPRIGHT", -1, -HEADER - 16 - (i - 1) * 42)
    local sel = T.Fill(nb, "BACKGROUND", 1, 1, 1, 0.07); sel:SetAllPoints()
    local hl = T.Fill(nb, "HIGHLIGHT", 1, 1, 1, 0.04); hl:SetAllPoints()
    local bar = T.Fill(nb, "ARTWORK", 1, 1, 1, 1)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(3)
    local text = T.Bold(nb, 14, T.TEXT, page.nav)
    text:SetPoint("LEFT", 26, 0)
    nb.badge = T.Bold(nb, 10, T.WARN); nb.badge:SetPoint("RIGHT", -16, 0)
    nb:SetScript("OnClick", function() ns.ShowPage(page.key) end)
    T.widgets[#T.widgets + 1] = function()
      local on = current == page
      local a = T.Accent()
      sel:SetShown(on); bar:SetShown(on)
      bar:SetColorTexture(a[1], a[2], a[3], 1)
      local c = on and T.TEXT or T.MUTED
      text:SetTextColor(c[1], c[2], c[3])
      nb.badge:SetText(page.badge and page.badge() or "")
    end
    nav[i] = nb
  end

  function window:SetHeading(t, s) title:SetText(t); subtitle:SetText(s or "") end
  window.content = content
  window:SetScript("OnShow", function()
    if ns.db.settings.wallpaper == "shuffle" then ns.ShuffleWallpaper() end
    ns.RefreshWindow()
  end)
  window:SetScript("OnHide", function() T.CloseMenu() end)
  window:Hide()
end

function ns.ShowPage(key)
  if not window then Create() end
  local page = PageByKey(key) or ns.Pages[1]
  T.CloseMenu()
  if current and current ~= page then
    current.shown = false
    if current.scroll then current.scroll:Hide() end
    if current.toolsFrame then current.toolsFrame:Hide() end
    if current.footFrame then current.footFrame:Hide() end
  end
  current = page
  if not built[page] then
    built[page] = true
    MakeView(window.content, page)
    page.toolsFrame = CreateFrame("Frame", nil, window.tools); page.toolsFrame:SetAllPoints()
    page.footFrame = CreateFrame("Frame", nil, window.foot); page.footFrame:SetAllPoints()
    page.build(page)
  end
  page.shown = true
  page.scroll:Show(); page.toolsFrame:Show(); page.footFrame:Show()
  page.scroll:SetVerticalScroll(0)
  window:SetHeading(page.title, type(page.subtitle) == "function" and page.subtitle() or page.subtitle)
  ns.db.settings.lastPage = page.key
  if not window:IsShown() then window:Show() else ns.RefreshWindow() end
end

function ns.RefreshWindow()
  if not window or not window:IsShown() then return end
  if not current then ns.ShowPage(ns.db.settings.lastPage or "overview"); return end
  if current.child:GetWidth() > 10 then
    local h = current.refresh(current) or 1
    current.child:SetHeight(math.max(1, h))
    current:UpdateScroll()
  end
  window:SetHeading(current.title, type(current.subtitle) == "function" and current.subtitle() or current.subtitle)
  T.Repaint()
end

function ns.ToggleWindow(key)
  if window and window:IsShown() and (not key or (current and current.key == key)) then window:Hide(); return end
  ns.ShowPage(key or (current and current.key) or ns.db.settings.lastPage or "overview")
end

-- Window scale: your setting, or (Auto) a size that suits your screen. It never
-- grows past what fits on screen, so big UI scales and small monitors work.
local function Fit()
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  if not w or w <= 0 or not h or h <= 0 then return 1.5 end
  return math.min(w * 0.96 / WIDTH, h * 0.94 / HEIGHT)
end
function ns.AutoScale()
  local h = UIParent:GetHeight() or 768
  local s = math.floor(h * 0.72 / HEIGHT * 20 + 0.5) / 20
  return math.max(0.5, math.min(1.5, s))
end
function ns.WindowScale()
  local s = ns.db and ns.db.settings.contentScale or ns.AutoScale()
  return math.max(0.4, math.min(s, Fit()))
end
function ns.ApplyScale() if window then window.Scale() end end
-- Re-fit when the resolution or UI scale changes (events only, no timers).
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("UI_SCALE_CHANGED"); f:RegisterEvent("DISPLAY_SIZE_CHANGED")
  f:SetScript("OnEvent", function() ns.ApplyScale() end)
end
function ns.ResetWindow()
  if not window then return end
  window:ClearAllPoints(); window:SetPoint("CENTER")
  ns.ApplyScale()
end

ns.OnChange(function() ns.RefreshWindow() end)

-- A pool helper for pages: reuse frames between refreshes.
function ns.Pool(make)
  local pool = { list = {}, used = 0 }
  function pool:Reset() for i = 1, #self.list do self.list[i]:Hide() end self.used = 0 end
  function pool:Get(parent)
    self.used = self.used + 1
    local f = self.list[self.used]
    if not f then f = make(parent); self.list[self.used] = f end
    f:ClearAllPoints(); f:Show()
    return f
  end
  return pool
end
