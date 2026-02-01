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

  // Can see admin panel (users list, all companies)
  const isAdmin = computed(() => isExecutive.value || isManager.value)
  // Can modify users, settings, system config
  const canManage = computed(() => isExecutive.value)
  // Can edit financial data
  const canEdit = computed(() => isExecutive.value || isManager.value || isAdvisor.value)

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
      return { success: true }
    } else {
      return { success: false, error: data.error }
    }
  }

  function logout() {
    token.value = null
    user.value = null
    localStorage.removeItem('auth_token')
    localStorage.removeItem('current_user')
  }

  return {
    token, user,
    isAuthenticated, isExecutive, isManager, isAdvisor, isClient, isViewer,
    isAdmin, canManage, canEdit,
    login, logout
  }
})
