<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-xl sm:text-3xl font-bold">Reports</h1>
      <div class="flex items-center gap-3">
        <input type="date" v-model="startDate" @change="refresh" class="input input-bordered input-sm" />
        <span class="text-base-content/40">to</span>
        <input type="date" v-model="endDate" @change="refresh" class="input input-bordered input-sm" />
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
        <div v-if="bsReport?.balanced" class="badge badge-success gap-1">✓ Balanced</div>
        <div v-else class="badge badge-error gap-1">⚠ Unbalanced</div>
        <a :href="`/api/v1/companies/${companyId}/exports/balance_sheet?as_of_date=${endDate}`" 
          class="btn btn-outline btn-sm gap-1">📥 Export CSV</a>
      </div>

      <div v-for="section in bsSections" :key="section.title" class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 :class="['card-title', section.color]">{{ section.title }}</h2>
          <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
            <tbody>
              <tr v-for="[name, amount] in section.items" :key="name">
                <td>{{ name }}</td>
                <td class="text-right font-mono">{{ formatCurrency(amount) }}</td>
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

    <!-- Trial Balance -->
    <div v-if="activeTab === 'tb'" class="space-y-6">
      <div class="flex justify-between items-center">
        <div v-if="tbReport?.balanced" class="badge badge-success gap-1">✓ Balanced (Debits = Credits)</div>
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
                <tr v-for="acct in tbReport?.accounts" :key="acct.code" class="hover">
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
                  <td class="text-right font-mono">{{ formatCurrency(tbReport?.total_debits) }}</td>
                  <td class="text-right font-mono">{{ formatCurrency(tbReport?.total_credits) }}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      </div>
    </div>

    <!-- General Ledger -->
    <div v-if="activeTab === 'gl'" class="space-y-4">
      <div v-for="entry in glReport?.entries" :key="entry.id" class="card bg-base-100 shadow">
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

      <div v-if="!glReport?.entries?.length" class="text-center py-12 text-base-content/50">
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

const companyId = computed(() => appStore.currentCompany?.id || 1)
const startDate = ref(new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0])
const endDate = ref(new Date().toISOString().split('T')[0])

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
    { title: 'Assets', color: 'text-success', items: Object.entries(r.assets || {}), total: r.total_assets || 0 },
    { title: 'Liabilities', color: 'text-error', items: Object.entries(r.liabilities || {}), total: r.total_liabilities || 0 },
    { title: 'Equity', color: 'text-primary', items: Object.entries(r.equity || {}), total: r.total_equity || 0 }
  ]
})

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
