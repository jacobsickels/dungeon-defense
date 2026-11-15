extends GutTest
## Hazards (spikes, skeletons, ...): where they stand, and adventurers taking one hit per
## hazard they pass.

const F = preload("res://tests/fixtures/content_fixture.gd")

var _sim: Simulation


func before_each() -> void:
	_sim = F.make_sim()
	_sim.blood = 1e6


func _spikes() -> DungeonRoom:
	return _sim.room_of_type(&"spikes")


func _walk_one_through() -> Adventurer:
	_sim.blood = 0.0
	var adv := _sim.spawn_adventurer(_sim.content.adventurers[&"peasant"])
	F.run_until_empty(_sim)
	return adv


func test_default_layout_is_stable_and_inside_the_room() -> void:
	var layout := HazardLayout.default_layout()
	var spots := layout.spots()
	assert_eq(spots.size(), 11 * 11)
	assert_eq(layout.spots(), spots, "same every call")
	for spot: Vector2 in spots:
		assert_lt(absf(spot.x), HazardLayout.HALF_ROOM)
		assert_lt(absf(spot.y), HazardLayout.HALF_ROOM)
	assert_lt(spots[0].length(), 0.5, "the first spike is in the middle of the room")


func test_default_layout_fills_the_path_before_the_sides() -> void:
	var spots := HazardLayout.default_layout().spots()
	for i: int in 5:
		assert_lt(absf(spots[i].y), 0.5, "spike %d should be on the path: %s" % [i, spots[i]])


func test_layout_can_keep_the_walkway_clear() -> void:
	var layout := HazardLayout.new()
	layout.spacing = 2.0
	layout.extent = Vector2i(2, 2)
	layout.keep_path_clear = true
	var spots := layout.spots()
	assert_eq(spots.size(), 5 * 4, "5 columns, 4 rows with the middle row left out")
	for spot: Vector2 in spots:
		assert_gt(absf(spot.y), 1.0, "nothing on the walkway: %s" % spot)


func test_one_hit_per_spike_per_level() -> void:
	_sim.buy_room(&"spikes")
	for level: int in [1, 2, 3, 7]:
		while _spikes().level < level:
			_sim.blood = 1e6
			assert_true(_sim.buy_room(&"spikes"))
		var hits := [0]
		var on_hit := func(_a: Adventurer, n: int, _b: float) -> void: hits[0] += n
		_sim.adventurer_hazard_hit.connect(on_hit)
		_walk_one_through()
		_sim.adventurer_hazard_hit.disconnect(on_hit)
		assert_eq(hits[0], level, "level %d" % level)
		assert_eq(_sim.blood, F.SPIKE_HIT * level, "level %d" % level)


func test_each_hazard_reports_which_one_hit() -> void:
	_sim.buy_room(&"spikes")
	_sim.buy_room(&"spikes")
	_sim.buy_room(&"spikes")
	var triggered: Array[int] = []
	_sim.hazard_triggered.connect(func(_r: DungeonRoom, i: int, _a: Adventurer) -> void: triggered.append(i))
	_walk_one_through()
	triggered.sort()
	assert_eq(triggered, [0, 1, 2] as Array[int], "every hazard went off once")


func test_hit_lands_when_passing_the_spike_not_before() -> void:
	_sim.buy_room(&"spikes")
	_sim.blood = 0.0
	var adv := _sim.spawn_adventurer(_sim.content.adventurers[&"peasant"])
	var spike_at := HazardLayout.pass_progress(HazardLayout.default_layout().spots()[0])
	assert_almost_eq(spike_at, 0.5, 0.05, "the first spike is mid-room")
	for i: int in 100:
		if adv.room_id == _spikes().id and adv.progress >= spike_at - 0.11:
			break
		_sim.tick(Balance.TICK_DT)
	assert_eq(adv.room_id, _spikes().id, "reached the spike room")
	assert_eq(_sim.blood, 0.0, "not hit before reaching the spike")
	for i: int in 3:
		_sim.tick(Balance.TICK_DT)
	assert_eq(_sim.blood, F.SPIKE_HIT, "hit once on passing it")


func test_past_capacity_each_level_still_adds_damage() -> void:
	_sim.buy_room(&"spikes")
	var capacity := HazardLayout.default_layout().capacity()
	_spikes().level = capacity * 2
	assert_eq(_spikes().hazard_count(), capacity, "the room is full")
	assert_eq(_spikes().hazard_hit_damage(), F.SPIKE_HIT * 2.0, "so each hit is doubled")
	_walk_one_through()
	assert_almost_eq(_sim.blood, F.SPIKE_HIT * capacity * 2.0, 1e-6, "level × damage per crossing")
