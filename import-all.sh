#!/bin/bash

# Elasticsearch Import Script
# Imports pre-generated NDJSON files into Elasticsearch indices with lookup mode enabled

set -e  # Exit on error

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found"
    exit 1
fi

ES_URL="${ES_ENDPOINT}"
API_KEY="${ES_API_KEY}"
DATA_DIR="elastic/AgentBuilderWN9.2"

echo "=== Elasticsearch Multi-Index Import Script ==="
echo "Elasticsearch URL: $ES_URL"
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

# Function to import NDJSON data
import_data() {
    local ndjson_file=$1
    local index_name=$2

    echo "Importing data from: $ndjson_file"

    response=$(curl -s -X POST \
        -H "Authorization: ApiKey $API_KEY" \
        -H "Content-Type: application/x-ndjson" \
        "$ES_URL/_bulk" \
        --data-binary @"$ndjson_file")

    # Simple check for errors in response
    if echo "$response" | grep -q '"errors":false'; then
        echo "✓ Data imported successfully"
    else
        echo "✗ Some errors may have occurred during import"
        echo "$response" | head -c 500
    fi
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

# Function to create data view
create_data_view() {
    local index_name=$1
    local display_name=$2

    echo "Creating data view: $display_name"

    # Note: Data view API may not be accessible via API in serverless
    # If this fails, create data views manually in Kibana UI
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: ApiKey $API_KEY" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        "$ES_URL/api/data_views/data_view" \
        -d "{
            \"data_view\": {
                \"title\": \"$index_name\",
                \"name\": \"$display_name\"
            }
        }")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo "✓ Data view created"
    else
        echo "⚠ Data view creation skipped (create manually in Kibana UI)"
    fi
    echo ""
}

# Process asset-usage
echo ""
echo "=== Processing asset-usage ==="
create_index "asset-usage" "$DATA_DIR/asset-usage.mapping"
import_data "$DATA_DIR/asset-usage-bulk.ndjson" "asset-usage"
verify_import "asset-usage"
create_data_view "asset-usage" "Asset Usage"

# Process brand-assets
echo ""
echo "=== Processing brand-assets ==="
create_index "brand-assets" "$DATA_DIR/brand-assets.mapping"
import_data "$DATA_DIR/brand-assets-bulk.ndjson" "brand-assets"
verify_import "brand-assets"
create_data_view "brand-assets" "Brand Assets"

# Process campaign-performance
echo ""
echo "=== Processing campaign-performance ==="
create_index "campaign-performance" "$DATA_DIR/campaign-performance.mapping"
import_data "$DATA_DIR/campaign-performance-bulk.ndjson" "campaign-performance"
verify_import "campaign-performance"
create_data_view "campaign-performance" "Campaign Performance"

echo ""
echo "=== All Imports Complete ==="
echo "Indices created:"
echo "  - asset-usage"
echo "  - brand-assets"
echo "  - campaign-performance"
echo ""
echo "All indices have lookup mode enabled"
echo ""
echo "Note: If data views were not created automatically,"
echo "please create them manually in the Kibana UI using the index names above."
