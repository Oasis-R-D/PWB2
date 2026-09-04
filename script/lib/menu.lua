#include "ui/ui_extensions.lua"

settings = {}

function settingUPD(key, value)
    SetBool("savegame.mod.pwb." .. key, value)
    settings[key] = value
end

function initBool(key, default)
    local value = default 
    if HasKey("savegame.mod.pwb." .. key) then
        value = GetBool("savegame.mod.pwb." .. key)
    else
        SetBool("savegame.mod.pwb." .. key, default)
    end

    settings[key] = value
end

function client.settingsInit()
    initBool("shelleject",  true)
    initBool("dynlights",   true)
    initBool("debug",       false)
end

function client.settingsDraw()
    if PauseMenuButton("PWB2 Settings") then
        menuActive = true
        SetBool("game.ui.hidemods", true)
    end
    
    if menuActive and menuAlpha == 0.0 then
        SetValue("menuAlpha", 1.0, "easeout", 0.3)
    end
    if not menuActive and menuAlpha == 1.0 then
        SetValue("menuAlpha", 0.0, "easein", 0.3)
        SetBool("game.ui.hidemods", false)
    end

    if menuAlpha > 0.0 then
		-- we do now want to draw a cursor
		if LastInputDevice() == UI_DEVICE_GAMEPAD then
			UiSetCursorState(UI_CURSOR_HIDE_AND_LOCK)	
		end
		if menuActive then
			UiMakeInteractive()
			SetBool("game.disablepause", true)
		end
		
		local width = 190
		local height = 500 -- update this when adding more toggles

		UiTranslate(-230+270*menuAlpha, UiMiddle())
		UiAlign("left middle")
		UiColor(.0, .0, .0, 0.75*menuAlpha)
		UiImageBox("ui/common/box-solid-10.png", width, height, 10, 10)
		UiWindow(width, height)

		UiAlign("top left")
		if InputPressed("menu_cancel") or (GetBool("game.cursor.enabled") and not UiIsMouseInRect(UiWidth(), UiHeight()) and InputPressed("lmb")) then
			menuActive = false
		end
		if InputPressed("pause") then
			menuActive = false
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
			if UiTextButton(settings.shelleject, bw, bh) then
                settingUPD("shelleject", not settings.shelleject)
			end
			UiTranslate(0, bh+sep)
			
            UiText("Dynamic Lights", true)
            UiTranslate(0, th)
			if UiTextButton(settings.dynlights, bw, bh) then
                settingUPD("dynlights", not settings.dynlights)
			end
			UiTranslate(0, bh+sep)

            UiText("Debug", true)
            UiTranslate(0, th)
			if UiTextButton(settings.debug, bw, bh) then
                settingUPD("debug", not settings.debug)
			end
			UiTranslate(0, bh+sep)
			UiTranslate(0, 10)

			if LastInputDevice() == UI_DEVICE_MOUSE or LastInputDevice() == UI_DEVICE_TOUCHSCREEN then
                UiColor(0.96, 0.32, 0.32)
                UiButtonHoverColor(1.0,0.5,0.5,1)
				if UiTextButton("loc@UI_BUTTON_CLOSE", bw, bh) then
					menuActive = false
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