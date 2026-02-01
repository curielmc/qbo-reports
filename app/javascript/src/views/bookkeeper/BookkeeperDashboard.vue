<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-xl sm:text-3xl font-bold">Bookkeeper Command Center</h1>
        <p class="text-base-content/60 mt-1">AI-powered overview of all your clients</p>
      </div>
      <button @click="generateTasks" :disabled="generating" class="btn btn-primary">
        <span v-if="generating" class="loading loading-spinner loading-sm"></span>
        🤖 AI Scan All Clients
      </button>
    </div>

    <!-- Stats Row -->
    <div class="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
      <div class="stat bg-base-100 rounded-box shadow p-4">
        <div class="stat-title text-xs">Clients</div>
        <div class="stat-value text-xl">{{ stats.total_clients }}</div>
      </div>
      <div class="stat bg-success/10 rounded-box shadow p-4">
        <div class="stat-title text-xs">Healthy</div>
        <div class="stat-value text-xl text-success">{{ stats.healthy }}</div>
      </div>
      <div class="stat bg-error/10 rounded-box shadow p-4">
        <div class="stat-title text-xs">Needs Attention</div>
        <div class="stat-value text-xl text-error">{{ stats.needs_attention }}</div>
      </div>
      <div class="stat bg-warning/10 rounded-box shadow p-4">
        <div class="stat-title text-xs">Open Tasks</div>
        <div class="stat-value text-xl text-warning">{{ stats.open_tasks }}</div>
      </div>
      <div class="stat bg-error/10 rounded-box shadow p-4">
        <div class="stat-title text-xs">Overdue</div>
        <div class="stat-value text-xl text-error">{{ stats.overdue_tasks }}</div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 sm:gap-6">
      <!-- Task Queue (2/3 width) -->
      <div class="lg:col-span-2">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-lg mb-4">📋 Task Queue</h2>
            <div class="space-y-3">
              <div v-for="task in tasks" :key="task.id" 
                :class="['flex items-start gap-3 p-3 rounded-lg border', priorityBorder(task.priority)]">
                <div class="mt-1">
                  <span class="text-lg">{{ taskIcon(task.type) }}</span>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <span :class="['badge badge-xs', priorityBadge(task.priority)]">{{ task.priority }}</span>
                    <span class="font-medium text-sm truncate">{{ task.title }}</span>
                  </div>
                  <p class="text-xs text-base-content/50 mt-1">{{ task.company_name }}</p>
                  <p v-if="task.description" class="text-xs text-base-content/40 mt-1 line-clamp-2">{{ task.description }}</p>
                  <div class="flex items-center gap-3 mt-2 text-xs text-base-content/40">
                    <span>⏱️ ~{{ task.estimated_minutes }}m</span>
                    <span v-if="task.due_date" :class="isOverdue(task.due_date) ? 'text-error font-bold' : ''">
                      📅 {{ formatDate(task.due_date) }}
                    </span>
                  </div>
                </div>
                <div class="flex gap-1">
                  <button v-if="task.status === 'pending'" @click="updateTask(task, 'start')" 
                    class="btn btn-outline btn-xs">▶️</button>
                  <button @click="updateTask(task, 'complete')" class="btn btn-success btn-xs">✅</button>
                  <button @click="updateTask(task, 'dismiss')" class="btn btn-ghost btn-xs">✕</button>
                </div>
              </div>
              <div v-if="!tasks.length" class="text-center py-8 text-base-content/50">
                <p class="text-4xl mb-2">🎉</p>
                <p>All caught up! Run AI Scan to check for new tasks.</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Client Health (1/3 width) -->
      <div>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-lg mb-4">🏥 Client Health</h2>
            <div class="space-y-3">
              <div v-for="client in clients" :key="client.company_id" 
                class="flex items-center gap-3 cursor-pointer hover:bg-base-200 rounded-lg p-2 transition"
                @click="selectClient(client)">
                <div :class="['w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm',
                  gradeColor(client.grade)]">
                  {{ client.grade }}
                </div>
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-sm truncate">{{ client.name }}</p>
                  <p class="text-xs text-base-content/40">
                    {{ client.uncategorized > 0 ? `${client.uncategorized} uncategorized` : '✓ Categorized' }}
                  </p>
                </div>
                <div class="text-right">
                  <p class="text-lg font-bold font-mono">{{ client.score }}</p>
                  <p class="text-xs text-base-content/40">/ 100</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="card bg-base-100 shadow-xl mt-4">
          <div class="card-body">
            <h2 class="card-title text-lg mb-4">⚡ Quick Actions</h2>
            <div class="space-y-2">
              <button @click="batchCategorize" class="btn btn-outline btn-block btn-sm justify-start">
                📋 Batch Categorize All Clients
              </button>
              <button @click="checkAnomalies" class="btn btn-outline btn-block btn-sm justify-start">
                🔍 Run Anomaly Detection
              </button>
              <button @click="openMonthEnd" class="btn btn-outline btn-block btn-sm justify-start">
                📅 Month-End Close
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Month-End Close Modal -->
    <dialog :class="['modal', showMonthEnd ? 'modal-open' : '']">
      <div class="modal-box max-w-lg w-full sm:w-auto">
        <h3 class="font-bold text-lg mb-2">📅 Month-End Close</h3>
        <p class="text-sm text-base-content/50 mb-4">{{ monthEndData?.period }}</p>
        
        <div class="mb-4">
          <progress class="progress progress-primary w-full h-3" :value="monthEndData?.progress || 0" max="100"></progress>
          <p class="text-sm text-right mt-1">{{ monthEndData?.progress || 0 }}%</p>
        </div>

        <div class="space-y-2">
          <label v-for="(item, key) in monthEndData?.checklist" :key="key"
            class="flex items-center gap-3 p-2 rounded-lg hover:bg-base-200 cursor-pointer">
            <input type="checkbox" :checked="item.completed" @change="toggleCheckItem(key, item)"
              class="checkbox checkbox-sm checkbox-primary" />
            <span :class="['text-sm', item.completed ? 'line-through text-base-content/40' : '']">
              {{ item.label }}
            </span>
          </label>
        </div>

        <div class="modal-action">
          <button @click="showMonthEnd = false" class="btn btn-ghost">Close</button>
          <button v-if="monthEndData?.progress === 100" @click="closeMonth" class="btn btn-success">
            🔒 Close Month
          </button>
        </div>
      </div>
      <form method="dialog" class="modal-backdrop" @click="showMonthEnd = false"><button>close</button></form>
    </dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { apiClient } from '../../api/client'

const clients = ref([])
const tasks = ref([])
const stats = ref({})
const generating = ref(false)
const showMonthEnd = ref(false)
const monthEndData = ref(null)
const selectedClient = ref(null)

const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : ''
const isOverdue = (d) => d && new Date(d) < new Date()

const taskIcon = (type) => ({
  categorize: '📋', reconcile: '🔄', review_anomaly: '⚠️', close_month: '📅',
  follow_up: '📞', receipt_match: '🧾', bank_reconnect: '🔌',
  missing_transactions: '❓', duplicate_check: '👯', vendor_review: '🏪'
}[type] || '📌')

const priorityBadge = (p) => ({
  critical: 'badge-error', high: 'badge-warning', normal: 'badge-info', low: 'badge-ghost'
}[p] || 'badge-ghost')

const priorityBorder = (p) => ({
  critical: 'border-error/30 bg-error/5', high: 'border-warning/30 bg-warning/5',
  normal: 'border-base-300', low: 'border-base-200'
}[p] || 'border-base-200')

const gradeColor = (g) => ({
  A: 'bg-success text-success-content', B: 'bg-info text-info-content',
  C: 'bg-warning text-warning-content', D: 'bg-error/60 text-white',
  F: 'bg-error text-error-content'
}[g] || 'bg-base-300')

const selectClient = (client) => {
  selectedClient.value = client
  // Could navigate to client detail view
}

const generateTasks = async () => {
  generating.value = true
  const result = await apiClient.post('/api/v1/bookkeeper/generate_tasks')
  if (result?.tasks_created > 0) {
    await fetchDashboard()
  }
  generating.value = false
}

const updateTask = async (task, action) => {
  await apiClient.patch(`/api/v1/bookkeeper/tasks/${task.id}`, { action_type: action })
  tasks.value = tasks.value.filter(t => t.id !== task.id || action === 'start')
  if (action === 'start') task.status = 'in_progress'
}

const openMonthEnd = async () => {
  if (!selectedClient.value && clients.value.length) {
    selectedClient.value = clients.value[0]
  }
  if (!selectedClient.value) return

  const data = await apiClient.get(`/api/v1/bookkeeper/month_end/${selectedClient.value.company_id}`)
  monthEndData.value = data
  showMonthEnd.value = true
}

const toggleCheckItem = async (key, item) => {
  await apiClient.patch(`/api/v1/bookkeeper/month_end/${selectedClient.value.company_id}/check`, {
    step: key,
    uncheck: item.completed
  })
  const data = await apiClient.get(`/api/v1/bookkeeper/month_end/${selectedClient.value.company_id}`)
  monthEndData.value = data
}

const closeMonth = async () => {
  await apiClient.post(`/api/v1/bookkeeper/month_end/${selectedClient.value.company_id}/close`)
  showMonthEnd.value = false
  alert('✅ Month closed!')
}

const batchCategorize = () => {
  // Navigate to batch categorization view
  alert('Opening batch categorization...')
}

const checkAnomalies = () => {
  alert('Running anomaly detection across all clients...')
}

const fetchDashboard = async () => {
  const data = await apiClient.get('/api/v1/bookkeeper/dashboard')
  if (data) {
    clients.value = data.clients || []
    tasks.value = data.tasks || []
    stats.value = data.stats || {}
  }
}

onMounted(fetchDashboard)
</script>
