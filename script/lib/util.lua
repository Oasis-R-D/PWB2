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

function server.SpawnFireHook(pos, chance)
	if math.random(0, 100) <= chance then
		SpawnFire(pos)
	end
end

function PlayFireSound(snd, pos, vol)
	StopSound(snd)
	PlaySound(snd, pos, 300)
end

function FREE(obj)
	obj = nil
end

----------------------------------------------------------------------------------------------
-- Weapon UTILs
----------------------------------------------------------------------------------------------

-- Reset player data on death
function CheckDeathReset()
	local count = GetEventCount("playerdied")
   	for i=1, count do
		local p, _, _ = GetEvent("playerdied", i)

		local wpns = PLAYER_WEAPONS[p]
		for j=1, #wpns do
			wpns[j]:initVars(p) -- this SHOULD reset weapons on death
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
		PlaySound(LoadSound(playMat .. "/hit-" 	 .. mag .. "0.ogg"), pos)
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
function AIM_GetSpreadedAim(pos, spreadRad, range, p, add)
	local _, posUse, _, dir = GetPlayerAimInfo(pos, range, p)

	-- Get Spread (Based on code from Novena)
	if spreadRad > 0 then
		local cosAngle = math.cos(spreadRad)

		SetRandomSeed(shared.seed + add)
		local z = 1 - GetRandomFloat(0,1)*(1 - cosAngle)

		SetRandomSeed(shared.seed + (2+add))
		local phi = GetRandomFloat(0,1)*math.pi*2

		local r   = math.sqrt(1 - z*z)
		local x   = r * math.cos(phi)
		local y   = r * math.sin(phi)
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

----------------------------------------------------------------------------------------------
-- Weapon Recoil
-- GoldSource styled "server sided" player aim recoil
-- Separate from the weapon class to save on memory
-- WARNING: Recoil will be higher in singleplayer, This is due to the game factoring
-- the viewpunch into the aim vector when playing singleplayer!
----------------------------------------------------------------------------------------------

local playerRecoil = {}

function AIM_RecoilTick(dt)
	for p in Players() do
		local len = VecLength(playerRecoil[p])
		if len > 0 then
		len = len - ((10.0 + len * 0.5) * dt)
		len = math.max(len, 0.0)
		playerRecoil[p] = VecScale(VecNormalize(playerRecoil[p]), len)
		end
	end
end

-- AIM_RECOILGET: Gets the aim direction's rotational offset used in FireBulletsPlayer()
local function AIM_RecoilGet(p)
	local recoil = playerRecoil[p]
	return QuatEuler(recoil[1], recoil[2], recoil[3])
end

-- AIM_RECOILADD: Increments the aim direction's rotational offset used in FireBulletsPlayer()
-- This MUST be ran on both the client and server or else desync will occur
function AIM_RecoilAdd(p, recoilPos)
	playerRecoil[p] = VecAdd(playerRecoil[p], recoilPos)
end

-- AIM_RECOILSET: Sets the aim direction's rotational offset used in FireBulletsPlayer()
-- This MUST be ran on both the client and server or else desync will occur
function AIM_RecoilSet(p, recoilPos)
	playerRecoil[p] = VecCopy(recoilPos)
end

-- AIM_RECOILADDMULT: Increments the aim direction's rotational offset used in FireBulletsPlayer() by a vector, while also making the old value lower
-- This MUST be ran on both the client and server or else desync will occur
function AIM_RecoilAddMult(p, recoilPos, multiplier)
	playerRecoil[p] = VecAdd(VecScale(playerRecoil[p], multiplier), recoilPos)
end

function AIM_RecoilApply(p, pos, dir)
	local len = VecLength(playerRecoil[p])
	if len == 0 then return dir end

	local firingTrans = Transform(pos, QuatLookAt(pos, VecAdd(pos, dir)))
	local localVec = TransformToLocalVec(firingTrans, dir)
	localVec = QuatRotateVec(AIM_RecoilGet(p), localVec)
	return TransformToParentVec(firingTrans, localVec)
end