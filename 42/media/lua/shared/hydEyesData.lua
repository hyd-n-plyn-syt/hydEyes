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
-- This pack's 12 colors map at shared single textures for now.

hydEyesData = hydEyesData or { Eyes = {} }

function hydEyesData.AddEye(entry)
    if type(entry) ~= "table" then return end
    if type(entry.male) ~= "string" and type(entry.female) ~= "string" then return end
    table.insert(hydEyesData.Eyes, entry)
end

-- Wearer's item for this entry: sex fit, then skin-tone texture.
function hydEyesData.itemFor(entry, isFemale, skinIndex)
    if not entry then return nil, 0 end
    local item = (isFemale and entry.female) or entry.male or entry.female
    local count = entry.textures or 1
    local tone = math.max(0, math.min(skinIndex or 0, count - 1))
    return item, tone
end

-- Wear an entry on a live player (post-spawn). Uses the registered
-- location object, never the item's own lookup.
function hydEyesData.wearOn(player, index)
    local entry = hydEyesData.Eyes and hydEyesData.Eyes[index]
    local loc = hydEyesLocation and hydEyesLocation["hydeyes:eyes"]
    if not entry or not loc or not player then return false end
    local okF, isFemale = pcall(function() return player:isFemale() end)
    local okV, visual = pcall(function() return player:getHumanVisual() end)
    local skin = 0
    if okV and visual then
        local okI, i = pcall(function() return visual:getSkinTextureIndex() end)
        if okI and type(i) == "number" then skin = i end
    end
    local fullType, tone = hydEyesData.itemFor(entry, isFemale, skin)
    if not fullType then return false end
    local ok, item = pcall(instanceItem, fullType)
    if not ok or not item then return false end
    local v = item:getVisual()
    if v and tone > 0 then
        pcall(function() v:setTextureChoice(tone) end)
        pcall(function() v:setBaseTexture(tone) end)
    end
    local okWear = pcall(function() player:setWornItem(loc, item) end)
    return okWear
end

local function eye(color, code)
    hydEyesData.AddEye({
        labelKey = "IGUI_Detail_Eyes" .. color,
        male = "hydEyes.Detail_Eyes" .. color .. "M",
        female = "hydEyes.Detail_Eyes" .. color .. "F",
        textures = 1,
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
