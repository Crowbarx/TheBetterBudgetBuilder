-- Training costs from a trainer scan. WoW-free (unit tested in tests/).
-- spells = { { name, rank, lvl, cost, used, skip } }
local _, ns = ...
local T = {}
ns.Training = T

-- Copper for untrained, unskipped spells you can learn by `level`.
function T.CostBy(spells, level)
  local total, list = 0, {}
  for _, sp in ipairs(spells or {}) do
    if not sp.used and not sp.skip and (sp.lvl or 0) <= level then
      total = total + (sp.cost or 0)
      list[#list + 1] = sp
    end
  end
  return total, list
end

-- The next level (> current) that has new spells, and what it adds.
function T.NextLevel(spells, level)
  local best
  for _, sp in ipairs(spells or {}) do
    if not sp.used and not sp.skip and sp.lvl > level and (not best or sp.lvl < best) then best = sp.lvl end
  end
  if not best then return nil, 0 end
  local cost = 0
  for _, sp in ipairs(spells) do
    if not sp.used and not sp.skip and sp.lvl == best then cost = cost + sp.cost end
  end
  return best, cost
end

-- Whether a level tier counts toward the Training goal. Ready spells always
-- do; your next training level does unless you removed it; later levels only
-- when you added them to pre-save. tiers = { [lvl] = true | false }.
function T.InGoal(lvl, level, nextLvl, tiers)
  if lvl <= level then return true end
  local pick = tiers and tiers[lvl]
  if pick ~= nil then return pick end
  return lvl == nextLvl
end

-- The Training bucket's goal: the cost of every tier that counts (above).
function T.Goal(spells, level, tiers)
  if not spells or #spells == 0 then return nil end
  local nextLvl = T.NextLevel(spells, level)
  local total = 0
  for _, sp in ipairs(spells) do
    if not sp.used and not sp.skip and T.InGoal(sp.lvl or 0, level, nextLvl, tiers) then
      total = total + (sp.cost or 0)
    end
  end
  return total
end

return T
