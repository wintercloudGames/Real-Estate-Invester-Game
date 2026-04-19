extends Resource
class_name JobData

@export var job_name: String = ""
@export var category: String = "Labor"
@export var required_player_level: int = 1
@export var required_skill_points: int = 0
@export var monthly_salary: float = 700.0
@export var Exp_gain_per_month: float = 10.0
@export var job_exp_gain_per_month: float = 0.1
@export_multiline var description: String = ""
