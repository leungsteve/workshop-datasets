# Agent Builder Workshop - Brand Analytics Setup

## Project Overview

This repository contains automation scripts and configuration files for setting up Elastic Agent Builder with brand analytics capabilities. It includes data import scripts, ES|QL tools, and an AI agent for analyzing brand assets and campaign performance.

## Repository Contents

### Data Files
- **3 CSV files**: brand-assets.csv, asset-usage.csv, campaign-performance.csv
- **3 NDJSON bulk files**: Pre-generated for faster import
- **3 mapping files**: Elasticsearch index mappings with lookup mode enabled

### Import Scripts
- `import-all.sh` - Full import script (requires .env file locally)
- `import-sandbox.sh` - Sandbox-optimized import with chunking (uses /tmp/api_key.txt)
- `import-asset-usage.sh` - Legacy single-index import

### Agent Builder Scripts
- `add-tools.sh` - Creates ES|QL tools via Agent Builder API
- `add-agent.sh` - Creates AI agents via Agent Builder API

### Tool Definitions (8 tools)
1. `tools-campaign-roi.json` - Campaign ROI and performance metrics
2. `tools-channel-performance.json` - Channel and region performance analysis
3. `tools-hidden-gems.json` - Identifies underutilized high-value assets
4. `tools-approval-workflow.json` - Approval workflow efficiency tracking
5. `tools-monthly-trends.json` - Time-series performance trends
6. `tools-asset-type-performance.json` - Asset type effectiveness ranking
7. `tools-audience-profitability.json` - Audience segment targeting efficiency
8. `tools-department-usage.json` - Cross-departmental asset adoption

### Agent Definition
- `agent-brand-analytics.json` - Brand Asset Performance Intelligence agent with all 8 tools

## Environment Setup

### Local Environment
Requires `.env` file in repository root with:
```bash
ES_API_KEY="your-api-key-here"
ES_ENDPOINT="https://your-cluster.es.region.gcp.elastic.cloud:443"
```

**Note**: Kibana endpoint is automatically derived by replacing `.es.` with `.kb.` in the ES_ENDPOINT.

### Sandbox Environment
Automatically detected when `/tmp/api_key.txt` exists:
- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:8080
- **API Key**: Read from `/tmp/api_key.txt`
- **CSP Headers**: Automatically added for sandbox

## Usage

### Step 1: Import Data into Elasticsearch

**On Local Machine:**
```bash
cd elastic/AgentBuilderWN9.2
./import-all.sh
```

**On Sandbox:**
```bash
mkdir -p elastic/AgentBuilderWN9.2
cd elastic/AgentBuilderWN9.2

# Download import script and data files
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/import-sandbox.sh
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/asset-usage-bulk.ndjson
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/brand-assets-bulk.ndjson
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/campaign-performance-bulk.ndjson
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/asset-usage.mapping
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/brand-assets.mapping
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/campaign-performance.mapping

chmod +x import-sandbox.sh
./import-sandbox.sh
```

**Expected Result**: 3 indices created with lookup mode:
- `asset-usage`: 16,013 documents
- `brand-assets`: 289 documents
- `campaign-performance`: 10,349 documents

### Step 2: Create Agent Builder Tools

**On Sandbox:**
```bash
# Download add-tools script
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/add-tools.sh
chmod +x add-tools.sh

# Download all 8 tool definition files
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/tools-campaign-roi.json
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/tools-channel-performance.json
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/tools-hidden-gems.json
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/tools-approval-workflow.json
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/tools-monthly-trends.json
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/tools-asset-type-performance.json
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/tools-audience-profitability.json
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/tools-department-usage.json

# Create all tools (loop through all JSON files)
for tool_file in tools-*.json; do
    ./add-tools.sh "$tool_file"
done
```

**Expected Result**: 8 tools created with IDs:
- customer.campaign_roi_analysis
- customer.channel_performance_regional
- customer.hidden_gems_analysis
- customer.approval_workflow_efficiency
- customer.monthly_performance_trends
- customer.asset_type_performance
- customer.audience_segment_profitability
- customer.department_asset_usage

### Step 3: Create Agent Builder Agent

**On Sandbox:**
```bash
# Download add-agent script and agent definition
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/add-agent.sh
wget https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/elastic/AgentBuilderWN9.2/agent-brand-analytics.json

chmod +x add-agent.sh

# Create the agent
./add-agent.sh agent-brand-analytics.json
```

**Expected Result**: Agent created with:
- **ID**: customer-brand-analytics-agent
- **Name**: Brand Asset Performance Intelligence
- **Tools**: All 8 tools automatically attached

## Known Issues and Solutions

### Issue 1: Import Sandbox Script - File Too Large (413 Error)
**Problem**: Large NDJSON files (asset-usage, campaign-performance) exceed nginx limit.

**Solution**: Script automatically chunks files into 1000-line batches (500 documents each).

### Issue 2: Data View Creation Fails in Serverless
**Problem**: Kibana data view API returns 400 error in serverless.

**Solution**: Create data views manually in Kibana UI using the index names.

### Issue 3: Sandbox Script Download Shows HTML
**Problem**: Using github.com URL instead of raw.githubusercontent.com downloads HTML page.

**Solution**: Always use `https://raw.githubusercontent.com/leungsteve/workshop-datasets/main/...` URLs.

### Issue 4: Syntax Error on Sandbox
**Problem**: Script shows "syntax error near unexpected token 'newline'" and `<!DOCTYPE html>`.

**Solution**: Downloaded HTML instead of script. Re-download using raw.githubusercontent.com URL (see Issue 3).

## Data Schema

### brand-assets Index
- **Fields**: Asset ID, Product Name, Asset Type, Description, Deployment Date, Status, Region, File Path, Usage Guidelines, Associated Campaign
- **Lookup Mode**: Enabled
- **Count**: 289 assets

### asset-usage Index
- **Fields**: Event ID, Asset ID, Timestamp, Action Type, User ID, Department, Device Type, Duration Seconds, Session ID
- **Lookup Mode**: Enabled
- **Count**: 16,013 events

### campaign-performance Index
- **Fields**: Performance ID, Campaign Name, Asset ID, Date, Channel, Region, Audience Segment, Impressions, Clicks, Conversions, Engagement Rate, Conversion Rate, Spend, Revenue
- **Lookup Mode**: Enabled
- **Count**: 10,349 records

## ES|QL Query Format

All tool queries use multi-line formatting with `\n` for readability:

```json
"query": "FROM campaign-performance\n| LOOKUP JOIN brand-assets ON `Asset ID`\n| EVAL roi = TO_DOUBLE(Revenue - Spend) / Spend * 100\n..."
```

## API Endpoints

### Tools API
- **Endpoint**: `POST /api/agent_builder/tools`
- **Create**: `curl -X POST -H "Authorization: ApiKey $API_KEY" -H "kbn-xsrf: true" -H "Content-Type: application/json" "$KIBANA_URL/api/agent_builder/tools" -d @tool.json`
- **Get**: `GET /api/agent_builder/tools/{tool_id}`
- **Delete**: `DELETE /api/agent_builder/tools/{tool_id}`

### Agents API
- **Endpoint**: `POST /api/agent_builder/agents`
- **Create**: `curl -X POST -H "Authorization: ApiKey $API_KEY" -H "kbn-xsrf: true" -H "Content-Type: application/json" "$KIBANA_URL/api/agent_builder/agents" -d @agent.json`
- **Get**: `GET /api/agent_builder/agents/{agent_id}`

## Next Steps

1. **Test Agent**: Interact with the Brand Asset Performance Intelligence agent in Kibana
2. **Create Data Views**: Manually create data views in Kibana UI for the 3 indices
3. **Add More Tools**: Create additional ES|QL tools for specific use cases
4. **Create Additional Agents**: Set up specialized agents for different teams

## Troubleshooting

### Script shows "command not found"
- Ensure script has execute permissions: `chmod +x script-name.sh`
- Try running with bash explicitly: `bash ./script-name.sh`

### API returns 404 or 400
- Verify Kibana URL is correct (should use `.kb.` subdomain for serverless)
- Check API key has proper permissions
- Ensure Agent Builder is available in your Kibana instance (9.2.0+)

### Tools not appearing in agent
- Verify tools were created successfully before creating agent
- Check tool IDs match exactly in agent configuration
- Use `GET /api/agent_builder/tools` to list all available tools

## Repository
https://github.com/leungsteve/workshop-datasets

## Documentation References
- [Agent Builder Kibana API](https://www.elastic.co/docs/solutions/search/agent-builder/kibana-api)
- [ES|QL Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/esql.html)
