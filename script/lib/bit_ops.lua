-- PackMan09's wonderful bit math library!

----------------------------------------------------------------------------------------------
-- SHIFTS
----------------------------------------------------------------------------------------------

function leftShift(bits) return 2 ^ bits
end

function rightShift(bits) return math.floor(1 / (2 ^ bits))
end

----------------------------------------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------------------------------------

-- WEAPON FLAGS
FWPN_CLICK_PRIM = leftShift(0) -- Weapon needs clicked to fire, no holding
FWPN_CLICK_SEC  = leftShift(1) -- Weapon needs clicked to fire, no holding
FWPN_NOHUD      = leftShift(2) -- Don't draw HUD

FWPN_SV_CALLONCE     = leftShift(3) -- Does 1 servercall every fire instead of 1 on start and stop
FWPN_SV_CALLONCESEC  = leftShift(4) -- Same as above but for secondary fire
                                    -- Use these if the weapons fire rate is really slow or has flag FWPN_NEEDSCLICKED

FWPN_NOAUTORELOAD = leftShift(5)    -- Don't automatically start reloading weapon on empty
FWPN_NOALTACTIONPOSE = leftShift(6) -- Don't automatically do the action animation when holding grab

-- TEMP ENTS
FTENT_NONE = 0
FTENT_SINEWAVE = leftShift(0)
FTENT_GRAVITY = leftShift(1)
FTENT_ROTATE = leftShift(2)
FTENT_SLOWGRAVITY = leftShift(3)
FTENT_SMOKETRAIL = leftShift(4)
FTENT_COLLIDEWORLD = leftShift(5)
FTENT_FLICKER = leftShift(6)
FTENT_FADEOUT = leftShift(7)
FTENT_SPRANIMATE = leftShift(8)
FTENT_HITSOUND = leftShift(9)
FTENT_SPIRAL = leftShift(10)
FTENT_SPRCYCLE = leftShift(11)
FTENT_COLLIDEALL = leftShift(12)		-- will collide with world and slideboxes
FTENT_PERSIST = leftShift(13)		-- tent is not removed when unable to draw
FTENT_COLLIDEKILL = leftShift(14)	-- tent is removed upon collision with anything
FTENT_PLYRATTACHMENT = leftShift(15) -- tent is attached to a player (owner)
FTENT_SPRANIMATELOOP = leftShift(16) -- animating sprite doesn't die when last frame is displayed
FTENT_SPARKSHOWER = leftShift(17)
FTENT_NOMODEL = leftShift(18)	  -- Doesn't have a model, never try to draw ( it just triggers other things )
FTENT_CLIENTCUSTOM = leftShift(19) -- Must specify callback.  Callback function is responsible for killing tempent and updating fields ( unless other flags specify how to do things )
FTENT_BUOYANT = leftShift(20)

-- TEMP ENT IMPACT SFX
FSFX_NONE = 0
FSFX_BRASS = leftShift(0)
FSFX_SHTGN = leftShift(1)
-- more for material types but we don't exactly have func_breakable here

----------------------------------------------------------------------------------------------
-- hacky bit operators (ONLY TAKES POWER OF 2! [otherwise these'd be very expensive])
----------------------------------------------------------------------------------------------

function hasFlag(var, flag) return math.floor(var / flag) % 2 == 1
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

function addFlag(var, flag) return (var % (2 * flag) >= flag) and var or (var + flag)
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

function clearFlag(var, flag) return var % (flag * 2) >= flag and var - flag or var
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

function math.clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

function math.lerp(a, b, t)
    return a + (b - a) * t
end

local glSeed = 1

local seed_table = {
    28985, 27138, 26457, 9451, 17764, 10909, 28790, 8716, 6361, 4853, 17798, 21977, 19643, 20662, 10834, 20103,
    27067, 28634, 18623, 25849, 8576, 26234, 23887, 18228, 32587, 4836, 3306, 1811, 3035, 24559, 18399, 315,
    26766, 907, 24102, 12370, 9674, 2972, 10472, 16492, 22683, 11529, 27968, 30406, 13213, 2319, 23620, 16823,
    10013, 23772, 21567, 1251, 19579, 20313, 18241, 30130, 8402, 20807, 27354, 7169, 21211, 17293, 5410, 19223,
    10255, 22480, 27388, 9946, 15628, 24389, 17308, 2370, 9530, 31683, 25927, 23567, 11694, 26397, 32602, 15031,
    18255, 17582, 1422, 28835, 23607, 12597, 20602, 10138, 5212, 1252, 10074, 23166, 19823, 31667, 5902, 24630,
    18948, 14330, 14950, 8939, 23540, 21311, 22428, 22391, 3583, 29004, 30498, 18714, 4278, 2437, 22430, 3439,
    28313, 23161, 25396, 13471, 19324, 15287, 2563, 18901, 13103, 16867, 9714, 14322, 15197, 26889, 19372, 26241,
    31925, 14640, 11497, 8941, 10056, 6451, 28656, 10737, 13874, 17356, 8281, 25937, 1661, 4850, 7448, 12744,
    21826, 5477, 10167, 16705, 26897, 8839, 30947, 27978, 27283, 24685, 32298, 3525, 12398, 28726, 9475, 10208,
    617, 13467, 22287, 2376, 6097, 26312, 2974, 9114, 21787, 28010, 4725, 15387, 3274, 10762, 31695, 17320,
    18324, 12441, 16801, 27376, 22464, 7500, 5666, 18144, 15314, 31914, 31627, 6495, 5226, 31203, 2331, 4668,
    12650, 18275, 351, 7268, 31319, 30119, 7600, 2905, 13826, 11343, 13053, 15583, 30055, 31093, 5067, 761,
    9685, 11070, 21369, 27155, 3663, 26542, 20169, 12161, 15411, 30401, 7580, 31784, 8985, 29367, 20989, 14203,
    29694, 21167, 10337, 1706, 28578, 887, 3373, 19477, 14382, 675, 7033, 15111, 26138, 12252, 30996, 21409,
    25678, 18555, 13256, 23316, 22407, 16727, 991, 9236, 5373, 29402, 6117, 15241, 27715, 19291, 19888, 19847
} -- 256 numbers!

function U_Random()
	glSeed = glSeed * 69069
	glSeed = glSeed + seed_table[glSeed % 256 + 1]

    local use = glSeed
    glSeed = glSeed + 1
	return use % 268435455
end

function U_Srand(seed)
	glSeed = seed_table[seed % 256 + 1]
end

--=====================
--UTIL_SharedRandomLong
--=====================
function UTIL_SharedRandomLong(seed, low, high)
	U_Srand(math.floor(seed) + low + high)

	local range = high - low + 1
	if 0 == (range - 1) then
		return low
	else
		local rnum = U_Random()

		local offset = rnum % range

		return low + offset
	end
end

--=====================
--UTIL_SharedRandomFloat
--=====================
function UTIL_SharedRandomFloat(seed, low, high)
	U_Srand(math.floor(seed) + low + high)

	U_Random()
	U_Random()

	local range = high - low
	if 0 == range then
		return low
	else
		local tensixrand = U_Random() % 65535

		local offset = tensixrand / 65536.0

		return low + offset * range
	end
end