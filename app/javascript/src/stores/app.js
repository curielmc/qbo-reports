import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { apiClient } from '../api/client'

export const useAppStore = defineStore('app', () => {
  const currentHousehold = ref(null)
  const households = ref([])
  const chartOfAccounts = ref([])
  const transactions = ref([])
  const loading = ref(false)
  const dateRange = ref({
    start: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0],
    end: new Date().toISOString().split('T')[0]
  })

  async function fetchHouseholds() {
    loading.value = true
    try {
      const data = await apiClient.get('/api/v1/households')
      households.value = data
    } finally {
      loading.value = false
    }
  }

  async function fetchChartOfAccounts(householdId) {
    loading.value = true
    try {
      const data = await apiClient.get(`/api/v1/households/${householdId}/chart_of_accounts`)
      chartOfAccounts.value = data
    } finally {
      loading.value = false
    }
  }

  async function fetchTransactions(householdId, startDate, endDate) {
    loading.value = true
    try {
      const params = new URLSearchParams({ start_date: startDate, end_date: endDate })
      const data = await apiClient.get(`/api/v1/households/${householdId}/transactions?${params}`)
      transactions.value = data
    } finally {
      loading.value = false
    }
  }

  function setCurrentHousehold(household) {
    currentHousehold.value = household
  }

  function setDateRange(range) {
    dateRange.value = range
  }

  return {
    currentHousehold, households, chartOfAccounts, transactions,
    loading, dateRange,
    fetchHouseholds, fetchChartOfAccounts, fetchTransactions,
    setCurrentHousehold, setDateRange
  }
})
