-- Eye shape, height, lash length and colour dropdowns on the vanilla
-- character creation screen, slid in under the body divider:
--
--   * drawing is layered: face -> eyes -> lashes, each on its own body slot;
--   * picking a value wears it on the preview desc immediately (hovering
--     previews);
--   * the preview desc never spawns (stripped at Play), so each player's
--     recorded picks are worn post-spawn instead — per-player picks keyed by
--     player index, so splitscreen characters don't clobber each other;
--   * outfit randomize / gender change / the dice clear worn items, so the
--     current picks are re-applied after each of those;
--   * with the Heterochromia trait the single colour dropdown is replaced by
--     two (left and right) and the two sides can never share a colour.
--
-- Third-party entries registered with hydEyesData.AddEye appear automatically
-- (options rebuild every time the creation screen is shown).

require("hydEyesData")

hydEyesChoice = hydEyesChoice or 1
hydEyesRightChoice = hydEyesRightChoice or 1
hydEyesTypeChoice = hydEyesTypeChoice or (hydEyesData.DefaultTypeIndex or 1)
hydEyesHeightChoice = hydEyesHeightChoice or (hydEyesData.DefaultHeightIndex or 1)
hydEyesLashChoice = hydEyesLashChoice or (hydEyesData.DefaultLashIndex or 1)
-- Per-player picks (splitscreen creates one character per player through
-- panels sharing one preview desc). Single-player only ever uses index 0.
hydEyesChoices = hydEyesChoices or {}
hydEyesRightChoices = hydEyesRightChoices or {}
hydEyesTypeChoices = hydEyesTypeChoices or {}
hydEyesHeightChoices = hydEyesHeightChoices or {}
hydEyesLashChoices = hydEyesLashChoices or {}

-- Which player the open creation screen is building (0 in single-player).
local function activePlayerIndex()
    local ok, coop = pcall(function() return CoopCharacterCreation.instance end)
    if ok and coop and type(coop.playerIndex) == "number" then
        return coop.playerIndex
    end
    return 0
end

local function clampChoice(value, count)
    if type(count) ~= "number" or count < 1 then return 1 end
    value = tonumber(value) or 1
    if value < 1 then value = 1 end
    if value > count then value = count end
    return math.floor(value)
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

local function panelRightChoiceIndex(creationMain)
    if creationMain and type(creationMain.hydEyesRightChoiceIndex) == "number" then
        return creationMain.hydEyesRightChoiceIndex
    end
    local recorded = hydEyesRightChoices[activePlayerIndex()]
    if type(recorded) == "number" then return recorded end
    return hydEyesRightChoice or 1
end

local function panelTypeIndex(creationMain)
    if creationMain and type(creationMain.hydEyesTypeIndex) == "number" then
        return creationMain.hydEyesTypeIndex
    end
    local recorded = hydEyesTypeChoices[activePlayerIndex()]
    if type(recorded) == "number" then return recorded end
    return hydEyesTypeChoice or hydEyesData.DefaultTypeIndex or 1
end

local function panelHeightIndex(creationMain)
    if creationMain and type(creationMain.hydEyesHeightIndex) == "number" then
        return creationMain.hydEyesHeightIndex
    end
    local recorded = hydEyesHeightChoices[activePlayerIndex()]
    if type(recorded) == "number" then return recorded end
    return hydEyesHeightChoice or hydEyesData.DefaultHeightIndex or 1
end

local function panelLashIndex(creationMain)
    if creationMain and type(creationMain.hydEyesLashIndex) == "number" then
        return creationMain.hydEyesLashIndex
    end
    local recorded = hydEyesLashChoices[activePlayerIndex()]
    if type(recorded) == "number" then return recorded end
    return hydEyesLashChoice or hydEyesData.DefaultLashIndex or 1
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

local function setTypeChoice(creationMain, index)
    hydEyesTypeChoice = index
    if creationMain then creationMain.hydEyesTypeIndex = index end
    hydEyesTypeChoices[activePlayerIndex()] = index
end

local function setHeightChoice(creationMain, index)
    hydEyesHeightChoice = index
    if creationMain then creationMain.hydEyesHeightIndex = index end
    hydEyesHeightChoices[activePlayerIndex()] = index
end

local function setLashChoice(creationMain, index)
    hydEyesLashChoice = index
    if creationMain then creationMain.hydEyesLashIndex = index end
    hydEyesLashChoices[activePlayerIndex()] = index
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

-- Two colour dropdowns only with the trait: the left and right eyes are
-- separate items, so they can show two colours.
local function heterochromiaMode()
    return hasHeterochromiaTrait()
end

local function entryLabel(entry)
    local text = nil
    if entry.labelKey then
        local s = getText(entry.labelKey)
        if s and s ~= entry.labelKey then text = s end
    end
    text = text or entry.label or entry.item
    -- Dropdown shows short colour names ("Blue"); the row label says Eyes.
    return string.gsub(text, "^Eyes ", "")
end

local function optionLabel(option)
    if option.labelKey then
        local s = getText(option.labelKey)
        if s and s ~= option.labelKey then return s end
    end
    return option.label or option.key
end

local function currentEntry(creationMain)
    local list = hydEyesData.Eyes
    if #list == 0 then return nil end
    local i = clampChoice(panelChoiceIndex(creationMain), #list)
    return list[i], i
end

-- An index that is never the same as the other side's pick.
local function differentIndex(avoid, count)
    if count <= 1 then return 1 end
    return (avoid % count) + 1
end

local function refreshAvatar(creationMain)
    local desc = MainScreen.instance and MainScreen.instance.desc
    if creationMain and creationMain.avatarPanel and desc then
        creationMain.avatarPanel:setSurvivorDesc(desc)
    end
end

-- Wears the current picks (or the supplied hover overrides) through the
-- shared data layer, so the creation preview and the spawned player follow
-- exactly the same layering rules.
local function applyPicks(creationMain, overrides)
    local desc = MainScreen.instance and MainScreen.instance.desc
    if not desc then return end
    local list = hydEyesData.Eyes
    if #list == 0 then return end
    overrides = overrides or {}
    local leftIndex = clampChoice(overrides.left or panelChoiceIndex(creationMain), #list)
    local rightIndex = clampChoice(overrides.right or panelRightChoiceIndex(creationMain), #list)
    local typeIndex = clampChoice(overrides.type or panelTypeIndex(creationMain), #hydEyesData.Types)
    local heightIndex = clampChoice(overrides.height or panelHeightIndex(creationMain), #hydEyesData.Heights)
    local lashIndex = clampChoice(overrides.lash or panelLashIndex(creationMain), #hydEyesData.LashLengths)
    hydEyesData.wearColors(desc, leftIndex, rightIndex, heterochromiaMode(),
        typeIndex, heightIndex, lashIndex)
end

local function applyCurrent(creationMain)
    applyPicks(creationMain)
    refreshAvatar(creationMain)
end

local function overrideFor(key, value)
    local overrides = {}
    overrides[key] = value
    return overrides
end

-- Hovering previews a value on the avatar without committing the pick.
local function previewPick(creationMain, key, index)
    applyPicks(creationMain, overrideFor(key, index))
    refreshAvatar(creationMain)
end

-- Keep the two sides on different colours: picking the colour the other side
-- already wears moves that side to the next colour instead.
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

local function hydEyesOnShape(creationMain, combo)
    setTypeChoice(creationMain, combo.selected)
    applyCurrent(creationMain)
end

local function hydEyesOnHeight(creationMain, combo)
    setHeightChoice(creationMain, combo.selected)
    applyCurrent(creationMain)
end

local function hydEyesOnLash(creationMain, combo)
    setLashChoice(creationMain, combo.selected)
    applyCurrent(creationMain)
end

local function fillCombo(combo, index)
    if type(combo.clear) == "function" then combo:clear() end
    for _, entry in ipairs(hydEyesData.Eyes) do
        combo:addOption(entryLabel(entry))
    end
    -- NB: select() takes visible TEXT, not an index; assign the field
    -- directly exactly like the popup does on click.
    combo.selected = clampChoice(index, #hydEyesData.Eyes)
end

local function fillTypeCombo(combo, index)
    if type(combo.clear) == "function" then combo:clear() end
    for _, typ in ipairs(hydEyesData.Types) do
        combo:addOption(tostring(typ))
    end
    combo.selected = clampChoice(index, #hydEyesData.Types)
end

local function fillOptionCombo(combo, options, index)
    if type(combo.clear) == "function" then combo:clear() end
    for _, option in ipairs(options) do
        combo:addOption(optionLabel(option))
    end
    combo.selected = clampChoice(index, #options)
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

-- Hover previews a value without committing it.
local function hookPreview(combo, creationMain, key)
    combo.pointOnItem = function(_self, index)
        if _self.lastIndex ~= index then
            previewPick(creationMain, key, index)
            _self.lastIndex = index
        end
    end
    combo.onMouseMoveOutside = function(_self)
        applyCurrent(creationMain)
    end
end

-- Build (or rebuild) the four/five rows: eye shape, eye height, lash
-- length, then colour (one dropdown, or left and right with the trait).
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
    local colorRows = two and 2 or 1
    local rows = 3 + colorRows
    local shift = ROW_GAP * rows
    shiftBelow(panel, insertY, shift)
    -- Remember the shift so a rebuild can undo it before shifting again.
    creationMain.hydEyesInsertY = insertY
    creationMain.hydEyesShift = shift

    local y = insertY
    local shapeLbl, shapeCombo = addEyeRow(creationMain, panel, y,
        getText("IGUI_hydEyes_Shape"), hydEyesOnShape)
    creationMain.hydEyesShapeLbl = shapeLbl
    creationMain.hydEyesShapeCombo = shapeCombo
    fillTypeCombo(shapeCombo, panelTypeIndex(creationMain))
    hookPreview(shapeCombo, creationMain, "type")

    y = y + ROW_GAP
    local heightLbl, heightCombo = addEyeRow(creationMain, panel, y,
        getText("IGUI_hydEyes_Height"), hydEyesOnHeight)
    creationMain.hydEyesHeightLbl = heightLbl
    creationMain.hydEyesHeightCombo = heightCombo
    fillOptionCombo(heightCombo, hydEyesData.Heights, panelHeightIndex(creationMain))
    hookPreview(heightCombo, creationMain, "height")

    y = y + ROW_GAP
    local lashLbl, lashCombo = addEyeRow(creationMain, panel, y,
        getText("IGUI_hydEyes_Lash"), hydEyesOnLash)
    creationMain.hydEyesLashLbl = lashLbl
    creationMain.hydEyesLashCombo = lashCombo
    fillOptionCombo(lashCombo, hydEyesData.LashLengths, panelLashIndex(creationMain))
    hookPreview(lashCombo, creationMain, "lash")

    y = y + ROW_GAP
    if two then
        local leftLbl, leftCombo = addEyeRow(creationMain, panel, y,
            getText("IGUI_hydEyes_LeftEye"), hydEyesOnSelect)
        creationMain.hydEyesLbl = leftLbl
        creationMain.hydEyesCombo = leftCombo
        local rightLbl, rightCombo = addEyeRow(creationMain, panel, y + ROW_GAP,
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
        hookPreview(leftCombo, creationMain, "left")
        hookPreview(rightCombo, creationMain, "right")
    else
        local lbl, combo = addEyeRow(creationMain, panel, y,
            getText("IGUI_hydEyes_Eyes"), hydEyesOnSelect)
        creationMain.hydEyesLbl = lbl
        creationMain.hydEyesCombo = combo
        creationMain.hydEyesRightCombo = nil
        fillCombo(combo, panelChoiceIndex(creationMain))
        hookPreview(combo, creationMain, "left")
    end
    creationMain.hydEyesTwoRows = two
    -- The trait may not be on the player object yet at spawn: keep the
    -- creation state so the post-spawn dress knows about it.
    hydEyesData.creationHeterochromia = two

    -- The layout pass that sizes table members ran at build; re-run it so
    -- the late-added rows get their width (IHM overrides this same method).
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
    local fields = {
        "hydEyesShapeLbl", "hydEyesShapeCombo",
        "hydEyesHeightLbl", "hydEyesHeightCombo",
        "hydEyesLashLbl", "hydEyesLashCombo",
        "hydEyesLbl", "hydEyesCombo",
        "hydEyesRightLbl", "hydEyesRightCombo",
    }
    for _, field in ipairs(fields) do
        drop(creationMain[field])
        creationMain[field] = nil
    end
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

    -- Insert after the full build (first show): slide the rows in under the
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
            if #hydEyesData.Types > 0 then
                local typ = ZombRand(#hydEyesData.Types) + 1
                setTypeChoice(self, typ)
                if self.hydEyesShapeCombo then self.hydEyesShapeCombo.selected = typ end
            end
            if #hydEyesData.Heights > 0 then
                local height = ZombRand(#hydEyesData.Heights) + 1
                setHeightChoice(self, height)
                if self.hydEyesHeightCombo then self.hydEyesHeightCombo.selected = height end
            end
            if #hydEyesData.LashLengths > 0 then
                local lash = ZombRand(#hydEyesData.LashLengths) + 1
                setLashChoice(self, lash)
                if self.hydEyesLashCombo then self.hydEyesLashCombo.selected = lash end
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

    -- The preview desc never spawns: strip our layers at Play so the engine
    -- never resolves them during Dressup, then wear post-spawn instead.
    if type(CharacterCreationMain.onOptionMouseDown) == "function"
        and not CharacterCreationMain.hydEyesPlayHooked then
        CharacterCreationMain.hydEyesPlayHooked = true
        local originalPlay = CharacterCreationMain.onOptionMouseDown
        CharacterCreationMain.onOptionMouseDown = function(self, button, ...)
            if button and button.internal == "NEXT" then
                pcall(function()
                    local desc = MainScreen.instance.desc
                    if desc then hydEyesData.clearWorn(desc) end
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
            local typ = hydEyesTypeChoices[n] or hydEyesTypeChoice
                or hydEyesData.DefaultTypeIndex or 1
            local height = hydEyesHeightChoices[n] or hydEyesHeightChoice
                or hydEyesData.DefaultHeightIndex or 1
            local lash = hydEyesLashChoices[n] or hydEyesLashChoice
                or hydEyesData.DefaultLashIndex or 1
            if ok and player and hydEyesData and hydEyesData.wearOn then
                hydEyesData.wearOn(player, index, right, typ, height, lash)
            end
        end)
    end

    -- Build the rows on first show (and refresh third-party entries after).
    if type(CharacterCreationMain.setVisible) == "function"
        and not CharacterCreationMain.hydEyesVisibleHooked then
        CharacterCreationMain.hydEyesVisibleHooked = true
        local originalVisible = CharacterCreationMain.setVisible
        CharacterCreationMain.setVisible = function(self, visible, ...)
            originalVisible(self, visible, ...)
            if visible then
                -- The trait can change between visits: rebuild the rows when
                -- the shape changes.
                if self.hydEyesCombo and self.hydEyesTwoRows ~= heterochromiaMode() then
                    clearEyeRows(self)
                end
                if not self.hydEyesCombo or not self.hydEyesShapeCombo then
                    if self.hydEyesCombo then clearEyeRows(self) end
                    buildEyeRows(self)
                end
                if self.hydEyesCombo then
                    fillCombo(self.hydEyesCombo, panelChoiceIndex(self))
                end
                if self.hydEyesRightCombo then
                    fillCombo(self.hydEyesRightCombo, panelRightChoiceIndex(self))
                end
                if self.hydEyesShapeCombo then
                    fillTypeCombo(self.hydEyesShapeCombo, panelTypeIndex(self))
                end
                if self.hydEyesHeightCombo then
                    fillOptionCombo(self.hydEyesHeightCombo, hydEyesData.Heights,
                        panelHeightIndex(self))
                end
                if self.hydEyesLashCombo then
                    fillOptionCombo(self.hydEyesLashCombo, hydEyesData.LashLengths,
                        panelLashIndex(self))
                end
                -- Re-wear so changes made elsewhere take effect here.
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
