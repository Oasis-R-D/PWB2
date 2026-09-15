CTestGun = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value

CTestGun.model	   = "smg1.xml" 			-- Path to the XML model file
CTestGun.casingOrg = Vec(0.02, 0.15, -0.15) -- Where casings are ejected

CTestGun.toolID   = "testgun"  -- Used by the engine. Lowercase and no spaces
CTestGun.toolName = "PWB2 Gun" -- Shown in killfeed
CTestGun.toolSlot = 3

CTestGun.ammoLoadedMax 	  = 45					   -- Max clip 	 	-- -1 for no clip (pulls from reserve)
CTestGun.ammoAltLoadedMax = 3 				 	   -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
CTestGun.ammoPickupSize	  = CTestGun.ammoLoadedMax -- Defaults to full mag
CTestGun.dmg_world		  = 0.4				       -- Size of hole in meters
CTestGun.dmg_plyr		  = 0.05				   -- 0.0-1.0

CTestGun.flags = addFlags(0, FWPN_NONE) -- Weapon flags
CTestGun.snds  = 0 -- Prechached SFX list, set on INIT

-- override initVars to add new variables
function CTestGun:initVars(owner)
	if client then
		self.timeFiring = 0
	end

	baseWeap.initVars(self, owner)
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CTestGun:Sounds()
	return {
		{"smg1_fire.ogg", 	"sv", 10},
		{"smg1_reload.ogg", "cl", 10},
		{"smg1_reload.ogg", "cl", 10, true}
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function CTestGun:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			self.nextAltFire = self.nextFire
			return
		end

		if GetTime() - self.lastFireTime < 0.1 then
			self.timeFiring = self.timeFiring + 0.1
		else
			self.timeFiring = 0
		end

		self:MDL_PunchPos(Vec(0, 0, GetRandomFloat(0.133, 0.166)))

		if self.isLocal then
			client.VFX_DynLight(self.owner, 15, 0.08, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			client.PUNCH_MachineGunKick(1, self.timeFiring, 2)

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(0.5, 1), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-1, 1)))

			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
		end

		self:muzzleFlash(mt.pos, 0.8)
	else
		PlayFireSound(self.snds[1], mt.pos, 300)
	end

	baseWeap.DepleteAmmo(self, 1, 1)

	self:FireBulletsPlayer(1, GetPlayerEyeTransform(self.owner).pos, GLOBAL_5DEGREES, 100)

	self.nextFire = self:GetNextAttackDelay(0.075)
	self.nextAltFire = GetTime() + 0.075
end

function CTestGun:SV_DontFireAltCond(dt)
	return self.ammoAltTotal <= 0
end

function CTestGun:SecondaryAttack(dt)
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
		PlayFireSound(self.snds[1], mt.pos, 300)
	end

	self:FireProjectilePlayer(1, mt.pos, GLOBAL_1DEGREE)

	-- Use get time because GetNextAttackDelay breaks here
	self.nextFire = GetTime() + 0.5
	self.nextAltFire = self.nextFire
end

function CTestGun:Reload()
	if not self:DefaultReload(1.5) then return end

	if self.isLocal then
		self:PlayFollowingSound(self.snds[2], 1.258)
	else
		PlaySound(self.snds[1], GetPlayerPos(self.owner), 1)
	end
end

function CTestGun:WeaponIdle()
	self.playEmptySound = true
end

CTestGun.projectiles = {}

function ProjectileVars(mdl, pos, dir)
	return {
		totalDist = 0,
		model = mdl,
		curPos = VecCopy(pos),
		oldPos = VecCopy(pos),
		Velocity = VecScale(dir, 25),
	}
end

function CTestGun:FireProjectilePlayer(shots, pos, spreadRad)
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

function CTestGun:Update(dt)
	if #self.projectiles == 0 then return end -- no crossbow bolts

	for index, data in pairs(self.projectiles) do
		if data.totalDist > 80 then -- make 500 if using HL2 speed
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