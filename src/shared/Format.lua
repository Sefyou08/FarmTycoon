--[[
	Format.lua  (ReplicatedStorage.Shared.Format)
	=============================================
	Fonctions utilitaires d'affichage, partagées client/serveur.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 15600000 -> "15.6M", 999 -> "999"
function Format.Number(value: number?): string
	local n = tonumber(value) or 0
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)

	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end

	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end

	local pattern = if n >= 100 then "%.0f" elseif n >= 10 then "%.1f" else "%.2f"
	local text = string.format(pattern, n)

	-- Retire les zéros inutiles après la virgule ("1.50" -> "1.5", "2.00" -> "2")
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end

	return sign .. text .. SUFFIXES[index]
end

-- 125 -> "2:05", 3725 -> "1:02:05"
function Format.Time(seconds: number?): string
	local s = math.max(0, math.floor(tonumber(seconds) or 0))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

return Format
