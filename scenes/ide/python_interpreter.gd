class_name PythonInterpreter
extends RefCounted

## Fully integrated in-engine Python interpreter and execution environment for the IDE.
## Runs Python code directly in GDScript without requiring any external OS Python installation.

# -----------------------------------------------------------------------------
# Built-in Functions Callable Within Expressions via base_instance
# -----------------------------------------------------------------------------

func len(val: Variant) -> int:
	if val is Array or val is Dictionary:
		return val.size()
	if val is String:
		return val.length()
	return 0

func range(a: int, b: Variant = null, step: int = 1) -> Array:
	var res: Array = []
	var start = 0
	var stop = a
	if b != null:
		start = a
		stop = int(b)
	if step == 0:
		step = 1
	if step > 0:
		var curr = start
		while curr < stop:
			res.append(curr)
			curr += step
	else:
		var curr = start
		while curr > stop:
			res.append(curr)
			curr += step
	return res

func startswith(s: Variant, prefix: String) -> bool:
	if s is String:
		return s.begins_with(prefix)
	return false

func endswith(s: Variant, suffix: String) -> bool:
	if s is String:
		return s.ends_with(suffix)
	return false

func int_cast(v: Variant) -> int:
	return int(v)

func float_cast(v: Variant) -> float:
	return float(v)

func str_cast(v: Variant) -> String:
	return str(v)

func bool_cast(v: Variant) -> bool:
	return bool(v)

func sum(arr: Variant) -> Variant:
	if arr is Array:
		var total = 0
		for item in arr:
			total += item
		return total
	return 0

func min_val(a: Variant, b: Variant = null) -> Variant:
	if b == null and a is Array and not a.is_empty():
		var m = a[0]
		for item in a:
			if item < m:
				m = item
		return m
	elif b != null:
		return min(a, b)
	return 0

func max_val(a: Variant, b: Variant = null) -> Variant:
	if b == null and a is Array and not a.is_empty():
		var m = a[0]
		for item in a:
			if item > m:
				m = item
		return m
	elif b != null:
		return max(a, b)
	return 0

# -----------------------------------------------------------------------------
# Function Execution
# -----------------------------------------------------------------------------

## Evaluates a specific function from Python source code with given argument values.
## Returns a Dictionary: {"status": "ok"|"error", "value": Variant, "error_msg": String}
func call_function(source_code: String, func_name: String, args: Array) -> Dictionary:
	var parsed = _extract_function_body_and_params(source_code, func_name)
	if not parsed.get("found", false):
		return {
			"status": "error",
			"value": null,
			"error_msg": "Function '%s' not found in source code" % func_name
		}
		
	var param_names: Array = parsed.get("params", [])
	var func_body: String = parsed.get("body", "")
	
	# Bind parameters to local scope
	var scope: Dictionary = {}
	for i in range(param_names.size()):
		var p_name = str(param_names[i])
		if i < args.size():
			scope[p_name] = args[i]
		else:
			scope[p_name] = null
			
	# Execute function statements
	return _execute_body_statements(func_body, scope)

## Extracts function parameter names and body text from source code.
func _extract_function_body_and_params(code: String, func_name: String) -> Dictionary:
	var def_needle = "def " + func_name
	var func_start = code.find(def_needle)
	if func_start == -1:
		return {"found": false}
		
	var paren_open = code.find("(", func_start)
	if paren_open == -1:
		return {"found": false}
		
	var paren_close = code.find(")", paren_open)
	if paren_close == -1:
		return {"found": false}
		
	var params_str = code.substr(paren_open + 1, paren_close - paren_open - 1).strip_edges()
	var raw_params = params_str.split(",")
	var params: Array[String] = []
	for p in raw_params:
		var trimmed = p.strip_edges()
		if trimmed.is_empty():
			continue
		# Remove type annotations like "packet: dict" or defaults "packet = {}"
		var p_name = trimmed.split(":")[0].split("=")[0].strip_edges()
		if not p_name.is_empty():
			params.append(p_name)
			
	var colon_pos = code.find(":", paren_close)
	if colon_pos == -1:
		return {"found": false}
		
	var body_start = colon_pos + 1
	var body_end = code.length()
	var check_keywords = ["\ndef ", "\nclass ", "\nif __name__"]
	for kw in check_keywords:
		var pos = code.find(kw, body_start)
		if pos != -1 and pos < body_end:
			body_end = pos
			
	var body = code.substr(body_start, body_end - body_start)
	return {
		"found": true,
		"params": params,
		"body": body
	}

## Executes the body statements of a function, respecting indentation levels, if/elif/else, loops, assignments, and returns.
func _execute_body_statements(func_body: String, scope: Dictionary) -> Dictionary:
	var statements = _parse_statements(func_body)
	return _execute_statement_list(statements, 0, scope)

func _execute_statement_list(statements: Array[Dictionary], start_idx: int, scope: Dictionary) -> Dictionary:
	var idx = start_idx
	var if_stack: Array[Dictionary] = []
	
	while idx < statements.size():
		var stmt = statements[idx]
		var type = stmt.get("type", "")
		var text = stmt.get("text", "").strip_edges()
		var indent = stmt.get("indent", 0)
		
		# Pop branches that have ended because current statement is at lesser or equal indentation
		while not if_stack.is_empty() and indent <= if_stack.back().get("indent", 0):
			if_stack.pop_back()
			
		var parent_active = true
		for frame in if_stack:
			if not frame.get("is_active", true):
				parent_active = false
				break
				
		match type:
			"if":
				var cond_expr = text.substr(3).strip_edges()
				if cond_expr.ends_with(":"):
					cond_expr = cond_expr.substr(0, cond_expr.length() - 1).strip_edges()
				if parent_active:
					var cond_val = bool(_evaluate_expression(cond_expr, scope))
					if_stack.append({"indent": indent, "is_active": cond_val, "branch_taken": cond_val})
				else:
					if_stack.append({"indent": indent, "is_active": false, "branch_taken": true})
				idx += 1
				continue
				
			"elif":
				if not if_stack.is_empty():
					var last_frame = if_stack.back()
					var cond_expr = text.substr(5).strip_edges()
					if cond_expr.ends_with(":"):
						cond_expr = cond_expr.substr(0, cond_expr.length() - 1).strip_edges()
					if parent_active and not last_frame.get("branch_taken", false):
						var cond_val = bool(_evaluate_expression(cond_expr, scope))
						last_frame["is_active"] = cond_val
						if cond_val:
							last_frame["branch_taken"] = true
					else:
						last_frame["is_active"] = false
				idx += 1
				continue
				
			"else":
				if not if_stack.is_empty():
					var last_frame = if_stack.back()
					if parent_active and not last_frame.get("branch_taken", false):
						last_frame["is_active"] = true
						last_frame["branch_taken"] = true
					else:
						last_frame["is_active"] = false
				idx += 1
				continue
				
		# Only execute active branch
		if not parent_active:
			idx += 1
			continue
			
		match type:
			"return":
				var ret_expr = text
				if ret_expr.begins_with("return"):
					ret_expr = ret_expr.substr(6).strip_edges()
				# Strip outer parentheses: return ( ... ) or return(...)
				if ret_expr.begins_with("(") and ret_expr.ends_with(")"):
					ret_expr = ret_expr.substr(1, ret_expr.length() - 2).strip_edges()
				var val = _evaluate_expression(ret_expr, scope)
				return {"status": "ok", "value": val, "error_msg": ""}
				
			"for":
				# for <var> in <iterable>:
				var header = text.substr(4).strip_edges()
				if header.ends_with(":"):
					header = header.substr(0, header.length() - 1).strip_edges()
				var in_pos = header.find(" in ")
				if in_pos != -1:
					var loop_var = header.substr(0, in_pos).strip_edges()
					var iter_expr = header.substr(in_pos + 4).strip_edges()
					var iterable = _evaluate_expression(iter_expr, scope)
					
					# Gather body statements of this for loop
					var loop_body: Array[Dictionary] = []
					var body_idx = idx + 1
					while body_idx < statements.size() and statements[body_idx].get("indent", 0) > indent:
						loop_body.append(statements[body_idx])
						body_idx += 1
						
					if iterable is Array:
						for item in iterable:
							scope[loop_var] = item
							var loop_res = _execute_statement_list(loop_body, 0, scope)
							if loop_res.get("status") == "ok" and loop_res.get("value") != null and loop_res.get("error_msg") != "no_return":
								return loop_res
					idx = body_idx
					continue
					
			"assign":
				_execute_assignment(text, scope)
				
			"expr":
				_evaluate_expression(text, scope)
				
		idx += 1
		
	return {"status": "ok", "value": false, "error_msg": "no_return"}

func _execute_assignment(text: String, scope: Dictionary) -> void:
	var plus_eq = text.find("+=")
	if plus_eq != -1:
		var v_name = text.substr(0, plus_eq).strip_edges()
		var expr = text.substr(plus_eq + 2).strip_edges()
		var curr = scope.get(v_name, 0)
		var added = _evaluate_expression(expr, scope)
		scope[v_name] = curr + added
		return
		
	var minus_eq = text.find("-=")
	if minus_eq != -1:
		var v_name = text.substr(0, minus_eq).strip_edges()
		var expr = text.substr(minus_eq + 2).strip_edges()
		var curr = scope.get(v_name, 0)
		var subbed = _evaluate_expression(expr, scope)
		scope[v_name] = curr - subbed
		return
		
	var mul_eq = text.find("*=")
	if mul_eq != -1:
		var v_name = text.substr(0, mul_eq).strip_edges()
		var expr = text.substr(mul_eq + 2).strip_edges()
		var curr = scope.get(v_name, 1)
		var muled = _evaluate_expression(expr, scope)
		scope[v_name] = curr * muled
		return
		
	var eq_pos = text.find("=")
	if eq_pos != -1:
		var v_name = text.substr(0, eq_pos).strip_edges()
		var expr = text.substr(eq_pos + 1).strip_edges()
		var val = _evaluate_expression(expr, scope)
		scope[v_name] = val

## Groups raw code lines into logical Python statements, merging multi-line expressions inside parentheses and calculating indentation.
func _parse_statements(body_code: String) -> Array[Dictionary]:
	var raw_lines = body_code.split("\n")
	var statements: Array[Dictionary] = []
	
	var in_docstring = false
	var accumulated_statement = ""
	var first_line_indent = 0
	var paren_depth = 0
	
	for line in raw_lines:
		var trimmed = line.strip_edges()
		
		# Handle docstrings
		if trimmed.begins_with('"""') or trimmed.begins_with("'''"):
			var marker = trimmed.substr(0, 3)
			var after_marker = trimmed.substr(3)
			if after_marker.contains(marker):
				continue
			in_docstring = not in_docstring
			continue
			
		if in_docstring:
			if trimmed.contains('"""') or trimmed.contains("'''"):
				in_docstring = false
			continue
			
		# Ignore comments and blank lines outside open parentheses
		if paren_depth == 0 and (trimmed.is_empty() or trimmed.begins_with("#")):
			continue
			
		# Measure indentation of first line of statement
		if accumulated_statement.is_empty():
			var non_space = line.length() - line.strip_edges(true, false).length()
			first_line_indent = non_space
			
		# Count open and close parentheses/brackets/braces
		var clean_line = _strip_line_comments_and_strings(trimmed)
		for ch in clean_line:
			if ch in ["(", "[", "{"]:
				paren_depth += 1
			elif ch in [")", "]", "}"]:
				paren_depth = max(0, paren_depth - 1)
				
		if accumulated_statement.is_empty():
			accumulated_statement = trimmed
		else:
			accumulated_statement += " " + trimmed
			
		# If parentheses are balanced, this logical statement is complete
		if paren_depth == 0:
			var stmt_text = accumulated_statement.strip_edges()
			var cur_indent = first_line_indent
			accumulated_statement = ""
			
			if stmt_text.is_empty() or stmt_text.begins_with("#"):
				continue
				
			var stmt_type = "expr"
			if stmt_text.begins_with("return") or stmt_text.begins_with("return(") or stmt_text.begins_with("return "):
				stmt_type = "return"
			elif stmt_text.begins_with("if "):
				stmt_type = "if"
			elif stmt_text.begins_with("elif "):
				stmt_type = "elif"
			elif stmt_text == "else:" or stmt_text.begins_with("else"):
				stmt_type = "else"
			elif stmt_text.begins_with("for "):
				stmt_type = "for"
			elif (stmt_text.contains("=") or stmt_text.contains("+=") or stmt_text.contains("-=") or stmt_text.contains("*=")) and not stmt_text.begins_with("if ") and not stmt_text.begins_with("elif ") and not stmt_text.contains("==") and not stmt_text.contains("<=") and not stmt_text.contains(">=") and not stmt_text.contains("!="):
				stmt_type = "assign"
				
			statements.append({
				"type": stmt_type,
				"text": stmt_text,
				"indent": cur_indent
			})
			
	# If any leftover statement
	if not accumulated_statement.is_empty():
		var stmt_text = accumulated_statement.strip_edges()
		var s_type = "return" if stmt_text.begins_with("return") else "expr"
		statements.append({"type": s_type, "text": stmt_text, "indent": first_line_indent})
		
	return statements

func _strip_line_comments_and_strings(line: String) -> String:
	var result = ""
	var in_quote = false
	var quote_char = ""
	for i in range(line.length()):
		var ch = line[i]
		if not in_quote:
			if ch == "#":
				break
			elif ch == '"' or ch == "'":
				in_quote = true
				quote_char = ch
			else:
				result += ch
		else:
			if ch == quote_char:
				in_quote = false
	return result

# -----------------------------------------------------------------------------
# Python Expression Translation & Evaluation
# -----------------------------------------------------------------------------

## Evaluates a Python expression string within the given local scope dictionary.
func _evaluate_expression(expr: String, scope: Dictionary) -> Variant:
	expr = expr.strip_edges()
	if expr.is_empty():
		return null
		
	# Literal constants
	if expr == "True" or expr == "true":
		return true
	if expr == "False" or expr == "false":
		return false
	if expr == "None" or expr == "null":
		return null
	if expr.is_valid_int():
		return expr.to_int()
	if expr.is_valid_float():
		return expr.to_float()
		
	# If it's directly a variable in scope
	if scope.has(expr):
		return scope[expr]
		
	# Translate Python syntax to GDScript Expression syntax
	var translated = _translate_python_to_gdscript_expr(expr)
	
	var var_names: PackedStringArray = []
	var var_values: Array = []
	for k in scope.keys():
		var_names.append(str(k))
		var_values.append(scope[k])
		
	var expression = Expression.new()
	var err = expression.parse(translated, var_names)
	if err == OK:
		var result = expression.execute(var_values, self, false)
		if not expression.has_execute_failed():
			return result
			
	return false

## Translates Python operators and conventions to GDScript Expression compatible syntax.
func _translate_python_to_gdscript_expr(expr: String) -> String:
	expr = expr.replace("\n", " ").replace("\r", " ")
	
	# Translate python identity checks
	expr = expr.replace(" is True", " == true")
	expr = expr.replace(" is False", " == false")
	expr = expr.replace(" is None", " == null")
	expr = expr.replace(" is not None", " != null")
	
	# Translate common methods
	expr = expr.replace(".startswith(", ".begins_with(")
	expr = expr.replace(".endswith(", ".ends_with(")
	expr = expr.replace(".lower()", ".to_lower()")
	expr = expr.replace(".upper()", ".to_upper()")
	expr = expr.replace(".strip()", ".strip_edges()")
	
	# Translate boolean and logical literals
	var tokens = _tokenize_for_translation(expr)
	var out: PackedStringArray = []
	for token in tokens:
		match token:
			"True": out.append("true")
			"False": out.append("false")
			"None": out.append("null")
			"and": out.append("and")
			"or": out.append("or")
			"not": out.append("not")
			_: out.append(token)
			
	return "".join(out)

func _tokenize_for_translation(expr: String) -> Array[String]:
	var tokens: Array[String] = []
	var current = ""
	var in_string = false
	var string_char = ""
	
	for i in range(expr.length()):
		var ch = expr[i]
		if not in_string:
			if ch == '"' or ch == "'":
				if not current.is_empty():
					tokens.append(current)
					current = ""
				in_string = true
				string_char = ch
				current += ch
			elif ch in [" ", "\t", "(", ")", "[", "]", "{", "}", ",", "+", "-", "*", "/", "%", "!", "<", ">", "=", "&", "|", ":"]:
				if not current.is_empty():
					tokens.append(current)
					current = ""
				tokens.append(ch)
			else:
				current += ch
		else:
			current += ch
			if ch == string_char and (i == 0 or expr[i - 1] != "\\"):
				in_string = false
				tokens.append(current)
				current = ""
				
	if not current.is_empty():
		tokens.append(current)
		
	return tokens

# -----------------------------------------------------------------------------
# Test Case Parser for Checkers
# -----------------------------------------------------------------------------

## Parses any Python test case tuple line dynamically into {"args": Array, "expected": Variant, "desc": String}
func parse_test_case(raw_tuple_str: String) -> Dictionary:
	var trimmed = raw_tuple_str.strip_edges()
	if trimmed.ends_with(","):
		trimmed = trimmed.substr(0, trimmed.length() - 1).strip_edges()
	if trimmed.begins_with("(") and trimmed.ends_with(")"):
		trimmed = trimmed.substr(1, trimmed.length() - 2).strip_edges()
		
	var array_expr = "[" + trimmed + "]"
	var tokens = _tokenize_for_translation(array_expr)
	var out: PackedStringArray = []
	for token in tokens:
		match token:
			"True": out.append("true")
			"False": out.append("false")
			"None": out.append("null")
			_: out.append(token)
			
	var translated_array = "".join(out)
	var expr = Expression.new()
	var err = expr.parse(translated_array)
	if err == OK:
		var parsed_val = expr.execute([], self, false)
		if not expr.has_execute_failed() and parsed_val is Array:
			var arr: Array = parsed_val
			var desc = "Test case"
			var expected: Variant = true
			var args: Array = []
			
			if arr.size() >= 3 and arr[-1] is String:
				desc = str(arr[-1])
				expected = arr[-2]
				args = arr.slice(0, arr.size() - 2)
			elif arr.size() >= 2:
				expected = arr[-1]
				args = arr.slice(0, arr.size() - 1)
			elif arr.size() == 1:
				args = [arr[0]]
				
			return {
				"args": args,
				"expected": expected,
				"desc": desc
			}
			
	# Fallback JSON / string parsing if Expression fails on complex syntax
	var dict_start = raw_tuple_str.find("{")
	var dict_end = raw_tuple_str.rfind("}")
	if dict_start != -1 and dict_end != -1:
		var dict_str = raw_tuple_str.substr(dict_start, dict_end - dict_start + 1)
		var rest = raw_tuple_str.substr(dict_end + 1).strip_edges()
		dict_str = dict_str.replace("True", "true").replace("False", "false").replace("None", "null")
		var json = JSON.new()
		if json.parse(dict_str) == OK:
			var args_fallback = [json.data]
			var exp_fallback = true
			var desc_fallback = "Test case"
			var parts = rest.split(",")
			for p in parts:
				var pt = p.strip_edges()
				if pt == "True" or pt == "true":
					exp_fallback = true
				elif pt == "False" or pt == "false":
					exp_fallback = false
				elif (pt.begins_with('"') and pt.ends_with('"')) or (pt.begins_with("'") and pt.ends_with("'")):
					desc_fallback = pt.substr(1, pt.length() - 2)
			return {"args": args_fallback, "expected": exp_fallback, "desc": desc_fallback}
			
	return {}

# -----------------------------------------------------------------------------
# Syntax Validation & Error IntelliSense for IDE Real-Time Checker
# -----------------------------------------------------------------------------

const PYTHON_KEYWORDS: Dictionary = {
	"def": true, "class": true, "return": true, "pass": true, "lambda": true,
	"yield": true, "raise": true, "import": true, "from": true, "as": true,
	"global": true, "nonlocal": true, "assert": true, "del": true, "with": true,
	"try": true, "except": true, "finally": true, "async": true, "await": true,
	"if": true, "elif": true, "else": true, "for": true, "while": true,
	"break": true, "continue": true, "in": true, "is": true, "not": true,
	"and": true, "or": true, "match": true, "case": true, "_": true
}

# -----------------------------------------------------------------------------
# Converted builtins.pyi Data & Dynamic Stub Parser
# -----------------------------------------------------------------------------

static var _builtins_loaded: bool = false

# Baseline converted types from builtins.pyi (classes, exceptions, typing constructs)
static var PYTHON_KNOWN_TYPES: Dictionary = {
	"AbstractSet": true, "AnnotateFunc": true, "AnnotationForm": true, "Any": true,
	"ArithmeticError": true, "AssertionError": true, "AttributeError": true, "Awaitable": true,
	"BaseException": true, "BinaryIO": true, "BlockingIOError": true, "BrokenPipeError": true,
	"BufferError": true, "BufferedRandom": true, "BufferedReader": true, "BufferedWriter": true,
	"BytesWarning": true, "Callable": true, "CellType": true, "ChildProcessError": true,
	"ClassVar": true, "CodeType": true, "Concatenate": true, "ConnectionAbortedError": true,
	"ConnectionError": true, "ConnectionRefusedError": true, "ConnectionResetError": true,
	"ConvertibleToFloat": true, "ConvertibleToInt": true, "DeprecationWarning": true,
	"EOFError": true, "EllipsisType": true, "EncodingWarning": true, "Exception": true,
	"FileDescriptorOrPath": true, "FileExistsError": true, "FileIO": true, "FileNotFoundError": true,
	"Final": true, "FloatingPointError": true, "FutureWarning": true, "GeneratorExit": true,
	"Generic": true, "GenericAlias": true, "IO": true, "ImportError": true, "ImportWarning": true,
	"IndentationError": true, "IndexError": true, "InterruptedError": true, "IsADirectoryError": true,
	"Iterable": true, "Iterator": true, "KeyError": true, "KeyboardInterrupt": true, "Literal": true,
	"LiteralString": true, "LookupError": true, "Mapping": true, "MemoryError": true,
	"ModuleNotFoundError": true, "MutableMapping": true, "MutableSequence": true, "MutableSet": true,
	"NameError": true, "None": true, "NotADirectoryError": true, "NotImplementedError": true,
	"NotImplementedType": true, "OSError": true, "OpenBinaryMode": true,
	"OpenBinaryModeReading": true, "OpenBinaryModeUpdating": true, "OpenBinaryModeWriting": true,
	"OpenTextMode": true, "OverflowError": true, "ParamSpec": true, "PathLike": true,
	"PendingDeprecationWarning": true, "PermissionError": true, "ProcessLookupError": true,
	"Protocol": true, "ReadableBuffer": true, "RecursionError": true, "ReferenceError": true,
	"ResourceWarning": true, "Reversible": true, "RuntimeError": true, "RuntimeWarning": true,
	"Self": true, "Sequence": true, "Sized": true, "StopAsyncIteration": true, "StopIteration": true,
	"SupportsAbs": true, "SupportsAdd": true, "SupportsAiter": true, "SupportsAnext": true,
	"SupportsBytes": true, "SupportsComplex": true, "SupportsDivMod": true, "SupportsFloat": true,
	"SupportsFlush": true, "SupportsIndex": true, "SupportsIter": true,
	"SupportsKeysAndGetItem": true, "SupportsLenAndGetItem": true, "SupportsNext": true,
	"SupportsRAdd": true, "SupportsRDivMod": true, "SupportsRichComparison": true,
	"SupportsRichComparisonT": true, "SupportsWrite": true, "SyntaxError": true,
	"SyntaxWarning": true, "SystemError": true, "SystemExit": true, "TabError": true,
	"TextIOWrapper": true, "TimeoutError": true, "TracebackType": true, "TypeAlias": true,
	"TypeError": true, "TypeGuard": true, "TypeIs": true, "TypeVar": true, "TypeVarTuple": true,
	"UnboundLocalError": true, "UnicodeDecodeError": true, "UnicodeEncodeError": true,
	"UnicodeError": true, "UnicodeTranslateError": true, "UnicodeWarning": true, "UnionType": true,
	"UserWarning": true, "ValueError": true, "Warning": true, "ZeroDivisionError": true,
	"_FormatMapMapping": true, "_GetItemIterable": true, "_SupportsPow2": true, "_SupportsPow3": true,
	"_SupportsPow3NoneOnly": true, "_SupportsRound1": true, "_SupportsRound2": true,
	"_SupportsSumWithNoDefaultGiven": true, "_SupportsSynchronousAnext": true,
	"_SupportsWriteAndFlush": true, "_TranslateTable": true, "bool": true, "bytearray": true,
	"bytes": true, "classmethod": true, "complex": true, "deprecated": true, "dict": true,
	"dict_items": true, "dict_keys": true, "dict_values": true, "disjoint_base": true,
	"enumerate": true, "filter": true, "final": true, "float": true, "frozenset": true,
	"function": true, "int": true, "list": true, "map": true, "memoryview": true, "object": true,
	"overload": true, "property": true, "range": true, "reversed": true, "set": true, "slice": true,
	"staticmethod": true, "str": true, "super": true, "tuple": true, "type": true,
	"type_check_only": true, "zip": true
}

# Baseline converted built-in symbols (functions, types, constants)
static var PYTHON_BUILTINS: Dictionary = {
	"AbstractSet": true, "AnnotateFunc": true, "AnnotationForm": true, "Any": true,
	"ArithmeticError": true, "AssertionError": true, "AttributeError": true, "Awaitable": true,
	"BaseException": true, "BinaryIO": true, "BlockingIOError": true, "BrokenPipeError": true,
	"BufferError": true, "BufferedRandom": true, "BufferedReader": true, "BufferedWriter": true,
	"BytesWarning": true, "Callable": true, "CellType": true, "ChildProcessError": true,
	"ClassVar": true, "CodeType": true, "Concatenate": true, "ConnectionAbortedError": true,
	"ConnectionError": true, "ConnectionRefusedError": true, "ConnectionResetError": true,
	"ConvertibleToFloat": true, "ConvertibleToInt": true, "DeprecationWarning": true,
	"EOFError": true, "Ellipsis": true, "EllipsisType": true, "EncodingWarning": true,
	"Exception": true, "False": true, "FileDescriptorOrPath": true, "FileExistsError": true,
	"FileIO": true, "FileNotFoundError": true, "Final": true, "FloatingPointError": true,
	"FutureWarning": true, "GeneratorExit": true, "Generic": true, "GenericAlias": true, "IO": true,
	"ImportError": true, "ImportWarning": true, "IndentationError": true, "IndexError": true,
	"InterruptedError": true, "IsADirectoryError": true, "Iterable": true, "Iterator": true,
	"KeyError": true, "KeyboardInterrupt": true, "Literal": true, "LiteralString": true,
	"LookupError": true, "Mapping": true, "MemoryError": true, "ModuleNotFoundError": true,
	"MutableMapping": true, "MutableSequence": true, "MutableSet": true, "NameError": true,
	"None": true, "NotADirectoryError": true, "NotImplemented": true, "NotImplementedError": true,
	"NotImplementedType": true, "OSError": true, "OpenBinaryMode": true,
	"OpenBinaryModeReading": true, "OpenBinaryModeUpdating": true, "OpenBinaryModeWriting": true,
	"OpenTextMode": true, "OverflowError": true, "ParamSpec": true, "PathLike": true,
	"PendingDeprecationWarning": true, "PermissionError": true, "ProcessLookupError": true,
	"Protocol": true, "ReadableBuffer": true, "RecursionError": true, "ReferenceError": true,
	"ResourceWarning": true, "Reversible": true, "RuntimeError": true, "RuntimeWarning": true,
	"Self": true, "Sequence": true, "Sized": true, "StopAsyncIteration": true, "StopIteration": true,
	"SupportsAbs": true, "SupportsAdd": true, "SupportsAiter": true, "SupportsAnext": true,
	"SupportsBytes": true, "SupportsComplex": true, "SupportsDivMod": true, "SupportsFloat": true,
	"SupportsFlush": true, "SupportsIndex": true, "SupportsIter": true,
	"SupportsKeysAndGetItem": true, "SupportsLenAndGetItem": true, "SupportsNext": true,
	"SupportsRAdd": true, "SupportsRDivMod": true, "SupportsRichComparison": true,
	"SupportsRichComparisonT": true, "SupportsWrite": true, "SyntaxError": true,
	"SyntaxWarning": true, "SystemError": true, "SystemExit": true, "TabError": true,
	"TextIOWrapper": true, "TimeoutError": true, "TracebackType": true, "True": true,
	"TypeAlias": true, "TypeError": true, "TypeGuard": true, "TypeIs": true, "TypeVar": true,
	"TypeVarTuple": true, "UnboundLocalError": true, "UnicodeDecodeError": true,
	"UnicodeEncodeError": true, "UnicodeError": true, "UnicodeTranslateError": true,
	"UnicodeWarning": true, "UnionType": true, "UserWarning": true, "ValueError": true,
	"Warning": true, "ZeroDivisionError": true, "_FormatMapMapping": true, "_GetItemIterable": true,
	"_SupportsPow2": true, "_SupportsPow3": true, "_SupportsPow3NoneOnly": true,
	"_SupportsRound1": true, "_SupportsRound2": true, "_SupportsSumWithNoDefaultGiven": true,
	"_SupportsSynchronousAnext": true, "_SupportsWriteAndFlush": true, "_TranslateTable": true,
	"abs": true, "aiter": true, "all": true, "anext": true, "any": true, "ascii": true, "bool": true,
	"breakpoint": true, "bytearray": true, "bytes": true, "callable": true, "chr": true,
	"classmethod": true, "cls": true, "complex": true, "copyright": true, "credits": true,
	"delattr": true, "deprecated": true, "dict": true, "dict_items": true, "dict_keys": true,
	"dict_values": true, "dir": true, "disjoint_base": true, "divmod": true, "enumerate": true,
	"exit": true, "filter": true, "final": true, "float": true, "format": true, "frozenset": true,
	"function": true, "getattr": true, "globals": true, "hasattr": true, "hash": true, "help": true,
	"id": true, "input": true, "int": true, "isinstance": true, "issubclass": true, "iter": true,
	"len": true, "license": true, "list": true, "locals": true, "map": true, "max": true,
	"memoryview": true, "min": true, "next": true, "object": true, "open": true, "ord": true,
	"overload": true, "pow": true, "print": true, "property": true, "quit": true, "range": true,
	"repr": true, "reversed": true, "round": true, "self": true, "set": true, "setattr": true,
	"slice": true, "sorted": true, "staticmethod": true, "str": true, "sum": true, "super": true,
	"tuple": true, "type": true, "type_check_only": true, "vars": true, "zip": true,
	"__name__": true, "__doc__": true, "__file__": true, "__package__": true, "__spec__": true,
	"__annotations__": true, "__dict__": true
}

# Baseline converted method names across all standard types in builtins.pyi
static var COMMON_METHOD_NAMES: Dictionary = {
	"add": true, "add_note": true, "append": true, "as_integer_ratio": true, "bin": true,
	"bit_count": true, "bit_length": true, "c_contiguous": true, "capitalize": true, "casefold": true,
	"cast": true, "center": true, "cmeth": true, "compile": true, "conjugate": true,
	"contiguous": true, "copy": true, "count": true, "decode": true, "deleter": true, "delx": true,
	"denominator": true, "derive": true, "difference": true, "difference_update": true,
	"discard": true, "encode": true, "endswith": true, "eval": true, "exceptions": true, "exec": true,
	"expandtabs": true, "extend": true, "f": true, "f_contiguous": true, "find": true, "format": true,
	"format_map": true, "from_bytes": true, "from_number": true, "fromhex": true, "fromkeys": true,
	"get": true, "getter": true, "getx": true, "hex": true, "imag": true, "index": true,
	"indices": true, "insert": true, "intersection": true, "intersection_update": true,
	"is_integer": true, "isalnum": true, "isalpha": true, "isascii": true, "isdecimal": true,
	"isdigit": true, "isdisjoint": true, "isidentifier": true, "islower": true, "isnumeric": true,
	"isprintable": true, "isspace": true, "issubset": true, "issuperset": true, "istitle": true,
	"isupper": true, "items": true, "itemsize": true, "join": true, "keys": true, "ljust": true,
	"lower": true, "lstrip": true, "maketrans": true, "message": true, "meth": true, "mro": true,
	"nbytes": true, "ndim": true, "numerator": true, "obj": true, "oct": true, "partition": true,
	"pop": true, "readonly": true, "real": true, "release": true, "remove": true,
	"removeprefix": true, "removesuffix": true, "replace": true, "resize": true, "rfind": true,
	"rindex": true, "rjust": true, "rpartition": true, "rsplit": true, "rstrip": true, "setter": true,
	"setx": true, "shape": true, "sort": true, "split": true, "splitlines": true, "start": true,
	"startswith": true, "step": true, "stop": true, "strides": true, "strip": true, "subgroup": true,
	"suboffsets": true, "swapcase": true, "symmetric_difference": true,
	"symmetric_difference_update": true, "take_bytes": true, "title": true, "to_bytes": true,
	"tobytes": true, "tolist": true, "toreadonly": true, "translate": true, "union": true,
	"update": true, "upper": true, "values": true, "with_traceback": true, "x": true, "zfill": true
}


# Parsed docstrings and signatures from builtins.pyi
static var BUILTIN_DOCS: Dictionary = {}

## Data-driven augmented-assignment compatibility table.
## Format: { lhs_type: { op: [valid_rhs_types] } }
## If a type is not listed as an lhs_type, the operator is unsupported for it.
static var _AUG_OP_COMPAT: Dictionary = {
	"str":   { "+=":  ["str"],
			   "*=":  ["int", "bool"],
			   "%=":  ["str", "int", "float", "bool", "list", "tuple", "dict"] },
	"bytes": { "+=":  ["bytes"],
			   "*=":  ["int", "bool"] },
	"int":   { "+=":  ["int", "float", "bool"],
			   "-=":  ["int", "float", "bool"],
			   "*=":  ["int", "float", "bool"],
			   "/=":  ["int", "float", "bool"],
			   "//=":  ["int", "float", "bool"],
			   "%=":  ["int", "float", "bool"],
			   "**=": ["int", "float", "bool"],
			   "|=":  ["int", "bool"],
			   "&=":  ["int", "bool"],
			   "^=":  ["int", "bool"] },
	"float": { "+=":  ["int", "float", "bool"],
			   "-=":  ["int", "float", "bool"],
			   "*=":  ["int", "float", "bool"],
			   "/=":  ["int", "float", "bool"],
			   "//=":  ["int", "float", "bool"],
			   "%=":  ["int", "float", "bool"],
			   "**=": ["int", "float", "bool"] },
	"bool":  { "+=":  ["int", "float", "bool"],
			   "-=":  ["int", "float", "bool"],
			   "*=":  ["int", "float", "bool"],
			   "/=":  ["int", "float", "bool"],
			   "//=":  ["int", "float", "bool"],
			   "%=":  ["int", "float", "bool"],
			   "**=": ["int", "float", "bool"],
			   "|=":  ["int", "bool"],
			   "&=":  ["int", "bool"],
			   "^=":  ["int", "bool"] },
	"list":  { "+=":  ["list"],
			   "*=":  ["int", "bool"] },
	"tuple": { "+=":  ["tuple"],
			   "*=":  ["int", "bool"] },
	"set":   { "|=":  ["set", "frozenset"],
			   "&=":  ["set", "frozenset"],
			   "-=":  ["set", "frozenset"],
			   "^=":  ["set", "frozenset"] },
	"frozenset": { "|=": ["frozenset", "set"],
				   "&=": ["frozenset", "set"],
				   "-=": ["frozenset", "set"],
				   "^=": ["frozenset", "set"] },
	"dict":  { "|=":  ["dict"] },
}

## Dynamically loads and parses builtins.pyi to update all types, symbols, methods, and docstrings.
static func load_builtins_from_pyi(pyi_path: String = "") -> void:
	var candidate_paths: Array[String] = [
		"res://scenes/ide/builtins.pyi",
		"res://ide/builtins.pyi",
		"res://builtins.pyi"
	]
	if not pyi_path.is_empty():
		candidate_paths.push_front(pyi_path)
		
	var target_path = ""
	for p in candidate_paths:
		if FileAccess.file_exists(p):
			target_path = p
			break
			
	if target_path.is_empty():
		_builtins_loaded = true
		return
		
	var file = FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		_builtins_loaded = true
		return
		
	var content = file.get_as_text()
	file.close()
	
	var in_multiline_import = false
	var current_doc_name = ""
	var current_doc_sig = ""
	var current_doc_kind = "function"
	var in_docstring = false
	var quote_char = '"""'
	var doc_lines: Array[String] = []
	
	for raw_line in content.split("\n"):
		var no_comment = raw_line.split("#")[0]
		var line = no_comment.strip_edges(false, true)
		var stripped = line.strip_edges()
		
		if in_docstring:
			if quote_char in stripped:
				var end_part = stripped.split(quote_char)[0]
				if not end_part.strip_edges().is_empty():
					doc_lines.append(end_part.strip_edges())
				in_docstring = false
				if not current_doc_name.is_empty() and not BUILTIN_DOCS.has(current_doc_name):
					BUILTIN_DOCS[current_doc_name] = {
						"signature": current_doc_sig,
						"kind": current_doc_kind,
						"docstring": "\n".join(doc_lines).strip_edges()
					}
				current_doc_name = ""
				doc_lines.clear()
			else:
				var clean_item = raw_line.strip_edges()
				if not clean_item.is_empty():
					doc_lines.append(clean_item)
			continue
			
		if stripped.is_empty():
			continue
			
		# Handle multiline imports: from typing import ( ... )
		if in_multiline_import:
			var part = stripped
			if ")" in part:
				part = part.split(")")[0]
				in_multiline_import = false
			for piece in part.split(","):
				var p = piece.strip_edges().split(" as ")[-1].strip_edges()
				if not p.is_empty() and _is_valid_identifier_static(p):
					PYTHON_KNOWN_TYPES[p] = true
					PYTHON_BUILTINS[p] = true
			continue
			
		if stripped.begins_with("from ") and " import (" in stripped:
			in_multiline_import = true
			continue
		elif stripped.begins_with("from ") and " import " in stripped:
			var after_import = stripped.split(" import ")[1]
			for piece in after_import.split(","):
				var p = piece.strip_edges().split(" as ")[-1].strip_edges()
				if not p.is_empty() and _is_valid_identifier_static(p):
					PYTHON_KNOWN_TYPES[p] = true
					PYTHON_BUILTINS[p] = true
			continue
			
		var indent = line.length() - line.strip_edges(true, false).length()
		if indent == 0:
			if stripped.begins_with("class "):
				var after_cls = stripped.substr(6).strip_edges()
				var cname = after_cls.split("(")[0].split(":")[0].strip_edges()
				if not cname.is_empty() and _is_valid_identifier_static(cname):
					PYTHON_KNOWN_TYPES[cname] = true
					PYTHON_BUILTINS[cname] = true
					current_doc_name = cname
					current_doc_sig = stripped.split(":")[0].strip_edges()
					current_doc_kind = "class"
			elif stripped.begins_with("def ") or stripped.begins_with("async def "):
				var after_def = stripped.split("def ")[1].strip_edges()
				var fname = after_def.split("(")[0].strip_edges()
				if not fname.is_empty() and not fname.begins_with("__") and _is_valid_identifier_static(fname):
					PYTHON_BUILTINS[fname] = true
					current_doc_name = fname
					current_doc_sig = stripped.split(":")[0].strip_edges()
					current_doc_kind = "function"
			elif ":" in stripped and not stripped.begins_with("@") and not stripped.begins_with("if ") and not stripped.begins_with("elif ") and not stripped.begins_with("else"):
				var vname = stripped.split(":")[0].strip_edges()
				if not vname.is_empty() and not vname.begins_with("_") and _is_valid_identifier_static(vname):
					PYTHON_BUILTINS[vname] = true
		elif indent >= 4 and stripped.begins_with("def "):
			var after_def = stripped.substr(4).strip_edges()
			var mname = after_def.split("(")[0].strip_edges()
			if not mname.is_empty() and not mname.begins_with("__") and _is_valid_identifier_static(mname):
				COMMON_METHOD_NAMES[mname] = true
				current_doc_name = mname
				current_doc_sig = stripped.split(":")[0].strip_edges()
				current_doc_kind = "method"
				
		# Check if line initiates a docstring
		if '"""' in stripped or "'''" in stripped:
			quote_char = '"""' if '"""' in stripped else "'''"
			var q_pos = stripped.find(quote_char)
			var rest = stripped.substr(q_pos + 3)
			if quote_char in rest:
				var doc_text = rest.split(quote_char)[0].strip_edges()
				if not current_doc_name.is_empty() and not BUILTIN_DOCS.has(current_doc_name):
					BUILTIN_DOCS[current_doc_name] = {
						"signature": current_doc_sig,
						"kind": current_doc_kind,
						"docstring": doc_text
					}
				current_doc_name = ""
			else:
				in_docstring = true
				doc_lines = [rest.strip_edges()]
				
	_builtins_loaded = true

## Static identifier validator for parser utility
static func _is_valid_identifier_static(s: String) -> bool:
	if s.is_empty():
		return false
	var first = s[0]
	if not ((first >= 'a' and first <= 'z') or (first >= 'A' and first <= 'Z') or first == '_'):
		return false
	for i in range(1, s.length()):
		var c = s[i]
		if not ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_'):
			return false
	return true

static func _ensure_builtins_initialized() -> void:
	if not _builtins_loaded:
		load_builtins_from_pyi()


## Infers the base Python type for a receiver variable name from source code.
static func infer_receiver_type(receiver_name: String, source_code: String) -> String:
	if receiver_name.is_empty() or source_code.is_empty():
		return ""
	if receiver_name in ["dict", "str", "list", "set", "tuple", "bytes"]:
		return receiver_name
		
	var lines = source_code.split("\n")
	for line in lines:
		var stripped = line.strip_edges()
		# Check parameter type annotations in def signatures
		if stripped.begins_with("def ") or stripped.begins_with("async def "):
			var paren_open = stripped.find("(")
			var paren_close = stripped.rfind(")")
			if paren_open != -1 and paren_close != -1:
				var params_str = stripped.substr(paren_open + 1, paren_close - paren_open - 1)
				for p in params_str.split(","):
					var p_clean = p.strip_edges()
					if ":" in p_clean:
						var parts = p_clean.split(":")
						var p_var = parts[0].split("=")[0].strip_edges().trim_prefix("*").trim_prefix("*")
						if p_var == receiver_name:
							var type_part = parts[1].split("=")[0].strip_edges()
							var base_type = type_part.split("[")[0].split("|")[0].strip_edges()
							return base_type
							
		# Check local variable assignments e.g. data = {} or data = dict()
		if "=" in stripped and not stripped.begins_with("if ") and not stripped.begins_with("while "):
			var eq_idx = stripped.find("=")
			if eq_idx > 0 and stripped[eq_idx - 1] not in ["=", "!", "<", ">"]:
				var lhs = stripped.substr(0, eq_idx).strip_edges()
				var rhs = stripped.substr(eq_idx + 1).strip_edges()
				if lhs == receiver_name:
					if rhs.begins_with("{") or rhs.begins_with("dict("):
						return "dict"
					elif rhs.begins_with("[") or rhs.begins_with("list("):
						return "list"
					elif rhs.begins_with('"') or rhs.begins_with("'") or rhs.begins_with("str("):
						return "str"
					elif rhs.begins_with("set("):
						return "set"
	return ""

## Retrieves documentation and docstring for a function, class, or method.
## Respects receiver type inference: if receiver type is unannotated, method docs are NOT returned.
static func get_symbol_doc(symbol_name: String, source_code: String = "", receiver_name: String = "") -> Dictionary:
	if symbol_name.is_empty():
		return {"found": false}
		
	# 1. If accessed via dot (receiver.method):
	if not receiver_name.is_empty():
		var rec_type = infer_receiver_type(receiver_name, source_code)
		if rec_type.is_empty():
			# Receiver has no type specified -> DO NOT recognize method!
			return {"found": false}
			
		_ensure_builtins_initialized()
		var key = "%s.%s" % [rec_type, symbol_name]
		if BUILTIN_DOCS.has(key):
			var bdoc = BUILTIN_DOCS[key]
			return {
				"found": true,
				"name": symbol_name,
				"signature": "(method) %s.%s%s" % [rec_type, symbol_name, bdoc.get("signature", "")],
				"kind": "method",
				"receiver_type": rec_type,
				"docstring": bdoc.get("docstring", "")
			}
		elif BUILTIN_DOCS.has(symbol_name):
			var bdoc = BUILTIN_DOCS[symbol_name]
			return {
				"found": true,
				"name": symbol_name,
				"signature": "(method) %s.%s(...)" % [rec_type, symbol_name],
				"kind": "method",
				"receiver_type": rec_type,
				"docstring": bdoc.get("docstring", "")
			}
		elif COMMON_METHOD_NAMES.has(symbol_name):
			return {
				"found": true,
				"name": symbol_name,
				"signature": "(method) %s.%s(...)" % [rec_type, symbol_name],
				"kind": "method",
				"receiver_type": rec_type,
				"docstring": "Method '%s' on %s." % [symbol_name, rec_type]
			}
		return {"found": false}
		
	# 2. Check user source code for functions and classes
	if not source_code.is_empty():
		var lines = source_code.split("\n")
		for i in range(lines.size()):
			var line = lines[i]
			var stripped = line.strip_edges()
			if stripped.begins_with("def " + symbol_name + "(") or stripped.begins_with("async def " + symbol_name + "(") or stripped.begins_with("class " + symbol_name + "(") or stripped.begins_with("class " + symbol_name + ":"):
				var is_class = stripped.begins_with("class ")
				var sig = stripped
				var j = i
				while not (sig.contains(")") and sig.ends_with(":")) and not (is_class and sig.ends_with(":")) and j + 1 < lines.size():
					j += 1
					sig += " " + lines[j].strip_edges()
				if sig.ends_with(":"):
					sig = sig.substr(0, sig.length() - 1).strip_edges()
					
				var docstring = ""
				var k = j + 1
				while k < lines.size() and (lines[k].strip_edges().is_empty() or lines[k].strip_edges().begins_with("#")):
					k += 1
				if k < lines.size():
					var k_stripped = lines[k].strip_edges()
					if k_stripped.begins_with('"""') or k_stripped.begins_with("'''"):
						var q = '"""' if k_stripped.begins_with('"""') else "'''"
						var rest = k_stripped.substr(3)
						if rest.contains(q):
							docstring = rest.split(q)[0].strip_edges()
						else:
							var doc_parts: Array[String] = []
							if not rest.strip_edges().is_empty():
								doc_parts.append(rest.strip_edges())
							var m = k + 1
							while m < lines.size():
								var m_stripped = lines[m].strip_edges()
								if m_stripped.contains(q):
									var end_doc = m_stripped.split(q)[0].strip_edges()
									if not end_doc.is_empty():
										doc_parts.append(end_doc)
									break
								else:
									doc_parts.append(lines[m].strip_edges())
								m += 1
							docstring = "\n".join(doc_parts).strip_edges()
							
				return {
					"found": true,
					"name": symbol_name,
					"signature": "(%s) %s" % ["class" if is_class else "function", sig],
					"kind": "class" if is_class else "function",
					"docstring": docstring if not docstring.is_empty() else "User-defined %s." % ("class" if is_class else "function")
				}
				
		# Check if symbol_name is a parameter in user functions e.g. packet in def validate_packet(packet: dict)
		for line in lines:
			var stripped = line.strip_edges()
			if stripped.begins_with("def ") or stripped.begins_with("async def "):
				var paren_open = stripped.find("(")
				var paren_close = stripped.rfind(")")
				if paren_open != -1 and paren_close != -1:
					var params_str = stripped.substr(paren_open + 1, paren_close - paren_open - 1)
					for p in params_str.split(","):
						var p_clean = p.strip_edges()
						var p_var = p_clean.split(":")[0].split("=")[0].strip_edges().trim_prefix("*").trim_prefix("*")
						if p_var == symbol_name:
							var p_type = p_clean.split(":")[1].split("=")[0].strip_edges() if ":" in p_clean else "Any"
							return {
								"found": true,
								"name": symbol_name,
								"signature": "(parameter) %s: %s" % [symbol_name, p_type],
								"kind": "variable",
								"docstring": "Parameter '%s' of type '%s'." % [symbol_name, p_type]
							}

	# 3. Check builtins
	_ensure_builtins_initialized()
	if BUILTIN_DOCS.has(symbol_name):
		var bdoc = BUILTIN_DOCS[symbol_name]
		var bkind = bdoc.get("kind", "builtin")
		return {
			"found": true,
			"name": symbol_name,
			"signature": "(%s) %s" % [bkind, bdoc.get("signature", symbol_name)],
			"kind": bkind,
			"docstring": bdoc.get("docstring", "")
		}
		
	if PYTHON_BUILTINS.has(symbol_name):
		var kind = "class" if PYTHON_KNOWN_TYPES.has(symbol_name) else "function"
		return {
			"found": true,
			"name": symbol_name,
			"signature": "(%s) %s" % [kind, symbol_name],
			"kind": kind,
			"docstring": "Python built-in %s." % kind
		}
		
	return {"found": false}


## Checks Python syntax and returns a list of error dictionaries for the PROBLEMS tab and editor gutters.
func validate_python_syntax(code: String, filename: String) -> Array[Dictionary]:
	_ensure_builtins_initialized()
	var errors: Array[Dictionary] = []
	var lines = code.split("\n")
	
	# -------------------------------------------------------------------------
	# Pass 1: Collect all declared symbols (functions, classes, imports, globals)
	# -------------------------------------------------------------------------
	var global_symbols: Dictionary = {}
	for k in PYTHON_BUILTINS.keys():
		global_symbols[k] = true
		
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.begins_with("#") or trimmed.is_empty():
			continue
			
		# Functions: def func_name(
		if trimmed.begins_with("def "):
			var after_def = trimmed.substr(4).strip_edges()
			var p_idx = after_def.find("(")
			if p_idx != -1:
				var fn_name = after_def.substr(0, p_idx).strip_edges()
				if _is_valid_identifier(fn_name):
					global_symbols[fn_name] = true
					
		# Classes: class ClassName
		elif trimmed.begins_with("class "):
			var after_cls = trimmed.substr(6).strip_edges()
			var p_idx = after_cls.find("(")
			var colon_idx = after_cls.find(":")
			var end_idx = p_idx if p_idx != -1 else colon_idx
			if end_idx != -1:
				var cls_name = after_cls.substr(0, end_idx).strip_edges()
				if _is_valid_identifier(cls_name):
					global_symbols[cls_name] = true
					
		# Imports: import math, sys / from math import sqrt, pi
		elif trimmed.begins_with("import "):
			var mods = trimmed.substr(7).split(",")
			for m in mods:
				var mod_name = m.strip_edges().split(" ")[0].strip_edges()
				if _is_valid_identifier(mod_name):
					global_symbols[mod_name] = true
		elif trimmed.begins_with("from "):
			var import_pos = trimmed.find(" import ")
			if import_pos != -1:
				var items = trimmed.substr(import_pos + 8).split(",")
				for item in items:
					var item_name = item.strip_edges().split(" ")[0].strip_edges()
					if _is_valid_identifier(item_name):
						global_symbols[item_name] = true
						
		# Root-level assignments & variable type annotations: x = 10, name: str, count: int = 0
		var root_indent = line.length() - line.strip_edges(true, false).length()
		if root_indent == 0:
			if trimmed.contains(":") and not trimmed.begins_with("if") and not trimmed.begins_with("while") and not trimmed.begins_with("for") and not trimmed.begins_with("try") and not trimmed.begins_with("except") and not trimmed.begins_with("finally") and not trimmed.begins_with("with") and not trimmed.begins_with("match") and not trimmed.begins_with("case"):
				var lhs_annot = trimmed.split(":")[0].strip_edges()
				if _is_valid_identifier(lhs_annot):
					global_symbols[lhs_annot] = true
			elif trimmed.contains("=") and not trimmed.begins_with("if") and not trimmed.begins_with("while") and not trimmed.begins_with("for"):
				var eq_idx = trimmed.find("=")
				if eq_idx != -1 and (eq_idx == 0 or trimmed[eq_idx - 1] not in ["=", "!", "<", ">", "+", "-", "*", "/"]):
					var lhs = trimmed.substr(0, eq_idx).strip_edges()
					for target in _extract_target_identifiers(lhs):
						global_symbols[target] = true

	# -------------------------------------------------------------------------
	# Pass 2: Line-by-line detailed syntax, structure, and name validation
	# -------------------------------------------------------------------------
	var in_docstring = false
	var docstring_marker = ""
	var paren_stack: Array[Dictionary] = []
	var previous_header_indent = -1
	var previous_header_line = -1
	var current_scope_stack: Array[Dictionary] = [] # Stack of { "indent": int, "symbols": Dictionary }
	var var_types: Dictionary = {}  # var_name -> inferred literal type (str/int/float/list/…)
	
	for idx in range(lines.size()):
		var line_num = idx + 1
		var raw_line = lines[idx]
		var trimmed = raw_line.strip_edges()
		var line_indent = raw_line.length() - raw_line.strip_edges(true, false).length()
		
		# Check docstrings
		if in_docstring:
			if trimmed.contains(docstring_marker):
				in_docstring = false
			continue
		else:
			if trimmed.begins_with('"""') or trimmed.begins_with("'''"):
				docstring_marker = trimmed.substr(0, 3)
				var rest = trimmed.substr(3)
				if not rest.contains(docstring_marker):
					in_docstring = true
				continue
				
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
			
		# Scope management by indentation
		while not current_scope_stack.is_empty() and line_indent <= current_scope_stack.back()["indent"] and paren_stack.is_empty():
			current_scope_stack.pop_back()
			
		# 1. Indentation check after statement header
		if previous_header_indent != -1:
			if line_indent <= previous_header_indent and paren_stack.is_empty():
				errors.append({
					"file": filename,
					"line": line_num,
					"message": "IndentationError: expected an indented block after statement on line %d" % previous_header_line,
					"snippet": trimmed
				})
			previous_header_indent = -1
			previous_header_line = -1
			
		# 2. Colon check for compound statement headers
		if paren_stack.is_empty():
			var block_headers = ["def ", "if ", "elif ", "else:", "for ", "while ", "class ", "try:", "except", "finally:", "match ", "case "]
			for header in block_headers:
				if trimmed.begins_with(header) or trimmed == header.replace(":", ""):
					var without_comment = trimmed.split("#")[0].strip_edges()
					var header_colon_pos = -1
					var p_depth = 0
					var in_q = false
					var q_c = ""
					for c_i in range(without_comment.length()):
						var c_ch = without_comment[c_i]
						if not in_q:
							if c_ch == '"' or c_ch == "'":
								in_q = true
								q_c = c_ch
							elif c_ch in ["(", "[", "{"]:
								p_depth += 1
							elif c_ch in [")", "]", "}"]:
								p_depth = max(0, p_depth - 1)
							elif c_ch == ':' and p_depth == 0:
								header_colon_pos = c_i
								break
						else:
							if c_ch == q_c and (c_i == 0 or without_comment[c_i - 1] != '\\'):
								in_q = false
					
					if header_colon_pos == -1:
						if p_depth == 0 and not without_comment.ends_with("\\"):
							errors.append({
								"file": filename,
								"line": line_num,
								"message": "SyntaxError: expected ':' at end of '%s' statement" % header.strip_edges(),
								"snippet": trimmed
							})
					else:
						var after_colon = without_comment.substr(header_colon_pos + 1).strip_edges()
						if after_colon.is_empty():
							previous_header_indent = line_indent
							previous_header_line = line_num
					break
					
		# Function definition: add parameters to function scope
		if trimmed.begins_with("def "):
			var paren_open = trimmed.find("(")
			var paren_close = -1
			if paren_open != -1:
				var p_depth = 0
				var in_q = false
				var q_c = ""
				for c_i in range(paren_open, trimmed.length()):
					var c_ch = trimmed[c_i]
					if not in_q:
						if c_ch == '"' or c_ch == "'":
							in_q = true
							q_c = c_ch
						elif c_ch == '(':
							p_depth += 1
						elif c_ch == ')':
							p_depth -= 1
							if p_depth == 0:
								paren_close = c_i
								break
					else:
						if c_ch == q_c and (c_i == 0 or trimmed[c_i - 1] != '\\'):
							in_q = false
			if paren_open == -1 or paren_close == -1 or paren_close < paren_open:
				errors.append({
					"file": filename,
					"line": line_num,
					"message": "SyntaxError: invalid function definition syntax",
					"snippet": trimmed
				})
			else:
				var fn_name = trimmed.substr(4, paren_open - 4).strip_edges()
				if not _is_valid_identifier(fn_name):
					errors.append({
						"file": filename,
						"line": line_num,
						"message": "SyntaxError: invalid function name '%s'" % fn_name,
						"snippet": trimmed
					})
				var params_str = trimmed.substr(paren_open + 1, paren_close - paren_open - 1)
				var fn_scope: Dictionary = {}
				for param in params_str.split(","):
					# Strip leading * / ** for *args / **kwargs
					var p_trimmed = param.strip_edges().trim_prefix("**").trim_prefix("*").strip_edges()
					if p_trimmed.is_empty():
						continue
					# Split off default value first, then check for annotation
					var p_no_default = p_trimmed.split("=")[0].strip_edges()
					var colon_idx = p_no_default.find(":")
					var p_name: String
					var p_annotation: String
					if colon_idx != -1:
						p_name = p_no_default.substr(0, colon_idx).strip_edges()
						p_annotation = p_no_default.substr(colon_idx + 1).strip_edges()
					else:
						p_name = p_no_default
						p_annotation = ""
					# Validate param name
					if p_name.is_empty():
						continue
					if not _is_valid_identifier(p_name):
						errors.append({
							"file": filename,
							"line": line_num,
							"message": "SyntaxError: invalid parameter name '%s'" % p_name,
							"snippet": trimmed
						})
					else:
						fn_scope[p_name] = true
						# Validate type annotation if the colon was present
						if colon_idx != -1:
							if p_annotation.is_empty():
								errors.append({
									"file": filename,
									"line": line_num,
									"message": "SyntaxError: expected type annotation after ':' for parameter '%s'" % p_name,
									"snippet": trimmed
								})
							else:
								# Extract base type name (before '[', '|', or whitespace for complex types)
								var base_type = p_annotation.split("[")[0].split("|")[0].strip_edges()
								if not _is_valid_identifier(base_type):
									errors.append({
										"file": filename,
										"line": line_num,
										"message": "SyntaxError: invalid type annotation '%s' for parameter '%s'" % [p_annotation, p_name],
										"snippet": trimmed
									})
								elif not PYTHON_KNOWN_TYPES.has(base_type) and not global_symbols.has(base_type):
									errors.append({
										"file": filename,
										"line": line_num,
										"message": "NameError: type '%s' is not defined (unknown type annotation for parameter '%s')" % [base_type, p_name],
										"snippet": trimmed
									})
				current_scope_stack.append({"indent": line_indent, "symbols": fn_scope})
				
		# Loop variables: for var in iter:
		elif trimmed.begins_with("for "):
			var in_pos = trimmed.find(" in ")
			if in_pos != -1:
				var loop_var = trimmed.substr(4, in_pos - 4).strip_edges()
				for v in _extract_target_identifiers(loop_var):
					_add_to_current_scope(current_scope_stack, global_symbols, v)
			else:
				errors.append({
					"file": filename,
					"line": line_num,
					"message": "SyntaxError: invalid 'for' loop (missing 'in')",
					"snippet": trimmed
				})
				
		# Exception binding: except ... as var_name:
		elif trimmed.begins_with("except"):
			var as_pos = trimmed.find(" as ")
			if as_pos != -1:
				var colon_pos = trimmed.rfind(":")
				if colon_pos > as_pos:
					var ex_var = trimmed.substr(as_pos + 4, colon_pos - (as_pos + 4)).strip_edges()
					if _is_valid_identifier(ex_var):
						_add_to_current_scope(current_scope_stack, global_symbols, ex_var)
				
		# Variable type annotations in class bodies / functions: name: str, battery: int = 100
		if trimmed.contains(":") and not trimmed.begins_with("def ") and not trimmed.begins_with("class ") and not trimmed.begins_with("if ") and not trimmed.begins_with("elif ") and not trimmed.begins_with("else") and not trimmed.begins_with("for ") and not trimmed.begins_with("while ") and not trimmed.begins_with("try") and not trimmed.begins_with("except") and not trimmed.begins_with("finally") and not trimmed.begins_with("with ") and not trimmed.begins_with("match ") and not trimmed.begins_with("case ") and not trimmed.begins_with("lambda "):
			var colon_pos = trimmed.find(":")
			if colon_pos != -1:
				var possible_decl = trimmed.substr(0, colon_pos).strip_edges()
				if _is_valid_identifier(possible_decl):
					_add_to_current_scope(current_scope_stack, global_symbols, possible_decl)

		# Variable assignments: x = ..., x += ...
		var assign_match = _extract_assignment_lhs(trimmed)
		if not assign_match.is_empty():
			for target in _extract_target_identifiers(assign_match):
				_add_to_current_scope(current_scope_stack, global_symbols, target)
					
		# Type-inference and type-mismatch check for augmented assignments
		var _asgn_info = _get_assignment_info(trimmed)
		if not _asgn_info.is_empty():
			var _lv: String = _asgn_info.get("lhs", "")
			var _op: String = _asgn_info.get("op", "")
			var _rv: String = _asgn_info.get("rhs", "")
			if _is_valid_identifier(_lv):
				if _op == "=":
					# Plain assignment: infer and track the type
					var _it = _infer_literal_type(_rv)
					if not _it.is_empty():
						var_types[_lv] = _it
				else:
					# Augmented assignment: check compatibility
					if var_types.has(_lv):
						var _lt: String = var_types[_lv]
						var _rt: String = _infer_literal_type(_rv)
						if not _rt.is_empty() and not _is_aug_op_compatible(_lt, _op, _rt):
							errors.append({
								"file": filename,
								"line": line_num,
								"message": "TypeError: unsupported operand type(s) for %s: '%s' and '%s'" % [_op, _lt, _rt],
								"snippet": trimmed
							})
					
		# Strip string literals and comments for token inspection
		var clean_line = _strip_strings_and_comments_for_lint(raw_line)
		
		# 3. Misspelled keywords and invalid literals
		var misspelled = {
			"retrun": "return", "retun": "return", "reutrn": "return",
			"whlie": "while", "wihle": "while",
			"elsif": "elif", "elseif": "elif",
			"function": "def", "func": "def"
		}
		var tokens = _tokenize_for_translation(clean_line)
		for tok in tokens:
			if misspelled.has(tok):
				errors.append({
					"file": filename,
					"line": line_num,
					"message": "SyntaxError: invalid keyword '%s' (did you mean '%s'?)" % [tok, misspelled[tok]],
					"snippet": trimmed
				})
			elif tok == "true":
				errors.append({
					"file": filename,
					"line": line_num,
					"message": "NameError: name 'true' is not defined (did you mean 'True'?)",
					"snippet": trimmed
				})
			elif tok == "false":
				errors.append({
					"file": filename,
					"line": line_num,
					"message": "NameError: name 'false' is not defined (did you mean 'False'?)",
					"snippet": trimmed
				})
			elif tok == "null":
				errors.append({
					"file": filename,
					"line": line_num,
					"message": "NameError: name 'null' is not defined (did you mean 'None'?)",
					"snippet": trimmed
				})
				
		# 4. Invalid operators
		if clean_line.contains("&&"):
			errors.append({
				"file": filename,
				"line": line_num,
				"message": "SyntaxError: '&&' is not valid in Python (use 'and')",
				"snippet": trimmed
			})
		if clean_line.contains("||"):
			errors.append({
				"file": filename,
				"line": line_num,
				"message": "SyntaxError: '||' is not valid in Python (use 'or')",
				"snippet": trimmed
			})
		if clean_line.contains("==="):
			errors.append({
				"file": filename,
				"line": line_num,
				"message": "SyntaxError: '===' is not valid in Python (use '==')",
				"snippet": trimmed
			})
		if clean_line.contains("!=="):
			errors.append({
				"file": filename,
				"line": line_num,
				"message": "SyntaxError: '!==' is not valid in Python (use '!=')",
				"snippet": trimmed
			})
		if clean_line.contains("++"):
			errors.append({
				"file": filename,
				"line": line_num,
				"message": "SyntaxError: '++' is not valid in Python (use '+= 1')",
				"snippet": trimmed
			})
		if clean_line.contains("--") and not clean_line.contains("---"):
			errors.append({
				"file": filename,
				"line": line_num,
				"message": "SyntaxError: '--' is not valid in Python (use '-= 1')",
				"snippet": trimmed
			})
				
		# 5. Method typos
		if clean_line.contains(".startwith("):
			errors.append({
				"file": filename,
				"line": line_num,
				"message": "AttributeError: str object has no attribute 'startwith' (did you mean 'startswith'?)",
				"snippet": trimmed
			})
		if clean_line.contains(".endwith("):
			errors.append({
				"file": filename,
				"line": line_num,
				"message": "AttributeError: str object has no attribute 'endwith' (did you mean 'endswith'?)",
				"snippet": trimmed
			})

		# 6. Real-Time Undefined Names, Functions & Random Tokens Validation
		_validate_line_identifiers(clean_line, line_num, filename, trimmed, global_symbols, current_scope_stack, errors, lines, paren_stack)

		# 7. Check parentheses and string parity
		var in_str = false
		var str_char = ""
		for ch_idx in range(raw_line.length()):
			var ch = raw_line[ch_idx]
			if not in_str:
				if ch == "#":
					break
				elif ch == '"' or ch == "'":
					in_str = true
					str_char = ch
				elif ch in ["(", "[", "{"]:
					paren_stack.append({"char": ch, "line": line_num})
				elif ch in [")", "]", "}"]:
					if paren_stack.is_empty():
						errors.append({
							"file": filename,
							"line": line_num,
							"message": "SyntaxError: unmatched closing '%s'" % ch,
							"snippet": trimmed
						})
					else:
						var last = paren_stack.pop_back()
						var matches = (last["char"] == "(" and ch == ")") or (last["char"] == "[" and ch == "]") or (last["char"] == "{" and ch == "}")
						if not matches:
							errors.append({
								"file": filename,
								"line": line_num,
								"message": "SyntaxError: closing '%s' does not match '%s' from line %d" % [ch, last["char"], last["line"]],
								"snippet": trimmed
							})
			else:
				if ch == str_char and (ch_idx == 0 or raw_line[ch_idx - 1] != "\\"):
					in_str = false
					
		if in_str and not in_docstring:
			errors.append({
				"file": filename,
				"line": line_num,
				"message": "SyntaxError: unterminated string literal",
				"snippet": trimmed
			})
			
	if not paren_stack.is_empty():
		var unclosed = paren_stack.pop_back()
		errors.append({
			"file": filename,
			"line": unclosed["line"],
			"message": "SyntaxError: unclosed '%s'" % unclosed["char"],
			"snippet": ""
		})
		
	return errors

func _is_valid_identifier(s: String) -> bool:
	if s.is_empty():
		return false
	var first = s[0]
	if not ((first >= 'a' and first <= 'z') or (first >= 'A' and first <= 'Z') or first == '_'):
		return false
	for i in range(1, s.length()):
		var c = s[i]
		if not ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_'):
			return false
	return true

func _add_to_current_scope(scope_stack: Array[Dictionary], global_symbols: Dictionary, var_name: String) -> void:
	if not scope_stack.is_empty():
		scope_stack.back()["symbols"][var_name] = true
	else:
		global_symbols[var_name] = true

func _is_symbol_in_scope(symbol: String, scope_stack: Array[Dictionary], global_symbols: Dictionary) -> bool:
	_ensure_builtins_initialized()
	if global_symbols.has(symbol) or PYTHON_KEYWORDS.has(symbol) or PYTHON_BUILTINS.has(symbol):
		return true
	for scope in scope_stack:
		if scope.get("symbols", {}).has(symbol):
			return true
	return false

func _extract_target_identifiers(target_str: String) -> Array[String]:
	var results: Array[String] = []
	var cleaned = target_str.replace("(", " ").replace(")", " ").replace("[", " ").replace("]", " ")
	for part in cleaned.split(","):
		var token = part.strip_edges()
		if token.contains("."):
			continue
		token = token.trim_prefix("*").strip_edges()
		if _is_valid_identifier(token) and not PYTHON_KEYWORDS.has(token):
			if not results.has(token):
				results.append(token)
	return results

func _extract_assignment_lhs(trimmed: String) -> String:
	if trimmed.begins_with("def ") or trimmed.begins_with("class ") or trimmed.begins_with("if ") or trimmed.begins_with("elif ") or trimmed.begins_with("for ") or trimmed.begins_with("while ") or trimmed.begins_with("return ") or trimmed.begins_with("assert "):
		return ""
	var ops = ["+=", "-=", "*=", "/=", "%=", "//=", "**=", "&=", "|=", "^=", "="]
	for op in ops:
		var pos = trimmed.find(op)
		if pos != -1:
			if op == "=" and pos > 0 and trimmed[pos - 1] in ["=", "!", "<", ">", "+", "-", "*", "/", "%", "&", "|", "^"]:
				continue
			var lhs = trimmed.substr(0, pos).strip_edges()
			if not lhs.contains("(") and not lhs.contains("["):
				return lhs
			elif lhs.begins_with("(") or lhs.begins_with("["):
				return lhs
			elif lhs.contains("["):
				# e.g. arr[i] = ... -> base name arr is in scope
				var bracket_idx = lhs.find("[")
				return lhs.substr(0, bracket_idx).strip_edges()
			else:
				return lhs
	return ""

## Validates all identifiers on a single code line to catch random undefined names, functions, and garbage tokens.
func _validate_line_identifiers(clean_line: String, line_num: int, filename: String, raw_trimmed: String, global_symbols: Dictionary, scope_stack: Array[Dictionary], errors: Array[Dictionary], all_lines: PackedStringArray = [], paren_stack: Array[Dictionary] = []) -> void:
	var trimmed = clean_line.strip_edges()
	if trimmed.is_empty() or trimmed.begins_with("#"):
		return
		
	# Skip definition lines where names are being declared
	if trimmed.begins_with("def ") or trimmed.begins_with("class ") or trimmed.begins_with("import ") or trimmed.begins_with("from "):
		return
		
	# Extract comprehension loop variables & lambda parameters (across current line and enclosing multiline parenthesized expressions)
	var line_locals: Dictionary = {}
	var scan_text = clean_line
	if not all_lines.is_empty() and (not paren_stack.is_empty() or clean_line.contains("(") or clean_line.contains("[") or clean_line.contains("{")):
		var start_l = paren_stack.back()["line"] - 1 if not paren_stack.is_empty() else line_num - 1
		var end_l = min(all_lines.size(), line_num + 20)
		var block_parts: Array[String] = []
		for k in range(start_l, end_l):
			block_parts.append(_strip_strings_and_comments_for_lint(all_lines[k]))
		scan_text = " ".join(block_parts)

	var for_regex = RegEx.new()
	for_regex.compile("\\bfor\\s+([A-Za-z0-9_,\\s\\(\\)]+?)\\s+in\\b")
	for m in for_regex.search_all(scan_text):
		var target_str = m.get_string(1).replace("(", "").replace(")", "").strip_edges()
		for part in target_str.split(","):
			var p_clean = part.strip_edges()
			if _is_valid_identifier(p_clean):
				line_locals[p_clean] = true
				
	var lambda_regex = RegEx.new()
	lambda_regex.compile("\\blambda\\b\\s*([^:]*):")
	for m in lambda_regex.search_all(scan_text):
		var params_str = m.get_string(1).strip_edges()
		for part in params_str.split(","):
			var p_clean = part.split("=")[0].strip_edges()
			if _is_valid_identifier(p_clean):
				line_locals[p_clean] = true

	# Tokenize identifiers and check their context
	var i = 0
	var len_line = clean_line.length()
	var prev_token_was_dot = false
	var paren_depth = 0
	
	while i < len_line:
		var ch = clean_line[i]
		if ch == '#':
			break
		if ch == '.':
			if i + 1 < len_line and clean_line[i + 1] >= '0' and clean_line[i + 1] <= '9':
				i += 1
				while i < len_line:
					var c = clean_line[i]
					if (c >= '0' and c <= '9') or c == '_' or c == 'j' or c == 'J':
						i += 1
					elif (c == 'e' or c == 'E'):
						i += 1
						if i < len_line and (clean_line[i] == '+' or clean_line[i] == '-'):
							i += 1
					else:
						break
				prev_token_was_dot = false
				continue
			prev_token_was_dot = true
			i += 1
			continue
		if ch == '(':
			paren_depth += 1
		elif ch == ')':
			paren_depth = max(0, paren_depth - 1)
			
		if ch >= '0' and ch <= '9':
			if ch == '0' and i + 1 < len_line and (clean_line[i + 1] in ['x', 'X', 'b', 'B', 'o', 'O']):
				i += 2
				while i < len_line:
					var c = clean_line[i]
					if (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F') or c == '_':
						i += 1
					else:
						break
			else:
				while i < len_line:
					var c = clean_line[i]
					if (c >= '0' and c <= '9') or c == '.' or c == '_' or c == 'j' or c == 'J':
						i += 1
					elif (c == 'e' or c == 'E'):
						i += 1
						if i < len_line and (clean_line[i] == '+' or clean_line[i] == '-'):
							i += 1
					else:
						break
			prev_token_was_dot = false
			continue

		if (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == '_':
			var start_idx = i
			while i < len_line:
				var c = clean_line[i]
				if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_':
					i += 1
				else:
					break
			var ident = clean_line.substr(start_idx, i - start_idx)
			
			# Lookahead for trailing characters (ignoring whitespace)
			var j = i
			while j < len_line and (clean_line[j] == ' ' or clean_line[j] == '\t'):
				j += 1
			var next_char = clean_line[j] if j < len_line else ""
			var next_char2 = clean_line.substr(j, 2) if j + 1 < len_line else next_char
			
			var is_kwarg_or_assign = (next_char == "=" and next_char2 != "==" and next_char2 != "=>")
			var is_type_annot = (next_char == ":" and not prev_token_was_dot and paren_depth == 0 and not PYTHON_KEYWORDS.has(ident))
			var is_func_call = (next_char == "(")
			
			if prev_token_was_dot:
				# Attribute or method access on an object (e.g. obj.method() or obj.attr)
				prev_token_was_dot = false
			elif is_kwarg_or_assign:
				# Keyword argument name (e.g. `func(foo=bar)`) or assignment target (`x = 5`)
				pass
			elif is_type_annot:
				# Variable / dataclass field type annotation (e.g. `name: str`, `count: int = 0`)
				pass
			elif line_locals.has(ident):
				# Inline comprehension or lambda variable
				pass
			else:
				# Standalone identifier or function call
				if not _is_symbol_in_scope(ident, scope_stack, global_symbols):
					if is_func_call:
						errors.append({
							"file": filename,
							"line": line_num,
							"message": "NameError: name '%s' is not defined (unknown function call)" % ident,
							"snippet": raw_trimmed
						})
					else:
						errors.append({
							"file": filename,
							"line": line_num,
							"message": "NameError: name '%s' is not defined" % ident,
							"snippet": raw_trimmed
						})
				prev_token_was_dot = false
		else:
			if ch not in [' ', '\t']:
				prev_token_was_dot = false
			i += 1

## Returns the inferred Python type name for a literal RHS expression, or "" if unknown.
func _infer_literal_type(rhs: String) -> String:
	var r = rhs.strip_edges()
	if r.is_empty():
		return ""
	# String literals (all prefix variants)
	for prefix in ['"""', "'''", 'f"', "f'", 'r"', "r'", 'f"""', "f'''", '"', "'"]:
		if r.begins_with(prefix):
			return "str"
	# Bytes literals
	if r.begins_with('b"') or r.begins_with("b'"):
		return "bytes"
	# Bool (must be before int — True/False are ints in Python)
	if r == "True" or r == "False":
		return "bool"
	# None
	if r == "None":
		return "NoneType"
	# Built-in type constructor calls: str(...), int(...), etc.
	for ctor in ["str", "int", "float", "bool", "list", "tuple", "dict", "set", "bytes", "frozenset", "complex"]:
		if r.begins_with(ctor + "("):
			return ctor
	# List
	if r.begins_with("["):
		return "list"
	# Tuple
	if r.begins_with("("):
		return "tuple"
	# Dict / Set  { } — colon inside → dict, else set, empty → dict
	if r.begins_with("{"):
		if r == "{}" or r.contains(":"):
			return "dict"
		return "set"
	# Numeric literals
	var stripped_sign = r.lstrip("-")
	if stripped_sign.is_valid_int():
		return "int"
	if stripped_sign.is_valid_float() and "." in r:
		return "float"
	return ""

## Returns { lhs, op, rhs } for an assignment line, or {} if the line is not an assignment.
func _get_assignment_info(trimmed: String) -> Dictionary:
	# Skip block headers and other non-assignment statements
	for prefix in ["def ", "class ", "if ", "elif ", "for ", "while ", "return ", "import ", "from ", "#"]:
		if trimmed.begins_with(prefix):
			return {}
	# Try augmented operators first (longer tokens must come before "=")
	var ops = ["**=", "//=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "="]
	for op in ops:
		var pos = trimmed.find(op)
		if pos <= 0:
			continue
		# Avoid ==, !=, <=, >= being mistaken for '='
		if op == "=" and trimmed[pos - 1] in ["=", "!", "<", ">", "+", "-", "*", "/", "%", "&", "|", "^", "*"]:
			continue
		var lhs = trimmed.substr(0, pos).strip_edges()
		var rhs = trimmed.substr(pos + op.length()).strip_edges()
		# Only handle simple identifier LHS (no subscripts / attributes)
		if not lhs.contains(".") and not lhs.contains("[") and _is_valid_identifier(lhs):
			return {"lhs": lhs, "op": op, "rhs": rhs}
		return {}
	return {}

## Returns true if `lhs_type op= rhs_type` is a valid operation according to _AUG_OP_COMPAT.
func _is_aug_op_compatible(lhs_type: String, op: String, rhs_type: String) -> bool:
	if not _AUG_OP_COMPAT.has(lhs_type):
		# Unknown lhs type — don't report an error (be conservative)
		return true
	var ops_for_type: Dictionary = _AUG_OP_COMPAT[lhs_type]
	if not ops_for_type.has(op):
		# The operator is not listed for this type at all → incompatible
		return false
	var valid_rhs: Array = ops_for_type[op]
	return rhs_type in valid_rhs

func _strip_strings_and_comments_for_lint(line: String) -> String:
	var res = ""
	var i = 0
	var n = line.length()
	while i < n:
		var ch = line[i]
		if ch == "#":
			break
		# Check if index i is at start of a string literal (with optional prefix f, r, b, u, rf, fr, rb, br)
		var can_be_prefix = (i == 0 or not ((line[i-1] >= 'a' and line[i-1] <= 'z') or (line[i-1] >= 'A' and line[i-1] <= 'Z') or (line[i-1] >= '0' and line[i-1] <= '9') or line[i-1] == '_'))
		var prefix_len = 0
		if can_be_prefix:
			if i + 2 < n:
				var p2 = line.substr(i, 2).to_lower()
				if (p2 == "rf" or p2 == "fr" or p2 == "rb" or p2 == "br") and (line[i+2] == '"' or line[i+2] == "'"):
					prefix_len = 2
			if prefix_len == 0 and i + 1 < n:
				var p1 = line[i].to_lower()
				if (p1 == "f" or p1 == "r" or p1 == "b" or p1 == "u") and (line[i+1] == '"' or line[i+1] == "'"):
					prefix_len = 1
					
		var q_pos = i + prefix_len
		if q_pos < n and (line[q_pos] == '"' or line[q_pos] == "'"):
			var quote_char = line[q_pos]
			var quote_len = 1
			if q_pos + 2 < n and line[q_pos] == quote_char and line[q_pos+1] == quote_char and line[q_pos+2] == quote_char:
				quote_len = 3
				
			var curr = q_pos + quote_len
			while curr < n:
				if quote_len == 3:
					if curr + 2 < n and line[curr] == quote_char and line[curr+1] == quote_char and line[curr+2] == quote_char and (curr == 0 or line[curr-1] != "\\"):
						curr += 3
						break
				else:
					if line[curr] == quote_char and (curr == 0 or line[curr-1] != "\\"):
						curr += 1
						break
				curr += 1
				
			var total_len = curr - i
			for _s in range(total_len):
				res += " "
			i = curr
			continue
			
		res += ch
		i += 1
		
	return res

# -----------------------------------------------------------------------------
# IntelliSense Autocompletion Data Provider
# -----------------------------------------------------------------------------

## Returns autocompletion items for the given source code and current typed word.
static func get_intellisense_completions(source_code: String) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	
	# 1. Python Keywords (VS Code Blue / Purple)
	var keywords = [
		{"text": "def", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#569cd6")},
		{"text": "return", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "if", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "elif", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "else", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "for", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "while", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "in", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#569cd6")},
		{"text": "is", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#569cd6")},
		{"text": "not", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#569cd6")},
		{"text": "and", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#569cd6")},
		{"text": "or", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#569cd6")},
		{"text": "True", "kind": CodeEdit.KIND_CONSTANT, "color": Color("#569cd6")},
		{"text": "False", "kind": CodeEdit.KIND_CONSTANT, "color": Color("#569cd6")},
		{"text": "None", "kind": CodeEdit.KIND_CONSTANT, "color": Color("#569cd6")},
		{"text": "import", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "from", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "as", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "try", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "except", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "finally", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "raise", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "pass", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#569cd6")},
		{"text": "break", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "continue", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "match", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")},
		{"text": "case", "kind": CodeEdit.KIND_PLAIN_TEXT, "color": Color("#c586c0")}
	]
	items.append_array(keywords)
	
	# 2. Builtin Functions & Types from builtins.pyi
	_ensure_builtins_initialized()
	for b in PYTHON_BUILTINS.keys():
		if PYTHON_KNOWN_TYPES.has(b):
			items.append({"text": b, "kind": CodeEdit.KIND_CLASS, "color": Color("#4ec9b0")})
		else:
			items.append({"text": b, "kind": CodeEdit.KIND_FUNCTION, "color": Color("#dcdcaa")})
		
	# 3. Common Methods from builtins.pyi
	for m in COMMON_METHOD_NAMES.keys():
		items.append({"text": m, "kind": CodeEdit.KIND_MEMBER, "color": Color("#4ec9b0")})
		
	# 4. Contextual Symbols dynamically extracted from current file (VS Code Light Blue)
	var regex = RegEx.new()
	regex.compile("\\b[A-Za-z_][A-Za-z0-9_]*\\b")
	var matches = regex.search_all(source_code)
	var seen: Dictionary = {}
	for m in matches:
		var sym = m.get_string()
		if sym.length() >= 2 and not seen.has(sym):
			seen[sym] = true
			items.append({"text": sym, "kind": CodeEdit.KIND_VARIABLE, "color": Color("#9cdcfe")})
			
	return items

## Executes Python source code using the in-engine GDScript Python runner.
## No external OS Python installation required on the player's system.
func execute(code: String, script_path: String = "") -> Dictionary:
	if not script_path.is_empty() and script_path.begins_with("res://"):
		var fa = FileAccess.open(script_path, FileAccess.WRITE)
		if fa:
			fa.store_string(code)
			fa.close()
	return PythonScriptRunner.run_code(code)
