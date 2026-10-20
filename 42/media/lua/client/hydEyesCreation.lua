-- Eye color dropdown on the vanilla character creation screen, slid in
-- under the body divider:
--
--   * picking a color wears that eye item on the preview desc immediately
--     (hovering previews);
--   * the preview desc never spawns (stripped at Play), so each player's
--     recorded pick is worn post-spawn instead — per-player picks keyed by
--     player index, so splitscreen characters don't clobber each other;
--   * outfit randomize / gender change / the dice clear worn items, so the
--     current pick is re-applied after each of those;
--   * with the Heterochromia trait the single dropdown is replaced by two
--     (left and right) and the two sides can never share a color.
--
-- Third-party entries registered with hydEyesData.AddEye appear automatically
-- (options rebuild every time the creation screen is shown).

require("hydEyesData")

hydEyesChoice = hydEyesChoice or 1
hydEyesRightChoice = hydEyesRightChoice or 1
-- Per-player picks (splitscreen creates one character per player through
-- panels sharing one preview desc). Single-player only ever uses index 0.
hydEyesChoices = hydEyesChoices or {}
hydEyesRightChoices = hydEyesRightChoices or {}

-- Which player the open creation screen is building (0 in single-player).
local function activePlayerIndex()
    local ok, coop = pcall(function() return CoopCharacterCreation.instance end)
    if ok and coop and type(coop.playerIndex) == "number" then
        return coop.playerIndex
    end
    return 0
end

-- This panel's pick: its own field, else its player's recorded pick, else
-- the default. Keeps splitscreen panels from clobber each other.
local function panelChoiceIndex(creationMain)
    if creationMain and type(creationMain.hydEyesChoiceIndex) == "number" then
        return creationMain.hydEyesChoiceIndex
    end
    local recorded = hydEyesChoices[activePlayerIndex()]
    if type(recorded) == "number" then return recorded end
    return hydEyesChoice or 1
end

local function panelRightChoiceIndex(creationMain)
    if creationMain and type(creationMain.hydEyesRightChoiceIndex) == "number" then
        return creationMain.hydEyesRightChoiceIndex
    end
    local recorded = hydEyesRightChoices[activePlayerIndex()]
    if type(recorded) == "number" then return recorded end
    return hydEyesRightChoice or 1
end

local function setChoice(creationMain, index)
    hydEyesChoice = index
    if creationMain then creationMain.hydEyesChoiceIndex = index end
    hydEyesChoices[activePlayerIndex()] = index
end

local function setRightChoice(creationMain, index)
    hydEyesRightChoice = index
    if creationMain then creationMain.hydEyesRightChoiceIndex = index end
    hydEyesRightChoices[activePlayerIndex()] = index
end

local BUTTON_HGT = getTextManager():getFontHeight(UIFont.Small) + 6
local UI_SPACING = 10
local ROW_GAP = BUTTON_HGT + UI_SPACING

-- The trait is picked on the traits screen, which comes before this one.
-- The selection is tracked from the traits screen's add/remove hooks: the
-- selected-trait list cannot be read back reliably from here, while the
-- hooks hand us the trait itself.
local selectedTraitTypes = {}

local function traitTypeOf(trait)
    if not trait then return nil end
    local ok, t = pcall(function() return trait:getType() end)
    if not ok or t == nil then return nil end
    local s = tostring(t)
    if s == "" then return nil end
    return s
end

-- Our trait, by type name or by its label (the translated name).
local function isHeterochromiaTrait(trait)
    if not trait then return false end
    local t = traitTypeOf(trait)
    if t and string.lower(t) == string.lower(hydEyesData.HETEROCHROMIA) then return true end
    local ok, label = pcall(function() return trait:getLabel() end)
    if ok and label then
        local wanted = getText("UI_trait_heterochromia")
        if wanted and tostring(label) == tostring(wanted) then return true end
    end
    return false
end

-- Fallback: read the traits screen's own list of selected traits.
local function readSelectedTraits()
    local ok, prof = pcall(function() return CharacterCreationProfession.instance end)
    if not ok or not prof then return nil end
    local list = prof.listboxTraitSelected
    if not list or not list.items then return nil end
    local items = {}
    for _, v in pairs(list.items) do
        if v and v.item then items[#items + 1] = v.item end
    end
    return items
end

local function hasHeterochromiaTrait()
    local wanted = string.lower(hydEyesData.HETEROCHROMIA)
    for t in pairs(selectedTraitTypes) do
        if string.lower(t) == wanted then return true end
    end
    local items = readSelectedTraits()
    if items then
        for _, trait in ipairs(items) do
            if isHeterochromiaTrait(trait) then return true end
        end
    end
    return false
end

-- Two dropdowns only with the trait, and only while the split graphics are
-- in use: the original combined art is one piece for both eyes, so it
-- cannot show two colors.
local function heterochromiaMode()
    if not hasHeterochromiaTrait() then return false end
    if hydEyesSettings and hydEyesSettings.fallback then return false end
    return true
end

local function entryLabel(entry)
    local text = nil
    if entry.labelKey then
        local s = getText(entry.labelKey)
        if s and s ~= entry.labelKey then text = s end
    end
    text = text or entry.label or entry.item
    -- Dropdown shows short color names ("Blue"); the row label says Eyes.
    return string.gsub(text, "^Eyes ", "")
end

local function currentEntry(creationMain)
    local list = hydEyesData.Eyes
    if #list == 0 then return nil end
    local i = math.max(1, math.min(panelChoiceIndex(creationMain), #list))
    return list[i], i
end

-- An index that is never the same as the other side's pick.
local function differentIndex(avoid, count)
    if count <= 1 then return 1 end
    return (avoid % count) + 1
end

local function descSkin(desc)
    local ok, v = pcall(function() return desc:getHumanVisual() end)
    if not ok or not v then return 0 end
    return hydEyesData.skinTone(v)
end

local function eyeLocation()
    return hydEyesLocation and hydEyesLocation["hydeyes:eyes"] or nil
end

local function eyeLoc(locId)
    return hydEyesLocation and hydEyesLocation[locId] or nil
end

local function clearSlot(desc, locId)
    local loc = eyeLoc(locId)
    if loc then desc:setWornItem(loc, nil) end
end

local function wearSide(desc, locId, entry, isFemale, skin, side)
    local loc = eyeLoc(locId)
    if loc == nil then return end
    if not entry then return end
    local fullType, tone = hydEyesData.itemFor(entry, isFemale, skin, side)
    if not fullType then return end
    local ok, item = pcall(instanceItem, fullType)
    if ok and item then
        local v = item:getVisual()
        -- Base texture only: these items carry their skin tones in
        -- <m_BaseTextures>. setTextureChoice would index the (absent)
        -- <textureChoices> list and the engine would re-roll a random
        -- texture on every avatar rebuild.
        -- Always set it, index 0 included: with several base textures the
        -- engine otherwise picks one at random.
        if v then
            pcall(function() v:setBaseTexture(tone) end)
        end
        desc:setWornItem(loc, item)
    end
end

-- Wears the chosen pair: one item per side in split mode, the single
-- fallback item otherwise (the original art is one piece for both eyes, so
-- the fallback can only show one color). The overrides are for hover
-- previews: they show a color without committing the pick.
local function applyPicks(creationMain, leftOverride, rightOverride)
    local desc = MainScreen.instance and MainScreen.instance.desc
    if not desc then return end
    local isFemale = desc:isFemale()
    local skin = descSkin(desc)
    local list = hydEyesData.Eyes
    if #list == 0 then return end
    local leftIndex = math.max(1, math.min(leftOverride or panelChoiceIndex(creationMain), #list))
    local leftEntry = list[leftIndex]
    if not leftEntry then return end
    local rightEntry = leftEntry
    if heterochromiaMode() then
        local rightIndex = math.max(1, math.min(rightOverride or panelRightChoiceIndex(creationMain), #list))
        rightEntry = list[rightIndex] or leftEntry
    end
    if hydEyesData.useSplit(leftEntry, isFemale) then
        clearSlot(desc, "hydeyes:eyes")
        wearSide(desc, "hydeyes:lefteye", leftEntry, isFemale, skin, "L")
        wearSide(desc, "hydeyes:righteye", rightEntry, isFemale, skin, "R")
        return
    end
    clearSlot(desc, "hydeyes:lefteye")
    clearSlot(desc, "hydeyes:righteye")
    local loc = eyeLocation()
    if loc == nil then return end
    local fullType, tone = hydEyesData.itemFor(leftEntry, isFemale, skin)
    if not fullType then return end
    local ok, item = pcall(instanceItem, fullType)
    if ok and item then
        local v = item:getVisual()
        if v then
            pcall(function() v:setBaseTexture(tone) end)
        end
        desc:setWornItem(loc, item)
    end
end

local function refreshAvatar(creationMain)
    local desc = MainScreen.instance and MainScreen.instance.desc
    if creationMain and creationMain.avatarPanel and desc then
        creationMain.avatarPanel:setSurvivorDesc(desc)
    end
end

local function applyCurrent(creationMain)
    applyPicks(creationMain)
    refreshAvatar(creationMain)
end

-- Hovering previews a color on the avatar without committing the pick.
local function previewEntry(creationMain, index, isRight)
    if isRight then
        applyPicks(creationMain, nil, index)
    else
        applyPicks(creationMain, index, nil)
    end
    refreshAvatar(creationMain)
end

-- Keep the two sides on different colors: picking the color the other side
-- already wears moves that side to the next color instead.
local function enforceDifferent(creationMain, changedIsRight)
    local count = #hydEyesData.Eyes
    if count < 2 then return end
    if changedIsRight then
        local right = panelRightChoiceIndex(creationMain)
        if right == panelChoiceIndex(creationMain) then
            local next = differentIndex(right, count)
            setChoice(creationMain, next)
            if creationMain.hydEyesCombo then creationMain.hydEyesCombo.selected = next end
        end
    else
        local left = panelChoiceIndex(creationMain)
        if left == panelRightChoiceIndex(creationMain) then
            local next = differentIndex(left, count)
            setRightChoice(creationMain, next)
            if creationMain.hydEyesRightCombo then
                creationMain.hydEyesRightCombo.selected = next
            end
        end
    end
end

local function hydEyesOnSelect(creationMain, combo)
    setChoice(creationMain, combo.selected)
    enforceDifferent(creationMain, false)
    applyCurrent(creationMain)
end

local function hydEyesOnSelectRight(creationMain, combo)
    setRightChoice(creationMain, combo.selected)
    enforceDifferent(creationMain, true)
    applyCurrent(creationMain)
end

local function fillCombo(combo, index)
    if type(combo.clear) == "function" then combo:clear() end
    for _, entry in ipairs(hydEyesData.Eyes) do
        combo:addOption(entryLabel(entry))
    end
    if index == nil then
        local _, i = currentEntry()
        index = i
    end
    -- NB: select() takes visible TEXT, not an index; assign the field
    -- directly exactly like the popup does on click.
    if index then combo.selected = index end
end

local function shiftBelow(panel, insertY, dy)
    local seen = {}
    local function shift(el)
        if not el or seen[el] then return end
        seen[el] = true
        -- Never move scrollbars or nested viewports, only content rows.
        local okS, isBar = pcall(function()
            return instanceof(el, "ISScrollBar")
        end)
        if okS and isBar then return end
        local ok, y = pcall(function() return el:getY() end)
        if ok and type(y) == "number" and y >= insertY then
            pcall(function() el:setY(y + dy) end)
        end
    end
    local okC, children = pcall(function() return panel:getChildren() end)
    if okC and type(children) == "table" then
        for _, el in pairs(children) do
            shift(el)
            -- One nesting level for mod-added wrappers (e.g. IHM extras).
            local okN, nested = pcall(function() return el:getChildren() end)
            if okN and type(nested) == "table" then
                for _, sub in pairs(nested) do shift(sub) end
            end
        end
    end
end

-- One row: a right-aligned label and a dropdown, vanilla side-by-side
-- style. The layout pass only sets X and width, so the row keeps its Y.
local function addEyeRow(creationMain, panel, y, labelText, onSelect)
    local lbl = ISLabel:new(0, y, BUTTON_HGT, labelText, 1, 1, 1, 1, UIFont.Small)
    lbl:initialise()
    lbl:instantiate()
    panel:addChild(lbl)
    if panel.repos2Table then table.insert(panel.repos2Table, lbl) end

    local combo = ISComboBox:new(0, y, 0, BUTTON_HGT, creationMain, onSelect)
    combo:initialise()
    combo.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    panel:addChild(combo)
    if panel.comboResizeTable then table.insert(panel.comboResizeTable, combo) end
    if panel.repos3Table then table.insert(panel.repos3Table, combo) end
    return lbl, combo
end

-- Build (or rebuild) the eye row(s). With the heterochromia trait the
-- single dropdown is replaced by a left and a right one.
local function buildEyeRows(creationMain)
    local panel = creationMain.characterPanel
    if not panel then return end
    -- Slide in under the body divider (above skin color): shift everything
    -- at/below the skin row down. Layout only ever sets X/width, so Y
    -- shifts persist through resizes and IHM centering.
    local anchor = creationMain.skinColorLbl
    local okA, insertY = pcall(function() return anchor:getY() end)
    if not anchor or not okA then return end

    local two = heterochromiaMode()
    local rows = two and 2 or 1
    local shift = ROW_GAP * rows
    shiftBelow(panel, insertY, shift)
    -- Remember the shift so a rebuild can undo it before shifting again.
    creationMain.hydEyesInsertY = insertY
    creationMain.hydEyesShift = shift

    if two then
        local leftLbl, leftCombo = addEyeRow(creationMain, panel, insertY,
            getText("IGUI_hydEyes_LeftEye"), hydEyesOnSelect)
        creationMain.hydEyesLbl = leftLbl
        creationMain.hydEyesCombo = leftCombo
        local rightLbl, rightCombo = addEyeRow(creationMain, panel, insertY + ROW_GAP,
            getText("IGUI_hydEyes_RightEye"), hydEyesOnSelectRight)
        creationMain.hydEyesRightLbl = rightLbl
        creationMain.hydEyesRightCombo = rightCombo
        fillCombo(leftCombo, panelChoiceIndex(creationMain))
        fillCombo(rightCombo, panelRightChoiceIndex(creationMain))
        -- The two sides can never match, not even in the initial state.
        local left = panelChoiceIndex(creationMain)
        local right = panelRightChoiceIndex(creationMain)
        if left == right then
            right = differentIndex(left, #hydEyesData.Eyes)
            setRightChoice(creationMain, right)
            fillCombo(rightCombo, right)
        end
        leftCombo.pointOnItem = function(_self, _index)
            if _self.lastIndex ~= _index then
                previewEntry(creationMain, _index, false)
                _self.lastIndex = _index
            end
        end
        rightCombo.pointOnItem = function(_self, _index)
            if _self.lastIndex ~= _index then
                previewEntry(creationMain, _index, true)
                _self.lastIndex = _index
            end
        end
        leftCombo.onMouseMoveOutside = function(_self)
            applyCurrent(creationMain)
        end
        rightCombo.onMouseMoveOutside = function(_self)
            applyCurrent(creationMain)
        end
    else
        local lbl, combo = addEyeRow(creationMain, panel, insertY,
            getText("IGUI_hydEyes_Eyes"), hydEyesOnSelect)
        creationMain.hydEyesLbl = lbl
        creationMain.hydEyesCombo = combo
        creationMain.hydEyesRightCombo = nil
        fillCombo(combo, panelChoiceIndex(creationMain))
        combo.pointOnItem = function(_self, _index)
            if _self.lastIndex ~= _index then
                previewEntry(creationMain, _index, false)
                _self.lastIndex = _index
            end
        end
        combo.onMouseMoveOutside = function(_self)
            applyCurrent(creationMain)
        end
    end
    creationMain.hydEyesTwoRows = two
    -- The trait may not be on the player object yet at spawn: keep the
    -- creation state so the post-spawn dress knows about it.
    hydEyesData.creationHeterochromia = two

    -- The layout pass that sizes table members ran at build; re-run it so
    -- the late-added row gets its width (IHM overrides this same method).
    pcall(function() panel:positionRelativeToScrollBar() end)

    applyCurrent(creationMain)
end

-- Remove the rows we added, so they can be rebuilt when the trait state
-- changes. The shift we gave the content below is undone first, so a
-- rebuild does not push the panel down again.
local function clearEyeRows(creationMain)
    local panel = creationMain.characterPanel
    if not panel then return end
    if creationMain.hydEyesInsertY and creationMain.hydEyesShift then
        shiftBelow(panel, creationMain.hydEyesInsertY, -creationMain.hydEyesShift)
    end
    local function drop(el)
        if not el then return end
        pcall(function() panel:removeChild(el) end)
        local function dropFrom(list)
            if type(list) ~= "table" then return end
            for i = #list, 1, -1 do
                if list[i] == el then table.remove(list, i) end
            end
        end
        dropFrom(panel.repos2Table)
        dropFrom(panel.repos3Table)
        dropFrom(panel.comboResizeTable)
    end
    drop(creationMain.hydEyesLbl)
    drop(creationMain.hydEyesCombo)
    drop(creationMain.hydEyesRightLbl)
    drop(creationMain.hydEyesRightCombo)
    creationMain.hydEyesLbl = nil
    creationMain.hydEyesCombo = nil
    creationMain.hydEyesRightLbl = nil
    creationMain.hydEyesRightCombo = nil
end

-- Rebuild the rows when the trait selection changes, so the dropdowns
-- match the trait no matter which order the screens are visited in.
local function refreshEyeRows()
    local ok, main = pcall(function() return CharacterCreationMain.instance end)
    if not ok or not main then return end
    if not main.hydEyesCombo then return end
    if main.hydEyesTwoRows == heterochromiaMode() then return end
    clearEyeRows(main)
    buildEyeRows(main)
end

-- The traits screen hands us the trait it adds and removes, so the
-- selection is tracked here instead of read back from the list.
local function hookTraitChanges()
    if type(CharacterCreationProfession) ~= "table" then return end
    if type(CharacterCreationProfession.addTrait) == "function"
        and not CharacterCreationProfession.hydEyesWrappedAdd then
        CharacterCreationProfession.hydEyesWrappedAdd = true
        local originalAdd = CharacterCreationProfession.addTrait
        CharacterCreationProfession.addTrait = function(self, trait, ...)
            local t = traitTypeOf(trait)
            local result = originalAdd(self, trait, ...)
            if t then selectedTraitTypes[t] = true end
            local ours = isHeterochromiaTrait(trait)
            if ours then selectedTraitTypes[hydEyesData.HETEROCHROMIA] = true end
            refreshEyeRows()
            return result
        end
    end
    if type(CharacterCreationProfession.removeTrait) == "function"
        and not CharacterCreationProfession.hydEyesWrappedRemove then
        CharacterCreationProfession.hydEyesWrappedRemove = true
        local originalRemove = CharacterCreationProfession.removeTrait
        CharacterCreationProfession.removeTrait = function(self, index, ...)
            local removedTrait = nil
            pcall(function()
                local entry = self.listboxTraitSelected:getItem(index)
                if entry then removedTrait = entry.item end
            end)
            local result = originalRemove(self, index, ...)
            local t = traitTypeOf(removedTrait)
            if t then selectedTraitTypes[t] = nil end
            local ours = isHeterochromiaTrait(removedTrait)
            if ours then selectedTraitTypes[hydEyesData.HETEROCHROMIA] = nil end
            refreshEyeRows()
            return result
        end
    end
    if type(CharacterCreationProfession.resetTraits) == "function"
        and not CharacterCreationProfession.hydEyesWrappedReset then
        CharacterCreationProfession.hydEyesWrappedReset = true
        local originalReset = CharacterCreationProfession.resetTraits
        CharacterCreationProfession.resetTraits = function(self, ...)
            local result = originalReset(self, ...)
            selectedTraitTypes = {}
            refreshEyeRows()
            return result
        end
    end
end

-- The appearance screen reads the selected traits while it builds its
-- clothing, and the list is only readable from there. Capture it at that
-- moment instead of guessing when to look.
local function hookInitClothing()
    if type(CharacterCreationMain) ~= "table" then return end
    if type(CharacterCreationMain.initClothing) == "function"
        and not CharacterCreationMain.hydEyesWrappedInit then
        CharacterCreationMain.hydEyesWrappedInit = true
        local original = CharacterCreationMain.initClothing
        CharacterCreationMain.initClothing = function(self, ...)
            -- Read the list AFTER the original runs: the appearance screen
            -- fills the selected-trait list while it builds the clothing,
            -- so reading before it comes back empty.
            local result = original(self, ...)
            local items = readSelectedTraits()
            if items then
                for _, trait in ipairs(items) do
                    local t = traitTypeOf(trait)
                    if t then selectedTraitTypes[t] = true end
                    if isHeterochromiaTrait(trait) then
                        selectedTraitTypes[hydEyesData.HETEROCHROMIA] = true
                    end
                end
            end
            return result
        end
    end
end

local function TryInstall()
    if type(CharacterCreationMain) ~= "table" then return end

    hookTraitChanges()
    hookInitClothing()

    -- Insert after the full build (first show): slide the row in under the
    -- body divider and shift everything below down. Layout only ever sets
    -- X/width, so Y shifts survive resizes and IHM centering. Hooking any
    -- builder method loses to IHM's wholesale replacements; doing it here
    -- depends on nothing but the finished panel.

    -- Outfit changes wipe worn items: put the eyes back on afterwards.
    if type(CharacterCreationMain.randomGenericOutfit) == "function"
        and not CharacterCreationMain.hydEyesOutfitHooked then
        CharacterCreationMain.hydEyesOutfitHooked = true
        local originalOutfit = CharacterCreationMain.randomGenericOutfit
        CharacterCreationMain.randomGenericOutfit = function(self, ...)
            originalOutfit(self, ...)
            applyCurrent(self)
        end
    end

    -- The dice rolls everything: roll the eyes too.
    if type(CharacterCreationMain.onRandomCharacter) == "function"
        and not CharacterCreationMain.hydEyesDiceHooked then
        CharacterCreationMain.hydEyesDiceHooked = true
        local originalDice = CharacterCreationMain.onRandomCharacter
        CharacterCreationMain.onRandomCharacter = function(self, ...)
            local count = #hydEyesData.Eyes
            if count > 0 then
                local roll = ZombRand(count) + 1
                setChoice(self, roll)
                if self.hydEyesCombo then
                    self.hydEyesCombo.selected = roll
                end
                -- With heterochromia the two sides never match, not even
                -- from a roll.
                local right = roll
                if count > 1 and heterochromiaMode() then
                    right = differentIndex(roll, count)
                end
                setRightChoice(self, right)
                if self.hydEyesRightCombo then
                    self.hydEyesRightCombo.selected = right
                end
            end
            return originalDice(self, ...)
        end
    end

    -- Skin tone changes the worn texture: re-apply the pick afterwards.
    -- The game sets the tone in onSkinColorPicked (the picker button only
    -- opens the picker), so that is the hook that matters - hooking the
    -- button would re-apply with the old tone and leave the avatar stale
    -- until the next redraw.
    if type(CharacterCreationMain.onSkinColorPicked) == "function"
        and not CharacterCreationMain.hydEyesSkinPickedHooked then
        CharacterCreationMain.hydEyesSkinPickedHooked = true
        local originalPicked = CharacterCreationMain.onSkinColorPicked
        CharacterCreationMain.onSkinColorPicked = function(self, color, mouseUp)
            local result = originalPicked(self, color, mouseUp)
            applyCurrent(self)
            return result
        end
    end

    if type(CharacterCreationMain.onSkinColorSelected) == "function"
        and not CharacterCreationMain.hydEyesSkinHooked then
        CharacterCreationMain.hydEyesSkinHooked = true
        local originalSkin = CharacterCreationMain.onSkinColorSelected
        CharacterCreationMain.onSkinColorSelected = function(self, ...)
            originalSkin(self, ...)
            applyCurrent(self)
        end
    end

    -- The preview desc never spawns: strip our eyes at Play so the engine
    -- never resolves them during Dressup, then wear post-spawn instead.
    if type(CharacterCreationMain.onOptionMouseDown) == "function"
        and not CharacterCreationMain.hydEyesPlayHooked then
        CharacterCreationMain.hydEyesPlayHooked = true
        local originalPlay = CharacterCreationMain.onOptionMouseDown
        CharacterCreationMain.onOptionMouseDown = function(self, button, ...)
            if button and button.internal == "NEXT" then
                pcall(function()
                    local desc = MainScreen.instance.desc
                    if desc then
                        clearSlot(desc, "hydeyes:eyes")
                        clearSlot(desc, "hydeyes:lefteye")
                        clearSlot(desc, "hydeyes:righteye")
                    end
                end)
            end
            return originalPlay(self, button, ...)
        end
    end

    if Events and Events.OnCreatePlayer and not hydEyesSpawnHooked then
        hydEyesSpawnHooked = true
        -- NB: the event passes a player INDEX, not the object.
        Events.OnCreatePlayer.Add(function(playerNum)
            local n = playerNum or 0
            local ok, player = pcall(getSpecificPlayer, n)
            local index = hydEyesChoices[n] or hydEyesChoice or 1
            local right = hydEyesRightChoices[n] or hydEyesRightChoice or index
            if ok and player and hydEyesData and hydEyesData.wearOn then
                hydEyesData.wearOn(player, index, right)
            end
        end)
    end

    -- Build the row on first show (and refresh third-party entries after).
    if type(CharacterCreationMain.setVisible) == "function"
        and not CharacterCreationMain.hydEyesVisibleHooked then
        CharacterCreationMain.hydEyesVisibleHooked = true
        local originalVisible = CharacterCreationMain.setVisible
        CharacterCreationMain.setVisible = function(self, visible, ...)
            originalVisible(self, visible, ...)
            if visible then
                -- The trait can change between visits, and so can the mod
                -- options fallback: rebuild the rows when the shape changes.
                if self.hydEyesCombo and self.hydEyesTwoRows ~= heterochromiaMode() then
                    clearEyeRows(self)
                end
                if not self.hydEyesCombo then buildEyeRows(self) end
                if self.hydEyesCombo then
                    fillCombo(self.hydEyesCombo, panelChoiceIndex(self))
                end
                if self.hydEyesRightCombo then
                    fillCombo(self.hydEyesRightCombo, panelRightChoiceIndex(self))
                end
                -- Re-wear so a Mod Options fallback toggle takes effect here.
                applyCurrent(self)
            end
        end
    end
end

TryInstall()
if Events then
    if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(TryInstall) end
    if Events.OnGameBoot then Events.OnGameBoot.Add(TryInstall) end
end
