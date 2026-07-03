class_name MantleSerializer

const BLANK_MANTLE_PATH := "res://Mantles/blank.tres"
const MANTLES_DIR := "res://Mantles/"

static func is_blank(path: String) -> bool:
	return path == BLANK_MANTLE_PATH

static func list_mantle_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(MANTLES_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			paths.append(MANTLES_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return paths

static func quick_save(mantle: Mantle, path: String) -> int:
	var err := ResourceSaver.save(mantle, path)
	if err != OK:
		push_error("[MantleSerializer] Quick save failed: " + str(err))
	else:
		print("[MantleSerializer] Quick saved to: ", path)
	return err

static func save_as(mantle: Mantle, mantle_name: String) -> Dictionary:
	var path := MANTLES_DIR + mantle_name + ".tres"
	var exists := ResourceLoader.exists(path)
	if exists:
		return {"error": OK, "path": path, "needs_overwrite": true}
	var err := ResourceSaver.save(mantle, path)
	if err != OK:
		push_error("[MantleSerializer] Save failed: " + str(err))
	else:
		print("[MantleSerializer] Saved to: ", path)
	return {"error": err, "path": path, "needs_overwrite": false}

static func overwrite_save(mantle: Mantle, path: String) -> int:
	var err := ResourceSaver.save(mantle, path)
	if err != OK:
		push_error("[MantleSerializer] Overwrite save failed: " + str(err))
	else:
		print("[MantleSerializer] Overwrite saved to: ", path)
	return err
