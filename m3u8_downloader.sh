#!/bin/bash

# Global arrays
list_items=()
m3u8_list=()
download_file_list=()
download_tasks_list_json=".download_tasks.json"

# Function to check if jq is installed
check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: 'jq' is required but not installed."
        echo "Please install jq using 'brew install jq' (macOS) or 'sudo apt-get install jq' (Linux)."
        exit 1
    fi
}

# Function to fetch .m3u8 links and populate the global array
fetch_list_items() {
    local URL="$1"
    local BASE_URL=$(echo "$URL" | sed -E 's|(https?://[^/]+).*|\1|')

    # Fetch and resolve unique .m3u8 links
    list_items=($(curl -s "$URL" | grep -Eo '(["'\''])([^"'\'' ]+\.m3u8[^"'\'' ]*)\1' | \
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
    m3u8_list=("${list_items[@]}")
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
        download_file_list+=("$UNIQUE_NAME")
        # Append renamed link to the output
        RENAMED_LINKS+=("$LINK to $UNIQUE_NAME")
    done

    # Update the global links array with renamed URLs
    list_items=("${RENAMED_LINKS[@]}")
}

# Function to fetch and append video durations
append_duration() {
    local LINKS=("$@")
    local UPDATED_LINKS=()

    echo "Fetching durations for each .m3u8 link..."

    for ITEM in "${LINKS[@]}"; do
        # Extract the URL part of the ITEM
        local URL=$(echo "$ITEM" | awk '{print $1}')

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
    list_items=("${UPDATED_LINKS[@]}")
}

# Function to write lists to JSON file
write_to_json() {
    local JSON_FILE=${download_tasks_list_json}
    echo "{" > "$JSON_FILE"
    for ((i = 0; i < ${#list_items[@]}; i++)); do
        # Escape special characters for JSON
        local key=$(printf '%s' "${list_items[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        local url=$(printf '%s' "${m3u8_list[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        local download_file=$(printf '%s' "${download_file_list[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')

        # Prepare the value as a JSON array
        echo -n "    \"$key\": [\"$url\", \"$download_file\"]" >> "$JSON_FILE"
        if [[ $i -lt $(( ${#list_items[@]} - 1 )) ]]; then
            echo "," >> "$JSON_FILE"
        fi
    done
    echo "" >> "$JSON_FILE"
    echo "}" >> "$JSON_FILE"
    echo "Written to $JSON_FILE"
}

# Function to read existing task file and populate arrays
read_task_file() {
    local JSON_FILE=${download_tasks_list_json}
    check_dependencies

    # Read the keys (list_items)
    mapfile -t list_items < <(jq -r 'keys[]' "$JSON_FILE")

    # For each key, extract the values
    for key in "${list_items[@]}"; do
        local url=$(jq -r --arg k "$key" '.[$k][0]' "$JSON_FILE")
        local download_file=$(jq -r --arg k "$key" '.[$k][1]' "$JSON_FILE")
        m3u8_list+=("$url")
        download_file_list+=("$download_file")
    done
}

# Main function to handle arguments and call other functions
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <URL>"
        exit 1
    fi

    local URL="$1"

    if [[ -f "$download_tasks_list_json" ]]; then
        echo "Found existing task file '$download_tasks_list_json'."
        echo "Content of the task file:"
        jq . "$download_tasks_list_json"
        echo
        read -p "Do you want to use this task menu? [Y/n]: " user_choice
        user_choice=$(echo "$user_choice" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
        if [[ "$user_choice" == "n" || "$user_choice" == "no" ]]; then
            # User chose not to use the existing task file
            echo "Generating new task menu..."
            fetch_list_items "$URL"
            rename_and_append "${list_items[@]}"
            append_duration "${list_items[@]}"
            write_to_json
        else
            echo "Using existing task file."
            read_task_file
        fi
    else
        # No existing task file
        fetch_list_items "$URL"
        rename_and_append "${list_items[@]}"
        append_duration "${list_items[@]}"
        write_to_json
    fi

    # Display final results
    echo "Final content of the task file:"
    jq . "$download_tasks_list_json"
    echo
    echo "List of items:"
    jq -r 'keys[]' "$download_tasks_list_json"
    echo
    read -p "Download all items listed here (Y/n)? " user_choice
    user_choice=$(echo "$user_choice" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    if [[ "$user_choice" == "n" || "$user_choice" == "no" ]]; then
        echo "Exiting script."
        exit 0
    fi
}

# Start the script
main "$@"
