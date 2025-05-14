#!/bin/bash

# === CONFIGURATION ===
BOT_TOKEN="8093819896:AAGcXPGIpr9u7ucuEqXODMGoOjhq5MphlIU"
CHAT_ID="8012388391"
NODE_NAME="VPS1"  # Change this to VPS1, VPS2, VPS3, VPS4 depending on the VPS
PROCESS_NAME="run_rl_swarm.sh"  # The process to monitor (same script on each VPS)
STATUS_FILE="/tmp/${NODE_NAME}_status"
START_TIME_FILE="/tmp/${NODE_NAME}_start_time"
CRASH_TIME_FILE="/tmp/${NODE_NAME}_crash_time"
NGROK_LOG_FILE="/tmp/${NODE_NAME}_ngrok.log"  # The file where the ngrok link will be captured

# === FUNCTIONS ===

send_telegram_message() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown" \
        > /dev/null
}

capture_ngrok_link() {
    # Capture the ngrok link from the log file or output of run_rl_swarm.sh
    ngrok_link=$(tail -n 50 "$NGROK_LOG_FILE" | grep -o 'http[s]\?://[a-zA-Z0-9./?=_-]*' | head -n 1)
    echo "$ngrok_link"
}

start_run_rl_swarm() {
    # Run the node script in the foreground and capture ngrok output
    bash "$PROCESS_NAME" &
    SWARM_PID=$!
    echo "$SWARM_PID" > /tmp/${NODE_NAME}_pid
}

monitor_node() {
    # Initialize start time if not present
    if [[ ! -f "$START_TIME_FILE" ]]; then
        date +%s > "$START_TIME_FILE"
    fi

    while true; do
        PID=$(pgrep -f "$PROCESS_NAME" | head -n 1)
        if [[ -z "$PID" ]]; then
            # If process is not running and status is not already crashed
            if [[ "$(cat "$STATUS_FILE" 2>/dev/null)" != "crashed" ]]; then
                crash_time=$(date '+%Y-%m-%d %H:%M:%S')  # Capture crash time
                echo "$crash_time" > "$CRASH_TIME_FILE"
                echo "crashed" > "$STATUS_FILE"
                send_telegram_message "*${NODE_NAME}*\nSTATUS :- CRASHED ❌\nCRASHED AT : $crash_time"
                sleep 30  # Wait 30 seconds before rerun
                start_run_rl_swarm  # Rerun the node script
                
                # Capture the ngrok link from the log file
                ngrok_link=$(capture_ngrok_link)
                
                send_telegram_message "*${NODE_NAME}* script has been rerun successfully."
                send_telegram_message "*${NODE_NAME}* has started again and is running.\nAccess via ngrok link: $ngrok_link"
            fi
        else
            echo "running" > "$STATUS_FILE"
        fi
        sleep 10
    done
}

listen_for_commands() {
    local offset=0
    while true; do
        response=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=$offset")
        updates=$(echo "$response" | jq -c '.result[]')
        for update in $updates; do
            offset=$(($(echo "$update" | jq '.update_id') + 1))
            message_text=$(echo "$update" | jq -r '.message.text')
            user_chat_id=$(echo "$update" | jq -r '.message.chat.id')

            if [[ "$user_chat_id" == "$CHAT_ID" && "$message_text" == "/status" ]]; then
                if [[ -f "$STATUS_FILE" && "$(cat $STATUS_FILE)" == "running" ]]; then
                    now=$(date +%s)
                    start_time=$(cat "$START_TIME_FILE")
                    uptime=$((now - start_time))
                    hours=$((uptime / 3600))
                    mins=$(((uptime % 3600) / 60))
                    secs=$((uptime % 60))
                    send_telegram_message "*${NODE_NAME}*\nSTATUS :- RUNNING ✅\nRUNTIME: ${hours}h ${mins}m ${secs}s"
                elif [[ -f "$STATUS_FILE" && "$(cat $STATUS_FILE)" == "crashed" ]]; then
                    crash_time=$(cat "$CRASH_TIME_FILE")
                    crash_seconds=$(date -d "$crash_time" +%s)
                    crash_uptime=$((now - crash_seconds))
                    crash_hours=$((crash_uptime / 3600))
                    crash_mins=$(((crash_uptime % 3600) / 60))
                    crash_secs=$((crash_uptime % 60))
                    send_telegram_message "*${NODE_NAME}*\nSTATUS :- CRASHED ❌\nCRASHED AT : ${crash_hours}h ${crash_mins}m ${crash_secs}s"
                else
                    send_telegram_message "*${NODE_NAME}*\nSTATUS :- UNKNOWN"
                fi
            fi
        done
        sleep 3
    done
}

# === MAIN ===

# Start the process and monitoring in the background
start_run_rl_swarm &
monitor_node &
listen_for_commands
