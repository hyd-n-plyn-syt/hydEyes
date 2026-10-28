-- Optional compat for other mods' character renders. Conditional only: each
-- patch installs itself when its target is present and stays dormant
-- otherwise.
--
-- Covered:
--   * GridCharacterHub health model: its buildDesc copies the player's
--     HumanVisual but only keeps underwear/bandage/wound worn items, so the
--     eye, lash and overlay slots are dropped. The patch keeps those slots
--     as well.
--   * ItIsOfInterestToMe ID card photo: its desc is built from skin/hair/
--     beard only (worn items are cleared), so the eyes and lashes are
--     re-worn onto it. The patch copies the player's eye/lash items live
--     plus a snapshot (fullType + tint + base texture) in the item's modData
--     so rebuilds restore them. Random NPC cards have no source look and
--     stay vanilla.
--   * ItIsOfInterestToMe printed eye color: the player's OWN card (tagged
--     iioitmIsOwnCard by that mod) prints their worn eye's registry code,
--     left eye first — a heterochromia character prints both ("BLU/GRN").
--     Frozen once written.
--   * Spongie's Character Customisation and Tomb's Player Body: their face
--     art is worn on SPNCC:Face and is drawn over our eye overlay. The
--     appearance screen re-applies our layers after they refresh the preview.
--   * Hyde Co. Character Creator: it hides vanilla's body/hair/beard rows and
--     lifts the voice block up under the name, which is where our Eyes section
--     goes. The eyes are put on top there and the voice block is moved down
--     below them.
--   * Project Spongie-Life / Project A-Life: handled in its own file,
--     hydEyesPSLSetup.lua, because it carries the face sheet that decides
--     which eyes each NPC face rolls and is meant to be edited by hand.
--
-- Left and right eyes are two separate items on two body locations
-- (hydeyes:lefteye / hydeyes:righteye), the lashes have their own pair
-- (hydeyes:leftlash / hydeyes:rightlash), and each runtime overlay is the
-- same item stacked on six slots per side (hydeyes:leftinfected,
-- hydeyes:leftinfected2..6 and hydeyes:leftbloodshot,
-- hydeyes:leftbloodshot2..6, plus the right equivalents). Every patch below
-- therefore uses the worn entry's own body location instead of resolving the
-- slot from the item type, which would collapse all six layers onto one slot.

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
            fn(item, wi)
        end
    end
end

local function locationFor(fullType)
    if not (hydEyesData and hydEyesData.locationFor) then
        return hydEyesLocation and hydEyesLocation["hydeyes:eyes"] or nil
    end
    return hydEyesLocation and hydEyesLocation[hydEyesData.locationFor(fullType)] or nil
end

-- The body location of one worn entry. The entry's own location is used
-- because the six stacked overlay layers all hold the same item type, and
-- locationFor() would send every one of them to the first layer's slot.
local function wornLocation(wi, fullType)
    if wi then
        local okLoc, loc = pcall(function() return wi:getLocation() end)
        if okLoc and loc then return loc end
    end
    return locationFor(fullType)
end

-- Body location id of one worn entry, for the snapshot table.
local function wornLocationId(wi, fullType)
    if wi then
        local okLoc, loc = pcall(function() return wi:getLocation() end)
        if okLoc and loc then
            local okId, id = pcall(function() return loc:getId() end)
            if okId and type(id) == "string" then return id end
        end
    end
    return hydEyesData and hydEyesData.locationFor and hydEyesData.locationFor(fullType)
        or "hydeyes:eyes"
end

local function copyLiveEyes(player, desc)
    if not (player and desc) then return end
    eachEyeItem(player, function(item, wi)
        local loc = wornLocation(wi, item:getFullType())
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
    eachEyeItem(player, function(item, wi)
        local fullType = item:getFullType()
        local entry = {
            type = fullType,
            loc = wornLocationId(wi, fullType),
        }
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
                -- A snapshot with no location falls back to the type's first
                -- slot.
                local loc = type(e.loc) == "string" and hydEyesLocation[e.loc] or nil
                if not loc then loc = locationFor(e.type) end
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

-- The eye codes of a character, left eye first, so a heterochromia
-- character prints both ("BLU/GRN").
local function wornEyeCodes(player)
    local codes = {}
    eachEyeItem(player, function(item)
        local fullType = item:getFullType()
        if not (hydEyesData and hydEyesData.codeFor) then return end
        local code = hydEyesData.codeFor(fullType)
        if not code then return end
        local slot = "hydeyes:eyes"
        if hydEyesData.locationFor then
            slot = hydEyesData.locationFor(fullType) or slot
        end
        local order = 1
        if slot == "hydeyes:righteye" then
            order = 2
        end
        codes[#codes + 1] = { order = order, code = code }
    end)
    table.sort(codes, function(a, b) return a.order < b.order end)
    local parts = {}
    for _, entry in ipairs(codes) do
        parts[#parts + 1] = entry.code
    end
    return table.concat(parts, "/")
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
                local code = wornEyeCodes(player)
                if code and code ~= "" then
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
    eachEyeItem(patient, function(item, wi)
        local loc = wornLocation(wi, item:getFullType())
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

-- Spongie's Character Customisation screen has its own preview survivor and
-- wears their customisation items on it, so our eyes are not part of that
-- preview. Their panel pushes the desc to the main avatar first (with every
-- customisation item on it), then strips the desc down to just the face for
-- the small portraits. So the eyes go on before each of those pushes.
local function applyEyesToPreview(desc)
    if not desc then return end
    local left = hydEyesChoices and hydEyesChoices[0] or hydEyesChoice or 1
    local right = hydEyesRightChoices and hydEyesRightChoices[0]
        or hydEyesRightChoice or left
    local typ = hydEyesTypeChoices and hydEyesTypeChoices[0]
        or hydEyesTypeChoice or (hydEyesData.DefaultTypeIndex or 1)
    local height = hydEyesHeightChoices and hydEyesHeightChoices[0]
        or hydEyesHeightChoice or (hydEyesData.DefaultHeightIndex or 1)
    local lash = hydEyesLashChoices and hydEyesLashChoices[0]
        or hydEyesLashChoice
    if hydEyesData and hydEyesData.wearColors then
        -- The preview survivor carries no traits, so the right eye is applied
        -- as picked (heterochromia included).
        pcall(function()
            hydEyesData.wearColors(desc, left, right, true, typ, height, lash)
        end)
    end
end

local function hookCustomisationPreview()
    if type(CharacterCustomisationPanel) == "table" then
        for _, name in ipairs({ "setAvatarDescs", "applyVisual" }) do
            local original = CharacterCustomisationPanel[name]
            if type(original) == "function"
                and not CharacterCustomisationPanel["hydEyesWrapped_" .. name] then
                CharacterCustomisationPanel["hydEyesWrapped_" .. name] = true
                CharacterCustomisationPanel[name] = function(self, ...)
                    -- Before the original: the push it does must include the
                    -- eyes, and the desc it leaves behind (face only) must
                    -- have them on for the small portraits.
                    pcall(function() applyEyesToPreview(self.previewDesc) end)
                    return original(self, ...)
                end
            end
        end
    end
    if type(BodyDetailAvatar) == "table" then
        local original = BodyDetailAvatar.applyVisual
        if type(original) == "function"
            and not BodyDetailAvatar.hydEyesPreviewHooked then
            BodyDetailAvatar.hydEyesPreviewHooked = true
            BodyDetailAvatar.applyVisual = function(self, selectedFace, ...)
                pcall(function() applyEyesToPreview(self.desc) end)
                return original(self, selectedFace, ...)
            end
        end
    end
end

-- Hyde Co. Character Creator lifts vanilla's voice block up under the name,
-- which is the slot our Eyes section takes. The eyes stay on top: the block
-- moves up to the voice's place and the voice block follows it down.
local HYDE_VOICE_WIDGETS = {
    "voiceLbl", "voiceRect", "voiceTypeLbl", "voiceTypeCombo",
    "voicePitchLbl", "voicePitchSlider", "voiceDemoButton",
}

local HYDE_EYE_WIDGETS = {
    "hydEyesSectionLbl", "hydEyesSectionRect",
    "hydEyesShapeLbl", "hydEyesShapeCombo",
    "hydEyesHeightLbl", "hydEyesHeightCombo",
    "hydEyesLashLbl", "hydEyesLashCombo",
    "hydEyesLbl", "hydEyesCombo",
    "hydEyesRightLbl", "hydEyesRightCombo",
}

local function widgetY(widget)
    if not (widget and widget.getY) then return nil end
    local ok, y = pcall(function() return widget:getY() end)
    if ok and type(y) == "number" then return y end
    return nil
end

local function moveWidgets(screen, names, dy)
    if dy == 0 then return end
    for _, name in ipairs(names) do
        local widget = screen[name]
        if widget and widget.getY and widget.setY then
            pcall(function() widget:setY(widget:getY() + dy) end)
        end
    end
end

-- Spongie's Character Customisation adds its "Change Appearance" button to the
-- same column. It belongs under the voice block, not wherever the rows we
-- pushed down left it.
local function placeCustomisationButton(screen)
    local button = screen.customisationButton
    if not (button and button.getY and button.setY) then return end
    local low = 0
    for _, name in ipairs(HYDE_VOICE_WIDGETS) do
        local widget = screen[name]
        if widget and widget.getBottom then
            local ok, bottom = pcall(function() return widget:getBottom() end)
            if ok and type(bottom) == "number" and bottom > low then
                low = bottom
            end
        end
    end
    if low <= 0 then return end
    local want = low + 16
    local now = widgetY(button)
    if now and math.abs(now - want) > 0.5 then
        pcall(function() button:setY(want) end)
    end
end

-- The upper column shows everything it holds -- name, eyes, voice and
-- Spongie's button -- without a scrollbar of its own. Its height is handed to
-- the Hyde Co. stack as the name section's, so their column starts below it.
local function fitUpperPanel(screen)
    local panel = screen.characterPanel
    if not (panel and panel.children) then return end
    local low = 0
    pcall(function()
        for _, child in pairs(panel.children) do
            if child and child ~= panel.vscroll and child ~= panel.hscroll
                and child.getBottom and child.getIsVisible
                and child:getIsVisible() then
                local h = child.getHeight and child:getHeight() or 0
                if type(h) == "number" and h > 4 then
                    local bottom = child:getBottom()
                    if type(bottom) == "number" and bottom > low then
                        low = bottom
                    end
                end
            end
        end
    end)
    if low <= 0 then return end
    local needed = math.floor(low + 16)
    local LD = HydeCoCharacterCreatorPlus
    if type(LD) == "table" and LD.Stage
        and math.abs((LD.Stage.nameContentH or 0) - needed) > 1 then
        LD.Stage.nameContentH = needed
    end
    local okH, height = pcall(function() return panel:getHeight() end)
    if okH and type(height) == "number" and math.abs(height - needed) > 1 then
        pcall(function() panel:setHeight(needed) end)
    end
end

-- Idempotent: once the eyes sit where the voice block was and the voice block
-- sits under them, every call is a no-op. Runs from the voice lift, which
-- their panel calls every frame.
local function arrangeEyesAboveVoice(screen)
    if not screen or not screen.voiceLbl or not screen.hydEyesSectionLbl then
        return
    end
    local blockH = screen.hydEyesShift
    local voiceY = widgetY(screen.voiceLbl)
    local headerY = widgetY(screen.hydEyesSectionLbl)
    if type(blockH) ~= "number" or not voiceY or not headerY then return end

    if headerY > voiceY then
        moveWidgets(screen, HYDE_EYE_WIDGETS, voiceY - headerY)
        screen.hydEyesInsertY = voiceY
        headerY = voiceY
    end
    -- The voice block belongs directly under the eyes.
    local wantVoiceY = headerY + blockH
    local nowVoiceY = widgetY(screen.voiceLbl)
    if nowVoiceY and nowVoiceY < wantVoiceY then
        moveWidgets(screen, HYDE_VOICE_WIDGETS, wantVoiceY - nowVoiceY)
    end

    placeCustomisationButton(screen)
    fitUpperPanel(screen)
end

local function hookHydeCo()
    if type(HydeCoCCPClothingPanel) ~= "table" then return end
    local original = HydeCoCCPClothingPanel.liftVoice
    if type(original) ~= "function"
        or HydeCoCCPClothingPanel.hydEyesVoiceHooked then
        return
    end
    HydeCoCCPClothingPanel.hydEyesVoiceHooked = true
    HydeCoCCPClothingPanel.liftVoice = function(self, ...)
        local result = original(self, ...)
        pcall(arrangeEyesAboveVoice, self and self.screen)
        return result
    end
end

local function TryInstall()
    hookGrid()
    hookIDCards()
    hookIDCardDetails()
    hookModelDesc()
    hookGridPanel()
    hookCustomisationPreview()
    hookHydeCo()
end

TryInstall()
if Events then
    if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(TryInstall) end
    if Events.OnGameBoot then Events.OnGameBoot.Add(TryInstall) end
end
