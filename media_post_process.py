import os
import curses
import subprocess
import time  # For spinner animation
import threading  # For loading animation
import whisper  # OpenAI's Whisper model

# Define supported media extensions
MEDIA_EXTENSIONS = ['.mp4', '.mkv', '.avi', '.flv', '.mov', '.wmv', '.mpeg', '.mpg']

# Define available Whisper models
WHISPER_MODELS = ['tiny', 'base', 'small', 'medium', 'large']

def get_media_files():
    """Retrieve all media files in the current directory."""
    files = []
    for f in os.listdir('.'):
        if os.path.isfile(f) and os.path.splitext(f)[1].lower() in MEDIA_EXTENSIONS:
            files.append(f)
    return files

def get_whisper_models():
    """Retrieve all Whisper models in the current directory."""
    models = []
    for f in os.listdir('.'):
        if os.path.isfile(f) and f in WHISPER_MODELS:
            models.append(f)
    return models

def file_selection_menu(stdscr):
    """Display the file selection menu and return the selected files."""
    try:
        curses.curs_set(0)  # Hide cursor
        curses.start_color()
        curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)

        media_files = get_media_files()
        items = media_files + ['(select all)']
        selection = [False] * len(items)
        current_row = 0

        while True:
            stdscr.clear()
            height, width = stdscr.getmaxyx()

            for idx, item in enumerate(items):
                if idx >= height - 2:
                    break  # Leave space for help message

                if idx == current_row:
                    stdscr.attron(curses.color_pair(1))
                    display_item = '+ ' + item if selection[idx] else '  ' + item
                    stdscr.addstr(idx, 0, display_item[:width - 1])
                    stdscr.attroff(curses.color_pair(1))
                else:
                    display_item = '+ ' + item if selection[idx] else '  ' + item
                    stdscr.addstr(idx, 0, display_item[:width - 1])

            help_message = "Use Up/Down arrows to navigate, Space to toggle selection, Enter to proceed, 'q' to quit."
            stdscr.addstr(height - 1, 0, help_message[:width - 1])

            stdscr.refresh()
            key = stdscr.getch()
            if key == curses.KEY_UP:
                current_row = (current_row - 1) % len(items)
            elif key == curses.KEY_DOWN:
                current_row = (current_row + 1) % len(items)
            elif key == ord(' '):
                if items[current_row] == '(select all)':
                    # Toggle all selections
                    toggle_value = not all(selection[:-1])
                    for i in range(len(selection) - 1):
                        selection[i] = toggle_value
                    selection[-1] = toggle_value
                else:
                    selection[current_row] = not selection[current_row]
                    # Update "(select all)" based on individual selections
                    selection[-1] = all(selection[:-1])
            elif key in [ord('\n'), curses.KEY_ENTER]:
                selected_files = [items[i] for i in range(len(items) - 1) if selection[i]]
                return selected_files
            elif key == ord('q') or key == ord('Q'):
                return None

    except KeyboardInterrupt:
        pass

def post_process_menu(stdscr, selected_files):
    """Display the post-process menu and perform the selected action."""
    try:
        curses.curs_set(0)
        curses.start_color()
        curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)

        options = [
            'Extract audio with MP3 format',
            'Re-encode media files to MP4 format',
            'Transcript audio with OpenAI\'s Whisper model',
            '(Back to file selection)'
        ]
        current_row = 0

        while True:
            stdscr.clear()
            height, width = stdscr.getmaxyx()

            for idx, option in enumerate(options):
                if idx >= height - 2:
                    break

                if idx == current_row:
                    stdscr.attron(curses.color_pair(1))
                    stdscr.addstr(idx, 0, option[:width - 1])
                    stdscr.attroff(curses.color_pair(1))
                else:
                    stdscr.addstr(idx, 0, option[:width - 1])

            help_message = "Use Up/Down arrows to navigate, Enter to select, 'q' to quit."
            stdscr.addstr(height - 1, 0, help_message[:width - 1])

            stdscr.refresh()
            key = stdscr.getch()
            if key == curses.KEY_UP:
                current_row = (current_row - 1) % len(options)
            elif key == curses.KEY_DOWN:
                current_row = (current_row + 1) % len(options)
            elif key in [ord('\n'), curses.KEY_ENTER]:
                selected_option = options[current_row]
                if selected_option == 'Extract audio with MP3 format':
                    extract_audio(selected_files, stdscr)
                    return True  # Return to file selection menu after processing
                elif selected_option == 'Re-encode media files to MP4 format':
                    reencode_media(selected_files, stdscr)
                    return True  # Return to file selection menu after processing
                elif selected_option == 'Transcript audio with OpenAI\'s Whisper model':
                    transcript_audio(selected_files, stdscr)
                    return True  # Return to file selection menu after processing
                elif selected_option == '(Back to file selection)':
                    return True  # Return to file selection menu
            elif key == ord('q') or key == ord('Q'):
                return None  # Signal to exit the script

    except KeyboardInterrupt:
        pass

def extract_audio(selected_files, stdscr):
    """Extract audio from selected media files and save as MP3."""
    stdscr.clear()
    height, width = stdscr.getmaxyx()

    if not selected_files:
        stdscr.addstr(0, 0, "No files selected.")
        stdscr.refresh()
        stdscr.getch()
        return

    stdscr.addstr(0, 0, "Extracting audio to MP3 format...")
    stdscr.refresh()

    for idx, media_file in enumerate(selected_files):
        base_name = os.path.splitext(media_file)[0]
        output_file = base_name + '.mp3'

        progress_message = f"Processing {media_file}... "
        stdscr.addstr(2 + idx, 0, progress_message[:width - 2])
        stdscr.refresh()

        cmd = [
            'ffmpeg', '-y', '-i', media_file, '-vn', '-acodec', 'libmp3lame', output_file
        ]

        try:
            # Start the ffmpeg process
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

            spinner = ['|', '/', '-', '\\']
            spinner_idx = 0

            while True:
                # Check if the process has finished
                if process.poll() is not None:
                    break

                # Update spinner
                spinner_char = spinner[spinner_idx % len(spinner)]
                stdscr.addstr(2 + idx, len(progress_message), spinner_char)
                stdscr.refresh()
                spinner_idx += 1

                # Sleep briefly to reduce CPU usage
                time.sleep(0.1)

            # Wait for the process to finish
            stdout, stderr = process.communicate()

            # Check if there was an error
            if process.returncode != 0:
                error_message = f"Error processing {media_file}"
                stdscr.addstr(2 + idx, 0, error_message[:width - 1])
                stdscr.refresh()
            else:
                # Remove spinner after completion
                stdscr.addstr(2 + idx, len(progress_message), ' ')
                stdscr.refresh()

        except Exception as e:
            error_message = f"Error processing {media_file}: {e}"
            stdscr.addstr(2 + idx, 0, error_message[:width - 1])
            stdscr.refresh()

    stdscr.addstr(height - 2, 0, "Extraction complete. Press any key to continue.")
    stdscr.refresh()
    stdscr.getch()

def reencode_media(selected_files, stdscr):
    """Re-encode selected media files and save as MP4."""
    stdscr.clear()
    height, width = stdscr.getmaxyx()

    if not selected_files:
        stdscr.addstr(0, 0, "No files selected.")
        stdscr.refresh()
        stdscr.getch()
        return

    stdscr.addstr(0, 0, "Re-encoding media files to MP4 format...")
    stdscr.refresh()

    for idx, media_file in enumerate(selected_files):
        base_name = os.path.splitext(media_file)[0]
        output_file = base_name + '_reencoded.mp4'

        progress_message = f"Processing {media_file}... "
        stdscr.addstr(2 + idx, 0, progress_message[:width - 2])
        stdscr.refresh()

        cmd = [
            'ffmpeg', '-y', '-i', media_file, '-c:v', 'libx264', '-preset', 'medium',
            '-crf', '23', '-c:a', 'aac', '-b:a', '128k', output_file
        ]

        try:
            # Start the ffmpeg process
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

            spinner = ['|', '/', '-', '\\']
            spinner_idx = 0

            while True:
                # Check if the process has finished
                if process.poll() is not None:
                    break

                # Update spinner
                spinner_char = spinner[spinner_idx % len(spinner)]
                stdscr.addstr(2 + idx, len(progress_message), spinner_char)
                stdscr.refresh()
                spinner_idx += 1

                # Sleep briefly to reduce CPU usage
                time.sleep(0.1)

            # Wait for the process to finish
            stdout, stderr = process.communicate()

            # Check if there was an error
            if process.returncode != 0:
                error_message = f"Error processing {media_file}"
                stdscr.addstr(2 + idx, 0, error_message[:width - 1])
                stdscr.refresh()
            else:
                # Remove spinner after completion
                stdscr.addstr(2 + idx, len(progress_message), ' ')
                stdscr.refresh()

        except Exception as e:
            error_message = f"Error processing {media_file}: {e}"
            stdscr.addstr(2 + idx, 0, error_message[:width - 1])
            stdscr.refresh()

    stdscr.addstr(height - 2, 0, "Re-encoding complete. Press any key to continue.")
    stdscr.refresh()
    stdscr.getch()

def transcript_audio(selected_files, stdscr):
    """Transcribe audio from selected media files using Whisper model."""
    stdscr.clear()
    height, width = stdscr.getmaxyx()

    if not selected_files:
        stdscr.addstr(0, 0, "No files selected.")
        stdscr.refresh()
        stdscr.getch()
        return

    # Check for models in the current directory
    available_models = [f for f in os.listdir('.') if f in WHISPER_MODELS]
    model_name = None

    if not available_models:
        # Inform user and download the "base" model
        stdscr.addstr(0, 0, "No Whisper models found in the current directory.")
        stdscr.addstr(1, 0, "Downloading the 'base' model...")
        stdscr.refresh()

        # Show loading animation while downloading
        loading = True

        def loading_animation():
            spinner = ['|', '/', '-', '\\']
            idx = 0
            while loading:
                stdscr.addstr(1, len("Downloading the 'base' model... "), spinner[idx % len(spinner)])
                stdscr.refresh()
                idx += 1
                time.sleep(0.1)

        animation_thread = threading.Thread(target=loading_animation)
        animation_thread.start()

        try:
            # Download the 'base' model to the current directory
            model_name = 'base'
            model = whisper.load_model(model_name, download_root='.')
        except Exception as e:
            loading = False
            animation_thread.join()
            stdscr.addstr(2, 0, f"Error downloading model: {e}")
            stdscr.refresh()
            stdscr.getch()
            return

        loading = False
        animation_thread.join()
    else:
        # Let the user pick a model
        model_name = select_model_menu(stdscr, available_models)
        if not model_name:
            return  # User canceled the selection

        # Inform user that the model is loading
        stdscr.clear()
        stdscr.addstr(0, 0, f"Loading model '{model_name}'...")
        stdscr.refresh()

        # Show loading animation while loading the model
        loading = True

        def loading_animation():
            spinner = ['|', '/', '-', '\\']
            idx = 0
            while loading:
                stdscr.addstr(0, len(f"Loading model '{model_name}'... "), spinner[idx % len(spinner)])
                stdscr.refresh()
                idx += 1
                time.sleep(0.1)

        animation_thread = threading.Thread(target=loading_animation)
        animation_thread.start()

        try:
            model = whisper.load_model(model_name, download_root='.')
        except Exception as e:
            loading = False
            animation_thread.join()
            stdscr.addstr(1, 0, f"Error loading model: {e}")
            stdscr.refresh()
            stdscr.getch()
            return

        loading = False
        animation_thread.join()

    # Start transcribing
    for idx, media_file in enumerate(selected_files):
        stdscr.clear()
        stdscr.addstr(0, 0, f"Transcribing {media_file}...")
        stdscr.refresh()

        # Show animation during transcription
        transcribing = True

        def transcribing_animation():
            spinner = ['|', '/', '-', '\\']
            idx_anim = 0
            while transcribing:
                stdscr.addstr(0, len(f"Transcribing {media_file}... "), spinner[idx_anim % len(spinner)])
                stdscr.refresh()
                idx_anim += 1
                time.sleep(0.1)

        animation_thread = threading.Thread(target=transcribing_animation)
        animation_thread.start()

        try:
            # Perform transcription
            result = model.transcribe(media_file)
            # Save transcription to a text file
            base_name = os.path.splitext(media_file)[0]
            output_file = base_name + '_transcript.txt'
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(result['text'])
        except Exception as e:
            transcribing = False
            animation_thread.join()
            stdscr.addstr(1, 0, f"Error transcribing {media_file}: {e}")
            stdscr.refresh()
            stdscr.getch()
            continue

        transcribing = False
        animation_thread.join()
        stdscr.addstr(1, 0, f"Transcription saved to {output_file}")
        stdscr.refresh()
        stdscr.getch()

def select_model_menu(stdscr, models):
    """Display a menu to select a Whisper model."""
    current_row = 0
    try:
        while True:
            stdscr.clear()
            height, width = stdscr.getmaxyx()

            stdscr.addstr(0, 0, "Select a Whisper model:")
            for idx, model in enumerate(models):
                if idx >= height - 3:
                    break  # Leave space for help message

                if idx == current_row:
                    stdscr.attron(curses.color_pair(1))
                    stdscr.addstr(idx + 1, 0, model[:width - 1])
                    stdscr.attroff(curses.color_pair(1))
                else:
                    stdscr.addstr(idx + 1, 0, model[:width - 1])

            help_message = "Use Up/Down arrows to navigate, Enter to select, 'q' to cancel."
            stdscr.addstr(height - 1, 0, help_message[:width - 1])

            stdscr.refresh()
            key = stdscr.getch()
            if key == curses.KEY_UP:
                current_row = (current_row - 1) % len(models)
            elif key == curses.KEY_DOWN:
                current_row = (current_row + 1) % len(models)
            elif key in [ord('\n'), curses.KEY_ENTER]:
                return models[current_row]
            elif key == ord('q') or key == ord('Q'):
                return None

    except KeyboardInterrupt:
        pass

def main(stdscr):
    while True:
        selected_files = file_selection_menu(stdscr)
        if selected_files is None:
            break  # User chose to quit
        elif not selected_files:
            continue  # No files selected, go back to file selection

        result = post_process_menu(stdscr, selected_files)
        if result is None:
            break  # User chose to quit
        elif result:
            continue  # Return to file selection menu after processing

if __name__ == '__main__':
    curses.wrapper(main)
