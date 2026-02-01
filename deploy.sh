#!/bin/bash
# ecfoBooks — One-command deploy to Fly.io
# Run: ./deploy.sh
#
# Prerequisites:
#   1. Install flyctl: curl -L https://fly.io/install.sh | sh
#   2. Login: flyctl auth login
#   3. Run this script

set -e
export PATH="$HOME/.fly/bin:$PATH"

echo "🚀 Deploying ecfoBooks to Fly.io..."

# Create app if it doesn't exist
flyctl apps create ecfobooks --org personal 2>/dev/null || echo "App already exists"

# Create PostgreSQL database (free tier)
echo "📦 Setting up PostgreSQL..."
flyctl postgres create --name ecfobooks-db --region sjc --vm-size shared-cpu-1x --initial-cluster-size 1 --volume-size 1 2>/dev/null || echo "DB already exists"

# Attach database
flyctl postgres attach ecfobooks-db --app ecfobooks 2>/dev/null || echo "DB already attached"

# Set secrets
echo "🔐 Setting secrets..."
MASTER_KEY=$(cat config/master.key 2>/dev/null || echo "")
if [ -n "$MASTER_KEY" ]; then
  flyctl secrets set RAILS_MASTER_KEY="$MASTER_KEY" --app ecfobooks
fi

# Set OpenAI key (prompt user)
if [ -n "$OPENAI_API_KEY" ]; then
  flyctl secrets set OPENAI_API_KEY="$OPENAI_API_KEY" --app ecfobooks
else
  echo "⚠️  Set OPENAI_API_KEY later: flyctl secrets set OPENAI_API_KEY=sk-xxx --app ecfobooks"
fi

# Deploy!
echo "🏗️  Building and deploying..."
flyctl deploy --app ecfobooks

# Run migrations and seed
echo "🗃️  Running migrations..."
flyctl ssh console --app ecfobooks -C "bundle exec rake db:migrate db:seed"

echo ""
echo "✅ ecfoBooks is LIVE!"
echo "🌐 URL: https://ecfobooks.fly.dev"
echo "🔑 Login: martin@myecfo.com / ecfobooks2026!"
echo ""
echo "Next steps:"
echo "  flyctl secrets set OPENAI_API_KEY=sk-xxx --app ecfobooks"
echo "  flyctl secrets set PLAID_CLIENT_ID=xxx PLAID_SECRET=xxx --app ecfobooks"
