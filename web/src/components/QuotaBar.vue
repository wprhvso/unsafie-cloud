<script setup lang="ts">
defineProps<{
  label: string
  used: number
  limit: number
  unit: string
}>()
</script>

<template>
  <div class="bg-slate-900 p-4 rounded-xl border border-slate-800">
    <div class="flex justify-between text-sm mb-2">
      <span class="text-slate-400 font-medium">{{ label }}</span>
      <span class="text-slate-200 font-semibold">{{ used }} / {{ limit }} {{ unit }}</span>
    </div>
    <div class="w-full bg-slate-800 h-2 rounded-full overflow-hidden">
      <div 
        class="bg-emerald-500 h-full rounded-full transition-all duration-300"
        :style="{ width: `${Math.min(100, (used / limit) * 100)}%` }"
      />
    </div>
  </div>
</template>
