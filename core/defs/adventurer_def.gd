class_name AdventurerDef
extends Resource
## Static definition of an adventurer type. Saved as .tres files in res://data/adventurers/.
## Adventurers can't die. What sets them apart is how fast they walk and how much they bleed.

@export var id: StringName
@export var display_name: String

## Multiplier on how fast rooms are crossed (1.0 = a room's traverse_time). Slower walkers
## spend longer in each room, so they bleed more.
@export var speed: float = 1.0
## Blood per point of damage taken.
@export var bleed: float = 1.0

@export_group("Presentation")
@export var color: Color = Color.WHITE
## A KayKit character model on the Rig_Medium rig, so it can share the animation library.
@export var model: PackedScene
