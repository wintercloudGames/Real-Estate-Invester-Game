extends Resource
class_name MissionData

@export var id: String = "m_01"
@export var title: String = "The Emerging Tycoon"
@export_multiline var description: String = ""
@export var unlock_id_needed: String = ""

@export_group("Financial Goals")
@export var target_money: int = 50000          # Matches Globals.money
@export var target_savings: int = 10000        # Matches Globals.Savings_balance
@export var target_net_worth: int = 0          # Matches Globals.net_worth

@export_group("Property & Business Goals")
@export var target_houses: int = 5             # Matches Globals.Propertys
@export var target_rented_houses: int = 0      # Matches Globals.houses_with_tenants
@export var target_business_level: int = 0     # New: Check against business growth
@export var target_employees: int = 0          # Matches Globals.employees

@export_group("Progression Goals")
@export var target_player_level: int = 1       # Matches Globals.level
@export var target_car_level: int = 1          # Matches Globals.car_level
@export var target_credit_score: int = 0       # Matches Globals.credit_score

@export_group("Time Limit")
@export var time_limit_year: int = 3           # Must win by end of this year
