<template>
  <div id="app" data-theme="ecfobooks">
    <!-- Masquerade banner -->
    <div v-if="isMasquerading" class="alert alert-warning rounded-none fixed top-0 left-0 right-0 z-50 flex justify-center py-2">
      <span>Viewing as <strong>{{ masqueradeName }}</strong></span>
      <button @click="stopMasquerade" class="btn btn-sm btn-ghost underline">Stop Masquerading</button>
    </div>

    <div v-if="isAuthenticated" class="min-h-screen bg-base-200" :class="{ 'pt-12': isMasquerading }">
      <!-- Mobile-first drawer layout -->
      <div class="drawer lg:drawer-open">
        <input id="main-drawer" type="checkbox" class="drawer-toggle" v-model="drawerOpen" />

        <!-- Main content area -->
        <div class="drawer-content flex flex-col">
          <!-- Top navbar (mobile: hamburger + logo + avatar) -->
          <div class="navbar bg-base-100 shadow-lg sticky top-0 z-30 lg:hidden">
            <div class="flex-none">
              <label for="main-drawer" class="btn btn-square btn-ghost">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block w-6 h-6 stroke-current"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path></svg>
              </label>
            </div>
            <div class="flex-1">
              <router-link to="/" class="btn btn-ghost text-lg gap-1 p-0">
                <img src="./src/assets/logo.svg" alt="ecfoBooks" class="h-7" />
              </router-link>
            </div>
            <div class="flex-none flex items-center gap-2">
              <button @click="showNotifications = !showNotifications" class="btn btn-ghost btn-circle btn-sm relative">
                🔔
                <span v-if="unreadCount > 0" class="badge badge-error badge-xs absolute -top-0.5 -right-0.5">{{ unreadCount }}</span>
              </button>
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-ghost btn-circle avatar placeholder btn-sm">
                  <div class="bg-neutral text-neutral-content rounded-full w-8">
                    <span class="text-xs">{{ userInitials }}</span>
                  </div>
                </div>
                <ul tabindex="0" class="mt-3 z-[1] p-2 shadow menu menu-sm dropdown-content bg-base-100 rounded-box w-48">
                  <li class="menu-title"><span>{{ userName }}</span></li>
                  <li><a @click="logout">Logout</a></li>
                </ul>
              </div>
            </div>
          </div>

          <!-- Desktop top bar -->
          <div class="hidden lg:flex navbar bg-base-100 shadow-sm sticky top-0 z-30">
            <div class="flex-1">
              <router-link to="/" class="btn btn-ghost text-xl gap-1">
                <img src="./src/assets/logo.svg" alt="ecfoBooks" class="h-8" />
              </router-link>
            </div>
            <div class="flex-none flex items-center gap-2">
              <!-- Company switcher -->
              <select v-if="companies.length > 0" v-model="currentCompanyId" @change="switchCompany"
                class="select select-bordered select-sm max-w-xs">
                <option v-for="c in companies" :key="c.id" :value="c.id">{{ c.name }}</option>
              </select>
              <button @click="showNotifications = !showNotifications" class="btn btn-ghost btn-circle btn-sm relative">
                🔔
                <span v-if="unreadCount > 0" class="badge badge-error badge-xs absolute -top-0.5 -right-0.5">{{ unreadCount }}</span>
              </button>
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

          <!-- Page content -->
          <main class="flex-1 p-3 sm:p-4 lg:p-6 max-w-7xl mx-auto w-full">
            <router-view />
          </main>
        </div>

        <!-- Sidebar drawer -->
        <div class="drawer-side z-40">
          <label for="main-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
          <aside class="bg-base-100 w-64 min-h-full flex flex-col">
            <!-- Sidebar header (mobile only) -->
            <div class="p-4 border-b lg:hidden">
              <img src="./src/assets/logo.svg" alt="ecfoBooks" class="h-8" />
            </div>

            <!-- Company switcher (mobile) -->
            <div v-if="companies.length > 0" class="p-3 border-b lg:hidden">
              <select v-model="currentCompanyId" @change="switchCompany"
                class="select select-bordered select-sm w-full">
                <option v-for="c in companies" :key="c.id" :value="c.id">{{ c.name }}</option>
              </select>
            </div>

            <!-- Nav links -->
            <ul class="menu p-3 flex-1">
              <li class="menu-title text-xs uppercase tracking-wider mt-2">Main</li>
              <li><router-link to="/" @click="closeMobile" :class="{'active': $route.path === '/'}">
                <span class="text-lg">💬</span> Chat
              </router-link></li>
              <li><router-link to="/dashboard" @click="closeMobile" :class="{'active': $route.path === '/dashboard'}">
                <span class="text-lg">📊</span> Dashboard
              </router-link></li>

              <li class="menu-title text-xs uppercase tracking-wider mt-4">Bookkeeping</li>
              <li><router-link to="/transactions" @click="closeMobile">
                <span class="text-lg">💳</span> Transactions
              </router-link></li>
              <li><router-link to="/journal" @click="closeMobile">
                <span class="text-lg">📒</span> Journal Entries
              </router-link></li>
              <li><router-link to="/reconciliation" @click="closeMobile">
                <span class="text-lg">🔄</span> Reconcile
              </router-link></li>
              <li><router-link to="/receipts" @click="closeMobile">
                <span class="text-lg">🧾</span> Receipts
              </router-link></li>

              <li class="menu-title text-xs uppercase tracking-wider mt-4">Reports & Data</li>
              <li><router-link to="/reports" @click="closeMobile">
                <span class="text-lg">📈</span> Reports
              </router-link></li>
              <li><router-link to="/chart-of-accounts" @click="closeMobile">
                <span class="text-lg">📋</span> Chart of Accounts
              </router-link></li>
              <li><router-link to="/linked-accounts" @click="closeMobile">
                <span class="text-lg">🏦</span> Linked Accounts
              </router-link></li>
              <li><router-link to="/import" @click="closeMobile">
                <span class="text-lg">📥</span> Import Data
              </router-link></li>
              <li><router-link to="/rules" @click="closeMobile">
                <span class="text-lg">⚡</span> Auto-Rules
              </router-link></li>

              <li class="menu-title text-xs uppercase tracking-wider mt-4">Account</li>
              <li><router-link to="/billing" @click="closeMobile">
                <span class="text-lg">💰</span> Billing & Usage
              </router-link></li>

              <li v-if="isBookkeeper" class="menu-title text-xs uppercase tracking-wider mt-4">Team</li>
              <li v-if="isBookkeeper"><router-link to="/bookkeeper" @click="closeMobile">
                <span class="text-lg">🧑‍💼</span> Bookkeeper Hub
              </router-link></li>

              <li v-if="isAdmin" class="menu-title text-xs uppercase tracking-wider mt-4">Admin</li>
              <li v-if="isAdmin"><router-link to="/admin/companies" @click="closeMobile">
                <span class="text-lg">🏢</span> Companies
              </router-link></li>
              <li v-if="isAdmin"><router-link to="/admin/billing" @click="closeMobile">
                <span class="text-lg">💵</span> Client Billing
              </router-link></li>
              <li v-if="isAdmin"><router-link to="/admin/users" @click="closeMobile">
                <span class="text-lg">👥</span> Users
              </router-link></li>
            </ul>

            <!-- Sidebar footer -->
            <div class="p-3 border-t">
              <div class="flex items-center gap-3 px-2">
                <div class="avatar placeholder">
                  <div class="bg-neutral text-neutral-content rounded-full w-8">
                    <span class="text-xs">{{ userInitials }}</span>
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium truncate">{{ userName }}</p>
                  <p class="text-xs text-base-content/50 truncate">{{ userEmail }}</p>
                </div>
              </div>
            </div>
          </aside>
        </div>
      </div>
    </div>

    <!-- Show login when not authenticated -->
    <router-view v-else />
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from './src/stores/auth'
import { useAppStore } from './src/stores/app'

const router = useRouter()
const authStore = useAuthStore()
const appStore = useAppStore()

const drawerOpen = ref(false)
const showNotifications = ref(false)
const unreadCount = ref(0)
const currentCompanyId = ref(appStore.activeCompany?.id || null)

const isAuthenticated = computed(() => authStore.isAuthenticated)
const isAdmin = computed(() => authStore.isAdmin)
const isBookkeeper = computed(() => authStore.user?.role === 'bookkeeper' || authStore.isAdmin)
const isMasquerading = computed(() => authStore.isMasquerading)
const masqueradeName = computed(() => {
  const m = authStore.masqueradingAs
  return m ? `${m.first_name || ''} ${m.last_name || ''}`.trim() : ''
})

const stopMasquerade = () => authStore.stopMasquerade()
const companies = computed(() => appStore.companies || [])

const userName = computed(() => {
  const user = authStore.user
  return user ? `${user.first_name || ''} ${user.last_name || ''}`.trim() : ''
})
const userInitials = computed(() => {
  const user = authStore.user
  if (!user) return '?'
  return `${(user.first_name || '')[0] || ''}${(user.last_name || '')[0] || ''}`.toUpperCase()
})
const userEmail = computed(() => authStore.user?.email || '')

const closeMobile = () => { drawerOpen.value = false }

const switchCompany = () => {
  const company = companies.value.find(c => c.id === currentCompanyId.value)
  if (company) appStore.setCurrentCompany(company)
}

const logout = () => {
  authStore.logout()
  router.push('/login')
}
</script>
