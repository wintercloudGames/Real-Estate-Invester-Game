extends Control

@onready var stock_list = $StockList  # Reference to a VBoxContainer or similar
@onready var portfolio_list = $"../PortfolioList"  # Reference to player portfolio UI
@onready var graph = $"../StockGraph"  # Placeholder for stock graph UI

func update_stock_display(stocks):
	for child in stock_list.get_children():
		child.queue_free()  # Clear existing UI elements
	
	for stock in stocks.keys():
		var label = Label.new()
		label.text = "%s: $%.2f (%+.2f)" % [stock, stocks[stock]["price"], stocks[stock]["change"]]
		if stocks[stock]["change"] > 0:
			label.add_theme_color_override("font_color", Color.GREEN)
		elif stocks[stock]["change"] < 0:
			label.add_theme_color_override("font_color", Color.RED)
		stock_list.add_child(label)

func update_portfolio_display(portfolio, balance):
	for child in portfolio_list.get_children():
		child.queue_free()
	
	var balance_label = Label.new()
	balance_label.text = "Balance: $%.2f" % balance
	portfolio_list.add_child(balance_label)
	
	for stock in portfolio.keys():
		var label = Label.new()
		label.text = "%s: %d shares" % [stock, portfolio[stock]]
		portfolio_list.add_child(label)

func update_stock_graph(stocks):
	# Placeholder function to visualize stock price history (Graph logic needs implementation)
	pass
