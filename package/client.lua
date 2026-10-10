-- Honor of Kings Takeover: the Sandy Shores runway becomes a MOBA lane.
-- Dawn (blue) against Dusk (red): health bars and team rings on every fighter, crystal towers that zap,
-- champions with ultimates, kill announcements, gold, and the Tyrant dragon boss.

HoK = HoK or {}
local TEAM = {
	a = { name = 'DAWN', col = { 70, 170, 255 }, hex = '#46aaff', tower = 'sigf_tower_blue' },
	b = { name = 'DUSK', col = { 255, 70, 70 }, hex = '#ff4646', tower = 'sigf_tower_red' },
}
local GOLD = { 255, 205, 60 }
local sideOf = {}            -- ped -> 'a' | 'b'
local champ = {}             -- side -> { ped, nextUlt, respawnAt }
local towers = {}            -- side -> { obj, hp, max, pos, nextZap, down }
HoK.towers = towers
local score = { a = 0, b = 0 }
local streak = { a = { n = 0, t = 0 }, b = { n = 0, t = 0 } }
local me = { gold = 500, level = 1, kills = 0 }
local firstBlood, lastCall = false, 0
local startMs = GetGameTimer()
local buff = { a = 0, b = 0 } -- until ms: Tyrant buff
local tyrant = nil
HoK.alignCam = false
local TS = 1.5            -- visual scale of towers
local beams = {}             -- short lines drawn each frame

local function hasPed(p) return p and p ~= 0 and DoesEntityExist(p) end
local function alive(p) return hasPed(p) and not IsPedDeadOrDying(p, true) end
local function other(s) return s == 'a' and 'b' or 'a' end

local function pushHud(extra)
	local d = extra or {}
	d.a, d.b = score.a, score.b
	d.gold, d.level = me.gold, me.level
	d.time = math.floor((GetGameTimer() - startMs) / 1000)
	Sigf.Nui(d)
end

local function feed(text, side)
	pushHud({ feed = text, feedColor = side and TEAM[side].hex or '#ffd34d' })
end

-- ---------- fighters: team ring + health bar ----------
Sigf.OnSpawn(function(ped, side)
	side = side or HoK.pending
	if not side then return end
	sideOf[ped] = side
	local arm = buff[side] > GetGameTimer() and 80 or 0
	if arm > 0 then SetPedArmour(ped, arm) end
	-- Dawn minions are lighter, Dusk the same: a lane fight lasts a few seconds
	SetPedMaxHealth(ped, 160) SetEntityHealth(ped, 160)
end)

local function drawBar(p, frac, w, col, big)
	local on, sx, sy = GetScreenCoordFromWorldCoord(p.x, p.y, p.z)
	if not on then return end
	local cam = Sigf.View().cam
	local d = #(p - cam)
	local s = math.max(0.4, math.min(1.6, 14.0 / d))
	local bw, bh = w * s, (big and 0.012 or 0.0075) * s
	DrawRect(sx, sy, bw + 0.003, bh + 0.004, 0, 0, 0, 200)
	DrawRect(sx - bw * (1 - frac) / 2, sy, bw * frac, bh, col[1], col[2], col[3], 235)
	return sx, sy, bw, bh
end

local function pedFrac(ped)
	local mx = GetEntityMaxHealth(ped) - 100
	if mx <= 0 then return 0 end
	return math.max(0.0, math.min(1.0, (GetEntityHealth(ped) - 100) / mx))
end

Sigf.Frame(function()
	local cam = Sigf.View().cam
	local now = GetGameTimer()
	for ped, side in pairs(sideOf) do
		if not hasPed(ped) then sideOf[ped] = nil
		elseif not IsPedDeadOrDying(ped, true) then
			local p = GetEntityCoords(ped)
			local d = #(p - cam)
			if d < 90.0 then
				local t = TEAM[side]
				local c = buff[side] > now and GOLD or t.col
				local isChamp = champ[side] and champ[side].ped == ped
				local r = isChamp and 1.9 or 1.1
				DrawMarker(25, p.x, p.y, p.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r, r, 0.6, c[1], c[2], c[3], 170, false, false, 2, false, nil, nil, false)
				local top = p + vector3(0, 0, isChamp and 1.25 or 1.1)
				local sx, sy, bw, bh = drawBar(top, pedFrac(ped), isChamp and 0.07 or 0.045, c, isChamp)
				if sx and isChamp then
					DrawSprite('sigf_img', 'crown', sx, sy - 0.03, 0.022, 0.04, 0.0, 255, 255, 255, 255)
				end
			end
		end
	end
	-- the demo hero: Dawn ring and crown
	if Sigf.Stage() == 'demo' then
		local hp = PlayerPedId()
		local p = GetEntityCoords(hp)
		DrawMarker(25, p.x, p.y, p.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.9, 1.9, 0.6, 70, 170, 255, 190, false, false, 2, false, nil, nil, false)
		local on, sx, sy = GetScreenCoordFromWorldCoord(p.x, p.y, p.z + 1.05)
		if on then
			local h = 0.045   -- fixed small size, just above the head
			DrawSprite('sigf_img', 'crown', sx, sy - h * 0.6, h * Sigf.View().aspectInv, h, 0.0, 255, 255, 255, 255)
		end
	end
	-- beams
	for i = #beams, 1, -1 do
		local b = beams[i]
		if now > b.untilMs then table.remove(beams, i)
		else
			local to = b.target and hasPed(b.target) and (GetEntityCoords(b.target) + vector3(0, 0, 0.3)) or b.to
			for k = 0, 2 do
				local o = vector3(0.0, 0.0, 0.0)
				DrawLine(b.from.x + k * 0.05, b.from.y, b.from.z, to.x, to.y, to.z, b.col[1], b.col[2], b.col[3], 255)
			end
		end
	end
end)

-- ---------- kills, gold, announcer ----------
local function announce(text, color, voice)
	local now = GetGameTimer()
	if now - lastCall < 2500 then return end
	lastCall = now
	Sigf.Text(text, 2.5, { y = 0.31, size = 64, color = color or '#ffd34d' })
	if voice then Sigf.Sound(voice) end
end

Sigf.OnKill(function(ped, killer)
	local side = sideOf[ped]
	if not side then return end
	local p = GetEntityCoords(ped)
	local winner = other(side)
	score[winner] = score[winner] + 1
	local now = GetGameTimer()
	local st = streak[winner]
	if now - st.t < 7000 then st.n = st.n + 1 else st.n = 1 end
	st.t = now
	Sigf.Fx(Sigf.FX.sparks[1], Sigf.FX.sparks[2], p + vector3(0, 0, 0.8), { scale = 1.0 })
	local gold = (champ[side] and champ[side].ped == ped) and 300 or 20
	local t0 = GetGameTimer()
	Sigf.Frame(function()
		local age = (GetGameTimer() - t0) / 1000.0
		if age > 1.6 then return false end
		local on, sx, sy = GetScreenCoordFromWorldCoord(p.x, p.y, p.z + 1.3 + age * 0.6)
		if on then DrawSprite('sigf_img', 'coin', sx, sy, 0.03 * Sigf.View().aspectInv, 0.03, 0.0, 255, 255, 255, math.floor(255 * (1 - age / 1.6))) end
	end)
	Sigf.Text3D('+' .. gold .. 'g', p + vector3(0, 0, 1.6), 1.5, { color = GOLD, scale = 0.6 })
	if winner == 'a' then
		me.gold = me.gold + gold
		me.kills = me.kills + 1
		if me.kills % 10 == 0 then HoK.LevelUp() end
	end
	feed(TEAM[winner].name .. ' slays a ' .. TEAM[side].name .. (gold > 20 and ' CHAMPION' or ' minion'), winner)
	if not firstBlood then
		firstBlood = true
		lastCall = 0
		announce('FIRST BLOOD!', '#ff3b3b', 'v_firstblood')
	elseif st.n == 2 then announce('DOUBLE KILL!', TEAM[winner].hex, 'v_double')
	elseif st.n == 3 then announce('TRIPLE KILL!', '#ff9d2e', 'v_triple')
	elseif st.n >= 5 then announce('KILLING SPREE!', '#ffd34d', 'v_spree') st.n = 0 end
	pushHud()
end)

function HoK.LevelUp()
	me.level = math.min(15, me.level + 1)
	local p = GetEntityCoords(PlayerPedId())
	Sigf.Sound('levelup')
	Sigf.Marker(25, p - vector3(0, 0, 0.95), vector3(3.5, 3.5, 1.0), { 255, 215, 80, 220 }, 1.5)
	Sigf.Light(p, GOLD, 12.0, 8.0, 1.5)
	Sigf.Text3D('LEVEL UP! Lv ' .. me.level, p + vector3(0, 0, 2.2), 2.0, { color = GOLD, scale = 0.8 })
	feed('You reached level ' .. me.level)
end

-- ---------- ultimates ----------
function HoK.Ult(side, pos, owner)
	local col = TEAM[side].col
	Sigf.Sound('ult', pos)
	Sigf.Marker(1, pos - vector3(0, 0, 0.9), vector3(16.0, 16.0, 0.3), { col[1], col[2], col[3], 140 }, 1.2)
	Sigf.Marker(25, pos - vector3(0, 0, 0.9), vector3(16.0, 16.0, 1.0), { 255, 255, 255, 220 }, 1.2)
	Sigf.After(1.2, function()
		Sigf.Marker(1, pos - vector3(0, 0, 1.0), vector3(14.0, 14.0, 60.0), { col[1], col[2], col[3], 90 }, 0.9)
		Sigf.Marker(1, pos - vector3(0, 0, 1.0), vector3(4.0, 4.0, 80.0), { 255, 255, 255, 190 }, 0.7)
		Sigf.Marker(25, pos - vector3(0, 0, 0.9), vector3(16.0, 16.0, 1.5), { col[1], col[2], col[3], 255 }, 0.9)
		Sigf.Fx(Sigf.FX.electric[1], Sigf.FX.electric[2], pos + vector3(0, 0, 1.0), { scale = 3.0 })
		Sigf.Light(pos + vector3(0, 0, 3), col, 25.0, 12.0, 1.2)
		Sigf.Fx(Sigf.FX.firework[1], Sigf.FX.firework[2], pos + vector3(0, 0, 3), { scale = 1.5 })
		Sigf.Explode(pos, 0, { scale = 0.3, owner = hasPed(owner) and owner or nil, shake = 1.0, quiet = false })
		Sigf.Shake(0.6)
		for _, e in ipairs(Sigf.Near(pos, 8.5)) do
			if sideOf[e] ~= side then
				ApplyDamageToPed(e, 110, false)
				Sigf.Fx(Sigf.FX.sparks[1], Sigf.FX.sparks[2], GetEntityCoords(e) + vector3(0, 0, 0.5), { scale = 1.0 })
			end
		end
		if tyrant and #(pos - tyrant.pos) < 10.0 then HoK.HurtTyrant(220, side) end
	end)
end

local function spawnChampion(side)
	local pos = Sigf.Ground(Sigf.Arena() + vector3(side == 'a' and -22.0 or 22.0, 0.0, 0.0), 6)
	HoK.pending = side
	local ped = Sigf.Ped(side == 'a' and 'u_m_y_imporage' or 'u_m_y_juggernaut_01', pos, {
		enemy = side == 'b', weapon = side == 'a' and 'WEAPON_ASSAULTRIFLE' or 'WEAPON_MINIGUN',
		health = 700, armor = 60, accuracy = 40,
	})
	HoK.pending = nil
	if not ped then return end
	sideOf[ped] = side
	SetPedMaxHealth(ped, 800) SetEntityHealth(ped, 800)
	champ[side] = { ped = ped, nextUlt = GetGameTimer() + 5000, respawnAt = nil }
	Sigf.Text3D(TEAM[side].name .. ' CHAMPION', pos + vector3(0, 0, 2.6), 3.0, { color = TEAM[side].col, scale = 0.6, rise = 0.1 })
end

Sigf.Every(1, function()
	local now = GetGameTimer()
	for side, c in pairs(champ) do
		if alive(c.ped) then
			if now > c.nextUlt then
				c.nextUlt = now + 11000
				local best, bd = nil, 40.0
				for _, e in ipairs(Sigf.Peds()) do
					if sideOf[e] == other(side) then
						local d = #(GetEntityCoords(e) - GetEntityCoords(c.ped))
						if d < bd then best, bd = e, d end
					end
				end
				if best then HoK.Ult(side, GetEntityCoords(best), c.ped) end
			end
		else
			c.respawnAt = c.respawnAt or (now + 7000)
			if now > c.respawnAt then spawnChampion(side) end
		end
	end
end)

-- ---------- crystal towers ----------
local function towerPos(side)
	return Sigf.Ground(Sigf.Arena() + vector3(side == 'a' and -32.0 or 32.0, 8.0, 0.0), 0)
end

local function spawnTower(side)
	local pos = towerPos(side)
	local obj = Sigf.Prop(TEAM[side].tower, pos, { ground = true, heading = side == 'a' and 90.0 or 270.0 })
	if not obj then return end
	local c = GetEntityCoords(obj)
	Sigf.ScaleProp(obj, TS)
	towers[side] = { obj = obj, hp = 1200, max = 1200, pos = c, nextZap = GetGameTimer() + 2000 }
	Sigf.Fx(Sigf.FX.sparks[1], Sigf.FX.sparks[2], c + vector3(0, 0, 1), { scale = 3.0 })
	Sigf.Light(c + vector3(0, 0, 8.5), TEAM[side].col, 16.0, 6.0, 3)
end

function HoK.HurtTower(side, dmg)
	local t = towers[side]
	if not t or t.down then return end
	t.hp = t.hp - dmg
	if t.hp <= 0 then HoK.FallTower(side) end
end

function HoK.FallTower(side)
	local t = towers[side]
	if not t or t.down then return end
	t.down = true
	local winner = other(side)
	local obj, base = t.obj, t.pos
	Sigf.Text(TEAM[side].name .. ' TOWER DESTROYED', 4, { y = 0.2, size = 70, color = TEAM[winner].hex })
	Sigf.Sound('v_victory')
	feed(TEAM[side].name .. ' crystal tower falls!', winner)
	score[winner] = score[winner] + 5
	if winner == 'a' then me.gold = me.gold + 600 end
	local t0 = GetGameTimer()
	Sigf.Frame(function()
		if not hasPed(obj) then return false end
		local k = (GetGameTimer() - t0) / 1800.0
		if k >= 1.0 then return false end
		SetEntityCoords(obj, base.x, base.y, base.z - 5.0 * k * k, false, false, false, false)
		SetEntityRotation(obj, 18.0 * k * (side == 'a' and 1 or -1), 6.0 * k, side == 'a' and 90.0 or 270.0, 2, true)
		Sigf.ScaleProp(obj, TS)
	end)
	for i = 0, 5 do
		Sigf.After(i * 0.35, function()
			local o = vector3(math.random(-4, 4), math.random(-4, 4), 1.0 + i * 1.0)
			Sigf.Explode(base + o, 4, { scale = 0.6, shake = 1.0 })
			Sigf.Fx(Sigf.FX.fire[1], Sigf.FX.fire[2], base + o, { scale = 2.0 })
		end)
	end
	Sigf.Shake(1.0)
	Sigf.After(2.1, function()
		if hasPed(obj) then DeleteEntity(obj) end
		for i = 1, 8 do
			Sigf.Fx(Sigf.FX.firework[1], Sigf.FX.firework[2], base + vector3(math.random(-8, 8), math.random(-8, 8), 6 + math.random() * 6), { scale = 1.2 })
		end
	end)
	Sigf.After(14, function()
		towers[side] = nil
		spawnTower(side)
		feed(TEAM[side].name .. ' crystal tower rebuilt', side)
	end)
end

Sigf.Frame(function()
	local cam = Sigf.View().cam
	for side, t in pairs(towers) do
		if not t.down and hasPed(t.obj) then
			local p = t.pos + vector3(0, 0, 9.2 * TS)
			local d = #(p - cam)
			local pulse = 0.85 + 0.15 * math.sin(GetGameTimer() / 280.0)
			local cc = TEAM[side].col
			local orb = t.pos + vector3(0, 0, 5.6 * TS)
			DrawMarker(28, orb.x, orb.y, orb.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0 * pulse, 2.0 * pulse, 3.2 * pulse, cc[1], cc[2], cc[3], 130, false, false, 2, false, nil, nil, false)
			DrawLightWithRange(orb.x, orb.y, orb.z, cc[1], cc[2], cc[3], 30.0, 8.0 * pulse)
			if d < 140.0 then
				local c = TEAM[side].col
				local on, sx, sy = GetScreenCoordFromWorldCoord(p.x, p.y, p.z)
				if on then
					local s = math.max(0.5, math.min(1.5, 30.0 / d))
					local bw = 0.11 * s
					DrawRect(sx, sy, bw + 0.004, 0.02 * s + 0.004, 0, 0, 0, 210)
					DrawRect(sx - bw * (1 - t.hp / t.max) / 2, sy, bw * t.hp / t.max, 0.02 * s, c[1], c[2], c[3], 240)
				end
			end
		end
	end
end)

-- Towers zap enemies in range and are chipped by enemy fighters standing at their feet.
Sigf.Every(1, function()
	local now = GetGameTimer()
	for side, t in pairs(towers) do
		if not t.down and hasPed(t.obj) then
			local zapped, near = false, 0
			local best, bd = nil, 26.0
			for _, e in ipairs(Sigf.Near(t.pos, 26.0)) do
				if sideOf[e] == other(side) then
					local d = #(GetEntityCoords(e) - t.pos)
					if d < 15.0 then near = near + 1 end
					if d < bd then best, bd = e, d end
				end
			end
			if best then
				local from = t.pos + vector3(0, 0, 7.2 * TS)
				beams[#beams + 1] = { from = from, target = best, untilMs = now + 450, col = TEAM[side].col }
				ApplyDamageToPed(best, 45, false)
				Sigf.Sound('zap', t.pos)
				Sigf.Fx(Sigf.FX.electric[1], Sigf.FX.electric[2], GetEntityCoords(best), { scale = 1.0 })
			end
			if near > 0 then HoK.HurtTower(side, math.min(near, 5) * 6) end
		end
	end
end)

-- the stream player's bullets hurt towers and the Tyrant (impact point close to them)
Sigf.Every(0.15, function()
	local ped = PlayerPedId()
	if not IsPedShooting(ped) then return end
	local ok, pos = GetPedLastWeaponImpactCoord(ped)
	if not ok then return end
	for side, t in pairs(towers) do
		if not t.down and side == 'b' and #(pos - t.pos) < 8.0 then
			HoK.HurtTower(side, 35)
			Sigf.Fx(Sigf.FX.sparks[1], Sigf.FX.sparks[2], pos, { scale = 1.5 })
		end
	end
	if tyrant and not tyrant.dead and #(pos - (tyrant.pos + vector3(0, 0, 3))) < 6.0 then
		HoK.HurtTyrant(70, 'a')
		Sigf.Fx(Sigf.FX.sparks[1], Sigf.FX.sparks[2], pos, { scale = 1.5 })
	end
end)

-- ---------- the Tyrant ----------
local function tyrantHud()
	if tyrant and not tyrant.dead then
		pushHud({ boss = math.max(0, tyrant.hp / tyrant.max) })
	else
		pushHud({ boss = -1 })
	end
end

function HoK.HurtTyrant(dmg, side)
	if not tyrant or tyrant.dead or not tyrant.landed then return end
	tyrant.hp = tyrant.hp - dmg
	tyrant.credit[side] = (tyrant.credit[side] or 0) + dmg
	if tyrant.hp <= 0 then HoK.KillTyrant() end
end

function HoK.KillTyrant()
	local t = tyrant
	if not t or t.dead then return end
	t.dead = true
	local win = (t.credit.a or 0) >= (t.credit.b or 0) and 'a' or 'b'
	Sigf.Text('TYRANT SLAIN! ' .. TEAM[win].name .. ' GAINS THE DRAGON BUFF', 5, { y = 0.2, size = 58, color = '#ffd34d' })
	Sigf.Sound('v_victory')
	feed('The Tyrant is slain! ' .. TEAM[win].name .. ' is empowered', win)
	buff[win] = GetGameTimer() + 30000
	for _, e in ipairs(Sigf.Peds()) do
		if sideOf[e] == win then SetPedArmour(e, 100) SetEntityHealth(e, GetEntityMaxHealth(e)) end
	end
	if win == 'a' then me.gold = me.gold + 1000 end
	local base = t.pos
	for i = 0, 6 do
		Sigf.After(i * 0.3, function()
			Sigf.Explode(base + vector3(math.random(-3, 3), math.random(-3, 3), 1.5 + math.random() * 3), 29, { scale = 0.5, shake = 0.8 })
			Sigf.Fx(Sigf.FX.firework[1], Sigf.FX.firework[2], base + vector3(math.random(-5, 5), math.random(-5, 5), 5 + math.random() * 6), { scale = 1.4 })
		end)
	end
	Sigf.Shake(1.0)
	Sigf.After(2.5, function() if hasPed(t.obj) then DeleteEntity(t.obj) end tyrantHud() end)
	pushHud({ boss = -1 })
end

function HoK.IsTyrant() return tyrant and not tyrant.dead end
function HoK.Tyrant(at)
	if tyrant and not tyrant.dead then return end
	local pos = at or Sigf.Ground(Sigf.Arena() + vector3(0.0, -22.0, 0.0), 0)
	Sigf.Text('THE TYRANT HAS AWAKENED!', 4, { y = 0.2, size = 70, color = '#ff9d2e' })
	Sigf.Sound('v_tyrant')
	feed('The Tyrant dragon has awakened! Slay it for the Dragon Buff')
	local obj = Sigf.Prop('sigf_tyrant', pos + vector3(0, 0, 45.0), { heading = 0.0 })
	if not obj then return end
	local t = { obj = obj, pos = pos, hp = 1600, max = 1600, credit = {}, landed = false, dead = false, nextBreath = 0, born = GetGameTimer() }
	tyrant = t
	local t0 = GetGameTimer()
	Sigf.Frame(function()
		if not hasPed(obj) then return false end
		local k = math.min(1.0, (GetGameTimer() - t0) / 2600.0)
		local z = 45.0 * (1.0 - k * k)
		SetEntityCoords(obj, pos.x, pos.y, pos.z + z, false, false, false, false)
		if k >= 1.0 then
			PlaceObjectOnGroundProperly(obj)
			t.landed = true
			local oc = GetEntityCoords(obj)
			Sigf.Log(string.format('SIGF_NOTE tyrant at %.1f %.1f %.1f want %.1f %.1f %.1f vis=%s alpha=%s player=%s', oc.x, oc.y, oc.z, pos.x, pos.y, pos.z, tostring(IsEntityVisible(obj)), tostring(GetEntityAlpha(obj)), tostring(GetEntityCoords(PlayerPedId()))))
			Sigf.Focus(pos + vector3(0, 0, 3), 7)
			Sigf.Explode(pos, 29, { scale = 0.6, shake = 1.0 })
			Sigf.Fx(Sigf.FX.sparks[1], Sigf.FX.sparks[2], pos + vector3(0, 0, 1), { scale = 3.0 })
			Sigf.Shake(1.0)
			tyrantHud()
			return false
		end
	end)
end

Sigf.Every(1.2, function()
	local t = tyrant
	if not t or t.dead or not t.landed then return end
	local now = GetGameTimer()
	if now - t.born > 70000 then
		t.dead = true
		Sigf.Text('The Tyrant flew away', 3, { y = 0.2, size = 50 })
		if hasPed(t.obj) then DeleteEntity(t.obj) end
		pushHud({ boss = -1 })
		return
	end
	-- fighters hit it, it breathes fire back at the two nearest
	local list = {}
	for _, e in ipairs(Sigf.Near(t.pos, 34.0)) do
		if sideOf[e] then list[#list + 1] = { e = e, d = #(GetEntityCoords(e) - t.pos) } end
	end
	table.sort(list, function(a, b) return a.d < b.d end)
	for i, it in ipairs(list) do
		if it.d < 24.0 then
			HoK.HurtTyrant(10, sideOf[it.e])
			if i <= 6 then Sigf.Fx(Sigf.FX.sparks[1], Sigf.FX.sparks[2], t.pos + vector3(math.random(-2, 2), math.random(-1, 1), 2 + math.random() * 3), { scale = 1.0 }) end
		end
	end
	for i = 1, math.min(2, #list) do
		local e = list[i].e
		local from = t.pos + vector3(0, 0, 5.2)
		beams[#beams + 1] = { from = from, target = e, untilMs = now + 600, col = { 255, 150, 30 } }
		local ep = GetEntityCoords(e)
		ApplyDamageToPed(e, 55, false)
		Sigf.Fx('core', 'ent_sht_flame', e, { loop = true, life = 3, offset = vector3(0, 0, 0) })
		Sigf.Fx(Sigf.FX.fire[1], Sigf.FX.fire[2], ep, { scale = 1.5 })
		Sigf.Light(ep, { 255, 140, 30 }, 8.0, 5.0, 0.6)
	end
	if #list > 0 then
		SetEntityHeading(t.obj, GetHeadingFromVector_2d(list[1].e and (GetEntityCoords(list[1].e).x - t.pos.x) or 0, GetEntityCoords(list[1].e).y - t.pos.y) + HoK.tyrantYaw)
	end
	tyrantHud()
end)
HoK.tyrantYaw = 0.0

local function tyrantGlow()
	if not tyrant or tyrant.dead or not tyrant.landed or not hasPed(tyrant.obj) then return end
	local p = tyrant.pos + vector3(0, 0, 3.5)
	local pulse = 0.8 + 0.2 * math.sin(GetGameTimer() / 200.0)
	DrawLightWithRange(p.x, p.y, p.z, 255, 170, 60, 26.0, 9.0 * pulse)
	DrawLightWithRange(p.x, p.y + 0.0, p.z + 4.0, 255, 200, 90, 18.0, 6.0)
end

local function tyrantBar()
	-- big bar over the dragon
	if not tyrant or tyrant.dead or not tyrant.landed or not hasPed(tyrant.obj) then return end
	local p = tyrant.pos + vector3(0, 0, 9.0)
	local c = { 255, 160, 40 }
	local on, sx, sy = GetScreenCoordFromWorldCoord(p.x, p.y, p.z)
	if on then
		local d = #(p - Sigf.View().cam)
		local s = math.max(0.5, math.min(1.6, 30.0 / d))
		local bw = 0.16 * s
		DrawRect(sx, sy, bw + 0.004, 0.024 * s + 0.004, 0, 0, 0, 210)
		DrawRect(sx - bw * (1 - tyrant.hp / tyrant.max) / 2, sy, bw * tyrant.hp / tyrant.max, 0.024 * s, c[1], c[2], c[3], 240)
	end
end
Sigf.Frame(function() tyrantBar() tyrantGlow() end)

-- ---------- boot ----------
local function auto() return Sigf.Stage() ~= 'demo' end
Sigf.After(1, function()
	Sigf.Battle({ a = 9, b = 9, radius = 40.0, modelA = 's_m_y_marine_01', modelB = 'g_m_y_mexgoon_01', weaponA = 'WEAPON_SMG', weaponB = 'WEAPON_MICROSMG' })
	if auto() then
		Sigf.Text('HONOR OF KINGS x GTA V', 5, { y = 0.18, size = 80, color = '#ffd34d' })
		Sigf.Text('DAWN vs DUSK: destroy the crystal tower', 5, { y = 0.30, size = 40, color = '#ffffff' })
	end
	Sigf.Image('crown') Sigf.Image('coin')
	spawnTower('a') spawnTower('b')
	spawnChampion('a') spawnChampion('b')
	pushHud()
	Sigf.After(1.0, function() if towers.a then Sigf.Focus(towers.a.pos + vector3(0, 0, 4), 6) end end)
	Sigf.After(7.5, function() if towers.b then Sigf.Focus(towers.b.pos + vector3(0, 0, 4), 6) end end)
end)
Sigf.Every(1, function() pushHud() end)
local tour = 0
Sigf.Every(30, function()
	tour = tour + 1
	local t = towers[tour % 2 == 0 and 'a' or 'b']
	if auto() and t and not t.down and not (tyrant and not tyrant.dead) then Sigf.Focus(t.pos + vector3(0, 0, 4), 6) end
end)

-- The Tyrant wakes up on its own every 100 s.
Sigf.After(20, function() if auto() then HoK.Tyrant() end end)
Sigf.Every(100, function() if auto() then HoK.Tyrant() end end)

-- demo: keep the camera behind the hero while the autopilot is off (the stage only does it while the pilot runs)
Sigf.Frame(function()
	if Sigf.Stage() ~= 'demo' then return false end
	if HoK.alignCam then SetGameplayCamRelativeHeading(0.0) SetGameplayCamRelativePitch(-6.0, 1.0) end
end)

-- The demo hero is the Dawn champion: he stays on his feet at full health (minigun fire and blasts would ragdoll him).
Sigf.Frame(function()
	if Sigf.Stage() ~= 'demo' then return false end
	local ped = PlayerPedId()
	SetPedCanRagdoll(ped, false)
	SetEntityProofs(ped, true, true, true, true, true, true, true, true)
	if GetEntityHealth(ped) < 180 then SetEntityHealth(ped, 200) end
	if IsPedRagdoll(ped) or IsPedFalling(ped) then ClearPedTasksImmediately(ped) end
end)
function HoK.tyrantDebug()
	if not tyrant then return 'no tyrant' end
	local ok = hasPed(tyrant.obj)
	return string.format('tyrant exists=%s dead=%s landed=%s pos=%s objpos=%s hp=%s', tostring(ok), tostring(tyrant.dead), tostring(tyrant.landed), tostring(tyrant.pos), ok and tostring(GetEntityCoords(tyrant.obj)) or '-', tostring(tyrant.hp))
end
