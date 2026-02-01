<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-3xl font-bold">Companies</h1>
      <button @click="openModal()" class="btn btn-primary btn-sm gap-1">+ New Company</button>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div v-for="company in companies" :key="company.id" class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">{{ company.name }}</h2>
          <div class="space-y-1 text-sm text-base-content/60">
            <p>👥 {{ company.members_count || 0 }} members</p>
            <p>🏦 {{ company.accounts_count || 0 }} accounts</p>
            <p>💳 {{ company.transactions_count || 0 }} transactions</p>
          </div>
          <div class="card-actions justify-end mt-4">
            <button @click="manageMembers(company)" class="btn btn-outline btn-xs">Members</button>
            <button @click="openModal(company)" class="btn btn-ghost btn-xs">Edit</button>
            <button @click="deleteCompany(company)" class="btn btn-ghost btn-xs text-error">Delete</button>
          </div>
        </div>
      </div>

      <!-- Empty State -->
      <div v-if="companies.length === 0" class="col-span-full text-center py-16">
        <div class="text-5xl mb-4">🏢</div>
        <h3 class="text-xl font-bold mb-2">No companies yet</h3>
        <p class="text-base-content/60 mb-4">Create your first company to start tracking finances</p>
        <button @click="openModal()" class="btn btn-primary">Create Company</button>
      </div>
    </div>

    <!-- Company Modal -->
    <dialog :class="['modal', showModal ? 'modal-open' : '']">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">{{ editing ? 'Edit Company' : 'New Company' }}</h3>
        <form @submit.prevent="saveCompany">
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Name</span></label>
            <input v-model="form.name" type="text" class="input input-bordered" required />
          </div>
          <div class="modal-action">
            <button type="button" @click="showModal = false" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showModal = false"><button>close</button></form>
    </dialog>

    <!-- Members Modal -->
    <dialog :class="['modal', showMembers ? 'modal-open' : '']">
      <div class="modal-box max-w-2xl">
        <h3 class="font-bold text-lg mb-4">{{ selectedCompany?.name }} — Members</h3>
        
        <!-- Add member -->
        <div class="flex gap-2 mb-4">
          <select v-model="newMember.user_id" class="select select-bordered select-sm flex-1">
            <option value="">Select user...</option>
            <option v-for="u in availableUsers" :key="u.id" :value="u.id">{{ u.first_name }} {{ u.last_name }} ({{ u.email }})</option>
          </select>
          <select v-model="newMember.role" class="select select-bordered select-sm">
            <option value="viewer">Viewer</option>
            <option value="client">Client</option>
            <option value="advisor">Advisor</option>
          </select>
          <button @click="addMember" class="btn btn-primary btn-sm" :disabled="!newMember.user_id">Add</button>
        </div>

        <!-- Current members -->
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Name</th>
              <th>Role</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="m in members" :key="m.user_id">
              <td>{{ m.first_name }} {{ m.last_name }}</td>
              <td>
                <select :value="m.role" @change="updateMemberRole(m, $event.target.value)" class="select select-bordered select-xs">
                  <option value="viewer">Viewer</option>
                  <option value="client">Client</option>
                  <option value="advisor">Advisor</option>
                </select>
              </td>
              <td class="text-right">
                <button @click="removeMember(m)" class="btn btn-ghost btn-xs text-error">Remove</button>
              </td>
            </tr>
          </tbody>
        </table>

        <div class="modal-action">
          <button @click="showMembers = false" class="btn">Close</button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showMembers = false"><button>close</button></form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { apiClient } from '../../api/client'

const companies = ref([])
const allUsers = ref([])
const members = ref([])
const showModal = ref(false)
const showMembers = ref(false)
const editing = ref(null)
const selectedCompany = ref(null)
const form = ref({ name: '' })
const newMember = ref({ user_id: '', role: 'client' })

const availableUsers = computed(() => {
  const memberIds = new Set(members.value.map(m => m.user_id))
  return allUsers.value.filter(u => !memberIds.has(u.id))
})

const openModal = (company = null) => {
  editing.value = company
  form.value = company ? { name: company.name } : { name: '' }
  showModal.value = true
}

const saveCompany = async () => {
  if (editing.value) {
    await apiClient.put(`/api/v1/admin/companies/${editing.value.id}`, { company: form.value })
  } else {
    await apiClient.post('/api/v1/admin/companies', { company: form.value })
  }
  showModal.value = false
  await fetchCompanies()
}

const deleteCompany = async (company) => {
  if (!confirm(`Delete "${company.name}" and all its data?`)) return
  await apiClient.delete(`/api/v1/admin/companies/${company.id}`)
  await fetchCompanies()
}

const manageMembers = async (company) => {
  selectedCompany.value = company
  members.value = await apiClient.get(`/api/v1/admin/companies/${company.id}/members`) || []
  showMembers.value = true
}

const addMember = async () => {
  if (!newMember.value.user_id) return
  await apiClient.post(`/api/v1/admin/companies/${selectedCompany.value.id}/members`, { 
    user_id: newMember.value.user_id, role: newMember.value.role 
  })
  newMember.value = { user_id: '', role: 'client' }
  members.value = await apiClient.get(`/api/v1/admin/companies/${selectedCompany.value.id}/members`) || []
}

const updateMemberRole = async (member, role) => {
  await apiClient.put(`/api/v1/admin/companies/${selectedCompany.value.id}/members/${member.user_id}`, { role })
  members.value = await apiClient.get(`/api/v1/admin/companies/${selectedCompany.value.id}/members`) || []
}

const removeMember = async (member) => {
  if (!confirm(`Remove ${member.first_name} from ${selectedCompany.value.name}?`)) return
  await apiClient.delete(`/api/v1/admin/companies/${selectedCompany.value.id}/members/${member.user_id}`)
  members.value = await apiClient.get(`/api/v1/admin/companies/${selectedCompany.value.id}/members`) || []
}

const fetchCompanies = async () => {
  companies.value = await apiClient.get('/api/v1/admin/companies') || []
}

onMounted(async () => {
  await fetchCompanies()
  allUsers.value = await apiClient.get('/api/v1/admin/users') || []
})
</script>
