class_name ContentFixture
extends RefCounted
## Content built in code for tests, so balance changes in res://data don't break them.
## Numbers are picked to make the math easy to check by hand.

const ROOM_TRAVERSE: float = 1.0  # 10 ticks per room at speed 1
## Room levels double in cost: 10, 20, 40, ... for spikes.
const ROOM_GROWTH: float = 2.0
## Spikes deal this per spike passed. One spike per level.
const SPIKE_HIT: float = 5.0
const SPIKES_COST: float = 10.0
const SPIKES_ORDER: int = 10
## A second room type that belongs after the spikes in the line. It hurts over time.
const BLADES_DPS: float = 20.0
const BLADES_COST: float = 100.0
const BLADES_ORDER: int = 20
## "ads": spawn ×2 per level. "plump": blood ×3 per level. "heavy": speed ×0.5 per level.
## Costs double per level.
const ADS_COST: float = 10.0
const PLUMP_COST: float = 20.0
const HEAVY_COST: float = 15.0
const LURE_GROWTH: float = 2.0


static func make() -> ContentDB:
	var db := ContentDB.new()
	db.add_room(room(&"entrance", 0.0, 0.0, false, true, false))
	# Not for sale: only Dungeon layout tests place hallways directly.
	db.add_room(room(&"hallway", 0.0, 0.0, false))
	db.add_room(room(&"treasure", 0.0, 0.0, false, false, true))
	var spikes := room(&"spikes", SPIKES_COST, 0.0, true)
	spikes.hazard_damage = SPIKE_HIT
	spikes.line_order = SPIKES_ORDER
	db.add_room(spikes)
	var blades := room(&"blades", BLADES_COST, BLADES_DPS, true)
	blades.line_order = BLADES_ORDER
	db.add_room(blades)
	var peasant := AdventurerDef.new()
	peasant.id = &"peasant"
	peasant.speed = 1.0
	peasant.bleed = 1.0
	db.add_adventurer(peasant)
	db.add_lure(lure(&"ads", ADS_COST, 2.0, 1.0, 1.0))
	db.add_lure(lure(&"plump", PLUMP_COST, 1.0, 3.0, 1.0))
	db.add_lure(lure(&"heavy", HEAVY_COST, 1.0, 1.0, 0.5))
	return db


static func lure(id: StringName, cost: float, spawn: float, blood: float, speed: float) -> LureDef:
	var def := LureDef.new()
	def.id = id
	def.base_cost = cost
	def.cost_growth = LURE_GROWTH
	def.spawn_rate_mult = spawn
	def.blood_mult = blood
	def.speed_mult = speed
	return def


static func room(id: StringName, cost: float, dps: float, buildable: bool,
		is_entrance: bool = false, is_treasure: bool = false) -> RoomDef:
	var def := RoomDef.new()
	def.id = id
	def.display_name = String(id)
	def.base_cost = cost
	def.cost_growth = ROOM_GROWTH
	def.dps = dps
	def.traverse_time = ROOM_TRAVERSE
	def.buildable = buildable
	def.is_entrance = is_entrance
	def.is_treasure = is_treasure
	return def


## A simulation with auto-spawn off.
static func make_sim() -> Simulation:
	var sim := Simulation.new(make())
	sim.auto_spawn = false
	return sim


## Ticks until no adventurers are left, or until max_ticks runs out. Returns the ticks used.
static func run_until_empty(sim: Simulation, max_ticks: int = 1000) -> int:
	for i: int in max_ticks:
		if sim.adventurers.is_empty():
			return i
		sim.tick(Balance.TICK_DT)
	return max_ticks
