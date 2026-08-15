local sounds = {}
local paused
function sndMan_AddLoop(snd)
    local ln = #sound_loops
    sounds[ln+1] = snd
end

function sndMan_ClearAll()
    local ln = #sound_loops
    for i=1, ln do
        SetSoundLoopProgress(sound_loops[i], 0)
    end
    paused = true
end