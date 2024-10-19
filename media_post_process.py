import os
import curses

# Define supported media extensions
MEDIA_EXTENSIONS = ['.mp4', '.mp3', '.mkv', '.avi', '.flv', '.mov', '.wmv', '.mpeg', '.mpg', '.wav']

def get_media_files():
    """Retrieve all media files in the current directory."""
    files = []
    for f in os.listdir('.'):
        if os.path.isfile(f) and os.path.splitext(f)[1].lower() in MEDIA_EXTENSIONS:
            files.append(f)
    return files

def main(stdscr):
    try:
        # Initialize curses settings
        curses.curs_set(0)  # Hide cursor
        curses.start_color()
        curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)

        # Get media files and add "(select all)" option
        media_files = get_media_files()
        items = media_files + ['(select all)']
        selection = [False] * len(items)
        current_row = 0  # Index of the currently selected item

        while True:
            stdscr.clear()

            # Get terminal height and width
            height, width = stdscr.getmaxyx()

            # Display the list of files with selection status
            for idx, item in enumerate(items):
                # Ensure we don't write beyond the window size
                if idx >= height - 2:
                    break  # Leave space for help message

                if idx == current_row:
                    stdscr.attron(curses.color_pair(1))  # Highlight current row
                    display_item = '+ ' + item if selection[idx] else '  ' + item
                    stdscr.addstr(idx, 0, display_item[:width - 1])
                    stdscr.attroff(curses.color_pair(1))
                else:
                    display_item = '+ ' + item if selection[idx] else '  ' + item
                    stdscr.addstr(idx, 0, display_item[:width - 1])

            # Display the help message at the bottom of the screen
            help_message = "Use Up/Down arrows to navigate, Space to toggle selection, Enter to proceed, 'q' to quit."
            stdscr.addstr(height - 1, 0, help_message[:width - 1])

            stdscr.refresh()

            # Handle user input
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
                    selection[-1] = toggle_value  # Update "(select all)" status
                else:
                    selection[current_row] = not selection[current_row]
                    # Update "(select all)" based on individual selections
                    selection[-1] = all(selection[:-1])
            elif key in [ord('\n'), curses.KEY_ENTER]:
                # Proceed to the next menu (to be implemented)
                break
            elif key == ord('q') or key == ord('Q'):
                # Quit the script
                break

    except KeyboardInterrupt:
        # Handle Ctrl+C gracefully
        pass  # Exit the main function and return to the caller

if __name__ == '__main__':
    curses.wrapper(main)
