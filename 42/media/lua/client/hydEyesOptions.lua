-- Mod Options (Options > MODS category, B42 native PZAPI.ModOptions).
-- One tickbox: revert to the original combined single-slot eye graphics
-- instead of the split left/right per-skin-tone art. The choice is cached
-- in hydEyesSettings (hydEyesData.lua), which the creation screen and
-- hydEyesData.wearOn both read; applying re-wears the current character.

require("hydEyesData")

local OPTIONS_ID = "hydEyes"

local function currentPick()
    return hydEyesChoices and hydEyesChoices[0] or hydEyesChoice or 1
end

local function currentRightPick()
    local right = hydEyesRightChoices and hydEyesRightChoices[0] or hydEyesRightChoice
    return right or currentPick()
end

local function reapplyToPlayer()
    if not getSpecificPlayer then return end
    local ok, player = pcall(getSpecificPlayer, 0)
    if ok and player and hydEyesData and hydEyesData.wearOn then
        pcall(function()
            hydEyesData.wearOn(player, currentPick(), currentRightPick())
        end)
    end
end

-- The value can come back as a boolean or as the string from the ini file.
local function toBoolean(value)
    if type(value) == "string" then return value:lower() == "true" end
    return value == true
end

local function setFallback(value)
    hydEyesSettings.fallback = toBoolean(value)
    reapplyToPlayer()
end

local options = nil
if PZAPI and PZAPI.ModOptions then
    local ok, o = pcall(function()
        return PZAPI.ModOptions:create(OPTIONS_ID, getText("IGUI_hydEyes_OptionsTitle"))
    end)
    if ok then options = o end
end

if options then
    local fallback = options:addTickBox("fallbackGraphics",
        getText("IGUI_hydEyes_Fallback"), false,
        getText("IGUI_hydEyes_Fallback_TT"))

    -- The options screen calls the option's onChangeApply when the box is
    -- ticked and applied; onChange fires while it is being toggled.
    fallback.onChangeApply = function(_self, value)
        setFallback(value)
    end
    fallback.onChange = function(_self, value)
        setFallback(value)
    end

    -- The game loads the saved ini when the options screen is opened, so
    -- pick the stored value up whenever the game comes back to a menu.
    local function sync()
        local ok, value = pcall(function() return fallback:getValue() end)
        if ok and value ~= nil then
            hydEyesSettings.fallback = toBoolean(value)
        end
    end
    if Events then
        if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(sync) end
        if Events.OnGameBoot then Events.OnGameBoot.Add(sync) end
    end
    sync()
end
