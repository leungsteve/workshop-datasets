#!/bin/bash

# Asset Usage CSV Import Script for Elasticsearch
# Replace YOUR_API_KEY with your actual API key
# Replace localhost:9200 with your Elasticsearch endpoint if different

API_KEY="YOUR_API_KEY"
ES_URL="http://localhost:9200"
INDEX_NAME="asset-usage"

echo "=== Elasticsearch Asset Usage Import Script ==="
echo "Index: $INDEX_NAME"
echo "Elasticsearch URL: $ES_URL"
echo ""

# Step 1: Create the index with lookup mode and mapping
echo "Step 1: Creating index with lookup mode and mapping..."
curl -X PUT -H "Authorization: ApiKey $API_KEY" \
     -H "Content-Type: application/json" \
     "$ES_URL/$INDEX_NAME" \
     -d @asset-usage-corrected.mapping

echo -e "\n"

# Step 2: Import the CSV data using bulk API
echo "Step 2: Importing CSV data..."
curl -X POST -H "Authorization: ApiKey $API_KEY" \
     -H "Content-Type: application/x-ndjson" \
     "$ES_URL/_bulk" \
     --data-binary @asset-usage-bulk.ndjson

echo -e "\n"

# Step 3: Verify the import
echo "Step 3: Verifying the import..."
curl -H "Authorization: ApiKey $API_KEY" \
     "$ES_URL/$INDEX_NAME/_count?pretty"

echo -e "\n"

# Step 4: Create a data view (if using Kibana)
echo "Step 4: Creating data view (Kibana API)..."
curl -X POST -H "Authorization: ApiKey $API_KEY" \
     -H "Content-Type: application/json" \
     -H "kbn-xsrf: true" \
     "$ES_URL/../api/data_views/data_view" \
     -d '{
       "data_view": {
         "title": "asset-usage*",
         "name": "Asset Usage",
         "timeFieldName": "@timestamp"
       }
     }'

echo -e "\n=== Import Complete ==="
echo "Index created: $INDEX_NAME"
echo "Index mode: lookup"
echo "Records imported from: asset-usage.csv"
echo "Data view created: Asset Usage"
