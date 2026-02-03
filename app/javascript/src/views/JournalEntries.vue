<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Journal Entries</h1>
        <p class="text-base-content/60 mt-1">Adjustments, recurring entries, and the general journal</p>
      </div>
      <div class="flex gap-2">
        <button @click="showTemplates = true" class="btn btn-outline">📑 Templates</button>
        <button @click="openNewEntry()" class="btn btn-primary">+ New Entry</button>
      </div>
    </div>

    <!-- AI Suggestions Banner -->
    <div v-if="suggestions.length" class="card bg-gradient-to-r from-primary/10 to-secondary/10 shadow-xl mb-6">
      <div class="card-body">
        <div class="flex justify-between items-center mb-4">
          <div>
            <h2 class="card-title text-lg">🤖 AI Suggested Adjustments</h2>
            <p class="text-sm text-base-content/50">{{ suggestions.length }} suggestions · {{ highConfidence }} high confidence</p>
          </div>
          <div class="flex gap-2">
            <button @click="autoAdjust" class="btn btn-primary btn-sm" :disabled="autoAdjusting">
              <span v-if="autoAdjusting" class="loading loading-spinner loading-sm"></span>
              ✨ Create All ({{ highConfidence }})
            </button>
            <button @click="fetchSuggestions" class="btn btn-ghost btn-sm">🔄 Refresh</button>
          </div>
        </div>
        <div class="space-y-2 max-h-64 overflow-y-auto">
          <div v-for="(s, i) in suggestions" :key="i"
            class="flex items-start gap-3 p-3 rounded-lg bg-base-100/80 border">
            <div class="flex-1">
              <div class="flex items-center gap-2">
                <span :class="['badge badge-xs', s.confidence >= 80 ? 'badge-success' : s.confidence >= 60 ? 'badge-warning' : 'badge-ghost']">
                  {{ s.confidence }}%
                </span>
                <span class="badge badge-xs badge-outline">{{ s.type }}</span>
                <span class="font-medium text-sm">{{ s.memo }}</span>
              </div>
              <p class="text-xs text-base-content/50 mt-1">{{ s.reasoning }}</p>
            </div>
            <div class="text-right">
              <p class="font-mono font-bold text-sm">{{ formatCurrency(s.amount) }}</p>
              <button @click="createFromSuggestion(s)" class="btn btn-outline btn-xs mt-1">Create</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Filter Tabs -->
    <div class="tabs tabs-boxed mb-6 bg-base-200 inline-flex">
      <button :class="['tab', filter === 'all' ? 'tab-active' : '']" @click="filter = 'all'; fetchEntries()">All</button>
      <button :class="['tab', filter === 'adjusting' ? 'tab-active' : '']" @click="filter = 'adjusting'; fetchEntries()">Adjusting</button>
      <button :class="['tab', filter === 'recurring' ? 'tab-active' : '']" @click="filter = 'recurring'; fetchEntries()">Recurring</button>
      <button :class="['tab', filter === 'reversing' ? 'tab-active' : '']" @click="filter = 'reversing'; fetchEntries()">Reversing</button>
      <button :class="['tab', filter === 'depreciation' ? 'tab-active' : '']" @click="filter = 'depreciation'; fetchEntries()">Depreciation</button>
    </div>

    <!-- Entries List -->
    <div class="space-y-4">
      <div v-for="entry in entries" :key="entry.id" class="card bg-base-100 shadow-md">
        <div class="card-body p-4">
          <div class="flex justify-between items-start">
            <div>
              <div class="flex items-center gap-2">
                <span class="badge badge-sm" :class="typeBadge(entry.entry_type)">{{ entry.entry_type }}</span>
                <span v-if="entry.posted" class="badge badge-success badge-sm">Posted</span>
                <span v-else class="badge badge-warning badge-sm">Draft</span>
                <span v-if="entry.reversed" class="badge badge-error badge-sm">Reversed</span>
                <span v-if="entry.reference_number" class="text-xs text-base-content/40">#{{ entry.reference_number }}</span>
              </div>
              <p class="font-medium mt-1">{{ entry.memo }}</p>
              <p class="text-sm text-base-content/50">{{ entry.entry_date }}</p>
            </div>
            <div class="text-right">
              <p class="text-lg font-bold font-mono">{{ formatCurrency(entry.total_debits) }}</p>
              <div class="flex gap-1 mt-1">
                <button v-if="!entry.posted" @click="postEntry(entry)" class="btn btn-success btn-xs">Post</button>
                <button v-if="entry.posted && !entry.reversed" @click="reverseEntry(entry)" class="btn btn-outline btn-xs">↩️ Reverse</button>
                <button v-if="!entry.posted" @click="deleteEntry(entry)" class="btn btn-ghost btn-xs text-error">🗑️</button>
                <button v-if="canSeeComments" @click="toggleEntryComments(entry)" class="btn btn-ghost btn-xs gap-1">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
                  </svg>
                  Comments
                </button>
              </div>
            </div>
          </div>

          <!-- Journal Lines -->
          <div class="overflow-x-auto mt-3">
            <table class="table table-sm sm:table-md table-sm sm:table-md table-xs">
              <thead>
                <tr><th>Account</th><th class="text-right">Debit</th><th class="text-right">Credit</th><th>Memo</th></tr>
              </thead>
              <tbody>
                <tr v-for="line in entry.lines" :key="line.id">
                  <td class="text-sm" :class="line.credit > 0 ? 'pl-8' : ''">{{ line.account }}</td>
                  <td class="text-right font-mono text-sm">{{ line.debit > 0 ? formatCurrency(line.debit) : '' }}</td>
                  <td class="text-right font-mono text-sm">{{ line.credit > 0 ? formatCurrency(line.credit) : '' }}</td>
                  <td class="text-xs text-base-content/40">{{ line.memo }}</td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Inline Comments (internal only) -->
          <div v-if="canSeeComments && expandedCommentEntryId === entry.id" class="mt-4 pt-4 border-t border-base-200">
            <CommentThread
              commentable-type="journal_entry"
              :commentable-id="entry.id"
              :show-header="true"
              placeholder="Add a comment about this journal entry..."
            />
          </div>
        </div>
      </div>

      <div v-if="!entries.length" class="text-center py-12 text-base-content/50">
        <p class="text-4xl mb-2">📒</p>
        <p>No journal entries yet</p>
      </div>
    </div>

    <!-- New Entry Modal -->
    <dialog :class="['modal', showNewEntry ? 'modal-open' : '']">
      <div class="modal-box max-w-2xl w-full sm:w-auto">
        <h3 class="font-bold text-lg mb-4">{{ editingEntry ? 'Edit' : 'New' }} Journal Entry</h3>
        <form @submit.prevent="saveEntry">
          <div class="grid grid-cols-2 gap-4 mb-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Date</span></label>
              <input v-model="form.entry_date" type="date" class="input input-bordered" required />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Type</span></label>
              <select v-model="form.entry_type" class="select select-bordered">
                <option value="adjusting">Adjusting</option>
                <option value="standard">Standard</option>
                <option value="accrual">Accrual</option>
                <option value="depreciation">Depreciation</option>
                <option value="closing">Closing</option>
              </select>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4 mb-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Memo</span></label>
              <input v-model="form.memo" type="text" class="input input-bordered" placeholder="Description of entry" required />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Reference #</span></label>
              <input v-model="form.reference_number" type="text" class="input input-bordered" placeholder="Optional" />
            </div>
          </div>

          <!-- Journal Lines -->
          <div class="mb-4">
            <div class="flex justify-between items-center mb-2">
              <label class="label"><span class="label-text font-bold">Lines</span></label>
              <button type="button" @click="addLine" class="btn btn-ghost btn-xs">+ Add Line</button>
            </div>
            <div class="overflow-x-auto">
              <table class="table table-sm sm:table-md table-sm sm:table-md table-sm">
                <thead>
                  <tr>
                    <th>Account</th>
                    <th class="w-28">Debit</th>
                    <th class="w-28">Credit</th>
                    <th class="w-40">Memo</th>
                    <th class="w-8"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(line, i) in form.lines" :key="i">
                    <td>
                      <select v-model="line.chart_of_account_id" class="select select-bordered select-sm w-full">
                        <option value="">Select account</option>
                        <option v-for="coa in chartOfAccounts" :key="coa.id" :value="coa.id">
                          {{ coa.name }}
                        </option>
                      </select>
                    </td>
                    <td><input v-model.number="line.debit" type="number" step="0.01" min="0" class="input input-bordered input-sm w-full" @focus="line.credit = 0" /></td>
                    <td><input v-model.number="line.credit" type="number" step="0.01" min="0" class="input input-bordered input-sm w-full" @focus="line.debit = 0" /></td>
                    <td><input v-model="line.memo" type="text" class="input input-bordered input-sm w-full" /></td>
                    <td><button type="button" @click="form.lines.splice(i, 1)" class="btn btn-ghost btn-xs">✕</button></td>
                  </tr>
                </tbody>
                <tfoot>
                  <tr class="font-bold">
                    <td>Totals</td>
                    <td class="font-mono">{{ formatCurrency(totalDebits) }}</td>
                    <td class="font-mono">{{ formatCurrency(totalCredits) }}</td>
                    <td colspan="2">
                      <span v-if="isBalanced" class="text-success">✅ Balanced</span>
                      <span v-else class="text-error">⚠️ Off by {{ formatCurrency(Math.abs(totalDebits - totalCredits)) }}</span>
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <div class="modal-action">
            <button type="button" @click="showNewEntry = false" class="btn">Cancel</button>
            <button type="submit" class="btn btn-outline" :disabled="!isBalanced">Save as Draft</button>
            <button type="button" @click="saveAndPost" class="btn btn-primary" :disabled="!isBalanced">Save & Post</button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showNewEntry = false"><button>close</button></form>
    </dialog>

    <!-- Templates Modal -->
    <dialog :class="['modal', showTemplates ? 'modal-open' : '']">
      <div class="modal-box max-w-lg w-full sm:w-auto">
        <h3 class="font-bold text-lg mb-4">📑 Journal Entry Templates</h3>
        <div class="space-y-3">
          <div v-for="tmpl in templates" :key="tmpl.id"
            class="flex items-start gap-3 p-3 rounded-lg border hover:bg-base-200 cursor-pointer transition"
            @click="useTemplate(tmpl)">
            <span class="text-xl mt-1">{{ templateIcon(tmpl.entry_type) }}</span>
            <div>
              <p class="font-medium text-sm">{{ tmpl.name }}</p>
              <p class="text-xs text-base-content/50">{{ tmpl.description }}</p>
              <p class="text-xs text-base-content/40 mt-1">
                {{ (tmpl.lines || []).map(l => l.account_name || l.memo).join(' ↔ ') }}
              </p>
            </div>
          </div>
        </div>
        <div class="modal-action">
          <button @click="showTemplates = false" class="btn">Close</button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showTemplates = false"><button>close</button></form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
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
const companyId = () => appStore.activeCompany?.id || 1
const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)

const entries = ref([])
const chartOfAccounts = ref([])
const templates = ref([])
const filter = ref('all')
const showNewEntry = ref(false)
const showTemplates = ref(false)
const editingEntry = ref(null)
const suggestions = ref([])
const highConfidence = ref(0)
const autoAdjusting = ref(false)
const expandedCommentEntryId = ref(null)

const toggleEntryComments = (entry) => {
  expandedCommentEntryId.value = expandedCommentEntryId.value === entry.id ? null : entry.id
}

const form = ref({
  entry_date: new Date().toISOString().split('T')[0],
  entry_type: 'adjusting',
  memo: '',
  reference_number: '',
  lines: [
    { chart_of_account_id: '', debit: 0, credit: 0, memo: '' },
    { chart_of_account_id: '', debit: 0, credit: 0, memo: '' }
  ]
})

const totalDebits = computed(() => form.value.lines.reduce((s, l) => s + (l.debit || 0), 0))
const totalCredits = computed(() => form.value.lines.reduce((s, l) => s + (l.credit || 0), 0))
const isBalanced = computed(() => Math.abs(totalDebits.value - totalCredits.value) < 0.01 && totalDebits.value > 0)

const typeBadge = (t) => ({
  standard: 'badge-info', adjusting: 'badge-warning', closing: 'badge-error',
  reversing: 'badge-ghost', depreciation: 'badge-secondary', accrual: 'badge-accent'
}[t] || 'badge-ghost')

const templateIcon = (t) => ({
  adjusting: '🔧', depreciation: '📉', accrual: '⏰', standard: '📝', closing: '🔒'
}[t] || '📑')

const addLine = () => form.value.lines.push({ chart_of_account_id: '', debit: 0, credit: 0, memo: '' })

const openNewEntry = () => {
  editingEntry.value = null
  form.value = {
    entry_date: new Date().toISOString().split('T')[0],
    entry_type: 'adjusting',
    memo: '',
    reference_number: '',
    lines: [
      { chart_of_account_id: '', debit: 0, credit: 0, memo: '' },
      { chart_of_account_id: '', debit: 0, credit: 0, memo: '' }
    ]
  }
  showNewEntry.value = true
}

const saveEntry = async (posted = false) => {
  const payload = { ...form.value, posted }
  const result = await apiClient.post(`/api/v1/companies/${companyId()}/journal_entries`, payload)
  if (result?.id) {
    showNewEntry.value = false
    await fetchEntries()
  }
}

const saveAndPost = () => saveEntry(true)

const postEntry = async (entry) => {
  await apiClient.post(`/api/v1/companies/${companyId()}/journal_entries/${entry.id}/post`)
  await fetchEntries()
}

const reverseEntry = async (entry) => {
  if (!confirm(`Reverse entry "${entry.memo}" for ${formatCurrency(entry.total_debits)}?`)) return
  await apiClient.post(`/api/v1/companies/${companyId()}/journal_entries/${entry.id}/reverse`)
  await fetchEntries()
}

const deleteEntry = async (entry) => {
  if (!confirm('Delete this draft entry?')) return
  await apiClient.delete(`/api/v1/companies/${companyId()}/journal_entries/${entry.id}`)
  entries.value = entries.value.filter(e => e.id !== entry.id)
}

const useTemplate = (tmpl) => {
  const amount = parseFloat(prompt(`Enter amount for "${tmpl.name}":`) || '0')
  if (!amount) return

  form.value = {
    entry_date: new Date().toISOString().split('T')[0],
    entry_type: tmpl.entry_type,
    memo: tmpl.name,
    reference_number: '',
    lines: (tmpl.lines || []).map(l => ({
      chart_of_account_id: l.chart_of_account_id || '',
      debit: l.side === 'debit' ? amount : 0,
      credit: l.side === 'credit' ? amount : 0,
      memo: l.memo || ''
    }))
  }
  showTemplates.value = false
  showNewEntry.value = true
}

const fetchSuggestions = async () => {
  const data = await apiClient.get(`/api/v1/companies/${companyId()}/journal_entries/suggestions`)
  if (data) {
    suggestions.value = data.suggestions || []
    highConfidence.value = data.high_confidence || 0
  }
}

const autoAdjust = async () => {
  autoAdjusting.value = true
  const result = await apiClient.post(`/api/v1/companies/${companyId()}/journal_entries/auto_adjust`)
  if (result?.created) {
    alert(`✅ Created ${result.created.length} adjusting entries as drafts. Review and post them.`)
    suggestions.value = []
    await fetchEntries()
  }
  autoAdjusting.value = false
}

const createFromSuggestion = async (s) => {
  const result = await apiClient.post(`/api/v1/companies/${companyId()}/journal_entries/create_from_suggestion`, s)
  if (result?.id) {
    suggestions.value = suggestions.value.filter(x => x !== s)
    await fetchEntries()
  }
}

const fetchEntries = async () => {
  const params = filter.value !== 'all' ? `?type=${filter.value}` : ''
  entries.value = await apiClient.get(`/api/v1/companies/${companyId()}/journal_entries${params}`) || []
}

onMounted(async () => {
  const [e, coa, t] = await Promise.all([
    apiClient.get(`/api/v1/companies/${companyId()}/journal_entries`),
    apiClient.get(`/api/v1/companies/${companyId()}/chart_of_accounts`),
    apiClient.get(`/api/v1/companies/${companyId()}/journal_entries/templates`)
  ])
  entries.value = e || []
  chartOfAccounts.value = coa || []
  templates.value = t || []
  
  // Fetch AI suggestions
  fetchSuggestions()
})
</script>
