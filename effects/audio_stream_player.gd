extends AudioStreamPlayer
class_name DynamicAudioPlayer

@export_group("Dynamic Sound Settings")
## A typed dictionary where you can assign sounds and name them in the Inspector.
@export var sound_library: Dictionary[String, AudioStream] = {
	"hover": null,
	"success": null,
	"error": null
}

## Default micro-pitch range to prevent auditory fatigue
@export var pitch_variation: float = 0.04

## Plays a specific sound from your library by its string name.
func play_sound(sound_name: String, base_pitch: float = 1.0) -> void:
	if not sound_library.has(sound_name):
		push_error("DynamicAudioPlayer: Sound '%s' not found in library!" % sound_name)
		return
		
	var stream: AudioStream = sound_library[sound_name]
	if stream:
		_execute_dynamic_play(stream, base_pitch)

## Fallback: Plays a sound directly if you want to pass an AudioStream resource from code.
func play_stream_directly(stream: AudioStream, base_pitch: float = 1.0) -> void:
	if stream:
		_execute_dynamic_play(stream, base_pitch)

# Internal processing to handle polyphony (layering sounds) and pitching
func _execute_dynamic_play(stream: AudioStream, base_pitch: float) -> void:
	# Spawning a temporary child player lets sounds overlap without cutting each other off
	var temp_player = AudioStreamPlayer.new()
	add_child(temp_player)
	
	# Assign the properties and copy bus settings
	temp_player.stream = stream
	temp_player.bus = self.bus 
	
	# Apply micro-pitch randomization
	var random_pitch_modifier = randf_range(-pitch_variation, pitch_variation)
	temp_player.pitch_scale = base_pitch + random_pitch_modifier
	
	# Automatically free the node when finished playing
	temp_player.finished.connect(temp_player.queue_free)
	temp_player.play()
