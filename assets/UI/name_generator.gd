extends Node

var names = ["Arin", "Bex", "Ciro", "Dax", "Elva", "Fynn", "Gale", "Hale"]
var generated_name: String = ""

func generate_name():
	generated_name = names.pick_random()

func get_gen_name() -> String:
	return generated_name
