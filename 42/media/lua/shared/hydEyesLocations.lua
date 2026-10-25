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

-- Register the eye, lash and overlay slots. They are added in reverse draw
-- order because addLocation() moves each new location to index 0; the final
-- group order is therefore eyes -> lashes -> infected 1..6 -> bloodshot 1..6,
-- which is the order the renderer draws them in. Each overlay layer is the
-- same item on its own slot, so the transparent art builds up; the infected
-- (yellow) layers sit under the bloodshot (red) ones.
-- hydeyes:eyes            : legacy/original single-eye location (third-party packs)
-- hydeyes:lefteye         : left eye colour layer
-- hydeyes:righteye        : right eye colour layer
-- hydeyes:leftlash        : left eyelash layer
-- hydeyes:rightlash       : right eyelash layer
-- hydeyes:*infected[2-6]  : stacked infected overlays, layer 1 first
-- hydeyes:*bloodshot[2-6] : stacked bloodshot overlays, layer 1 first
for layer = 6, 1, -1 do
    addLocation("hydeyes:rightbloodshot" .. (layer > 1 and layer or ""))
    addLocation("hydeyes:leftbloodshot" .. (layer > 1 and layer or ""))
end
for layer = 6, 1, -1 do
    addLocation("hydeyes:rightinfected" .. (layer > 1 and layer or ""))
    addLocation("hydeyes:leftinfected" .. (layer > 1 and layer or ""))
end
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

    -- Desired draw order after the face: eyes, lashes, then the infected
    -- layers 1..6, then the bloodshot layers 1..6. Moving the slots to the
    -- same index in reverse order leaves them in that order.
    local order = {
        "hydeyes:eyes",
        "hydeyes:lefteye",
        "hydeyes:righteye",
        "hydeyes:leftlash",
        "hydeyes:rightlash",
    }
    local infectedLayers = hydEyesData and hydEyesData.InfectedLayers or 6
    local bloodshotLayers = hydEyesData and hydEyesData.BloodshotLayers or 6
    for layer = 1, infectedLayers do
        local suffix = layer > 1 and layer or ""
        order[#order + 1] = "hydeyes:leftinfected" .. suffix
        order[#order + 1] = "hydeyes:rightinfected" .. suffix
    end
    for layer = 1, bloodshotLayers do
        local suffix = layer > 1 and layer or ""
        order[#order + 1] = "hydeyes:leftbloodshot" .. suffix
        order[#order + 1] = "hydeyes:rightbloodshot" .. suffix
    end
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
