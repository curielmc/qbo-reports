<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Import Data</h1>
        <p class="text-base-content/60 mt-1">Bring your data from any accounting system</p>
      </div>
    </div>

    <!-- Step 1: Source Selection -->
    <div v-if="step === 'select'" class="space-y-6">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div v-for="fmt in formats" :key="fmt.id"
          class="card bg-base-100 shadow-md hover:shadow-xl cursor-pointer transition border-2 border-transparent hover:border-primary"
          @click="selectSource(fmt)">
          <div class="card-body items-center text-center p-4">
            <span class="text-3xl">{{ fmt.icon }}</span>
            <h3 class="font-bold text-sm mt-2">{{ fmt.name }}</h3>
            <p class="text-xs text-base-content/40">{{ fmt.extensions.join(', ') }}</p>
          </div>
        </div>
      </div>

      <div class="divider">OR</div>

      <div class="card bg-base-100 shadow-xl">
        <div class="card-body items-center text-center">
          <p class="text-lg font-medium mb-2">Just upload — AI figures out the rest</p>
          <label class="btn btn-primary btn-lg">
            📁 Upload Any File
            <input type="file" @change="handleUpload" accept=".csv,.iif,.ofx,.qfx,.qbo,.xls,.xlsx,.json,.pdf" class="hidden" />
          </label>
          <p class="text-sm text-base-content/40 mt-2">CSV, IIF, OFX, QFX, Excel, JSON — we handle them all</p>
        </div>
      </div>
    </div>

    <!-- Step 2: Uploading/Processing -->
    <div v-if="step === 'processing'" class="text-center py-16">
      <span class="loading loading-spinner loading-lg text-primary"></span>
      <p class="text-lg mt-4">Analyzing your data...</p>
      <p class="text-sm text-base-content/50 mt-2">AI is detecting format, mapping categories, and checking for duplicates</p>
    </div>

    <!-- Step 3: Preview -->
    <div v-if="step === 'preview'" class="space-y-6">
      <!-- Detection Result -->
      <div class="alert alert-info">
        <span class="text-lg">{{ sourceIcon }}</span>
        <div>
          <p class="font-bold">Detected: {{ preview.source?.source?.replace(/_/g, ' ') }}</p>
          <p class="text-sm">{{ preview.source?.confidence }}% confidence</p>
        </div>
      </div>

      <!-- Summary Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="stat bg-base-100 rounded-box shadow p-4">
          <div class="stat-title text-xs">Transactions</div>
          <div class="stat-value text-xl">{{ preview.summary?.transactions }}</div>
        </div>
        <div class="stat bg-base-100 rounded-box shadow p-4">
          <div class="stat-title text-xs">Accounts</div>
          <div class="stat-value text-xl">{{ preview.summary?.accounts }}</div>
        </div>
        <div class="stat bg-base-100 rounded-box shadow p-4">
          <div class="stat-title text-xs">Categories</div>
          <div class="stat-value text-xl">{{ preview.summary?.chart_of_accounts }}</div>
        </div>
        <div class="stat bg-base-100 rounded-box shadow p-4">
          <div class="stat-title text-xs">Date Range</div>
          <div class="stat-value text-sm">
            {{ preview.summary?.date_range?.from }} → {{ preview.summary?.date_range?.to }}
          </div>
        </div>
      </div>

      <!-- Warnings -->
      <div v-if="preview.warnings?.length" class="space-y-2">
        <div v-for="(w, i) in preview.warnings" :key="i" class="alert alert-warning py-2">
          <span>⚠️ {{ w }}</span>
        </div>
      </div>

      <!-- Category Mapping -->
      <div v-if="preview.category_mapping && Object.keys(preview.category_mapping).length" class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">📋 Category Mapping</h2>
          <div class="overflow-x-auto">
            <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
              <thead>
                <tr><th>Your Old Category</th><th>→</th><th>ecfoBooks Category</th></tr>
              </thead>
              <tbody>
                <tr v-for="(mapped, original) in preview.category_mapping" :key="original">
                  <td class="text-sm">{{ original }}</td>
                  <td class="text-center">→</td>
                  <td class="text-sm font-medium text-primary">{{ mapped }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- New Categories -->
      <div v-if="preview.suggested_new_categories?.length" class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <div class="flex justify-between items-center mb-4">
            <h2 class="card-title text-lg">🆕 New Categories to Create</h2>
            <label class="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" v-model="createNewCategories" class="checkbox checkbox-sm checkbox-primary" />
              <span class="text-sm">Create all</span>
            </label>
          </div>
          <div class="space-y-2">
            <div v-for="cat in preview.suggested_new_categories" :key="cat.name"
              class="flex items-center gap-3 p-2 rounded bg-base-200">
              <span class="badge badge-sm badge-outline">{{ cat.account_type }}</span>
              <span class="font-medium text-sm">{{ cat.name }}</span>
              <span class="text-xs text-base-content/40">from: {{ cat.source }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Transaction Preview -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">📊 Transaction Preview (first 20)</h2>
          <div class="overflow-x-auto">
            <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Description</th>
                  <th>Category</th>
                  <th class="text-right">Amount</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(txn, i) in preview.sample_transactions" :key="i" class="hover">
                  <td class="text-sm whitespace-nowrap">{{ txn.date }}</td>
                  <td class="text-sm max-w-xs truncate">{{ txn.description || txn.merchant }}</td>
                  <td><span v-if="txn.category" class="badge badge-sm badge-outline">{{ txn.category }}</span></td>
                  <td :class="['text-right font-mono text-sm', txn.amount < 0 ? 'text-error' : 'text-success']">
                    {{ formatCurrency(txn.amount) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex justify-between">
        <button @click="step = 'select'" class="btn btn-ghost">← Back</button>
        <div class="flex gap-2">
          <button @click="step = 'select'" class="btn btn-outline">Cancel</button>
          <button @click="commitImport" class="btn btn-primary btn-lg" :disabled="committing">
            <span v-if="committing" class="loading loading-spinner loading-sm"></span>
            ✅ Import {{ preview.summary?.transactions }} Transactions
          </button>
        </div>
      </div>
    </div>

    <!-- Step 4: Complete -->
    <div v-if="step === 'complete'" class="text-center py-16">
      <p class="text-6xl mb-4">🎉</p>
      <h2 class="text-2xl font-bold mb-2">Import Complete!</h2>
      <div class="stats shadow mt-4">
        <div class="stat">
          <div class="stat-title">Imported</div>
          <div class="stat-value text-success">{{ results?.results?.created?.transactions || 0 }}</div>
          <div class="stat-desc">transactions</div>
        </div>
        <div class="stat">
          <div class="stat-title">Duplicates Skipped</div>
          <div class="stat-value">{{ results?.results?.skipped?.duplicates || 0 }}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Auto-Categorized</div>
          <div class="stat-value text-primary">{{ results?.auto_categorized || 0 }}</div>
        </div>
      </div>
      <div class="mt-8 flex gap-4 justify-center">
        <router-link to="/transactions" class="btn btn-outline">View Transactions</router-link>
        <router-link to="/" class="btn btn-primary">Go to Chat</router-link>
        <button @click="resetImport" class="btn btn-ghost">Import More</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const companyId = () => appStore.currentCompany?.id || 1
const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)

const step = ref('select')
const formats = ref([])
const preview = ref({})
const results = ref(null)
const createNewCategories = ref(true)
const committing = ref(false)

const sourceIcon = computed(() => {
  const icons = { quickbooks_online: '📗', quickbooks_desktop: '📘', xero: '📋', freshbooks: '📒', wave: '🌊', ofx_qfx: '🏦', generic_csv: '📄' }
  return icons[preview.value.source?.source] || '📁'
})

const selectSource = (fmt) => {
  // Just open file picker — AI detects anyway
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = fmt.extensions.join(',')
  input.onchange = (e) => handleUpload(e)
  input.click()
}

const handleUpload = async (e) => {
  const file = e.target.files?.[0]
  if (!file) return

  step.value = 'processing'

  const form = new FormData()
  form.append('file', file)

  try {
    const result = await fetch(`/api/v1/companies/${companyId()}/imports/upload`, {
      method: 'POST',
      body: form,
      headers: { 'X-CSRF-Token': document.querySelector('meta[name=csrf-token]')?.content }
    }).then(r => r.json())

    if (result?.import_key) {
      preview.value = result
      step.value = 'preview'
    } else {
      alert(result?.error || 'Import failed')
      step.value = 'select'
    }
  } catch (err) {
    alert('Upload failed: ' + err.message)
    step.value = 'select'
  }
}

const commitImport = async () => {
  committing.value = true
  try {
    const result = await apiClient.post(`/api/v1/companies/${companyId()}/imports/commit`, {
      import_key: preview.value.import_key,
      create_new_categories: createNewCategories.value
    })
    results.value = result
    step.value = 'complete'
  } catch (err) {
    alert('Import failed: ' + err.message)
  }
  committing.value = false
}

const resetImport = () => {
  step.value = 'select'
  preview.value = {}
  results.value = null
}

onMounted(async () => {
  const data = await apiClient.get(`/api/v1/companies/${companyId()}/imports/supported`)
  formats.value = data?.formats || []
})
</script>
