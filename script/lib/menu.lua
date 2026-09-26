#include "ui/ui_extensions.lua"

MenuAlpha = 0
MenuActive = false

local function settingUPD(key, value)
    SetBool("savegame.mod.pwb." .. key, value)
    PWB_SETTING[key] = value
end

function server.settingUPD(key, value)
    PWB_SETTING[key] = value
	DebugPrint("server setting " .. key .. " set to " .. value)
end

local function InitBool(key, default, onSV)
    local value = default 
    if HasKey("savegame.mod.pwb." .. key) then
        value = GetBool("savegame.mod.pwb." .. key)
    else
        SetBool("savegame.mod.pwb." .. key, default)
    end

    PWB_SETTING[key] = value

	if GetLocalPlayer() == 1 and onSV then
		ServerCall("server.settingUPD", key, value)
	end
end

function client.settingsInit()
    InitBool("shelleject",  true,  false)
    InitBool("dynlights",   true,  false)
	InitBool("penetration", true,  true)
    InitBool("debug",       false, true)
end

function client.settingsTick()
	if PauseMenuButton("PWB2 Settings") then
      	MenuActive = true
      	SetBool("game.ui.hidemods", true)
    end

   	if MenuActive and MenuAlpha == 0.0 then
      	SetValue("MenuAlpha", 1.0, "easeout", 0.3)
	elseif not MenuActive and MenuAlpha == 1.0 then
      	SetValue("MenuAlpha", 0.0, "easein", 0.3)
        SetBool("game.ui.hidemods", false)
   	end
end

function client.settingsDraw()
    if MenuAlpha > 0.0 then
		-- we do now want to draw a cursor
		if LastInputDevice() == UI_DEVICE_GAMEPAD then
			UiSetCursorState(UI_CURSOR_HIDE_AND_LOCK)
		end
		if MenuActive then
			UiMakeInteractive()
			SetBool("game.disablepause", true)
		end

		local width = 190
		local height = 550 -- update this when adding more toggles

		UiTranslate(-230+270*MenuAlpha, UiMiddle())
		UiAlign("left middle")
		UiColor(.0, .0, .0, 0.75)
		UiImageBox("ui/common/box-solid-10.png", width, height, 10, 10)
		UiWindow(width, height)
		UiAlign("top left")

		if InputPressed("menu_cancel") or
		   InputPressed("pause") or 
		   (GetBool("game.cursor.enabled") and not UiIsMouseInRect(UiWidth(), UiHeight()) and InputPressed("lmb")) 
		   then

			MenuActive = false
		end

		UiPush()
			UiAlign("center middle")
			UiTranslate(UiWidth()/2, 60)

			UiFont("regular.ttf", 27)

			local padding = 40
			local bw = width - 2 * padding
			local bh = 38
			local sep = 20
            local th = UiFontHeight()

			UiColor(0.96, 0.96, 0.96)
			UiButtonImageBox("ui/common/box-outline-fill-6.png", 6, 6, 0.96, 0.96, 0.96, 0.8)

			UiButtonHoverColor(1.0,1.0,0.5,1)

            UiText("Shell ejection", true)
            UiTranslate(0, th)
			if UiTextButton(PWB_SETTING.shelleject, bw, bh) then
                settingUPD("shelleject", not PWB_SETTING.shelleject)
			end
			UiTranslate(0, bh+sep)

            UiText("Dynamic Lights", true)
            UiTranslate(0, th)
			if UiTextButton(PWB_SETTING.dynlights, bw, bh) then
                settingUPD("dynlights", not PWB_SETTING.dynlights)
			end
			UiTranslate(0, bh+sep)

            UiText("Debug", true)
            UiTranslate(0, th)
			if UiTextButton(PWB_SETTING.debug, bw, bh) then
                settingUPD("debug", not PWB_SETTING.debug)
				if GetLocalPlayer() == 1 then
					ServerCall("server.settingUPD", "debug", PWB_SETTING.debug)
				end
			end
			UiTranslate(0, bh+sep)

			UiText("Penetration (host)", true)
            UiTranslate(0, th)
			if UiTextButton(PWB_SETTING.penetration, bw, bh) then
                settingUPD("penetration", not PWB_SETTING.penetration)
				if GetLocalPlayer() == 1 then
					ServerCall("server.settingUPD", "penetration", PWB_SETTING.penetration)
				end
			end
			UiTranslate(0, bh+sep)
			UiTranslate(0, 10)

			if LastInputDevice() == UI_DEVICE_MOUSE or LastInputDevice() == UI_DEVICE_TOUCHSCREEN then
                UiColor(0.96, 0.32, 0.32)
                UiButtonHoverColor(1.0,0.5,0.5,1)
				if UiTextButton("loc@UI_BUTTON_CLOSE", bw, bh) then
					MenuActive = false
				end
			else
				Ui:RegularFont(22)

				UiTranslate(0, 16)
				UiDrawHintsCentered({
					{ ico = "[[menu:menu_accept;iconsize=42,42]]", txt = "loc@UI_BUTTON_SELECT" },
					{ ico = "[[menu:menu_cancel;iconsize=42,42]]", txt = "loc@UI_BUTTON_CLOSE" }
				},20)
			end
		UiPop()

        return true
	end

    return false
end