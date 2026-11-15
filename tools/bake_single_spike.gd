extends SceneTree
## Extracts one spike from KayKit's floor_tile_big_spikes (whose "spikes" mesh is 9 spikes merged
## into one) and saves it as its own mesh, keeping KayKit's material.
##
## Run from the project root:
##   "E:/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tools/bake_single_spike.gd

const SOURCE := "res://assets/third_party/kaykit/dungeon/floor_tile_big_spikes.gltf"
const OUTPUT := "res://assets/derived/kaykit_single_spike.tres"
## The middle spike of the 3×3 grid sits at the origin and fits inside this box.
const CENTER_BOX := AABB(Vector3(-0.3, -0.1, -0.3), Vector3(0.6, 2.5, 0.6))


func _init() -> void:
	var scene: Node = (load(SOURCE) as PackedScene).instantiate()
	var source: MeshInstance3D = scene.find_child("spikes", true, false)
	var arrays := source.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	# Keep the triangles whose corners are all inside the middle spike's box.
	var remap: Dictionary[int, int] = {}
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_indices := PackedInt32Array()
	for t: int in range(0, indices.size(), 3):
		var tri := [indices[t], indices[t + 1], indices[t + 2]]
		if not tri.all(func(i: int) -> bool: return CENTER_BOX.has_point(verts[i])):
			continue
		for i: int in tri:
			if not remap.has(i):
				remap[i] = out_verts.size()
				out_verts.append(verts[i])
				out_normals.append(normals[i])
				out_uvs.append(uvs[i])
			out_indices.append(remap[i])

	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_verts
	out[Mesh.ARRAY_NORMAL] = out_normals
	out[Mesh.ARRAY_TEX_UV] = out_uvs
	out[Mesh.ARRAY_INDEX] = out_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	mesh.surface_set_material(0, source.mesh.surface_get_material(0))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var err := ResourceSaver.save(mesh, OUTPUT)
	print("Saved %s: %d vertices, %d triangles (error %d)" % [OUTPUT, out_verts.size(), out_indices.size() / 3, err])
	scene.free()
	quit()
