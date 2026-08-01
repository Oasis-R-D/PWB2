#version 2

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

-- MAIN FLAGS
MF_CL_NODRAW = leftShift(0)
MF_CL_NOINIT = leftShift(1)
MF_CL_NOTICK = leftShift(2)

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

-- UNTESTED
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