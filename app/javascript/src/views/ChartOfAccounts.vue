<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Chart of Accounts</h1>
        <p class="text-base-content/60 mt-1">{{ accounts.length }} accounts</p>
      </div>
      <div class="flex gap-2">
        <a :href="`/api/v1/companies/${companyId}/exports/chart_of_accounts`" class="btn btn-outline btn-sm gap-1">📥 CSV</a>
        <button @click="showSuggestPanel = !showSuggestPanel" :class="['btn btn-sm gap-1', showSuggestPanel ? 'btn-secondary' : 'btn-outline btn-secondary']">
          🤖 AI Suggest
        </button>
        <button @click="openModal()" class="btn btn-primary btn-sm gap-1">+ New Account</button>
      </div>
    </div>

    <!-- AI Suggest Panel -->
    <div v-if="showSuggestPanel" class="card bg-base-100 shadow-xl mb-6">
      <div class="card-body">
        <h2 class="card-title text-lg">🤖 AI Chart of Accounts Suggestions</h2>
        <p class="text-sm text-base-content/60 mb-3">
          Describe your business and AI will suggest industry-specific accounts to add.
        </p>
        <div class="flex gap-3">
          <input v-model="suggestDescription" type="text" class="input input-bordered flex-1"
            placeholder="e.g. SaaS startup, restaurant, real estate rental company, law firm, e-commerce store..."
            @keyup.enter="fetchSuggestions" />
          <button @click="fetchSuggestions" class="btn btn-secondary" :disabled="suggestLoading || !suggestDescription.trim()">
            <span v-if="suggestLoading" class="loading loading-spinner loading-sm"></span>
            <span v-else>Suggest</span>
          </button>
        </div>

        <div v-if="suggestedAccounts.length" class="mt-4">
          <div class="flex justify-between items-center mb-3">
            <span class="font-medium">{{ suggestedAccounts.length }} suggestions</span>
            <div class="flex gap-2">
              <button @click="toggleAllSuggestions" class="btn btn-ghost btn-xs">
                {{ allSuggestionsSelected ? 'Deselect All' : 'Select All' }}
              </button>
              <button @click="addSelectedSuggestions" class="btn btn-primary btn-sm" :disabled="selectedSuggestions.size === 0">
                Add {{ selectedSuggestions.size }} Selected
              </button>
            </div>
          </div>
          <div class="space-y-2">
            <div v-for="s in suggestedAccounts" :key="s.code"
              :class="['flex items-center gap-3 p-3 rounded-lg border', selectedSuggestions.has(s.code) ? 'border-primary bg-primary/5' : 'border-base-300']">
              <input type="checkbox" class="checkbox checkbox-sm checkbox-primary"
                :checked="selectedSuggestions.has(s.code)" @change="toggleSuggestion(s.code)" />
              <span class="font-mono text-sm w-14">{{ s.code }}</span>
              <span class="badge badge-sm badge-outline capitalize">{{ s.account_type }}</span>
              <span class="font-medium flex-1">{{ s.name }}</span>
              <span class="text-xs text-base-content/50 max-w-xs hidden md:inline">{{ s.reason }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Type Tabs -->
    <div class="tabs tabs-boxed mb-6">
      <a :class="['tab', activeType === 'all' ? 'tab-active' : '']" @click="activeType = 'all'">All</a>
      <a v-for="t in types" :key="t" :class="['tab', activeType === t ? 'tab-active' : '']" @click="activeType = t">
        {{ t.charAt(0).toUpperCase() + t.slice(1) }}
        <span class="badge badge-sm ml-1">{{ countByType(t) }}</span>
      </a>
    </div>

    <!-- Accounts by Type -->
    <div v-for="type in visibleTypes" :key="type" class="card bg-base-100 shadow mb-6">
      <div class="card-body">
        <h2 class="card-title capitalize">{{ type }}</h2>
        <div class="overflow-x-auto">
          <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
            <thead>
              <tr>
                <th>Code</th>
                <th>Name</th>
                <th class="text-right">Transactions</th>
                <th>Active</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="acct in accountsByType(type)" :key="acct.id" class="hover">
                <td class="font-mono text-sm">{{ acct.code }}</td>
                <td class="font-medium">{{ acct.name }}</td>
                <td class="text-right font-mono text-sm">{{ acct.transactions_count }}</td>
                <td>
                  <span :class="['badge badge-xs', acct.active ? 'badge-success' : 'badge-error']">
                    {{ acct.active ? 'Active' : 'Inactive' }}
                  </span>
                </td>
                <td class="text-right">
                  <button @click="openModal(acct)" class="btn btn-ghost btn-xs">Edit</button>
                  <button v-if="acct.transactions_count === 0" @click="deleteAccount(acct)" class="btn btn-ghost btn-xs text-error">Delete</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <dialog :class="['modal', showModal ? 'modal-open' : '']">
      <div class="modal-box w-[95vw] sm:w-auto max-h-[90vh]">
        <h3 class="font-bold text-lg mb-4">{{ editing ? 'Edit Account' : 'New Account' }}</h3>
        <form @submit.prevent="saveAccount">
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Code</span></label>
            <input v-model="form.code" type="text" class="input input-bordered" placeholder="e.g. 4010" />
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Name</span></label>
            <input v-model="form.name" type="text" class="input input-bordered" placeholder="e.g. Office Supplies" required />
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Type</span></label>
            <select v-model="form.account_type" class="select select-bordered" required>
              <option value="">Select type...</option>
              <option v-for="t in types" :key="t" :value="t">{{ t }}</option>
            </select>
          </div>
          <div class="form-control mb-3">
            <label class="label cursor-pointer">
              <span class="label-text">Active</span>
              <input type="checkbox" v-model="form.active" class="toggle toggle-success" />
            </label>
          </div>
          <div class="modal-action">
            <button type="button" @click="showModal = false" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showModal = false"><button>close</button></form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const accounts = ref([])
const showModal = ref(false)
const editing = ref(null)
const activeType = ref('all')
const form = ref({ code: '', name: '', account_type: 'expense', active: true })

const types = ['income', 'expense', 'asset', 'liability', 'equity']
const companyId = computed(() => appStore.activeCompany?.id || 1)

const countByType = (type) => accounts.value.filter(a => a.account_type === type).length
const accountsByType = (type) => accounts.value.filter(a => a.account_type === type).sort((a, b) => (a.code || '').localeCompare(b.code || ''))

const visibleTypes = computed(() => {
  if (activeType.value === 'all') return types.filter(t => countByType(t) > 0 || t === 'income' || t === 'expense')
  return [activeType.value]
})

const openModal = (acct = null) => {
  editing.value = acct
  form.value = acct ? { ...acct } : { code: '', name: '', account_type: 'expense', active: true }
  showModal.value = true
}

const saveAccount = async () => {
  const cid = companyId.value
  if (editing.value) {
    await apiClient.put(`/api/v1/companies/${cid}/chart_of_accounts/${editing.value.id}`, { chart_of_account: form.value })
  } else {
    await apiClient.post(`/api/v1/companies/${cid}/chart_of_accounts`, { chart_of_account: form.value })
  }
  showModal.value = false
  await fetchAccounts()
}

const deleteAccount = async (acct) => {
  if (!confirm(`Delete "${acct.name}"?`)) return
  await apiClient.delete(`/api/v1/companies/${companyId.value}/chart_of_accounts/${acct.id}`)
  await fetchAccounts()
}

const fetchAccounts = async () => {
  accounts.value = await apiClient.get(`/api/v1/companies/${companyId.value}/chart_of_accounts`) || []
}

// AI Suggestions
const showSuggestPanel = ref(false)
const suggestDescription = ref('')
const suggestLoading = ref(false)
const suggestedAccounts = ref([])
const selectedSuggestions = ref(new Set())

const allSuggestionsSelected = computed(() =>
  suggestedAccounts.value.length > 0 && suggestedAccounts.value.every(s => selectedSuggestions.value.has(s.code))
)

const fetchSuggestions = async () => {
  if (!suggestDescription.value.trim()) return
  suggestLoading.value = true
  suggestedAccounts.value = []
  selectedSuggestions.value = new Set()

  try {
    const data = await apiClient.post(`/api/v1/companies/${companyId.value}/chart_of_accounts/suggest`, {
      description: suggestDescription.value
    })
    suggestedAccounts.value = data?.suggestions || []
    selectedSuggestions.value = new Set(suggestedAccounts.value.map(s => s.code))
  } catch (e) {
    suggestedAccounts.value = []
  } finally {
    suggestLoading.value = false
  }
}

const toggleSuggestion = (code) => {
  const s = new Set(selectedSuggestions.value)
  s.has(code) ? s.delete(code) : s.add(code)
  selectedSuggestions.value = s
}

const toggleAllSuggestions = () => {
  if (allSuggestionsSelected.value) {
    selectedSuggestions.value = new Set()
  } else {
    selectedSuggestions.value = new Set(suggestedAccounts.value.map(s => s.code))
  }
}

const addSelectedSuggestions = async () => {
  const cid = companyId.value
  const toAdd = suggestedAccounts.value.filter(s => selectedSuggestions.value.has(s.code))

  for (const s of toAdd) {
    await apiClient.post(`/api/v1/companies/${cid}/chart_of_accounts`, {
      chart_of_account: { code: s.code, name: s.name, account_type: s.account_type, active: true }
    })
  }

  suggestedAccounts.value = suggestedAccounts.value.filter(s => !selectedSuggestions.value.has(s.code))
  selectedSuggestions.value = new Set()
  await fetchAccounts()
}

onMounted(fetchAccounts)
</script>
