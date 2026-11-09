-- Vendor guard: if a purchase would take gold out of a savings bucket, ask
-- first. No tinting (TSM moves the vendor window, so nothing is drawn on it):
-- the check sits on the buy itself. Right-click buys go through
-- BuyMerchantItem; left-click (pick up, drop in a bag) through PickupMerchantItem.
local _, ns = ...
local Bk, Lines = ns.BucketMath, ns.Lines

local function Cost(index, qty)
  local price, stack
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(index)
    if info then price, stack = info.price, info.stackCount end
  end
  if not price and GetMerchantItemInfo then
    local _
    _, _, price, stack = GetMerchantItemInfo(index)
  end
  price = price or 0
  stack = (stack and stack > 0) and stack or 1
  if qty and qty > 0 then return math.ceil(price / stack * qty) end
  return price
end

-- The dips a purchase would cause, or nil when it's covered by safe gold.
local function Dips(index, qty)
  if not ns.db or not ns.db.settings.guard then return nil end
  local cost = Cost(index, qty)
  if cost <= 0 then return nil end
  local link = GetMerchantItemLink and GetMerchantItemLink(index)
  local id, ic, sub = ns.ItemInfo(link)
  local line = ns.LineOf({ src = "vendor_buy", d = -cost, item = id, ic = ic, isub = sub, who = UnitName("npc") })
  local plan = Bk.PlanSpend(ns.Buckets(), cost, GetMoney() - cost, Lines.BucketFor(line, ns.Cats()))
  local dips = Bk.Dips(plan)
  if #dips == 0 then return nil end
  return dips, cost, link
end

local function Ask(dips, cost, link, go)
  local parts = {}
  for _, p in ipairs(dips) do
    local b = ns.Bucket(p.id)
    parts[#parts + 1] = ("  %s from |cffffffff%s|r"):format(ns.Fmt(p.take, true), b and b.name or p.id)
  end
  ns.Confirm(("%s costs %s.\nYou have %s safe to spend.\n\nBuying it takes:\n%s\n\nBuy it anyway?"):format(
    link or "This", ns.Fmt(cost, true), ns.Fmt(math.max(0, ns.Safe()), true), table.concat(parts, "\n")),
    go, nil, "Buy anyway", "Don't buy")
end

local bypass = false
function ns.InstallGuard()
  if ns.guardInstalled then return end
  ns.guardInstalled = true
  local origBuy, origPickup = BuyMerchantItem, PickupMerchantItem
  if origBuy then
    BuyMerchantItem = function(index, qty, ...)
      local link = GetMerchantItemLink and GetMerchantItemLink(index)
      local id, ic, sub = ns.ItemInfo(link)
      local info = { who = UnitName("npc"), item = id, ic = ic, isub = sub, qty = qty, link = link }
      if not bypass then
        local dips, cost = Dips(index, qty)
        if dips then
          Ask(dips, cost, link, function()
            bypass = true
            ns.Pend("vendor_buy", info)
            pcall(origBuy, index, qty)
            bypass = false
          end)
          return
        end
      end
      ns.Pend("vendor_buy", info)
      return origBuy(index, qty, ...)
    end
  end
  if origPickup then
    PickupMerchantItem = function(index, ...)
      if index and index > 0 and not CursorHasItem() then
        local link = GetMerchantItemLink and GetMerchantItemLink(index)
        local id, ic, sub = ns.ItemInfo(link)
        local info = { who = UnitName("npc"), item = id, ic = ic, isub = sub, link = link }
        if not bypass then
          local dips, cost = Dips(index)
          if dips then
            Ask(dips, cost, link, function()
              bypass = true
              ns.Pend("vendor_buy", info, 30)
              pcall(origPickup, index)
              bypass = false
            end)
            return
          end
        end
        ns.Pend("vendor_buy", info, 30)
      end
      return origPickup(index, ...)
    end
  end
end
