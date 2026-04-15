extends AudioStreamPlayer

var songs: Array = [
	"res://music/background-music-piano-soft-380590.mp3",
	"res://music/chill-happy.mp3",
	"res://music/emotional-inspiring.mp3",
	"res://music/happiness-upbeat.mp3",
	"res://music/in-the-heavens.mp3",
	"res://music/lo-fi-hip-hop-galaxy.mp3",
	"res://music/smooth-chill-jazzy.mp3",

]
var current_song: String = ""

func _ready():
	update_volume()
	play_random_song()

func play_random_song():
	if songs.is_empty():
		print("No songs found!")
		return

	var new_song = current_song
	while new_song == current_song and songs.size() > 1:
		new_song = songs.pick_random()
	current_song = new_song
	
	# Load and play the new song
	var stream_res = load(current_song)
	if stream_res:
		stream = stream_res
		play()
	else:
		print("Failed to load song:", current_song)

func _on_song_finished():
	play_random_song()

func skip_song():
	stop()
	play_random_song()

func update_volume():
	volume_db = Settings.Music  # Apply global volume setting
