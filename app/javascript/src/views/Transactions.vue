<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Transactions</h1>
        <p class="text-base-content/60 mt-1">
          {{ pagination.total }} transactions
          <span v-if="selectedIds.size > 0" class="text-primary"> · {{ selectedIds.size }} selected</span>
        </p>
      </div>
      <div class="flex gap-2">
        <a :href="exportUrl" class="btn btn-outline btn-sm gap-1">Export CSV</a>
        <button @click="showFilters = !showFilters" :class="['btn btn-sm', showFilters ? 'btn-primary' : 'btn-outline']">
          Filters
        </button>
      </div>
    </div>

    <!-- Account Cards -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 mb-6">
      <div
        v-for="account in accountsSummary"
        :key="account.id"
        @click="selectAccount(account.id)"
        :class="[
          'card bg-base-100 shadow cursor-pointer transition-all hover:shadow-lg',
          filters.account_id === account.id ? 'ring-2 ring-primary' : ''
        ]"
      >
        <div class="card-body p-4">
          <div class="flex justify-between items-start">
            <div>
              <h3 class="font-semibold text-sm">{{ account.name }}</h3>
              <p class="text-xs text-base-content/50">{{ account.account_type }} {{ account.mask ? `••${account.mask}` : '' }}</p>
            </div>
            <div v-if="account.pending_count > 0" class="badge badge-warning badge-sm">{{ account.pending_count }}</div>
          </div>
          <div class="mt-2">
            <div class="text-2xl font-bold">{{ formatCurrency(account.current_balance) }}</div>
            <div v-if="account.available_balance !== account.current_balance" class="text-xs text-base-content/50">
              Available: {{ formatCurrency(account.available_balance) }}
            </div>
          </div>
          <div class="card-actions justify-end mt-2">
            <router-link
              :to="`/reconciliation?account_id=${account.id}`"
              @click.stop
              class="btn btn-ghost btn-xs"
            >
              Reconcile
            </router-link>
          </div>
        </div>
      </div>
      <!-- All Accounts card -->
      <div
        @click="selectAccount('')"
        :class="[
          'card bg-base-100 shadow cursor-pointer transition-all hover:shadow-lg',
          !filters.account_id ? 'ring-2 ring-primary' : ''
        ]"
      >
        <div class="card-body p-4 flex flex-col justify-center items-center">
          <div class="text-4xl mb-2">All</div>
          <p class="text-sm text-base-content/60">View all accounts</p>
          <div class="mt-2 text-xs">
            <span class="badge badge-warning badge-sm mr-1">{{ totalPending }}</span> pending
          </div>
        </div>
      </div>
    </div>

    <!-- Ledger Status Tabs -->
    <div class="tabs tabs-boxed mb-4 bg-base-200">
      <a
        :class="['tab', filters.ledger_status === 'pending' && 'tab-active']"
        @click="setLedgerStatus('pending')"
      >
        Pending
        <span v-if="statusCounts.pending > 0" class="badge badge-warning badge-sm ml-2">{{ statusCounts.pending }}</span>
      </a>
      <a
        :class="['tab', filters.ledger_status === 'posted' && 'tab-active']"
        @click="setLedgerStatus('posted')"
      >
        Posted
        <span v-if="statusCounts.posted > 0" class="badge badge-ghost badge-sm ml-2">{{ statusCounts.posted }}</span>
      </a>
      <a
        :class="['tab', filters.ledger_status === 'excluded' && 'tab-active']"
        @click="setLedgerStatus('excluded')"
      >
        Excluded
        <span v-if="statusCounts.excluded > 0" class="badge badge-ghost badge-sm ml-2">{{ statusCounts.excluded }}</span>
      </a>
    </div>

    <!-- Filters -->
    <div v-if="showFilters" class="card bg-base-100 shadow mb-6">
      <div class="card-body py-4">
        <div class="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div class="form-control">
            <label class="label label-text text-xs">From</label>
            <input type="date" v-model="filters.start_date" @change="fetchData" class="input input-bordered input-sm" />
          </div>
          <div class="form-control">
            <label class="label label-text text-xs">To</label>
            <input type="date" v-model="filters.end_date" @change="fetchData" class="input input-bordered input-sm" />
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
    <div v-if="selectedIds.size > 0" class="bg-primary/10 rounded-lg p-3 mb-4 flex flex-wrap items-center gap-3">
      <span class="font-medium">{{ selectedIds.size }} selected</span>

      <!-- Categorize -->
      <select v-model="bulkCategory" class="select select-bordered select-sm">
        <option value="">Categorize as...</option>
        <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
      </select>
      <button v-if="bulkCategory" @click="bulkCategorize" class="btn btn-sm btn-outline">Apply Category</button>

      <!-- Post / Exclude buttons based on current tab -->
      <template v-if="filters.ledger_status === 'pending'">
        <button @click="bulkPost" class="btn btn-primary btn-sm">Post Selected</button>
        <button @click="bulkExclude" class="btn btn-ghost btn-sm">Exclude Selected</button>
      </template>
      <template v-else-if="filters.ledger_status === 'posted' || filters.ledger_status === 'excluded'">
        <button @click="bulkUnpost" class="btn btn-outline btn-sm">Move to Pending</button>
      </template>

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
                <th>Actions</th>
                <th v-if="canSeeComments" class="w-10"></th>
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
                  <select
                    :value="txn.chart_of_account_id || ''"
                    @change="categorizeOne(txn.id, $event.target.value)"
                    :class="['select select-bordered select-xs w-40', txn.categorized ? '' : 'bg-warning/10']">
                    <option value="">{{ txn.categorized ? '-- Remove --' : 'Uncategorized' }}</option>
                    <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
                  </select>
                </td>
                <td :class="['text-right font-mono whitespace-nowrap', txn.amount >= 0 ? 'text-success' : 'text-error']">
                  {{ formatCurrency(txn.amount) }}
                </td>
                <td>
                  <div class="flex gap-1">
                    <!-- Pending: show Post/Exclude -->
                    <template v-if="txn.ledger_status === 'pending'">
                      <button
                        @click="postOne(txn.id)"
                        :disabled="!txn.categorized"
                        :title="txn.categorized ? 'Post to ledger' : 'Categorize first'"
                        class="btn btn-xs btn-primary"
                      >Post</button>
                      <button @click="excludeOne(txn.id)" title="Exclude" class="btn btn-xs btn-ghost">Exclude</button>
                    </template>
                    <!-- Posted: show Unpost -->
                    <template v-else-if="txn.ledger_status === 'posted'">
                      <span class="badge badge-success badge-sm mr-1">Posted</span>
                      <button @click="unpostOne(txn.id)" class="btn btn-xs btn-ghost">Unpost</button>
                    </template>
                    <!-- Excluded: show Restore -->
                    <template v-else-if="txn.ledger_status === 'excluded'">
                      <span class="badge badge-ghost badge-sm mr-1">Excluded</span>
                      <button @click="unpostOne(txn.id)" class="btn btn-xs btn-ghost">Restore</button>
                    </template>
                  </div>
                </td>
                <td v-if="canSeeComments">
                  <button @click.stop="openCommentPanel(txn)"
                    :class="['btn btn-ghost btn-xs', commentTxnId === txn.id ? 'btn-active' : '']"
                    :title="'Comments'">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
                    </svg>
                    <span v-if="txn.comment_count" class="text-xs">{{ txn.comment_count }}</span>
                  </button>
                </td>
              </tr>
              <tr v-if="transactions.length === 0 && !loading">
                <td colspan="9" class="text-center py-12 text-base-content/50">
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

    <!-- Transaction Comment Panel -->
    <dialog :class="['modal modal-bottom sm:modal-middle', commentTxnId ? 'modal-open' : '']">
      <div class="modal-box max-w-lg w-full sm:w-auto">
        <div class="flex justify-between items-center mb-4">
          <div>
            <h3 class="font-bold text-lg">Transaction Comments</h3>
            <p v-if="commentTxn" class="text-sm text-base-content/50 mt-0.5">
              {{ commentTxn.description }} · {{ formatCurrency(commentTxn.amount) }} · {{ formatDate(commentTxn.date) }}
            </p>
          </div>
          <button @click="closeCommentPanel" class="btn btn-ghost btn-sm btn-circle">X</button>
        </div>
        <CommentThread
          v-if="commentTxnId"
          ref="txnCommentThread"
          commentable-type="transaction"
          :commentable-id="commentTxnId"
          :show-header="false"
          placeholder="Add a comment about this transaction..."
          @count-changed="onTxnCommentCount"
        />
      </div>
      <form method="dialog" class="modal-backdrop" @click="closeCommentPanel"><button>close</button></form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { useAuthStore } from '../stores/auth'
import { apiClient } from '../api/client'
import CommentThread from '../components/CommentThread.vue'

const appStore = useAppStore()
const authStore = useAuthStore()

const canSeeComments = computed(() => {
  const role = authStore.user?.role
  return ['executive', 'manager', 'advisor'].includes(role)
    || authStore.isAdmin
    || authStore.user?.is_bookkeeper
})

const transactions = ref([])
const accounts = ref([])
const accountsSummary = ref([])
const categories = ref([])
const loading = ref(false)
const showFilters = ref(false)
const selectedIds = ref(new Set())
const bulkCategory = ref('')
const pagination = ref({ page: 1, per_page: 50, total: 0, total_pages: 1 })
const sortField = ref('date')
const sortDir = ref('desc')
const commentTxnId = ref(null)
const commentTxn = ref(null)
const txnCommentThread = ref(null)
const statusCounts = ref({ pending: 0, posted: 0, excluded: 0 })

const companyId = () => appStore.activeCompany?.id || 1

const filters = ref({
  start_date: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0],
  end_date: new Date().toISOString().split('T')[0],
  account_id: '',
  chart_of_account_id: '',
  ledger_status: 'pending',
  search: ''
})

const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)
const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: '2-digit' }) : ''

const summaryIn = computed(() => transactions.value.filter(t => t.amount >= 0).reduce((s, t) => s + t.amount, 0))
const summaryOut = computed(() => transactions.value.filter(t => t.amount < 0).reduce((s, t) => s + Math.abs(t.amount), 0))
const summaryNet = computed(() => summaryIn.value - summaryOut.value)

const totalPending = computed(() => accountsSummary.value.reduce((s, a) => s + a.pending_count, 0))

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
  if (sortField.value !== field) return ''
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

const selectAccount = (accountId) => {
  filters.value.account_id = accountId
  fetchData()
  fetchStatusCounts()
}

const setLedgerStatus = (status) => {
  filters.value.ledger_status = status
  selectedIds.value = new Set()
  fetchData()
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
    end_date: filters.value.end_date,
    ledger_status: filters.value.ledger_status
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

const fetchStatusCounts = async () => {
  const cid = companyId()
  const params = filters.value.account_id ? `?account_id=${filters.value.account_id}` : ''
  const data = await apiClient.get(`/api/v1/companies/${cid}/transactions/status_counts${params}`)
  statusCounts.value = data || { pending: 0, posted: 0, excluded: 0 }
}

const fetchAccountsSummary = async () => {
  const cid = companyId()
  const data = await apiClient.get(`/api/v1/companies/${cid}/transactions/accounts_summary`)
  accountsSummary.value = data?.accounts || []
}

const goPage = (p) => {
  if (p >= 1 && p <= pagination.value.total_pages) fetchData(p)
}

const categorizeOne = async (txnId, chartOfAccountId) => {
  const cid = companyId()
  await apiClient.put(`/api/v1/companies/${cid}/transactions/${txnId}`, {
    transaction: { chart_of_account_id: chartOfAccountId || null }
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

// Post / Exclude / Unpost actions
const postOne = async (txnId) => {
  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/${txnId}/post_transaction`)
  await refresh()
}

const excludeOne = async (txnId) => {
  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/${txnId}/exclude`)
  await refresh()
}

const unpostOne = async (txnId) => {
  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/${txnId}/unpost`)
  await refresh()
}

const bulkPost = async () => {
  if (selectedIds.value.size === 0) return
  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/bulk_post`, {
    transaction_ids: [...selectedIds.value]
  })
  selectedIds.value = new Set()
  await refresh()
}

const bulkExclude = async () => {
  if (selectedIds.value.size === 0) return
  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/bulk_exclude`, {
    transaction_ids: [...selectedIds.value]
  })
  selectedIds.value = new Set()
  await refresh()
}

const bulkUnpost = async () => {
  // Move selected back to pending
  for (const id of selectedIds.value) {
    await unpostOne(id)
  }
  selectedIds.value = new Set()
}

const refresh = async () => {
  await Promise.all([
    fetchData(pagination.value.page),
    fetchStatusCounts(),
    fetchAccountsSummary()
  ])
}

// Comment panel
const openCommentPanel = (txn) => {
  commentTxn.value = txn
  commentTxnId.value = txn.id
}

const closeCommentPanel = () => {
  commentTxnId.value = null
  commentTxn.value = null
}

const onTxnCommentCount = (count) => {
  if (commentTxn.value) {
    const txn = transactions.value.find(t => t.id === commentTxn.value.id)
    if (txn) txn.comment_count = count
  }
}

// Watch for company change
watch(() => appStore.activeCompany, () => {
  refresh()
  apiClient.get(`/api/v1/companies/${companyId()}/accounts`).then(data => accounts.value = data || [])
  apiClient.get(`/api/v1/companies/${companyId()}/chart_of_accounts`).then(data => categories.value = data || [])
})

onMounted(async () => {
  const cid = companyId()
  const [, accts, cats] = await Promise.all([
    refresh(),
    apiClient.get(`/api/v1/companies/${cid}/accounts`),
    apiClient.get(`/api/v1/companies/${cid}/chart_of_accounts`)
  ])
  accounts.value = accts || []
  categories.value = cats || []
})
</script>
