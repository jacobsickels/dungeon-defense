extends GutTest
## Layout rules: branching, inserting with subtree shifts, and pathing.

var _content: ContentDB
var _d: Dungeon
var _entrance: DungeonRoom
var _hall: DungeonRoom
var _treasure: DungeonRoom


func before_each() -> void:
	_content = ContentFixture.make()
	# E(0,0) - H(1,0) - T(2,0), outside to the west.
	_d = Dungeon.new()
	_entrance = _d.add_entrance(_content.rooms[&"entrance"], Vector2i.ZERO, Vector2i.LEFT)
	_hall = _d.build_branch(_content.rooms[&"hallway"], _entrance.id, Vector2i.RIGHT)
	_treasure = _d.build_branch(_content.rooms[&"treasure"], _hall.id, Vector2i.RIGHT)


func _spikes() -> RoomDef:
	return _content.rooms[&"spikes"]


func test_starting_path_runs_entrance_hall_treasure() -> void:
	assert_eq(_d.path(_entrance.id, _treasure.id), [_entrance.id, _hall.id, _treasure.id])
	assert_eq(_d.nearest_treasure(_entrance.id), _treasure.id)


func test_cannot_build_on_occupied_or_outside_cells() -> void:
	assert_false(_d.can_build_branch(_entrance.id, Vector2i.RIGHT), "occupied by hallway")
	assert_false(_d.can_build_branch(_entrance.id, Vector2i.LEFT), "outside door")
	assert_true(_d.can_build_branch(_entrance.id, Vector2i.UP))
	assert_false(_d.can_build_branch(_entrance.id, Vector2i(1, 1)), "diagonal isn't a direction")


func test_branch_connects_only_to_parent() -> void:
	var a := _d.build_branch(_spikes(), _hall.id, Vector2i.DOWN)   # (1,1)
	var b := _d.build_branch(_spikes(), _entrance.id, Vector2i.DOWN)  # (0,1), touches a on the grid
	assert_eq(a.coord, Vector2i(1, 1))
	assert_eq(b.coord, Vector2i(0, 1))
	assert_false(_d.neighbors(a.id).has(b.id), "touching on the grid doesn't make a connection")
	assert_eq(_d.path(b.id, a.id), [b.id, _entrance.id, _hall.id, a.id])


func test_insert_pushes_subtree_outward() -> void:
	var side := _d.build_branch(_spikes(), _treasure.id, Vector2i.UP)  # (2,-1)
	var inserted := _d.insert_between(_spikes(), _hall.id, _treasure.id)
	assert_not_null(inserted)
	assert_eq(inserted.coord, Vector2i(2, 0), "new room takes the child's old cell")
	assert_eq(_treasure.coord, Vector2i(3, 0))
	assert_eq(side.coord, Vector2i(3, -1), "the treasure's branch moves with it")
	assert_eq(_d.room_at(Vector2i(2, 0)), inserted)
	assert_eq(_d.room_at(Vector2i(3, 0)), _treasure)
	assert_null(_d.room_at(Vector2i(2, -1)), "the old cell was freed")
	assert_eq(_d.path(_entrance.id, _treasure.id),
			[_entrance.id, _hall.id, inserted.id, _treasure.id])


func test_insert_at_entrance_shifts_everything_but_entrance() -> void:
	var inserted := _d.insert_between(_spikes(), _entrance.id, _hall.id)
	assert_not_null(inserted)
	assert_eq(_entrance.coord, Vector2i(0, 0))
	assert_eq(inserted.coord, Vector2i(1, 0))
	assert_eq(_hall.coord, Vector2i(2, 0))
	assert_eq(_treasure.coord, Vector2i(3, 0))


func test_insert_blocked_when_shift_collides_with_other_branch() -> void:
	# A hangs below H, and F sits just below A.
	var a := _d.build_branch(_spikes(), _hall.id, Vector2i.DOWN)          # (1,1)
	var c := _d.build_branch(_spikes(), _entrance.id, Vector2i.DOWN)      # (0,1)
	var e := _d.build_branch(_spikes(), c.id, Vector2i.DOWN)              # (0,2)
	var f := _d.build_branch(_spikes(), e.id, Vector2i.RIGHT)             # (1,2)
	assert_eq(f.coord, Vector2i(1, 2))
	# Inserting between H and A would push A down onto F.
	assert_false(_d.can_insert(_hall.id, a.id))
	assert_null(_d.insert_between(_spikes(), _hall.id, a.id))
	assert_eq(a.coord, Vector2i(1, 1), "nothing moved")


func test_insert_requires_direct_parent_child() -> void:
	assert_false(_d.can_insert(_entrance.id, _treasure.id))
	assert_false(_d.can_insert(_hall.id, _entrance.id), "order matters: parent first")


func test_open_directions_excludes_occupied_and_outside() -> void:
	var dirs := _d.open_directions(_entrance.id)
	assert_false(dirs.has(Vector2i.LEFT))
	assert_false(dirs.has(Vector2i.RIGHT))
	assert_true(dirs.has(Vector2i.UP))
	assert_true(dirs.has(Vector2i.DOWN))
