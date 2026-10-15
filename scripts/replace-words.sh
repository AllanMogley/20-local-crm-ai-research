#!/usr/bin/env bash

# Usage:
# ./replace-words.sh old_word new_word /path/to/dir
# ./replace-words.sh old_word new_word /path/to/file.json

OLD="${1:-}"
NEW="${2:-}"
TARGET="${3:-.}"

if [[ -z "$OLD" ]]; then
    echo "Usage: $0 old_word new_word [directory|file]" >&2
    exit 1
fi

if [[ ! -e "$TARGET" ]]; then
    echo "Error: '$TARGET' does not exist." >&2
    exit 1
fi

if [[ -f "$TARGET" ]]; then
    # Process a single file
    files=("$TARGET")
elif [[ -d "$TARGET" ]]; then
    # Process all files recursively
    mapfile -d '' files < <(find "$TARGET" -type f -print0)
else
    echo "Error: '$TARGET' is not a regular file or directory." >&2
    exit 1
fi

for file in "${files[@]}"; do
    # Skip binary files and files without OLD
    if grep -IqF -- "$OLD" "$file"; then
        echo "Updating: $file"

        # Replace literal occurrences of OLD
        OLD_SED="${OLD//\\/\\\\}"
        OLD_SED="${OLD_SED//|/\\|}"
        OLD_SED="${OLD_SED//&/\\&}"
        NEW_SED="${NEW//\\/\\\\}"
        NEW_SED="${NEW_SED//|/\\|}"
        NEW_SED="${NEW_SED//&/\\&}"

        sed -i "s|${OLD_SED}|${NEW_SED}|g" "$file"
    fi
done