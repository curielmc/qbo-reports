<template>
  <div class="balance-sheet-report">
    <div class="header">
      <h2>Balance Sheet</h2>
      <div class="date-selector">
        <label>As of:</label>
        <input type="date" v-model="asOfDate" @change="fetchReport" />
      </div>
    </div>

    <div class="report-body" v-if="report">
      <!-- Assets Section -->
      <div class="section assets">
        <h3>Assets</h3>
        <div class="account-list">
          <div v-for="account in report.assets.accounts" :key="account.id" class="account-row">
            <span class="account-name">{{ account.code }} - {{ account.name }}</span>
            <span class="amount">{{ formatCurrency(account.balance) }}</span>
          </div>
        </div>
        <div class="total-row">
          <span>Total Assets</span>
          <span class="amount">{{ formatCurrency(report.assets.total) }}</span>
        </div>
      </div>

      <!-- Liabilities Section -->
      <div class="section liabilities">
        <h3>Liabilities</h3>
        <div class="account-list">
          <div v-for="account in report.liabilities.accounts" :key="account.id" class="account-row">
            <span class="account-name">{{ account.code }} - {{ account.name }}</span>
            <span class="amount">{{ formatCurrency(account.balance) }}</span>
          </div>
        </div>
        <div class="total-row">
          <span>Total Liabilities</span>
          <span class="amount">{{ formatCurrency(report.liabilities.total) }}</span>
        </div>
      </div>

      <!-- Equity Section -->
      <div class="section equity">
        <h3>Equity</h3>
        <div class="account-list">
          <div v-for="account in report.equity.accounts" :key="account.id" class="account-row">
            <span class="account-name">{{ account.code }} - {{ account.name }}</span>
            <span class="amount">{{ formatCurrency(account.balance) }}</span>
          </div>
          <div class="account-row retained">
            <span class="account-name">Retained Earnings</span>
            <span class="amount">{{ formatCurrency(report.equity.retained_earnings) }}</span>
          </div>
        </div>
        <div class="total-row">
          <span>Total Equity</span>
          <span class="amount">{{ formatCurrency(report.equity.total + report.equity.retained_earnings) }}</span>
        </div>
      </div>

      <!-- Balance Check -->
      <div class="balance-check" :class="{ balanced: isBalanced }">
        <span>Total Liabilities + Equity</span>
        <span class="amount">{{ formatCurrency(report.total_liabilities_and_equity) }}</span>
      </div>
    </div>

    <div v-else class="loading">Loading...</div>
  </div>
</template>

<script>
export default {
  name: 'BalanceSheetReport',
  data() {
    return {
      asOfDate: new Date().toISOString().split('T')[0],
      report: null
    }
  },
  computed: {
    isBalanced() {
      if (!this.report) return false
      return Math.abs(this.report.assets.total - this.report.total_liabilities_and_equity) < 0.01
    }
  },
  mounted() {
    this.fetchReport()
  },
  methods: {
    async fetchReport() {
      const householdId = this.$store.state.currentHousehold?.id
      if (!householdId) return

      const params = new URLSearchParams({ as_of_date: this.asOfDate })
      const response = await fetch(`/api/v1/households/${householdId}/reports/balance_sheet?${params}`)
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
.balance-sheet-report {
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

.date-selector {
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

.assets h3 { color: #2e7d32; }
.liabilities h3 { color: #c62828; }
.equity h3 { color: #1565c0; }

.account-row {
  display: flex;
  justify-content: space-between;
  padding: 8px 0;
  border-bottom: 1px solid #f0f0f0;
}

.account-row.retained {
  font-style: italic;
  color: #666;
}

.total-row {
  display: flex;
  justify-content: space-between;
  padding: 15px 0 0;
  margin-top: 10px;
  font-weight: bold;
  border-top: 2px solid #e0e0e0;
}

.balance-check {
  display: flex;
  justify-content: space-between;
  padding: 20px;
  background: #ffebee;
  border-radius: 8px;
  font-size: 1.2em;
  font-weight: bold;
}

.balance-check.balanced {
  background: #e8f5e9;
}

.amount {
  font-family: monospace;
}
</style>
