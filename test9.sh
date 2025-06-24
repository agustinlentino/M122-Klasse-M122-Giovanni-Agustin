#!/bin/bash

#==============================================================================
# Simple Weather Script using Open-Meteo API
# A basic weather information fetcher using the free Open-Meteo API
#==============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/weather.conf"
LOG_FILE="$SCRIPT_DIR/weather.log"

# =============================================================================
# DEFAULT CONFIGURATION VALUES
# =============================================================================

# These are used when creating a new config file
DEFAULT_CONFIG() {
    cat << 'EOF'
# Weather Script Configuration File
# Edit these values to customize the weather script behavior

# Default city configuration
DEFAULT_CITY="Zurich"
DEFAULT_COUNTRY="Switzerland"

# Open-Meteo API URLs (usually don't need to change these)
GEOCODING_URL="https://geocoding-api.open-meteo.com/v1/search"
WEATHER_URL="https://api.open-meteo.com/v1/forecast"

# Weather parameters to fetch
CURRENT_PARAMS="temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m"

# Units configuration
TEMPERATURE_UNIT="celsius"  # celsius or fahrenheit
WIND_SPEED_UNIT="kmh"      # kmh, ms, mph, kn
TIMEZONE="auto"            # auto uses location timezone
FORECAST_DAYS="1"          # 0 = today only, max 16

# Debug mode (set to 1 to enable debug output, 0 to disable)
DEBUG=0

# Display settings
SHOW_EMOJI=1               # 1 = show emojis, 0 = text only
COMPACT_OUTPUT=0           # 1 = compact display, 0 = detailed

# Logging settings
ENABLE_LOGGING=1           # 1 = enable logging, 0 = disable
LOG_LEVEL="WEATHER"        # WEATHER, INFO, DEBUG
                           # WEATHER = Only weather data and errors
                           # INFO = Weather data, errors, and basic info
                           # DEBUG = Everything including technical details
MAX_LOG_SIZE_MB=10         # Maximum log file size in MB before rotation
KEEP_LOG_FILES=5           # Number of old log files to keep after rotation

# Cronjob settings
ENABLE_CRONJOB=1           # 1 = enable automatic cronjob, 0 = disable
CRON_TIME="0 8 * * *"      # Cron time format (default: 8:00 AM daily)
                           # Format: minute hour day month weekday
                           # Examples:
                           # "0 8 * * *"     = Every day at 8:00 AM
                           # "30 7 * * 1-5"  = Monday-Friday at 7:30 AM
                           # "0 */6 * * *"   = Every 6 hours
                           # "0 12 * * 0"    = Every Sunday at noon
CRON_CITY=""               # City for cronjob (empty = use DEFAULT_CITY)
CRON_COUNTRY=""            # Country for cronjob (empty = use DEFAULT_COUNTRY)
EOF
}

# =============================================================================
# CRONJOB MANAGEMENT
# =============================================================================

# Check if cronjob exists
check_cronjob_exists() {
    local script_path="$1"
    crontab -l 2>/dev/null | grep -F "$script_path" >/dev/null
    return $?
}

# Install cronjob
install_cronjob() {
    local script_path="$(realpath "$0")"
    local cron_city="${CRON_CITY:-$DEFAULT_CITY}"
    local cron_country="${CRON_COUNTRY:-$DEFAULT_COUNTRY}"
    
    log_info "Installing cronjob with schedule: $CRON_TIME"
    
    # Build cron command
    local cron_cmd="$script_path"
    if [ -n "$cron_city" ]; then
        cron_cmd="$cron_cmd \"$cron_city\""
        if [ -n "$cron_country" ]; then
            cron_cmd="$cron_cmd \"$cron_country\""
        fi
    fi
    
    # Add logging redirect for cron
    cron_cmd="$cron_cmd --cron"
    
    # Create new cron entry
    local cron_entry="$CRON_TIME $cron_cmd"
    local cron_comment="# Weather Script - Auto-generated"
    
    echo "📅 Installing cronjob..." >&2
    echo "   Schedule: $CRON_TIME ($(describe_cron_schedule "$CRON_TIME"))" >&2
    echo "   Command: $cron_cmd" >&2
    
    # Get current crontab, remove old entries, add new one
    local temp_cron=$(mktemp)
    (crontab -l 2>/dev/null | grep -v "$script_path"; echo "$cron_comment"; echo "$cron_entry") > "$temp_cron"
    
    if crontab "$temp_cron" 2>/dev/null; then
        rm -f "$temp_cron"
        echo "✅ Cronjob installed successfully" >&2
        log_info "Cronjob installed: $cron_entry"
        return 0
    else
        rm -f "$temp_cron"
        local error_msg="Failed to install cronjob"
        echo "❌ $error_msg" >&2
        log_error "$error_msg"
        return 1
    fi
}

# Remove cronjob
remove_cronjob() {
    local script_path="$(realpath "$0")"
    
    echo "📅 Removing cronjob..." >&2
    log_info "Removing cronjob for script: $script_path"
    
    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$script_path" > "$temp_cron"
    
    if crontab "$temp_cron" 2>/dev/null; then
        rm -f "$temp_cron"
        echo "✅ Cronjob removed successfully" >&2
        log_info "Cronjob removed successfully"
        return 0
    else
        rm -f "$temp_cron"
        local error_msg="Failed to remove cronjob"
        echo "❌ $error_msg" >&2
        log_error "$error_msg"
        return 1
    fi
}

# Describe cron schedule in human readable format
describe_cron_schedule() {
    local cron_time="$1"
    local minute=$(echo "$cron_time" | cut -d' ' -f1)
    local hour=$(echo "$cron_time" | cut -d' ' -f2)
    local day=$(echo "$cron_time" | cut -d' ' -f3)
    local month=$(echo "$cron_time" | cut -d' ' -f4)
    local weekday=$(echo "$cron_time" | cut -d' ' -f5)
    
    # Simple descriptions for common patterns
    case "$cron_time" in
        "0 8 * * *") echo "Daily at 8:00 AM" ;;
        "30 7 * * 1-5") echo "Weekdays at 7:30 AM" ;;
        "0 */6 * * *") echo "Every 6 hours" ;;
        "0 12 * * 0") echo "Sundays at noon" ;;
        *) 
            local desc="At "
            [ "$minute" != "*" ] && desc="${desc}${minute}m "
            [ "$hour" != "*" ] && desc="${desc}${hour}h "
            echo "$desc$cron_time"
            ;;
    esac
}

# Check and setup cronjob if needed
setup_cronjob() {
    if [ "$ENABLE_CRONJOB" -ne 1 ]; then
        log_debug "Cronjob disabled in configuration"
        return 0
    fi
    
    local script_path="$(realpath "$0")"
    
    if check_cronjob_exists "$script_path"; then
        log_debug "Cronjob already exists for: $script_path"
        return 0
    fi
    
    echo "⏰ Cronjob not found. Setting up automatic weather updates..." >&2
    install_cronjob
}

# Show cronjob status
show_cronjob_status() {
    local script_path="$(realpath "$0")"
    
    echo "⏰ Cronjob Status:"
    echo "=================================================="
    echo "Enabled in config: $([ "$ENABLE_CRONJOB" -eq 1 ] && echo "YES" || echo "NO")"
    echo "Schedule: $CRON_TIME ($(describe_cron_schedule "$CRON_TIME"))"
    echo "Cron City: ${CRON_CITY:-$DEFAULT_CITY}"
    echo "Cron Country: ${CRON_COUNTRY:-$DEFAULT_COUNTRY}"
    echo ""
    
    if check_cronjob_exists "$script_path"; then
        echo "Status: ✅ INSTALLED"
        echo "Current cron entries for this script:"
        echo "--------------------------------------------------"
        crontab -l 2>/dev/null | grep "$script_path"
    else
        echo "Status: ❌ NOT INSTALLED"
        if [ "$ENABLE_CRONJOB" -eq 1 ]; then
            echo "💡 Run the script normally to auto-install the cronjob"
        fi
    fi
    echo ""
}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Initialize logging
init_logging() {
    # Create log file if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || {
            echo "❌ Warning: Cannot create log file: $LOG_FILE" >&2
            ENABLE_LOGGING=0
            return 1
        }
        log_info "Log file initialized: $LOG_FILE"
    fi
    
    # Check log file size and rotate if necessary
    rotate_log_if_needed
}

# Log rotation function
rotate_log_if_needed() {
    if [ ! -f "$LOG_FILE" ] || [ "$ENABLE_LOGGING" -eq 0 ]; then
        return 0
    fi
    
    # Get file size in MB
    local file_size_bytes=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    local file_size_mb=$((file_size_bytes / 1024 / 1024))
    
    if [ "$file_size_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
        log_info "Rotating log file (size: ${file_size_mb}MB)"
        
        # Rotate existing log files
        for ((i=KEEP_LOG_FILES-1; i>=1; i--)); do
            local old_log="${LOG_FILE}.$i"
            local new_log="${LOG_FILE}.$((i+1))"
            [ -f "$old_log" ] && mv "$old_log" "$new_log"
        done
        
        # Move current log to .1
        mv "$LOG_FILE" "${LOG_FILE}.1"
        touch "$LOG_FILE"
        
        log_info "Log rotation completed"
    fi
}

# Generic logging function
write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$ENABLE_LOGGING" -eq 1 ]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
    fi
}

# Check if log level should be written based on configuration
should_log_level() {
    local level="$1"
    
    case "$LOG_LEVEL" in
        "WEATHER")
            case "$level" in
                "WEATHER"|"ERROR") return 0 ;;
                *) return 1 ;;
            esac
            ;;
        "INFO")
            case "$level" in
                "WEATHER"|"ERROR"|"INFO") return 0 ;;
                *) return 1 ;;
            esac
            ;;
        "DEBUG")
            return 0  # Log everything
            ;;
        *)
            case "$level" in
                "WEATHER"|"ERROR") return 0 ;;
                *) return 1 ;;
            esac
            ;;
    esac
}

# Specific log level functions
log_debug() {
    if should_log_level "DEBUG"; then
        write_log "DEBUG" "$1"
    fi
    debug "$1"  # Also show in debug output if enabled
}

log_info() {
    if should_log_level "INFO"; then
        write_log "INFO" "$1"
    fi
}

log_warn() {
    if should_log_level "WARN"; then
        write_log "WARN" "$1"
    fi
}

log_error() {
    if should_log_level "ERROR"; then
        write_log "ERROR" "$1"
    fi
}

# Log weather data in structured format - always logged regardless of level if logging is enabled
log_weather_data() {
    local city="$1"
    local country="$2"
    local temperature="$3"
    local weather_desc="$4"
    local humidity="$5"
    local wind_speed="$6"
    local wind_direction="$7"
    
    local location="$city"
    [ -n "$country" ] && location="$city, $country"
    
    # Clean weather description (remove emoji for cleaner log)
    local clean_desc=$(echo "$weather_desc" | sed 's/^[[:space:]]*[^[:alpha:]]*[[:space:]]*//')
    
    if [ "$ENABLE_LOGGING" -eq 1 ]; then
        write_log "WEATHER" "Location='$location' Temp='${temperature}°C' Condition='$clean_desc' Humidity='${humidity}%' Wind='${wind_speed}km/h@${wind_direction}°'"
    fi
}

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

# Create default config file if it doesn't exist
create_default_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "📁 Creating default configuration file: $CONFIG_FILE"
        DEFAULT_CONFIG > "$CONFIG_FILE"
        echo "✅ Configuration file created with default values"
        echo "   Edit $CONFIG_FILE to customize settings"
        echo ""
        log_info "Default configuration file created: $CONFIG_FILE"
    fi
}

# Load configuration from file
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        echo "❌ Error: Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Source the configuration file
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    
    log_debug "Configuration loaded from: $CONFIG_FILE"
    log_debug "DEFAULT_CITY: $DEFAULT_CITY, DEFAULT_COUNTRY: $DEFAULT_COUNTRY, DEBUG: $DEBUG"
}

# =============================================================================
# WEATHER CODE MAPPING
# =============================================================================

get_weather_description() {
    local code=$1
    local emoji=""
    local description=""
    
    case $code in
        0) emoji="☀️"; description="Clear sky" ;;
        1) emoji="🌤️"; description="Mainly clear" ;;
        2) emoji="⛅"; description="Partly cloudy" ;;
        3) emoji="☁️"; description="Overcast" ;;
        45) emoji="🌫️"; description="Fog" ;;
        48) emoji="🌫️"; description="Depositing rime fog" ;;
        51) emoji="🌦️"; description="Light drizzle" ;;
        53) emoji="🌦️"; description="Moderate drizzle" ;;
        55) emoji="🌦️"; description="Dense drizzle" ;;
        61) emoji="🌧️"; description="Slight rain" ;;
        63) emoji="🌧️"; description="Moderate rain" ;;
        65) emoji="🌧️"; description="Heavy rain" ;;
        71) emoji="❄️"; description="Slight snow fall" ;;
        73) emoji="❄️"; description="Moderate snow fall" ;;
        75) emoji="❄️"; description="Heavy snow fall" ;;
        80) emoji="🌦️"; description="Slight rain showers" ;;
        81) emoji="🌧️"; description="Moderate rain showers" ;;
        82) emoji="⛈️"; description="Violent rain showers" ;;
        95) emoji="⛈️"; description="Thunderstorm" ;;
        96) emoji="⛈️"; description="Thunderstorm with slight hail" ;;
        99) emoji="⛈️"; description="Thunderstorm with heavy hail" ;;
        *) emoji="🌡️"; description="Weather code: $code" ;;
    esac
    
    if [ "$SHOW_EMOJI" -eq 1 ]; then
        echo "$emoji $description"
    else
        echo "$description"
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Debug output function
debug() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "🐛 DEBUG: $*" >&2
    fi
}

# Check if required commands exist
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        local error_msg="Missing required dependencies: ${missing_deps[*]}"
        log_error "$error_msg"
        echo "❌ Error: $error_msg"
        echo "   Please install them:"
        echo "   Ubuntu/Debian: sudo apt install curl jq"
        echo "   CentOS/RHEL:   sudo yum install curl jq"
        echo "   macOS:         brew install curl jq"
        exit 1
    fi
    
    log_info "Dependencies check passed"
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

# Get coordinates for a city using geocoding API
get_coordinates() {
    local city="$1"
    local country="$2"
    local query="$city"
    
    if [ -n "$country" ]; then
        query="$city, $country"
    fi
    
    echo "📍 Getting coordinates for $query..." >&2
    log_info "Getting coordinates for: $query"
    
    # Build the URL with proper parameter encoding
    local url="${GEOCODING_URL}?name=$(printf "%s" "$query" | sed 's/ /%20/g')&count=1&language=en&format=json"
    log_debug "Geocoding URL: $url"
    
    local geocoding_response
    geocoding_response=$(curl -s "$url")
    local curl_exit_code=$?
    
    log_debug "Geocoding curl exit code: $curl_exit_code"
    
    if [ $curl_exit_code -ne 0 ]; then
        local error_msg="Failed to fetch coordinates (curl error: $curl_exit_code)"
        log_error "$error_msg"
        echo "❌ Error: $error_msg" >&2
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$geocoding_response" | jq empty 2>/dev/null; then
        local error_msg="Invalid JSON response from geocoding API"
        log_error "$error_msg"
        log_debug "Geocoding response was: $geocoding_response"
        echo "❌ Error: $error_msg" >&2
        return 1
    fi
    
    # Check if we got results
    local result_count=$(echo "$geocoding_response" | jq -r '.results | length // 0')
    log_debug "Geocoding result count: $result_count"
    
    if [ "$result_count" -eq 0 ]; then
        local error_msg="Location '$query' not found"
        log_error "$error_msg"
        echo "❌ Error: $error_msg" >&2
        echo "   Try a different spelling or just the city name without country" >&2
        return 1
    fi
    
    # Extract latitude and longitude
    local latitude=$(echo "$geocoding_response" | jq -r '.results[0].latitude')
    local longitude=$(echo "$geocoding_response" | jq -r '.results[0].longitude')
    local found_name=$(echo "$geocoding_response" | jq -r '.results[0].name // "Unknown"')
    local found_country=$(echo "$geocoding_response" | jq -r '.results[0].country // "Unknown"')
    
    log_info "Found location: $found_name, $found_country (${latitude}, ${longitude})"
    
    echo "   Found: $found_name, $found_country ($latitude, $longitude)" >&2
    echo "$latitude,$longitude"
}

# Fetch weather data from Open-Meteo API
get_weather_data() {
    local coordinates="$1"
    local latitude=$(echo "$coordinates" | cut -d',' -f1)
    local longitude=$(echo "$coordinates" | cut -d',' -f2)
    
    echo "🌡️ Fetching weather data..." >&2
    log_info "Fetching weather data for coordinates: $latitude, $longitude"
    
    local weather_url="${WEATHER_URL}?latitude=${latitude}&longitude=${longitude}"
    weather_url="${weather_url}&current=${CURRENT_PARAMS}"
    weather_url="${weather_url}&temperature_unit=${TEMPERATURE_UNIT}"
    weather_url="${weather_url}&wind_speed_unit=${WIND_SPEED_UNIT}"
    weather_url="${weather_url}&timezone=${TIMEZONE}"
    weather_url="${weather_url}&forecast_days=${FORECAST_DAYS}"
    
    log_debug "Weather API URL: $weather_url"
    
    local weather_response=$(curl -s "$weather_url")
    local curl_exit_code=$?
    
    log_debug "Weather API curl exit code: $curl_exit_code"
    
    if [ $curl_exit_code -ne 0 ]; then
        local error_msg="Failed to fetch weather data (curl error: $curl_exit_code)"
        log_error "$error_msg"
        echo "❌ Error: $error_msg" >&2
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$weather_response" | jq empty 2>/dev/null; then
        local error_msg="Invalid JSON response from weather API"
        log_error "$error_msg"
        log_debug "Weather response was: $weather_response"
        echo "❌ Error: $error_msg" >&2
        return 1
    fi
    
    log_info "Weather data fetched successfully"
    echo "$weather_response"
}

# Display weather information
display_weather() {
    local weather_data="$1"
    local city="$2"
    local country="$3"
    local is_cron="${4:-0}"
    
    # Parse weather data using jq
    local temperature=$(echo "$weather_data" | jq -r '.current.temperature_2m // "N/A"')
    local humidity=$(echo "$weather_data" | jq -r '.current.relative_humidity_2m // "N/A"')
    local weather_code=$(echo "$weather_data" | jq -r '.current.weather_code // "N/A"')
    local wind_speed=$(echo "$weather_data" | jq -r '.current.wind_speed_10m // "N/A"')
    local wind_direction=$(echo "$weather_data" | jq -r '.current.wind_direction_10m // "N/A"')
    local update_time=$(echo "$weather_data" | jq -r '.current.time // "Unknown"')
    
    # Build location string
    local location="$city"
    if [ -n "$country" ]; then
        location="$city, $country"
    fi
    
    # Get weather description
    local weather_desc=$(get_weather_description "$weather_code")
    local weather_emoji=""
    
    if [ "$SHOW_EMOJI" -eq 1 ]; then
        weather_emoji=$(echo "$weather_desc" | cut -d' ' -f1)
    fi
    
    # Get temperature unit symbol
    local temp_unit="°C"
    if [ "$TEMPERATURE_UNIT" = "fahrenheit" ]; then
        temp_unit="°F"
    fi
    
    # Log the weather data (always logged at WEATHER level)
    log_weather_data "$city" "$country" "$temperature" "$weather_desc" "$humidity" "$wind_speed" "$wind_direction"
    
    # Display weather information (skip if running from cron and output is not compact)
    if [ "$is_cron" -eq 0 ] || [ "$COMPACT_OUTPUT" -eq 1 ]; then
        echo ""
        if [ "$COMPACT_OUTPUT" -eq 1 ]; then
            # Compact format
            echo "$weather_emoji $location: ${temperature}${temp_unit}, $weather_desc, ${humidity}% humidity"
        else
            # Detailed format
            echo "$weather_emoji Weather in $location"
            echo "=================================================="
            echo "Temperature: ${temperature}${temp_unit}"
            echo "Condition: $weather_desc"
            echo "Humidity: ${humidity}%"
            echo "Wind: ${wind_speed} ${WIND_SPEED_UNIT} at ${wind_direction}°"
            echo "Last updated: $update_time"
        fi
    fi
}

# Show configuration information
show_config() {
    echo "📋 Current Configuration (from $CONFIG_FILE):"
    echo "=================================================="
    echo "Default City: $DEFAULT_CITY"
    echo "Default Country: $DEFAULT_COUNTRY"
    echo "Temperature Unit: $TEMPERATURE_UNIT"
    echo "Wind Speed Unit: $WIND_SPEED_UNIT"
    echo "Debug Mode: $([ "$DEBUG" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "Show Emoji: $([ "$SHOW_EMOJI" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "Compact Output: $([ "$COMPACT_OUTPUT" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "Logging: $([ "$ENABLE_LOGGING" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "Log Level: $LOG_LEVEL"
    echo "Log File: $LOG_FILE"
    echo ""
    show_cronjob_status
    echo ""
    echo "Log Levels explained:"
    echo "  WEATHER = Only weather data and errors"
    echo "  INFO    = Weather data, errors, and basic info"
    echo "  DEBUG   = Everything including technical details"
    echo ""
    echo "Edit $CONFIG_FILE to change these settings"
}

# Show log file information
show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "📝 No log file found: $LOG_FILE"
        return 1
    fi
    
    local file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    local file_size_kb=$((file_size / 1024))
    local line_count=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    
    echo "📝 Log File Information:"
    echo "=================================================="
    echo "Log file: $LOG_FILE"
    echo "Size: ${file_size_kb}KB (${file_size} bytes)"
    echo "Lines: $line_count"
    echo "Current log level: $LOG_LEVEL"
    echo ""
    
    # Show recent log entries
    if [ "$line_count" -gt 0 ]; then
        echo "Recent entries (last 15):"
        echo "--------------------------------------------------"
        tail -n 15 "$LOG_FILE"
    else
        echo "Log file is empty"
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    local is_cron=0
    
    # Handle special arguments
    case "${1:-}" in
        --config|config)
            create_default_config
            load_config
            init_logging
            show_config
            return 0
            ;;
        --logs|logs)
            create_default_config
            load_config
            show_logs
            return 0
            ;;
        --cron)
            is_cron=1
            shift  # Remove --cron from arguments
            ;;
        --install-cron)
            create_default_config
            load_config
            init_logging
            install_cronjob
            return 0
            ;;
        --remove-cron)
            create_default_config
            load_config
            init_logging
            remove_cronjob
            return 0
            ;;
        --help|help|-h)
            echo "Weather Script Usage:"
            echo "  $0                          # Use default city from config"
            echo "  $0 \"London\"                 # Specific city"
            echo "  $0 \"Berlin\" \"Germany\"       # City and country"
            echo "  $0 --config                 # Show current configuration"
            echo "  $0 --logs                   # Show log information"
            echo "  $0 --install-cron           # Manually install cronjob"
            echo "  $0 --remove-cron            # Remove cronjob"
            echo "  $0 --help                   # Show this help"
            echo ""
            echo "Files:"
            echo "  Configuration: $CONFIG_FILE"
            echo "  Log file:      $LOG_FILE"
            echo ""
            echo "Log Levels:"
            echo "  WEATHER = Only weather data and errors (cleanest)"
            echo "  INFO    = Weather data, errors, and basic operations"
            echo "  DEBUG   = Everything including technical details"
            echo ""
            echo "Cronjob will be automatically set up on first normal run if enabled in config."
            return 0
            ;;
    esac
    
    # Create config file if it doesn't exist
    create_default_config
    
    # Load configuration
    load_config
    if [ $? -ne 0 ]; then
        echo "❌ Failed to load configuration"
        exit 1
    fi
    
    # Initialize logging
    init_logging
    
    # Setup cronjob if this is not a cron execution and cronjob is enabled
    if [ "$is_cron" -eq 0 ]; then
        setup_cronjob
    fi
    
    local city="${1:-$DEFAULT_CITY}"
    local country="${2:-$DEFAULT_COUNTRY}"
    
    log_info "Weather script started with arguments: city='$city' country='$country' cron=$is_cron"
    
    # Only show header if not running from cron
    if [ "$is_cron" -eq 0 ]; then
        echo "🌤️ Simple Weather Script (Open-Meteo)"
        echo "=================================================="
    fi
    
    # Check dependencies
    check_dependencies
    
    # Get coordinates
    local coordinates
    coordinates=$(get_coordinates "$city" "$country")
    if [ $? -ne 0 ]; then
        log_error "Failed to get coordinates for: $city, $country"
        if [ "$is_cron" -eq 0 ]; then
            echo ""
            echo "💡 Try these alternatives:"
            echo "   $0 \"Zurich\""
            echo "   $0 \"London\""
            echo "   $0 \"New York\""
            echo ""
            echo "🔧 Edit configuration: $CONFIG_FILE"
            echo "📝 Check logs: $0 --logs"
            echo "🐛 For debugging, set DEBUG=1 in the config file"
        fi
        exit 1
    fi
    
    # Get weather data
    local weather_data
    weather_data=$(get_weather_data "$coordinates")
    if [ $? -ne 0 ]; then
        log_error "Failed to get weather data"
        exit 1
    fi
    
    # Display weather
    display_weather "$weather_data" "$city" "$country" "$is_cron"
    
    log_info "Weather script completed successfully"
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Run main function with all arguments
main "$@"
