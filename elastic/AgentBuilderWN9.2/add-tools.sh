#!/bin/bash

# Agent Builder - Tool Management Script
# Creates ES|QL tools for Elastic Agent Builder
#
# Environment Detection:
# - Sandbox: Uses http://localhost:9200 and /tmp/api_key.txt
# - Local: Uses .env file with ES_ENDPOINT and ES_API_KEY
#
# Usage:
#   ./add-tools.sh <tools-file.json>
#   ./add-tools.sh tools.json

set -e

# Detect environment and load credentials
if [ -f /tmp/api_key.txt ]; then
    # Sandbox environment
    echo "Detected sandbox environment"
    API_KEY=$(cat /tmp/api_key.txt | tr -d '\n\r')
    KIBANA_URL="http://localhost:8080"
    CSP_HEADER="script-src 'self' https://kibana.estccdn.com; worker-src blob: 'self'; style-src 'unsafe-inline' 'self' https://kibana.estccdn.com; style-src-elem 'unsafe-inline' 'self' https://kibana.estccdn.com"
else
    # Local environment - load from .env
    echo "Detected local environment"
    if [ -f ../../.env ]; then
        export $(cat ../../.env | grep -v '^#' | xargs)
    elif [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    else
        echo "Error: .env file not found and not in sandbox environment"
        exit 1
    fi

    # Convert Elasticsearch endpoint to Kibana endpoint (.es. -> .kb.)
    KIBANA_URL="${ES_ENDPOINT/.es./.kb.}"
    API_KEY="${ES_API_KEY}"
    CSP_HEADER=""
fi

# Check if tools file provided
if [ -z "$1" ]; then
    echo ""
    echo "Usage: $0 <tools-file.json>"
    echo ""
    echo "Example tools file format:"
    echo '{'
    echo '  "tools": ['
    echo '    {'
    echo '      "id": "customer.campaign_roi_analysis",'
    echo '      "type": "esql",'
    echo '      "description": "Analyzes campaign ROI and performance metrics...",'
    echo '      "tags": ["campaign", "roi", "revenue"],'
    echo '      "configuration": {'
    echo '        "query": "FROM campaign-performance | LOOKUP JOIN..."'
    echo '      }'
    echo '    }'
    echo '  ]'
    echo '}'
    exit 1
fi

TOOLS_FILE="$1"

if [ ! -f "$TOOLS_FILE" ]; then
    echo "Error: Tools file '$TOOLS_FILE' not found"
    exit 1
fi

echo "=== Agent Builder - Tool Creation Script ==="
echo "Kibana URL: $KIBANA_URL"
echo "Tools file: $TOOLS_FILE"
echo ""

# Function to create a single tool
create_tool() {
    local tool_json=$1

    # Extract tool details for display
    local tool_id=$(echo "$tool_json" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    local tool_desc=$(echo "$tool_json" | grep -o '"description"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1)

    echo "Creating tool: $tool_id"
    if [ -n "$tool_desc" ]; then
        echo "Description: ${tool_desc:0:80}..."
    fi

    # Build the API request
    if [ -n "$CSP_HEADER" ]; then
        # Sandbox: Include CSP header
        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Authorization: ApiKey $API_KEY" \
            -H "kbn-xsrf: true" \
            -H "Content-Type: application/json" \
            -H "Content-Security-Policy: $CSP_HEADER" \
            "$KIBANA_URL/api/agent_builder/tools" \
            -d "$tool_json")
    else
        # Local: No CSP header needed
        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Authorization: ApiKey $API_KEY" \
            -H "kbn-xsrf: true" \
            -H "Content-Type: application/json" \
            "$KIBANA_URL/api/agent_builder/tools" \
            -d "$tool_json")
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo "✓ Tool created successfully"
    else
        echo "✗ Failed to create tool (HTTP $http_code)"
        echo "Response: $body"
    fi
    echo ""
}

# Process tools from JSON file
echo "Reading tools from $TOOLS_FILE..."
echo ""

# Use jq if available, otherwise parse manually
if command -v jq &> /dev/null; then
    # Use jq for clean JSON parsing
    tool_count=$(cat "$TOOLS_FILE" | jq '.tools | length')
    echo "Found $tool_count tool(s) to create"
    echo ""

    for i in $(seq 0 $((tool_count - 1))); do
        echo "=== Tool $((i + 1)) of $tool_count ==="
        tool_json=$(cat "$TOOLS_FILE" | jq -c ".tools[$i]")
        create_tool "$tool_json"
    done
else
    # Manual parsing without jq
    echo "Note: jq not found, using basic parsing"
    echo ""

    # Extract each tool object manually
    # This is a simplified parser - assumes proper JSON formatting
    awk '
    BEGIN { in_tools=0; in_tool=0; brace_count=0; tool_num=0; }
    /"tools"[[:space:]]*:/ { in_tools=1; next; }
    in_tools && /{/ && !in_tool {
        in_tool=1;
        brace_count=1;
        tool_num++;
        print "TOOL_START_" tool_num;
        print $0;
        next;
    }
    in_tool {
        print $0;
        brace_count += gsub(/{/, "{");
        brace_count -= gsub(/}/, "}");
        if (brace_count == 0) {
            print "TOOL_END_" tool_num;
            in_tool=0;
        }
    }
    ' "$TOOLS_FILE" | {
        tool_num=0
        tool_json=""
        while IFS= read -r line; do
            if [[ "$line" =~ TOOL_START_([0-9]+) ]]; then
                tool_num=${BASH_REMATCH[1]}
                tool_json=""
            elif [[ "$line" =~ TOOL_END_([0-9]+) ]]; then
                echo "=== Tool $tool_num ==="
                create_tool "$tool_json"
            else
                if [ -n "$tool_json" ]; then
                    tool_json="$tool_json
$line"
                else
                    tool_json="$line"
                fi
            fi
        done
    }
fi

echo "=== Tool Creation Complete ==="
