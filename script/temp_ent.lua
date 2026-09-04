-- NOTE: some features have been removed. See entity.CPP in the Half-Life: 1 SDK if you really need them back.

local pTempEnts = {}

--===========================================
--	Definitions
--============================================

local function newCLent()
	return {
		-- float
		nextThink = 0.0,

		-- Actual render position and angles
		origin = Vec(),
		angles = Vec(),
		angleVel = Vec(),
		prevOrigin = Vec(),
		velocity = Vec(),

		model = 0, -- Temp ent body
	}
end

local function newTempEnt()
	return {
		-- int
		flags = 0, 
		hitSound = 0,

		-- floats
		die = 0,
		bounceFactor = 0,

		entity = newCLent(),
	}
end

--===========================================
--	Creation
--============================================

local function CL_TempEntAlloc(org, model)

	local tempent = newTempEnt()

	tempent.flags = FTENT_NONE
	tempent.die = 0
	tempent.entity.model = Spawn(model, Transform(org))[1]
	tempent.hitSound = 0
	tempent.bounceFactor = 1.0
	tempent.entity.origin = org

	local index = findArrayOpening(pTempEnts)
	pTempEnts[index] = tempent

	return pTempEnts[index]
end

local function R_TempModel(pos, velocity, angles, life, model, soundtype)

	local tempent = CL_TempEntAlloc(pos, model)

	tempent.entity.angles = angles
	tempent.flags = 1048614 --addFlags(FTENT_NONE, FTENT_COLLIDEWORLD, FTENT_GRAVITY, FTENT_BUOYANT, FTENT_ROTATE)
	tempent.hitSound = soundtype
	tempent.frameMax = 0 -- tempent.frameMax = framecount
	
	tempent.entity.velocity = velocity
	tempent.entity.angleVel = GetRandomDirection(256)
	tempent.die = life + GetTime()
end

function ENT_EjectShell(p, org, dir, model, casingtype)
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

--===========================================
--	Simulation
--============================================

local shellSFX_brass = 0
local shellSFX_buck = 0

function ENT_UpdateTempents(
    frametime,	-- Simulation time
	client_time, -- Absolute time on client
	cl_gravity)	-- True gravity on client

    local pTempEnts_Length = #pTempEnts

	-- Nothing to simulate
	if pTempEnts_Length == 0 then
		return end

    for i = 1, pTempEnts_Length do
		local pTemp = pTempEnts[i]
		if pTemp ~= nil then
			local life = pTemp.die - client_time
			if life < 0 then
				Delete(pTemp.entity.model)
				table.remove(pTempEnts, i)
			else
				pTemp.entity.prevOrigin = VecCopy(pTemp.entity.origin)

				-- apply velocity
				for j = 1, 3 do
					pTemp.entity.origin[j] = pTemp.entity.origin[j] + (pTemp.entity.velocity[j] * frametime)
				end

				if hasFlag(pTemp.flags, FTENT_ROTATE) then
					for j = 1, 3 do
						pTemp.entity.angles[j] = pTemp.entity.angles[j] + pTemp.entity.angleVel[j] * frametime
					end
				end

				local gravity = -frametime * cl_gravity

				if hasFlag(pTemp.flags, FTENT_COLLIDEWORLD) then
					local betweenDir = VecNormalize(pTemp.entity.velocity)
					local betweenLen = VecLength(pTemp.entity.velocity) * frametime

					QueryRequire("visible physical")
					local hit, dist, traceNormal = QueryRaycast(pTemp.entity.prevOrigin, betweenDir, betweenLen)
					
					if hit == true then
						local proj, damp

						-- Pull away from walls
						local useDist = dist
						if traceNormal[2] < 0.9 then
							useDist = useDist - 0.01
						end

						-- Place at contact point
						pTemp.entity.origin = VecAdd(pTemp.entity.prevOrigin, VecScale(betweenDir, useDist))

						-- Damp velocity
						damp = pTemp.bounceFactor
						if hasFlag(pTemp.flags, FTENT_GRAVITY) ~= 0 then
							damp = damp * 0.5
							if traceNormal[2] > 0.9 then -- Hit floor?
								if pTemp.entity.velocity[2] <= 0 and pTemp.entity.velocity[2] >= gravity * 2 then
									damp = 0 -- Stop
									pTemp.flags = clearFlags(pTemp.flags, FTENT_ROTATE, FTENT_GRAVITY, FTENT_COLLIDEWORLD)
									pTemp.entity.angles[1] = 0
								end
							end
						end

						if damp > 0 and betweenLen / frametime > 1 and pTemp.hitSound ~= FSFX_NONE then
							if hasFlag(pTemp.hitSound, FSFX_BRASS) then
								if shellSFX_brass == 0 then
									shellSFX_brass = LoadSound("MOD/snd/base/bounce_brass0.ogg")
								end

								PlaySound(shellSFX_brass, pTemp.entity.origin, damp / 2)
							elseif hasFlag(pTemp.hitSound, FSFX_SHTGN) then
								if shellSFX_buck == 0 then
									shellSFX_buck = LoadSound("MOD/snd/base/bounce_shell0.ogg")
								end

								PlaySound(shellSFX_buck, pTemp.entity.origin, damp / 2)
							end
						end

						-- Reflect velocity
						if damp ~= 0 then
							proj = VecDot(pTemp.entity.velocity, traceNormal)
							--VectorMA(pTemp.entity.velocity, -proj * 2, traceNormal, pTemp.entity.velocity)
							pTemp.entity.velocity = VecAdd(pTemp.entity.velocity, VecScale(traceNormal, -proj * 2))

							-- Reflect rotation (fake)
							pTemp.entity.angles[2] = -pTemp.entity.angles[2]
						end

						if damp ~= 1 then
							pTemp.entity.velocity = VecScale(pTemp.entity.velocity, damp)
							pTemp.entity.angleVel = VecScale(pTemp.entity.angleVel, 0.9)
						end
					end
				end

				if hasFlag(pTemp.flags, FTENT_GRAVITY) then
					pTemp.entity.velocity[2] = pTemp.entity.velocity[2] + gravity

					-- From Post-Human
					if IsPointInWater(pTemp.entity.origin) == true then
						pTemp.entity.velocity[2] = pTemp.entity.velocity[2] - gravity

						pTemp.entity.velocity = VecScale(pTemp.entity.velocity, 0.98)
						pTemp.entity.angles = VecScale(pTemp.entity.angles, 0.98)

						if pTemp.entity.velocity[2] < 0 then
							pTemp.entity.velocity[2] = pTemp.entity.velocity[2] * 0.95
						end

						pTemp.entity.velocity[2] = pTemp.entity.velocity[2] + ((math.sin(3 * GetTime()) * 0.00127) + 0.0127)
					end
				end

				SetBodyTransform(pTemp.entity.model, Transform(pTemp.entity.origin, QuatEuler(pTemp.entity.angles[1], pTemp.entity.angles[2], pTemp.entity.angles[3])))
			end
		end
	end
end