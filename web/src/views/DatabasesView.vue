<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'

const databases = ref<any[]>([])
const loading = ref(false)

const form = ref({
  db_type: 'postgres',
  db_name: '',
})

const fetchDbs = async () => {
  try {
    const { data } = await axios.get('/api/databases')
    databases.value = data
  } catch {}
}

const orderDb = async () => {
  loading.value = true
  try {
    await axios.post('/api/databases', form.value)
    await fetchDbs()
    form.value.db_name = ''
  } catch (err: any) {
    alert(err.response?.data?.detail || 'Ошибка создания')
  } finally {
    loading.value = false
  }
}

onMounted(fetchDbs)
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold text-white">СУБД Data Hub</h1>
      <p class="text-slate-400 text-sm mt-1">11 нативных баз данных в systemd с изоляцией прав и лимитами</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div class="md:col-span-2 space-y-4">
        <div v-for="db in databases" :key="db.id" class="bg-slate-900 border border-slate-800 p-5 rounded-2xl space-y-3">
          <div class="flex items-center justify-between">
            <span class="font-bold text-white text-lg">{{ db.db_name }}</span>
            <span class="px-2.5 py-1 text-xs rounded-full bg-slate-800 border border-slate-700 text-emerald-400 font-mono">{{ db.db_type }}</span>
          </div>
          <div class="bg-slate-950 p-3 rounded-xl border border-slate-800 font-mono text-xs text-slate-300 break-all select-all">
            {{ db.connection_url }}
          </div>
        </div>
      </div>

      <div class="bg-slate-900 border border-slate-800 p-6 rounded-2xl space-y-4">
        <h3 class="text-lg font-bold text-white">Выдача базы данных</h3>
        <div class="space-y-3 text-sm">
          <div>
            <label class="block text-slate-400 mb-1">СУБД</label>
            <select v-model="form.db_type" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white">
              <option value="postgres">PostgreSQL 17</option>
              <option value="valkey">Valkey 8 (Redis)</option>
              <option value="mongo">MongoDB 7</option>
              <option value="clickhouse">ClickHouse 24</option>
              <option value="redpanda">Redpanda (Kafka)</option>
              <option value="rabbitmq">RabbitMQ 3.13</option>
              <option value="nats">NATS JetStream</option>
              <option value="meilisearch">Meilisearch</option>
              <option value="qdrant">Qdrant</option>
              <option value="pocketbase">PocketBase</option>
            </select>
          </div>
          <div>
            <label class="block text-slate-400 mb-1">Имя базы данных</label>
            <input v-model="form.db_name" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white" placeholder="my_shop_db" />
          </div>
          <button @click="orderDb" :disabled="loading" class="w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 rounded-xl font-semibold text-white transition text-sm">
            {{ loading ? 'Выдача...' : 'Выдать базу' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
