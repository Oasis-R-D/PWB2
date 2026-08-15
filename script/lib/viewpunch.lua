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