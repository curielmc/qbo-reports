<template>
  <div>
    <!-- Stats Overview -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-primary">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block w-8 h-8 stroke-current">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"></path>
          </svg>
        </div>
        <div class="stat-title">Households</div>
        <div class="stat-value text-primary">{{ stats.households }}</div>
      </div>

      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-secondary">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block w-8 h-8 stroke-current">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"></path>
          </svg>
        </div>
        <div class="stat-title">Accounts</div>
        <div class="stat-value text-secondary">{{ stats.accounts }}</div>
      </div>

      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-accent">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block w-8 h-8 stroke-current">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path>
          </svg>
        </div>
        <div class="stat-title">Transactions</div>
        <div class="stat-value text-accent">{{ stats.transactions }}</div>
      </div>

      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-success">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block w-8 h-8 stroke-current">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
        </div>
        <div class="stat-title">Net Income</div>
        <div class="stat-value text-success">{{ formatCurrency(stats.netIncome) }}</div>
        <div class="stat-desc">Year to date</div>
      </div>
    </div>

    <!-- Household Selector -->
    <div class="card bg-base-100 shadow-xl mb-8" v-if="appStore.households.length > 0">
      <div class="card-body">
        <h2 class="card-title">Select Household</h2>
        <div class="flex flex-wrap gap-2">
          <button 
            v-for="household in appStore.households" 
            :key="household.id"
            @click="appStore.setCurrentHousehold(household)"
            :class="['btn btn-sm', appStore.currentHousehold?.id === household.id ? 'btn-primary' : 'btn-outline']"
          >
            {{ household.name }}
          </button>
        </div>
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <router-link to="/reports" class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow cursor-pointer">
        <div class="card-body items-center text-center">
          <div class="text-4xl mb-2">📈</div>
          <h2 class="card-title">Financial Reports</h2>
          <p class="text-base-content/60">P&L statements and balance sheets</p>
          <div class="card-actions mt-4">
            <div class="btn btn-primary btn-sm">View Reports</div>
          </div>
        </div>
      </router-link>

      <router-link to="/chart-of-accounts" class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow cursor-pointer">
        <div class="card-body items-center text-center">
          <div class="text-4xl mb-2">📋</div>
          <h2 class="card-title">Chart of Accounts</h2>
          <p class="text-base-content/60">Manage account structure</p>
          <div class="card-actions mt-4">
            <div class="btn btn-secondary btn-sm">Manage</div>
          </div>
        </div>
      </router-link>

      <router-link to="/transactions" class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow cursor-pointer">
        <div class="card-body items-center text-center">
          <div class="text-4xl mb-2">💳</div>
          <h2 class="card-title">Transactions</h2>
          <p class="text-base-content/60">View and categorize transactions</p>
          <div class="card-actions mt-4">
            <div class="btn btn-accent btn-sm">Browse</div>
          </div>
        </div>
      </router-link>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAppStore } from '../stores/app'

const appStore = useAppStore()

const stats = ref({
  households: 0,
  accounts: 0,
  transactions: 0,
  netIncome: 0
})

const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0
  }).format(amount || 0)
}

onMounted(async () => {
  await appStore.fetchHouseholds()
  stats.value.households = appStore.households.length
})
</script>
