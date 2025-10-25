#!/bin/bash

# Elasticsearch Import Script for Sandbox Environment
# Imports pre-generated NDJSON files into Elasticsearch indices with lookup mode enabled
#
# Requirements:
# - API key in /tmp/api_key.txt
# - Elasticsearch running on localhost:9200
# - All data files in current directory

set -e  # Exit on error

# Read API key from file
if [ -f /tmp/api_key.txt ]; then
    API_KEY=$(cat /tmp/api_key.txt | tr -d '\n\r')
else
    echo "Error: /tmp/api_key.txt not found"
    exit 1
fi

# Use localhost as default endpoint
ES_URL="http://localhost:9200"

# Get script directory to find data files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Elasticsearch Multi-Index Import Script ==="
echo "Elasticsearch URL: $ES_URL"
echo "Data directory: $SCRIPT_DIR"
echo ""

# Function to create index with mapping
create_index() {
    local index_name=$1
    local mapping_file=$2

    echo "Creating index: $index_name"

    response=$(curl -s -w "\n%{http_code}" -X PUT \
        -H "Authorization: ApiKey $API_KEY" \
        -H "Content-Type: application/json" \
        "$ES_URL/$index_name" \
        -d @"$mapping_file")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo "✓ Index created successfully"
    else
        echo "✗ Failed to create index (HTTP $http_code)"
        echo "$response" | sed '$d'
    fi
    echo ""
}

# Function to import NDJSON data in chunks
import_data() {
    local ndjson_file=$1
    local index_name=$2
    local chunk_size=1000  # Lines per chunk (500 documents since each doc = 2 lines)

    echo "Importing data from: $(basename $ndjson_file)"

    # Count total lines (each document is 2 lines in bulk format)
    local total_lines=$(wc -l < "$ndjson_file")
    local total_docs=$((total_lines / 2))

    echo "Total documents: $total_docs"

    # Split and import in chunks
    local line_num=0
    local chunk_num=0
    local success_count=0

    while IFS= read -r line; do
        echo "$line" >> /tmp/chunk_$chunk_num.ndjson
        line_num=$((line_num + 1))

        # When we reach chunk size, upload it
        if [ $((line_num % chunk_size)) -eq 0 ]; then
            response=$(curl -s -X POST \
                -H "Authorization: ApiKey $API_KEY" \
                -H "Content-Type: application/x-ndjson" \
                "$ES_URL/_bulk" \
                --data-binary @/tmp/chunk_$chunk_num.ndjson)

            if echo "$response" | grep -q '"errors":false'; then
                success_count=$((success_count + chunk_size / 2))
                echo -n "."
            else
                echo -n "X"
            fi

            rm -f /tmp/chunk_$chunk_num.ndjson
            chunk_num=$((chunk_num + 1))
        fi
    done < "$ndjson_file"

    # Upload remaining lines
    if [ -f /tmp/chunk_$chunk_num.ndjson ]; then
        response=$(curl -s -X POST \
            -H "Authorization: ApiKey $API_KEY" \
            -H "Content-Type: application/x-ndjson" \
            "$ES_URL/_bulk" \
            --data-binary @/tmp/chunk_$chunk_num.ndjson)

        if echo "$response" | grep -q '"errors":false'; then
            echo -n "."
        else
            echo -n "X"
        fi

        rm -f /tmp/chunk_$chunk_num.ndjson
    fi

    echo ""
    echo "✓ Import completed in $((chunk_num + 1)) chunks"
    echo ""
}

# Function to verify import
verify_import() {
    local index_name=$1

    echo "Verifying import for: $index_name"

    # Refresh index to make documents searchable
    curl -s -X POST -H "Authorization: ApiKey $API_KEY" \
        "$ES_URL/$index_name/_refresh" > /dev/null

    # Get document count
    response=$(curl -s -H "Authorization: ApiKey $API_KEY" \
        "$ES_URL/$index_name/_count")

    # Extract count using grep and sed
    count=$(echo "$response" | grep -o '"count":[0-9]*' | grep -o '[0-9]*')

    if [ -n "$count" ]; then
        echo "✓ Documents imported: $count"
    else
        echo "Response: $response"
    fi
    echo ""
}

# Process asset-usage
echo ""
echo "=== Processing asset-usage ==="
create_index "asset-usage" "$SCRIPT_DIR/asset-usage.mapping"
import_data "$SCRIPT_DIR/asset-usage-bulk.ndjson" "asset-usage"
verify_import "asset-usage"

# Process brand-assets
echo ""
echo "=== Processing brand-assets ==="
create_index "brand-assets" "$SCRIPT_DIR/brand-assets.mapping"
import_data "$SCRIPT_DIR/brand-assets-bulk.ndjson" "brand-assets"
verify_import "brand-assets"

# Process campaign-performance
echo ""
echo "=== Processing campaign-performance ==="
create_index "campaign-performance" "$SCRIPT_DIR/campaign-performance.mapping"
import_data "$SCRIPT_DIR/campaign-performance-bulk.ndjson" "campaign-performance"
verify_import "campaign-performance"

echo ""
echo "=== All Imports Complete ==="
echo "Indices created:"
echo "  - asset-usage"
echo "  - brand-assets"
echo "  - campaign-performance"
echo ""
echo "All indices have lookup mode enabled"
