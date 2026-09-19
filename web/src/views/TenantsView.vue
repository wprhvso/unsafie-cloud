<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'

const tenants = ref<any[]>([])
const loading = ref(false)
const showCreateModal = ref(false)

const form = ref({
  name: '',
  kind: 'ns',
  cpu_limit_cores: 2.0,
  ram_limit_mb: 4096,
  storage_limit_gb: 20,
  subdomain: '',
  wildcard: true,
})

const fetchTenants = async () => {
  try {
    const { data } = await axios.get('/api/tenants')
    tenants.value = data
  } catch {}
}

const createTenant = async () => {
  loading.value = true
  try {
    await axios.post('/api/tenants', form.value)
    showCreateModal.value = false
    await fetchTenants()
  } catch (err: any) {
    alert(err.response?.data?.detail || 'Ошибка создания')
  } finally {
    loading.value = false
  }
}

onMounted(fetchTenants)
</script>

<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-white">K3s Тенанты и vcluster</h1>
        <p class="text-slate-400 text-sm mt-1">Изолированные пространства имен и виртуальные кластеры</p>
      </div>
      <button @click="showCreateModal = true" class="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 rounded-xl text-sm font-semibold text-white transition">
        + Создать тенант
      </button>
    </div>

    <div v-if="tenants.length === 0" class="bg-slate-900 border border-slate-800 p-12 text-center rounded-2xl text-slate-400">
      Тенанты не созданы. Нажмите кнопку выше для развертывания.
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div v-for="t in tenants" :key="t.id" class="bg-slate-900 border border-slate-800 p-6 rounded-2xl space-y-4">
        <div class="flex items-center justify-between">
          <span class="font-bold text-lg text-white">{{ t.name }}</span>
          <span class="px-2.5 py-1 text-xs rounded-full bg-slate-800 border border-slate-700 text-emerald-400 font-medium">
            {{ t.kind === 'vc' ? 'vcluster' : 'namespace' }}
          </span>
        </div>
        <div class="text-sm text-slate-400 space-y-1">
          <div>Квоты: {{ t.cpu_limit_cores }} vCPU / {{ Math.round(t.ram_limit_mb / 1024) }} GB RAM / {{ t.storage_limit_gb }} GB Storage</div>
          <div v-if="t.domains.length > 0" class="text-emerald-400 font-mono text-xs">{{ t.domains.join(', ') }}</div>
        </div>
        <div class="pt-2 border-t border-slate-800 flex justify-between items-center text-xs">
          <span class="text-slate-500">Статус: <strong class="text-emerald-400">{{ t.status }}</strong></span>
          <button class="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 rounded-lg text-slate-300 font-medium">
            Скачать Kubeconfig
          </button>
        </div>
      </div>
    </div>

    <div v-if="showCreateModal" class="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50">
      <div class="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4">
        <h3 class="text-lg font-bold text-white">Создание K3s Тенанта</h3>
        <div class="space-y-3 text-sm">
          <div>
            <label class="block text-slate-400 mb-1">Имя проекта / команды</label>
            <input v-model="form.name" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white" placeholder="my-team-app" />
          </div>
          <div>
            <label class="block text-slate-400 mb-1">Тип изоляции</label>
            <div class="flex space-x-4">
              <label class="flex items-center space-x-2 text-slate-300">
                <input type="radio" v-model="form.kind" value="ns" /> <span>Namespace (ns)</span>
              </label>
              <label class="flex items-center space-x-2 text-slate-300">
                <input type="radio" v-model="form.kind" value="vc" /> <span>vcluster (vc)</span>
              </label>
            </div>
          </div>
          <div>
            <label class="block text-slate-400 mb-1">Поддомен</label>
            <input v-model="form.subdomain" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white" placeholder="my-team" />
          </div>
        </div>
        <div class="flex justify-end space-x-3 pt-4 border-t border-slate-800">
          <button @click="showCreateModal = false" class="px-4 py-2 bg-slate-800 text-slate-300 rounded-xl text-sm font-medium">Отмена</button>
          <button @click="createTenant" :disabled="loading" class="px-4 py-2 bg-emerald-600 text-white rounded-xl text-sm font-semibold">
            {{ loading ? 'Создание...' : 'Создать' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
