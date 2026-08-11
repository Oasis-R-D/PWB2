#version 2

-- NOTE: some features have been removed. See entity.CPP in the Half-Life: 1 SDK if you really need them back.

gpTempEnts = {}

function newCLent()
	return {
		--entity_state_t curstate,  -- The state information from the last message received from server

		-- float
		spark_lifetime = 0.0,
		nextThink = 0.0,
		fadeStartIntensity = 0.0,

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
		frameMax = 0,
		fadeSpeed = 0,
		bounceFactor = 0,

		-- short
		clientIndex = -1, -- if attached, this is the index of the client to stick to
						-- if COLLIDEALL, this is the index of the client to ignore
						-- TENTS with FTENT_PLYRATTACHMENT MUST set the clientindex

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
				if hasFlag(pTemp.flags, FTENT_FADEOUT) then
					--[[
					if pTemp.entity.curstate.rendermode == kRenderNormal then
						pTemp.entity.curstate.rendermode = kRenderTransTexture end
					pTemp.entity.curstate.renderamt = pTemp.entity.fadeStartIntensity * (1 + life * pTemp.fadeSpeed)
					if pTemp.entity.curstate.renderamt <= 0 then
						active = false
					end]]
				else
					active = false
				end
			end
			if active == false then -- Kill it
				Delete(pTemp.entity.model)
				table.remove(gpTempEnts, i)
			else
				pTemp.entity.prevOrigin = VecCopy(pTemp.entity.origin)

				if hasFlag(pTemp.flags, FTENT_SPARKSHOWER) then -- NOTE: could be useful?
					-- Adjust speed if it's time
					if client_time > pTemp.entity.nextThink then
						-- Show Sparks
						for j=1,8 do
							ParticleReset()
							ParticleCollide(1)
							ParticleRadius(0.02, 0)
							ParticleGravity(-10)
							ParticleEmissive(5)
							ParticleStretch(5)
							ParticleTile(4)
							ParticleColor(1,0.5,0.4, 1,0.25,0)
							SpawnParticle(pTemp.entity.origin, GetRandomDirection(5.08), GetRandomFloat(0.1, 0.5))
						end

						-- Reduce life
						pTemp.entity.spark_lifetime = pTemp.entity.spark_lifetime - 0.1

						if pTemp.entity.spark_lifetime <= 0.0 then
							pTemp.die = client_time
						else
							-- So it will die no matter what
							pTemp.die = client_time + 0.5

							-- Next think
							pTemp.entity.nextThink = client_time + 0.1
						end
					end
				else -- apply velocity
					for j = 1, 3 do
						pTemp.entity.origin[j] = pTemp.entity.origin[j] + (pTemp.entity.velocity[j] * frametime)
					end
				end

				--[[ -- no sprites in teardown!
				if hasFlag(pTemp.flags, FTENT_SPRANIMATE) then
					pTemp.entity.curstate.frame = pTemp.entity.curstate.frame + (frametime * pTemp.entity.curstate.framerate)
					if pTemp.entity.curstate.frame >= pTemp.frameMax then
						pTemp.entity.curstate.frame = pTemp.entity.curstate.frame - (int)(pTemp.entity.curstate.frame)

						if not hasFlag(pTemp.flags, FTENT_SPRANIMATELOOP) then
							-- this animating sprite isn't set to loop, so destroy it.
							pTemp.die = client_time
							continue
						end
					end
				elseif hasFlag(pTemp.flags, FTENT_SPRCYCLE) then
					pTemp.entity.curstate.frame = pTemp.entity.curstate.frame + (frametime * 10)
					if pTemp.entity.curstate.frame >= pTemp.frameMax then
						pTemp.entity.curstate.frame = pTemp.entity.curstate.frame - (int)(pTemp.entity.curstate.frame)
					end
				end
				]]

				if hasFlag(pTemp.flags, FTENT_ROTATE) then
					for j = 1, 3 do
						pTemp.entity.angles[j] = pTemp.entity.angles[j] + pTemp.entity.angleVel[j] * frametime
					end
				end

				local gravity = -frametime * cl_gravity

				if hasFlags_OR(pTemp.flags, FTENT_COLLIDEALL, FTENT_COLLIDEWORLD) then
					local betweenDir = VecNormalize(pTemp.entity.velocity)
					local betweenLen = VecLength(pTemp.entity.velocity) * frametime

					if hasFlag(pTemp.flags, FTENT_COLLIDEALL) then
						QueryInclude("player")
						QueryInclude("animator")
					end

					QueryRequire("visible physical")
					local hit, dist, traceNormal = QueryRaycast(pTemp.entity.prevOrigin, betweenDir, betweenLen)
					
					if hit == true then
						if hasFlag(pTemp.flags, FTENT_SPARKSHOWER) then
							-- Chop spark speeds a bit more
							--
							pTemp.entity.velocity = VecScale(pTemp.entity.velocity, 0.6)

							if VecLength(pTemp.entity.velocity) < 0.254 then
								pTemp.entity.spark_lifetime = 0.0
							end
						end

						local proj, damp

						-- Place at contact point
						pTemp.entity.origin = VecAdd(pTemp.entity.prevOrigin, VecScale(betweenDir, dist))

						-- Damp velocity
						damp = pTemp.bounceFactor
						if hasFlags_OR(pTemp.flags, FTENT_GRAVITY, FTENT_SLOWGRAVITY) ~= 0 then
							damp = damp * 0.5
							if traceNormal[2] > 0.9 then -- Hit floor?
								if pTemp.entity.velocity[2] <= 0 and pTemp.entity.velocity[2] >= gravity * 2 then
									damp = 0 -- Stop
									pTemp.flags = clearFlags(pTemp.flags, FTENT_ROTATE, FTENT_GRAVITY, FTENT_SLOWGRAVITY, FTENT_COLLIDEWORLD, FTENT_SMOKETRAIL)
									pTemp.entity.angles[1] = 0
									pTemp.entity.angles[3] = 0
								end
							end
						end

						if damp > 0 and betweenLen / frametime > 1 and pTemp.hitSound ~= FSFX_NONE then
							--CL_TempEntPlaySound(pTemp, damp)
							local sound = ""

							if hasFlag(pTemp.hitSound, FSFX_BRASS) then
								sound = "MOD/snd/bounce_brass0.ogg"
							elseif hasFlag(pTemp.hitSound, FSFX_SHTGN) then
								sound = "MOD/snd/bounce_shell0.ogg"
							end

							PlaySound(LoadSound(sound), pTemp.entity.origin, damp / 2)
						end

						if hasFlag(pTemp.flags, FTENT_COLLIDEKILL) then
							-- die on impact
							pTemp.flags = clearFlag(pTemp.flags, FTENT_FADEOUT)
							pTemp.die = client_time
						else
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
								pTemp.entity.angles = VecScale(pTemp.entity.angles, 0.9)
							end
						end
					end
				end

				if hasFlag(pTemp.flags, FTENT_GRAVITY) then
					pTemp.entity.velocity[2] = pTemp.entity.velocity[2] + gravity

					if hasFlag(pTemp.flags, FTENT_BUOYANT) then -- Post-Human addition
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
				end

				SetBodyTransform(pTemp.entity.model, Transform(pTemp.entity.origin, QuatEuler(pTemp.entity.angles[1], pTemp.entity.angles[2], pTemp.entity.angles[3])))
			end
		end
	end
end