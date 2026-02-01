<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Reconciliation</h1>
        <p class="text-base-content/60 mt-1">Match your books to your bank statements</p>
      </div>
      <button @click="showNewModal = true" class="btn btn-primary">🔄 New Reconciliation</button>
    </div>

    <!-- Active Reconciliation -->
    <div v-if="active" class="card bg-base-100 shadow-xl mb-8">
      <div class="card-body">
        <div class="flex justify-between items-start mb-4">
          <div>
            <h2 class="card-title text-lg">{{ active.account }}</h2>
            <p class="text-sm text-base-content/50">Statement Date: {{ active.statement_date }}</p>
          </div>
          <div class="text-right">
            <p class="text-sm text-base-content/50">Statement Balance</p>
            <p class="text-2xl font-bold font-mono">{{ formatCurrency(active.statement_balance) }}</p>
          </div>
        </div>

        <!-- Balance Comparison -->
        <div class="grid grid-cols-3 gap-2 sm:gap-4 mb-4 sm:mb-6">
          <div class="stat bg-base-200 rounded-box p-4">
            <div class="stat-title text-xs">Cleared Balance</div>
            <div class="stat-value text-lg font-mono">{{ formatCurrency(active.book_balance) }}</div>
          </div>
          <div class="stat bg-base-200 rounded-box p-4">
            <div class="stat-title text-xs">Statement Balance</div>
            <div class="stat-value text-lg font-mono">{{ formatCurrency(active.statement_balance) }}</div>
          </div>
          <div :class="['stat rounded-box p-4', active.difference == 0 ? 'bg-success/20' : 'bg-error/20']">
            <div class="stat-title text-xs">Difference</div>
            <div :class="['stat-value text-lg font-mono', active.difference == 0 ? 'text-success' : 'text-error']">
              {{ formatCurrency(active.difference) }}
            </div>
          </div>
        </div>

        <!-- Actions -->
        <div class="flex gap-2 mb-4">
          <button @click="suggestClears" class="btn btn-outline btn-sm">🤖 AI Suggest</button>
          <button @click="finishRecon" :disabled="active.difference !== 0" class="btn btn-success btn-sm">
            ✅ Finish Reconciliation
          </button>
        </div>

        <!-- Transaction List -->
        <div class="overflow-x-auto max-h-[50vh] sm:max-h-96 overflow-y-auto -mx-4 sm:mx-0">
          <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
            <thead class="sticky top-0 bg-base-100">
              <tr>
                <th class="w-10">✓</th>
                <th>Date</th>
                <th>Description</th>
                <th class="text-right">Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="txn in active.transactions" :key="txn.id" 
                :class="['hover cursor-pointer', txn.cleared ? 'bg-success/10' : '']"
                @click="toggleCleared(txn)">
                <td>
                  <input type="checkbox" :checked="txn.cleared" class="checkbox checkbox-sm checkbox-success" @click.stop="toggleCleared(txn)" />
                </td>
                <td class="text-sm">{{ txn.date }}</td>
                <td class="text-sm">{{ txn.description }}</td>
                <td :class="['text-right font-mono text-sm', txn.amount < 0 ? 'text-error' : 'text-success']">
                  {{ formatCurrency(txn.amount) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Past Reconciliations -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title text-lg mb-4">History</h2>
        <div class="overflow-x-auto">
          <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
            <thead>
              <tr>
                <th>Account</th>
                <th>Statement Date</th>
                <th class="text-right">Balance</th>
                <th>Status</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in history" :key="r.id" class="hover">
                <td>{{ r.account }}</td>
                <td>{{ r.statement_date }}</td>
                <td class="text-right font-mono">{{ formatCurrency(r.statement_balance) }}</td>
                <td>
                  <span :class="['badge badge-sm', r.status === 'completed' ? 'badge-success' : 'badge-warning']">
                    {{ r.status }}
                  </span>
                </td>
                <td class="text-sm text-base-content/50">{{ formatDate(r.created_at) }}</td>
              </tr>
              <tr v-if="!history.length">
                <td colspan="5" class="text-center py-6 text-base-content/50">No reconciliations yet</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- New Reconciliation Modal -->
    <dialog :class="['modal', showNewModal ? 'modal-open' : '']">
      <div class="modal-box w-[95vw] sm:w-auto max-h-[90vh]">
        <h3 class="font-bold text-lg mb-4">Start Reconciliation</h3>
        <form @submit.prevent="startRecon">
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Account</span></label>
            <select v-model="newRecon.account_id" class="select select-bordered" required>
              <option value="">Select account</option>
              <option v-for="a in accounts" :key="a.id" :value="a.id">{{ a.name }}</option>
            </select>
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Statement Ending Date</span></label>
            <input v-model="newRecon.statement_date" type="date" class="input input-bordered" required />
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Statement Ending Balance</span></label>
            <input v-model.number="newRecon.statement_balance" type="number" step="0.01" class="input input-bordered" required />
          </div>
          <div class="modal-action">
            <button type="button" @click="showNewModal = false" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary">Start</button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showNewModal = false"><button>close</button></form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const companyId = () => appStore.currentCompany?.id || 1
const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)
const formatDate = (d) => d ? new Date(d).toLocaleDateString() : ''

const active = ref(null)
const history = ref([])
const accounts = ref([])
const showNewModal = ref(false)
const newRecon = ref({ account_id: '', statement_date: '', statement_balance: 0 })

const startRecon = async () => {
  const result = await apiClient.post(`/api/v1/companies/${companyId()}/reconciliations`, newRecon.value)
  if (result?.reconciliation) {
    active.value = { ...result.reconciliation, transactions: result.transactions }
    showNewModal.value = false
  }
}

const toggleCleared = async (txn) => {
  const result = await apiClient.patch(
    `/api/v1/companies/${companyId()}/reconciliations/${active.value.id}/toggle`,
    { transaction_id: txn.id }
  )
  if (result) {
    txn.cleared = result.status === 'cleared'
    active.value.book_balance = result.book_balance
    active.value.difference = result.difference
  }
}

const suggestClears = async () => {
  const result = await apiClient.patch(
    `/api/v1/companies/${companyId()}/reconciliations/${active.value.id}/suggest`
  )
  if (result?.suggested_transaction_ids) {
    active.value.transactions.forEach(t => {
      if (result.suggested_transaction_ids.includes(t.id)) t.cleared = true
    })
    // Apply all suggestions
    for (const id of result.suggested_transaction_ids) {
      await apiClient.patch(
        `/api/v1/companies/${companyId()}/reconciliations/${active.value.id}/toggle`,
        { transaction_id: id }
      )
    }
    // Refresh
    const recon = await apiClient.get(`/api/v1/companies/${companyId()}/reconciliations/${active.value.id}`)
    if (recon) active.value = { ...recon.reconciliation, transactions: recon.transactions }
  }
}

const finishRecon = async () => {
  const result = await apiClient.patch(
    `/api/v1/companies/${companyId()}/reconciliations/${active.value.id}/finish`
  )
  if (result?.success) {
    active.value = null
    await fetchHistory()
    alert('✅ Reconciliation complete!')
  } else {
    alert(result?.message || 'Cannot finalize — difference is not zero.')
  }
}

const fetchHistory = async () => {
  history.value = await apiClient.get(`/api/v1/companies/${companyId()}/reconciliations`) || []
}

onMounted(async () => {
  const [accts, recons] = await Promise.all([
    apiClient.get(`/api/v1/companies/${companyId()}/accounts`),
    apiClient.get(`/api/v1/companies/${companyId()}/reconciliations`)
  ])
  accounts.value = accts || []
  history.value = recons || []

  // Check for in-progress reconciliation
  const inProgress = recons?.find(r => r.status === 'in_progress')
  if (inProgress) {
    const detail = await apiClient.get(`/api/v1/companies/${companyId()}/reconciliations/${inProgress.id}`)
    if (detail) active.value = { ...detail.reconciliation, transactions: detail.transactions }
  }
})
</script>
