extends Node

enum KEY_TYPE {
	NORMAL = 0,
	ANY_KEY = 1,
	OPTIONAL = 2
}

# Tokens will have leading and trailing white space stripped away.
const any_key_token = '[*:key]'
# First capture group is the "real" key name
const optional_key_regex = '\\[opt:key\\:(.+?)]'

# Checks the structure against object to make sure that object contains all of the keys defined in structure.
# Arrays in the structure mean "this key in the object we are checking must be an array of objects matching
# this sub-structure." In the case of an array with no values in the structure definition, this code will
# verify that the object being checked has an array at the location, but will not check the structure of
# its members.
#
# Parameters
# - structure: A Dictionary containing keys against which to test object
# - object: A Dictionary to be compared to structure
# - result: A dictionary in which errors and the overall function result will be stored; you should pass in {}
# - path: Keeps track of where in the structure we are; you should pass in nothing
#
# Examples structure:
# {
#	"key": { "level_2_key": null, "level_2_key_b": { "l2b_sub_key": null } }
#	, "key2": null
#	, "array_key": [
#		{ "array_structure_key_1": null, "array_structure_key_2": { "another_object": { "the_bottom": null}} }
#	]
#   , "array_of_anything": []
#   , "object_with_any_structure": {}
#   , "varying_keys": {"[*:key]": {"sex": null, "dob": null}}
#   , "[opt:key:optional_key_any_value]": null
#   , "[opt:key:optional_key_object_value]": {"key": {"sub-key": "sub-value"}}
#}
# The object you check against this
# - Must have keys named "key", "key2", "array_key", "array_of_anything",
#   "object_with_any_structure", and "varying_keys"
# -- "key" must contain an object with the keys "level_2_key" and "level_2_key_b"
# --- "level_2_key" can have any value
# --- "level_2_key_b" must be an object with the "l2b_sub_key" key in it
# ---- "l2b_sub_key" can have any value
# -- "key2" can have any value
# -- "array_key" must be an array, and each item inside the array must
# --- Have keys named "array_structure_key_1" and "array_structure_key_2"
# ---- "array_structure_key_1" can have any value
# ---- "array_structure_key_2" must be an object with the "another_object" key
# ----- "another_object_key" must contain an object with a key named "the_bottom"
# ------ "the_bottom" may have any value
# -- Have an array value for "array_of_anything", but the data in the array doesn't matter
# -- Have an object value for "object_with_any_structure", but the object structure doesn't matter
# -- Have a key called "varying_keys" which must contain only objects with a structure of
#    {"sex": null, "dob": null}} whose parent keys do not matter.
# - May optionall have keys named "optional_key_any_value" and "optional_key_object_value"
# -- These keys may or may not exist on the object being checked. If they do exist
# --- They must follow all the rules that govern other keys, except that optional keys are
#     not required to exist on the target object
# --- "optional_key_any_value" may have any value
# --- "optional_key_object_value" must contain an object with the structure shown above
#
# An example of data that might require "[*:key]"
#"object_with_varying_keys": {
#       "Tom": {"sex":"male"},
#       "Dick": {"sex":"male"},
#       "Harry": {"sex":"male"},
#       "Rachel": {"sex":"female"}
# }
# "object_with_varying_keys" must have some keys in it if [*:key] is specified; an empty
#  object will fail the test.
#
# Notes:
# - Extra keys on an object will not cause it to fail, but missing keys will.
# - Any object inside the structure definition may have a maximum of one
#   '[*:key]' key, as that token will match all keys in the current
#   level of the object. For instance, in the example above, you could
#   not have two keys in the structure, { "[*:key]": {}, "[*:key]": [] },
#   because there's no way to tell which wildcard in the structure you want
#   to match against which element of the object.
# - An array value in the structure can only have one object inside of it.
#   For example, in the "array_key" example above, if array_key were defined
#   as
#   "array_key": [
#	  { "key_one": null, "key_two": null }
#     , { "key_a": null, "key_b": null }
#   ]
#   the second object definition (key_a and key_b) would be ignored. If you
#   want to validate your object against all four of those keys, put them
#   inside one {} in the structure definition.
func verify_json_structure(structure, object, result, path = []):
	result.error = OK if !("error" in result) else result.error
	result.errors = [] if !("errors" in result) else result.errors
	path = [] if typeof(path) != TYPE_ARRAY else path

	var keys = structure.keys()
	for raw_key in keys:
		var processed = self.process_key(raw_key)
		var key = processed.key
		var key_type = processed.key_type
		if is_valid_type(object) && ((key_type == self.KEY_TYPE.ANY_KEY && object.keys().size() > 0) || object.has(key)):
			# dh.d("Object %s " % object)
			path.push_back(key)
			var structure_value_type = typeof(structure[raw_key])
			if structure_value_type == TYPE_ARRAY:
				self.handle_array_element(structure, object, raw_key, key, key_type, path, result)
			elif structure_value_type == TYPE_DICTIONARY:
				self.handle_dictionary_element(structure, object, raw_key, key, key_type, path, result)
			path.pop_back()
		elif key_type != self.KEY_TYPE.OPTIONAL:
			result.errors.push_back(
				(
					(
						"Object%s%s is missing key '%s'"
					) % ["." if path.size() > 0 else "", PoolStringArray(path).join("."),  key]
				)
			)
			# See duck_type() for more on why we can't use |=
			result.error = ERR_DOES_NOT_EXIST


func is_valid_type(object):
	var object_type = typeof(object)
	var result = false if object_type != TYPE_ARRAY && object_type != TYPE_DICTIONARY else true

	return result


# ToDo: Support combining different key types
func process_key(key):
	var result = { "key": "", "key_type": self.KEY_TYPE.NORMAL }
	if key.strip_edges() == self.any_key_token.strip_edges():
		result.key = key
		result.key_type = self.KEY_TYPE.ANY_KEY
	else:
		var regex = RegEx.new()
		regex.compile(self.optional_key_regex)
		if (regex.is_valid()):
			var m = regex.search(key)
			if m:
				if m.strings.size() > 0:
					result.key = m.strings[1]
					result.key_type = self.KEY_TYPE.OPTIONAL

		result.key = key if result.key == "" else result.key

	return result


func handle_array_element(structure, object, raw_key, key, key_type, path, result):
	var array_structure = (
		structure[key][0] if key_type == self.KEY_TYPE.NORMAL && structure[key].size() > 0
		else structure[raw_key][0] if key_type == self.KEY_TYPE.OPTIONAL && structure[raw_key].size() > 0
		else null
	)
	var object_value_type = typeof(object[key])

	if object_value_type != TYPE_ARRAY:
		# Errors are not bit-flags, so we are going to overwrite result.error if we encounter
		# more than one error. See comment in duck_type() for details.
		# ToDo: Consider refactoring to store multiple errors
		result.errors.push_back(
			(
				"Object key '%s' should be an array (type %d); type %d found, instead."
				% [key, TYPE_ARRAY, object_value_type]
			)
		)
		# This could be |= if ERR_* were powers of two
		result.error = ERR_INVALID_DATA
	else:
		if array_structure:
			if object[key].size() < 1:
				result.errors.push_back(
					(
						"Expected to find data in array at key %s; found nothing."
						% [key]
					)
				)
				result.error = ERR_INVALID_DATA
			else:
				for array_item in object[key]:
					self.verify_json_structure(array_structure, array_item, result, path)


func handle_dictionary_element(structure, object, raw_key, key, key_type, path, result):
	if key_type != self.KEY_TYPE.ANY_KEY:
		var object_value_type = typeof(object[key])
		if object_value_type == TYPE_DICTIONARY:
			# If the structure is just an empty Dictionary, all we need to verify is that the corresponding
			# key in the object contains a Dictionary value; we don't care what's in it.
			if structure.keys().size() > 0:
				self.verify_json_structure(structure[raw_key], object[key], result, path)
		else:
			result.errors.push_back(
				(
					"Object key '%s' should be a Dictionary (type %d); type %d found, instead."
					% [key, TYPE_DICTIONARY, object_value_type]
				)
			)
			# This could be |= if ERR_* were powers of two
			result.error = ERR_INVALID_DATA
	else:
		var object_keys = object.keys()
		for object_key in object_keys:
			path.pop_back()
			path.push_back(object_key)
			self.verify_json_structure(structure[key], object[object_key], result, path)


# A helper function to generate output for validation errors.
# Parameters
# - structure: The Dictionary containing the structure used to validate object
# - object: The object being validated
# - result: The result object from the call to verify_json_structure()
# - file: The name of the file the error occurred in
# - function: The name of the function the error occurred in
# - dump_json: True = output formatted JSON for both structure and object
# - json_indent: The character(s) to use for formatting the structure and object debug output
func print_validation_error(
	structure
	, object
	, result
	, file = null
	, function = null
	, dump_json = true
	, json_indent = "  "
):
	dh.d(
		(
			"Failed to validate object in %s -> %s; see error panel for details"
		) % [file if !file.empty() else "?", function if !function.empty() else "?"]
	)
	
	if dump_json:
		dh.d(
			"Validation structure: {structure}".format(
				{"structure": JSON.print(structure, json_indent)}
			)
			, dh.level.ERROR
		).d(
			"Object: {object}".format({"object": JSON.print(object, json_indent)}), dh.level.ERROR
		)
		
	dh.d(
		"Structure validator errors: {errors}".format({"errors": result.errors}), dh.level.ERROR
	)
