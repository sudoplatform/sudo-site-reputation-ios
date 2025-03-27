#!/bin/bash
set -eu
echo "Generating mocks using mockingbird from spm"
echo "run \`swift package update Mockingbird\` to install tooling"
tempfile="$(mktemp).json"
swift package describe --type json > "$tempfile"
.build/checkouts/mockingbird/mockingbird generate \
    --project "$tempfile" \
    --only-protocols \
    --targets "SudoSiteReputation" \
    --testbundle "SudoSiteReputationTests" \
    --outputs "SudoSiteReputationTests/GeneratedMocks/SudoSiteReputationTests-SudoSiteReputationMocks.generated.swift"
rm "$tempfile"

