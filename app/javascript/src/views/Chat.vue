<template>
  <div class="flex flex-col h-[calc(100vh-8rem)]">
    <!-- Chat Header -->
    <div class="flex items-center justify-between pb-4 border-b border-base-300">
      <div class="flex items-center gap-3">
        <div class="avatar placeholder">
          <div class="bg-primary text-primary-content rounded-full w-10">
            <span class="text-xl">🤖</span>
          </div>
        </div>
        <div>
          <h1 class="text-lg font-bold">ecfoBooks AI</h1>
          <p class="text-xs text-base-content/50">Ask anything about your finances</p>
        </div>
      </div>
      <div class="flex gap-2">
        <button @click="clearChat" class="btn btn-ghost btn-sm" title="Clear history">🗑️</button>
      </div>
    </div>

    <!-- Messages -->
    <div ref="messagesContainer" class="flex-1 overflow-y-auto py-4 space-y-4">
      <!-- Welcome message if no history -->
      <div v-if="messages.length === 0" class="flex flex-col items-center justify-center h-full text-center">
        <div class="text-6xl mb-4">💬</div>
        <h2 class="text-2xl font-bold mb-2">Talk to your books</h2>
        <p class="text-base-content/60 mb-8 max-w-md">
          Ask questions in plain English. I can look up transactions, run reports, categorize expenses, and spot trends.
        </p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 max-w-lg">
          <button v-for="prompt in quickPrompts" :key="prompt" 
            @click="sendMessage(prompt)"
            class="btn btn-outline btn-sm text-left normal-case h-auto py-3 px-4">
            {{ prompt }}
          </button>
        </div>
      </div>

      <!-- Message bubbles -->
      <div v-for="msg in messages" :key="msg.id" 
        :class="['chat', msg.role === 'user' ? 'chat-end' : 'chat-start']">
        <div class="chat-image avatar placeholder">
          <div :class="['rounded-full w-8', msg.role === 'user' ? 'bg-secondary text-secondary-content' : 'bg-primary text-primary-content']">
            <span>{{ msg.role === 'user' ? '👤' : '🤖' }}</span>
          </div>
        </div>
        <div :class="['chat-bubble', msg.role === 'user' ? 'chat-bubble-secondary' : 'chat-bubble-primary']">
          <div v-html="formatMessage(msg.content)"></div>
        </div>
        <div class="chat-footer opacity-50 text-xs">
          {{ formatTime(msg.created_at) }}
        </div>
      </div>

      <!-- Typing indicator -->
      <div v-if="loading" class="chat chat-start">
        <div class="chat-image avatar placeholder">
          <div class="bg-primary text-primary-content rounded-full w-8">
            <span>🤖</span>
          </div>
        </div>
        <div class="chat-bubble chat-bubble-primary">
          <span class="loading loading-dots loading-sm"></span>
        </div>
      </div>
    </div>

    <!-- Input -->
    <div class="pt-4 border-t border-base-300">
      <form @submit.prevent="sendMessage()" class="flex gap-2">
        <input 
          ref="inputRef"
          v-model="input" 
          type="text" 
          class="input input-bordered flex-1" 
          placeholder="Ask about your finances..."
          :disabled="loading"
          autocomplete="off"
        />
        <button type="submit" class="btn btn-primary" :disabled="loading || !input.trim()">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
          </svg>
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const messages = ref([])
const input = ref('')
const loading = ref(false)
const messagesContainer = ref(null)
const inputRef = ref(null)

const companyId = () => appStore.currentCompany?.id || 1

const quickPrompts = [
  "What's my P&L this year?",
  "Show me uncategorized transactions",
  "What's my burn rate?",
  "Top 10 vendors by spend",
  "How much did we spend last month?",
  "Any unusual transactions recently?"
]

const formatMessage = (text) => {
  if (!text) return ''
  // Simple markdown-like formatting
  return text
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\n/g, '<br>')
    .replace(/\$([0-9,]+\.?\d*)/g, '<span class="font-mono font-bold">$$1</span>')
}

const formatTime = (ts) => {
  if (!ts) return ''
  return new Date(ts).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
}

const scrollToBottom = async () => {
  await nextTick()
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  }
}

const sendMessage = async (text) => {
  const msg = text || input.value.trim()
  if (!msg) return

  input.value = ''

  // Add user message locally
  messages.value.push({
    id: Date.now(),
    role: 'user',
    content: msg,
    created_at: new Date().toISOString()
  })

  scrollToBottom()
  loading.value = true

  try {
    const result = await apiClient.post(`/api/v1/companies/${companyId()}/chat`, { message: msg })
    if (result?.message) {
      messages.value.push(result.message)
    }
  } catch (e) {
    messages.value.push({
      id: Date.now(),
      role: 'assistant',
      content: 'Sorry, something went wrong. Please try again.',
      created_at: new Date().toISOString()
    })
  }

  loading.value = false
  scrollToBottom()
  inputRef.value?.focus()
}

const clearChat = async () => {
  if (!confirm('Clear chat history?')) return
  await apiClient.delete(`/api/v1/companies/${companyId()}/chat`)
  messages.value = []
}

onMounted(async () => {
  // Load chat history
  const history = await apiClient.get(`/api/v1/companies/${companyId()}/chat?limit=50`)
  if (history) messages.value = history
  scrollToBottom()
  inputRef.value?.focus()
})
</script>
