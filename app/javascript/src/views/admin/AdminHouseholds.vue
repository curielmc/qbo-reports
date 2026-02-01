<template>
  <div>
    <div class="flex justify-between items-center mb-8">
      <div>
        <h1 class="text-3xl font-bold">Household Management</h1>
        <p class="text-base-content/60 mt-1">Manage client households and memberships</p>
      </div>
      <button @click="openModal()" class="btn btn-primary gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        Add Household
      </button>
    </div>

    <!-- Households Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div v-for="h in households" :key="h.id" class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">
            {{ h.name }}
            <span class="badge badge-sm badge-outline">ID: {{ h.id }}</span>
          </h2>
          
          <div class="grid grid-cols-3 gap-2 my-4">
            <div class="text-center">
              <div class="text-2xl font-bold text-primary">{{ h.users_count || 0 }}</div>
              <div class="text-xs text-base-content/60">Users</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-secondary">{{ h.accounts_count || 0 }}</div>
              <div class="text-xs text-base-content/60">Accounts</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-accent">{{ h.transactions_count || 0 }}</div>
              <div class="text-xs text-base-content/60">Transactions</div>
            </div>
          </div>

          <!-- Members -->
          <div v-if="h.users && h.users.length > 0" class="mb-2">
            <p class="text-sm font-medium mb-1">Members:</p>
            <div class="flex flex-wrap gap-1">
              <span v-for="u in h.users" :key="u.id" class="badge badge-sm badge-outline">
                {{ u.first_name }} {{ u.last_name }} ({{ u.role }})
              </span>
            </div>
          </div>

          <div class="card-actions justify-end mt-2">
            <button @click="openModal(h)" class="btn btn-ghost btn-sm">Edit</button>
            <button @click="manageMembers(h)" class="btn btn-outline btn-sm">Members</button>
            <button @click="deleteHousehold(h)" class="btn btn-ghost btn-sm text-error">Delete</button>
          </div>
        </div>
      </div>

      <!-- Empty state -->
      <div v-if="households.length === 0" class="col-span-full text-center py-12">
        <div class="text-6xl mb-4">🏠</div>
        <h3 class="text-xl font-semibold mb-2">No households yet</h3>
        <p class="text-base-content/60 mb-4">Create your first household to get started</p>
        <button @click="openModal()" class="btn btn-primary">Add Household</button>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <dialog :class="['modal', showModal ? 'modal-open' : '']">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">{{ editing ? 'Edit Household' : 'New Household' }}</h3>
        <form @submit.prevent="saveHousehold">
          <div class="form-control">
            <label class="label"><span class="label-text">Household Name</span></label>
            <input v-model="form.name" type="text" class="input input-bordered" placeholder="e.g. Smith Family" required />
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
    <dialog :class="['modal', showMembersModal ? 'modal-open' : '']">
      <div class="modal-box w-11/12 max-w-3xl">
        <h3 class="font-bold text-lg mb-4">Members of {{ membersHousehold?.name }}</h3>
        
        <!-- Current Members -->
        <div class="overflow-x-auto mb-4">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>User</th>
                <th>Role in Household</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in currentMembers" :key="m.id">
                <td>{{ m.first_name }} {{ m.last_name }} ({{ m.email }})</td>
                <td>
                  <select 
                    :value="m.household_role" 
                    @change="updateMemberRole(m, $event.target.value)"
                    class="select select-bordered select-xs"
                  >
                    <option value="admin">Admin</option>
                    <option value="advisor">Advisor</option>
                    <option value="client">Client</option>
                    <option value="viewer">Viewer</option>
                  </select>
                </td>
                <td class="text-right">
                  <button @click="removeMember(m)" class="btn btn-ghost btn-xs text-error">Remove</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Add Member -->
        <div class="flex gap-2">
          <select v-model="addMemberUserId" class="select select-bordered select-sm flex-1">
            <option value="">Select user to add...</option>
            <option v-for="u in availableUsers" :key="u.id" :value="u.id">
              {{ u.first_name }} {{ u.last_name }} ({{ u.email }})
            </option>
          </select>
          <button @click="addMember" class="btn btn-primary btn-sm" :disabled="!addMemberUserId">Add</button>
        </div>

        <div class="modal-action">
          <button @click="showMembersModal = false" class="btn">Close</button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showMembersModal = false"><button>close</button></form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { apiClient } from '../../api/client'

const households = ref([])
const allUsers = ref([])
const showModal = ref(false)
const showMembersModal = ref(false)
const editing = ref(null)
const membersHousehold = ref(null)
const currentMembers = ref([])
const addMemberUserId = ref('')
const form = ref({ name: '' })

const availableUsers = computed(() => {
  const memberIds = currentMembers.value.map(m => m.id)
  return allUsers.value.filter(u => !memberIds.includes(u.id))
})

const openModal = (h = null) => {
  editing.value = h
  form.value = h ? { name: h.name } : { name: '' }
  showModal.value = true
}

const saveHousehold = async () => {
  if (editing.value) {
    await apiClient.put(`/api/v1/admin/households/${editing.value.id}`, { household: form.value })
  } else {
    await apiClient.post('/api/v1/admin/households', { household: form.value })
  }
  showModal.value = false
  await fetchHouseholds()
}

const deleteHousehold = async (h) => {
  if (confirm(`Delete household "${h.name}"? This cannot be undone.`)) {
    await apiClient.delete(`/api/v1/admin/households/${h.id}`)
    await fetchHouseholds()
  }
}

const manageMembers = async (h) => {
  membersHousehold.value = h
  currentMembers.value = await apiClient.get(`/api/v1/admin/households/${h.id}/members`) || []
  showMembersModal.value = true
}

const addMember = async () => {
  if (!addMemberUserId.value) return
  await apiClient.post(`/api/v1/admin/households/${membersHousehold.value.id}/members`, { user_id: addMemberUserId.value })
  currentMembers.value = await apiClient.get(`/api/v1/admin/households/${membersHousehold.value.id}/members`) || []
  addMemberUserId.value = ''
}

const removeMember = async (m) => {
  await apiClient.delete(`/api/v1/admin/households/${membersHousehold.value.id}/members/${m.id}`)
  currentMembers.value = await apiClient.get(`/api/v1/admin/households/${membersHousehold.value.id}/members`) || []
}

const updateMemberRole = async (m, role) => {
  await apiClient.put(`/api/v1/admin/households/${membersHousehold.value.id}/members/${m.id}`, { role })
}

const fetchHouseholds = async () => {
  households.value = await apiClient.get('/api/v1/admin/households') || []
}

onMounted(async () => {
  await fetchHouseholds()
  allUsers.value = await apiClient.get('/api/v1/admin/users') || []
})
</script>
