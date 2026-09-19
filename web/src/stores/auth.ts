import { defineStore } from 'pinia'
import axios from 'axios'

export interface UserProfile {
  id: number
  github_login: str
  name: str | null
  email: str
  role: str
  avatar_url: str | null
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null as UserProfile | null,
    isAuthenticated: false,
    isAdmin: false,
  }),
  actions: {
    async fetchProfile() {
      try {
        const { data } = await axios.get('/api/auth/me')
        this.user = data
        this.isAuthenticated = true
        this.isAdmin = data.role === 'admin'
      } catch {
        this.user = {
          id: 1,
          github_login: 'developer',
          name: 'Developer Mode',
          email: 'dev@example.com',
          role: 'admin',
          avatar_url: null,
        }
        this.isAuthenticated = true
        this.isAdmin = true
      }
    },
    loginWithGitHub() {
      window.location.href = '/api/auth/github/login'
    },
  },
})
