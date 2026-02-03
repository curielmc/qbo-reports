<template>
  <div>
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6">
      <h1 class="text-2xl font-bold">Schedule C Worksheets</h1>
      <div class="flex items-center gap-3 mt-2 sm:mt-0">
        <label class="text-sm text-base-content/60">Tax Year:</label>
        <select v-model="taxYear" @change="loadData" class="select select-bordered select-sm w-28">
          <option v-for="year in availableYears" :key="year" :value="year">{{ year }}</option>
        </select>
      </div>
    </div>

    <!-- Tabs -->
    <div class="tabs tabs-boxed mb-6">
      <a :class="['tab', activeTab === 'home_office' && 'tab-active']" @click="activeTab = 'home_office'">
        Home Office (Form 8829)
      </a>
      <a :class="['tab', activeTab === 'vehicles' && 'tab-active']" @click="activeTab = 'vehicles'">
        Vehicle Expenses
      </a>
      <a :class="['tab', activeTab === 'summary' && 'tab-active']" @click="activeTab = 'summary'">
        Summary
      </a>
    </div>

    <!-- Home Office Tab -->
    <div v-if="activeTab === 'home_office'" class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title mb-4">Home Office Deduction</h2>

        <!-- Method Toggle -->
        <div class="form-control mb-6">
          <label class="label cursor-pointer justify-start gap-4">
            <span class="label-text font-medium">Calculation Method:</span>
            <div class="join">
              <button
                :class="['btn btn-sm join-item', homeOffice.method === 'simplified' && 'btn-primary']"
                @click="homeOffice.method = 'simplified'"
              >Simplified</button>
              <button
                :class="['btn btn-sm join-item', homeOffice.method === 'regular' && 'btn-primary']"
                @click="homeOffice.method = 'regular'"
              >Regular</button>
            </div>
          </label>
        </div>

        <!-- Simplified Method -->
        <div v-if="homeOffice.method === 'simplified'" class="space-y-4">
          <div class="alert alert-info">
            <span>The simplified method allows $5 per square foot of home office space, up to 300 sq ft (max $1,500).</span>
          </div>

          <div class="form-control w-full max-w-xs">
            <label class="label">
              <span class="label-text">Office Square Footage</span>
              <span class="label-text-alt">(max 300)</span>
            </label>
            <input
              type="number"
              v-model.number="homeOffice.office_sq_ft"
              class="input input-bordered"
              min="0"
              max="300"
              placeholder="Enter sq ft"
            />
          </div>

          <!-- Progress toward cap -->
          <div class="mt-4">
            <div class="flex justify-between text-sm mb-1">
              <span>Deduction: {{ formatCurrency(simplifiedDeduction) }}</span>
              <span class="text-base-content/60">Max: $1,500</span>
            </div>
            <progress
              class="progress progress-primary w-full"
              :value="simplifiedDeduction"
              max="1500"
            ></progress>
          </div>
        </div>

        <!-- Regular Method -->
        <div v-else class="space-y-6">
          <div class="alert alert-info">
            <span>The regular method calculates actual home expenses multiplied by business use percentage.</span>
          </div>

          <!-- Square Footage -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Total Home Sq Ft</span></label>
              <input type="number" v-model.number="homeOffice.total_home_sq_ft" class="input input-bordered" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Office Sq Ft</span></label>
              <input type="number" v-model.number="homeOffice.office_sq_ft" class="input input-bordered" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Business Use %</span></label>
              <input type="text" :value="businessUsePct + '%'" class="input input-bordered" disabled />
            </div>
          </div>

          <!-- Expenses -->
          <div class="divider">Annual Home Expenses</div>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Mortgage Interest</span></label>
              <input type="number" v-model.number="homeOffice.mortgage_interest" class="input input-bordered" step="0.01" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Real Estate Taxes</span></label>
              <input type="number" v-model.number="homeOffice.real_estate_taxes" class="input input-bordered" step="0.01" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Rent Paid</span></label>
              <input type="number" v-model.number="homeOffice.rent_paid" class="input input-bordered" step="0.01" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Utilities</span></label>
              <input type="number" v-model.number="homeOffice.utilities" class="input input-bordered" step="0.01" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Insurance</span></label>
              <input type="number" v-model.number="homeOffice.insurance" class="input input-bordered" step="0.01" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Repairs & Maintenance</span></label>
              <input type="number" v-model.number="homeOffice.repairs_maintenance" class="input input-bordered" step="0.01" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Depreciation</span></label>
              <input type="number" v-model.number="homeOffice.depreciation" class="input input-bordered" step="0.01" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Other Expenses</span></label>
              <input type="number" v-model.number="homeOffice.other_expenses" class="input input-bordered" step="0.01" min="0" />
            </div>
          </div>

          <!-- Totals -->
          <div class="stats shadow mt-4">
            <div class="stat">
              <div class="stat-title">Total Expenses</div>
              <div class="stat-value text-lg">{{ formatCurrency(regularTotalExpenses) }}</div>
            </div>
            <div class="stat">
              <div class="stat-title">Business Use %</div>
              <div class="stat-value text-lg">{{ businessUsePct }}%</div>
            </div>
            <div class="stat">
              <div class="stat-title">Deductible Amount</div>
              <div class="stat-value text-lg text-primary">{{ formatCurrency(regularDeduction) }}</div>
            </div>
          </div>
        </div>

        <!-- Notes -->
        <div class="form-control mt-6">
          <label class="label"><span class="label-text">Notes</span></label>
          <textarea v-model="homeOffice.notes" class="textarea textarea-bordered" rows="2" placeholder="Optional notes..."></textarea>
        </div>

        <!-- Save Button -->
        <div class="card-actions justify-end mt-6">
          <button @click="saveHomeOffice" :disabled="savingHomeOffice" class="btn btn-primary">
            <span v-if="savingHomeOffice" class="loading loading-spinner loading-sm"></span>
            Save Home Office Record
          </button>
        </div>

        <!-- Result Display -->
        <div v-if="homeOffice.id" class="alert alert-success mt-4">
          <span>Calculated Deduction: <strong>{{ formatCurrency(homeOffice.deductible_amount) }}</strong></span>
        </div>
      </div>
    </div>

    <!-- Vehicles Tab -->
    <div v-if="activeTab === 'vehicles'">
      <!-- Add Vehicle Button -->
      <div class="flex justify-end mb-4">
        <button @click="addVehicle" class="btn btn-primary btn-sm">+ Add Vehicle</button>
      </div>

      <!-- Vehicle Cards -->
      <div v-if="vehicles.length === 0" class="alert">
        <span>No vehicles recorded for {{ taxYear }}. Click "Add Vehicle" to get started.</span>
      </div>

      <div v-for="(vehicle, index) in vehicles" :key="vehicle.id || index" class="card bg-base-100 shadow-xl mb-6">
        <div class="card-body">
          <div class="flex justify-between items-start">
            <h3 class="card-title">{{ vehicle.vehicle_description || 'New Vehicle' }}</h3>
            <button @click="deleteVehicle(vehicle, index)" class="btn btn-ghost btn-sm text-error">Delete</button>
          </div>

          <!-- Vehicle Description -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Vehicle Description</span></label>
              <input type="text" v-model="vehicle.vehicle_description" class="input input-bordered" placeholder="e.g., 2020 Toyota Camry" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Date Placed in Service</span></label>
              <input type="date" v-model="vehicle.date_placed_in_service" class="input input-bordered" />
            </div>
          </div>

          <!-- Method Toggle -->
          <div class="form-control mt-4">
            <label class="label cursor-pointer justify-start gap-4">
              <span class="label-text font-medium">Deduction Method:</span>
              <div class="join">
                <button
                  :class="['btn btn-sm join-item', vehicle.method === 'standard_mileage' && 'btn-primary']"
                  @click="vehicle.method = 'standard_mileage'"
                >Standard Mileage</button>
                <button
                  :class="['btn btn-sm join-item', vehicle.method === 'actual' && 'btn-primary']"
                  @click="vehicle.method = 'actual'"
                >Actual Expenses</button>
              </div>
            </label>
          </div>

          <!-- Mileage Tracking (both methods) -->
          <div class="divider">Mileage Tracking</div>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text">Total Miles</span></label>
              <input type="number" v-model.number="vehicle.total_miles" class="input input-bordered" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Business Miles</span></label>
              <input type="number" v-model.number="vehicle.business_miles" class="input input-bordered" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Commuting Miles</span></label>
              <input type="number" v-model.number="vehicle.commuting_miles" class="input input-bordered" min="0" />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Personal Miles</span></label>
              <input type="number" v-model.number="vehicle.personal_miles" class="input input-bordered" min="0" />
            </div>
          </div>

          <div class="text-sm text-base-content/60 mt-2">
            Business Use: {{ calculateVehicleBusinessPct(vehicle) }}%
          </div>

          <!-- Standard Mileage Method -->
          <div v-if="vehicle.method === 'standard_mileage'" class="mt-4">
            <div class="alert alert-info mb-4">
              <span>IRS Rate for {{ taxYear }}: {{ getMileageRate(taxYear) }} per mile</span>
            </div>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label"><span class="label-text">Parking & Tolls (fully deductible)</span></label>
                <input type="number" v-model.number="vehicle.parking_tolls" class="input input-bordered" step="0.01" min="0" />
              </div>
            </div>
            <div class="stats shadow mt-4">
              <div class="stat">
                <div class="stat-title">Mileage Deduction</div>
                <div class="stat-value text-lg">{{ formatCurrency(calculateStandardMileageDeduction(vehicle)) }}</div>
                <div class="stat-desc">{{ vehicle.business_miles || 0 }} miles x {{ getMileageRate(taxYear) }}</div>
              </div>
              <div class="stat">
                <div class="stat-title">+ Parking & Tolls</div>
                <div class="stat-value text-lg">{{ formatCurrency(vehicle.parking_tolls || 0) }}</div>
              </div>
              <div class="stat">
                <div class="stat-title">Total Deduction</div>
                <div class="stat-value text-lg text-primary">{{ formatCurrency(calculateStandardMileageDeduction(vehicle) + (vehicle.parking_tolls || 0)) }}</div>
              </div>
            </div>
          </div>

          <!-- Actual Expense Method -->
          <div v-else class="mt-4">
            <div class="divider">Actual Expenses</div>
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
              <div class="form-control">
                <label class="label"><span class="label-text">Gas & Fuel</span></label>
                <input type="number" v-model.number="vehicle.gas_fuel" class="input input-bordered" step="0.01" min="0" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Oil Changes</span></label>
                <input type="number" v-model.number="vehicle.oil_changes" class="input input-bordered" step="0.01" min="0" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Repairs & Maint.</span></label>
                <input type="number" v-model.number="vehicle.repairs_maintenance" class="input input-bordered" step="0.01" min="0" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Insurance</span></label>
                <input type="number" v-model.number="vehicle.insurance" class="input input-bordered" step="0.01" min="0" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Registration Fees</span></label>
                <input type="number" v-model.number="vehicle.registration_fees" class="input input-bordered" step="0.01" min="0" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Lease Payments</span></label>
                <input type="number" v-model.number="vehicle.lease_payments" class="input input-bordered" step="0.01" min="0" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Loan Interest</span></label>
                <input type="number" v-model.number="vehicle.loan_interest" class="input input-bordered" step="0.01" min="0" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Depreciation</span></label>
                <input type="number" v-model.number="vehicle.depreciation" class="input input-bordered" step="0.01" min="0" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Parking & Tolls</span></label>
                <input type="number" v-model.number="vehicle.parking_tolls" class="input input-bordered" step="0.01" min="0" />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Other Expenses</span></label>
                <input type="number" v-model.number="vehicle.other_expenses" class="input input-bordered" step="0.01" min="0" />
              </div>
            </div>

            <div class="stats shadow mt-4">
              <div class="stat">
                <div class="stat-title">Total Expenses</div>
                <div class="stat-value text-lg">{{ formatCurrency(calculateActualExpenses(vehicle)) }}</div>
              </div>
              <div class="stat">
                <div class="stat-title">Business Use %</div>
                <div class="stat-value text-lg">{{ calculateVehicleBusinessPct(vehicle) }}%</div>
              </div>
              <div class="stat">
                <div class="stat-title">Deductible Amount</div>
                <div class="stat-value text-lg text-primary">{{ formatCurrency(calculateActualDeduction(vehicle)) }}</div>
                <div class="stat-desc">Prorated + parking/tolls</div>
              </div>
            </div>
          </div>

          <!-- Notes -->
          <div class="form-control mt-4">
            <label class="label"><span class="label-text">Notes</span></label>
            <textarea v-model="vehicle.notes" class="textarea textarea-bordered" rows="2" placeholder="Optional notes..."></textarea>
          </div>

          <!-- Save Vehicle -->
          <div class="card-actions justify-end mt-4">
            <button @click="saveVehicle(vehicle)" :disabled="savingVehicle" class="btn btn-primary btn-sm">
              <span v-if="savingVehicle" class="loading loading-spinner loading-sm"></span>
              Save Vehicle
            </button>
          </div>
        </div>
      </div>

      <!-- Total Vehicle Deduction -->
      <div v-if="vehicles.length > 0" class="alert alert-success">
        <span>Total Vehicle Deduction for {{ taxYear }}: <strong>{{ formatCurrency(totalVehicleDeduction) }}</strong></span>
      </div>
    </div>

    <!-- Summary Tab -->
    <div v-if="activeTab === 'summary'" class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title mb-6">Schedule C Deduction Summary - {{ taxYear }}</h2>

        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Deduction Type</th>
                <th>Method</th>
                <th class="text-right">Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Home Office (Form 8829)</td>
                <td>
                  <span v-if="homeOffice.id" class="badge badge-outline">{{ homeOffice.method === 'simplified' ? 'Simplified' : 'Regular' }}</span>
                  <span v-else class="text-base-content/40">Not entered</span>
                </td>
                <td class="text-right font-mono">{{ formatCurrency(homeOffice.deductible_amount || 0) }}</td>
              </tr>
              <tr v-for="vehicle in vehicles" :key="vehicle.id">
                <td>{{ vehicle.vehicle_description || 'Vehicle' }}</td>
                <td>
                  <span class="badge badge-outline">{{ vehicle.method === 'standard_mileage' ? 'Standard Mileage' : 'Actual Expense' }}</span>
                </td>
                <td class="text-right font-mono">{{ formatCurrency(vehicle.deductible_amount || calculateVehicleDeduction(vehicle)) }}</td>
              </tr>
              <tr v-if="vehicles.length === 0">
                <td>Vehicle Expenses</td>
                <td><span class="text-base-content/40">No vehicles entered</span></td>
                <td class="text-right font-mono">$0</td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="text-lg font-bold">
                <td colspan="2">Total Schedule C Additions</td>
                <td class="text-right text-primary">{{ formatCurrency(totalScheduleCDeductions) }}</td>
              </tr>
            </tfoot>
          </table>
        </div>

        <div class="alert mt-6">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-info shrink-0 w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
          <span>These deductions are added to your Schedule C. Home office goes to Line 30, vehicle expenses to Line 9.</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { apiClient } from '../api/client'
import { useAppStore } from '../stores/app'

const appStore = useAppStore()
const currentYear = new Date().getFullYear()

const taxYear = ref(currentYear)
const activeTab = ref('home_office')
const availableYears = [currentYear, currentYear - 1, currentYear - 2]

// Home Office State
const homeOffice = ref({
  method: 'simplified',
  office_sq_ft: null,
  total_home_sq_ft: null,
  mortgage_interest: null,
  real_estate_taxes: null,
  rent_paid: null,
  utilities: null,
  insurance: null,
  repairs_maintenance: null,
  depreciation: null,
  other_expenses: null,
  notes: ''
})
const savingHomeOffice = ref(false)

// Vehicles State
const vehicles = ref([])
const savingVehicle = ref(false)

// IRS Mileage Rates
const mileageRates = {
  2024: 0.670,
  2025: 0.700,
  2026: 0.700
}

// Computed values for home office
const simplifiedDeduction = computed(() => {
  const sqFt = Math.min(homeOffice.value.office_sq_ft || 0, 300)
  return Math.min(sqFt * 5, 1500)
})

const businessUsePct = computed(() => {
  if (!homeOffice.value.total_home_sq_ft || homeOffice.value.total_home_sq_ft === 0) return 0
  return ((homeOffice.value.office_sq_ft || 0) / homeOffice.value.total_home_sq_ft * 100).toFixed(2)
})

const regularTotalExpenses = computed(() => {
  const h = homeOffice.value
  return [
    h.mortgage_interest, h.real_estate_taxes, h.rent_paid, h.utilities,
    h.insurance, h.repairs_maintenance, h.depreciation, h.other_expenses
  ].reduce((sum, val) => sum + (val || 0), 0)
})

const regularDeduction = computed(() => {
  return (regularTotalExpenses.value * businessUsePct.value / 100).toFixed(2)
})

// Vehicle calculations
const getMileageRate = (year) => {
  const rate = mileageRates[year] || 0.670
  return '$' + rate.toFixed(3)
}

const calculateVehicleBusinessPct = (vehicle) => {
  if (!vehicle.total_miles || vehicle.total_miles === 0) return 0
  return ((vehicle.business_miles || 0) / vehicle.total_miles * 100).toFixed(2)
}

const calculateStandardMileageDeduction = (vehicle) => {
  const rate = mileageRates[taxYear.value] || 0.670
  return (vehicle.business_miles || 0) * rate
}

const calculateActualExpenses = (vehicle) => {
  return [
    vehicle.gas_fuel, vehicle.oil_changes, vehicle.repairs_maintenance,
    vehicle.insurance, vehicle.registration_fees, vehicle.lease_payments,
    vehicle.loan_interest, vehicle.depreciation, vehicle.other_expenses
  ].reduce((sum, val) => sum + (val || 0), 0)
}

const calculateActualDeduction = (vehicle) => {
  const expenses = calculateActualExpenses(vehicle)
  const pct = calculateVehicleBusinessPct(vehicle) / 100
  const prorated = expenses * pct
  return prorated + (vehicle.parking_tolls || 0)
}

const calculateVehicleDeduction = (vehicle) => {
  if (vehicle.method === 'standard_mileage') {
    return calculateStandardMileageDeduction(vehicle) + (vehicle.parking_tolls || 0)
  } else {
    return calculateActualDeduction(vehicle)
  }
}

const totalVehicleDeduction = computed(() => {
  return vehicles.value.reduce((sum, v) => {
    return sum + (v.deductible_amount || calculateVehicleDeduction(v))
  }, 0)
})

const totalScheduleCDeductions = computed(() => {
  const homeOfficeAmt = homeOffice.value.deductible_amount ||
    (homeOffice.value.method === 'simplified' ? simplifiedDeduction.value : parseFloat(regularDeduction.value))
  return (homeOfficeAmt || 0) + totalVehicleDeduction.value
})

// Format currency
const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 2
  }).format(amount || 0)
}

// API Functions
const loadData = async () => {
  const companyId = appStore.currentCompany?.id
  if (!companyId) return

  try {
    // Load home office record
    const hoData = await apiClient.get(`/api/v1/companies/${companyId}/schedule_c/home_office/${taxYear.value}`)
    if (hoData && hoData.id) {
      homeOffice.value = hoData
    } else {
      homeOffice.value = { method: 'simplified', tax_year: taxYear.value }
    }

    // Load vehicles
    const vehiclesData = await apiClient.get(`/api/v1/companies/${companyId}/schedule_c/vehicles`)
    vehicles.value = (vehiclesData || []).filter(v => v.tax_year === taxYear.value)
  } catch (error) {
    console.error('Error loading Schedule C data:', error)
  }
}

const saveHomeOffice = async () => {
  const companyId = appStore.currentCompany?.id
  if (!companyId) return

  savingHomeOffice.value = true
  try {
    const response = await apiClient.post(`/api/v1/companies/${companyId}/schedule_c/home_office`, {
      ...homeOffice.value,
      tax_year: taxYear.value
    })
    homeOffice.value = response
  } catch (error) {
    console.error('Error saving home office:', error)
    alert('Error saving home office record')
  } finally {
    savingHomeOffice.value = false
  }
}

const addVehicle = () => {
  vehicles.value.push({
    tax_year: taxYear.value,
    method: 'standard_mileage',
    vehicle_description: '',
    total_miles: null,
    business_miles: null,
    commuting_miles: null,
    personal_miles: null,
    parking_tolls: null
  })
}

const saveVehicle = async (vehicle) => {
  const companyId = appStore.currentCompany?.id
  if (!companyId) return

  savingVehicle.value = true
  try {
    const response = await apiClient.post(`/api/v1/companies/${companyId}/schedule_c/vehicles`, {
      ...vehicle,
      tax_year: taxYear.value
    })
    // Update vehicle in array with response (includes id)
    const index = vehicles.value.indexOf(vehicle)
    if (index >= 0) {
      vehicles.value[index] = response
    }
  } catch (error) {
    console.error('Error saving vehicle:', error)
    alert('Error saving vehicle record')
  } finally {
    savingVehicle.value = false
  }
}

const deleteVehicle = async (vehicle, index) => {
  if (!confirm('Delete this vehicle record?')) return

  const companyId = appStore.currentCompany?.id
  if (vehicle.id) {
    try {
      await apiClient.delete(`/api/v1/companies/${companyId}/schedule_c/vehicles/${vehicle.id}`)
    } catch (error) {
      console.error('Error deleting vehicle:', error)
      alert('Error deleting vehicle')
      return
    }
  }
  vehicles.value.splice(index, 1)
}

// Watch for company changes
watch(() => appStore.currentCompany, () => {
  loadData()
})

onMounted(() => {
  loadData()
})
</script>
