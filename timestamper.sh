#!/bin/bash

# Function to display usage instructions
function usage() {
    echo "Usage: $0 [-r] <directory>"
    echo "  -r  Enable recursive mode to process subdirectories"
}

# Parse command line options
recursive=0

while getopts ":r" opt; do
    case $opt in
        r)
            recursive=1
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

# Check if a directory path is provided
if [ -z "$1" ]; then
    usage
    exit 1
fi

dir_path="$1"

# Set find options based on recursive flag
if [ $recursive -eq 1 ]; then
    find_opts="-type d"
else
    find_opts="-maxdepth 1 -type d"
fi

# Loop through the subdirectories
while IFS= read -r -d $'\0' subdir; do
    # Check if the subdirectory contains jpg files
    if [ $(find "$subdir" -maxdepth 1 -type f -iname "*.jpg" | wc -l) -eq 0 ]; then
        echo "No jpg files found in the subdirectory: $subdir"
        continue
    fi

    # Initialize variables
    first_file=1
    index=0
    datetime_mode=0

    # Loop through the jpg files
    while IFS= read -r -d $'\0' file; do
        if [ $first_file -eq 1 ]; then
            # Get the DateCreated, TimeCreated, and DateTimeOriginal of the first file
            basedate=$(exiftool -DateCreated -s3 "$file")
            basetime=$(exiftool -TimeCreated -s3 "$file" | awk -F'+' '{print $1}')
            datetimeoriginal=$(exiftool -DateTimeOriginal -s3 "$file")

            # Check if DateCreated and TimeCreated are available, otherwise use DateTimeOriginal
            if [ -z "$basedate" ] || [ -z "$basetime" ]; then
                if [ -z "$datetimeoriginal" ]; then
                    echo "DateCreated, TimeCreated, and DateTimeOriginal not found for the first file."
                    exit 1
                else
                    datetime_mode=1
                    basedatetime=$(echo "$datetimeoriginal" | awk -F'+' '{print $1}')
                fi
            fi

            # Set first_file flag to 0
            first_file=0
        else
            if [ $datetime_mode -eq 1 ]; then
                # Calculate the new DateTimeOriginal (basedatetime + 1 second) using Python
                new_datetime=$(python3 -c "from datetime import datetime, timedelta; basedatetime = datetime.strptime('$basedatetime', '%Y:%m:%d %H:%M:%S'); new_datetime = basedatetime + timedelta(seconds=$index); print(new_datetime.strftime('%Y:%m:%d %H:%M:%S'))")

                # Update DateTimeOriginal for the current file
                exiftool "-DateTimeOriginal=$new_datetime" -overwrite_original "$file" > /dev/null 2>&1
                echo "DateTimeOriginal for '$file' changed to $new_datetime"
            else
                # Calculate the new time (basetime + 1 second) using Python
                new_time=$(python3 -c "from datetime import datetime, timedelta; import re; basetime_no_tz = re.sub(r'[-+]\d{2}:\d{2}$', '', '$basetime'); basetime = datetime.strptime(basetime_no_tz, '%H:%M:%S'); new_time = basetime + timedelta(seconds=$index); print(new_time.strftime('%H:%M:%S'))")

                # Update DateCreated and TimeCreated for the current file
                exiftool "-DateCreated=$basedate" "-TimeCreated=$new_time" -overwrite_original "$file" > /dev/null 2>&1
                echo "Date for '$file' changed to $basedate and time changed to $new_time"
            fi

            # Increment index
            index=$((index + 1))
        fi
    done < <(find "$subdir" -maxdepth 1 -type f -iname "*.jpg" -print0 | sort -z -V)

    echo "Timestamps updated for photos in '$subdir'."
done < <(find "$dir_path" $find_opts -print0 | sort -z -V)
