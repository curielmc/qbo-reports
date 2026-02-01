<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Linked Accounts</h1>
        <p class="text-base-content/60 mt-1">Connect bank accounts via Plaid to sync transactions automatically</p>
      </div>
      <button @click="linkAccount" class="btn btn-primary gap-2" :disabled="linking">
        <span v-if="linking" class="loading loading-spinner loading-sm"></span>
        🏦 Link New Account
      </button>
    </div>

    <!-- Linked Items -->
    <div v-if="items.length === 0 && !loading" class="card bg-base-100 shadow-xl">
      <div class="card-body items-center text-center py-16">
        <div class="text-6xl mb-4">🏦</div>
        <h2 class="text-2xl font-bold mb-2">No accounts linked yet</h2>
        <p class="text-base-content/60 mb-6 max-w-md">
          Connect your bank, credit card, or investment accounts to automatically import transactions.
        </p>
        <button @click="linkAccount" class="btn btn-primary btn-lg gap-2">
          🔗 Connect Your First Account
        </button>
      </div>
    </div>

    <div v-for="item in items" :key="item.id" class="card bg-base-100 shadow-xl mb-6">
      <div class="card-body">
        <div class="flex justify-between items-start">
          <div>
            <h2 class="card-title">{{ item.institution_name }}</h2>
            <p class="text-sm text-base-content/50">
              Connected {{ formatDate(item.created_at) }}
              · Last synced {{ item.last_synced_at ? timeAgo(item.last_synced_at) : 'never' }}
            </p>
          </div>
          <div class="flex gap-2">
            <button @click="syncItem(item)" class="btn btn-outline btn-sm gap-1" :disabled="syncing === item.id">
              <span v-if="syncing === item.id" class="loading loading-spinner loading-xs"></span>
              🔄 Sync
            </button>
            <button @click="refreshBalances(item)" class="btn btn-outline btn-sm gap-1" :disabled="refreshing === item.id">
              💰 Refresh
            </button>
            <button @click="removeItem(item)" class="btn btn-ghost btn-sm text-error">✕</button>
          </div>
        </div>

        <!-- Accounts under this item -->
        <div class="overflow-x-auto mt-4">
          <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
            <thead>
              <tr>
                <th>Account</th>
                <th>Type</th>
                <th>Mask</th>
                <th class="text-right">Balance</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="acct in item.accounts" :key="acct.id">
                <td class="font-medium">{{ acct.name }}</td>
                <td>
                  <span class="badge badge-sm badge-outline">{{ acct.account_type }}</span>
                </td>
                <td class="font-mono text-sm text-base-content/50">···{{ acct.mask }}</td>
                <td class="text-right font-mono font-bold">
                  {{ formatCurrency(acct.current_balance) }}
                </td>
                <td>
                  <span :class="['badge badge-xs', acct.active ? 'badge-success' : 'badge-error']">
                    {{ acct.active ? 'Active' : 'Inactive' }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Sync Results Toast -->
    <div v-if="toast" class="toast toast-end">
      <div :class="['alert', toast.type === 'success' ? 'alert-success' : 'alert-error']">
        <span>{{ toast.message }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const items = ref([])
const loading = ref(false)
const linking = ref(false)
const syncing = ref(null)
const refreshing = ref(null)
const toast = ref(null)

const companyId = () => appStore.currentCompany?.id || 1

const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)
const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : ''
const timeAgo = (d) => {
  if (!d) return 'never'
  const mins = Math.floor((Date.now() - new Date(d)) / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins}m ago`
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`
  return `${Math.floor(mins / 1440)}d ago`
}

const showToast = (message, type = 'success') => {
  toast.value = { message, type }
  setTimeout(() => toast.value = null, 4000)
}

const fetchItems = async () => {
  loading.value = true
  items.value = await apiClient.get('/api/v1/plaid/items') || []
  loading.value = false
}

const linkAccount = async () => {
  linking.value = true
  try {
    const { link_token } = await apiClient.post('/api/v1/plaid/create_link_token', { company_id: companyId() })
    
    // Open Plaid Link
    const handler = window.Plaid.create({
      token: link_token,
      onSuccess: async (public_token, metadata) => {
        await apiClient.post('/api/v1/plaid/exchange_token', {
          public_token,
          company_id: companyId(),
          institution_name: metadata.institution?.name
        })
        showToast(`Connected ${metadata.institution?.name}!`)
        await fetchItems()
      },
      onExit: () => { linking.value = false }
    })
    handler.open()
  } catch (e) {
    showToast('Failed to initialize Plaid Link', 'error')
    linking.value = false
  }
}

const syncItem = async (item) => {
  syncing.value = item.id
  try {
    const result = await apiClient.post('/api/v1/plaid/sync_transactions', { plaid_item_id: item.id })
    showToast(`Synced ${result?.added || 0} new transactions`)
    await fetchItems()
  } catch (e) {
    showToast('Sync failed', 'error')
  }
  syncing.value = null
}

const refreshBalances = async (item) => {
  refreshing.value = item.id
  try {
    await apiClient.post('/api/v1/plaid/refresh_balances', { plaid_item_id: item.id })
    showToast('Balances refreshed')
    await fetchItems()
  } catch (e) {
    showToast('Refresh failed', 'error')
  }
  refreshing.value = null
}

const removeItem = async (item) => {
  if (!confirm(`Disconnect ${item.institution_name}? This won't delete existing transactions.`)) return
  await apiClient.delete(`/api/v1/plaid/items/${item.id}`)
  showToast(`Disconnected ${item.institution_name}`)
  await fetchItems()
}

onMounted(fetchItems)
</script>
