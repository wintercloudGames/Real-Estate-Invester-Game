extends Panel

signal name_confirmed(save_name: String)
signal cancelled

@onready var name_input = $VBoxContainer/NameInput as LineEdit

func _ready() -> void:
	# Connect the signal in case it's not connected in the editor
	if not name_input.text_submitted.is_connected(_on_name_input_text_submitted):
		name_input.text_submitted.connect(_on_name_input_text_submitted)
		
	name_input.grab_focus()
	name_input.select_all()

func _on_confirm_button_pressed() -> void:
	var final_name = name_input.text.strip_edges()
	
	if final_name.is_empty():
		final_name = "My Save"
		
	name_confirmed.emit(final_name)
	
	queue_free()

func _on_cancel_button_pressed() -> void:
	cancelled.emit()
	queue_free()

# This handles the ENTER key automatically
func _on_name_input_text_submitted(_new_text: String) -> void:
	_on_confirm_button_pressed()
