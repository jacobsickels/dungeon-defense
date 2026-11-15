class_name ContentDB
extends RefCounted
## Index of every content definition, looked up by id.
## The game loads it from res://data/. Tests build one by hand.

const ROOMS_DIR: String = "res://data/rooms/"
const ADVENTURERS_DIR: String = "res://data/adventurers/"
const LURES_DIR: String = "res://data/lures/"

var rooms: Dictionary[StringName, RoomDef] = {}
var adventurers: Dictionary[StringName, AdventurerDef] = {}
var lures: Dictionary[StringName, LureDef] = {}


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	for res: Resource in _load_dir(ROOMS_DIR):
		if res is RoomDef:
			db.add_room(res)
	for res: Resource in _load_dir(ADVENTURERS_DIR):
		if res is AdventurerDef:
			db.add_adventurer(res)
	for res: Resource in _load_dir(LURES_DIR):
		if res is LureDef:
			db.add_lure(res)
	return db


func add_room(def: RoomDef) -> void:
	assert(def.id != &"", "RoomDef is missing an id: %s" % def.resource_path)
	assert(not rooms.has(def.id), "Duplicate RoomDef id: %s" % def.id)
	rooms[def.id] = def


func add_adventurer(def: AdventurerDef) -> void:
	assert(def.id != &"", "AdventurerDef is missing an id: %s" % def.resource_path)
	assert(not adventurers.has(def.id), "Duplicate AdventurerDef id: %s" % def.id)
	adventurers[def.id] = def


func add_lure(def: LureDef) -> void:
	assert(def.id != &"", "LureDef is missing an id: %s" % def.resource_path)
	assert(not lures.has(def.id), "Duplicate LureDef id: %s" % def.id)
	lures[def.id] = def


## Lures for sale (available ones), cheapest first.
func sorted_lures() -> Array[LureDef]:
	var out: Array[LureDef] = []
	for def: LureDef in lures.values():
		if def.available:
			out.append(def)
	out.sort_custom(func(a: LureDef, b: LureDef) -> bool: return a.base_cost < b.base_cost)
	return out


## Rooms the player can buy, in line order (nearest the Entrance first).
func buildable_rooms() -> Array[RoomDef]:
	var out: Array[RoomDef] = []
	for def: RoomDef in rooms.values():
		if def.buildable:
			out.append(def)
	out.sort_custom(func(a: RoomDef, b: RoomDef) -> bool: return a.line_order < b.line_order)
	return out


static func _load_dir(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	# list_directory handles exported builds, where files are remapped or converted.
	for file: String in ResourceLoader.list_directory(dir):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res: Resource = load(dir + file)
			if res != null:
				out.append(res)
	return out
