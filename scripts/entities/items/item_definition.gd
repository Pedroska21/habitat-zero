extends Resource

@export var item_id: StringName
@export var display_name: String = "Item de teste"
@export_range(0, 2, 1) var effect: int = 0
@export var pickup_color: Color = Color.WHITE
