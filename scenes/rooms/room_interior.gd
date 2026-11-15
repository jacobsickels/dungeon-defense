class_name RoomInterior
extends Node3D
## Root script for a room's interior scene. It shows the room's level and passes events
## (a hazard hitting, a pulse) down to the pieces that animate them.
##
## - Tag any node with `metadata/min_level` (shown from that level on) and/or
##   `metadata/max_level` (shown only up to that level).
## - Children with `set_room(room)` are given the room (LevelScatter, LevelSpawner, ...).
## - Children with `trigger_hazard(index)` hear when hazard `index` hits someone.
## - Children with `pulse()` hear when the room pulses (the boulder rolling).

const NO_MAX: int = 1 << 30

var room: DungeonRoom


func setup(p_room: DungeonRoom) -> void:
	room = p_room
	_apply(self)


func trigger_hazard(index: int) -> void:
	_forward(self, &"trigger_hazard", [index])


func pulse() -> void:
	_forward(self, &"pulse", [])


func _apply(node: Node) -> void:
	for child: Node in node.get_children():
		if child.has_method(&"set_room"):
			child.call(&"set_room", room)
		if child is Node3D and (child.has_meta(&"min_level") or child.has_meta(&"max_level")):
			var min_level: int = child.get_meta(&"min_level", 0)
			var max_level: int = child.get_meta(&"max_level", NO_MAX)
			(child as Node3D).visible = room.level >= min_level and room.level <= max_level
		# Don't descend into instanced models: their insides aren't tagged.
		if child.scene_file_path.is_empty():
			_apply(child)


func _forward(node: Node, method: StringName, args: Array) -> void:
	for child: Node in node.get_children():
		if child.has_method(method):
			child.callv(method, args)
		elif child.scene_file_path.is_empty():
			_forward(child, method, args)
