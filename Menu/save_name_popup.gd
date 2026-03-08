extends Panel

signal name_confirmed(save_name: String)
signal cancelled

@onready var name_input = $VBoxContainer/NameInput as LineEdit

func _ready() -> void:
	name_input.grab_focus()
	name_input.select_all()  # ← Select all text for easy editing

func _on_confirm_button_pressed() -> void:
	var save_name = name_input.text.strip_edges()
	if save_name.is_empty():
		save_name = "My Save"
	name_confirmed.emit(save_name)
	queue_free()

func _on_cancel_button_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_name_input_text_submitted(new_text: String) -> void:
	_on_confirm_button_pressed()
