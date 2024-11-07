const fs = require('fs');
const inquirer = require('inquirer');
const readline = require('readline');

// Utility function to get all media files in the current directory
function getMediaFiles() {
    const mediaExtensions = ['.mp4', '.mkv', '.avi', '.mov'];
    return fs.readdirSync('.').filter(file => {
        return mediaExtensions.some(ext => file.endsWith(ext));
    });
}

async function main() {
    let mediaFiles = getMediaFiles();
    mediaFiles.push('(select all)');

    let selectedFiles = new Array(mediaFiles.length - 1).fill(false);

    let cursorIndex = 0;

    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });

    readline.emitKeypressEvents(process.stdin, rl);
    if (process.stdin.isTTY) {
        process.stdin.setRawMode(true);
    }

    console.clear();
    printList();

    process.stdin.on('keypress', (str, key) => {
        if (key.name === 'up') {
            cursorIndex = (cursorIndex - 1 + mediaFiles.length) % mediaFiles.length;
        } else if (key.name === 'down') {
            cursorIndex = (cursorIndex + 1) % mediaFiles.length;
        } else if (key.name === 'space') {
            if (cursorIndex === mediaFiles.length - 1) { // Toggle all
                const allSelected = selectedFiles.every(selected => selected);
                selectedFiles = selectedFiles.map(() => !allSelected);
            } else {
                selectedFiles[cursorIndex] = !selectedFiles[cursorIndex];
            }
        } else if (key.name === 'return') {
            rl.close();
            openPostProcessMenu(selectedFiles, mediaFiles);
            return;
        } else if (key.name.toLowerCase() === 'q') {
            rl.close();
            process.exit();
        }

        console.clear();
        printList();
    });

    function printList() {
        mediaFiles.forEach((file, index) => {
            if (index === mediaFiles.length - 1) {
                console.log(`${cursorIndex === index ? '> ' : '  '}${selectedFiles.every(s => s) ? '+ ' : '  '}${file}`);
            } else {
                console.log(`${cursorIndex === index ? '> ' : '  '}${selectedFiles[index] ? '+ ' : '  '}${file}`);
            }
        });
        console.log("\nUse 'up'/'down' arrows to navigate, 'space' to toggle selection, 'enter' to proceed, 'q' to quit.");
    }
}

async function openPostProcessMenu(selectedFiles, mediaFiles) {
    const selectedMediaFiles = mediaFiles.filter((_, index) => selectedFiles[index]);
    if (selectedMediaFiles.length === 0) {
        console.log("No files selected. Exiting...");
        process.exit();
    }

    const postProcessOptions = [
        'Extract audio with MP3 format',
        'Re-encode media files to MP4 format',
        'Transcript audio with OpenAI’s Whisper model'
    ];

    let cursorIndex = 0;

    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });

    readline.emitKeypressEvents(process.stdin, rl);
    if (process.stdin.isTTY) {
        process.stdin.setRawMode(true);
    }

    console.clear();
    printPostProcessMenu();

    process.stdin.on('keypress', (str, key) => {
        if (key.name === 'up') {
            cursorIndex = (cursorIndex - 1 + postProcessOptions.length) % postProcessOptions.length;
        } else if (key.name === 'down') {
            cursorIndex = (cursorIndex + 1) % postProcessOptions.length;
        } else if (key.name === 'return') {
            rl.close();
            console.log(`\nSelected option: ${postProcessOptions[cursorIndex]}`);
            // Here, proceed to execute the selected post-process function
            process.exit();
        } else if (key.name.toLowerCase() === 'q') {
            rl.close();
            process.exit();
        }

        console.clear();
        printPostProcessMenu();
    });

    function printPostProcessMenu() {
        postProcessOptions.forEach((option, index) => {
            console.log(`${cursorIndex === index ? '> ' : '  '}${option}`);
        });
        console.log("\nUse 'up'/'down' arrows to navigate, 'enter' to select, 'q' to quit.");
    }
}

main();

