# Eye Pack Wiki — adding your own eyes to the hydEyes framework

This mod (`hydEyes`) doubles as a framework: any other mod can add its
own eye colors and they show up in the character creation dropdown, persist,
and sync with zero extra code. No lua framework to copy — you just register
entries.

You need: this mod, and basic familiarity with Zomboid clothing items. All
paths below are relative to your mod's folder.

**Compat patches this mod ships** (all optional, each active only when its
target mod is installed): GridCharacterHub's health model keeps the eyes,
lashes and both overlay sets, ItIsOfInterestToMe's ID photos wear them and
print their colour codes, and Spongie's Character Customisation / Tomb's
Player Body custom faces are drawn *under* the eyes, so the eyes stay visible
over a custom face. A third-party eye pack rides along with all of them — it
only has to register entries.

## The eye entry (the only lua you write)

One file, e.g. `42/media/lua/shared/MyEyes.lua`. The `AddEye` function
already ships in this mod — you only write entries:

```lua
hydEyesData.AddEye({
    label = "My Blue",                   -- plain label ...
    labelKey = "IGUI_MyEyes_Blue",       -- ... or translation key (preferred)
    male = "MyEyes.Detail_EyesMyBlueM",    -- male-fit item ...
    female = "MyEyes.Detail_EyesMyBlueF",  -- ... and female-fit item (see below)
    textures = 1,                        -- textures on the single-slot items
    code = "MYB",                        -- optional short code label
})
```

Entries list in the dropdown in registration order. Late registration is
fine: the dropdown rebuilds its options every time creation opens. If your
mod loads before this one, defer your calls so the registry exists:

```lua
local registered = false
local function registerMyEyes()
    if registered then return end
    if not (hydEyesData and hydEyesData.AddEye) then return end
    registered = true
    hydEyesData.AddEye({ ... })
end
registerMyEyes()
if Events and Events.OnGameBoot then Events.OnGameBoot.Add(registerMyEyes) end
```

### Split left/right eyes (optional)

The engine renders one texture per clothing item, so a pack that draws the
eyes separately needs **one item per side**. Register the split items and
the mod wears both:

```lua
hydEyesData.AddEye({
    labelKey = "IGUI_MyEyes_Blue",
    male = "MyEyes.Detail_EyesMyBlueM",      -- optional single-slot item
    female = "MyEyes.Detail_EyesMyBlueF",
    maleL = "MyEyes.Detail_EyesMyBlueML",    -- left eye, male fit
    maleR = "MyEyes.Detail_EyesMyBlueMR",    -- right eye, male fit
    femaleL = "MyEyes.Detail_EyesMyBlueFL",  -- left eye, female fit
    femaleR = "MyEyes.Detail_EyesMyBlueFR",  -- right eye, female fit
    textures = 1,                            -- textures on the single-slot items
    splitTextures = 5,                       -- textures on each split item
})
```

With the split fields present, picking the color wears the left item on
`hydeyes:lefteye` and the right item on `hydeyes:righteye`. Without them
the entry keeps the single-slot behavior on `hydeyes:eyes`.

**Slot names are not configurable per pack** — the split slots are the
mod's own `hydeyes:lefteye` / `hydeyes:righteye` locations, so a third-party
pack reuses them and its left/right items sit on the same slots as this
pack's. Items are keyed by their own script names, so two packs never
collide.

### Layered entries (advanced)

This pack's own colors are layered: the eye item carries one texture per
eye shape and height, and a separate lash item is worn on
`hydeyes:leftlash` / `hydeyes:rightlash` above it. An entry opts in with
`layered = true`:

```lua
hydEyesData.AddEye({
    labelKey = "IGUI_MyEyes_Blue",
    maleL = "MyEyes.Detail_EyesMyBlueML",
    maleR = "MyEyes.Detail_EyesMyBlueMR",
    femaleL = "MyEyes.Detail_EyesMyBlueFL",
    femaleR = "MyEyes.Detail_EyesMyBlueFR",
    layered = true,
    splitTextures = hydEyesData.eyeTextureCount(),  -- shapes x heights
})
```

`splitTextures` must equal `#hydEyesData.Types * #hydEyesData.Heights`, and
the item's `<m_BaseTextures>` must be in shape-major order, height-major
inside each shape (`01/low`, `01/normal`, `01/high`, `02/low`, …). Lashes
are module-wide: `hydEyesData.LashItems` holds the four lash item full types
and their textures are ordered shape → height → length (short, long). A
layered third-party pack that wants its own lash art must replace
`hydEyesData.LashItems` and its lash item xmls; entries themselves do not
carry lash items.

The bloodshot overlay is module-wide in the same way:
`hydEyesData.BloodshotItems` holds the two bloodshot item full types (one per
side, no male/female split), worn on stacked slots above the lashes:
`hydeyes:leftbloodshot` / `hydeyes:rightbloodshot` for layer 1, then
`hydeyes:leftbloodshot2` / `3` / `4` / `5` / `6` and the right equivalents.
Every layer is
the same item, so the transparent red art builds up; the textures use the same
shape → height order as the eyes. The overlay is worn automatically (never
picked in creation) and copies the base texture of the eye underneath so it
always matches the chosen shape and height, per eye. Up to six layers stack:

| Stat | Layer added at |
| --- | --- |
| Intoxication (0–100%) | over 30%, over 50%, over 70% |
| Sickness (0–100%) | 75%, 90% |
| Anger (0–100%) | 75% |

The thresholds live in `hydEyesData.BloodshotThresholds` and the cap in
`hydEyesData.BloodshotLayers` (6 — the three stats together max out at exactly
that). Only layered entries get the overlay — a
single-slot or split entry without `layered` indexes its textures by skin
tone, not by shape/height, so there is nothing for the overlay to match.

The infected overlay works the same way and is drawn *under* the bloodshot
layers: `hydEyesData.InfectedItems` holds the two infected item full types
(one per side, no male/female split), worn on stacked slots above the lashes
and below the bloodshot layers: `hydeyes:leftinfected` /
`hydeyes:rightinfected` for layer 1, then `hydeyes:leftinfected2` / `3` / `4`
/ `5` / `6` and the right equivalents. Every layer is the same item, so the
transparent yellow art builds up; the textures use the same shape → height
order as the eyes, and each layer copies the base texture of the eye
underneath so it always matches the chosen shape and height, per eye.

| Stat | Layer added at |
| --- | --- |
| Zombie infection (0–100%) | 10%, 21%, 41%, 61%, 81% |
| Sickness (0–100%) | 90% (the sixth layer) |

Infection below 10% wears no infected layers unless sickness is at 90% or
worse. The thresholds live in `hydEyesData.InfectedThresholds`, the sickness
step in `hydEyesData.InfectedSicknessLayer`, and the cap in
`hydEyesData.InfectedLayers` (6). The same layered-entry restriction applies
as for the bloodshot overlay.

## Textures

512x512 PNGs under `media/textures/`. This pack uses:

```
media/textures/Eyes/<shape>/<height>/<shape><Color>_<L|R>.png
media/textures/Eyes/<shape>/<height>/<shape>_Lash<Short|Long>_<L|R>.png
media/textures/Eyes/<shape>/<height>/<shape>_Infected_<L|R>.png
media/textures/Eyes/<shape>/<height>/<shape>_Bloodshot_<L|R>.png
```

e.g. `Eyes/01/normal/01Amber_L.png`. Shapes are `01`–`04`, heights are
`low`, `normal`, `high`.

### Skin tones

Vanilla ships five body textures, `MaleBody01`..`MaleBody05` and
`FemaleBody01`..`FemaleBody05` — tone `01` is the palest, `05` the
darkest. A third-party pack can carry one texture per tone: add PNGs in tone
order (01, 02, 03, 04, 05) to the xml's texture list and raise the entry's
`textures` (or `splitTextures`) count to match. The worn texture is picked
from the wearer's tone, clamped to what exists — so `textures = 1` (one
texture for every tone) is a complete starting point.

This pack's layered art is tone-independent; its texture list is indexed by
shape and height instead.

## Clothing item xmls

One file per eye item (per side for split art) in
`42/media/clothing/clothingitems/`, e.g. `Detail_EyesMyBlueM.xml` and
`Detail_EyesMyBlueF.xml`. Mint a **fresh GUID** per file (PowerShell:
`[guid]::NewGuid()`). Never reuse a GUID from this or any other mod.

```xml
<?xml version="1.0" encoding="utf-8"?>
<clothingItem>
    <m_MaleModel></m_MaleModel>
    <m_FemaleModel></m_FemaleModel>
    <m_GUID>PASTE-FRESH-GUID-HERE</m_GUID>
    <m_Static>false</m_Static>
    <m_AllowRandomHue>false</m_AllowRandomHue>
    <m_AllowRandomTint>false</m_AllowRandomTint>
    <m_AttachBone></m_AttachBone>
    <m_BaseTextures>EyesMyPack/EyesMyBlue</m_BaseTextures>
</clothingItem>
```

(`m_BaseTextures` is the texture path minus `media/textures/` and `.png`.)

### Several textures on one item

**Repeat the element — do not comma-join.** A texture list is one
`<m_BaseTextures>` element per texture, in the order the lua will index:

```xml
    <m_BaseTextures>EyesMyPack/EyesMyBlue01</m_BaseTextures>
    <m_BaseTextures>EyesMyPack/EyesMyBlue02</m_BaseTextures>
    <m_BaseTextures>EyesMyPack/EyesMyBlue03</m_BaseTextures>
    <m_BaseTextures>EyesMyPack/EyesMyBlue04</m_BaseTextures>
    <m_BaseTextures>EyesMyPack/EyesMyBlue05</m_BaseTextures>
```

A comma-joined list is read as a single (broken) path, and the item then
fails to load — which silently drops the script item that points at it, and
the game logs `Couldn't find item <your type>`.

## Script items

One `item` per xml under your own script module (e.g. `module MyEyes` with
`imports { Base }` in `42/media/scripts/MyEyes.txt` - the module owns your
locations and item names, so the example item below is
`MyEyes.Detail_EyesMyBlueM` in full). `item` and `ClothingItem` must match
the xml filename. The `BodyLocation` is what makes it an eye - your own
slot no other mod uses (here `myeyes:eyes`), single-item so the engine
enforces one pair at a time. Use all-lowercase location ids; the engine
normalizes registered ids and mixed case does not resolve.

```
    item Detail_EyesMyBlueM
    {
        DisplayCategory = MaleBody,
        ItemType = base:clothing,
        ClothingItem = Detail_EyesMyBlueM,
        BodyLocation = myeyes:eyes,
        Tags = MyEyes:Eyes,
        hidden = true,
        Weight = 0,
    }
    item Detail_EyesMyBlueF
    {
        DisplayCategory = MaleBody,
        ItemType = base:clothing,
        ClothingItem = Detail_EyesMyBlueF,
        BodyLocation = myeyes:eyes,
        Tags = MyEyes:Eyes,
        hidden = true,
        Weight = 0,
    }
```

**The module block needs its own brace line.** A script file that starts

```
module MyEyes
    imports
```

instead of

```
module MyEyes
{
    imports
```

does not parse, and *no* item in the file is registered — the game then
logs `Couldn't find item <type>` for every one of them. If your items are
missing, check this first.

Split items use the mod's eye slots: `hydeyes:lefteye` for the left item
and `hydeyes:righteye` for the right one.

## GUID table

Register every xml in `42/media/fileGuidTable.xml`:

```xml
	<files>
		<path>media/clothing/clothingItems/Detail_EyesMyBlueM.xml</path>
		<guid>PASTE-THE-SAME-GUID-AS-THE-XML</guid>
	</files>
```

## Traits (B42)

This mod ships the **Heterochromia** trait: a 1-point disadvantage that
gives a character two different eye colors. With the trait picked on the
traits screen, the creation screen swaps the single eye color dropdown for
**Left Eye Color** and **Right Eye Color**, and the two can never match —
not even from the randomize button.

Traits are data-driven in B42, so a third-party pack can add its own the
same way. Two pieces:

**1. Register the trait** in `media/registries.lua` (the game loads this
file at boot, before the script files):

```lua
MyEyesRegistries = MyEyesRegistries or {}
MyEyesRegistries.pirate = CharacterTrait.register("MyEyes:pirate")
```

**2. Define it** in a script file, e.g. `media/scripts/MyEyesTraits.txt`:

```
module MyEyes
{
    character_trait_definition MyEyes:pirate
    {
        IsProfessionTrait = false,
        DisabledInMultiplayer = false,
        CharacterTrait = MyEyes:pirate,
        Cost = -3,
        UIName = UI_trait_pirate,
        UIDescription = UI_trait_piratedesc,
    }
}
```

- `Cost` is signed: **negative is a disadvantage** (it gives trait points
  back), positive is an advantage. `Cost = -1` is a 1-point disadvantage.
- `UIName` / `UIDescription` are translation keys. The trait name and
  description keys (`UI_trait_*`) belong in `UI.json` in the same
  translation folder, next to `IG_UI.json` (which holds the `IGUI_*`
  row and option labels).
- The icon is a small PNG at `media/ui/Traits/trait_<name>.png`, named
  after the trait exactly as written in the definition block
  (`trait_heterochromia.png` for `heterochromia`). The base game uses
  **18x18** for most traits and **16x16** for a few — either is fine. The
  base game's icons live in `media/ui/Traits/` next to the game install.
- **Register before you define.** A `character_trait_definition` pointing
  at an unregistered trait aborts script loading — and a broken script file
  takes every item in it down with it.

## Labels

`labelKey = "IGUI_MyEyes_Blue"` shows that key's text. One JSON file,
`42/media/lua/shared/Translate/EN/IG_UI.json`:

```json
{
    "IGUI_MyEyes_Blue": "Eyes My Blue"
}
```

(`label` skips all that and shows raw text — fine for testing, prefer a key
for release.)

## mod.info

```ini
name=My hydEyes Pack
id=myHydEyes
require=\hydEyes
```

`require` guarantees the dropdown exists. No load-order tricks needed.

## Field reference

| Field | Meaning |
|---|---|
| `male` / `female` | Your M/F single-slot script item full types (module included). Required for a legacy entry. |
| `maleL` / `maleR` | Optional left/right items, male fit. Worn on `hydeyes:lefteye` / `hydeyes:righteye`. |
| `femaleL` / `femaleR` | Optional left/right items, female fit. |
| `textures` | Textures on the single-slot items, tone order (01-05). Default 1. |
| `splitTextures` | Textures on each split item. Default: same as `textures`. |
| `layered` | `true` for shape/height art with lash layers. `splitTextures` must be `hydEyesData.eyeTextureCount()`. |
| `label` / `labelKey` | Dropdown text. One of them is required. |
| `code` | Optional short code label. |

## Engine notes that will save you an afternoon

- **Texture lists are repeated elements**, not comma-joined strings (see
  above).
- **Pick the worn texture with `setBaseTexture(index)`, never
  `setTextureChoice`.** The renderer uses `textureChoices[textureChoice]`
  when an item has `<textureChoices>` entries and `baseTextures[baseTexture]`
  otherwise. `setTextureChoice` on an item without `<textureChoices>` is an
  out-of-range choice, and the engine re-rolls a *random* texture every
  time it rebuilds the model — the eyes flicker between textures while the
  mouse moves.
- **Set the base texture even for index 0.** An item with several base
  textures and no explicit choice is rendered with a random one, so the
  first texture flickers if you only set it when the index is greater than
  zero.
- For per-tone art the tone index is the body number minus one: body `01`
  → index 0.
- A trait is registered in `media/registries.lua` and defined in a script
  file with `character_trait_definition` (see the Traits section). A
  negative `Cost` is a disadvantage.

## Checklist before publishing

1. Every PNG has an xml, script item, GUID-table line, and registry entry
   (and a label that resolves).
2. All GUIDs fresh; no `item` name collides with this pack.
3. `require` set in `mod.info`.
4. The script file's module block has its brace on its own line.
5. Tested in creation: entry listed, hover previews, selection persists into
   the game, and the chosen shape/height/lash/colour matches.
6. Layered packs: the bloodshot layers appear while drunk, badly sick or
   furious, match the chosen shape and height per eye, deepen as the stats
   rise (up to six layers), and go away again once the stats recover.
7. The infected layers appear as zombie infection climbs (10/21/41/61/81%)
   and at 90% sickness, match the eye shape and height, and sit under the
   bloodshot layers when both are active.
