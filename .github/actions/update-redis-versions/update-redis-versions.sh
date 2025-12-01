#!/bin/bash
set -e

# This script updates .redis_versions.json with the provided risk_level and release_tag
# and commits changes if any were made.

# Input RISK_LEVEL is expected in $1
# Input RELEASE_TAG is expected in $2
RISK_LEVEL="$1"
RELEASE_TAG="$2"

if [ -z "$RISK_LEVEL" ]; then
    echo "Error: RISK_LEVEL is required as first argument"
    exit 1
fi

if [ -z "$RELEASE_TAG" ]; then
    echo "Error: RELEASE_TAG is required as second argument"
    exit 1
fi

echo "RISK_LEVEL: $RISK_LEVEL"
echo "RELEASE_TAG: $RELEASE_TAG"

VERSIONS_FILE=".redis_versions.json"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "Error: $VERSIONS_FILE not found"
    exit 1
fi

# Validate that the file is valid JSON
if ! jq empty "$VERSIONS_FILE" 2>/dev/null; then
    echo "Error: $VERSIONS_FILE is not valid JSON"
    exit 1
fi

# Check if risk_level exists in the JSON file
if ! jq -e "has(\"$RISK_LEVEL\")" "$VERSIONS_FILE" > /dev/null; then
    echo "Error: Risk level '$RISK_LEVEL' does not exist in $VERSIONS_FILE"
    echo "Available risk levels:"
    jq -r 'keys[]' "$VERSIONS_FILE"
    exit 1
fi

# Refuse to change "edge" risk level
if [ "$RISK_LEVEL" = "edge" ]; then
    echo "Error: Cannot update 'edge' risk level. Edge is reserved for unstable builds."
    exit 1
fi

# Get current value for this risk level
CURRENT_VALUE=$(jq -r ".$RISK_LEVEL" "$VERSIONS_FILE")
echo "Current value for $RISK_LEVEL: $CURRENT_VALUE"

# Check if the value is already set to the release tag
if [ "$CURRENT_VALUE" = "$RELEASE_TAG" ]; then
    echo "Risk level '$RISK_LEVEL' is already set to '$RELEASE_TAG', no changes needed"
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "changed_files=" >> "$GITHUB_OUTPUT"
    fi
    exit 0
fi

# Update the JSON file
echo "Updating $RISK_LEVEL from '$CURRENT_VALUE' to '$RELEASE_TAG'..."
jq ".$RISK_LEVEL = \"$RELEASE_TAG\"" "$VERSIONS_FILE" > "${VERSIONS_FILE}.tmp"
mv "${VERSIONS_FILE}.tmp" "$VERSIONS_FILE"

# Verify the update was successful
NEW_VALUE=$(jq -r ".$RISK_LEVEL" "$VERSIONS_FILE")
if [ "$NEW_VALUE" != "$RELEASE_TAG" ]; then
    echo "Error: Failed to update $VERSIONS_FILE"
    exit 1
fi

echo "Successfully updated $VERSIONS_FILE"
echo "New content:"
cat "$VERSIONS_FILE"

# Check what files actually changed in git
mapfile -t changed_files < <(git diff --name-only "$VERSIONS_FILE")

# Output the list of changed files for GitHub Actions
if [ ${#changed_files[@]} -gt 0 ]; then
    echo "Files were modified:"
    printf '%s\n' "${changed_files[@]}"

    if [ -n "$GITHUB_OUTPUT" ]; then
        # Set GitHub Actions output
        changed_files_output=$(printf '%s\n' "${changed_files[@]}")
        {
            echo "changed_files<<EOF"
            echo "$changed_files_output"
            echo "EOF"
        } >> "$GITHUB_OUTPUT"
        echo "Changed files output set for next step"
    fi
else
    echo "No files were modified"
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "changed_files=" >> "$GITHUB_OUTPUT"
    fi
fi

