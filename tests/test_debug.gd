extends SceneTree

func _initialize() -> void:
	await process_frame
	
	var root := Node3D.new()
	root.name = "TestRoot"
	
	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.name = "TestMultiMesh"
	var multimesh := MultiMesh.new()
	multimesh.instance_count = 10
	multimesh.mesh = BoxMesh.new()
	mm_instance.multimesh = multimesh
	root.add_child(mm_instance)
	
	var mi := MeshInstance3D.new()
	mi.name = "TestMeshInstance"
	mi.mesh = BoxMesh.new()
	root.add_child(mi)
	
	# Test find_children with different patterns
	var mm_found1 := root.find_children("*", "MultiMeshInstance3D")
	print("find_children('*', 'MultiMeshInstance3D'): %d" % mm_found1.size())
	
	var mm_found2 := root.find_children("", "MultiMeshInstance3D")
	print("find_children('', 'MultiMeshInstance3D'): %d" % mm_found2.size())
	
	var mm_found3 := root.find_children("*", "")
	print("find_children('*', ''): %d" % mm_found3.size())
	for node in mm_found3:
		print("  %s: %s" % [node.name, node.get_class()])
	
	var mm_found4 := root.get_children()
	print("get_children(): %d" % mm_found4.size())
	for node in mm_found4:
		print("  %s: %s" % [node.name, node.get_class()])
	
	await process_frame
	quit(0)