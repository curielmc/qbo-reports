<template>
  <div class="min-h-screen flex items-center justify-center bg-base-200">
    <div class="card w-full max-w-lg bg-base-100 shadow-xl">
      <div class="card-body">
        <!-- Loading -->
        <div v-if="loading" class="text-center py-8">
          <span class="loading loading-spinner loading-lg"></span>
          <p class="mt-4 text-base-content/60">Loading invitation...</p>
        </div>

        <!-- Error -->
        <div v-else-if="error" class="text-center py-8">
          <div class="text-6xl mb-4">😕</div>
          <h2 class="text-xl font-bold mb-2">{{ error }}</h2>
          <p class="text-base-content/60 mb-4">This invitation link is no longer valid.</p>
          <router-link to="/login" class="btn btn-primary">Go to Login</router-link>
        </div>

        <!-- Invitation Form -->
        <div v-else-if="invitation">
          <div class="text-center mb-6">
            <img src="../assets/logo.svg" alt="ecfoBooks" class="h-12 mx-auto" />
            <h2 class="text-2xl font-bold mt-4">Welcome to ecfoBooks</h2>
            <p class="text-base-content/60 mt-1">Set up your account to get started</p>
          </div>

          <!-- Personal message -->
          <div v-if="invitation.personal_message" class="alert alert-info mb-6">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            <span>{{ invitation.personal_message }}</span>
          </div>

          <div class="bg-base-200 rounded-lg p-4 mb-6">
            <div class="text-sm text-base-content/60">You're joining</div>
            <div class="font-bold">{{ invitation.household_name || 'ecfoBooks' }}</div>
            <div class="text-sm">as {{ capitalize(invitation.role) }}</div>
          </div>

          <div v-if="formErrors.length" class="alert alert-error mb-4">
            <ul class="list-disc pl-4">
              <li v-for="err in formErrors" :key="err">{{ err }}</li>
            </ul>
          </div>

          <form @submit.prevent="acceptInvitation">
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
              <input :value="invitation.email" type="email" class="input input-bordered" disabled />
            </div>

            <div class="form-control mt-4">
              <label class="label"><span class="label-text">Create Password</span></label>
              <input v-model="form.password" type="password" class="input input-bordered" required minlength="6" placeholder="Minimum 6 characters" />
            </div>

            <div class="form-control mt-4">
              <label class="label"><span class="label-text">Confirm Password</span></label>
              <input v-model="form.password_confirmation" type="password" class="input input-bordered" required />
            </div>

            <button type="submit" class="btn btn-primary w-full mt-6" :disabled="submitting">
              <span v-if="submitting" class="loading loading-spinner loading-sm"></span>
              {{ submitting ? 'Creating account...' : 'Create My Account' }}
            </button>
          </form>

          <div class="divider">Already have an account?</div>
          <router-link to="/login" class="btn btn-outline w-full">Sign In</router-link>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const loading = ref(true)
const error = ref('')
const invitation = ref(null)
const submitting = ref(false)
const formErrors = ref([])
const form = ref({ first_name: '', last_name: '', password: '', password_confirmation: '' })

const capitalize = (s) => s ? s.charAt(0).toUpperCase() + s.slice(1) : ''

const fetchInvitation = async () => {
  try {
    const response = await fetch(`/api/v1/invitations/${route.params.token}`)
    const data = await response.json()
    
    if (response.ok) {
      invitation.value = data
      form.value.first_name = data.first_name || ''
      form.value.last_name = data.last_name || ''
    } else {
      error.value = data.error || 'Invalid invitation'
    }
  } catch (err) {
    error.value = 'Unable to load invitation'
  } finally {
    loading.value = false
  }
}

const acceptInvitation = async () => {
  formErrors.value = []
  
  if (form.value.password !== form.value.password_confirmation) {
    formErrors.value = ['Passwords do not match']
    return
  }

  submitting.value = true
  try {
    const response = await fetch(`/api/v1/invitations/${route.params.token}/accept`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form.value)
    })
    
    const data = await response.json()
    
    if (response.ok) {
      // Auto-login
      localStorage.setItem('auth_token', data.token)
      localStorage.setItem('current_user', JSON.stringify(data.user))
      authStore.token = data.token
      authStore.user = data.user
      router.push('/')
    } else {
      formErrors.value = data.errors || [data.error || 'Something went wrong']
    }
  } finally {
    submitting.value = false
  }
}

onMounted(fetchInvitation)
</script>
