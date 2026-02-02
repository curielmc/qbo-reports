<template>
  <div>
    <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-6">
      <h1 class="text-xl sm:text-3xl font-bold">Reports</h1>
      <div class="flex flex-wrap items-center gap-2">
        <select v-model="selectedPeriod" @change="applyPeriod" class="select select-bordered select-sm">
          <option value="this_month">This Month</option>
          <option value="last_month">Last Month</option>
          <option value="this_quarter">This Quarter</option>
          <option value="last_quarter">Last Quarter</option>
          <option value="this_year">This Year</option>
          <option value="last_year">Last Year</option>
          <option value="year_to_date">Year to Date</option>
          <option value="last_12_months">Last 12 Months</option>
          <option value="all_time">All Time</option>
          <option value="custom">Custom</option>
        </select>
        <template v-if="selectedPeriod === 'custom'">
          <input type="date" v-model="startDate" @change="refresh" class="input input-bordered input-sm" />
          <span class="text-base-content/40">to</span>
          <input type="date" v-model="endDate" @change="refresh" class="input input-bordered input-sm" />
        </template>
        <span v-else class="text-sm text-base-content/60">{{ formatDateRange }}</span>
      </div>
    </div>

    <!-- Report Tabs -->
    <div class="tabs tabs-boxed mb-6">
      <a :class="['tab', activeTab === 'pl' ? 'tab-active' : '']" @click="activeTab = 'pl'">Profit & Loss</a>
      <a :class="['tab', activeTab === 'bs' ? 'tab-active' : '']" @click="activeTab = 'bs'">Balance Sheet</a>
      <a :class="['tab', activeTab === 'tb' ? 'tab-active' : '']" @click="activeTab = 'tb'">Trial Balance</a>
      <a :class="['tab', activeTab === 'gl' ? 'tab-active' : '']" @click="activeTab = 'gl'">General Ledger</a>
    </div>

    <!-- AI Summary -->
    <div v-if="summary" class="alert alert-info shadow-lg mb-6">
      <div class="flex gap-3">
        <span class="text-2xl">🤖</span>
        <div>
          <p class="font-medium text-sm mb-1">AI Insights</p>
          <p>{{ summary }}</p>
        </div>
      </div>
    </div>

    <!-- P&L Report -->
    <div v-if="activeTab === 'pl'" class="space-y-6">
      <div class="flex justify-end">
        <a :href="`/api/v1/companies/${companyId}/exports/profit_loss?start_date=${startDate}&end_date=${endDate}`" 
          class="btn btn-outline btn-sm gap-1">📥 Export CSV</a>
      </div>

      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-success">Income</h2>
          <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
            <tbody>
              <tr v-for="[name, amount] in plData.income" :key="name">
                <td>{{ name }}</td>
                <td class="text-right font-mono text-success">{{ formatCurrency(amount) }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="font-bold border-t-2">
                <td>Total Income</td>
                <td class="text-right font-mono text-success">{{ formatCurrency(plData.totalIncome) }}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-error">Expenses</h2>
          <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
            <tbody>
              <tr v-for="[name, amount] in plData.expenses" :key="name">
                <td>{{ name }}</td>
                <td class="text-right font-mono text-error">{{ formatCurrency(amount) }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="font-bold border-t-2">
                <td>Total Expenses</td>
                <td class="text-right font-mono text-error">{{ formatCurrency(plData.totalExpenses) }}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <div class="card bg-primary text-primary-content shadow-xl">
        <div class="card-body flex-row justify-between items-center">
          <h2 class="card-title">Net Income</h2>
          <span class="text-3xl font-bold font-mono">{{ formatCurrency(plData.totalIncome - plData.totalExpenses) }}</span>
        </div>
      </div>
    </div>

    <!-- Balance Sheet -->
    <div v-if="activeTab === 'bs'" class="space-y-6">
      <div class="flex justify-between">
        <div v-if="bsReport && bsReport.balanced" class="badge badge-success gap-1">✓ Balanced</div>
        <div v-else class="badge badge-error gap-1">⚠ Unbalanced</div>
        <a :href="`/api/v1/companies/${companyId}/exports/balance_sheet?as_of_date=${endDate}`" 
          class="btn btn-outline btn-sm gap-1">📥 Export CSV</a>
      </div>

      <div v-for="section in bsSections" :key="section.title" class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 :class="['card-title', section.color]">{{ section.title }}</h2>
          <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
            <tbody>
              <tr v-for="item in section.items" :key="item.name"
                  :class="item.id ? 'cursor-pointer hover:bg-base-200 transition-colors' : ''"
                  @click="item.id ? openDrilldown(item) : null">
                <td>
                  <span v-if="item.id" class="text-primary underline decoration-dotted underline-offset-4">{{ item.name }}</span>
                  <span v-else>{{ item.name }}</span>
                </td>
                <td class="text-right font-mono">{{ formatCurrency(item.balance) }}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="font-bold border-t-2">
                <td>Total {{ section.title }}</td>
                <td class="text-right font-mono">{{ formatCurrency(section.total) }}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
    </div>

    <!-- Account Drilldown Modal -->
    <dialog ref="drilldownModal" class="modal">
      <div class="modal-box max-w-5xl w-11/12">
        <form method="dialog">
          <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">X</button>
        </form>
        <h3 class="font-bold text-lg mb-1" v-if="drilldownAccount">
          {{ drilldownAccount.name }}
        </h3>
        <p class="text-sm text-base-content/60 mb-4" v-if="drilldownData">
          {{ drilldownData.transactions.length }} transaction{{ drilldownData.transactions.length === 1 ? '' : 's' }}
          <template v-if="drilldownData.start_date"> from {{ drilldownData.start_date }}</template>
          through {{ drilldownData.as_of_date }}
          &mdash; Ending Balance: <span class="font-mono font-semibold">{{ formatCurrency(drilldownData.ending_balance) }}</span>
        </p>

        <div v-if="drilldownLoading" class="flex justify-center py-12">
          <span class="loading loading-spinner loading-lg"></span>
        </div>

        <div v-else-if="drilldownData && drilldownData.transactions.length" class="overflow-x-auto">
          <table class="table table-sm table-pin-rows">
            <thead>
              <tr class="bg-base-200">
                <th>Date</th>
                <th>Memo</th>
                <th>Account</th>
                <th class="text-right">Debit</th>
                <th class="text-right">Credit</th>
                <th class="text-right">Balance</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(txn, idx) in drilldownData.transactions" :key="idx" class="hover">
                <td class="font-mono text-sm whitespace-nowrap">{{ txn.date }}</td>
                <td class="max-w-xs truncate">{{ txn.memo || '—' }}</td>
                <td class="text-sm text-base-content/70 max-w-xs truncate">{{ txn.other_accounts.join(', ') || '—' }}</td>
                <td class="text-right font-mono">{{ txn.debit > 0 ? formatCurrency(txn.debit) : '' }}</td>
                <td class="text-right font-mono">{{ txn.credit > 0 ? formatCurrency(txn.credit) : '' }}</td>
                <td class="text-right font-mono font-semibold">{{ formatCurrency(txn.running_balance) }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div v-else class="text-center py-12 text-base-content/50">
          No transactions found for this account in the selected period.
        </div>
      </div>
      <form method="dialog" class="modal-backdrop"><button>close</button></form>
    </dialog>

    <!-- Trial Balance -->
    <div v-if="activeTab === 'tb'" class="space-y-6">
      <div class="flex justify-between items-center">
        <div v-if="tbReport && tbReport.balanced" class="badge badge-success gap-1">✓ Balanced (Debits = Credits)</div>
        <div v-else class="badge badge-error gap-1">⚠ Unbalanced</div>
      </div>

      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <div class="overflow-x-auto">
            <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
              <thead>
                <tr class="bg-base-200">
                  <th>Code</th>
                  <th>Account</th>
                  <th>Type</th>
                  <th class="text-right">Debit</th>
                  <th class="text-right">Credit</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="acct in (tbReport && tbReport.accounts) || []" :key="acct.code" class="hover">
                  <td class="font-mono text-sm">{{ acct.code }}</td>
                  <td class="font-medium">{{ acct.name }}</td>
                  <td><span class="badge badge-xs badge-outline capitalize">{{ acct.account_type }}</span></td>
                  <td class="text-right font-mono">{{ acct.debit > 0 ? formatCurrency(acct.debit) : '' }}</td>
                  <td class="text-right font-mono">{{ acct.credit > 0 ? formatCurrency(acct.credit) : '' }}</td>
                </tr>
              </tbody>
              <tfoot>
                <tr class="font-bold border-t-2 bg-base-200">
                  <td colspan="3">Totals</td>
                  <td class="text-right font-mono">{{ formatCurrency(tbReport && tbReport.total_debits) }}</td>
                  <td class="text-right font-mono">{{ formatCurrency(tbReport && tbReport.total_credits) }}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      </div>
    </div>

    <!-- General Ledger -->
    <div v-if="activeTab === 'gl'" class="space-y-4">
      <div v-for="entry in (glReport && glReport.entries) || []" :key="entry.id" class="card bg-base-100 shadow">
        <div class="card-body py-4">
          <div class="flex justify-between items-center mb-2">
            <div>
              <span class="font-mono text-sm text-base-content/50">{{ entry.date }}</span>
              <span class="ml-2 font-medium">{{ entry.memo }}</span>
            </div>
            <span class="badge badge-xs badge-outline">{{ entry.source }}</span>
          </div>
          <table class="table table-sm sm:table-md table-sm sm:table-md table-xs">
            <thead>
              <tr>
                <th>Account</th>
                <th class="text-right">Debit</th>
                <th class="text-right">Credit</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(line, idx) in entry.lines" :key="idx">
                <td :class="line.debit > 0 ? '' : 'pl-8'">{{ line.account }}</td>
                <td class="text-right font-mono">{{ line.debit > 0 ? formatCurrency(line.debit) : '' }}</td>
                <td class="text-right font-mono">{{ line.credit > 0 ? formatCurrency(line.credit) : '' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-if="!glReport || !(glReport.entries || []).length" class="text-center py-12 text-base-content/50">
        No journal entries for this period. Categorize some transactions to see double-entry records.
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const activeTab = ref('pl')
const summary = ref(null)
const loading = ref(false)
const plReport = ref(null)
const bsReport = ref(null)
const tbReport = ref(null)
const glReport = ref(null)

const companyId = computed(() => appStore.activeCompany?.id || 1)
const selectedPeriod = ref('this_year')
const startDate = ref(new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0])
const endDate = ref(new Date().toISOString().split('T')[0])

const toISO = (d) => d.toISOString().split('T')[0]

const periodDates = (period) => {
  const now = new Date()
  const y = now.getFullYear()
  const m = now.getMonth()
  const q = Math.floor(m / 3)

  switch (period) {
    case 'this_month':
      return [new Date(y, m, 1), new Date(y, m + 1, 0)]
    case 'last_month':
      return [new Date(y, m - 1, 1), new Date(y, m, 0)]
    case 'this_quarter':
      return [new Date(y, q * 3, 1), new Date(y, q * 3 + 3, 0)]
    case 'last_quarter':
      return [new Date(y, (q - 1) * 3, 1), new Date(y, q * 3, 0)]
    case 'this_year':
      return [new Date(y, 0, 1), new Date(y, 11, 31)]
    case 'last_year':
      return [new Date(y - 1, 0, 1), new Date(y - 1, 11, 31)]
    case 'year_to_date':
      return [new Date(y, 0, 1), now]
    case 'last_12_months':
      return [new Date(y - 1, m + 1, 1), now]
    case 'all_time':
      return [new Date(2000, 0, 1), now]
    default:
      return [new Date(y, 0, 1), now]
  }
}

const applyPeriod = () => {
  if (selectedPeriod.value === 'custom') return
  const [s, e] = periodDates(selectedPeriod.value)
  startDate.value = toISO(s)
  endDate.value = toISO(e)
  refresh()
}

const formatDateRange = computed(() => {
  const opts = { month: 'short', day: 'numeric', year: 'numeric' }
  const s = new Date(startDate.value + 'T00:00:00')
  const e = new Date(endDate.value + 'T00:00:00')
  return `${s.toLocaleDateString('en-US', opts)} – ${e.toLocaleDateString('en-US', opts)}`
})

const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)

const plData = computed(() => {
  if (!plReport.value) return { income: [], expenses: [], totalIncome: 0, totalExpenses: 0 }
  const r = plReport.value
  return {
    income: Object.entries(r.income || {}).sort((a, b) => b[1] - a[1]),
    expenses: Object.entries(r.expenses || {}).sort((a, b) => b[1] - a[1]),
    totalIncome: r.total_income || 0,
    totalExpenses: r.total_expenses || 0
  }
})

const bsSections = computed(() => {
  if (!bsReport.value) return []
  const r = bsReport.value
  return [
    { title: 'Assets', color: 'text-success', items: r.assets || [], total: r.total_assets || 0 },
    { title: 'Liabilities', color: 'text-error', items: r.liabilities || [], total: r.total_liabilities || 0 },
    { title: 'Equity', color: 'text-primary', items: r.equity || [], total: r.total_equity || 0 }
  ]
})

// Drilldown state
const drilldownModal = ref(null)
const drilldownAccount = ref(null)
const drilldownData = ref(null)
const drilldownLoading = ref(false)

const openDrilldown = async (item) => {
  drilldownAccount.value = item
  drilldownData.value = null
  drilldownLoading.value = true
  drilldownModal.value?.showModal()

  const cid = companyId.value
  const params = new URLSearchParams({ chart_of_account_id: item.id, as_of_date: endDate.value })
  if (startDate.value) params.set('start_date', startDate.value)

  try {
    drilldownData.value = await apiClient.get(`/api/v1/companies/${cid}/reports/account_transactions?${params}`)
  } catch (e) {
    drilldownData.value = { transactions: [], ending_balance: 0, as_of_date: endDate.value, start_date: startDate.value }
  } finally {
    drilldownLoading.value = false
  }
}

const refresh = async () => {
  loading.value = true
  summary.value = null
  const cid = companyId.value
  
  if (activeTab.value === 'pl') {
    const data = await apiClient.get(`/api/v1/companies/${cid}/reports/profit_loss?start_date=${startDate.value}&end_date=${endDate.value}`)
    plReport.value = data
    summary.value = data?.ai_summary || null
  } else if (activeTab.value === 'bs') {
    const data = await apiClient.get(`/api/v1/companies/${cid}/reports/balance_sheet?as_of_date=${endDate.value}`)
    bsReport.value = data
    summary.value = data?.ai_summary || null
  } else if (activeTab.value === 'tb') {
    tbReport.value = await apiClient.get(`/api/v1/companies/${cid}/reports/trial_balance?as_of_date=${endDate.value}`)
  } else if (activeTab.value === 'gl') {
    glReport.value = await apiClient.get(`/api/v1/companies/${cid}/reports/general_ledger?start_date=${startDate.value}&end_date=${endDate.value}`)
  }
  loading.value = false
}

watch(activeTab, refresh)
onMounted(refresh)
</script>
