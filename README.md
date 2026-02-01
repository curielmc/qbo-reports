# ecfoBooks 📊

**AI-native bookkeeping for small businesses and non-profits.**

Built by [MYeCFO](https://myecfo.com) — your books, your way, with AI doing the heavy lifting.

## What Makes It Different

**QuickBooks gives you tools. ecfoBooks gives you answers.**

- 💬 **AI Chat** — Ask questions in plain English: *"What's my burn rate?"* *"Categorize all Starbucks as meals"*
- 🤖 **Smart Categorization** — Pattern-based rules that learn from your behavior
- 🔔 **Anomaly Detection** — Alerts for unusual charges, spending spikes, new vendors
- 📊 **Plain English Reports** — Every report includes an AI-generated summary
- 🏦 **Plaid Integration** — Auto-sync bank transactions daily
- 👥 **Multi-company, Multi-user** — Role-based access (Executive → Viewer)

## Tech Stack

- **Backend:** Rails 6.1, PostgreSQL, Devise + JWT
- **Frontend:** Vue 3, DaisyUI (Tailwind), Pinia, Vue Router
- **AI:** OpenAI GPT-4o-mini (configurable)
- **Banking:** Plaid Link + Transaction Sync API
- **Build:** Webpacker 5

## Quick Start

```bash
# Install dependencies
bundle install
yarn install

# Setup database
rails db:create db:migrate db:seed

# Set environment variables
export OPENAI_API_KEY=sk-...
export PLAID_CLIENT_ID=...
export PLAID_SECRET=...

# Start
rails server
bin/webpack-dev-server
```

Default admin: `admin@ecfobooks.com` / `ecfobooks2026!`

## Features

### For Clients
- Dashboard with net worth, P&L, spending trends
- Transaction search with inline categorization
- AI chat for financial questions
- CSV exports

### For Advisors (MYeCFO team)
- Manage multiple client companies
- AI-powered anomaly alerts
- Categorization rules engine
- Report generation with insights

### For Admins
- User management with 5-tier roles
- Company creation with member assignments
- Client invitation system (secure token links)
- Plaid + AI configuration

## Architecture

```
┌──────────────────────────────────────────┐
│              Vue 3 Frontend              │
│  Dashboard │ Chat │ Transactions │ Admin │
├──────────────────────────────────────────┤
│            Rails 6.1 API (JSON)          │
│  Auth │ Companies │ Reports │ Exports    │
├──────────────────────────────────────────┤
│  BookkeeperAi  │  AnomalyDetector       │
│  ReportSummarizer  │  CategorizationRule │
├──────────────────────────────────────────┤
│          PostgreSQL │ Plaid API          │
└──────────────────────────────────────────┘
```

## Roles

| Role | See All Companies | Edit | Admin Panel |
|------|:-:|:-:|:-:|
| Executive | ✅ | ✅ | ✅ |
| Manager | ✅ | ⚠️ | ✅ |
| Advisor | Assigned only | ✅ | ❌ |
| Client | Own only | ⚠️ | ❌ |
| Viewer | Shared only | ❌ | ❌ |

## License

Proprietary — MYeCFO LLC
