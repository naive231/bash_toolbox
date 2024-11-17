#!/bin/bash

# Global array to store .m3u8 links
M3U8_LINKS=()

# Function to fetch .m3u8 links and populate the global array
fetch_m3u8_links() {
    local URL="$1"
    local BASE_URL=$(echo "$URL" | sed -E 's|(https?://[^/]+).*|\1|')

    # Fetch and resolve unique .m3u8 links
    M3U8_LINKS=($(curl -s "$URL" | grep -Eo '(["'\''])([^"'\'' ]+\.m3u8[^"'\'' ]*)\1' | \
        sed 's/^["'\'']//;s/["'\'']$//' | while read -r LINK; do
            if [[ $LINK == http* ]]; then
                echo "$LINK"
            else
                # Resolve relative URLs
                if [[ $LINK == /* ]]; then
                    # Absolute path on the same domain
                    echo "$BASE_URL$LINK"
                else
                    # Relative path
                    local DIR_URL=$(dirname "$URL")
                    echo "$DIR_URL/$LINK"
                fi
            fi
        done | grep -F ".m3u8" | sort -u))
}

# Function to rename URLs and append identical names
rename_and_append() {
    local LINKS=("$@")  # Convert passed arguments back into an array
    local RENAMED_LINKS=()

    echo "Checking and renaming URLs to ensure unique filenames..."

    for LINK in "${LINKS[@]}"; do
        # Extract filename and parent folder
        local FILE_NAME=$(basename "$LINK")
        local PARENT_FOLDER=$(basename "$(dirname "$LINK")")

        # Determine unique name
        local UNIQUE_NAME=""
        if [[ $(grep -o "$FILE_NAME" <<<"${LINKS[@]}" | wc -l) -gt 1 ]]; then
            # Use parent folder for uniqueness
            UNIQUE_NAME="${PARENT_FOLDER}_${FILE_NAME}"
        else
            # Use just the file name
            UNIQUE_NAME="$FILE_NAME"
        fi

        # Ensure the extension is .mp4
        UNIQUE_NAME="${UNIQUE_NAME%.*}.mp4"

        # Append renamed link to the output
        RENAMED_LINKS+=("$LINK to $UNIQUE_NAME")
    done

    # Update the global links array with renamed URLs
    M3U8_LINKS=("${RENAMED_LINKS[@]}")
}

# Main function to handle arguments and call other functions
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <URL>"
        exit 1
    fi

    local URL="$1"
    fetch_m3u8_links "$URL"
    rename_and_append "${M3U8_LINKS[@]}"

    # Display final results
    echo "Final URL list with renamed files:"
    for ITEM in "${M3U8_LINKS[@]}"; do
        echo "$ITEM"
    done
}

# Uncomment the line below to test the script with a specific URL
main "$@"
