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
      <!-- Box.com Folder Card -->
      <div class="card bg-base-100 shadow-xl border-2 border-base-300">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <svg class="w-10 h-10 text-blue-500" viewBox="0 0 24 24" fill="currentColor">
                <path d="M4.027 8.028l3.973 2.972 3.998-2.972-3.998-2.973zM12.002 11l3.998-2.972-3.998-2.973L8 8.028zm-3.975 2.972l3.975 2.973 3.998-2.973-3.998-2.972zm3.975-1.5l-3.975-2.972L4.027 12l3.975 2.972 3.998-2.972L15.998 12z"/>
              </svg>
              <div>
                <h2 class="text-lg font-bold">Box.com Folder</h2>
                <p class="text-sm text-base-content/60" v-if="boxConfig && boxConfig.box_folder_url">{{ boxConfig.box_folder_url }}</p>
                <p class="text-sm text-base-content/60" v-else>Connect a Box folder to auto-import statements</p>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <span v-if="boxConfig && boxConfig.imported_count" class="badge badge-success badge-sm">{{ boxConfig.imported_count }} imported</span>
              <button class="btn btn-sm btn-ghost" @click="showBoxSettings = !showBoxSettings">
                {{ showBoxSettings ? 'Hide' : 'Settings' }}
              </button>
              <button v-if="boxConfig && (boxConfig.has_token || boxConfig.has_jwt) && boxConfig.box_folder_id"
                class="btn btn-sm btn-primary" @click="triggerBoxSync" :disabled="boxSyncing">
                <span v-if="boxSyncing" class="loading loading-spinner loading-xs"></span>
                Refresh
              </button>
            </div>
          </div>

          <!-- Box Settings Panel -->
          <div v-if="showBoxSettings" class="mt-4 p-4 bg-base-200 rounded-lg space-y-3">
            <div v-if="boxConfig && boxConfig.has_jwt" class="flex items-center gap-2 text-sm text-success">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>
              Box JWT authentication configured (server-side)
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Box Folder URL</span></label>
              <input type="text" v-model="boxFolderUrl" placeholder="https://app.box.com/folder/123456789"
                class="input input-bordered input-sm w-full" />
            </div>
            <div class="form-control">
              <label class="label">
                <span class="label-text">Developer Token <span class="text-base-content/40 font-normal">(optional — only needed if JWT is not configured)</span></span>
              </label>
              <input type="password" v-model="boxToken" placeholder="Leave blank to use JWT auth"
                class="input input-bordered input-sm w-full" />
            </div>
            <button class="btn btn-sm btn-primary" @click="saveBoxConfig" :disabled="savingBoxConfig">
              <span v-if="savingBoxConfig" class="loading loading-spinner loading-xs"></span>
              Save
            </button>
          </div>

          <!-- Sync Progress -->
          <div v-if="boxSyncStatus && boxSyncStatus.status && boxSyncStatus.status !== 'none' && boxSyncStatus.status !== 'completed'" class="mt-4">
            <div class="flex items-center justify-between text-sm mb-1">
              <span>{{ boxSyncStatus.current_file || 'Scanning...' }}</span>
              <span>{{ boxSyncStatus.progress_pct || 0 }}%</span>
            </div>
            <progress class="progress progress-primary w-full" :value="boxSyncStatus.progress_pct || 0" max="100"></progress>
          </div>

          <!-- Sync Results -->
          <div v-if="boxSyncStatus && boxSyncStatus.status === 'completed'" class="mt-4 flex gap-2 flex-wrap">
            <span class="badge badge-success gap-1">{{ boxSyncStatus.imported_files || 0 }} imported</span>
            <span v-if="boxSyncStatus.skipped_files" class="badge badge-warning gap-1">{{ boxSyncStatus.skipped_files }} skipped</span>
            <span v-if="boxSyncStatus.failed_files" class="badge badge-error gap-1">{{ boxSyncStatus.failed_files }} failed</span>
          </div>

          <!-- Sync Error -->
          <div v-if="boxSyncStatus && boxSyncStatus.status === 'failed'" class="mt-3 alert alert-error py-2">
            <span>{{ boxSyncStatus.error_message }}</span>
          </div>
        </div>
      </div>

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
            Upload Any File
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
      <!-- Duplicate Warning -->
      <div v-if="preview.duplicate_warning" class="alert alert-warning shadow-lg">
        <div>
          <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current flex-shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
          <span>{{ preview.duplicate_warning }}</span>
        </div>
        <div class="flex gap-2">
          <button class="btn btn-sm btn-ghost" @click="step = 'select'">Cancel</button>
          <button class="btn btn-sm btn-warning">Proceed Anyway</button>
        </div>
      </div>

      <!-- Detection Result -->
      <div class="alert alert-info">
        <span class="text-lg">{{ sourceIcon }}</span>
        <div>
          <p class="font-bold">Detected: {{ (preview.source && preview.source.source && preview.source.source.replace(/_/g, ' ')) || '' }}</p>
          <p class="text-sm">{{ (preview.source && preview.source.confidence) || 0 }}% confidence</p>
        </div>
      </div>

      <!-- Summary Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="stat bg-base-100 rounded-box shadow p-4">
          <div class="stat-title text-xs">Transactions</div>
          <div class="stat-value text-xl">{{ (preview.summary && preview.summary.transactions) || 0 }}</div>
        </div>
        <div class="stat bg-base-100 rounded-box shadow p-4">
          <div class="stat-title text-xs">Accounts</div>
          <div class="stat-value text-xl">{{ (preview.summary && preview.summary.accounts) || 0 }}</div>
        </div>
        <div class="stat bg-base-100 rounded-box shadow p-4">
          <div class="stat-title text-xs">Categories</div>
          <div class="stat-value text-xl">{{ (preview.summary && preview.summary.chart_of_accounts) || 0 }}</div>
        </div>
        <div class="stat bg-base-100 rounded-box shadow p-4">
          <div class="stat-title text-xs">Date Range</div>
          <div class="stat-value text-sm">
            {{ (preview.summary && preview.summary.date_range && preview.summary.date_range.from) || '' }} → {{ (preview.summary && preview.summary.date_range && preview.summary.date_range.to) || '' }}
          </div>
        </div>
      </div>

      <!-- Warnings -->
      <div v-if="(preview.warnings || []).length" class="space-y-2">
        <div v-for="(w, i) in preview.warnings" :key="i" class="alert alert-warning py-2">
          <span>{{ w }}</span>
        </div>
      </div>

      <!-- Category Mapping -->
      <div v-if="preview.category_mapping && Object.keys(preview.category_mapping).length" class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">Category Mapping</h2>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr><th>Your Old Category</th><th></th><th>ecfoBooks Category</th></tr>
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
      <div v-if="(preview.suggested_new_categories || []).length" class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <div class="flex justify-between items-center mb-4">
            <h2 class="card-title text-lg">New Categories to Create</h2>
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

      <!-- Editable Transaction Preview -->
      <div :class="['card bg-base-100 shadow-xl', boxEmbedUrl ? '' : '']">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">Transaction Preview (first 20)</h2>

          <div :class="boxEmbedUrl ? 'flex gap-4' : ''">
            <!-- Box PDF Preview (iframe) -->
            <div v-if="boxEmbedUrl" class="w-1/2 border rounded-lg overflow-hidden" style="min-height: 500px;">
              <iframe :src="boxEmbedUrl" class="w-full h-full" style="min-height: 500px;" frameborder="0"></iframe>
            </div>

            <!-- Editable Table -->
            <div :class="boxEmbedUrl ? 'w-1/2' : 'w-full'" class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Description</th>
                    <th>Category</th>
                    <th class="text-right">Amount</th>
                    <th class="w-8"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(txn, i) in editedTransactions" :key="i" class="hover">
                    <td class="text-sm whitespace-nowrap">{{ txn.date }}</td>
                    <td>
                      <input type="text" v-model="txn.description"
                        class="input input-bordered input-xs w-full max-w-xs" />
                    </td>
                    <td>
                      <div class="flex items-center gap-1">
                        <select v-model="txn.category" class="select select-bordered select-xs w-full max-w-[160px]">
                          <option value="">-- none --</option>
                          <option v-for="cat in companyCategories" :key="cat" :value="cat">{{ cat }}</option>
                        </select>
                        <button class="btn btn-ghost btn-xs" @click="suggestCategory(i)"
                          :disabled="txn._suggesting" title="AI suggest">
                          <span v-if="txn._suggesting" class="loading loading-spinner loading-xs"></span>
                          <span v-else class="text-xs">AI</span>
                        </button>
                      </div>
                    </td>
                    <td class="text-right">
                      <input type="number" v-model.number="txn.amount" step="0.01"
                        class="input input-bordered input-xs w-24 text-right font-mono" />
                    </td>
                    <td>
                      <span v-if="txn._edited" class="badge badge-xs badge-info">edited</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
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
            Import {{ (preview.summary && preview.summary.transactions) || 0 }} Transactions
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
          <div class="stat-value text-success">{{ (results && results.results && results.results.created && results.results.created.transactions) || 0 }}</div>
          <div class="stat-desc">transactions</div>
        </div>
        <div class="stat">
          <div class="stat-title">Duplicates Skipped</div>
          <div class="stat-value">{{ (results && results.results && results.results.skipped && results.results.skipped.duplicates) || 0 }}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Auto-Categorized</div>
          <div class="stat-value text-primary">{{ (results && results.auto_categorized) || 0 }}</div>
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
import { ref, computed, onMounted, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const companyId = () => appStore.activeCompany?.id || 1
const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)

const step = ref('select')
const formats = ref([])
const preview = ref({})
const results = ref(null)
const createNewCategories = ref(true)
const committing = ref(false)
const companyCategories = ref([])

// Editable transactions
const editedTransactions = ref([])

// Box.com state
const showBoxSettings = ref(false)
const boxConfig = ref(null)
const boxFolderUrl = ref('')
const boxToken = ref('')
const savingBoxConfig = ref(false)
const boxSyncing = ref(false)
const boxSyncStatus = ref(null)
const boxEmbedUrl = ref(null)
let boxPollTimer = null

const sourceIcon = computed(() => {
  const icons = { quickbooks_online: '📗', quickbooks_desktop: '📘', xero: '📋', freshbooks: '📒', wave: '🌊', ofx_qfx: '🏦', generic_csv: '📄' }
  const src = preview.value && preview.value.source && preview.value.source.source
  return icons[src] || '📁'
})

// Populate editedTransactions from preview
watch(() => preview.value.sample_transactions, (txns) => {
  if (txns && txns.length) {
    editedTransactions.value = txns.map((t, i) => ({
      index: i,
      date: t.date,
      description: t.description || t.merchant || '',
      category: t.category || '',
      amount: t.amount != null ? Number(t.amount) : 0,
      merchant: t.merchant || '',
      _suggesting: false,
      _edited: false
    }))
  }
}, { immediate: true })

// Track edits
watch(editedTransactions, (txns) => {
  const orig = (preview.value && preview.value.sample_transactions) || []
  txns.forEach((t, i) => {
    if (orig[i]) {
      t._edited = (t.description !== (orig[i].description || orig[i].merchant || '')) ||
                  (t.category !== (orig[i].category || '')) ||
                  (Number(t.amount) !== Number(orig[i].amount || 0))
    }
  })
}, { deep: true })

const selectSource = (fmt) => {
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = fmt.extensions.join(',')
  input.onchange = (e) => handleUpload(e)
  input.click()
}

const handleUpload = async (e) => {
  const files = e.target && e.target.files
  const file = files && files[0]
  if (!file) return

  step.value = 'processing'

  const form = new FormData()
  form.append('file', file)

  try {
    const result = await apiClient.upload(`/api/v1/companies/${companyId()}/imports/upload`, form)

    if (result && result.import_key) {
      preview.value = result
      step.value = 'preview'
    } else {
      alert((result && result.error) || 'Import failed')
      step.value = 'select'
    }
  } catch (err) {
    alert('Upload failed: ' + err.message)
    step.value = 'select'
  }
}

const suggestCategory = async (idx) => {
  const txn = editedTransactions.value[idx]
  if (!txn) return

  txn._suggesting = true
  try {
    const result = await apiClient.post(`/api/v1/companies/${companyId()}/imports/suggest_category`, {
      description: txn.description,
      amount: txn.amount,
      merchant: txn.merchant
    })
    if (result && result.suggested_category) {
      txn.category = result.suggested_category
      txn._edited = true
    }
  } catch (err) {
    console.error('Category suggestion failed:', err)
  }
  txn._suggesting = false
}

const commitImport = async () => {
  committing.value = true
  try {
    // Collect modified transactions
    const modified = editedTransactions.value
      .filter(t => t._edited)
      .map(t => ({
        index: t.index,
        description: t.description,
        amount: t.amount,
        category: t.category,
        mapped_category: t.category
      }))

    const result = await apiClient.post(`/api/v1/companies/${companyId()}/imports/commit`, {
      import_key: preview.value.import_key,
      create_new_categories: createNewCategories.value,
      modified_transactions: modified.length > 0 ? modified : undefined
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
  editedTransactions.value = []
  boxEmbedUrl.value = null
}

// --- Box.com methods ---

const loadBoxConfig = async () => {
  try {
    const data = await apiClient.get(`/api/v1/companies/${companyId()}/box/config`)
    boxConfig.value = data
    if (data) {
      boxFolderUrl.value = data.box_folder_url || ''
    }
  } catch (err) {
    console.error('Failed to load Box config:', err)
  }
}

const saveBoxConfig = async () => {
  savingBoxConfig.value = true
  try {
    await apiClient.put(`/api/v1/companies/${companyId()}/box/config`, {
      box_folder_url: boxFolderUrl.value,
      box_developer_token: boxToken.value || undefined
    })
    await loadBoxConfig()
    showBoxSettings.value = false
    boxToken.value = ''
  } catch (err) {
    alert('Failed to save Box config: ' + err.message)
  }
  savingBoxConfig.value = false
}

const triggerBoxSync = async () => {
  boxSyncing.value = true
  boxSyncStatus.value = null
  try {
    const result = await apiClient.post(`/api/v1/companies/${companyId()}/box/sync`, {})
    if (result && result.sync_job_id) {
      startPollingSyncStatus()
    }
  } catch (err) {
    alert('Box sync failed: ' + err.message)
    boxSyncing.value = false
  }
}

const startPollingSyncStatus = () => {
  if (boxPollTimer) clearInterval(boxPollTimer)
  boxPollTimer = setInterval(async () => {
    try {
      const status = await apiClient.get(`/api/v1/companies/${companyId()}/box/sync_status`)
      boxSyncStatus.value = status
      if (status && (status.status === 'completed' || status.status === 'failed')) {
        clearInterval(boxPollTimer)
        boxPollTimer = null
        boxSyncing.value = false
        if (status.status === 'completed') {
          await loadBoxConfig()
        }
      }
    } catch (err) {
      clearInterval(boxPollTimer)
      boxPollTimer = null
      boxSyncing.value = false
    }
  }, 2000)
}

const loadCategories = async () => {
  try {
    const data = await apiClient.get(`/api/v1/companies/${companyId()}/chart_of_accounts`)
    if (data && Array.isArray(data)) {
      companyCategories.value = data.filter(c => c.active !== false).map(c => c.name).sort()
    }
  } catch (err) {
    console.error('Failed to load categories:', err)
  }
}

onMounted(async () => {
  const data = await apiClient.get(`/api/v1/companies/${companyId()}/imports/supported`)
  formats.value = (data && data.formats) || []
  loadBoxConfig()
  loadCategories()
})
</script>
