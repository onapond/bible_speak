#!/bin/sh
set -eu
ROOT=$(git rev-parse --show-toplevel)
exec "$ROOT/bin/harness" verify --lane full
