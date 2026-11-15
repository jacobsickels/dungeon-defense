extends GutTest
## Hazards (spikes): where they stand, and adventurers taking one hit per hazard they pass.

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


func test_layout_is_stable_and_inside_the_room() -> void:
	var spots := HazardLayout.spots()
	assert_eq(spots.size(), (HazardLayout.EXTENT * 2 + 1) ** 2)
	assert_eq(HazardLayout.spots(), spots, "same every call")
	for spot: Vector2 in spots:
		assert_lt(absf(spot.x), HazardLayout.HALF_ROOM)
		assert_lt(absf(spot.y), HazardLayout.HALF_ROOM)
	assert_lt(spots[0].length(), 0.5, "the first spike is in the middle of the room")


func test_layout_fills_the_path_before_the_sides() -> void:
	# The first few spikes are spread along the path (x), not across it (z).
	var spots := HazardLayout.spots()
	for i: int in 5:
		assert_lt(absf(spots[i].y), 0.5, "spike %d should be on the path: %s" % [i, spots[i]])


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


func test_hit_lands_when_passing_the_spike_not_before() -> void:
	_sim.buy_room(&"spikes")
	_sim.blood = 0.0
	var adv := _sim.spawn_adventurer(_sim.content.adventurers[&"peasant"])
	var spike_at := HazardLayout.pass_progress(HazardLayout.spots()[0])
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


func test_spikes_beyond_capacity_add_nothing() -> void:
	_sim.buy_room(&"spikes")
	_spikes().level = HazardLayout.capacity() + 10
	assert_eq(_spikes().hazard_count(), HazardLayout.capacity())
