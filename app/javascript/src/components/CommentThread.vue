<template>
  <div class="comment-thread">
    <!-- Header -->
    <div v-if="showHeader" class="flex items-center justify-between mb-3">
      <h3 class="font-bold text-sm">
        Comments
        <span v-if="comments.length" class="badge badge-sm badge-ghost ml-1">{{ comments.length }}</span>
      </h3>
      <button v-if="collapsible" @click="collapsed = !collapsed" class="btn btn-ghost btn-xs">
        {{ collapsed ? 'Show' : 'Hide' }}
      </button>
    </div>

    <div v-show="!collapsed">
      <!-- Comments List -->
      <div v-if="comments.length" class="space-y-3 mb-4 max-h-96 overflow-y-auto">
        <div v-for="comment in comments" :key="comment.id"
          class="flex gap-3 group">
          <!-- Avatar -->
          <div class="avatar placeholder flex-shrink-0">
            <div class="bg-neutral text-neutral-content rounded-full w-8 h-8">
              <span class="text-xs">{{ initials(comment.user) }}</span>
            </div>
          </div>
          <!-- Comment body -->
          <div class="flex-1 min-w-0">
            <div class="flex items-baseline gap-2">
              <span class="font-semibold text-sm">{{ comment.user.name }}</span>
              <span class="text-xs text-base-content/40">{{ timeAgo(comment.created_at) }}</span>
              <button v-if="comment.is_author || isAdmin"
                @click="deleteComment(comment.id)"
                class="btn btn-ghost btn-xs opacity-0 group-hover:opacity-100 text-error ml-auto">
                Delete
              </button>
            </div>
            <div class="text-sm mt-0.5 whitespace-pre-wrap break-words" v-html="renderBody(comment.body)"></div>
          </div>
        </div>
      </div>

      <div v-else-if="!loading" class="text-center py-4 text-sm text-base-content/40">
        No comments yet. Be the first to add one.
      </div>

      <!-- Loading -->
      <div v-if="loading" class="flex justify-center py-4">
        <span class="loading loading-spinner loading-sm"></span>
      </div>

      <!-- New Comment Input -->
      <div class="relative">
        <div class="flex gap-2">
          <div class="avatar placeholder flex-shrink-0 mt-1">
            <div class="bg-primary text-primary-content rounded-full w-8 h-8">
              <span class="text-xs">{{ currentUserInitials }}</span>
            </div>
          </div>
          <div class="flex-1 relative">
            <textarea
              ref="inputRef"
              v-model="newComment"
              @keydown="handleKeydown"
              @input="handleInput"
              :placeholder="placeholder"
              class="textarea textarea-bordered w-full text-sm min-h-[44px] resize-none"
              rows="1"
            ></textarea>

            <!-- Mention Dropdown -->
            <div v-if="showMentionDropdown && filteredUsers.length"
              class="absolute z-50 bg-base-100 border border-base-300 rounded-lg shadow-xl mt-1 max-h-48 overflow-y-auto w-64"
              :style="mentionDropdownStyle">
              <ul class="py-1">
                <li v-for="(user, i) in filteredUsers" :key="user.id"
                  @mousedown.prevent="insertMention(user)"
                  :class="['flex items-center gap-2 px-3 py-2 cursor-pointer text-sm hover:bg-base-200 transition',
                            i === mentionIndex ? 'bg-base-200' : '']">
                  <div class="avatar placeholder flex-shrink-0">
                    <div class="bg-neutral text-neutral-content rounded-full w-6 h-6">
                      <span class="text-[10px]">{{ initials(user) }}</span>
                    </div>
                  </div>
                  <div class="min-w-0">
                    <div class="font-medium truncate">{{ user.name }}</div>
                    <div class="text-xs text-base-content/40 truncate">{{ user.email }}</div>
                  </div>
                </li>
              </ul>
            </div>

            <div class="flex items-center justify-between mt-1">
              <span class="text-xs text-base-content/40">
                Type <kbd class="kbd kbd-xs">@</kbd> to mention someone
              </span>
              <button
                @click="submitComment"
                :disabled="!newComment.trim() || submitting"
                class="btn btn-primary btn-xs">
                <span v-if="submitting" class="loading loading-spinner loading-xs"></span>
                Post
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { apiClient } from '../api/client'
import { useAuthStore } from '../stores/auth'
import { useAppStore } from '../stores/app'

const props = defineProps({
  commentableType: { type: String, required: true }, // 'company', 'transaction', 'journal_entry'
  commentableId: { type: [Number, String], default: null },
  showHeader: { type: Boolean, default: true },
  collapsible: { type: Boolean, default: false },
  placeholder: { type: String, default: 'Add a comment...' },
  autoLoad: { type: Boolean, default: true }
})

const emit = defineEmits(['comment-added', 'comment-deleted', 'count-changed'])

const authStore = useAuthStore()
const appStore = useAppStore()

const comments = ref([])
const newComment = ref('')
const loading = ref(false)
const submitting = ref(false)
const collapsed = ref(false)
const mentionableUsers = ref([])
const showMentionDropdown = ref(false)
const mentionQuery = ref('')
const mentionIndex = ref(0)
const mentionStartPos = ref(0)
const inputRef = ref(null)

const companyId = computed(() => appStore.activeCompany?.id)

const isAdmin = computed(() => authStore.isAdmin)

const currentUserInitials = computed(() => {
  const u = authStore.user
  if (!u) return '?'
  return `${(u.first_name || '')[0] || ''}${(u.last_name || '')[0] || ''}`.toUpperCase()
})

const filteredUsers = computed(() => {
  const q = mentionQuery.value.toLowerCase()
  if (!q) return mentionableUsers.value.slice(0, 8)
  return mentionableUsers.value
    .filter(u =>
      u.name.toLowerCase().includes(q) ||
      u.email.toLowerCase().includes(q) ||
      (u.first_name || '').toLowerCase().includes(q) ||
      (u.last_name || '').toLowerCase().includes(q)
    )
    .slice(0, 8)
})

const mentionDropdownStyle = computed(() => {
  return { left: '0px', top: '100%' }
})

function buildApiUrl(suffix = '') {
  const cid = companyId.value
  if (!cid) return null

  if (props.commentableType === 'transaction' && props.commentableId) {
    return `/api/v1/companies/${cid}/transactions/${props.commentableId}/comments${suffix}`
  } else if (props.commentableType === 'journal_entry' && props.commentableId) {
    return `/api/v1/companies/${cid}/journal_entries/${props.commentableId}/comments${suffix}`
  } else {
    return `/api/v1/companies/${cid}/comments${suffix}`
  }
}

async function fetchComments() {
  const url = buildApiUrl()
  if (!url) return

  loading.value = true
  try {
    const data = await apiClient.get(url)
    comments.value = data?.comments || []
    emit('count-changed', comments.value.length)
  } catch (e) {
    console.error('Failed to load comments:', e)
  } finally {
    loading.value = false
  }
}

async function fetchMentionableUsers() {
  const cid = companyId.value
  if (!cid) return
  try {
    const data = await apiClient.get(`/api/v1/companies/${cid}/comments/mentionable_users`)
    mentionableUsers.value = data?.users || []
  } catch (e) {
    console.error('Failed to load mentionable users:', e)
  }
}

async function submitComment() {
  if (!newComment.value.trim() || submitting.value) return

  const url = buildApiUrl()
  if (!url) return

  submitting.value = true
  try {
    const data = await apiClient.post(url, { body: newComment.value })
    if (data?.comment) {
      comments.value.push(data.comment)
      newComment.value = ''
      emit('comment-added', data.comment)
      emit('count-changed', comments.value.length)
    }
  } catch (e) {
    console.error('Failed to post comment:', e)
  } finally {
    submitting.value = false
  }
}

async function deleteComment(commentId) {
  if (!confirm('Delete this comment?')) return

  const cid = companyId.value
  try {
    await apiClient.delete(`/api/v1/companies/${cid}/comments/${commentId}`)
    comments.value = comments.value.filter(c => c.id !== commentId)
    emit('comment-deleted', commentId)
    emit('count-changed', comments.value.length)
  } catch (e) {
    console.error('Failed to delete comment:', e)
  }
}

function handleKeydown(e) {
  if (showMentionDropdown.value && filteredUsers.value.length) {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      mentionIndex.value = (mentionIndex.value + 1) % filteredUsers.value.length
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      mentionIndex.value = (mentionIndex.value - 1 + filteredUsers.value.length) % filteredUsers.value.length
    } else if (e.key === 'Enter' || e.key === 'Tab') {
      e.preventDefault()
      insertMention(filteredUsers.value[mentionIndex.value])
    } else if (e.key === 'Escape') {
      showMentionDropdown.value = false
    }
  } else if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
    e.preventDefault()
    submitComment()
  }
}

function handleInput(e) {
  const textarea = e.target
  const text = textarea.value
  const cursorPos = textarea.selectionStart

  // Auto-resize textarea
  textarea.style.height = 'auto'
  textarea.style.height = Math.min(textarea.scrollHeight, 160) + 'px'

  // Check if user is typing a mention (@ followed by text)
  const textBeforeCursor = text.substring(0, cursorPos)
  const mentionMatch = textBeforeCursor.match(/@(\w*)$/)

  if (mentionMatch) {
    mentionQuery.value = mentionMatch[1]
    mentionStartPos.value = cursorPos - mentionMatch[0].length
    showMentionDropdown.value = true
    mentionIndex.value = 0
  } else {
    showMentionDropdown.value = false
  }
}

function insertMention(user) {
  const text = newComment.value
  const before = text.substring(0, mentionStartPos.value)
  const after = text.substring(inputRef.value.selectionStart)

  // Insert mention in format: @[Name](id) - this is parsed by the backend
  const mentionText = `@[${user.name}](${user.id}) `
  newComment.value = before + mentionText + after

  showMentionDropdown.value = false
  mentionQuery.value = ''

  nextTick(() => {
    const newPos = before.length + mentionText.length
    inputRef.value.focus()
    inputRef.value.selectionStart = newPos
    inputRef.value.selectionEnd = newPos
  })
}

function renderBody(body) {
  // Convert @[Name](id) mentions to styled spans
  return body
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/@\[([^\]]+)\]\(\d+\)/g, '<span class="badge badge-sm badge-primary gap-1">@$1</span>')
}

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

// Public method to refresh from parent
function refresh() {
  fetchComments()
}

defineExpose({ refresh, comments })

watch(() => [props.commentableId, companyId.value], () => {
  if (props.autoLoad && companyId.value) {
    fetchComments()
  }
})

onMounted(() => {
  if (props.autoLoad && companyId.value) {
    fetchComments()
    fetchMentionableUsers()
  }
})
</script>
