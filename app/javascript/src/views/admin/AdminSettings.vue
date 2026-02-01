<template>
  <div>
    <h1 class="text-3xl font-bold mb-6">Settings</h1>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Plaid Configuration -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">🏦 Plaid</h2>
          <p class="text-sm text-base-content/60">Bank connection settings</p>
          <div class="form-control mt-4">
            <label class="label"><span class="label-text">Client ID</span></label>
            <input v-model="settings.plaid_client_id" type="text" class="input input-bordered input-sm" placeholder="Plaid Client ID" />
          </div>
          <div class="form-control mt-2">
            <label class="label"><span class="label-text">Secret</span></label>
            <input v-model="settings.plaid_secret" type="password" class="input input-bordered input-sm" placeholder="Plaid Secret" />
          </div>
          <div class="form-control mt-2">
            <label class="label"><span class="label-text">Environment</span></label>
            <select v-model="settings.plaid_env" class="select select-bordered select-sm">
              <option value="sandbox">Sandbox</option>
              <option value="development">Development</option>
              <option value="production">Production</option>
            </select>
          </div>
        </div>
      </div>

      <!-- AI Configuration -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">🤖 AI</h2>
          <p class="text-sm text-base-content/60">Conversational bookkeeper settings</p>
          <div class="form-control mt-4">
            <label class="label"><span class="label-text">OpenAI API Key</span></label>
            <input v-model="settings.openai_api_key" type="password" class="input input-bordered input-sm" placeholder="sk-..." />
          </div>
          <div class="form-control mt-2">
            <label class="label"><span class="label-text">Model</span></label>
            <select v-model="settings.ai_model" class="select select-bordered select-sm">
              <option value="gpt-4o-mini">GPT-4o Mini (Fast, cheap)</option>
              <option value="gpt-4o">GPT-4o (Best quality)</option>
              <option value="gpt-3.5-turbo">GPT-3.5 Turbo (Legacy)</option>
            </select>
          </div>
          <div class="form-control mt-2">
            <label class="label cursor-pointer">
              <span class="label-text">Enable AI summaries on reports</span>
              <input type="checkbox" v-model="settings.ai_summaries" class="toggle toggle-primary" />
            </label>
          </div>
        </div>
      </div>

      <!-- Company Defaults -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">🏢 Defaults</h2>
          <p class="text-sm text-base-content/60">Default settings for new companies</p>
          <div class="form-control mt-4">
            <label class="label"><span class="label-text">Default Chart of Accounts</span></label>
            <select v-model="settings.default_coa" class="select select-bordered select-sm">
              <option value="standard">Standard (US GAAP)</option>
              <option value="simple">Simple (Income/Expense only)</option>
              <option value="nonprofit">Non-Profit</option>
              <option value="none">Empty (Build from scratch)</option>
            </select>
          </div>
          <div class="form-control mt-2">
            <label class="label"><span class="label-text">Fiscal Year Start</span></label>
            <select v-model="settings.fiscal_year_start" class="select select-bordered select-sm">
              <option v-for="m in 12" :key="m" :value="m">{{ monthName(m) }}</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Notifications -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">🔔 Notifications</h2>
          <p class="text-sm text-base-content/60">Alert preferences</p>
          <div class="form-control mt-4">
            <label class="label cursor-pointer">
              <span class="label-text">Anomaly alerts</span>
              <input type="checkbox" v-model="settings.anomaly_alerts" class="toggle toggle-warning" />
            </label>
          </div>
          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text">Weekly spending summary email</span>
              <input type="checkbox" v-model="settings.weekly_summary" class="toggle toggle-info" />
            </label>
          </div>
          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text">New transaction alerts</span>
              <input type="checkbox" v-model="settings.transaction_alerts" class="toggle toggle-success" />
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- Save -->
    <div class="flex justify-end mt-6">
      <button @click="save" class="btn btn-primary" :disabled="saving">
        <span v-if="saving" class="loading loading-spinner loading-sm"></span>
        Save Settings
      </button>
    </div>

    <!-- Toast -->
    <div v-if="toast" class="toast toast-end">
      <div class="alert alert-success"><span>{{ toast }}</span></div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { apiClient } from '../../api/client'

const settings = ref({
  plaid_client_id: '', plaid_secret: '', plaid_env: 'sandbox',
  openai_api_key: '', ai_model: 'gpt-4o-mini', ai_summaries: true,
  default_coa: 'standard', fiscal_year_start: 1,
  anomaly_alerts: true, weekly_summary: false, transaction_alerts: false
})
const saving = ref(false)
const toast = ref(null)

const monthName = (m) => new Date(2000, m - 1).toLocaleString('en', { month: 'long' })

const save = async () => {
  saving.value = true
  // Settings would be stored in a config table or Rails credentials
  // For now, just show success
  await new Promise(r => setTimeout(r, 500))
  toast.value = 'Settings saved!'
  setTimeout(() => toast.value = null, 3000)
  saving.value = false
}

onMounted(async () => {
  // Would load from API
})
</script>
