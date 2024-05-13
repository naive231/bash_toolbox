#!/bin/bash

# Prompt for the repository URL and set a default value
read -p "Enter the repository URL (default: https://github.com/github/debug-repo): " repo_http
repo_http=${repo_http:-https://github.com/github/debug-repo}

read -p "Enter the SSH repository URL (default: git@github.com:github/debug-repo): " repo_ssh
repo_ssh=${repo_ssh:-git@github.com:github/debug-repo}

# Define destination directories
dest_http="/tmp/debug-repo-http"
dest_ssh="/tmp/debug-repo-ssh"

# Remove existing directories if they exist
[ -d "$dest_http" ] && rm -rf "$dest_http"
[ -d "$dest_ssh" ] && rm -rf "$dest_ssh"

# Clone repositories
git clone "$repo_http" "$dest_http"
git clone "$repo_ssh" "$dest_ssh"

# Prompt for the host to ping and trace, default is github.com
read -p "Enter the host to ping and trace (default: github.com): " host
host=${host:-github.com}

# Ping the host
ping -c 10 "$host"

# Trace the route to the host
traceroute "$host"

# Measure and display download metrics using curl
curl -s -o/dev/null -w "downloadspeed: %{speed_download} | dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download}\n" "https://$host"
