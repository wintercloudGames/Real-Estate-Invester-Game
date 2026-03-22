extends Node

# --- Configuration ---
@export var ai_aggression: float = 0.05 # 5% chance per month to attempt a buy
@export var min_profit_margin: float = 0.15 # AI only buys if house is 15% below market value
@onready var market_node = $"../Market" # Path to your Market script

func _ready():
	pass

func _process(_delta):
	pass

var last_checked_month = -1

func attempt_ai_purchase():
	# Difficulty check: AI is smarter/faster on harder difficulties
	var current_chance = ai_aggression
	if market_node.difficulty == market_node.Difficulty.NIGHTMARE:
		current_chance = 0.15 

	if randf() > current_chance:
		return # AI decides to wait this month

	var houses = get_tree().get_nodes_in_group("houses")
	if houses.is_empty():
		return

	houses.shuffle()

	for house in houses:
		if not house.is_for_sale: continue
		
		var is_good_deal = house.price < (house.market_value * (1.0 - min_profit_margin))
		
		if market_node.is_crashing:
			is_good_deal = house.price < house.market_value 

		if is_good_deal:
			buy_house_as_ai(house)
			break # AI only buys one house per month maximum

func buy_house_as_ai(house):
	market_node.news_label.modulate = Color.GOLD
	house.is_for_sale = false
