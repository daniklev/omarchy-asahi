#!/bin/bash
# Enhanced hardware capability detection for MacBook Pro M1
# Integrates with existing omarchy-asahi infrastructure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create hardware configuration directory
mkdir -p ~/.config/omarchy

# Initialize hardware configuration file
HARDWARE_CONF="$HOME/.config/omarchy/hardware.conf"
echo "# Omarchy Hardware Configuration - Generated $(date)" > "$HARDWARE_CONF"
echo "# MacBook Pro M1 Hardware Capability Detection" >> "$HARDWARE_CONF"
echo "" >> "$HARDWARE_CONF"

log_info "Detecting MacBook Pro M1 hardware capabilities..."

# Detect system information
detect_system_info() {
    log_info "Gathering system information..."
    
    # Detect if this is a MacBook Pro M1
    SYSTEM_PRODUCT=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Name" | cut -d: -f2 | xargs || echo "Unknown")
    SYSTEM_CHIP=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Chip" | cut -d: -f2 | xargs || echo "Unknown")
    
    # Alternative detection on Linux
    if [[ -z "$SYSTEM_PRODUCT" || "$SYSTEM_PRODUCT" == "Unknown" ]]; then
        SYSTEM_PRODUCT=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "Unknown")
    fi
    
    # Check if running on Apple Silicon
    IS_APPLE_SILICON=false
    if [[ "$SYSTEM_CHIP" == *"Apple"* ]] || [[ -f /proc/device-tree/compatible ]] && grep -q "apple" /proc/device-tree/compatible 2>/dev/null; then
        IS_APPLE_SILICON=true
        log_success "Apple Silicon system detected"
    fi
    
    echo "SYSTEM_PRODUCT=\"$SYSTEM_PRODUCT\"" >> "$HARDWARE_CONF"
    echo "SYSTEM_CHIP=\"$SYSTEM_CHIP\"" >> "$HARDWARE_CONF"
    echo "IS_APPLE_SILICON=$IS_APPLE_SILICON" >> "$HARDWARE_CONF"
    echo "" >> "$HARDWARE_CONF"
}

# Detect brightness control capabilities
detect_brightness_interfaces() {
    log_info "Detecting brightness control interfaces..."
    
    # Internal display backlight detection
    INTERNAL_BACKLIGHT=false
    BACKLIGHT_DEVICE=""
    
    if [[ -d /sys/class/backlight ]]; then
        for backlight in /sys/class/backlight/*; do
            if [[ -d "$backlight" ]]; then
                BACKLIGHT_DEVICE=$(basename "$backlight")
                INTERNAL_BACKLIGHT=true
                log_success "Internal backlight detected: $BACKLIGHT_DEVICE"
                break
            fi
        done
    fi
    
    # Check for brightnessctl command
    BRIGHTNESSCTL_AVAILABLE=false
    if command -v brightnessctl >/dev/null 2>&1; then
        BRIGHTNESSCTL_AVAILABLE=true
        log_success "brightnessctl command available"
    fi
    
    # External Apple display detection (using existing asdcontrol)
    EXTERNAL_APPLE_DISPLAY=false
    ASDCONTROL_AVAILABLE=false
    
    if command -v asdcontrol >/dev/null 2>&1; then
        ASDCONTROL_AVAILABLE=true
        # Test for external Apple displays
        if sudo asdcontrol --detect /dev/usb/hiddev* 2>/dev/null | grep -q "hiddev"; then
            EXTERNAL_APPLE_DISPLAY=true
            log_success "External Apple display detected"
        fi
    fi
    
    # Keyboard backlight detection
    KEYBOARD_BACKLIGHT=false
    KEYBOARD_BACKLIGHT_DEVICE=""
    
    if [[ -d /sys/class/leds ]]; then
        for led in /sys/class/leds/*kbd*; do
            if [[ -d "$led" ]]; then
                KEYBOARD_BACKLIGHT_DEVICE=$(basename "$led")
                KEYBOARD_BACKLIGHT=true
                log_success "Keyboard backlight detected: $KEYBOARD_BACKLIGHT_DEVICE"
                break
            fi
        done
    fi
    
    # Alternative keyboard backlight detection methods
    if [[ "$KEYBOARD_BACKLIGHT" == "false" ]]; then
        # Check for Apple-specific keyboard backlight
        for led in /sys/class/leds/*smc*; do
            if [[ -d "$led" ]] && [[ "$led" == *"kbd"* ]]; then
                KEYBOARD_BACKLIGHT_DEVICE=$(basename "$led")
                KEYBOARD_BACKLIGHT=true
                log_success "Apple keyboard backlight detected: $KEYBOARD_BACKLIGHT_DEVICE"
                break
            fi
        done
    fi
    
    if [[ "$KEYBOARD_BACKLIGHT" == "false" ]]; then
        log_warning "Keyboard backlight not detected - may not be supported on this hardware"
    fi
    
    # Write brightness configuration
    echo "# Brightness Control Configuration" >> "$HARDWARE_CONF"
    echo "INTERNAL_BACKLIGHT=$INTERNAL_BACKLIGHT" >> "$HARDWARE_CONF"
    echo "BACKLIGHT_DEVICE=\"$BACKLIGHT_DEVICE\"" >> "$HARDWARE_CONF"
    echo "BRIGHTNESSCTL_AVAILABLE=$BRIGHTNESSCTL_AVAILABLE" >> "$HARDWARE_CONF"
    echo "EXTERNAL_APPLE_DISPLAY=$EXTERNAL_APPLE_DISPLAY" >> "$HARDWARE_CONF"
    echo "ASDCONTROL_AVAILABLE=$ASDCONTROL_AVAILABLE" >> "$HARDWARE_CONF"
    echo "KEYBOARD_BACKLIGHT=$KEYBOARD_BACKLIGHT" >> "$HARDWARE_CONF"
    echo "KEYBOARD_BACKLIGHT_DEVICE=\"$KEYBOARD_BACKLIGHT_DEVICE\"" >> "$HARDWARE_CONF"
    echo "" >> "$HARDWARE_CONF"
}

# Detect audio interfaces
detect_audio_interfaces() {
    log_info "Detecting audio interfaces..."
    
    # Audio system detection
    AUDIO_SYSTEM="none"
    PIPEWIRE_AVAILABLE=false
    PULSEAUDIO_AVAILABLE=false
    PAMIXER_AVAILABLE=false
    
    # Check for PipeWire
    if pgrep -x pipewire >/dev/null 2>&1; then
        AUDIO_SYSTEM="pipewire"
        PIPEWIRE_AVAILABLE=true
        log_success "PipeWire audio system detected"
    elif pgrep -x pulseaudio >/dev/null 2>&1; then
        AUDIO_SYSTEM="pulseaudio"
        PULSEAUDIO_AVAILABLE=true
        log_success "PulseAudio system detected"
    fi
    
    # Check for pamixer
    if command -v pamixer >/dev/null 2>&1; then
        PAMIXER_AVAILABLE=true
        log_success "pamixer command available"
    fi
    
    # Detect audio cards
    AUDIO_CARDS=()
    if [[ -d /proc/asound ]]; then
        while IFS= read -r -d '' card; do
            card_name=$(basename "$card")
            if [[ "$card_name" =~ ^card[0-9]+$ ]]; then
                card_info=$(cat "/proc/asound/$card_name/id" 2>/dev/null || echo "Unknown")
                AUDIO_CARDS+=("$card_name:$card_info")
                log_info "Audio card detected: $card_name ($card_info)"
            fi
        done < <(find /proc/asound -name "card*" -type d -print0 2>/dev/null)
    fi
    
    # Write audio configuration
    echo "# Audio Interface Configuration" >> "$HARDWARE_CONF"
    echo "AUDIO_SYSTEM=\"$AUDIO_SYSTEM\"" >> "$HARDWARE_CONF"
    echo "PIPEWIRE_AVAILABLE=$PIPEWIRE_AVAILABLE" >> "$HARDWARE_CONF"
    echo "PULSEAUDIO_AVAILABLE=$PULSEAUDIO_AVAILABLE" >> "$HARDWARE_CONF"
    echo "PAMIXER_AVAILABLE=$PAMIXER_AVAILABLE" >> "$HARDWARE_CONF"
    echo "AUDIO_CARDS=(${AUDIO_CARDS[*]})" >> "$HARDWARE_CONF"
    echo "" >> "$HARDWARE_CONF"
}

# Detect SwayOSD and Hyprland integration
detect_desktop_integration() {
    log_info "Detecting desktop integration capabilities..."
    
    # SwayOSD detection
    SWAYOSD_AVAILABLE=false
    SWAYOSD_RUNNING=false
    
    if command -v swayosd-client >/dev/null 2>&1; then
        SWAYOSD_AVAILABLE=true
        log_success "SwayOSD client available"
        
        # Check if SwayOSD server is running
        if pgrep -x swayosd-server >/dev/null 2>&1; then
            SWAYOSD_RUNNING=true
            log_success "SwayOSD server is running"
        else
            log_warning "SwayOSD server not running"
        fi
    fi
    
    # Hyprland detection
    HYPRLAND_AVAILABLE=false
    HYPRLAND_RUNNING=false
    
    if command -v hyprctl >/dev/null 2>&1; then
        HYPRLAND_AVAILABLE=true
        log_success "Hyprland available"
        
        # Check if Hyprland is running
        if pgrep -x Hyprland >/dev/null 2>&1; then
            HYPRLAND_RUNNING=true
            log_success "Hyprland is running"
        fi
    fi
    
    # Check for existing hardware control scripts
    OMARCHY_BRIGHTNESS_SCRIPT=false
    if [[ -f ~/.local/share/omarchy/bin/omarchy-cmd-apple-display-brightness ]]; then
        OMARCHY_BRIGHTNESS_SCRIPT=true
        log_success "Existing omarchy brightness script found"
    fi
    
    # Write desktop integration configuration
    echo "# Desktop Integration Configuration" >> "$HARDWARE_CONF"
    echo "SWAYOSD_AVAILABLE=$SWAYOSD_AVAILABLE" >> "$HARDWARE_CONF"
    echo "SWAYOSD_RUNNING=$SWAYOSD_RUNNING" >> "$HARDWARE_CONF"
    echo "HYPRLAND_AVAILABLE=$HYPRLAND_AVAILABLE" >> "$HARDWARE_CONF"
    echo "HYPRLAND_RUNNING=$HYPRLAND_RUNNING" >> "$HARDWARE_CONF"
    echo "OMARCHY_BRIGHTNESS_SCRIPT=$OMARCHY_BRIGHTNESS_SCRIPT" >> "$HARDWARE_CONF"
    echo "" >> "$HARDWARE_CONF"
}

# Generate hardware capability summary
generate_summary() {
    log_info "Generating hardware capability summary..."
    
    echo "# Hardware Capability Summary" >> "$HARDWARE_CONF"
    echo "# Generated on $(date)" >> "$HARDWARE_CONF"
    echo "" >> "$HARDWARE_CONF"
    
    # Brightness control summary
    local brightness_methods=0
    [[ "$INTERNAL_BACKLIGHT" == "true" ]] && ((brightness_methods++))
    [[ "$EXTERNAL_APPLE_DISPLAY" == "true" ]] && ((brightness_methods++))
    
    echo "BRIGHTNESS_CONTROL_METHODS=$brightness_methods" >> "$HARDWARE_CONF"
    
    # Audio control summary
    local audio_ready=false
    [[ "$AUDIO_SYSTEM" != "none" ]] && [[ "$PAMIXER_AVAILABLE" == "true" ]] && audio_ready=true
    echo "AUDIO_CONTROL_READY=$audio_ready" >> "$HARDWARE_CONF"
    
    # Overall system readiness
    local system_ready=false
    [[ $brightness_methods -gt 0 ]] && [[ "$audio_ready" == "true" ]] && [[ "$SWAYOSD_AVAILABLE" == "true" ]] && system_ready=true
    echo "SYSTEM_READY=$system_ready" >> "$HARDWARE_CONF"
    
    echo "" >> "$HARDWARE_CONF"
    echo "# Detection completed on $(date)" >> "$HARDWARE_CONF"
    
    # Display summary
    echo ""
    log_info "=== Hardware Detection Summary ==="
    log_info "System: $SYSTEM_PRODUCT"
    log_info "Brightness methods available: $brightness_methods"
    log_info "Audio system: $AUDIO_SYSTEM"
    log_info "SwayOSD available: $SWAYOSD_AVAILABLE"
    log_info "System ready: $system_ready"
    
    if [[ "$system_ready" == "true" ]]; then
        log_success "Hardware detection complete - system is ready for enhanced controls"
    else
        log_warning "Hardware detection complete - some features may be limited"
    fi
}

# Main execution
main() {
    log_info "Starting enhanced hardware detection for omarchy-asahi..."
    
    detect_system_info
    detect_brightness_interfaces
    detect_audio_interfaces
    detect_desktop_integration
    generate_summary
    
    log_success "Hardware configuration saved to: $HARDWARE_CONF"
    log_info "Configuration can be sourced with: source $HARDWARE_CONF"
}

# Run main function
main "$@"