extends Label

## List of tips for your game
@export var tips: Array[String] = [
	"Right click to drag the camera",
	"Get a job as soon as posible",
	"WASD or arrow keys to move camera",
	"Remember to use the Skill Tree",
	"The game saves",
	"Loans help build credit"
]

## How long to show each tip in seconds
@export var display_time: float = 8.0

func _ready() -> void:
	if tips.size() > 0:
		show_new_tip()
		_start_tip_timer()
	else:
		text = "Stay tuned for more tips!"

func _start_tip_timer() -> void:
	# Create a recurring timer without needing a Timer Node
	while true:
		await get_tree().create_timer(display_time).timeout
		show_new_tip()

func show_new_tip() -> void:
	# Pick a random tip that isn't the one currently displayed
	var new_tip = tips.pick_random()
	
	# Optional: Prevent the same tip from showing twice in a row
	while new_tip == text and tips.size() > 1:
		new_tip = tips.pick_random()
	
	text = new_tip
