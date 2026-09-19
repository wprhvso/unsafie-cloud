<script setup lang="ts">
import { useAuthStore } from '../stores/auth'
import { onMounted } from 'vue'

const auth = useAuthStore()

onMounted(() => {
  auth.fetchProfile()
})
</script>

<template>
  <header class="bg-slate-900 border-b border-slate-800 sticky top-0 z-50">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
      <div class="flex items-center space-x-8">
        <router-link to="/dashboard" class="flex items-center space-x-2 text-white font-bold text-lg">
          <span class="text-emerald-500">◆</span>
          <span>Infrastructure</span>
        </router-link>
        <nav class="hidden md:flex space-x-1">
          <router-link to="/dashboard" class="px-3 py-2 rounded-lg text-sm text-slate-300 hover:text-white hover:bg-slate-800">Обзор</router-link>
          <router-link to="/tenants" class="px-3 py-2 rounded-lg text-sm text-slate-300 hover:text-white hover:bg-slate-800">K3s Тенанты</router-link>
          <router-link to="/vms" class="px-3 py-2 rounded-lg text-sm text-slate-300 hover:text-white hover:bg-slate-800">Виртуалки KVM</router-link>
          <router-link to="/databases" class="px-3 py-2 rounded-lg text-sm text-slate-300 hover:text-white hover:bg-slate-800">СУБД Hub</router-link>
          <router-link to="/storage" class="px-3 py-2 rounded-lg text-sm text-slate-300 hover:text-white hover:bg-slate-800">S3 Хранилище</router-link>
          <router-link to="/api-keys" class="px-3 py-2 rounded-lg text-sm text-slate-300 hover:text-white hover:bg-slate-800">API Ключи</router-link>
          <router-link v-if="auth.isAdmin" to="/admin" class="px-3 py-2 rounded-lg text-sm text-emerald-400 hover:bg-slate-800">Админка</router-link>
        </nav>
      </div>

      <div class="flex items-center space-x-4">
        <div v-if="auth.user" class="flex items-center space-x-3 text-sm text-slate-300">
          <span class="font-medium text-slate-200">{{ auth.user.name || auth.user.github_login }}</span>
          <span class="px-2 py-0.5 rounded text-xs bg-slate-800 border border-slate-700 text-emerald-400">{{ auth.user.role }}</span>
        </div>
        <button v-else @click="auth.loginWithGitHub" class="px-4 py-2 rounded-lg text-sm bg-emerald-600 hover:bg-emerald-500 text-white font-medium transition">
          Войти
        </button>
      </div>
    </div>
  </header>
</template>
