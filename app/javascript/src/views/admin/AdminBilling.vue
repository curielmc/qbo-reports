<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-3xl font-bold">Billing</h1>
        <p class="text-base-content/60 mt-1">Manage client engagements and AI query billing</p>
      </div>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-title">Active Clients</div>
        <div class="stat-value text-primary">{{ companies.length }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-title">Total Monthly Revenue</div>
        <div class="stat-value text-success text-2xl">{{ formatCurrency(totalMonthlyFees) }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-title">Total AI Overage</div>
        <div class="stat-value text-warning text-2xl">{{ formatCurrency(totalOverage) }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-title">Total Queries This Cycle</div>
        <div class="stat-value text-2xl">{{ totalQueries }}</div>
      </div>
    </div>

    <!-- Client Billing Table -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body p-0">
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr class="bg-base-200">
                <th>Company</th>
                <th>Engagement</th>
                <th>Base Fee</th>
                <th>AI Credit</th>
                <th>Used</th>
                <th>Remaining</th>
                <th>Queries</th>
                <th>Overage</th>
                <th class="text-right">Total Due</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="c in companies" :key="c.id" class="hover">
                <td class="font-medium">{{ c.name }}</td>
                <td><span class="badge badge-sm badge-outline">{{ c.engagement_type }}</span></td>
                <td class="font-mono">{{ formatCurrency(c.monthly_fee) }}</td>
                <td class="font-mono">{{ formatCurrency(c.ai_credit) }}</td>
                <td class="font-mono">{{ formatCurrency(c.ai_credit_used) }}</td>
                <td>
                  <span :class="['font-mono', c.credit_remaining > 0 ? 'text-success' : 'text-error']">
                    {{ formatCurrency(c.credit_remaining) }}
                  </span>
                </td>
                <td class="font-mono text-center">{{ c.total_queries }}</td>
                <td :class="['font-mono', c.overage > 0 ? 'text-warning font-bold' : '']">
                  {{ c.overage > 0 ? formatCurrency(c.overage) : '—' }}
                </td>
                <td class="text-right font-mono font-bold">{{ formatCurrency(c.total_due) }}</td>
                <td>
                  <button @click="editBilling(c)" class="btn btn-ghost btn-xs">⚙️</button>
                  <button @click="resetCredit(c)" class="btn btn-ghost btn-xs" title="Reset credit">🔄</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Edit Billing Modal -->
    <dialog :class="['modal', showModal ? 'modal-open' : '']">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">{{ editingCompany?.name }} — Billing Settings</h3>
        <form @submit.prevent="saveBilling">
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Engagement Type</span></label>
            <select v-model="form.engagement_type" class="select select-bordered">
              <option value="flat_fee">Flat Fee (monthly)</option>
              <option value="hourly">Hourly</option>
            </select>
          </div>
          <div v-if="form.engagement_type === 'flat_fee'" class="form-control mb-3">
            <label class="label"><span class="label-text">Monthly Fee ($)</span></label>
            <input v-model.number="form.monthly_fee" type="number" step="0.01" class="input input-bordered" />
          </div>
          <div v-if="form.engagement_type === 'hourly'" class="form-control mb-3">
            <label class="label"><span class="label-text">Hourly Rate ($)</span></label>
            <input v-model.number="form.hourly_rate" type="number" step="0.01" class="input input-bordered" />
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">AI Query Credit ($)</span></label>
            <input v-model.number="creditDollars" type="number" step="1" class="input input-bordered" />
            <label class="label"><span class="label-text-alt">Included AI queries per billing cycle</span></label>
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Per Query Rate (¢) — after credit exhausted</span></label>
            <input v-model.number="form.per_query_cents" type="number" class="input input-bordered" />
            <label class="label"><span class="label-text-alt">${{ (form.per_query_cents / 100).toFixed(2) }} per query</span></label>
          </div>
          <div class="modal-action">
            <button type="button" @click="showModal = false" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showModal = false"><button>close</button></form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { apiClient } from '../../api/client'

const companies = ref([])
const showModal = ref(false)
const editingCompany = ref(null)
const creditDollars = ref(100)
const form = ref({ engagement_type: 'flat_fee', monthly_fee: 0, hourly_rate: 0, per_query_cents: 5 })

const formatCurrency = (n) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n || 0)

const totalMonthlyFees = computed(() => companies.value.reduce((s, c) => s + (c.monthly_fee || 0), 0))
const totalOverage = computed(() => companies.value.reduce((s, c) => s + (c.overage || 0), 0))
const totalQueries = computed(() => companies.value.reduce((s, c) => s + (c.total_queries || 0), 0))

const editBilling = (c) => {
  editingCompany.value = c
  creditDollars.value = c.ai_credit
  form.value = {
    engagement_type: c.engagement_type,
    monthly_fee: c.monthly_fee,
    hourly_rate: c.hourly_rate || 0,
    per_query_cents: 5 // default
  }
  showModal.value = true
}

const saveBilling = async () => {
  await apiClient.put(`/api/v1/admin/billing/${editingCompany.value.id}`, {
    billing: {
      ...form.value,
      ai_credit_cents: creditDollars.value * 100
    }
  })
  showModal.value = false
  await fetchBilling()
}

const resetCredit = async (c) => {
  if (!confirm(`Reset AI credit for ${c.name} to $${c.ai_credit}?`)) return
  await apiClient.post(`/api/v1/admin/billing/${c.id}/reset_credit`)
  await fetchBilling()
}

const fetchBilling = async () => {
  companies.value = await apiClient.get('/api/v1/admin/billing') || []
}

onMounted(fetchBilling)
</script>
