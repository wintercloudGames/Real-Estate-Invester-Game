extends Control

# Dictionary of food items with their properties: name, hunger increase, health boost, cost
var food_items = {
	"burger": {"hunger": 30, "health": 0, "cost": 200, "label": "Burger"},
	"fries": {"hunger": 10, "health": 0, "cost": 100, "label": "Fries"},
	"apple": {"hunger": 25, "health": 10, "cost": 150, "label": "Apple"},
	"pizza": {"hunger": 40, "health": 0, "cost": 250, "label": "Pizza"},
	"salad": {"hunger": 20, "health": 15, "cost": 120, "label": "Salad"},
	"sandwich": {"hunger": 35, "health": 5, "cost": 180, "label": "Sandwich"},
	"hotdog": {"hunger": 25, "health": 0, "cost": 120, "label": "Hotdog"},
	"ice_cream": {"hunger": 15, "health": -5, "cost": 800, "label": "Ice Cream"},
	"chips": {"hunger": 12, "health": -2, "cost": 100, "label": "Chips"},
	"steak": {"hunger": 50, "health": 10, "cost": 400, "label": "Steak"},
	"donut": {"hunger": 10, "health": -5, "cost": 100, "label": "Donut"},
	"chocolate": {"hunger": 8, "health": -3, "cost": 700, "label": "Chocolate"},
	"cucumber": {"hunger": 15, "health": 10, "cost": 500, "label": "Cucumber"},
	"carrot": {"hunger": 10, "health": 5, "cost": 300, "label": "Carrot"},
	"banana": {"hunger": 20, "health": 5, "cost": 200, "label": "Banana"},
	"grapes": {"hunger": 18, "health": 8, "cost": 300, "label": "Grapes"},
	"watermelon": {"hunger": 25, "health": 8, "cost": 122, "label": "Watermelon"},
	"fish": {"hunger": 35, "health": 20, "cost": 300, "label": "Fish"},
	"chicken": {"hunger": 40, "health": 15, "cost": 250, "label": "Chicken"},
	"pasta": {"hunger": 35, "health": 5, "cost": 150, "label": "Pasta"},
	"muffin": {"hunger": 12, "health": 2, "cost": 600, "label": "Muffin"},
	"bacon": {"hunger": 30, "health": -5, "cost": 1000, "label": "Bacon"},
	"cheese": {"hunger": 15, "health": 5, "cost": 800, "label": "Cheese"},
	"sushi": {"hunger": 30, "health": 15, "cost": 2000, "label": "Sushi"},
	"taco": {"hunger": 25, "health": 0, "cost": 1200, "label": "Taco"}
}

# Inside _ready function:
func _ready() -> void:
	var button_theme = load("res://themes/theme.tres")  # Adjust the path
	for food_name in food_items.keys():
		var button = Button.new()
		button.text = food_items[food_name]["label"] + "\nHunger: " + str(food_items[food_name]["hunger"]) + "\nHealth: " + str(food_items[food_name]["health"]) + "\nCost: " + str(food_items[food_name]["cost"])
		
		# Connect the button's pressed signal with the bind argument for food_name
		button.connect("pressed", Callable(self, "_on_food_button_pressed").bind(food_name))
		button.theme = button_theme
		$ScrollContainer/VBoxContainer.add_child(button)  # Add the button to your container

# General function for all food buttons
func _on_food_button_pressed(food_name: String) -> void:
	if food_items.has(food_name):
		var food = food_items[food_name]
		Globals.Player_hunger += food["hunger"]
		Globals.Player_health += food["health"]
		Globals.money_out(food["cost"])
		Globals.notify("Spent " + str(food["cost"]) + "$ on " + food["label"], Color.DARK_ORANGE)
