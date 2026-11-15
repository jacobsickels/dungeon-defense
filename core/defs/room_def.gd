class_name RoomDef
extends Resource
## Static definition of a room type. Saved as .tres files in res://data/rooms/.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Economy")
## Cost to build the room (level 1).
@export var base_cost: float = 10.0
## Each level owned multiplies the next level's cost by this.
@export var cost_growth: float = 1.15
## Whether the player can buy this room. Entrance and Treasure are placed by the game.
@export var buildable: bool = true
## Where the room sits in the line: rooms are ordered from the Entrance by this, lowest first.
## The Treasure Pit is always last.
@export var line_order: int = 0

@export_group("Combat")
## Damage per second to each adventurer inside the room, per level. For hazards that hurt
## the whole time they're inside (gas, fire, ...).
@export var dps: float = 0.0
## Damage each hazard (spike, ...) deals as an adventurer walks past it. The room has one
## hazard per level, placed by HazardLayout.
@export var hazard_damage: float = 0.0
## Seconds an adventurer at speed 1.0 takes to cross the room.
@export var traverse_time: float = 2.0

@export_group("Role")
@export var is_entrance: bool = false
@export var is_treasure: bool = false

@export_group("Presentation")
## Placeholder color until real art lands.
@export var color: Color = Color.GRAY
## Floor and props for this room, centered on the room (12×12 units). The walls are
## added by the view. If empty, the room gets a plain floor.
@export var interior: PackedScene
