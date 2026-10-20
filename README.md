# Vanilla Eyes (`hydEyes`)

512x512 eye colors in 12 shades for the vanilla bodies, picked from a dropdown on the character creation screen.

> **Open Disclosure.** I utilize several daemons through *opencode* in my workflow for formatting, code analysis, debugging, and testing. *I'm not concerned about your opinion on that*, so keep it to yourself.

## Contents

- **Eye colors in 12 shades** — Amber, Black, Blue, Brown, Gray, Green, Hazel, Light Amber, Light Blue, Light Brown, Light Green, Light Hazel — with separate male/female fits.
- **Split left/right eyes** — each color ships its own left-eye and right-eye art, worn on two separate slots, so the eyes sit where they belong instead of being one combined overlay.
- **Per-skin-tone art** — five skin tones, each with its own eye artwork (tone 01 is the palest, 05 the darkest), drawn for male and female bodies separately.
- **Heterochromia trait** — a 1-point disadvantage that gives a character two different eye colors. With the trait picked, the creation screen swaps the single dropdown for **Left Eye Color** and **Right Eye Color**, and the two can never match, even from the randomize button.
- **Creation dropdown** — pick your color right with the other body options. Hover previews, random button picks eyes too, and outfit/gender/skin-tone changes keep your pick.
- **Original art kept as a fallback** — the pre-split graphics are still in the mod, and a tickbox in **Options → MODS → Vanilla Eyes** switches the whole mod back to them.

## Standalone, no framework

Eyes are ordinary clothing worn at the mod's own slots — `hydeyes:lefteye` and `hydeyes:righteye` for the split eyes, `hydeyes:eyes` for the fallback pair — nothing else in the game uses them, so glasses, makeup, and masks never
interfere. They ride the creation desc into the game, then persist and sync like any other worn item. - No requirements, no known incompatibilities.

**Dedicated servers must install this mod too** — clients need the textures.

## Options

**Options → MODS → Vanilla Eyes**

- **Use original eye graphics** — reverts to the old combined eye art (one piece for both eyes, one style for every skin tone) on the single `hydeyes:eyes` slot. The split art is the default. Toggling re-dresses your current character immediately, so you can compare the two without a restart. The original art is a single piece, so it cannot show two colors — with the fallback on, Heterochromia is off and the single Eye Color dropdown is used.

## For Modders — add your own eyes

This pack is a framework: register entries and they appear in the creation dropdown automatically. Full guide: [WIKI.md](WIKI.md).

## Conditional compat patches

No extra requirements; each activates only if its target mod is present:

- GridCharacterHub: the health-view model keeps your eyes instead of dropping them — both the left and the right slot.
- ItIsOfInterestToMe: your ID card photo wears your eyes, snapshotted per card so it survives session reloads, and your own card's printed eye color matches them. A heterochromia character prints both codes, left eye first (e.g. `BLU/GRN`). Random NPC cards stay vanilla.

Multiplayer and splitscreen are **untested** — single-player is verified. The code paths are set up to work (per-player picks keyed by player index, engine-synced worn clothing), but neither has been confirmed in a live session yet.

## Roadmap / TODO

- **Blinking** — closed-eye graphics are drawn for every skin tone and gender; the blink timing and swap are not wired up yet.
- **Bloodshot eyes for the Stoned moodlet** — alternate bloodshot texture per eye color, swapped in while the moodlet is active.
- **Multiplayer / splitscreen confirmation** — verify picks and rendering per player. Single-player only so far.

## Credits

- hydnplynsyt — 512x512 eye color overlays and standalone implementation.

---

Mod ID: `hydEyes`
