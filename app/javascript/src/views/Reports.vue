<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-3xl font-bold">Reports</h1>
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
      <!-- Export -->
      <div class="flex justify-end">
        <a :href="`/api/v1/companies/${companyId}/exports/profit_loss?start_date=${startDate}&end_date=${endDate}`" 
          class="btn btn-outline btn-sm gap-1">📥 Export CSV</a>
      </div>

      <!-- Income Section -->
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-success">Income</h2>
          <table class="table table-sm">
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

      <!-- Expenses Section -->
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-error">Expenses</h2>
          <table class="table table-sm">
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

      <!-- Net Income -->
      <div class="card bg-primary text-primary-content shadow-xl">
        <div class="card-body flex-row justify-between items-center">
          <h2 class="card-title">Net Income</h2>
          <span class="text-3xl font-bold font-mono">{{ formatCurrency(plData.totalIncome - plData.totalExpenses) }}</span>
        </div>
      </div>
    </div>

    <!-- Balance Sheet -->
    <div v-if="activeTab === 'bs'" class="space-y-6">
      <div class="flex justify-end">
        <a :href="`/api/v1/companies/${companyId}/exports/balance_sheet?as_of_date=${endDate}`" 
          class="btn btn-outline btn-sm gap-1">📥 Export CSV</a>
      </div>

      <div v-for="section in bsSections" :key="section.title" class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 :class="['card-title', section.color]">{{ section.title }}</h2>
          <table class="table table-sm">
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
  } else {
    const data = await apiClient.get(`/api/v1/companies/${cid}/reports/balance_sheet?as_of_date=${endDate.value}`)
    bsReport.value = data
    summary.value = data?.ai_summary || null
  }
  loading.value = false
}

watch(activeTab, refresh)

onMounted(refresh)
</script>
