# Design: Fantasy Party Deckbuilder (working title)

**Date:** 2026-09-04
**Status:** Approved, pending implementation plan

## Summary

A Slay the Spire 2-style deckbuilding roguelike, built in Godot 4 /
GDScript, with an original party of comedic fantasy archetypes in the
spirit of *Donjon de Naheulbeuk*'s bickering-adventurers tone (no
copyrighted names, characters, dialogue, or plot — an original cast
and story built to evoke the same feel). Adds a persistent
meta-progression layer (per-class talent trees) on top of STS's
run-based deckbuilding, so runs still fully reset while characters
still permanently grow between runs.

## 1. Core loop

Two nested loops:

- **Run loop** (fully resets each time, STS-faithful): climb a
  branching node map across Acts, fighting turn-based card-battle
  combats, ending in a boss. Death or victory ends the run.
- **Camp loop** (persistent): after a run, return to Camp with
  earned meta-currency ("Renown"), spend it on your class's talent
  tree, then start a fresh run with an improved baseline.

## 2. Playable classes

Seven archetypes, each with a distinct stat focus and mechanical
identity, mirroring how STS's Ironclad/Silent/Defect/Watcher each
play differently:

| Class | Stat focus | Mechanical identity |
|---|---|---|
| Dwarf (Guardian) | STR / VIT | Tank: Block carries over turns, counter-attacks, thorns |
| Elf Ranger | AGI | Combo: multi-hit cards build "Focus" stacks for a burst finisher |
| Barbarian | STR | Berserk: spends own HP for power, Fury stacks raise damage/lower defense |
| Thief | AGI / LUK | Risk/reward: poison, gold-synergy cards, can steal a card from the enemy |
| Ogre | VIT | Huge HP, few but massive hits; cards get cheaper as HP drops |
| Wizard | INT | Chaotic caster: volatile Mana stacks, spells can "overload" for bonus or backfire |
| Cleric | INT / WIS | Sustain: stacking Faith buffs, heavy self-heal/block generation |

**Phasing:** build shared systems generically, ship Phase 1 with
**Dwarf, Elf Ranger, Wizard** (covers the tank / combo / chaos-caster
spread, mirroring STS's original 3-character spread). Add Barbarian,
Thief, Ogre, Cleric in Phase 2 using the same framework. Phase 2
classes also double as Camp unlock milestones (see §5).

## 3. Combat system

- **Resource:** per-turn spend resource (3 baseline), STS's Energy
  reflavored per class in UI only (Dwarf: Stamina, Wizard: Mana,
  Cleric: Faith, etc.) — mechanically identical across classes.
- **Card types:** Strike (offense), Technique (utility — block/draw/
  buff), Trait (persistent passive for the run — STS's Powers).
- **Enemy intents:** telegraphed next-move icons (attack+damage,
  defend, buff, debuff, special), STS-style.
- **In-run status effects:** Strength-equivalent, Dexterity-
  equivalent, Poison, Weak, Vulnerable — temporary stacks from cards/
  potions/relics, reset every run. Kept mechanically separate from
  persistent stats (below).
- **Persistent stats → run baseline:** talent-tree stats (STR, AGI,
  INT, VIT, LUK) set the run's *starting* baseline — STR raises base
  Strike damage, VIT raises base max HP, AGI raises base card draw/
  evasion, INT reduces Wizard overload-backfire odds, LUK raises
  crit/loot chance. In-run buffs then stack on top of that raised
  baseline. Persistent stats never directly modify in-run buff math;
  they only set where a run starts from.
- **Elites & bosses:** elite fights (harder, better rewards) and one
  Act-ending boss per Act with a unique gimmick, same cadence as STS.

## 4. Map & run structure

3 Acts per run (Act 4 postgame is an explicit stretch goal, not in
initial scope — see STS's own history). Each Act is a branching node
map:

- **Combat** — standard fight
- **Elite** — tougher single enemy, relic-weighted rewards
- **Event** — narrative encounter with choices/consequences; primary
  venue for comedic party-banter writing (see §6)
- **Rest Site** — heal HP, or upgrade one specific card
  (per-run-permanent for that card; resets with the deck each run —
  distinct from and additive to persistent stats)
- **Shop** — spend gold on cards, relics, potions, card removal
- **Treasure** — guaranteed relic
- **Boss** — Act-ending fight, unique gimmick

**Relics** are run-long passive items, the main build-around system
within a single run, granted via combat rewards, events, shops, and
treasure nodes.

## 5. Camp & meta-progression

Camp is the party's home base between runs — also the hub for
between-run narrative beats (§6). Runs earn **Renown**, scaled by
floor reached, kills (incl. elites/bosses), and win/loss. Renown is
spent per-class on a branching **talent tree**:

- **Stat nodes** — permanently raise that class's STR/AGI/INT/VIT/LUK
  baseline
- **Unlock nodes** — new starting cards, deeper card/relic reward
  pools, extra potion slot, starting gold
- **Capstone node** — one class-defining permanent perk (e.g. Dwarf:
  start every run with a permanent Thorns aura)

Phase 2 classes (Barbarian, Thief, Ogre, Cleric) unlock via Camp
milestones, giving long-term goals beyond stat growth alone.

**Explicitly deferred:** an Ascension-style escalating-difficulty
ladder (STS's answer to "what's left after you've won", to prevent
permanent stat growth from eventually trivializing runs) was
discussed and intentionally deferred — post-run progression already
carries weight through story beats, new floors/content, and rewards,
and difficulty scaling can be revisited once the core loop is proven
out and that risk is actually observed rather than assumed.

## 6. Story & tone

Original party of the seven archetypes above, written with the same
absurd, bickering-adventuring-party comedy *Donjon de Naheulbeuk* is
known for — no copyrighted names, dialogue, or plot beats, only the
tone: a mismatched crew sent after a vague, probably-doomed quest,
constantly undercutting each other and stumbling into trouble across
the climb.

Writing lives in three places (systems must expose hooks for all
three, actual copy is written once systems exist to hang it on):

- **Event nodes** — where most actual "story" plays out
- **Camp dialogue** — between-run banter reacting to how the last run went
- **Flavor text** — card/relic/enemy names and quips

## 7. Technical architecture (Godot 4 / GDScript)

**Data-driven content:** Cards, Relics, Enemies, Status Effects, and
Talent nodes are Godot `Resource` (.tres) files with a small attached
script — not hardcoded per-item logic. A card resource holds cost,
type, target, and a list of effect resources (Damage, Block,
ApplyStatus, Draw, ...) that a generic effect-resolver executes. This
is what makes the full-roster content volume (50+ cards, dozens of
relics, a full enemy roster) tractable without a script-per-card
explosion — new content becomes editor resource authoring, not new
code.

**Autoload singletons:**

- `RunState` — resets each run: deck, HP, gold, relics, map
  position, current Act
- `MetaState` — persistent: Renown, per-class talent unlocks,
  unlocked classes; saved to `user://` on every Camp visit
- `CombatManager` — turn engine: draw, resource spend, effect
  resolution, enemy intent execution
- `SaveManager` — reads/writes `MetaState`, and an in-progress
  `RunState` snapshot so a run can be resumed after quitting

**Scenes:** MainMenu → CampHub (talent trees, class select) →
MapView (node graph) → {CombatScene, EventScene, ShopScene,
RestScene} → VictoryScene/GameOverScene → back to CampHub.

## 8. Testing

- **GUT** (Godot's community-standard GDScript test addon) covers
  pure logic: card effect resolution, damage/block math, status-effect
  stacking, talent-tree stat application.
- Map generation, combat feel, and UX are verified by actually
  running the game in the Godot editor and playing it through, not
  just by claiming tests pass — mirrors how UI/feature work is
  verified generally.

## Open items for later (explicitly out of scope now)

- Ascension-style difficulty ladder (§5)
- Act 4 postgame content
- Phase 2 classes: Barbarian, Thief, Ogre, Cleric
