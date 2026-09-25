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

function baseWeap:KF_ApplyAnimation(shapeIndex, offsetTransform)
    local shapeTransform = TransformCopy(self.shapeTransforms[shapeIndex])

    -- Rotate around pivot
    local relativePivot = VecSub(shapeTransform.pos, self.shapeCenters[shapeIndex])

    relativePivot = QuatRotateVec(offsetTransform.rot, relativePivot)

    shapeTransform.pos = VecAdd(VecAdd(self.shapeCenters[shapeIndex], relativePivot), offsetTransform.pos)
    shapeTransform.rot = QuatRotateQuat(offsetTransform.rot, shapeTransform.rot)

    SetShapeLocalTransform(GetBodyShapes(GetToolBody(self.owner))[shapeIndex], shapeTransform)

    if PWB_SETTING.debug then DebugPrint(VecStr(shapeTransform.pos) .. " NEW: " .. VecStr(self.animNextFrameInfo[shapeIndex].pos)) end
end

function baseWeap:KF_Animate(dt)
    if self.animIndex == 0 then return end

    for shapeIndex, data in pairs(self.animFrameInfo) do
        -- freeze parts if they aren't used next frame
        self.animNextFrameInfo[shapeIndex] = self.animNextFrameInfo[shapeIndex] and self.animNextFrameInfo[shapeIndex] or self.animFrameInfo[shapeIndex]

        -- cubic interpolation between 0 and 0.0166 repeating
        -- NOTE: this undershoots!
        local t = self.animFrameTime*60
        local u = 3*t^2 - 2*t^3
        if u > 1 then u = 1 end

        local pos = VecLerp(data.pos, self.animNextFrameInfo[shapeIndex].pos, u)
        local rotEuler = data.angles and VecLerp(data.angles, self.animNextFrameInfo[shapeIndex].angles, u) or nil
        local rot = nil
        if rotEuler then
            rot = QuatEuler(rotEuler[1], rotEuler[2], rotEuler[3])
        end

        local offsetTransform = Transform(pos, rot)

        if shapeIndex == "hand_l" then
            client.PWB_ANIMATOR[self.owner].leftHand.transform = offsetTransform
        elseif shapeIndex == "hand_r" then
            client.PWB_ANIMATOR[self.owner].leftHand.transform = offsetTransform
        else
            self:KF_ApplyAnimation(shapeIndex, offsetTransform)
        end
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

        local min, max = GetShapeBounds(shape)
        self.shapeCenters[shapeIndex] = TransformToLocalPoint(GetBodyTransform(GetToolBody(self.owner)), VecLerp(min, max, 0.5))
    end

    self:KF_ApplyAnimation(shapeIndex, Transform(pos, rot))
end

function baseWeap:KF_Advance(dt)
	if self.animIndex == 0 then return end

	local anim = self.anims[self.animIndex]

    repeat
        self.animFrameInfo[anim[self.animFrame][1]] = ExtractValues(anim[self.animFrame])

        self:KF_NewFrame(anim[self.animFrame])
    until type(anim[self.animFrame]) ~= "table"

    if not anim[self.animFrame] then -- end of anim
        self:KF_Reset()
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
        self.shapeCenters = {}
    end

    if not self.anims[animIndex] then error("Animation " .. animIndex .. " not found!", 2) return end

    self:KF_Reset()

    self.animIndex = animIndex

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
    self.animFrame = 1
    self.animFrameTime = 0
end