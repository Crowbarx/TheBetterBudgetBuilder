-- Buckets: named savings piles. They are labels on the gold you carry; the
-- gold that isn't in a bucket (and isn't owed to a friend) is Safe to spend.
-- WoW-free (unit tested in tests/).
local _, ns = ...
local B = {}
ns.BucketMath = B

local max, min, floor = math.max, math.min, math.floor
local CeilDiv = ns.Money.CeilDiv

function B.Saved(buckets)
  local t = 0
  for _, b in ipairs(buckets) do t = t + max(0, b.saved or 0) end
  return t
end

-- What you can spend without touching a bucket or money you owe.
function B.Safe(gold, buckets, owed)
  return gold - B.Saved(buckets) - (owed or 0)
end

-- New gold: each bucket with an auto % takes its share until it reaches its
-- goal. target(b) returns the goal in copper or nil (no goal = no limit).
-- room (optional) caps the total so buckets never hold more than you have.
-- Mutates buckets; returns { [id] = copper }.
function B.Earn(buckets, amount, target, room)
  local alloc = {}
  for _, b in ipairs(buckets) do
    local pct = b.pct or 0
    if pct > 0 and not b.paused then
      local share = floor(amount * pct / 100)
      local goal = target and target(b)
      if goal then share = min(share, max(0, goal - (b.saved or 0))) end
      if room then share = min(share, max(0, room)); room = room - max(0, share) end
      if share > 0 then
        b.saved = (b.saved or 0) + share
        alloc[b.id] = share
      end
    end
  end
  return alloc
end

-- Buckets can't hold more than `limit` (your gold minus what you owe): take
-- the extra out, bottom of the list first. Returns the copper removed.
function B.Clamp(buckets, limit)
  local extra = B.Saved(buckets) - max(0, limit)
  local removed = 0
  for i = #buckets, 1, -1 do
    if extra <= 0 then break end
    local b = buckets[i]
    local take = min(extra, max(0, b.saved or 0))
    if take > 0 then b.saved = b.saved - take; extra = extra - take; removed = removed + take end
  end
  return removed
end

-- The buckets a shortfall is taken from: the paying bucket first, then from
-- the bottom of the list up (put what matters most at the top).
local function dipOrder(buckets, payFrom)
  local order = {}
  for _, b in ipairs(buckets) do if b.id == payFrom then order[1] = b end end
  for i = #buckets, 1, -1 do
    if buckets[i].id ~= payFrom then order[#order + 1] = buckets[i] end
  end
  return order
end

-- Who pays for spending `amount` when you'll have `goldAfter` left.
-- The paying bucket (payFrom, e.g. Training for class training) gives up to
-- what it holds; then if the buckets hold more than the gold you have left,
-- the difference comes out of buckets, bottom of the list first.
-- Returns plan = { { id = , take = , paid = true|nil } ... } without changing anything.
function B.PlanSpend(buckets, amount, goldAfter, payFrom)
  local plan, took = {}, {}
  local order = dipOrder(buckets, payFrom)
  if payFrom and order[1] and order[1].id == payFrom then
    local take = min(amount, max(0, order[1].saved or 0))
    if take > 0 then plan[#plan + 1] = { id = payFrom, take = take, paid = true }; took[payFrom] = take end
  end
  local held = 0
  for _, b in ipairs(buckets) do held = held + max(0, (b.saved or 0) - (took[b.id] or 0)) end
  local deficit = held - max(0, goldAfter)
  for _, b in ipairs(order) do
    if deficit <= 0 then break end
    local left = max(0, (b.saved or 0) - (took[b.id] or 0))
    local take = min(deficit, left)
    if take > 0 then
      plan[#plan + 1] = { id = b.id, take = take }
      took[b.id] = (took[b.id] or 0) + take
      deficit = deficit - take
    end
  end
  return plan
end

-- Apply a PlanSpend result. Returns { [id] = copper }.
function B.Apply(buckets, plan)
  local byId, alloc = {}, {}
  for _, b in ipairs(buckets) do byId[b.id] = b end
  for _, p in ipairs(plan) do
    local b = byId[p.id]
    if b then
      b.saved = (b.saved or 0) - p.take
      alloc[p.id] = (alloc[p.id] or 0) + p.take
    end
  end
  return alloc
end

-- Just the dips (not the bucket that was meant to pay): what the guard warns about.
function B.Dips(plan)
  local out = {}
  for _, p in ipairs(plan) do if not p.paid then out[#out + 1] = p end end
  return out
end

-- How much to save per level to reach a goal by its level.
function B.PerLevel(b, level, goal)
  if not b.dueLevel or not goal then return nil end
  local remaining = max(0, goal - (b.saved or 0))
  local levels = b.dueLevel - level
  if levels <= 0 then return remaining end
  return CeilDiv(remaining, levels)
end

-- Fill every bucket to its goal from what's safe to spend, top first.
-- Returns copper moved.
function B.FillAll(buckets, safe, target)
  local moved = 0
  for _, b in ipairs(buckets) do
    local goal = target and target(b)
    if goal and goal > (b.saved or 0) and safe > 0 then
      local give = min(goal - (b.saved or 0), safe)
      b.saved = (b.saved or 0) + give
      safe = safe - give
      moved = moved + give
    end
  end
  return moved
end

return B
