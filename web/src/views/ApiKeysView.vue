<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'

const keys = ref<any[]>([])
const createdKeySecret = ref<string | null>(null)
const keyName = ref('')
const loading = ref(false)

const fetchKeys = async () => {
  try {
    const { data } = await axios.get('/api/api-keys')
    keys.value = data
  } catch {}
}

const createKey = async () => {
  loading.value = true
  try {
    const { data } = await axios.post('/api/api-keys', { name: keyName.value })
    createdKeySecret.value = data.secret_key
    keyName.value = ''
    await fetchKeys()
  } catch (err: any) {
    alert(err.response?.data?.detail || 'Ошибка создания')
  } finally {
    loading.value = false
  }
}

onMounted(fetchKeys)
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold text-white">Единые API Ключи</h1>
      <p class="text-slate-400 text-sm mt-1">Один ключ для доступа к LLM нейросетям, антидетект-браузерам и Task Pool</p>
    </div>

    <div v-if="createdKeySecret" class="bg-emerald-950/50 border border-emerald-500/50 p-4 rounded-2xl space-y-2">
      <div class="text-sm font-semibold text-emerald-400">Ключ успешно создан! Скопируйте его прямо сейчас:</div>
      <div class="bg-slate-950 p-3 rounded-xl border border-slate-800 font-mono text-sm text-emerald-300 break-all select-all">
        {{ createdKeySecret }}
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div class="md:col-span-2 space-y-4">
        <div v-for="k in keys" :key="k.id" class="bg-slate-900 border border-slate-800 p-5 rounded-2xl flex items-center justify-between">
          <div>
            <div class="font-bold text-white">{{ k.name }}</div>
            <div class="text-xs font-mono text-slate-400 mt-1">Префикс: {{ k.key_prefix }}••••••••</div>
            <div class="text-xs text-emerald-400 mt-1">Скоупы: {{ k.scopes.join(', ') }}</div>
          </div>
          <span class="px-2.5 py-1 text-xs rounded-full bg-slate-800 text-emerald-400 border border-slate-700">Активен</span>
        </div>
      </div>

      <div class="bg-slate-900 border border-slate-800 p-6 rounded-2xl space-y-4">
        <h3 class="text-lg font-bold text-white">Создание API Ключа</h3>
        <div class="space-y-3 text-sm">
          <div>
            <label class="block text-slate-400 mb-1">Назначение ключа</label>
            <input v-model="keyName" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white" placeholder="Telegram Bot / Parser" />
          </div>
          <button @click="createKey" :disabled="loading || !keyName" class="w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 rounded-xl font-semibold text-white transition text-sm">
            {{ loading ? 'Генерация...' : 'Создать ключ' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
