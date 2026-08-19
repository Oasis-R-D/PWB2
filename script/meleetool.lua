CMelee = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CMelee:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", 	"sv", 10},
		{"MOD/snd/smg1_reload.ogg", "cl", 10},
		{"MOD/snd/smg1_reload.ogg", "cl", 10, true}
	}
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value
CMelee.model				= "MOD/models/xml/smg1.xml" -- path to the XML model file

CMelee.toolID 			= "testgmelee"	  	-- used by the engine. lowercase and no spaces
CMelee.toolName 		= "PWB2 Test Melee" -- shown in killfeed
CMelee.toolSlot			= 1

CMelee.ammoLoadedMax 	= -1   -- max clip 	 	-- -1 for no clip (pulls from reserve)
CMelee.ammoPickupSize	= 9999 -- defaults to full mag
CMelee.dmg_world		= 0.4
CMelee.dmg_plyr			= 0.05 -- 0.0-1.0

CMelee.flags = 0	-- weapon flags
CMelee.snds	 = 0	-- temp value, will be set to the sound array on init

-- override initVars to add new variables
function CMelee:initVars(owner)
	baseWeap.initVars(self, owner)
	
	if server then
		self.hitDelay 	 = -1
		self.hitPos   	 = Vec()
	end

	self.swingAgainDelay = -1
end

--=========================================================================
-- Weapon functions
--=========================================================================

function CMelee:PrimaryAttack(dt)
	if self:Swing(true) == true then
		self.swingAgainDelay = GetTime() + 0.1
	end
end

function CMelee:Swing(fFirst)
	local fDidHit = false

	TraceResult tr

	local vecSrc = GetPlayerEyeTransform(self.owner)
	local vecEnd = vecSrc + gpGlobals->v_forward * 32

	UTIL_TraceLine(vecSrc, vecEnd, dont_ignore_monsters, ENT(m_pPlayer->pev), &tr)
	QueryRaycast(vecSrc, direction, 1)


	if server then
		if tr.flFraction >= 1.0 then
			UTIL_TraceHull(vecSrc, vecEnd, dont_ignore_monsters, head_hull, ENT(m_pPlayer->pev), &tr)
			if tr.flFraction < 1.0 then
				-- Calculate the point of intersection of the line (or hull) and the object we hit
				-- This is and approximation of the "best" intersection
				CBaseEntity* pHit = CBaseEntity::Instance(tr.pHit)
				if not pHit or pHit->IsBSPModel())
					FindHullIntersection(vecSrc, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer->edict())
				vecEnd = tr.vecEndPos -- This is the point on the actual surface (the hull could have hit space)
			end
		end
	end

	-- TO-DO: EVENT CODE HERE
	if fFirst and client then
	end

	if tr.flFraction >= 1.0 the
		if fFirst then
			-- miss
			self.nextFire = self:GetNextAttackDelay(0.5)
		end
	else
		self.nextFire = self:GetNextAttackDelay(0.25)

		if server then
			-- hit
			fDidHit = true
			CBaseEntity* pEntity = CBaseEntity::Instance(tr.pHit)

			if ((self.nextFire + 1.0) <= GetTime()) or isMP() then
				-- first swing does full damage
				ApplyPlayerDamage(pEntity, self.dmg_plyr, self.toolName, self.owner)
			else
				-- subsequent swings do half
				ApplyPlayerDamage(pEntity, self.dmg_plyr / 2, self.toolName, self.owner)
			end

			-- play thwack, smack, or dong sound
			local flVol = 1.0
			local fHitWorld = true

			if pEntity then
				if pEntity->Classify() != CLASS_NONE and pEntity->Classify() != CLASS_MACHINE then
					-- play thwack or smack sound
					switch (RANDOM_LONG(0, 2))
					{
					case 0:
						EMIT_SOUND(ENT(m_pPlayer->pev), CHAN_ITEM, "weapons/cbar_hitbod1.wav", 1, ATTN_NORM)
						break
					case 1:
						EMIT_SOUND(ENT(m_pPlayer->pev), CHAN_ITEM, "weapons/cbar_hitbod2.wav", 1, ATTN_NORM)
						break
					case 2:
						EMIT_SOUND(ENT(m_pPlayer->pev), CHAN_ITEM, "weapons/cbar_hitbod3.wav", 1, ATTN_NORM)
						break
					}
					
					if GetPlayerHealth(pEntity) <= 0 then
						return true
					else
						flVol = 0.1
					end

					fHitWorld = false
				end
			end

			-- play texture hit sound
			if fHitWorld then
				local fvolbar = TEXTURETYPE_PlaySound(&tr, vecSrc, vecSrc + (vecEnd - vecSrc) * 2, BULLET_PLAYER_CROWBAR)
				
				PlayImpactSFX(fHitWorld, vecEnd, Vec()--[[TO-DO: NORMAL]])

				-- also play crowbar strike
				switch (RANDOM_LONG(0, 1))
				{
				case 0:
					EMIT_SOUND_DYN(ENT(m_pPlayer->pev), CHAN_ITEM, "weapons/cbar_hit1.wav", fvolbar, ATTN_NORM, 0, 98 + RANDOM_LONG(0, 3))
					break
				case 1:
					EMIT_SOUND_DYN(ENT(m_pPlayer->pev), CHAN_ITEM, "weapons/cbar_hit2.wav", fvolbar, ATTN_NORM, 0, 98 + RANDOM_LONG(0, 3))
					break
				}

				-- delay the decal a bit
				m_trHit = tr
			end
			self.hitpos = vecEnd
			self.hitDelay = GetTime() + 0.2
		end
	end

	return fDidHit
end

function CMelee:Smack()
	DebugPrint("HIT")
	MakeHole(self.hitPos, 0.5, 0.33, 0.25)
end

function CMelee:ShouldWeaponIdle() return true end

function CMelee:WeaponIdle()
	if server and self.hitDelay ~= -1 and self.hitDelay < (GetTime()-dt) then 
		self:Smack()
		self.hitDelay = -1
	end

	if self.swingAgainDelay ~= -1 and self.swingAgainDelay < (GetTime()-dt) then
		self:Swing(false)
		self.swingAgainDelay = -1
	end
end