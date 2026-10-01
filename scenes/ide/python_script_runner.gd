class_name PythonScriptRunner
extends RefCounted

## Pure GDScript in-engine Python runtime environment.
## Executes Python scripts without requiring any external Python installation on the user's PC.

static func _native_sqrt(x: float) -> float:
	return sqrt(x)

static func _native_floor(x: float) -> float:
	return floor(x)

static func _native_ceil(x: float) -> float:
	return ceil(x)

static func _native_abs(x: float) -> float:
	return abs(x)

static func _native_sin(x: float) -> float:
	return sin(x)

static func _native_cos(x: float) -> float:
	return cos(x)

static func _native_round(x: float, decimals: int = 0) -> float:
	var mult = pow(10, decimals)
	return round(x * mult) / mult

# â”€â”€â”€ PRNG (Python 3 MT19937 Compatibility) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class PyRandom extends RefCounted:
	var mt: Array[int] = []
	var index: int = 624

	func _init(seed_val: int = 5489) -> void:
		seed(seed_val)

	func seed(s: int) -> void:
		mt.resize(624)
		mt[0] = s & 0xFFFFFFFF
		for i in range(1, 624):
			var prev = mt[i - 1]
			var x = (1812433253 * (prev ^ (prev >> 30)) + i) & 0xFFFFFFFF
			mt[i] = x
		index = 624

	func extract_number() -> int:
		if index >= 624:
			twist()
		var y = mt[index]
		y ^= (y >> 11)
		y ^= ((y << 7) & 0x9D2C5680) & 0xFFFFFFFF
		y ^= ((y << 15) & 0xEFC60000) & 0xFFFFFFFF
		y ^= (y >> 18)
		index += 1
		return y & 0xFFFFFFFF

	func twist() -> void:
		for i in range(624):
			var y = ((mt[i] & 0x80000000) + (mt[(i + 1) % 624] & 0x7FFFFFFF)) & 0xFFFFFFFF
			mt[i] = (mt[(i + 397) % 624] ^ (y >> 1)) & 0xFFFFFFFF
			if (y & 1) != 0:
				mt[i] = (mt[i] ^ 0x9908B0DF) & 0xFFFFFFFF
		index = 0

	func genrand_res53() -> float:
		var a = extract_number() >> 5
		var b = extract_number() >> 6
		return (float(a) * 67108864.0 + float(b)) * (1.0 / 9007199254740992.0)

	func randint(a: int, b: int) -> int:
		var r = genrand_res53()
		return a + int(PythonScriptRunner._native_floor(r * float(b - a + 1)))

	func uniform(a: float, b: float) -> float:
		return a + (b - a) * genrand_res53()

	func choice(list: Array) -> Variant:
		if list.is_empty():
			return null
		var idx = int(PythonScriptRunner._native_floor(genrand_res53() * float(list.size())))
		return list[idx]

	func shuffle(arr: Array) -> void:
		for i in range(arr.size() - 1, 0, -1):
			var j = int(PythonScriptRunner._native_floor(genrand_res53() * float(i + 1)))
			var tmp = arr[i]
			arr[i] = arr[j]
			arr[j] = tmp

# â”€â”€â”€ MATH MODULE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class PyMath extends RefCounted:
	var pi: float = PI
	var e: float = 2.718281828459045

	func sqrt(x: float) -> float:
		return PythonScriptRunner._native_sqrt(x)

	func floor(x: float) -> float:
		return PythonScriptRunner._native_floor(x)

	func ceil(x: float) -> float:
		return PythonScriptRunner._native_ceil(x)

	func abs(x: float) -> float:
		return PythonScriptRunner._native_abs(x)

	func sin(x: float) -> float:
		return PythonScriptRunner._native_sin(x)

	func cos(x: float) -> float:
		return PythonScriptRunner._native_cos(x)

# â”€â”€â”€ COLLECTIONS MODULE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class PyCounter extends RefCounted:
	var counts: Dictionary = {}

	func _init(iterable: Variant = null) -> void:
		counts = {}
		if iterable is Array:
			for item in iterable:
				var k = str(item)
				counts[k] = counts.get(k, 0) + 1
		elif iterable is Dictionary:
			counts = iterable.duplicate()

	func to_dict() -> Dictionary:
		return counts

	func _to_string() -> String:
		return str(counts)

class PyDeque extends RefCounted:
	var items: Array = []
	var maxlen: int = -1

	func _init(init_items: Variant = null, mlen: int = -1) -> void:
		items = []
		maxlen = mlen
		if init_items is Array:
			for x in init_items:
				append(x)

	func append(x: Variant) -> void:
		if maxlen > 0 and items.size() >= maxlen:
			items.pop_front()
		items.append(x)

	func pop() -> Variant:
		return items.pop_back() if not items.is_empty() else null

	func popleft() -> Variant:
		return items.pop_front() if not items.is_empty() else null

	func to_list() -> Array:
		return items.duplicate()

	func _to_string() -> String:
		return str(items)

# â”€â”€â”€ PYTHON INSTANCE (CLASSES & DATACLASSES) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class PyInstance extends RefCounted:
	var class_name_str: String
	var attrs: Dictionary = {}
	var methods: Dictionary = {}
	var runner_ref = null

	func _init(c_name: String, runner = null) -> void:
		class_name_str = c_name
		runner_ref = runner

	func get_attr(prop: String) -> Variant:
		if attrs.has(prop):
			return attrs[prop]
		return null

	func set_attr(prop: String, val: Variant) -> void:
		attrs[prop] = val

	func _get(prop: StringName) -> Variant:
		return attrs.get(str(prop), null)

	func _set(prop: StringName, val: Variant) -> bool:
		attrs[str(prop)] = val
		return true

	func call_method(method_name: String, args: Array) -> Variant:
		if methods.has(method_name) and runner_ref:
			return runner_ref.call_instance_method(self, methods[method_name], args)
		return null

	func _to_string() -> String:
		if methods.has("status") and runner_ref:
			return str(call_method("status", []))
		if methods.has("__str__") and runner_ref:
			return str(call_method("__str__", []))
		return "<%s object>" % class_name_str

# â”€â”€â”€ RUNNER STATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

var global_scope: Dictionary = {}
var classes: Dictionary = {}
var functions: Dictionary = {}
var stdout_buffer: PackedStringArray = []
var runtime_error: String = ""

func _init() -> void:
	_init_builtins()

func _init_builtins() -> void:
	global_scope = {
		"math": PyMath.new(),
		"random": PyRandom.new(0),
		"Counter": Callable(self, "_make_counter"),
		"deque": Callable(self, "_make_deque"),
		"True": true,
		"False": false,
		"None": null,
		"__name__": "__main__",
		"sys": RefCounted.new(),
		"dataclass": Callable(self, "_dummy_callable"),
		"field": Callable(self, "_dummy_field"),
	}

func _dummy_callable(x = null, _y = null, _z = null) -> Variant:
	return x

func _dummy_field(_default_factory = null) -> Variant:
	return []

func _make_counter(iterable = null) -> PyCounter:
	return PyCounter.new(iterable)

func _make_deque(iterable = null, maxlen = -1) -> PyDeque:
	return PyDeque.new(iterable, maxlen)

# â”€â”€â”€ PUBLIC EXECUTE API â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

static func run_code(code: String) -> Dictionary:
	var runner = PythonScriptRunner.new()
	return runner._execute_script(code)

func _execute_script(code: String) -> Dictionary:
	stdout_buffer.clear()
	runtime_error = ""
	
	# Parse top-level structures: classes, functions, and statements
	var lines = code.split("\n")
	var statements = _group_statements(lines)
	
	_first_pass_classes_and_functions(statements)
	
	for stmt in statements:
		if not runtime_error.is_empty():
			break
		if stmt["type"] in ["class", "def", "import", "from"]:
			continue
		_execute_statement(stmt, global_scope)
		
	var out_text = "\n".join(stdout_buffer)
	if not out_text.is_empty() and not out_text.ends_with("\n"):
		out_text += "\n"
		
	return {
		"output": out_text,
		"error": runtime_error
	}

# â”€â”€â”€ PARSING â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

static func _strip_inline_comment(line: String) -> String:
	var in_q = false
	var q_c = ""
	for i in range(line.length()):
		var ch = line[i]
		if not in_q:
			if ch in ['"', "'"]:
				in_q = true
				q_c = ch
			elif ch == '#':
				return line.substr(0, i).strip_edges()
		else:
			if ch == q_c and (i == 0 or line[i - 1] != '\\'):
				in_q = false
	return line.strip_edges()

func _group_statements(lines: PackedStringArray) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var i = 0
	var n = lines.size()
	
	while i < n:
		var raw_line = lines[i]
		var trimmed = raw_line.strip_edges()
		
		if trimmed.is_empty() or trimmed.begins_with("#"):
			i += 1
			continue
			
		var indent = raw_line.length() - raw_line.strip_edges(true, false).length()
		
		# Class definition (supports @dataclass decorator above)
		if trimmed == "@dataclass" and i + 1 < n and lines[i + 1].strip_edges().begins_with("class "):
			i += 1
			raw_line = lines[i]
			trimmed = raw_line.strip_edges()
			var block_info = _gather_block(lines, i)
			result.append({
				"type": "class",
				"name": _extract_name_after(trimmed, "class "),
				"header": trimmed,
				"body": block_info["body_lines"],
				"indent": indent,
				"is_dataclass": true
			})
			i = block_info["next_index"]
			continue
		elif trimmed.begins_with("class "):
			var block_info = _gather_block(lines, i)
			result.append({
				"type": "class",
				"name": _extract_name_after(trimmed, "class "),
				"header": trimmed,
				"body": block_info["body_lines"],
				"indent": indent,
				"is_dataclass": false
			})
			i = block_info["next_index"]
			continue
		elif trimmed.begins_with("def "):
			var paren_open = trimmed.find("(")
			var colon_pos = -1
			if paren_open != -1:
				var p_depth = 0
				for c_i in range(paren_open, trimmed.length()):
					if trimmed[c_i] == '(': p_depth += 1
					elif trimmed[c_i] == ')':
						p_depth -= 1
						if p_depth == 0:
							colon_pos = trimmed.find(":", c_i)
							break
			else:
				colon_pos = trimmed.find(":")
				
			var inline_body = ""
			if colon_pos != -1:
				inline_body = trimmed.substr(colon_pos + 1).strip_edges()
				
			if not inline_body.is_empty():
				result.append({
					"type": "def",
					"name": _extract_name_after(trimmed, "def "),
					"header": trimmed.substr(0, colon_pos + 1),
					"body": PackedStringArray([inline_body]),
					"indent": indent
				})
				i += 1
				continue
			else:
				var block_info = _gather_block(lines, i)
				result.append({
					"type": "def",
					"name": _extract_name_after(trimmed, "def "),
					"header": trimmed,
					"body": block_info["body_lines"],
					"indent": indent
				})
				i = block_info["next_index"]
				continue
		elif trimmed.begins_with("try:"):
			var try_info = _gather_try_except(lines, i)
			result.append(try_info["stmt"])
			i = try_info["next_index"]
			continue
		elif trimmed.begins_with("for "):
			var block_info = _gather_block(lines, i)
			result.append({
				"type": "for",
				"header": trimmed,
				"body": block_info["body_lines"],
				"indent": indent
			})
			i = block_info["next_index"]
			continue
		elif trimmed.begins_with("while "):
			var block_info = _gather_block(lines, i)
			result.append({
				"type": "while",
				"header": trimmed,
				"body": block_info["body_lines"],
				"indent": indent
			})
			i = block_info["next_index"]
			continue
		elif trimmed.begins_with("if "):
			var if_info = _gather_if_branches(lines, i)
			result.append(if_info["stmt"])
			i = if_info["next_index"]
			continue
		elif trimmed.begins_with("import ") or trimmed.begins_with("from "):
			result.append({
				"type": "import",
				"text": trimmed,
				"indent": indent
			})
			i += 1
			continue
		else:
			# Multi-line statement continuation when brackets are left unclosed
			var paren_count = _count_unclosed_delimiters(trimmed)
			while paren_count > 0 and i + 1 < n:
				i += 1
				var next_raw = lines[i]
				var next_trimmed = next_raw.strip_edges()
				if next_trimmed.begins_with("#"):
					continue
				trimmed += " " + next_trimmed
				paren_count += _count_unclosed_delimiters(next_trimmed)

			trimmed = _strip_inline_comment(trimmed)
			if trimmed.begins_with("raise "):
				result.append({
					"type": "raise",
					"text": trimmed,
					"indent": indent
				})
			elif trimmed.begins_with("return"):
				result.append({
					"type": "return",
					"text": trimmed,
					"indent": indent
				})
			else:
				result.append({
					"type": "stmt",
					"text": trimmed,
					"indent": indent
				})
			i += 1
			
	return result

func _gather_block(lines: PackedStringArray, start_idx: int) -> Dictionary:
	var base_indent = lines[start_idx].length() - lines[start_idx].strip_edges(true, false).length()
	var body: PackedStringArray = []
	var j = start_idx + 1
	var n = lines.size()
	
	while j < n:
		var line = lines[j]
		var trimmed = line.strip_edges()
		if trimmed.is_empty():
			body.append("")
			j += 1
			continue
		if trimmed.begins_with("#"):
			body.append(line)
			j += 1
			continue
		var cur_indent = line.length() - line.strip_edges(true, false).length()
		if cur_indent > base_indent:
			body.append(line)
			j += 1
		else:
			break
			
	return {"body_lines": body, "next_index": j}

func _gather_try_except(lines: PackedStringArray, start_idx: int) -> Dictionary:
	var base_indent = lines[start_idx].length() - lines[start_idx].strip_edges(true, false).length()
	var try_block = _gather_block(lines, start_idx)
	var j = try_block["next_index"]
	var except_header = ""
	var except_body: PackedStringArray = []
	
	if j < lines.size() and lines[j].strip_edges().begins_with("except"):
		except_header = lines[j].strip_edges()
		var eb = _gather_block(lines, j)
		except_body = eb["body_lines"]
		j = eb["next_index"]
		
	return {
		"stmt": {
			"type": "try",
			"try_body": try_block["body_lines"],
			"except_header": except_header,
			"except_body": except_body,
			"indent": base_indent
		},
		"next_index": j
	}

func _count_unclosed_delimiters(s: String) -> int:
	var count = 0
	var in_q = false
	var q_c = ""
	for i in range(s.length()):
		var ch = s[i]
		if not in_q:
			if ch == '#':
				break
			elif ch == '"' or ch == "'":
				in_q = true
				q_c = ch
			elif ch in ['(', '[', '{']:
				count += 1
			elif ch in [')', ']', '}']:
				count -= 1
		else:
			if ch == q_c and (i == 0 or s[i - 1] != '\\'):
				in_q = false
	return count

func _gather_if_branches(lines: PackedStringArray, start_idx: int) -> Dictionary:
	var branches: Array[Dictionary] = []
	var cur_idx = start_idx
	var base_indent = lines[start_idx].length() - lines[start_idx].strip_edges(true, false).length()
	
	while cur_idx < lines.size():
		var line = lines[cur_idx]
		var trimmed = line.strip_edges()
		var cur_indent = line.length() - line.strip_edges(true, false).length()
		
		if cur_indent != base_indent:
			break
			
		if trimmed.begins_with("if ") or trimmed.begins_with("elif "):
			var colon_pos = -1
			var p_depth = 0
			var in_q = false
			var q_c = ""
			for c_i in range(trimmed.length()):
				var c_ch = trimmed[c_i]
				if not in_q:
					if c_ch == '"' or c_ch == "'":
						in_q = true
						q_c = c_ch
					elif c_ch in ["(", "[", "{"]:
						p_depth += 1
					elif c_ch in [")", "]", "}"]:
						p_depth = max(0, p_depth - 1)
					elif c_ch == ':' and p_depth == 0:
						colon_pos = c_i
						break
				else:
					if c_ch == q_c and (c_i == 0 or trimmed[c_i - 1] != '\\'):
						in_q = false
			
			var space_pos = trimmed.find(" ")
			var cond = ""
			var inline_body = ""
			if colon_pos != -1:
				cond = trimmed.substr(space_pos + 1, colon_pos - (space_pos + 1)).strip_edges()
				inline_body = trimmed.substr(colon_pos + 1).strip_edges()
			else:
				cond = trimmed.substr(space_pos + 1).trim_suffix(":").strip_edges()
				
			if not inline_body.is_empty():
				branches.append({"kind": "if" if trimmed.begins_with("if") else "elif", "cond": cond, "body": PackedStringArray([inline_body])})
				cur_idx += 1
			else:
				var b = _gather_block(lines, cur_idx)
				branches.append({"kind": "if" if trimmed.begins_with("if") else "elif", "cond": cond, "body": b["body_lines"]})
				cur_idx = b["next_index"]
		elif trimmed.begins_with("else:") or trimmed == "else" or trimmed.begins_with("else "):
			var colon_pos = trimmed.find(":")
			var inline_body = ""
			if colon_pos != -1:
				inline_body = trimmed.substr(colon_pos + 1).strip_edges()
			if not inline_body.is_empty():
				branches.append({"kind": "else", "cond": "True", "body": PackedStringArray([inline_body])})
				cur_idx += 1
			else:
				var b = _gather_block(lines, cur_idx)
				branches.append({"kind": "else", "cond": "True", "body": b["body_lines"]})
				cur_idx = b["next_index"]
			break
		else:
			break
			
	return {
		"stmt": {
			"type": "if_chain",
			"branches": branches,
			"indent": base_indent
		},
		"next_index": cur_idx
	}

func _extract_name_after(header: String, prefix: String) -> String:
	var s = header.substr(header.find(prefix) + prefix.length()).strip_edges()
	var paren = s.find("(")
	var colon = s.find(":")
	var cut = s.length()
	if paren != -1 and paren < cut: cut = paren
	if colon != -1 and colon < cut: cut = colon
	return s.substr(0, cut).strip_edges()

# â”€â”€â”€ CLASS & FUNCTION REGISTRATION â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _first_pass_classes_and_functions(statements: Array[Dictionary]) -> void:
	for stmt in statements:
		if stmt["type"] == "class":
			_register_class(stmt)
		elif stmt["type"] == "def":
			_register_function(stmt)

func _register_class(stmt: Dictionary) -> void:
	var c_name = stmt["name"]
	var body_lines: PackedStringArray = stmt["body"]
	var fields: Dictionary = {}
	var methods: Dictionary = {}
	
	# Base class inheritance e.g. class Robot(Entity):
	var header = stmt.get("header", "")
	var p_open = header.find("(")
	var p_close = header.find(")")
	if p_open != -1 and p_close > p_open:
		var base_name = header.substr(p_open + 1, p_close - p_open - 1).strip_edges()
		if classes.has(base_name):
			fields = classes[base_name]["fields"].duplicate(true)
			methods = classes[base_name]["methods"].duplicate(true)
	
	# Parse fields and methods inside class
	var i = 0
	var n = body_lines.size()
	while i < n:
		var line = body_lines[i]
		var trimmed = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			i += 1
			continue
		if trimmed.begins_with("def "):
			var paren_open = trimmed.find("(")
			var colon_pos = -1
			if paren_open != -1:
				var p_depth = 0
				for c_i in range(paren_open, trimmed.length()):
					if trimmed[c_i] == '(': p_depth += 1
					elif trimmed[c_i] == ')':
						p_depth -= 1
						if p_depth == 0:
							colon_pos = trimmed.find(":", c_i)
							break
			else:
				colon_pos = trimmed.find(":")
				
			var inline_body = ""
			if colon_pos != -1:
				inline_body = trimmed.substr(colon_pos + 1).strip_edges()
				
			var m_name = _extract_name_after(trimmed, "def ")
			if not inline_body.is_empty():
				methods[m_name] = {
					"name": m_name,
					"header": trimmed.substr(0, colon_pos + 1),
					"body": PackedStringArray([inline_body])
				}
				i += 1
				continue
			else:
				var b = _gather_block(body_lines, i)
				methods[m_name] = {
					"name": m_name,
					"header": trimmed,
					"body": b["body_lines"]
				}
				i = b["next_index"]
				continue
		elif trimmed.contains(":"):
			# Field definition: name: type = default
			var parts = trimmed.split(":")
			var f_name = parts[0].strip_edges()
			var default_val: Variant = null
			if parts.size() > 1 and parts[1].contains("="):
				var r_expr = parts[1].substr(parts[1].find("=") + 1).strip_edges()
				if r_expr.begins_with("field(default_factory=list)"):
					default_val = []
				elif r_expr.begins_with("field("):
					default_val = null
				else:
					default_val = _eval_expr(r_expr, global_scope)
			fields[f_name] = default_val
		i += 1
		
	var class_def = {
		"name": c_name,
		"fields": fields,
		"methods": methods,
		"is_dataclass": stmt.get("is_dataclass", false)
	}
	classes[c_name] = class_def
	global_scope[c_name] = Callable(self, "_instantiate_class_wrapper").bind(class_def)

func _instantiate_class_wrapper(class_def: Dictionary) -> PyInstance:
	return _instantiate_class([], {}, class_def)

func _instantiate_class(args: Array, kwargs: Dictionary, class_def: Dictionary) -> PyInstance:
	var inst = PyInstance.new(class_def["name"], self)
	inst.methods = class_def["methods"]
	
	if class_def.get("is_dataclass", false):
		# Default fields
		for k in class_def["fields"].keys():
			var def_val = class_def["fields"][k]
			if def_val is Array:
				inst.attrs[k] = def_val.duplicate()
			elif def_val is Dictionary:
				inst.attrs[k] = def_val.duplicate()
			else:
				inst.attrs[k] = def_val
				
		# Positional args mapped to fields
		var field_keys = class_def["fields"].keys()
		for idx in range(min(args.size(), field_keys.size())):
			inst.attrs[field_keys[idx]] = args[idx]
			
		# Kwargs override
		for k in kwargs.keys():
			inst.attrs[k] = kwargs[k]
			
		if inst.methods.has("__post_init__"):
			call_instance_method(inst, inst.methods["__post_init__"], [])
	else:
		if inst.methods.has("__init__"):
			call_instance_method(inst, inst.methods["__init__"], args, kwargs)
		else:
			for k in kwargs.keys():
				inst.attrs[k] = kwargs[k]
			
	return inst

func _register_function(stmt: Dictionary) -> void:
	var f_name = stmt["name"]
	var f_def = {
		"name": f_name,
		"header": stmt["header"],
		"body": stmt["body"]
	}
	functions[f_name] = f_def
	global_scope[f_name] = Callable(self, "_call_function_wrapper").bind(f_def)

func _call_function_wrapper(args: Array, kwargs: Dictionary, f_def: Dictionary) -> Variant:
	return _call_user_func(f_def, args, null, kwargs)

# â”€â”€â”€ STATEMENT EXECUTION â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _execute_statement(stmt: Dictionary, scope: Dictionary) -> Variant:
	if not runtime_error.is_empty():
		return null
		
	var s_type = stmt.get("type", "")
	match s_type:
		"stmt":
			_exec_expr_or_assign(stmt["text"], scope)
		"for":
			_exec_for(stmt, scope)
		"while":
			var header = stmt["header"].substr(6).trim_suffix(":").strip_edges()
			var sub_stmts = _group_statements(stmt["body"])
			while _is_truthy(_eval_expr(header, scope)):
				for sub in sub_stmts:
					var res = _execute_statement(sub, scope)
					if sub["type"] == "return" or res != null:
						return res
					if not runtime_error.is_empty():
						return null
		"if_chain":
			_exec_if_chain(stmt, scope)
		"try":
			_exec_try(stmt, scope)
		"raise":
			var msg_expr = stmt["text"].trim_prefix("raise ").strip_edges()
			if msg_expr.begins_with("RuntimeError(") and msg_expr.ends_with(")"):
				msg_expr = msg_expr.substr(13, msg_expr.length() - 14)
			var evaluated_msg = _eval_expr(msg_expr, scope)
			runtime_error = "RuntimeError: " + str(evaluated_msg)
		"return":
			var ret_expr = stmt["text"].trim_prefix("return").strip_edges()
			return _eval_expr(ret_expr, scope) if not ret_expr.is_empty() else null
			
	return null

func _exec_for(stmt: Dictionary, scope: Dictionary) -> Variant:
	var header = stmt["header"].substr(4).trim_suffix(":").strip_edges()
	var in_pos = header.find(" in ")
	if in_pos == -1:
		return null
		
	var var_part = header.substr(0, in_pos).strip_edges()
	var iter_part = header.substr(in_pos + 4).strip_edges()
	var iterable = _eval_expr(iter_part, scope)
	if iterable is PyDeque:
		iterable = iterable.items
	elif iterable is PyCounter:
		iterable = iterable.counts.keys()
	elif iterable is Dictionary:
		iterable = iterable.keys()
	elif iterable is String:
		var chars: Array = []
		for ch in iterable: chars.append(ch)
		iterable = chars
	
	var sub_stmts = _group_statements(stmt["body"])
	
	if iterable is Array:
		for item in iterable:
			_bind_loop_var(var_part, item, scope)
			for sub_stmt in sub_stmts:
				var res = _execute_statement(sub_stmt, scope)
				if sub_stmt["type"] == "return" or res != null:
					return res
				if not runtime_error.is_empty():
					return null
					
	return null

func _bind_loop_var(var_part: String, item: Variant, scope: Dictionary) -> void:
	_assign_target(var_part, item, scope)

func _is_truthy(v: Variant) -> bool:
	if v == null: return false
	if v is bool: return v
	if v is int or v is float: return v != 0
	if v is String: return not v.is_empty()
	if v is Array: return not v.is_empty()
	if v is Dictionary: return not v.is_empty()
	if v is PyDeque: return not v.items.is_empty()
	if v is PyCounter: return not v.counts.is_empty()
	return true

func _exec_if_chain(stmt: Dictionary, scope: Dictionary) -> Variant:
	for branch in stmt["branches"]:
		var cond_val = _is_truthy(_eval_expr(branch["cond"], scope))
		if cond_val:
			var sub_stmts = _group_statements(branch["body"])
			for sub in sub_stmts:
				var res = _execute_statement(sub, scope)
				if sub["type"] == "return" or res != null:
					return res
				if not runtime_error.is_empty():
					return null
			break
	return null

func _exec_try(stmt: Dictionary, scope: Dictionary) -> Variant:
	var _prev_err = runtime_error
	var try_stmts = _group_statements(stmt["try_body"])
	
	for sub in try_stmts:
		var res = _execute_statement(sub, scope)
		if not runtime_error.is_empty():
			break
		if sub["type"] == "return" or res != null:
			return res
			
	if not runtime_error.is_empty():
		var err_val = runtime_error
		runtime_error = "" # Caught!
		
		# Bind exception variable if provided (e.g. `except RuntimeError as e:`)
		var ex_hdr = stmt["except_header"]
		if ex_hdr.contains(" as "):
			var ex_var = ex_hdr.substr(ex_hdr.find(" as ") + 4).trim_suffix(":").strip_edges()
			scope[ex_var] = err_val.replace("RuntimeError: ", "")
			
		var except_stmts = _group_statements(stmt["except_body"])
		for sub in except_stmts:
			var res = _execute_statement(sub, scope)
			if sub["type"] == "return" or res != null:
				return res
			if not runtime_error.is_empty():
				return null
				
	return null

func _exec_expr_or_assign(line: String, scope: Dictionary) -> void:
	line = _strip_inline_comment(line)
	if line.is_empty() or line.begins_with("#"):
		return
		
	# Augmented assignment: +=, -=, *=, /=, //=, %=, **=, &=, |=, ^=, <<=, >>=
	# Use top-level split to avoid matching inside strings or comparisons
	for aug_op in ["**=", "//=", "<<=", ">>=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^="]:
		var aug_split = _split_top_level_op(line, [aug_op])
		if aug_split["found"]:
			var target = aug_split["left"]
			var rhs_expr = aug_split["right"]
			var delta = _eval_expr(rhs_expr, scope)
			var cur_val = _eval_expr(target, scope)
			if cur_val == null: cur_val = 0
			var new_val = cur_val
			match aug_op:
				"+=":
					if cur_val is String or delta is String:
						new_val = str(cur_val) + str(delta)
					elif cur_val is Array and delta is Array:
						new_val = cur_val.duplicate()
						new_val.append_array(delta)
					else:
						new_val = cur_val + delta
				"-=": new_val = cur_val - delta
				"*=": new_val = cur_val * delta
				"/=": new_val = float(cur_val) / float(delta) if float(delta) != 0.0 else 0.0
				"//=": new_val = int(float(cur_val) / float(delta)) if float(delta) != 0.0 else 0
				"%=": new_val = int(cur_val) % int(delta) if int(delta) != 0 else 0
				"**=": new_val = pow(float(cur_val), float(delta))
				"&=": new_val = int(cur_val) & int(delta)
				"|=": new_val = int(cur_val) | int(delta)
				"^=": new_val = int(cur_val) ^ int(delta)
				"<<=": new_val = int(cur_val) << int(delta)
				">>=": new_val = int(cur_val) >> int(delta)
			_assign_target(target, new_val, scope)
			return
			
	# Normal assignment: = (but not ==, !=, <=, >=)
	var eq_split = _split_top_level_op(line, ["="])
	if eq_split["found"] and not (line.contains("==") and eq_split["left"].is_empty()):
		var target = eq_split["left"]
		# Ignore type annotation if present (e.g. name: str = val)
		if target.contains(":") and not target.contains("["):
			target = target.split(":")[0].strip_edges()
		var rhs_expr = eq_split["right"]
		var val = _eval_expr(rhs_expr, scope)
		_assign_target(target, val, scope)
		return
		
	# Plain expression or function call
	_eval_expr(line, scope)

func _assign_target(target: String, val: Variant, scope: Dictionary) -> void:
	target = target.strip_edges()
	# Strip outer parens/brackets only if it's a tuple/list
	if (target.begins_with("(") and target.ends_with(")")) or (target.begins_with("[") and target.ends_with("]")):
		var inner_check = target.substr(1, target.length() - 2).strip_edges()
		# Only strip if it contains commas (it's actually a tuple, not a single grouped expr)
		if inner_check.contains(","):
			target = inner_check
		else:
			target = inner_check
	var parts = _split_args(target)
	if parts.size() > 1:
		if val is Array:
			for idx in range(min(parts.size(), val.size())):
				_assign_target(parts[idx].strip_edges(), val[idx], scope)
		return
	if target.contains(".") and not (target.begins_with("'") or target.begins_with('"')):
		# Check if it's obj.attr[idx] = val
		var open_b = target.find("[")
		var dot_idx_in_attr: int
		if open_b != -1:
			# Could be obj.attr[idx]
			var before_bracket = target.substr(0, open_b)
			dot_idx_in_attr = before_bracket.rfind(".")
			if dot_idx_in_attr != -1:
				var obj_name = before_bracket.substr(0, dot_idx_in_attr).strip_edges()
				var attr_name = before_bracket.substr(dot_idx_in_attr + 1).strip_edges()
				var index_expr = target.substr(open_b + 1, target.length() - open_b - 2).strip_edges()
				var obj = _eval_expr(obj_name, scope)
				if obj is PyInstance:
					var container = obj.get_attr(attr_name)
					var key_or_idx = _eval_expr(index_expr, scope)
					if container is Array and (key_or_idx is int or str(key_or_idx).is_valid_int()):
						container[int(key_or_idx)] = val
					elif container is Dictionary:
						container[key_or_idx] = val
				return
		# Attribute assignment: obj.attr = val
		var dot_idx = target.rfind(".")
		var obj_name2 = target.substr(0, dot_idx).strip_edges()
		var attr_name2 = target.substr(dot_idx + 1).strip_edges()
		var obj2 = _eval_expr(obj_name2, scope)
		if obj2 is PyInstance:
			obj2.set_attr(attr_name2, val)
	elif target.contains("[") and target.ends_with("]"):
		# Subscript assignment: arr[idx] = val or dict[key] = val
		var open_bracket = target.find("[")
		var container_name = target.substr(0, open_bracket).strip_edges()
		var index_expr = target.substr(open_bracket + 1, target.length() - open_bracket - 2).strip_edges()
		var container = _eval_expr(container_name, scope)
		var key_or_idx = _eval_expr(index_expr, scope)
		if container is Dictionary:
			container[key_or_idx] = val
		elif container is Array and (key_or_idx is int or str(key_or_idx).is_valid_int()):
			var idx = int(key_or_idx)
			if idx >= 0 and idx < container.size():
				container[idx] = val
	else:
		scope[target] = val

# â”€â”€â”€ EXPRESSION EVALUATION â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

func _is_fully_enclosed(s: String) -> bool:
	if not s.begins_with("(") or not s.ends_with(")"):
		return false
	var depth = 0
	for i in range(s.length() - 1):
		var ch = s[i]
		if ch == '(':
			depth += 1
		elif ch == ')':
			depth -= 1
			if depth == 0:
				return false
	return depth == 1

func _is_fully_enclosed_bracket(s: String) -> bool:
	if not s.begins_with("[") or not s.ends_with("]"):
		return false
	var depth = 0
	for i in range(s.length() - 1):
		var ch = s[i]
		if ch == '[':
			depth += 1
		elif ch == ']':
			depth -= 1
			if depth == 0:
				return false
	return depth == 1

func _find_matching_bracket_from_end(s: String) -> int:
	var depth = 0
	var in_q = false
	var q_c = ""
	var i = s.length() - 1
	while i >= 0:
		var ch = s[i]
		if not in_q:
			if ch in ['"', "'"]:
				in_q = true
				q_c = ch
			elif ch == ']':
				depth += 1
			elif ch == '[':
				depth -= 1
				if depth == 0:
					return i
		else:
			if ch == q_c and (i == 0 or s[i - 1] != '\\'):
				in_q = false
		i -= 1
	return -1

func _find_depth_0(s: String, needle: String) -> int:
	var depth = 0
	var in_quote = false
	var q_char = ""
	var n_len = needle.length()
	var s_len = s.length()
	for i in range(s_len - n_len + 1):
		var ch = s[i]
		if not in_quote:
			if ch in ['"', "'"]:
				in_quote = true
				q_char = ch
			elif ch in ['(', '[', '{']:
				depth += 1
			elif ch in [')', ']', '}']:
				depth = max(0, depth - 1)
			elif depth == 0 and s.substr(i, n_len) == needle:
				return i
		else:
			if ch == q_char and (i == 0 or s[i - 1] != '\\'):
				in_quote = false
	return -1

static func _to_float(v: Variant) -> float:
	if v == null: return 0.0
	if v is float: return v
	if v is int: return float(v)
	if v is bool: return 1.0 if v else 0.0
	if v is String: return v.to_float()
	return 0.0

static func _to_int(v: Variant) -> int:
	if v == null: return 0
	if v is int: return v
	if v is float: return int(v)
	if v is bool: return 1 if v else 0
	if v is String: return v.to_int()
	return 0

func _split_top_level_op(expr: String, ops: Array[String]) -> Dictionary:
	var n = expr.length()
	for op in ops:
		var op_len = op.length()
		var depth = 0
		var in_quote = false
		var q_char = ""
		var i = n - 1
		while i >= 0:
			var ch = expr[i]
			if not in_quote:
				if ch in ['"', "'"]:
					in_quote = true
					q_char = ch
				elif ch in [')', ']', '}']:
					depth += 1
				elif ch in ['(', '[', '{']:
					depth = max(0, depth - 1)
				elif depth == 0 and i + op_len <= n and expr.substr(i, op_len) == op:
					# Check boundaries
					if op == "=" and (i > 0 and expr[i - 1] in ["=", "!", "<", ">", "+", "-", "*", "/", "%", "&", "|", "^", "~", ":"]):
						i -= 1
						continue
					if op == "=" and (i + 1 < n and expr[i + 1] == "="):
						i -= 1
						continue
					if op == "&" and ((i > 0 and expr[i - 1] == "&") or (i + 1 < n and (expr[i + 1] == "&" or expr[i + 1] == "="))):
						i -= 1
						continue
					if op == "|" and ((i > 0 and expr[i - 1] == "|") or (i + 1 < n and (expr[i + 1] == "|" or expr[i + 1] == "="))):
						i -= 1
						continue
					if op == "^" and (i + 1 < n and expr[i + 1] == "="):
						i -= 1
						continue
					if (op == "<<" or op == ">>") and (i + 2 < n and expr[i + 2] == "="):
						i -= 1
						continue
					if (op == "<" or op == ">") and i + 1 < n and expr[i + 1] == "=":
						i -= 1
						continue
					if op == "<" and ((i > 0 and expr[i - 1] == "<") or (i + 1 < n and expr[i + 1] == "<")):
						i -= 1
						continue
					if op == ">" and ((i > 0 and expr[i - 1] in [">", "-", "="]) or (i + 1 < n and expr[i + 1] == ">")):
						i -= 1
						continue
					if (op == "*" or op == "/") and (i > 0 and expr[i - 1] == op):
						i -= 1
						continue
					if (op == "*" or op == "/") and (i + 1 < n and expr[i + 1] == op):
						i -= 1
						continue
					if op == "-" and (i == 0 or expr[i - 1] in ["+", "-", "*", "/", "%", "<", ">", "=", "(", "[", ",", "e", "E"]):
						i -= 1
						continue
					var left = expr.substr(0, i).strip_edges()
					var right = expr.substr(i + op_len).strip_edges()
					if not left.is_empty() and not right.is_empty():
						return {"found": true, "op": op, "left": left, "right": right}
			else:
				if ch == q_char and (i == 0 or expr[i - 1] != '\\'):
					in_quote = false
			i -= 1
			
	return {"found": false}

func _eval_expr(expr: String, scope: Dictionary) -> Variant:
	expr = expr.strip_edges()
	if expr.is_empty():
		return null
		
	# Literal constants
	if expr == "True": return true
	if expr == "False": return false
	if expr == "None": return null
	if expr.begins_with("0x") or expr.begins_with("0X"):
		return ("0x" + expr.substr(2).replace("_", "")).hex_to_int()
	if expr.begins_with("0b") or expr.begins_with("0B"):
		return expr.substr(2).replace("_", "").bin_to_int()
	if expr.begins_with("0o") or expr.begins_with("0O"):
		var octal_str = expr.substr(2).replace("_", "")
		var oct_val = 0
		for ch in octal_str: oct_val = (oct_val * 8) + ch.to_int()
		return oct_val
	if expr.is_valid_int(): return expr.to_int()
	if expr.is_valid_float(): return expr.to_float()
	if expr.begins_with("~"):
		return ~int(_eval_expr(expr.substr(1).strip_edges(), scope))
	if (expr.begins_with('"') and expr.ends_with('"')) or (expr.begins_with("'") and expr.ends_with("'")):
		var raw_str = expr.substr(1, expr.length() - 2)
		return raw_str.c_unescape()
		
	# f-string: f"..." or f'...'
	if (expr.begins_with('f"') and expr.ends_with('"')) or (expr.begins_with("f'") and expr.ends_with("'")):
		return _format_fstring(expr.substr(2, expr.length() - 3), scope)
		
	# print(...)
	if expr.begins_with("print(") and expr.ends_with(")"):
		var inner = expr.substr(6, expr.length() - 7).strip_edges()
		if inner.is_empty():
			stdout_buffer.append("")
		else:
			var args = _split_args(inner)
			var str_parts: PackedStringArray = []
			for a in args:
				var res = _eval_expr(a, scope)
				str_parts.append(_py_str(res))
			stdout_buffer.append(" ".join(str_parts))
		return null

	# Parenthesized expression: (expr)
	if expr.begins_with("(") and expr.ends_with(")") and not expr.contains(" for "):
		var inner = expr.substr(1, expr.length() - 2).strip_edges()
		if not inner.ends_with(",") and _is_fully_enclosed(expr):
			var parts = _split_args(inner)
			if parts.size() == 1:
				return _eval_expr(inner, scope)

	# Boolean NOT
	if expr.begins_with("not ") and not expr.contains(" for "):
		return not _is_truthy(_eval_expr(expr.substr(4).strip_edges(), scope))

	# Boolean OR / AND
	var bool_split = _split_top_level_op(expr, [" or ", " and "])
	if bool_split["found"]:
		var lv = _eval_expr(bool_split["left"], scope)
		var rv = _eval_expr(bool_split["right"], scope)
		if bool_split["op"] == " or ":
			return lv if _is_truthy(lv) else rv
		else:
			return rv if _is_truthy(lv) else lv

	# Comparisons
	var comp_split = _split_top_level_op(expr, ["==", "!=", "<=", ">=", "<", ">"])
	if comp_split["found"]:
		var lv = _eval_expr(comp_split["left"], scope)
		var rv = _eval_expr(comp_split["right"], scope)
		if lv == null or rv == null:
			match comp_split["op"]:
				"==": return lv == rv
				"!=": return lv != rv
				_: return false
		match comp_split["op"]:
			"==": return lv == rv
			"!=": return lv != rv
			"<=": return lv <= rv
			">=": return lv >= rv
			"<": return lv < rv
			">": return lv > rv

	# Bitwise OR: |
	var b_or_split = _split_top_level_op(expr, ["|"])
	if b_or_split["found"]:
		var lv = _eval_expr(b_or_split["left"], scope)
		var rv = _eval_expr(b_or_split["right"], scope)
		if lv != null and rv != null:
			return int(lv) | int(rv)

	# Bitwise XOR: ^
	var b_xor_split = _split_top_level_op(expr, ["^"])
	if b_xor_split["found"]:
		var lv = _eval_expr(b_xor_split["left"], scope)
		var rv = _eval_expr(b_xor_split["right"], scope)
		if lv != null and rv != null:
			return int(lv) ^ int(rv)

	# Bitwise AND: &
	var b_and_split = _split_top_level_op(expr, ["&"])
	if b_and_split["found"]:
		var lv = _eval_expr(b_and_split["left"], scope)
		var rv = _eval_expr(b_and_split["right"], scope)
		if lv != null and rv != null:
			return int(lv) & int(rv)

	# Bitwise Shifts: <<, >>
	var shift_split = _split_top_level_op(expr, ["<<", ">>"])
	if shift_split["found"]:
		var lv = _eval_expr(shift_split["left"], scope)
		var rv = _eval_expr(shift_split["right"], scope)
		if lv != null and rv != null:
			if shift_split["op"] == "<<":
				return int(lv) << int(rv)
			else:
				return int(lv) >> int(rv)

	# Addition / Subtraction
	var add_split = _split_top_level_op(expr, ["+", "-"])
	if add_split["found"]:
		var lv = _eval_expr(add_split["left"], scope)
		var rv = _eval_expr(add_split["right"], scope)
		if add_split["op"] == "+":
			if lv is String or rv is String:
				return str(lv) + str(rv)
			elif lv is Array and rv is Array:
				var res_arr = lv.duplicate()
				res_arr.append_array(rv)
				return res_arr
			elif lv != null and rv != null:
				return lv + rv
		elif add_split["op"] == "-":
			if lv != null and rv != null:
				return lv - rv

	# Multiplication / Division / Modulo
	var mul_split = _split_top_level_op(expr, ["//", "%", "*", "/"])
	if mul_split["found"]:
		var lv = _eval_expr(mul_split["left"], scope)
		var rv = _eval_expr(mul_split["right"], scope)
		if lv != null and rv != null:
			match mul_split["op"]:
				"*":
					if lv is Array and (rv is int or rv is float):
						var res = []
						for _k in range(int(rv)): res.append_array(lv)
						return res
					elif rv is Array and (lv is int or lv is float):
						var res = []
						for _k in range(int(lv)): res.append_array(rv)
						return res
					elif lv is String and (rv is int or rv is float):
						return lv.repeat(max(0, int(rv)))
					elif rv is String and (lv is int or lv is float):
						return rv.repeat(max(0, int(lv)))
					return lv * rv
				"/":
					var f_lv = _to_float(lv)
					var f_rv = _to_float(rv)
					return f_lv / f_rv if f_rv != 0.0 else 0.0
				"//":
					var f_lv = _to_float(lv)
					var f_rv = _to_float(rv)
					return int(f_lv / f_rv) if f_rv != 0.0 else 0
				"%":
					var i_lv = _to_int(lv)
					var i_rv = _to_int(rv)
					return i_lv % i_rv if i_rv != 0 else 0

	# Exponentiation **
	var pow_split = _split_top_level_op(expr, ["**"])
	if pow_split["found"]:
		var lv = _eval_expr(pow_split["left"], scope)
		var rv = _eval_expr(pow_split["right"], scope)
		if lv != null and rv != null:
			return pow(_to_float(lv), _to_float(rv))
		
	# List or generator comprehension: [expr for var in iterable] or (expr for var in iterable) or expr for var in iterable
	if expr.contains(" for ") and expr.contains(" in "):
		if expr.begins_with("[") and expr.ends_with("]") and _is_fully_enclosed_bracket(expr):
			var inner = expr.substr(1, expr.length() - 2).strip_edges()
			if _find_depth_0(inner, " for ") != -1 and _find_depth_0(inner, " in ") != -1:
				return _eval_list_comprehension(inner, scope)
		elif expr.begins_with("(") and expr.ends_with(")") and _is_fully_enclosed(expr):
			var inner = expr.substr(1, expr.length() - 2).strip_edges()
			if _find_depth_0(inner, " for ") != -1 and _find_depth_0(inner, " in ") != -1:
				return _eval_list_comprehension(inner, scope)
		elif _find_depth_0(expr, " for ") != -1 and _find_depth_0(expr, " in ") != -1:
			return _eval_list_comprehension(expr, scope)
		
	# Simple list: [...]
	if expr.begins_with("[") and expr.ends_with("]"):
		var inner = expr.substr(1, expr.length() - 2).strip_edges()
		if inner.is_empty(): return []
		var parts = _split_args(inner)
		var arr: Array = []
		for p in parts:
			arr.append(_eval_expr(p, scope))
		return arr
		
	# Simple tuple: (...)
	if expr.begins_with("(") and expr.ends_with(")") and not expr.contains("def ") and not expr.contains("="):
		var inner = expr.substr(1, expr.length() - 2).strip_edges()
		var parts = _split_args(inner)
		if parts.size() > 1 or inner.ends_with(","):
			var arr: Array = []
			for p in parts:
				arr.append(_eval_expr(p, scope))
			return arr

	# Subscript access: container[index]
	if expr.ends_with("]") and not expr.begins_with("["):
		var b_open = _find_matching_bracket_from_end(expr)
		if b_open != -1:
			var container_expr = expr.substr(0, b_open).strip_edges()
			var idx_expr = expr.substr(b_open + 1, expr.length() - b_open - 2).strip_edges()
			var container = _eval_expr(container_expr, scope)
			var idx_val = _eval_expr(idx_expr, scope)
			if container is PyInstance:
				# Treat PyInstance as indexable via attrs if it's a sequence (e.g. position)
				var idx_int = int(idx_val) if idx_val != null else 0
				var attr_val = container.get_attr(str(idx_int))
				if attr_val != null: return attr_val
				return null
			if container is Dictionary and container.has(idx_val):
				return container[idx_val]
			elif container is Array and idx_val != null:
				var int_idx = int(idx_val)
				if int_idx < 0: int_idx = container.size() + int_idx
				if int_idx >= 0 and int_idx < container.size():
					return container[int_idx]
			elif container is String and idx_val != null:
				var int_idx = int(idx_val)
				if int_idx < 0: int_idx = container.length() + int_idx
				if int_idx >= 0 and int_idx < container.length():
					return container[int_idx]
			
	# Method or property access: target.member(...) or target.member
	if expr.contains("."):
		var dot_eval = _eval_dot_expression(expr, scope)
		if dot_eval is Dictionary and dot_eval.get("handled", false):
			return dot_eval.get("value", null)
			
	# Direct variable lookup
	if scope.has(expr):
		return scope[expr]
	if global_scope.has(expr):
		return global_scope[expr]
		
	# Call to user-defined class constructor or function: Func(args)
	var paren_open = expr.find("(")
	if paren_open != -1 and expr.ends_with(")"):
		var fn_name = expr.substr(0, paren_open).strip_edges()
		var arg_str = expr.substr(paren_open + 1, expr.length() - paren_open - 2).strip_edges()
		var parsed_args = _parse_call_args(arg_str, scope)
		
		# Builtin constructors
		if fn_name == "dict":
			var arg0 = parsed_args["args"][0] if not parsed_args["args"].is_empty() else null
			if arg0 is PyCounter: return arg0.to_dict()
			if arg0 is Dictionary: return arg0
			return {}
		elif fn_name == "deque":
			var iter_arg = parsed_args["args"][0] if not parsed_args["args"].is_empty() else null
			var mlen = -1
			if parsed_args["kwargs"].has("maxlen"):
				mlen = int(parsed_args["kwargs"]["maxlen"])
			elif parsed_args["args"].size() > 1:
				mlen = int(parsed_args["args"][1])
			return PyDeque.new(iter_arg, mlen)
		elif fn_name == "Counter":
			var iter_arg = parsed_args["args"][0] if not parsed_args["args"].is_empty() else null
			return PyCounter.new(iter_arg)
		elif fn_name == "list":
			var arg0 = parsed_args["args"][0] if not parsed_args["args"].is_empty() else null
			if arg0 is PyDeque: return arg0.to_list()
			if arg0 is Array: return arg0
			return []
		elif fn_name == "len":
			if parsed_args["args"].is_empty(): return 0
			var arg0 = parsed_args["args"][0]
			if arg0 is Array or arg0 is Dictionary: return arg0.size()
			if arg0 is String: return arg0.length()
			if arg0 is PyDeque: return arg0.items.size()
			return 0
		elif fn_name == "sum":
			if parsed_args["args"].is_empty(): return 0
			var arg0 = parsed_args["args"][0]
			var total: float = 0.0
			if arg0 is Array:
				for xv in arg0:
					if xv is int or xv is float:
						total += xv
			if total == float(int(total)): return int(total)
			return total
		elif fn_name == "range":
			var pargs = parsed_args["args"]
			var res: Array = []
			if pargs.size() == 1:
				for idx in range(int(pargs[0])): res.append(idx)
			elif pargs.size() == 2:
				var start = int(pargs[0]); var stop = int(pargs[1])
				var idx = start
				while idx < stop: res.append(idx); idx += 1
			elif pargs.size() >= 3:
				var start = int(pargs[0]); var stop = int(pargs[1]); var step = int(pargs[2])
				if step > 0:
					var idx = start
					while idx < stop: res.append(idx); idx += step
				elif step < 0:
					var idx = start
					while idx > stop: res.append(idx); idx += step
			return res
		elif fn_name == "enumerate":
			if parsed_args["args"].is_empty(): return []
			var arg0 = parsed_args["args"][0]
			var res: Array = []
			if arg0 is Array:
				for idx in range(arg0.size()):
					res.append([idx, arg0[idx]])
			return res
		elif fn_name == "abs":
			if parsed_args["args"].is_empty(): return 0
			var av = parsed_args["args"][0]
			if av == null: return 0
			if av is int: return abs(av)
			if av is float: return abs(av)
			return 0
		elif fn_name == "min":
			var ma = parsed_args["args"]
			if ma.size() == 1 and ma[0] is Array: return ma[0].min()
			if ma.size() >= 2: return min(ma[0], ma[1])
			return null
		elif fn_name == "max":
			var ma = parsed_args["args"]
			if ma.size() == 1 and ma[0] is Array: return ma[0].max()
			if ma.size() >= 2: return max(ma[0], ma[1])
			return null
		elif fn_name == "int":
			if parsed_args["args"].is_empty(): return 0
			return _to_int(parsed_args["args"][0])
		elif fn_name == "float":
			if parsed_args["args"].is_empty(): return 0.0
			return _to_float(parsed_args["args"][0])
		elif fn_name == "str":
			if parsed_args["args"].is_empty(): return ""
			return _py_str(parsed_args["args"][0])
		elif fn_name == "round":
			if parsed_args["args"].is_empty(): return 0
			var val = _to_float(parsed_args["args"][0])
			var d = _to_int(parsed_args["args"][1]) if parsed_args["args"].size() > 1 else 0
			var mult = pow(10, d)
			return round(val * mult) / mult
			
		# Class instantiation
		if classes.has(fn_name):
			return _instantiate_class(parsed_args["args"], parsed_args["kwargs"], classes[fn_name])
			
		# User function call
		if functions.has(fn_name):
			return _call_user_func(functions[fn_name], parsed_args["args"], null, parsed_args["kwargs"])
			
		# Callable object
		if scope.has(fn_name) and scope[fn_name] is Callable:
			return scope[fn_name].callv(parsed_args["args"])
		if global_scope.has(fn_name) and global_scope[fn_name] is Callable:
			return global_scope[fn_name].callv(parsed_args["args"])
			
	# Fallback GDScript Expression evaluation for arithmetic / comparisons
	var translated = expr.replace(" and ", " && ").replace(" or ", " || ").replace(" not ", " ! ")
	var exp_obj = Expression.new()
	var v_names: PackedStringArray = []
	var v_vals: Array = []
	for k in scope.keys():
		var sk = str(k)
		if sk.is_valid_ascii_identifier():
			v_names.append(sk)
			v_vals.append(scope[k])
	for k in global_scope.keys():
		var sk = str(k)
		if not scope.has(k) and sk.is_valid_ascii_identifier() and not v_names.has(sk):
			v_names.append(sk)
			v_vals.append(global_scope[k])
	if exp_obj.parse(translated, v_names) == OK:
		var eval_res = exp_obj.execute(v_vals, self, false)
		if not exp_obj.has_execute_failed():
			return eval_res
			
	return null

func _eval_dot_expression(expr: String, scope: Dictionary) -> Dictionary:
	# target.method(...) or target.prop
	var paren_open = expr.find("(")
	if paren_open != -1 and expr.ends_with(")"):
		var dot_idx = expr.rfind(".", paren_open)
		if dot_idx != -1:
			var target_expr = expr.substr(0, dot_idx).strip_edges()
			var method_name = expr.substr(dot_idx + 1, paren_open - (dot_idx + 1)).strip_edges()
			if not method_name.is_valid_ascii_identifier():
				return {"handled": false, "value": null}
			var arg_str = expr.substr(paren_open + 1, expr.length() - paren_open - 2).strip_edges()
			var args = _parse_call_args(arg_str, scope)["args"]
			if classes.has(target_expr):
				var cls = classes[target_expr]
				if cls["methods"].has(method_name):
					var self_inst = args[0] if (not args.is_empty() and args[0] is PyInstance) else null
					var remaining_args = args.slice(1) if self_inst != null else args
					return {"handled": true, "value": _call_user_func(cls["methods"][method_name], remaining_args, self_inst)}
			var target = _eval_expr(target_expr, scope)
			if target is PyInstance:
				return {"handled": true, "value": target.call_method(method_name, args)}
			elif target is PyDeque:
				if method_name == "append":
					if not args.is_empty(): target.append(args[0])
					return {"handled": true, "value": null}
				elif method_name == "pop": return {"handled": true, "value": target.pop()}
				elif method_name == "popleft": return {"handled": true, "value": target.popleft()}
			elif target is Array:
				if method_name == "append":
					target.append(args[0] if not args.is_empty() else null)
					return {"handled": true, "value": null}
				elif method_name == "extend":
					if not args.is_empty() and args[0] is Array: target.append_array(args[0])
					return {"handled": true, "value": null}
				elif method_name == "pop":
					if args.is_empty():
						return {"handled": true, "value": target.pop_back() if not target.is_empty() else null}
					var pidx = int(args[0])
					var pval = target[pidx]
					target.remove_at(pidx)
					return {"handled": true, "value": pval}
				elif method_name == "remove":
					var ridx = target.find(args[0] if not args.is_empty() else null)
					if ridx != -1: target.remove_at(ridx)
					return {"handled": true, "value": null}
				elif method_name == "sort":
					target.sort()
					return {"handled": true, "value": null}
				elif method_name == "reverse":
					target.reverse()
					return {"handled": true, "value": null}
				elif method_name == "index":
					return {"handled": true, "value": target.find(args[0] if not args.is_empty() else null)}
				elif method_name == "count":
					return {"handled": true, "value": target.count(args[0] if not args.is_empty() else null)}
				elif method_name == "copy":
					return {"handled": true, "value": target.duplicate()}
				elif method_name == "insert":
					if args.size() >= 2: target.insert(int(args[0]), args[1])
					return {"handled": true, "value": null}
			elif target is PyRandom:
				if method_name == "seed":
					target.seed(int(args[0]) if not args.is_empty() else 0)
					return {"handled": true, "value": null}
				elif method_name == "choice":
					return {"handled": true, "value": target.choice(args[0] if not args.is_empty() else [])}
				elif method_name == "randint":
					return {"handled": true, "value": target.randint(int(args[0]), int(args[1]))}
				elif method_name == "uniform":
					return {"handled": true, "value": target.uniform(float(args[0]), float(args[1]))}
				elif method_name == "shuffle":
					if not args.is_empty() and args[0] is Array: target.shuffle(args[0])
					return {"handled": true, "value": null}
				elif method_name == "random":
					return {"handled": true, "value": target.genrand_res53()}
				elif method_name == "sample":
					if args.size() >= 2 and args[0] is Array:
						var pool = args[0].duplicate()
						var k = int(args[1])
						target.shuffle(pool)
						return {"handled": true, "value": pool.slice(0, k)}
					return {"handled": true, "value": []}
			elif target is PyMath:
				if method_name == "sqrt":
					return {"handled": true, "value": target.sqrt(_to_float(args[0]) if not args.is_empty() else 0.0)}
				elif method_name == "floor":
					return {"handled": true, "value": target.floor(_to_float(args[0]) if not args.is_empty() else 0.0)}
				elif method_name == "ceil":
					return {"handled": true, "value": target.ceil(_to_float(args[0]) if not args.is_empty() else 0.0)}
				elif method_name == "abs":
					return {"handled": true, "value": target.abs(_to_float(args[0]) if not args.is_empty() else 0.0)}
				elif method_name == "sin":
					return {"handled": true, "value": target.sin(_to_float(args[0]) if not args.is_empty() else 0.0)}
				elif method_name == "cos":
					return {"handled": true, "value": target.cos(_to_float(args[0]) if not args.is_empty() else 0.0)}
				elif method_name == "pow":
					return {"handled": true, "value": pow(_to_float(args[0]), _to_float(args[1])) if args.size() >= 2 else 1.0}
				elif method_name == "log":
					return {"handled": true, "value": log(_to_float(args[0])) if not args.is_empty() else 0.0}
				elif method_name == "exp":
					return {"handled": true, "value": exp(_to_float(args[0])) if not args.is_empty() else 1.0}
			elif target is PyCounter:
				if method_name == "most_common":
					var k = int(args[0]) if not args.is_empty() else -1
					var items_list: Array = []
					for ck in target.counts.keys():
						items_list.append([ck, target.counts[ck]])
					items_list.sort_custom(func(a, b): return a[1] > b[1])
					if k > 0 and k < items_list.size(): items_list = items_list.slice(0, k)
					return {"handled": true, "value": items_list}
				elif method_name == "keys": return {"handled": true, "value": target.counts.keys()}
				elif method_name == "values": return {"handled": true, "value": target.counts.values()}
				elif method_name == "get":
					return {"handled": true, "value": target.counts.get(str(args[0]) if not args.is_empty() else "", args[1] if args.size() > 1 else null)}
			elif target is String:
				if method_name == "split":
					var sep = str(args[0]) if not args.is_empty() else " "
					var parts_arr = target.split(sep)
					var res: Array = []
					for ps in parts_arr: res.append(ps)
					return {"handled": true, "value": res}
				elif method_name == "strip": return {"handled": true, "value": target.strip_edges()}
				elif method_name == "upper": return {"handled": true, "value": target.to_upper()}
				elif method_name == "lower": return {"handled": true, "value": target.to_lower()}
				elif method_name == "replace":
					if args.size() >= 2: return {"handled": true, "value": target.replace(str(args[0]), str(args[1]))}
					return {"handled": true, "value": target}
				elif method_name == "startswith":
					return {"handled": true, "value": target.begins_with(str(args[0]) if not args.is_empty() else "")}
				elif method_name == "endswith":
					return {"handled": true, "value": target.ends_with(str(args[0]) if not args.is_empty() else "")}
				elif method_name == "find":
					return {"handled": true, "value": target.find(str(args[0]) if not args.is_empty() else "")}
				elif method_name == "join":
					if not args.is_empty() and args[0] is Array:
						var str_parts: PackedStringArray = []
						for it in args[0]: str_parts.append(str(it))
						return {"handled": true, "value": target.join(str_parts)}
					return {"handled": true, "value": ""}
			elif target is Dictionary:
				if method_name == "get":
					return {"handled": true, "value": target.get(args[0] if not args.is_empty() else null, args[1] if args.size() > 1 else null)}
				elif method_name == "keys": return {"handled": true, "value": target.keys()}
				elif method_name == "values": return {"handled": true, "value": target.values()}
				elif method_name == "items":
					var kv_pairs: Array = []
					for dk in target.keys(): kv_pairs.append([dk, target[dk]])
					return {"handled": true, "value": kv_pairs}
				elif method_name == "update":
					if not args.is_empty() and args[0] is Dictionary:
						for dk in args[0].keys(): target[dk] = args[0][dk]
					return {"handled": true, "value": null}
				elif method_name == "pop":
					if not args.is_empty():
						var dv = target.get(args[0], args[1] if args.size() > 1 else null)
						target.erase(args[0])
						return {"handled": true, "value": dv}
					return {"handled": true, "value": null}
	else:
		# Property access: target.prop
		var dot_idx = expr.rfind(".")
		if dot_idx != -1:
			var prop_name = expr.substr(dot_idx + 1).strip_edges()
			if prop_name.is_valid_ascii_identifier():
				var target_expr = expr.substr(0, dot_idx).strip_edges()
				var target = _eval_expr(target_expr, scope)
				if target is PyInstance:
					return {"handled": true, "value": target.get_attr(prop_name)}
				elif target is PyMath:
					if prop_name == "pi": return {"handled": true, "value": target.pi}
					if prop_name == "e": return {"handled": true, "value": target.e}
		
	return {"handled": false, "value": null}

func _eval_list_comprehension(inner: String, scope: Dictionary) -> Array:
	var for_pos = _find_depth_0(inner, " for ")
	if for_pos == -1: return []
	var expr_part = inner.substr(0, for_pos).strip_edges()
	var rest = inner.substr(for_pos + 5).strip_edges()
	var in_pos = _find_depth_0(rest, " in ")
	if in_pos == -1: return []
	
	var var_name = rest.substr(0, in_pos).strip_edges()
	var iter_part = rest.substr(in_pos + 4).strip_edges()
	var if_pos = _find_depth_0(iter_part, " if ")
	var cond_part = ""
	if if_pos != -1:
		cond_part = iter_part.substr(if_pos + 4).strip_edges()
		iter_part = iter_part.substr(0, if_pos).strip_edges()
		
	var iterable = _eval_expr(iter_part, scope)
	if iterable is PyDeque:
		iterable = iterable.items
	elif iterable is Dictionary:
		iterable = iterable.keys()
	elif iterable is String:
		var chars: Array = []
		for ch in iterable: chars.append(ch)
		iterable = chars
	
	var res: Array = []
	if iterable is Array:
		var local_s = scope.duplicate()
		for item in iterable:
			_bind_loop_var(var_name, item, local_s)
			if cond_part.is_empty() or _is_truthy(_eval_expr(cond_part, local_s)):
				res.append(_eval_expr(expr_part, local_s))
	return res

func _call_user_func(f_def: Dictionary, args: Array, self_inst: PyInstance = null, kwargs: Dictionary = {}) -> Variant:
	var local_scope = global_scope.duplicate()
	if self_inst != null:
		local_scope["self"] = self_inst
		
	# Parse parameter names from function header (e.g. `def move(self, x, y):`)
	var hdr = f_def["header"]
	var p_open = hdr.find("(")
	var p_close = -1
	if p_open != -1:
		var p_depth = 0
		for c_i in range(p_open, hdr.length()):
			if hdr[c_i] == '(': p_depth += 1
			elif hdr[c_i] == ')':
				p_depth -= 1
				if p_depth == 0:
					p_close = c_i
					break
	if p_open != -1 and p_close != -1:
		var params_str = hdr.substr(p_open + 1, p_close - p_open - 1).strip_edges()
		var raw_params = _split_args(params_str)
		var p_names: Array[String] = []
		var defaults: Dictionary = {}
		
		for rp in raw_params:
			var trimmed = rp.strip_edges()
			if trimmed.is_empty(): continue
			var p_no_default = trimmed
			if trimmed.contains("="):
				var sp = trimmed.split("=")
				p_no_default = sp[0].strip_edges()
				var p_key = p_no_default.split(":")[0].strip_edges()
				defaults[p_key] = _eval_expr(sp[1].strip_edges(), global_scope)
			var p_name = p_no_default.split(":")[0].strip_edges()
			p_names.append(p_name)
			
		if p_names.size() > 0 and p_names[0] == "self" and self_inst != null:
			p_names.remove_at(0)
			
		for idx in range(p_names.size()):
			var pn = p_names[idx]
			if idx < args.size():
				local_scope[pn] = args[idx]
			elif kwargs.has(pn):
				local_scope[pn] = kwargs[pn]
			elif defaults.has(pn):
				local_scope[pn] = defaults[pn]
				
	var sub_stmts = _group_statements(f_def["body"])
	for stmt in sub_stmts:
		var res = _execute_statement(stmt, local_scope)
		if stmt["type"] == "return" or res != null:
			return res
		if not runtime_error.is_empty():
			return null
			
	return null

func call_instance_method(inst: PyInstance, method_def: Dictionary, args: Array, kwargs: Dictionary = {}) -> Variant:
	return _call_user_func(method_def, args, inst, kwargs)

# ─── STRING / F-STRING FORMATTING ─────────────────────────────────────────────

func _format_fstring(template: String, scope: Dictionary) -> String:
	var res = ""
	var i = 0
	var n = template.length()
	while i < n:
		if template[i] == '{':
			var close_idx = template.find("}", i)
			if close_idx != -1:
				var expr = template.substr(i + 1, close_idx - i - 1)
				var fmt = ""
				if expr.contains(":"):
					var parts = expr.split(":")
					expr = parts[0]
					fmt = parts[1]
				var val = _eval_expr(expr, scope)
				if not fmt.is_empty():
					var fmt_str = "%" + fmt
					if fmt.ends_with("f"):
						res += fmt_str % _to_float(val)
					elif fmt.ends_with("d"):
						res += fmt_str % _to_int(val)
					else:
						res += fmt_str % (val if val != null else "")
				else:
					res += _py_str(val)
				i = close_idx + 1
				continue
		res += template[i]
		i += 1
	return res

func _py_str(v: Variant) -> String:
	if v == null: return "None"
	if v is bool: return "True" if v else "False"
	if v is String: return v
	if v is PyInstance: return str(v)
	if v is PyDeque: return _py_repr(v.items)
	if v is PyCounter: return _py_repr(v.counts)
	return _py_repr(v)

func _py_repr(v: Variant) -> String:
	if v == null: return "None"
	if v is bool: return "True" if v else "False"
	if v is String: return "'%s'" % v.replace("'", "\\'")
	if v is Dictionary:
		var entries: PackedStringArray = []
		for k in v.keys():
			entries.append("%s: %s" % [_py_repr(k), _py_repr(v[k])])
		return "{" + ", ".join(entries) + "}"
	if v is Array:
		var items: PackedStringArray = []
		for item in v:
			items.append(_py_repr(item))
		return "[" + ", ".join(items) + "]"
	if v is PyDeque:
		return _py_repr(v.items)
	if v is PyCounter:
		return _py_repr(v.counts)
	if v is PyInstance:
		return str(v)
	return str(v)

func _parse_call_args(arg_str: String, scope: Dictionary) -> Dictionary:
	var positional: Array = []
	var kwargs: Dictionary = {}
	if arg_str.is_empty():
		return {"args": positional, "kwargs": kwargs}
		
	var pieces = _split_args(arg_str)
	for p in pieces:
		var trimmed = p.strip_edges()
		if trimmed.contains("=") and not trimmed.contains("=="):
			var sp = trimmed.split("=")
			var k = sp[0].strip_edges()
			var v = _eval_expr(sp[1].strip_edges(), scope)
			kwargs[k] = v
		else:
			positional.append(_eval_expr(trimmed, scope))
			
	return {"args": positional, "kwargs": kwargs}

func _split_args(s: String) -> Array[String]:
	var result: Array[String] = []
	var current = ""
	var depth = 0
	var in_quote = false
	var q_char = ""
	
	for i in range(s.length()):
		var ch = s[i]
		if not in_quote:
			if ch in ['"', "'"]:
				in_quote = true
				q_char = ch
				current += ch
			elif ch in ['(', '[', '{']:
				depth += 1
				current += ch
			elif ch in [')', ']', '}']:
				depth = max(0, depth - 1)
				current += ch
			elif ch == ',' and depth == 0:
				result.append(current.strip_edges())
				current = ""
			else:
				current += ch
		else:
			current += ch
			if ch == q_char and (i == 0 or s[i - 1] != '\\'):
				in_quote = false
				
	if not current.strip_edges().is_empty():
		result.append(current.strip_edges())
		
	return result
