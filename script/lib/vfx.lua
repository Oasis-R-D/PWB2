--============================================================================================
--[[ DYNAMIC LIGHTS
    Dynamic lights in PWB2 were made to recreate the Teardown weapon's shrinking light volumes.
    Dynamic lights can be attached to a weapons muzzle position if needed
]]
--============================================================================================

local dynLights = {}

function client.VFX_DynLight(p, intensity, life, color, pos, attachment)
    if settings.dynlights == false then return end
    
    attachment = attachment or false
    table.insert(dynLights, {p, intensity, life, color, pos, attachment})
end

function client.VFX_DynLightDraw(dt)
    for i, light in pairs(dynLights) do
        local usePos = Vec()

        if light[6] ~= false then
            usePos = GetToolLocationWorldTransform(light[6], light[1])
            if usePos then
                usePos = usePos.pos
                light[7] = usePos
            else
                usePos = light[7]
            end
        else
            usePos = light[5]
        end

        local timeLeft = light[3] - GetTime()
        if timeLeft <= 0 then
            table.remove(dynLights, i)
        else
            PointLight(VecAdd(usePos, VecScale(GetPlayerVelocity(light[1]), dt)), light[4][1], light[4][2], light[4][3], light[2]*(timeLeft/light[3]*light[3]))
        end
    end
end

--============================================================================================
--[[ BASIC VIEWPUNCH
    Very optimized and basic viewpunch from the GoldSRC engine
]]
--============================================================================================

local cl_punchangle = Vec(0,0,0)

function client.PUNCHBASIC_Apply(dt)
	local len = VecLength(cl_punchangle)
	if len <= 0 then return end

	local t = Transform(Vec(), QuatEuler(cl_punchangle[1], cl_punchangle[2], cl_punchangle[3]))
	SetPlayerCameraOffsetTransform(t, true)

	client.PUNCHBASIC_Decay(dt, len)
end

function client.PUNCHBASIC_Decay(dt, len)
	len = len - ((10.0 + len * 0.5) * dt)
	len = math.max(len, 0.0)
	cl_punchangle = VecScale(VecNormalize(cl_punchangle), len)
end

function client.PUNCHBASIC_Axis(axis, punch)
	cl_punchangle[axis] = cl_punchangle[axis] + punch
end

function client.PUNCHBASIC_Vec(punch)
	cl_punchangle = VecAdd(cl_punchangle, punch)
end

--============================================================================================
--[[ VIEWPUNCH
    PWB2's main viewpunch system from the Source engine, 
    uses a simulated spring for smooth movement.
]]
--============================================================================================

local vecPunchAngle    = Vec(0,0,0)
local vecPunchAngleVel = Vec(0,0,0)

function client.PUNCH_Apply(dt)
	if VecLength(vecPunchAngle) <= 0.000001 and VecLength(vecPunchAngleVel) <= 0.000001 then
		vecPunchAngle 	 = Vec(0,0,0)
		vecPunchAngleVel = Vec(0,0,0)
		return
	end

	client.PUNCH_Decay(dt)
	
	local t = Transform(Vec(), QuatEuler(vecPunchAngle[1], vecPunchAngle[2], vecPunchAngle[3]))
	SetPlayerCameraOffsetTransform(t, true)
end

function client.PUNCH_Decay(dt)
	vecPunchAngle = VecAdd(vecPunchAngle, VecScale(vecPunchAngleVel, dt))
	local damping = math.max(1 - (9 * dt), 0)

	vecPunchAngleVel = VecScale(vecPunchAngleVel, damping)
	
	-- torsional spring
	local springForceMagnitude = math.min(65 * dt, 2.0)
	vecPunchAngleVel = VecSub(vecPunchAngleVel, VecScale(vecPunchAngle, springForceMagnitude))

	-- don't wrap around
	vecPunchAngle[1] = clamp(vecPunchAngle[1], -89,  89 )
	vecPunchAngle[2] = clamp(vecPunchAngle[2], -179, 179)
	vecPunchAngle[3] = clamp(vecPunchAngle[3], -89,  89 )
end

function client.PUNCH_Axis(axis, punch, mult)
	mult = mult and mult or 20
	vecPunchAngleVel[axis] = vecPunchAngleVel[axis] + punch * mult
end

function client.PUNCH_Vec(punch, mult)
	mult = mult and mult or 20
	vecPunchAngleVel = VecAdd(vecPunchAngleVel, VecScale(punch, mult))
end

function client.PUNCH_Reset(tolerance)
	tolerance = tolerance or 0
	if tolerance ~= 0 then
		tolerance = tolerance

		local check = VecLength(vecPunchAngleVel) + VecLength(vecPunchAngle)

		if tolerance > 0 and check > tolerance then
			return
		elseif tolerance < 0 and check < (tolerance*-1) then
			return
		end
	end

	vecPunchAngle 	 = Vec(0,0,0)
	vecPunchAngleVel = Vec(0,0,0)
end

function client.PUNCH_MachineGunKick(maxVerticleKickAngle, fireDurationTime, slideLimitTime )
	local vecScratch = Vec()
	
	--Find how far into our accuracy degradation we are
	local duration = fireDurationTime > slideLimitTime and slideLimitTime or fireDurationTime
	local kickPerc = duration / slideLimitTime

	-- do this to get a hard discontinuity, clear out anything under 10 degrees punch
	client.PUNCH_Reset( 10 )

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
	client.PUNCH_Axis(1, vecScratch[1])
	client.PUNCH_Axis(2, vecScratch[2])
	client.PUNCH_Axis(3, vecScratch[3])
end

--============================================================================================
--[[ DYNAMIC FOV
    Mainly used for ADS, smoothly lerps between user FOV and a set FOV value
]]
--============================================================================================

local FOV_cur = nil
local FOV_mult = 1

function client.FOV_Apply(dt)
	local baseFOV = GetFloat("options.gfx.fov")
	if not FOV_cur then FOV_cur = baseFOV end

	local diff = math.abs(FOV_cur - (baseFOV*FOV_mult))
	local FOV_new = lerp(FOV_cur, baseFOV*FOV_mult, diff * 0.5 * dt + dt)
	FOV_cur = FOV_new

	SetCameraFov(FOV_cur)
end

function client.FOV_set(multiplier)
	FOV_mult = multiplier
end

--============================================================================================
--[[ VISUAL EFFECTS
    Contains global visual effects such as blood
]]
--============================================================================================

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

function server.BloodDecal(pos, dir, damage, playerhit, ignore)
	local count = 1
	local noise = 0.1
	if damage < 0.1 then
		noise = 0.3
		count = 2
	elseif damage < 0.25 then
		noise = 0.35
		count = 5
	elseif damage > 0.8 then
		noise = 0.6
		count = 13
	else
		noise = 0.45
		count = 8
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