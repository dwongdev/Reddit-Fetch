#!/bin/sh

# Docker entrypoint script for Reddit Fetcher

set -e  # Exit on any error

echo "Starting Reddit Saved Posts Fetcher"
echo "Configuration:"
echo "   - Output Format: ${OUTPUT_FORMAT:-json}"
echo "   - Fetch Interval: ${FETCH_INTERVAL:-86400} seconds"
echo "   - Force Fetch: ${FORCE_FETCH:-false}"
echo "   - Data Directory: /data"
echo "   - Reddit Username: ${REDDIT_USERNAME:-not set}"

if [ "$1" = "auth" ]; then
    echo "Starting OAuth setup"
    echo "Open the printed Reddit URL in your browser."
    echo "Make sure this container publishes the redirect port, for example: -p 8080:8080"
    exec python3 -m reddit_fetch.generate_tokens
fi

# Function to check if required files exist
check_requirements() {
    echo "Checking requirements..."
    
    # Check if tokens.json exists
    if [ ! -f "/data/tokens.json" ]; then
        echo "ERROR: /data/tokens.json not found!"
        echo ""
        echo "To fix this:"
        echo "1. Generate tokens with this Docker auth command:"
        echo "   docker run --rm -it --env-file .env -e DOCKER=1 -p 8080:8080 -v \"\$(pwd)/data:/data\" <image> auth"
        echo "2. Restart this container:"
        echo "   docker-compose restart"
        echo ""
        exit 1
    fi
    
    # Check basic environment variables
    if [ -z "$CLIENT_ID" ]; then
        echo "ERROR: CLIENT_ID environment variable not set!"
        exit 1
    fi
    
    if [ -z "$CLIENT_SECRET" ]; then
        echo "ERROR: CLIENT_SECRET environment variable not set!"
        exit 1
    fi
    
    if [ -z "$REDDIT_USERNAME" ]; then
        echo "ERROR: REDDIT_USERNAME environment variable not set!"
        exit 1
    fi
    
    # Check if tokens.json is readable and has content
    if [ ! -s "/data/tokens.json" ]; then
        echo "ERROR: /data/tokens.json is empty!"
        echo "Please regenerate tokens.json"
        exit 1
    fi
    
    # Validate tokens.json format
    if ! python3 -c "import json; json.load(open('/data/tokens.json'))" 2>/dev/null; then
        echo "ERROR: /data/tokens.json is not valid JSON!"
        echo "Please regenerate tokens.json"
        exit 1
    fi
    
    echo "Requirements check passed"
}

# Function to run the fetcher
run_fetcher() {
    echo "Fetching Reddit saved posts..."
    
    # Set environment variables for the reddit-fetcher command
    export OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
    export FORCE_FETCH="${FORCE_FETCH:-false}"
    
    # Run the fetcher and capture exit code
    if reddit-fetcher; then
        echo "Fetch completed successfully"
        return 0
    else
        exit_code=$?
        echo "Fetch failed with exit code: $exit_code"
        
        # Provide helpful error messages based on common issues
        case $exit_code in
            1)
                echo "This might be an authentication or configuration error."
                echo "   - Check your .env file and tokens.json"
                echo "   - Verify your Reddit app credentials"
                echo "   - Try regenerating tokens.json"
                ;;
            130)
                echo "Process was interrupted (Ctrl+C)"
                ;;
            *)
                echo "Unexpected error occurred. Check the logs above."
                echo "   - Check your internet connection"
                echo "   - Verify Reddit API is accessible"
                echo "   - Check file permissions in /data directory"
                ;;
        esac
        
        return $exit_code
    fi
}

# Function to handle shutdown gracefully
cleanup() {
    echo ""
    echo "Received shutdown signal"
    echo "Shutting down Reddit Fetcher..."
    exit 0
}

# Set up signal handlers for graceful shutdown
trap cleanup SIGTERM SIGINT

# Check requirements before starting
check_requirements

# If FETCH_INTERVAL is 0 or "once", run once and exit
if [ "$FETCH_INTERVAL" = "0" ] || [ "$FETCH_INTERVAL" = "once" ]; then
    echo "Single run mode"
    run_fetcher
    exit $?
fi

# Validate FETCH_INTERVAL is a number
if ! echo "$FETCH_INTERVAL" | grep -E '^[0-9]+$' > /dev/null; then
    echo "ERROR: FETCH_INTERVAL must be a number (seconds) or 'once'"
    echo "   Current value: $FETCH_INTERVAL"
    exit 1
fi

# Main loop for continuous operation
echo "Starting continuous fetch mode"
echo "   Interval: ${FETCH_INTERVAL} seconds ($(echo "scale=2; $FETCH_INTERVAL/3600" | bc 2>/dev/null || echo "?") hours)"

run_count=0

while true; do
    run_count=$((run_count + 1))
    echo ""
    echo "Run #${run_count} - $(date)"
    
    if run_fetcher; then
        echo "Sleeping for ${FETCH_INTERVAL} seconds..."
        
        # Calculate next run time (if date command supports it)
        if next_time=$(date -d "+${FETCH_INTERVAL} seconds" 2>/dev/null); then
            echo "   Next run at: $next_time"
        else
            echo "   Next run in: ${FETCH_INTERVAL} seconds"
        fi
        
        # Sleep with ability to interrupt
        sleep "${FETCH_INTERVAL}" &
        wait $!
    else
        echo "Fetch failed on run #${run_count}"
        echo "Retrying in 60 seconds..."
        sleep 60 &
        wait $!
    fi
done
