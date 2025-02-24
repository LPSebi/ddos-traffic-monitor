#!/usr/bin/env bash

# Configuration
CLEANUP_DAYS=1
PNG_FILES=("1.png" "2.png" "3.png" "4.png")

# Initialize variables
ddos_state=0
timerpid=""
webhook_url=""
interface=""
max_speed=""
count_packet=""
avatar_url=""
username=""
script_dir=$(dirname "$0")

# ASCII Art Display
show_header() {
    figlet -c "DDoS Warning Bandwidth"
    echo "Developed by fl0w"
    echo "----------------------------------------"
}

# Display usage information
usage() {
    echo "Usage: $0 <webhook> <interface> <maxspeed(mbit/s)> <count_packets> [avatar] [username]"
    echo
    echo "Required arguments:"
    echo "  webhook        Discord webhook URL"
    echo "  interface      Network interface to monitor"
    echo "  maxspeed       Threshold in Mbit/s for DDoS detection"
    echo "  count_packets  Number of packets for tcpdump to capture"
    echo
    echo "Optional arguments:"
    echo "  avatar         Custom avatar URL for Discord bot"
    echo "  username       Custom username for Discord bot"
    exit 1
}

# Verify dependencies
check_dependencies() {
    local dependencies=("figlet" "tcpdump" "vnstati" "jq")
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required command '$cmd' not found"
            exit 1
        fi
    done

    if [[ ! -x "$script_dir/libs/discord.sh" ]]; then
        echo "Error: discord.sh script not found or not executable in libs directory"
        exit 1
    fi
}

# Send Discord message with optional file
send_discord() {
    local message="$1"
    local file="$2"

    local args=(
        "--webhook-url" "$webhook_url"
        "--text" "$message"
    )

    [[ -n "$avatar_url" ]] && args+=("--avatar" "$avatar_url")
    [[ -n "$username" ]] && args+=("--username" "$username")
    [[ -n "$file" ]] && args+=("--file" "$file")

    "$script_dir/libs/discord.sh" "${args[@]}"
}

# Cleanup old files
cleanup_files() {
    find dumps/ -name "*.pcap" -mtime +$CLEANUP_DAYS -exec rm -f {} \; 2>/dev/null
    rm -f "${PNG_FILES[@]}" second.txt 2>/dev/null
}

# Main execution
main() {
    show_header

    # Validate arguments
    if [[ $# -lt 4 ]]; then
        usage
    fi

    webhook_url="$1"
    interface="$2"
    max_speed="$3"
    count_packet="$4"
    avatar_url="${5:-}"
    username="${6:-}"

    # Validate network interface
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        echo "Error: Network interface $interface does not exist"
        exit 1
    fi

    # Create dump directory if needed
    mkdir -p dumps

    # Initialize previous bandwidth counters
    R1=$(<"/sys/class/net/$interface/statistics/rx_bytes")
    T1=$(<"/sys/class/net/$interface/statistics/tx_bytes")

    while true; do
        # Cleanup old files
        cleanup_files

        # Get current bandwidth
        R2=$(<"/sys/class/net/$interface/statistics/rx_bytes")
        T2=$(<"/sys/class/net/$interface/statistics/tx_bytes")

        # Calculate speeds
        TBPS=$((T2 - T1))
        RBPS=$((R2 - R1))
        TKBPS=$((TBPS / 125000))
        RKBPS=$((RBPS / 125000))

        # Update previous counters
        R1=$R2
        T1=$T2

        current_time=$(date +%F-%T)

        # DDoS detection logic
        if (( RKBPS > max_speed )) && (( ddos_state == 0 )); then
            echo "[$current_time] DDoS START detected: RX ${RKBPS}Mbit/s TX ${TKBPS}Mbit/s"
            send_discord "[$current_time] DDoS START | RX ${RKBPS}Mbit/s TX ${TKBPS}Mbit/s"

            # Start packet capture
            timeout 300 tcpdump -i "$interface" -c "$count_packet" -w "dumps/${current_time}.pcap" &
            tcpdump_pid=$!

            # Start timer
            "$script_dir/libs/timer.sh" &
            timerpid=$!

            # Record initial statistics
            rxdrop1=$(<"/sys/class/net/$interface/statistics/rx_dropped")
            txdrop1=$(<"/sys/class/net/$interface/statistics/tx_dropped")
            rxbytes_start=$(<"/sys/class/net/$interface/statistics/rx_bytes")
            txbytes_start=$(<"/sys/class/net/$interface/statistics/tx_bytes")

            ddos_state=1

        elif (( RKBPS < max_speed )) && (( ddos_state == 1 )); then
            # DDoS end processing
            ddos_state=0
            current_time=$(date +%F-%T)
            
            # Get final statistics
            rxdrop2=$(<"/sys/class/net/$interface/statistics/rx_dropped")
            txdrop2=$(<"/sys/class/net/$interface/statistics/tx_dropped")
            rxbytes_end=$(<"/sys/class/net/$interface/statistics/rx_bytes")
            txbytes_end=$(<"/sys/class/net/$interface/statistics/tx_bytes")

            # Calculate totals
            rx_dropped=$((rxdrop2 - rxdrop1))
            tx_dropped=$((txdrop2 - txdrop1))
            rx_total=$(( (rxbytes_end - rxbytes_start) / 1024 / 1024 ))
            tx_total=$(( (txbytes_end - txbytes_start) / 1024 / 1024 ))

            # Get duration
            kill "$timerpid" 2>/dev/null
            duration=$(<"second.txt")

            # Send notifications
            echo "[$current_time] DDoS END | Duration: ${duration}s"
            send_discord "[$current_time] DDoS END | Duration: ${duration}s"
            
            # Send statistics
            stats_msg="[$current_time] STATS | RX Drop: $rx_dropped, TX Drop: $tx_dropped, Data RX: ${rx_total}MB, Data TX: ${tx_total}MB"
            echo "$stats_msg"
            send_discord "$stats_msg"

            # Generate and send graphs
            vnstati -i "$interface" -5 -o 1.png
            vnstati -i "$interface" -h -o 2.png
            vnstati -i "$interface" -hs -o 3.png
            vnstati -i "$interface" -vs -o 4.png

            for graph in "${PNG_FILES[@]}"; do
                if [[ -f "$graph" ]]; then
                    send_discord "" "$graph"
                    sleep 1  # Rate limit protection
                fi
            done

            # Cleanup temporary files
            cleanup_files
        fi

        sleep 1
    done
}

# Start main program
check_dependencies
main "$@"
