extends Control


func _on_skip_song_pressed() -> void:
	$ScrollContainer/VBoxContainer/AudioStreamPlayer.skip_song()


func _on_play_music_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$ScrollContainer/VBoxContainer/AudioStreamPlayer.stop()
	else:
		$ScrollContainer/VBoxContainer/AudioStreamPlayer.play_random_song()
