#!/bin/bash

#==============================================================================
# Simple Weather Script using Open-Meteo API
# A basic weather information fetcher using the free Open-Meteo API
#==============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/weather.conf"
LOG_FILE="$SCRIPT_DIR/weather.log"
ERROR_LOG_FILE="$SCRIPT_DIR/error.log"

# GitHub configuration
GITHUB_TOKEN="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"
GITHUB_REPO_URL="https://github.com/LieutenantJimmy/M122-Klasse-M122-Giovanni-Agustin.git"
GITHUB_REPO_NAME="M122-Klasse-M122-Giovanni-Agustin"
GITHUB_BRANCH="main"
REPO_DIR="$SCRIPT_DIR/$GITHUB_REPO_NAME"

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
PRETTY_LOGS=1              # 1 = use emojis and formatting in logs, 0 = plain text
SEPARATE_ERROR_LOG=1       # 1 = separate error log file, 0 = all in one file
MAX_LOG_SIZE_MB=10         # Maximum log file size in MB before rotation
KEEP_LOG_FILES=5           # Number of old log files to keep after rotation

# GitHub integration settings
ENABLE_GITHUB_SYNC=1       # 1 = enable GitHub sync, 0 = disable
AUTO_PUSH_LOGS=1           # 1 = automatically push logs to GitHub, 0 = manual only
SYNC_ON_STARTUP=1          # 1 = sync with GitHub on startup, 0 = disable
SYNC_ERROR_LOG=1           # 1 = also sync error log to GitHub, 0 = weather log only

# Cronjob settings
ENABLE_CRONJOB=1           # 1 = enable automatic cronjob, 0 = disable
CRON_TIME="0 8 * * *"      # Cron time format (default: 8:00 AM daily)
CRON_CITY=""               # City for cronjob (empty = use DEFAULT_CITY)
CRON_COUNTRY=""            # Country for cronjob (empty = use DEFAULT_COUNTRY)
EOF
}

# =============================================================================
# WEATHER CODE TO EMOJI MAPPING
# =============================================================================

# Get weather emoji for log files
get_weather_emoji() {
    local code=$1
    case $code in
        0) echo "☀️" ;;      # Clear sky
        1) echo "🌤️" ;;     # Mainly clear
        2) echo "⛅" ;;      # Partly cloudy
        3) echo "☁️" ;;      # Overcast
        45|48) echo "🌫️" ;; # Fog
        51|53|55) echo "🌦️" ;; # Drizzle
        56|57) echo "🧊" ;;  # Freezing drizzle
        61|63|65) echo "🌧️" ;; # Rain
        66|67) echo "🌨️" ;;  # Freezing rain
        71|73|75) echo "❄️" ;; # Snow
        77) echo "🌨️" ;;     # Snow grains
        80|81) echo "🌦️" ;;  # Rain showers
        82) echo "⛈️" ;;     # Violent rain showers
        85|86) echo "🌨️" ;;  # Snow showers
        95) echo "⛈️" ;;     # Thunderstorm
        96|99) echo "🌩️" ;;  # Thunderstorm with hail
        *) echo "🌡️" ;;      # Unknown
    esac
}

# Get season emoji based on month
get_season_emoji() {
    local month=$(date +%m)
    case $month in
        12|01|02) echo "❄️" ;;  # Winter
        03|04|05) echo "🌸" ;;  # Spring
        06|07|08) echo "☀️" ;;  # Summer
        09|10|11) echo "🍂" ;;  # Autumn
        *) echo "🌍" ;;
    esac
}

# Get time of day emoji
get_time_emoji() {
    local hour=$(date +%H)
    case $hour in
        05|06) echo "🌅" ;;     # Dawn
        07|08|09|10|11) echo "🌇" ;; # Morning
        12|13|14|15) echo "☀️" ;; # Afternoon
        16|17|18) echo "🌆" ;;   # Evening
        19|20|21) echo "🌃" ;;   # Night
        *) echo "🌙" ;;          # Late night/early morning
    esac
}

# =============================================================================
# GIT/GITHUB FUNCTIONS
# =============================================================================

# Check if git is installed and install if needed
check_git_dependency() {
    if ! command -v git &> /dev/null; then
        echo "📦 Git not found. Installing git..." >&2
        log_info "Git not found, attempting to install"
        
        # Detect OS and install git
        if command -v apt &> /dev/null; then
            # Debian/Ubuntu
            sudo apt update && sudo apt install -y git
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL/Fedora
            sudo yum install -y git
        elif command -v dnf &> /dev/null; then
            # Newer Fedora
            sudo dnf install -y git
        elif command -v brew &> /dev/null; then
            # macOS with Homebrew
            brew install git
        elif command -v pacman &> /dev/null; then
            # Arch Linux
            sudo pacman -S git
        else
            echo "❌ Cannot automatically install git. Please install it manually:" >&2
            echo "   Ubuntu/Debian: sudo apt install git" >&2
            echo "   CentOS/RHEL:   sudo yum install git" >&2
            echo "   Fedora:        sudo dnf install git" >&2
            echo "   macOS:         brew install git" >&2
            log_error "Failed to auto-install git - unsupported package manager"
            return 1
        fi
        
        # Verify installation
        if command -v git &> /dev/null; then
            echo "✅ Git installed successfully" >&2
            log_info "Git installed successfully"
        else
            echo "❌ Failed to install git" >&2
            log_error "Failed to install git"
            return 1
        fi
    fi
    
    log_debug "Git dependency check passed"
    return 0
}

# Clone or update GitHub repository
setup_github_repo() {
    if [ "$ENABLE_GITHUB_SYNC" -ne 1 ]; then
        log_debug "GitHub sync disabled in configuration"
        return 0
    fi
    
    check_git_dependency
    if [ $? -ne 0 ]; then
        log_error "Git dependency check failed"
        return 1
    fi
    
    # Prepare authenticated URL
    local auth_url="https://${GITHUB_TOKEN}@github.com/LieutenantJimmy/M122-Klasse-M122-Giovanni-Agustin.git"
    
    if [ -d "$REPO_DIR" ]; then
        # Repository exists, update it
        echo "🔄 Updating existing repository..." >&2
        log_info "Updating existing GitHub repository"
        
        cd "$REPO_DIR" || {
            log_error "Failed to enter repository directory: $REPO_DIR"
            return 1
        }
        
        # Configure git to use the token
        git remote set-url origin "$auth_url" 2>/dev/null
        
        # Fetch latest changes
        if git fetch origin 2>/dev/null; then
            # Try to pull if there are no local changes
            if git status --porcelain | grep -q .; then
                log_warn "Local changes detected, skipping pull"
                echo "⚠️  Local changes detected in repository, skipping pull" >&2
            else
                git pull origin "$GITHUB_BRANCH" 2>/dev/null || {
                    log_warn "Failed to pull latest changes"
                    echo "⚠️  Failed to pull latest changes" >&2
                }
            fi
        else
            log_warn "Failed to fetch from remote repository"
            echo "⚠️  Failed to fetch from remote repository" >&2
        fi
        
        cd "$SCRIPT_DIR" || return 1
    else
        # Repository doesn't exist, clone it
        echo "📥 Cloning GitHub repository..." >&2
        log_info "Cloning GitHub repository: $GITHUB_REPO_URL"
        
        if git clone "$auth_url" "$REPO_DIR" 2>/dev/null; then
            echo "✅ Repository cloned successfully" >&2
            log_info "Repository cloned successfully"
        else
            echo "❌ Failed to clone repository" >&2
            log_error "Failed to clone GitHub repository"
            return 1
        fi
    fi
    
    return 0
}

# Download existing logs from GitHub
download_existing_logs() {
    if [ "$ENABLE_GITHUB_SYNC" -ne 1 ]; then
        return 0
    fi
    
    local repo_weather_log="$REPO_DIR/weather.log"
    local repo_error_log="$REPO_DIR/error.log"
    
    # Download weather log
    if [ -f "$repo_weather_log" ]; then
        echo "📥 Found existing weather log in repository, merging..." >&2
        log_info "Merging existing weather log from GitHub repository"
        
        if [ -f "$LOG_FILE" ]; then
            cp "$LOG_FILE" "${LOG_FILE}.backup" 2>/dev/null
        fi
        
        # Merge weather logs
        {
            [ -f "$repo_weather_log" ] && cat "$repo_weather_log"
            [ -f "${LOG_FILE}.backup" ] && cat "${LOG_FILE}.backup"
        } | sort -u > "$LOG_FILE.tmp" 2>/dev/null
        
        if [ -f "$LOG_FILE.tmp" ]; then
            mv "$LOG_FILE.tmp" "$LOG_FILE"
            echo "✅ Weather logs merged successfully" >&2
            log_info "Weather logs merged successfully"
        else
            echo "⚠️  Failed to merge weather logs, keeping current log" >&2
            log_warn "Failed to merge weather logs"
            [ -f "${LOG_FILE}.backup" ] && mv "${LOG_FILE}.backup" "$LOG_FILE"
        fi
        
        rm -f "${LOG_FILE}.backup" 2>/dev/null
    fi
    
    # Download error log if enabled
    if [ "$SEPARATE_ERROR_LOG" -eq 1 ] && [ "$SYNC_ERROR_LOG" -eq 1 ] && [ -f "$repo_error_log" ]; then
        echo "📥 Found existing error log in repository, merging..." >&2
        log_info "Merging existing error log from GitHub repository"
        
        if [ -f "$ERROR_LOG_FILE" ]; then
            cp "$ERROR_LOG_FILE" "${ERROR_LOG_FILE}.backup" 2>/dev/null
        fi
        
        # Merge error logs
        {
            [ -f "$repo_error_log" ] && cat "$repo_error_log"
            [ -f "${ERROR_LOG_FILE}.backup" ] && cat "${ERROR_LOG_FILE}.backup"
        } | sort -u > "$ERROR_LOG_FILE.tmp" 2>/dev/null
        
        if [ -f "$ERROR_LOG_FILE.tmp" ]; then
            mv "$ERROR_LOG_FILE.tmp" "$ERROR_LOG_FILE"
            echo "✅ Error logs merged successfully" >&2
            log_info "Error logs merged successfully"
        else
            echo "⚠️  Failed to merge error logs, keeping current log" >&2
            log_warn "Failed to merge error logs"
            [ -f "${ERROR_LOG_FILE}.backup" ] && mv "${ERROR_LOG_FILE}.backup" "$ERROR_LOG_FILE"
        fi
        
        rm -f "${ERROR_LOG_FILE}.backup" 2>/dev/null
    fi
}

# Push logs to GitHub
push_logs_to_github() {
    if [ "$ENABLE_GITHUB_SYNC" -ne 1 ] || [ "$AUTO_PUSH_LOGS" -ne 1 ]; then
        return 0
    fi
    
    if [ ! -d "$REPO_DIR" ]; then
        log_error "Repository directory not found: $REPO_DIR"
        return 1
    fi
    
    echo "📤 Pushing logs to GitHub..." >&2
    log_info "Pushing logs to GitHub"
    
    local files_to_add=()
    
    # Copy weather log to repository
    if [ -f "$LOG_FILE" ]; then
        cp "$LOG_FILE" "$REPO_DIR/weather.log" 2>/dev/null || {
            log_error "Failed to copy weather log file to repository"
            echo "❌ Failed to copy weather log file to repository" >&2
            return 1
        }
        files_to_add+=("weather.log")
    fi
    
    # Copy error log to repository if enabled
    if [ "$SEPARATE_ERROR_LOG" -eq 1 ] && [ "$SYNC_ERROR_LOG" -eq 1 ] && [ -f "$ERROR_LOG_FILE" ]; then
        cp "$ERROR_LOG_FILE" "$REPO_DIR/error.log" 2>/dev/null || {
            log_error "Failed to copy error log file to repository"
            echo "❌ Failed to copy error log file to repository" >&2
            return 1
        }
        files_to_add+=("error.log")
    fi
    
    if [ ${#files_to_add[@]} -eq 0 ]; then
        log_debug "No log files to push"
        return 0
    fi
    
    cd "$REPO_DIR" || {
        log_error "Failed to enter repository directory"
        return 1
    }
    
    # Configure git user if not set
    git config user.email "weather-script@automated.local" 2>/dev/null
    git config user.name "Weather Script" 2>/dev/null
    
    # Add files
    for file in "${files_to_add[@]}"; do
        git add "$file" 2>/dev/null
    done
    
    if git diff --staged --quiet; then
        log_debug "No changes to commit"
        cd "$SCRIPT_DIR"
        return 0
    fi
    
    local commit_msg="📊 Update weather logs - $(date '+%Y-%m-%d %H:%M:%S')"
    
    if git commit -m "$commit_msg" 2>/dev/null; then
        # Push to remote
        if git push origin "$GITHUB_BRANCH" 2>/dev/null; then
            echo "✅ Logs pushed to GitHub successfully" >&2
            log_info "Logs pushed to GitHub successfully"
        else
            echo "❌ Failed to push to GitHub" >&2
            log_error "Failed to push logs to GitHub"
            cd "$SCRIPT_DIR"
            return 1
        fi
    else
        echo "❌ Failed to commit changes" >&2
        log_error "Failed to commit log changes"
        cd "$SCRIPT_DIR"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    return 0
}

# Show GitHub status
show_github_status() {
    echo "🐙 GitHub Integration Status:"
    echo "=================================================="
    echo "GitHub Sync: $([ "$ENABLE_GITHUB_SYNC" -eq 1 ] && echo "ENABLED" || echo "DISABLED")"
    echo "Auto Push: $([ "$AUTO_PUSH_LOGS" -eq 1 ] && echo "ENABLED" || echo "DISABLED")"
    echo "Sync on Startup: $([ "$SYNC_ON_STARTUP" -eq 1 ] && echo "ENABLED" || echo "DISABLED")"
    echo "Sync Error Log: $([ "$SYNC_ERROR_LOG" -eq 1 ] && echo "ENABLED" || echo "DISABLED")"
    echo "Repository: $GITHUB_REPO_URL"
    echo "Local Path: $REPO_DIR"
    
    if [ -d "$REPO_DIR" ]; then
        echo "Status: ✅ CLONED"
        
        # Check if we're in the repo directory and get git status
        if cd "$REPO_DIR" 2>/dev/null; then
            local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
            local remote_url=$(git remote get-url origin 2>/dev/null | sed 's/.*@github\.com[:/]//' | sed 's/\.git$//' || echo "unknown")
            echo "Current branch: $branch"
            echo "Remote: $remote_url"
            
            # Check for uncommitted changes
            if git status --porcelain 2>/dev/null | grep -q .; then
                echo "Local changes: ⚠️  YES (uncommitted changes)"
            else
                echo "Local changes: ✅ CLEAN"
            fi
            
            cd "$SCRIPT_DIR"
        fi
    else
        echo "Status: ❌ NOT CLONED"
        echo "💡 Run the script normally to auto-clone the repository"
    fi
    echo ""
}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Initialize logging
init_logging() {
    # Create weather log file if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || {
            echo "❌ Warning: Cannot create weather log file: $LOG_FILE" >&2
            ENABLE_LOGGING=0
            return 1
        }
        
        # Add a pretty header to new weather log
        if [ "$PRETTY_LOGS" -eq 1 ]; then
            cat << 'EOF' > "$LOG_FILE"
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🌤️  WEATHER LOG FILE  🌤️                            ║
║                      📊 Automatic Weather Data Collection 📊                 ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF
        fi
        
        log_info "Weather log file initialized: $LOG_FILE"
    fi
    
    # Create error log file if separate error logging is enabled
    if [ "$SEPARATE_ERROR_LOG" -eq 1 ] && [ ! -f "$ERROR_LOG_FILE" ]; then
        touch "$ERROR_LOG_FILE" 2>/dev/null || {
            echo "❌ Warning: Cannot create error log file: $ERROR_LOG_FILE" >&2
        }
        
        # Add a header to new error log
        if [ "$PRETTY_LOGS" -eq 1 ]; then
            cat << 'EOF' > "$ERROR_LOG_FILE"
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🚨  ERROR LOG FILE  🚨                             ║
║                     🔍 System Errors and Debug Information 🔍               ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF
        fi
        
        log_info "Error log file initialized: $ERROR_LOG_FILE"
    fi
    
    # Download existing logs from GitHub if enabled
    if [ "$SYNC_ON_STARTUP" -eq 1 ]; then
        download_existing_logs
    fi
    
    # Check log file sizes and rotate if necessary
    rotate_log_if_needed
}

# Log rotation function
rotate_log_if_needed() {
    if [ "$ENABLE_LOGGING" -eq 0 ]; then
        return 0
    fi
    
    # Rotate weather log
    if [ -f "$LOG_FILE" ]; then
        local file_size_bytes=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        local file_size_mb=$((file_size_bytes / 1024 / 1024))
        
        if [ "$file_size_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
            log_info "Rotating weather log file (size: ${file_size_mb}MB)"
            
            # Rotate existing log files
            for ((i=KEEP_LOG_FILES-1; i>=1; i--)); do
                local old_log="${LOG_FILE}.$i"
                local new_log="${LOG_FILE}.$((i+1))"
                [ -f "$old_log" ] && mv "$old_log" "$new_log"
            done
            
            # Move current log to .1
            mv "$LOG_FILE" "${LOG_FILE}.1"
            touch "$LOG_FILE"
            
            log_info "Weather log rotation completed"
        fi
    fi
    
    # Rotate error log if separate error logging is enabled
    if [ "$SEPARATE_ERROR_LOG" -eq 1 ] && [ -f "$ERROR_LOG_FILE" ]; then
        local file_size_bytes=$(stat -f%z "$ERROR_LOG_FILE" 2>/dev/null || stat -c%s "$ERROR_LOG_FILE" 2>/dev/null || echo 0)
        local file_size_mb=$((file_size_bytes / 1024 / 1024))
        
        if [ "$file_size_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
            log_info "Rotating error log file (size: ${file_size_mb}MB)"
            
            # Rotate existing error log files
            for ((i=KEEP_LOG_FILES-1; i>=1; i--)); do
                local old_log="${ERROR_LOG_FILE}.$i"
                local new_log="${ERROR_LOG_FILE}.$((i+1))"
                [ -f "$old_log" ] && mv "$old_log" "$new_log"
            done
            
            # Move current error log to .1
            mv "$ERROR_LOG_FILE" "${ERROR_LOG_FILE}.1"
            touch "$ERROR_LOG_FILE"
            
            log_info "Error log rotation completed"
        fi
    fi
}

# Generic logging function
write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local target_file
    
    if [ "$ENABLE_LOGGING" -ne 1 ]; then
        return 0
    fi
    
    # Determine target file based on level and configuration
    if [ "$SEPARATE_ERROR_LOG" -eq 1 ] && [[ "$level" =~ ^(ERROR|WARN|INFO|DEBUG)$ ]]; then
        target_file="$ERROR_LOG_FILE"
    else
        target_file="$LOG_FILE"
    fi
    
    # Write to appropriate file
    if [ "$PRETTY_LOGS" -eq 1 ]; then
        # Pretty format with emojis
        local level_emoji
        case "$level" in
            "WEATHER") level_emoji="🌤️" ;;
            "ERROR") level_emoji="❌" ;;
            "WARN") level_emoji="⚠️" ;;
            "INFO") level_emoji="ℹ️" ;;
            "DEBUG") level_emoji="🔍" ;;
            *) level_emoji="📝" ;;
        esac
        
        echo "[$timestamp] $level_emoji [$level] $message" >> "$target_file" 2>/dev/null
    else
        # Plain format
        echo "[$timestamp] [$level] $message" >> "$target_file" 2>/dev/null
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
                "WEATHER"|"ERROR"|"INFO"|"WARN") return 0 ;;
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

# Log weather data in beautiful format
log_weather_data() {
    local city="$1"
    local country="$2"
    local temperature="$3"
    local weather_desc="$4"
    local humidity="$5"
    local wind_speed="$6"
    local wind_direction="$7"
    local weather_code="$8"
    
    if [ "$ENABLE_LOGGING" -ne 1 ]; then
        return 0
    fi
    
    local location="$city"
    [ -n "$country" ] && location="$city, $country"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$PRETTY_LOGS" -eq 1 ]; then
        # Beautiful format with emojis
        local weather_emoji=$(get_weather_emoji "$weather_code")
        local season_emoji=$(get_season_emoji)
        local time_emoji=$(get_time_emoji)
        
        # Wind direction arrow
        local wind_arrow
        if [ "$wind_direction" != "N/A" ] && [ -n "$wind_direction" ]; then
            local dir_int=$(echo "$wind_direction" | cut -d'.' -f1)
            if [ "$dir_int" -ge 0 ] && [ "$dir_int" -le 360 ]; then
                if [ "$dir_int" -ge 337 ] || [ "$dir_int" -lt 23 ]; then wind_arrow="⬆️"; # N
                elif [ "$dir_int" -ge 23 ] && [ "$dir_int" -lt 68 ]; then wind_arrow="↗️"; # NE
                elif [ "$dir_int" -ge 68 ] && [ "$dir_int" -lt 113 ]; then wind_arrow="➡️"; # E
                elif [ "$dir_int" -ge 113 ] && [ "$dir_int" -lt 158 ]; then wind_arrow="↘️"; # SE
                elif [ "$dir_int" -ge 158 ] && [ "$dir_int" -lt 203 ]; then wind_arrow="⬇️"; # S
                elif [ "$dir_int" -ge 203 ] && [ "$dir_int" -lt 248 ]; then wind_arrow="↙️"; # SW
                elif [ "$dir_int" -ge 248 ] && [ "$dir_int" -lt 293 ]; then wind_arrow="⬅️"; # W
                elif [ "$dir_int" -ge 293 ] && [ "$dir_int" -lt 337 ]; then wind_arrow="↖️"; # NW
                else wind_arrow="🌀"; fi
            else
                wind_arrow="🌀"
            fi
        else
            wind_arrow="🌀"
        fi
        
        # Temperature emoji based on value
        local temp_emoji="🌡️"
        if [ "$temperature" != "N/A" ] && [ -n "$temperature" ]; then
            local temp_int=$(echo "$temperature" | cut -d'.' -f1 | tr -d '-')
            local temp_sign=$(echo "$temperature" | head -c 1)
            if [ "$temp_sign" = "-" ] || [ "$temp_int" -lt 0 ]; then
                temp_emoji="🥶"  # Freezing
            elif [ "$temp_int" -lt 10 ]; then
                temp_emoji="🥵"  # Cold
            elif [ "$temp_int" -lt 20 ]; then
                temp_emoji="😊"  # Mild
            elif [ "$temp_int" -lt 30 ]; then
                temp_emoji="😎"  # Warm
            else
                temp_emoji="🔥"  # Hot
            fi
        fi
        
        # Clean weather description (remove original emoji)
        local clean_desc=$(echo "$weather_desc" | sed 's/^[[:space:]]*[^[:alpha:]]*[[:space:]]*//')
        
        # Beautiful log entry
        cat << EOF >> "$LOG_FILE"

┌────────────────────────────────────────────────────────────────────────────┐
│ $time_emoji [$timestamp] $season_emoji Weather Report for $location
├────────────────────────────────────────────────────────────────────────────┤
│ $weather_emoji Condition: $clean_desc
│ $temp_emoji Temperature: ${temperature}°C
│ 💧 Humidity: ${humidity}%
│ $wind_arrow Wind: ${wind_speed} km/h from ${wind_direction}°
└────────────────────────────────────────────────────────────────────────────┘

EOF
    else
        # Plain format
        local clean_desc=$(echo "$weather_desc" | sed 's/^[[:space:]]*[^[:alpha:]]*[[:space:]]*//')
        write_log "WEATHER" "Location='$location' Temp='${temperature}°C' Condition='$clean_desc' Humidity='${humidity}%' Wind='${wind_speed}km/h@${wind_direction}°'"
    fi
}

# =============================================================================
# CRONJOB MANAGEMENT (keeping existing functions)
# =============================================================================

# (Previous cronjob functions remain the same...)

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
# WEATHER CODE MAPPING (for display)
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
# UTILITY FUNCTIONS (keeping existing ones)
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
# MAIN FUNCTIONS (keeping existing ones with updated logging)
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
    
    # Log the weather data (beautiful format)
    log_weather_data "$city" "$country" "$temperature" "$weather_desc" "$humidity" "$wind_speed" "$wind_direction" "$weather_code"
    
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
    echo "Pretty Logs: $([ "$PRETTY_LOGS" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "Separate Error Log: $([ "$SEPARATE_ERROR_LOG" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "Weather Log: $LOG_FILE"
    if [ "$SEPARATE_ERROR_LOG" -eq 1 ]; then
        echo "Error Log: $ERROR_LOG_FILE"
    fi
    echo ""
    show_github_status
    echo ""
    echo "Edit $CONFIG_FILE to change these settings"
}

# Show log file information
show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "📝 No weather log file found: $LOG_FILE"
        return 1
    fi
    
    local file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    local file_size_kb=$((file_size / 1024))
    local line_count=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    
    echo "📝 Weather Log Information:"
    echo "=================================================="
    echo "Weather log: $LOG_FILE"
    echo "Size: ${file_size_kb}KB (${file_size} bytes)"
    echo "Lines: $line_count"
    echo "Current log level: $LOG_LEVEL"
    echo "Pretty logs: $([ "$PRETTY_LOGS" -eq 1 ] && echo "ENABLED" || echo "DISABLED")"
    echo ""
    
    # Show recent log entries
    if [ "$line_count" -gt 0 ]; then
        echo "Recent entries (last 10 lines):"
        echo "--------------------------------------------------"
        tail -n 10 "$LOG_FILE"
    else
        echo "Weather log is empty"
    fi
    
    # Show error log info if separate error logging is enabled
    if [ "$SEPARATE_ERROR_LOG" -eq 1 ] && [ -f "$ERROR_LOG_FILE" ]; then
        echo ""
        echo "🚨 Error Log Information:"
        echo "=================================================="
        local error_file_size=$(stat -f%z "$ERROR_LOG_FILE" 2>/dev/null || stat -c%s "$ERROR_LOG_FILE" 2>/dev/null || echo 0)
        local error_file_size_kb=$((error_file_size / 1024))
        local error_line_count=$(wc -l < "$ERROR_LOG_FILE" 2>/dev/null || echo 0)
        
        echo "Error log: $ERROR_LOG_FILE"
        echo "Size: ${error_file_size_kb}KB (${error_file_size} bytes)"
        echo "Lines: $error_line_count"
        
        if [ "$error_line_count" -gt 0 ]; then
            echo ""
            echo "Recent error entries (last 5 lines):"
            echo "--------------------------------------------------"
            tail -n 5 "$ERROR_LOG_FILE"
        else
            echo "Error log is empty"
        fi
    fi
}

# =============================================================================
# CRONJOB MANAGEMENT (adding required functions)
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
    
    # Simple descriptions for common patterns
    case "$cron_time" in
        "0 8 * * *") echo "Daily at 8:00 AM" ;;
        "30 7 * * 1-5") echo "Weekdays at 7:30 AM" ;;
        "0 */6 * * *") echo "Every 6 hours" ;;
        "0 12 * * 0") echo "Sundays at noon" ;;
        *) echo "$cron_time" ;;
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
        --github|github)
            create_default_config
            load_config
            init_logging
            show_github_status
            return 0
            ;;
        --sync|sync)
            create_default_config
            load_config
            init_logging
            setup_github_repo
            download_existing_logs
            push_logs_to_github
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
            echo "  $0 --github                 # Show GitHub integration status"
            echo "  $0 --sync                   # Force sync with GitHub"
            echo "  $0 --install-cron           # Manually install cronjob"
            echo "  $0 --remove-cron            # Remove cronjob"
            echo "  $0 --help                   # Show this help"
            echo ""
            echo "Files:"
            echo "  Configuration: $CONFIG_FILE"
            echo "  Weather Log:   $LOG_FILE"
            echo "  Error Log:     $ERROR_LOG_FILE"
            echo "  GitHub repo:   $REPO_DIR"
            echo ""
            echo "Log files can be prettified with emojis and formatting."
            echo "Errors and debug info go to separate error log if enabled."
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
    
    # Setup GitHub repository if not running from cron
    if [ "$is_cron" -eq 0 ]; then
        setup_github_repo
    fi
    
    # Initialize logging (includes downloading existing logs from GitHub if enabled)
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
    
    # Push logs to GitHub if enabled
    push_logs_to_github
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Run main function with all arguments
main "$@"
