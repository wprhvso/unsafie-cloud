<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'

const vms = ref<any[]>([])
const loading = ref(false)

const form = ref({
  name: '',
  node: 'node1-aeza',
  vcpus: 2,
  ram_mb: 4096,
  disk_gb: 30,
})

const fetchVms = async () => {
  try {
    const { data } = await axios.get('/api/vms')
    vms.value = data
  } catch {}
}

const createVm = async () => {
  loading.value = true
  try {
    await axios.post('/api/vms', form.value)
    await fetchVms()
    form.value.name = ''
  } catch (err: any) {
    alert(err.response?.data?.detail || 'Creation error')
  } finally {
    loading.value = false
  }
}

onMounted(fetchVms)
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold text-white">KVM Virtual Machines</h1>
      <p class="text-slate-400 text-sm mt-1">Hardware virtualization powered by Incus / Libvirt</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div class="md:col-span-2 space-y-4">
        <div v-for="vm in vms" :key="vm.id" class="bg-slate-900 border border-slate-800 p-5 rounded-2xl flex items-center justify-between">
          <div>
            <div class="font-bold text-white">{{ vm.name }}</div>
            <div class="text-xs text-slate-400 mt-1">
              {{ vm.node }} • {{ vm.vcpus }} vCPU • {{ Math.round(vm.ram_mb / 1024) }} GB RAM • {{ vm.disk_gb }} GB Disk
            </div>
            <div class="text-xs font-mono text-emerald-400 mt-1">IP: {{ vm.ip_address || '10.42.1.x' }}</div>
          </div>
          <div class="flex items-center space-x-3">
            <span class="px-2.5 py-1 text-xs rounded-full bg-slate-800 text-emerald-400 border border-slate-700">{{ vm.status }}</span>
          </div>
        </div>
      </div>

      <div class="bg-slate-900 border border-slate-800 p-6 rounded-2xl space-y-4">
        <h3 class="text-lg font-bold text-white">Order KVM VM</h3>
        <div class="space-y-3 text-sm">
          <div>
            <label class="block text-slate-400 mb-1">VM Name</label>
            <input v-model="form.name" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white" placeholder="vm-prod" />
          </div>
          <div>
            <label class="block text-slate-400 mb-1">Target Node</label>
            <select v-model="form.node" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white">
              <option value="node1-aeza">Node 1 (Aeza 9950X)</option>
              <option value="node2-cloud">Node 2 (Cloud Dedicated)</option>
              <option value="node3-office">Node 3 (Office behind NAT)</option>
            </select>
          </div>
          <div>
            <label class="block text-slate-400 mb-1">vCPU: {{ form.vcpus }}</label>
            <input type="range" v-model.number="form.vcpus" min="1" max="8" class="w-full" />
          </div>
          <div>
            <label class="block text-slate-400 mb-1">RAM: {{ Math.round(form.ram_mb / 1024) }} GB</label>
            <input type="range" v-model.number="form.ram_mb" min="1024" max="16384" step="1024" class="w-full" />
          </div>
          <button @click="createVm" :disabled="loading" class="w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 rounded-xl font-semibold text-white transition text-sm">
            {{ loading ? 'Creating...' : 'Order VM' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
