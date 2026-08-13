#version 2

-- NOTE: some features have been removed. See entity.CPP in the Half-Life: 1 SDK if you really need them back.

gpTempEnts = {}

function newCLent()
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

function newTempEnt()
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

function HUD_TempEntUpdate_(
    frametime,	-- Simulation time
	client_time, -- Absolute time on client
	cl_gravity)	-- True gravity on client

    local gpTempEnts_Length = #gpTempEnts

	-- Nothing to simulate
	if gpTempEnts_Length == 0 then
		return end

    for i = 1, gpTempEnts_Length do
		local pTemp = gpTempEnts[i] -- this errors sometimes, seemingly when one is deleted?
		if pTemp ~= nil then
			local active = true

			local life = pTemp.die - client_time
			if life < 0 then
				active = false
			end
			if active == false then -- Kill it
				Delete(pTemp.entity.model)
				table.remove(gpTempEnts, i)
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

						-- Place at contact point
						pTemp.entity.origin = VecAdd(pTemp.entity.prevOrigin, VecScale(betweenDir, traceNormal[2] > 0.9 and dist or dist-0.01))

						-- Damp velocity
						damp = pTemp.bounceFactor
						if hasFlag(pTemp.flags, FTENT_GRAVITY) ~= 0 then
							damp = damp * 0.5
							if traceNormal[2] > 0.9 then -- Hit floor?
								if pTemp.entity.velocity[2] <= 0 and pTemp.entity.velocity[2] >= gravity * 2 then
									damp = 0 -- Stop
									pTemp.flags = clearFlags(pTemp.flags, FTENT_ROTATE, FTENT_GRAVITY, FTENT_COLLIDEWORLD, FTENT_SMOKETRAIL)
									pTemp.entity.angles[1] = 0
								end
							end
						end

						if damp > 0 and betweenLen / frametime > 1 and pTemp.hitSound ~= FSFX_NONE then
							local sound = ""

							-- TO-DO: precache sounds
							if hasFlag(pTemp.hitSound, FSFX_BRASS) then
								sound = "MOD/snd/bounce_brass0.ogg"
							elseif hasFlag(pTemp.hitSound, FSFX_SHTGN) then
								sound = "MOD/snd/bounce_shell0.ogg"
							end

							PlaySound(LoadSound(sound), pTemp.entity.origin, damp / 2)
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