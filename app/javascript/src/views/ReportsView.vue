<template>
  <div class="min-h-screen bg-base-200">
    <!-- Header -->
    <div class="bg-primary text-primary-content py-8">
      <div class="container mx-auto px-4">
        <h1 class="text-4xl font-bold mb-2">Reports</h1>
        <p class="text-lg opacity-80">Financial statements and analysis</p>
      </div>
    </div>

    <div class="container mx-auto px-4 py-8">
      <!-- Report Type Selection -->
      <div class="flex gap-4 mb-8">
        <button 
          @click="currentReport = 'pnl'"
          :class="['btn', currentReport === 'pnl' ? 'btn-primary' : 'btn-outline']"
        >
          Profit & Loss
        </button>
        <button 
          @click="currentReport = 'balance'"
          :class="['btn', currentReport === 'balance' ? 'btn-primary' : 'btn-outline']"
        >
          Balance Sheet
        </button>
      </div>

      <!-- Date Range Selector -->
      <div class="card bg-base-100 shadow-xl mb-8">
        <div class="card-body">
          <h2 class="card-title mb-4">Date Range</h2>
          <div class="flex gap-4 items-end">
            <div class="form-control">
              <label class="label">
                <span class="label-text">Start Date</span>
              </label>
              <input 
                type="date" 
                v-model="startDate" 
                class="input input-bordered"
              />
            </div>
            <div class="form-control">
              <label class="label">
                <span class="label-text">End Date</span>
              </label>
              <input 
                type="date" 
                v-model="endDate" 
                class="input input-bordered"
              />
            </div>
            <button @click="fetchReport" class="btn btn-primary">
              Generate Report
            </button>
          </div>
        </div>
      </div>

      <!-- Profit & Loss Report -->
      <div v-if="currentReport === 'pnl' && reportData" class="space-y-6">
        <!-- Summary Cards -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="card bg-success text-success-content">
            <div class="card-body">
              <h3 class="text-lg font-semibold">Total Income</h3>
              <p class="text-3xl font-bold">{{ formatCurrency(reportData.income?.total) }}</p>
            </div>
          </div>
          <div class="card bg-error text-error-content">
            <div class="card-body">
              <h3 class="text-lg font-semibold">Total Expenses</h3>
              <p class="text-3xl font-bold">{{ formatCurrency(reportData.expenses?.total) }}</p>
            </div>
          </div>
          <div :class="['card', netIncome >= 0 ? 'bg-info text-info-content' : 'bg-warning text-warning-content']">
            <div class="card-body">
              <h3 class="text-lg font-semibold">Net Income</h3>
              <p class="text-3xl font-bold">{{ formatCurrency(netIncome) }}</p>
            </div>
          </div>
        </div>

        <!-- Income Section -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-success mb-4">Income</h2>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>Account</th>
                    <th class="text-right">Amount</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="account in reportData.income?.accounts" :key="account.id">
                    <td>{{ account.code }} - {{ account.name }}</td>
                    <td class="text-right font-mono">{{ formatCurrency(account.amount) }}</td>
                  </tr>
                  <tr class="font-bold bg-success/10">
                    <td>Total Income</td>
                    <td class="text-right font-mono">{{ formatCurrency(reportData.income?.total) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Expenses Section -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-error mb-4">Expenses</h2>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>Account</th>
                    <th class="text-right">Amount</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="account in reportData.expenses?.accounts" :key="account.id">
                    <td>{{ account.code }} - {{ account.name }}</td>
                    <td class="text-right font-mono">{{ formatCurrency(account.amount) }}</td>
                  </tr>
                  <tr class="font-bold bg-error/10">
                    <td>Total Expenses</td>
                    <td class="text-right font-mono">{{ formatCurrency(reportData.expenses?.total) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <!-- Balance Sheet Report -->
      <div v-if="currentReport === 'balance' && reportData" class="space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
          <div class="card bg-success text-success-content">
            <div class="card-body">
              <h3 class="text-lg font-semibold">Total Assets</h3>
              <p class="text-3xl font-bold">{{ formatCurrency(reportData.assets?.total) }}</p>
            </div>
          </div>
          <div class="card bg-error text-error-content">
            <div class="card-body">
              <h3 class="text-lg font-semibold">Total Liabilities & Equity</h3>
              <p class="text-3xl font-bold">{{ formatCurrency(reportData.total_liabilities_and_equity) }}</p>
            </div>
          </div>
        </div>

        <!-- Assets -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-success mb-4">Assets</h2>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <tbody>
                  <tr v-for="account in reportData.assets?.accounts" :key="account.id">
                    <td>{{ account.code }} - {{ account.name }}</td>
                    <td class="text-right font-mono">{{ formatCurrency(account.balance) }}</td>
                  </tr>
                  <tr class="font-bold bg-success/10">
                    <td>Total Assets</td>
                    <td class="text-right font-mono">{{ formatCurrency(reportData.assets?.total) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Liabilities -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-error mb-4">Liabilities</h2>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <tbody>
                  <tr v-for="account in reportData.liabilities?.accounts" :key="account.id">
                    <td>{{ account.code }} - {{ account.name }}</td>
                    <td class="text-right font-mono">{{ formatCurrency(account.balance) }}</td>
                  </tr>
                  <tr class="font-bold bg-error/10">
                    <td>Total Liabilities</td>
                    <td class="text-right font-mono">{{ formatCurrency(reportData.liabilities?.total) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Equity -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-info mb-4">Equity</h2>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <tbody>
                  <tr v-for="account in reportData.equity?.accounts" :key="account.id">
                    <td>{{ account.code }} - {{ account.name }}</td>
                    <td class="text-right font-mono">{{ formatCurrency(account.balance) }}</td>
                  </tr>
                  <tr>
                    <td>Retained Earnings</td>
                    <td class="text-right font-mono">{{ formatCurrency(reportData.equity?.retained_earnings) }}</td>
                  </tr>
                  <tr class="font-bold bg-info/10">
                    <td>Total Equity</td>
                    <td class="text-right font-mono">
                      {{ formatCurrency(reportData.equity?.total + reportData.equity?.retained_earnings) }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const currentReport = ref('pnl')
const startDate = ref(new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0])
const endDate = ref(new Date().toISOString().split('T')[0])
const reportData = ref(null)
const loading = ref(false)

const netIncome = computed(() => {
  if (!reportData.value) return 0
  return (reportData.value.income?.total || 0) - (reportData.value.expenses?.total || 0)
})

const formatCurrency = (amount) => {
  if (amount === null || amount === undefined) return '$0.00'
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(amount)
}

const fetchReport = async () => {
  loading.value = true
  try {
    const householdId = 1 // TODO: Get from store/context
    const endpoint = currentReport.value === 'pnl' 
      ? `/api/v1/households/${householdId}/reports/profit_loss`
      : `/api/v1/households/${householdId}/reports/balance_sheet`
    
    const params = new URLSearchParams()
    if (currentReport.value === 'pnl') {
      params.append('start_date', startDate.value)
      params.append('end_date', endDate.value)
    } else {
      params.append('as_of_date', endDate.value)
    }
    
    const response = await fetch(`${endpoint}?${params}`)
    reportData.value = await response.json()
  } catch (error) {
    console.error('Error fetching report:', error)
  } finally {
    loading.value = false
  }
}

// Load initial report
fetchReport()
</script>
