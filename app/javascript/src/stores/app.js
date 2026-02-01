import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'
import { apiClient } from '../api/client'

export const useAppStore = defineStore('app', () => {
  const currentCompany = ref(JSON.parse(localStorage.getItem('current_company') || 'null'))
  const companies = ref(JSON.parse(localStorage.getItem('user_companies') || '[]'))
  const chartOfAccounts = ref([])
  const transactions = ref([])
  const loading = ref(false)
  const dateRange = ref({
    start: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0],
    end: new Date().toISOString().split('T')[0]
  })

  // Auto-select first company if none selected
  const activeCompany = computed(() => {
    if (currentCompany.value) return currentCompany.value
    if (companies.value.length) return companies.value[0]
    return null
  })

  async function fetchCompanies() {
    loading.value = true
    try {
      const data = await apiClient.get('/api/v1/companies')
      companies.value = data || []
      localStorage.setItem('user_companies', JSON.stringify(companies.value))
      
      // Auto-select if none
      if (!currentCompany.value && companies.value.length) {
        setCurrentCompany(companies.value[0])
      }
    } finally {
      loading.value = false
    }
  }

  function setCurrentCompany(company) {
    currentCompany.value = company
    localStorage.setItem('current_company', JSON.stringify(company))
  }

  function setCompanies(list) {
    companies.value = list || []
    localStorage.setItem('user_companies', JSON.stringify(companies.value))
    if (!currentCompany.value && companies.value.length) {
      setCurrentCompany(companies.value[0])
    }
  }

  async function fetchChartOfAccounts(companyId) {
    loading.value = true
    try {
      const cid = companyId || activeCompany.value?.id
      if (!cid) return
      const data = await apiClient.get(`/api/v1/companies/${cid}/chart_of_accounts`)
      chartOfAccounts.value = data
    } finally {
      loading.value = false
    }
  }

  async function fetchTransactions(companyId, startDate, endDate) {
    loading.value = true
    try {
      const cid = companyId || activeCompany.value?.id
      if (!cid) return
      const params = new URLSearchParams({ start_date: startDate, end_date: endDate })
      const data = await apiClient.get(`/api/v1/companies/${cid}/transactions?${params}`)
      transactions.value = data
    } finally {
      loading.value = false
    }
  }

  function setDateRange(range) {
    dateRange.value = range
  }

  return {
    currentCompany, companies, activeCompany,
    chartOfAccounts, transactions,
    loading, dateRange,
    fetchCompanies, fetchChartOfAccounts, fetchTransactions,
    setCurrentCompany, setCompanies, setDateRange
  }
})
