-- Optional compat for other mods' character renders. Conditional only: each
-- patch installs itself when its target is present and stays dormant
-- otherwise.
--
-- Covered:
--   * GridCharacterHub health model: its buildDesc copies the player's
--     HumanVisual but only keeps underwear/bandage/wound worn items, so eye
--     overlays are dropped. Fixed by also keeping the eye slots.
--   * ItIsOfInterestToMe ID card photo: its desc is built from skin/hair/
--     beard only (worn items are cleared), so the eyes are re-worn onto it.
--     Fixed by copying the player's eye items live plus a snapshot
--     (fullType + tint + base texture) in the item's modData so rebuilds
--     restore it. Random NPC cards have no source look and stay vanilla.
--   * ItIsOfInterestToMe printed eye color: the player's OWN card (tagged
--     iioitmIsOwnCard by that mod) prints their worn eye's registry code.
--     Frozen once written.
--
-- Left and right eyes are two separate items on two body locations
-- (hydeyes:lefteye / hydeyes:righteye), so every patch below resolves the
-- slot per item instead of assuming one eye slot. Whatever the player is
-- wearing is copied: the split graphics by default, the original combined
-- art when the Mod Options fallback is on.

require("hydEyesData")

local SNAP_KEY = "hydEyesSnap"
local EYE_SNAP_KEY = "hydEyesEyeCodeSet"

local function isEyeItem(item)
    if not item then return false end
    local ok, fullType = pcall(function() return item:getFullType() end)
    if not ok or not fullType then return false end
    return hydEyesData.isEyeType(fullType)
end

local function eachEyeItem(player, fn)
    local ok, worn = pcall(function() return player:getWornItems() end)
    if not ok or not worn then return end
    for i = 0, worn:size() - 1 do
        local okItem, wi = pcall(function() return worn:get(i) end)
        local item = okItem and wi and wi:getItem()
        if isEyeItem(item) then
            fn(item)
        end
    end
end

local function locationFor(fullType)
    if not (hydEyesData and hydEyesData.locationFor) then
        return hydEyesLocation and hydEyesLocation["hydeyes:eyes"] or nil
    end
    return hydEyesLocation and hydEyesLocation[hydEyesData.locationFor(fullType)] or nil
end

local function copyLiveEyes(player, desc)
    if not (player and desc) then return end
    eachEyeItem(player, function(item)
        local loc = locationFor(item:getFullType())
        if loc then pcall(function() desc:setWornItem(loc, item) end) end
    end)
end

local function readFloatColor(c)
    if not c then return nil end
    local okR, r = pcall(function() return c:getRedFloat() end)
    local okG, g = pcall(function() return c:getGreenFloat() end)
    local okB, b = pcall(function() return c:getBlueFloat() end)
    if okR and okG and okB then return { r, g, b } end
    return nil
end

local function snapshotPlayer(player)
    local list = {}
    eachEyeItem(player, function(item)
        local entry = { type = item:getFullType() }
        local okV, v = pcall(function() return item:getVisual() end)
        if okV and v then
            local okT, tint = pcall(function() return v:getTint() end)
            if okT then entry.tint = readFloatColor(tint) end
            -- The skin tone lives in the base texture list. The texture
            -- choice list is not used by these items, so it is not stored.
            local okB, bt = pcall(function() return v:getBaseTexture() end)
            if okB and type(bt) == "number" then entry.base = bt end
        end
        table.insert(list, entry)
    end)
    return list
end

local function applySnapshot(desc, snap)
    if type(snap) ~= "table" then return end
    for _, e in ipairs(snap) do
        if type(e) == "table" and type(e.type) == "string" then
            local ok, item = pcall(instanceItem, e.type)
            if ok and item then
                local loc = locationFor(e.type)
                if loc then
                    local v = item:getVisual()
                    if v then
                        if type(e.tint) == "table" then
                            pcall(function()
                                v:setTint(ImmutableColor.new(e.tint[1], e.tint[2], e.tint[3], 1))
                            end)
                        end
                        if type(e.base) == "number" and v.setBaseTexture then
                            pcall(function() v:setBaseTexture(e.base) end)
                        end
                    end
                    pcall(function() desc:setWornItem(loc, item) end)
                end
            end
        end
    end
end

local function wornEyeCode(player)
    local code = nil
    eachEyeItem(player, function(item)
        if code then return end
        code = hydEyesData and hydEyesData.codeFor
            and hydEyesData.codeFor(item:getFullType()) or nil
    end)
    return code
end

-- GridCharacterHub: keep eye overlays on the health-view model.
local function hookGrid()
    local ok, Compat = pcall(require, "GridInvMedical_CompatCU")
    if not ok or type(Compat) ~= "table"
        or type(Compat.keepOnModel) ~= "function" then
        return
    end
    if Compat.hydEyesWrapped then return end
    Compat.hydEyesWrapped = true
    local original = Compat.keepOnModel
    Compat.keepOnModel = function(locId, ...)
        if type(locId) == "string" then
            if string.find(string.lower(tostring(locId)), "^hydeyes:") then
                return true
            end
        end
        return original(locId, ...)
    end
end

-- ItIsOfInterestToMe: dress the player's ID photo in their eyes.
local function hookIDCards()
    if type(IDCardAppearance) ~= "table"
        or type(IDCardAppearance.getOrAssignForPlayer) ~= "function" then
        return
    end
    if IDCardAppearance.hydEyesWrapped then return end
    IDCardAppearance.hydEyesWrapped = true
    local original = IDCardAppearance.getOrAssignForPlayer
    IDCardAppearance.getOrAssignForPlayer = function(item, player, ...)
        local desc = original(item, player, ...)
        if desc and item and player then
            local ok, modData = pcall(function() return item:getModData() end)
            if ok and modData then
                local snap = modData[SNAP_KEY]
                if type(snap) == "table" and #snap > 0 then
                    applySnapshot(desc, snap)
                else
                    copyLiveEyes(player, desc)
                    local okSnap, fresh = pcall(snapshotPlayer, player)
                    if okSnap and type(fresh) == "table" and #fresh > 0 then
                        modData[SNAP_KEY] = fresh
                    end
                end
            else
                copyLiveEyes(player, desc)
            end
        end
        return desc
    end
end

-- ItIsOfInterestToMe: print the worn eye's registry code on the own card.
local function hookIDCardDetails()
    if type(IDCardDetails) ~= "table"
        or type(IDCardDetails.getOrAssign) ~= "function" then
        return
    end
    if IDCardDetails.hydEyesWrapped then return end
    IDCardDetails.hydEyesWrapped = true
    local original = IDCardDetails.getOrAssign
    IDCardDetails.getOrAssign = function(item, isFemale, player, ...)
        local details = original(item, isFemale, player, ...)
        if details and item and player then
            local ok, modData = pcall(function() return item:getModData() end)
            if ok and modData and modData.iioitmIsOwnCard == true
                and not modData[EYE_SNAP_KEY] then
                local code = wornEyeCode(player)
                if code then
                    details.eyes = code
                    modData[EYE_SNAP_KEY] = true
                end
            end
        end
        return details
    end
end

-- GridCharacterHub model reinjection: buildDesc drops everything but
-- underwear/bandages/wounds before our items are even visible to its filter,
-- so re-wear the patient's eyes on the model's desc after every rebuild.
-- Hooked per panel instance via module-level Style.apply (safe to wrap late);
-- the desc is tracked with a stash on setSurvivorDesc (dynamic dispatch,
-- also late-safe). Injection re-pushes the desc once per rebuild only.
local function reInjectGridEyes(panel)
    local av = panel._gimModel
    if not av then return end
    local desc = av._hydDesc
    if not desc or av._hydLastDesc == desc then return end
    local patient = nil
    if type(panel.getPatient) == "function" then
        local ok, p = pcall(function() return panel:getPatient() end)
        if ok then patient = p end
    end
    if not patient then return end
    local injected = false
    eachEyeItem(patient, function(item)
        local loc = locationFor(item:getFullType())
        if loc and pcall(function() desc:setWornItem(loc, item) end) then
            injected = true
        end
    end)
    if injected then
        pcall(function() av:setSurvivorDesc(desc) end)
        av._hydLastDesc = desc
    end
end

local function hookModelDesc()
    if type(ISUI3DModel) ~= "table"
        or type(ISUI3DModel.setSurvivorDesc) ~= "function" then
        return
    end
    if ISUI3DModel.hydEyesWrapped then return end
    ISUI3DModel.hydEyesWrapped = true
    local original = ISUI3DModel.setSurvivorDesc
    ISUI3DModel.setSurvivorDesc = function(self, desc, ...)
        if self then self._hydDesc = desc end
        return original(self, desc, ...)
    end
end

local function hookGridPanel()
    local ok, Style = pcall(require, "GridInvMedical_Style")
    if not ok or type(Style) ~= "table"
        or type(Style.apply) ~= "function" then
        return
    end
    if Style.hydEyesWrapped then return end
    Style.hydEyesWrapped = true
    local originalApply = Style.apply
    Style.apply = function(panel, ...)
        originalApply(panel, ...)
        if panel and type(panel.render) == "function"
            and not panel.hydEyesWrapped then
            panel.hydEyesWrapped = true
            local baseRender = panel.render
            panel.render = function(self)
                baseRender(self)
                pcall(reInjectGridEyes, self)
            end
        end
    end
end

local function TryInstall()
    hookGrid()
    hookIDCards()
    hookIDCardDetails()
    hookModelDesc()
    hookGridPanel()
end

TryInstall()
if Events then
    if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(TryInstall) end
    if Events.OnGameBoot then Events.OnGameBoot.Add(TryInstall) end
end
