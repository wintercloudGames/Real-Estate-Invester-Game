@tool
extends EditorScript

# The source data for all jobs
var jobs_data = [
	# --- LABOR CATEGORY ---
	{"name": "Street Sweeper", "cat": "Labor", "lvl": 1, "pts": 0, "pay": 450, "exp": 10, "job_exp": 0.01},
	{"name": "Furniture Mover", "cat": "Labor", "lvl": 2, "pts": 1, "pay": 600, "exp": 12, "job_exp": 0.01},
	{"name": "Junk Hauler", "cat": "Labor", "lvl": 4, "pts": 2, "pay": 850, "exp": 15, "job_exp": 0.02},
	{"name": "Landscaping Assistant", "cat": "Labor", "lvl": 6, "pts": 4, "pay": 1200, "exp": 18, "job_exp": 0.02},
	{"name": "Roofer", "cat": "Labor", "lvl": 9, "pts": 6, "pay": 1700, "exp": 22, "job_exp": 0.03},
	{"name": "Demolition Specialist", "cat": "Labor", "lvl": 12, "pts": 8, "pay": 2300, "exp": 28, "job_exp": 0.04},
	{"name": "Concrete Finisher", "cat": "Labor", "lvl": 15, "pts": 12, "pay": 3100, "exp": 35, "job_exp": 0.05},
	{"name": "Heavy Equipment Op", "cat": "Labor", "lvl": 20, "pts": 18, "pay": 4200, "exp": 45, "job_exp": 0.06},
	{"name": "Site Foreman", "cat": "Labor", "lvl": 28, "pts": 25, "pay": 6000, "exp": 60, "job_exp": 0.08},
	{"name": "Construction Director", "cat": "Labor", "lvl": 40, "pts": 40, "pay": 9500, "exp": 85, "job_exp": 0.1},

	# --- SERVICES CATEGORY ---
	{"name": "Dishwasher", "cat": "Services", "lvl": 1, "pts": 0, "pay": 500, "exp": 10, "job_exp": 0.01},
	{"name": "House Cleaner", "cat": "Services", "lvl": 3, "pts": 1, "pay": 750, "exp": 14, "job_exp": 0.01},
	{"name": "Delivery Driver", "cat": "Services", "lvl": 5, "pts": 2, "pay": 1050, "exp": 18, "job_exp": 0.02},
	{"name": "Security Guard", "cat": "Services", "lvl": 8, "pts": 5, "pay": 1550, "exp": 24, "job_exp": 0.03},
	{"name": "Concierge", "cat": "Services", "lvl": 11, "pts": 8, "pay": 2200, "exp": 30, "job_exp": 0.04},
	{"name": "Event Coordinator", "cat": "Services", "lvl": 16, "pts": 12, "pay": 3200, "exp": 40, "job_exp": 0.05},
	{"name": "Private Investigator", "cat": "Services", "lvl": 22, "pts": 18, "pay": 4800, "exp": 55, "job_exp": 0.07},
	{"name": "Luxury Travel Agent", "cat": "Services", "lvl": 30, "pts": 25, "pay": 7500, "exp": 75, "job_exp": 0.1},
	{"name": "Estate Manager", "cat": "Services", "lvl": 42, "pts": 45, "pay": 14000, "exp": 110, "job_exp": 0.15},
	{"name": "Hospitality Tycoon", "cat": "Services", "lvl": 50, "pts": 60, "pay": 28000, "exp": 180, "job_exp": 0.2},

	# --- TRADE CATEGORY ---
	{"name": "Apprentice Carpenter", "cat": "Trade", "lvl": 2, "pts": 1, "pay": 850, "exp": 15, "job_exp": 0.02},
	{"name": "Painter", "cat": "Trade", "lvl": 4, "pts": 2, "pay": 1200, "exp": 20, "job_exp": 0.03},
	{"name": "Pipefitter", "cat": "Trade", "lvl": 7, "pts": 5, "pay": 1800, "exp": 28, "job_exp": 0.05},
	{"name": "HVAC Tech", "cat": "Trade", "lvl": 10, "pts": 8, "pay": 2600, "exp": 38, "job_exp": 0.06},
	{"name": "Electrician", "cat": "Trade", "lvl": 14, "pts": 12, "pay": 3800, "exp": 50, "job_exp": 0.08},
	{"name": "Master Plumber", "cat": "Trade", "lvl": 19, "pts": 18, "pay": 5500, "exp": 65, "job_exp": 0.12},
	{"name": "Interior Designer", "cat": "Trade", "lvl": 25, "pts": 25, "pay": 8500, "exp": 90, "job_exp": 0.15},
	{"name": "Structural Inspector", "cat": "Trade", "lvl": 32, "pts": 35, "pay": 13000, "exp": 120, "job_exp": 0.2},
	{"name": "Restoration Expert", "cat": "Trade", "lvl": 40, "pts": 50, "pay": 21000, "exp": 160, "job_exp": 0.3},
	{"name": "Master Architect", "cat": "Trade", "lvl": 50, "pts": 70, "pay": 35000, "exp": 250, "job_exp": 0.4},

	# --- FINANCE CATEGORY ---
	{"name": "Tax Preparer", "cat": "Finance", "lvl": 5, "pts": 2, "pay": 1500, "exp": 25, "job_exp": 0.05},
	{"name": "Loan Processor", "cat": "Finance", "lvl": 9, "pts": 5, "pay": 2800, "exp": 40, "job_exp": 0.07},
	{"name": "Bank Auditor", "cat": "Finance", "lvl": 14, "pts": 10, "pay": 4500, "exp": 60, "job_exp": 0.1},
	{"name": "Underwriter", "cat": "Finance", "lvl": 20, "pts": 18, "pay": 6800, "exp": 85, "job_exp": 0.15},
	{"name": "Stock Analyst", "cat": "Finance", "lvl": 26, "pts": 25, "pay": 10500, "exp": 115, "job_exp": 0.2},
	{"name": "Portfolio Manager", "cat": "Finance", "lvl": 33, "pts": 35, "pay": 17000, "exp": 160, "job_exp": 0.3},
	{"name": "Investment Banker", "cat": "Finance", "lvl": 40, "pts": 50, "pay": 28000, "exp": 220, "job_exp": 0.45},
	{"name": "Hedge Fund Lead", "cat": "Finance", "lvl": 45, "pts": 65, "pay": 45000, "exp": 300, "job_exp": 0.6},
	{"name": "Venture Capitalist", "cat": "Finance", "lvl": 50, "pts": 80, "pay": 65000, "exp": 450, "job_exp": 0.8},
	{"name": "Central Bank Chair", "cat": "Finance", "lvl": 60, "pts": 100, "pay": 95000, "exp": 700, "job_exp": 1.0},

	# --- MANAGEMENT CATEGORY ---
	{"name": "Shift Lead", "cat": "Management", "lvl": 5, "pts": 2, "pay": 1600, "exp": 20, "job_exp": 0.05},
	{"name": "Office Manager", "cat": "Management", "lvl": 10, "pts": 6, "pay": 3000, "exp": 35, "job_exp": 0.08},
	{"name": "Assistant Principal", "cat": "Management", "lvl": 18, "pts": 15, "pay": 5200, "exp": 55, "job_exp": 0.12},
	{"name": "District Manager", "cat": "Management", "lvl": 25, "pts": 22, "pay": 9000, "exp": 85, "job_exp": 0.2},
	{"name": "Operations Director", "cat": "Management", "lvl": 32, "pts": 30, "pay": 15000, "exp": 130, "job_exp": 0.3},
	{"name": "Property Strategist", "cat": "Management", "lvl": 38, "pts": 40, "pay": 24000, "exp": 190, "job_exp": 0.45},
	{"name": "Regional VP", "cat": "Management", "lvl": 44, "pts": 55, "pay": 38000, "exp": 280, "job_exp": 0.6},
	{"name": "Chief Op Officer", "cat": "Management", "lvl": 50, "pts": 75, "pay": 60000, "exp": 400, "job_exp": 0.8},
	{"name": "Chief Exec Officer", "cat": "Management", "lvl": 55, "pts": 90, "pay": 85000, "exp": 600, "job_exp": 1.0},
	{"name": "Chairman of the Board", "cat": "Management", "lvl": 70, "pts": 120, "pay": 135000, "exp": 1000, "job_exp": 1.5}
]

const SAVE_PATH = "res://assets/job/jobs/"

func _run():
	print("--- Starting Job Generation ---")
	
	# Create directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(SAVE_PATH):
		var dir_err = DirAccess.make_dir_recursive_absolute(SAVE_PATH)
		if dir_err != OK:
			print("CRITICAL ERROR: Could not create folder at ", SAVE_PATH)
			return
		else:
			print("Created folder: ", SAVE_PATH)
		
	for data in jobs_data:
		var job = JobData.new()
		
		# Resource Assignments
		job.job_name = data["name"]
		job.category = data["cat"]
		job.required_player_level = data["lvl"]
		job.required_skill_points = data["pts"]
		job.monthly_salary = data["pay"]
		job.Exp_gain_per_month = data["exp"]
		
		# UPDATED: Changed from jop to job to match your script
		job.job_exp_gain_per_month = data["job_exp"] 
		
		job.description = "A standard job in the %s sector." % data["cat"]
		
		# Filename formatting
		var safe_name = data["name"].to_lower().replace(" ", "_")
		var file_name = "%s_%s.tres" % [data["cat"].to_lower(), safe_name]
		var full_path = SAVE_PATH + file_name
		
		# Save Resource
		var err = ResourceSaver.save(job, full_path)
		if err == OK:
			print("Saved: ", file_name)
		else:
			print("ERROR: Failed to save ", file_name, " (Error Code: ", err, ")")

	print("--- Job Generation Finished! ---")
	print("If the FileSystem is empty, right-click 'res://' and choose 'Re-scan'.")s
