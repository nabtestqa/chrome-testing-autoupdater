#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Exit if any command in a pipeline fails.
set -o pipefail

# Function to get the latest entity for Testing download URL
# Arguments:
#   $1: platform ("linux64", "mac-arm64", "win64")
#   $2: channel ("Stable", "Beta", "Dev", "Canary")
#   $3: entity ("chrome", "chromedriver", "chrome-headless-shell")
# Returns:
#   Echos the download URL if successful, otherwise prints error to stderr and returns 1.
get_entity_testing_url() {
  local platform="$1"
  local channel="$2"
  local entity="$3"
  local json_url="https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json"
  local download_url=""

  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it to use this function." >&2
    echo "  (e.g., sudo apt-get install jq or brew install jq)" >&2
    return 1 # Indicate an error
  fi

  # Fetch the JSON data and parse it using jq
  download_url=$(curl -s "$json_url" | \
    jq -r ".channels.\"$channel\".downloads.\"$entity\"[] | select(.platform == \"$platform\").url")

  # Check if a URL was found
  if [ -n "$download_url" ]; then
    echo "$download_url"
  else
    echo "Error: Could not find the download URL for Chrome for Testing (Channel: '$channel', Platform: '$platform', Entity: '$entity')." >&2
    echo "  Please check the platform, channel or entity names, or the API endpoint might have changed." >&2
    return 1 # Indicate an error
  fi
}

# Function to download a file from a given URL to a specified destination
# Arguments:
#   $1: The URL of the file to download
#   $2: The local path where the file should be saved (can be a directory or a full path)
# Returns:
#   Returns 0 on successful download, 1 on failure.
download_file() {
  local url="$1"
  local destination="$2"
  local filename=""

  # Check if curl is installed
  if ! command -v curl &> /dev/null; then
    echo "Error: 'curl' is not installed. Please install it to use this function." >&2
    echo "  (e.g., sudo apt-get install curl or brew install curl)" >&2
    return 1
  fi

  # Extract filename from URL
  filename=$(basename "$url")

  # Determine the final download path
  local final_path=""
  if [ -d "$destination" ]; then # If destination is a directory
    final_path="${destination}/${filename}"
  else # Assume destination is the full path including filename
    final_path="$destination"
  fi

  echo "Attempting to download: $url"
  echo "Saving to: $final_path"

  # Use curl to download the file
  # -L: Follow redirects
  # -o: Specify output file
  # -f: Fail silently (no output on HTTP errors)
  # -# (or --progress-bar): Show a simple progress bar
  if curl -L -o "$final_path" "$url" -#; then
    echo "Download successful: $final_path"
    return 0
  else
    echo "Error: Download failed for $url" >&2
    return 1
  fi
}


## Main Script Logic

# --- Configuration ---
BACKUP_DIR_PRE="./old"
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
DOWNLOADS_EXT="zip" # Assuming the downloaded files are zip archives

PLATFORM="linux64" # options: linux64, mac-arm64, mac-x64, win32, win64
CHANNEL="Stable"   # options: Stable, Beta, Dev, Canary

CHROME_DIR="./chrome-testing"
DRIVER_DIR="./chromedriver"
HEADLESS_SHELL_DIR="./chrome-testing-headless-shell" # Consistent variable name

# --- Setup Directories ---
echo "--- Setting up directories ---"
mkdir -p "$BACKUP_DIR_PRE"
mkdir -p "$BACKUP_DIR_PRE/$BACKUP_DIR" # Create the timestamped backup dir inside ./old
echo "Backup directory created: $BACKUP_DIR_PRE/$BACKUP_DIR"
echo ""

# --- Get Download URLs ---
echo "--- Fetching Download URLs ---"

# Chrome
CHROME_DOWNLOAD_URL=$(get_entity_testing_url "$PLATFORM" "$CHANNEL" "chrome")
if [ -z "$CHROME_DOWNLOAD_URL" ]; then # get_entity_testing_url already returns 1 on error
    echo "Couldn't get Chrome URL. EXITING"
    exit 1
fi
echo "Found Chrome URL: $CHROME_DOWNLOAD_URL"

# ChromeDriver
DRIVER_DOWNLOAD_URL=$(get_entity_testing_url "$PLATFORM" "$CHANNEL" "chromedriver")
if [ -z "$DRIVER_DOWNLOAD_URL" ]; then
    echo "Couldn't get ChromeDriver URL. EXITING"
    exit 1
fi
echo "Found ChromeDriver URL: $DRIVER_DOWNLOAD_URL"

# Chrome Headless Shell
HEADLESS_SHELL_DOWNLOAD_URL=$(get_entity_testing_url "$PLATFORM" "$CHANNEL" "chrome-headless-shell")
if [ -z "$HEADLESS_SHELL_DOWNLOAD_URL" ]; then
    echo "Couldn't get Chrome Headless Shell URL. EXITING"
    exit 1
fi
echo "Found Chrome Headless Shell URL: $HEADLESS_SHELL_DOWNLOAD_URL"

echo ""

# --- Backup Current Versions ---
echo "------ BACKUP STARTED ------"
# Create target directories for extraction if they don't exist (needed for later unzip)
mkdir -p "$CHROME_DIR" "$DRIVER_DIR" "$HEADLESS_SHELL_DIR"

# Copy existing directories to the backup location
# Using 2>/dev/null to suppress "No such file or directory" errors if they don't exist
cp -r "$CHROME_DIR" "$BACKUP_DIR_PRE/$BACKUP_DIR/" 2>/dev/null || echo "Warning: '$CHROME_DIR' not found for backup, skipping."
cp -r "$DRIVER_DIR" "$BACKUP_DIR_PRE/$BACKUP_DIR/" 2>/dev/null || echo "Warning: '$DRIVER_DIR' not found for backup, skipping."
cp -r "$HEADLESS_SHELL_DIR" "$BACKUP_DIR_PRE/$BACKUP_DIR/" 2>/dev/null || echo "Warning: '$HEADLESS_SHELL_DIR' not found for backup, skipping."
echo "------ BACKUP FINISHED ------"
echo ""

# --- Remove Current Versions ---
echo "------ CURRENT VERSIONS REMOVED ------"
# Use -rf to force removal and avoid errors if directories don't exist
rm -rf "$CHROME_DIR" "$DRIVER_DIR" "$HEADLESS_SHELL_DIR"
echo "------ REMOVAL FINISHED ------"
echo ""

# --- Download New Versions ---
echo "------ DOWNLOADING NEW VERSIONS ------"

# Download Chrome
if download_file "$CHROME_DOWNLOAD_URL" "$CHROME_DIR.$DOWNLOADS_EXT"; then
    echo "Chrome downloaded successfully to $CHROME_DIR.$DOWNLOADS_EXT"
else
    echo "Failed to download Chrome. EXITING."
    exit 1 # Exit if a crucial download fails
fi

# Download ChromeDriver
if download_file "$DRIVER_DOWNLOAD_URL" "$DRIVER_DIR.$DOWNLOADS_EXT"; then
    echo "ChromeDriver downloaded successfully to $DRIVER_DIR.$DOWNLOADS_EXT"
else
    echo "Failed to download ChromeDriver. EXITING."
    exit 1 # Exit if a crucial download fails
fi

# Download Chrome Headless Shell
# Corrected variable name in echo message
if download_file "$HEADLESS_SHELL_DOWNLOAD_URL" "$HEADLESS_SHELL_DIR.$DOWNLOADS_EXT"; then
    echo "Chrome Headless Shell downloaded successfully to $HEADLESS_SHELL_DIR.$DOWNLOADS_EXT"
else
    echo "Failed to download Chrome Headless Shell. EXITING."
    exit 1 # Exit if a crucial download fails
fi

echo "------ DOWNLOAD FINISHED ------"
echo ""

# --- Extracting Archives ---
echo "------ EXTRACTING... ------"
# Check if unzip is installed
if ! command -v unzip &> /dev/null; then
    echo "Error: 'unzip' is not installed. Please install it to extract archives." >&2
    exit 1
fi

# Recreate extraction target directories (rm -rf removed them)
mkdir -p "$CHROME_DIR" "$DRIVER_DIR" "$HEADLESS_SHELL_DIR"

# Unzip each downloaded archive into its respective directory with -q for quiet output
if unzip -q "$CHROME_DIR.$DOWNLOADS_EXT" -d "$CHROME_DIR"; then
    echo "Extracted Chrome to $CHROME_DIR"
else
    echo "Error: Failed to extract Chrome archive. EXITING." >&2
    exit 1
fi

if unzip -q "$DRIVER_DIR.$DOWNLOADS_EXT" -d "$DRIVER_DIR"; then
    echo "Extracted ChromeDriver to $DRIVER_DIR"
else
    echo "Error: Failed to extract ChromeDriver archive. EXITING." >&2
    exit 1
fi

if unzip -q "$HEADLESS_SHELL_DIR.$DOWNLOADS_EXT" -d "$HEADLESS_SHELL_DIR"; then
    echo "Extracted Chrome Headless Shell to $HEADLESS_SHELL_DIR"
else
    echo "Error: Failed to extract Chrome Headless Shell archive. EXITING." >&2
    exit 1
fi

echo "------ EXTRACTION FINISHED ------"
echo ""

# --- Clean Up ---
echo "------ CLEAN UP ------"
# Remove the downloaded zip files
rm -f "$CHROME_DIR.$DOWNLOADS_EXT" "$DRIVER_DIR.$DOWNLOADS_EXT" "$HEADLESS_SHELL_DIR.$DOWNLOADS_EXT"
echo "------ CLEAN UP FINISHED ------"

echo ""
echo "Script completed successfully."
