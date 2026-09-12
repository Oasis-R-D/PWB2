-- NOTE: some features have been removed. See entity.CPP in the Half-Life: 1 SDK if you really need them back.

local pTempEnts = {}

--===========================================
--	Definitions
--============================================

local function newTempEnt()
	return {
		active = true, -- hasn't hit the ground?

		hitSound = 0,

		-- floats
		die = 0,
		bounceFactor = 0,


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

--===========================================
--	Creation
--============================================

local function CL_TempEntAlloc(org, model)

	local tempent = newTempEnt()

	tempent.die = 0
	tempent.model = Spawn(model, Transform(org))[1]
	tempent.hitSound = 0
	tempent.bounceFactor = 1.0
	tempent.origin = org

	local index = findArrayOpening(pTempEnts)
	pTempEnts[index] = tempent

	return pTempEnts[index]
end

local function R_TempModel(pos, velocity, angles, life, model, soundtype)

	local tempent = CL_TempEntAlloc(pos, model)

	tempent.angles = angles
	tempent.hitSound = soundtype
	tempent.frameMax = 0 -- tempent.frameMax = framecount

	tempent.velocity = velocity
	tempent.angleVel = GetRandomDirection(256)
	tempent.die = life + GetTime()
end

---@param p number Who's shell is being ejected
---@param org TVec Where is the shell being ejected
---@param dir TVec Where the shell will be ejected towards
---@param model string Path to shell's XML ("MOD/models/xml/shell/x.xml")
---@param casingtype number Which shell impact sounds to play (values in bit_ops.lua)
function ENT_EjectShell(p, org, dir, model, casingtype)
	if settings.shelleject == false then return end

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

    for i, pTemp in pairs(pTempEnts) do
		if (pTemp.die - client_time) < 0 then
			Delete(pTemp.model)
			table.remove(pTempEnts, i)
		else
			pTemp.prevOrigin = VecCopy(pTemp.origin)

			-- apply velocity
			for j = 1, 3 do
				pTemp.origin[j] = pTemp.origin[j] + (pTemp.velocity[j] * frametime)
			end

			if pTemp.active then
				-- Ang vel ----------------------------------------------------
				for j = 1, 3 do
					pTemp.angles[j] = pTemp.angles[j] + pTemp.angleVel[j] * frametime
				end

				-- Collision ----------------------------------------------------
				local betweenDir = VecNormalize(pTemp.velocity)
				local betweenLen = VecLength(pTemp.velocity) * frametime
				local gravity = -frametime * cl_gravity

				QueryRequire("visible physical")
				local hit, dist, traceNormal = QueryRaycast(pTemp.prevOrigin, betweenDir, betweenLen)

				if hit == true then
					local proj, damp

					-- Pull away from walls
					local useDist = dist
					if traceNormal[2] < 0.9 then
						useDist = useDist - 0.01
					end

					-- Place at contact point
					pTemp.origin = VecAdd(pTemp.prevOrigin, VecScale(betweenDir, useDist))

					-- Damp velocity
					damp = pTemp.bounceFactor
					damp = damp * 0.5
					if traceNormal[2] > 0.9 then -- Hit floor?
						if pTemp.velocity[2] <= 0 and pTemp.velocity[2] >= gravity * 2 then
							damp = 0 -- Stop
							pTemp.active = false
							pTemp.angles[1] = 0
						end
					end

					if damp > 0 and betweenLen / frametime > 1 and pTemp.hitSound ~= FSFX_NONE then
						if hasFlag(pTemp.hitSound, FSFX_BRASS) then
							if shellSFX_brass == 0 then
								shellSFX_brass = LoadSound("MOD/snd/base/bounce_brass0.ogg")
							end

							PlaySound(shellSFX_brass, pTemp.origin, damp / 2)
						elseif hasFlag(pTemp.hitSound, FSFX_SHTGN) then
							if shellSFX_buck == 0 then
								shellSFX_buck = LoadSound("MOD/snd/base/bounce_shell0.ogg")
							end

							PlaySound(shellSFX_buck, pTemp.origin, damp / 2)
						end
					end

					-- Reflect velocity
					if damp ~= 0 then
						proj = VecDot(pTemp.velocity, traceNormal)
						--VectorMA(pTemp.velocity, -proj * 2, traceNormal, pTemp.velocity)
						pTemp.velocity = VecAdd(pTemp.velocity, VecScale(traceNormal, -proj * 2))

						-- Reflect rotation (fake)
						pTemp.angles[2] = -pTemp.angles[2]
					end

					if damp ~= 1 then
						pTemp.velocity = VecScale(pTemp.velocity, damp)
						pTemp.angleVel = VecScale(pTemp.angleVel, 0.9)
					end
				end

				-- Gravity ----------------------------------------------------
				if pTemp.active then
					pTemp.velocity[2] = pTemp.velocity[2] + gravity

					-- From Post-Human
					if IsPointInWater(pTemp.origin) == true then
						pTemp.velocity[2] = pTemp.velocity[2] - gravity

						pTemp.velocity = VecScale(pTemp.velocity, 0.98)
						pTemp.angles = VecScale(pTemp.angles, 0.98)

						if pTemp.velocity[2] < 0 then
							pTemp.velocity[2] = pTemp.velocity[2] * 0.95
						end

						pTemp.velocity[2] = pTemp.velocity[2] + ((math.sin(3 * GetTime()) * 0.00127) + 0.0127)
					end
				end
			end

			SetBodyTransform(pTemp.model, Transform(pTemp.origin, QuatEuler(pTemp.angles[1], pTemp.angles[2], pTemp.angles[3])))
		end
	end
end