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
            # Remove escape characters
            LINK=$(echo -e "$LINK" | sed 's/\\//g')

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

# Function to fetch and append video durations
append_duration() {
    local LINKS=("$@")
    local UPDATED_LINKS=()

    echo "Fetching durations for each .m3u8 link..."

    for ITEM in "${LINKS[@]}"; do
        # Extract the URL part of the ITEM
        local URL=$(echo "$ITEM" | cut -d' ' -f1)

        # Get the duration using ffprobe (ensure ffprobe is installed)
        local DURATION=$(ffprobe -i "$URL" -show_entries format=duration -v quiet -of csv="p=0" 2>/dev/null)

        if [[ -z "$DURATION" ]]; then
            DURATION="0"
        else
            # Truncate or round the decimal part
            DURATION=$(echo "$DURATION" | awk '{printf "%.0f", $1}')
        fi

        # Convert duration from seconds to HH:MM:SS
        local HOURS=$(printf "%02d" $(echo "$DURATION/3600" | bc))
        local MINUTES=$(printf "%02d" $(echo "($DURATION%3600)/60" | bc))
        local SECONDS=$(printf "%02d" $(echo "$DURATION%60" | bc))
        DURATION="${HOURS}:${MINUTES}:${SECONDS}"

        # Display progress message to the user
        echo "Processed: $ITEM ($DURATION)"

        # Append duration to the renamed item
        UPDATED_LINKS+=("$ITEM ($DURATION)")
    done

    # Update the global links array with durations
    M3U8_LINKS=("${UPDATED_LINKS[@]}")
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
    append_duration "${M3U8_LINKS[@]}"

    # Display final results
    echo "Final URL list with renamed files and durations:"
    for ITEM in "${M3U8_LINKS[@]}"; do
        echo "$ITEM"
    done
}

# Uncomment the line below to test the script with a specific URL
main "$@"
