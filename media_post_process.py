import os
import curses
import subprocess
import time  # For spinner animation
import youtube_dl  # Use youtube-dl for YouTube extraction

# Define supported media extensions
MEDIA_EXTENSIONS = ['.mp4', '.mkv', '.avi', '.flv', '.mov', '.wmv', '.mpeg', '.mpg', '.m4a']

def get_media_files():
    """Retrieve all media files in the current directory."""
    files = []
    for f in os.listdir('.'):
        if os.path.isfile(f) and os.path.splitext(f)[1].lower() in MEDIA_EXTENSIONS:
            files.append(f)
    return files

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
            'Extract audio with MP3 format (from files)',
            'Extract audio with MP3 format (from YouTube link)',
            'Re-encode media files to MP4 format',
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
                if selected_option == 'Extract audio with MP3 format (from files)':
                    extract_audio(selected_files, stdscr)
                    return True  # Return to file selection menu after processing
                elif selected_option == 'Extract audio with MP3 format (from YouTube link)':
                    url = input_youtube_url(stdscr)
                    if url:
                        extract_audio_from_youtube(url, stdscr)
                    return True
                elif selected_option == 'Re-encode media files to MP4 format':
                    reencode_media(selected_files, stdscr)
                    return True
                elif selected_option == '(Back to file selection)':
                    return True
            elif key == ord('q') or key == ord('Q'):
                return None

    except KeyboardInterrupt:
        pass

def input_youtube_url(stdscr):
    """Prompt user to input a YouTube URL."""
    curses.echo()
    stdscr.clear()
    stdscr.addstr(0, 0, "Enter YouTube URL (or press Enter to cancel): ")
    url = stdscr.getstr().decode('utf-8').strip()
    curses.noecho()
    return url if url else None

def extract_audio_from_youtube(url, stdscr):
    """Extract audio from a YouTube link and save as MP3."""
    stdscr.clear()
    height, width = stdscr.getmaxyx()
    stdscr.addstr(0, 0, "Extracting audio from YouTube...")
    stdscr.refresh()

    options = {
        'format': 'bestaudio/best',
        'outtmpl': '%(title)s.%(ext)s',
        'postprocessors': [
            {
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '192',
            }
        ],
    }

    with youtube_dl.YoutubeDL(options) as ydl:
        try:
            ydl.download([url])
            stdscr.addstr(height - 2, 0, "Audio extraction complete. Press any key to continue.")
            stdscr.refresh()
            stdscr.getch()
        except Exception as e:
            error_message = f"Error extracting audio: {e}"
            stdscr.addstr(height - 2, 0, error_message[:width - 1])
            stdscr.refresh()
            stdscr.getch()

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
                # Update status to indicate completion
                stdscr.addstr(2 + idx, 0, f"Extracted {output_file}")
                stdscr.refresh()

        except Exception as e:
            error_message = f"Error processing {media_file}: {e}"
            stdscr.addstr(2 + idx, 0, error_message[:width - 1])
            stdscr.refresh()

    # Wait for user input after all files have been processed
    stdscr.addstr(height - 2, 0, "Extraction complete. Press any key to continue.")
    stdscr.refresh()
    stdscr.getch()

def reencode_media(selected_files, stdscr):
    """Re-encode selected media files to MP4 format."""
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
                # Update status to indicate completion
                stdscr.addstr(2 + idx, 0, f"Re-encoded to {output_file}")
                stdscr.refresh()

        except Exception as e:
            error_message = f"Error processing {media_file}: {e}"
            stdscr.addstr(2 + idx, 0, error_message[:width - 1])
            stdscr.refresh()

    # Wait for user input after all files have been processed
    stdscr.addstr(height - 2, 0, "Re-encoding complete. Press any key to continue.")
    stdscr.refresh()
    stdscr.getch()

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
