class_name RoomInterior
extends Node3D
## Root script for a room's interior scene, so pieces can appear as the room levels up.
##
## Give any node in the scene `metadata/min_level` to show it from that level on, and/or
## `metadata/max_level` to show it only up to that level. For example, a floor tile with
## max_level 2 and a spike tile in the same spot with min_level 3 swap at level 3.
## Nodes without either are always shown. Children with their own `set_level` (such as
## LevelScatter) are passed the level too.

const NO_MAX: int = 1 << 30


func set_level(level: int) -> void:
	_apply(self, level)


func _apply(node: Node, level: int) -> void:
	for child: Node in node.get_children():
		if child.has_method(&"set_level"):
			child.call(&"set_level", level)
		if child is Node3D and (child.has_meta(&"min_level") or child.has_meta(&"max_level")):
			var min_level: int = child.get_meta(&"min_level", 0)
			var max_level: int = child.get_meta(&"max_level", NO_MAX)
			(child as Node3D).visible = level >= min_level and level <= max_level
		# Don't descend into instanced models: their insides aren't tagged.
		if child.scene_file_path.is_empty():
			_apply(child, level)
