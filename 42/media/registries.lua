-- Trait registries. The game loads this file at boot (ModRegistries) before
-- the script files, so the trait object exists by the time the
-- character_trait_definition in hydEyesTraits.txt is parsed. A missing
-- registration would leave that script pointing at a missing trait and
-- abort script loading.

hydEyesRegistries = hydEyesRegistries or {}

-- Heterochromia: the left and right eyes are different colors. Costs one
-- trait point (a disadvantage) because it makes a character easier to
-- identify.
hydEyesRegistries.heterochromia = CharacterTrait.register("hydEyes:heterochromia")
