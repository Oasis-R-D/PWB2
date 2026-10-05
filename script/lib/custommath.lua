-- PackMan's wonderful bit math library!

----------------------------------------------------------------------------------------------
-- SHIFTS
----------------------------------------------------------------------------------------------

local function leftShift(bits) return 2 ^ bits
end

local function rightShift(bits) return math.floor(1 / (2 ^ bits))
end

----------------------------------------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------------------------------------

-- WEAPON FLAGS
-- To apply weapon flags on init using x.flags, use addFlags() to 
-- add multiple or direct set x.flags to the flag if it's just the 1 flag.
-- if you are adding flags onto x.flags afterwards, you must use addFlags()
-- unless you want to overwrite the pre-existing flags.
FWPN_NONE = 0

FWPN_CLICK_PRIM = leftShift(0) -- Weapon needs clicked to fire, no holding
FWPN_CLICK_SEC  = leftShift(1) -- Weapon needs clicked to fire, no holding
FWPN_NOHUD      = leftShift(2) -- Don't draw HUD

FWPN_SV_CALLONCE_PRIM = leftShift(3) -- Does 1 servercall every fire instead of 1 on start and stop
FWPN_SV_CALLONCE_SEC  = leftShift(4) -- Does 1 servercall every secondary fire instead of 1 on start and stop
                                     -- Use these if the weapons fire rate is really slow or has flag FWPN_NEEDSCLICKED

FWPN_NOAUTORELOAD    = leftShift(5) -- Don't automatically start reloading weapon on empty
FWPN_NOALTACTIONPOSE = leftShift(6) -- Don't automatically do the action animation when holding grab


-- TEMP ENT IMPACT SFX
FSFX_NONE  = 0
FSFX_BRASS = leftShift(0)
FSFX_SHTGN = leftShift(1)
-- more for material types but we don't have func_breakable here

-- ENT FLAGS
FENT_NONE = 0
FENT_FAKEPHYSICS = leftShift(0) -- Use GoldSRC physics instead of TD. Can be changed at any time (must give model physical tag!)
----------------------------------------------------------------------------------------------
-- hacky bit operators (ONLY TAKES POWER OF 2! [otherwise these'd be very expensive])
----------------------------------------------------------------------------------------------

function hasFlag(var, flag) return
    math.floor(var / flag) % 2 == 1
end

function hasFlags_OR(var, ...)
	local flag_count = select("#", ...)

    for i = 1, flag_count do
        local flag = select(i, ...)
        if hasFlag(var, flag) then return true end
    end

	return false
end

function hasFlags_AND(var, ...)
	local flag_count = select("#", ...)

    for i = 1, flag_count do
        local flag = select(i, ...)
        if not hasFlag(var, flag) then return false end
    end

	return true
end

----------------------------------------------------------------------------------------------

function addFlag(var, flag) 
    return (var % (2 * flag) >= flag) and var or (var + flag)
end

function addFlags(var, ...)
	local flag_count = select("#", ...)

    for i = 1, flag_count do
        local flag = select(i, ...)
        var = addFlag(var, flag)
    end

	return var
end

----------------------------------------------------------------------------------------------

function clearFlag(var, flag)
    return var % (flag * 2) >= flag and var - flag or var
end

function clearFlags(var, ...)
	local flag_count = select("#", ...)

    for i = 1, flag_count do
        local flag = select(i, ...)
        var = clearFlag(var, flag)
    end

	return var
end

----------------------------------------------------------------------------------------------
-- misc math
----------------------------------------------------------------------------------------------

function Lerp(a, b, t)
    return a + (b - a) * t
end

function VecLerpExponential(a, b, decay, t)
    a = VecLerp(a, b, 1.0 - decay ^ t)
end