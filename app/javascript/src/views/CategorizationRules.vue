<template>
  <div>
    <div class="flex justify-between items-center mb-8">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Categorization Rules</h1>
        <p class="text-base-content/60 mt-1">Auto-categorize transactions based on patterns</p>
      </div>
      <div class="flex gap-2">
        <button @click="runRules" class="btn btn-secondary gap-2" :disabled="running">
          <span v-if="running" class="loading loading-spinner loading-sm"></span>
          ⚡ Run Rules
        </button>
        <button @click="openModal()" class="btn btn-primary gap-2">+ New Rule</button>
      </div>
    </div>

    <!-- Suggestions -->
    <div v-if="suggestions.length > 0" class="card bg-base-100 shadow-xl mb-6">
      <div class="card-body">
        <h2 class="card-title">💡 Suggested Rules</h2>
        <p class="text-sm text-base-content/60 mb-4">Based on your existing categorizations</p>
        <div class="space-y-2">
          <div v-for="s in suggestions" :key="s.match_value" class="flex items-center justify-between bg-base-200 rounded-lg p-3">
            <div>
              <span class="font-medium">{{ s.match_value }}</span>
              <span class="text-base-content/60"> → </span>
              <span class="badge badge-sm badge-primary">{{ s.chart_of_account_name }}</span>
              <span class="text-xs text-base-content/40 ml-2">({{ s.occurrences }} matches, {{ s.confidence }}% confidence)</span>
            </div>
            <button @click="acceptSuggestion(s)" class="btn btn-success btn-sm">Accept</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Active Rules -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <div class="overflow-x-auto">
          <table class="table table-sm sm:table-md table-sm sm:table-md">
            <thead>
              <tr>
                <th>Match Field</th>
                <th>Type</th>
                <th>Pattern</th>
                <th>Category</th>
                <th>Applied</th>
                <th>Status</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="rule in rules" :key="rule.id" class="hover">
                <td><span class="badge badge-sm badge-outline">{{ rule.match_field }}</span></td>
                <td class="text-sm">{{ rule.match_type }}</td>
                <td class="font-mono text-sm">{{ rule.match_value }}</td>
                <td><span class="badge badge-sm badge-primary">{{ rule.chart_of_account_name }}</span></td>
                <td class="font-mono text-sm">{{ rule.times_applied }}×</td>
                <td>
                  <input type="checkbox" :checked="rule.active" @change="toggleRule(rule)" class="toggle toggle-sm toggle-success" />
                </td>
                <td class="text-right">
                  <button @click="openModal(rule)" class="btn btn-ghost btn-xs">Edit</button>
                  <button @click="deleteRule(rule)" class="btn btn-ghost btn-xs text-error">Delete</button>
                </td>
              </tr>
              <tr v-if="rules.length === 0">
                <td colspan="7" class="text-center py-8 text-base-content/50">
                  No rules yet. Create rules to auto-categorize your transactions.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <dialog :class="['modal', showModal ? 'modal-open' : '']">
      <div class="modal-box w-[95vw] sm:w-auto max-h-[90vh]">
        <h3 class="font-bold text-lg mb-4">{{ editing ? 'Edit Rule' : 'New Rule' }}</h3>
        <form @submit.prevent="saveRule">
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">When</span></label>
            <select v-model="form.match_field" class="select select-bordered">
              <option value="description">Description</option>
              <option value="merchant_name">Merchant Name</option>
              <option value="category">Plaid Category</option>
            </select>
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Match Type</span></label>
            <select v-model="form.match_type" class="select select-bordered">
              <option value="contains">Contains</option>
              <option value="exact">Exact Match</option>
              <option value="starts_with">Starts With</option>
              <option value="regex">Regex</option>
            </select>
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Pattern</span></label>
            <input v-model="form.match_value" type="text" class="input input-bordered" placeholder="e.g. STARBUCKS" required />
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Assign to Category</span></label>
            <select v-model="form.chart_of_account_id" class="select select-bordered" required>
              <option value="">Select category...</option>
              <option v-for="coa in chartOfAccounts" :key="coa.id" :value="coa.id">
                {{ coa.name }} ({{ coa.account_type }})
              </option>
            </select>
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Priority (higher = first)</span></label>
            <input v-model.number="form.priority" type="number" class="input input-bordered" />
          </div>
          <div class="modal-action">
            <button type="button" @click="showModal = false" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showModal = false"><button>close</button></form>
    </dialog>

    <!-- Toast -->
    <div v-if="toast" class="toast toast-end">
      <div :class="['alert', toast.type === 'success' ? 'alert-success' : 'alert-info']">
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
const rules = ref([])
const suggestions = ref([])
const chartOfAccounts = ref([])
const showModal = ref(false)
const editing = ref(null)
const running = ref(false)
const toast = ref(null)
const form = ref({ match_field: 'description', match_type: 'contains', match_value: '', chart_of_account_id: '', priority: 0 })

const companyId = () => appStore.activeCompany?.id || 1

const showToast = (message, type = 'success') => {
  toast.value = { message, type }
  setTimeout(() => toast.value = null, 3000)
}

const openModal = (rule = null) => {
  editing.value = rule
  form.value = rule ? { ...rule } : { match_field: 'description', match_type: 'contains', match_value: '', chart_of_account_id: '', priority: 0 }
  showModal.value = true
}

const saveRule = async () => {
  const cid = companyId()
  if (editing.value) {
    await apiClient.put(`/api/v1/companies/${cid}/categorization_rules/${editing.value.id}`, { categorization_rule: form.value })
  } else {
    await apiClient.post(`/api/v1/companies/${cid}/categorization_rules`, { categorization_rule: form.value })
  }
  showModal.value = false
  await fetchRules()
}

const deleteRule = async (rule) => {
  if (!confirm('Delete this rule?')) return
  await apiClient.delete(`/api/v1/companies/${companyId()}/categorization_rules/${rule.id}`)
  await fetchRules()
}

const toggleRule = async (rule) => {
  await apiClient.put(`/api/v1/companies/${companyId()}/categorization_rules/${rule.id}`, { categorization_rule: { active: !rule.active } })
  await fetchRules()
}

const runRules = async () => {
  running.value = true
  const result = await apiClient.post(`/api/v1/companies/${companyId()}/categorization_rules/run`)
  showToast(`${result?.categorized || 0} transactions categorized`)
  running.value = false
}

const acceptSuggestion = async (s) => {
  await apiClient.post(`/api/v1/companies/${companyId()}/categorization_rules`, {
    categorization_rule: {
      match_field: s.match_field,
      match_type: s.match_type,
      match_value: s.match_value.toLowerCase(),
      chart_of_account_id: s.chart_of_account_id,
      priority: 0
    }
  })
  showToast('Rule created from suggestion')
  await fetchRules()
  await fetchSuggestions()
}

const fetchRules = async () => {
  rules.value = await apiClient.get(`/api/v1/companies/${companyId()}/categorization_rules`) || []
}

const fetchSuggestions = async () => {
  suggestions.value = await apiClient.get(`/api/v1/companies/${companyId()}/categorization_rules/suggestions`) || []
}

onMounted(async () => {
  await fetchRules()
  await fetchSuggestions()
  chartOfAccounts.value = await apiClient.get(`/api/v1/companies/${companyId()}/chart_of_accounts`) || []
})
</script>
