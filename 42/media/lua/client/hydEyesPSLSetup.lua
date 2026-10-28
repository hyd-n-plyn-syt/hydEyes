-- Project Spongie-Life / Project A-Life setup. This is the file to edit.
--
-- NPC_FACE_EYES below is the face sheet: which eye shape and height each
-- Spongie face rolls. Everything else in this file is the wiring that puts our
-- eyes and lashes on A-Life NPCs (layered over the Spongie face like a
-- player's) and adds the EYES section to A-Life's NPC creator. It installs
-- itself only when Project Spongie-Life is loaded.
--
-- Face sheet format:
--   FaceName = { { shape = 1-4, height = 1-3 }, ... }
-- Duplicate an entry to weight it. Leave a face out and both roll. Face names
-- are the bracketed ones in the creator's FACE dropdown. Colours always roll
-- (2% heterochromia); lashes stay short for men, long for women.
--
-- ---------------------------------------------------------------------------
-- Project Spongie-Life / Project A-Life: eyes on NPCs and in the NPC creator
-- ---------------------------------------------------------------------------
-- A-Life dresses every NPC from a clothing plan of { slot, itemType, tint }
-- entries. Our eyes and lashes are ordinary worn items on their own body
-- slots, so they ride the same plan: the eye items land on hydeyes:lefteye /
-- hydeyes:righteye and the lash items on hydeyes:leftlash / hydeyes:rightlash,
-- above the Spongie face and below nothing else. The tint carries the texture
-- index (A-Life would otherwise pick a random base texture), which the
-- prepareClothing wrapper reads back.
--
-- An NPC's eyes come from, in order: the A-Life creator's EYES section (saved
-- on the profile as moduleOverrides.hydEyes), the face-name weight sheet
-- below, then a seeded roll so the same NPC keeps the same eyes across
-- respawns. Males get short lashes, females long, and 2% of rolled NPCs get
-- heterochromia with two random colours.

local NPC_EYE_MARKER = "hydEyes:"

-- Face name -> list of { shape = eye shape index, height = height index }.
-- Duplicate an entry to weight it. A face that is not listed rolls both.
-- Example:
--   Bob = { { shape = 2, height = 2 }, { shape = 3, height = 1 } },
local NPC_FACE_EYES = {
}

local function npcEyeText(key, fallback)
    local value = type(getText) == "function" and getText(key) or nil
    if type(value) ~= "string" or value == key then return fallback end
    return value
end

local function npcEyeHash(seed, count)
    if type(count) ~= "number" or count < 1 then return 1 end
    local hash = 17
    seed = tostring(seed or "")
    for index = 1, #seed do
        hash = (hash * 131 + string.byte(seed, index)) % 2147483647
    end
    return (hash % count) + 1
end

-- Profile picks, stored as "left,right,shape,height,lash,hetero" with 0
-- meaning automatic (weight sheet or seeded roll).
local function npcEyeConfig(profile)
    local stored = profile and profile.moduleOverrides
        and profile.moduleOverrides.hydEyes
    local left, right, shape, height, lash, hetero = string.match(
        tostring(stored or ""), "^(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$")
    return {
        left = tonumber(left) or 0, right = tonumber(right) or 0,
        shape = tonumber(shape) or 0, height = tonumber(height) or 0,
        lash = tonumber(lash) or 0, hetero = tonumber(hetero) == 1,
    }
end

local function storeNpcEyeConfig(profile, config)
    if not profile then return end
    profile.moduleOverrides = profile.moduleOverrides or {}
    profile.moduleOverrides.hydEyes = table.concat({ config.left or 0,
        config.right or 0, config.shape or 0, config.height or 0,
        config.lash or 0, config.hetero and 1 or 0 }, ",")
end

-- Face name of the Spongie face worn in a clothing plan (nil when the NPC has
-- no Spongie face, or Spongie-Life is not loaded).
local function npcPlanFaceName(plan)
    local bridge = ALifeSPNCCTomb
    if type(bridge) ~= "table" or type(bridge.lookup) ~= "function" then
        return nil
    end
    for _, entry in ipairs(plan.clothing or {}) do
        local ok, data, kind = pcall(bridge.lookup, entry.itemType,
            plan.female == true)
        if ok and kind == "face" and type(data) == "table" then
            return data.name
        end
    end
    return nil
end

-- Face name chosen for a creator profile, from the SPNCC marker or the item.
local function npcProfileFaceName(profile, outfitId)
    local tints = profile and profile.outfitTints
        and profile.outfitTints[outfitId or "A"]
    local name = tints and tints.Faces
        and string.match(tostring(tints.Faces), "^ALifeSPNCCChoice:(.+)$")
    if name then return name end
    local outfit = profile and profile.outfits and profile.outfits[outfitId or "A"]
    local fullType = outfit and outfit.Faces
    local bridge = ALifeSPNCCTomb
    if type(fullType) == "string" and type(bridge) == "table"
        and type(bridge.lookup) == "function" then
        local ok, data, kind = pcall(bridge.lookup, fullType,
            profile.general and profile.general.female == true)
        if ok and kind == "face" and type(data) == "table" then
            return data.name
        end
    end
    return nil
end

-- Resolve one NPC's eyes: left/right colour, shape, height and lash index.
local function npcEyesFor(seed, female, faceName, config)
    local data = hydEyesData
    local shapeCount, heightCount = #data.Types, #data.Heights
    local shape, height = config.shape, config.height
    if shape <= 0 or height <= 0 then
        local sheet = faceName and NPC_FACE_EYES[faceName]
        if type(sheet) == "table" and #sheet > 0 then
            local pick = sheet[npcEyeHash(seed .. ":style", #sheet)]
            if type(pick) == "table" then
                if shape <= 0 then shape = tonumber(pick.shape) or 0 end
                if height <= 0 then height = tonumber(pick.height) or 0 end
            end
        end
    end
    if shape <= 0 then shape = npcEyeHash(seed .. ":shape", shapeCount) end
    if height <= 0 then height = npcEyeHash(seed .. ":height", heightCount) end
    shape = data.clampIndex(shape, shapeCount)
    height = data.clampIndex(height, heightCount)

    local colours = #data.Eyes
    local left = config.left > 0
        and data.clampIndex(config.left, colours)
        or npcEyeHash(seed .. ":left", colours)
    local hetero = config.hetero
    if not hetero and config.left <= 0 then
        hetero = npcEyeHash(seed .. ":hetero", 100) <= 2
    end
    local right = left
    if hetero and colours > 0 then
        right = config.right > 0
            and data.clampIndex(config.right, colours)
            or npcEyeHash(seed .. ":right", colours)
        if right == left and colours > 1 then right = (left % colours) + 1 end
    end
    local lash = config.lash > 0
        and data.clampIndex(config.lash, #data.LashLengths)
        or data.defaultLashIndex(female)
    return left, right, shape, height, lash
end

-- Plan entries for one resolved set of eyes. Each entry's tint carries the
-- base texture index the item has to be drawn with.
local function npcEyeEntries(female, left, right, shape, height, lash)
    local data = hydEyesData
    local entries = {}
    local colours = #data.Eyes
    if colours < 1 then return entries end
    local texture = data.eyeTextureIndex(shape, height)
    local leftEntry = data.Eyes[data.clampIndex(left, colours)]
    local rightEntry = data.Eyes[data.clampIndex(right, colours)] or leftEntry
    local leftType = data.itemFor(leftEntry, female, texture, "L")
    local rightType = data.itemFor(rightEntry, female, texture, "R")
    if leftType and rightType then
        entries[#entries + 1] = { slot = "hydeyes:lefteye",
            itemType = leftType, tint = NPC_EYE_MARKER .. texture }
        entries[#entries + 1] = { slot = "hydeyes:righteye",
            itemType = rightType, tint = NPC_EYE_MARKER .. texture }
    end
    local lashTexture = data.lashTextureIndex(shape, height, lash)
    if lashTexture then
        local lashL = data.lashItemFor(female, "L")
        local lashR = data.lashItemFor(female, "R")
        if lashL and lashR then
            entries[#entries + 1] = { slot = "hydeyes:leftlash",
                itemType = lashL, tint = NPC_EYE_MARKER .. lashTexture }
            entries[#entries + 1] = { slot = "hydeyes:rightlash",
                itemType = lashR, tint = NPC_EYE_MARKER .. lashTexture }
        end
    end
    return entries
end

local function npcEyeTexture(entry)
    return tonumber(string.match(tostring(entry and entry.tint or ""),
        "^hydEyes:(%d+)$"))
end

local function isNpcEyeSlot(slot)
    return slot == "hydeyes:lefteye" or slot == "hydeyes:righteye"
        or slot == "hydeyes:leftlash" or slot == "hydeyes:rightlash"
end

local npcEyePlanReported = false

-- Add the eyes to one clothing plan, replacing any previous copies so the
-- plan never stacks two sets.
local function dressPlanEyes(plan, profile)
    local data = hydEyesData
    if type(plan) ~= "table" or type(plan.clothing) ~= "table" then return end
    if type(data) ~= "table" or type(data.Eyes) ~= "table" or #data.Eyes < 1 then
        return
    end
    local kept = {}
    for _, entry in ipairs(plan.clothing) do
        if not (type(entry) == "table" and isNpcEyeSlot(entry.slot)) then
            kept[#kept + 1] = entry
        end
    end
    local seed = tostring(plan.appearanceSeed or plan.actorUid
        or plan.profileId or "")
    local left, right, shape, height, lash = npcEyesFor(seed,
        plan.female == true, npcPlanFaceName(plan), npcEyeConfig(profile))
    local eyes = npcEyeEntries(plan.female == true, left, right, shape, height,
        lash)
    for _, entry in ipairs(eyes) do kept[#kept + 1] = entry end
    plan.clothing = kept
    local hydrator = ProjectALife and ProjectALife.ProfileHydrator
    if hydrator and type(hydrator.renderOrder) == "function" then
        hydrator.renderOrder(kept)
    end
    if not npcEyePlanReported then
        npcEyePlanReported = true
        print(string.format("[hydEyes] NPC plan eyes: %d of %d entries",
            #eyes, #kept))
    end
end

local function hookALifeHydrator()
    local hydrator = ProjectALife and ProjectALife.ProfileHydrator
    if type(hydrator) ~= "table" or type(hydrator.plan) ~= "function" then
        return false
    end
    if hydrator.hydEyesInstalled then return true end
    hydrator.hydEyesInstalled = true
    print("[hydEyes] A-Life NPC dressing hooked")

    local originalPlan = hydrator.plan
    hydrator.plan = function(actor)
        local plan, reason = originalPlan(actor)
        if type(plan) == "table" and type(plan.clothing) == "table" then
            pcall(function()
                local profile = nil
                local catalog = ProjectALife.Catalog
                if catalog and type(catalog.npc) == "function" then
                    profile = catalog.npc(actor and actor.profileId
                        or plan.profileId)
                end
                dressPlanEyes(plan, profile)
            end)
        end
        return plan, reason
    end

    local originalPrepare = hydrator.prepareClothing
    if type(originalPrepare) == "function" then
        hydrator.prepareClothing = function(item, entry, seed)
            local visual = originalPrepare(item, entry, seed)
            local texture = npcEyeTexture(entry)
            if visual and texture then
                pcall(function() visual:setBaseTexture(texture) end)
                pcall(function() visual:setHue(0) end)
                local white = ImmutableColor
                    and (ImmutableColor.white or ImmutableColor.new(1, 1, 1, 1))
                if white then
                    pcall(function() visual:setTint(white) end)
                end
            end
            return visual
        end
    end

    -- A-Life sorts the plan by body-location rank before dressing it, and its
    -- rank lookup resolves to -1 for items whose location it cannot read — ours
    -- sit on custom slots, so they land at the front and the Spongie face is
    -- drawn over them. Keep them last in the list instead, whatever calls the
    -- sort (us, Spongie-Life's plan hook, or A-Life itself).
    local originalRenderOrder = hydrator.renderOrder
    if type(originalRenderOrder) == "function" then
        hydrator.renderOrder = function(entries)
            local result = originalRenderOrder(entries)
            if type(entries) ~= "table" or #entries < 2 then return result end
            local kept, eyes = {}, {}
            for _, entry in ipairs(entries) do
                if type(entry) == "table" and isNpcEyeSlot(entry.slot) then
                    eyes[#eyes + 1] = entry
                else
                    kept[#kept + 1] = entry
                end
            end
            if #eyes == 0 then return result end
            for _, entry in ipairs(eyes) do kept[#kept + 1] = entry end
            for index = 1, #entries do entries[index] = nil end
            for index, entry in ipairs(kept) do entries[index] = entry end
            return entries
        end
    end
    return true
end

-- Creator preview: the large avatar and the queued portrait panels all go
-- through submitPortrait, which is the one shared point where the descriptor
-- can be dressed.
local function decorateCreatorEyes(desc, profile, outfitId, seed)
    if not desc or type(desc.setWornItem) ~= "function" then return "" end
    local female = false
    pcall(function() female = desc:isFemale() == true end)
    local left, right, shape, height, lash = npcEyesFor(seed, female,
        npcProfileFaceName(profile, outfitId), npcEyeConfig(profile))
    local signature = {}
    for _, entry in ipairs(npcEyeEntries(female, left, right, shape, height,
        lash)) do
        -- Our items resolve their own body location to nil (they are on
        -- custom slots), so pass the registered location object instead.
        local location = hydEyesLocation and hydEyesLocation[entry.slot]
        local item = instanceItem(entry.itemType)
        local asset = item and item:getClothingItem()
        if location and item and item:getVisual() and asset and asset:isReady() then
            local texture = npcEyeTexture(entry)
            if texture then
                pcall(function() item:getVisual():setBaseTexture(texture) end)
            end
            desc:setWornItem(location, item)
            signature[#signature + 1] = entry.itemType .. ":" .. entry.tint
        end
    end
    return table.concat(signature, "|")
end

local function npcShapeOptions()
    local options = { { npcEyeText("IGUI_hydEyes_Automatic", "Automatic"), 0 } }
    for index, shape in ipairs(hydEyesData.Types) do
        options[#options + 1] = { tostring(shape), index }
    end
    return options
end

local function npcHeightOptions()
    local options = { { npcEyeText("IGUI_hydEyes_Automatic", "Automatic"), 0 } }
    for index, height in ipairs(hydEyesData.Heights) do
        options[#options + 1] = { npcEyeText(height.labelKey, height.key), index }
    end
    return options
end

local function npcLashOptions()
    local options = { { npcEyeText("IGUI_hydEyes_Automatic", "Automatic"), 0 } }
    for index, lash in ipairs(hydEyesData.LashLengths) do
        options[#options + 1] = { npcEyeText(lash.labelKey, lash.key), index }
    end
    return options
end

local function npcColourOptions()
    local options = { { npcEyeText("IGUI_hydEyes_Automatic", "Automatic"), 0 } }
    for index, entry in ipairs(hydEyesData.Eyes) do
        local text = npcEyeText(entry.labelKey, entry.label or entry.labelKey)
        options[#options + 1] = { string.match(text, "^Eyes (.+)$") or text, index }
    end
    return options
end

local function pageContentBottom(page)
    local bottom = 0
    pcall(function()
        for _, child in pairs(page.children or {}) do
            if child and child ~= page.vscroll and child ~= page.hscroll
                and child.getBottom and child.getIsVisible
                and child:getIsVisible() then
                local value = child:getBottom()
                if type(value) == "number" and value > bottom then
                    bottom = value
                end
            end
        end
    end)
    return bottom
end

local function creatorEyesKey(window)
    local profile = window and window.currentProfile
    if not profile then return "" end
    local outfitId = window.activeOutfit or "A"
    return table.concat({ tostring(profile.id),
        tostring(profile.general and profile.general.female), outfitId,
        tostring(profile.moduleOverrides and profile.moduleOverrides.hydEyes),
        tostring(npcProfileFaceName(profile, outfitId)) }, ":")
end

local function syncCreatorEyesLayout(creator, state)
    local hetero = state.tick and state.tick:isSelected(1) == true
    state.rightLbl:setVisible(hetero)
    state.rightCombo:setVisible(hetero)
    if state.colourLbl then
        state.colourLbl:setName(npcEyeText(hetero and "IGUI_hydEyes_LeftEye"
            or "IGUI_hydEyes_Eyes", hetero and "Left Eye Color" or "Eye Color"))
    end
    local px = creator.px
    local bottom = hetero and state.rightCombo:getY() + state.rightCombo:getHeight()
        or state.colourCombo:getY() + state.colourCombo:getHeight()
    state.card:setHeight(bottom + px(14))
    state.page:setScrollHeight(math.max(state.page.height,
        state.card:getY() + state.card:getHeight() + px(24)))
end

local function applyCreatorEyes(creator, state, window)
    local profile = window and window.currentProfile
    if not profile then return end
    local config = npcEyeConfig(profile)
    creator.selectData(state.shapeCombo, config.shape)
    creator.selectData(state.heightCombo, config.height)
    creator.selectData(state.lashCombo, config.lash)
    creator.selectData(state.colourCombo, config.left)
    creator.selectData(state.rightCombo, config.hetero and config.right or 0)
    state.tick:setSelected(1, config.hetero)
    syncCreatorEyesLayout(creator, state)
end

local function changedCreatorEyes(creator, state, window)
    local profile = window and window.currentProfile
    if not profile then return end
    local config = {
        left = tonumber(creator.selectedData(state.colourCombo)) or 0,
        shape = tonumber(creator.selectedData(state.shapeCombo)) or 0,
        height = tonumber(creator.selectedData(state.heightCombo)) or 0,
        lash = tonumber(creator.selectedData(state.lashCombo)) or 0,
        hetero = state.tick:isSelected(1) == true,
    }
    config.right = config.hetero
        and (tonumber(creator.selectedData(state.rightCombo)) or 0)
        or config.left
    storeNpcEyeConfig(profile, config)
    state.key = creatorEyesKey(window)
    creator.harvestProfile(window)
    creator.refreshAvatar(window)
end

local function buildCreatorEyes(creator, window, formW)
    local page = window and window.profilePages and window.profilePages.faces
    if not page then return end
    local px = creator.px
    local cardW = formW - px(8)
    local card = creator.addSectionCard(page, px(4),
        pageContentBottom(page) + px(16), cardW, px(300), "EYES",
        "Layered over the face like a player's. Automatic follows the face.")
    local state = { page = page, card = card }
    local x, width = px(12), cardW - px(24)
    local row = px(52)
    local y = px(50)

    creator.addLabel(card, x, y, npcEyeText("IGUI_hydEyes_Shape", "Eye Shape"),
        creator.palette.TEXT)
    state.shapeCombo = creator.addCombo(card, x, y + px(20), width,
        npcShapeOptions())
    y = y + row

    creator.addLabel(card, x, y, npcEyeText("IGUI_hydEyes_Height", "Eye Height"),
        creator.palette.TEXT)
    state.heightCombo = creator.addCombo(card, x, y + px(20), width,
        npcHeightOptions())
    y = y + row

    creator.addLabel(card, x, y, npcEyeText("IGUI_hydEyes_Lash", "Lashes"),
        creator.palette.TEXT)
    state.lashCombo = creator.addCombo(card, x, y + px(20), width,
        npcLashOptions())
    y = y + row

    state.tick = creator.addTick(card, x, y, width,
        npcEyeText("UI_trait_heterochromia", "Heterochromia"))
    y = y + px(30)

    state.colourLbl = creator.addLabel(card, x, y,
        npcEyeText("IGUI_hydEyes_Eyes", "Eye Color"), creator.palette.TEXT)
    state.colourCombo = creator.addCombo(card, x, y + px(20), width,
        npcColourOptions())
    y = y + row

    state.rightLbl = creator.addLabel(card, x, y,
        npcEyeText("IGUI_hydEyes_RightEye", "Right Eye Colour"),
        creator.palette.TEXT)
    state.rightCombo = creator.addCombo(card, x, y + px(20), width,
        npcColourOptions())

    for _, combo in ipairs({ state.shapeCombo, state.heightCombo,
        state.lashCombo, state.colourCombo, state.rightCombo }) do
        combo.target, combo.onChange = window, function()
            changedCreatorEyes(creator, state, window)
        end
    end
    state.tick.changeOptionTarget = state
    state.tick.changeOptionMethod = function(target)
        syncCreatorEyesLayout(creator, target)
        changedCreatorEyes(creator, target, window)
    end

    local originalPrerender = page.prerender
    page.prerender = function(self)
        if type(originalPrerender) == "function" then originalPrerender(self) end
        local key = creatorEyesKey(window)
        if state.key ~= key then
            state.key = key
            applyCreatorEyes(creator, state, window)
        end
    end
    page.hydEyes = state
    applyCreatorEyes(creator, state, window)
end

local function hookALifeCreator()
    local creator = ProjectALife and ProjectALife.CreatorScreen
    if type(creator) ~= "table" or type(creator.buildFacesPage) ~= "function"
        or creator.hydEyesFacesHooked then
        return
    end
    creator.hydEyesFacesHooked = true
    local originalBuild = creator.buildFacesPage
    creator.buildFacesPage = function(window, formW)
        local result = originalBuild(window, formW)
        local ok, err = pcall(buildCreatorEyes, creator, window, formW)
        if not ok then print("[hydEyes] creator eyes failed: " .. tostring(err)) end
        return result
    end

    local originalSubmit = creator.submitPortrait
    if type(originalSubmit) ~= "function" then return end
    creator.submitPortrait = function(panel)
        if panel and not panel.palSubmitted and panel.palDescriptor then
            local window = creator.window
            local profile = window
                and (window.itemPreviewProfile or window.currentProfile)
            local seed = tostring(profile and profile.id
                or panel.palSignature or "preview")
            local ok, signature = pcall(decorateCreatorEyes, panel.palDescriptor,
                profile, window and window.activeOutfit or "A", seed)
            if ok then
                panel.palSignature = tostring(panel.palSignature or "")
                    .. "|hydEyes:" .. signature
            end
        end
        return originalSubmit(panel)
    end
end

local function installALifeEyes()
    if type(ALifeSPNCCTomb) ~= "table" then return false end
    hookALifeCreator()
    if hookALifeHydrator() then
        if Events and Events.OnTick then Events.OnTick.Remove(installALifeEyes) end
    end
    return true
end

local spongieLifeStarted = false

local function hookSpongieLife()
    if type(ALifeSPNCCTomb) ~= "table" then return end
    if spongieLifeStarted then
        installALifeEyes()
        return
    end
    spongieLifeStarted = true
    installALifeEyes()
    if Events and Events.OnGameStart then
        Events.OnGameStart.Add(installALifeEyes)
    end
    if Events and Events.OnTick then Events.OnTick.Add(installALifeEyes) end
end

if Events then
    -- Spongie-Life replaces the creator's faces page from its own client file,
    -- so the hook waits for an event: every mod's files are loaded by then.
    if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(hookSpongieLife) end
    if Events.OnGameBoot then Events.OnGameBoot.Add(hookSpongieLife) end
end
hookSpongieLife()
