-- Stats over the ledger: totals per line, per day/week/month, per source,
-- gold per hour played. WoW-free (unit tested in tests/).
local _, ns = ...
local S = {}
ns.Stats = S

local floor, max = math.floor, math.max
local P = ns.Period

-- The bucket start (day number) a day falls in for a grouping.
-- "day", "week" (weeks start Monday) or "month".
function S.GroupStart(day, group)
  if group == "week" then
    local wd = P.Weekday(day)           -- 0 = Sunday
    return day - ((wd + 6) % 7)         -- back to Monday
  elseif group == "month" then
    local y, m = P.CivilFromDay(day)
    return P.DayFromCivil(y, m, 1)
  end
  return day
end

-- The next group start after `start`.
function S.NextGroup(start, group)
  if group == "week" then return start + 7 end
  if group == "month" then
    local y, m = P.CivilFromDay(start)
    m = m + 1
    if m > 12 then y, m = y + 1, 1 end
    return P.DayFromCivil(y, m, 1)
  end
  return start + 1
end

-- The last `count` group starts ending at today's group, oldest first.
function S.Groups(today, group, count)
  local starts = {}
  local s = S.GroupStart(today, group)
  starts[count] = s
  for i = count - 1, 1, -1 do
    if group == "month" then
      local y, m = P.CivilFromDay(starts[i + 1])
      m = m - 1
      if m < 1 then y, m = y - 1, 12 end
      starts[i] = P.DayFromCivil(y, m, 1)
    else
      starts[i] = starts[i + 1] - (group == "week" and 7 or 1)
    end
  end
  return starts
end

-- Sum rows into series. rows need .day and .d; keyFn(row) returns the
-- series key or nil to skip; sign = -1 for spending (stored negative), 1 for income.
-- Returns { totals = { [key] = copper }, grid = { [groupIndex] = { [key] = copper } },
--           count = { [key] = rows }, sum = all }
function S.Series(rows, starts, group, keyFn, sign)
  local idx = {}
  for i, s in ipairs(starts) do idx[s] = i end
  local first = starts[1]
  local totals, grid, count, sum = {}, {}, {}, 0
  for i = 1, #starts do grid[i] = {} end
  for _, r in ipairs(rows) do
    if r.day and r.day >= first then
      local key = keyFn(r)
      if key then
        local v = (r.d or 0) * sign
        if v > 0 then
          local gi = idx[S.GroupStart(r.day, group)]
          if gi then
            grid[gi][key] = (grid[gi][key] or 0) + v
            totals[key] = (totals[key] or 0) + v
            count[key] = (count[key] or 0) + 1
            sum = sum + v
          end
        end
      end
    end
  end
  return { totals = totals, grid = grid, count = count, sum = sum }
end

-- Keys sorted by total, biggest first; more than `limit` fold into "more".
function S.Ranked(totals, limit)
  local keys = {}
  for k, v in pairs(totals) do keys[#keys + 1] = { k = k, v = v } end
  table.sort(keys, function(a, b) if a.v ~= b.v then return a.v > b.v end return a.k < b.k end)
  local out, more = {}, 0
  for i, e in ipairs(keys) do
    if not limit or i <= limit then out[#out + 1] = e.k else more = more + e.v end
  end
  return out, more
end

-- Gold per hour: copper earned / seconds played * 3600 (nil without play time).
function S.PerHour(copper, seconds)
  if not seconds or seconds < 60 then return nil end
  return floor(copper * 3600 / seconds)
end

-- Earned and spent for days >= fromDay (transfers excluded by kindFn).
function S.Totals(rows, fromDay, kindFn)
  local earned, spent = 0, 0
  for _, r in ipairs(rows) do
    if r.day and r.day >= fromDay then
      local k = kindFn(r)
      if k == "income" then earned = earned + max(0, r.d)
      elseif k == "spend" then spent = spent + max(0, -r.d) end
    end
  end
  return earned, spent
end

return S
