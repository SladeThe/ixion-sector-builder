extends Node2D

const GRID_COLOR = Color("5570A0")
const SQUARE_SIZE = Vector2(21, 21)
const SECTOR_SIZE = Vector2(56, 30)
const GRID_LINE_WIDTH = 3.0

const TILE_COLUMNS = 4
const TILE_SIZE = Vector2(131.0, 46.0)
const CATEGORY_SPACER = 6.0
const PANEL_MARGIN = 12.0
const IO_BUTTON_SIZE = Vector2(96.0, 36.0)
const TOOLBAR_HEIGHT = 56.0
const INSPECTOR_WIDTH = 340.0
const CANVAS_PAD = 12.0
const FRAME_GAP = 6.0
const WALL_ZONE_X0 = 24
const WALL_ZONE_X1 = 31
const WALL_ZONE_FILL = Color(1.0, 0.35, 0.35, 0.45)
const WALL_ZONE_BORDER = Color(1.0, 0.55, 0.55, 0.9)
const QUARTER_CAPACITY = {
	"Crew Quarters": 24.0,
	"Optimized Quarter": 64.0,
	"Domotic Quarter": 112.0,
	"Cell Housing": 162.0,
}
const BATTERY_STORAGE = {
	"Battery - Tier 1": 100.0,
	"Battery - Tier 2": 300.0,
	"Battery - Tier 3": 700.0,
}
const HEADER_COLOR = Color("C8CDD6")
const PANEL_BG = Color(0.07, 0.08, 0.12, 0.9)
const PANEL_BORDER = Color("5570A0")
const TEXT_DARK = Color(0.06, 0.06, 0.09)

const BuildingInfo = preload("res://Classes/BuildingInfo.gd")
const SidebarButton = preload("res://Classes/SidebarButton.gd")
const LayoutIO = preload("res://Classes/LayoutIO.gd")
const GridRenderScript = preload("res://Classes/GridRender.gd")

var target = Vector2.ZERO
var build_grid = []
var can_select = true

var resources = {}

var ui_scale = 1.0
var canvas_rect = Rect2()
var _shot_frames = -1

var ui_font: DynamicFont
var ui_font_large: DynamicFont
var ui_font_title: DynamicFont
var ui_font_small: DynamicFont
var header_labels = []
var button_labels = []
var palette_buttons = []
var palette_grids = []
var palette_spacers = []
var palette_box: VBoxContainer
var info_title: Label
var info_category: Label
var info_body: RichTextLabel
var sidebar: PanelContainer
var right_panel: PanelContainer
var toolbar: PanelContainer
var toolbar_row: HBoxContainer
var res_bar: HBoxContainer
var io_row: HBoxContainer
var left_box: HBoxContainer
var coord_label: Label
var building_fonts = {}
var building_scenes = {}
var import_pending = false
var last_sizes = {}
var wall_zone_show = false
var import_errors = []
var hover_building = null
var hover_entry = null
var messages_title: Label
var messages_body: RichTextLabel

var ResourceDisplayScene = preload("res://Classes/ResourceDisplay.tscn")

func _ready():
	Global.Main = self
	if OS.get_environment("IXION_SHOT") != "":
		_shot_frames = 30
	for x in SECTOR_SIZE.x:
		build_grid.append([])
		for y in SECTOR_SIZE.y:
			build_grid[x].append(0)
	get_viewport().connect("size_changed", self, "_on_viewport_resized")
	set_up_toolbar()
	set_up_resource_display()
	set_up_sidebar()
	set_up_right_rail()
	set_up_io_buttons()
	refresh_ui_scale()
	if OS.get_environment("IXION_LAYOUT") != "":
		var f = File.new()
		if f.open(OS.get_environment("IXION_LAYOUT"), File.READ) == OK:
			apply_layout(LayoutIO.from_yaml(f.get_as_text()))
			f.close()
	if OS.get_environment("IXION_HOVER_TEST") != "":
		var b = load("res://Buildings/Stockpile-Lg.tscn").instance()
		b.state = b.STATES.STATIC
		add_child(b)
		b.set_process(false)
		b.set_hover(true)
	if OS.get_environment("IXION_CONVERT") != "":
		convert_yaml_dir()

func _draw():
	for y in SECTOR_SIZE.y:
		for x in SECTOR_SIZE.x:
			draw_rect(Rect2(Vector2(x, y) * SQUARE_SIZE, SQUARE_SIZE), GRID_COLOR, false, GRID_LINE_WIDTH)
	if wall_zone_show:
		for x in range(WALL_ZONE_X0, WALL_ZONE_X1 + 1):
			if build_grid[x][0] == 0:
				var cell = Rect2(Vector2(x, 0) * SQUARE_SIZE, SQUARE_SIZE)
				draw_rect(cell, WALL_ZONE_FILL, true)
				draw_rect(cell, WALL_ZONE_BORDER, false, 1.0)

func _process(_delta):
	target = get_local_mouse_position() / SQUARE_SIZE
	target.x = floor(clamp(target.x, 0, SECTOR_SIZE.x - 1))
	target.y = floor(clamp(target.y, 0, SECTOR_SIZE.y - 1))
	coord_label.text = str(target)
	if import_pending:
		poll_import()
	update_wall_zone()
	if _shot_frames > 0:
		_shot_frames -= 1
		if _shot_frames == 0:
			var image = get_viewport().get_texture().get_data()
			image.flip_y()
			image.save_png("res://../shot.png")
			get_tree().quit()

func update_wall_zone():
	var show = false
	for child in get_children():
		if child is Building and child.wall_locked and child.state != Building.STATES.STATIC:
			show = true
			break
	if show != wall_zone_show:
		wall_zone_show = show
		update()

func wall_zone_blocked(pos: Vector2, bsize: Vector2) -> bool:
	return pos.y <= 0.5 and pos.x < WALL_ZONE_X1 + 1.0 and pos.x + bsize.x > WALL_ZONE_X0

func spawn_building(building_name: String):
	var scene = building_scenes.get(building_name, null)
	if scene == null:
		return
	var building = scene.instance()
	add_child(building)
	if last_sizes.has(building_name) and not building.wall_locked:
		building.size = last_sizes[building_name]
	can_select = false

func fit_camera():
	var view = get_viewport_rect().size
	var grid_px = SECTOR_SIZE * SQUARE_SIZE
	var pad = CANVAS_PAD * ui_scale
	var avail = canvas_rect.size - Vector2(2.0 * pad, 2.0 * pad)
	var z = clamp(max(grid_px.x / max(avail.x, 100.0), grid_px.y / max(avail.y, 100.0)), 0.35, 2.5)
	$Cam.zoom = Vector2(z, z)
	var center = canvas_rect.position + canvas_rect.size * 0.5
	$Cam.position = grid_px * 0.5 - (center - view * 0.5) * z

func _on_viewport_resized():
	refresh_ui_scale()
	fit_camera()

func bounds_ok(cells: PoolVector2Array) -> bool:
	for vec in cells:
		if vec.x < 0 or vec.y < 0 or vec.x >= SECTOR_SIZE.x or vec.y >= SECTOR_SIZE.y:
			return false
	return true

func is_grid_buildable(grid: PoolVector2Array):
	for vec in grid:
		if build_grid[vec.x][vec.y] == 1:
			return false
	return true

func set_buildability_of_points(points: PoolVector2Array, buildable: int):
	for vec in points:
		build_grid[vec.x][vec.y] = buildable
	update_resource_display()

func mouse_in_bounds():
	var pos = get_local_mouse_position()
	var bounds = SECTOR_SIZE * SQUARE_SIZE
	if pos.x >= 0 and pos.x <= bounds.x and pos.y >= 0 and pos.y <= bounds.y:
		return true
	return false

func set_up_toolbar():
	toolbar = PanelContainer.new()
	toolbar.name = "Toolbar"
	toolbar.add_stylebox_override("panel", make_panel_style())
	toolbar_row = HBoxContainer.new()
	toolbar_row.add_constant_override("separation", 16)
	left_box = HBoxContainer.new()
	coord_label = Label.new()
	left_box.add_child(coord_label)
	toolbar_row.add_child(left_box)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_row.add_child(spacer)
	res_bar = HBoxContainer.new()
	res_bar.add_constant_override("separation", 10)
	toolbar_row.add_child(res_bar)
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_row.add_child(spacer2)
	toolbar.add_child(toolbar_row)
	$UILayer.add_child(toolbar)

func set_up_resource_display():
	var temp_scene = ResourceDisplayScene.instance()
	var keys = temp_scene.ICON_DICT.keys()
	temp_scene.queue_free()
	for key in keys:
		var new_res = ResourceDisplayScene.instance()
		var color_text = true
		if key == "Housing" or key == "Workers":
			color_text = false
		new_res.set_up(key, color_text)
		res_bar.add_child(new_res)

func update_resource_display():
	var children = get_children()
	resources = {}
	for child in children:
		if child is Building:
			for res_name in child.resources.keys():
				if resources.has(res_name):
					resources[res_name] += child.resources[res_name]
				else:
					resources[res_name] = child.resources[res_name]
	for ResDis in res_bar.get_children():
		ResDis.visible = false
	for res_name in resources.keys():
		var ResDis = res_bar.get_node(res_name)
		ResDis.set_value(resources[res_name])
		if ResDis.name == "Workers":
			if resources.has("Housing"):
				if resources["Housing"] < resources["Workers"]:
					ResDis.get_node("HBoxContainer/RichTextLabel").self_modulate = Color.red
				else:
					ResDis.get_node("HBoxContainer/RichTextLabel").self_modulate = Color.white
			else:
				ResDis.get_node("HBoxContainer/RichTextLabel").self_modulate = Color.red
		ResDis.visible = true
	update_layout_messages()

func update_layout_messages():
	if messages_body == null:
		return
	var counts = {}
	var workers = 0.0
	var capacity = 0.0
	var stored_power = 0.0
	var total = 0
	for child in get_children():
		if child is Building and child.state == Building.STATES.STATIC:
			total += 1
			counts[child.building_name] = counts.get(child.building_name, 0) + 1
			workers += child.resources.get("Workers", 0.0)
			capacity += QUARTER_CAPACITY.get(child.building_name, 0.0)
			stored_power += BATTERY_STORAGE.get(child.building_name, 0.0)
	var errors = []
	for ie in import_errors:
		errors.append(ie)
	var warnings = []
	if total > 0:
		if not counts.has("Mess Hall"):
			errors.append("No Mess Hall - the crew would starve.")
		if not counts.has("Workshop"):
			errors.append("No Workshop - nothing can be constructed or repaired.")
		if capacity < workers:
			errors.append("Quarters house " + str(int(capacity)) + " of " + str(int(workers)) + " required workers.")
		if not counts.has("Fire Station"):
			warnings.append("No Fire Station - fires spread unchecked.")
		if not counts.has("DLS Center"):
			warnings.append("No DLS Center - no policies or specializations.")
		if not counts.has("Memorial"):
			warnings.append("No Memorial - missing an easy +1 Stability.")
		if not counts.has("Infirmary"):
			warnings.append("No Infirmary - injured crew have no local care.")
		if stored_power < 700.0:
			warnings.append("Stored power " + str(int(stored_power)) + " is below 700 - weak buffer for travel or overload.")
		if capacity < 800.0:
			if counts.has("Alternative Life Center"):
				warnings.append("Alternative Life Center at partial bonus - quarters house " + str(int(capacity)) + " of 800 people.")
			else:
				warnings.append("Quarters house " + str(int(capacity)) + " of 800 people - below the max Alternative Life Center bonus.")
	var text = ""
	if total == 0 and errors.empty():
		text = "[color=#8A93A3]Place buildings to see layout checks.[/color]"
	elif errors.empty() and warnings.empty():
		text = "[color=#7ADB8F]No layout issues.[/color]"
	else:
		for e in errors:
			text += "[color=#FF6B6B]" + e + "[/color]\n"
		for w in warnings:
			text += "[color=#FFD37A]" + w + "[/color]\n"
	messages_body.bbcode_text = text
	position_messages_panel(max(1, errors.size() + warnings.size()))

func position_messages_panel(line_count: int):
	pass

func collect_buildings():
	var by_category = {}
	var dir = Directory.new()
	if dir.open("res://Buildings/") != OK:
		print("An error occurred when trying to access the path.")
		return by_category
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var scene = load("res://Buildings/" + file_name)
			var probe = scene.instance()
			var entry = {
				"name": probe.building_name,
				"color": probe.display_color,
				"size": probe.size,
				"resources": probe.resources,
				"wall_locked": probe.wall_locked,
				"scene": scene,
			}
			probe.free()
			var meta = BuildingInfo.INFO.get(entry["name"], {})
			entry["category"] = meta.get("category", "Other")
			entry["description"] = meta.get("description", "")
			building_scenes[entry["name"]] = scene
			if not by_category.has(entry["category"]):
				by_category[entry["category"]] = []
			by_category[entry["category"]].append(entry)
		file_name = dir.get_next()
	dir.list_dir_end()
	for category in by_category.keys():
		by_category[category].sort_custom(self, "_sort_entries")
		var ordered = []
		for name in BuildingInfo.CATEGORY_TILES.get(category, []):
			for entry in by_category[category]:
				if entry["name"] == name:
					ordered.append(entry)
		for entry in by_category[category]:
			if ordered.find(entry) == -1:
				ordered.append(entry)
		by_category[category] = ordered
	return by_category

func _sort_entries(a, b):
	return a["name"] < b["name"]

func set_up_sidebar():
	sidebar = PanelContainer.new()
	sidebar.name = "Sidebar"
	sidebar.add_stylebox_override("panel", make_panel_style())
	palette_box = VBoxContainer.new()
	palette_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_box.add_constant_override("separation", 4)
	var by_category = collect_buildings()
	var categories = BuildingInfo.CATEGORY_ORDER.duplicate()
	for extra in by_category.keys():
		if categories.find(extra) == -1:
			categories.append(extra)
	for category in categories:
		if not by_category.has(category):
			continue
		var header = Label.new()
		header.text = category.to_upper()
		header.align = Label.ALIGN_CENTER
		header.add_color_override("font_color", HEADER_COLOR)
		palette_box.add_child(header)
		header_labels.append(header)
		var grid = GridContainer.new()
		grid.columns = TILE_COLUMNS
		grid.add_constant_override("hseparation", 8)
		grid.add_constant_override("vseparation", 8)
		for entry in by_category[category]:
			grid.add_child(make_building_button(entry))
		palette_box.add_child(grid)
		palette_grids.append(grid)
		if category != categories[categories.size() - 1]:
			var spacer = Control.new()
			spacer.rect_min_size = Vector2(0.0, CATEGORY_SPACER)
			palette_box.add_child(spacer)
			palette_spacers.append(spacer)
	sidebar.add_child(palette_box)
	$UILayer.add_child(sidebar)

func make_building_button(entry: Dictionary) -> Button:
	var button = SidebarButton.new()
	button.set_up(entry["name"], entry["scene"])
	button.base_color = entry["color"]
	button.flat = true
	button.rect_min_size = TILE_SIZE
	button.add_stylebox_override("focus", StyleBoxEmpty.new())
	var tile_text = BuildingInfo.tile_label(entry["name"])
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.bbcode_text = "[center]" + tile_text
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("lines", tile_text.split("\n").size())
	if is_color_dark(entry["color"]):
		label.add_color_override("default_color", Color.white)
	else:
		label.add_color_override("default_color", TEXT_DARK)
	button.add_child(label)
	button_labels.append(label)
	button.connect("pressed", self, "_on_button_pressed", [button])
	button.connect("mouse_entered", self, "_on_button_hover", [button, entry])
	button.connect("mouse_exited", self, "_on_button_blur", [button])
	button.connect("button_down", self, "_on_button_down", [button])
	button.connect("button_up", self, "_on_button_up", [button])
	palette_buttons.append(button)
	return button

func _on_button_pressed(button: Button):
	if can_select:
		button.make_building()

func is_color_dark(color: Color) -> bool:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114 < 0.55

func make_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func set_up_right_rail():
	right_panel = PanelContainer.new()
	right_panel.name = "RightRail"
	right_panel.add_stylebox_override("panel", make_panel_style())
	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 6)
	messages_title = Label.new()
	messages_title.text = "LAYOUT CHECK"
	messages_title.add_color_override("font_color", HEADER_COLOR)
	vbox.add_child(messages_title)
	messages_body = RichTextLabel.new()
	messages_body.bbcode_enabled = true
	messages_body.scroll_active = true
	messages_body.fit_content_height = false
	messages_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(messages_body)
	var title_row = HBoxContainer.new()
	title_row.add_constant_override("separation", 12)
	info_title = Label.new()
	info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_title.add_color_override("font_color", Color.white)
	title_row.add_child(info_title)
	info_category = Label.new()
	info_category.align = Label.ALIGN_RIGHT
	info_category.add_color_override("font_color", Color("8A93A3"))
	title_row.add_child(info_category)
	vbox.add_child(title_row)
	info_body = RichTextLabel.new()
	info_body.bbcode_enabled = true
	info_body.scroll_active = true
	info_body.fit_content_height = false
	vbox.add_child(info_body)
	right_panel.add_child(vbox)
	$UILayer.add_child(right_panel)
	show_info_hint()

func show_info_hint():
	info_title.text = "Controls"
	info_category.text = ""
	info_body.bbcode_text = "LMB place or move | R rotate | RMB / Esc cancel or delete\nMMB on a stockpile cycles its stored resource (Shift+MMB reverses).\nExport saves a PNG with the layout embedded; hold Shift for YAML\nwhen the browser has no save picker. Hover a building for details."

func _on_button_hover(button: Button, entry: Dictionary):
	hover_entry = entry
	button.hovered = true
	button.hover_tex = BuildingInfo.hover_texture(button.rect_size, entry["color"])
	button.update()
	var size_text = str(int(entry["size"].x)) + " x " + str(int(entry["size"].y))
	if entry["wall_locked"]:
		size_text += " | wall only"
	info_title.text = entry["name"]
	info_category.text = entry["category"].to_upper()
	info_body.bbcode_text = PoolStringArray([size_text, format_resources(entry["resources"]), "", entry["description"]]).join("\n")

func _on_button_blur(button: Button):
	button.hovered = false
	button.hover_tex = null
	button.modulate = Color.white
	button.update()
	hover_entry = null
	show_info_hint()

func set_hover_building(b):
	if hover_building == b:
		return
	hover_building = b
	if b == null:
		if hover_entry == null:
			show_info_hint()
		return
	var size_text = str(int(b.size.x)) + " x " + str(int(b.size.y))
	var meta = BuildingInfo.INFO.get(b.building_name, {})
	info_title.text = b.building_name
	info_category.text = meta.get("category", "").to_upper()
	var lines = [size_text, format_resources(b.resources)]
	if b.stockpile_resource != "":
		lines.append("Stores: " + b.stockpile_resource)
	lines.append(meta.get("description", ""))
	info_body.bbcode_text = PoolStringArray(lines).join("\n")

func _on_button_down(button: Button):
	button.modulate = Color(0.8, 0.8, 0.8)

func _on_button_up(button: Button):
	button.modulate = Color.white

func set_up_io_buttons():
	io_row = HBoxContainer.new()
	io_row.add_constant_override("separation", 10)
	for label in ["Import", "Export", "Clear"]:
		var button = Button.new()
		button.text = label
		button.rect_min_size = IO_BUTTON_SIZE
		button.add_stylebox_override("normal", make_io_style(false))
		button.add_stylebox_override("hover", make_io_style(true))
		button.add_stylebox_override("pressed", make_io_style(false, true))
		button.add_stylebox_override("focus", StyleBoxEmpty.new())
		button.connect("pressed", self, "_on_io_button", [label])
		io_row.add_child(button)
	toolbar_row.add_child(io_row)

func make_io_style(hover: bool, pressed: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if hover:
		style.bg_color = Color(0.2, 0.24, 0.36)
		style.border_color = Color("9FB3CC")
	elif pressed:
		style.bg_color = Color(0.08, 0.09, 0.14)
		style.border_color = PANEL_BORDER
	else:
		style.bg_color = Color(0.12, 0.14, 0.21)
		style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _on_io_button(label: String):
	if label == "Import":
		start_import()
	elif label == "Export":
		export_layout(Input.is_key_pressed(KEY_SHIFT))
	elif label == "Clear":
		clear_grid()

func js_eval(code: String):
	if not OS.has_feature("JavaScript"):
		return null
	return JavaScript.eval(code, true)

func last_path() -> String:
	var value = js_eval("localStorage.getItem('ixion-builder-last-path') || ''")
	if value == null:
		return ""
	return String(value)

func remember_path(file_name: String):
	js_eval("localStorage.setItem('ixion-builder-last-path', " + JSON.print(file_name) + ")")

func default_base_name(extension: String) -> String:
	var previous = last_path()
	if previous != "":
		var dot = previous.find_last(".")
		if dot > 0 and previous.substr(dot + 1).to_lower() == extension.to_lower():
			return previous.substr(0, dot)
	return "ixion-sector"

func collect_layout() -> Array:
	var data = []
	for child in get_children():
		if child is Building and child.state == Building.STATES.STATIC:
			data.append({"name": child.building_name, "pos": child.position / SQUARE_SIZE, "size": child.size, "resource": child.stockpile_resource})
	return data

func export_layout(yaml_mode: bool = false):
	var png_bytes = yield(render_grid_png(), "completed")
	if png_bytes == null or png_bytes.size() == 0:
		return
	var yaml = LayoutIO.to_yaml(collect_layout())
	js_eval("ixionSaveLayout(" + JSON.print(Marshalls.raw_to_base64(png_bytes)) + ", " + JSON.print(yaml) + ", " + JSON.print(default_base_name("png")) + ", " + ("true" if yaml_mode else "false") + ")")


func start_import():
	import_pending = true
	js_eval("ixionPickImport()")

func poll_import():
	var err = js_eval("window.__ixion_import_error || null")
	if err != null and String(err) != "":
		js_eval("window.__ixion_import_error = null")
		import_pending = false
		import_errors = [String(err)]
		update_layout_messages()
		return
	var value = js_eval("window.__ixion_import || null")
	if value == null or String(value) == "":
		return
	import_pending = false
	js_eval("window.__ixion_import = null")
	apply_layout(LayoutIO.from_yaml(String(value)))

func apply_layout(entries: Array):
	clear_grid()
	for entry in entries:
		var scene = building_scenes.get(entry["name"], null)
		if scene == null:
			continue
		var building = scene.instance()
		add_child(building)
		building.size = entry["size"]
		building.position = entry["pos"] * SQUARE_SIZE
		building.stockpile_resource = entry.get("resource", "")
		building.state = Building.STATES.STATIC
		var cells = building.get_grid_translation()
		var pos_text = "(" + str(int(entry["pos"].x)) + ", " + str(int(entry["pos"].y)) + ")"
		if not bounds_ok(cells):
			import_errors.append(entry["name"] + " at " + pos_text + " is out of bounds - skipped.")
			building.queue_free()
			continue
		if not is_grid_buildable(cells):
			import_errors.append(entry["name"] + " at " + pos_text + " overlaps another building.")
		set_buildability_of_points(cells, 1)

func clear_grid():
	import_errors = []
	hover_building = null
	for child in get_children():
		if child is Building:
			child.free()
	for x in SECTOR_SIZE.x:
		for y in SECTOR_SIZE.y:
			build_grid[x][y] = 0
	can_select = true
	update_resource_display()

func render_grid_png() -> PoolByteArray:
	var scale_factor = 2.0
	var viewport = Viewport.new()
	viewport.size = SECTOR_SIZE * SQUARE_SIZE * scale_factor
	viewport.render_target_v_flip = true
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	var node = Node2D.new()
	node.set_script(GridRenderScript)
	node.scale_factor = scale_factor
	viewport.add_child(node)
	add_child(viewport)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var image = viewport.get_texture().get_data()
	var path = "user://ixion-export.png"
	if not OS.has_feature("JavaScript"):
		path = "res://../export-test.png"
	image.save_png(path)
	var file = File.new()
	file.open(path, File.READ)
	var bytes = file.get_buffer(file.get_len())
	file.close()
	if OS.has_feature("JavaScript"):
		var dir = Directory.new()
		dir.remove(path)
	viewport.queue_free()
	return bytes

func format_resources(res: Dictionary) -> String:
	if res.empty():
		return "No sector-wide effects"
	var keys = res.keys()
	keys.sort()
	var parts = []
	for key in keys:
		var value = res[key]
		var prefix = "+"
		if value < 0:
			prefix = ""
		parts.append(key + " " + prefix + str(stepify(value, 0.1)))
	return PoolStringArray(parts).join(" | ")

func make_font(size: int, outlined: bool = false, filtered: bool = true) -> DynamicFont:
	var font = DynamicFont.new()
	font.font_data = load("res://Belwe Medium.otf")
	font.size = size
	font.use_filter = filtered
	font.extra_spacing_top = 2
	font.extra_spacing_bottom = 2
	if outlined:
		font.outline_size = 1
		font.outline_color = Color(0, 0, 0, 1)
	return font

func building_font(size: int) -> DynamicFont:
	if not building_fonts.has(size):
		building_fonts[size] = make_font(size, false)
	return building_fonts[size]

func pick_building_font(width_px: float, building_name: String, font_scale: float = 1.0) -> DynamicFont:
	for base_size in [14, 12, 11]:
		var size = int(round(base_size * font_scale))
		var font = building_font(size)
		var max_word = 0.0
		for word in building_name.split(" "):
			max_word = max(max_word, font.get_string_size(word).x)
		if max_word <= width_px - 8.0 * font_scale:
			return font
	return building_font(int(round(11 * font_scale)))

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.control:
		if event.scancode == KEY_O:
			start_import()
		elif event.scancode == KEY_S:
			export_layout(event.shift)

func refresh_ui_scale():
	var view = get_viewport_rect().size
	ui_scale = clamp(min(view.x / 2560.0, view.y / 1440.0), 0.8, 1.3)
	ui_font = make_font(int(round(15 * ui_scale)), false, false)
	ui_font_large = make_font(int(round(17 * ui_scale)), true, false)
	ui_font_title = make_font(int(round(16 * ui_scale)), false, false)
	ui_font_small = make_font(int(round(13 * ui_scale)), false, false)
	for header in header_labels:
		header.add_font_override("font", ui_font_large)
	var line_h = ui_font.get_height()
	var tile = palette_tile_size()

	for button in palette_buttons:
		button.rect_min_size = tile
	for label in button_labels:
		label.add_font_override("normal_font", ui_font)
		var lines = int(label.get_meta("lines", 1))
		label.rect_position = Vector2(4.0 * ui_scale, (tile.y - lines * line_h) * 0.5)
		label.rect_size = Vector2(tile.x - 8.0 * ui_scale, lines * line_h + 4.0)
	palette_box.add_constant_override("separation", int(4 * ui_scale))
	for grid in palette_grids:
		grid.add_constant_override("hseparation", int(8 * ui_scale))
		grid.add_constant_override("vseparation", int(8 * ui_scale))
	for spacer in palette_spacers:
		spacer.rect_min_size = Vector2(0.0, CATEGORY_SPACER * ui_scale)
	info_title.add_font_override("font", ui_font_title)
	info_category.add_font_override("font", ui_font_small)
	info_body.add_font_override("normal_font", ui_font)
	info_body.rect_min_size = Vector2(0.0, 9.0 * ui_font.get_height())
	messages_title.add_font_override("font", ui_font_small)
	messages_body.add_font_override("normal_font", ui_font_small)
	coord_label.add_font_override("font", ui_font)
	for button in io_row.get_children():
		button.add_font_override("font", ui_font_small)
		button.rect_min_size = IO_BUTTON_SIZE * ui_scale
	for ResDis in res_bar.get_children():
		ResDis.get_node("HBoxContainer/RichTextLabel").add_font_override("normal_font", ui_font)
		ResDis.get_node("HBoxContainer/TextureRect").rect_min_size = Vector2(27, 27) * ui_scale
	layout_ui()
	fit_camera()
	update_layout_messages()

func palette_tile_size() -> Vector2:
	var view = get_viewport_rect().size
	var tile = TILE_SIZE * ui_scale
	var width_scale = 0.8
	var aspect = view.x / max(view.y, 1.0)
	if aspect > 2.4:
		width_scale = 1.0
	elif aspect >= 2.0:
		width_scale = 0.8 + (aspect - 2.0) * 0.5
	tile.x *= width_scale
	return tile

func layout_ui():
	var view = get_viewport_rect().size
	var s = ui_scale
	var toolbar_h = round(TOOLBAR_HEIGHT * s)
	var gap = round(FRAME_GAP * s)
	var palette_w = round(TILE_COLUMNS * palette_tile_size().x + (TILE_COLUMNS - 1) * 8.0 * s + 2.0 * PANEL_MARGIN)
	var rail_w = round(INSPECTOR_WIDTH * s)
	toolbar.rect_position = Vector2.ZERO
	toolbar.rect_size = Vector2(view.x, toolbar_h)
	left_box.rect_min_size = Vector2(round(3.0 * IO_BUTTON_SIZE.x * s + 20.0 * s), 0.0)
	sidebar.rect_position = Vector2(0.0, toolbar_h + gap)
	sidebar.rect_size = Vector2(palette_w, view.y - toolbar_h - gap)
	right_panel.rect_position = Vector2(view.x - rail_w, toolbar_h + gap)
	right_panel.rect_size = Vector2(rail_w, view.y - toolbar_h - gap)
	canvas_rect = Rect2(palette_w, toolbar_h + gap, view.x - palette_w - rail_w, view.y - toolbar_h - gap)

func convert_yaml_dir():
	var dir = Directory.new()
	var err = dir.open(ProjectSettings.globalize_path("res://") + "../../sectors")
	if err != OK:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".yaml") or file_name.ends_with(".yml"):
			yield(convert_one(dir.get_current_dir() + "/" + file_name), "completed")
		file_name = dir.get_next()
	dir.list_dir_end()

func convert_one(path: String):
	var f = File.new()
	if f.open(path, File.READ) != OK:
		return
	var yaml = f.get_as_text()
	f.close()
	apply_layout(LayoutIO.from_yaml(yaml))
	yield(get_tree(), "idle_frame")
	var bytes = yield(render_grid_png(), "completed")
	if bytes != null and bytes.size() > 0:
		var out = File.new()
		if out.open(path.get_basename() + ".png", File.WRITE) == OK:
			out.store_buffer(bytes)
			out.close()

func _on_Main_child_exiting_tree(_node):
	call_deferred("update_resource_display")
