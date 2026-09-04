----------------------------------------------------------------------------------------------
--[[ DYNAMIC LIGHTS
    Dynamic lights in PWB2 were made to recreate the Teardown weapon's shrinking light volumes.
    Dynamic lights can be attached to a weapons muzzle position if needed
]]
----------------------------------------------------------------------------------------------

local dynLights = {}

function client.VFX_DynLight(p, intensity, life, color, pos, attachment)
    attachment = attachment or false
    dynLights[#dynLights + 1] = {p, intensity, life, color, pos, attachment}
end

function client.VFX_DynLightDraw(dt)
    local dynLights_amnt = #dynLights

	-- Nothing to simulate
	if dynLights_amnt == 0 then
		return end

    for i = 1, dynLights_amnt do
        local light = dynLights[i]
        if light then
            local usePos = Vec()

            if light[6] ~= false then
                usePos = GetToolLocationWorldTransform(light[6], light[1])
                if usePos then
                    usePos = usePos.pos
                    light[7] = usePos
                else
                    usePos = light[7]
                end
            else
                usePos = light[5]
            end

            local timeLeft = light[3] - GetTime()
            if timeLeft <= 0 then
                table.remove(dynLights, i)
            else
                PointLight(VecAdd(usePos, VecScale(GetPlayerVelocity(light[1]), dt)), light[4][1], light[4][2], light[4][3], light[2]*(timeLeft/light[3]*light[3]))
            end
        end
    end
end
