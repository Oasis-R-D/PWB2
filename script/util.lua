----------------------------------------------------------------------------------------------
-- Temp-Ents
----------------------------------------------------------------------------------------------

function CL_TempEntAlloc(org, model)

	local tempent = newTempEnt()

	tempent.flags = FTENT_NONE
	tempent.die = 0
	tempent.entity.model = Spawn(model, Transform(org))[1]
	tempent.fadeSpeed = 0.5
	tempent.hitSound = 0
	tempent.bounceFactor = 1.0
	tempent.entity.origin = org

	local index = findArrayOpening(gpTempEnts)
	gpTempEnts[index] = tempent

	return gpTempEnts[index]
end

function R_TempModel(pos, velocity, angles, life, model, soundtype)

	local tempent = CL_TempEntAlloc(pos, model)

	tempent.entity.angles = angles
	tempent.flags = 1048614 --addFlags(FTENT_NONE, FTENT_COLLIDEWORLD, FTENT_GRAVITY, FTENT_BUOYANT, FTENT_ROTATE)
	tempent.hitSound = soundtype
	tempent.frameMax = 0 -- tempent.frameMax = framecount
	
	tempent.entity.velocity = velocity
	tempent.entity.angleVel = GetRandomDirection(256) --Vec(GetRandomFloat(-512, 511), GetRandomFloat(-256, 255), GetRandomFloat(-256, 255))
	tempent.die = life + GetTime()
end

function ejectBrass(p, org, dir, model, casingtype)
	local transform = GetBodyTransform(GetToolBody(p))

	local eject_origin = TransformToParentPoint(transform, org)

	-- add some randomization
	dir[1] = dir[1] + GetRandomFloat(0.75, 1)
	dir[2] = dir[2] + GetRandomFloat(1.5, 2.125)
	dir[3] = dir[3] + GetRandomFloat(0.5, 0.75)

	local eject_vel = TransformToParentVec(transform, dir)
	eject_vel = VecAdd(eject_vel, GetPlayerVelocity(p))

	local x, y, z = GetQuatEuler(transform.rot)

	R_TempModel(eject_origin, eject_vel, Vec(x, y, z), 2.5, model, casingtype)
end

----------------------------------------------------------------------------------------------
-- GoldSource Viewpunch
----------------------------------------------------------------------------------------------

local cl_punchangle = Vec(0,0,0)

function client.GS_ApplyPlayerPunch(dt)
	local t = Transform(Vec(), QuatEuler(cl_punchangle[1], cl_punchangle[2], cl_punchangle[3]))
	SetPlayerCameraOffsetTransform(t, true)

	client.GS_DropPunchAngle(dt)
end

function client.GS_DropPunchAngle(dt)
	local len = VecLength(cl_punchangle)
	len = len - ((10.0 + len * 0.5) * dt)
	len = math.max(len, 0.0)
	cl_punchangle = VecScale(VecNormalize(cl_punchangle), len)
end

function client.GS_PunchAxis(axis, punch)
	cl_punchangle[axis] = punch
end

----------------------------------------------------------------------------------------------
-- Source Viewpunch
----------------------------------------------------------------------------------------------

local vecPunchAngle    = Vec(0,0,0)
local vecPunchAngleVel = Vec(0,0,0)

function client.SRC_ApplyPlayerPunch(dt)
	local t = Transform(Vec(), QuatEuler(vecPunchAngle[1], vecPunchAngle[2], vecPunchAngle[3]))
	SetPlayerCameraOffsetTransform(t, true)

	client.SRC_DecayPunchAngle(dt)
end

function client.SRC_DecayPunchAngle(dt)
	if VecLength(vecPunchAngle) > 0.03 or VecLength(vecPunchAngleVel) > 0.03 then
		vecPunchAngle = VecAdd(vecPunchAngle, VecScale(vecPunchAngleVel, dt))
		local damping = 1 - (9 * dt)
		
		if damping < 0 then 
			damping = 0
		end

		vecPunchAngleVel = VecScale(vecPunchAngleVel, damping)
		
		-- torsional spring
		-- UNDONE: Per-axis spring constant?
		local springForceMagnitude = 65 * dt
		springForceMagnitude = math.clamp( springForceMagnitude, 0.0, 2.0 )
		vecPunchAngleVel = VecSub(vecPunchAngleVel, VecScale(vecPunchAngle, springForceMagnitude))

		-- don't wrap around
		vecPunchAngle[1] = math.clamp(vecPunchAngle[1], -89,  89 )
		vecPunchAngle[2] = math.clamp(vecPunchAngle[2], -179, 179)
		vecPunchAngle[3] = math.clamp(vecPunchAngle[3], -89,  89 )
	else
		vecPunchAngle 	 = Vec(0,0,0)
		vecPunchAngleVel = Vec(0,0,0)
	end
end

function client.SRC_PunchAxis(axis, punch)
	vecPunchAngleVel[axis] = vecPunchAngleVel[axis] + punch * 20
end

function client.SRC_PunchReset(tolerance)
	tolerance = tolerance or 0
	if tolerance ~= 0 then
		tolerance = tolerance

		local check = VecLength(vecPunchAngleVel) + VecLength(vecPunchAngle)

		if check > tolerance then
			return
		end
	end

	vecPunchAngle 	 = Vec(0,0,0)
	vecPunchAngleVel = Vec(0,0,0)
end

function client.DoMachineGunKick(maxVerticleKickAngle, fireDurationTime, slideLimitTime )
	local vecScratch = Vec()
	
	--Find how far into our accuracy degradation we are
	local duration = fireDurationTime > slideLimitTime and slideLimitTime or fireDurationTime
	local kickPerc = duration / slideLimitTime

	-- do this to get a hard discontinuity, clear out anything under 10 degrees punch
	client.SRC_PunchReset( 10 )

	--Apply this to the view angles as well
	vecScratch[1] =    0.2 + ( maxVerticleKickAngle * kickPerc )
	vecScratch[2] = -( 0.2 + ( maxVerticleKickAngle * kickPerc ) ) / 3
	vecScratch[3] =    0.1 + ( maxVerticleKickAngle * kickPerc )   / 8

	--Wibble left and right
	if math.random( -1, 1 ) >= 0 then
		vecScratch[2] = vecScratch[2] * -1 
	end

	--Wobble up and down
	if math.random( -1, 1 ) >= 0 then
		vecScratch[3] = vecScratch[3] * -1
	end

	--Clip this to our desired min/max
	local final = VecAdd(vecScratch, vecPunchAngle)
	local clip = Vec(24, 3, 1)

	--Clip each component
	for i=1, 3 do
		if final[i] > clip[i] then
			final[i] = clip[i]
		elseif final[i] < -clip[i] then
			final[i] = -clip[i]
		end

		--Return the result
		vecScratch[i] = final[i] - vecPunchAngle[i]
	end

	--Add it to the view punch
	-- NOTE: 0.5 is just tuned to match the old effect before the punch became simulated
	vecScratch = VecScale(vecScratch, 0.5)
	client.SRC_PunchAxis(1, vecScratch[1])
	client.SRC_PunchAxis(2, vecScratch[2])
	client.SRC_PunchAxis(3, vecScratch[3])
end

----------------------------------------------------------------------------------------------
-- Blood Effects
----------------------------------------------------------------------------------------------

function client.BloodParticles(pos, dir, damage, playerhit)
	local impactsize = damage
	if impactsize > 0.3 then
		impactsize = 0.3
	end

	local size = impactsize/5
	if size > 0.035 then
		size = 0.035
	elseif size <= 0.02 then
		size = 0.02
	end

	local playervel = GetPlayerVelocity(playerhit)

	local blooddir = VecScale(dir, -1)

	local cloudsize = size*10

	local dropsize = damage/3
	if dropsize > 0.4 then dropsize = 0.4 end

	for i=0, 4 do
		ParticleReset()
		ParticleRadius(dropsize)
		ParticleGravity(GetRandomFloat(-5, -10))
		ParticleAlpha(5, 0, "easein") 
		ParticleTile(5)
		ParticleStretch(10)
		ParticleColor(0.33, 0.01, 0)
		ParticleCollide(0)
		local direct = VecAdd(blooddir, GetRandomDirection(0.25))
		SpawnParticle(pos, VecAdd(VecScale(direct, GetRandomFloat(0.8, 3.0)), playervel), 0.75)

		ParticleReset()
		ParticleRadius(cloudsize, 0.35)
		ParticleAlpha(5, 0, "easein") 
		ParticleTile(1)
		ParticleStretch(10)
		ParticleColor(0.33, 0.01, 0)
		ParticleCollide(0)
		SpawnParticle(pos, VecAdd(VecScale(direct, math.random()*1.5), playervel), 0.75)
	end

	for i=0, (impactsize * 40) do
		size = size + GetRandomFloat(-0.01, 0.005)
		newPos = VecAdd(pos, GetRandomDirection(0.25))
		ParticleReset()
		ParticleGravity(GetRandomFloat(-20, -25))
		ParticleRadius(size)
		ParticleAlpha(1, 0, "easein") 
		ParticleColor(0.33, 0.01, 0)
		ParticleTile(6)
		ParticleDrag(0.0625)
		ParticleSticky(0.5)
		ParticleCollide(0, 1, "easeout")
		ParticleRotation(0.2, 0)
		ParticleStretch(1, 0, "easein")
		SpawnParticle(newPos, VecAdd(VecScale(GetRandomDirection(), GetRandomFloat(2, 6)), playervel), 3)
	end
end

function BloodVFX(pos, dir, damage, playerhit, ignore)
	ClientCall(0, "client.BloodParticles", pos, dir, damage, playerhit) -- NOTE: could be worth it to have a check so you only send this to clients in the PVS

	local count = 1
	local noise = 0.1
	if damage < 0.1 then
		noise = 0.2
		count = 3
	elseif damage < 0.25 then
		noise = 0.35
		count = 6
	elseif damage > 0.8 then
		noise = 0.6
		count = 18
	else
		noise = 0.35
		count = 12
	end

	-- Impact for animators
	PaintRGBA(pos, GetRandomFloat(0.166, 0.3), GetRandomFloat(0.2, 0.3), 0.0, 0.0, 1.0, 0.9)

	for i=0, count do 
		local newPos = VecAdd(pos, GetRandomDirection(0.2))
		local newdir = VecNormalize(VecAdd(VecAdd(dir, GetRandomDirection(noise)), VecScale(GetGravity(), 0.025)))

		if ignore ~= nil then QueryRejectAnimator(ignore) end
		local bloodhit, blooddist = QueryRaycast(pos, newdir, 5.5)

		if bloodhit ~= 0 and blooddist > 0.33 then
			local splatDist = blooddist
			if splatDist > 1 then splatDist = 1 end
			local chance = GetRandomFloat(0.75, 1.0) * 1/splatDist * splatDist / 2
			PaintRGBA(VecAdd(pos, VecScale(newdir, blooddist)), GetRandomFloat(0.166, 0.3), GetRandomFloat(0.166, 0.2), 0.0, 0.0, 1.0, chance)
		end
	end
	
	local newestdir = VecNormalize(VecAdd(dir, VecScale(GetGravity(), 0.025)))
	if ignore ~= nil then QueryRejectAnimator(ignore) end
	local bigbloodhit, bigblooddist = QueryRaycast(pos, newestdir, 4)

	if bigbloodhit ~= 0 then
		local splatDist = bigblooddist
		if splatDist > 1 then splatDist = 1 end
		local chance = splatDist/1
		PaintRGBA(VecAdd(pos, VecScale(dir, bigblooddist)), 0.5, GetRandomFloat(0.166, 0.2), 0.0, 0.0, 1.0, chance)
	end
end

----------------------------------------------------------------------------------------------
-- UTILs
----------------------------------------------------------------------------------------------

function findArrayOpening(array)
    local i = 1
    while array[i] ~= nil do
        i = i + 1
    end
    return i
end

-- Returns true if the server is MP
function isMP()
	return GetMaxPlayers() > 1
end

function server.SpawnFireHook(pos, chance)
	if math.random(0, 100) <= chance then
		SpawnFire(pos)
	end
end

function PlaySoundOverrider(snd, pos, vol)
	StopSound(snd)
	PlaySound(snd, mt.pos, 300)
end

----------------------------------------------------------------------------------------------
-- Weapon UTILs
----------------------------------------------------------------------------------------------

-- Reset player data on death
function checkDeathReset()
	local count = GetEventCount("playerdied")
   	for i=1, count do
		local p, _, _ = GetEvent("playerdied", i)
		
		local wpns = PLAYER_WEAPONS[p]
		for i=1, #wpns do
			wpns[i]:initVars(p) -- this SHOULD reset weapons on death
		end
   	end
end

function getAimVector(pos, range, spreadRad, p, spreadRadVert)
	spreadRadVert = spreadRadVert or spreadRad

	local _,newPos,_,dir = GetPlayerAimInfo(pos, range, p)

	if spreadRad <= 0 then
		return newPos, dir
	end
	
	-- BEGIN BORROWED CODE (Thanks Novena)
	local cosAngle = math.cos(spreadRad)
	local z = 1 - math.random()*(1 - cosAngle)
	local phi = math.random()*math.pi*2
	local r = math.sqrt(1 - z*z)
	local x = r * math.cos(phi)
	local y = r * math.sin(phi)
	local vec = Vec(x, y, z)

	if dir[3] > 0.9999 then
		return newPos, vec
	elseif dir[3] < -0.9999 then
		return newPos, VecScale(vec,-1)
	end

	local quat = QuatLookAt(Vec(0,0,0),VecScale(dir,-1))
	local newDir = TransformToParentVec(Transform(Vec(0,0,0),quat),vec)
	-- END BORROWED CODE

	return newPos, newDir
end

function PlayImpactSFX(shape, pos, normal, mag)
	mag = mag or "l"

	pos = VecSub(pos, VecScale(normal, 0.05))

	local playPos = pos
	
	pos = TransformToLocalPoint(GetShapeWorldTransform(shape), pos)

	for i = 1, 3 do
		pos[i] = math.floor(pos[i]*10)
	end

	local material = GetShapeMaterialAtIndex(shape, pos[1], pos[2], pos[3])

	-- Some materials share sounds!
	local playMat = material
	if playMat == "rock" then
		playMat = "masonry"
	elseif playMat == "plaster" then
		playMat = "plastic"
	elseif playMat == "hardmetal" then
		playMat = "metal"
	end

	if playMat ~= "" then PlaySound(LoadSound(playMat .. "/hit-" .. mag .. "0.ogg"), playPos) end

	DebugPrint(material)
end

-- hook the Shoot func to add new stuff
function server.ShootHook(pos, dir, shoottype, damage, playerdamage, range, player, weaponid, weaponname, impulseMult, radius)
	impulseMult = impulseMult or 1
	playerdamage = playerdamage or 0
	radius = radius or 0

	-- destroy ropes (only runs once!!)
	local ropeHit, ropeDist, ropeJoint = QueryRaycastRope(pos, dir, range)
	if ropeHit then
		local breakPoint = VecAdd(pos, VecScale(dir, ropeDist))
		BreakRope(ropeJoint, breakPoint)
	end
	
	-- figure out whether we need to run player or world hit code
	local bHit, pdist, pShape, playerhit = QueryShot(pos, dir, range, 0, player)

	if radius > 0 then
		QueryRequire("player")
		HULLbHit, HULLpdist, HULLpShape, HULLplayerhit, _, normal = QueryShot(pos, dir, range, radius, player)

		if HULLplayerhit ~= 0 then
			local hitPoint = VecAdd(pos, VecAdd(VecScale(dir, HULLpdist), VecScale(normal, -radius)))
			pdist = HULLpdist
			dir = VecNormalize(VecSub(hitPoint, pos))
			playerhit = HULLplayerhit
			bHit = true
		end
	end

	-- knock back objects some more
	if bHit then
		ApplyBodyImpulse(GetShapeBody(pShape), VecAdd(pos, VecScale(dir, pdist)), VecScale(dir, 800 * impulseMult))
	end

	local hitAnimator = GetBodyAnimator(GetShapeBody(pShape))

	if playerhit == 0 and hitAnimator == 0 then
		-- use normal shooting for world
		Shoot(pos, dir, shoottype, damage, range, player, weaponid)
	elseif playerdamage > 0 then
		-- play player impact SFX
		local SoundPoint = VecAdd(pos, VecScale(dir, pdist))
		PlaySound(LoadSound("MOD/snd/bullet_hit0.ogg"), SoundPoint, 2)

		-- don't actually hit the player so we can do our own damage and vfx
		local newrange = pdist - 0.5
		if newrange > 0 then Shoot(pos, dir, shoottype, 0.0, newrange, player, weaponid) end

		if playerhit ~= 0 then
			-- apply hitgroups
			QueryRequire("player")
			QueryInclude("player")
			QueryRejectPlayer(player)
			local _, _, _, bodyPart = QueryRaycast(pos, dir, pdist + 0.25)

			
			local hitPart = GetTagValue(GetShapeBody(bodyPart), "bone")
			if hitPart == "head" or hitPart == "neck" then
				playerdamage = playerdamage * GLOBAL_HEADSHOTMULT
			end

			-- Deal damage
			ApplyPlayerDamage(playerhit, playerdamage, weaponname, player)

			-- Blood VFX
			BloodVFX(SoundPoint, dir, playerdamage, playerhit)
		else
			-- Blood VFX
			BloodVFX(SoundPoint, dir, playerdamage, nil, hitAnimator)
		end
	end

	return bHit, pdist, playerhit
end