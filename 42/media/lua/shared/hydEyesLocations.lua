-- The mod's own body locations. Lowercase ids match vanilla/CU convention
-- exactly (base:*, casualtiesundead:*), so script parsing and the runtime
-- registry agree on it.
require("NPCs/BodyLocations")

hydEyesLocation = hydEyesLocation or {}

local group = BodyLocations.getGroup("Human")

local function addLocation(name)
    local ok, loc = pcall(function() return ItemBodyLocation.register(name) end)
    if not ok or loc == nil then
        print("[hydEyes] failed to register body location: " .. tostring(name))
        return
    end
    hydEyesLocation[name] = loc
    pcall(function() group:getOrCreateLocation(loc) end)
    pcall(function() group:moveLocationToIndex(loc, 0) end)
end

-- Register the eye and lash slots. They are added in reverse draw order
-- because addLocation() moves each new location to index 0; the final group
-- order is therefore eyes -> lashes, which is the order the renderer draws
-- them in (eyes first, lashes on top).
-- hydeyes:eyes        : legacy/original single-eye location (third-party packs)
-- hydeyes:lefteye     : left eye colour layer
-- hydeyes:righteye    : right eye colour layer
-- hydeyes:leftlash    : left eyelash layer
-- hydeyes:rightlash   : right eyelash layer
addLocation("hydeyes:rightlash")
addLocation("hydeyes:leftlash")
addLocation("hydeyes:righteye")
addLocation("hydeyes:lefteye")
addLocation("hydeyes:eyes")

-- Body visuals are drawn in body-location order, so a custom face worn on
-- SPNCC:Face (Spongie's Character Customisation, and Tomb's Player Body
-- which is built on it) or on betterbodies:face (Better Bodies) is drawn
-- over the eyes while the eye slots sit behind it. When one of those mods
-- is present, the eye slots are moved behind their face location so the
-- eyes end up on top of the custom face.
--
-- The Better Bodies "Faces (for Spongie's Character Customisation)" addon
-- puts its faces on SPNCC:Face, so it is covered by the same entry.
local function customFaceLocations()
    local faces = {}
    local ok, spn = pcall(function() return SPNCC end)
    if ok and type(spn) == "table" and spn.ItemBodyLocation
        and spn.ItemBodyLocation.Face then
        faces[#faces + 1] = spn.ItemBodyLocation.Face
    end
    local okB, better = pcall(function() return BetterBodies end)
    if okB and type(better) == "table" and better.ItemBodyLocation
        and better.ItemBodyLocation.Face then
        faces[#faces + 1] = better.ItemBodyLocation.Face
    end
    return faces
end

local function moveEyesBehindCustomFaces()
    local faces = customFaceLocations()
    if #faces == 0 then return end

    -- Where the face locations sit in the group right now.
    local function lastFaceIndex()
        local best = nil
        local okAll, all = pcall(function() return group:getAllLocations() end)
        for _, face in ipairs(faces) do
            local index = nil
            local okIndex, found = pcall(function() return group:indexOf(face) end)
            if okIndex and type(found) == "number" then
                index = found
            elseif okAll and type(all) == "table" then
                for i, loc in ipairs(all) do
                    if loc == face then index = i break end
                end
            end
            if index and (not best or index > best) then best = index end
        end
        return best
    end

    -- Desired draw order after the face: eyes, then lashes. Moving the
    -- slots to the same index in reverse order leaves them in that order.
    local order = {
        "hydeyes:eyes",
        "hydeyes:lefteye",
        "hydeyes:righteye",
        "hydeyes:leftlash",
        "hydeyes:rightlash",
    }
    for i = #order, 1, -1 do
        local loc = hydEyesLocation[order[i]]
        if loc then
            -- The index shifts as each slot moves, so read it every time.
            local index = lastFaceIndex()
            if index then
                pcall(function() group:moveLocationToIndex(loc, index + 1) end)
            end
        end
    end
end

moveEyesBehindCustomFaces()

-- Their lua may load after ours, so try again once the game is up.
if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(moveEyesBehindCustomFaces) end
    if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(moveEyesBehindCustomFaces) end
end
