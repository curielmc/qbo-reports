<template>
  <div id="app" data-theme="corporate">
    <div v-if="isAuthenticated" class="min-h-screen bg-base-200">
      <!-- Navbar -->
      <div class="navbar bg-base-100 shadow-lg">
        <div class="flex-1">
          <a href="/" class="btn btn-ghost text-xl">📊 ecfoBooks</a>
        </div>
        <div class="flex-none">
          <ul class="menu menu-horizontal px-1">
            <li><router-link to="/" class="font-medium">Dashboard</router-link></li>
            <li><router-link to="/reports" class="font-medium">Reports</router-link></li>
            <li><router-link to="/chart-of-accounts" class="font-medium">Chart of Accounts</router-link></li>
            <li><router-link to="/transactions" class="font-medium">Transactions</router-link></li>
            <li><router-link to="/linked-accounts" class="font-medium">🏦 Accounts</router-link></li>
            <li v-if="isAdmin">
              <details>
                <summary class="font-medium">Admin</summary>
                <ul class="bg-base-100 rounded-box z-[1] w-52 p-2 shadow">
                  <li><router-link to="/admin/users">Users</router-link></li>
                  <li><router-link to="/admin/households">Households</router-link></li>
                  <li><router-link to="/admin/accounts">Accounts</router-link></li>
                  <li><router-link to="/admin/invitations">Invitations</router-link></li>
                  <li v-if="authStore.canManage"><router-link to="/admin/settings">Settings</router-link></li>
                </ul>
              </details>
            </li>
          </ul>
          <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost btn-circle avatar placeholder">
              <div class="bg-neutral text-neutral-content rounded-full w-10">
                <span class="text-sm">{{ userInitials }}</span>
              </div>
            </div>
            <ul tabindex="0" class="mt-3 z-[1] p-2 shadow menu menu-sm dropdown-content bg-base-100 rounded-box w-52">
              <li class="menu-title"><span>{{ userName }}</span></li>
              <li><a @click="logout">Logout</a></li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Main Content -->
      <div class="container mx-auto px-4 py-6">
        <router-view />
      </div>
    </div>

    <!-- Show login when not authenticated -->
    <router-view v-else />
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from './src/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const isAuthenticated = computed(() => authStore.isAuthenticated)
const isAdmin = computed(() => authStore.isAdmin)
const userName = computed(() => {
  const user = authStore.user
  return user ? `${user.first_name} ${user.last_name}` : ''
})
const userInitials = computed(() => {
  const user = authStore.user
  if (!user) return '?'
  return `${(user.first_name || '')[0] || ''}${(user.last_name || '')[0] || ''}`.toUpperCase()
})

const logout = () => {
  authStore.logout()
  router.push('/login')
}
</script>
