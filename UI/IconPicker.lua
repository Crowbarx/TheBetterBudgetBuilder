-- A window to pick a bucket icon: a hand-picked set first, or every icon in
-- the game (the same list the macro icon picker uses). Built the first time
-- you open it, never at login.
local _, ns = ...
local T, K = ns.T, ns.Kit

local I = "Interface\\Icons\\"
local SUGGESTED = {
  -- money and bags
  "INV_Misc_Coin_01", "INV_Misc_Coin_02", "INV_Misc_Coin_03", "INV_Misc_Coin_04", "INV_Misc_Coin_05", "INV_Misc_Coin_06",
  "INV_Misc_Bag_10_Blue", "INV_Misc_Bag_08", "INV_Misc_Bag_07_Black", "INV_Misc_Bag_EnchantedMageweave", "INV_Box_01", "INV_Crate_01",
  "INV_Misc_Key_03", "INV_Misc_Note_01", "INV_Scroll_03", "INV_Misc_Book_11", "INV_Misc_Book_09", "INV_Misc_Book_07",
  "INV_Misc_Gem_Pearl_04", "INV_Misc_Gem_Ruby_01", "INV_Misc_Gem_Emerald_01", "INV_Misc_Gem_Sapphire_01", "INV_Misc_Gem_Diamond_01", "INV_Misc_Orb_01",
  -- mounts
  "Ability_Mount_Raptor", "Ability_Mount_WhiteTiger", "Ability_Mount_BlackPanther", "Ability_Mount_Kodo_01", "Ability_Mount_NightmareHorse",
  "Ability_Mount_Dreadsteed", "Ability_Mount_MountainRam", "Ability_Mount_MechaStrider", "Ability_Mount_WhiteDireWolf", "Ability_Mount_Undeadhorse",
  "Ability_Mount_RidingHorse", "Ability_Mount_JungleTiger",
  -- gear
  "INV_Sword_04", "INV_Sword_39", "INV_Axe_09", "INV_Mace_01", "INV_Weapon_Bow_02", "INV_Weapon_Rifle_01", "INV_Staff_08", "INV_Shield_06",
  "INV_Chest_Plate06", "INV_Helmet_03", "INV_Gauntlets_04", "INV_Boots_Plate_03", "INV_Shoulder_02", "INV_Pants_04",
  "INV_Jewelry_Ring_03", "INV_Misc_Cape_01",
  -- professions and supplies
  "Trade_BlackSmithing", "Trade_Alchemy", "Trade_Engineering", "Trade_Tailoring", "Trade_LeatherWorking", "Trade_Engraving",
  "Trade_Herbalism", "Trade_Mining", "Trade_Fishing", "INV_Misc_Food_15", "INV_Potion_54", "INV_Potion_51",
  "INV_Drink_05", "INV_Ingot_03", "INV_Fabric_Linen_01", "INV_Misc_Herb_01", "INV_Misc_Ammo_Arrow_01", "INV_Misc_Bomb_01",
  -- class and fun
  "Ability_Warrior_BattleShout", "Ability_Warrior_Charge", "Ability_DualWield", "Spell_Holy_HolyBolt", "Spell_Fire_FlameBolt",
  "Spell_Frost_FrostBolt02", "Spell_Nature_Lightning", "Spell_Shadow_ShadowBolt", "Spell_Holy_Resurrection", "INV_Misc_Head_Dragon_01",
  "INV_Misc_Spyglass_02", "INV_Misc_Map_01", "INV_Misc_PocketWatch_01", "INV_Misc_Lantern_01", "INV_Misc_Bone_HumanSkull_01", "INV_Misc_QuestionMark",
}
for i, n in ipairs(SUGGESTED) do SUGGESTED[i] = I .. n end
ns.SuggestedIcons = SUGGESTED

local COLS, ROWS, SIZE, GAP = 10, 7, 38, 5
local picker, all

local function AllIcons()
  if all then return all end
  all = {}
  local seen = {}
  local function Add(list)
    for _, v in ipairs(list or {}) do
      if v and not seen[v] then
        seen[v] = true
        all[#all + 1] = type(v) == "string" and not v:find("\\") and (I .. v) or v
      end
    end
  end
  Add(SUGGESTED)
  for _, fn in ipairs({ GetMacroIcons, GetMacroItemIcons, GetLooseMacroIcons, GetLooseMacroItemIcons }) do
    if fn then local t = {}; pcall(fn, t); Add(t) end
  end
  return all
end

local function Build()
  local f = CreateFrame("Frame", "BBBIconPicker", BBBWindow or UIParent)
  f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
  f:SetSize(COLS * (SIZE + GAP) - GAP + 48, ROWS * (SIZE + GAP) - GAP + 168)
  f:SetPoint("CENTER")
  f:EnableMouse(true)
  T.Fill(f, "BACKGROUND", 0.05, 0.05, 0.06, 0.97):SetAllPoints()
  T.Outline(f, 1, 1, 1, 0.16)
  tinsert(UISpecialFrames, "BBBIconPicker")

  f.title = T.Bold(f, 16, T.TEXT, "Pick an icon"); f.title:SetPoint("TOPLEFT", 24, -22)
  f.sub = T.Med(f, 11, T.MUTED, ""); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
  f.close = T.Button(f, "x", 24, 24, function() f:Hide() end); f.close:SetPoint("TOPRIGHT", -16, -16)

  f.tab = K.Segmented(f, { { value = "suggested", text = "Suggested" }, { value = "all", text = "Every icon" } },
    function() return f.mode end, function(v) f.mode = v; f.offset = 0; f:Fill() end)
  f.tab:SetPoint("TOPLEFT", 24, -68)

  f.grid = CreateFrame("Frame", nil, f)
  f.grid:SetPoint("TOPLEFT", 24, -110)
  f.grid:SetSize(COLS * (SIZE + GAP) - GAP, ROWS * (SIZE + GAP) - GAP)
  f.grid:EnableMouseWheel(true)
  f.grid:SetScript("OnMouseWheel", function(_, d) f.offset = f.offset - d * 2; f:Fill() end)
  f.cells = {}
  for i = 1, COLS * ROWS do
    local b = CreateFrame("Button", nil, f.grid)
    b:SetSize(SIZE, SIZE)
    b:SetPoint("TOPLEFT", ((i - 1) % COLS) * (SIZE + GAP), -math.floor((i - 1) / COLS) * (SIZE + GAP))
    b.icon = T.Icon(b, SIZE - 2); b.icon:SetPoint("CENTER")
    b.outline = T.Outline(b, 1, 1, 1, 0.12)
    b.hl = T.Fill(b, "HIGHLIGHT", 1, 1, 1, 0.18); b.hl:SetAllPoints()
    b:SetScript("OnClick", function(self) local pick = f.pick; f:Hide(); if pick then pick(self.value) end end)
    f.cells[i] = b
  end
  -- a slim scroll track on the right
  f.track = T.Fill(f, "ARTWORK", 1, 1, 1, 0.06)
  f.track:SetWidth(3)
  f.track:SetPoint("TOPLEFT", f.grid, "TOPRIGHT", 8, 0); f.track:SetPoint("BOTTOMLEFT", f.grid, "BOTTOMRIGHT", 8, 0)
  f.thumb = f:CreateTexture(nil, "OVERLAY"); f.thumb:SetTexture("Interface\\Buttons\\WHITE8x8"); f.thumb:SetWidth(3)

  f.hint = T.Med(f, 11, T.MUTED, "Scroll for more.  Esc closes."); f.hint:SetPoint("BOTTOMLEFT", 24, 20)
  f.cancel = T.Button(f, "Cancel", 100, 30, function() f:Hide() end); f.cancel:SetPoint("BOTTOMRIGHT", -24, 14)

  function f:Fill()
    local list = self.mode == "all" and AllIcons() or SUGGESTED
    local rows = math.ceil(#list / COLS)
    local maxOff = math.max(0, rows - ROWS)
    self.offset = math.max(0, math.min(maxOff, self.offset or 0))
    local a = T.Accent()
    for i, b in ipairs(self.cells) do
      local v = list[self.offset * COLS + i]
      b.value = v
      b:SetShown(v ~= nil)
      if v then
        b.icon:SetTexture(v)
        if v == self.current then b.outline(a[1], a[2], a[3], 1) else b.outline(1, 1, 1, 0.12) end
      end
    end
    self.sub:SetText(self.mode == "all" and (#list .. " icons, the same ones the macro window offers.") or "A few that fit savings goals.")
    local h = self.grid:GetHeight()
    self.thumb:SetShown(maxOff > 0); self.track:SetShown(maxOff > 0)
    if maxOff > 0 then
      local th = math.max(20, h * ROWS / rows)
      self.thumb:SetHeight(th)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOP", self.track, "TOP", 0, -(h - th) * self.offset / maxOff)
      self.thumb:SetVertexColor(a[1], a[2], a[3], 0.9)
    end
  end
  f:Hide()
  return f
end

-- Open the picker. current = the icon in use now; pick(icon) gets the choice.
function ns.PickIcon(current, pick)
  picker = picker or Build()
  picker.current, picker.pick = current, pick
  picker.mode, picker.offset = "suggested", 0
  picker:Show()
  picker:Raise()
  picker:Fill()
  T.Repaint()
end
