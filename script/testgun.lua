CTestGun = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CTestGun:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", "sv", 10},
		{"MOD/snd/smg1_reload.ogg", "cl", 10},
		{"MOD/snd/smg1_reload.ogg", "cl", 10, true}
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
-- These don't need redefined in a weapon if a var is just the default value
CTestGun.model				= "MOD/models/xml/grease.xml"-- path to the XML model file
CTestGun.casingOrg			= Vec(0.01, 0.12, -0.15)	 -- where casings are ejected

CTestGun.toolID 			= "testgun"					 -- used by the engine. lowercase and no spaces
CTestGun.toolName 			= "PWB2 Test Gun"			 -- shown in killfeed
CTestGun.toolSlot			= 3

CTestGun.ammoLoadedMax 		= 30						 -- max clip 	 	-- -1 for no clip (pulls from reserve)
CTestGun.ammoAltLoadedMax	= 0 						 -- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
CTestGun.ammoAltItemID		= 0 						 -- wpnID of item to drain ammo for when altfiring
CTestGun.ammoPickupSize		= CTestGun.ammoLoadedMax	 -- defaults to full mag
CTestGun.dmg_world			= 0.5
CTestGun.dmg_plyr			= 0.16						 -- 0.0-1.0

CTestGun.flags				= 0							 -- weapon flags
CTestGun.snds				= 0							 -- temp value, will be set to the sound array on init
--=========================================================================
-- Weapon functions
--=========================================================================

function CTestGun:PrimaryAttack(dt)
	

	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			return
		end

		local punchVec = Vec(GetRandomFloat(-0.05, 0.05), GetRandomFloat(0.0, 0.025), GetRandomFloat(0.05, 0.1))
		self:RecoilPosPunch(punchVec)

		if self.isLocal then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)

			self:RecoilAngReset(-4)
			self:RecoilAngPunch(Vec(GetRandomFloat(1, 3), GetRandomFloat(-2, 2), GetRandomFloat(-1, 1)))
			
			client.SRC_PunchReset()
			for i=1, 3 do
				client.SRC_PunchAxis(i, punchVec[4-i] * 10)
			end

			-- shell ejection
			ejectBrass(self.owner, self.casingOrg, Vec(1, -1, 0), "MOD/models/xml/shell/casing_45acp.xml", FSFX_BRASS)
		end

		self:muzzleFlash(mt.pos, 1)
		
		self.ammoLoaded = self.ammoLoaded - 1
	else
		local pos, dir = getAimVector(GetPlayerEyeTransform(self.owner).pos, 100, GLOBAL_3DEGREES, self.owner)
	
		server.ShootHook(pos, dir, "bullet", self.dmg_world, self.dmg_plyr, 100, self.owner, self.toolID, self.toolName)

		PlayFireSound(self.snds[1], mt.pos, 300)

		baseWeap.DepleteAmmo(self)
	end

	self.nextFire = self:GetNextAttackDelay(0.133)
end

function CTestGun:Reload()
	if not self:DefaultReload(self.ammoLoadedMax50, 1.5) then return end
	
	if self.isLocal then
		self:PlayFollowingSound(self.snds[2], 1.258)
	else
		PlaySound(self.snds[1], GetPlayerPos(self.owner), 1)
	end
end

function CTestGun:WeaponIdle()
	self.playEmptySound = true
end