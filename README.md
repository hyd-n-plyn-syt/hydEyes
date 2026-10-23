# Vanilla Eyes (`hydEyes`)

512x512 eye colors in 12 shades for the vanilla bodies, with selectable eye shape, eye height, and lash length. Everything is picked from dropdowns on the character creation screen.

> **Open Disclosure.** I utilize several daemons through *opencode* in my workflow for formatting, code analysis, debugging, and testing. *I'm not concerned about your opinion on that*, so keep it to yourself.

## Contents

- **Eye colors in 12 shades** — Amber, Black, Blue, Brown, Gray, Green, Hazel, Light Amber, Light Blue, Light Brown, Light Green, Light Hazel — with separate male/female fits.
- **Eye shapes** — four shapes (`01`–`04`) selected from the **Eye Shape** dropdown.
- **Eye heights** — **Low**, **Normal** (default), and **High**, so the eye sits where you want on the face.
- **Lash lengths** — **None**, **Short**, and **Long**. Lashes are a separate layer drawn over the eye color.
- **Layered rendering** — face, then eyes, then lashes. Changing one layer never replaces another.
- **Split left/right eyes** — each color ships its own left-eye and right-eye art, worn on two separate slots, so the eyes sit where they belong instead of being one combined overlay.
- **Heterochromia trait** — a 1-point disadvantage that gives a character two different eye colors. With the trait picked, the creation screen swaps the single color dropdown for **Left Eye Color** and **Right Eye Color**, and the two can never match, even from the randomize button.
- **Creation dropdowns** — pick your eyes alongside the other body options. Hover previews, the random button rolls eyes too, and outfit/gender/skin-tone changes keep your picks.

## Standalone, no framework

Eyes and lashes are ordinary clothing worn at the mod's own slots — `hydeyes:lefteye` and `hydeyes:righteye` for the eye layers, `hydeyes:leftlash` and `hydeyes:rightlash` for the lash layers — nothing else in the game uses them, so glasses, makeup, and masks never interfere. They ride the creation desc into the game, then persist and sync like any other worn item. No requirements, no known incompatibilities.

**Dedicated servers must install this mod too** — clients need the textures.

## For Modders — add your own eyes

This pack is a framework: register entries and they appear in the creation dropdown automatically. Full guide: [WIKI.md](WIKI.md).

## Conditional compat patches

No extra requirements; each activates only if its target mod is present:

- GridCharacterHub: the health-view model keeps your eyes and lashes instead of dropping them — both the left and the right slots.
- ItIsOfInterestToMe: your ID card photo wears your eyes and lashes, snapshotted per card so it survives session reloads, and your own card's printed eye color matches them. A heterochromia character prints both codes, left eye first (e.g. `BLU/GRN`). Random NPC cards stay vanilla.
- Spongie's Character Customisation and Tomb's Player Body: their custom faces are drawn over the eye overlay, so the eyes and lashes are put back on top of them — the eyes show over custom faces too.

Multiplayer and splitscreen are **untested** — single-player is verified. The code paths are set up to work (per-player picks keyed by player index, engine-synced worn clothing), but neither has been confirmed in a live session yet.

## Roadmap / TODO

- **Blinking** — closed-eye graphics are not part of the current art set; the blink timing and swap are not wired up.
- **Bloodshot eyes** — bloodshot layers are drawn for every shape and height; the moodle thresholds and swap are not wired up yet.
- **Multiplayer / splitscreen confirmation** — verify picks and rendering per player. Single-player only so far.
- **Zombie eyes** — dead-eyed colored versions fitted to the zombie skins, chosen at random for them.

## Credits

- hydnplynsyt — 512x512 eye color overlays and standalone implementation.

---

Mod ID: `hydEyes`
