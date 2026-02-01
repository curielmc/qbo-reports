<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-xl sm:text-3xl font-bold">Users</h1>
      <button @click="openModal()" class="btn btn-primary btn-sm gap-1">+ Add User</button>
    </div>

    <div class="card bg-base-100 shadow-xl">
      <div class="card-body p-0">
        <div class="overflow-x-auto">
          <table class="table table-sm sm:table-md">
            <thead>
              <tr class="bg-base-200">
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Companies</th>
                <th>Last Login</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="user in users" :key="user.id" class="hover">
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
                <td class="text-sm">{{ user.email }}</td>
                <td><span :class="['badge badge-sm', roleBadge(user.role)]">{{ user.role }}</span></td>
                <td class="text-sm">{{ user.companies_count || 0 }}</td>
                <td class="text-sm text-base-content/50">{{ user.last_sign_in_at ? formatDate(user.last_sign_in_at) : 'Never' }}</td>
                <td class="text-right">
                  <button @click="openModal(user)" class="btn btn-ghost btn-xs">Edit</button>
                  <button @click="deleteUser(user)" class="btn btn-ghost btn-xs text-error" v-if="user.id !== currentUserId">Delete</button>
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
        <h3 class="font-bold text-lg mb-4">{{ editing ? 'Edit User' : 'New User' }}</h3>
        <form @submit.prevent="saveUser">
          <div class="grid grid-cols-2 gap-3 mb-3">
            <div class="form-control">
              <label class="label"><span class="label-text">First Name</span></label>
              <input v-model="form.first_name" type="text" class="input input-bordered" required />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Last Name</span></label>
              <input v-model="form.last_name" type="text" class="input input-bordered" required />
            </div>
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Email</span></label>
            <input v-model="form.email" type="email" class="input input-bordered" required />
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Role</span></label>
            <select v-model="form.role" class="select select-bordered" required>
              <option value="viewer">Viewer</option>
              <option value="client">Client</option>
              <option value="advisor">Advisor</option>
              <option value="manager">Manager</option>
              <option value="executive">Executive</option>
            </select>
          </div>
          <div v-if="!editing" class="form-control mb-3">
            <label class="label"><span class="label-text">Password</span></label>
            <input v-model="form.password" type="password" class="input input-bordered" required />
          </div>
          <div v-if="error" class="alert alert-error mb-3"><span>{{ error }}</span></div>
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
import { ref, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth'
import { apiClient } from '../../api/client'

const authStore = useAuthStore()
const users = ref([])
const showModal = ref(false)
const editing = ref(null)
const error = ref(null)
const form = ref({ first_name: '', last_name: '', email: '', role: 'client', password: '' })
const currentUserId = authStore.user?.id

const initials = (u) => `${(u.first_name || '')[0] || ''}${(u.last_name || '')[0] || ''}`.toUpperCase()
const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : ''
const roleBadge = (role) => {
  const map = { executive: 'badge-primary', manager: 'badge-secondary', advisor: 'badge-accent', client: 'badge-info', viewer: 'badge-ghost' }
  return map[role] || 'badge-ghost'
}

const openModal = (user = null) => {
  editing.value = user
  error.value = null
  form.value = user ? { ...user } : { first_name: '', last_name: '', email: '', role: 'client', password: '' }
  showModal.value = true
}

const saveUser = async () => {
  try {
    error.value = null
    if (editing.value) {
      await apiClient.put(`/api/v1/admin/users/${editing.value.id}`, { user: form.value })
    } else {
      await apiClient.post('/api/v1/admin/users', { user: form.value })
    }
    showModal.value = false
    await fetchUsers()
  } catch (e) {
    error.value = e.message
  }
}

const deleteUser = async (user) => {
  if (!confirm(`Delete ${user.first_name} ${user.last_name}?`)) return
  await apiClient.delete(`/api/v1/admin/users/${user.id}`)
  await fetchUsers()
}

const fetchUsers = async () => {
  users.value = await apiClient.get('/api/v1/admin/users') || []
}

onMounted(fetchUsers)
</script>
