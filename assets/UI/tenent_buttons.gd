extends Control

@onready var tenent_name_label = $Name_Label
@onready var tenent_rent_label = $Rent_Label
var house = null
@onready var max_rent = house.morgage if house and house.morgage > 0 else 1500
@onready var rent = randi_range(500, int(max_rent))
@onready var game =  $"../../../../.."



func _ready() -> void:
	
	tenent_name_label.text = "Potential Tenant "

func add_comma_to_int(value: int) -> String:
	var str_value: String = str(value)
	var loop_end: int = 0 if value > -1 else 1
	
	for i in range(str_value.length()-3, loop_end, -3):
		str_value = str_value.insert(i, ",")

	return str_value


func _process(delta: float) -> void:
	var rounded_number = round(rent / 250.0) * 250
	rent = rounded_number
	tenent_rent_label.text = "Rent: " + add_comma_to_int(rent)


func _on_texture_rect_pressed() -> void:
	var temp = $"../../.."
	temp.visible = false
	
	game.picked_tenant()
	if game.house != null:
		game.house.add_tenant(rent)
		
	rent = randi_range(500, int(max_rent) * 3)
