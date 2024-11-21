#!/bin/bash

# Global arrays
list_items=()
m3u8_list=()
download_file_list=()
download_tasks_list_json=".download_tasks.json"

# Function to check if dependencies are installed
check_dependencies() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: 'jq' is required but not installed."
        echo "Please install jq using 'brew install jq' (macOS) or 'sudo apt-get install jq' (Linux)."
        exit 1
    fi

    if ! command -v yt-dlp >/dev/null 2>&1; then
        echo "Error: 'yt-dlp' is required but not installed."
        echo "Please install yt-dlp using 'brew install yt-dlp' (macOS) or 'sudo apt-get install yt-dlp' (Linux)."
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
    echo "[" > "$JSON_FILE"
    for ((i = 0; i < ${#list_items[@]}; i++)); do
        # Escape special characters for JSON
        local key=$(printf '%s' "${list_items[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        local url=$(printf '%s' "${m3u8_list[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        local download_file=$(printf '%s' "${download_file_list[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')

        # Prepare the object
        echo "  {" >> "$JSON_FILE"
        echo "    \"key\": \"$key\"," >> "$JSON_FILE"
        echo "    \"url\": \"$url\"," >> "$JSON_FILE"
        echo "    \"download_file\": \"$download_file\"" >> "$JSON_FILE"
        if [[ $i -lt $(( ${#list_items[@]} - 1 )) ]]; then
            echo "  }," >> "$JSON_FILE"
        else
            echo "  }" >> "$JSON_FILE"
        fi
    done
    echo "]" >> "$JSON_FILE"
    echo "Written to $JSON_FILE"
}

# Function to read existing task file and populate arrays
read_task_file() {
    local JSON_FILE=${download_tasks_list_json}
    check_dependencies

    # Read the array of tasks
    tasks=()
    while IFS= read -r line; do
        tasks+=("$line")
    done < <(jq -c '.[]' "$JSON_FILE")

    # Clear existing arrays
    list_items=()
    m3u8_list=()
    download_file_list=()

    # For each task, extract the values
    for task in "${tasks[@]}"; do
        key=$(echo "$task" | jq -r '.key')
        url=$(echo "$task" | jq -r '.url')
        download_file=$(echo "$task" | jq -r '.download_file')
        list_items+=("$key")
        m3u8_list+=("$url")
        download_file_list+=("$download_file")
    done
}

# Function to handle existing task file
handle_existing_task_file() {
    if [[ -f "$download_tasks_list_json" ]]; then
        echo "Found existing task file '$download_tasks_list_json'."
        echo "Content of the task file:"
        jq . "$download_tasks_list_json"
        echo
        read -p "Do you want to start downloading from this task file? [Y/n]: " user_choice
        user_choice=$(echo "$user_choice" | tr '[:upper:]' '[:lower:]')
        
        if [[ "$user_choice" != "n" && "$user_choice" != "no" ]]; then
            echo "Using existing task file for downloading."
            read_task_file
            return 0  # Use existing file
        fi
    fi
    return 1  # Generate new task file
}

# Function to generate new task file
generate_new_task_file() {
    local URL="$1"
    echo "Generating new task menu..."
    fetch_list_items "$URL"
    rename_and_append "${list_items[@]}"
    append_duration "${list_items[@]}"
    write_to_json
}

# Function to display tasks and get user confirmation
display_and_confirm_tasks() {
    echo "Final content of the task file:"
    jq . "$download_tasks_list_json"
    echo
    echo "List of items:"
    jq -r '.[] | .key' "$download_tasks_list_json"
    echo
    read -p "Download all items listed here (Y/n)? " user_choice
    user_choice=$(echo "$user_choice" | tr '[:upper:]' '[:lower:]')
    if [[ "$user_choice" == "n" || "$user_choice" == "no" ]]; then
        return 1
    fi
    return 0
}

# Function to handle downloads
handle_downloads() {
    echo "Starting downloads..."
    local tasks=()
    while IFS= read -r line; do
        tasks+=("$line")
    done < <(jq -c '.[]' "$download_tasks_list_json")

    for task in "${tasks[@]}"; do
        local key=$(echo "$task" | jq -r '.key')
        local url=$(echo "$task" | jq -r '.url')
        local output_file=$(echo "$task" | jq -r '.download_file')

        echo "Downloading '$key'..."
        yt-dlp "$url" -o "$output_file" --no-check-certificates --concurrent-fragments 2

        if [ $? -eq 0 ]; then
            echo "Downloaded '$output_file' successfully."
        else
            echo "Failed to download '$output_file'."
        fi
    done
}

# Update main function to use new functions
main() {
    check_dependencies
    
    local goto_download=false
    if handle_existing_task_file; then
        goto_download=true
    fi
    
    if [[ "$goto_download" != "true" ]]; then
        if [[ $# -lt 1 ]]; then
            echo "No URL provided and no existing task file to use."
            echo "Usage: $0 [URL]"
            exit 1
        fi
        
        generate_new_task_file "$1"
    fi

    if display_and_confirm_tasks; then
        handle_downloads
    else
        echo "Exiting script."
        exit 0
    fi
}

# Start the script
main "$@"
