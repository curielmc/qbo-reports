<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Invitations</h1>
        <p class="text-base-content/60 mt-1">Invite clients and team members</p>
      </div>
      <button @click="showModal = true" class="btn btn-primary btn-sm gap-1">📨 Send Invite</button>
    </div>

    <div class="card bg-base-100 shadow-xl">
      <div class="card-body p-0">
        <div class="overflow-x-auto">
          <table class="table table-sm sm:table-md">
            <thead>
              <tr class="bg-base-200">
                <th>Email</th>
                <th>Company</th>
                <th>Role</th>
                <th>Status</th>
                <th>Sent</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="inv in invitations" :key="inv.id" class="hover">
                <td>{{ inv.email }}</td>
                <td>{{ inv.company_name }}</td>
                <td><span :class="['badge badge-sm', roleBadge(inv.role)]">{{ inv.role }}</span></td>
                <td>
                  <span :class="['badge badge-sm', inv.accepted_at ? 'badge-success' : inv.expired ? 'badge-error' : 'badge-warning']">
                    {{ inv.accepted_at ? 'Accepted' : inv.expired ? 'Expired' : 'Pending' }}
                  </span>
                </td>
                <td class="text-sm text-base-content/50">{{ formatDate(inv.created_at) }}</td>
                <td class="text-right">
                  <button v-if="!inv.accepted_at" @click="resend(inv)" class="btn btn-ghost btn-xs">Resend</button>
                  <button v-if="!inv.accepted_at" @click="copyLink(inv)" class="btn btn-ghost btn-xs">📋 Copy</button>
                  <button @click="deleteInvite(inv)" class="btn btn-ghost btn-xs text-error">Delete</button>
                </td>
              </tr>
              <tr v-if="invitations.length === 0">
                <td colspan="6" class="text-center py-8 text-base-content/50">No invitations sent yet.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Send Invite Modal -->
    <dialog :class="['modal', showModal ? 'modal-open' : '']">
      <div class="modal-box w-[95vw] sm:w-auto max-h-[90vh]">
        <h3 class="font-bold text-lg mb-4">Send Invitation</h3>
        <form @submit.prevent="sendInvite">
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Email</span></label>
            <input v-model="form.email" type="email" class="input input-bordered" placeholder="client@example.com" required />
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Company</span></label>
            <select v-model="form.company_id" class="select select-bordered" required>
              <option value="">Select company...</option>
              <option v-for="c in companies" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
          </div>
          <div class="form-control mb-3">
            <label class="label"><span class="label-text">Role</span></label>
            <select v-model="form.role" class="select select-bordered">
              <option value="client">Client</option>
              <option value="viewer">Viewer</option>
              <option value="advisor">Advisor</option>
            </select>
          </div>
          <div v-if="error" class="alert alert-error mb-3"><span>{{ error }}</span></div>
          <div class="modal-action">
            <button type="button" @click="showModal = false" class="btn">Cancel</button>
            <button type="submit" class="btn btn-primary">Send Invitation</button>
          </div>
        </form>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showModal = false"><button>close</button></form>
    </dialog>

    <!-- Toast -->
    <div v-if="toast" class="toast toast-end">
      <div class="alert alert-success"><span>{{ toast }}</span></div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { apiClient } from '../../api/client'

const invitations = ref([])
const companies = ref([])
const showModal = ref(false)
const error = ref(null)
const toast = ref(null)
const form = ref({ email: '', company_id: '', role: 'client' })

const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : ''
const roleBadge = (role) => ({ executive: 'badge-primary', manager: 'badge-secondary', advisor: 'badge-accent', client: 'badge-info', viewer: 'badge-ghost' }[role] || 'badge-ghost')

const showToast = (msg) => { toast.value = msg; setTimeout(() => toast.value = null, 3000) }

const sendInvite = async () => {
  try {
    error.value = null
    await apiClient.post('/api/v1/admin/invitations', { invitation: form.value })
    showModal.value = false
    showToast('Invitation sent!')
    form.value = { email: '', company_id: '', role: 'client' }
    await fetchInvitations()
  } catch (e) {
    error.value = e.message
  }
}

const resend = async (inv) => {
  await apiClient.post(`/api/v1/admin/invitations/${inv.id}/resend`)
  showToast('Invitation resent!')
}

const copyLink = (inv) => {
  const url = `${window.location.origin}/invite/${inv.token}`
  navigator.clipboard.writeText(url)
  showToast('Link copied!')
}

const deleteInvite = async (inv) => {
  if (!confirm('Delete this invitation?')) return
  await apiClient.delete(`/api/v1/admin/invitations/${inv.id}`)
  await fetchInvitations()
}

const fetchInvitations = async () => {
  invitations.value = await apiClient.get('/api/v1/admin/invitations') || []
}

onMounted(async () => {
  await fetchInvitations()
  companies.value = await apiClient.get('/api/v1/admin/companies') || []
})
</script>
