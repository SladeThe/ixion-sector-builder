extends Node2D

var scale_factor = 2.0

const ResourceDisplayScript = preload("res://Classes/ResourceDisplay.gd")

func _draw():
	var main = Global.Main
	var square = main.SQUARE_SIZE * scale_factor
	var grid_size = main.SECTOR_SIZE * square
	draw_rect(Rect2(Vector2.ZERO, grid_size), Color("1B2029"), true)
	for y in main.SECTOR_SIZE.y:
		for x in main.SECTOR_SIZE.x:
			draw_rect(Rect2(Vector2(x, y) * square, square), main.GRID_COLOR, false, main.GRID_LINE_WIDTH * scale_factor)
	for child in main.get_children():
		if child is Building:
			var rect = Rect2(child.position * scale_factor, child.size * square)
			draw_rect(rect, child.display_color, true)
			draw_rect(rect, main.GRID_COLOR, false, main.GRID_LINE_WIDTH * scale_factor)
			draw_building_name(child, rect)
			if child.stockpile_resource != "":
				var icon = ResourceDisplayScript.ICON_DICT.get(child.stockpile_resource, null)
				if icon != null:
					var side = child.stockpile_icon_side() * scale_factor
					var icon_pos = rect.position + Vector2(2.0, 2.0) * scale_factor
					draw_texture_rect(icon, Rect2(icon_pos.x, icon_pos.y, side, side), false)

func draw_building_name(building, rect: Rect2):
	var longest_side = max(building.size.x, building.size.y)
	var font_tier = 1.5
	if longest_side <= 3.0:
		font_tier = 1.0
	elif longest_side >= 9.0:
		font_tier = 2.0
	var font = Global.Main.pick_building_font(rect.size.x, building.building_name, font_tier)
	var lines
	if rect.size.y > rect.size.x:
		lines = building.building_name.split(" ")
	else:
		lines = wrap_words(building.building_name, font, rect.size.x - 8.0 * font_tier)
	var line_h = font.get_height()
	var total_h = lines.size() * line_h
	var pos = Vector2(rect.position.x, rect.position.y + (rect.size.y - total_h) * 0.5)
	var text_color = Color.white if Global.Main.is_color_dark(building.display_color) else Color(0.06, 0.06, 0.09)
	for line in lines:
		var line_w = font.get_string_size(line).x
		draw_string(font, Vector2(rect.position.x + (rect.size.x - line_w) * 0.5, pos.y + line_h), line, text_color)
		pos.y += line_h

func wrap_words(text: String, font, max_width: float) -> Array:
	var lines = []
	var line = ""
	for word in text.split(" "):
		var candidate = word if line == "" else line + " " + word
		if line == "" or font.get_string_size(candidate).x <= max_width:
			line = candidate
		else:
			lines.append(line)
			line = word
	lines.append(line)
	return lines
