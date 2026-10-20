-- Eye registry. Third-party eye packs add entries with hydEyesData.AddEye
-- and they show up in the character creation dropdown automatically:
--
--   hydEyesData.AddEye({
--       label = "My Blue",               -- raw label ...
--       labelKey = "IGUI_MyEyes_Blue",   -- ... or translation key (preferred)
--       male = "MyEyes.Detail_EyesMyBlueM",
--       female = "MyEyes.Detail_EyesMyBlueF",
--       textures = 1,                    -- per-skin-tone textures on the item
--       code = "MYB",                    -- 3-letter print code for ID cards
--   })
--
-- male/female are separate items because the eye area is laid out differently
-- per sex. textures counts how many skin-tone textures the items carry, in
-- vanilla skintone order (0-4); the worn texture is picked from the wearer's
-- tone, clamped to what exists. Start at 1 (one texture for every tone) and
-- grow it as per-tone art lands — no new items needed.
--
-- Optional split-graphics fields, for packs that ship separate left/right
-- eye art: maleL/maleR and femaleL/femaleR (worn on hydeyes:lefteye and
-- hydeyes:righteye) plus splitTextures for their per-tone texture count.
-- Entries without them keep the original single-slot hydeyes:eyes behavior.
--
-- This pack's 12 colors ship split left/right graphics for 5 skin tones
-- (Eyes/body01..body05, named 01<Color>_<tone><M|F>_<L|R>.png), with the
-- original combined art kept in Eyes/basic_eyes as the mod-options fallback.

hydEyesData = hydEyesData or { Eyes = {} }

-- Runtime settings, written by the Mod Options tickbox (hydEyesOptions.lua).
-- fallback = true reverts to the original single-slot combined graphics.
hydEyesSettings = hydEyesSettings or { fallback = false }

function hydEyesData.AddEye(entry)
    if type(entry) ~= "table" then return end
    if type(entry.male) ~= "string" and type(entry.female) ~= "string" then return end
    table.insert(hydEyesData.Eyes, entry)
end

-- Item for one slot: side "L"/"R" picks the split item, nil the original.
local function slotType(entry, isFemale, side)
    if side == "L" then
        return (isFemale and entry.femaleL) or entry.maleL
            or (isFemale and entry.maleL) or entry.femaleL
    elseif side == "R" then
        return (isFemale and entry.femaleR) or entry.maleR
            or (isFemale and entry.maleR) or entry.femaleR
    end
    return (isFemale and entry.female) or entry.male or entry.female
end

-- Wearer's item for this entry, plus the texture index for their skin tone.
function hydEyesData.itemFor(entry, isFemale, skinIndex, side)
    if not entry then return nil, 0 end
    local item = slotType(entry, isFemale, side)
    if item == nil then return nil, 0 end
    local count = entry.textures or 1
    if side then count = entry.splitTextures or count end
    local tone = math.max(0, math.min(skinIndex or 0, count - 1))
    return item, tone
end

-- Split left/right items for this entry/sex, if it ships any.
function hydEyesData.splitTypes(entry, isFemale)
    if not entry then return nil, nil end
    return slotType(entry, isFemale, "L"), slotType(entry, isFemale, "R")
end

-- Whether this pick should wear the split two-slot graphics.
function hydEyesData.useSplit(entry, isFemale)
    if hydEyesSettings and hydEyesSettings.fallback then return false end
    local l, r = hydEyesData.splitTypes(entry, isFemale)
    return l ~= nil and r ~= nil
end

-- Whether a registry slot value (string or list) holds this type.
local function typeMatches(v, fullType)
    if type(v) == "string" then return v == fullType end
    if type(v) == "table" then
        for _, t in ipairs(v) do
            if t == fullType then return true end
        end
    end
    return false
end

-- Registry entry wearing this full type, if any.
local function entryFor(fullType)
    if type(fullType) ~= "string" then return nil end
    for _, entry in ipairs(hydEyesData.Eyes) do
        if typeMatches(entry.male, fullType) or typeMatches(entry.female, fullType)
            or typeMatches(entry.maleL, fullType) or typeMatches(entry.femaleL, fullType)
            or typeMatches(entry.maleR, fullType) or typeMatches(entry.femaleR, fullType) then
            return entry
        end
    end
    return nil
end

function hydEyesData.isEyeType(fullType)
    return entryFor(fullType) ~= nil
end

-- Body location id a worn eye item belongs on.
function hydEyesData.locationFor(fullType)
    local entry = entryFor(fullType)
    if not entry then return "hydeyes:eyes" end
    if typeMatches(entry.maleL, fullType) or typeMatches(entry.femaleL, fullType) then
        return "hydeyes:lefteye"
    elseif typeMatches(entry.maleR, fullType) or typeMatches(entry.femaleR, fullType) then
        return "hydeyes:righteye"
    end
    return "hydeyes:eyes"
end

-- Registry print code for a worn eye item (ID cards).
function hydEyesData.codeFor(fullType)
    local entry = entryFor(fullType)
    return entry and entry.code or nil
end

-- Skin tone index (0-4) for a wearer. The skin texture name is the reliable
-- source: vanilla ships MaleBody01..MaleBody05 / FemaleBody01..FemaleBody05,
-- and the eye art is numbered the same way (body01 = palest). The visual's
-- own index is only a fallback.
function hydEyesData.skinTone(visual)
    if not visual then return 0 end
    local okName, name = pcall(function() return visual:getSkinTexture() end)
    if okName and type(name) == "string" then
        local digits = string.match(name, "(%d+)%s*$")
        local n = tonumber(digits)
        if n and n >= 1 and n <= 5 then return n - 1 end
    end
    local okIndex, index = pcall(function() return visual:getSkinTextureIndex() end)
    if okIndex and type(index) == "number" then
        return math.max(0, math.min(index, 4))
    end
    return 0
end

local function location(locId)
    return hydEyesLocation and hydEyesLocation[locId] or nil
end

local function wearSlot(player, loc, entry, isFemale, skin, side)
    local fullType, tone = hydEyesData.itemFor(entry, isFemale, skin, side)
    if not fullType then return false end
    local ok, item = pcall(instanceItem, fullType)
    if not ok or not item then return false end
    local v = item:getVisual()
    -- NB: only the base texture list is used here. setTextureChoice indexes
    -- the <textureChoices> list, which these items do not have, so calling it
    -- would leave the choice out of range and the engine would re-roll a
    -- random texture on every model rebuild.
    -- Always set the base texture, including index 0: an item with several
    -- base textures is otherwise rendered with a randomly picked one.
    if v then
        pcall(function() v:setBaseTexture(tone) end)
    end
    return pcall(function() player:setWornItem(loc, item) end)
end

local function clearSlot(player, loc)
    if loc then pcall(function() player:setWornItem(loc, nil) end) end
end

-- Wear an entry on a live player (post-spawn). Uses the registered
-- location object, never the item's own lookup. Split graphics wear one
-- item per eye slot; fallback/third-party entries wear the single item.
function hydEyesData.wearOn(player, index)
    local entry = hydEyesData.Eyes and hydEyesData.Eyes[index]
    if not entry or not player then return false end
    local okF, isFemale = pcall(function() return player:isFemale() end)
    local okV, visual = pcall(function() return player:getHumanVisual() end)
    local skin = 0
    if okV and visual then
        skin = hydEyesData.skinTone(visual)
    end
    local locEyes = location("hydeyes:eyes")
    local locL = location("hydeyes:lefteye")
    local locR = location("hydeyes:righteye")
    if hydEyesData.useSplit(entry, isFemale) and locL and locR then
        clearSlot(player, locEyes)
        local okL = wearSlot(player, locL, entry, isFemale, skin, "L")
        local okR = wearSlot(player, locR, entry, isFemale, skin, "R")
        return okL and okR
    end
    clearSlot(player, locL)
    clearSlot(player, locR)
    if not locEyes then return false end
    local fullType, tone = hydEyesData.itemFor(entry, isFemale, skin)
    if not fullType then return false end
    local ok, item = pcall(instanceItem, fullType)
    if not ok or not item then return false end
    local v = item:getVisual()
    if v then
        pcall(function() v:setBaseTexture(tone) end)
    end
    local okWear = pcall(function() player:setWornItem(locEyes, item) end)
    return okWear
end

-- Split left/right items: one per color x sex x side, each carrying the
-- per-skin-tone textures (index 0 = palest, tone 01 in the art).
local function eye(color, code)
    hydEyesData.AddEye({
        labelKey = "IGUI_Detail_Eyes" .. color,
        male = "hydEyes.Detail_Eyes" .. color .. "M",
        female = "hydEyes.Detail_Eyes" .. color .. "F",
        maleL = "hydEyes.Detail_Eyes" .. color .. "ML",
        maleR = "hydEyes.Detail_Eyes" .. color .. "MR",
        femaleL = "hydEyes.Detail_Eyes" .. color .. "FL",
        femaleR = "hydEyes.Detail_Eyes" .. color .. "FR",
        textures = 1,
        splitTextures = 5,
        code = code,
    })
end

eye("Amber", "AMB")
eye("Black", "BLA")
eye("Blue", "BLU")
eye("Brown", "BRO")
eye("Gray", "GRY")
eye("Green", "GRN")
eye("Hazel", "HAZ")
eye("LightAmber", "AMB")
eye("LightBlue", "BLU")
eye("LightBrown", "BRO")
eye("LightGreen", "GRN")
eye("LightHazel", "HAZ")
