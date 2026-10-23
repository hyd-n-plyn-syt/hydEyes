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
-- This pack's 12 colors are layered: the eye item carries one texture per
-- eye shape and height (Eyes/<type>/<height>/<type><Color>_<side>.png) and
-- a separate lash item carries the lash art. Both eye and lash items are
-- split left/right and worn on their own body slots, so the renderer draws
-- face -> eyes -> lashes.

hydEyesData = hydEyesData or { Eyes = {} }

-- Full type of the mod's own trait, registered in media/registries.lua.
hydEyesData.HETEROCHROMIA = "hydEyes:heterochromia"

-- Set by the creation screen while a character with the heterochromia trait
-- is being built. The trait may not be on the player object yet when the
-- post-spawn dress runs, so the creation state is used as a fallback.
hydEyesData.creationHeterochromia = hydEyesData.creationHeterochromia or false

-- Eye shapes: one folder per entry under media/textures/Eyes. Add a folder
-- (and its textures to the eye/lash clothing items) to make a new shape
-- selectable; the dropdown follows this list.
hydEyesData.Types = { "01", "02", "03", "04" }
hydEyesData.DefaultTypeIndex = 1

-- Height subfolders, in dropdown order. Normal is the default.
hydEyesData.Heights = {
    { key = "low", labelKey = "IGUI_hydEyes_HeightLow" },
    { key = "normal", labelKey = "IGUI_hydEyes_HeightNormal" },
    { key = "high", labelKey = "IGUI_hydEyes_HeightHigh" },
}
hydEyesData.DefaultHeightIndex = 2

-- Lash lengths. "none" wears no lash item; the others map to the
-- <type>_LashShort_<side> / <type>_LashLong_<side> art.
hydEyesData.LashLengths = {
    { key = "none", labelKey = "IGUI_hydEyes_LashNone" },
    { key = "short", labelKey = "IGUI_hydEyes_LashShort", texture = "LashShort" },
    { key = "long", labelKey = "IGUI_hydEyes_LashLong", texture = "LashLong" },
}
hydEyesData.DefaultLashIndex = 1

-- Lash items: one per sex fit and side, carrying every shape x height x
-- length texture. Worn on the lash slots, above the eye slots.
hydEyesData.LashItems = {
    maleL = "hydEyes.Detail_EyesLashML",
    maleR = "hydEyes.Detail_EyesLashMR",
    femaleL = "hydEyes.Detail_EyesLashFL",
    femaleR = "hydEyes.Detail_EyesLashFR",
}

function hydEyesData.AddEye(entry)
    if type(entry) ~= "table" then return end
    local hasItem = type(entry.male) == "string" or type(entry.female) == "string"
        or type(entry.maleL) == "string" or type(entry.maleR) == "string"
        or type(entry.femaleL) == "string" or type(entry.femaleR) == "string"
    if not hasItem then return end
    table.insert(hydEyesData.Eyes, entry)
end

function hydEyesData.clampIndex(value, count)
    if type(count) ~= "number" or count < 1 then return 1 end
    value = tonumber(value) or 1
    if value < 1 then value = 1 end
    if value > count then value = count end
    return math.floor(value)
end

-- The eye items carry one base texture per shape x height combination,
-- ordered shape-major then height-major (low, normal, high).
function hydEyesData.eyeTextureCount()
    return #hydEyesData.Types * #hydEyesData.Heights
end

function hydEyesData.eyeTextureIndex(typeIndex, heightIndex)
    local t = hydEyesData.clampIndex(typeIndex, #hydEyesData.Types) - 1
    local h = hydEyesData.clampIndex(heightIndex, #hydEyesData.Heights) - 1
    return t * #hydEyesData.Heights + h
end

-- Lash items carry shape x height x length, ordered shape, then height,
-- then length (short, long). "none" has no texture and returns nil.
function hydEyesData.lashTextureCount()
    return hydEyesData.eyeTextureCount() * (#hydEyesData.LashLengths - 1)
end

function hydEyesData.lashTextureIndex(typeIndex, heightIndex, lashIndex)
    local lash = hydEyesData.clampIndex(lashIndex, #hydEyesData.LashLengths)
    if lash <= 1 then return nil end
    return hydEyesData.eyeTextureIndex(typeIndex, heightIndex) * (#hydEyesData.LashLengths - 1)
        + (lash - 2)
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

-- Wearer's item for this entry, plus the texture index to select on it.
-- Layered entries pass a shape/height index; legacy entries pass a skin tone.
function hydEyesData.itemFor(entry, isFemale, textureIndex, side)
    if not entry then return nil, 0 end
    local item = slotType(entry, isFemale, side)
    if item == nil then return nil, 0 end
    local count = entry.textures or 1
    if side then count = entry.splitTextures or count end
    local index = math.max(0, math.min(textureIndex or 0, count - 1))
    return item, index
end

-- Split left/right items for this entry/sex, if it ships any.
function hydEyesData.splitTypes(entry, isFemale)
    if not entry then return nil, nil end
    return slotType(entry, isFemale, "L"), slotType(entry, isFemale, "R")
end

-- Whether this pick should wear the split two-slot graphics.
function hydEyesData.useSplit(entry, isFemale)
    local l, r = hydEyesData.splitTypes(entry, isFemale)
    return l ~= nil and r ~= nil
end

-- Lash item for one side.
function hydEyesData.lashItemFor(isFemale, side)
    local items = hydEyesData.LashItems
    if side == "L" then
        return (isFemale and items.femaleL) or items.maleL or items.femaleL
    end
    return (isFemale and items.femaleR) or items.maleR or items.femaleR
end

local function isLashType(fullType)
    if type(fullType) ~= "string" then return false end
    for _, full in pairs(hydEyesData.LashItems) do
        if full == fullType then return true end
    end
    return false
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
    return entryFor(fullType) ~= nil or isLashType(fullType)
end

-- Body location id a worn eye or lash item belongs on.
function hydEyesData.locationFor(fullType)
    if isLashType(fullType) then
        local items = hydEyesData.LashItems
        if fullType == items.maleL or fullType == items.femaleL then
            return "hydeyes:leftlash"
        end
        return "hydeyes:rightlash"
    end
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

-- Skin tone index (0-4) for a wearer. Used by legacy/single-slot entries;
-- the mod's own layered art is tone-independent. The skin texture name is
-- the reliable source: vanilla ships MaleBody01..MaleBody05 /
-- FemaleBody01..FemaleBody05. The visual's own index is only a fallback.
function hydEyesData.skinTone(visual)
    if not visual then return 0 end
    -- The game stores the skin tone zero-based (the skin picker does
    -- setSkinTextureIndex(index - 1)) and the body textures are numbered
    -- 01..05, so the index is the art's tone number minus one.
    local okIndex, index = pcall(function() return visual:getSkinTextureIndex() end)
    if okIndex and type(index) == "number" and index >= 0 and index <= 4 then
        return index
    end
    -- Fall back to the skin texture name: MaleBody01..FemaleBody05.
    local okName, name = pcall(function() return visual:getSkinTexture() end)
    if okName and type(name) == "string" then
        local digits = string.match(name, "(%d+)%s*$")
        local n = tonumber(digits)
        if n and n >= 1 and n <= 5 then return n - 1 end
    end
    return 0
end

-- Whether the character was created with the heterochromia trait.
-- The state is tracked from the creation screen instead of asking the
-- character object: the trait methods are not exposed to Lua on every
-- object (the creation desc has no hasTrait), and in Kahlua a call to a
-- missing Java method is a hard error that pcall does not catch.
function hydEyesData.heterochromiaActive()
    return hydEyesData.creationHeterochromia == true
end

local function location(locId)
    return hydEyesLocation and hydEyesLocation[locId] or nil
end

local function wearSlot(player, loc, entry, isFemale, textureIndex, side)
    local fullType, index = hydEyesData.itemFor(entry, isFemale, textureIndex, side)
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
        pcall(function() v:setBaseTexture(index) end)
    end
    return pcall(function() player:setWornItem(loc, item) end)
end

local function wearLashSlot(player, loc, isFemale, textureIndex, side)
    local fullType = hydEyesData.lashItemFor(isFemale, side)
    if not fullType then return false end
    local ok, item = pcall(instanceItem, fullType)
    if not ok or not item then return false end
    local v = item:getVisual()
    if v then
        pcall(function() v:setBaseTexture(textureIndex) end)
    end
    return pcall(function() player:setWornItem(loc, item) end)
end

local function clearSlot(player, loc)
    if loc then pcall(function() player:setWornItem(loc, nil) end) end
end

-- Remove every eye and lash layer from a character. Used by the creation Play
-- handoff and when switching to a legacy/single-slot entry.
function hydEyesData.clearWorn(target)
    if not target then return end
    for _, id in ipairs({
        "hydeyes:eyes",
        "hydeyes:lefteye",
        "hydeyes:righteye",
        "hydeyes:leftlash",
        "hydeyes:rightlash",
    }) do
        clearSlot(target, location(id))
    end
end

local function applyLashes(target, isFemale, typeIndex, heightIndex, lashIndex)
    local locL = location("hydeyes:leftlash")
    local locR = location("hydeyes:rightlash")
    local index = hydEyesData.lashTextureIndex(typeIndex, heightIndex, lashIndex)
    if not index then
        clearSlot(target, locL)
        clearSlot(target, locR)
        return
    end
    if locL then wearLashSlot(target, locL, isFemale, index, "L") end
    if locR then wearLashSlot(target, locR, isFemale, index, "R") end
end

-- Wear the chosen eye colours, shape, height and lash length on any
-- character: the creation preview, a customisation panel's own preview
-- survivor, or a spawned player.
-- rightIndex is the right eye's pick and is used when the character has
-- different colours; forceRight applies it regardless, for previews of a
-- character that has the heterochromia trait.
function hydEyesData.wearColors(target, leftIndex, rightIndex, forceRight, typeIndex, heightIndex, lashIndex)
    local list = hydEyesData.Eyes
    if not list then return false end
    local entry = list[leftIndex]
    if not entry or not target then return false end
    typeIndex = hydEyesData.clampIndex(typeIndex or hydEyesData.DefaultTypeIndex, #hydEyesData.Types)
    heightIndex = hydEyesData.clampIndex(heightIndex or hydEyesData.DefaultHeightIndex, #hydEyesData.Heights)
    lashIndex = hydEyesData.clampIndex(lashIndex or hydEyesData.DefaultLashIndex, #hydEyesData.LashLengths)
    local okF, isFemale = pcall(function() return target:isFemale() end)
    local okV, visual = pcall(function() return target:getHumanVisual() end)
    local skin = 0
    if okV and visual then
        skin = hydEyesData.skinTone(visual)
    end
    local locEyes = location("hydeyes:eyes")
    local locL = location("hydeyes:lefteye")
    local locR = location("hydeyes:righteye")
    local rightEntry = entry
    if rightIndex and rightIndex ~= leftIndex
        and (forceRight or hydEyesData.heterochromiaActive()) then
        rightEntry = list[rightIndex] or entry
    end
    if entry.layered then
        if hydEyesData.useSplit(entry, isFemale) and locL and locR then
            clearSlot(target, locEyes)
            local texture = hydEyesData.eyeTextureIndex(typeIndex, heightIndex)
            local okL = wearSlot(target, locL, entry, isFemale, texture, "L")
            local okR = wearSlot(target, locR, rightEntry, isFemale, texture, "R")
            applyLashes(target, isFemale, typeIndex, heightIndex, lashIndex)
            return okL and okR
        end
        -- Layered entries have no single-slot art.
        hydEyesData.clearWorn(target)
        return false
    end
    clearSlot(target, locL)
    clearSlot(target, locR)
    applyLashes(target, isFemale, 0, 0, 0)
    if not locEyes then return false end
    local fullType, tone = hydEyesData.itemFor(entry, isFemale, skin)
    if not fullType then return false end
    local ok, item = pcall(instanceItem, fullType)
    if not ok or not item then return false end
    local v = item:getVisual()
    if v then
        pcall(function() v:setBaseTexture(tone) end)
    end
    local okWear = pcall(function() target:setWornItem(locEyes, item) end)
    return okWear
end

-- Wear an entry on a live player (post-spawn). Uses the registered
-- location object, never the item's own lookup. Split graphics wear one
-- item per eye slot; third-party single-slot entries wear one item.
-- rightIndex is the right eye's pick and is only used when the character
-- has the heterochromia trait.
function hydEyesData.wearOn(player, index, rightIndex, typeIndex, heightIndex, lashIndex)
    return hydEyesData.wearColors(player, index, rightIndex, false,
        typeIndex, heightIndex, lashIndex)
end

-- Split left/right items: one per color x sex x side, each carrying the
-- shape x height textures (shape-major, low/normal/high).
local function eye(color, code)
    hydEyesData.AddEye({
        labelKey = "IGUI_Detail_Eyes" .. color,
        maleL = "hydEyes.Detail_Eyes" .. color .. "ML",
        maleR = "hydEyes.Detail_Eyes" .. color .. "MR",
        femaleL = "hydEyes.Detail_Eyes" .. color .. "FL",
        femaleR = "hydEyes.Detail_Eyes" .. color .. "FR",
        layered = true,
        splitTextures = hydEyesData.eyeTextureCount(),
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
