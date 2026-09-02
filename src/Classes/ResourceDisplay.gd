extends MarginContainer

const ICON_DICT = {
	"Iron": preload("res://Art/Resources/Iron.png"), 
	"Alloy": preload("res://Art/Resources/Alloy.png"), 
	
	"Carbon": preload("res://Art/Resources/Carbon.png"), 
	"Polymer": preload("res://Art/Resources/Polymer.png"), 
	
	"Silicon": preload("res://Art/Resources/Silicon.png"), 
	"Electronics": preload("res://Art/Resources/Electronics.png"), 
	
	
	"Hydrogen": preload("res://Art/Resources/Hydrogen.png"), 
	
	
	
	"Power": preload("res://Art/Resources/Power.png"), 
	
	
	"Waste": preload("res://Art/Resources/Waste.png"), 
	"Water": preload("res://Art/Resources/Water.png"), 
	
	"Cryopod": preload("res://Art/Resources/Cryopod.png"), 
	
	"Ice": preload("res://Art/Resources/Ice.png"), 
	"Food": preload("res://Art/Resources/Food.png"), 
	
	"Workers": preload("res://Art/Resources/Workers.png"), 
	"Housing": preload("res://Art/Resources/Housing.png"), 
	"Science": preload("res://Art/Resources/Science.png")
}

var color_text: bool = true


func set_value(value: float):
	$HBoxContainer / RichTextLabel.text = str(stepify(value, 0.1))
	$HBoxContainer / RichTextLabel.self_modulate = Color.white
	if not color_text:
		return
	if value > 0:
		$HBoxContainer / RichTextLabel.text = "+" + $HBoxContainer / RichTextLabel.text
		$HBoxContainer / RichTextLabel.self_modulate = Color.green
	elif value < 0:
		$HBoxContainer / RichTextLabel.self_modulate = Color.red
	

func set_up(resource_name: String, _color_text: = true):
	if ICON_DICT.has(resource_name):
		$HBoxContainer / TextureRect.texture = ICON_DICT[resource_name]
	name = resource_name
	color_text = _color_text
	visible = false


