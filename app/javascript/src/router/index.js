import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import Dashboard from '../views/Dashboard.vue'
import Reports from '../views/Reports.vue'
import ChartOfAccounts from '../views/ChartOfAccounts.vue'
import Transactions from '../views/Transactions.vue'
import Login from '../views/Login.vue'

const routes = [
  { path: '/login', name: 'Login', component: Login, meta: { guest: true } },
  { path: '/', name: 'Dashboard', component: Dashboard, meta: { requiresAuth: true } },
  { path: '/dashboard', redirect: '/' },
  { path: '/reports', name: 'Reports', component: Reports, meta: { requiresAuth: true } },
  { path: '/chart-of-accounts', name: 'ChartOfAccounts', component: ChartOfAccounts, meta: { requiresAuth: true } },
  { path: '/transactions', name: 'Transactions', component: Transactions, meta: { requiresAuth: true } },
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to) => {
  const token = localStorage.getItem('auth_token')

  if (to.meta.requiresAuth && !token) {
    return { name: 'Login' }
  }
  if (to.meta.guest && token) {
    return { name: 'Dashboard' }
  }
})

export default router
