<script setup lang="ts">
import { ref } from 'vue'

const activeTab = ref('nodes')
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold text-white">Admin & Teacher Dashboard</h1>
      <p class="text-slate-400 text-sm mt-1">Cluster monitoring, quota management, and domain moderation</p>
    </div>

    <div class="flex space-x-2 border-b border-slate-800 pb-3">
      <button @click="activeTab = 'nodes'" :class="[activeTab === 'nodes' ? 'bg-slate-800 text-white' : 'text-slate-400 hover:text-white', 'px-4 py-2 rounded-xl text-sm font-medium transition']">
        Nodes & Quorum
      </button>
      <button @click="activeTab = 'approvals'" :class="[activeTab === 'approvals' ? 'bg-slate-800 text-white' : 'text-slate-400 hover:text-white', 'px-4 py-2 rounded-xl text-sm font-medium transition']">
        Domain Requests
      </button>
      <button @click="activeTab = 'quotas'" :class="[activeTab === 'quotas' ? 'bg-slate-800 text-white' : 'text-slate-400 hover:text-white', 'px-4 py-2 rounded-xl text-sm font-medium transition']">
        Pricing Plans
      </button>
    </div>

    <div v-if="activeTab === 'nodes'" class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="bg-slate-900 border border-slate-800 p-5 rounded-2xl space-y-2">
        <div class="flex justify-between items-center">
          <span class="font-bold text-white">Node 1 (Aeza 9950X)</span>
          <span class="text-emerald-400 text-xs font-semibold">10.42.0.1</span>
        </div>
        <div class="text-xs text-slate-400">16 cores Ryzen 9950X • 40GB RAM • 480GB NVMe</div>
        <div class="text-xs text-emerald-400">Roles: K3s Master 1, Primary Postgres, Kameleo 1</div>
      </div>
      <div class="bg-slate-900 border border-slate-800 p-5 rounded-2xl space-y-2">
        <div class="flex justify-between items-center">
          <span class="font-bold text-white">Node 2 (Cloud Dedicated)</span>
          <span class="text-emerald-400 text-xs font-semibold">10.42.0.2</span>
        </div>
        <div class="text-xs text-slate-400">Xeon E-2388G • 64GB RAM • 2x 960GB NVMe</div>
        <div class="text-xs text-emerald-400">Roles: Ingress Anchor, K3s Master 2, VictoriaMetrics Core</div>
      </div>
      <div class="bg-slate-900 border border-slate-800 p-5 rounded-2xl space-y-2">
        <div class="flex justify-between items-center">
          <span class="font-bold text-white">Node 3 (Office Server)</span>
          <span class="text-emerald-400 text-xs font-semibold">10.42.0.3</span>
        </div>
        <div class="text-xs text-slate-400">Behind NAT (AWG Mesh) • 32GB RAM • 2TB HDD</div>
        <div class="text-xs text-emerald-400">Roles: etcd quorum 3/3, offline backups 3-2-1</div>
      </div>
    </div>
  </div>
</template>
