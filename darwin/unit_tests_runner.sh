#!/usr/bin

R_UNIT_TESTS="$(pwd)/r_unit_tests.R"
PYTHON_UNIT_TESTS=""

if [ ! -f "$R_UNIT_TESTS" ]; then
  echo "Kernel test file '$R_UNIT_TESTS' not found"
  exit 1
fi

Rscript "$R_UNIT_TESTS"

if [ $? -eq 0 ]; then
  exit 0
else
  exit 1
fi