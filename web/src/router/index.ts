import { createRouter, createWebHistory } from 'vue-router'
import DashboardView from '../views/DashboardView.vue'
import TenantsView from '../views/TenantsView.vue'
import VmsView from '../views/VmsView.vue'
import DatabasesView from '../views/DatabasesView.vue'
import StorageView from '../views/StorageView.vue'
import ApiKeysView from '../views/ApiKeysView.vue'
import AdminView from '../views/AdminView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/dashboard' },
    { path: '/dashboard', component: DashboardView },
    { path: '/tenants', component: TenantsView },
    { path: '/vms', component: VmsView },
    { path: '/databases', component: DatabasesView },
    { path: '/storage', component: StorageView },
    { path: '/api-keys', component: ApiKeysView },
    { path: '/admin', component: AdminView },
  ],
})

export default router
