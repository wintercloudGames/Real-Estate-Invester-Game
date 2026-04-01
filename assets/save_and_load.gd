extends Node

const SAVE_DIR = "saves"
var current_save_slot = 0
var loaded_data: Dictionary = {}  # Store parsed save data for deferred application

# Loan type constants
const LOAN_TYPE_MORTGAGE: int = 0
const LOAN_TYPE_PERSONAL: int = 1

func get_save_path(slot: int) -> String:
	var exe_dir = OS.get_executable_path().get_base_dir()
	return exe_dir.path_join("%s/save_slot_%d.json" % [SAVE_DIR, slot])

func save_file_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

func save_game() -> bool:
	var save_path = get_save_path(current_save_slot)
	var save_dir = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		var dir = DirAccess.open(save_dir.get_base_dir())
		if not dir:
			push_error("Failed to access parent directory for saves")
			return false
		var err = dir.make_dir_recursive(save_dir)
		if err != OK:
			push_error("Failed to create saves directory: %s" % err)
			return false

	var data = {
		"Globals": {
			"save_name": Globals.save_name,
			"money": Globals.money,
			"brokerage_balance": Globals.brokerage_balance,
			"portfolio": Globals.portfolio,
			"first_start": Globals.first_start,
			"credit_score": Globals.credit_score,
			"credit_history": Globals.credit_history,
			"Expenses": Globals.Expenses,
			"Propertys": Globals.Propertys,
			"Income": Globals.Income,
			"Savings_balance": Globals.Savings_balance,
			"wallpaper": Globals.wallpaper,
			"difficulty": Globals.difficulty,
			"last_savings_paid": Globals.last_savings_paid,
			"Player_health": Globals.Player_health,
			"Player_hunger": Globals.Player_hunger,
			"Player_comfort": Globals.Player_comfort,
			"business_name": Globals.business_name,
			"Business_worth": Globals.Business_worth,
			"max_job_time": Globals.max_job_time,
			"job_pay": Globals.job_pay,
			"job_time": Globals.job_time,
			"employees": Globals.employees,
			"car_level": Globals.car_level,
			"has_car":Globals.has_car,
			"year": Globals.year,
			"month": Globals.month,
			"renter_finder": Globals.renter_finder,
			"hasagent": Globals.hasagent,
			"hascleaner": Globals.hascleaner,
			"mission_active": Globals.mission_active,
			"mission_type": Globals.mission_type,
			"mission_target": Globals.mission_target,
			"mission_deadline_year": Globals.mission_deadline_year,
			"mission_desc": Globals.mission_desc,
			"mission_completed": Globals.mission_completed,
		},
		"Skills": {
			"skillpoints": Globals.skillpoints,
			"exp": Globals.exp,
			"exp_to_level": Globals.exp_to_level,
			"level": Globals.level,
			"has_hireing_app": Globals.has_hireing_app,
			"has_info_app": Globals.has_info_app,
			"has_stock_app":Globals.has_stock_app,
			"has_market_app":Globals.has_market_app,
			"has_bank_app": Globals.has_bank_app,
			"has_manager_app": Globals.has_manager_app,
			"rent_houses": Globals.rent_houses,
			"rent_bost": Globals.rent_bost,
			"unlock_business": Globals.unlock_business,
			"job_manager": Globals.job_manager,
			"Job_bonus": Globals.Job_bonus,
			"business_bonus": Globals.business_bonus,
			"job_manager_level": Globals.job_manager_level,
			"work_bonus": Globals.work_bonus,
			"work_amount": Globals.work_amount,
			"rent_finder_upgrade": Globals.rent_finder_upgrade,
			"credit_app": Globals.credit_app
		},
		"Houses": [],
		"Loans": [],
		"Market": {}
	}
	var market_node = get_node_or_null("/root/Root/UserInterface/Game/Market")
	if market_node and market_node.has_method("get_market_data"):
		data["Market"] = market_node.get_market_data()
	else:
		data["Market"] = {}
	for stock in Globals.all_stocks:
		data["Market"][stock.ticker] = {
			"current_price": stock.current_price,
			"price_history": stock.price_history
		}
	# Save house data
	var houses = get_tree().get_nodes_in_group("houses")

	for house in houses:
		var collect_rent = house.get_node_or_null("Collect_Rent")
		if not is_instance_valid(house):
			push_warning("Invalid house in group 'houses': %s" % house.name)
			continue
			
		var house_data = {
			"id": house.id,
			"yard_objects": [],
			"plot": house.plot,
			"rarity": house.rarity,
			"base_price": house.base_price,
			"current_price": house.current_price,
			"mortgage": house.mortgage,
			"owner_type":house.owner_type,
			"for_sale":house.for_sale,
			"time_on_market":house.time_on_market,
			"bought_price": house.bought_price,
			"rent": house.rent,
			"lease_length": house.lease_length,
			"apartment_condition": house.apartment_condition,
			"mortgage_deducted": house.mortgage_deducted,
			"tenant_offers": house.tenant_offers,
			"is_listed": house.is_listed,
			"edit_mode": house.edit_mode,
			"loan_price": house.loan_price,
			"owned": house.owned,
			"has_loan": house.has_loan,
			"has_tenant": house.has_tenant,
			"just_bought": house.just_bought,
			"upgrade_amount": house.upgrade_amount,
			"remaining_months": house.remaining_months if house.has_method("set_remaining_months") else 0,
			"stored_cash": collect_rent.stored_cash if collect_rent else 0,
			"accumulated_months": collect_rent.accumulated_months if collect_rent else 0
		}
		data["Houses"].append(house_data)
		var storage = house.get_node_or_null("YardObjects")
		if storage:
			for item in storage.get_children():
				# Get the path we stored in metadata earlier
				var path = item.get_meta("scene_path", "")
				if path != "":
					var item_data = {
						"scene_path": path,
						"transform": var_to_str(item.transform) # Saves local position/rotation/scale
					}
					house_data["yard_objects"].append(item_data)
	# Save loan data
	var loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
	if loans_ui and is_instance_valid(loans_ui) and loans_ui.loan_mod_Container:
		for mod in loans_ui.active_loan_mods:
			if is_instance_valid(mod):
				var loan_type: int = LOAN_TYPE_MORTGAGE if mod.loan_type_str == "Mortgage" else LOAN_TYPE_PERSONAL
				data["Loans"].append({
					"loan_id": mod.loan_id,
					"loan_balance": mod.loan_balance,
					"months": int(mod.months),
					"payment": mod.payment,
					"interest": mod.interest,
					"loan_type": loan_type,
					"autopay_enabled": mod.autopay_enabled,
					"house_path": mod.house_ref.id if mod.house_ref and is_instance_valid(mod.house_ref) and "id" in mod.house_ref else ""
				})

			else:
				push_warning("Invalid mod instance in active_loan_mods")
	else:
		push_warning("No loans_ui or loan_mod_Container for saving loans")

	# Write to file
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file for writing: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	return true

func load_game() -> bool:
	var save_path = get_save_path(current_save_slot)
	if not FileAccess.file_exists(save_path):
		push_error("Save file does not exist at path: %s" % save_path)
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("Failed to open save file. Error: %s" % FileAccess.get_open_error())
		return false

	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("JSON parse failed. Error: %s" % json.get_error_message())
		return false

	loaded_data = json.get_data()
	if not loaded_data or not loaded_data is Dictionary:
		push_error("No valid data parsed from JSON")
		return false


	# Load non-node-dependent data
	if loaded_data.has("Globals"):
		var g = loaded_data["Globals"]

		# Existing important ones (add more as needed)
		Globals.save_name = g.get("save_name", "My Save")
		Globals.money = g.get("money", 5000)
		Globals.brokerage_balance = g.get("brokerage_balance", 0.0)
		Globals.portfolio = g.get("portfolio", {})
		Globals.first_start = g.get("first_start", true)
		Globals.credit_score = g.get("credit_score", 600)
		Globals.credit_history = g.get("credit_history", [Globals.credit_score])
		if typeof(Globals.credit_history) != TYPE_ARRAY:
			Globals.credit_history = [Globals.credit_score]
		Globals.Expenses = g.get("Expenses", 1000)
		Globals.Propertys = g.get("Propertys", 0)
		Globals.Income = g.get("Income", 0)
		Globals.Savings_balance = g.get("Savings_balance", 0)
		Globals.wallpaper = g.get("wallpaper", "")
		Globals.difficulty = g.get("difficulty", 1)
		Globals.last_savings_paid = g.get("last_savings_paid", 0)
		Globals.Player_health = g.get("Player_health", 100)
		Globals.Player_hunger = g.get("Player_hunger", 100)
		Globals.Player_comfort = g.get("Player_comfort", 100)
		Globals.business_name = g.get("business_name", "")
		Globals.Business_worth = g.get("Business_worth", 30000)
		Globals.max_job_time = g.get("max_job_time", 0)
		Globals.job_pay = g.get("job_pay", 0)
		Globals.job_time = g.get("job_time", 0)
		Globals.employees = g.get("employees", 0)
		Globals.car_level = g.get("car_level", 1)
		Globals.has_car = g.get("has_car",true)
		Globals.year = g.get("year", 1)
		Globals.month = g.get("month", 1)
		Globals.renter_finder = g.get("renter_finder", false)
		Globals.hasagent = g.get("hasagent", false)
		Globals.hascleaner = g.get("hascleaner", false)

		# Critical: explicitly set mission vars
		Globals.mission_active         = g.get("mission_active", false)
		Globals.mission_type           = g.get("mission_type", "")
		Globals.mission_target         = g.get("mission_target", 0)
		Globals.mission_deadline_year  = g.get("mission_deadline_year", 0)
		Globals.mission_desc           = g.get("mission_desc", "")
		Globals.mission_completed      = g.get("mission_completed", false)


	
	# 1. Safely Load Market Data (Price and History)
	if loaded_data.has("Market"):
		var m_data = loaded_data["Market"]
		for stock in Globals.all_stocks:
			if m_data.has(stock.ticker):
				var stock_save = m_data[stock.ticker]
				stock.current_price = stock_save.get("current_price", stock.current_price)
				
				# Safely handle the history array
				var saved_history = stock_save.get("price_history", [])
				if not saved_history.is_empty():
					stock.price_history.clear()
					for val in saved_history:
						stock.price_history.append(float(val))
	else:
		push_warning("SaveAndLoad: No 'Market' data found in this save slot. Skipping.")
		
	if loaded_data.has("Skills"):
		for key in loaded_data["Skills"]:
			if key in Globals:
				Globals.set(key, loaded_data["Skills"][key])
			else:
				push_warning("Unknown skill key: %s" % key)


	# Defer house and loan loading to apply_loaded_data
	return true

func apply_loaded_data() -> void:
	if loaded_data.is_empty():
		push_error("No loaded data to apply")
		return

	# Initialize global counters
	var owned_count = 0
	var net_worth = 0.0
	var expenses = 0.0

	# Build house registry
	var house_registry: Dictionary = {}
	var houses = get_tree().get_nodes_in_group("houses")
	for house in houses:
		if is_instance_valid(house) and house.id != "":
			house_registry[house.id] = house
			#print("Registered house: id=%s, name=%s, owned=%s" % [house.id, house.name, house.owned])
		else:
			push_warning("Invalid house or empty id: name=%s, id=%s" % [house.name, house.id])
	
	var market_node = get_node_or_null("/root/Root/UserInterface/Game/Market")
	if market_node and loaded_data.has("Market"):
		market_node.set_market_data(loaded_data["Market"])
	
	# Load houses
	var matched_houses = 0
	if loaded_data.has("Houses"):
		for saved_house in loaded_data["Houses"]:
			var house_id = saved_house.get("id", "")
			if house_id == "":
				push_warning("Skipping saved house with empty id")
				continue
			var house = house_registry.get(house_id)
			if house and is_instance_valid(house):
				house.plot = saved_house.get("plot", house.plot)
				house.rarity = saved_house.get("rarity", house.rarity)
				house.base_price = saved_house.get("base_price", house.base_price)
				house.current_price = saved_house.get("current_price", house.current_price)
				house.mortgage = saved_house.get("mortgage", house.mortgage)
				house.bought_price = saved_house.get("bought_price", house.bought_price)
				house.rent = saved_house.get("rent", house.rent)
				house.owner_type = saved_house.get("owner_type", house.owner_type)
				house.for_sale = saved_house.get("for_sale",house.for_sale)
				house.time_on_market = saved_house.get("time_on_market",house.time_on_market)
				house.lease_length = saved_house.get("lease_length", house.lease_length)
				house.apartment_condition = saved_house.get("apartment_condition", house.apartment_condition)
				house.mortgage_deducted = saved_house.get("mortgage_deducted", house.mortgage_deducted)
				house.tenant_offers = saved_house.get("tenant_offers", house.tenant_offers)
				house.is_listed = saved_house.get("is_listed", house.is_listed)
				house.edit_mode = saved_house.get("edit_mode", house.edit_mode)
				house.loan_price = saved_house.get("loan_price", house.loan_price)
				house.owned = saved_house.get("owned", house.owned)
				house.has_loan = saved_house.get("has_loan", house.has_loan)
				house.has_tenant = saved_house.get("has_tenant", house.has_tenant)
				house.just_bought = saved_house.get("just_bought", house.just_bought)
				house.upgrade_amount = saved_house.get("upgrade_amount", house.upgrade_amount)
				if saved_house.has("yard_objects"):
					# 1. Clear existing objects to prevent duplicates on double-load
					var storage = house.get_node_or_null("YardObjects")
					if storage:
						for child in storage.get_children():
							child.queue_free()
					else:
						# Create storage node if it doesn't exist
						storage = Node3D.new()
						storage.name = "YardObjects"
						house.add_child(storage)
						storage.owner = house

					# 2. Spawn saved objects
					for item_data in saved_house["yard_objects"]:
						var scene_path = item_data.get("scene_path", "")
						if scene_path != "" and ResourceLoader.exists(scene_path):
							var scene = load(scene_path)
							var obj = scene.instantiate()
							storage.add_child(obj)
							
							# Restore Transform (Position/Rotation)
							var t_str = item_data.get("transform", "")
							if t_str != "":
								obj.transform = str_to_var(t_str)
							
							# Set ownership for future saves and scene tree visibility
							obj.owner = house
							obj.set_meta("scene_path", scene_path)
				var collect_rent = house.get_node_or_null("Collect_Rent")
				if collect_rent and is_instance_valid(collect_rent):
						collect_rent.stored_cash = saved_house.get("stored_cash", 0)
						collect_rent.accumulated_months = saved_house.get("accumulated_months", 0)
						if collect_rent.stored_cash > 0:
							var dollar_sign = collect_rent.get_node_or_null("Dollar_sign")
							var label_3d = collect_rent.get_node_or_null("Label3D")
							if dollar_sign and label_3d:
								dollar_sign.visible = true
								label_3d.text = collect_rent.get_rent_status()
				if house.has_method("set_remaining_months"):
					house.set_remaining_months(saved_house.get("remaining_months", 0))
				if house.owned:
					owned_count += 1
					net_worth += house.bought_price
				matched_houses += 1
				#print("Loaded house: id=%s, name=%s, owned=%s, mortgage=%s, loan_price=%s, months=%s" % [house_id, house.name, house.owned, house.mortgage, house.loan_price, saved_house.get("remaining_months", "N/A")])
				if house.has_method("set_house_UI"):
					house.set_house_UI()
			else:
				push_warning("No matching house for saved id=%s, available ids=%s" % [house_id, house_registry.keys()])
	else:
		push_warning("No 'Houses' data in save file")

	# Load loans
	var loans_ui = get_node_or_null("/root/Root/UserInterface/Game/HUD/Phone/Loans")
	if loans_ui and is_instance_valid(loans_ui):
		loans_ui.active_loan_mods.clear()
		if loaded_data.has("Loans"):
			for loan_data in loaded_data["Loans"]:
				var house_id = loan_data.get("house_path", "")
				var house_ref = house_registry.get(house_id) if house_id != "" else null
				var loan_type_raw = loan_data.get("loan_type", LOAN_TYPE_MORTGAGE)
				var loan_type: int
				if loan_type_raw is String:
					loan_type = LOAN_TYPE_MORTGAGE if loan_type_raw == "Mortgage" else LOAN_TYPE_PERSONAL
				else:  # Handle int or float
					loan_type = int(loan_type_raw)  # Convert float to int
					if loan_type != LOAN_TYPE_MORTGAGE and loan_type != LOAN_TYPE_PERSONAL:
						loan_type = LOAN_TYPE_MORTGAGE  # Fallback
						push_warning("Invalid loan_type %s for loan_id %s, using default Mortgage" % [loan_type_raw, loan_data.get("loan_id", "")])
				var loan_mod
				if loan_type == LOAN_TYPE_PERSONAL:
					# Use add_loan_mod for personal loans
					if loans_ui.has_method("add_loan_mod"):
						loan_mod = loans_ui.add_loan_mod(
							loan_data.get("payment", 0.0),
							loan_data.get("interest", 0.0),
							loan_data.get("loan_balance", 0.0),
							loan_data.get("months", 12),
							loan_type,
							null
						)
					else:
						# Fallback: use add_mortgage_as_loan
						loan_mod = loans_ui.add_mortgage_as_loan(
							loan_data.get("payment", 0.0),
							loan_data.get("interest", 0.0),
							loan_data.get("months", 12),
							null
						)
				else:
					# Use add_mortgage_as_loan for mortgage loans
					loan_mod = loans_ui.add_mortgage_as_loan(
						loan_data.get("payment", 0.0),
						loan_data.get("interest", 0.0),
						loan_data.get("months", 360),
						house_ref
					)
				if loan_mod and is_instance_valid(loan_mod):
					loan_mod.loan_id = loan_data.get("loan_id", "loan_" + str(randi()))
					loan_mod.loan_balance = loan_data.get("loan_balance", 0.0)
					loan_mod.months = loan_data.get("months", 360)
					loan_mod.payment = loan_data.get("payment", 0.0)
					loan_mod.interest = loan_data.get("interest", 0.0)
					loan_mod.loan_type_str = "Mortgage" if loan_type == LOAN_TYPE_MORTGAGE else "Personal"
					loan_mod.autopay_enabled = loan_data.get("autopay_enabled", true)
					loan_mod.house_ref = house_ref
					loan_mod.update_ui()
					if house_ref and house_ref.has_method("set_remaining_months"):
						house_ref.set_remaining_months(loan_data.get("months", 360))
					if loan_mod.autopay_enabled:
						expenses += loan_mod.payment

				else:
					push_warning("Failed to create loan mod for id=%s, type=%s, house_id=%s" % [loan_data.get("loan_id", ""), loan_type, house_id])
		
	# Update global counters
	Globals.Propertys = owned_count
	Globals.net_worth = net_worth
	Globals.Expenses = expenses
	loaded_data = {} # Clear after loading

func create_new_profile(slot: int) -> bool:
	current_save_slot = slot
	var save_path = get_save_path(slot)
	if save_file_exists(slot):
		push_error("Save file already exists in slot %d" % slot)
		return false

	var data = {
		"Globals": {
			"save_name": Globals.save_name,
			"money": 5000,
			"brokerage_balance": 0.0,
			"portfolio": {},
			"Expenses": 1000,
			"Income": 0,
			"credit_score": 600,
			"Propertys": 0,
			"Savings_balance": 0,
			"wallpaper": "",
			"last_savings_paid": 0,
			"Player_health": 100,
			"Player_hunger": 100,
			"Player_comfort": 100,
			"business_name": "",
			"Business_worth": 30000,
			"max_job_time": 0,
			"job_pay": 0,
			"job_time": 0,
			"employees": 0,
			"car_level": 1,
			"year": 1,
			"month": 1,
			"renter_finder": false,
			"hasagent": false,
			"hascleaner": false,
			"mission_active": false,
			"mission_type": "",
			"mission_target": 0,
			"mission_deadline_year": 0,
			"mission_desc": "",
			"mission_completed": false,
		},
		"Skills": {
			"exp": 0,
			"level": 1,
			"skillpoints": 1,
			"exp_to_level": 100,
			"has_hireing_app": false,
			"has_info_app": false,
			"has_bank_app": false,
			"has_manager_app": false,
			"rent_houses": false,
			"rent_bost": 0.0,
			"unlock_business": false,
			"job_manager": false,
			"Job_bonus": false,
			"business_bonus": false,
			"job_manager_level": 0,
			"work_bonus": 0.0,
			"work_amount": 0,
			"rent_finder_upgrade": false,
			"credit_app": false
		},
		"Houses": [],
		"Loans": []
	}

	var save_dir = save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		var dir = DirAccess.open(save_dir.get_base_dir())
		if not dir:
			push_error("Failed to access parent directory for saves")
			return false
		var err = dir.make_dir_recursive(save_dir)
		if err != OK:
			push_error("Failed to create saves directory: %s" % err)
			return false

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create new save file: %s" % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func delete_save_file(slot: int) -> bool:
	var save_path = get_save_path(slot)
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open(save_path.get_base_dir())
		if dir:
			return dir.remove(save_path.get_file()) == OK
	return false

func get_all_save_slots() -> Array:
	var slots = []
	for slot in range(10):
		if save_file_exists(slot):
			slots.append(slot)
	return slots

func get_save_info(slot: int) -> Dictionary:
	if not save_file_exists(slot):
		return {}

	var save_path = get_save_path(slot)
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}

	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		return {}

	var data = json.get_data()
	if not data:
		return {}

	return {
		"slot": slot,
		"player_name": data["Globals"].get("business_name", "Business Owner"),
		"money": data["Globals"].get("money", 0),
		"level": data["Skills"].get("level", 1),
		"playtime": 0,
		"created": Time.get_datetime_string_from_system()
	}

func rename_save_slot(slot: int, new_name: String) -> bool:
	var save_path = get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		push_warning("SaveAndLoad: Cannot rename, save slot %d does not exist" % slot)
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("SaveAndLoad: Failed to open save file for reading: %s" % save_path)
		return false

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("SaveAndLoad: Failed to parse JSON in save file: %s" % json.get_error_message())
		file.close()
		return false
	file.close()

	var data = json.get_data()
	if not data or not data.has("Globals"):
		push_error("SaveAndLoad: Invalid save data or missing Globals section")
		return false

	data["Globals"]["save_name"] = new_name
	Globals.save_name = new_name  # Update in-memory value

	file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("SaveAndLoad: Failed to open save file for writing: %s" % save_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
