<template>
  <div>
    <div class="flex justify-between items-center mb-8">
      <div>
        <h1 class="text-3xl font-bold">Linked Accounts</h1>
        <p class="text-base-content/60 mt-1">Connect your bank accounts via Plaid</p>
      </div>
      <button @click="openPlaidLink" class="btn btn-primary gap-2" :disabled="linkLoading">
        <span v-if="linkLoading" class="loading loading-spinner loading-sm"></span>
        <svg v-else xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
        </svg>
        Link New Account
      </button>
    </div>

    <!-- Plaid Items -->
    <div v-if="items.length > 0" class="space-y-6">
      <div v-for="item in items" :key="item.id" class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <div class="flex justify-between items-center mb-4">
            <div>
              <h2 class="card-title">🏦 {{ item.institution_name }}</h2>
              <p class="text-sm text-base-content/60">Last synced: {{ formatDate(item.last_synced) }}</p>
            </div>
            <div class="flex gap-2">
              <button @click="syncTransactions" class="btn btn-outline btn-sm gap-1">
                🔄 Sync
              </button>
              <button @click="refreshBalances" class="btn btn-outline btn-sm gap-1">
                💰 Refresh Balances
              </button>
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-ghost btn-sm">⋮</div>
                <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-40">
                  <li><a @click="removeItem(item)" class="text-error">Disconnect</a></li>
                </ul>
              </div>
            </div>
          </div>

          <!-- Accounts in this item -->
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Account</th>
                  <th>Type</th>
                  <th>Mask</th>
                  <th class="text-right">Available</th>
                  <th class="text-right">Current</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="account in item.accounts" :key="account.id">
                  <td class="font-medium">{{ account.name }}</td>
                  <td><span class="badge badge-sm badge-outline">{{ account.type }}</span></td>
                  <td class="font-mono text-sm">****{{ account.mask }}</td>
                  <td class="text-right font-mono">{{ formatCurrency(account.available_balance) }}</td>
                  <td class="text-right font-mono font-bold">{{ formatCurrency(account.current_balance) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-else class="card bg-base-100 shadow-xl">
      <div class="card-body items-center text-center py-16">
        <div class="text-6xl mb-4">🏦</div>
        <h2 class="text-2xl font-bold mb-2">No accounts linked yet</h2>
        <p class="text-base-content/60 mb-6 max-w-md">
          Connect your bank accounts, credit cards, and investment accounts to automatically import transactions and track your finances.
        </p>
        <button @click="openPlaidLink" class="btn btn-primary btn-lg gap-2" :disabled="linkLoading">
          <span v-if="linkLoading" class="loading loading-spinner loading-sm"></span>
          Link Your First Account
        </button>
        <div class="mt-6 flex items-center gap-2 text-sm text-base-content/40">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
          </svg>
          Secured by Plaid — your credentials are never stored
        </div>
      </div>
    </div>

    <!-- Toast -->
    <div v-if="toast" class="toast toast-end">
      <div :class="['alert', toast.type === 'success' ? 'alert-success' : toast.type === 'error' ? 'alert-error' : 'alert-info']">
        <span>{{ toast.message }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { apiClient } from '../api/client'

const items = ref([])
const linkLoading = ref(false)
const toast = ref(null)

const formatCurrency = (amount) => {
  if (amount === null || amount === undefined) return '—'
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount)
}

const formatDate = (d) => d ? new Date(d).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : 'Never'

const showToast = (message, type = 'success') => {
  toast.value = { message, type }
  setTimeout(() => toast.value = null, 4000)
}

const openPlaidLink = async () => {
  linkLoading.value = true
  try {
    // Get link token from backend
    const data = await apiClient.post('/api/v1/plaid/create_link_token')
    if (!data?.link_token) {
      showToast('Unable to initialize Plaid Link', 'error')
      return
    }

    // Open Plaid Link
    const handler = window.Plaid.create({
      token: data.link_token,
      onSuccess: async (publicToken, metadata) => {
        showToast('Linking account...', 'info')
        const result = await apiClient.post('/api/v1/plaid/exchange_token', {
          public_token: publicToken,
          institution_id: metadata.institution?.institution_id,
          institution_name: metadata.institution?.name
        })
        if (result?.error) {
          showToast(result.error, 'error')
        } else {
          showToast(`Linked ${result.accounts_count} account(s) from ${metadata.institution?.name}!`)
          await fetchItems()
        }
      },
      onExit: (err) => {
        if (err) {
          showToast(`Link error: ${err.display_message || err.error_message}`, 'error')
        }
      },
      onEvent: (eventName) => {
        console.log('Plaid event:', eventName)
      }
    })
    handler.open()
  } catch (err) {
    showToast('Failed to open Plaid Link', 'error')
  } finally {
    linkLoading.value = false
  }
}

const syncTransactions = async () => {
  showToast('Syncing transactions...', 'info')
  const result = await apiClient.post('/api/v1/plaid/sync_transactions')
  if (result?.error) {
    showToast(result.error, 'error')
  } else {
    showToast(`Synced: ${result.added} added, ${result.modified} modified, ${result.removed} removed`)
  }
}

const refreshBalances = async () => {
  showToast('Refreshing balances...', 'info')
  const result = await apiClient.post('/api/v1/plaid/refresh_balances')
  if (result?.error) {
    showToast(result.error, 'error')
  } else {
    showToast('Balances refreshed!')
    await fetchItems()
  }
}

const removeItem = async (item) => {
  if (!confirm(`Disconnect ${item.institution_name}? This will not delete existing transactions.`)) return
  await apiClient.delete(`/api/v1/plaid/items/${item.id}`)
  showToast('Account disconnected')
  await fetchItems()
}

const fetchItems = async () => {
  items.value = await apiClient.get('/api/v1/plaid/items') || []
}

onMounted(fetchItems)
</script>
