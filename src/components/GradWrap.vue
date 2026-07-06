<template>
  <span class="grad-wrap" ref="wrapRef">
    <span class="grad-base"><slot /></span>
    <span class="grad-layer"><slot /></span>
  </span>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { initGradText } from '../lib/animations.js';

const wrapRef = ref(null);

onMounted(() => {
  const wrap = wrapRef.value;
  if (!wrap) return;
  const layer = wrap.querySelector('.grad-layer');
  if (!layer || getComputedStyle(layer).display === 'none') return;
  initGradText(wrap, layer);
});
</script>
