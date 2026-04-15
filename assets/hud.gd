extends CanvasLayer

@onready var black_screen : ColorRect = $ColorRect

func _ready() -> void:
	black_screen.visible = true
	# 1. Start fully black
	black_screen.modulate.a = 1.0
	
	# 2. Wait for 1 second (as you requested)
	var timer = get_tree().create_timer(1.0)
	await timer.timeout
	
	# 3. Create a smooth fade-in
	fade_in()

func fade_in() -> void:
	var tween = create_tween()
	# Animates the 'alpha' (transparency) from 1 to 0 over 1.5 seconds
	tween.tween_property(black_screen, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE)
	
	# Optional: Hide the layer entirely when done to save performance
	tween.tween_callback(black_screen.hide)
