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

local function reapplyToPlayer()
    if not getSpecificPlayer then return end
    local ok, player = pcall(getSpecificPlayer, 0)
    if ok and player and hydEyesData and hydEyesData.wearOn then
        pcall(function() hydEyesData.wearOn(player, currentPick()) end)
    end
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
    options.apply = function()
        local ok, v = pcall(function() return fallback:getValue() end)
        hydEyesSettings.fallback = ok and v or false
        reapplyToPlayer()
    end
    local sync = function()
        pcall(function() options:apply() end)
    end
    if Events then
        if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(sync) end
        if Events.OnGameBoot then Events.OnGameBoot.Add(sync) end
    end
    sync()
end
