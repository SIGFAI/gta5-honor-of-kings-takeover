-- Demo: the stream player is the Dawn hero. Moments: tower shot, ultimate + kill streak, tower siege, Tyrant boss.
-- a ground point d metres ahead of the hero (Sigf.Front gave the hero's own spot here)
local function frontPos(d, sideways)
	local me = PlayerPedId()
	local p = GetOffsetFromEntityInWorldCoords(me, (sideways or 0.0) + 0.0, d + 0.0, 0.0)
	local ok, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 30.0, false)
	return vector3(p.x, p.y, ok and z or p.z - 1.0)
end

local function foe(dist, model, opts)
	opts = opts or { weapon = 'WEAPON_PISTOL' }
	opts.enemy = true
	opts.heading = GetEntityHeading(PlayerPedId()) + 180.0
	HoK.pending = 'b'
	local e = Sigf.Ped(model or 'g_m_y_mexgoon_01', frontPos(dist, math.random(-4, 4)) + vector3(0, 0, 0.5), opts)
	HoK.pending = nil
	return e
end

Sigf.Demo(1, function()
		Sigf.Text('HONOR OF KINGS x GTA V', 4, { y = 0.12, size = 70, color = '#ffd34d' })
	local t = HoK.towers.b
	if t and not t.down then
		Sigf.Cinematic(t.pos + vector3(-16, -20, 6), t.pos + vector3(0, 0, 7), 5.0, 55.0)
	end
end)
Sigf.Demo(6, function() Sigf.Text('Crystal towers zap anyone in range', 4, { y = 0.43, size = 40, color = '#ffffff' }) end)

-- Moment 2: ultimate then a kill streak
Sigf.Demo(26, function()
	Sigf.Pilot(false) HoK.alignCam = true
	local me = PlayerPedId()
	local stand = Sigf.Ground(Sigf.Arena() + vector3(-4.0, -12.0, 0.0), 0)
	SetEntityCoords(me, stand.x, stand.y, stand.z + 1.0, false, false, false, false)
	SetEntityHeading(me, 0.0)
	local a, b, c = foe(16), foe(18), foe(15)
	local p = frontPos(15)
	Sigf.Text('HERO ULTIMATE!', 3, { y = 0.43, size = 40, color = '#7fc4ff' })
	HoK.Ult('a', p, PlayerPedId())
	Sigf.After(2.6, function()
		for i, e in ipairs({ a, b, c }) do
			Sigf.After(0.8 * (i - 1), function()
				if e and DoesEntityExist(e) then Sigf.LookAt(e, 0.5) Sigf.Shoot(0.6, e) Sigf.After(0.5, function() Sigf.KillByHost(e) end) end
			end)
		end
	end)
	Sigf.After(8, function() Sigf.Pilot(true) HoK.alignCam = false end)
end)

-- Moment 3: siege the Dusk tower
Sigf.Demo(38, function()
	Sigf.Pilot(false) HoK.alignCam = true
	local t = HoK.towers.b
	if not t or t.down then Sigf.Pilot(true) HoK.alignCam = false return end
	Sigf.Text('DESTROY THE CRYSTAL TOWER', 4, { y = 0.43, size = 40, color = '#ff6a6a' })
	local me = PlayerPedId()
	-- the hero runs up to 17 m from the tower, facing it
	local toArena = Sigf.Arena() - t.pos
	toArena = vector3(toArena.x, toArena.y, 0.0) / #vector3(toArena.x, toArena.y, 0.0)
	local stand = Sigf.Ground(t.pos + toArena * 17.0, 0)
	SetEntityCoords(me, stand.x, stand.y, stand.z + 1.0, false, false, false, false)
	SetEntityHeading(me, GetHeadingFromVector_2d(t.pos.x - stand.x, t.pos.y - stand.y))
	Sigf.LookAt(t.pos + vector3(0, 0, 3), 1.0)
	local pp = GetEntityCoords(me)
	local dir = t.pos - pp
	dir = vector3(dir.x, dir.y, 0.0) / #vector3(dir.x, dir.y, 0.0)
	Sigf.Cinematic(pp - dir * 4.5 + vector3(0, 0, 2.2), t.pos + vector3(0, 0, 4.5), 8.5, 60.0)
	Sigf.After(1.2, function()
		Sigf.Shoot(6.0, t.pos + vector3(0, 0, 3))
		for i = 1, 12 do
			Sigf.After(0.5 * i, function() HoK.HurtTower('b', 110) end)
		end
	end)
	Sigf.After(8.5, function()
		local t2 = HoK.towers.b
		if t2 and not t2.down then HoK.HurtTower('b', 5000) end
		Sigf.Pilot(true) HoK.alignCam = false
	end)
end)

-- Moment 4: the Tyrant (the hero is staged south of the lane, the dragon lands 26 m ahead)
Sigf.Demo(7, function()
	Sigf.Pilot(false) HoK.alignCam = true
	local me = PlayerPedId()
	local A = Sigf.Arena()
	local stand = Sigf.Ground(A + vector3(0.0, -10.0, 0.0), 0)
	SetEntityCoords(me, stand.x, stand.y, stand.z + 1.0, false, false, false, false)
	SetEntityHeading(me, 0.0)
	local tpos = Sigf.Ground(A + vector3(0.0, 16.0, 0.0), 0)
	HoK.Tyrant(tpos)
	Sigf.Cinematic(tpos + vector3(-24.0, -8.0, 5.0), tpos + vector3(0, 0, 3.5), 6.0, 60.0)
	Sigf.After(6.5, function() SetEntityHeading(me, 0.0) Sigf.LookAt(tpos, 1.0) end)
	Sigf.After(7.0, function()
		Sigf.Text('SLAY THE TYRANT FOR THE DRAGON BUFF', 4, { y = 0.43, size = 40, color = '#ffd34d' })
		Sigf.Shoot(8.0, tpos + vector3(0, 0, 3))
		for i = 1, 5 do Sigf.After(1.3 * i, function() HoK.HurtTyrant(220, 'a') end) end
	end)
	Sigf.After(17, function()
		if HoK.IsTyrant() then HoK.HurtTyrant(5000, 'a') end
		Sigf.Pilot(true) HoK.alignCam = false
	end)
end)
