-- Eye color dropdown on the vanilla character creation screen, slid in
-- under the body divider:
--
--   * picking a color wears that eye item on the preview desc immediately
--     (hovering previews);
--   * the preview desc never spawns (stripped at Play), so each player's
--     recorded pick is worn post-spawn instead — per-player picks keyed by
--     player index, so splitscreen characters don't clobber each other;
--   * outfit randomize / gender change / the dice clear worn items, so the
--     current pick is re-applied after each of those.
--
-- Third-party entries registered with hydEyesData.AddEye appear automatically
-- (options rebuild every time the creation screen is shown).

require("hydEyesData")

hydEyesChoice = hydEyesChoice or 1
-- Per-player picks (splitscreen creates one character per player through
-- panels sharing one preview desc). Single-player only ever uses index 0.
hydEyesChoices = hydEyesChoices or {}

-- Which player the open creation screen is building (0 in single-player).
local function activePlayerIndex()
    local ok, coop = pcall(function() return CoopCharacterCreation.instance end)
    if ok and coop and type(coop.playerIndex) == "number" then
        return coop.playerIndex
    end
    return 0
end

-- This panel's pick: its own field, else its player's recorded pick, else
-- the default. Keeps splitscreen panels from clobbering each other.
local function panelChoiceIndex(creationMain)
    if creationMain and type(creationMain.hydEyesChoiceIndex) == "number" then
        return creationMain.hydEyesChoiceIndex
    end
    local recorded = hydEyesChoices[activePlayerIndex()]
    if type(recorded) == "number" then return recorded end
    return hydEyesChoice or 1
end

local function setChoice(creationMain, index)
    hydEyesChoice = index
    if creationMain then creationMain.hydEyesChoiceIndex = index end
    hydEyesChoices[activePlayerIndex()] = index
end

local BUTTON_HGT = getTextManager():getFontHeight(UIFont.Small) + 6
local UI_SPACING = 10

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

local function applyEntry(entry)
    local desc = MainScreen.instance and MainScreen.instance.desc
    if not desc or not entry then return end
    local isFemale = desc:isFemale()
    local skin = descSkin(desc)
    if hydEyesData.useSplit(entry, isFemale) then
        clearSlot(desc, "hydeyes:eyes")
        wearSide(desc, "hydeyes:lefteye", entry, isFemale, skin, "L")
        wearSide(desc, "hydeyes:righteye", entry, isFemale, skin, "R")
        return
    end
    clearSlot(desc, "hydeyes:lefteye")
    clearSlot(desc, "hydeyes:righteye")
    local loc = eyeLocation()
    if loc == nil then return end
    local fullType, tone = hydEyesData.itemFor(entry, isFemale, skin)
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
    local entry = currentEntry(creationMain)
    applyEntry(entry)
    refreshAvatar(creationMain)
end

local function previewEntry(creationMain, index)
    local entry = hydEyesData.Eyes[index]
    applyEntry(entry)
    refreshAvatar(creationMain)
end

local function hydEyesOnSelect(creationMain, combo)
    setChoice(creationMain, combo.selected)
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

local function addEyeRow(creationMain)
    if creationMain.hydEyesCombo then return end
    local panel = creationMain.characterPanel
    if not panel then return end
    -- Slide in under the body divider (above skin color): shift everything
    -- at/below the skin row down. Layout only ever sets X/width, so Y
    -- shifts persist through resizes and IHM centering.
    local anchor = creationMain.skinColorLbl
    local okA, insertY = pcall(function() return anchor:getY() end)
    if not anchor or not okA then return end
    local dy = BUTTON_HGT + UI_SPACING
    shiftBelow(panel, insertY, dy)

    -- Label + dropdown sharing the freed row, vanilla side-by-side style.
    creationMain.hydEyesLbl = ISLabel:new(0, insertY, BUTTON_HGT,
        getText("IGUI_hydEyes_Eyes"), 1, 1, 1, 1, UIFont.Small)
    creationMain.hydEyesLbl:initialise()
    creationMain.hydEyesLbl:instantiate()
    panel:addChild(creationMain.hydEyesLbl)
    if panel.repos2Table then table.insert(panel.repos2Table, creationMain.hydEyesLbl) end

    -- Dropdown next to it, gender-combo border to match the neighbors.
    local combo = ISComboBox:new(0, insertY, 0, BUTTON_HGT,
        creationMain, hydEyesOnSelect)
    combo:initialise()
    combo.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    fillCombo(combo, panelChoiceIndex(creationMain))
    combo.pointOnItem = function(_self, _index)
        if _self.lastIndex ~= _index then
            previewEntry(creationMain, _index)
            _self.lastIndex = _index
        end
    end
    combo.onMouseMoveOutside = function(_self)
        applyCurrent(creationMain)
    end
    panel:addChild(combo)
    if panel.comboResizeTable then table.insert(panel.comboResizeTable, combo) end
    if panel.repos3Table then table.insert(panel.repos3Table, combo) end
    creationMain.hydEyesCombo = combo

    -- The layout pass that sizes table members ran at build; re-run it so
    -- the late-added row gets its width (IHM overrides this same method).
    pcall(function() panel:positionRelativeToScrollBar() end)

    applyCurrent(creationMain)
end

local function TryInstall()
    if type(CharacterCreationMain) ~= "table" then return end

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
            if #hydEyesData.Eyes > 0 then
                local roll = ZombRand(#hydEyesData.Eyes) + 1
                setChoice(self, roll)
                if self.hydEyesCombo then
                    self.hydEyesCombo.selected = roll
                end
            end
            return originalDice(self, ...)
        end
    end

    -- Skin tone changes the worn texture: re-apply the pick afterwards.
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
            if ok and player and hydEyesData and hydEyesData.wearOn then
                hydEyesData.wearOn(player, index)
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
                if not self.hydEyesCombo then addEyeRow(self) end
                if self.hydEyesCombo then
                    fillCombo(self.hydEyesCombo, panelChoiceIndex(self))
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
