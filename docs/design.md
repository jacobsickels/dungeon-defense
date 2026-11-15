# Dungeon Defense — Game Design

Status: **draft v6**. Items marked **[OPEN]** are undecided. Everything else is decided
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
- Each level costs `base_cost × cost_growth^level` (×1.15, **per room type**, so cheap rooms stay
  worth upgrading as pricier ones unlock).
- **Rooms show their level**: each level adds a visible piece (a spike, a skeleton, a book, a
  dish, ...), so what you see is what's hurting adventurers.
- **Nothing depends on where a room sits in the line.** Effects that reach beyond a room
  (poison, global bonuses) are built so their value is the same wherever the room is.

### How rooms hurt

| Kind | How it works | Rooms |
|---|---|---|
| **Hazard** | One hazard per level at fixed spots (`HazardLayout`). Each hits once as an adventurer walks past, and that specific piece animates. Once the room is full, further levels make each hit stronger, so every level is worth the same. | Spike Corridor, Skeleton Crypt, Mimic Treasury, Animated Armory, Glyph Hall |
| **Damage over time** | Hurts the whole time an adventurer is inside, so slow walkers (Heavy Packs) bleed more. | Gelatinous Cube, Haunted Library |
| **Poison** | Picked up on entering, dealt over 4 s wherever they go. Anything left lands when they fall, so the Banquet pays the same anywhere in the line. | Cursed Banquet |
| **Pulse** | Every 3 s, hits everyone inside at once. Best when the dungeon is crowded. | Rolling Boulder |
| **Global** | Boosts the whole dungeon. | Lich's Phylactery (+5% all blood per level), Blood Altar (+damage on every hit per level) |

### The rooms (in line order)

| Room | D&D idea | Kind | Each level adds | Build cost | Per level |
|---|---|---|---|---|---|
| Spike Corridor | Pit trap | Hazard (121 spots) | a spike | 15 | 3 per spike |
| Skeleton Crypt | Undead guardians | Hazard (20 spots, beside the path) | a Skeleton Minion that swings | 100 | 15 per skeleton |
| Mimic Treasury | The chest bites | Hazard (20 spots, along the walls) | a mimic chest that snaps | 1.1K | 24 per bite |
| Gelatinous Cube | Engulfing cube | Damage over time | the cube grows (to a max size) | 12K | 30 dps |
| Animated Armory | Floating swords | Hazard (28 spots) | a sword that slashes | 130K | 320 per slash |
| Haunted Library | Biting spellbooks | Damage over time | a flying book (up to 24) | 1.4M | 384 dps |
| Glyph Hall | Glyph of Warding | Hazard (49 spots) | a rune that flares | 20M | 5.5K per rune |
| Cursed Banquet | Poisoned feast | Poison | a dish on the tables (up to 16) | 330M | 30K poison |
| Rolling Boulder | The rolling-stone trap | Pulse every 3 s | a bigger boulder | 5.1B | 155K per hit |
| Lich's Phylactery | A lich's soul gem | Global | a candle (up to 14), brighter gem | 75B | +5% all blood |
| Blood Altar | Drinks every wound | Global | a candle or bottle (up to 14) | 1T | +15K damage per hit |

Each tier is about 3× less efficient per blood spent than the one before
(`V ≈ C / (5 · 3^tier)`), as in Cookie Clicker. Room data is generated by
`tools/generate_rooms.py`: edit it there and rerun it.

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

| Lure | Per level | Base cost (growth) | Max |
|---|---|---|---|
| Advertisements | arrivals ×1.3 | 40 (×3.0) | 10 |
| Plump Pilgrims | blood per damage ×1.4 | 60 (×3.5) | 10 |
| Heavy Packs | walking speed ×0.85 (more time in damage-over-time rooms) | 50 (×3.0) | 5 |

Lures are capped, like Cookie Clicker's upgrades. Unlimited levels of multipliers made every
room's payback shrink with them, and the whole room lineup unlocked in about 11 minutes.

Effects stack multiplicatively and are fixed when an adventurer arrives. Data is in
`res://data/lures/`.

### Pacing (measured)

A bot that always buys the cheapest thing (any room level or lure level), with **no clicking**:

| Room | First built at |
|---|---|
| Skeleton Crypt | 2:20 |
| Mimic Treasury | 4:00 |
| Gelatinous Cube | 6:10 |
| Animated Armory | 8:10 |
| Haunted Library | 12:50 |
| Glyph Hall | 22:50 |
| Cursed Banquet | 1:16:00 |
| Rolling Boulder, Phylactery, Altar | after 2 hours |

blood/s: 1.2K at 5 min, 130K at 10 min, 2.9M at 30 min, 13M at 2 h. New rooms come quickly
at first, then further and further apart: the Cookie Clicker curve.

- **[OPEN] Crowd ceiling.** `MAX_ADVENTURERS` (50) is reached at about 10 minutes, after which
  extra arrivals are dropped, so the last Advertisements levels are partly wasted, and the
  Rolling Boulder's "crowd" bonus tops out. Likely fix: **parties** (one model = a group of N).
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
