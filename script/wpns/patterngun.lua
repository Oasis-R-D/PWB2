CPattGun = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value

CPattGun.model	   = "smg1.xml" 			-- Path to the XML model file
CPattGun.casingOrg = Vec(0.02, 0.15, -0.15) -- Where casings are ejected

CPattGun.toolID   = "pattgun"	  		 -- Used by the engine. Lowercase and no spaces
CPattGun.toolName = "PWB2 CounterStrike" -- Shown in killfeed
CPattGun.toolSlot = 3

CPattGun.ammoLoadedMax 	  = 30					   -- Max clip 	 	-- -1 for no clip (pulls from reserve)
CPattGun.ammoAltLoadedMax = 0 				 	   -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
CPattGun.ammoPickupSize	  = CPattGun.ammoLoadedMax -- Defaults to full mag
CPattGun.dmg_world		  = 0.1				       -- Size of hole in meters
CPattGun.dmg_plyr		  = 0.31				   -- 0.0-1.0

CPattGun.flags = addFlags(0, FWPN_NONE) -- Weapon flags
CPattGun.snds  = 0 -- Prechached SFX list, set on INIT

-- override initVars to add new variables
function CPattGun:initVars(owner)
	if client then
		self.timeFiring = 0
	end

	-- Which shot is this? (used because server doesn't have clip)
	self.shot = 1

	self.lastFireTime = 0

	baseWeap.initVars(self, owner)
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CPattGun:Sounds()
	return {
		{"smg1_fire.ogg", 	"sv", 10},
		{"smg1_reload.ogg", "cl", 10},
		{"smg1_reload.ogg", "cl", 10, true}
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

-- CS:S M4A1
-- Pattern taken from Authentic CS:S weapons mod for GMod
local SprayPattern = {
	Vec(0,0,0),
	Vec(0.65625,-0.375,0),
	Vec(0.90625,0.35625,0),
	Vec(1.96875,-0.2,0),
	Vec(2.375,0.125,0),
	Vec(3.8125,-0.25,0),
	Vec(4.46875,0.35625,0),
	Vec(5.65625,0.53125,0),
	Vec(6.4375,2.21875,0),
	Vec(5.65625,2.875,0),
	Vec(6.3125,3.8125,0),
	Vec(5.78125,4.46875,0),
	Vec(6.1875,5.25,0),
	Vec(5.25,4.0625,0),
	Vec(6.0625,3.28125,0),
	Vec(5.9375,2.21875,0),
	Vec(6.59375,1.3125,0),
	Vec(6.0625,0.5,0),
	Vec(6.71875,-0.125,0),
	Vec(5.78125,-0.375,0),
	Vec(6.4375,-1.4375,0),
	Vec(5.40625,-1.6875,0),
	Vec(6.0625,-2.625,0),
	Vec(5.125,-2.5,0),
	Vec(5.9375,-1.1875,0),
	Vec(5.25,-0.125,0),
	Vec(5.78125,1.03125,0),
	Vec(5.1875,1.6875,0),
	Vec(5.65625,3.03125,0),
	Vec(5.65625,3.03125,0),
	Vec(5.65625,3.03125,0),
}

function CPattGun:GetAccuracy()
	local spread = 0.00060

	if not IsPlayerGrounded(self.owner) then
		spread = spread + 0.34151
	else
		if GetPlayerCrouch(self.owner) > 0.5 then
			spread = spread + 0.00525
		else
			spread = spread + 0.00700
		end
	end

	if VecLength(GetPlayerVelocity(self.owner)) > GetPlayerWalkingSpeed(self.owner) / 1.5 then
		spread = spread + 0.06872
	end

	local retVal = spread < 1.25 and spread or 1.25
    return retVal
end

function CPattGun:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if self.lastFireTime < GetTime() - 0.4 then
		self.shot = 1
	end
	self.lastFireTime = GetTime()

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			return
		end

		self:MDL_PunchPos(Vec(0, 0, GetRandomFloat(0.133, 0.166)))

		if self.isLocal then
			client.VFX_DynLight(self.owner, 12, 0.1, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			self:MDL_PunchAngReset()
			self:MDL_PunchAng(VecScale(SprayPattern[self.shot], 1.33))

			if self.shot ~= 1 then
				client.PUNCH_VecSetAngle(self:GetViewpunch())
			else
				client.PUNCH_Vec(self:GetViewpunch())
			end

			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
		end

		self:muzzleFlash(mt.pos, 0.8)
	else
		PlayFireSound(self.snds[1], mt.pos, 300)
	end

	-- Fire before viewpunch offsets it (only happens in SP though because MP viewpunch is weird)
	self:FireBulletsPlayer(1, GetPlayerEyeTransform(self.owner).pos, self:GetAccuracy(), 100)

	AIM_RecoilSet(self.owner, SprayPattern[self.shot])
	self.shot = self.shot + 1

	baseWeap.DepleteAmmo(self, 1, 1)

	self.nextFire = self:GetNextAttackDelay(0.09009)
end

function CPattGun:ResetShots()
	self.shot = 1
end

function CPattGun:Reload()
	if not self:DefaultReload(3.1) then return end

	self:ResetShots()

	if self.isLocal then
		self:ServerWpnCall("ResetShots")
		self:PlayFollowingSound(self.snds[2], 1.258)
	else
		PlaySound(self.snds[1], GetPlayerPos(self.owner), 1)
	end
end

function CPattGun:GetViewpunch()
	local PUNCH_Recoil = SprayPattern[self.shot]
	PUNCH_Recoil[2] = PUNCH_Recoil[2] * 0.66
	PUNCH_Recoil[1] = Clamp(PUNCH_Recoil[1], 4, 10) / 1.7
	return PUNCH_Recoil
end

function CPattGun:WeaponIdle()
	self.playEmptySound = true
end

function CPattGun:DebugCustom()
	if client and not self.isLocal then return end

	local prefix = "SV "
	if client then prefix = "CL "
	end

	DebugWatch(prefix .. "shot", 			self.shot)
	DebugWatch(prefix .. "GetAccuracy", 	self:GetAccuracy())
end