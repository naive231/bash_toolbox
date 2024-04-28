#!/bin/bash

# Declare choices array globally to retain choices between function calls
declare -a choices

list_media_files() {
    local dir=$1
    local files=()  # Array to store file names

    # Populate the array with media files
    while IFS=  read -r -d $'\0'; do
        files+=("$REPLY")  # Store full path
        if [[ -z "${choices[${#files[@]}-1]}" ]]; then
            # Initialize with empty string for each new file
            choices+=("")
        fi
    done < <(find "$dir" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" \) -print0)

    if [[ ${#files[@]} -eq 0 ]]; then
        printf "No media files found in the directory: %s\n" "$dir" >&2
        return 1
    fi

    printf "Listing all media files:\n"
    local any_process_assigned=false
    for i in "${!files[@]}"; do
        local display_name="${files[$i]##*/}"
        if [[ -n "${choices[$i]}" ]]; then
            printf "%d. %s (%s)\n" "$((i+1))" "$display_name" "${choices[$i]}"
            any_process_assigned=true
        else
            printf "%d. %s\n" "$((i+1))" "$display_name"
        fi
    done

    if [[ "$any_process_assigned" == true ]]; then
        printf "%d. < proceed >\n" "$(( ${#files[@]} + 1 ))"
    fi

    read -n 1 -p "Choose a file number for further processing or press 'q' to quit: " choice
    printf "\n"
    local max_choice=$(( ${#files[@]} + 1 ))
    if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_choice" ]; then
        if [[ "$choice" -eq "$max_choice" ]] && [[ "$any_process_assigned" == true ]]; then
            proceed_with_tasks "${files[@]}"
        else
            local file_idx=$((choice-1))
            choose_process "$file_idx" "${files[$file_idx]}"
        fi
    elif [[ "$choice" == 'q' ]]; then
        printf "Exiting program.\n"
        exit 0
    else
        printf "Invalid input. Please enter a number between 1 and %d or press 'q' to quit.\n" "$max_choice"
    fi
}

choose_process() {
    local idx=$1
    local file=$2
    local options=("Extract audio to .mp3" "Re-encode to new .mp4")

    printf "Available post-processes:\n1. %s\n2. %s\n" "${options[0]}" "${options[1]}"
    read -n 1 -p "Choose a post-process option: " process_choice
    printf "\n"

    case "$process_choice" in
        1)
            choices[$idx]="${options[0]}"
            ;;
        2)
            choices[$idx]="${options[1]}"
            ;;
        *)
            printf "Invalid choice. Please select 1 or 2.\n"
            choose_process "$idx" "$file"  # Retry if invalid input
            ;;
    esac
    list_media_files "."  # Refresh list after making a choice
}

proceed_with_tasks() {
    local ffmpeg_path=$(which ffmpeg)
    if [[ -z "$ffmpeg_path" ]]; then
        printf "ffmpeg is not installed or not found in the PATH.\n"
        return 1
    fi

    printf "Proceeding with the assigned tasks...\n"
    for idx in "${!choices[@]}"; do
        local input_file="${files[$idx]}"
        if [[ "${choices[$idx]}" == "Extract audio to .mp3" ]]; then
            local output_file="${input_file%.*}.mp3"
            printf "Extracting audio from %s to %s...\n" "$input_file" "$output_file"
            "$ffmpeg_path" -i "$input_file" -vn -acodec libmp3lame -ac 2 -ab 192k -ar 48000 "$output_file"
        elif [[ "${choices[$idx]}" == "Re-encode to new .mp4" ]]; then
            local output_file="${input_file%.*}.reencoded.mp4"
            printf "Re-encoding %s to %s...\n" "$input_file" "$output_file"
            "$ffmpeg_path" -i "$input_file" -codec:v libx264 -codec:a aac -strict experimental -b:a 192k -y "$output_file"
        fi
    done
}

main() {
    local directory_path="." # Set the default path to current directory
    list_media_files "$directory_path"
}

main
