CMelee = {} -- goes in GLOBAL_WEAPONS
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
---------------------------------------------------------------------------

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CMelee:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", 	"sv", 10}, -- Player hit
		{"MOD/snd/smg1_fire.ogg", 	"sv", 10}, -- Hard object hit
	}
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value
CMelee.model			= "MOD/models/xml/crowbar.xml" -- path to the XML model file

CMelee.edgePos			= Vec(0,1,0)	-- where will hits be detected
CMelee.edgeDir			= Vec(0,1,-1)	-- what direction hits will be considered
CMelee.edgeType			= 1				-- 0: blunt 1: slice (slice hits things multiple times)
CMelee.hitDist			= 1.33			-- how far from the edge to check hits
CMelee.knockbackMult    = 500			-- object impulse multiplier, rec: 1000 for blunt, 50 for slice

CMelee.toolID 			= "testmelee"	  	-- used by the engine. lowercase and no spaces
CMelee.toolName 		= "PWB2 Test Melee" -- shown in killfeed
CMelee.toolSlot			= 1

CMelee.ammoLoadedMax 	= -1   -- max clip 	 	-- -1 for no clip (pulls from reserve)
CMelee.ammoPickupSize	= 9999 -- defaults to full mag
CMelee.dmg_world		= 0.4
CMelee.dmg_plyr			= 0.33 -- 0.0-1.0

CMelee.flags = 0	-- weapon flags
CMelee.snds	 = 0	-- temp value, will be set to the sound array on init

-- override initVars to add new variables
function CMelee:initVars(owner)
	baseWeap.initVars(self, owner)

	if client then
		self.animator.maxActionPoseTime = 0.2
		self.animator.collider.enabled  = true
		self.animator.collider.radius   = 0.02

		self.swingNumb 					= -1 -- 1-3
	else
		self.hitDelay 					= -1

		self.stopHitDelay 				= -1

		self.swingStartPos 				= 0

		self.lasHitObj 					= -1

		self.strength					= 0
	end

	self.startHitDelay = -1
end

function CMelee:callToolAnimator(dt)
	tickToolAnimator(self.animator, dt, nil, self.owner, self.swingNumb, self.swingNumb, true)
end

--=========================================================================
-- Weapon functions
--=========================================================================

function CMelee:Holster()
	if server then
		self:StopSwing()
	end
end

function CMelee:PrimaryAttack(dt)
	self.startHitDelay = GetTime() + 0.1

	if client then
		self.swingNumb = self.swingNumb - 1
		if self.swingNumb == -4 then self.swingNumb = -1 end
		
		self.animator.forceSecondaryActionPose = true
	elseif self.edgeType ~= 0 then
		self.strength = GetRandomFloat(0.8, 1)
	end

	self.nextFire = self:GetNextAttackDelay(0.5)
end

function CMelee:CheckHit()
	self.hitDelay = GetTime() + 0.01

	local t = GetBodyTransform(GetToolBody(self.owner))
	local dir = TransformToParentVec(t, self.edgeDir)
	
	if self.swingStartPos == 0 then 
		self.swingStartPos = t.pos
		self.hitDelay = GetTime() + 0.025
		return
	end

	QueryRequire("large physical, visible")
	local pHit, pDist, pHitWorld, pHitPlayer, _, pNorm = QueryShot(t.pos, dir, self.hitDist, 0.25, self.owner)
	
	if pHit then
		local hitPos = VecAdd(t.pos, VecScale(dir, pDist))   
		hitPos = VecAdd(hitPos, VecScale(pNorm, -0.25))
		self.debugpoint = hitPos

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
			BloodVFX(hitPos, VecNormalize(hitForce), self.dmg_plyr, pHitPlayer)

			if self.edgeType == 0 or self.lasHitObj ~= pHitPlayer then
				PlaySound(self.snd[1], hitPos)
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
				mat = PlayImpactSFX(pHitWorld, hitPos)
			else
				mat = GetShapeMaterialAtPos(pHitWorld, hitPos)
			end

			if self.edgeType ~= 0 then
				local penalty = 0.05
				if mat ~= "" then
					if mat == "hardmetal" or mat == "metal" or mat == "rock" or mat == "hardmasonry" or mat == "masonry" or mat == "heavymetal" then
						penalty = penalty + 0.05
						if self.lasHitObj ~= pHitWorld then
							PlaySound(self.snd[2], hitPos)
						end
					end
				end
				self.strength = math.max(self.strength - penalty, 0)

				MakeHole(hitPos, 0.5*self.strength, 0.25*self.strength, 0.125*self.strength)
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


function CMelee:StopSwing()
	self.stopHitDelay = -1
	self.hitDelay = -1
	self.swingStartPos = 0
	self.lasHitObj = -1
end

function CMelee:ShouldWeaponIdle() return true end
function CMelee:WeaponIdle()
	if self.startHitDelay ~= -1 and self.startHitDelay < GetTime() then
		if client then
			self.animator.forceSecondaryActionPose = false
			self.animator.timeSinceFire = 0.0
		else
			self.hitDelay = 0
			self.stopHitDelay = GetTime() + 0.2
		end

		self.startHitDelay = -1
	end

	if client then return end

	DebugCross(self.debugpoint)

	if self.stopHitDelay ~= -1 and self.stopHitDelay < GetTime() then
		self:StopSwing()
	end

	if self.hitDelay ~= -1 and self.hitDelay < GetTime() then
		self:CheckHit()
	end
end