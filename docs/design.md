# Dungeon Defense — Game Design

Status: **draft v1**. Items marked **[OPEN]** are undecided. Everything else is decided
unless changed here.

## Pitch

You are the dungeon. Dig rooms, fill them with traps and monsters, and guard your hoard.
Greedy adventurers come in, hunt for your gold, and try to carry it out. The ones who die
drop their loot. That loot builds a bigger, deadlier dungeon, and a deadlier dungeon draws
braver, richer adventurers.

## Core loop

1. **Adventurers arrive** at the Entrance at a steady rate (faster as Infamy grows).
2. They **head for a Treasure room**, taking damage in every room they pass through.
3. In a Treasure room they **grab Gold** (up to their carry capacity), which comes straight
   out of your Gold.
4. They then **walk back to the Entrance**. Only an adventurer who gets *out* has escaped.
5. **If an adventurer dies**, you get their bounty (Gold scaled by tier) *plus* any Gold
   they were carrying.
6. **If they escape**, the carried Gold is gone and Infamy drops.
7. **Spend Gold** on new rooms, room upgrades, and monsters. Growing the dungeon raises
   Infamy, which brings tougher, richer adventurers.

**Gold is both your money and the bait.** Spending it is safe. Gold that's carried off is lost.
Because escaping means a round trip, Treasure rooms deep in the dungeon are safer. That
gives the player a real layout choice: how far from the Entrance should the hoard sit?

### The click

**Click an adventurer to hit them** (direct damage). Early on this is your main source of
kills, and especially a way to stop a fleeing thief. Upgrades scale click damage later.

## The dungeon (sprawling layout)

- The dungeon is a **grid of room cells** (`Vector2i` coords). It starts with an
  **Entrance** and one **Treasure room** next to it.
- **Building**: pick an empty cell next to an existing room and buy a room there.
  The cost goes up with every room (around ×1.15 per room, as is usual for the genre).
- **Connections**: a new room connects to the room it was built off of, so the dungeon is a
  **tree** and has exactly one path between any two rooms. That keeps pathing simple
  and means the player can never block the treasure off.
  **[OPEN]** Later: buy extra doors to make loops and choices (this needs smarter pathing).
- Each room has:
  - a **type** (Spike Corridor, Goblin Den, Flooded Hall, Treasure, ...) that sets its damage
    and behavior,
  - a **level** (upgrade with Gold for more damage),
  - **monster slots** (later).
- **Treasure rooms** are a room type. More than one is allowed **[OPEN: how many]**.
  Adventurers target the nearest one that has Gold in it.
- Adventurers spend `room_traverse_time / speed` seconds in a room and take that room's DPS
  the whole time.

### Where Gold "is"

There's one Gold total (the number in the HUD). Treasure rooms are where adventurers
*take* it from, and they don't each store a separate amount. **[OPEN]** Later idea: each vault
has a capacity, and Gold beyond it doesn't count, so the player has to build more vaults.

## Adventurers

| Tier | Example | HP     | Speed  | Carry  | Bounty    | Notes                    |
|------|---------|--------|--------|--------|-----------|--------------------------|
| 1    | Peasant | low    | normal | small  | low       | Shows up from the start  |
| 2    | Fighter | medium | slow   | medium | medium    | Unlocks with Infamy      |
| 3    | Rogue   | low    | fast   | large  | high      | Fewer seconds in each room, takes lots of gold |
| 4    | Cleric  | medium | normal | medium | high      | Heals over time          |
| ...  | Paladin | high   | slow   | medium | very high | Resists some room types  |

Traits counter certain rooms, which pushes the player to mix room types.

## Resources

| Resource   | Gained by                         | Lost by        | Spent on                     |
|------------|-----------------------------------|----------------|------------------------------|
| **Gold**   | Kills (bounty + recovered loot)   | Escapes        | Rooms, levels, monsters      |
| **Infamy** | Kills, dungeon size               | Escapes        | Not spent: sets spawn rate and tier |
| **Souls**  | Prestige                          | —              | Permanent upgrades           |

## Prestige

**"Collapse the dungeon"**: reset rooms, Gold, and Infamy, and earn **Souls** based on lifetime
Gold or room count. Souls buy permanent multipliers and new room types.
**[OPEN]** formula.

## Idle & offline

- The dungeon runs on its own while the game is open.
- Offline progress gives credit for time away (cap around 8h, upgradable), shown on a
  "While you were away..." summary. In a browser, a background tab gets throttled, so
  catch-up has to work from timestamps, not frame counts.

## Presentation

- **Isometric** view built from Kenney's *Isometric Miniature Dungeon* (CC0). These are
  pre-rendered 2D sprites, not 3D models (see CLAUDE.md → Art).
- Each room cell becomes a small block of floor tiles with walls. Doorways (archway tiles)
  mark the connections.
- Adventurers use the pack's character (8 directions: run, idle, pickup). The *pickup*
  animation plays when they grab gold. Tiers are told apart by color tints at first.
- Damage numbers, gold pop-ups, and screen shake give the feedback.
- **Gaps in the pack**: no monsters, traps, or death effects. Placeholders for now.
  Other Kenney CC0 packs may fill these. **[OPEN]**
- Shop/build UI sits on top of the isometric view. Camera pans and zooms.

## Platforms

Desktop (Windows) and **Web** (HTML5, e.g. itch.io). See CLAUDE.md → Web build.

## Milestones

1. **Slice 1 (core loop):** grid dungeon with Entrance and Treasure. Build one room type on
   adjacent cells. Peasants path to treasure, grab gold, and walk out. Click to hit. Gold HUD.
   Rooms drawn as colored rectangles, no art yet.
2. **Slice 2:** isometric art pass with the Kenney tiles and character.
3. **Slice 3:** 3–4 room types, room levels, 2–3 adventurer tiers, Infamy.
4. **Slice 4:** save/load, autosave, offline progress. First web export.
5. **Slice 5:** monsters in room slots, upgrades shop.
6. **Slice 6:** prestige.
7. Later: extra doors/loops, vault capacity, achievements, balancing.

## Open questions

- Extra doors / loops in the layout, and if so, how adventurers choose a route.
- Limit on the number of Treasure rooms? Vault capacity?
- Art to use for monsters and traps.
- Prestige formula.
