C_Gun = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap

C_Gun.model	    = "smg1.xml" 			 -- Path to the XML model file
C_Gun.casingOrg = Vec(0.02, 0.15, -0.15) -- Where casings are ejected

C_Gun.toolID   = "testgun"  -- Used by the engine. Lowercase and no spaces
C_Gun.toolName = "PWB2 Gun" -- Shown in killfeed
C_Gun.toolSlot = 3
C_Gun.toolPos  = 1			-- placement in the hud column

C_Gun.ammoLoadedMax    = 45					 -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_Gun.ammoAltLoadedMax = 3 				 	 -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_Gun.ammoPickupSize   = C_Gun.ammoLoadedMax -- Defaults to full mag
C_Gun.dmg_world		   = 0.4				 -- Size of hole in meters
C_Gun.dmg_plyr		   = 0.05				 -- 0.0-1.0

C_Gun.flags = addFlags(0, FWPN_SV_CALLONCE_SEC,
						  FWPN_CLICK_SEC) -- Weapon flags
C_Gun.snds  = 0 -- Prechached SFX list, set on INIT

-- override initVars to add new variables
function C_Gun:initVars(owner)
	baseWeap.initVars(self, owner)

	if client and self.isLocal then
		self.timeFiring = 0
		self.lastFireTime = 0
	end
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_Gun:Sounds()
	return {
		{"smg1_fire.ogg",   "sv", "fire"  },
		{"smg1_reload.ogg", "cl", "reload"},
		{"smg1_reload.ogg", "cl", "reloadLoop", true}
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_Gun:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			self.nextAltFire = self.nextFire
			return
		end

		self:MDL_PunchPos(Vec(0, 0, GetRandomFloat(0.133, 0.166)))

		if self.isLocal then
			client.VFX_DynLight(self.owner, 15, 0.08, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			if self.lastFireTime < GetTime() - 0.2 then
				self.timeFiring = 0
			else
				self.timeFiring = self.timeFiring + 0.1
			end

			self.lastFireTime = GetTime()
			client.PUNCH_MachineGunKick(1, self.timeFiring, 2)

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(0.5, 1), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-1, 1)))

			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
		end

		self:muzzleFlash(mt.pos, 0.8)
	else
		PlayFireSound(self.snds["fire"], mt.pos, 300)
	end

	baseWeap.DepleteAmmo(self, 1, 1)

	self:FireBulletsPlayer(1, GetPlayerEyeTransform(self.owner).pos, GLOBAL_5DEGREES, 100)

	self.nextFire = self:GetNextAttackDelay(0.075)
	self.nextAltFire = GetTime() + 0.075
end

function C_Gun:SecondaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoAltTotal <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			self.nextAltFire = self.nextFire
			return
		end

		self:MDL_PunchPos(Vec(0, 0, GetRandomFloat(0.133, 0.166)))

		if self.isLocal then
			-- Manually call this, as having it be automatic causes the final shot to reliably fail
			self:ServerWpnCall("SecondaryAttack", dt)

			client.VFX_DynLight(self.owner, 30, 0.25, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			client.PUNCH_Axis(1, 5)

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(2, 3), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-1, 1)))

			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
		end

		self:muzzleFlash(mt.pos, 0.8)

		self.ammoAltTotal = self.ammoAltTotal - 1
	else
		PlayFireSound(self.snds["fire"], mt.pos, 300)
	end

	self:FireProjectilePlayer(1, mt.pos, GLOBAL_1DEGREE)

	self.nextFire = self:GetNextAttackDelay(0.5)
	self.nextAltFire = self.nextFire
end

function C_Gun:Reload()
	if not self:DefaultReload(1.5) then return end

	if self.isLocal then
		self:PlayFollowingSound(self.snds["reloadLoop"], 1.258)
	else
		PlaySound(self.snds["reload"], GetPlayerPos(self.owner), 1)
	end
end

function C_Gun:WeaponIdle()
	self.playEmptySound = true
end

C_Gun.projectiles = {}

local function ProjectileVars(mdl, pos, dir)
	return {
		totalDist = 0,
		model 	  = mdl,
		curPos 	  = VecCopy(pos),
		oldPos 	  = VecCopy(pos),
		Velocity  = VecScale(dir, 25),
	}
end

function C_Gun:FireProjectilePlayer(shots, pos, spreadRad)
	for i=1, shots do
		local posUse, dir = AIM_GetSpreadedAim(pos, spreadRad, 80, self.owner, i)

		-- Apply aim recoil
		if spreadRad ~= -1 then dir = AIM_RecoilApply(self.owner, posUse, dir) end

		table.insert(
			self.projectiles, 
			ProjectileVars(
				client and Spawn("MOD/models/xml/gren_m203.xml", Transform(pos))[1] --[[body]] or 0,
				posUse,
				dir
			)
		)

		PostEvent("pwb_shot_m203", posUse, dir, self.dmg_world, self.dmg_plyr)
	end

	-- Reset seed AFTER using it on both server and client
	-- Can be unreliable at high latency
	if server then shared.seed = GetRandomInt(0,10000) end
end


function C_Gun:Update(dt)
	-- Only simulate on local device
	if client and not self.isLocal then return
	elseif server and not IsPlayerHost(self.owner) then return
	elseif #self.projectiles == 0 then return end

	for index, data in pairs(self.projectiles) do
		if data.totalDist > 80 then
			Delete(data.model)
			table.remove(self.projectiles, index)
		else
			QueryRequire("large visible physical")
			QueryRejectBody(data.model)
			local hit, dist, shape, hitPlayer, _, normal = QueryShot(data.curPos, data.Velocity, VecLength(data.Velocity) * dt, 0.0, data.owner)

			data.curPos = VecAdd(data.curPos, VecScale(data.Velocity, dt))
			data.Velocity = VecAdd(data.Velocity, VecScale(GetGravity(), dt))

			data.totalDist = data.totalDist + dist

			if client then
				SetBodyTransform(data.model, Transform(data.curPos, QuatLookAt(data.oldPos, data.curPos)))
			end

			data.oldPos = VecCopy(data.curPos)

			-- damage, vfx
			if hit then
				-- get mat type BEFORE we break it
				local pos = VecSub(data.curPos, VecScale(normal, 0.05))
				local matType = GetShapeMaterialAtPos(shape, pos)

				if server then
					ApplyBodyImpulse(GetShapeBody(shape), data.curPos, VecScale(data.curDir, 800 * 4))
					MakeHole(data.curPos, 0.75, 0.4, 0.25)
				end

				if matType ~= "glass" or HasTag(GetShapeBody(shape), "unbreakable") == true then
					if client then
						Delete(data.model)
					else
						Explosion(data.curPos, 1)
					end

					table.remove(self.projectiles, index)
				end
			end
		end
	end
end