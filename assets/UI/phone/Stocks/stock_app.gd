extends Control

@onready var div_timer_label = $PortfolioSummary/DividendTimerLabel

# --- UI NODE REFERENCES ---
@onready var market_list = $MarketList/VBoxContainer
@onready var trading_view = $TradingView
@onready var graph = $TradingView/stock_graph
@onready var summary_label = $PortfolioSummary/Label

# TradingView Page Labels
@onready var price_label = $TradingView/Stock_price
@onready var name_label = $TradingView/StockName
@onready var ticker_label = $TradingView/StockTicker
@onready var yield_label = $TradingView/DividendYield
@onready var payout_label = $TradingView/DividendPayout

# Funding UI (Wallet -> Brokerage)
@onready var amount_input = $PortfolioSummary/AmountInput
@onready var fund_button = $PortfolioSummary/Fund_account
@onready var withdraw_button = $PortfolioSummary/Withdraw

# Trade Confirmation Popup (Buy/Sell Quantity)
@onready var trade_popup = $TradingView/TradePopup
@onready var trade_amount_input = $TradingView/TradePopup/AmountInput
@onready var trade_total_label = $TradingView/TradePopup/TotalCostLabel
@onready var trade_title = $TradingView/TradePopup/TitleLabel

var selected_stock: StockData = null
var is_buying: bool = true # Tracks if popup is in Buy or Sell mode

func _ready():
	# Initial UI State
	trading_view.visible = false
	trade_popup.visible = false
	$MarketList.visible = true
	$PortfolioSummary.visible = true
	
	# Connect to MarketManager for real-time price ticks
	if MarketManager.has_signal("market_updated"):
		MarketManager.market_updated.connect(_on_market_tick)
	
	# Connect Graph signals for "Hover" functionality
	if graph.has_signal("hovered_price"):
		graph.hovered_price.connect(_on_graph_hovered)
	graph.mouse_exited.connect(_on_graph_exited)
	
	# Connect Popup buttons
	$TradingView/TradePopup/ConfirmTradeButton.pressed.connect(_on_confirm_trade_pressed)
	$TradingView/TradePopup/CancelTradeButton.pressed.connect(func(): trade_popup.visible = false)
	trade_amount_input.text_changed.connect(_on_trade_amount_changed)
	
	setup_market_list()
	update_portfolio_summary()
	_update_dividend_display()

func _process(_delta):
	# Only update if the summary is visible to save performance
	if $PortfolioSummary.visible:
		var time_left = MarketManager.get_time_until_dividend()
		div_timer_label.text = "Next Dividend in: " + str(time_left) + "s"

func _on_dividends_received(amount: float):
	update_portfolio_summary()

func _update_dividend_display():
	if selected_stock:
		# 1. Percentage Yield (e.g., 2.5%)
		var yield_percent = selected_stock.dividend_yield * 100.0
		yield_label.text = "Dividend Yield: " + str(snapped(yield_percent, 0.01)) + "%"
		
		# 2. Actual Cash per share per 60s payout
		# Formula: (Price * Yield) / 12 months
		var amount_per_payout = (selected_stock.current_price * selected_stock.dividend_yield) / 12.0
		payout_label.text = "Pay Per Share: $" + str(snapped(amount_per_payout, 0.01))

# --- MARKET UPDATES ---

func _on_market_tick():
	setup_market_list()
	update_portfolio_summary()
	_update_dividend_display()
	
	if selected_stock:
		graph.history = selected_stock.price_history
		graph.queue_redraw()
		
		
		# Only update main label if mouse is NOT scrubbing the graph
		if not graph.get_global_rect().has_point(get_global_mouse_position()):
			_update_main_price_label()

func setup_market_list():
	for child in market_list.get_children():
		child.queue_free()
	
	for stock in Globals.all_stocks:
		var btn = Button.new()
		var shares_owned = Globals.portfolio.get(stock.ticker, 0)
		var btn_text = stock.ticker + " - $" + str(snapped(stock.current_price, 0.01))
		if shares_owned > 0:
			btn_text += " (" + str(shares_owned) + ")"
			
		btn.text = btn_text
		btn.pressed.connect(_on_stock_selected.bind(stock))
		market_list.add_child(btn)

func update_portfolio_summary():
	var total_stock_value = 0.0
	for ticker in Globals.portfolio.keys():
		var shares = Globals.portfolio[ticker]
		for s in Globals.all_stocks:
			if s.ticker == ticker:
				total_stock_value += (shares * s.current_price)
				break
	
	var account_total = total_stock_value + Globals.brokerage_balance
	var text = "BROKERAGE CASH: $" + Globals.add_comma_to_int(snapped(Globals.brokerage_balance, 0.01)) + "\n"
	text += "TOTAL ACCT VALUE: $" + Globals.add_comma_to_int(snapped(account_total, 0.01))
	summary_label.text = text

# --- NAVIGATION & UI HELPERS ---

func _on_stock_selected(stock: StockData):
	selected_stock = stock
	$MarketList.visible = false
	$PortfolioSummary.visible = false 
	trading_view.visible = true
	
	name_label.text = stock.stock_name
	ticker_label.text = stock.ticker
	_update_main_price_label()

	
	graph.history = stock.price_history
	graph.queue_redraw()

func _on_back_pressed():
	trading_view.visible = false
	$MarketList.visible = true
	$PortfolioSummary.visible = true
	selected_stock = null

func _update_main_price_label():
	if selected_stock:
		price_label.text = selected_stock.stock_name + "\n$" + str(snapped(selected_stock.current_price, 0.01))


func _on_fund_account_pressed():
	var amount = float(amount_input.text)
	if amount > 0 and Globals.money >= amount:
		Globals.money -= amount
		Globals.brokerage_balance += amount
		amount_input.text = "" 
		update_portfolio_summary()
		SaveAndLoad.save_game()


func _on_withdraw_pressed():
	var amount = float(amount_input.text)
	if amount > 0 and Globals.brokerage_balance >= amount:
		Globals.brokerage_balance -= amount
		Globals.money += amount
		amount_input.text = "" 
		update_portfolio_summary()
		SaveAndLoad.save_game()

# --- TRADING POPUP LOGIC ---
# --- TRADING POPUP LOGIC ---

func _on_buy_pressed():
	if not selected_stock: return
	is_buying = true
	
	# Show Buying Power (Brokerage Balance)
	var balance = str(snapped(Globals.brokerage_balance, 0.01))
	trade_title.text = "BUY " + selected_stock.ticker
	trade_amount_input.text = "1"
	
	# Update the label to show current funds
	trade_total_label.text = "Buying Power: $" + balance + "\nTotal: $0.00"
	
	_on_trade_amount_changed("1")
	trade_popup.visible = true

func _on_sell_pressed():
	if not selected_stock: return
	is_buying = false
	
	# Show Current Holdings (Shares Owned)
	var owned = Globals.portfolio.get(selected_stock.ticker, 0)
	trade_title.text = "SELL " + selected_stock.ticker
	trade_amount_input.text = "1"
	
	# Update the label to show current shares
	trade_total_label.text = "You Own: " + str(owned) + " shares\nTotal: $0.00"
	
	_on_trade_amount_changed("1")
	trade_popup.visible = true

func _on_trade_amount_changed(new_text: String):
	var amount = int(new_text)
	if selected_stock and amount > 0:
		var total = amount * selected_stock.current_price
		
		# Keep the top info visible while updating the bottom total
		if is_buying:
			var balance = str(snapped(Globals.brokerage_balance, 0.01))
			trade_total_label.text = "Buying Power: $" + balance + "\nTotal: $" + str(snapped(total, 0.01))
		else:
			var owned = Globals.portfolio.get(selected_stock.ticker, 0)
			trade_total_label.text = "You Own: " + str(owned) + " shares\nTotal: $" + str(snapped(total, 0.01))
	else:
		# Reset to default if input is empty or 0
		if is_buying:
			trade_total_label.text = "Buying Power: $" + str(snapped(Globals.brokerage_balance, 0.01)) + "\nTotal: $0.00"
		else:
			trade_total_label.text = "You Own: " + str(Globals.portfolio.get(selected_stock.ticker, 0)) + " shares\nTotal: $0.00"

func _on_confirm_trade_pressed():
	var count = int(trade_amount_input.text)
	if count <= 0 or not selected_stock: return
	
	var total_price = count * selected_stock.current_price
	var ticker = selected_stock.ticker
	
	if is_buying:
		if Globals.brokerage_balance >= total_price:
			Globals.brokerage_balance -= total_price
			Globals.portfolio[ticker] = Globals.portfolio.get(ticker, 0) + count
			_complete_trade()
	else:
		var owned = Globals.portfolio.get(ticker, 0)
		if owned >= count:
			Globals.brokerage_balance += total_price
			Globals.portfolio[ticker] = owned - count
			_complete_trade()

func _complete_trade():
	trade_popup.visible = false
	update_portfolio_summary()
	SaveAndLoad.save_game()

# --- GRAPH INTERACTION ---

func _on_graph_hovered(price: float):
	if selected_stock:
		price_label.text = selected_stock.stock_name + "\n$" + str(snapped(price, 0.01))

func _on_graph_exited():
	_update_main_price_label()
