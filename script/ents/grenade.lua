-- SERVER ENTITY
-- M203 and frag grenade merged into one abomination

E_Gren = {}

--=========================================================================
-- Define the entity and it's variables
--=========================================================================

-- Static values for this specific entity
-- These don't need redefined in a entity if a var is just the default value found in baseEnt

E_Gren.snds = {}

--=========================================================================
-- Define the entity's static functions
--=========================================================================

function E_Gren:Sounds()
    return {
		{"grenade_tick.ogg", "sv", "tick"},
	}
end

function E_Gren:SpawnFlags()
    return addFlag(FENT_NONE, FENT_FAKEPHYSICS)
end

--=========================================================================
-- Entity's functions
--=========================================================================

function E_Gren:Spawn()
    self.think = self.Cook
    self.nextThink = GetTime() + 10
    self.explodeTime = GetTime() + 10
    self.nextTick = math.huge
end

function E_Gren:Cook()
    -- Frag
    if self.flags == 0 then
        if self.nextTick < GetTime() then
            PlaySound(self.snds["tick"], self.origin)
            if (GetTime() - self.explodeTime ) < 1.5 then
                self.nextTick = GetTime() + 0.3
            else
                self.nextTick = GetTime() + 1.0
            end
        end

        local laserStartTrans = TransformToParentTransform(GetBodyTransform(self.body), Transform(Vec(-0.1, 0.2, -0.1), GetBodyTransform(self.body).rot))
		local laserStartVec = laserStartTrans.pos

		ParticleReset()
		ParticleRadius(0.075, 0)
		ParticleGravity(0)
		ParticleEmissive(5)
		ParticleStretch(5)
		ParticleTile(15)
		ParticleColor(1,0,0)
		SpawnParticle(laserStartVec, Vec(0,0,0), 0.5)
		SpawnParticle(laserStartVec, Vec(0,0,0), 0.75)
    end

    self.nextThink = GetTime()

    if self.explodeTime <= GetTime() then
        self:Explode()
    end
end

function E_Gren:Explode()
    self.origin = VecAdd(self.origin, Vec(0, 0.1, 0)) -- move out of ground

    Explosion(self.origin, 2, self.owner)

    self:DeleteThis()
end

--=========================================================================
-- Custom creation functions
--=========================================================================

-- Fire a M203 grenade
function E_Gren.Fire(transform, owner)
    if client then CurEntSlot = CurEntSlot + 1 return end

    local x, y, z = GetQuatEuler(transform.rot)

    local grenade = baseEnt:Create(E_Gren, transform.pos, Vec(x, y, z), owner)

    grenade:MDL_SET_SV("MOD/models/xml/gren_m203.xml", 1)

	local angThrow = TransformToParentVec(transform, Vec(0, 0, -1))
    grenade.velocity = VecScale(angThrow, 25)

    grenade.touch = grenade.Explode

    return grenade
end

-- Throw a frag grenade
function E_Gren.Throw(origin, angles, velocity, time, owner)
    if client then CurEntSlot = CurEntSlot + 1 return end

    local grenade = baseEnt:Create(E_Gren, origin, nil, owner)

    grenade.flags = 0

    grenade.nextTick = GetTime() + 1
    grenade.nextThink = GetTime()
    grenade.explodeTime = GetTime() + time

    grenade.collideRadius = 0.1

    grenade:MDL_SET_SV("MOD/models/xml/gren_frag.xml", 1)

    SetBodyTransform(grenade.body, Transform(origin, QuatEuler(angles[1], angles[2], angles[3])))
    SetBodyVelocity(grenade.body, velocity)
    SetBodyAngularVelocity(grenade.body, TransformToParentVec(GetBodyTransform(grenade.body), angles))

    PlaySound(grenade.snds["tick"], grenade.origin)
end