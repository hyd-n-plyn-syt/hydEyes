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

-- Register three eye-related locations:
-- hydeyes:eyes  : fallback/original single-eye location
-- hydeyes:lefteye : new left eye slot
-- hydeyes:righteye : new right eye slot
addLocation("hydeyes:eyes")
addLocation("hydeyes:lefteye")
addLocation("hydeyes:righteye")
