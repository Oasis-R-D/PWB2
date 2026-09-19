C_Melee = {} -- goes in GLOBAL_WEAPONS
---------------------------------------------------------------------------
-- MELEE WEAPON DOCS:
-- Melee weapons in PWB2 use a system similar to Left4Dead2's for it's melee
-- weapons. A melee weapon can either be sharp or blunt. Blunt weapons
-- can only hit a surface again if it hits another first (x->y->x but not x->x).
-- Sharp weapons continuously hit surfaces with a decaying damage amount.
-- Sharp weapons should have less force and player damage as it can hit the same
-- object up to ~20 times in one swing

-- third person animations must closely match first person animations
-- in order for clients to get the correct result.

-- weapon swings start from the secaction pos and end at the action pos.

-- edge hit detection is done from the vox model's origin.
---------------------------------------------------------------------------

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap

C_Melee.model = "crowbar.xml" -- Path to the XML model file

C_Melee.edgeDir		  = Vec(0,1,-1) -- What direction hits will be considered
C_Melee.edgeType	  = 1			-- 0: blunt 1: slice (slice hits things multiple times)
C_Melee.hitDist		  = 1.33		-- How far from the edge to check hits
C_Melee.knockbackMult = 500		   	-- Object impulse multiplier, rec: 1000 for blunt, 50 for slice

C_Melee.toolID 	 = "testmelee"  -- Used by the engine. Lowercase and no spaces
C_Melee.toolName = "PWB2 Melee" -- Shown in killfeed
C_Melee.toolSlot = 1
C_Melee.toolPos	 = 1			-- placement in the hud column

C_Melee.ammoLoadedMax  = -1   -- Max clip 	 -- -1 for no clip (pulls from reserve)
C_Melee.ammoPickupSize = 9999 -- Defaults to full mag
C_Melee.dmg_world	   = 0.4  -- Size of hole in meters
C_Melee.dmg_plyr	   = 0.05 -- 0.0-1.0

C_Melee.flags = addFlags(0, FWPN_NOALTACTIONPOSE, FWPN_NOHUD) -- weapon flags
C_Melee.snds  = 0 -- Prechached SFX list, set on INIT

-- override initVars to add new variables
function C_Melee:initVars(owner)
	baseWeap.initVars(self, owner)

	if client then
		self.swingNumb 					= -1 -- 1-3
	else
		self.hitDelay 					= -1

		self.stopHitDelay 				= -1

		self.swingStartPos 				= false

		self.lasHitObj 					= -1

		self.strength					= 0
	end

	self.startHitDelay = -1
end

function C_Melee:MDL_CallAnimator(dt)
	tickToolAnimator(client.PWB_ANIMATOR[self.owner], dt, nil, self.owner, self.swingNumb, self.swingNumb, true)
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_Melee:Sounds()
	return {
		{"base/bullet_hit0.ogg", "sv", 10}, -- Player hit
		{"base/empty.ogg", "sv", 10}, -- Hard object hit
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_Melee:Holster()
	if server then
		self:StopSwing()
	else
		-- reset back to defaults
		client.PWB_ANIMATOR[self.owner].maxActionPoseTime = 5.0
		client.PWB_ANIMATOR[self.owner].collider.enabled  = false
		client.PWB_ANIMATOR[self.owner].collider.radius   = 0.01
	end
end

function C_Melee:Deploy()
	if client then
		-- override certain animator settings
		client.PWB_ANIMATOR[self.owner].maxActionPoseTime = 0.2
		client.PWB_ANIMATOR[self.owner].collider.enabled  = true
		client.PWB_ANIMATOR[self.owner].collider.radius   = 0.02
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 999
	end
end

function C_Melee:PrimaryAttack(dt)
	self.startHitDelay = GetTime() + 0.1

	if client then
		self.swingNumb = self.swingNumb - 1
		if self.swingNumb == -4 then self.swingNumb = -1 end

		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = true
	elseif self.edgeType ~= 0 then
		self.strength = GetRandomFloat(0.8, 1)
	end

	self.nextFire = self:GetNextAttackDelay(0.5)
end

-- OPTIMIZATION: Add this to make sure it doesn't check for alt fire
function C_Melee:SV_DontFireAltCond() return true end

function C_Melee:CheckHit()
	self.hitDelay = GetTime() + 0.01

	local t = GetBodyTransform(GetToolBody(self.owner))
	local dir = TransformToParentVec(t, self.edgeDir)

	if not self.swingStartPos then 
		self.swingStartPos = t.pos
		self.hitDelay = GetTime() + 0.025
		return
	end

	QueryRequire("large physical visible")
	local pHit, pDist, pHitWorld, pHitPlayer, _, pNorm = QueryShot(t.pos, dir, self.hitDist, 0.25, self.owner)

	-- pull out a little to prevent overshooting
	pDist = math.min(pDist, self.hitDist-0.5)

	if pHit then
		local hitPos = VecAdd(t.pos, VecScale(dir, pDist))   
		hitPos = VecAdd(hitPos, VecScale(pNorm, -0.25))

		-- blunt weapons hit something once
		if self.edgeType == 0 then
			if self.lasHitObj == pHitPlayer or self.lasHitObj == pHitWorld then
				return
			end
		end

		local hitForce = VecSub(self.swingStartPos, t.pos)
		ApplyBodyImpulse(GetShapeBody(pHitWorld), hitPos, VecScale(hitForce, -self.knockbackMult))

		local hitAnimator = GetBodyAnimator(GetShapeBody(pHitWorld))
		if pHitPlayer ~= 0 or hitAnimator ~= 0 then
			-- play thwack or smack sound
			server.BloodDecal(hitPos, VecNormalize(VecScale(hitForce, -1)), self.dmg_plyr, pHitPlayer)

			if self.edgeType == 0 or self.lasHitObj ~= pHitPlayer then
				PlaySound(self.snds[1], hitPos)
			end

			if pHitPlayer ~= 0 then
				ApplyPlayerDamage(pHitPlayer, self.dmg_plyr, self.toolName, self.owner)
				self.lasHitObj = pHitPlayer
			else
				self.lasHitObj = pHitWorld
			end
		elseif pHitWorld ~= 0 then
			local mat = ""
			if self.lasHitObj ~= pHitWorld then
				mat = PlayImpactSFX(pHitWorld, hitPos, 'm')
			else
				mat = GetShapeMaterialAtPos(pHitWorld, hitPos)
			end

			if self.edgeType ~= 0 then
				local penalty = 0.05
				if mat ~= "" then
					if mat == "hardmetal" or mat == "metal" or mat == "rock" or mat == "hardmasonry" or mat == "masonry" or mat == "heavymetal" then
						penalty = penalty + 0.05
						if self.lasHitObj ~= pHitWorld then
							--PlaySound(self.snds[2], hitPos)
						end
					end
				end
				self.strength = math.max(self.strength - penalty, 0)

				MakeHole(hitPos, 0.5*self.strength, 0.25*self.strength, 0.1)
			else
				MakeHole(hitPos, 0.5, 0.25, 0.125)
			end

			-- give chunks velocity here
			local list = QueryAabbBodies(VecSub(hitPos, Vec(0.2, 0.2, 0.2)), VecAdd(hitPos, Vec(0.2, 0.2, 0.2)))
			for i=1, #list do
				local body = list[i]
				local distFromHit = VecLength(VecSub(GetBodyTransform(body).pos, hitPos))
				ApplyBodyImpulse(body, hitPos, VecScale(hitForce, -self.knockbackMult * 0.05))
			end

			self.lasHitObj = pHitWorld
		end
	end
end

function C_Melee:StopSwing()
	self.stopHitDelay = -1
	self.hitDelay = -1
	self.swingStartPos = false
	self.lasHitObj = -1
end

function C_Melee:ShouldWeaponIdle() return true end
function C_Melee:WeaponIdle()
	if self.startHitDelay ~= -1 and self.startHitDelay < GetTime() then
		if client then
			client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = false
			client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0
		else
			self.hitDelay = 0
			self.stopHitDelay = GetTime() + 0.2
		end

		self.startHitDelay = -1
	end

	if client then return end

	if self.stopHitDelay ~= -1 and self.stopHitDelay < GetTime() then
		self:StopSwing()
	elseif self.hitDelay ~= -1 and self.hitDelay < GetTime() then
		self:CheckHit()
	end
end