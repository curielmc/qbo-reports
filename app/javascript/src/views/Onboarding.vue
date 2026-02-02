<template>
  <div class="min-h-screen flex items-center justify-center bg-base-200">
    <div class="card w-full max-w-2xl bg-base-100 shadow-2xl">
      <div class="card-body">
        <!-- Progress Steps -->
        <ul class="steps steps-horizontal w-full mb-8">
          <li :class="['step', currentStep >= 1 ? 'step-primary' : '']">Company</li>
          <li :class="['step', currentStep >= 2 ? 'step-primary' : '']">Connect Bank</li>
          <li :class="['step', currentStep >= 3 ? 'step-primary' : '']">Import Data</li>
          <li :class="['step', currentStep >= 4 ? 'step-primary' : '']">Ready!</li>
        </ul>

        <!-- Step 1: Company Info -->
        <div v-if="currentStep === 1">
          <h2 class="text-2xl font-bold mb-2">Let's set up your business</h2>
          <p class="text-base-content/60 mb-6">Tell us a bit about your company — the AI will customize everything for you.</p>

          <div class="form-control mb-4">
            <label class="label"><span class="label-text">Company Name</span></label>
            <input v-model="form.name" type="text" class="input input-bordered" placeholder="e.g. Acme LLC" />
          </div>
          <div class="grid grid-cols-2 gap-4 mb-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Business Type</span></label>
              <select v-model="form.business_type" class="select select-bordered">
                <option value="">Select...</option>
                <option value="llc">LLC</option>
                <option value="s_corp">S-Corp</option>
                <option value="c_corp">C-Corp</option>
                <option value="sole_prop">Sole Proprietorship</option>
                <option value="partnership">Partnership</option>
                <option value="nonprofit">Non-Profit</option>
                <option value="trust">Trust</option>
              </select>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Industry</span></label>
              <select v-model="form.industry" class="select select-bordered">
                <option value="">Select...</option>
                <option value="tech">Technology / SaaS</option>
                <option value="consulting">Consulting / Professional Services</option>
                <option value="retail">Retail / E-commerce</option>
                <option value="restaurant">Restaurant / Food Service</option>
                <option value="healthcare">Healthcare</option>
                <option value="real_estate">Real Estate</option>
                <option value="construction">Construction</option>
                <option value="creative">Creative / Agency</option>
                <option value="legal">Legal</option>
                <option value="other">Other</option>
              </select>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4 mb-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Tax Year</span></label>
              <select v-model="form.fiscal_year" class="select select-bordered">
                <option value="calendar">Calendar (Jan - Dec)</option>
                <option value="fiscal">Custom Fiscal Year</option>
              </select>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Accounting Method</span></label>
              <select v-model="form.accounting_method" class="select select-bordered">
                <option value="cash">Cash Basis</option>
                <option value="accrual">Accrual Basis</option>
              </select>
            </div>
          </div>

          <div class="card-actions justify-end mt-6">
            <button @click="createCompany" :disabled="!form.name" class="btn btn-primary">
              Continue →
            </button>
          </div>
        </div>

        <!-- Step 2: Connect Bank -->
        <div v-if="currentStep === 2">
          <h2 class="text-2xl font-bold mb-2">Connect your bank accounts</h2>
          <p class="text-base-content/60 mb-6">We'll pull transactions automatically. You can also upload statements if your bank isn't supported.</p>

          <div class="flex flex-col items-center gap-4">
            <button @click="connectPlaid" class="btn btn-primary btn-lg w-full max-w-sm">
              🏦 Connect with Plaid
            </button>
            <div class="divider w-full max-w-sm">OR</div>
            <label class="btn btn-outline btn-lg w-full max-w-sm">
              📄 Upload Bank Statement
              <input type="file" @change="uploadStatement" accept=".csv,.ofx,.qfx,.pdf" class="hidden" />
            </label>
          </div>

          <div v-if="connectedAccounts.length" class="mt-6">
            <h3 class="font-bold mb-2">Connected Accounts</h3>
            <div v-for="acct in connectedAccounts" :key="acct.id" class="flex items-center gap-3 p-3 bg-success/10 rounded-lg mb-2">
              <span class="text-success text-lg">✅</span>
              <span class="font-medium">{{ acct.name }}</span>
              <span class="text-sm text-base-content/50">{{ acct.mask }}</span>
            </div>
          </div>

          <div class="card-actions justify-between mt-6">
            <button @click="currentStep = 1" class="btn btn-ghost">← Back</button>
            <button @click="currentStep = 3" class="btn btn-primary">
              {{ connectedAccounts.length ? 'Continue →' : 'Skip for now →' }}
            </button>
          </div>
        </div>

        <!-- Step 3: Import Existing Data -->
        <div v-if="currentStep === 3">
          <h2 class="text-2xl font-bold mb-2">Import existing data?</h2>
          <p class="text-base-content/60 mb-6">If you're switching from another system, we can bring everything over.</p>

          <div class="grid grid-cols-2 gap-4 mb-6">
            <div v-for="src in importSources" :key="src.id"
              class="card bg-base-200 hover:bg-base-300 cursor-pointer transition p-4 text-center"
              @click="startImport(src)">
              <span class="text-3xl">{{ src.icon }}</span>
              <p class="font-medium text-sm mt-2">{{ src.name }}</p>
            </div>
          </div>

          <div class="card-actions justify-between mt-6">
            <button @click="currentStep = 2" class="btn btn-ghost">← Back</button>
            <button @click="finishSetup" class="btn btn-primary">
              {{ hasImported ? 'Continue →' : 'Skip — Start Fresh →' }}
            </button>
          </div>
        </div>

        <!-- Step 4: Ready! -->
        <div v-if="currentStep === 4" class="text-center">
          <p class="text-6xl mb-4">🎉</p>
          <h2 class="text-3xl font-bold mb-2">{{ form.name }} is ready!</h2>
          <p class="text-base-content/60 mb-4">Your AI bookkeeper is set up and waiting.</p>

          <div class="stats shadow bg-base-200 mb-8">
            <div class="stat">
              <div class="stat-title">Accounts</div>
              <div class="stat-value text-primary">{{ setupSummary.accounts }}</div>
            </div>
            <div class="stat">
              <div class="stat-title">Transactions</div>
              <div class="stat-value text-primary">{{ setupSummary.transactions }}</div>
            </div>
            <div class="stat">
              <div class="stat-title">Categories</div>
              <div class="stat-value text-primary">{{ setupSummary.categories }}</div>
            </div>
          </div>

          <p class="text-sm text-base-content/50 mb-6">
            💡 Tip: Just talk to the AI. Say things like "categorize my transactions" or "show me my P&L".
          </p>

          <router-link to="/" class="btn btn-primary btn-lg">
            💬 Start Chatting with Your Bookkeeper
          </router-link>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const router = useRouter()
const appStore = useAppStore()

const currentStep = ref(1)
const connectedAccounts = ref([])
const hasImported = ref(false)
const setupSummary = ref({ accounts: 0, transactions: 0, categories: 0 })

const form = ref({
  name: '',
  business_type: '',
  industry: '',
  fiscal_year: 'calendar',
  accounting_method: 'cash'
})

const importSources = [
  { id: 'qbo', name: 'QuickBooks Online', icon: '📗' },
  { id: 'qbd', name: 'QuickBooks Desktop', icon: '📘' },
  { id: 'xero', name: 'Xero', icon: '📋' },
  { id: 'csv', name: 'CSV / Excel', icon: '📄' },
]

const createCompany = async () => {
  const result = await apiClient.post('/api/v1/admin/companies', form.value)
  if (result?.id) {
    appStore.setCurrentCompany(result)
    currentStep.value = 2
  }
}

const connectPlaid = () => {
  // Will trigger Plaid Link flow
  router.push('/linked-accounts')
}

const uploadStatement = () => {
  router.push('/import')
}

const startImport = (src) => {
  router.push('/import')
}

const finishSetup = async () => {
  const cid = appStore.activeCompany?.id
  if (cid) {
    const [accounts, coa] = await Promise.all([
      apiClient.get(`/api/v1/companies/${cid}/accounts`),
      apiClient.get(`/api/v1/companies/${cid}/chart_of_accounts`)
    ])
    setupSummary.value = {
      accounts: accounts?.length || 0,
      transactions: 0, // Will be filled after import
      categories: coa?.length || 0
    }
  }
  currentStep.value = 4
}
</script>
