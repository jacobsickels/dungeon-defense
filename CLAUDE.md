# Dungeon Defense — Claude Guide

An incremental / idle game (Cookie Clicker lineage) where the player builds a dungeon
room by room. Adventurers enter, walk through the rooms, and get killed by the traps and
monsters the player placed. Kills produce resources, resources buy more rooms and upgrades.

- **Game design lives in [docs/design.md](docs/design.md).** Read it before adding gameplay.
  When a design decision changes, update that doc in the same change.
- This file covers *how* we build: engine, architecture, conventions.

## Engine & project

- **Godot 4.7.2**, GDScript only (no C#, which can't export to web).
- **Renderer: Compatibility** (OpenGL / WebGL 2), required for the web build. Don't use
  Forward+/Mobile-only features (compute shaders, SDFGI, volumetric fog, etc.).
- The game is **2D** (isometric sprites). No 3D nodes.
- Window stretch: `canvas_items` / `expand` (already set in `project.godot`).
- Godot executable: `E:\Godot\Godot_v4.7.2-stable_win64.exe`. Use the `_console.exe`
  next to it for CLI/headless runs, since it prints to stdout. Export templates for 4.7.2
  are installed.
- Edit `project.godot` through the editor where possible. Autoloads and input actions
  may be added by hand, but keep the file's formatting intact.
- `.godot/` is generated. Never edit or commit it.
- Godot writes `.uid` files next to scripts and resources. Commit them, and keep them
  next to their file when moving things (move files in the editor, or move the `.uid` too).

## Architecture

The rule that matters most: **simulation is separate from presentation.**

```
data (Resources)  ->  simulation (pure logic, ticks)  ->  signals  ->  presentation (scenes/UI)
                             ^                                              |
                             +-------------- player commands ---------------+
```

- **Simulation** (`res://core/`): plain GDScript classes (`RefCounted`) or autoloads.
  It owns all game state and math. It must never touch nodes, scenes, or `get_tree()`,
  so it can run headless, in tests, and in fast-forward for offline progress.
- **Presentation** (`res://scenes/`, `res://ui/`): nodes that *read* state and *listen*
  to signals. They send player intent back as commands (`GameState.buy_room(id)`).
  They never change state directly.
- **Fixed tick**: the simulation advances on a fixed timestep (`TICK_RATE = 10`/s),
  driven by an accumulator in `_process`, not by frame delta. Visuals interpolate or
  animate on their own.
- **Offline progress**: on load, figure out elapsed time and either run the simulation
  in a fast loop (capped) or use an averaged income rate. Pick whichever stays accurate.

### Autoloads (planned)

| Autoload    | Responsibility                                                  |
|-------------|-----------------------------------------------------------------|
| `Events`    | Global signal bus for cross-system events only (`adventurer_killed`, `room_built`). |
| `GameState` | Currencies, owned rooms/upgrades, dungeon layout. The one source of truth. |
| `Sim`       | Tick loop, adventurer spawning, combat resolution.              |
| `SaveSystem`| Serialize/deserialize `GameState`, autosave, offline time.      |
| `Content`   | Loads and indexes every content `Resource` by id.               |

Add a new autoload only for truly global state. Prefer passing references.

### Dungeon model

- The simulation models the dungeon as a **graph of rooms on a grid**: `Dictionary[Vector2i, RoomState]`
  plus connections (currently a tree: each room has one parent). It has no idea about tiles or pixels.
- Adventurers move **room to room** along a path (in a tree, the parent chain to the
  common ancestor). Their position is `(current_room, progress 0..1, next_room)`.
  Pathing is computed in `core/`, without `NavigationAgent2D` or physics.
- The presentation turns room coords into isometric tile blocks
  (`ROOM_SIZE_TILES`) and interpolates adventurer sprites along the path.
- Write pathing so it doesn't *assume* a tree. Loops are a planned feature, so a
  BFS or `AStar2D` over the room graph is the safe default.

### Data-driven content

All game content is a custom `Resource` saved as `.tres` under `res://data/`:
`RoomDef`, `MonsterDef`, `AdventurerDef`, `UpgradeDef`. Each has a stable
`id: StringName`. Adding a room or monster should mean adding a `.tres` file, not code.

Saves store **ids and numbers only**, never resource paths or object references.

### Numbers

- Use `float` (64-bit in GDScript, good to ~1e308) for currencies and scaling values.
  Don't use `int` for currencies. A real big-number type is a later decision, made only
  if progression actually goes past 1e308.
- All number display goes through one formatter (`NumberFormat.short(x)` gives
  `1.23K`, `4.56M`, ... then scientific notation). Never format currency inline.
- Cost curves, rates, and balance constants live in data or in one `Balance` script,
  never scattered as magic numbers.

## Art

- Main art: **Kenney "Isometric Miniature Dungeon"** (CC0), in
  `res://assets/third_party/kenney_isometric_dungeon/`. The pack's `License.txt` stays with it.
- These are **pre-rendered 2D sprites**, not 3D models. Each tile is a 256×512 PNG with
  4 facings (`_N/_E/_S/_W`). The floor diamond is 256×128. Use `TileMapLayer` with an
  **isometric** `TileSet` (tile size 256×128) and set texture origins so the bases line up.
- Characters: `Characters/Male/Male_<dir>_<Idle|Run|Pickup><frame>.png`. The 8 directions
  are numbered 0–7, with 10 frames for Run and Pickup. Build `SpriteFrames` from these.
- Use **y-sorting** (`y_sort_enabled`) on the world so adventurers pass correctly behind
  walls and furniture. Walls may need a separate layer.
- The sprites are large, so the camera zooms out. Set texture filtering to linear
  (this is vector-style art, not pixel art).
- The pack has no monsters, traps, or death effects. Don't invent art. Use labeled
  placeholders and log the gap in docs/design.md.

## Web build

- Target: HTML5 export, **single-threaded** (thread support off). This avoids needing
  the cross-origin-isolation headers, so it runs on itch.io and simple static hosts.
- Don't rely on threads, native file dialogs, or `OS.execute` in gameplay code.
- Saves go to `user://`, which maps to the browser's IndexedDB on web. Autosave often,
  and also on `NOTIFICATION_WM_CLOSE_REQUEST` / visibility change, because a tab can close
  without warning.
- Browsers throttle background tabs. Time progression uses wall-clock timestamps
  (`Time.get_unix_time_from_system()`) to catch up, not accumulated frame deltas alone.
- Audio only starts after the first user input on web. Don't play sound at boot.
- Check the web build at each milestone (export, then serve locally), not just at the end.

## Folder layout

```
res://
  core/        # simulation: state, combat, economy, save. No Node-dependent code.
  data/        # .tres content: rooms/, monsters/, adventurers/, upgrades/
  scenes/      # world presentation: dungeon view, room visuals, adventurer sprites
  ui/          # HUD, shop panels, tooltips, number formatting widgets
  assets/      # art, audio, fonts. Third-party packs go in assets/third_party/<pack>/
  tests/       # headless tests for core/
  docs/        # design docs. Has a .gdignore so Godot doesn't import it
```

Keep a scene and its script side by side (`room_view.tscn` + `room_view.gd`).

## GDScript conventions

- **Static typing everywhere**: typed vars, params, and returns, typed arrays
  (`Array[RoomDef]`), typed dictionaries where it helps.
- `snake_case` files, functions, and vars. `PascalCase` for `class_name` and nodes.
  `CONSTANT_CASE` for constants.
- Signals use past tense (`room_built`, `adventurer_died`). Connect in code with
  `signal.connect(callable)`, not with editor connections.
- Get child nodes with `%UniqueName` or `@onready var x: Type = $Path`. No
  `get_node("../../..")` paths that climb up the tree.
- Use `class_name` on reusable types and Resources. Private helpers start with `_`.
- Prefer composition (child nodes or Resources) over deep inheritance.
- No `await` in simulation code, because it breaks deterministic ticking.

## Testing & running

- Tests use **GUT 9.7.1** (`res://addons/gut/`, a third-party addon, so don't edit it).
  Config lives in `.gutconfig.json`.
- Test files go in `res://tests/` (subfolders allowed, e.g. `tests/core/`), named
  `test_*.gd`, `extends GutTest`, with test functions named `test_*`.
- Test `core/` logic directly: build a state, tick it N times, assert on the numbers.
  Use doubles/stubs sparingly, since core shouldn't need them.
- Run all tests headless (exits nonzero on failure):
  `"E:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd`
  Add `-gselect=<file_name_part>` to run one script, or `-gunit_test_name=<name>` for one test.
  If newly added `class_name`s aren't found, run once with `--import` first.
- The user can also run tests from the GUT panel at the bottom of the editor.
- Other headless runs:
  `"E:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . <args>`
- Add or update tests together with any `core/` change. All tests must pass before
  calling the work done.
- Before calling a gameplay change done, check the math: run a short simulation
  or a test that prints income per second over time, so it's not just "it compiles".

## Workflow notes

- Build in thin vertical slices: get one room, one adventurer type, and one currency
  working end to end before widening.
- Balance numbers will change constantly. Keep them easy to find (see *Numbers*).
- When unsure about a design question (new currency, new mechanic), ask. Don't invent one.
