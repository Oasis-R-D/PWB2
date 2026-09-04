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

function PlayFireSound(snd, pos, vol)
	StopSound(snd)
	PlaySound(snd, pos, 300)
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

function GetShapeMaterialAtPos(shape, pos)
	local _, point = GetShapeClosestPoint(shape, pos)
	
	pos = TransformToLocalPoint(GetShapeWorldTransform(shape), point)

	for i = 1, 3 do
		pos[i] = math.floor(pos[i]*10)
	end

	return GetShapeMaterialAtIndex(shape, pos[1], pos[2], pos[3])
end

function PlayImpactSFX(shape, pos, mag)
	mag = mag or "l"

	local material = GetShapeMaterialAtPos(shape, pos)

	-- Some materials share sounds!
	local playMat = material
	if playMat == "rock" then
		playMat = "masonry"
	elseif playMat == "plaster" then
		playMat = "plastic"
	elseif playMat == "hardmetal" then
		playMat = "metal"
	end

	if playMat ~= "" then
		PlaySound(LoadSound(playMat .. "/break-" .. mag .. "0.ogg"), pos)
		PlaySound(LoadSound(playMat .. "/hit-" .. mag .. "0.ogg"), pos)
	end

	--DebugPrint("mat: " .. material)
	return material
end

function QueryShootRope(pos, dir, range)
	local ropeHit, ropeDist, ropeJoint = QueryRaycastRope(pos, dir, range)
	if ropeHit then
		local breakPoint = VecAdd(pos, VecScale(dir, ropeDist))
		BreakRope(ropeJoint, breakPoint)
	end
end

shared.seed = 1
function GetPlayerAimInfoSpread(pos, spreadRad, range, p, add)
	local _, posUse, _, dir = GetPlayerAimInfo(pos, range, p)

	-- Get Spread (Based on code from Novena)
	if spreadRad > 0 then
		local cosAngle = math.cos(spreadRad)
		SetRandomSeed(shared.seed + add)
		local z = 1 - GetRandomFloat(0,1)*(1 - cosAngle)
		SetRandomSeed(shared.seed + (2+add))
		local phi = GetRandomFloat(0,1)*math.pi*2
		local r = math.sqrt(1 - z*z)
		local x = r * math.cos(phi)
		local y = r * math.sin(phi)
		local vec = Vec(x, y, z)

		if dir[3] > 0.9999 then
			dir = vec
		elseif dir[3] < -0.9999 then
			dir = VecScale(vec,-1)
		else
			local quat = QuatLookAt(Vec(0,0,0),VecScale(dir,-1))
			dir = TransformToParentVec(Transform(Vec(0,0,0),quat),vec)
		end
	end
	
	return posUse, dir
end