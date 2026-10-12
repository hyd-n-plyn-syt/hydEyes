# Eye Pack Wiki — adding your own eyes to the hydEyes framework

This mod (`hydEyes`) doubles as a framework: any other mod can add its
own eye colors and they show up in the character creation dropdown, persist,
and sync with zero extra code. No lua framework to copy — you just register
entries.

You need: this mod, and basic familiarity with Zomboid clothing items. All
paths below are relative to your mod's folder.

## The eye entry (the only lua you write)

One file, e.g. `42/media/lua/shared/MyEyes.lua`. The `AddEye` function
already ships in this mod — you only write entries:

```lua
hydEyesData.AddEye({
    label = "My Blue",                   -- plain label ...
    labelKey = "IGUI_MyEyes_Blue",       -- ... or translation key (preferred)
    male = "MyEyes.Detail_EyesMyBlueM",    -- male-fit item ...
    female = "MyEyes.Detail_EyesMyBlueF",  -- ... and female-fit item (see below)
    textures = 1,                        -- per-skin-tone textures on the items
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

## Textures

512x512 PNGs under `media/textures/`, e.g.
`media/textures/EyesMyPack/EyesMyBlue.png` — same eye layout as this
pack's template so they fit the vanilla heads.

Male and female heads lay the eye area out differently, so each color ships
as a male/female item pair (below). Start both on one shared texture; when
per-sex art lands, point each xml at its own PNG.

Skin tones may also shift the layout. Items support a texture per tone
without new items: add PNGs in vanilla skintone order (index 0-4) to the
xml's texture list and raise the entry's `textures` count to match. The worn
texture is picked from the wearer's tone, clamped to what exists — so
`textures = 1` (one texture for every tone) is a complete starting point.

## Clothing item xmls

One file per eye per sex in `42/media/clothing/clothingitems/`, e.g.
`Detail_EyesMyBlueM.xml` and `Detail_EyesMyBlueF.xml`. Mint a **fresh GUID**
per file (PowerShell: `[guid]::NewGuid()`). Never reuse a GUID from this or
any other mod.

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

## Script items

One `item` per xml under your own script module (e.g. `module MyEyes` with
`imports { Base }` in `42/media/scripts/MyEyes.txt` - the module owns your
locations and item names, so the example item below is
`MyEyes.Detail_EyesMyBlueM` in full). `item` and `ClothingItem` must match
the xml filename. The `BodyLocation` is what makes it an eye - your own
slot no other mod uses (here `MyEyes:Eyes`), single-item so the engine
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

## GUID table

Register every xml in `42/media/fileGuidTable.xml`:

```xml
	<files>
		<path>media/clothing/clothingItems/Detail_EyesMyBlueM.xml</path>
		<guid>PASTE-THE-SAME-GUID-AS-THE-XML</guid>
	</files>
```

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
| `male` / `female` | Your M/F script item full types (module included). At least one required. |
| `textures` | Per-skin-tone textures per item, vanilla tone order (0-4). Default 1. |
| `label` / `labelKey` | Dropdown text. One of them is required. |
| `code` | Optional short code label. |

## Checklist before publishing

1. Every PNG has an xml, script item, GUID-table line, and registry entry
   (and a label that resolves).
2. All GUIDs fresh; no `item` name collides with this pack.
3. `require` set in `mod.info`.
4. Tested in creation: entry listed, hover previews, selection persists into
   the game.
