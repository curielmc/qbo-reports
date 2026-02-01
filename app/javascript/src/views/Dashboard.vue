<template>
  <div>
    <!-- Stats Overview -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-6 mb-6 sm:mb-8">
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-primary">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 sm:w-8 sm:h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <div class="stat-title">Net Worth</div>
        <div class="stat-value text-primary text-lg sm:text-2xl">{{ formatCurrency(data.financials?.net_worth) }}</div>
        <div class="stat-desc">Assets minus liabilities</div>
      </div>

      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-success">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 sm:w-8 sm:h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
          </svg>
        </div>
        <div class="stat-title">YTD Income</div>
        <div class="stat-value text-success text-lg sm:text-2xl">{{ formatCurrency(data.financials?.ytd_income) }}</div>
        <div class="stat-desc">Since Jan 1</div>
      </div>

      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-error">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 sm:w-8 sm:h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6" />
          </svg>
        </div>
        <div class="stat-title">YTD Expenses</div>
        <div class="stat-value text-error text-lg sm:text-2xl">{{ formatCurrency(data.financials?.ytd_expenses) }}</div>
        <div class="stat-desc">Since Jan 1</div>
      </div>

      <div :class="['stat bg-base-100 rounded-box shadow']">
        <div class="stat-figure text-warning">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 sm:w-8 sm:h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
          </svg>
        </div>
        <div class="stat-title">Uncategorized</div>
        <div class="stat-value text-warning text-2xl">{{ data.stats?.uncategorized || 0 }}</div>
        <div class="stat-desc">Transactions need review</div>
      </div>
    </div>

    <!-- Middle Row: Net Income + Assets/Liabilities -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-3 sm:gap-6 mb-6 sm:mb-8">
      <!-- Net Income Card -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Net Income (YTD)</h2>
          <div class="flex items-center gap-4 mt-4">
            <div :class="['text-4xl font-bold', (data.financials?.net_income || 0) >= 0 ? 'text-success' : 'text-error']">
              {{ formatCurrency(data.financials?.net_income) }}
            </div>
          </div>
          <div class="mt-4 space-y-2">
            <div class="flex justify-between">
              <span class="text-base-content/60">Income</span>
              <span class="font-mono text-success">{{ formatCurrency(data.financials?.ytd_income) }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Expenses</span>
              <span class="font-mono text-error">{{ formatCurrency(data.financials?.ytd_expenses) }}</span>
            </div>
            <progress 
              class="progress progress-success w-full" 
              :value="incomeRatio" 
              max="100"
            ></progress>
            <div class="text-xs text-base-content/40 text-right">
              {{ incomeRatio.toFixed(0) }}% savings rate
            </div>
          </div>
        </div>
      </div>

      <!-- Monthly Spending Trend -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Monthly Spending (6 months)</h2>
          <div class="mt-4 space-y-3">
            <div v-for="month in data.monthly_spending" :key="month.month" class="flex items-center gap-3">
              <span class="w-20 text-sm text-base-content/60">{{ month.month }}</span>
              <progress 
                class="progress progress-primary flex-1" 
                :value="month.amount" 
                :max="maxSpending"
              ></progress>
              <span class="w-24 text-right font-mono text-sm">{{ formatCurrency(month.amount) }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- AI Alerts -->
    <div v-if="data.alerts?.length" class="mb-8">
      <div v-for="alert in data.alerts" :key="alert.message" 
        :class="['alert shadow-lg mb-2', alertClass(alert.severity)]">
        <span>{{ alertIcon(alert.type) }} {{ alert.message }}</span>
        <router-link v-if="alert.type === 'uncategorized'" to="/chat" class="btn btn-sm">Fix with AI →</router-link>
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      <router-link to="/chat" class="btn btn-primary gap-2">💬 Ask AI</router-link>
      <router-link to="/reports" class="btn btn-outline gap-2">📈 Reports</router-link>
      <router-link to="/linked-accounts" class="btn btn-outline gap-2">🏦 Link Account</router-link>
      <router-link to="/transactions" class="btn btn-outline gap-2">💳 Transactions</router-link>
    </div>

    <!-- Recent Transactions -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <div class="flex justify-between items-center mb-4">
          <h2 class="card-title">Recent Transactions</h2>
          <router-link to="/transactions" class="btn btn-ghost btn-sm">View All →</router-link>
        </div>
        <div class="overflow-x-auto">
          <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
            <thead>
              <tr>
                <th>Date</th>
                <th>Description</th>
                <th>Account</th>
                <th>Category</th>
                <th class="text-right">Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="txn in data.recent_transactions" :key="txn.id">
                <td class="font-mono text-sm">{{ formatDate(txn.date) }}</td>
                <td>{{ txn.description }}</td>
                <td class="text-sm text-base-content/60">{{ txn.account_name }}</td>
                <td>
                  <span v-if="txn.chart_of_account_name" class="badge badge-sm badge-outline">
                    {{ txn.chart_of_account_name }}
                  </span>
                  <span v-else class="badge badge-sm badge-warning">Uncategorized</span>
                </td>
                <td :class="['text-right font-mono', txn.amount >= 0 ? 'text-success' : 'text-error']">
                  {{ formatCurrency(txn.amount) }}
                </td>
              </tr>
              <tr v-if="!data.recent_transactions?.length">
                <td colspan="5" class="text-center py-8 text-base-content/50">
                  No transactions yet. Link an account to get started.
                </td>
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
import { apiClient } from '../api/client'

const data = ref({
  stats: {},
  financials: {},
  monthly_spending: [],
  recent_transactions: []
})

const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 0 }).format(amount || 0)
}
const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : ''

const incomeRatio = computed(() => {
  const income = data.value.financials?.ytd_income || 0
  const expenses = data.value.financials?.ytd_expenses || 0
  if (income === 0) return 0
  return Math.max(0, ((income - expenses) / income) * 100)
})

const alertClass = (severity) => {
  if (severity >= 70) return 'alert-error'
  if (severity >= 40) return 'alert-warning'
  return 'alert-info'
}
const alertIcon = (type) => {
  const icons = { unusual_amount: '⚠️', spending_spike: '📈', new_vendors: '🆕', uncategorized: '📋' }
  return icons[type] || '🔔'
}

const maxSpending = computed(() => {
  return Math.max(...(data.value.monthly_spending || []).map(m => m.amount), 1)
})

onMounted(async () => {
  data.value = await apiClient.get('/api/v1/dashboard') || data.value
})
</script>
