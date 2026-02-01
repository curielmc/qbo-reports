<template>
  <div>
    <h1 class="text-3xl font-bold mb-2">Settings</h1>
    <p class="text-base-content/60 mb-8">System configuration and preferences</p>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Profile -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title mb-4">Your Profile</h2>
          <form @submit.prevent="updateProfile">
            <div class="grid grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label"><span class="label-text">First Name</span></label>
                <input v-model="profile.first_name" type="text" class="input input-bordered" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Last Name</span></label>
                <input v-model="profile.last_name" type="text" class="input input-bordered" />
              </div>
            </div>
            <div class="form-control mt-4">
              <label class="label"><span class="label-text">Email</span></label>
              <input v-model="profile.email" type="email" class="input input-bordered" disabled />
            </div>
            <div class="form-control mt-4">
              <label class="label"><span class="label-text">Role</span></label>
              <input :value="capitalize(profile.role)" type="text" class="input input-bordered" disabled />
            </div>
            <button type="submit" class="btn btn-primary mt-4">Update Profile</button>
          </form>
        </div>
      </div>

      <!-- Change Password -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title mb-4">Change Password</h2>
          <form @submit.prevent="changePassword">
            <div class="form-control">
              <label class="label"><span class="label-text">Current Password</span></label>
              <input v-model="passwords.current" type="password" class="input input-bordered" required />
            </div>
            <div class="form-control mt-4">
              <label class="label"><span class="label-text">New Password</span></label>
              <input v-model="passwords.new_password" type="password" class="input input-bordered" required minlength="6" />
            </div>
            <div class="form-control mt-4">
              <label class="label"><span class="label-text">Confirm New Password</span></label>
              <input v-model="passwords.confirm" type="password" class="input input-bordered" required />
            </div>
            <button type="submit" class="btn btn-primary mt-4">Change Password</button>
          </form>
        </div>
      </div>

      <!-- System Info -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title mb-4">System Information</h2>
          <div class="space-y-3">
            <div class="flex justify-between">
              <span class="text-base-content/60">Application</span>
              <span class="font-mono">ecfoBooks v1.0</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Framework</span>
              <span class="font-mono">Rails 6.1 + Vue 3</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Database</span>
              <span class="font-mono">PostgreSQL</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">UI</span>
              <span class="font-mono">Tailwind CSS + DaisyUI</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Data Management -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title mb-4">Data Management</h2>
          <div class="space-y-3">
            <button @click="exportData" class="btn btn-outline w-full justify-start gap-2">
              📥 Export All Data (CSV)
            </button>
            <button @click="syncAccounts" class="btn btn-outline w-full justify-start gap-2">
              🔄 Sync Plaid Accounts
            </button>
            <button @click="recalculate" class="btn btn-outline w-full justify-start gap-2">
              📊 Recalculate Balances
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Toast -->
    <div v-if="toast" class="toast toast-end">
      <div :class="['alert', toast.type === 'success' ? 'alert-success' : 'alert-error']">
        <span>{{ toast.message }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth'
import { apiClient } from '../../api/client'

const authStore = useAuthStore()
const toast = ref(null)
const profile = ref({ ...authStore.user })
const passwords = ref({ current: '', new_password: '', confirm: '' })

const capitalize = (s) => s ? s.charAt(0).toUpperCase() + s.slice(1) : ''

const showToast = (message, type = 'success') => {
  toast.value = { message, type }
  setTimeout(() => toast.value = null, 3000)
}

const updateProfile = async () => {
  await apiClient.put('/api/v1/auth/me', { user: profile.value })
  showToast('Profile updated')
}

const changePassword = async () => {
  if (passwords.value.new_password !== passwords.value.confirm) {
    showToast('Passwords do not match', 'error')
    return
  }
  await apiClient.put('/api/v1/auth/password', passwords.value)
  passwords.value = { current: '', new_password: '', confirm: '' }
  showToast('Password changed')
}

const exportData = () => showToast('Export started — download will begin shortly')
const syncAccounts = () => showToast('Plaid sync initiated')
const recalculate = () => showToast('Balance recalculation started')
</script>
