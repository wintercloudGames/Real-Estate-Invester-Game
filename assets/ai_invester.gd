extends Node

# AI starting capital
var money: float = Globals.ai_money
var houses_owned: Array = []
var profit_margin_target: float = 1.20 # Wants 20% profit

func _ready() -> void:
	# Connect to your global timer 
	Globals.month_ended.connect(_on_month_ended)

func _on_month_ended() -> void:
	manage_portfolio()
	search_for_deals()

func search_for_deals() -> void:
	var all_houses = get_tree().get_nodes_in_group("houses") 
	
	for house in all_houses:
		# Only check houses not owned by the player or the AI [cite: 1, 11]
		if not house.owned and house.for_sale:
			# DECISION: Is it a deal? (Looking for 10% below base price)
			if house.current_price < house.base_price * 0.90:
				if money >= house.current_price:
					buy_house(house)
					break # Limit to one purchase per month for balance

func buy_house(house) -> void:
	if Globals.ai_money >= house.current_price:
		Globals.ai_money -= house.current_price
		house.bought_price = house.current_price
		house.set_as_ai_owned() # Use the new helper function
		houses_owned.append(house)
		house.for_sale = false
		print("AI Investor bought ", house.name, " for $", house.current_price)
		
func manage_portfolio() -> void:
	for house in houses_owned:
		if not house.for_sale:
			# SELL DECISION: Target 20% profit
			var target_price = house.bought_price * profit_margin_target
			
			if house.current_price >= target_price:
				house.for_sale = true
				print("AI listed ", house.name, " at profit: $", house.current_price)
