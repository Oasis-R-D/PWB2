C_DB = {} -- goes in GLOBAL_WEAPONS

-- ALL PARTICLES STOLEN FROM: https://steamcommunity.com/sharedfiles/filedetails/?id=3192024198

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap
C_DB.model	   = "shotgun.xml" 		    -- Path to the XML model file
C_DB.casingOrg = Vec(0.02, 0.08, 0.022) -- Where casings are ejected

C_DB.toolID   = "pbw_dbsg"  	   	   -- Used by the engine. Lowercase and no spaces
C_DB.toolName = "PWB2 Dragon's Breath" -- Shown in killfeed
C_DB.toolSlot = 4
C_DB.toolPos  = 1			   -- placement in the hud column

C_DB.ammoLoadedMax 	  = 4				  -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_DB.ammoAltLoadedMax = 0 				  -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_DB.ammoPickupSize	  = C_DB.ammoLoadedMax -- Defaults to full mag
C_DB.dmg_world		  = 0.35				  -- Size of hole in meters
C_DB.dmg_plyr		  = 0.1				  -- 0.0-1.0

C_DB.flags = addFlags(0, FWPN_SV_CALLONCE_PRIM,
						 FWPN_CLICK_PRIM) -- Weapon flags
C_DB.snds  = 0 -- Prechached SFX list, set on INIT

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_DB:Sounds()
	return {
		{"sbarrel.ogg", 	  "sv", "fire"},
		{"dbarrel.ogg", 	  "sv", "fireAlt"},
		{"explosion/s0.ogg",  "sv", "impact", false, true},

		{"sgcock.ogg", 		  "cl", "pump"},
		{"sgshellin0.ogg",    "cl", "load"},
		{"sgreloadstart.ogg", "cl", "reload"},
		{"tools/leafblower-loop.ogg", "cl", "fly", true, true}
	}
end

function C_DB:muzzleFlash(pos, size, color)
	color = color or Vec(1, 1, 1)

	if self.isLocal then
		pos = VecAdd(pos, VecScale(GetPlayerVelocity(), GetTimeStep()))
	end

	local t = Transform(pos)
	t.rot = QuatRotateQuat(GetCameraTransform().rot, QuatEuler(0,0,GetRandomFloat(-180, 180)))

	-- Create the flashSPR variable to hold the sprite
	if not C_DB.flashSPR then C_DB.flashSPR = LoadSprite("gfx/flare_0.png") end

	DrawSprite(C_DB.flashSPR, t, size, size, color[1], color[2], color[3], 1.0, true, true, true)
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_DB:PrimaryAttack(dt)
	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self:Reload()
			return
		end

		if self.pumpTime == -1 then
			self.specialReload = 0
			self.timeWeaponIdle = GetTime() + 1.5

			self.nextFire = self:GetNextAttackDelay(0.25)
			self.pumpTime = 0

			-- reload debounce has timed out
			if self.isLocal then
				self:KF_SetAnim(C_DB.ANIM_PUMP)
			end

			PlaySound(self.snds["pump"], self.muzzle)
			return
		end

		self:MDL_PunchPos(Vec(0, 0.2, GetRandomFloat(0.2, 0.3)))

		self:FiringVFX()

		if self.isLocal then
			self:ServerWpnCall("PrimaryAttack", dt)

			client.VFX_DynLight(self.owner, 60, 0.5, Vec(0.8, 0.3, 0.1), Vec(), "muzzle")

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(4, 5), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-5, -1)))

			client.PUNCH_Axis(1, 5)
			client.PUNCH_Axis(2, GetRandomFloat(-0.5, 0.5))

			-- make VFX more intense
			--self:FireProjectilePlayer(4, self.eyePos, GLOBAL_5DEGREES, true)
		end

		self:muzzleFlash(self.muzzle, 5)

		self.specialReload = 0

		if self.ammoLoaded == 0 then
			self.timeWeaponIdle = 1
		end
	else
		PlayFireSound(self.snds["fire"], self.muzzle, 300)
	end

	baseWeap.DepleteAmmo(self, 1, 1)

	self:FireProjectilePlayer(8, self.eyePos, GLOBAL_10DEGREES)

	self.nextFire = self:GetNextAttackDelay(0.5)
	self.nextAltFire = self.nextFire
end

function C_DB:Reload()
	if self.ammoTotal <= 0 or self.ammoLoaded == self.ammoLoadedMax then
		return end

	local curTime = GetTime()

	-- check to see if we're ready to reload
	if self.specialReload == 0 then
		-- don't reload until recoil is done
		if self.nextFire > curTime then
			return end

		if self.isLocal then 
			self:MDL_PunchAng(Vec(0, 2, -10))
			PlaySound(self.snds["reload"], self.muzzle)
		end

		if self.ammoLoaded == 0 then self.pumpTime = -1 end

		-- hold gun straight
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0

		self.specialReload = 1

		self.timeWeaponIdle = curTime + 0.6

		self.nextFire = self:GetNextAttackDelay(1.0)
		self.nextAltFire = curTime + 1.0
	elseif self.specialReload == 1 then
		-- waiting for gun to move to side
		if self.timeWeaponIdle > curTime then
			return end

		self.ammoLoaded = self.ammoLoaded + 1

		self.specialReload = 2

		PlayFireSound(self.snds["load"], self.muzzle)

		self:MDL_PunchPos(Vec(0, 0.1, 0.1))
		if self.isLocal then
			self:MDL_PunchAng(Vec(GetRandomFloat(3, 4), GetRandomFloat(0, 1), GetRandomFloat(-6, -2)))
			client.PUNCH_Axis(3, -0.33)
			client.PUNCH_Axis(1, -0.33)
		end

		self.timeWeaponIdle = curTime + 0.5
	else
		self.specialReload = 1

		-- hold gun straight
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0
	end
end

function C_DB:WeaponIdle()
	if server then return end

	self.playEmptySound = true

	local curTime = GetTime()

	if self.timeWeaponIdle > curTime then
		return
	end

	if self.ammoLoaded == 0 and self.specialReload == 0 and self.ammoLoaded ~= self.ammoTotal then
		self:Reload()
	elseif self.specialReload ~= 0 then
		if self.ammoLoaded ~= self.ammoLoadedMax and self.ammoLoaded ~= self.ammoTotal then
			self:Reload()
			return
		end

		self.specialReload = 0
		self.timeWeaponIdle = curTime + 1.5

		if self.pumpTime == -1 then
			self.nextFire = self:GetNextAttackDelay(0.25)
			self.pumpTime = 0

			-- reload debounce has timed out
			if self.isLocal then
				self:KF_SetAnim(C_DB.ANIM_PUMP)
			end

			PlaySound(self.snds["pump"], self.muzzle)
		end
	end
end

C_DB.projectiles = {}

local function ProjectileVars(pos, dir, i)
	SetRandomSeed(shared.seed + i)
	return {
		totalDist = 0,
		maxDist   = GetRandomFloat(18, 30),
		curPos 	  = VecCopy(pos),
		oldPos 	  = VecCopy(pos),
		velocity  = VecScale(dir, 37),
		pow		  = 1
	}
end

function C_DB:FireProjectilePlayer(shots, pos, spreadRad, fake)
	for i=1, shots do
		local posUse, dir = AIM_GetSpreadedAim(pos, spreadRad, 80, self.owner, fake and i+GetTime() or i)

		-- Apply aim recoil
		if spreadRad ~= -1 then dir = AIM_RecoilApply(self.owner, posUse, dir) end

		table.insert(
			self.projectiles, 
			ProjectileVars(
				posUse,
				dir,
				fake and i+GetTime() or i
			)
		)

		PostEvent("pwb_shot_m203", posUse, dir, self.dmg_world, self.dmg_plyr)
	end

	-- Reset seed AFTER using it on both server and client
	-- Can be unreliable at high latency
	if server then shared.seed = GetRandomInt(0,10000) end
end

local function ProjectileVFX(data)
	local rnd = GetRandomFloat
	local rndVec = GetRandomDirection

	ParticleReset()
	ParticleColor(1, 0.6, 0.4, 1, 0.1, 0.1)
	ParticleAlpha(1, 0.0)
	ParticleRadius(0.07,0.0)
	ParticleGravity(-1, rnd(-2, -5))
	ParticleDrag(0.7)
	ParticleEmissive(rnd(2, 6), 0, "easeout")
	ParticleTile(5)
	ParticleStretch(3)
	ParticleCollide(1)
	for i=1,3 do
		SpawnParticle(data.curPos, VecAdd(VecScale(0.001, 0.001), rndVec(3)), rnd(0.1, 0.7))
	end

	ParticleReset()
	ParticleColor(1, 0.6, 0.4, 1, 0.1, 0.1)
	ParticleAlpha(1, 0.0)
	ParticleRadius(rnd(0.01,0.04),0.0)
	ParticleGravity(-1, rnd(-2, -5))
	ParticleDrag(0.4)
	ParticleEmissive(rnd(3, 7), 0, "easeout")
	ParticleTile(4)
	ParticleStretch(0.2)
	SpawnParticle(data.curPos, VecAdd(VecScale(0.001, 0.001), rndVec(6)), rnd(0.2, 1.4))
end

local function ProjectileHitVFX(data)
	local rnd = GetRandomFloat
	local rndVec = GetRandomDirection

	ParticleReset()
	ParticleColor(1, 0.6, 0.4, 1, 0.1, 0.1)
	ParticleAlpha(1, 0.0)
	ParticleRadius(0.2,0.0)
	ParticleGravity(-1, rnd(-2, -5))
	ParticleDrag(0.7)
	ParticleEmissive(rnd(3, 5), 0, "easeout")
	ParticleTile(5)
	ParticleStretch(4)
	ParticleCollide(1)
	for i=1,4 do
		SpawnParticle(data.curPos, VecAdd(VecScale(0.001, 0.001), rndVec(3)), rnd(0.1, 0.7))
	end


	ParticleReset()
	ParticleColor(1, 0.6, 0.4, 1, 0.1, 0.1)
	ParticleAlpha(1, 0.0)
	ParticleRadius(rnd(0.01,0.04),0.0)
	ParticleGravity(-1, rnd(-2, -5))
	ParticleDrag(0.4)
	ParticleEmissive(rnd(3, 7), 0, "easeout")
	ParticleTile(4)
	ParticleStretch(0.2)
	SpawnParticle(data.curPos, VecAdd(VecScale(0.001, 0.001), rndVec(8)), rnd(0.5, 2))
end

client.oddFrame = true
function C_DB:Update(dt)
	-- Only simulate on local device
	if client then
		client.oddFrame = not client.oddFrame
	 	if not self.isLocal or client.oddFrame then return end
		dt = dt * 2
	elseif server and not IsPlayerHost(self.owner) then return end

	for index, data in pairs(self.projectiles) do
		if data.totalDist > 80 then
			Delete(data.model)
			table.remove(self.projectiles, index)
		else
			QueryRequire("large visible physical")
			QueryRejectBody(data.model)
			local hit, dist, shape, hitPlayer, _, normal = QueryShot(data.curPos, data.velocity, VecLength(data.velocity) * dt, 0.0, data.owner)

			data.curPos = VecAdd(data.curPos, VecScale(VecNormalize(data.velocity), dist))
			data.velocity = VecAdd(data.velocity, VecScale(GetGravity(), dt))

			data.totalDist = data.totalDist + dist

			data.oldPos = VecCopy(data.curPos)

			if client then
				PointLight(data.curPos, 0.8, 0.3, 0.1, 0.5)
				ProjectileVFX(data)


				-- jitters due to only being called every other frame (sounds cool though)
				PlayLoop(self.snds["fly"], data.curPos)
			end

			-- damage, vfx
			if hit or data.totalDist > data.maxDist then
				if hitPlayer == 0 then
					if server then
						ApplyBodyImpulse(GetShapeBody(shape), data.curPos, VecScale(data.curDir, 800 * 4))
						MakeHole(data.curPos, 0.35*data.pow, 0.2*data.pow, 0.1*data.pow)
						SpawnFire(VecAdd(data.curPos, VecScale(data.dir, 0.25)))
						data.pow = data.pow * 0.33
					else
						ProjectileHitVFX(data)
					end

					if dist < 0.00001 or data.totalDist > 20 then
						if server then
							for i=1, 4 do
								SpawnFire(VecAdd(data.curPos, GetRandomDirection(0.25)))
							end

							PlayFireSound(self.snds["impact"], data.curPos)
						end

						table.remove(self.projectiles, index)
					end
				else
					if server then
						ApplyPlayerDamage(hitPlayer, self.dmg_plyr, self.toolName, self.owner)
						PlayFireSound(self.snds["impact"], data.curPos)
					else
						ProjectileHitVFX(data)
					end

					table.remove(self.projectiles, index)
				end
			end
		end
	end
end

function C_DB:FiringVFX()
	local rnd = GetRandomFloat
	local rndVec = GetRandomDirection

	ParticleReset()
	ParticleColor(1, 0.6, 0.4, 1, 0.1, 0.1)
	ParticleAlpha(1, 0.0)
	ParticleRadius(rnd(0.03,0.06),0.0)
	ParticleGravity(-1, rnd(-2, -5))
	ParticleDrag(0.5)
	ParticleEmissive(rnd(4, 6), 0, "easeout")
	ParticleTile(4)
	ParticleStretch(0.2)
	for i=1,20 do
		SpawnParticle(self.muzzle, VecAdd(VecScale(0.001, 0.001), rndVec(7)), rnd(0.2, 0.7))
	end

	ParticleReset()
	ParticleColor(1, 0.6, 0.4, 1, 0.1, 0.1)
	ParticleAlpha(1, 0.0)
	ParticleRadius(rnd(0.01,0.04),0.0)
	ParticleGravity(-1, rnd(-2, -5))
	ParticleDrag(0.7)
	ParticleEmissive(rnd(4, 6), 0, "easeout")
	ParticleTile(4)
	ParticleStretch(0.2)
	for i=1,10 do
		SpawnParticle(self.muzzle, VecAdd(VecScale(0.001, 0.001), rndVec(8)), rnd(0.1, 0.6))
	end

	ParticleReset()
	ParticleTile(5)
	ParticleRadius(0.01, 0.7, "smooth")
	ParticleColor(1, 0.6, 0.4, 1, 0.4, 0.2)
	ParticleGravity(0)
	ParticleAlpha(1, 0.0)
	ParticleStretch(0.0)
	ParticleCollide(0, 0.0)
	ParticleRotation(-20, 1, "easeout")
	ParticleEmissive(rnd(8, 10), 0, "easeout")
	ParticleDrag(0)
	for i=1,4 do
		SpawnParticle(self.muzzle, Vec(rnd(-2.0,2.0), rnd(-2.0,2.0), rnd(-2.0,2.0)), rnd(0.15,0.45))
	end

	ParticleReset()
	ParticleTile(5)
	ParticleRadius(0.01, 0.7, "smooth")
	ParticleColor(1, 0.8, 0.6, 1, 0.7, 0.4)
	ParticleGravity(0)
	ParticleAlpha(1, 0.0)
	ParticleStretch(0.0)
	ParticleCollide(0, 0.0)
	ParticleRotation(20, -1, "easeout")
	ParticleEmissive(rnd(10, 12), 0, "easeout")
	ParticleDrag(0)
	for i=1,4 do
		SpawnParticle(self.muzzle, Vec(rnd(-2.0,2.0), rnd(-2.0,2.0), rnd(-2.0,2.0)), rnd(0.15,0.45))
	end

	ParticleReset()
	ParticleTile(5)
	ParticleRadius(0.01, 0.2, "smooth")
	ParticleColor(1, 0.6, 0.4, 1, 0.4, 0.2)
	ParticleGravity(0)
	ParticleAlpha(1, 0.1)
	ParticleStretch(0.0)
	ParticleCollide(0, 0.0)
	ParticleRotation(20, 1, "easeout")
	ParticleEmissive(rnd(8, 10), 0, "easeout")
	ParticleDrag(0.9)	
	for i=1,2 do
		SpawnParticle(self.muzzle, Vec(rnd(-1.0,1.0), rnd(-1.0,1.0), rnd(-1.0,1.0)), rnd(0.2,0.3))
	end

	ParticleReset()
	ParticleTile(5)
	ParticleRadius(0.01, 0.2, "smooth")
	ParticleColor(1, 0.8, 0.6, 1, 0.7, 0.4)
	ParticleGravity(0)
	ParticleAlpha(1, 0.1)
	ParticleStretch(0.0)
	ParticleCollide(0, 0.0)
	ParticleRotation(-20, -1, "easeout")
	ParticleEmissive(rnd(10, 12), 0, "easeout")
	ParticleDrag(0.9)
	for i=1,2 do
		SpawnParticle(self.muzzle, Vec(rnd(-1.0,1.0), rnd(-1.0,1.0), rnd(-1.0,1.0)), rnd(0.2,0.3))
	end
end