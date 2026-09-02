extends Button

const BuildingInfo = preload("res://Classes/BuildingInfo.gd")

var building_scene: PackedScene
var building_name: String
var base_color: Color
var hovered = false
var hover_tex = null

func set_up(_building_name: String, _building_scene: PackedScene) -> void:
	building_name = _building_name
	building_scene = _building_scene

func _draw():
	var vec = rect_size
	if hovered and hover_tex != null:
		draw_texture_rect(hover_tex, Rect2(Vector2.ZERO, vec), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, vec), base_color)

func make_building() -> void:
	if Global.Main == null:
		return
	Global.Main.spawn_building(building_name)
