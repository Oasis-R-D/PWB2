function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Return signed angle between vec0 and vec1 with respect to axis
function getSignedAngle(vec0, vec1, axis)
    local dot0 = VecDot(axis, vec0)
    local dot1 = VecDot(axis, vec1)

    local v0 = VecNormalize(VecSub(vec0, VecScale(axis, dot0)))
    local v1 = VecNormalize(VecSub(vec1, VecScale(axis, dot1)))

    local dotv = VecDot(v0, v1)
    local angle = math.acos(clamp(dotv, -1.0, 1.0))

    local c = VecCross(v0,v1)
    if VecDot(c, axis) < 0.0 then
        return -angle
    else
        return angle
    end
end

function dampVal(rate, dt)
    return 1.0 - 2.0^(-rate * dt)
end

function debugSphere(position, radius, r,g,b,a)
    DebugLine(VecSub(position, Vec(0,radius, 0)), VecAdd(position, Vec(0, radius, 0)), r, g, b, a)
    DebugLine(VecSub(position, Vec(radius, 0, 0)), VecAdd(position, Vec(radius, 0, 0)), r, g, b, a)
    DebugLine(VecSub(position, Vec(0, 0, radius)), VecAdd(position, Vec(0, 0, radius)), r, g, b, a)
end

function HandPose()
    local handPose = {}
    handPose.transform = Transform()
    handPose.used = 0.0

    return handPose
end

function ToolAnimator()
    local anim = {}
    
    -- Contact is tested and if there is an intersection with the world action pose will return faster to the alternative poses
    anim.contact = {}
    anim.contact.center = Vec()
    anim.contact.radius = 0.3

    -- Collider is used for interstion solving. Will push the tool out.
    anim.collider = {}
    anim.collider.center = Vec()
    anim.collider.radius = 0.01
    anim.collider.enabled = false

    -- Scale pitch motion. Arm pitch is position rotation around shoulder. Tool pitch is actual pitch rotation around tool pivot.
    anim.armPitchScale = 1.0
    anim.toolPitchScale = 1.0

    -- Enable aim rotation to auto rotate tool making -z axis point at target
    anim.useAimRotation = false

    -- Max time to hold action pose after last "usetool"
    anim.maxActionPoseTime = 2.0

    -- The action pose is automatically selected when "usetool" is pressed. To manually select the action pose set forceActionPose to true. 
    anim.forceActionPose = false
	anim.forceSecondaryActionPose = false
	
    -- Adds offset transform
    anim.offsetTransform = Transform()

    -- Internal
    anim.transform = Transform()
    anim.rightHand = HandPose()
    anim.leftHand = HandPose()

    anim.contact.intersects = false

    anim.poseTransform = Transform()
    anim.armPitchActual = 0.0
    anim.toolRotation = Quat()

    anim.timeSinceFire = 100.0
    anim.solverOffset = Vec()

    return anim
end

function tickToolAnimator(toolAnimator, dt, defaultPoseTransform, playerId, swingamnts, noheldaction)

	swingamnts = swingamnts or ""
	noheldaction = noheldaction or false
	
    -- Get current tool and hand pose transforms
    local thirdPerson = (playerId and playerId > 0 and not IsPlayerLocal(playerId)) or GetBool("game.thirdperson")

    local prefix = "fp_"
    if thirdPerson then
		swingamnts = ""
        prefix = "tp_"
    end
	
	if swingamnts ~= "" then
		swingamnts = math.random(1, swingamnts)
	end
	
    local poseRightHand = HandPose()
    local poseLeftHand = HandPose()
	
	local pose = nil 
	
	if toolAnimator.forceSecondaryActionPose == false then
		pose = getPoseTransform(prefix.."action"..swingamnts, playerId)
	else
		pose = getPoseTransform(prefix.."secaction", playerId)
	end
	
    if defaultPoseTransform ~= nil then
        pose = TransformCopy(defaultPoseTransform)
    end

    if pose == nil then
        pose = Transform()
    end
	
	if toolAnimator.forceSecondaryActionPose == false then
		getHandPoseTransforms(prefix .. "action"..swingamnts, poseRightHand, poseLeftHand, playerId)
		mixWithPose(prefix.."action_crouch"..swingamnts, getCrouching(playerId), pose, poseRightHand, poseLeftHand, playerId)
	else
		getHandPoseTransforms(prefix .. "secaction", poseRightHand, poseLeftHand, playerId)
		mixWithPose(prefix.."secaction_crouch", getCrouching(playerId), pose, poseRightHand, poseLeftHand, playerId)
	end
	
    toolAnimator.timeSinceFire = toolAnimator.timeSinceFire + dt
    if (InputDown("usetool", playerId) and noheldaction == false) or toolAnimator.forceActionPose or toolAnimator.forceSecondaryActionPose then
        toolAnimator.timeSinceFire = 0.0
    end
	
    local useAimRotation = toolAnimator.useAimRotation
    local poseTimeCondition = toolAnimator.maxActionPoseTime
    if toolAnimator.contact.intersects then
        poseTimeCondition = math.min(0.3, poseTimeCondition)
    end
    local useAltPose = false
    if toolAnimator.timeSinceFire > poseTimeCondition then
        toolAnimator.timeSinceFire = 10000

        local alt = getPoseTransform(prefix.."run", playerId)
        if alt then
            pose = alt
            useAltPose = true
        end
        getHandPoseTransforms(prefix .. "run", poseRightHand, poseLeftHand, playerId)

        local mixed = mixWithPose(prefix.."jump", getJumping(playerId), pose, poseRightHand, poseLeftHand, playerId)
        useAltPose = useAltPose or mixed

        mixed = mixWithPose(prefix.."swim", getSwimming(playerId), pose, poseRightHand, poseLeftHand, playerId)
        useAltPose = useAltPose or mixed

        mixed = mixWithPose(prefix.."crouch", getCrouching(playerId), pose, poseRightHand, poseLeftHand, playerId)
        useAltPose = useAltPose or mixed
        if useAltPose then
            useAimRotation = false
        end

    end

    -- Smooth out tool pose and hand pose changes
    local changeRate = 60.0
    if useAltPose then
        changeRate = 20.0
    end
    local a = dampVal(changeRate, dt)
    mixInTransform(toolAnimator.poseTransform, pose, a)
    mixInHand(toolAnimator.rightHand, poseRightHand, a)
    mixInHand(toolAnimator.leftHand, poseLeftHand, a)

    local t = TransformCopy(toolAnimator.poseTransform)

    -- Animate tool
    local playerAnimator = GetPlayerAnimator(playerId)

    local thirdPersonAnimation = thirdPerson and playerAnimator ~= 0
    if  thirdPersonAnimation then

        -- Add shoulder movement
        t.pos = VecAdd(t.pos, getBoneAnimationOffset(playerAnimator, "shoulder_r", playerId))

        -- Add arm pitch (rotate tool position only)
        local armPitchScale = toolAnimator.armPitchScale
        if useAltPose then
            armPitchScale = armPitchScale * 0.5
        end

        toolAnimator.armPitchActual = toolAnimator.armPitchActual + ((getPitch(playerId) * armPitchScale) - toolAnimator.armPitchActual) * a

        local armRot = QuatAxisAngle(Vec(1, 0, 0), toolAnimator.armPitchActual)
        local pivot = getBonePosition(playerAnimator, "neck", playerId)
        t = rotatePositionAroundPivot(t, pivot, armRot)

        -- Apply sway
        local offset = getBoneAnimationOffset(playerAnimator, "foot_r", playerId)
        local sway = QuatAxisAngle(Vec(0.0, 1.0, 0.0), offset[3] * 5.0)
        t = rotateAroundPivot(t, pivot, sway)

        -- Rotate tool
        if useAimRotation then
            local b = dampVal(15.0, dt)
            local _, target = getAimTarget(10.0, playerId)
            local rot = getAimRotation(target, t.pos)
            toolAnimator.toolRotation = QuatSlerp(toolAnimator.toolRotation, rot, b)
        else
            local b = dampVal(30.0, dt)
            local pitchScale = toolAnimator.toolPitchScale
            if useAltPose then
                pitchScale = pitchScale * 0.4
            end
            local rot = QuatAxisAngle(Vec(1.0, 0.0, 0.0), getPitch(playerId) * pitchScale)
            toolAnimator.toolRotation = QuatSlerp(toolAnimator.toolRotation, rot, b)
        end
        t = rotateAroundPivot(t, t.pos, toolAnimator.toolRotation)
    end

    t = TransformToParentTransform(t, toolAnimator.offsetTransform)

    local toWorld = getToWorldTransform(thirdPersonAnimation)

    -- Check if in contact (pre intersection resolving)
    local center = TransformToParentPoint(t, toolAnimator.contact.center)
    center = TransformToParentPoint(toWorld, center)
    toolAnimator.contact.intersects = testContact(center, toolAnimator.contact.radius)

    -- Solve intersections
    if toolAnimator.collider.enabled then
        center = TransformToParentPoint(t, toolAnimator.collider.center)
        center = TransformToParentPoint(toWorld, center)

        local offset = solveIntersection(center, toolAnimator.collider.radius)
        offset = TransformToLocalVec(toWorld, offset)

        local alpha = dampVal(100.0, dt)
        toolAnimator.solverOffset = VecAdd(toolAnimator.solverOffset,
            VecScale(VecSub(offset, toolAnimator.solverOffset), alpha))

        t.pos = VecAdd(t.pos, toolAnimator.solverOffset)
    end

    toolAnimator.transform = t

    local right = nil
    if toolAnimator.rightHand.used > 0.5 then
        right = toolAnimator.rightHand.transform
    end

    local left = nil
    if toolAnimator.leftHand.used > 0.5 then
        left = toolAnimator.leftHand.transform
    end
    SetToolHandPoseLocalTransform(right, left, playerId)

    if thirdPerson then
        SetToolTransformOverride(toolAnimator.transform, playerId)
    else
        SetToolTransform(toolAnimator.transform, 1.0, playerId)
    end
end

function getPoseTransform(poseName, playerId)
    return GetToolLocationLocalTransform(poseName, playerId)
end

function getHandPoseTransforms(poseName, rightHand, leftHand, playerId)
    local right = GetToolLocationLocalTransform(poseName.."_rh", playerId)
    local left = GetToolLocationLocalTransform(poseName.."_lh", playerId)

    if right or left then
        rightHand.used = 0.0
        leftHand.used = 0.0
        if right then
            rightHand.transform = right
            rightHand.used = 1.0
        end

        if left then
            leftHand.transform = left
            leftHand.used = 1.0
        end
    end

    return right ~= nil or left ~= nil
end

function mixValue(a, b, t)
    local result = 0.0
    result = a * (1.0 - t) + b * t
    return result
end

function mixInTransform(aInOut, bIn, t)
    aInOut.pos = VecLerp(aInOut.pos, bIn.pos, t)
    aInOut.rot = QuatSlerp(aInOut.rot, bIn.rot, t)
end

function mixInHand(aInOut, bIn, t)
    mixInTransform(aInOut.transform, bIn.transform, t)
    aInOut.used = mixValue(aInOut.used, bIn.used, t)
end

function mixWithPose(poseName, alpha, pose, poseRightHand, poseLeftHand, playerId)

    local poseAlt = getPoseTransform(poseName, playerId)
    if alpha > 0.0 and poseAlt then
        mixInTransform(pose, poseAlt, alpha)

        local poseAltRightHand = HandPose()
        local poseAltLeftHand = HandPose()
        if getHandPoseTransforms(poseName, poseAltRightHand, poseAltLeftHand, playerId) then
            mixInHand(poseRightHand, poseAltRightHand, alpha)
            mixInHand(poseLeftHand, poseAltLeftHand, alpha)
        end

        return true
    end

    return false
end

function getEyeMaxHeight()
    return 1.7
end

function getEyeHeight(playerId)
    return VecDot(VecSub(GetPlayerEyeTransform(playerId).pos, GetPlayerTransform(playerId).pos), GetPlayerUp(playerId))
end

function getChestHeight(playerId)
    return 1.2 - (0.6 * getCrouching(playerId))
end

function getPitch(playerId)
    local pitch = GetPlayerPitch(playerId)
    return pitch
end

function getBoneAnimationOffset(animator, boneName, playerId)
    local animatorTW = GetAnimatorTransform(animator)
    local boneBPT = GetBoneBindPoseTransform(animator, boneName)
    local boneBPTW = TransformToParentTransform(animatorTW, boneBPT)
    local boneTW = GetBoneWorldTransform(animator, boneName)

    local offsetW = VecSub(boneTW.pos, boneBPTW.pos)
    local offsetL = TransformToLocalVec(getYawTransform(playerId), offsetW)

    return offsetL
end

-- eye space
function getBonePosition(animator, boneName, playerId)
    local p = GetBoneWorldTransform(animator, boneName).pos
    local t = getToWorldTransform(true, playerId)
    return TransformToLocalPoint(t, p)
end

-- eye space
function getAimRotation(target, pivot)
    local d = VecNormalize(VecSub(target, pivot))

    local YAW_MAX_UP = math.rad(10.0)
    local YAW_MAX_DOWN = math.rad(5)
    local PITCH_MAX = math.rad(80.0)

    local pitch = clamp(getSignedAngle(Vec(0.0,0.0,-1.0), d, Vec(1.0,0.0,0.0)), -PITCH_MAX, PITCH_MAX)
    local yaw = getSignedAngle(Vec(0.0,0.0,-1.0), d, Vec(0.0,1.0,0.0))

    if pitch < 0.0 then
        yaw = clamp(yaw, -YAW_MAX_DOWN, YAW_MAX_DOWN)
    else
        yaw = clamp(yaw, -YAW_MAX_UP, YAW_MAX_UP)
    end

    local rot = QuatRotateQuat(QuatAxisAngle(Vec(0.0,1.0,0.0), math.deg(yaw)), QuatAxisAngle(Vec(1.0,0.0,0.0), math.deg(pitch)))
    return rot
end

function getAimTarget(maxDist, playerId)
    QueryRequire("physical visible")
    
    local ct = GetPlayerCameraTransform(playerId)

    local start = ct.pos
    local direction = QuatRotateVec(ct.rot, Vec(0,0,-1))

    local distanceFromEye = math.max(VecDot(VecSub(GetPlayerEyeTransform(playerId).pos, start), direction), 0.0)
    start = VecAdd(start, VecScale(direction, distanceFromEye))

    local hit, dist, _, _ = QueryRaycast(start, direction, maxDist)

    if not hit then
        dist = maxDist
    end

    local hitPosWorld = VecAdd(start, VecScale(direction, dist))
    local hitPos = TransformToLocalPoint(getToWorldTransform(true, playerId), hitPosWorld)

    return hit, hitPos
end


function rotateAroundPivot(transform, pivot, rotation)
    local t = TransformCopy(transform)
    t.pos = VecSub(t.pos, pivot)

    local r = Transform(Vec(), rotation)
    t = TransformToParentTransform(r, t)
    t.pos = VecAdd(t.pos, pivot)

    return t
end

function rotatePositionAroundPivot(transform, pivot, rotation)
    local t = TransformCopy(transform)

    local p = VecSub(t.pos, pivot)
    local r = Transform(Vec(), rotation)
    p = TransformToParentVec(r, p)
    p = VecAdd(p, pivot)

    t.pos = p
    return t
end


function getToWorldTransform(useToolOverride, playerId)
    if useToolOverride then
        local playerAnimator = GetPlayerAnimator(playerId)
        local t = GetPlayerTransform(playerId);
        if playerAnimator ~= 0 then
            t = GetAnimatorTransform(playerAnimator)
        end

        t.rot = getYawTransform().rot
        local up = GetPlayerUp(playerId)
        t.pos = VecAdd(t.pos, VecScale(up, getEyeMaxHeight()))        
        return t
    else
        return GetPlayerEyeTransform(playerId)
    end
end

function getPitchTransform(playerId)
    return Transform(Vec(), QuatAxisAngle(Vec(1,0,0), getPitch(playerId)))
end

function getYawTransform(playerId)
    return Transform(Vec(), GetPlayerTransform(playerId).rot)
end


function getCrouching(playerId)
    local height = getEyeHeight(playerId)
    return 1.0 - (clamp(height, 0.85, 1.7) - 0.85)/(1.7 - 0.85)
end

function getJumping(playerId)
    local pt = GetPlayerTransform(playerId)
    QueryRequire("physical")
    local hit, _, _, _ = QueryClosestPoint(pt.pos, 0.3)

    if hit then
        return 0.0
    end

    return 1.0
end

function getSwimming(playerId)
    local pt = GetPlayerTransform(playerId)
    local inWater, depth = IsPointInWater(VecAdd(pt.pos, Vec(0,0.2,0)))

    if inWater and depth > 0.0 then
        return clamp(1.0/depth, 0.0, 1.0)
    end

    return 0.0
end

function testContact(center, radius)
    QueryRequire("physical")
    local hit, point, _, _ = QueryClosestPoint(center, radius)

    local contact = false
    if hit then
        local dist = VecLength(VecSub(point, center))
        contact = dist < radius
    end

    return contact
end

function solveIntersection(center, radius, playerId)
    local centerCurr = VecCopy(center)

    for i = 1, 2, 1 do

        QueryRequire("physical")
        local a = VecAdd(GetPlayerTransform(playerId).pos,VecScale(Vec(0.0,1.0,0.0), getChestHeight(playerId)))
        local d = VecSub(centerCurr, a)
        local l = VecLength(d)
        d = VecNormalize(d)

        local rayHit, rayHitDist, rayHitNormal = QueryRaycast(a, d, l)
        if rayHit then
            local hitPos = VecAdd(a, VecScale(d, rayHitDist))
            centerCurr = VecAdd(hitPos, VecScale(rayHitNormal, 0.01))
        end

        QueryRequire("physical")
        local hit, hitPos, hitNormal = QueryClosestPoint(centerCurr, radius * 1.5)
        if hit then
            local v = VecSub(centerCurr, hitPos)
            local dist = VecDot(hitNormal, v)
            local moveDist = math.max(radius - dist, 0.0)
            centerCurr = VecAdd(centerCurr, VecScale(hitNormal, moveDist))
        end

    end

    local offset = VecSub(centerCurr, center)
    local offsetDist = math.min(VecLength(offset), 0.4)
    offset = VecScale(VecNormalize(offset), offsetDist)

    return offset
end
