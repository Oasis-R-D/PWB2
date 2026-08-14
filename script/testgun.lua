CTestGun = {} -- goes in GLOBAL_WEAPONS

-- Per weapon constants
local CASING_ORG = Vec(0.02, 0.15, -0.15)

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CTestGun:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", "sv", 10}
	}
end

function CTestGun:muzzleFlash(pos, size, color)
	color = color or Vec(1, 1, 1)
	local t = Transform(pos)
	t.rot = QuatRotateQuat(GetCameraTransform().rot, QuatEuler(0,0,GetRandomFloat(-15, 15)))

	-- Create the flashSPR variable to hold the sprite
	if not CTestGun.flashSPR then CTestGun.flashSPR = LoadSprite("gfx/flare_0.png") end

	local spriteSize = size * 0.4
	DrawSprite(CTestGun.flashSPR, t, spriteSize, spriteSize, color[1], color[2], color[3], 1.0, true, true, true)
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
CTestGun.model				= "MOD/models/xml/smg1.xml" -- path to the XML model file
CTestGun.toolID 			= "testgun"					-- used by the engine. lowercase and no spaces
CTestGun.toolName 			= "PWB2 Test Gun"			-- shown in killfeed
CTestGun.toolSlot			= 3

CTestGun.ammoLoadedMax 		= 30						-- max clip 	 	-- -1 for no clip (pulls from reserve)
CTestGun.ammoAltLoadedMax	= 0 						-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
CTestGun.ammoAltItemID		= 0 						-- wpnID of item to drain ammo for when altfiring
CTestGun.ammoPickupSize		= CTestGun.ammoLoadedMax	-- defaults to full mag
CTestGun.dmg_world			= 0.6
CTestGun.dmg_plyr			= 0.1						-- 0.0-1.0

CTestGun.flags				= 0							-- weapon flags
CTestGun.snds				= 0							-- temp value, will be set to the sound array on init

-- override initVars to add new variables
function CTestGun:initVars(owner)
	if client then
		self.timeFiring = 0
	end

	baseWeap.initVars(self, owner)
end

--=========================================================================
-- Weapon functions
--=========================================================================

function CTestGunFire(p)
	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, 100, GLOBAL_5DEGREES, p)
	
	server.ShootHook(pos, dir, "bullet", CTestGun.dmg_world, CTestGun.dmg_plyr, 100, p, CTestGun.toolID, CTestGun.toolName)

	StopSound(CTestGun.snds[1])
	PlaySound(CTestGun.snds[1], GetToolLocationWorldTransform("muzzle", p).pos, 300)

	baseWeap.DepleteAmmo(CTestGun)
end

function CTestGun:PrimaryAttack(dt)
	if self.ammoLoaded <= 0 then
		self:PlayEmptySound()
		self.nextFire = GetTime() + 0.15
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", self.owner)

	if GetTime() - self.lastFireTime < 0.125 then
		self.timeFiring = self.timeFiring + 0.125
	else
		self.timeFiring = 0
	end

	if IsPlayerLocal(self.owner) then
		mt.pos = VecAdd(mt.pos, VecScale(GetPlayerVelocity(), dt))

		PointLight(mt.pos, 1, 0.7, 0.5, 3)

		ServerCall("CTestGunFire", self.owner)

		client.DoMachineGunKick(1.66, self.timeFiring, 1)
		
		self.recoilPos = Vec(GetRandomFloat(0, 0.05), GetRandomFloat(0.0, 0.1), GetRandomFloat(0.05, 0.125))
		self:RecoilAngReset(1)
		self:RecoilAngPunch(Vec(GetRandomFloat(0.5, 1), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-1, 1)))

		-- shell ejection
		ejectBrass(self.owner, CASING_ORG, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_556.xml", FSFX_BRASS)
	end

	self:muzzleFlash(mt.pos, 1)

	self.ammoLoaded = self.ammoLoaded - 1

	self.nextFire = self:GetNextAttackDelay(0.1)
end

function CTestGun:Reload()
	self:DefaultReload(self.ammoLoadedMax50, 1.5)
end

function CTestGun:WeaponIdle()
	self.playEmptySound = true
end