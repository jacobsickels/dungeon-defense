# Dungeon Defense — Claude Guide

An incremental / idle game (Cookie Clicker lineage) where the player builds a dungeon
room by room. Adventurers walk through the rooms to a treasure pit and drop through a
trapdoor. Every point of damage the rooms (and clicks) deal along the way bleeds **blood**, the
currency, which buys more rooms and upgrades. Adventurers can't die or steal, so income only grows.

- **Game design lives in [docs/design.md](docs/design.md).** Read it before adding gameplay.
  When a design decision changes, update that doc in the same change.
- This file covers *how* we build: engine, architecture, conventions.

## Engine & project

- **Godot 4.7.2**, GDScript only (no C#, which can't export to web).
- **Renderer: Compatibility** (OpenGL / WebGL 2), required for the web build. Don't use
  Forward+/Mobile-only features (compute shaders, SDFGI, volumetric fog, etc.).
- The world is **3D** (low-poly KayKit models) seen through an **orthographic isometric
  camera**. The UI is 2D on CanvasLayers. Keep 3D cheap for WebGL 2: no per-object shadows
  from omni lights, and a modest number of lights.
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

### Core types (`res://core/`)

| Type          | Responsibility                                                   |
|---------------|------------------------------------------------------------------|
| `Simulation`  | Holds all game state: blood, dungeon, adventurers, lures, and stats. `tick(dt)`, commands (`buy_room`, `hit_adventurer`, `buy_lure`), signals. |
| `Dungeon` / `DungeonRoom` | Room graph on a grid: building, inserting, pathing.  |
| `Adventurer`  | Runtime state of one adventurer.                                 |
| `ContentDB`   | Indexes `RoomDef` / `AdventurerDef` / `LureDef` by id and loads them from `res://data/`. |
| Lures (in `Simulation`) | `lures_owned` per id, `buy_lure`, `lure_multiplier(&"blood_mult")`. Multipliers are applied when an adventurer spawns. |
| `HazardLayout`| Where a room's hazards (spikes) stand, in order: spot i for the i-th hazard. The sim hits adventurers as they pass each spot (`pass_progress`). `LevelScatter` draws them at the same spots. Change it in one place only. |
| `Balance`     | Global tuning constants.                                         |
| `NumberFormat`| All number display.                                              |

### Autoloads (`res://autoload/`)

| Autoload | Responsibility                                                      |
|----------|---------------------------------------------------------------------|
| `Game`   | Owns `Game.sim` and runs it on the fixed tick. `tick_fraction()` for smoothing visuals. |

Planned: `SaveSystem` (Slice 4). Add an autoload only for truly global state.
Cross-system events are signals on `Simulation`. Add an `Events` bus only if that stops being enough.

### Dungeon model

- Gameplay-wise the dungeon is a **single line**: Entrance → owned rooms → Treasure Pit, at
  most one room per type. `Simulation.buy_room(id)` builds a type in its place
  (`RoomDef.line_order`) the first time and raises `DungeonRoom.level` after that.
  `room_cost(id)` / `room_level(id)` / `room_of_type(id)`.
- Underneath, `Dungeon` is still a general **graph of rooms on a grid**: `Vector2i` coords,
  explicit parent/child connections, `insert_between` (shifts the child's subtree one cell),
  `build_branch`, and BFS `path`. The line is built with `insert_between`. Keep that API
  general in case branching comes back. It has no idea about tiles or pixels.
- Adventurers move **room to room**. Their position is `(room_id, progress 0..1)`, plus
  `prev_room_id` / `next_room_id` (`NO_ROOM` = outside). The next step is recomputed when they
  enter a room and whenever the layout changes. Pathing is computed in `core/`, without
  `NavigationAgent2D` or physics.
- The presentation maps each room coord to a 12×12-unit cell (`DungeonGeometry.CELL`).
  Adventurers walk entry edge → room center → exit edge, interpolated between ticks.
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

- All art is **KayKit by Kay Lousberg** (CC0), in `res://assets/third_party/kaykit/`, with
  each pack's license: `dungeon/` (Dungeon Pack 1.1, gltf + one shared `dungeon_texture.png`),
  `adventurers/` (Adventurers 2.0), `skeletons/` (Skeletons 1.1, the monsters), and
  `animations/` (five Rig_Medium files from Character Animations 1.1). The original downloads
  are in `E:\programming\Godot\asset-candidates\`. Copy more from there as needed. The
  user's other project, `E:\programming\Godot\heavens-mandate`, uses the same packs and is a
  good reference.
- **Scale**: Dungeon pieces sit on a 4-unit grid. Floor tiles are 4×4 (`floor_tile_large`),
  and walls, `wall_doorway`, and `barrier` are 4 wide (walls 4 tall, barriers 1.1). Characters
  are about 2.5 tall. A room cell is 3×3 large tiles (12 units).
- **Cutaway walls** (`DungeonGeometry`): the camera looks from the south-east, so only
  north/west edges with nothing behind them get tall walls (plus a torch). Every other edge
  gets a low `barrier`, with the middle segment left open where rooms connect.
- **Room interiors** are scenes in `res://scenes/rooms/<id>.tscn` (floor + props, centered,
  12×12), linked from `RoomDef.interior`. The path runs west edge → center → east edge, so put
  traps on that line and keep props in the corners.
- **Rooms show their level**: give an interior's root the `RoomInterior` script, and tag
  pieces with `metadata/min_level` (shown from that level) and/or `metadata/max_level`
  (shown up to that level). `DungeonGeometry` calls `set_level`, and the view rebuilds on
  `room_upgraded`. Any child with its own `set_level` gets the level too. **`LevelScatter`**
  (a MultiMeshInstance3D) draws one copy of a mesh per level at `HazardLayout`'s spots, which are
  where the simulation deals hazard damage. The Spike Corridor uses it: one spike at level 1, one
  more per level, and each spike hits an adventurer once as they walk past (`RoomDef.hazard_damage`).
- **Derived assets**: single pieces cut out of KayKit models live in `res://assets/derived/`,
  made by scripts in `res://tools/` (run with `-s tools/<script>.gd`). Example:
  `tools/bake_single_spike.gd` cuts one spike out of `floor_tile_big_spikes` (9 spikes in one mesh)
  into `assets/derived/kaykit_single_spike.tres`. Rerun the script rather than hand-editing the output.
- **Characters** share one `AnimationLibrary` (`CharacterAnimations`), since every
  adventurer and skeleton uses the same rig. Names are like `Running_A`, `Hit_A`, `Death_A`,
  `PickUp`, `Skeletons_Idle`. glTF models face +Z. `AdventurerDef.model` picks the model.
- Don't invent art. If no KayKit piece fits, use a labeled placeholder and log the gap in
  docs/design.md.
- To look at the running game, render frames to PNG with a `-s` SceneTree script (not
  `--headless`), waiting on `RenderingServer.frame_post_draw` before
  `get_viewport().get_texture().get_image()`. If the game window is covered or loses
  focus, frames may stop and the capture hangs or comes out blank. Retry before suspecting the game.

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
  autoload/    # autoload Nodes (Game). Thin: they drive core/, never hold rules.
  core/        # simulation: state, combat, economy, save. No Node-dependent code.
  data/        # .tres content: rooms/, adventurers/, lures/ (later monsters/, upgrades/)
  scenes/      # world presentation
    main/        # root scene, IsoCamera
    dungeon/     # DungeonView (3D view + click input), DungeonGeometry, FloatingText3D
    rooms/       # one interior scene per room type, RoomInterior (level visuals)
    characters/  # AdventurerModel, CharacterAnimations
  ui/          # HUD, shop panels, tooltips, number formatting widgets
  assets/      # art, audio, fonts. Third-party packs in assets/third_party/<pack>/, pieces cut from them in assets/derived/
  tools/       # one-off -s scripts that generate assets (e.g. bake_single_spike.gd)
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
  Use `tests/fixtures/content_fixture.gd` (content built in code) instead of the real
  `res://data`, so balance changes don't break tests. Reference it with
  `const F = preload(...)`, not `const F := ContentFixture` (a class name can't be a constant).
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
