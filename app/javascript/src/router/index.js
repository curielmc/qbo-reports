import Vue from 'vue'
import VueRouter from 'vue-router'
import Dashboard from '../views/Dashboard.vue'
import Reports from '../views/Reports.vue'
import ChartOfAccounts from '../views/ChartOfAccounts.vue'
import Transactions from '../views/Transactions.vue'

Vue.use(VueRouter)

const routes = [
  { path: '/', name: 'Dashboard', component: Dashboard },
  { path: '/reports', name: 'Reports', component: Reports },
  { path: '/chart-of-accounts', name: 'ChartOfAccounts', component: ChartOfAccounts },
  { path: '/transactions', name: 'Transactions', component: Transactions },
]

const router = new VueRouter({
  mode: 'history',
  routes
})

export default router
