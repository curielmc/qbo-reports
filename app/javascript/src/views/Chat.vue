<template>
  <div class="flex flex-col h-[calc(100vh-8rem)]">
    <!-- Chat Header -->
    <div class="flex items-center justify-between pb-4 border-b border-base-300">
      <div class="flex items-center gap-3">
        <div class="avatar placeholder">
          <div class="bg-primary text-primary-content rounded-full w-10">
            <span class="text-xl">📊</span>
          </div>
        </div>
        <div>
          <h1 class="text-lg font-bold">ecfoBooks</h1>
          <p class="text-xs text-base-content/50">Your AI bookkeeper — ask anything, I'll handle the rest</p>
        </div>
      </div>
      <div class="flex gap-2">
        <button @click="clearChat" class="btn btn-ghost btn-sm" title="Clear history">🗑️</button>
      </div>
    </div>

    <!-- Messages -->
    <div ref="messagesContainer" class="flex-1 overflow-y-auto py-4 space-y-4">
      <!-- Welcome -->
      <div v-if="messages.length === 0" class="flex flex-col items-center justify-center h-full text-center px-4">
        <div class="text-6xl mb-4">📊</div>
        <h2 class="text-2xl font-bold mb-2">Your AI Bookkeeper</h2>
        <p class="text-base-content/60 mb-8 max-w-lg">
          I handle everything — categorization, reconciliation, reports, rules. Just tell me what you need in plain English.
        </p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 max-w-2xl w-full">
          <button v-for="prompt in quickPrompts" :key="prompt.text"
            @click="sendMessage(prompt.text)"
            class="btn btn-outline btn-sm text-left normal-case h-auto py-3 px-4 gap-2">
            <span>{{ prompt.icon }}</span>
            <span>{{ prompt.text }}</span>
          </button>
        </div>
      </div>

      <!-- Message bubbles -->
      <div v-for="msg in messages" :key="msg.id"
        :class="['chat', msg.role === 'user' ? 'chat-end' : 'chat-start']">
        <div class="chat-image avatar placeholder">
          <div :class="['rounded-full w-8', msg.role === 'user' ? 'bg-secondary text-secondary-content' : 'bg-primary text-primary-content']">
            <span>{{ msg.role === 'user' ? '👤' : '📊' }}</span>
          </div>
        </div>
        <div :class="['chat-bubble max-w-2xl', msg.role === 'user' ? 'chat-bubble-secondary' : '']">
          <div v-html="formatMessage(msg.content)"></div>
          
          <!-- Action buttons from AI suggestions -->
          <div v-if="msg.suggestions?.length" class="mt-3 flex flex-wrap gap-2">
            <button v-for="s in msg.suggestions" :key="s.transaction_id"
              @click="applySuggestion(s)"
              class="btn btn-xs btn-outline gap-1">
              ✅ {{ s.category_name }} ({{ s.confidence }}%)
            </button>
          </div>
        </div>
        <div class="chat-footer opacity-50 text-xs">
          {{ formatTime(msg.created_at) }}
        </div>
      </div>

      <!-- Typing indicator -->
      <div v-if="loading" class="chat chat-start">
        <div class="chat-image avatar placeholder">
          <div class="bg-primary text-primary-content rounded-full w-8">
            <span>📊</span>
          </div>
        </div>
        <div class="chat-bubble">
          <span class="loading loading-dots loading-sm"></span>
        </div>
      </div>
    </div>

    <!-- Quick Action Bar -->
    <div v-if="messages.length > 0" class="flex gap-2 py-2 overflow-x-auto">
      <button @click="sendMessage('Show uncategorized transactions')" class="btn btn-xs btn-ghost whitespace-nowrap">📋 Uncategorized</button>
      <button @click="sendMessage('Suggest categories for my transactions')" class="btn btn-xs btn-ghost whitespace-nowrap">🤖 AI Categorize</button>
      <button @click="sendMessage('Run all categorization rules')" class="btn btn-xs btn-ghost whitespace-nowrap">⚡ Run Rules</button>
      <button @click="sendMessage('What\\'s my P&L this year?')" class="btn btn-xs btn-ghost whitespace-nowrap">📈 P&L</button>
      <button @click="sendMessage('Find duplicate transactions')" class="btn btn-xs btn-ghost whitespace-nowrap">🔍 Duplicates</button>
      <button @click="sendMessage('Any anomalies?')" class="btn btn-xs btn-ghost whitespace-nowrap">⚠️ Anomalies</button>
    </div>

    <!-- Input -->
    <div class="pt-2 border-t border-base-300">
      <form @submit.prevent="sendMessage()" class="flex gap-2">
        <!-- File upload button -->
        <input type="file" ref="fileInput" class="hidden" 
          accept=".csv,.ofx,.qfx,.pdf,.tsv" @change="uploadStatement" />
        <button type="button" @click="$refs.fileInput.click()" 
          class="btn btn-ghost" :disabled="uploading" title="Upload bank statement">
          <span v-if="uploading" class="loading loading-spinner loading-sm"></span>
          <span v-else>📎</span>
        </button>
        <input
          ref="inputRef"
          v-model="input"
          type="text"
          class="input input-bordered flex-1"
          placeholder="Categorize, reconcile, upload statements, ask questions..."
          :disabled="loading"
          autocomplete="off"
        />
        <button type="submit" class="btn btn-primary" :disabled="loading || !input.trim()">
          Send
        </button>
      </form>
      <p class="text-xs text-base-content/30 mt-1 text-center">
        📎 Upload CSV/OFX/PDF statements · "categorize all Starbucks as meals" · "what's my burn rate?"
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue'
import { useAppStore } from '../stores/app'
import { apiClient } from '../api/client'

const appStore = useAppStore()
const messages = ref([])
const input = ref('')
const loading = ref(false)
const uploading = ref(false)
const messagesContainer = ref(null)
const inputRef = ref(null)
const fileInput = ref(null)

const companyId = () => appStore.currentCompany?.id || 1

const quickPrompts = [
  { icon: '📋', text: 'Show uncategorized transactions' },
  { icon: '🤖', text: 'Suggest categories for my transactions' },
  { icon: '💰', text: "What's my P&L this year?" },
  { icon: '🔥', text: "What's my burn rate?" },
  { icon: '🏦', text: 'Reconcile all my accounts' },
  { icon: '📈', text: 'Top 10 vendors by spend' },
  { icon: '⚠️', text: 'Any unusual transactions?' },
  { icon: '📊', text: 'Compare this month vs last month' },
]

const formatMessage = (text) => {
  if (!text) return ''
  return text
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\n/g, '<br>')
    .replace(/\$([0-9,]+\.?\d*)/g, '<span class="font-mono font-bold">$$1</span>')
    .replace(/ID:(\d+)/g, '<code class="text-xs">ID:$1</code>')
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
      // Check if AI returned categorization suggestions
      const data = result.message.data
      if (data?.[0]?.action === 'suggest_categories' && data[0].suggestions?.length) {
        result.message.suggestions = data[0].suggestions
      }
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

const uploadStatement = async (event) => {
  const file = event.target.files[0]
  if (!file) return

  uploading.value = true

  // Show upload message in chat
  messages.value.push({
    id: Date.now(),
    role: 'user',
    content: `📎 Uploading statement: **${file.name}** (${(file.size / 1024).toFixed(0)} KB)`,
    created_at: new Date().toISOString()
  })
  scrollToBottom()

  try {
    const formData = new FormData()
    formData.append('file', file)

    const result = await apiClient.upload(`/api/v1/companies/${companyId()}/statements/upload`, formData)

    if (result?.transactions_found > 0) {
      // Build a rich response
      let preview = `✅ Parsed **${result.transactions_found} transactions** from ${file.name}\n\n`
      if (result.account_name) preview += `📋 Account detected: **${result.account_name}** (${result.account_type || 'unknown'})\n`
      if (result.notes) preview += `📝 ${result.notes}\n\n`
      preview += `**Preview (first ${Math.min(result.preview?.length || 0, 10)}):**\n`
      result.preview?.forEach(t => {
        preview += `  ${t.date} | ${t.description} | $${t.amount} → ${t.suggested_category || '❓'}\n`
      })
      preview += `\nSay **"import into [account name]"** to import, or **"show preview"** to see all transactions.`

      messages.value.push({
        id: Date.now() + 1,
        role: 'assistant',
        content: preview,
        created_at: new Date().toISOString(),
        uploadId: result.upload_id
      })

      // Also tell the AI about the upload so it can help with next steps
      await apiClient.post(`/api/v1/companies/${companyId()}/chat`, {
        message: `[SYSTEM] Statement uploaded: ${file.name}, ${result.transactions_found} transactions parsed, upload_id=${result.upload_id}. AI suggested categories for transactions. User needs to pick an account and confirm import.`
      })
    } else {
      messages.value.push({
        id: Date.now() + 1,
        role: 'assistant',
        content: `❌ Couldn't parse any transactions from ${file.name}. Try a different format (CSV, OFX/QFX, or PDF).`,
        created_at: new Date().toISOString()
      })
    }
  } catch (e) {
    messages.value.push({
      id: Date.now() + 1,
      role: 'assistant',
      content: `❌ Upload failed: ${e.message}. Supported formats: CSV, OFX/QFX, PDF.`,
      created_at: new Date().toISOString()
    })
  }

  uploading.value = false
  event.target.value = '' // Reset file input
  scrollToBottom()
}

const applySuggestion = async (suggestion) => {
  await sendMessage(`Categorize transaction ${suggestion.transaction_id} as ${suggestion.category_name}`)
}

const clearChat = async () => {
  if (!confirm('Clear chat history?')) return
  await apiClient.delete(`/api/v1/companies/${companyId()}/chat`)
  messages.value = []
}

onMounted(async () => {
  const history = await apiClient.get(`/api/v1/companies/${companyId()}/chat?limit=50`)
  if (history) messages.value = history
  scrollToBottom()
  inputRef.value?.focus()
})
</script>
