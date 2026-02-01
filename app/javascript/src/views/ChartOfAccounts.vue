<template>
  <div>
    <div class="flex justify-between items-center mb-8">
      <div>
        <h1 class="text-3xl font-bold">Chart of Accounts</h1>
        <p class="text-base-content/60 mt-1">Manage your account structure</p>
      </div>
      <button @click="showAddModal = true" class="btn btn-primary gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        Add Account
      </button>
    </div>

    <!-- Filter by type -->
    <div class="tabs tabs-boxed mb-6">
      <a 
        v-for="type in accountTypes" 
        :key="type"
        @click="filterType = type"
        :class="['tab', filterType === type ? 'tab-active' : '']"
      >
        {{ type === 'all' ? 'All' : capitalize(type) }}
      </a>
    </div>

    <!-- Accounts Table -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Code</th>
                <th>Name</th>
                <th>Type</th>
                <th>Status</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="account in filteredAccounts" :key="account.id">
                <td class="font-mono">{{ account.code }}</td>
                <td class="font-medium">{{ account.name }}</td>
                <td>
                  <span :class="['badge', typeBadgeClass(account.account_type)]">
                    {{ capitalize(account.account_type) }}
                  </span>
                </td>
                <td>
                  <span :class="['badge', account.active ? 'badge-success' : 'badge-ghost']">
                    {{ account.active ? 'Active' : 'Inactive' }}
                  </span>
                </td>
                <td class="text-right">
                  <button @click="editAccount(account)" class="btn btn-ghost btn-xs">Edit</button>
                  <button @click="toggleActive(account)" class="btn btn-ghost btn-xs">
                    {{ account.active ? 'Deactivate' : 'Activate' }}
                  </button>
                </td>
              </tr>
              <tr v-if="filteredAccounts.length === 0">
                <td colspan="5" class="text-center py-8 text-base-content/50">
                  No accounts found. Add your first account to get started.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <dialog :class="['modal', showAddModal ? 'modal-open' : '']">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">{{ editingAccount ? 'Edit Account' : 'New Account' }}</h3>
        <form @submit.prevent="saveAccount">
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Code</span></label>
            <input v-model="form.code" type="text" class="input input-bordered" required />
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Name</span></label>
            <input v-model="form.name" type="text" class="input input-bordered" required />
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Type</span></label>
            <select v-model="form.account_type" class="select select-bordered">
              <option value="asset">Asset</option>
              <option value="liability">Liability</option>
              <option value="equity">Equity</option>
              <option value="income">Income</option>
              <option value="expense">Expense</option>
            </select>
          </div>
          <div class="modal-action">
            <button type="button" @click="closeModal" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="closeModal">
        <button>close</button>
      </form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const filterType = ref('all')
const showAddModal = ref(false)
const editingAccount = ref(null)
const form = ref({ code: '', name: '', account_type: 'expense' })

const accountTypes = ['all', 'asset', 'liability', 'equity', 'income', 'expense']

const filteredAccounts = computed(() => {
  if (filterType.value === 'all') return appStore.chartOfAccounts
  return appStore.chartOfAccounts.filter(a => a.account_type === filterType.value)
})

const capitalize = (str) => str.charAt(0).toUpperCase() + str.slice(1)

const typeBadgeClass = (type) => ({
  asset: 'badge-success',
  liability: 'badge-error',
  equity: 'badge-info',
  income: 'badge-primary',
  expense: 'badge-warning'
}[type] || 'badge-ghost')

const editAccount = (account) => {
  editingAccount.value = account
  form.value = { ...account }
  showAddModal.value = true
}

const closeModal = () => {
  showAddModal.value = false
  editingAccount.value = null
  form.value = { code: '', name: '', account_type: 'expense' }
}

const saveAccount = async () => {
  const companyId = appStore.currentCompany?.id || 1
  if (editingAccount.value) {
    await apiClient.put(`/api/v1/companies/${companyId}/chart_of_accounts/${editingAccount.value.id}`, form.value)
  } else {
    await apiClient.post(`/api/v1/companies/${companyId}/chart_of_accounts`, form.value)
  }
  closeModal()
  await appStore.fetchChartOfAccounts(companyId)
}

const toggleActive = async (account) => {
  const companyId = appStore.currentCompany?.id || 1
  await apiClient.put(`/api/v1/companies/${companyId}/chart_of_accounts/${account.id}`, { active: !account.active })
  await appStore.fetchChartOfAccounts(companyId)
}

onMounted(async () => {
  const companyId = appStore.currentCompany?.id || 1
  await appStore.fetchChartOfAccounts(companyId)
})
</script>
