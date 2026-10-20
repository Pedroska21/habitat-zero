extends RigidBody3D

@export var definition: Resource

@onready var display_mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	add_to_group("world_items")
	linear_damp = 1.2
	angular_damp = 3.5
	can_sleep = true
	if definition == null:
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = definition.get("pickup_color")
	material.roughness = 0.65
	display_mesh.material_override = material
