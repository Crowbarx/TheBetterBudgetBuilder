-- Money: integer copper in, text out. WoW-free (unit tested in tests/).
local _, ns = ...
local M = {}
ns.Money = M

local floor, abs = math.floor, math.abs

local function commas(n)
  local s = tostring(n)
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

-- Round a division up to whole copper (the desktop app's ceilCents).
function M.CeilDiv(a, b)
  if b <= 0 then return a end
  return -floor(-a / b)
end

-- 1234567 -> "123g 45s 67c". Zero parts are left out; 0 -> "0c".
function M.Format(copper, colored)
  copper = copper or 0
  local neg = copper < 0
  copper = floor(abs(copper) + 0.5)
  local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
  local parts = {}
  local function add(v, suffix, col)
    if colored then parts[#parts + 1] = commas(v) .. "|cff" .. col .. suffix .. "|r"
    else parts[#parts + 1] = commas(v) .. suffix end
  end
  if g > 0 then add(g, "g", "ffd700") end
  if s > 0 then add(s, "s", "c7c7cf") end
  if c > 0 or #parts == 0 then add(c, "c", "eda55f") end
  return (neg and "-" or "") .. table.concat(parts, " ")
end

-- With the game's coin icons: 2[g] 81[s] 17[c]. Silver and copper always show
-- under a gold amount so columns line up.
local ICON = "|TInterface\\MoneyFrame\\UI-%sIcon:%d:%d:1:0|t"
function M.Icons(copper, size)
  size = size or 12
  copper = copper or 0
  local neg = copper < 0
  copper = floor(abs(copper) + 0.5)
  local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = commas(g) .. ICON:format("Gold", size, size) end
  if g > 0 or s > 0 then parts[#parts + 1] = s .. ICON:format("Silver", size, size) end
  parts[#parts + 1] = c .. ICON:format("Copper", size, size)
  return (neg and "-" or "") .. table.concat(parts, " ")
end

-- "5", "5g", "12g 50s", "75s", "30c", "1,200g" -> copper. A plain number is gold.
function M.Parse(text)
  if type(text) ~= "string" then return nil end
  text = text:lower():gsub(",", ""):gsub("%s+", "")
  if text == "" then return nil end
  local plain = tonumber(text)
  if plain then
    if plain < 0 then return nil end
    return floor(plain * 10000 + 0.5)
  end
  local total, matched = 0, false
  local rest = text:gsub("([%d%.]+)([gsc])", function(num, unit)
    local v = tonumber(num)
    if v then
      matched = true
      total = total + v * ((unit == "g" and 10000) or (unit == "s" and 100) or 1)
    end
    return ""
  end)
  if not matched or rest ~= "" then return nil end
  return floor(total + 0.5)
end

return M
