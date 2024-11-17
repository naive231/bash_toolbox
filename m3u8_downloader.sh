#!/bin/bash

URL="$1"
BASE_URL=$(echo "$URL" | sed -E 's|(https?://[^/]+).*|\1|')

# Collect and format unique .m3u8 links
LINKS=$(curl -s "$URL" | grep -Eo '(["'\''])([^"'\'' ]+\.m3u8[^"'\'' ]*)\1' | \
    sed 's/^["'\'']//;s/["'\'']$//' | while read -r LINK; do
        if [[ $LINK == http* ]]; then
            echo "$LINK"
        else
            # Resolve relative URLs
            if [[ $LINK == /* ]]; then
                # Absolute path on the same domain
                echo "$BASE_URL$LINK"
            else
                # Relative path
                DIR_URL=$(dirname "$URL")
                echo "$DIR_URL/$LINK"
            fi
        fi
    done | grep -F ".m3u8" | sort -u)

# Display the list
echo "Found .m3u8 links:"
echo "$LINKS" | while read -r LINK; do
    echo "- $LINK"
done
