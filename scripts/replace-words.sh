#!/usr/bin/env bash

# bash replace-words.sh /path/to/dir
OLD="komondo-hpc"
NEW="komondor-hpc"

# Directory to search; defaults to current directory
DIR="${1:-.}"

find "$DIR" -type f -print0 |
while IFS= read -r -d '' file; do
    # Skip binary files
    if grep -Iq "$OLD" "$file"; then
        echo "$file"

        # Replace all occurrences in the file
        sed -i "s/${OLD}/${NEW}/g" "$file"
    fi
done
