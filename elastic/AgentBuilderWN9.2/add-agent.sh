#!/bin/bash

# Agent Builder - Agent Management Script
# Creates AI agents for Elastic Agent Builder
#
# Environment Detection:
# - Sandbox: Uses http://localhost:8080 and /tmp/api_key.txt
# - Local: Uses .env file with ES_ENDPOINT and ES_API_KEY
#
# Usage:
#   ./add-agent.sh <agent-file.json>
#   ./add-agent.sh agent-brand-analytics.json

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
        set -a
        . ../../.env
        set +a
    elif [ -f .env ]; then
        set -a
        . .env
        set +a
    else
        echo "Error: .env file not found and not in sandbox environment"
        exit 1
    fi

    # Convert Elasticsearch endpoint to Kibana endpoint (.es. -> .kb.)
    KIBANA_URL="${ES_ENDPOINT/.es./.kb.}"
    API_KEY="${ES_API_KEY}"
    CSP_HEADER=""
fi

# Check if agent file provided
if [ -z "$1" ]; then
    echo ""
    echo "Usage: $0 <agent-file.json>"
    echo ""
    echo "Example agent file format:"
    echo '{'
    echo '  "agents": ['
    echo '    {'
    echo '      "id": "customer-my-agent",'
    echo '      "name": "My Agent Name",'
    echo '      "description": "Agent description...",'
    echo '      "labels": ["label1", "label2"],'
    echo '      "configuration": {'
    echo '        "instructions": "Custom instructions...",'
    echo '        "tools": [{'
    echo '          "tool_ids": ["customer.tool1", "customer.tool2"]'
    echo '        }]'
    echo '      }'
    echo '    }'
    echo '  ]'
    echo '}'
    exit 1
fi

AGENT_FILE="$1"

if [ ! -f "$AGENT_FILE" ]; then
    echo "Error: Agent file '$AGENT_FILE' not found"
    exit 1
fi

echo "=== Agent Builder - Agent Creation Script ==="
echo "Kibana URL: $KIBANA_URL"
echo "Agent file: $AGENT_FILE"
echo ""

# Function to create a single agent
create_agent() {
    local agent_json=$1

    # Extract agent details for display
    local agent_id=$(echo "$agent_json" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1)
    local agent_name=$(echo "$agent_json" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | head -1)

    echo "Creating agent: $agent_id"
    if [ -n "$agent_name" ]; then
        echo "Name: $agent_name"
    fi

    # Build the API request
    if [ -n "$CSP_HEADER" ]; then
        # Sandbox: Include CSP header
        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Authorization: ApiKey $API_KEY" \
            -H "kbn-xsrf: true" \
            -H "Content-Type: application/json" \
            -H "Content-Security-Policy: $CSP_HEADER" \
            "$KIBANA_URL/api/agent_builder/agents" \
            -d "$agent_json")
    else
        # Local: No CSP header needed
        response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Authorization: ApiKey $API_KEY" \
            -H "kbn-xsrf: true" \
            -H "Content-Type: application/json" \
            "$KIBANA_URL/api/agent_builder/agents" \
            -d "$agent_json")
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo "✓ Agent created successfully"
    else
        echo "✗ Failed to create agent (HTTP $http_code)"
        echo "Response: $body"
    fi
    echo ""
}

# Process agents from JSON file
echo "Reading agents from $AGENT_FILE..."
echo ""

# Use jq if available, otherwise parse manually
if command -v jq &> /dev/null; then
    # Use jq for clean JSON parsing
    agent_count=$(cat "$AGENT_FILE" | jq '.agents | length')
    echo "Found $agent_count agent(s) to create"
    echo ""

    for i in $(seq 0 $((agent_count - 1))); do
        echo "=== Agent $((i + 1)) of $agent_count ==="
        agent_json=$(cat "$AGENT_FILE" | jq -c ".agents[$i]")
        create_agent "$agent_json"
    done
else
    # Manual parsing without jq
    echo "Note: jq not found, using basic parsing"
    echo ""

    # Extract each agent object manually
    # This is a simplified parser - assumes proper JSON formatting
    awk '
    BEGIN { in_agents=0; in_agent=0; brace_count=0; agent_num=0; }
    /"agents"[[:space:]]*:/ { in_agents=1; next; }
    in_agents && /{/ && !in_agent {
        in_agent=1;
        brace_count=1;
        agent_num++;
        print "AGENT_START_" agent_num;
        print $0;
        next;
    }
    in_agent {
        print $0;
        brace_count += gsub(/{/, "{");
        brace_count -= gsub(/}/, "}");
        if (brace_count == 0) {
            print "AGENT_END_" agent_num;
            in_agent=0;
        }
    }
    ' "$AGENT_FILE" | {
        agent_num=0
        agent_json=""
        while IFS= read -r line; do
            if [[ "$line" =~ AGENT_START_([0-9]+) ]]; then
                agent_num=${BASH_REMATCH[1]}
                agent_json=""
            elif [[ "$line" =~ AGENT_END_([0-9]+) ]]; then
                echo "=== Agent $agent_num ==="
                create_agent "$agent_json"
            else
                if [ -n "$agent_json" ]; then
                    agent_json="$agent_json
$line"
                else
                    agent_json="$line"
                fi
            fi
        done
    }
fi

echo "=== Agent Creation Complete ==="
