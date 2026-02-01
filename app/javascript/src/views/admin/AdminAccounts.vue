<template>
  <div>
    <div class="flex justify-between items-center mb-8">
      <div>
        <h1 class="text-3xl font-bold">Account Management</h1>
        <p class="text-base-content/60 mt-1">Manage financial accounts across households</p>
      </div>
      <button @click="openModal()" class="btn btn-primary gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        Add Account
      </button>
    </div>

    <!-- Filters -->
    <div class="flex gap-4 mb-6">
      <select v-model="householdFilter" class="select select-bordered select-sm">
        <option value="">All Households</option>
        <option v-for="h in households" :key="h.id" :value="h.id">{{ h.name }}</option>
      </select>
      <select v-model="typeFilter" class="select select-bordered select-sm">
        <option value="">All Types</option>
        <option v-for="t in accountTypes" :key="t" :value="t">{{ capitalize(t) }}</option>
      </select>
      <input v-model="search" type="text" placeholder="Search..." class="input input-bordered input-sm flex-1" />
    </div>

    <!-- Accounts Table -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Account Name</th>
                <th>Institution</th>
                <th>Type</th>
                <th>Mask</th>
                <th>Household</th>
                <th>Status</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="account in filteredAccounts" :key="account.id" class="hover">
                <td class="font-medium">{{ account.name }}</td>
                <td>{{ account.institution || '—' }}</td>
                <td><span class="badge badge-sm badge-outline">{{ account.account_type }}</span></td>
                <td class="font-mono text-sm">{{ account.mask ? `****${account.mask}` : '—' }}</td>
                <td>{{ account.household_name || '—' }}</td>
                <td>
                  <input 
                    type="checkbox" 
                    :checked="account.active" 
                    @change="toggleActive(account)"
                    class="toggle toggle-sm toggle-success" 
                  />
                </td>
                <td class="text-right">
                  <button @click="openModal(account)" class="btn btn-ghost btn-xs">Edit</button>
                  <button @click="deleteAccount(account)" class="btn btn-ghost btn-xs text-error">Delete</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <dialog :class="['modal', showModal ? 'modal-open' : '']">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">{{ editing ? 'Edit Account' : 'New Account' }}</h3>
        <form @submit.prevent="saveAccount">
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Household</span></label>
            <select v-model="form.household_id" class="select select-bordered" required>
              <option value="">Select household...</option>
              <option v-for="h in households" :key="h.id" :value="h.id">{{ h.name }}</option>
            </select>
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Account Name</span></label>
            <input v-model="form.name" type="text" class="input input-bordered" required />
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Institution</span></label>
            <input v-model="form.institution" type="text" class="input input-bordered" />
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Account Type</span></label>
            <select v-model="form.account_type" class="select select-bordered">
              <option v-for="t in accountTypes" :key="t" :value="t">{{ capitalize(t) }}</option>
            </select>
          </div>
          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Mask (last 4 digits)</span></label>
            <input v-model="form.mask" type="text" class="input input-bordered" maxlength="4" />
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
import { apiClient } from '../../api/client'

const accounts = ref([])
const households = ref([])
const householdFilter = ref('')
const typeFilter = ref('')
const search = ref('')
const showModal = ref(false)
const editing = ref(null)
const accountTypes = ['checking', 'savings', 'credit', 'investment', 'loan', 'other']
const form = ref({ name: '', institution: '', account_type: 'checking', mask: '', household_id: '' })

const capitalize = (s) => s ? s.charAt(0).toUpperCase() + s.slice(1) : ''

const filteredAccounts = computed(() => {
  let list = accounts.value
  if (householdFilter.value) list = list.filter(a => a.household_id == householdFilter.value)
  if (typeFilter.value) list = list.filter(a => a.account_type === typeFilter.value)
  if (search.value) {
    const s = search.value.toLowerCase()
    list = list.filter(a => a.name.toLowerCase().includes(s) || a.institution?.toLowerCase().includes(s))
  }
  return list
})

const openModal = (account = null) => {
  editing.value = account
  form.value = account 
    ? { ...account } 
    : { name: '', institution: '', account_type: 'checking', mask: '', household_id: '' }
  showModal.value = true
}

const saveAccount = async () => {
  if (editing.value) {
    await apiClient.put(`/api/v1/admin/accounts/${editing.value.id}`, { account: form.value })
  } else {
    await apiClient.post('/api/v1/admin/accounts', { account: form.value })
  }
  showModal.value = false
  await fetchAccounts()
}

const toggleActive = async (account) => {
  await apiClient.put(`/api/v1/admin/accounts/${account.id}`, { account: { active: !account.active } })
  await fetchAccounts()
}

const deleteAccount = async (account) => {
  if (confirm(`Delete account "${account.name}"?`)) {
    await apiClient.delete(`/api/v1/admin/accounts/${account.id}`)
    await fetchAccounts()
  }
}

const fetchAccounts = async () => {
  accounts.value = await apiClient.get('/api/v1/admin/accounts') || []
}

onMounted(async () => {
  await fetchAccounts()
  households.value = await apiClient.get('/api/v1/admin/households') || []
})
</script>
