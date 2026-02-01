import { createRouter, createWebHistory } from 'vue-router'
import Dashboard from '../views/Dashboard.vue'
import Reports from '../views/Reports.vue'
import ChartOfAccounts from '../views/ChartOfAccounts.vue'
import Transactions from '../views/Transactions.vue'
import Login from '../views/Login.vue'
import AdminUsers from '../views/admin/AdminUsers.vue'
import AdminHouseholds from '../views/admin/AdminHouseholds.vue'
import AdminAccounts from '../views/admin/AdminAccounts.vue'
import AdminSettings from '../views/admin/AdminSettings.vue'

const routes = [
  { path: '/login', name: 'Login', component: Login, meta: { guest: true } },
  { path: '/', name: 'Dashboard', component: Dashboard, meta: { requiresAuth: true } },
  { path: '/dashboard', redirect: '/' },
  { path: '/reports', name: 'Reports', component: Reports, meta: { requiresAuth: true } },
  { path: '/chart-of-accounts', name: 'ChartOfAccounts', component: ChartOfAccounts, meta: { requiresAuth: true } },
  { path: '/transactions', name: 'Transactions', component: Transactions, meta: { requiresAuth: true } },
  
  // Admin routes
  { path: '/admin/users', name: 'AdminUsers', component: AdminUsers, meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/households', name: 'AdminHouseholds', component: AdminHouseholds, meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/accounts', name: 'AdminAccounts', component: AdminAccounts, meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/settings', name: 'AdminSettings', component: AdminSettings, meta: { requiresAuth: true, requiresAdmin: true } },
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to) => {
  const token = localStorage.getItem('auth_token')
  const user = JSON.parse(localStorage.getItem('current_user') || 'null')

  if (to.meta.requiresAuth && !token) {
    return { name: 'Login' }
  }
  if (to.meta.requiresAdmin && user?.role !== 'admin' && user?.role !== 'executive') {
    return { name: 'Dashboard' }
  }
  if (to.meta.guest && token) {
    return { name: 'Dashboard' }
  }
})

export default router
