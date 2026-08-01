local baseWeap = {}
baseWeap.__index = baseWeap

-- Values that ALL weapons share/use
function baseWeap:initVars()
    self.var = 2
end

function baseWeap:new(obj)
    obj = obj or {}
    setmetatable(obj, self)

    -- Set up variables
    baseWeap:initVars()

    return obj
end


