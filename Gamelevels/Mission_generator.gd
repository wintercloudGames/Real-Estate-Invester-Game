@tool
extends EditorScript


const MISSIONS_TO_CREATE = {
	# --- PHASE 1: THE BASICS ---
	"m_01": {"title": "The Emerging Tycoon", "target_money": 10000, "target_houses": 1, "time_limit_year": 3},
	"m_02": {"title": "Rental Rookie", "unlock_id_needed": "m_01", "target_rented_houses": 2, "target_player_level": 3, "time_limit_year": 5},
	"m_03": {"title": "Safety Net", "unlock_id_needed": "m_02", "target_savings": 10000, "time_limit_year": 6},
	"m_04": {"title": "Mobile Mogul", "unlock_id_needed": "m_03", "target_car_level": 3, "target_money": 15000, "time_limit_year": 7},
	"m_05": {"title": "Small Landlord", "unlock_id_needed": "m_04", "target_houses": 5, "target_rented_houses": 4, "time_limit_year": 10},

	# --- PHASE 2: MID-GAME EXPANSION ---
	"m_06": {"title": "Career Climber", "unlock_id_needed": "m_05", "target_player_level": 10, "target_money": 50000, "time_limit_year": 12},
	"m_07": {"title": "Urban Scout", "unlock_id_needed": "m_06", "target_houses": 10, "target_savings": 25000, "time_limit_year": 15},
	"m_08": {"title": "Fleet Manager", "unlock_id_needed": "m_07", "target_car_level": 5, "target_employees": 2, "time_limit_year": 15},
	"m_09": {"title": "Credit Master", "unlock_id_needed": "m_08", "target_credit_score": 750, "target_savings": 40000, "time_limit_year": 18},
	"m_10": {"title": "Local Legend", "unlock_id_needed": "m_09", "target_money": 100000, "target_rented_houses": 12, "time_limit_year": 20},

	# --- PHASE 3: THE ESTABLISHED MOGUL ---
	"m_11": {"title": "Neighborhood Pro", "unlock_id_needed": "m_10", "target_houses": 15, "target_player_level": 15, "time_limit_year": 22},
	"m_12": {"title": "Early Retirement", "unlock_id_needed": "m_11", "target_savings": 100000, "target_car_level": 8, "time_limit_year": 25},
	"m_13": {"title": "Business Anchor", "unlock_id_needed": "m_12", "target_employees": 10, "target_money": 200000, "time_limit_year": 28},
	"m_14": {"title": "Asset Collector", "unlock_id_needed": "m_13", "target_houses": 25, "target_rented_houses": 20, "time_limit_year": 30},
	"m_15": {"title": "The Quarter Million", "unlock_id_needed": "m_14", "target_money": 250000, "target_player_level": 25, "time_limit_year": 32},

	# --- PHASE 4: HIGH-STAKES INDUSTRY ---
	"m_16": {"title": "Regional Director", "unlock_id_needed": "m_15", "target_employees": 25, "target_savings": 200000, "time_limit_year": 35},
	"m_17": {"title": "Block Ruler", "unlock_id_needed": "m_16", "target_houses": 40, "target_car_level": 12, "time_limit_year": 38},
	"m_18": {"title": "Steady Growth", "unlock_id_needed": "m_17", "target_money": 500000, "target_rented_houses": 35, "time_limit_year": 40},
	"m_19": {"title": "Executive Suite", "unlock_id_needed": "m_18", "target_player_level": 40, "target_credit_score": 800, "time_limit_year": 42},
	"m_20": {"title": "Town Mayor", "unlock_id_needed": "m_19", "target_houses": 60, "target_employees": 50, "time_limit_year": 45},

	# --- PHASE 5: THE ENDGAME LEGACY ---
	"m_21": {"title": "The Half-Million", "unlock_id_needed": "m_20", "target_savings": 500000, "target_car_level": 15, "time_limit_year": 48},
	"m_22": {"title": "Industrial Base", "unlock_id_needed": "m_21", "target_houses": 80, "target_money": 1000000, "time_limit_year": 50},
	"m_23": {"title": "Centurion Goal", "unlock_id_needed": "m_22", "target_rented_houses": 100, "target_player_level": 60, "time_limit_year": 55},
	"m_24": {"title": "Empire Architect", "unlock_id_needed": "m_23", "target_employees": 100, "target_money": 2500000, "time_limit_year": 60},
	"m_25": {"title": "Project Master", "unlock_id_needed": "m_24", "target_money": 5000000, "target_houses": 150, "target_car_level": 20, "time_limit_year": 70}
}

# Where to save the resources
const SAVE_PATH = "res://Gamelevels/missons"

func _run():
	# Ensure the directory exists
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(SAVE_PATH):
		dir.make_dir_recursive(SAVE_PATH)
		print("Created directory: ", SAVE_PATH)

	for file_name in MISSIONS_TO_CREATE:
		var data = MISSIONS_TO_CREATE[file_name]
		create_mission_resource(file_name, data)

func create_mission_resource(file_name: String, data: Dictionary):
	var mission = MissionData.new()
	
	# Map dictionary keys to resource properties
	for key in data:
		if key in mission:
			mission.set(key, data[key])
		else:
			push_warning("Property '%s' not found in MissionData!" % key)

	var full_path = SAVE_PATH + file_name + ".tres"
	var result = ResourceSaver.save(mission, full_path)
	
	if result == OK:
		print("Successfully saved: ", full_path)
	else:
		push_error("Failed to save resource at: ", full_path)
