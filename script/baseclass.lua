#version 2

-- 1. Define the class table
local baseWeap = {}
baseWeap.__index = baseWeap

-- Constructor
function baseWeap:new(name)
    -- Create a new instance table
    local instance = setmetatable({}, baseWeap)
    
    -- Initialize properties
    instance.name = name or "Unknown"
    
    return instance
end