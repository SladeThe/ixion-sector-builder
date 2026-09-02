extends Reference

static func to_yaml(buildings: Array) -> String:
	var lines = [
		"# IXION sector builder layout",
		"sector: 56x30",
		"buildings:",
	]
	for b in buildings:
		lines.append("  - name: \"" + b["name"] + "\"")
		lines.append("    pos: [" + str(int(b["pos"].x)) + ", " + str(int(b["pos"].y)) + "]")
		lines.append("    size: [" + str(int(b["size"].x)) + ", " + str(int(b["size"].y)) + "]")
		if b.has("resource") and b["resource"] != "":
			lines.append("    resource: \"" + b["resource"] + "\"")
	return PoolStringArray(lines).join("\n") + "\n"

static func from_yaml(text: String) -> Array:
	var result = []
	var current = null
	for raw_line in text.split("\n"):
		var line = raw_line.strip_edges()
		if line.begins_with("#") or line.empty():
			continue
		if line.begins_with("- name:"):
			current = {"name": "", "pos": Vector2.ZERO, "size": Vector2(4, 4), "resource": ""}
			var name_text = line.substr(7).strip_edges()
			if name_text.begins_with('"') and name_text.ends_with('"') and name_text.length() >= 2:
				name_text = name_text.substr(1, name_text.length() - 2)
			current["name"] = name_text
		elif current != null and line.begins_with("pos:"):
			current["pos"] = parse_pair(line.substr(4))
		elif current != null and line.begins_with("size:"):
			current["size"] = parse_pair(line.substr(5))
			result.append(current)
		elif current != null and line.begins_with("resource:"):
			var res_text = line.substr(9).strip_edges()
			if res_text.begins_with('"') and res_text.ends_with('"') and res_text.length() >= 2:
				res_text = res_text.substr(1, res_text.length() - 2)
			current["resource"] = res_text
	return result

static func parse_pair(text: String) -> Vector2:
	var clean = text.strip_edges()
	if clean.begins_with("["):
		clean = clean.substr(1)
	if clean.ends_with("]"):
		clean = clean.substr(0, clean.length() - 1)
	var parts = clean.split(",")
	if parts.size() != 2:
		return Vector2.ZERO
	return Vector2(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
