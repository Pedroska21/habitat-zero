extends Node

const SLOT_COUNT: int = 4
const PICKUP_RANGE: float = 4.5
const USE_RANGE: float = 8.0
const THROW_FORWARD_IMPULSE: float = 4.0
const THROW_UP_IMPULSE: float = 1.8
const PAINT_MARK_GROUP: StringName = &"test_paint_marks"
const EFFECT_PAINT_BLUE: int = 1
const EFFECT_ERASE_PAINT: int = 2
const WORLD_ITEM_SCENE: PackedScene = preload("res://scenes/entities/items/world_item.tscn")

var slots: Array[Resource] = [null, null, null, null]
var selected_slot: int = 0

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var camera: Camera3D = player.get_node("Head/Camera3D") as Camera3D
@onready var status_label: Label = player.get_node("Hud/InventoryStatus") as Label
@onready var slot_labels: Array[Label] = [
	player.get_node("Hud/InventoryPanel/Slots/Slot1") as Label,
	player.get_node("Hud/InventoryPanel/Slots/Slot2") as Label,
	player.get_node("Hud/InventoryPanel/Slots/Slot3") as Label,
	player.get_node("Hud/InventoryPanel/Slots/Slot4") as Label,
]


func _ready() -> void:
	_refresh_hud()
	_set_status("E coletar  |  Q arremessar  |  M1 usar")


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("pickup_item"):
		_pickup_aimed_item()
		return
	if event.is_action_pressed("drop_item"):
		_drop_selected_item()
		return
	if event.is_action_pressed("use_item"):
		_use_selected_item()
		return

	for slot_index in range(SLOT_COUNT):
		if event.is_action_pressed("select_slot_%d" % (slot_index + 1)):
			_select_slot(slot_index)
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_slot(posmod(selected_slot - 1, SLOT_COUNT))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_slot((selected_slot + 1) % SLOT_COUNT)


func _pickup_aimed_item() -> void:
	var empty_slot := _find_empty_slot()
	if empty_slot == -1:
		_set_status("Inventário cheio: solte um item com Q")
		return

	var hit := _raycast(PICKUP_RANGE)
	if hit.is_empty():
		_set_status("Mire em um item próximo para coletá-lo")
		return

	var world_item := hit.get("collider") as RigidBody3D
	if world_item == null:
		_set_status("Mire em um item de teste para coletá-lo")
		return

	var definition := world_item.get("definition") as Resource
	if definition == null:
		_set_status("Mire em um item de teste para coletá-lo")
		return
	slots[empty_slot] = definition
	var collected_name: String = definition.get("display_name")
	world_item.queue_free()
	_refresh_hud()
	_set_status("Coletado: %s" % collected_name)


func _drop_selected_item() -> void:
	var definition: Resource = slots[selected_slot]
	if definition == null:
		_set_status("O slot selecionado está vazio")
		return

	var dropped_item := WORLD_ITEM_SCENE.instantiate() as RigidBody3D
	dropped_item.set("definition", definition)
	get_tree().current_scene.add_child(dropped_item)
	var forward := -camera.global_transform.basis.z
	dropped_item.global_position = camera.global_position + forward * 0.8 - Vector3.UP * 0.4
	dropped_item.apply_central_impulse(forward * THROW_FORWARD_IMPULSE + Vector3.UP * THROW_UP_IMPULSE)
	dropped_item.apply_torque_impulse(Vector3(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8), randf_range(-0.8, 0.8)))
	slots[selected_slot] = null
	_refresh_hud()
	_set_status("Arremessado: %s" % definition.get("display_name"))


func _use_selected_item() -> void:
	var definition: Resource = slots[selected_slot]
	if definition == null:
		_set_status("Selecione um item antes de usar M1")
		return

	var effect: int = definition.get("effect")
	if effect == 0:
		_set_status("%s ainda não tem uma função de teste" % definition.get("display_name"))
		return

	var hit := _raycast(USE_RANGE)
	if hit.is_empty():
		_set_status("Mire em uma superfície ao alcance")
		return

	match effect:
		EFFECT_PAINT_BLUE:
			_create_blue_mark(hit)
			_set_status("Marca azul aplicada")
		EFFECT_ERASE_PAINT:
			_erase_near_hit(hit.get("position", Vector3.ZERO))


func _create_blue_mark(hit: Dictionary) -> void:
	var mark := MeshInstance3D.new()
	mark.name = "BlueTestMark"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.28
	disc.height = 0.012
	disc.radial_segments = 32
	mark.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.28, 1.0, 1.0)
	material.roughness = 0.5
	mark.material_override = material
	mark.add_to_group(PAINT_MARK_GROUP)
	get_tree().current_scene.add_child(mark)

	var normal: Vector3 = hit.get("normal", Vector3.UP).normalized()
	var surface_point: Vector3 = hit.get("position", Vector3.ZERO)
	mark.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), surface_point + normal * 0.012)


func _erase_near_hit(hit_position: Vector3) -> void:
	var closest_mark: Node3D
	var closest_distance := 0.65
	for candidate in get_tree().get_nodes_in_group(PAINT_MARK_GROUP):
		var mark := candidate as Node3D
		if mark == null:
			continue
		var distance := mark.global_position.distance_to(hit_position)
		if distance <= closest_distance:
			closest_mark = mark
			closest_distance = distance

	if closest_mark == null:
		_set_status("Nenhuma marca azul perto do ponto mirado")
		return
	closest_mark.queue_free()
	_set_status("Colorido apagado")


func _raycast(max_distance: float) -> Dictionary:
	var start := camera.global_position
	var end := start - camera.global_transform.basis.z * max_distance
	var query := PhysicsRayQueryParameters3D.create(start, end)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query)


func _find_empty_slot() -> int:
	for index in range(SLOT_COUNT):
		if slots[index] == null:
			return index
	return -1


func _select_slot(slot_index: int) -> void:
	selected_slot = clampi(slot_index, 0, SLOT_COUNT - 1)
	_refresh_hud()
	var definition: Resource = slots[selected_slot]
	_set_status("Slot %d: %s" % [selected_slot + 1, definition.get("display_name") if definition != null else "Vazio"])


func _refresh_hud() -> void:
	for index in range(SLOT_COUNT):
		var definition: Resource = slots[index]
		var item_name: String = definition.get("display_name") if definition != null else "Vazio"
		slot_labels[index].text = "%d  %s" % [index + 1, item_name]
		var color := Color(0.45, 0.82, 1.0) if index == selected_slot else Color(0.9, 0.92, 0.94)
		slot_labels[index].add_theme_color_override("font_color", color)


func _set_status(message: String) -> void:
	status_label.text = message
