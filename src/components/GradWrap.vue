<template>
  <span class="grad-wrap" ref="wrapRef">
    <span class="grad-base"><slot /></span>
    <span class="grad-layer"><slot /></span>
  </span>
</template>

<script setup>
import { ref } from 'vue';

const wrapRef = ref(null);
</script>
