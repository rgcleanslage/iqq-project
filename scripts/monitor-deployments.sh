#!/bin/bash

# Script to monitor deployment progress
# Usage: ./scripts/monitor-deployments.sh

echo "🔍 Monitoring Deployment Progress"
echo ""

# Watch the workflow runs
watch -n 10 'gh run list --workflow="deploy-version.yml" --repo rgcleanslage/iqq-project --limit 5'
