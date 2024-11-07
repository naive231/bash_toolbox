const fs = require('fs');
const inquirer = require('inquirer');
const readline = require('readline');
const { exec } = require('child_process');
const path = require('path');

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
            if (cursorIndex === 0) {
                extractAudio(selectedMediaFiles);
            } else if (cursorIndex === 1) {
                reEncodeMedia(selectedMediaFiles);
            } else if (cursorIndex === 2) {
                transcriptAudio(selectedMediaFiles);
            }
            return;
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

function extractAudio(files) {
    files.forEach(file => {
        const output = file.replace(/\.[^/.]+$/, ".mp3");
        console.log(`Extracting audio from ${file} to ${output}...`);
        exec(`ffmpeg -i "${file}" -q:a 0 -map a "${output}"`, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error extracting audio from ${file}: ${error.message}`);
                return;
            }
            console.log(`Audio extracted to ${output}`);
        });
    });
}

function reEncodeMedia(files) {
    files.forEach(file => {
        const output = file.replace(/\.[^/.]+$/, ".mp4");
        console.log(`Re-encoding ${file} to ${output}...`);
        exec(`ffmpeg -i "${file}" -c:v libx264 -crf 23 -preset veryfast -c:a aac -b:a 128k "${output}"`, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error re-encoding ${file}: ${error.message}`);
                return;
            }
            console.log(`Re-encoded to ${output}`);
        });
    });
}

function transcriptAudio(files) {
    files.forEach(file => {
        const modelPath = path.join(__dirname, 'whisper_model');
        if (!fs.existsSync(modelPath)) {
            console.log(`Model not found. Downloading Whisper model...`);
            exec(`curl -o whisper_model https://example.com/path/to/whisper/model`, (error, stdout, stderr) => {
                if (error) {
                    console.error(`Error downloading model: ${error.message}`);
                    return;
                }
                console.log(`Model downloaded.`);
                loadAndTranscribe(file, modelPath);
            });
        } else {
            loadAndTranscribe(file, modelPath);
        }
    });
}

function loadAndTranscribe(file, modelPath) {
    console.log(`Loading Whisper model from ${modelPath}...`);
    // Placeholder for loading animation
    setTimeout(() => {
        console.log(`Model loaded. Starting transcription for ${file}...`);
        // Placeholder for actual Whisper transcription implementation
        setTimeout(() => {
            console.log(`Transcription for ${file} complete.`);
        }, 3000); // Simulating transcription delay
    }, 2000); // Simulating loading delay
}

main();
