<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-3xl font-bold">Billing & Usage</h1>
        <p class="text-base-content/60 mt-1">{{ companyName }}</p>
      </div>
      <div class="text-right">
        <p class="text-sm text-base-content/50">Billing Cycle</p>
        <p class="font-medium">{{ cycleLabel }}</p>
      </div>
    </div>

    <!-- Top Cards: What They Owe -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
      <div class="card bg-primary text-primary-content shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-primary-content/70 text-sm">Total This Period</h2>
          <p class="text-4xl font-bold font-mono">{{ formatCurrency(usage.total_due) }}</p>
          <p class="text-primary-content/60 text-sm mt-1">
            {{ usage.engagement_type === 'flat_fee' ? 'Flat fee' : 'Hourly' }} + AI usage
          </p>
        </div>
      </div>

      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-base-content/60 text-sm">
            {{ usage.engagement_type === 'flat_fee' ? 'Monthly Fee' : 'Time & Hours' }}
          </h2>
          <p class="text-3xl font-bold font-mono">{{ formatCurrency(usage.base_fee) }}</p>
          <p v-if="usage.engagement_type === 'flat_fee'" class="text-sm text-base-content/50 mt-1">
            Monthly flat fee
          </p>
          <p v-else class="text-sm text-base-content/50 mt-1">
            {{ usage.hours?.total_hours || 0 }} hrs × {{ formatCurrency(usage.hourly_rate) }}/hr
          </p>
        </div>
      </div>

      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-base-content/60 text-sm">AI Usage</h2>
          <p :class="['text-3xl font-bold font-mono', usage.overage > 0 ? 'text-warning' : 'text-success']">
            {{ formatCurrency(usage.ai_overage || 0) }}
          </p>
          <p class="text-sm text-base-content/50 mt-1">
            {{ usage.total_queries || 0 }} queries · ${{ formatCurrency(usage.credit_total) }} credit included
          </p>
        </div>
      </div>
    </div>

    <!-- Credit Meter -->
    <div class="card bg-base-100 shadow-xl mb-8">
      <div class="card-body">
        <div class="flex justify-between items-center mb-3">
          <h2 class="card-title text-lg">AI Query Credit</h2>
          <span :class="['badge badge-lg', creditPct > 50 ? 'badge-success' : creditPct > 20 ? 'badge-warning' : 'badge-error']">
            {{ formatCurrency(usage.credit_remaining) }} remaining
          </span>
        </div>
        
        <progress 
          :class="['progress w-full h-4', creditPct > 50 ? 'progress-success' : creditPct > 20 ? 'progress-warning' : 'progress-error']"
          :value="usage.credit_used" 
          :max="usage.credit_total || 1"
        ></progress>
        
        <div class="flex justify-between text-sm text-base-content/50 mt-2">
          <span>{{ formatCurrency(usage.credit_used) }} used</span>
          <span>{{ formatCurrency(usage.credit_total) }} total</span>
        </div>

        <div v-if="usage.overage > 0" class="alert alert-warning mt-4">
          <span>⚠️ You've exceeded your included credit. Additional queries billed at {{ formatCurrency(usage.per_query_rate) }}/query.</span>
        </div>
      </div>
    </div>

    <!-- Time Entries (hourly engagements) -->
    <div v-if="usage.engagement_type === 'hourly' && usage.hours?.entries?.length" class="card bg-base-100 shadow-xl mb-8">
      <div class="card-body">
        <div class="flex justify-between items-center mb-4">
          <h2 class="card-title text-lg">⏱️ Time Entries</h2>
          <div class="badge badge-primary badge-lg font-mono">
            {{ usage.hours.total_hours }} hrs = {{ formatCurrency(usage.hours.total_amount) }}
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Date</th>
                <th>Description</th>
                <th>Team Member</th>
                <th class="text-right">Hours</th>
                <th class="text-right">Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(entry, i) in usage.hours.entries" :key="i" class="hover">
                <td class="text-sm whitespace-nowrap">{{ entry.date }}</td>
                <td class="text-sm">{{ entry.description || '—' }}</td>
                <td class="text-sm">{{ entry.user || '—' }}</td>
                <td class="text-right font-mono text-sm">{{ entry.duration_hours }}h</td>
                <td class="text-right font-mono text-sm">{{ formatCurrency(entry.duration_hours * (usage.hourly_rate || 0)) }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="font-bold">
                <td colspan="3">Total</td>
                <td class="text-right font-mono">{{ usage.hours.total_hours }}h</td>
                <td class="text-right font-mono">{{ formatCurrency(usage.hours.total_amount) }}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
    </div>

    <!-- Usage Breakdown -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
      <!-- By Action Type -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">Queries by Type</h2>
          <div class="space-y-3">
            <div v-for="item in usageBreakdown" :key="item.action" class="flex items-center gap-3">
              <span class="text-xl w-8 text-center">{{ actionIcon(item.action) }}</span>
              <div class="flex-1">
                <div class="flex justify-between text-sm">
                  <span class="font-medium capitalize">{{ item.action.replace(/_/g, ' ') }}</span>
                  <span class="font-mono">{{ item.count }} queries</span>
                </div>
                <progress class="progress progress-primary w-full h-2" :value="item.count" :max="maxQueries"></progress>
              </div>
              <span class="font-mono text-sm w-16 text-right">{{ formatCurrency(item.total) }}</span>
            </div>
            <div v-if="!usageBreakdown.length" class="text-center py-4 text-base-content/50">
              No queries this billing cycle yet.
            </div>
          </div>
        </div>
      </div>

      <!-- Monthly Trend -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">Monthly History</h2>
          <div class="space-y-3">
            <div v-for="month in history" :key="month.period" class="flex items-center gap-3">
              <span class="w-20 text-sm text-base-content/60">{{ month.period.split(' ')[0].substring(0,3) }}</span>
              <div class="flex-1">
                <progress class="progress progress-secondary w-full h-3" :value="month.total_due" :max="maxMonthly"></progress>
              </div>
              <div class="text-right w-28">
                <span class="font-mono text-sm font-bold">{{ formatCurrency(month.total_due) }}</span>
                <span class="block text-xs text-base-content/40">{{ month.ai_queries }} queries</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Recent Queries Log -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title text-lg mb-4">Recent Activity</h2>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Time</th>
                <th>Action</th>
                <th>Detail</th>
                <th class="text-right">Cost</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="q in recentQueries" :key="q.id" class="hover">
                <td class="text-sm text-base-content/50 whitespace-nowrap">{{ formatTime(q.created_at) }}</td>
                <td>
                  <span class="badge badge-sm badge-outline capitalize">{{ q.action.replace(/_/g, ' ') }}</span>
                </td>
                <td class="text-sm max-w-xs truncate">{{ q.query_summary }}</td>
                <td class="text-right font-mono text-sm">{{ formatCurrency(q.billed_amount) }}</td>
              </tr>
              <tr v-if="!recentQueries.length">
                <td colspan="4" class="text-center py-6 text-base-content/50">No queries yet this cycle.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const usage = ref({})
const history = ref([])
const recentQueries = ref([])

const companyId = computed(() => appStore.currentCompany?.id || 1)
const companyName = computed(() => appStore.currentCompany?.name || 'Your Company')
const cycleLabel = computed(() => {
  const now = new Date()
  return `${now.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}`
})

const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)
const formatTime = (ts) => ts ? new Date(ts).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : ''

const creditPct = computed(() => {
  if (!usage.value.credit_total) return 100
  return Math.max(0, ((usage.value.credit_total - (usage.value.credit_used || 0)) / usage.value.credit_total) * 100)
})

const usageBreakdown = computed(() => (usage.value.breakdown || []).sort((a, b) => b.count - a.count))
const maxQueries = computed(() => Math.max(...usageBreakdown.value.map(i => i.count), 1))
const maxMonthly = computed(() => Math.max(...history.value.map(m => m.total_due || 0), 1))

const actionIcon = (action) => {
  const icons = {
    chat: '💬', categorize: '📋', suggest_categories: '🤖', report: '📈',
    parse_statement: '📄', reconcile: '🔍', anomalies: '⚠️', coa_health: '🏥',
    migration: '📦', search_transactions: '🔎', balance_summary: '💰'
  }
  return icons[action] || '⚡'
}

onMounted(async () => {
  const cid = companyId.value
  const [usageData, historyData] = await Promise.all([
    apiClient.get(`/api/v1/companies/${cid}/usage`),
    apiClient.get(`/api/v1/companies/${cid}/usage/history?months=6`)
  ])
  
  usage.value = {
    ...usageData,
    total_due: (usageData?.monthly_fee || 0) + (usageData?.overage || 0),
    base_fee: usageData?.monthly_fee || 0,
    per_query_rate: (usageData?.per_query_cents || 5) / 100
  }
  history.value = historyData || []

  // Fetch recent queries
  // This would be a separate endpoint in production; for now, derive from usage
})
</script>
