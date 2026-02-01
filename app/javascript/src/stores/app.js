import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { apiClient } from '../api/client'

export const useAppStore = defineStore('app', () => {
  const currentCompany = ref(null)
  const companies = ref([])
  const chartOfAccounts = ref([])
  const transactions = ref([])
  const loading = ref(false)
  const dateRange = ref({
    start: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0],
    end: new Date().toISOString().split('T')[0]
  })

  async function fetchCompanies() {
    loading.value = true
    try {
      const data = await apiClient.get('/api/v1/companies')
      companies.value = data
    } finally {
      loading.value = false
    }
  }

  async function fetchChartOfAccounts(companyId) {
    loading.value = true
    try {
      const data = await apiClient.get(`/api/v1/companies/${companyId}/chart_of_accounts`)
      chartOfAccounts.value = data
    } finally {
      loading.value = false
    }
  }

  async function fetchTransactions(companyId, startDate, endDate) {
    loading.value = true
    try {
      const params = new URLSearchParams({ start_date: startDate, end_date: endDate })
      const data = await apiClient.get(`/api/v1/companies/${companyId}/transactions?${params}`)
      transactions.value = data
    } finally {
      loading.value = false
    }
  }

  function setCurrentCompany(company) {
    currentCompany.value = company
  }

  function setDateRange(range) {
    dateRange.value = range
  }

  return {
    currentCompany, companies, chartOfAccounts, transactions,
    loading, dateRange,
    fetchCompanies, fetchChartOfAccounts, fetchTransactions,
    setCurrentCompany, setDateRange
  }
})
