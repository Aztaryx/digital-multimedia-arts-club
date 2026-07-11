<!-- ColorWheelPicker.vue — a real color wheel: hue around the ring,
     saturation from center (white) to edge (full color), plus a
     brightness slider underneath. v-model of a hex string. Canvas +
     Pointer Events, no dependency — draws the wheel once per mount
     (it never needs to change), then just reads/writes hue+sat from
     pointer position and redraws only the small cursor dot. -->
<template>
  <div class="wheel-picker">
    <div class="wheel-canvas-wrap" :style="{ width: `${SIZE}px`, height: `${SIZE}px` }">
      <canvas
        ref="canvasRef"
        :width="SIZE"
        :height="SIZE"
        class="wheel-canvas"
        @pointerdown="onPointerDown"
        @pointermove="onPointerMove"
        @pointerup="onPointerUp"
        @pointercancel="onPointerUp"
      ></canvas>
      <div class="wheel-cursor" :style="cursorStyle" aria-hidden="true"></div>
    </div>

    <div class="wheel-value-row">
      <span class="wheel-value-label">Brightness</span>
      <input
        class="wheel-value-slider"
        type="range"
        min="0"
        max="100"
        v-model.number="value"
        @input="emitColor"
        aria-label="Color brightness"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { hexToHsv, hsvToHex, hsvToRgb } from '../lib/color-utils.js';

const props = defineProps({
  modelValue: { type: String, default: '#f97316' },
});
const emit = defineEmits(['update:modelValue']);

const SIZE = 180;
const RADIUS = SIZE / 2;

const canvasRef = ref(null);
const hue = ref(0);
const sat = ref(100);
const value = ref(100);

// Guards against the watch(modelValue) below re-reading a value this
// component just emitted itself — hex round-trips through HSV lose a
// little precision, and without this the picker would visibly jitter
// as it corrects its own output every time you move it.
let selfUpdate = false;

function syncFromModel(hex) {
  const hsv = hexToHsv(hex || '#f97316');
  hue.value = hsv.h;
  sat.value = hsv.s;
  value.value = hsv.v;
}

watch(
  () => props.modelValue,
  (hex) => {
    if (selfUpdate) { selfUpdate = false; return; }
    syncFromModel(hex);
  },
);

function emitColor() {
  selfUpdate = true;
  emit('update:modelValue', hsvToHex(hue.value, sat.value, value.value));
}

function drawWheel() {
  const canvas = canvasRef.value;
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const img = ctx.createImageData(SIZE, SIZE);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const dx = x - RADIUS;
      const dy = y - RADIUS;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const idx = (y * SIZE + x) * 4;
      if (dist > RADIUS) {
        img.data[idx + 3] = 0; // outside the circle — fully transparent
        continue;
      }
      let angle = Math.atan2(dy, dx) * (180 / Math.PI);
      angle = (angle + 360) % 360;
      const s = Math.min(1, dist / RADIUS) * 100;
      const [r, g, b] = hsvToRgb(angle, s, 100);
      img.data[idx] = r;
      img.data[idx + 1] = g;
      img.data[idx + 2] = b;
      img.data[idx + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
}

const cursorStyle = computed(() => {
  const angleRad = (hue.value * Math.PI) / 180;
  const dist = (sat.value / 100) * RADIUS;
  const x = RADIUS + dist * Math.cos(angleRad);
  const y = RADIUS + dist * Math.sin(angleRad);
  return {
    left: `${x}px`,
    top: `${y}px`,
    background: hsvToHex(hue.value, sat.value, value.value),
  };
});

const dragging = ref(false);

function pickFromEvent(e) {
  const canvas = canvasRef.value;
  const rect = canvas.getBoundingClientRect();
  const dx = e.clientX - rect.left - RADIUS;
  const dy = e.clientY - rect.top - RADIUS;
  const dist = Math.min(RADIUS, Math.sqrt(dx * dx + dy * dy));
  let angle = Math.atan2(dy, dx) * (180 / Math.PI);
  angle = (angle + 360) % 360;
  hue.value = angle;
  sat.value = Math.round((dist / RADIUS) * 100);
  emitColor();
}

function onPointerDown(e) {
  dragging.value = true;
  canvasRef.value?.setPointerCapture?.(e.pointerId);
  pickFromEvent(e);
}
function onPointerMove(e) {
  if (!dragging.value) return;
  pickFromEvent(e);
}
function onPointerUp() {
  dragging.value = false;
}

onMounted(() => {
  syncFromModel(props.modelValue);
  drawWheel();
});
</script>

<style scoped>
.wheel-picker {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.wheel-canvas-wrap {
  position: relative;
  flex-shrink: 0;
}

.wheel-canvas {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  cursor: crosshair;
  touch-action: none;
  box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.12);
}

.wheel-cursor {
  position: absolute;
  width: 16px;
  height: 16px;
  margin-left: -8px;
  margin-top: -8px;
  border-radius: 50%;
  border: 2px solid #fff;
  box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.5), 0 2px 6px rgba(0, 0, 0, 0.4);
  pointer-events: none;
}

.wheel-value-row {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  max-width: 220px;
}

.wheel-value-label {
  font-family: var(--font, inherit);
  font-size: 0.7rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.55);
  flex-shrink: 0;
}

.wheel-value-slider {
  flex: 1;
  accent-color: var(--orange, #f97316);
}
</style>
