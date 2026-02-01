<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-3xl font-bold">Transactions</h1>
        <p class="text-base-content/60 mt-1">
          {{ pagination.total }} transactions
          <span v-if="selectedIds.size > 0" class="text-primary"> · {{ selectedIds.size }} selected</span>
        </p>
      </div>
      <div class="flex gap-2">
        <a :href="exportUrl" class="btn btn-outline btn-sm gap-1">📥 CSV</a>
        <button @click="showFilters = !showFilters" :class="['btn btn-sm', showFilters ? 'btn-primary' : 'btn-outline']">
          🔍 Filters
        </button>
      </div>
    </div>

    <!-- Filters -->
    <div v-if="showFilters" class="card bg-base-100 shadow mb-6">
      <div class="card-body py-4">
        <div class="grid grid-cols-2 md:grid-cols-6 gap-3">
          <div class="form-control">
            <label class="label label-text text-xs">From</label>
            <input type="date" v-model="filters.start_date" @change="fetchData" class="input input-bordered input-sm" />
          </div>
          <div class="form-control">
            <label class="label label-text text-xs">To</label>
            <input type="date" v-model="filters.end_date" @change="fetchData" class="input input-bordered input-sm" />
          </div>
          <div class="form-control">
            <label class="label label-text text-xs">Account</label>
            <select v-model="filters.account_id" @change="fetchData" class="select select-bordered select-sm">
              <option value="">All</option>
              <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.name }}</option>
            </select>
          </div>
          <div class="form-control">
            <label class="label label-text text-xs">Category</label>
            <select v-model="filters.chart_of_account_id" @change="fetchData" class="select select-bordered select-sm">
              <option value="">All</option>
              <option value="uncategorized">Uncategorized</option>
              <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
          </div>
          <div class="form-control col-span-2">
            <label class="label label-text text-xs">Search</label>
            <input type="text" v-model="filters.search" @input="debouncedFetch" 
              placeholder="Description or merchant..." class="input input-bordered input-sm" />
          </div>
        </div>
      </div>
    </div>

    <!-- Bulk Actions Bar -->
    <div v-if="selectedIds.size > 0" class="bg-primary/10 rounded-lg p-3 mb-4 flex items-center gap-4">
      <span class="font-medium">{{ selectedIds.size }} selected</span>
      <select v-model="bulkCategory" class="select select-bordered select-sm">
        <option value="">Categorize as...</option>
        <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
      </select>
      <button v-if="bulkCategory" @click="bulkCategorize" class="btn btn-primary btn-sm">Apply</button>
      <button @click="selectedIds.clear()" class="btn btn-ghost btn-sm">Clear</button>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
      <div class="stat bg-base-100 rounded-box shadow py-3">
        <div class="stat-title text-xs">Showing</div>
        <div class="stat-value text-lg">{{ transactions.length }} of {{ pagination.total }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow py-3">
        <div class="stat-title text-xs">Money In</div>
        <div class="stat-value text-lg text-success">{{ formatCurrency(summaryIn) }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow py-3">
        <div class="stat-title text-xs">Money Out</div>
        <div class="stat-value text-lg text-error">{{ formatCurrency(summaryOut) }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow py-3">
        <div class="stat-title text-xs">Net</div>
        <div :class="['stat-value text-lg', summaryNet >= 0 ? 'text-success' : 'text-error']">
          {{ formatCurrency(summaryNet) }}
        </div>
      </div>
    </div>

    <!-- Transactions Table -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body p-0">
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr class="bg-base-200">
                <th><input type="checkbox" class="checkbox checkbox-sm" @change="toggleAll" :checked="allSelected" /></th>
                <th class="cursor-pointer" @click="toggleSort('date')">
                  Date {{ sortIcon('date') }}
                </th>
                <th>Description</th>
                <th>Account</th>
                <th>Category</th>
                <th class="text-right cursor-pointer" @click="toggleSort('amount')">
                  Amount {{ sortIcon('amount') }}
                </th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="txn in transactions" :key="txn.id" 
                :class="['hover', selectedIds.has(txn.id) ? 'bg-primary/5' : '']">
                <td><input type="checkbox" class="checkbox checkbox-sm" :checked="selectedIds.has(txn.id)" @change="toggleSelect(txn.id)" /></td>
                <td class="font-mono text-sm whitespace-nowrap">{{ formatDate(txn.date) }}</td>
                <td>
                  <div class="font-medium">{{ txn.description }}</div>
                  <div v-if="txn.merchant_name && txn.merchant_name !== txn.description" class="text-xs text-base-content/40">{{ txn.merchant_name }}</div>
                </td>
                <td class="text-sm text-base-content/60 whitespace-nowrap">{{ txn.account_name }}</td>
                <td>
                  <!-- Inline category selector -->
                  <select v-if="!txn.categorized" 
                    @change="categorizeOne(txn.id, $event.target.value)"
                    class="select select-bordered select-xs w-40 bg-warning/10">
                    <option value="">⚠️ Uncategorized</option>
                    <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
                  </select>
                  <span v-else class="badge badge-sm badge-outline">{{ txn.chart_of_account_name }}</span>
                </td>
                <td :class="['text-right font-mono whitespace-nowrap', txn.amount >= 0 ? 'text-success' : 'text-error']">
                  {{ formatCurrency(txn.amount) }}
                </td>
                <td>
                  <span :class="['badge badge-xs', txn.pending ? 'badge-warning' : 'badge-ghost']">
                    {{ txn.pending ? 'Pending' : '✓' }}
                  </span>
                </td>
              </tr>
              <tr v-if="transactions.length === 0 && !loading">
                <td colspan="7" class="text-center py-12 text-base-content/50">
                  No transactions found. Try adjusting your filters.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="flex justify-center py-8">
          <span class="loading loading-spinner loading-lg"></span>
        </div>

        <!-- Pagination -->
        <div v-if="pagination.total_pages > 1" class="flex justify-between items-center p-4 border-t border-base-300">
          <span class="text-sm text-base-content/60">
            Page {{ pagination.page }} of {{ pagination.total_pages }}
          </span>
          <div class="join">
            <button @click="goPage(1)" :disabled="pagination.page <= 1" class="join-item btn btn-sm">«</button>
            <button @click="goPage(pagination.page - 1)" :disabled="pagination.page <= 1" class="join-item btn btn-sm">‹</button>
            <button v-for="p in visiblePages" :key="p" @click="goPage(p)"
              :class="['join-item btn btn-sm', p === pagination.page ? 'btn-active' : '']">
              {{ p }}
            </button>
            <button @click="goPage(pagination.page + 1)" :disabled="pagination.page >= pagination.total_pages" class="join-item btn btn-sm">›</button>
            <button @click="goPage(pagination.total_pages)" :disabled="pagination.page >= pagination.total_pages" class="join-item btn btn-sm">»</button>
          </div>
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
const transactions = ref([])
const accounts = ref([])
const categories = ref([])
const loading = ref(false)
const showFilters = ref(true)
const selectedIds = ref(new Set())
const bulkCategory = ref('')
const pagination = ref({ page: 1, per_page: 50, total: 0, total_pages: 1 })
const sortField = ref('date')
const sortDir = ref('desc')

const companyId = () => appStore.currentCompany?.id || 1

const filters = ref({
  start_date: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0],
  end_date: new Date().toISOString().split('T')[0],
  account_id: '',
  chart_of_account_id: '',
  search: ''
})

const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)
const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: '2-digit' }) : ''

const summaryIn = computed(() => transactions.value.filter(t => t.amount >= 0).reduce((s, t) => s + t.amount, 0))
const summaryOut = computed(() => transactions.value.filter(t => t.amount < 0).reduce((s, t) => s + Math.abs(t.amount), 0))
const summaryNet = computed(() => summaryIn.value - summaryOut.value)

const allSelected = computed(() => transactions.value.length > 0 && transactions.value.every(t => selectedIds.value.has(t.id)))

const exportUrl = computed(() => {
  const cid = companyId()
  return `/api/v1/companies/${cid}/exports/transactions?start_date=${filters.value.start_date}&end_date=${filters.value.end_date}`
})

const visiblePages = computed(() => {
  const current = pagination.value.page
  const total = pagination.value.total_pages
  const pages = []
  for (let i = Math.max(1, current - 2); i <= Math.min(total, current + 2); i++) {
    pages.push(i)
  }
  return pages
})

const sortIcon = (field) => {
  if (sortField.value !== field) return '↕'
  return sortDir.value === 'asc' ? '↑' : '↓'
}

const toggleSort = (field) => {
  if (sortField.value === field) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortField.value = field
    sortDir.value = 'desc'
  }
  fetchData()
}

const toggleSelect = (id) => {
  const s = new Set(selectedIds.value)
  s.has(id) ? s.delete(id) : s.add(id)
  selectedIds.value = s
}

const toggleAll = () => {
  if (allSelected.value) {
    selectedIds.value = new Set()
  } else {
    selectedIds.value = new Set(transactions.value.map(t => t.id))
  }
}

let debounceTimer = null
const debouncedFetch = () => {
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(fetchData, 300)
}

const fetchData = async (page = 1) => {
  loading.value = true
  const cid = companyId()
  const params = new URLSearchParams({
    page: page,
    per_page: pagination.value.per_page,
    start_date: filters.value.start_date,
    end_date: filters.value.end_date
  })
  if (filters.value.account_id) params.set('account_id', filters.value.account_id)
  if (filters.value.chart_of_account_id === 'uncategorized') {
    params.set('uncategorized', 'true')
  } else if (filters.value.chart_of_account_id) {
    params.set('chart_of_account_id', filters.value.chart_of_account_id)
  }
  if (filters.value.search) params.set('search', filters.value.search)

  try {
    const data = await apiClient.get(`/api/v1/companies/${cid}/transactions?${params}`)
    transactions.value = data?.transactions || []
    pagination.value = data?.pagination || pagination.value
  } finally {
    loading.value = false
  }
}

const goPage = (p) => {
  if (p >= 1 && p <= pagination.value.total_pages) fetchData(p)
}

const categorizeOne = async (txnId, chartOfAccountId) => {
  if (!chartOfAccountId) return
  const cid = companyId()
  await apiClient.put(`/api/v1/companies/${cid}/transactions/${txnId}`, {
    transaction: { chart_of_account_id: chartOfAccountId }
  })
  await fetchData(pagination.value.page)
}

const bulkCategorize = async () => {
  if (!bulkCategory.value || selectedIds.value.size === 0) return
  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/categorize`, {
    transaction_ids: [...selectedIds.value],
    chart_of_account_id: bulkCategory.value
  })
  selectedIds.value = new Set()
  bulkCategory.value = ''
  await fetchData(pagination.value.page)
}

onMounted(async () => {
  const cid = companyId()
  const [, accts, cats] = await Promise.all([
    fetchData(),
    apiClient.get(`/api/v1/companies/${cid}/accounts`),
    apiClient.get(`/api/v1/companies/${cid}/chart_of_accounts`)
  ])
  accounts.value = accts || []
  categories.value = cats || []
})
</script>
