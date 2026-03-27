#!/bin/bash
# Script to detect which EESSI version(s) have easystack files changed in a PR
# Outputs the detected EESSI version(s) to stdout, separated by newlines

set -e

# Get the list of changed files from the PR
# When run in GitHub Actions, this uses the github.event.pull_request.changed_files
# For local testing or other contexts, can use git diff directly

CHANGED_FILES="$1"
BASE_COMMIT="$2"
HEAD_COMMIT="$3"

# EESSI version directories to check
EESSI_VERSIONS=("2023.06" "2025.06")
DETECTED_VERSIONS=()

if [ -n "$CHANGED_FILES" ]; then
    # Changed files are passed as argument (newline-separated from GitHub Actions join())
    # Handle both actual newlines and literal \n strings
    # First, convert literal \n to actual newlines if needed
    CHANGED_FILES=$(echo "$CHANGED_FILES" | sed 's/\\n/\n/g')
    
    files_array=()
    while IFS= read -r file; do
        # Trim whitespace and skip empty lines
        file=$(echo "$file" | tr -d '[:space:]')
        if [ -n "$file" ]; then
            files_array+=("$file")
        fi
    done <<< "$CHANGED_FILES"
elif [ -n "$BASE_COMMIT" ] && [ -n "$HEAD_COMMIT" ]; then
    # Use git diff to get changed files between commits
    IFS=$'\n' read -r -d '' -a files_array <<< "$(git diff --name-only "$BASE_COMMIT" "$HEAD_COMMIT")" || true
else
    # Try to use GitHub Actions context
    if [ -n "$GITHUB_EVENT_PATH" ]; then
        # Extract changed files from the pull_request event using jq if available
        if command -v jq &> /dev/null; then
            CHANGED_FILES_JSON=$(jq -r '.changed_files // empty' "$GITHUB_EVENT_PATH" 2>/dev/null)
            if [ -n "$CHANGED_FILES_JSON" ]; then
                while IFS= read -r file; do
                    if [ -n "$file" ]; then
                        files_array+=("$file")
                    fi
                done <<< "$CHANGED_FILES_JSON"
            fi
        else
            # Fallback to grep-based parsing
            CHANGED_FILES_JSON=$(cat "$GITHUB_EVENT_PATH" | grep -o '"changed_files"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
            if [ -n "$CHANGED_FILES_JSON" ]; then
                IFS=$'\n' read -r -d '' -a files_array <<< "$CHANGED_FILES_JSON" || true
            fi
        fi
    fi
fi

# Check each changed file to see which EESSI version directory it belongs to
for file in "${files_array[@]}"; do
    for version in "${EESSI_VERSIONS[@]}"; do
        if [[ "$file" == easystacks/software.eessi.io/$version/* ]]; then
            # Add version to detected versions if not already present
            if [[ ! " ${DETECTED_VERSIONS[*]} " =~ " $version " ]]; then
                DETECTED_VERSIONS+=("$version")
            fi
        fi
    done
done

# Output detected versions
for version in "${DETECTED_VERSIONS[@]}"; do
    echo "$version"
done
