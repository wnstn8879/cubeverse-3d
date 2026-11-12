extends SceneTree
## Invoked by run_tests.py twice to prove persistence across actual Godot processes.
const Cube = preload("res://scripts/core/cube_state.gd")
const Store = preload("res://scripts/core/save_store.gd")

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or not arguments[0] in ["write", "read"]:
		quit(2)
		return
	var store = Store.new("user://process_restart_test.json")
	var expected = Cube.new(10)
	expected.scramble(31, 98203)
	if arguments[0] == "write":
		var data: Dictionary = Store.defaults()
		data.cubes["10"] = expected.to_dict()
		data.settings.selected_cube = 10
		data.settings.sound = "arcade"
		data.settings.volume = 0.44
		if not store.save_data(data):
			quit(1)
			return
		print("PROCESS_RESTART_WRITE_OK")
	else:
		var data: Dictionary = store.load_data()
		var restored = Cube.new()
		if not data.cubes.has("10") or not restored.from_dict(data.cubes["10"]):
			quit(1)
			return
		if restored.state_key() != expected.state_key() or data.settings.sound != "arcade" or int(data.settings.selected_cube) != 10:
			quit(1)
			return
		print("PROCESS_RESTART_READ_OK")
	quit(0)
