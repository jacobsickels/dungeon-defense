# Dungeon Defense — Game Design

Status: **draft v5**. Items marked **[OPEN]** are undecided. Everything else is decided
unless changed here.

## Pitch

You are the dungeon, and you feed on blood. Dig rooms, fill them with traps and monsters, and
bait adventurers with a pile of gold. They come in and make for the treasure, bleeding in every
room along the way, and at the end they drop through a trapdoor beside the gold. Their blood
builds a bigger, deadlier dungeon, and a bigger dungeon draws more of them.

## Core loop

1. **Adventurers arrive** at the Entrance at a steady rate (faster with Advertisements).
2. They **walk the path to the Treasure Pit**. Every point of damage they take, from rooms or
   your clicks, **bleeds blood**: the currency.
3. In the Treasure Pit they reach for the gold and **drop through the trapdoor**. That's the end
   of their trip. It's a one-way path.
4. **Spend blood** on new rooms, lures, and later upgrades and monsters.

**Adventurers can't die and can't steal.** Income is never at risk. It only grows, as in
Cookie Clicker:

`blood/s ≈ arrivals per second × total damage along the path × blood per damage`

Every room on the path adds blood/s, every lure multiplies it, and nothing ever switches off.

How we got here (so we don't go back): an earlier version had adventurers steal gold and
escape. With kills paying bounties, that meant the number could go down, lures had a failure
cliff, and adding rooms could lower income. Moving to damage → blood, with no deaths and no
escapes, removed all three.

### The click

**Click an adventurer to hit them.** Each hit bleeds blood right away (1 damage × their bleed).
That's the early-game engine before the first Spike Corridor, and the "cookie click" for the
whole game. Upgrades should scale click damage with path damage later, so clicking stays relevant.

## The dungeon (a single line)

- The dungeon is **one line of rooms**: Entrance → the rooms you own → Treasure Pit. It
  starts as just **Entrance → Treasure Pit**.
- **You own at most one of each room type.** Buying a room type the first time builds it
  in **its set place** in the line (`RoomDef.line_order`, lowest nearest the Entrance), wherever
  and whenever you buy it. Buying it again **raises its level** instead of adding a room.
  This is Cookie Clicker's building count: the level is how many you own.
- Rooms hurt in one of two ways:
  - **Hazards** (spikes): one per level, standing at fixed spots (`HazardLayout`). Each one
    hits once, for `hazard_damage`, as an adventurer walks past it. Walking speed doesn't matter.
  - **Damage over time** (`dps`, per level): for rooms like gas or fire, hurting the whole time
    an adventurer is inside, so slower walkers bleed more. (No room uses this yet.)
- The next level costs
  `base_cost × cost_growth^level` (×1.15 by default, **per room type**, so cheap rooms stay worth
  upgrading as pricier ones unlock).
- **Rooms show their level.** The Spike Corridor starts with **a single spike** in the center
  and gains one spike per level, filling outward along the walking path and then to the sides
  (121 spots, so it keeps visibly growing for a long time). **Each spike hits once (3 damage) as
  an adventurer walks past it**: they flinch and a blood popup shows the hit. What you see is
  exactly what deals damage. Interiors can also tag pieces with `min_level` / `max_level` for
  bigger changes at certain levels.
- The **Treasure Pit** is a gold pile around an open trapdoor. Adventurers walk to its center
  and fall. It deals no damage itself.
- How we got here: the first versions had a sprawling grid with branches and inserting rooms
  between others. It was replaced by the line to make it about upgrades rather than placement
  (Cookie Clicker style), and to keep the path, and with it the crowd, bounded. The grid code
  (`Dungeon`: coords, insert with subtree shift, BFS pathing) is still there and runs the line,
  so branching could return later.

## Adventurers

They can't die. What sets types apart is how they bleed:

| Stat | Effect |
|---|---|
| **Speed** | Slower walkers spend longer in every room, so they bleed more from damage over time (not from spikes) |
| **Bleed** | Blood per point of damage |
| (later) **Resistances** | Less blood from certain room types, so mixed layouts pay off |

Peasant: speed 1.0, bleed 1.0. Later tiers (Fighter, Rogue, Cleric, Paladin, ...) arrive
through lures or milestones, with KayKit Adventurers models.

### Lures

Plain upgrades with levels and rising cost (CC's "upgrades"). Each level multiplies blood/s
one way or another. There's no downside, so there's nothing to dial back.

| Lure | Per level | Base cost (growth) |
|---|---|---|
| Advertisements | arrivals ×1.3 | 40 (×3.0) |
| Plump Pilgrims | blood per damage ×1.4 | 60 (×3.5) |
| Heavy Packs | walking speed ×0.85 (longer in each room), **max level 5** | 50 (×3.0) |

- **Heavy Packs is hidden for now** (`available = false`). It only helps damage-over-time rooms,
  and none exist yet now that spikes hit per spike. Turn it back on when one is added.

Lure costs grow much faster than their effect (×3+ per level for ×1.3–1.4) on purpose. At
×1.7–1.9, three multiplicative lures plus room levels outran prices, and purchases came
*faster* over time (a runaway to 17M blood/s in 30 minutes).

Effects stack multiplicatively and are fixed when an adventurer arrives. Data is in
`res://data/lures/`.

### Pacing (measured)

A bot that always buys the cheapest thing (a Spike Corridor level or a lure level), with
**no clicking**:

| Time | blood/s | Spike Corridor | Lures (a/p) | Inside | Wait between buys |
|---|---|---|---|---|---|
| 1 min | 2 | Lv 5 | 0/0 | 2 | ~8–12 s |
| 5 min | 182 | Lv 35 | 4/3 | 4 | |
| 10 min | 1.0K | Lv 53 | 6/5 | 7 | |
| 30 min | 9.0K | Lv 77 | 9/8 | 16 | ~50–70 s |

(Spikes deal one hit per spike. Heavy Packs is hidden.)

Purchases get slowly further apart: the Cookie Clicker curve. With only one room type, the
bot sinks everything into one room. More room types are the next content need.

- **[OPEN] Crowd ceiling.** `MAX_ADVENTURERS` (50) caps how many are inside at once. With
  Heavy Packs hidden, it's 16 at 30 minutes, but Advertisements keeps raising it. Likely
  fix when it matters: **parties** (one model = a group of N, and Advertisements raises N).
- The HUD shows blood/s (a ~20 s moving average of blood from all damage).

## Resources

| Resource   | Gained by                         | Lost by | Spent on                     |
|------------|-----------------------------------|---------|------------------------------|
| **Blood**  | Damage to adventurers (rooms, clicks) | Never | Rooms, lures, upgrades, monsters |
| **Souls**  | Prestige                          | —       | Permanent upgrades           |

## Prestige

**"Collapse the dungeon"**: reset rooms, blood, and lures, and earn **Souls** based on lifetime
blood. Souls buy permanent multipliers and new room types. **[OPEN]** formula (CC uses a
cube root of lifetime production).

## Idle & offline

- The dungeon runs on its own while the game is open.
- Offline progress: blood/s × time away (cap around 8h, upgradable), shown on a
  "While you were away..." summary. Since income is steady, the measured blood/s is
  a good basis for it. In a browser, a background tab gets throttled, so catch-up has to
  work from timestamps, not frame counts.

## Presentation

- **3D low-poly with an isometric camera**, using the KayKit packs (CC0). A cutaway
  diorama: tall walls only along the back of the dungeon, low barriers everywhere else, so
  every room stays visible.
- Each room type has its own interior (floor + props). Spike Corridor has spike tiles across
  the path. The Treasure Pit has a gold chest and coin piles around an open trapdoor grate.
- Adventurers are KayKit Adventurers models (Peasant = hooded rogue for now). They run,
  flinch on entering a damaging room or when clicked, and drop through the trapdoor at the end.
  Red "+N" blood popups rise from them about once a second while they bleed, and on every click.
- **Monsters** will be KayKit Skeletons (Minion, Warrior, Rogue, Mage) standing in rooms.
- **Traps** available: floor spikes, grates and pits, and more as needed.
- Shop/build UI sits on top of the 3D view. Camera pans and zooms.

## Platforms

Desktop (Windows) and **Web** (HTML5, e.g. itch.io). See CLAUDE.md → Web build.

## Milestones

1. **Slice 1 (core loop):** done (layout, building, inserting, clicking).
2. **Slice 2:** 3D isometric art pass with KayKit. *(First version done. Still to do: polish
   and a playtest.)*
3. **Slice 3 (Cookie Clicker structure):** single-line dungeon with leveled rooms *(done)*.
   Next: more room types (tiers, each ~10× the last), multiplicative room upgrades unlocked
   by level milestones, click damage that scales, and a fix for the crowd ceiling (parties).
4. **Slice 4:** save/load, autosave, offline progress. First web export.
5. **Slice 5:** monsters in room slots, special visitor events (CC's golden cookies).
6. **Slice 6:** prestige.
7. Later: extra doors/loops, more adventurer types with resistances, achievements, balancing.

## Open questions

- The crowd ceiling: parties (one model = N adventurers) vs. capping Heavy Packs vs. both.
- What room types come after the Spike Corridor, and what each looks like as it levels up.
- Which monster types beyond the four skeletons (KayKit has no other monster pack here).
- Prestige formula.
