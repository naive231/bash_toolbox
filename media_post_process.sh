#!/bin/bash

# Declare choices array globally to retain choices between function calls
declare -a choices

list_media_files_menu() {
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
    local idx=0
    for i in "${!files[@]}"; do
        local display_name="${files[$i]##*/}"
        local letter=$(printf "\\x$(printf %x $((65 + idx)))")
        if [[ -n "${choices[$i]}" ]]; then
            printf "%s. %s (%s)\n" "$letter" "$display_name" "${choices[$i]}"
        else
            printf "%s. %s\n" "$letter" "$display_name"
        fi
        ((idx++))
    done

    local any_process_assigned=false
    for choice in "${choices[@]}"; do
        if [[ -n "$choice" ]]; then
            any_process_assigned=true
            break
        fi
    done

    if [[ "$any_process_assigned" == true ]]; then
        local proceed_letter=$(printf "\\x$(printf %x $((65 + idx)))")
        printf "%s. < proceed >\n" "$proceed_letter"
    fi
    read -n 1 -p "Choose a file letter for further processing, or 'q' to quit: " choice

    printf "\n"
    choice=$(echo "$choice" | tr '[:lower:]' '[:upper:]')
    local selected_index=$(( $(printf "%d" "'$choice") - 65 ))

    if [[ "$choice" =~ [A-Z] ]] && [ "$selected_index" -ge 0 ] && [ "$selected_index" -lt "${#files[@]}" ]; then
        choose_process "$selected_index" "${files[$selected_index]}"
    elif [[ "$choice" == "$proceed_letter" ]] && [[ "$any_process_assigned" == true ]]; then
        proceed_with_tasks "${files[@]}"
    elif [[ "$choice" == 'Q' ]]; then
        printf "Exiting program.\n"
        exit 0
    else
        printf "Invalid input. Please enter a valid letter between A and %s, press '%s' to proceed, or 'Q' to quit.\n" "$proceed_letter" "$proceed_letter"
    fi
}

main_menu() {
    local directory_path="."  # Set the default path to current directory
    list_media_files_menu "$directory_path"
}

choose_process() {
    local idx=$1
    local file=$2
    local options=("Extract audio to .mp3" "Re-encode to new .mp4" "Merge subtitle")

    printf "Available post-processes:\n"
    for i in "${!options[@]}"; do
        printf "%d. %s\n" "$((i + 1))" "${options[$i]}"
    done

    read -n 1 -p "Choose a post-process option: " process_choice
    printf "\n"

    case "$process_choice" in
        1)
            choices[$idx]="${options[0]}"
            ;;
        2)
            choices[$idx]="${options[1]}"
            ;;
        3)
            choices[$idx]="${options[2]}"
            ;;
        *)
            printf "Invalid choice. Please select a number between 1 and %d.\n" "${#options[@]}"
            choose_process "$idx" "$file"  # Retry if invalid input
            ;;
    esac
    list_media_files_menu "."  # Refresh list after making a choice
}

proceed_with_tasks() {
    local ffmpeg_path=$(which ffmpeg)
    if [[ -z "$ffmpeg_path" ]]; then
        printf "ffmpeg is not installed or not found in the PATH.\n" >&2
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
        elif [[ "${choices[$idx]}" == "Merge subtitle" ]]; then
            local subtitle_file="${input_file%.*}.srt"
            if [[ -f "$subtitle_file" ]]; then
                local output_file="${input_file%.*}.subtitled.mp4"
                printf "Merging subtitle from %s to %s...\n" "$subtitle_file" "$output_file"
                "$ffmpeg_path" -i "$input_file" -vf subtitles="$subtitle_file" -codec:a copy -codec:v libx264 -crf 23 "$output_file"
            else
                printf "No subtitle file found for %s\n" "$input_file"
            fi
        fi
    done
}

main_menu
