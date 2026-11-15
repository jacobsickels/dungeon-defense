extends Node
## Sandbox: the real game with every room unlocked and a debug panel on the right, for
## looking at rooms. Open scenes/debug/sandbox.tscn and press F6 (Run Current Scene).
##
## It changes the simulation directly (free levels, infinite blood), so it's for testing only.
## The normal game (F5) is unaffected.

const START_LEVEL: int = 6
const LEVEL_PRESETS: Array[int] = [1, 3, 6, 12, 25, 60, 121]
const SPEEDS: Array[float] = [1.0, 2.0, 4.0, 8.0]
const ROOM_ZOOM: float = 16.0
const OVERVIEW_ZOOM: float = 70.0

var _sim: Simulation
var _infinite_blood: bool = true
var _level_label: Label
var _speed_label: Label
var _level: int = START_LEVEL

## %Camera is a unique name inside main.tscn, so look it up from there.
@onready var _camera: IsoCamera = $Main.get_node("%Camera")


func _ready() -> void:
	_sim = Game.sim
	_set_all_levels(START_LEVEL)
	_build_panel()


func _process(_delta: float) -> void:
	if _infinite_blood:
		_sim.blood = 1e30


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# --- Actions ------------------------------------------------------------------

func _set_all_levels(level: int) -> void:
	_level = level
	for def: RoomDef in _sim.content.buildable_rooms():
		_sim.debug_set_room_level(def.id, level)
	if _level_label != null:
		_level_label.text = "All rooms: level %d" % level


func _spawn(count: int) -> void:
	var def: AdventurerDef = _sim.content.adventurers[Simulation.DEFAULT_ADVENTURER]
	for i: int in count:
		if _sim.adventurers.size() >= Balance.MAX_ADVENTURERS:
			break
		var adv := _sim.spawn_adventurer(def)
		# Spread them along the Entrance so they don't arrive as one clump.
		adv.progress = float(i) / count * 0.9


func _max_lures() -> void:
	var blood := _sim.blood
	_sim.blood = 1e300
	for def: LureDef in _sim.content.sorted_lures():
		while _sim.buy_lure(def.id):
			pass
	_sim.blood = blood


func _set_speed(speed: float) -> void:
	Engine.time_scale = speed
	_speed_label.text = "Game speed: %s×" % str(speed)


func _go_to(def_id: StringName) -> void:
	var room := _sim.room_of_type(def_id)
	if room != null:
		_camera.size = ROOM_ZOOM
		_camera.look_at_ground(DungeonGeometry.cell_center(room.coord))


func _overview() -> void:
	var line := _sim.dungeon.path(_sim.dungeon.entrance_id, _sim.dungeon.nearest_treasure(_sim.dungeon.entrance_id))
	var first := DungeonGeometry.cell_center(_sim.dungeon.get_room(line[0]).coord)
	var last := DungeonGeometry.cell_center(_sim.dungeon.get_room(line[-1]).coord)
	_camera.size = OVERVIEW_ZOOM
	_camera.look_at_ground((first + last) * 0.5)


# --- Panel ----------------------------------------------------------------------

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-16, 16)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_title(box, "SANDBOX")

	_level_label = _label(box, "All rooms: level %d" % _level)
	var levels := HFlowContainer.new()
	box.add_child(levels)
	for level: int in LEVEL_PRESETS:
		_button(levels, str(level), _set_all_levels.bind(level))
	var steps := HBoxContainer.new()
	box.add_child(steps)
	_button(steps, "−1", func() -> void: _set_all_levels(maxi(1, _level - 1)))
	_button(steps, "+1", func() -> void: _set_all_levels(_level + 1))

	_label(box, "Adventurers")
	var spawn := HBoxContainer.new()
	box.add_child(spawn)
	_button(spawn, "Spawn 1", _spawn.bind(1))
	_button(spawn, "Spawn 10", _spawn.bind(10))
	var auto := CheckBox.new()
	auto.text = "Keep arriving"
	auto.button_pressed = _sim.auto_spawn
	auto.focus_mode = Control.FOCUS_NONE
	auto.toggled.connect(func(on: bool) -> void: _sim.auto_spawn = on)
	box.add_child(auto)

	_speed_label = _label(box, "Game speed: 1×")
	var speeds := HBoxContainer.new()
	box.add_child(speeds)
	for speed: float in SPEEDS:
		_button(speeds, "%s×" % str(speed), _set_speed.bind(speed))

	var blood := CheckBox.new()
	blood.text = "Infinite blood"
	blood.button_pressed = _infinite_blood
	blood.focus_mode = Control.FOCUS_NONE
	blood.toggled.connect(func(on: bool) -> void: _infinite_blood = on)
	box.add_child(blood)
	_button(box, "Max all lures", _max_lures)

	_label(box, "Camera")
	_button(box, "Whole dungeon", _overview)
	var rooms := GridContainer.new()
	rooms.columns = 2
	box.add_child(rooms)
	for def: RoomDef in _sim.content.buildable_rooms():
		_button(rooms, def.display_name, _go_to.bind(def.id))


func _title(parent: Container, text: String) -> void:
	var label := _label(parent, text)
	label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	label.add_theme_font_size_override("font_size", 16)


func _label(parent: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	return label


func _button(parent: Container, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
