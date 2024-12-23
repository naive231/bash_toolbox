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
    done < <(find "$dir" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.m4a" \) -print0)

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

    # Add All[*] option
    local all_choice_letter=$(printf "\\x$(printf %x $((65 + idx)))")
    printf "%s. All[*]\n" "$all_choice_letter"

    local any_process_assigned=false
    for choice in "${choices[@]}"; do
        if [[ -n "$choice" ]]; then
            any_process_assigned=true
            break
        fi
    done

    if [[ "$any_process_assigned" == true ]]; then
        local proceed_letter=$(printf "\\x$(printf %x $((65 + idx + 1)))")
        printf "%s. < proceed >\n" "$proceed_letter"
    fi

    read -n 1 -p "Choose a file letter for further processing, or 'q' to quit: " choice
    printf "\n"

    choice=$(echo "$choice" | tr '[:lower:]' '[:upper:]')
    local selected_index=$(( $(printf "%d" "'$choice") - 65 ))

    if [[ "$choice" =~ [A-Z] ]] && [ "$selected_index" -ge 0 ] && [ "$selected_index" -lt "${#files[@]}" ]; then
        choose_process "$selected_index" "${files[$selected_index]}"
    elif [[ "$choice" == "$all_choice_letter" ]]; then
        apply_to_all_files
    elif [[ "$choice" == "$proceed_letter" ]] && [[ "$any_process_assigned" == true ]]; then
        proceed_with_tasks "${files[@]}"
    elif [[ "$choice" == 'Q' ]]; then
        printf "Exiting program.\n"
        exit 0
    else
        printf "Invalid input. Please enter a valid letter between A and %s, press '%s' to proceed, or 'Q' to quit.\n" "$proceed_letter" "$proceed_letter"
    fi
}

apply_to_all_files() {
    printf "Select a process to apply to all files:\n"
    local options=("Extract audio to .mp3" "Re-encode to new .mp4" "Merge subtitle" "Extract transcript with Chinese")
    local i
    for i in "${!options[@]}"; do
        printf "%d. %s\n" "$((i + 1))" "${options[$i]}"
    done

    local process_choice
    read -n 1 -p "Enter your choice: " process_choice
    printf "\n"

    for idx in "${!choices[@]}"; do
        case "$process_choice" in
            1) choices[$idx]="Extract audio to .mp3" ;;
            2) choices[$idx]="Re-encode to new .mp4" ;;
            3) choices[$idx]="Merge subtitle" ;;
            4) choices[$idx]="Extract transcript with Chinese" ;;
            *) printf "Invalid choice. Please select a number between 1 and %d.\n" "${#options[@]}"
               apply_to_all_files
               return ;;
        esac
    done
    list_media_files_menu "."  # Refresh list after making a choice
}

main_menu() {
    local directory_path="."  # Set the default path to current directory
    list_media_files_menu "$directory_path"
}

choose_process() {
    local idx=$1
    local file=$2
    local options=("Extract audio to .mp3" "Re-encode to new .mp4" "Merge subtitle" "Translate JP to TC" "Extract transcript with Chinese")

    printf "Available post-processes:\n"
    for i in "${!options[@]}"; do
        printf "%d. %s\n" "$((i + 1))" "${options[$i]}"
    done

    read -n 1 -p "Choose a post-process option: " process_choice
    printf "\n"

    case "$process_choice" in
        1) choices[$idx]="Extract audio to .mp3" ;;
        2) choices[$idx]="Re-encode to new .mp4" ;;
        3) choices[$idx]="Merge subtitle" ;;
        4) choices[$idx]="Translate JP to TC" ;;
        5) choices[$idx]="Extract transcript with Chinese" ;;
        *) printf "Invalid choice. Please select a number between 1 and %d.\n" "${#options[@]}"
           choose_process "$idx" "$file"  # Retry if invalid input
           ;;
    esac
    list_media_files_menu "."  # Refresh list after making a choice
}

run_whisper_transcription() {
    local input_file=$1
    local whisper_model="ggml-turbo.bin"

    # Check if Whisper model is available, download if not
    if [[ ! -f "$whisper_model" ]]; then
        printf "Whisper model not found. Downloading '%s'...\n" "$whisper_model"
        curl -L -o "$whisper_model" -# "https://huggingface.co/openai/whisper-turbo/resolve/main/$whisper_model"
    fi
    printf "Model '%s' is available. Loading model, this may take a while...\n" "$whisper_model"

    # Load the model using Python and perform transcription
    python3 - <<END
import whisper
print("Loading model, please wait...")
model = whisper.load_model("$whisper_model")
print("Model loaded successfully.")
# Here, you would add the code to transcribe the audio file and save the result
transcription = model.transcribe("$input_file")
with open("${input_file%.*}_transcript.txt", "w") as f:
    f.write(transcription["text"])
print("Transcription completed and saved to ${input_file%.*}_transcript.txt")
END
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
        local subtitle_file="${input_file%.*}.srt"

        case "${choices[$idx]}" in
            "Extract audio to .mp3")
                local output_file="${input_file%.*}.mp3"
                printf "Extracting audio from %s to %s...\n" "$input_file" "$output_file"
                "$ffmpeg_path" -i "$input_file" -vn -acodec libmp3lame -ac 2 -ab 192k -ar 48000 "$output_file"
                ;;
            "Re-encode to new .mp4")
                local output_file="${input_file%.*}.reencoded.mp4"
                printf "Re-encoding %s to %s...\n" "$input_file" "$output_file"
                "$ffmpeg_path" -i "$input_file" -codec:v libx264 -codec:a aac -strict experimental -b:a 192k -y "$output_file"
                ;;
            "Merge subtitle")
                if [[ -f "$subtitle_file" ]]; then
                    local output_file="${input_file%.*}.subtitled.mp4"
                    printf "Merging subtitle from %s to %s...\n" "$subtitle_file" "$output_file"
                    "$ffmpeg_path" -i "$input_file" -vf subtitles="$subtitle_file" -codec:a copy -codec:v libx264 -crf 23 "$output_file"
                else
                    printf "No subtitle file found for %s\n" "$input_file"
                fi
                ;;
            "Translate JP to TC")
                if [[ -f "$subtitle_file" ]]; then
                    printf "Translating subtitles from Japanese to Traditional Chinese for %s...\n" "$input_file"
                    if ! trans -b -no-warn -no-autocorrect -i "$subtitle_file" -o "$subtitle_file" ja:zh-TW; then
                        printf "Failed to translate subtitles for %s\n" "$input_file" >&2
                    fi
                else
                    printf "No subtitle file found for %s\n" "$input_file"
                fi
                ;;
            "Extract transcript with Chinese")
                run_whisper_transcription "$input_file"
                ;;
        esac
    done
}

main_menu

