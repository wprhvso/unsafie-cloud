<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'
import QuotaBar from '../components/QuotaBar.vue'

const stats = ref({
  nodes_online: 3,
  active_vms: 2,
  active_tenants: 4,
  active_databases: 11,
  active_kameleo_slots: 1,
  max_kameleo_slots: 10,
})

const quotas = ref({
  vcpus_used: 2,
  vcpus_limit: 4,
  ram_mb_used: 4096,
  ram_mb_limit: 8192,
  disk_gb_used: 25,
  disk_gb_limit: 60,
  domains_used: 1,
  domains_limit: 6,
})

onMounted(async () => {
  try {
    const [statsRes, quotasRes] = await Promise.all([
      axios.get('/api/dashboard/stats'),
      axios.get('/api/dashboard/quotas'),
    ])
    stats.value = statsRes.data
    quotas.value = quotasRes.data
  } catch {}
})
</script>

<template>
  <div class="space-y-8">
    <div>
      <h1 class="text-2xl font-bold text-white">Platform Dashboard</h1>
      <p class="text-slate-400 text-sm mt-1">3-Node Cluster across Amnezia WireGuard Mesh</p>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div class="bg-slate-900 border border-slate-800 p-5 rounded-2xl">
        <span class="text-xs text-slate-400 font-medium">Cluster Nodes</span>
        <div class="text-2xl font-bold text-emerald-400 mt-2">{{ stats.nodes_online }} / 3 Online</div>
      </div>
      <div class="bg-slate-900 border border-slate-800 p-5 rounded-2xl">
        <span class="text-xs text-slate-400 font-medium">K3s Tenants</span>
        <div class="text-2xl font-bold text-white mt-2">{{ stats.active_tenants }} active</div>
      </div>
      <div class="bg-slate-900 border border-slate-800 p-5 rounded-2xl">
        <span class="text-xs text-slate-400 font-medium">Systemd Databases</span>
        <div class="text-2xl font-bold text-white mt-2">{{ stats.active_databases }} services</div>
      </div>
      <div class="bg-slate-900 border border-slate-800 p-5 rounded-2xl">
        <span class="text-xs text-slate-400 font-medium">Kameleo Slots</span>
        <div class="text-2xl font-bold text-emerald-400 mt-2">{{ stats.active_kameleo_slots }} / {{ stats.max_kameleo_slots }}</div>
      </div>
    </div>

    <div>
      <h2 class="text-lg font-semibold text-white mb-4">My Personal Quotas</h2>
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <QuotaBar label="vCPU Cores" :used="quotas.vcpus_used" :limit="quotas.vcpus_limit" unit="cores" />
        <QuotaBar label="RAM" :used="Math.round(quotas.ram_mb_used / 1024)" :limit="Math.round(quotas.ram_mb_limit / 1024)" unit="GB" />
        <QuotaBar label="NVMe Disk" :used="quotas.disk_gb_used" :limit="quotas.disk_gb_limit" unit="GB" />
        <QuotaBar label="Domains" :used="quotas.domains_used" :limit="quotas.domains_limit" unit="pcs" />
      </div>
    </div>
  </div>
</template>
