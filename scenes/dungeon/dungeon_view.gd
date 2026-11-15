class_name DungeonView
extends Node3D
## 3D isometric view of the simulation: room geometry and adventurer models.
## Clicks are resolved in screen space by projecting world points with the camera.
## Left-click an adventurer to hit them.

## Click distance from an adventurer, in world units at the camera's zoom.
const ADVENTURER_HIT_RADIUS: float = 1.4
## Adventurers' chest height, for clicks and popups.
const BODY_HEIGHT: float = 1.3
## Seconds between the "+blood" popups over each bleeding adventurer.
const BLOOD_POPUP_INTERVAL: float = 1.0

const COLOR_BLOOD := Color(0.95, 0.2, 0.2)
const COLOR_LEVEL_UP := Color(1.0, 0.85, 0.4)

@onready var _camera: IsoCamera = %Camera

var _sim: Simulation
var _geometry: Node3D
## Set when the layout changes. The geometry is rebuilt once in the next _process,
## so several changes in one frame cost a single rebuild.
var _geometry_dirty: bool = true
## Re-center the camera with the next rebuild: only when the line grows, not on upgrades.
var _recenter: bool = true
var _models: Dictionary[int, AdventurerModel] = {}


func _ready() -> void:
	_sim = Game.sim
	_sim.dungeon_changed.connect(func() -> void:
		_geometry_dirty = true
		_recenter = true)
	_sim.room_upgraded.connect(_on_room_upgraded)
	_sim.adventurer_hit.connect(_on_adventurer_hit)
	_sim.adventurer_hazard_hit.connect(_on_adventurer_hazard_hit)
	_sim.adventurer_fell.connect(_on_adventurer_fell)


func _process(delta: float) -> void:
	if _geometry_dirty:
		_rebuild_geometry()
	_sync_models(delta)


# --- Geometry ---------------------------------------------------------------

## Rebuilds the rooms, which also shows each room's level (see RoomInterior).
func _rebuild_geometry() -> void:
	_geometry_dirty = false
	if _recenter:
		_recenter = false
		_camera.look_at_ground(_dungeon_center())
	if _geometry != null:
		remove_child(_geometry)
		_geometry.queue_free()
	_geometry = DungeonGeometry.build(_sim.dungeon)
	add_child(_geometry)


func _dungeon_center() -> Vector3:
	var sum := Vector3.ZERO
	for room: DungeonRoom in _sim.dungeon.rooms.values():
		sum += DungeonGeometry.cell_center(room.coord)
	return sum / maxf(1.0, _sim.dungeon.rooms.size())


# --- Adventurers ------------------------------------------------------------

func _sync_models(delta: float) -> void:
	for adv: Adventurer in _sim.adventurers.values():
		var model: AdventurerModel = _models.get(adv.id)
		if model == null:
			model = AdventurerModel.new()
			add_child(model)
			model.setup(adv.def.model)
			_models[adv.id] = model
			model.position = adventurer_position(adv)
			model.last_room_id = adv.room_id
			model.shown_blood = adv.blood_drained
		var target := adventurer_position(adv)
		model.face(target - model.position, delta)
		model.position = target
		# Flinch on stepping into a room that hurts over time.
		if adv.room_id != model.last_room_id:
			model.last_room_id = adv.room_id
			if _sim.dungeon.get_room(adv.room_id).dps() > 0.0:
				model.flinch()
		# Damage over time shows as one popup a second. (Hazard hits pop right away.)
		model.popup_timer += delta
		if model.popup_timer >= BLOOD_POPUP_INTERVAL:
			model.popup_timer = 0.0
			_show_fresh_blood(adv, model)


## Pops up the blood drained from an adventurer since their last popup.
func _show_fresh_blood(adv: Adventurer, model: AdventurerModel) -> void:
	var fresh: float = adv.blood_drained - model.shown_blood
	if fresh >= 0.5:
		model.shown_blood = adv.blood_drained
		_popup(adv, "+" + NumberFormat.short(fresh), COLOR_BLOOD, 40)


## Where an adventurer stands: from the entry edge to the room's center, then to the exit
## edge. In the Treasure room they stop at the center, over the trapdoor. Smoothed between ticks.
func adventurer_position(adv: Adventurer) -> Vector3:
	var room := _sim.dungeon.get_room(adv.room_id)
	var center := DungeonGeometry.cell_center(room.coord)
	var entry := _edge_point(room, adv.prev_room_id)
	var exit := center if room.def.is_treasure else _edge_point(room, adv.next_room_id)
	var step := Game.tick_fraction() * Balance.TICK_DT * adv.speed / room.def.traverse_time
	var p := clampf(adv.progress + step, 0.0, 1.0)
	var pos := entry.lerp(center, p * 2.0) if p < 0.5 else center.lerp(exit, (p - 0.5) * 2.0)
	return pos + _lane_offset(adv.id)


## Midpoint of the edge between `room` and another room (NO_ROOM = the outside door).
func _edge_point(room: DungeonRoom, other_id: int) -> Vector3:
	if other_id == Dungeon.NO_ROOM:
		return DungeonGeometry.edge_center(room.coord, _sim.dungeon.entrance_outside_dir)
	var other := _sim.dungeon.get_room(other_id)
	return DungeonGeometry.edge_center(room.coord, other.coord - room.coord)


## Small fixed offset per adventurer so a crowd doesn't stack on one point.
func _lane_offset(id: int) -> Vector3:
	return Vector3(((id * 7) % 5 - 2) * 0.45, 0.0, ((id * 13) % 5 - 2) * 0.45)


func _model_or_position(adv: Adventurer) -> Vector3:
	var model: AdventurerModel = _models.get(adv.id)
	return model.position if model != null else adventurer_position(adv)


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var adv := _adventurer_at(mb.position)
			if adv != null:
				_sim.hit_adventurer(adv.id)
				get_viewport().set_input_as_handled()


func _adventurer_at(screen_pos: Vector2) -> Adventurer:
	var pixels_per_unit := get_viewport().get_visible_rect().size.y / _camera.size
	var best: Adventurer = null
	var best_dist := ADVENTURER_HIT_RADIUS * pixels_per_unit
	for adv: Adventurer in _sim.adventurers.values():
		var body := _model_or_position(adv) + Vector3.UP * BODY_HEIGHT
		var dist := _camera.unproject_position(body).distance_to(screen_pos)
		if dist <= best_dist:
			best = adv
			best_dist = dist
	return best


# --- Feedback ---------------------------------------------------------------

## A click: flinch, and the blood it drew pops out right away. The model's running total
## counts it as shown, so the next per-second popup doesn't repeat it.
func _on_adventurer_hit(adv: Adventurer, _damage: float, blood: float) -> void:
	var model: AdventurerModel = _models.get(adv.id)
	if model != null:
		model.flinch()
		model.shown_blood += blood
	_popup(adv, "+" + NumberFormat.short(blood), COLOR_BLOOD, 56)


## Walked over spikes: flinch, and show the blood straight away.
func _on_adventurer_hazard_hit(adv: Adventurer, _hits: int, _blood: float) -> void:
	var model: AdventurerModel = _models.get(adv.id)
	if model == null:
		return
	model.flinch()
	model.popup_timer = 0.0
	_show_fresh_blood(adv, model)


func _on_room_upgraded(room: DungeonRoom) -> void:
	_geometry_dirty = true
	var pos := DungeonGeometry.cell_center(room.coord) + Vector3.UP * 3.0
	FloatingText3D.spawn(self, pos, "Lv %d" % room.level, COLOR_LEVEL_UP, 72)


func _on_adventurer_fell(adv: Adventurer) -> void:
	var model: AdventurerModel = _models.get(adv.id)
	if model != null:
		_models.erase(adv.id)
		model.fall()


func _popup(adv: Adventurer, text: String, color: Color, font_size: int) -> void:
	FloatingText3D.spawn(self, _model_or_position(adv) + Vector3.UP * (BODY_HEIGHT + 1.5), text, color, font_size)
