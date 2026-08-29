#!/usr/bin/env bash
set -u

expected="$1"
shift

set +e
"$@"
status=$?
set -e

[ "$status" -eq "$expected" ]
