import Vue from 'vue'
import Vuex from 'vuex'

Vue.use(Vuex)

export default new Vuex.Store({
  state: {
    user: null,
    currentHousehold: null,
    households: [],
    chartOfAccounts: [],
    transactions: [],
    dateRange: {
      start: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0],
      end: new Date().toISOString().split('T')[0]
    }
  },
  mutations: {
    SET_USER(state, user) {
      state.user = user
    },
    SET_HOUSEHOLDS(state, households) {
      state.households = households
    },
    SET_CURRENT_HOUSEHOLD(state, household) {
      state.currentHousehold = household
    },
    SET_CHART_OF_ACCOUNTS(state, coa) {
      state.chartOfAccounts = coa
    },
    SET_TRANSACTIONS(state, transactions) {
      state.transactions = transactions
    },
    SET_DATE_RANGE(state, range) {
      state.dateRange = range
    }
  },
  actions: {
    async fetchHouseholds({ commit }) {
      const response = await fetch('/api/households')
      const data = await response.json()
      commit('SET_HOUSEHOLDS', data)
    },
    async fetchChartOfAccounts({ commit }, householdId) {
      const response = await fetch(`/api/households/${householdId}/chart_of_accounts`)
      const data = await response.json()
      commit('SET_CHART_OF_ACCOUNTS', data)
    },
    async fetchTransactions({ commit }, { householdId, startDate, endDate }) {
      const params = new URLSearchParams({ start_date: startDate, end_date: endDate })
      const response = await fetch(`/api/households/${householdId}/transactions?${params}`)
      const data = await response.json()
      commit('SET_TRANSACTIONS', data)
    }
  }
})
