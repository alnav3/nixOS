#!/usr/bin/env bash

set -e

# Configuration
ICS_URL="http://sonarr.home/feed/v3/calendar/Sonarr.ics?apikey=8049043aab444bcdab497fd2d5c35ba7"
CALDAV_URL="http://10.71.71.10:5232/testuser/"
USERNAME="testuser"
PASSWORD="testpass"

# Temporary files
TMP_DIR=$(mktemp -d)
ICS_FILE="${TMP_DIR}/sonarr.ics"
EVENT_FILE="${TMP_DIR}/event.ics"

# Cleanup on exit
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Downloading ICS file from Sonarr..."
curl -s "${ICS_URL}" -o "${ICS_FILE}"

if [ ! -s "${ICS_FILE}" ]; then
    echo "Error: Failed to download ICS file or file is empty"
    exit 1
fi

echo "Finding CalDAV calendar..."

# Discover calendar home set
PROPFIND_BODY='<?xml version="1.0" encoding="utf-8" ?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <c:calendar-home-set />
  </d:prop>
</d:propfind>'

CALENDAR_HOME=$(curl -s -u "${USERNAME}:${PASSWORD}" \
    -X PROPFIND \
    -H "Depth: 0" \
    -H "Content-Type: application/xml" \
    -d "${PROPFIND_BODY}" \
    "${CALDAV_URL}" | grep -oP '(?<=<d:href>)[^<]+(?=</d:href>)' | head -1)

if [ -z "${CALENDAR_HOME}" ]; then
    CALENDAR_HOME="/testuser/"
fi

echo "Calendar home: http://10.71.71.10:5232${CALENDAR_HOME}"

# List calendars
PROPFIND_CALENDARS='<?xml version="1.0" encoding="utf-8" ?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:resourcetype />
    <d:displayname />
  </d:prop>
</d:propfind>'

# For simplicity, directly discover calendars in the user path
# Most CalDAV servers have calendars as subdirectories
CALENDAR_PATH=$(curl -s -u "${USERNAME}:${PASSWORD}" \
    -X PROPFIND \
    -H "Depth: 1" \
    -H "Content-Type: application/xml" \
    -d "${PROPFIND_CALENDARS}" \
    "http://10.71.71.10:5232${CALENDAR_HOME}" | \
    sed 's/></>\n</g' | grep '<href>' | grep -v "testuser/<" | \
    tail -1 | sed 's/<href>//; s/<\/href>//')

if [ -z "${CALENDAR_PATH}" ]; then
    echo "Error: No calendars found"
    exit 1
fi

FULL_CALENDAR_URL="http://10.71.71.10:5232${CALENDAR_PATH}"
echo "Using calendar: ${FULL_CALENDAR_URL}"

# Extract and upload events
echo ""
echo "Adding events..."

# Counter file to track events across subshell
COUNTER_FILE="${TMP_DIR}/counter"
echo "0" > "${COUNTER_FILE}"

# Use awk to split the ICS file into individual events
awk '
BEGIN { in_event=0; event="" }
/BEGIN:VEVENT/ { in_event=1; event="BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Sonarr Sync//EN\n" $0 "\n"; next }
in_event==1 { event=event $0 "\n" }
/END:VEVENT/ { 
    if (in_event==1) {
        event=event "END:VCALENDAR\n"
        print event
        event=""
        in_event=0
    }
}
' "${ICS_FILE}" | while IFS= read -r line; do
    if [ "$line" = "BEGIN:VCALENDAR" ]; then
        EVENT_DATA="$line"
        continue
    fi
    
    if [ -n "$EVENT_DATA" ]; then
        EVENT_DATA="${EVENT_DATA}"$'\n'"${line}"
    fi
    
    if [ "$line" = "END:VCALENDAR" ]; then
        # Extract EVENT_UID and SUMMARY from event
        EVENT_UID=$(echo "$EVENT_DATA" | grep "^UID:" | cut -d: -f2- | tr -d '\r')
        SUMMARY=$(echo "$EVENT_DATA" | grep "^SUMMARY:" | cut -d: -f2- | tr -d '\r')
        
        if [ -z "$EVENT_UID" ]; then
            echo "Event has no UID, skipping"
            EVENT_DATA=""
            continue
        fi
        
        # Save event to file
        echo "$EVENT_DATA" > "${EVENT_FILE}"
        
        # Upload event to CalDAV server
        HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
            -u "${USERNAME}:${PASSWORD}" \
            -X PUT \
            -H "Content-Type: text/calendar; charset=utf-8" \
            --data-binary "@${EVENT_FILE}" \
            "${FULL_CALENDAR_URL}${EVENT_UID}.ics")
        
        if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
            # Increment counter in file
            CURRENT=$(cat "${COUNTER_FILE}")
            echo "$((CURRENT + 1))" > "${COUNTER_FILE}"
            
            if [ -n "$SUMMARY" ]; then
                echo "Added event: ${SUMMARY}"
            else
                echo "Added event: No title"
            fi
        else
            echo "Failed to add event (HTTP ${HTTP_CODE}): ${SUMMARY}"
        fi
        
        EVENT_DATA=""
    fi
done

EVENT_COUNT=$(cat "${COUNTER_FILE}")
echo ""
echo "✅ Successfully added ${EVENT_COUNT} events from Sonarr!"
