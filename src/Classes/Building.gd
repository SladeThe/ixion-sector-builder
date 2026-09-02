tool
extends Node2D
class_name Building

const GRID_COLOR = Color("5570A0")
const SQUARE_SIZE = Vector2(21, 21)
const SECTOR_SIZE = Vector2(56, 30)
const GRID_LINE_WIDTH = 3.0

const BuildingInfo = preload("res://Classes/BuildingInfo.gd")
const ResourceDisplayScript = preload("res://Classes/ResourceDisplay.gd")



export (String) var building_name = ""
export (Vector2) var size = Vector2(4, 4)
export (Color) var display_color = Color.white
export (Dictionary) var resources = {}
export (bool) var wall_locked = false

var Main
var being_placed = true
enum STATES{PLACING, STATIC, MOVING}
var state = STATES.PLACING

var button
var stockpile_resource = ""

var last_position = Vector2.ZERO
var last_size = Vector2.ZERO
var _hover = false
var _lp = Vector2(-1, -1)
var _ls = Vector2.ZERO
var _lm = Color.white
var _lr = "" 
var _hover_tex = null

func _ready():
	Main = get_parent()
	if not Engine.editor_hint and state != STATES.STATIC and Main.name == "Main":
		position = compute_target() * SQUARE_SIZE

func compute_target() -> Vector2:
	var target = Main.target - (size * 0.5) + Vector2(0.5, 0.5)
	target.x = floor(clamp(target.x, 0, SECTOR_SIZE.x - size.x))
	target.y = floor(clamp(target.y, 0, SECTOR_SIZE.y - size.y))
	if wall_locked:
		if target.y <= SECTOR_SIZE.y * 0.5:
			target.y = 0
		else:
			target.y = SECTOR_SIZE.y - size.y
	return target

func set_hover(on: bool):
	if _hover == on:
		return
	_hover = on
	if on:
		_hover_tex = BuildingInfo.hover_texture(size * SQUARE_SIZE, display_color)
	else:
		_hover_tex = null
	update()
	if on:
		Main.set_hover_building(self)
	elif Main.hover_building == self:
		Main.set_hover_building(null)



func _draw():
	var vec = size * SQUARE_SIZE
	if _hover and _hover_tex != null:
		draw_texture_rect(_hover_tex, Rect2(Vector2.ZERO, vec), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, vec), display_color)
	draw_rect(Rect2(Vector2.ZERO, vec), GRID_COLOR, false, GRID_LINE_WIDTH)
	$MarginContainer.rect_position = Vector2.ZERO
	$MarginContainer.rect_size = vec
	$MarginContainer / RichTextLabel.rect_size.x = vec.x
	if Global.Main != null:
		$MarginContainer / RichTextLabel.add_font_override("normal_font", Global.Main.pick_building_font(vec.x, building_name))
		var rtl = $MarginContainer / RichTextLabel
		var label_text = building_name
		if size.y > size.x:
			label_text = building_name.replace(" ", "\n")
		rtl.bbcode_text = "[center]" + label_text
		if Global.Main.is_color_dark(display_color):
			rtl.add_color_override("default_color", Color.white)
		else:
			rtl.add_color_override("default_color", Color(0.06, 0.06, 0.09))
	if stockpile_resource != "" and BuildingInfo.is_stockpile(building_name):
		var icon = ResourceDisplayScript.ICON_DICT.get(stockpile_resource, null)
		if icon != null:
			var side = stockpile_icon_side()
			draw_texture_rect(icon, Rect2(2.0, 2.0, side, side), false)

func _process(_delta):
	if not Engine.editor_hint and (state == STATES.PLACING or state == STATES.MOVING):
		if Main.name != "Main":
			return
		if Input.is_action_just_pressed("r"):
			rota()
		var target = compute_target()
		position = target * SQUARE_SIZE
		var cur_grid = get_grid_translation()
		var buildable = Main.is_grid_buildable(cur_grid) and (not wall_locked or not Main.wall_zone_blocked(target, size))
		if not buildable:
			self_modulate = Color(1, 0, 0)
		else:
			self_modulate = Color(1, 1, 1)
			
			if Input.is_action_just_pressed("l_click"):
				Main.set_buildability_of_points(cur_grid, 1)
				state = STATES.STATIC
				Main.last_sizes[building_name] = size
				Main.spawn_building(building_name)
		if Input.is_action_just_pressed("r_click") or Input.is_action_just_pressed("ui_cancel"):
			if state == STATES.PLACING:
				Main.set_deferred("can_select", true)
				queue_free()
			elif state == STATES.MOVING:
				position = last_position
				size = last_size
				cur_grid = get_grid_translation()
				Main.set_buildability_of_points(cur_grid, 1)
				state = STATES.STATIC
				Main.set_deferred("can_select", true)
	elif not Engine.editor_hint and state == STATES.STATIC:
		if Main.mouse_in_bounds() and Main.can_select:
			var cur_grid = get_grid_translation()
			var highlighted = highlight_check(cur_grid)
			if highlighted:
				self_modulate = Color(1, 1, 1)
				set_hover(true)
				
				if Input.is_action_just_pressed("l_click"):
					Main.set_buildability_of_points(cur_grid, 0)
					state = STATES.MOVING
					Main.can_select = false
					last_position = position
					last_size = size
					set_hover(false)
				
				if Input.is_action_just_pressed("r_click") or Input.is_action_just_pressed("ui_cancel"):
					Main.set_buildability_of_points(cur_grid, 0)
					set_hover(false)
					queue_free()
				
				if Input.is_action_just_pressed("m_click"):
					cycle_stockpile_resource(Input.is_physical_key_pressed(KEY_SHIFT))
			else:
				self_modulate = Color(1, 1, 1)
				set_hover(false)
		else:
			self_modulate = Color(1, 1, 1)
			set_hover(false)
	if position != _lp or size != _ls or self_modulate != _lm or stockpile_resource != _lr:
		_lp = position
		_ls = size
		_lm = self_modulate
		_lr = stockpile_resource
		update()

func rota():
	if not wall_locked:
		size = Vector2(size.y, size.x)
		if Main != null:
			Main.last_sizes[building_name] = size

func get_grid_translation():
	var list: = PoolVector2Array([])
	var pos = position / SQUARE_SIZE
	for y in size.y:
		for x in size.x:
			list.append(pos + Vector2(x, y))
	return list

func highlight_check(grid: PoolVector2Array):
	for vec in grid:
		if vec == Main.target:
			return true
	return false

func stockpile_icon_side() -> float:
	var shortest = min(size.x, size.y)
	var longest = max(size.x, size.y)
	if longest <= 4.0:
		return 16.0
	if shortest <= 4.0:
		return 24.0
	return 32.0

func cycle_stockpile_resource(reverse: bool = false):
	if not BuildingInfo.is_stockpile(building_name):
		return
	var options = [""] + BuildingInfo.STOCKPILE_RESOURCES
	var index = options.find(stockpile_resource)
	if reverse:
		index = (index + options.size() - 1) % options.size()
	else:
		index = (index + 1) % options.size()
	stockpile_resource = options[index]
	update()
