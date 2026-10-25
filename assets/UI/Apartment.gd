extends Node3D
@onready var game: Node = get_node("/root/Root/UserInterface/Game")

var id: String = "" 
var bought_price = 0
var loan_price = 0.0 
var owned = false
var has_loan = false
var has_tenant = false
var tenant = null
var paid_rent = false
var just_bought = false
var upgrade_max: int = 10
var upgrade_amount: int = 0
var for_sale = false
var time_on_market = 0
var owner_type: String = "none"
var loan_module: Control = null
var is_on_screen: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_area_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and !Globals.yard_edit:
		game.house = self
		if owned:
			game.set_house_UI()
		else:
			if for_sale:       
				game.set_listing_UI()
