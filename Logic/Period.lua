-- Periods: start at `anchor` and repeat every `length` days. Days are whole
-- calendar day numbers (days since 1970-01-01), so no time zone or daylight
-- saving math is involved. WoW-free (unit tested in tests/).
local _, ns = ...
local P = {}
ns.Period = P

local floor = math.floor

-- Calendar date -> day number (Howard Hinnant's days_from_civil).
function P.DayFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = floor(y / 400)
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

-- Day number -> y, m, d.
function P.CivilFromDay(z)
  z = z + 719468
  local era = floor(z / 146097)
  local doe = z - era * 146097
  local yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
  local mp = floor((5 * doy + 2) / 153)
  local d = doy - floor((153 * mp + 2) / 5) + 1
  local m = mp < 10 and mp + 3 or mp - 9
  if m <= 2 then y = y + 1 end
  return y, m, d
end

-- "2026-11-03" <-> day number.
function P.Day(ymd)
  local y, m, d = tostring(ymd or ""):match("^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$")
  if not y then return nil end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if m < 1 or m > 12 or d < 1 or d > 31 then return nil end
  return P.DayFromCivil(y, m, d)
end

function P.Ymd(day)
  local y, m, d = P.CivilFromDay(day)
  return ("%04d-%02d-%02d"):format(y, m, d)
end

-- A date table from date("*t") -> day number.
function P.DayOfTable(t) return P.DayFromCivil(t.year, t.month, t.day) end

-- 0 = Sunday ... 6 = Saturday (1970-01-01 was a Thursday).
function P.Weekday(day) return (day + 4) % 7 end

-- The first day of the period containing `day`.
function P.StartOf(day, anchor, length)
  return anchor + floor((day - anchor) / length) * length
end

-- The period id (its start date) for a day.
function P.Id(day, anchor, length) return P.Ymd(P.StartOf(day, anchor, length)) end

-- How many periods start between periodStart and due, both included.
function P.Until(periodStart, due, length)
  if due < periodStart then return 0 end
  return floor((due - periodStart) / length) + 1
end

-- Days left in the period containing `day`, counting today.
function P.DaysLeft(day, anchor, length)
  return P.StartOf(day, anchor, length) + length - day
end

-- The last `n` finished period starts before the one containing `day`, newest first.
function P.Previous(day, anchor, length, n)
  local start = P.StartOf(day, anchor, length)
  local out = {}
  for i = 1, n do out[i] = start - i * length end
  return out
end

return P
