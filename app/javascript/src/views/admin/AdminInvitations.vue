<template>
  <div>
    <div class="flex justify-between items-center mb-8">
      <div>
        <h1 class="text-3xl font-bold">Client Invitations</h1>
        <p class="text-base-content/60 mt-1">Invite clients to set up their ecfoBooks account</p>
      </div>
      <button @click="showInviteModal = true" class="btn btn-primary gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
        </svg>
        Send Invitation
      </button>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-warning">📨</div>
        <div class="stat-title">Pending</div>
        <div class="stat-value text-warning">{{ pendingCount }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-success">✅</div>
        <div class="stat-title">Accepted</div>
        <div class="stat-value text-success">{{ acceptedCount }}</div>
      </div>
      <div class="stat bg-base-100 rounded-box shadow">
        <div class="stat-figure text-error">⏰</div>
        <div class="stat-title">Expired</div>
        <div class="stat-value text-error">{{ expiredCount }}</div>
      </div>
    </div>

    <!-- Invitations Table -->
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Recipient</th>
                <th>Role</th>
                <th>Company</th>
                <th>Status</th>
                <th>Sent</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="inv in invitations" :key="inv.id" class="hover">
                <td>
                  <div class="font-medium">{{ inv.first_name }} {{ inv.last_name }}</div>
                  <div class="text-sm text-base-content/60">{{ inv.email }}</div>
                </td>
                <td><span class="badge badge-sm badge-outline">{{ capitalize(inv.role) }}</span></td>
                <td>{{ inv.company_name || '—' }}</td>
                <td>
                  <span :class="['badge badge-sm', statusBadge(inv.status)]">
                    {{ capitalize(inv.status) }}
                  </span>
                </td>
                <td class="text-sm">{{ formatDate(inv.created_at) }}</td>
                <td class="text-right">
                  <div class="flex gap-1 justify-end">
                    <button 
                      v-if="inv.status === 'pending'"
                      @click="copyLink(inv)" 
                      class="btn btn-ghost btn-xs"
                      title="Copy invite link"
                    >📋</button>
                    <button 
                      v-if="inv.status === 'pending' || inv.status === 'expired'"
                      @click="resendInvite(inv)" 
                      class="btn btn-ghost btn-xs"
                      title="Resend"
                    >🔄</button>
                    <button 
                      v-if="inv.status !== 'accepted'"
                      @click="cancelInvite(inv)" 
                      class="btn btn-ghost btn-xs text-error"
                      title="Cancel"
                    >✕</button>
                  </div>
                </td>
              </tr>
              <tr v-if="invitations.length === 0">
                <td colspan="6" class="text-center py-8 text-base-content/50">
                  No invitations sent yet. Click "Send Invitation" to invite your first client.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Send Invitation Modal -->
    <dialog :class="['modal', showInviteModal ? 'modal-open' : '']">
      <div class="modal-box w-11/12 max-w-2xl">
        <h3 class="font-bold text-lg mb-4">Send Invitation</h3>
        <form @submit.prevent="sendInvitation">
          <div class="grid grid-cols-2 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">First Name</span></label>
              <input v-model="form.first_name" type="text" class="input input-bordered" required />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Last Name</span></label>
              <input v-model="form.last_name" type="text" class="input input-bordered" required />
            </div>
          </div>
          <div class="form-control mt-4">
            <label class="label"><span class="label-text">Email Address</span></label>
            <input v-model="form.email" type="email" class="input input-bordered" required />
          </div>
          <div class="grid grid-cols-2 gap-4 mt-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Role</span></label>
              <select v-model="form.role" class="select select-bordered">
                <option value="client">Client</option>
                <option value="viewer">Viewer (read-only)</option>
                <option value="advisor">Advisor</option>
                <option value="manager">Manager</option>
              </select>
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Assign to Company</span></label>
              <select v-model="form.company_id" class="select select-bordered">
                <option value="">None (assign later)</option>
                <option v-for="h in companies" :key="h.id" :value="h.id">{{ h.name }}</option>
              </select>
            </div>
          </div>
          <div class="form-control mt-4">
            <label class="label"><span class="label-text">Personal Message (optional)</span></label>
            <textarea 
              v-model="form.personal_message" 
              class="textarea textarea-bordered" 
              rows="3"
              placeholder="Welcome to ecfoBooks! We're excited to help you manage your finances..."
            ></textarea>
          </div>
          <div class="modal-action">
            <button type="button" @click="showInviteModal = false" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary" :disabled="sending">
              <span v-if="sending" class="loading loading-spinner loading-sm"></span>
              {{ sending ? 'Sending...' : 'Send Invitation' }}
            </button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showInviteModal = false"><button>close</button></form>
    </dialog>

    <!-- Success Toast -->
    <div v-if="toast" class="toast toast-end">
      <div :class="['alert', toast.type === 'success' ? 'alert-success' : 'alert-info']">
        <span>{{ toast.message }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { apiClient } from '../../api/client'

const invitations = ref([])
const companies = ref([])
const showInviteModal = ref(false)
const sending = ref(false)
const toast = ref(null)
const form = ref({ first_name: '', last_name: '', email: '', role: 'client', company_id: '', personal_message: '' })

const pendingCount = computed(() => invitations.value.filter(i => i.status === 'pending').length)
const acceptedCount = computed(() => invitations.value.filter(i => i.status === 'accepted').length)
const expiredCount = computed(() => invitations.value.filter(i => i.status === 'expired').length)

const capitalize = (s) => s ? s.charAt(0).toUpperCase() + s.slice(1) : ''
const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : ''
const statusBadge = (s) => ({ pending: 'badge-warning', accepted: 'badge-success', expired: 'badge-error' }[s] || 'badge-ghost')

const showToast = (message, type = 'success') => {
  toast.value = { message, type }
  setTimeout(() => toast.value = null, 3000)
}

const sendInvitation = async () => {
  sending.value = true
  try {
    const result = await apiClient.post('/api/v1/admin/invitations', { invitation: form.value })
    if (result?.errors) {
      showToast(result.errors.join(', '), 'error')
    } else {
      showInviteModal.value = false
      form.value = { first_name: '', last_name: '', email: '', role: 'client', company_id: '', personal_message: '' }
      showToast('Invitation sent!')
      await fetchInvitations()
    }
  } finally {
    sending.value = false
  }
}

const copyLink = (inv) => {
  navigator.clipboard.writeText(inv.invite_url)
  showToast('Invite link copied to clipboard')
}

const resendInvite = async (inv) => {
  await apiClient.post(`/api/v1/admin/invitations/${inv.id}/resend`)
  showToast('Invitation resent')
  await fetchInvitations()
}

const cancelInvite = async (inv) => {
  if (confirm('Cancel this invitation?')) {
    await apiClient.delete(`/api/v1/admin/invitations/${inv.id}`)
    await fetchInvitations()
  }
}

const fetchInvitations = async () => {
  invitations.value = await apiClient.get('/api/v1/admin/invitations') || []
}

onMounted(async () => {
  await fetchInvitations()
  companies.value = await apiClient.get('/api/v1/admin/companies') || []
})
</script>
