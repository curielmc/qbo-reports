import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('auth_token') || null)
  const user = ref(JSON.parse(localStorage.getItem('current_user') || 'null'))

  const isAuthenticated = computed(() => !!token.value)
  const isExecutive = computed(() => user.value?.role === 'executive')
  const isManager = computed(() => user.value?.role === 'manager')
  const isAdvisor = computed(() => user.value?.role === 'advisor')
  const isClient = computed(() => user.value?.role === 'client')
  const isViewer = computed(() => user.value?.role === 'viewer')

  const isAdmin = computed(() => isExecutive.value || isManager.value)
  const canManage = computed(() => isExecutive.value)
  const canEdit = computed(() => isExecutive.value || isManager.value || isAdvisor.value)
  const isBookkeeper = computed(() => user.value?.is_bookkeeper || isAdmin.value)

  async function login(email, password) {
    const response = await fetch('/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    })

    const data = await response.json()

    if (response.ok) {
      token.value = data.token
      user.value = data.user
      localStorage.setItem('auth_token', data.token)
      localStorage.setItem('current_user', JSON.stringify(data.user))

      // Store companies
      if (data.companies) {
        localStorage.setItem('user_companies', JSON.stringify(data.companies))
      }

      return { success: true, companies: data.companies }
    } else {
      return { success: false, error: data.error }
    }
  }

  function logout() {
    token.value = null
    user.value = null
    localStorage.removeItem('auth_token')
    localStorage.removeItem('current_user')
    localStorage.removeItem('user_companies')
    localStorage.removeItem('current_company')
  }

  return {
    token, user,
    isAuthenticated, isExecutive, isManager, isAdvisor, isClient, isViewer,
    isAdmin, canManage, canEdit, isBookkeeper,
    login, logout
  }
})
