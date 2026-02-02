<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Receipts</h1>
        <p class="text-base-content/60 mt-1">Upload receipts — AI reads and matches them to transactions</p>
      </div>
      <label class="btn btn-primary">
        📷 Upload Receipt
        <input type="file" accept="image/*,.pdf" @change="uploadReceipt" class="hidden" multiple />
      </label>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
      <div class="stat bg-base-100 rounded-box shadow p-4">
        <div class="stat-title text-xs">Total</div>
        <div class="stat-value text-xl">{{ receipts.length }}</div>
      </div>
      <div class="stat bg-success/10 rounded-box shadow p-4">
        <div class="stat-title text-xs">Matched</div>
        <div class="stat-value text-xl text-success">{{ receipts.filter(r => r.status === 'matched').length }}</div>
      </div>
      <div class="stat bg-warning/10 rounded-box shadow p-4">
        <div class="stat-title text-xs">Unmatched</div>
        <div class="stat-value text-xl text-warning">{{ receipts.filter(r => r.status === 'unmatched').length }}</div>
      </div>
      <div class="stat bg-base-200 rounded-box shadow p-4">
        <div class="stat-title text-xs">Pending</div>
        <div class="stat-value text-xl">{{ receipts.filter(r => r.status === 'pending').length }}</div>
      </div>
    </div>

    <!-- Upload Progress -->
    <div v-if="uploading" class="alert alert-info mb-4">
      <span class="loading loading-spinner"></span>
      <span>Uploading and parsing receipt...</span>
    </div>

    <!-- Receipts Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="r in receipts" :key="r.id" class="card bg-base-100 shadow-md">
        <div class="card-body p-4">
          <div class="flex justify-between items-start">
            <div>
              <h3 class="font-bold">{{ r.vendor || 'Unknown Vendor' }}</h3>
              <p class="text-sm text-base-content/50">{{ r.date || 'No date' }}</p>
            </div>
            <span :class="['badge badge-sm', statusClass(r.status)]">{{ r.status }}</span>
          </div>
          <p class="text-2xl font-bold font-mono mt-2">{{ formatCurrency(r.amount) }}</p>
          <p v-if="r.description" class="text-sm text-base-content/60 mt-1">{{ r.description }}</p>
          <p class="text-xs text-base-content/40 mt-2">📎 {{ r.filename }}</p>
          <div v-if="r.status === 'matched'" class="mt-2 text-xs text-success">
            ✅ Matched to transaction #{{ r.matched_transaction_id }}
          </div>
          <div v-if="r.status === 'unmatched'" class="mt-2">
            <button @click="promptMatch(r)" class="btn btn-outline btn-xs">🔗 Match Manually</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="!receipts.length && !uploading" class="text-center py-16">
      <p class="text-4xl mb-4">🧾</p>
      <p class="text-lg text-base-content/50">No receipts yet</p>
      <p class="text-sm text-base-content/40 mt-1">Upload a receipt photo and AI will parse it instantly</p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const companyId = () => appStore.activeCompany?.id || 1
const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)

const receipts = ref([])
const uploading = ref(false)

const statusClass = (s) => ({
  matched: 'badge-success', unmatched: 'badge-warning', pending: 'badge-ghost', manual: 'badge-info'
}[s] || 'badge-ghost')

const uploadReceipt = async (e) => {
  const files = e.target.files
  if (!files.length) return

  uploading.value = true
  for (const file of files) {
    const form = new FormData()
    form.append('file', file)
    try {
      const result = await fetch(`/api/v1/companies/${companyId()}/receipts`, {
        method: 'POST',
        body: form,
        headers: { 'X-CSRF-Token': document.querySelector('meta[name=csrf-token]')?.content }
      }).then(r => r.json())

      if (result?.receipt) receipts.value.unshift(result.receipt)
    } catch (err) {
      console.error('Upload failed:', err)
    }
  }
  uploading.value = false
  e.target.value = ''
}

const promptMatch = (receipt) => {
  const txnId = prompt(`Enter transaction ID to match receipt from ${receipt.vendor}:`)
  if (txnId) matchReceipt(receipt.id, parseInt(txnId))
}

const matchReceipt = async (receiptId, transactionId) => {
  const result = await apiClient.patch(
    `/api/v1/companies/${companyId()}/receipts/${receiptId}/match`,
    { transaction_id: transactionId }
  )
  if (result?.receipt) {
    const idx = receipts.value.findIndex(r => r.id === receiptId)
    if (idx >= 0) receipts.value[idx] = result.receipt
  }
}

onMounted(async () => {
  receipts.value = await apiClient.get(`/api/v1/companies/${companyId()}/receipts`) || []
})
</script>
