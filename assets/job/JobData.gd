extends Resource
class_name JobData

@export var job_name: String = ""
@export var monthly_salary: float = 700.0
@export var required_player_level: int = 1
@export var required_skill_points: int = 0
@export var Exp_gain_per_month: float = 10
@export_enum("Labor", "Services", "Trade", "Finance", "Management") var category: String = "Labor"
@export_multiline var description: String = ""
