<template>
  <div class="min-h-screen flex items-center justify-center bg-base-200">
    <div class="card w-96 bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title text-2xl font-bold justify-center mb-6">QBO Reports</h2>
        
        <div v-if="error" class="alert alert-error mb-4">
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
            {{ isLoading ? 'Signing in...' : 'Sign In' }}
          </button>
        </form>

        <div class="divider">OR</div>
        
        <a href="/admin" class="btn btn-outline btn-sm w-full">
          Admin Panel →
        </a>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'Login',
  data() {
    return {
      email: '',
      password: '',
      error: '',
      isLoading: false
    }
  },
  methods: {
    async handleLogin() {
      this.isLoading = true
      this.error = ''
      
      try {
        const response = await fetch('/api/v1/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: this.email, password: this.password })
        })
        
        const data = await response.json()
        
        if (response.ok) {
          localStorage.setItem('auth_token', data.token)
          localStorage.setItem('current_user', JSON.stringify(data.user))
          this.$router.push('/')
        } else {
          this.error = data.error || 'Invalid email or password'
        }
      } catch (err) {
        this.error = 'Connection error. Please try again.'
      } finally {
        this.isLoading = false
      }
    }
  }
}
</script>
