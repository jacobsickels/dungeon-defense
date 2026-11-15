class_name Simulation
extends RefCounted
## All game state and rules. Advance it with tick(), change it with commands
## (buy_room, hit_adventurer, buy_lure), and watch it through signals.
## It never touches nodes, so it runs headless, in tests, and in fast-forward.
##
## The economy: the currency is blood. Every point of damage an adventurer takes, from rooms or
## clicks, bleeds blood into the dungeon. Adventurers can't die. They walk from the Entrance to
## the Treasure room, then drop through its trapdoor and are gone.
##
## The dungeon is a single line: Entrance, then each room type the player owns (one of each,
## ordered by RoomDef.line_order), then the Treasure Pit. Buying a room type the first time
## inserts it in its place. Buying it again raises its level.

signal blood_changed(blood: float)
signal dungeon_changed
signal room_built(room: DungeonRoom)
signal room_upgraded(room: DungeonRoom)
signal adventurer_spawned(adv: Adventurer)
## Direct hits (clicks).
signal adventurer_hit(adv: Adventurer, damage: float, blood: float)
## Took one or more discrete hits from a room this tick: hazards walked past, or a pulse.
## Damage over time and poison aren't signalled.
signal adventurer_hazard_hit(adv: Adventurer, hits: int, blood: float)
## A specific hazard (by index in its room's layout) just hit someone, for its attack animation.
signal hazard_triggered(room: DungeonRoom, index: int, adv: Adventurer)
## A room with pulse damage just went off, hitting `targets` adventurers.
signal room_pulsed(room: DungeonRoom, targets: int)
## Reached the treasure and dropped through the trapdoor.
signal adventurer_fell(adv: Adventurer)
signal lures_changed

const STARTING_ENTRANCE: StringName = &"entrance"
const STARTING_TREASURE: StringName = &"treasure"
const DEFAULT_ADVENTURER: StringName = &"peasant"
## How far into the Treasure room adventurers walk before falling: its center.
const FALL_PROGRESS: float = 0.5

var content: ContentDB
var dungeon: Dungeon = Dungeon.new()
var blood: float = Balance.STARTING_BLOOD
var adventurers: Dictionary[int, Adventurer] = {}
## Lure levels bought, by id.
var lures_owned: Dictionary[StringName, int] = {}

## Turn off to drive spawning by hand (tests).
var auto_spawn: bool = true
var elapsed: float = 0.0
var visitors: int = 0
var fallen: int = 0
var lifetime_blood: float = 0.0
## Smoothed blood per second from all damage (rooms and clicks). Spending isn't counted.
var income_per_second: float = 0.0

## Counts up in "base seconds": real seconds times the spawn rate multiplier.
var _spawn_timer: float = Balance.SPAWN_INTERVAL - Balance.FIRST_SPAWN_DELAY
var _next_adventurer_id: int = 0
## Blood earned during the current tick, folded into income_per_second.
var _tick_income: float = 0.0
## Dungeon-wide bonuses from rooms like the Phylactery and the Blood Altar. Recomputed on purchase.
var _global_blood_mult: float = 1.0
var _global_hit_bonus: float = 0.0


func _init(p_content: ContentDB) -> void:
	content = p_content
	_build_starting_layout()
	_recompute_globals()


func _build_starting_layout() -> void:
	var entrance := dungeon.add_entrance(content.rooms[STARTING_ENTRANCE], Vector2i.ZERO, Vector2i.LEFT)
	dungeon.build_branch(content.rooms[STARTING_TREASURE], entrance.id, Vector2i.RIGHT)


# --- Tick -------------------------------------------------------------------

func tick(dt: float) -> void:
	elapsed += dt
	if auto_spawn:
		_spawn_timer += dt * lure_multiplier(&"spawn_rate_mult")
		while _spawn_timer >= Balance.SPAWN_INTERVAL:
			_spawn_timer -= Balance.SPAWN_INTERVAL
			if adventurers.size() < Balance.MAX_ADVENTURERS:
				spawn_adventurer(content.adventurers[DEFAULT_ADVENTURER])
	for adv: Adventurer in adventurers.values():
		_tick_adventurer(adv, dt)
	_tick_pulses(dt)
	# Exponential moving average of income.
	var blend := clampf(dt / Balance.INCOME_SMOOTHING_TIME, 0.0, 1.0)
	income_per_second = lerpf(income_per_second, _tick_income / dt, blend)
	_tick_income = 0.0


func _tick_adventurer(adv: Adventurer, dt: float) -> void:
	var room := dungeon.get_room(adv.room_id)
	var damage := room.dps() * dt
	if damage > 0.0:
		_bleed(adv, damage)
	if adv.poison_remaining > 0.0:
		var poison := minf(adv.poison_rate * dt, adv.poison_remaining)
		adv.poison_remaining -= poison
		_bleed(adv, poison)
	var before := adv.progress
	adv.progress += dt * adv.speed / room.def.traverse_time
	var count := room.hazard_count()
	if count > 0:
		var passed: PackedInt32Array = room.def.layout().hazards_passed(count, before, adv.progress)
		if not passed.is_empty():
			var per_hit := room.hazard_hit_damage() + _global_hit_bonus
			var gained := _bleed(adv, per_hit * passed.size())
			adventurer_hazard_hit.emit(adv, passed.size(), gained)
			for index: int in passed:
				hazard_triggered.emit(room, index, adv)
	if room.def.is_treasure and adv.progress >= FALL_PROGRESS:
		_fall(adv)
	elif adv.progress >= 1.0:
		_advance(adv)


## The adventurer has finished crossing their room. Move them into the next one.
func _advance(adv: Adventurer) -> void:
	if adv.next_room_id == Dungeon.NO_ROOM:
		# Nowhere to go (no treasure in the dungeon): they leave.
		_fall(adv)
		return
	adv.prev_room_id = adv.room_id
	adv.room_id = adv.next_room_id
	adv.progress = 0.0
	var room := dungeon.get_room(adv.room_id)
	if room.poison_damage() > 0.0:
		_add_poison(adv, room.poison_damage())
	_update_next_room(adv)


## Poison stacks: what's left of earlier doses plus the new one, spread over a fresh duration.
func _add_poison(adv: Adventurer, amount: float) -> void:
	adv.poison_remaining += amount
	adv.poison_rate = adv.poison_remaining / Balance.POISON_DURATION


## Rooms with pulses (the boulder) go off every pulse_interval, hitting everyone inside.
func _tick_pulses(dt: float) -> void:
	for room: DungeonRoom in dungeon.rooms.values():
		if room.def.pulse_damage <= 0.0:
			continue
		room.pulse_timer += dt
		while room.pulse_timer >= room.def.pulse_interval:
			room.pulse_timer -= room.def.pulse_interval
			_pulse(room)


func _pulse(room: DungeonRoom) -> void:
	var targets := 0
	var per_hit := room.pulse_damage() + _global_hit_bonus
	for adv: Adventurer in adventurers.values():
		if adv.room_id != room.id:
			continue
		targets += 1
		var gained := _bleed(adv, per_hit)
		adventurer_hazard_hit.emit(adv, 1, gained)
	room_pulsed.emit(room, targets)


func _update_next_room(adv: Adventurer) -> void:
	var treasure := dungeon.nearest_treasure(adv.room_id)
	adv.next_room_id = _step_toward(adv.room_id, treasure) if treasure != Dungeon.NO_ROOM else Dungeon.NO_ROOM


func _step_toward(from_id: int, to_id: int) -> int:
	var p := dungeon.path(from_id, to_id)
	return p[1] if p.size() >= 2 else Dungeon.NO_ROOM


# --- Adventurers ------------------------------------------------------------

func spawn_adventurer(def: AdventurerDef) -> Adventurer:
	var adv := Adventurer.new(_next_adventurer_id, def, lure_multiplier(&"speed_mult"),
			lure_multiplier(&"blood_mult"))
	_next_adventurer_id += 1
	adv.room_id = dungeon.entrance_id
	adv.prev_room_id = Dungeon.NO_ROOM
	_update_next_room(adv)
	adventurers[adv.id] = adv
	visitors += 1
	adventurer_spawned.emit(adv)
	return adv


## A click on an adventurer. Returns false if there's no such adventurer.
func hit_adventurer(adv_id: int, damage: float = Balance.CLICK_DAMAGE) -> bool:
	var adv: Adventurer = adventurers.get(adv_id)
	if adv == null:
		return false
	var total := damage + _global_hit_bonus
	var gained := _bleed(adv, total)
	adventurer_hit.emit(adv, total, gained)
	return true


## Damage turns into blood at the adventurer's bleed rate, times the dungeon-wide bonus.
## Returns the blood gained.
func _bleed(adv: Adventurer, damage: float) -> float:
	var gained: float = damage * adv.bleed * _global_blood_mult
	adv.blood_drained += gained
	_add_blood(gained)
	return gained


## Into the pit. Any poison still working lands now, so where the poison room sits doesn't matter.
func _fall(adv: Adventurer) -> void:
	if adv.poison_remaining > 0.0:
		var poison := adv.poison_remaining
		adv.poison_remaining = 0.0
		_bleed(adv, poison)
	adventurers.erase(adv.id)
	fallen += 1
	adventurer_fell.emit(adv)


# --- Building ---------------------------------------------------------------

## The built room of this type, or null if it hasn't been built.
func room_of_type(def_id: StringName) -> DungeonRoom:
	for room: DungeonRoom in dungeon.rooms.values():
		if room.def.id == def_id:
			return room
	return null


## Level of a room type. 0 means it hasn't been built.
func room_level(def_id: StringName) -> int:
	var room := room_of_type(def_id)
	return room.level if room != null else 0


## Cost of the next level (level 1 = building it). INF if it can't be bought.
func room_cost(def_id: StringName) -> float:
	var def := _buildable_def(def_id)
	if def == null:
		return INF
	return ceilf(def.base_cost * pow(def.cost_growth, room_level(def_id)))


func can_buy_room(def_id: StringName) -> bool:
	return blood >= room_cost(def_id)


## Builds the room type in its place in the line, or raises its level if it's already built.
func buy_room(def_id: StringName) -> bool:
	if not can_buy_room(def_id):
		return false
	blood -= room_cost(def_id)
	var room := room_of_type(def_id)
	if room == null:
		room = _place_in_line(_buildable_def(def_id))
		_reroute_adventurers()
		room_built.emit(room)
		dungeon_changed.emit()
	else:
		room.level += 1
		room_upgraded.emit(room)
	_recompute_globals()
	blood_changed.emit(blood)
	return true


## Multiplier on all blood from rooms with global_blood_bonus (1 = no bonus).
func global_blood_multiplier() -> float:
	return _global_blood_mult


## Extra damage on every hit from rooms with global_hit_damage.
func global_hit_bonus() -> float:
	return _global_hit_bonus


func _recompute_globals() -> void:
	_global_blood_mult = 1.0
	_global_hit_bonus = 0.0
	for room: DungeonRoom in dungeon.rooms.values():
		_global_blood_mult += room.def.global_blood_bonus * room.level
		_global_hit_bonus += room.def.global_hit_damage * room.level


## Inserts the room before the first room on the line that should come after it.
func _place_in_line(def: RoomDef) -> DungeonRoom:
	var line := dungeon.path(dungeon.entrance_id, dungeon.nearest_treasure(dungeon.entrance_id))
	for i: int in range(1, line.size()):
		var next := dungeon.get_room(line[i])
		if next.def.is_treasure or next.def.line_order > def.line_order:
			return dungeon.insert_between(def, line[i - 1], line[i])
	assert(false, "The line has no Treasure Pit to insert before")
	return null


## After the layout changes, fix up where each adventurer came from and where they head next.
func _reroute_adventurers() -> void:
	for adv: Adventurer in adventurers.values():
		# A room may have been inserted behind them. Make "came from" the adjacent room.
		if adv.prev_room_id != Dungeon.NO_ROOM and not dungeon.neighbors(adv.room_id).has(adv.prev_room_id):
			adv.prev_room_id = _step_toward(adv.room_id, adv.prev_room_id)
		_update_next_room(adv)


func _buildable_def(def_id: StringName) -> RoomDef:
	var def: RoomDef = content.rooms.get(def_id)
	if def == null or not def.buildable:
		return null
	return def


func _add_blood(amount: float) -> void:
	blood += amount
	lifetime_blood += amount
	_tick_income += amount
	blood_changed.emit(blood)


# --- Lures ------------------------------------------------------------------

func lure_owned(id: StringName) -> int:
	return lures_owned.get(id, 0)


## Cost of the next level. INF if the lure doesn't exist, isn't available, or is at its max level.
func lure_cost(id: StringName) -> float:
	var def: LureDef = content.lures.get(id)
	if def == null or not def.available or (def.max_level > 0 and lure_owned(id) >= def.max_level):
		return INF
	return ceilf(def.base_cost * pow(def.cost_growth, lure_owned(id)))


func buy_lure(id: StringName) -> bool:
	var cost := lure_cost(id)
	if is_inf(cost) or blood < cost:
		return false
	blood -= cost
	lures_owned[id] = lure_owned(id) + 1
	blood_changed.emit(blood)
	lures_changed.emit()
	return true


## Product of one effect (a LureDef property name, such as &"blood_mult") over the levels
## owned of every lure.
func lure_multiplier(effect: StringName) -> float:
	var total := 1.0
	for id: StringName in lures_owned:
		var def: LureDef = content.lures.get(id)
		if def != null:
			total *= pow(float(def.get(effect)), lures_owned[id])
	return total
