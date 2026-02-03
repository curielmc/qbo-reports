<template>
  <div class="flex flex-col h-[calc(100vh-8rem)]">
    <!-- Header -->
    <div class="flex justify-between items-center mb-4">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Messages</h1>
        <p class="text-base-content/60 mt-1">Company conversation thread &mdash; visible to everyone on this account</p>
      </div>
      <div class="flex items-center gap-2">
        <div class="avatar-group -space-x-3">
          <div v-for="p in participants.slice(0, 5)" :key="p.id"
            class="avatar placeholder" :title="p.name">
            <div class="bg-neutral text-neutral-content rounded-full w-8">
              <span class="text-[10px]">{{ initials(p) }}</span>
            </div>
          </div>
          <div v-if="participants.length > 5" class="avatar placeholder">
            <div class="bg-neutral text-neutral-content rounded-full w-8">
              <span class="text-[10px]">+{{ participants.length - 5 }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Message Thread -->
    <div class="card bg-base-100 shadow-xl flex-1 flex flex-col min-h-0">
      <div class="card-body p-0 flex flex-col min-h-0">
        <!-- Messages scroll area -->
        <div ref="messagesContainer" class="flex-1 overflow-y-auto p-4 space-y-4">
          <!-- Loading -->
          <div v-if="loading" class="flex justify-center py-12">
            <span class="loading loading-spinner loading-lg"></span>
          </div>

          <!-- Empty state -->
          <div v-else-if="!messages.length" class="text-center py-16">
            <p class="text-5xl mb-3">💬</p>
            <p class="text-lg font-medium mb-1">No messages yet</p>
            <p class="text-sm text-base-content/50">Start the conversation. Use @mentions to notify specific people.</p>
          </div>

          <!-- Messages -->
          <template v-else>
            <div v-for="(msg, i) in messages" :key="msg.id">
              <!-- Date separator -->
              <div v-if="showDateSeparator(i)" class="divider text-xs text-base-content/40 my-2">
                {{ formatDateSeparator(msg.created_at) }}
              </div>

              <div class="flex gap-3 group" :class="msg.is_author ? '' : ''">
                <!-- Avatar -->
                <div class="avatar placeholder flex-shrink-0 mt-0.5">
                  <div :class="['rounded-full w-9 h-9', roleBg(msg.user.role)]">
                    <span class="text-xs">{{ initials(msg.user) }}</span>
                  </div>
                </div>

                <!-- Message content -->
                <div class="flex-1 min-w-0">
                  <div class="flex items-baseline gap-2">
                    <span class="font-semibold text-sm">{{ msg.user.name }}</span>
                    <span :class="['badge badge-xs', roleBadge(msg.user.role)]">{{ msg.user.role }}</span>
                    <span class="text-xs text-base-content/40">{{ formatTime(msg.created_at) }}</span>
                    <button v-if="msg.is_author || isAdmin"
                      @click="deleteMessage(msg.id)"
                      class="btn btn-ghost btn-xs opacity-0 group-hover:opacity-100 text-error ml-auto">
                      Delete
                    </button>
                  </div>
                  <div class="text-sm mt-0.5 whitespace-pre-wrap break-words leading-relaxed"
                    v-html="renderBody(msg.body)"></div>
                </div>
              </div>
            </div>
          </template>
        </div>

        <!-- Input area -->
        <div class="border-t border-base-200 p-4">
          <div class="relative">
            <textarea
              ref="inputRef"
              v-model="newMessage"
              @keydown="handleKeydown"
              @input="handleInput"
              placeholder="Write a message... (use @ to mention someone)"
              class="textarea textarea-bordered w-full text-sm min-h-[48px] max-h-[160px] resize-none pr-20"
              rows="1"
            ></textarea>

            <!-- Mention Dropdown -->
            <div v-if="showMentionDropdown && filteredUsers.length"
              class="absolute bottom-full left-0 mb-1 z-50 bg-base-100 border border-base-300 rounded-lg shadow-xl max-h-48 overflow-y-auto w-64">
              <ul class="py-1">
                <li v-for="(user, idx) in filteredUsers" :key="user.id"
                  @mousedown.prevent="insertMention(user)"
                  :class="['flex items-center gap-2 px-3 py-2 cursor-pointer text-sm hover:bg-base-200 transition',
                            idx === mentionIndex ? 'bg-base-200' : '']">
                  <div class="avatar placeholder flex-shrink-0">
                    <div :class="['rounded-full w-6 h-6', roleBg(user.role)]">
                      <span class="text-[10px]">{{ initials(user) }}</span>
                    </div>
                  </div>
                  <div class="min-w-0">
                    <div class="font-medium truncate">{{ user.name }}</div>
                    <div class="text-xs text-base-content/40 truncate">{{ user.role }}</div>
                  </div>
                </li>
              </ul>
            </div>

            <button
              @click="submitMessage"
              :disabled="!newMessage.trim() || submitting"
              class="btn btn-primary btn-sm absolute right-2 bottom-2">
              <span v-if="submitting" class="loading loading-spinner loading-xs"></span>
              Send
            </button>
          </div>
          <div class="flex items-center gap-3 mt-1">
            <span class="text-xs text-base-content/40">
              <kbd class="kbd kbd-xs">@</kbd> to mention &middot;
              <kbd class="kbd kbd-xs">Ctrl</kbd>+<kbd class="kbd kbd-xs">Enter</kbd> to send
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { apiClient } from '../api/client'
import { useAuthStore } from '../stores/auth'
import { useAppStore } from '../stores/app'

const authStore = useAuthStore()
const appStore = useAppStore()

const messages = ref([])
const participants = ref([])
const newMessage = ref('')
const loading = ref(false)
const submitting = ref(false)
const showMentionDropdown = ref(false)
const mentionQuery = ref('')
const mentionIndex = ref(0)
const mentionStartPos = ref(0)
const inputRef = ref(null)
const messagesContainer = ref(null)

const companyId = computed(() => appStore.activeCompany?.id)
const isAdmin = computed(() => authStore.isAdmin)

const filteredUsers = computed(() => {
  const q = mentionQuery.value.toLowerCase()
  if (!q) return participants.value.slice(0, 8)
  return participants.value
    .filter(u =>
      u.name.toLowerCase().includes(q) ||
      u.email.toLowerCase().includes(q) ||
      (u.first_name || '').toLowerCase().includes(q) ||
      (u.last_name || '').toLowerCase().includes(q)
    )
    .slice(0, 8)
})

function roleBg(role) {
  const map = {
    executive: 'bg-primary text-primary-content',
    manager: 'bg-secondary text-secondary-content',
    advisor: 'bg-accent text-accent-content',
    client: 'bg-neutral text-neutral-content',
    viewer: 'bg-base-300 text-base-content'
  }
  return map[role] || 'bg-neutral text-neutral-content'
}

function roleBadge(role) {
  const map = {
    executive: 'badge-primary',
    manager: 'badge-secondary',
    advisor: 'badge-accent',
    client: 'badge-ghost',
    viewer: 'badge-ghost'
  }
  return map[role] || 'badge-ghost'
}

function initials(user) {
  if (!user) return '?'
  return `${(user.first_name || user.name?.[0] || '')[0] || ''}${(user.last_name || '')[0] || ''}`.toUpperCase()
}

function formatTime(dateStr) {
  const d = new Date(dateStr)
  return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
}

function formatDateSeparator(dateStr) {
  const d = new Date(dateStr)
  const today = new Date()
  const yesterday = new Date(today)
  yesterday.setDate(yesterday.getDate() - 1)

  if (d.toDateString() === today.toDateString()) return 'Today'
  if (d.toDateString() === yesterday.toDateString()) return 'Yesterday'
  return d.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })
}

function showDateSeparator(index) {
  if (index === 0) return true
  const curr = new Date(messages.value[index].created_at).toDateString()
  const prev = new Date(messages.value[index - 1].created_at).toDateString()
  return curr !== prev
}

function renderBody(body) {
  return body
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/@\[([^\]]+)\]\(\d+\)/g, '<span class="badge badge-sm badge-primary gap-1">@$1</span>')
}

function scrollToBottom() {
  nextTick(() => {
    if (messagesContainer.value) {
      messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
    }
  })
}

async function fetchMessages() {
  const cid = companyId.value
  if (!cid) return

  loading.value = true
  try {
    const data = await apiClient.get(`/api/v1/companies/${cid}/messages?per_page=200`)
    messages.value = data?.messages || []
    scrollToBottom()
  } catch (e) {
    console.error('Failed to load messages:', e)
  } finally {
    loading.value = false
  }
}

async function fetchParticipants() {
  const cid = companyId.value
  if (!cid) return

  try {
    const data = await apiClient.get(`/api/v1/companies/${cid}/messages/participants`)
    participants.value = data?.users || []
  } catch (e) {
    console.error('Failed to load participants:', e)
  }
}

async function submitMessage() {
  if (!newMessage.value.trim() || submitting.value) return

  const cid = companyId.value
  if (!cid) return

  submitting.value = true
  try {
    const data = await apiClient.post(`/api/v1/companies/${cid}/messages`, { body: newMessage.value })
    if (data?.message) {
      messages.value.push(data.message)
      newMessage.value = ''
      // Reset textarea height
      if (inputRef.value) inputRef.value.style.height = 'auto'
      scrollToBottom()
    }
  } catch (e) {
    console.error('Failed to send message:', e)
  } finally {
    submitting.value = false
  }
}

async function deleteMessage(messageId) {
  if (!confirm('Delete this message?')) return

  const cid = companyId.value
  try {
    await apiClient.delete(`/api/v1/companies/${cid}/messages/${messageId}`)
    messages.value = messages.value.filter(m => m.id !== messageId)
  } catch (e) {
    console.error('Failed to delete message:', e)
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
    submitMessage()
  }
}

function handleInput(e) {
  const textarea = e.target
  const text = textarea.value
  const cursorPos = textarea.selectionStart

  // Auto-resize
  textarea.style.height = 'auto'
  textarea.style.height = Math.min(textarea.scrollHeight, 160) + 'px'

  // Check for @mention
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
  const text = newMessage.value
  const before = text.substring(0, mentionStartPos.value)
  const after = text.substring(inputRef.value.selectionStart)

  const mentionText = `@[${user.name}](${user.id}) `
  newMessage.value = before + mentionText + after

  showMentionDropdown.value = false
  mentionQuery.value = ''

  nextTick(() => {
    const newPos = before.length + mentionText.length
    inputRef.value.focus()
    inputRef.value.selectionStart = newPos
    inputRef.value.selectionEnd = newPos
  })
}

watch(() => companyId.value, () => {
  if (companyId.value) {
    fetchMessages()
    fetchParticipants()
  }
})

onMounted(() => {
  if (companyId.value) {
    fetchMessages()
    fetchParticipants()
  }
})
</script>
