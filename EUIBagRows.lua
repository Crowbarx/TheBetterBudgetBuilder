-- Shared helper for Eric's addons that add their own rows to the EllesmereUI
-- bag sidebar (Bag Keyring, Loan Ledger). The same file ships in each addon;
-- whichever loads first sets it up and the rest reuse it, so the rows stack
-- under each other instead of landing on the same spot.
--
-- EllesmereUI ends every sidebar build with sidebarChild:SetHeight(). One hook
-- on that places every registered row, in `order`, after the last category
-- (above "+ Add Category", which moves down). They go at the end so
-- EllesmereUI's drag-to-reorder math for categories stays exact.
-- Nothing in EllesmereUI is edited.
local VERSION = 1
local R = _G.EUIBagExtraRows
if R and (R.version or 0) >= VERSION then return end
R = R or {}
_G.EUIBagExtraRows = R
R.version = VERSION
R.rows = R.rows or {}
R.hooked = R.hooked or {}
R.BTN_H, R.BTN_PAD, R.ICON = 26, 2, 18 -- EllesmereUI sidebar metrics

-- row = { id, order, make(child, refLabel) -> button, paint(button, active),
--         onLeave() (another view was picked) }
function R:Register(row)
  for i, r in ipairs(self.rows) do
    if r.id == row.id then self.rows[i] = row; return end
  end
  self.rows[#self.rows + 1] = row
  table.sort(self.rows, function(a, b) return (a.order or 50) < (b.order or 50) end)
end

function R.Accent()
  if EllesmereUI and EllesmereUI.GetAccentColor then
    local ok, r, g, b = pcall(EllesmereUI.GetAccentColor)
    if ok and r then return r, g, b end
  end
  return 0.047, 0.824, 0.616
end

function R:IsActive(id) return self.active == id end

local function Bags() return _G.EUI_Bags end

function R:PaintAll()
  for _, row in ipairs(self.rows) do
    if row.btn then row.paint(row.btn, self.active == row.id) end
  end
end

-- EllesmereUI's buttons keep their own "selected" look; while one of ours is
-- up we dim theirs so only ours reads as picked. Their next refresh repaints.
function R:DimTheirs()
  local child = Bags() and Bags()._sidebarChild
  if not child or not self.active then return end
  for _, c in ipairs({ child:GetChildren() }) do
    if c._indicator and c._catIdx then
      c._indicator:Hide()
      if c._bg then c._bg:SetColorTexture(1, 1, 1, 0) end
      if c._icon then c._icon:SetAlpha(0.75) end
      if c._label then c._label:SetTextColor(1, 1, 1, 0.75) end
    end
  end
end

-- Switch to one of our views (id) or back to EllesmereUI's own (nil).
function R:Activate(id)
  local prev = self.active
  self.active = id
  for _, row in ipairs(self.rows) do
    if row.id == prev and prev ~= id and row.onLeave then row.onLeave() end
  end
  self:PaintAll()
  if id then
    self:DimTheirs()
  elseif prev then
    local bags = Bags()
    if bags and bags.RefreshInventory then bags:RefreshInventory() end -- let it repaint its selection
  end
end

-- Drop our view without asking EllesmereUI to repaint (it is about to anyway).
function R:Leave()
  local prev = self.active
  if not prev then return end
  self.active = nil
  for _, row in ipairs(self.rows) do
    if row.id == prev and row.onLeave then row.onLeave() end
  end
  self:PaintAll()
end

-- Any click on one of their sidebar entries leaves our view.
function R:HookTheirs(child)
  for _, c in ipairs({ child:GetChildren() }) do
    if c._catIdx and not self.hooked[c] then
      self.hooked[c] = true
      c:HookScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then R:Leave() end
      end)
    end
  end
end

-- Move a frame/texture's anchors down by dy if it sits at or below `below`.
local function ShiftDown(obj, below, dy)
  if obj:GetNumPoints() == 0 then return end
  local pts = {}
  for i = 1, obj:GetNumPoints() do pts[i] = { obj:GetPoint(i) } end
  local y1 = pts[1][5]
  if not y1 or y1 > below + 0.5 then return end
  obj:ClearAllPoints()
  for _, p in ipairs(pts) do obj:SetPoint(p[1], p[2], p[3], p[4], (p[5] or 0) - dy) end
end

function R:Layout(child)
  local bags = Bags()
  local sidebar = bags and bags._sidebar
  local ours = {}
  for _, row in ipairs(self.rows) do if row.btn then ours[row.btn] = true end end
  if not sidebar or not sidebar:IsShown() or (sidebar:GetWidth() or 0) < 1 or #self.rows == 0 then
    for b in pairs(ours) do b:Hide() end
    return
  end
  local insertY, ref
  for _, c in ipairs({ child:GetChildren() }) do
    if not ours[c] and c:IsShown() and c._catIdx and c:GetNumPoints() > 0 then
      local y = select(5, c:GetPoint(1))
      if y and (not insertY or y < insertY) then insertY = y; ref = c end
    end
  end
  local step = self.BTN_H + self.BTN_PAD
  insertY = (insertY or step) - step
  local dy = step * #self.rows
  for _, c in ipairs({ child:GetChildren() }) do
    if not ours[c] and c:IsShown() then ShiftDown(c, insertY, dy) end
  end
  for _, r in ipairs({ child:GetRegions() }) do
    if r:IsShown() then ShiftDown(r, insertY, dy) end
  end
  local y = insertY
  for _, row in ipairs(self.rows) do
    if not row.btn then
      row.btn = row.make(child, ref and ref._label)
      ours[row.btn] = true
    end
    local b = row.btn
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
    b:SetWidth(sidebar:GetWidth())
    b:Show()
    y = y - step
  end
  self.inLayout = true
  child:SetHeight((child:GetHeight() or 0) + dy)
  self.inLayout = false
  self:HookTheirs(child)
  self:PaintAll()
  self:DimTheirs()
end

-- Call when the EllesmereUI bag window exists (safe to call often).
function R:Hook()
  local bags = Bags()
  local child = bags and bags._sidebarChild
  if not child or self.childHooked == child then return end
  self.childHooked = child
  hooksecurefunc(child, "SetHeight", function(c)
    if R.inLayout then return end
    R:Layout(c)
  end)
  bags:HookScript("OnHide", function() R:Leave() end)
  if child:IsVisible() then self:Layout(child) end
end

-- Paint helper shared by the rows: the same look as EllesmereUI's own buttons.
function R.PaintRow(b, active)
  local ar, ag, ab = R.Accent()
  local sb = Bags() and Bags()._sidebar
  local collapsed = sb and (sb:GetWidth() or 0) < 60
  b._icon:ClearAllPoints()
  if collapsed then b._icon:SetPoint("CENTER") else b._icon:SetPoint("LEFT", b, "LEFT", 8, 0) end
  b._label:SetShown(not collapsed); b._count:SetShown(not collapsed)
  if active then
    b._indicator:SetColorTexture(ar, ag, ab, 1); b._indicator:Show()
    b._bg:SetColorTexture(ar, ag, ab, 0.1)
    b._icon:SetAlpha(1); b._label:SetTextColor(1, 1, 1, 1)
  else
    b._indicator:Hide(); b._bg:SetColorTexture(1, 1, 1, 0)
    b._icon:SetAlpha(0.75); b._label:SetTextColor(1, 1, 1, 0.75)
  end
end

-- A sidebar button shaped like EllesmereUI's.
function R.MakeRow(child, refLabel, name, label, icon)
  local b = CreateFrame("Button", name, child)
  b:SetHeight(R.BTN_H)
  b._indicator = b:CreateTexture(nil, "OVERLAY")
  local px = (EllesmereUI and EllesmereUI.PP and EllesmereUI.PP.mult) or 1
  b._indicator:SetWidth(px * 2)
  b._indicator:SetPoint("TOPLEFT"); b._indicator:SetPoint("BOTTOMLEFT")
  b._bg = b:CreateTexture(nil, "BACKGROUND", nil, 2); b._bg:SetAllPoints()
  b._bg:SetColorTexture(1, 1, 1, 0)
  b._icon = b:CreateTexture(nil, "ARTWORK"); b._icon:SetSize(R.ICON, R.ICON)
  b._icon:SetTexture(icon); b._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b._label = b:CreateFontString(nil, "OVERLAY")
  b._count = b:CreateFontString(nil, "OVERLAY")
  local font, size, flags
  if refLabel then font, size, flags = refLabel:GetFont() end
  if font then
    b._label:SetFont(font, size or 11, flags or ""); b._count:SetFont(font, (size or 11) - 1, flags or "")
  else
    b._label:SetFontObject(GameFontHighlightSmall); b._count:SetFontObject(GameFontHighlightSmall)
  end
  b._label:SetShadowColor(0, 0, 0, 0.8); b._label:SetShadowOffset(1, -1)
  b._label:SetJustifyH("LEFT"); b._label:SetWordWrap(false)
  b._label:SetPoint("LEFT", b._icon, "RIGHT", 6, 0)
  b._label:SetPoint("RIGHT", b._count, "LEFT", -4, 0)
  b._label:SetText(label)
  b._count:SetJustifyH("RIGHT"); b._count:SetTextColor(0.5, 0.5, 0.5)
  b._count:SetPoint("RIGHT", b, "RIGHT", -6, 0)
  b:SetScript("OnEnter", function(self)
    if R.active ~= self._rowId then self._bg:SetColorTexture(1, 1, 1, 0.06) end
  end)
  b:SetScript("OnLeave", function(self)
    if R.active ~= self._rowId then self._bg:SetColorTexture(1, 1, 1, 0) end
    GameTooltip:Hide()
  end)
  return b
end
