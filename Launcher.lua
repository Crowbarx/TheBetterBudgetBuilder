-- Minimap button (left: the BBB, right: Buckets), a data broker with Safe to
-- spend for any broker display, the slash command and key bindings.
local _, ns = ...
local T, Bk = ns.T, ns.BucketMath
local ICON = ns.MEDIA .. "Icon" -- our own gold "B" coin (Media/Icon.tga)
local mm, broker

BINDING_HEADER_BBB = "The BBB (Better Budget Builder)"
BINDING_NAME_BBB_TOGGLE = "Open the BBB"
BINDING_NAME_BBB_BUCKETS = "Open Buckets"

local function OnClick(_, button)
  if button == "RightButton" then ns.ToggleWindow("buckets") else ns.ToggleWindow() end
end

local function Tooltip(tt)
  local a = T.Accent()
  tt:AddLine("The BBB", a[1], a[2], a[3])
  tt:AddDoubleLine("Safe to spend", ns.Coins(ns.Safe()), 1, 1, 1, 1, 1, 1)
  for _, b in ipairs(ns.Buckets()) do
    local goal = ns.Goal(b)
    tt:AddDoubleLine(b.name, ns.Coins(b.saved) .. (goal and ("  |cff9a9aa0/ " .. ns.Fmt(goal) .. "|r") or ""), 0.8, 0.8, 0.8, 1, 1, 1)
  end
  local owed = ns.Owed()
  if owed > 0 then tt:AddDoubleLine("Owed to friends", "-" .. ns.Coins(owed), 0.8, 0.8, 0.8, 1, 0.42, 0.42) end
  local toMe = ns.OwedToMe()
  if toMe > 0 then tt:AddDoubleLine("Friends owe you", "+" .. ns.Coins(toMe), 0.8, 0.8, 0.8, 0.42, 0.85, 0.6) end
  tt:AddLine(" ")
  tt:AddLine("Left-click: the BBB   ·   Right-click: Buckets", 0.6, 0.6, 0.6)
end

local function Place(btn)
  local angle = math.rad(ns.db.settings.minimap.angle or 200)
  local x, y = math.cos(angle), math.sin(angle)
  if (GetMinimapShape and GetMinimapShape() or "ROUND") == "SQUARE" then
    local m = math.max(math.abs(x), math.abs(y)); x, y = x / m, y / m
  end
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + 6), y * (Minimap:GetHeight() / 2 + 6))
end

local function OwnButton()
  local b = CreateFrame("Button", "BBBMinimapButton", Minimap)
  b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = b:CreateTexture(nil, "ARTWORK"); icon:SetSize(22, 22); icon:SetPoint("CENTER", 1, -1); icon:SetTexture(ICON)
  b:SetScript("OnMouseDown", function() icon:SetSize(20, 20) end)
  b:SetScript("OnMouseUp", function() icon:SetSize(22, 22) end)
  local ring = b:CreateTexture(nil, "OVERLAY"); ring:SetSize(53, 53); ring:SetPoint("TOPLEFT"); ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetScript("OnClick", OnClick)
  b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); Tooltip(GameTooltip); GameTooltip:Show() end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      ns.db.settings.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
      Place(self)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  Place(b)
  return b
end

function ns.SetMinimapShown(shown)
  ns.db.settings.minimapShown = shown and true or false
  ns.db.settings.minimap.hide = not shown
  if mm == "ldb" then
    local DBI = LibStub("LibDBIcon-1.0", true)
    if DBI then if shown then DBI:Show("BBB") else DBI:Hide("BBB") end end
  elseif mm then
    mm:SetShown(shown)
  end
end

local function Create()
  if not Minimap then return end
  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
  if LDB then
    broker = LDB:NewDataObject("BBB", { type = "data source", text = "", label = "Safe to spend", icon = ICON,
      OnClick = OnClick, OnTooltipShow = Tooltip })
  end
  if broker and DBI then
    ns.db.settings.minimap.hide = not ns.db.settings.minimapShown
    DBI:Register("BBB", broker, ns.db.settings.minimap)
    mm = "ldb"
  else
    mm = OwnButton()
    mm:SetShown(ns.db.settings.minimapShown)
  end
end

ns.OnChange(function() if broker then broker.text = ns.Coins(ns.Safe(), 11) end end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() Create() end)

SLASH_BBB1 = "/bbb"
SLASH_BBB2 = "/budget"
SlashCmdList.BBB = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "" then ns.ToggleWindow()
  elseif msg == "buckets" or msg == "ledger" or msg == "spending" or msg == "income" or msg == "loans"
    or msg == "training" or msg == "settings" or msg == "overview" then ns.ShowPage(msg)
  elseif msg == "bags" then ns.SetBagView(true)
  elseif msg == "train" then ns.TrainMyList()
  elseif msg == "guard" then
    ns.db.settings.guard = not ns.db.settings.guard
    ns.Print("Vendor guard " .. (ns.db.settings.guard and "on." or "off."))
  elseif msg == "minimap" then ns.SetMinimapShown(not ns.db.settings.minimapShown)
  elseif msg == "fill" then
    local moved = Bk.FillAll(ns.Buckets(), math.max(0, ns.Safe()), ns.Goal)
    ns.Print("Moved " .. ns.Fmt(moved, true) .. " into your buckets.")
    ns.Changed()
  elseif msg:match("^scale") then
    local n = tonumber(msg:match("(%d+)"))
    if n then ns.db.settings.contentScale = math.max(0.5, math.min(1.5, n / 100)) else ns.db.settings.contentScale = nil end
    ns.ApplyScale(); ns.Changed()
    ns.Print("Window scale " .. (n and (math.floor(ns.WindowScale() * 100 + 0.5) .. "%.") or ("Auto (" .. math.floor(ns.WindowScale() * 100 + 0.5) .. "%).")))
  elseif msg == "reset" then
    ns.db.settings.contentScale = nil; ns.ResetWindow(); ns.Changed()
    ns.Print("Window centered and back to Auto size.")
  elseif msg == "debug" then ns.debug = not ns.debug; ns.Print("Debug " .. (ns.debug and "on" or "off"))
  else
    ns.Print("/bbb (window), /bbb buckets | ledger | spending | income | loans | training | settings, /bbb bags, /bbb train (at your trainer), /bbb fill, /bbb guard, /bbb minimap, /bbb scale 50-150 (or auto), /bbb reset")
  end
end
