# Vanilla Eyes (`hydEyes`)

512x512 eye colors in 12 shades for the vanilla bodies, picked from a dropdown
on the character creation screen.

> **Open Disclosure.** I utilize several daemons through *opencode* in my
> workflow for formatting, code analysis, debugging, and testing. *I'm not
> concerned about your opinion on that*, so keep it to yourself.

## Contents

- **Eye colors in 12 shades** — Amber, Black, Blue, Brown, Gray, Green, Hazel,
  Light Amber, Light Blue, Light Brown, Light Green, Light Hazel — with
  separate male/female fits and per-skin-tone texture slots.
- **Creation dropdown** — pick your color right after the beard section. Hover
  previews, the dice rolls eyes too, and outfit/gender changes keep your pick.

## Standalone, no framework

Eyes are ordinary clothing worn at the mod's own `hydeyes:eyes` slot —
nothing else in the game uses it, so glasses, makeup, and masks never
interfere. Single-item, so the engine itself enforces one pair at a time.
They ride the
creation desc into the game, then persist and sync like any other worn item.
No requirements, no known incompatibilities.

**Dedicated servers must install this mod too** — clients need the textures.

## For Modders — add your own eyes

This pack is a framework: register entries and they appear in the creation
dropdown automatically. Full guide: [WIKI.md](WIKI.md).

## Conditional compat patches

No extra requirements; each activates only if its target mod is present:

- GridCharacterHub: the health-view model keeps your eyes instead of dropping
  them.
- ItIsOfInterestToMe: your ID card photo wears your eyes, snapshotted per
  card so it survives session reloads, and your own card's printed eye color
  matches them. Random NPC cards stay vanilla.

Multiplayer and splitscreen are **untested** — single-player is verified.
The code paths are set up to work (per-player picks keyed by player index,
engine-synced worn clothing), but neither has been confirmed in a live
session yet.

## Roadmap / TODO

- **Bloodshot eyes for the Stoned moodlet** — alternate bloodshot texture per
  eye color, swapped in while the moodlet is active.
- **Blinking** — one closed-eye graphic (color-independent), blinked
  periodically.
- **Multiplayer / splitscreen confirmation** — verify picks and rendering
  per player. Single-player only so far.

## Credits

- hydnplynsyt — 512x512 eye color overlays and standalone implementation.

---

Mod ID: `hydEyes`
