import { createRouter, createWebHistory } from 'vue-router'
import Dashboard from '../views/Dashboard.vue'
import Reports from '../views/Reports.vue'
import ChartOfAccounts from '../views/ChartOfAccounts.vue'
import Transactions from '../views/Transactions.vue'
import Login from '../views/Login.vue'
import AdminUsers from '../views/admin/AdminUsers.vue'
import AdminCompanies from '../views/admin/AdminCompanies.vue'
import AdminAccounts from '../views/admin/AdminAccounts.vue'
import AdminSettings from '../views/admin/AdminSettings.vue'
import AdminInvitations from '../views/admin/AdminInvitations.vue'
import AcceptInvite from '../views/AcceptInvite.vue'
import LinkedAccounts from '../views/LinkedAccounts.vue'

const routes = [
  { path: '/login', name: 'Login', component: Login, meta: { guest: true } },
  { path: '/', name: 'Dashboard', component: Dashboard, meta: { requiresAuth: true } },
  { path: '/dashboard', redirect: '/' },
  { path: '/reports', name: 'Reports', component: Reports, meta: { requiresAuth: true } },
  { path: '/chart-of-accounts', name: 'ChartOfAccounts', component: ChartOfAccounts, meta: { requiresAuth: true, canEdit: true } },
  { path: '/transactions', name: 'Transactions', component: Transactions, meta: { requiresAuth: true } },
  { path: '/linked-accounts', name: 'LinkedAccounts', component: LinkedAccounts, meta: { requiresAuth: true } },
  
  // Admin routes (executive + manager)
  { path: '/admin/users', name: 'AdminUsers', component: AdminUsers, meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/companies', name: 'AdminCompanies', component: AdminCompanies, meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/accounts', name: 'AdminAccounts', component: AdminAccounts, meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/invitations', name: 'AdminInvitations', component: AdminInvitations, meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/settings', name: 'AdminSettings', component: AdminSettings, meta: { requiresAuth: true, requiresExecutive: true } },
  
  // Public invitation acceptance
  { path: '/invite/:token', name: 'AcceptInvite', component: AcceptInvite, meta: { guest: true } },
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to) => {
  const token = localStorage.getItem('auth_token')
  const user = JSON.parse(localStorage.getItem('current_user') || 'null')
  const role = user?.role

  if (to.meta.requiresAuth && !token) {
    return { name: 'Login' }
  }
  // Executive + Manager can see admin
  if (to.meta.requiresAdmin && role !== 'executive' && role !== 'manager') {
    return { name: 'Dashboard' }
  }
  // Only executive can access settings
  if (to.meta.requiresExecutive && role !== 'executive') {
    return { name: 'Dashboard' }
  }
  if (to.meta.guest && token) {
    return { name: 'Dashboard' }
  }
})

export default router
