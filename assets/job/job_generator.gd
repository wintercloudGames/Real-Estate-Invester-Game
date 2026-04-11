@tool
extends EditorScript

# This is the data from your spreadsheet
var jobs_data = [
	# --- LABOR CATEGORY ---
	{"name": "Street Sweeper", "cat": "Labor", "lvl": 1, "pts": 0, "pay": 700},
	{"name": "Furniture Mover", "cat": "Labor", "lvl": 2, "pts": 1, "pay": 950},
	{"name": "Junk Hauler", "cat": "Labor", "lvl": 4, "pts": 2, "pay": 1300},
	{"name": "Landscaping Assistant", "cat": "Labor", "lvl": 6, "pts": 4, "pay": 1800},
	{"name": "Roofer", "cat": "Labor", "lvl": 9, "pts": 6, "pay": 2500},
	{"name": "Demolition Specialist", "cat": "Labor", "lvl": 12, "pts": 8, "pay": 3400},
	{"name": "Concrete Finisher", "cat": "Labor", "lvl": 15, "pts": 12, "pay": 4600},
	{"name": "Heavy Equipment Op", "cat": "Labor", "lvl": 20, "pts": 18, "pay": 6200},
	{"name": "Site Foreman", "cat": "Labor", "lvl": 28, "pts": 25, "pay": 9500},
	{"name": "Construction Director", "cat": "Labor", "lvl": 40, "pts": 40, "pay": 15000},

	# --- SERVICES CATEGORY ---
	{"name": "Dishwasher", "cat": "Services", "lvl": 1, "pts": 0, "pay": 750},
	{"name": "House Cleaner", "cat": "Services", "lvl": 3, "pts": 1, "pay": 1100},
	{"name": "Delivery Driver", "cat": "Services", "lvl": 5, "pts": 2, "pay": 1500},
	{"name": "Security Guard", "cat": "Services", "lvl": 8, "pts": 5, "pay": 2200},
	{"name": "Concierge", "cat": "Services", "lvl": 11, "pts": 8, "pay": 3100},
	{"name": "Event Coordinator", "cat": "Services", "lvl": 16, "pts": 12, "pay": 4500},
	{"name": "Private Investigator", "cat": "Services", "lvl": 22, "pts": 18, "pay": 6800},
	{"name": "Luxury Travel Agent", "cat": "Services", "lvl": 30, "pts": 25, "pay": 10500},
	{"name": "Estate Manager", "cat": "Services", "lvl": 42, "pts": 45, "pay": 22000},
	{"name": "Hospitality Tycoon", "cat": "Services", "lvl": 50, "pts": 60, "pay": 45000},

	# --- TRADE CATEGORY ---
	{"name": "Apprentice Carpenter", "cat": "Trade", "lvl": 2, "pts": 1, "pay": 1200},
	{"name": "Painter", "cat": "Trade", "lvl": 4, "pts": 2, "pay": 1700},
	{"name": "Pipefitter", "cat": "Trade", "lvl": 7, "pts": 5, "pay": 2400},
	{"name": "HVAC Tech", "cat": "Trade", "lvl": 10, "pts": 8, "pay": 3600},
	{"name": "Electrician", "cat": "Trade", "lvl": 14, "pts": 12, "pay": 5200},
	{"name": "Master Plumber", "cat": "Trade", "lvl": 19, "pts": 18, "pay": 7800},
	{"name": "Interior Designer", "cat": "Trade", "lvl": 25, "pts": 25, "pay": 12000},
	{"name": "Structural Inspector", "cat": "Trade", "lvl": 32, "pts": 35, "pay": 18500},
	{"name": "Restoration Expert", "cat": "Trade", "lvl": 40, "pts": 50, "pay": 30000},
	{"name": "Master Architect", "cat": "Trade", "lvl": 50, "pts": 70, "pay": 55000},

	# --- FINANCE CATEGORY ---
	{"name": "Tax Preparer", "cat": "Finance", "lvl": 5, "pts": 2, "pay": 2000},
	{"name": "Loan Processor", "cat": "Finance", "lvl": 9, "pts": 5, "pay": 3800},
	{"name": "Bank Auditor", "cat": "Finance", "lvl": 14, "pts": 10, "pay": 6000},
	{"name": "Underwriter", "cat": "Finance", "lvl": 20, "pts": 18, "pay": 9200},
	{"name": "Stock Analyst", "cat": "Finance", "lvl": 26, "pts": 25, "pay": 14500},
	{"name": "Portfolio Manager", "cat": "Finance", "lvl": 33, "pts": 35, "pay": 24000},
	{"name": "Investment Banker", "cat": "Finance", "lvl": 40, "pts": 50, "pay": 42000},
	{"name": "Hedge Fund Lead", "cat": "Finance", "lvl": 45, "pts": 65, "pay": 68000},
	{"name": "Venture Capitalist", "cat": "Finance", "lvl": 50, "pts": 80, "pay": 95000},
	{"name": "Central Bank Chair", "cat": "Finance", "lvl": 60, "pts": 100, "pay": 150000},

	# --- MANAGEMENT CATEGORY ---
	{"name": "Shift Lead", "cat": "Management", "lvl": 5, "pts": 2, "pay": 2200},
	{"name": "Office Manager", "cat": "Management", "lvl": 10, "pts": 6, "pay": 4000},
	{"name": "Assistant Principal", "cat": "Management", "lvl": 18, "pts": 15, "pay": 7500},
	{"name": "District Manager", "cat": "Management", "lvl": 25, "pts": 22, "pay": 13000},
	{"name": "Operations Director", "cat": "Management", "lvl": 32, "pts": 30, "pay": 21000},
	{"name": "Property Strategist", "cat": "Management", "lvl": 38, "pts": 40, "pay": 35000},
	{"name": "Regional VP", "cat": "Management", "lvl": 44, "pts": 55, "pay": 55000},
	{"name": "Chief Op Officer", "cat": "Management", "lvl": 50, "pts": 75, "pay": 85000},
	{"name": "Chief Exec Officer", "cat": "Management", "lvl": 55, "pts": 90, "pay": 120000},
	{"name": "Chairman of the Board", "cat": "Management", "lvl": 70, "pts": 120, "pay": 200000}
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
