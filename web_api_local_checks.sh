#!/bin/ksh

echo makes_at_least_two_requests_with_requests
pytest -q tests/test_requirements.py -k test_makes_at_least_two_requests_with_requests

echo script_filename_no_spaces_and_py_extension
pytest -q tests/test_requirements.py -k test_script_filename_no_spaces_and_py_extension

echo incorporates_input_prompt_or_script_arguments
pytest -q tests/test_requirements.py -k test_incorporates_input_prompt_or_script_arguments

echo uses_typed_variable_int_float_or_str
pytest -q tests/test_requirements.py -k test_uses_typed_variable_int_float_or_str

echo uses_boolean_variable
pytest -q tests/test_requirements.py -k test_uses_boolean_variable

echo has_if_statement
pytest -q tests/test_requirements.py -k test_has_if_statement

echo has_loop
pytest -q tests/test_requirements.py -k test_has_loop

echo uses_list
pytest -q tests/test_requirements.py -k test_uses_list

echo parses_dictionary
pytest -q tests/test_requirements.py -k test_parses_dictionary

# echo prerequisite_declared_variables_are_used
# pytest -q tests/test_requirements.py -k test_prerequisite_declared_variables_are_used