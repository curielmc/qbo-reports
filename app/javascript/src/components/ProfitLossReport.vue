<template>
  <div class="p-and-l-report">
    <div class="header">
      <h2>Profit & Loss</h2>
      <div class="date-range">
        <input type="date" v-model="startDate" @change="fetchReport" />
        <span>to</span>
        <input type="date" v-model="endDate" @change="fetchReport" />
      </div>
    </div>

    <div class="report-body" v-if="report">
      <!-- Income Section -->
      <div class="section income">
        <h3>Income</h3>
        <div class="account-list">
          <div v-for="account in report.income.accounts" :key="account.id" class="account-row">
            <span class="account-name">{{ account.code }} - {{ account.name }}</span>
            <span class="amount">{{ formatCurrency(account.amount) }}</span>
          </div>
        </div>
        <div class="total-row">
          <span>Total Income</span>
          <span class="amount">{{ formatCurrency(report.income.total) }}</span>
        </div>
      </div>

      <!-- Expenses Section -->
      <div class="section expenses">
        <h3>Expenses</h3>
        <div class="account-list">
          <div v-for="account in report.expenses.accounts" :key="account.id" class="account-row">
            <span class="account-name">{{ account.code }} - {{ account.name }}</span>
            <span class="amount">{{ formatCurrency(account.amount) }}</span>
          </div>
        </div>
        <div class="total-row">
          <span>Total Expenses</span>
          <span class="amount">{{ formatCurrency(report.expenses.total) }}</span>
        </div>
      </div>

      <!-- Net Income -->
      <div class="net-income" :class="{ positive: report.net_income >= 0, negative: report.net_income < 0 }">
        <span>Net Income</span>
        <span class="amount">{{ formatCurrency(report.net_income) }}</span>
      </div>
    </div>

    <div v-else class="loading">Loading...</div>
  </div>
</template>

<script>
export default {
  name: 'ProfitLossReport',
  data() {
    return {
      startDate: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0],
      endDate: new Date().toISOString().split('T')[0],
      report: null
    }
  },
  mounted() {
    this.fetchReport()
  },
  methods: {
    async fetchReport() {
      const companyId = this.$store.state.currentCompany?.id
      if (!companyId) return

      const params = new URLSearchParams({
        start_date: this.startDate,
        end_date: this.endDate
      })

      const response = await fetch(`/api/v1/companies/${companyId}/reports/profit_loss?${params}`)
      this.report = await response.json()
    },
    formatCurrency(amount) {
      return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
      }).format(amount)
    }
  }
}
</script>

<style scoped>
.p-and-l-report {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
}

.date-range {
  display: flex;
  gap: 10px;
  align-items: center;
}

.section {
  background: white;
  border-radius: 8px;
  padding: 20px;
  margin-bottom: 20px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.section h3 {
  margin-bottom: 15px;
  padding-bottom: 10px;
  border-bottom: 2px solid #e0e0e0;
}

.account-row {
  display: flex;
  justify-content: space-between;
  padding: 8px 0;
  border-bottom: 1px solid #f0f0f0;
}

.total-row {
  display: flex;
  justify-content: space-between;
  padding: 15px 0 0;
  margin-top: 10px;
  font-weight: bold;
  border-top: 2px solid #e0e0e0;
}

.net-income {
  display: flex;
  justify-content: space-between;
  padding: 20px;
  background: #f5f5f5;
  border-radius: 8px;
  font-size: 1.2em;
  font-weight: bold;
}

.net-income.positive { background: #e8f5e9; }
.net-income.negative { background: #ffebee; }

.amount {
  font-family: monospace;
}
</style>
