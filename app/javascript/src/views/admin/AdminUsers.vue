<template>
  <div>
    <div class="flex justify-between items-center mb-8">
      <div>
        <h1 class="text-3xl font-bold">User Management</h1>
        <p class="text-base-content/60 mt-1">Manage system users and permissions</p>
      </div>
      <button v-if="authStore.canManage" @click="openModal()" class="btn btn-primary gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        Add User
      </button>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
      <div class="stat bg-base-100 rounded-box shadow" v-for="role in roleCounts" :key="role.name">
        <div class="stat-title">{{ role.name }}</div>
        <div class="stat-value text-lg">{{ role.count }}</div>
      </div>
    </div>

    <!-- Users Table -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <div class="flex gap-4 mb-4">
          <input 
            v-model="search" 
            type="text" 
            placeholder="Search users..." 
            class="input input-bordered input-sm flex-1"
          />
          <select v-model="roleFilter" class="select select-bordered select-sm">
            <option value="">All Roles</option>
            <option v-for="r in roles" :key="r" :value="r">{{ capitalize(r) }}</option>
          </select>
        </div>

        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Companies</th>
                <th>Created</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="user in filteredUsers" :key="user.id" class="hover">
                <td>
                  <div class="flex items-center gap-3">
                    <div class="avatar placeholder">
                      <div class="bg-neutral text-neutral-content rounded-full w-8">
                        <span class="text-xs">{{ initials(user) }}</span>
                      </div>
                    </div>
                    <span class="font-medium">{{ user.first_name }} {{ user.last_name }}</span>
                  </div>
                </td>
                <td>{{ user.email }}</td>
                <td>
                  <span :class="['badge', roleBadge(user.role)]">{{ capitalize(user.role) }}</span>
                </td>
                <td>{{ user.company_count || 0 }}</td>
                <td class="text-sm text-base-content/60">{{ formatDate(user.created_at) }}</td>
                <td class="text-right">
                  <div v-if="authStore.canManage" class="dropdown dropdown-end">
                    <div tabindex="0" role="button" class="btn btn-ghost btn-xs">⋮</div>
                    <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-40">
                      <li><a @click="openModal(user)">Edit</a></li>
                      <li><a @click="resetPassword(user)">Reset Password</a></li>
                      <li><a @click="deleteUser(user)" class="text-error">Delete</a></li>
                    </ul>
                  </div>
                  <span v-else class="text-base-content/40 text-xs">View only</span>
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
        <h3 class="font-bold text-lg mb-4">{{ editing ? 'Edit User' : 'New User' }}</h3>
        <form @submit.prevent="saveUser">
          <div class="grid grid-cols-2 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">First Name</span></label>
              <input v-model="form.first_name" type="text" class="input input-bordered" required />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Last Name</span></label>
              <input v-model="form.last_name" type="text" class="input input-bordered" required />
            </div>
          </div>
          <div class="form-control mt-4">
            <label class="label"><span class="label-text">Email</span></label>
            <input v-model="form.email" type="email" class="input input-bordered" required />
          </div>
          <div class="form-control mt-4">
            <label class="label"><span class="label-text">Role</span></label>
            <select v-model="form.role" class="select select-bordered">
              <option v-for="r in roles" :key="r" :value="r">{{ capitalize(r) }}</option>
            </select>
          </div>
          <div class="form-control mt-4" v-if="!editing">
            <label class="label"><span class="label-text">Password</span></label>
            <input v-model="form.password" type="password" class="input input-bordered" :required="!editing" minlength="6" />
          </div>
          <div class="modal-action">
            <button type="button" @click="showModal = false" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary" :disabled="saving">
              <span v-if="saving" class="loading loading-spinner loading-sm"></span>
              {{ saving ? 'Saving...' : 'Save' }}
            </button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showModal = false"><button>close</button></form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth'
import { apiClient } from '../../api/client'

const authStore = useAuthStore()
const users = ref([])
const search = ref('')
const roleFilter = ref('')
const showModal = ref(false)
const editing = ref(null)
const saving = ref(false)
const roles = ['executive', 'manager', 'advisor', 'client', 'viewer']
const form = ref({ first_name: '', last_name: '', email: '', role: 'client', password: '' })

const filteredUsers = computed(() => {
  let list = users.value
  if (search.value) {
    const s = search.value.toLowerCase()
    list = list.filter(u => 
      u.email.toLowerCase().includes(s) || 
      `${u.first_name} ${u.last_name}`.toLowerCase().includes(s)
    )
  }
  if (roleFilter.value) list = list.filter(u => u.role === roleFilter.value)
  return list
})

const roleCounts = computed(() => 
  roles.map(r => ({ name: capitalize(r), count: users.value.filter(u => u.role === r).length }))
)

const capitalize = (s) => s ? s.charAt(0).toUpperCase() + s.slice(1) : ''
const initials = (u) => `${(u.first_name||'')[0]||''}${(u.last_name||'')[0]||''}`.toUpperCase()
const formatDate = (d) => d ? new Date(d).toLocaleDateString() : ''
const roleBadge = (r) => ({ executive: 'badge-error', manager: 'badge-warning', advisor: 'badge-info', client: 'badge-success', viewer: 'badge-ghost' }[r] || 'badge-ghost')

const openModal = (user = null) => {
  editing.value = user
  form.value = user ? { ...user, password: '' } : { first_name: '', last_name: '', email: '', role: 'client', password: '' }
  showModal.value = true
}

const saveUser = async () => {
  saving.value = true
  try {
    if (editing.value) {
      await apiClient.put(`/api/v1/admin/users/${editing.value.id}`, { user: form.value })
    } else {
      await apiClient.post('/api/v1/admin/users', { user: form.value })
    }
    showModal.value = false
    await fetchUsers()
  } finally {
    saving.value = false
  }
}

const deleteUser = async (user) => {
  if (confirm(`Delete ${user.email}?`)) {
    await apiClient.delete(`/api/v1/admin/users/${user.id}`)
    await fetchUsers()
  }
}

const resetPassword = async (user) => {
  const pwd = prompt('New password (min 6 chars):')
  if (pwd && pwd.length >= 6) {
    await apiClient.put(`/api/v1/admin/users/${user.id}`, { user: { password: pwd } })
    alert('Password updated')
  }
}

const fetchUsers = async () => {
  users.value = await apiClient.get('/api/v1/admin/users') || []
}

onMounted(fetchUsers)
</script>
