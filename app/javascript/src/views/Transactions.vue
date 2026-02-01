<template>
  <div>
    <div class="flex justify-between items-center mb-8">
      <div>
        <h1 class="text-3xl font-bold">Transactions</h1>
        <p class="text-base-content/60 mt-1">View and categorize financial transactions</p>
      </div>
      <div class="flex gap-2">
        <button @click="showFilters = !showFilters" class="btn btn-outline gap-2">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
          </svg>
          Filters
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div v-if="showFilters" class="card bg-base-100 shadow-xl mb-6">
      <div class="card-body">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div class="form-control">
            <label class="label"><span class="label-text">Start Date</span></label>
            <input type="date" v-model="filters.startDate" class="input input-bordered input-sm" />
          </div>
          <div class="form-control">
            <label class="label"><span class="label-text">End Date</span></label>
            <input type="date" v-model="filters.endDate" class="input input-bordered input-sm" />
          </div>
          <div class="form-control">
            <label class="label"><span class="label-text">Account</span></label>
            <select v-model="filters.accountId" class="select select-bordered select-sm">
              <option value="">All Accounts</option>
              <option v-for="coa in appStore.chartOfAccounts" :key="coa.id" :value="coa.id">
                {{ coa.code }} - {{ coa.name }}
              </option>
            </select>
          </div>
          <div class="form-control">
            <label class="label"><span class="label-text">Search</span></label>
            <input type="text" v-model="filters.search" placeholder="Search description..." class="input input-bordered input-sm" />
          </div>
        </div>
        <div class="flex justify-end mt-4">
          <button @click="applyFilters" class="btn btn-primary btn-sm">Apply</button>
        </div>
      </div>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-title">Total Transactions</div>
        <div class="stat-value text-sm">{{ filteredTransactions.length }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-title">Total Debits</div>
        <div class="stat-value text-error text-sm">{{ formatCurrency(totalDebits) }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-title">Total Credits</div>
        <div class="stat-value text-success text-sm">{{ formatCurrency(totalCredits) }}</div>
      </div>
    </div>

    <!-- Transactions Table -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <div class="overflow-x-auto">
          <table class="table table-zebra table-sm">
            <thead>
              <tr>
                <th @click="sortBy('date')" class="cursor-pointer hover:bg-base-200">Date ↕</th>
                <th>Description</th>
                <th>Account</th>
                <th @click="sortBy('amount')" class="cursor-pointer hover:bg-base-200 text-right">Amount ↕</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="txn in sortedTransactions" :key="txn.id">
                <td class="font-mono text-sm">{{ formatDate(txn.date) }}</td>
                <td>{{ txn.description }}</td>
                <td>
                  <span class="badge badge-sm badge-outline">
                    {{ txn.chart_of_account?.name || 'Uncategorized' }}
                  </span>
                </td>
                <td :class="['text-right font-mono', txn.amount >= 0 ? 'text-success' : 'text-error']">
                  {{ formatCurrency(txn.amount) }}
                </td>
                <td>
                  <span :class="['badge badge-sm', txn.pending ? 'badge-warning' : 'badge-success']">
                    {{ txn.pending ? 'Pending' : 'Cleared' }}
                  </span>
                </td>
              </tr>
              <tr v-if="filteredTransactions.length === 0">
                <td colspan="5" class="text-center py-8 text-base-content/50">
                  No transactions found for the selected filters.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Pagination -->
        <div class="flex justify-center mt-6">
          <div class="join">
            <button 
              v-for="page in totalPages" 
              :key="page"
              @click="currentPage = page"
              :class="['join-item btn btn-sm', currentPage === page ? 'btn-active' : '']"
            >
              {{ page }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'

const appStore = useAppStore()
const showFilters = ref(true)
const currentPage = ref(1)
const perPage = 50
const sortField = ref('date')
const sortDir = ref('desc')

const filters = ref({
  startDate: appStore.dateRange.start,
  endDate: appStore.dateRange.end,
  accountId: '',
  search: ''
})

const filteredTransactions = computed(() => {
  let txns = [...appStore.transactions]
  if (filters.value.accountId) {
    txns = txns.filter(t => t.chart_of_account_id == filters.value.accountId)
  }
  if (filters.value.search) {
    const s = filters.value.search.toLowerCase()
    txns = txns.filter(t => t.description?.toLowerCase().includes(s))
  }
  return txns
})

const sortedTransactions = computed(() => {
  const txns = [...filteredTransactions.value]
  txns.sort((a, b) => {
    const aVal = a[sortField.value]
    const bVal = b[sortField.value]
    const dir = sortDir.value === 'asc' ? 1 : -1
    if (aVal < bVal) return -1 * dir
    if (aVal > bVal) return 1 * dir
    return 0
  })
  const start = (currentPage.value - 1) * perPage
  return txns.slice(start, start + perPage)
})

const totalPages = computed(() => Math.ceil(filteredTransactions.value.length / perPage) || 1)

const totalDebits = computed(() => 
  filteredTransactions.value.filter(t => t.amount < 0).reduce((sum, t) => sum + Math.abs(t.amount), 0)
)

const totalCredits = computed(() => 
  filteredTransactions.value.filter(t => t.amount >= 0).reduce((sum, t) => sum + t.amount, 0)
)

const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount || 0)
}

const formatDate = (date) => {
  if (!date) return ''
  return new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

const sortBy = (field) => {
  if (sortField.value === field) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortField.value = field
    sortDir.value = 'desc'
  }
}

const applyFilters = async () => {
  const companyId = appStore.currentCompany?.id || 1
  await appStore.fetchTransactions(companyId, filters.value.startDate, filters.value.endDate)
}

onMounted(async () => {
  const companyId = appStore.currentCompany?.id || 1
  await appStore.fetchTransactions(companyId, filters.value.startDate, filters.value.endDate)
  await appStore.fetchChartOfAccounts(companyId)
})
</script>
