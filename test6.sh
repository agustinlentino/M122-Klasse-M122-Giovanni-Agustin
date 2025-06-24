#!/bin/bash

#==============================================================================
# Simple Weather Script using Open-Meteo API
# A basic weather information fetcher using the free Open-Meteo API
#==============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/weather.conf"

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
EOF
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
    fi
}

# Load configuration from file
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Error: Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Source the configuration file
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    
    debug "Configuration loaded from: $CONFIG_FILE"
    debug "DEFAULT_CITY: $DEFAULT_CITY"
    debug "DEFAULT_COUNTRY: $DEFAULT_COUNTRY"
    debug "DEBUG: $DEBUG"
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
        echo "❌ Error: Missing required dependencies: ${missing_deps[*]}"
        echo "   Please install them:"
        echo "   Ubuntu/Debian: sudo apt install curl jq"
        echo "   CentOS/RHEL:   sudo yum install curl jq"
        echo "   macOS:         brew install curl jq"
        exit 1
    fi
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
    
    # Build the URL with proper parameter encoding
    local url="${GEOCODING_URL}?name=$(printf "%s" "$query" | sed 's/ /%20/g')&count=1&language=en&format=json"
    debug "Geocoding URL: $url"
    
    local geocoding_response
    geocoding_response=$(curl -s "$url")
    local curl_exit_code=$?
    
    debug "Curl exit code: $curl_exit_code"
    debug "Raw geocoding response: $geocoding_response"
    
    if [ $curl_exit_code -ne 0 ]; then
        echo "❌ Error: Failed to fetch coordinates (curl error: $curl_exit_code)" >&2
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$geocoding_response" | jq empty 2>/dev/null; then
        echo "❌ Error: Invalid JSON response from geocoding API" >&2
        debug "Response was: $geocoding_response"
        return 1
    fi
    
    # Check if we got results
    local result_count=$(echo "$geocoding_response" | jq -r '.results | length // 0')
    debug "Result count: $result_count"
    
    if [ "$result_count" -eq 0 ]; then
        echo "❌ Error: Location '$query' not found" >&2
        echo "   Try a different spelling or just the city name without country" >&2
        debug "Full response: $(echo "$geocoding_response" | jq .)"
        return 1
    fi
    
    # Extract latitude and longitude
    local latitude=$(echo "$geocoding_response" | jq -r '.results[0].latitude')
    local longitude=$(echo "$geocoding_response" | jq -r '.results[0].longitude')
    local found_name=$(echo "$geocoding_response" | jq -r '.results[0].name // "Unknown"')
    local found_country=$(echo "$geocoding_response" | jq -r '.results[0].country // "Unknown"')
    
    debug "Found location: $found_name, $found_country"
    debug "Coordinates: $latitude, $longitude"
    
    echo "   Found: $found_name, $found_country ($latitude, $longitude)" >&2
    echo "$latitude,$longitude"
}

# Fetch weather data from Open-Meteo API
get_weather_data() {
    local coordinates="$1"
    local latitude=$(echo "$coordinates" | cut -d',' -f1)
    local longitude=$(echo "$coordinates" | cut -d',' -f2)
    
    echo "🌡️ Fetching weather data..." >&2
    
    local weather_url="${WEATHER_URL}?latitude=${latitude}&longitude=${longitude}"
    weather_url="${weather_url}&current=${CURRENT_PARAMS}"
    weather_url="${weather_url}&temperature_unit=${TEMPERATURE_UNIT}"
    weather_url="${weather_url}&wind_speed_unit=${WIND_SPEED_UNIT}"
    weather_url="${weather_url}&timezone=${TIMEZONE}"
    weather_url="${weather_url}&forecast_days=${FORECAST_DAYS}"
    
    debug "Weather URL: $weather_url"
    
    local weather_response=$(curl -s "$weather_url")
    local curl_exit_code=$?
    
    debug "Weather curl exit code: $curl_exit_code"
    debug "Weather response: $weather_response"
    
    if [ $curl_exit_code -ne 0 ]; then
        echo "❌ Error: Failed to fetch weather data (curl error: $curl_exit_code)" >&2
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$weather_response" | jq empty 2>/dev/null; then
        echo "❌ Error: Invalid JSON response from weather API" >&2
        debug "Weather response was: $weather_response"
        return 1
    fi
    
    echo "$weather_response"
}

# Display weather information
display_weather() {
    local weather_data="$1"
    local city="$2"
    local country="$3"
    
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
    
    # Display weather information
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
    echo ""
    echo "Edit $CONFIG_FILE to change these settings"
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    # Handle special arguments
    case "${1:-}" in
        --config|config)
            create_default_config
            load_config
            show_config
            return 0
            ;;
        --help|help|-h)
            echo "Weather Script Usage:"
            echo "  $0                          # Use default city from config"
            echo "  $0 \"London\"                 # Specific city"
            echo "  $0 \"Berlin\" \"Germany\"       # City and country"
            echo "  $0 --config                 # Show current configuration"
            echo "  $0 --help                   # Show this help"
            echo ""
            echo "Configuration file: $CONFIG_FILE"
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
    
    local city="${1:-$DEFAULT_CITY}"
    local country="${2:-$DEFAULT_COUNTRY}"
    
    echo "🌤️ Simple Weather Script (Open-Meteo)"
    echo "=================================================="
    
    # Check dependencies
    check_dependencies
    
    # Get coordinates
    local coordinates
    coordinates=$(get_coordinates "$city" "$country")
    if [ $? -ne 0 ]; then
        echo ""
        echo "💡 Try these alternatives:"
        echo "   $0 \"Zurich\""
        echo "   $0 \"London\""
        echo "   $0 \"New York\""
        echo ""
        echo "🔧 Edit configuration: $CONFIG_FILE"
        echo "🐛 For debugging, set DEBUG=1 in the config file"
        exit 1
    fi
    
    # Get weather data
    local weather_data
    weather_data=$(get_weather_data "$coordinates")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Display weather
    display_weather "$weather_data" "$city" "$country"
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Run main function with all arguments
main "$@"
