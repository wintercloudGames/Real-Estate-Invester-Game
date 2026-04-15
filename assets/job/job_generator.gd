@tool
extends EditorScript

# This is the data from your spreadsheet
var jobs_data = [
	# --- LABOR CATEGORY ---
	{"name": "Street Sweeper", "cat": "Labor", "lvl": 1, "pts": 0, "pay": 450, "exp": 10, "job_exp": 1},
	{"name": "Furniture Mover", "cat": "Labor", "lvl": 2, "pts": 1, "pay": 600, "exp": 12, "job_exp": 1},
	{"name": "Junk Hauler", "cat": "Labor", "lvl": 4, "pts": 2, "pay": 850, "exp": 15, "job_exp": 1.2},
	{"name": "Landscaping Assistant", "cat": "Labor", "lvl": 6, "pts": 4, "pay": 1200, "exp": 18, "job_exp": 1.2},
	{"name": "Roofer", "cat": "Labor", "lvl": 9, "pts": 6, "pay": 1700, "exp": 22, "job_exp": 1.5},
	{"name": "Demolition Specialist", "cat": "Labor", "lvl": 12, "pts": 8, "pay": 2300, "exp": 28, "job_exp": 1.5},
	{"name": "Concrete Finisher", "cat": "Labor", "lvl": 15, "pts": 12, "pay": 3100, "exp": 35, "job_exp": 2},
	{"name": "Heavy Equipment Op", "cat": "Labor", "lvl": 20, "pts": 18, "pay": 4200, "exp": 45, "job_exp": 2},
	{"name": "Site Foreman", "cat": "Labor", "lvl": 28, "pts": 25, "pay": 6000, "exp": 60, "job_exp": 2.5},
	{"name": "Construction Director", "cat": "Labor", "lvl": 40, "pts": 40, "pay": 9500, "exp": 85, "job_exp": 3},

	# --- SERVICES CATEGORY ---
	{"name": "Dishwasher", "cat": "Services", "lvl": 1, "pts": 0, "pay": 500, "exp": 10, "job_exp": 1},
	{"name": "House Cleaner", "cat": "Services", "lvl": 3, "pts": 1, "pay": 750, "exp": 14, "job_exp": 1},
	{"name": "Delivery Driver", "cat": "Services", "lvl": 5, "pts": 2, "pay": 1050, "exp": 18, "job_exp": 1.2},
	{"name": "Security Guard", "cat": "Services", "lvl": 8, "pts": 5, "pay": 1550, "exp": 24, "job_exp": 1.5},
	{"name": "Concierge", "cat": "Services", "lvl": 11, "pts": 8, "pay": 2200, "exp": 30, "job_exp": 1.8},
	{"name": "Event Coordinator", "cat": "Services", "lvl": 16, "pts": 12, "pay": 3200, "exp": 40, "job_exp": 2},
	{"name": "Private Investigator", "cat": "Services", "lvl": 22, "pts": 18, "pay": 4800, "exp": 55, "job_exp": 2.5},
	{"name": "Luxury Travel Agent", "cat": "Services", "lvl": 30, "pts": 25, "pay": 7500, "exp": 75, "job_exp": 3},
	{"name": "Estate Manager", "cat": "Services", "lvl": 42, "pts": 45, "pay": 14000, "exp": 110, "job_exp": 4},
	{"name": "Hospitality Tycoon", "cat": "Services", "lvl": 50, "pts": 60, "pay": 28000, "exp": 180, "job_exp": 5},

	# --- TRADE CATEGORY ---
	{"name": "Apprentice Carpenter", "cat": "Trade", "lvl": 2, "pts": 1, "pay": 850, "exp": 15, "job_exp": 1.5},
	{"name": "Painter", "cat": "Trade", "lvl": 4, "pts": 2, "pay": 1200, "exp": 20, "job_exp": 1.5},
	{"name": "Pipefitter", "cat": "Trade", "lvl": 7, "pts": 5, "pay": 1800, "exp": 28, "job_exp": 2},
	{"name": "HVAC Tech", "cat": "Trade", "lvl": 10, "pts": 8, "pay": 2600, "exp": 38, "job_exp": 2},
	{"name": "Electrician", "cat": "Trade", "lvl": 14, "pts": 12, "pay": 3800, "exp": 50, "job_exp": 2.5},
	{"name": "Master Plumber", "cat": "Trade", "lvl": 19, "pts": 18, "pay": 5500, "exp": 65, "job_exp": 3},
	{"name": "Interior Designer", "cat": "Trade", "lvl": 25, "pts": 25, "pay": 8500, "exp": 90, "job_exp": 3.5},
	{"name": "Structural Inspector", "cat": "Trade", "lvl": 32, "pts": 35, "pay": 13000, "exp": 120, "job_exp": 4},
	{"name": "Restoration Expert", "cat": "Trade", "lvl": 40, "pts": 50, "pay": 21000, "exp": 160, "job_exp": 5},
	{"name": "Master Architect", "cat": "Trade", "lvl": 50, "pts": 70, "pay": 35000, "exp": 250, "job_exp": 6},

	# --- FINANCE CATEGORY ---
	{"name": "Tax Preparer", "cat": "Finance", "lvl": 5, "pts": 2, "pay": 1500, "exp": 25, "job_exp": 2},
	{"name": "Loan Processor", "cat": "Finance", "lvl": 9, "pts": 5, "pay": 2800, "exp": 40, "job_exp": 2.5},
	{"name": "Bank Auditor", "cat": "Finance", "lvl": 14, "pts": 10, "pay": 4500, "exp": 60, "job_exp": 3},
	{"name": "Underwriter", "cat": "Finance", "lvl": 20, "pts": 18, "pay": 6800, "exp": 85, "job_exp": 3.5},
	{"name": "Stock Analyst", "cat": "Finance", "lvl": 26, "pts": 25, "pay": 10500, "exp": 115, "job_exp": 4},
	{"name": "Portfolio Manager", "cat": "Finance", "lvl": 33, "pts": 35, "pay": 17000, "exp": 160, "job_exp": 5},
	{"name": "Investment Banker", "cat": "Finance", "lvl": 40, "pts": 50, "pay": 28000, "exp": 220, "job_exp": 6},
	{"name": "Hedge Fund Lead", "cat": "Finance", "lvl": 45, "pts": 65, "pay": 45000, "exp": 300, "job_exp": 8},
	{"name": "Venture Capitalist", "cat": "Finance", "lvl": 50, "pts": 80, "pay": 65000, "exp": 450, "job_exp": 10},
	{"name": "Central Bank Chair", "cat": "Finance", "lvl": 60, "pts": 100, "pay": 95000, "exp": 700, "job_exp": 15},

	# --- MANAGEMENT CATEGORY ---
	{"name": "Shift Lead", "cat": "Management", "lvl": 5, "pts": 2, "pay": 1600, "exp": 20, "job_exp": 2},
	{"name": "Office Manager", "cat": "Management", "lvl": 10, "pts": 6, "pay": 3000, "exp": 35, "job_exp": 2.5},
	{"name": "Assistant Principal", "cat": "Management", "lvl": 18, "pts": 15, "pay": 5200, "exp": 55, "job_exp": 3},
	{"name": "District Manager", "cat": "Management", "lvl": 25, "pts": 22, "pay": 9000, "exp": 85, "job_exp": 4},
	{"name": "Operations Director", "cat": "Management", "lvl": 32, "pts": 30, "pay": 15000, "exp": 130, "job_exp": 5},
	{"name": "Property Strategist", "cat": "Management", "lvl": 38, "pts": 40, "pay": 24000, "exp": 190, "job_exp": 6},
	{"name": "Regional VP", "cat": "Management", "lvl": 44, "pts": 55, "pay": 38000, "exp": 280, "job_exp": 8},
	{"name": "Chief Op Officer", "cat": "Management", "lvl": 50, "pts": 75, "pay": 60000, "exp": 400, "job_exp": 10},
	{"name": "Chief Exec Officer", "cat": "Management", "lvl": 55, "pts": 90, "pay": 85000, "exp": 600, "job_exp": 12},
	{"name": "Chairman of the Board", "cat": "Management", "lvl": 70, "pts": 120, "pay": 135000, "exp": 1000, "job_exp": 20}
]

const SAVE_PATH = "res://assets/job/jobs/"

func _run():
	# Create directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(SAVE_PATH):
		DirAccess.make_dir_recursive_absolute(SAVE_PATH)
		
	for data in jobs_data:
		var job = JobData.new()
		job.job_name = data["name"]
		job.category = data["cat"]
		job.required_player_level = data["lvl"]
		job.required_skill_points = data["pts"]
		job.monthly_salary = data["pay"]
		job.description = "A standard job in the %s sector." % data["cat"]
		
		# Create a clean filename (e.g., "labor_street_sweeper.tres")
		var safe_name = data["name"].to_lower().replace(" ", "_")
		var file_name = "%s_%s.tres" % [data["cat"].to_lower(), safe_name]
		var full_path = SAVE_PATH + file_name
		
		var err = ResourceSaver.save(job, full_path)
		if err == OK:
			print("Generated: ", file_name)
		else:
			print("Error saving: ", file_name)
