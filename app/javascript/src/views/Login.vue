<template>
  <div class="min-h-screen flex items-center justify-center bg-base-200">
    <div class="card w-96 bg-base-100 shadow-xl">
      <div class="card-body">
        <div class="flex justify-center mb-4">
          <img src="../assets/logo.svg" alt="ecfoBooks" class="h-12" />
        </div>
        <p class="text-center text-base-content/60 mb-6">Your financial command center</p>
        
        <div v-if="error" class="alert alert-error mb-4">
          <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span>{{ error }}</span>
        </div>

        <form @submit.prevent="handleLogin">
          <div class="form-control mb-4">
            <label class="label">
              <span class="label-text">Email</span>
            </label>
            <input 
              type="email" 
              v-model="email" 
              placeholder="email@example.com" 
              class="input input-bordered w-full" 
              required
            />
          </div>

          <div class="form-control mb-6">
            <label class="label">
              <span class="label-text">Password</span>
            </label>
            <input 
              type="password" 
              v-model="password" 
              placeholder="••••••••" 
              class="input input-bordered w-full" 
              required
            />
          </div>

          <button 
            type="submit" 
            class="btn btn-primary w-full"
            :disabled="isLoading"
          >
            <span v-if="isLoading" class="loading loading-spinner loading-sm"></span>
            {{ isLoading ? 'Signing in...' : 'Sign In' }}
          </button>
        </form>

      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const email = ref('')
const password = ref('')
const error = ref('')
const isLoading = ref(false)

const handleLogin = async () => {
  isLoading.value = true
  error.value = ''
  
  const result = await authStore.login(email.value, password.value)
  
  if (result.success) {
    const role = authStore.user?.role
    if (role === 'executive' || role === 'manager') {
      router.push('/admin/companies')
    } else {
      router.push('/')
    }
  } else {
    error.value = result.error || 'Invalid email or password'
  }
  
  isLoading.value = false
}
</script>
