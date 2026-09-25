function Anim(...)
    local keyFrames = {...}
    table.insert(keyFrames, false) -- terminator value
    return keyFrames
end

-- turns the pos and rot into named values to be used with SetValueInTable()
local function ExtractValues(data)
    return {
        pos = VecCopy(data[2]),
        angles = VecCopy(data[3])
    }
end

function baseWeap:KF_Animate(dt)
    if self.animIndex == 0 then return end

    for shapeIndex, data in pairs(self.animFrameInfo) do
        local pos, rotEuler = data.pos, data.angles
        local rot = rotEuler and QuatEuler(rotEuler[1], rotEuler[2], rotEuler[3]) or nil

        local u = 3*self.animFrameTime^2 - 2*self.animFrameTime^3
        if u > 1 then u = 1 end

        pos = VecLerp(data.pos, self.animNextFrameInfo[shapeIndex].pos, u)
        rot = VecLerp(data.angles, self.animNextFrameInfo[shapeIndex].angles, u)

        if shapeIndex == "hand_l" then
            client.PWB_ANIMATOR[self.owner].leftHand.transform = Transform(pos, rot)
            return
        elseif shapeIndex == "hand_r" then
            client.PWB_ANIMATOR[self.owner].leftHand.transform = Transform(pos, rot)
            return
        end

        local tOffset = Transform(pos, rot)
        local t = TransformToParentTransform(tOffset, self.shapeTransforms[shapeIndex])
        SetShapeLocalTransform(GetBodyShapes(GetToolBody())[shapeIndex], t)

        -- freeze parts if they aren't used next frame
        self.animNextFrameInfo[shapeIndex] = self.animNextFrameInfo[shapeIndex] and self.animNextFrameInfo[shapeIndex] or self.animFrameInfo[shapeIndex]

        if PWB_SETTING.debug then DebugPrint(VecStr(data.pos) .. " NEW: " .. VecStr(self.animNextFrameInfo[shapeIndex].pos)) end
    end

    self.animFrameTime = self.animFrameTime + dt
end

function baseWeap:KF_NewFrame(keyFrame)
    local shapeIndex, pos, rotEuler = keyFrame[1], keyFrame[2], keyFrame[3]
    local rot = rotEuler and QuatEuler(rotEuler[1], rotEuler[2], rotEuler[3]) or nil

    -- Animation events
    if keyFrame[4] then keyFrame[4]() end

    self.animFrameTime = 0
    self.animFrame = self.animFrame + 1
    -- This value is not accurate if you have multiple shapes moving per frame!!!
    if PWB_SETTING.debug then DebugPrint("THIS FRAME: " .. self.animFrame / 2) end

    if shapeIndex == "hand_l" then
        client.PWB_ANIMATOR[self.owner].leftHand.transform = Transform(pos, rot)
        return
    elseif shapeIndex == "hand_r" then
        client.PWB_ANIMATOR[self.owner].leftHand.transform = Transform(pos, rot)
        return
    end

    -- Save original positions
    local shape = GetBodyShapes(GetToolBody())[shapeIndex]
    if not self.shapeTransforms[shapeIndex] then
        self.shapeTransforms[shapeIndex] = GetShapeLocalTransform(shape)
    end

    local tOffset = Transform(pos, rot)
    local t = TransformToParentTransform(tOffset, self.shapeTransforms[shapeIndex])
    SetShapeLocalTransform(shape, t)
end

function baseWeap:KF_Advance(dt)
	if self.animIndex == 0 then return end

	local anim = self.anims[self.animIndex]

    repeat
        self.animFrameInfo[anim[self.animFrame][1]] = ExtractValues(anim[self.animFrame])

        self:KF_NewFrame(anim[self.animFrame])
    until type(anim[self.animFrame]) ~= "table"

    if not anim[self.animFrame] then -- end of anim
        self.animIndex = 0
        return
    else -- new frame
        self.animFrame = self.animFrame + 1 -- start on a real frame

        local i = self.animFrame
        repeat -- steal next frame's data
            self.animNextFrameInfo[anim[i][1]] = ExtractValues(anim[i])

            i = i + 1
        until type(anim[i]) ~= "table"
    end
end

function baseWeap:KF_SetAnim(animIndex)
    if not self.shapeTransforms then
        self.shapeTransforms = {}
    end

    if not self.anims[animIndex] then error("Animation " .. animIndex .. " not found!", 2) return end

    self:KF_Reset()

    self.animIndex = animIndex
    self.animFrame = 1

    if PWB_SETTING.debug then DebugPrint("ANIM SET: " .. animIndex) end
end

function baseWeap:KF_Deploy() -- reset anims
    if self.animIndex == 0 then
		return -- already finished the animation (which should've hopefully ended with resetting positions)
	end

    self:KF_Reset()

    local shapes = GetBodyShapes(GetToolBody())
    for i = 1, #shapes do
        if self.shapeTransforms[i] then
            SetShapeLocalTransform(shapes[i], GetShapeLocalTransform(shapes[i]))
        end
    end
end

function baseWeap:KF_Reset() -- reset anims
    self.animIndex = 0
    self.animFrameInfo = {}
    self.animNextFrameInfo = {}
end