CChildGun = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CChildGun:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", "sv", 10}
	}
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
CChildGun.model				= "MOD/models/xml/smg1.xml" -- path to the XML model file
CChildGun.casingOrg			= Vec(0.02, 0.15, -0.15)	-- where casings are ejected

CChildGun.toolID 			= "CChildGun"				-- used by the engine. lowercase and no spaces
CChildGun.toolName 			= "PWB2 Weapon"				-- shown in killfeed
CChildGun.toolSlot			= 3

CChildGun.ammoLoadedMax 	= 45						-- max clip 	 	-- -1 for no clip (pulls from reserve)
CChildGun.ammoAltLoadedMax	= 0 						-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
CChildGun.ammoPickupSize	= CChildGun.ammoLoadedMax	-- defaults to full mag
CChildGun.dmg_world			= 0.4
CChildGun.dmg_plyr			= 0.05						-- 0.0-1.0

CChildGun.flags				= 0							-- weapon flags
CChildGun.snds				= 0							-- temp value, will be set to the sound array on init

-- override initVars to add new variables
function CChildGun:initVars(owner)
	if client then
		self.timeFiring = 0
	end

	baseWeap.initVars(self, owner)
end

--=========================================================================
-- Weapon functions
--=========================================================================

function CChildGunFire(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, 100, GLOBAL_5DEGREES, p)
	server.ShootHook(pos, dir, "bullet", CChildGun.dmg_world, CChildGun.dmg_plyr, 100, p, CChildGun.toolID, CChildGun.toolName)
	
	StopSound(CChildGun.snds[1])
	PlaySound(CChildGun.snds[1], mt.pos, 300)

	baseWeap.DepleteAmmo(CChildGun)
end

function CChildGun:PrimaryAttack(dt)
	if self.ammoLoaded <= 0 then
		self:PlayEmptySound()
		self.nextFire = GetTime() + 0.15
		self.nextAltFire = self.nextFire
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", self.owner)

	if GetTime() - self.lastFireTime < 0.1 then
		self.timeFiring = self.timeFiring + 0.1
	else
		self.timeFiring = 0
	end

	if IsPlayerLocal(self.owner) then
		mt.pos = VecAdd(mt.pos, VecScale(GetPlayerVelocity(), dt))

		PointLight(mt.pos, 1, 0.7, 0.5, 3)

		ServerCall("CChildGunFire", self.owner)

		client.DoMachineGunKick(1, self.timeFiring, 2)

		self.recoilPos = Vec(0, 0, GetRandomFloat(0.05, 0.2))
		self:RecoilAngReset(1)
		self:RecoilAngPunch(Vec(GetRandomFloat(0.5, 1), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-1, 1)))

		-- shell ejection
		ejectBrass(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
	end

	self:muzzleFlash(mt.pos, 2)

	self.ammoLoaded = self.ammoLoaded - 1

	self.nextFire = self:GetNextAttackDelay(0.075)
end

function CChildGunAltFire(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)
	
	for i=1, 4 do
		local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, 100, GLOBAL_5DEGREES, p)
		server.ShootHook(pos, dir, "bullet", CChildGun.dmg_world, CChildGun.dmg_plyr, 100, p, CChildGun.toolID, CChildGun.toolName)
	end
	
	StopSound(CChildGun.snds[1])
	PlaySound(CChildGun.snds[1], mt.pos, 300)

	baseWeap.DepleteAmmo(CChildGun, 4)
end

function CChildGun:SecondaryAttack(dt)
	if self.ammoLoaded <= 3 then
		self:PlayEmptySound()
		self.nextFire = GetTime() + 0.15
		self.nextAltFire = self.nextFire
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", self.owner)

	if IsPlayerLocal(self.owner) then
		mt.pos = VecAdd(mt.pos, VecScale(GetPlayerVelocity(), dt))
		
		PointLight(mt.pos, 1, 0.7, 0.5, 4)

		ServerCall("CChildGunAltFire", self.owner)

		client.SRC_PunchAxis(1, 0.5)

		-- shell ejection
		ejectBrass(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
	end

	self:muzzleFlash(mt.pos, 2)

	self.ammoLoaded = self.ammoLoaded - 4

	self.nextFire = self:GetNextAttackDelay(0.5)
	self.nextAltFire = self.nextFire
end

function CChildGun:Reload()
	self:DefaultReload(self.ammoLoadedMax50, 1.5)
end

function CChildGun:WeaponIdle()
	self.playEmptySound = true
end