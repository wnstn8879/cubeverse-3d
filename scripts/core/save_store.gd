class_name SaveStore
extends RefCounted
## Local, offline persistence. Entitlements here are cached metadata only;
## an online store must verify purchases with its server before granting access.

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://cubeverse_save.json"

var path: String
var last_error := ""
var recovered_from_backup := false


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


static func defaults() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"settings": {
			"selected_cube": 3,
			"sound": "magnetic",
			"volume": 0.65,
			"haptics": true,
			"strength": 0.5,
		},
		"cubes": {},
		"records": [],
		"progress": {},
		"owned_skins": ["classic"],
		"entitlements": {},
	}


func load_data() -> Dictionary:
	last_error = ""
	recovered_from_backup = false
	var loaded := _read_valid(path)
	if not loaded.is_empty():
		return loaded
	loaded = _read_valid(path + ".bak")
	if not loaded.is_empty():
		recovered_from_backup = true
		last_error = "Recovered local save from backup."
		return loaded
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		last_error = "No valid local save was found; defaults were loaded."
	return defaults()


func save_data(data: Dictionary) -> bool:
	last_error = ""
	var normalized := _normalize(data)
	if normalized.is_empty():
		return _fail("Save data has an invalid schema or settings.")
	var directory := ProjectSettings.globalize_path(path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return _fail("Unable to create the local save directory.")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("Unable to open a temporary local save.")
	file.store_string(JSON.stringify(normalized))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_valid(temporary).is_empty():
		_remove_if_present(temporary)
		return _fail("Unable to write a complete local save.")
	# Keep the previous valid state. A corrupt primary never replaces a good backup.
	var backup_source := ""
	if not _read_valid(path).is_empty():
		backup_source = path
	elif _read_valid(path + ".bak").is_empty():
		backup_source = temporary
	if not backup_source.is_empty():
		var backup_temporary := path + ".bak.tmp"
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(backup_source),
			ProjectSettings.globalize_path(backup_temporary)
		)
		if copy_error != OK:
			_remove_if_present(temporary)
			return _fail("Unable to preserve the local save backup.")
		if not _replace(backup_temporary, path + ".bak"):
			_remove_if_present(temporary)
			return _fail("Unable to commit the local save backup.")
	if not _replace(temporary, path):
		return _fail("Unable to commit the local save.")
	return true


func _read_valid(candidate_path: String) -> Dictionary:
	if not FileAccess.file_exists(candidate_path):
		return {}
	var file := FileAccess.open(candidate_path, FileAccess.READ)
	if file == null:
		return {}
	var encoded := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(encoded) != OK or not parser.data is Dictionary:
		return {}
	return _normalize(parser.data)


static func _normalize(data: Dictionary) -> Dictionary:
	# Missing version is permitted only for a new, empty data object. Future
	# versions must be migrated explicitly instead of being overwritten.
	if not data.is_empty() and data.get("version", -1) != SCHEMA_VERSION:
		return {}
	var result := defaults()
	for key in data:
		result[key] = data[key]
	for key in ["settings", "cubes", "progress", "entitlements"]:
		if not result[key] is Dictionary:
			return {}
	if not result["records"] is Array or not result["owned_skins"] is Array:
		return {}
	var settings: Dictionary = defaults()["settings"]
	settings.merge(result["settings"], true)
	var selected: Variant = settings["selected_cube"]
	if not _is_number(selected) or float(selected) != floor(float(selected)):
		return {}
	if int(selected) < 2 or int(selected) > 10:
		return {}
	settings["selected_cube"] = int(selected)
	if not settings["sound"] is String or settings["sound"].is_empty():
		return {}
	if not settings["haptics"] is bool:
		return {}
	for key in ["volume", "strength"]:
		if not _is_number(settings[key]):
			return {}
		if float(settings[key]) < 0.0 or float(settings[key]) > 1.0:
			return {}
		settings[key] = float(settings[key])
	for skin in result["owned_skins"]:
		if not skin is String:
			return {}
	result["settings"] = settings
	result["version"] = SCHEMA_VERSION
	return result.duplicate(true)


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _replace(source: String, destination: String) -> bool:
	# rename is atomic within the same filesystem, and leaves the backup available
	# if the process terminates before the primary commit.
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source),
		ProjectSettings.globalize_path(destination)
	) == OK


static func _remove_if_present(candidate_path: String) -> void:
	if FileAccess.file_exists(candidate_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate_path))


func _fail(message: String) -> bool:
	last_error = message
	return false
