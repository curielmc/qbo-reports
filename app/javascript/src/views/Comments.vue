<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Comments</h1>
        <p class="text-base-content/60 mt-1">Team notes and discussions across all records</p>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Company Notes (left/main column) -->
      <div class="lg:col-span-2 space-y-6">
        <!-- Company-level notes -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-lg">Company Notes</h2>
            <p class="text-sm text-base-content/50 mb-2">General notes, reminders, and questions about this company.</p>
            <CommentThread
              commentable-type="company"
              :show-header="false"
              placeholder="Add a note about this company... (use @ to mention someone)"
            />
          </div>
        </div>
      </div>

      <!-- Recent Activity Feed (right column) -->
      <div class="space-y-4">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-lg">Recent Activity</h2>
            <p class="text-sm text-base-content/50 mb-3">Latest comments across all transactions and entries.</p>

            <div v-if="loadingRecent" class="flex justify-center py-8">
              <span class="loading loading-spinner loading-md"></span>
            </div>

            <div v-else-if="recentComments.length" class="space-y-4">
              <div v-for="comment in recentComments" :key="comment.id" class="border-b border-base-200 pb-3 last:border-0">
                <div class="flex items-start gap-2">
                  <div class="avatar placeholder flex-shrink-0">
                    <div class="bg-neutral text-neutral-content rounded-full w-7 h-7">
                      <span class="text-[10px]">{{ initials(comment.user) }}</span>
                    </div>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-baseline gap-1.5">
                      <span class="font-semibold text-sm">{{ comment.user.name }}</span>
                      <span class="text-xs text-base-content/40">{{ timeAgo(comment.created_at) }}</span>
                    </div>
                    <div class="text-sm mt-0.5 whitespace-pre-wrap break-words" v-html="renderBody(comment.body)"></div>
                    <!-- Context badge -->
                    <div class="mt-1">
                      <span v-if="comment.commentable_type === 'Company'" class="badge badge-xs badge-outline">Company Note</span>
                      <span v-else-if="comment.commentable_type === 'AccountTransaction'" class="badge badge-xs badge-info">
                        Transaction: {{ comment.commentable_label }}
                      </span>
                      <span v-else-if="comment.commentable_type === 'JournalEntry'" class="badge badge-xs badge-warning">
                        Journal: {{ comment.commentable_label }}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div v-else class="text-center py-6 text-sm text-base-content/40">
              No comments yet across this company.
            </div>
          </div>
        </div>

        <!-- Team Members -->
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-lg">Team Members</h2>
            <p class="text-sm text-base-content/50 mb-3">People you can @mention in comments.</p>
            <div v-if="teamMembers.length" class="space-y-2">
              <div v-for="member in teamMembers" :key="member.id" class="flex items-center gap-2">
                <div class="avatar placeholder flex-shrink-0">
                  <div class="bg-neutral text-neutral-content rounded-full w-7 h-7">
                    <span class="text-[10px]">{{ initials(member) }}</span>
                  </div>
                </div>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-medium truncate">{{ member.name }}</p>
                  <p class="text-xs text-base-content/40 truncate">{{ member.email }}</p>
                </div>
                <span class="badge badge-xs badge-ghost">{{ member.role }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'
import CommentThread from '../components/CommentThread.vue'

const appStore = useAppStore()
const companyId = computed(() => appStore.activeCompany?.id)

const recentComments = ref([])
const teamMembers = ref([])
const loadingRecent = ref(false)

function initials(user) {
  if (!user) return '?'
  return `${(user.first_name || user.name?.[0] || '')[0] || ''}${(user.last_name || '')[0] || ''}`.toUpperCase()
}

function timeAgo(dateStr) {
  const date = new Date(dateStr)
  const now = new Date()
  const diff = Math.floor((now - date) / 1000)

  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

function renderBody(body) {
  return body
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/@\[([^\]]+)\]\(\d+\)/g, '<span class="badge badge-sm badge-primary gap-1">@$1</span>')
}

async function fetchRecentComments() {
  const cid = companyId.value
  if (!cid) return

  loadingRecent.value = true
  try {
    const data = await apiClient.get(`/api/v1/companies/${cid}/comments/recent?limit=30`)
    recentComments.value = data?.comments || []
  } catch (e) {
    console.error('Failed to load recent comments:', e)
  } finally {
    loadingRecent.value = false
  }
}

async function fetchTeamMembers() {
  const cid = companyId.value
  if (!cid) return

  try {
    const data = await apiClient.get(`/api/v1/companies/${cid}/comments/mentionable_users`)
    teamMembers.value = data?.users || []
  } catch (e) {
    console.error('Failed to load team members:', e)
  }
}

onMounted(() => {
  if (companyId.value) {
    fetchRecentComments()
    fetchTeamMembers()
  }
})
</script>
