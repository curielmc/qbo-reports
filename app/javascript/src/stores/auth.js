import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('auth_token') || null)
  const user = ref(JSON.parse(localStorage.getItem('current_user') || 'null'))
  const masqueradingAs = ref(JSON.parse(localStorage.getItem('masquerade_as') || 'null'))
  const realUser = ref(JSON.parse(localStorage.getItem('real_user') || 'null'))

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
  const isMasquerading = computed(() => !!masqueradingAs.value)

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
    masqueradingAs.value = null
    realUser.value = null
    localStorage.removeItem('auth_token')
    localStorage.removeItem('current_user')
    localStorage.removeItem('user_companies')
    localStorage.removeItem('current_company')
    localStorage.removeItem('masquerade_as')
    localStorage.removeItem('real_user')
    localStorage.removeItem('real_token')
  }

  async function startMasquerade(userId) {
    const router = useRouter()

    // Save current (real) user state
    const currentToken = token.value
    const currentUser = user.value
    localStorage.setItem('real_token', currentToken)
    localStorage.setItem('real_user', JSON.stringify(currentUser))
    realUser.value = currentUser

    const response = await fetch(`/api/v1/admin/masquerade/${userId}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${currentToken}`
      }
    })

    const data = await response.json()

    if (response.ok) {
      token.value = data.token
      user.value = data.user
      masqueradingAs.value = data.user
      localStorage.setItem('auth_token', data.token)
      localStorage.setItem('current_user', JSON.stringify(data.user))
      localStorage.setItem('masquerade_as', JSON.stringify(data.user))

      if (data.companies) {
        localStorage.setItem('user_companies', JSON.stringify(data.companies))
      }

      router.push('/')
    } else {
      // Restore on failure
      realUser.value = null
      localStorage.removeItem('real_token')
      localStorage.removeItem('real_user')
      throw new Error(data.error || 'Failed to start masquerade')
    }
  }

  async function stopMasquerade() {
    const router = useRouter()

    const response = await fetch('/api/v1/admin/masquerade', {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token.value}`
      }
    })

    const data = await response.json()

    if (response.ok) {
      token.value = data.token
      user.value = data.user
      masqueradingAs.value = null
      realUser.value = null
      localStorage.setItem('auth_token', data.token)
      localStorage.setItem('current_user', JSON.stringify(data.user))
      localStorage.removeItem('masquerade_as')
      localStorage.removeItem('real_user')
      localStorage.removeItem('real_token')

      if (data.companies) {
        localStorage.setItem('user_companies', JSON.stringify(data.companies))
      }

      router.push('/admin/companies')
    } else {
      throw new Error(data.error || 'Failed to stop masquerade')
    }
  }

  return {
    token, user, masqueradingAs, realUser,
    isAuthenticated, isExecutive, isManager, isAdvisor, isClient, isViewer,
    isAdmin, canManage, canEdit, isBookkeeper, isMasquerading,
    login, logout, startMasquerade, stopMasquerade
  }
})
