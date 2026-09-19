<script setup lang="ts">
import { ref, onMounted } from 'vue'
import axios from 'axios'

const buckets = ref<any[]>([])
const loading = ref(false)

const form = ref({
  bucket_name: '',
  bucket_type: 'public-read',
  quota_gb: 10,
})

const fetchBuckets = async () => {
  try {
    const { data } = await axios.get('/api/storage/buckets')
    buckets.value = data
  } catch {}
}

const createBucket = async () => {
  loading.value = true
  try {
    await axios.post('/api/storage/buckets', form.value)
    await fetchBuckets()
    form.value.bucket_name = ''
  } catch (err: any) {
    alert(err.response?.data?.detail || 'Creation error')
  } finally {
    loading.value = false
  }
}

onMounted(fetchBuckets)
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold text-white">S3 Storage (Garage + Cloudflare R2)</h1>
      <p class="text-slate-400 text-sm mt-1">Local NVMe-speed S3 cluster with background R2 replication</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <div class="md:col-span-2 space-y-4">
        <div v-for="b in buckets" :key="b.id" class="bg-slate-900 border border-slate-800 p-5 rounded-2xl space-y-3">
          <div class="flex items-center justify-between">
            <span class="font-bold text-white text-lg">{{ b.bucket_name }}</span>
            <span class="px-2.5 py-1 text-xs rounded-full bg-slate-800 border border-slate-700 text-emerald-400">{{ b.bucket_type }}</span>
          </div>
          <div class="text-xs text-slate-400">Quota: {{ b.quota_gb }} GB • Access Key: <span class="font-mono text-slate-200">{{ b.access_key_id }}</span></div>
          <div class="flex space-x-2 pt-2">
            <a :href="`/api/storage/buckets/${b.id}/cyberduck-profile`" class="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs rounded-lg font-medium transition">
              Download Cyberduck profile
            </a>
          </div>
        </div>
      </div>

      <div class="bg-slate-900 border border-slate-800 p-6 rounded-2xl space-y-4">
        <h3 class="text-lg font-bold text-white">Create S3 Bucket</h3>
        <div class="space-y-3 text-sm">
          <div>
            <label class="block text-slate-400 mb-1">Bucket Name</label>
            <input v-model="form.bucket_name" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white" placeholder="my-media-bucket" />
          </div>
          <div>
            <label class="block text-slate-400 mb-1">Access Type</label>
            <select v-model="form.bucket_type" class="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-white">
              <option value="public-read">Public Read (CDN)</option>
              <option value="private">Private (Backups)</option>
            </select>
          </div>
          <button @click="createBucket" :disabled="loading" class="w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 rounded-xl font-semibold text-white transition text-sm">
            {{ loading ? 'Creating...' : 'Create Bucket' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
