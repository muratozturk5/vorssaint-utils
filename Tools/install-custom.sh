#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# custom: rebuilds the daily-use Developer build, installs it into
# /Applications and starts it again. Signs with my own Developer ID unless
# VORSSAINT_SIGNING_IDENTITY is already set.
set -euo pipefail
cd "$(dirname "$0")/.."

export VORSSAINT_SIGNING_IDENTITY="${VORSSAINT_SIGNING_IDENTITY:-Developer ID Application: Murat OZTURK (99G5W9P68N)}"
./build.sh --dev --install
open "/Applications/Vorssaint (Developer).app"
