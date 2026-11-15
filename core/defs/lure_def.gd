class_name LureDef
extends Resource
## An upgrade that brings more adventurers, or ones who bleed more or linger longer.
## Saved as .tres files in res://data/lures/.
##
## Effects multiply once per level owned: at level 3, blood_mult 1.4 means ×2.744 blood.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Economy")
@export var base_cost: float = 50.0
## Each level owned multiplies the next level's cost by this.
@export var cost_growth: float = 1.6
## Most levels that can be bought. 0 means no limit.
@export var max_level: int = 0
## Off hides the lure from the shop and stops it being bought, e.g. until it has
## something to do.
@export var available: bool = true

@export_group("Effects per level")
@export var spawn_rate_mult: float = 1.0
@export var blood_mult: float = 1.0
## Below 1 slows adventurers down, so they spend longer in every room.
@export var speed_mult: float = 1.0
