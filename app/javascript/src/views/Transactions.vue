<template>
  <div>
    <!-- Header -->
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Transactions</h1>
        <p class="text-base-content/60 mt-1">Review and categorize imported transactions</p>
      </div>
      <div class="flex gap-2">
        <a :href="exportUrl" class="btn btn-outline btn-sm">Export CSV</a>
      </div>
    </div>

    <!-- Ledger Status Tabs -->
    <div class="tabs tabs-boxed mb-6 bg-base-200 inline-flex">
      <a
        :class="['tab', filters.ledger_status === 'pending' && 'tab-active']"
        @click="setLedgerStatus('pending')"
      >
        For Review
        <span v-if="globalCounts.pending > 0" class="badge badge-warning badge-sm ml-2">{{ globalCounts.pending }}</span>
      </a>
      <a
        :class="['tab', filters.ledger_status === 'posted' && 'tab-active']"
        @click="setLedgerStatus('posted')"
      >
        In Books
        <span v-if="globalCounts.posted > 0" class="badge badge-ghost badge-sm ml-2">{{ globalCounts.posted }}</span>
      </a>
      <a
        :class="['tab', filters.ledger_status === 'excluded' && 'tab-active']"
        @click="setLedgerStatus('excluded')"
      >
        Excluded
        <span v-if="globalCounts.excluded > 0" class="badge badge-ghost badge-sm ml-2">{{ globalCounts.excluded }}</span>
      </a>
    </div>

    <!-- Loading -->
    <div v-if="loading && accountsSummary.length === 0" class="flex justify-center py-12">
      <span class="loading loading-spinner loading-lg"></span>
    </div>

    <!-- No Accounts Message -->
    <div v-else-if="accountsSummary.length === 0" class="card bg-base-100 shadow-xl">
      <div class="card-body text-center py-12">
        <p class="text-base-content/50">No accounts found. Link a bank account or import statements to get started.</p>
      </div>
    </div>

    <!-- Account Cards with Transaction Tables -->
    <div v-else class="space-y-4">
      <div
        v-for="account in filteredAccounts"
        :key="account.id"
        class="card bg-base-100 shadow-xl"
      >
        <!-- Account Header (clickable to expand/collapse) -->
        <div
          @click="toggleAccount(account.id)"
          class="card-body p-4 cursor-pointer hover:bg-base-50 transition-colors"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-4">
              <!-- Expand/Collapse Icon -->
              <svg
                :class="['w-5 h-5 transition-transform', expandedAccounts.has(account.id) && 'rotate-90']"
                fill="none" stroke="currentColor" viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>

              <!-- Account Info -->
              <div>
                <h3 class="font-bold text-lg">{{ account.name }}</h3>
                <p class="text-sm text-base-content/50">
                  {{ account.account_type }}
                  <span v-if="account.mask"> · ••{{ account.mask }}</span>
                </p>
              </div>

              <!-- Pending Badge -->
              <span v-if="getAccountCount(account.id) > 0" class="badge badge-warning">
                {{ getAccountCount(account.id) }} {{ filters.ledger_status === 'pending' ? 'to review' : '' }}
              </span>
            </div>

            <!-- Balance & Actions -->
            <div class="flex items-center gap-4">
              <div class="text-right">
                <div class="text-2xl font-bold">{{ formatCurrency(account.current_balance) }}</div>
                <div class="text-xs text-base-content/50">Balance</div>
              </div>
              <router-link
                :to="`/reconciliation?account_id=${account.id}`"
                @click.stop
                class="btn btn-outline btn-sm"
              >
                Reconcile
              </router-link>
            </div>
          </div>
        </div>

        <!-- Expanded Transaction Table -->
        <div v-if="expandedAccounts.has(account.id)" class="border-t border-base-200">
          <!-- Bulk Actions -->
          <div v-if="getSelectedForAccount(account.id).length > 0"
            class="bg-primary/10 px-4 py-2 flex items-center gap-3 border-b border-base-200">
            <span class="text-sm font-medium">{{ getSelectedForAccount(account.id).length }} selected</span>
            <select v-model="bulkCategory" class="select select-bordered select-xs">
              <option value="">Categorize...</option>
              <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
            <button v-if="bulkCategory" @click="bulkCategorizeAccount(account.id)" class="btn btn-xs">Apply</button>
            <template v-if="filters.ledger_status === 'pending'">
              <button @click="bulkPostAccount(account.id)" class="btn btn-primary btn-xs">Add to Books</button>
              <button @click="bulkExcludeAccount(account.id)" class="btn btn-ghost btn-xs">Exclude</button>
            </template>
            <template v-else>
              <button @click="bulkUnpostAccount(account.id)" class="btn btn-ghost btn-xs">Move to Review</button>
            </template>
          </div>

          <!-- Transaction Table -->
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr class="bg-base-100">
                  <th class="w-8">
                    <input type="checkbox" class="checkbox checkbox-xs"
                      @change="toggleAllForAccount(account.id)"
                      :checked="isAllSelectedForAccount(account.id)" />
                  </th>
                  <th>Date</th>
                  <th>Description</th>
                  <th>Category</th>
                  <th class="text-right">Amount</th>
                  <th class="w-28">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="txn in getTransactionsForAccount(account.id)" :key="txn.id"
                  :class="['hover', selectedIds.has(txn.id) && 'bg-primary/5']">
                  <td>
                    <input type="checkbox" class="checkbox checkbox-xs"
                      :checked="selectedIds.has(txn.id)" @change="toggleSelect(txn.id)" />
                  </td>
                  <td class="font-mono text-xs whitespace-nowrap">{{ formatDate(txn.date) }}</td>
                  <td>
                    <div class="font-medium text-sm">{{ txn.description }}</div>
                    <div v-if="txn.merchant_name && txn.merchant_name !== txn.description"
                      class="text-xs text-base-content/40">{{ txn.merchant_name }}</div>
                  </td>
                  <td>
                    <select
                      :value="txn.chart_of_account_id || ''"
                      @change="categorizeOne(txn.id, $event.target.value)"
                      :class="['select select-bordered select-xs w-32', !txn.categorized && 'select-warning']">
                      <option value="">{{ txn.categorized ? '-- None --' : 'Select...' }}</option>
                      <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
                    </select>
                  </td>
                  <td :class="['text-right font-mono text-sm', txn.amount >= 0 ? 'text-success' : 'text-error']">
                    {{ formatCurrency(txn.amount) }}
                  </td>
                  <td>
                    <template v-if="txn.ledger_status === 'pending'">
                      <button
                        @click="postOne(txn.id)"
                        :disabled="!txn.categorized"
                        :class="['btn btn-xs', txn.categorized ? 'btn-primary' : 'btn-disabled']"
                      >Add</button>
                      <button @click="excludeOne(txn.id)" class="btn btn-xs btn-ghost ml-1">✕</button>
                    </template>
                    <template v-else-if="txn.ledger_status === 'posted'">
                      <span class="badge badge-success badge-xs">Posted</span>
                      <button @click="unpostOne(txn.id)" class="btn btn-xs btn-ghost ml-1">Undo</button>
                    </template>
                    <template v-else>
                      <button @click="unpostOne(txn.id)" class="btn btn-xs btn-ghost">Restore</button>
                    </template>
                  </td>
                </tr>
                <tr v-if="getTransactionsForAccount(account.id).length === 0">
                  <td colspan="6" class="text-center py-6 text-base-content/40">
                    No {{ filters.ledger_status }} transactions
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Load More / Pagination for this account -->
          <div v-if="hasMorePages(account.id)" class="p-3 border-t border-base-200 text-center">
            <button
              @click="loadMoreForAccount(account.id)"
              class="btn btn-ghost btn-sm"
            >
              Load more ({{ getRemainingCount(account.id) }} remaining)
            </button>
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

const accountsSummary = ref([])
const accountTransactions = ref({}) // { accountId: [transactions] }
const accountPagination = ref({}) // { accountId: { page, total, total_pages } }
const categories = ref([])
const loading = ref(false)
const expandedAccounts = ref(new Set())
const selectedIds = ref(new Set())
const bulkCategory = ref('')
const globalCounts = ref({ pending: 0, posted: 0, excluded: 0 })

const companyId = () => appStore.activeCompany?.id || 1

const filters = ref({
  ledger_status: 'pending'
})

const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)
const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : ''

const exportUrl = computed(() => {
  const cid = companyId()
  const year = new Date().getFullYear()
  return `/api/v1/companies/${cid}/exports/transactions?start_date=${year}-01-01&end_date=${year}-12-31`
})

// Filter accounts that have transactions in current status
const filteredAccounts = computed(() => {
  return accountsSummary.value.filter(a => getAccountCount(a.id) > 0 || expandedAccounts.value.has(a.id))
})

const getAccountCount = (accountId) => {
  const account = accountsSummary.value.find(a => a.id === accountId)
  if (!account) return 0
  switch (filters.value.ledger_status) {
    case 'pending': return account.pending_count || 0
    case 'posted': return account.posted_count || 0
    case 'excluded': return account.excluded_count || 0
    default: return 0
  }
}

const getTransactionsForAccount = (accountId) => {
  return accountTransactions.value[accountId] || []
}

const getSelectedForAccount = (accountId) => {
  const txns = getTransactionsForAccount(accountId)
  return txns.filter(t => selectedIds.value.has(t.id))
}

const isAllSelectedForAccount = (accountId) => {
  const txns = getTransactionsForAccount(accountId)
  return txns.length > 0 && txns.every(t => selectedIds.value.has(t.id))
}

const toggleSelect = (id) => {
  const s = new Set(selectedIds.value)
  s.has(id) ? s.delete(id) : s.add(id)
  selectedIds.value = s
}

const toggleAllForAccount = (accountId) => {
  const txns = getTransactionsForAccount(accountId)
  const s = new Set(selectedIds.value)

  if (isAllSelectedForAccount(accountId)) {
    txns.forEach(t => s.delete(t.id))
  } else {
    txns.forEach(t => s.add(t.id))
  }
  selectedIds.value = s
}

const toggleAccount = async (accountId) => {
  const expanded = new Set(expandedAccounts.value)
  if (expanded.has(accountId)) {
    expanded.delete(accountId)
  } else {
    expanded.add(accountId)
    // Load transactions if not already loaded
    if (!accountTransactions.value[accountId]) {
      await fetchTransactionsForAccount(accountId)
    }
  }
  expandedAccounts.value = expanded
}

const setLedgerStatus = async (status) => {
  filters.value.ledger_status = status
  selectedIds.value = new Set()
  // Clear cached transactions and reload for expanded accounts
  accountTransactions.value = {}
  for (const accountId of expandedAccounts.value) {
    await fetchTransactionsForAccount(accountId)
  }
}

const fetchAccountsSummary = async () => {
  const cid = companyId()
  try {
    const data = await apiClient.get(`/api/v1/companies/${cid}/transactions/accounts_summary`)
    accountsSummary.value = data?.accounts || []

    // Calculate global counts
    globalCounts.value = {
      pending: accountsSummary.value.reduce((s, a) => s + (a.pending_count || 0), 0),
      posted: accountsSummary.value.reduce((s, a) => s + (a.posted_count || 0), 0),
      excluded: accountsSummary.value.reduce((s, a) => s + (a.excluded_count || 0), 0)
    }

    // Auto-expand first account with transactions
    if (expandedAccounts.value.size === 0) {
      const firstWithTxns = accountsSummary.value.find(a => getAccountCount(a.id) > 0)
      if (firstWithTxns) {
        expandedAccounts.value.add(firstWithTxns.id)
        await fetchTransactionsForAccount(firstWithTxns.id)
      }
    }
  } catch (e) {
    console.error('Failed to fetch accounts summary:', e)
  }
}

const fetchTransactionsForAccount = async (accountId, page = 1) => {
  const cid = companyId()
  try {
    const params = new URLSearchParams({
      account_id: accountId,
      ledger_status: filters.value.ledger_status,
      page: page,
      per_page: 50
    })

    const data = await apiClient.get(`/api/v1/companies/${cid}/transactions?${params}`)

    if (page === 1) {
      accountTransactions.value[accountId] = data?.transactions || []
    } else {
      // Append for "load more"
      accountTransactions.value[accountId] = [
        ...(accountTransactions.value[accountId] || []),
        ...(data?.transactions || [])
      ]
    }

    accountPagination.value[accountId] = data?.pagination || { page: 1, total: 0, total_pages: 1 }
  } catch (e) {
    console.error(`Failed to fetch transactions for account ${accountId}:`, e)
  }
}

const loadMoreForAccount = async (accountId) => {
  const pag = accountPagination.value[accountId]
  const currentPage = pag ? pag.page : 1
  await fetchTransactionsForAccount(accountId, currentPage + 1)
}

const hasMorePages = (accountId) => {
  const pag = accountPagination.value[accountId]
  if (!pag) return false
  return pag.total_pages > 1 && pag.page < pag.total_pages
}

const getRemainingCount = (accountId) => {
  const pag = accountPagination.value[accountId]
  if (!pag) return 0
  const loaded = getTransactionsForAccount(accountId).length
  return pag.total - loaded
}

const categorizeOne = async (txnId, chartOfAccountId) => {
  const cid = companyId()
  await apiClient.put(`/api/v1/companies/${cid}/transactions/${txnId}`, {
    transaction: { chart_of_account_id: chartOfAccountId || null }
  })
  await refreshAll()
}

const postOne = async (txnId) => {
  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/${txnId}/post_transaction`)
  await refreshAll()
}

const excludeOne = async (txnId) => {
  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/${txnId}/exclude`)
  await refreshAll()
}

const unpostOne = async (txnId) => {
  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/${txnId}/unpost`)
  await refreshAll()
}

const bulkCategorizeAccount = async (accountId) => {
  if (!bulkCategory.value) return
  const ids = getSelectedForAccount(accountId).map(t => t.id)
  if (ids.length === 0) return

  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/categorize`, {
    transaction_ids: ids,
    chart_of_account_id: bulkCategory.value
  })
  bulkCategory.value = ''
  selectedIds.value = new Set()
  await refreshAll()
}

const bulkPostAccount = async (accountId) => {
  const ids = getSelectedForAccount(accountId).map(t => t.id)
  if (ids.length === 0) return

  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/bulk_post`, {
    transaction_ids: ids
  })
  selectedIds.value = new Set()
  await refreshAll()
}

const bulkExcludeAccount = async (accountId) => {
  const ids = getSelectedForAccount(accountId).map(t => t.id)
  if (ids.length === 0) return

  const cid = companyId()
  await apiClient.post(`/api/v1/companies/${cid}/transactions/bulk_exclude`, {
    transaction_ids: ids
  })
  selectedIds.value = new Set()
  await refreshAll()
}

const bulkUnpostAccount = async (accountId) => {
  const ids = getSelectedForAccount(accountId).map(t => t.id)
  for (const id of ids) {
    const cid = companyId()
    await apiClient.post(`/api/v1/companies/${cid}/transactions/${id}/unpost`)
  }
  selectedIds.value = new Set()
  await refreshAll()
}

const refreshAll = async () => {
  await fetchAccountsSummary()
  // Reload transactions for expanded accounts
  for (const accountId of expandedAccounts.value) {
    await fetchTransactionsForAccount(accountId)
  }
}

watch(() => appStore.activeCompany, async () => {
  expandedAccounts.value = new Set()
  accountTransactions.value = {}
  await refreshAll()
  const cid = companyId()
  categories.value = await apiClient.get(`/api/v1/companies/${cid}/chart_of_accounts`) || []
})

onMounted(async () => {
  loading.value = true
  try {
    const cid = companyId()
    const [, cats] = await Promise.all([
      fetchAccountsSummary(),
      apiClient.get(`/api/v1/companies/${cid}/chart_of_accounts`)
    ])
    categories.value = cats || []
  } finally {
    loading.value = false
  }
})
</script>
