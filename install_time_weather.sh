#!/bin/bash

# =============================================================================
# install_time_weather.sh
# AllStar ASL3 Time and Weather Announcement Installer
# Author: KJ5MLL / Brian
# GitHub: https://github.com/g4master/AllStar-Time-Weather-Watch-Warning-Alerts-NWS/tree/g4master-patch-1
# Version: 2.0
#
# Requirements:
# - AllStarLink ASL3
# - Free WeatherAPI.com account and API key (https://www.weatherapi.com)
# - curl, python3
# =============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LOGFILE="/var/log/time_weather.log"
SBIN="/usr/local/sbin"
CUSTOM="/usr/local/share/asterisk/sounds/custom"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOGFILE"; }

echo ""
echo "=============================================="
echo "  AllStar ASL3 Time and Weather Installer"
echo "  by KJ5MLL"
echo "  https://github.com/briankj5mll/AllStar-Time-Weather"
echo "  Version 2.0 - Now with NWS Watch/Warning Alerts"
echo "=============================================="
echo ""
echo "You will need a FREE WeatherAPI.com account."
echo "Sign up at: https://www.weatherapi.com"
echo ""
echo "You will also need your latitude and longitude."
echo "Find yours at: https://www.latlong.net"
echo ""

# Collect info
read -p "Enter your AllStar node number: " NODE
if [ -z "$NODE" ]; then echo "Node number is required. Exiting."; exit 1; fi

read -p "Enter your WeatherAPI.com API key: " APIKEY
if [ -z "$APIKEY" ]; then echo "API key is required. Exiting."; exit 1; fi

read -p "Enter your ZIP code: " ZIP
if [ -z "$ZIP" ]; then echo "ZIP code is required. Exiting."; exit 1; fi

read -p "Enter your latitude (e.g. 34.2740): " LAT
if [ -z "$LAT" ]; then echo "Latitude is required. Exiting."; exit 1; fi

read -p "Enter your longitude (e.g. -88.4092): " LON
if [ -z "$LON" ]; then echo "Longitude is required. Exiting."; exit 1; fi

echo ""
log "Installing for node=$NODE ZIP=$ZIP LAT=$LAT LON=$LON"

# Check required tools
for cmd in curl python3; do
    if ! command -v $cmd &>/dev/null; then
        log "ERROR: $cmd is not installed. Please install it first."
        exit 1
    fi
done

# Check sound files exist
if [ ! -d "$CUSTOM/digits" ]; then
    log "ERROR: AllStar sound files not found at $CUSTOM"
    log "Please make sure AllStar ASL3 is installed correctly."
    exit 1
fi

# Write get_weather.sh
log "Writing /usr/local/sbin/get_weather.sh..."
cat > "$SBIN/get_weather.sh" << WEATHEREOF
#!/bin/bash
# get_weather.sh - Fetch current weather from WeatherAPI.com
# Part of AllStar-Time-Weather by KJ5MLL
# https://github.com/briankj5mll/AllStar-Time-Weather

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

APIKEY="$APIKEY"
ZIP="$ZIP"
LOGFILE="/var/log/time_weather.log"

log() { echo "\$(date '+%Y-%m-%d %H:%M:%S') \$1" >> "\$LOGFILE"; }

RESPONSE=\$(curl -sf --max-time 10 "https://api.weatherapi.com/v1/current.json?key=\${APIKEY}&q=\${ZIP}&aqi=no")

if [ -z "\$RESPONSE" ]; then
    log "ERROR: No response from WeatherAPI.com"
    exit 1
fi

TEMP=\$(echo "\$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(int(d['current']['temp_f']))")
CONDITION=\$(echo "\$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['current']['condition']['text'].lower())")

log "Weather: temp=\$TEMP condition=\$CONDITION"
echo "\$TEMP|\$CONDITION"
WEATHEREOF

chmod +x "$SBIN/get_weather.sh"
log "get_weather.sh written."

# Write saytime_wx.sh
log "Writing /usr/local/sbin/saytime_wx.sh..."
cat > "$SBIN/saytime_wx.sh" << SAYTIMEEOF
#!/bin/bash
# saytime_wx.sh - Time, Weather, and NWS Alert Announcement for AllStar ASL3
# Part of AllStar-Time-Weather by KJ5MLL
# https://github.com/briankj5mll/AllStar-Time-Weather

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

NODE="$NODE"
LAT="$LAT"
LON="$LON"
CUSTOM="/usr/local/share/asterisk/sounds/custom"
TMPFILE="/tmp/saytime_wx_\${NODE}.gsm"
LOGFILE="/var/log/time_weather.log"

log() { echo "\$(date '+%Y-%m-%d %H:%M:%S') \$1" >> "\$LOGFILE"; }
log "--- Starting announcement ---"

HOUR=\$(date +%-I)
HOUR24=\$(date +%-H)
MIN=\$(date +%-M)
AMPM=\$(date +%p)

# Greeting based on time of day
if [ "\$HOUR24" -lt 12 ]; then
    FILES="\$CUSTOM/good-morning.gsm"
elif [ "\$HOUR24" -lt 17 ]; then
    FILES="\$CUSTOM/good-afternoon.gsm"
else
    FILES="\$CUSTOM/good-evening.gsm"
fi

# The time is...
FILES="\$FILES \$CUSTOM/the-time-is.gsm \$CUSTOM/digits/\$HOUR.gsm"

# Minutes
if [ "\$MIN" -eq 0 ]; then
    FILES="\$FILES \$CUSTOM/digits/oclock.gsm"
elif [ "\$MIN" -lt 10 ]; then
    FILES="\$FILES \$CUSTOM/digits/oh.gsm \$CUSTOM/digits/\$MIN.gsm"
elif [ "\$MIN" -lt 20 ]; then
    FILES="\$FILES \$CUSTOM/digits/\$MIN.gsm"
else
    MIN10=\$(( (MIN/10)*10 ))
    MIN1=\$(( MIN%10 ))
    FILES="\$FILES \$CUSTOM/digits/\$MIN10.gsm"
    if [ "\$MIN1" -gt 0 ]; then FILES="\$FILES \$CUSTOM/digits/\$MIN1.gsm"; fi
fi

# AM or PM
if [ "\$AMPM" = "AM" ] || [ "\$AMPM" = "am" ]; then
    FILES="\$FILES \$CUSTOM/digits/a-m.gsm"
else
    FILES="\$FILES \$CUSTOM/digits/p-m.gsm"
fi

# Short pause before weather
FILES="\$FILES \$CUSTOM/silence/1.gsm"

# Get weather
WX=\$(/usr/local/sbin/get_weather.sh 2>/dev/null)
log "Weather output: \$WX"

TEMP=\$(echo "\$WX" | cut -d'|' -f1)
CONDITION=\$(echo "\$WX" | cut -d'|' -f2)

# Temperature
if [ -n "\$TEMP" ] && [ "\$TEMP" -gt 0 ] 2>/dev/null; then
    FILES="\$FILES \$CUSTOM/temperature.gsm"
    if [ "\$TEMP" -lt 20 ]; then
        FILES="\$FILES \$CUSTOM/digits/\$TEMP.gsm"
    else
        TEMP10=\$(( (TEMP/10)*10 ))
        TEMP1=\$(( TEMP%10 ))
        FILES="\$FILES \$CUSTOM/digits/\$TEMP10.gsm"
        if [ "\$TEMP1" -gt 0 ]; then FILES="\$FILES \$CUSTOM/digits/\$TEMP1.gsm"; fi
    fi
    FILES="\$FILES \$CUSTOM/degrees.gsm \$CUSTOM/fahrenheit.gsm"
fi

# Weather condition words - match against available sound files
for WORD in \$CONDITION; do
    WORD=\$(echo "\$WORD" | tr -d '.,;:')
    if [ -f "\$CUSTOM/\${WORD}.gsm" ]; then
        FILES="\$FILES \$CUSTOM/\${WORD}.gsm"
        log "Matched condition word: \$WORD"
    fi
done

# Build audio file
log "Building audio..."
cat \$FILES > "\$TMPFILE" 2>/dev/null

if [ ! -s "\$TMPFILE" ]; then
    log "ERROR: Failed to build audio file"
    exit 1
fi

# Play on node
/usr/sbin/asterisk -rx "rpt localplay \$NODE /tmp/saytime_wx_\${NODE}" >> "\$LOGFILE" 2>&1
log "Announcement played on node \$NODE"
sleep 8
rm -f "\$TMPFILE"
log "Done"

# ---- NWS ALERT CHECK ----
ALERT_TMP="/tmp/nws_alert_\${NODE}.gsm"

ALERTS=\$(curl -sf --max-time 10 "https://api.weather.gov/alerts/active?point=\${LAT},\${LON}" \
    -H "User-Agent: KJ5MLL-weather/1.0" \
    -H "Accept: application/geo+json")

ALERT_EVENT=\$(echo "\$ALERTS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
skip = ['advisory','statement','outlook','special weather','dense fog','frost','freeze','wind chill','heat index','air quality']
for f in data.get('features', []):
    p = f['properties']
    event = p.get('event','').lower()
    if any(s in event for s in skip):
        continue
    print(p.get('event',''))
    break
" 2>/dev/null)

if [ -n "\$ALERT_EVENT" ]; then
    log "NWS Alert: \$ALERT_EVENT"
    ALERT_FILES="\$CUSTOM/national-weather-service.gsm \$CUSTOM/alert.gsm"
    EVENT_LOWER=\$(echo "\$ALERT_EVENT" | tr '[:upper:]' '[:lower:]')
    if echo "\$EVENT_LOWER" | grep -q "tornado"; then
        ALERT_FILES="\$ALERT_FILES \$CUSTOM/tornado.gsm"
    fi
    if echo "\$EVENT_LOWER" | grep -q "thunderstorm"; then
        ALERT_FILES="\$ALERT_FILES \$CUSTOM/thunderstorm.gsm"
    fi
    if echo "\$EVENT_LOWER" | grep -q "severe"; then
        ALERT_FILES="\$ALERT_FILES \$CUSTOM/severe.gsm"
    fi
    if echo "\$EVENT_LOWER" | grep -q "warning"; then
        ALERT_FILES="\$ALERT_FILES \$CUSTOM/warning.gsm"
    fi
    if echo "\$EVENT_LOWER" | grep -q "watch"; then
        ALERT_FILES="\$ALERT_FILES \$CUSTOM/watch.gsm"
    fi
    if [ -f "\$CUSTOM/mississippi.gsm" ]; then
        ALERT_FILES="\$ALERT_FILES \$CUSTOM/mississippi.gsm"
    fi
    cat \$ALERT_FILES > "\$ALERT_TMP" 2>/dev/null
    if [ -s "\$ALERT_TMP" ]; then
        sleep 2
        /usr/sbin/asterisk -rx "rpt localplay \$NODE /tmp/nws_alert_\${NODE}" >> "\$LOGFILE" 2>&1
        sleep 8
    fi
    rm -f "\$ALERT_TMP"
else
    log "NWS: No active alerts"
fi
SAYTIMEEOF

chmod +x "$SBIN/saytime_wx.sh"
log "saytime_wx.sh written."

# Set up cron job
log "Setting up cron job (top of every hour)..."
( sudo crontab -l 2>/dev/null | grep -v saytime_wx; echo "00 00-23 * * * /usr/local/sbin/saytime_wx.sh >/dev/null 2>&1" ) | sudo crontab -
log "Cron job set."

# Test weather fetch
log "Testing WeatherAPI connection..."
WX_TEST=$("$SBIN/get_weather.sh" 2>/dev/null)
if [ -z "$WX_TEST" ]; then
    echo ""
    echo "WARNING: Weather test failed. Check your API key and ZIP code."
    echo "You can test manually with: sudo /usr/local/sbin/get_weather.sh"
else
    log "Weather test OK: $WX_TEST"
fi

echo ""
echo "=============================================="
echo "  Installation Complete!"
echo ""
echo "  Node:     $NODE"
echo "  ZIP:      $ZIP"
echo "  Location: $LAT, $LON"
echo "  Schedule: Top of every hour"
echo ""
echo "  Test now:   sudo /usr/local/sbin/saytime_wx.sh"
echo "  View log:   tail -f /var/log/time_weather.log"
echo "  View cron:  sudo crontab -l"
echo "=============================================="
