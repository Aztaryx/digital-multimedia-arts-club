import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  // Repo is served at username.github.io/digital-multimedia-arts-club/,
  // not the domain root, so every asset URL needs this prefix. If you
  // ever put a custom domain on this (there's CNAME history for one),
  // change this back to '/' — a custom domain serves from the root.
  base: '/digital-multimedia-arts-club/',
})