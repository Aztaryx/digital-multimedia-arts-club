<!-- AvatarCropModal.vue — square drag-to-pan + zoom cropper for avatar
     uploads. Self-contained: takes the raw File the person picked,
     hands back a cropped File (same general shape as the input) via
     the `cropped` event, or `cancel` if they back out. No new
     dependency — everything here is plain canvas + Pointer Events,
     consistent with how the rest of this app builds its own small
     interactive bits (badge tilt, zigzag divider, etc.) rather than
     reaching for a library. -->
<template>
  <Teleport to="body">
    <div class="crop-overlay" @click="onOverlayClick">
      <div class="crop-modal" @click.stop>
        <div class="crop-head">
          <strong>Crop your avatar</strong>
          <button class="crop-close" aria-label="Cancel" @click="$emit('cancel')">✕</button>
        </div>

        <div
          ref="viewportRef"
          class="crop-viewport"
          @pointerdown="onPointerDown"
          @pointermove="onPointerMove"
          @pointerup="onPointerUp"
          @pointercancel="onPointerUp"
          @wheel.prevent="onWheel"
        >
          <img
            v-if="objectUrl"
            ref="imgRef"
            :src="objectUrl"
            class="crop-image"
            :style="imageStyle"
            draggable="false"
            @load="onImageLoad"
            alt=""
          />
        </div>

        <p class="crop-hint">Drag to reposition · scroll or use the slider to zoom</p>

        <div class="crop-zoom-row">
          <span class="crop-zoom-label">Zoom</span>
          <input
            class="crop-zoom-slider"
            type="range"
            min="1"
            max="3"
            step="0.01"
            v-model.number="zoom"
            @input="onZoomInput"
          />
        </div>

        <p v-if="errorMsg" class="crop-error">{{ errorMsg }}</p>

        <div class="crop-actions">
          <button class="forum-btn" @click="$emit('cancel')">Cancel</button>
          <button class="forum-btn forum-btn--primary" :disabled="!ready" @click="confirm">Use this crop</button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, onBeforeUnmount } from 'vue';

const props = defineProps({
  file: { type: File, required: true },
});
const emit = defineEmits(['cropped', 'cancel']);

const VIEWPORT = 260; // css px — the square crop window itself
const OUTPUT = 512;   // px — the actual uploaded image's resolution

const objectUrl = ref(URL.createObjectURL(props.file));
onBeforeUnmount(() => URL.revokeObjectURL(objectUrl.value));

const viewportRef = ref(null);
const imgRef = ref(null);
const ready = ref(false);
const errorMsg = ref('');

const naturalW = ref(0);
const naturalH = ref(0);
const baseScale = ref(1); // scale at zoom=1 — the "cover the viewport" minimum
const zoom = ref(1);
const tx = ref(0); // image top-left offset within the viewport, in css px
const ty = ref(0);

const scale = computed(() => baseScale.value * zoom.value);
const dispW = computed(() => naturalW.value * scale.value);
const dispH = computed(() => naturalH.value * scale.value);

const imageStyle = computed(() => ({
  width: `${dispW.value}px`,
  height: `${dispH.value}px`,
  transform: `translate(${tx.value}px, ${ty.value}px)`,
}));

function clamp(v, min, max) {
  return Math.min(max, Math.max(min, v));
}

// Keeps the viewport always fully covered by the image — no gaps at
// any edge, same constraint a typical avatar cropper enforces.
function clampOffsets() {
  const minX = VIEWPORT - dispW.value;
  const minY = VIEWPORT - dispH.value;
  tx.value = clamp(tx.value, minX, 0);
  ty.value = clamp(ty.value, minY, 0);
}

function onImageLoad(e) {
  naturalW.value = e.target.naturalWidth;
  naturalH.value = e.target.naturalHeight;
  if (!naturalW.value || !naturalH.value) {
    errorMsg.value = "Couldn't read that image — try a different file.";
    return;
  }
  baseScale.value = Math.max(VIEWPORT / naturalW.value, VIEWPORT / naturalH.value);
  zoom.value = 1;
  // Center the image in the viewport to start.
  tx.value = (VIEWPORT - naturalW.value * baseScale.value) / 2;
  ty.value = (VIEWPORT - naturalH.value * baseScale.value) / 2;
  ready.value = true;
}

function onZoomInput() {
  clampOffsets();
}

function onWheel(e) {
  const next = clamp(zoom.value - e.deltaY * 0.0015, 1, 3);
  zoom.value = next;
  clampOffsets();
}

/* ── DRAG (Pointer Events cover mouse + touch + pen in one path) ──── */
const dragging = ref(false);
const lastX = ref(0);
const lastY = ref(0);

function onPointerDown(e) {
  if (!ready.value) return;
  dragging.value = true;
  lastX.value = e.clientX;
  lastY.value = e.clientY;
  viewportRef.value?.setPointerCapture?.(e.pointerId);
}

function onPointerMove(e) {
  if (!dragging.value) return;
  const dx = e.clientX - lastX.value;
  const dy = e.clientY - lastY.value;
  lastX.value = e.clientX;
  lastY.value = e.clientY;
  tx.value += dx;
  ty.value += dy;
  clampOffsets();
}

function onPointerUp() {
  dragging.value = false;
}

function onOverlayClick(e) {
  if (e.target === e.currentTarget) emit('cancel');
}

/* ── OUTPUT ─────────────────────────────────────────
   Renders the exact same crop the viewport is showing, just at a
   fixed higher resolution — same viewport-space transform (tx/ty/
   scale), scaled up by OUTPUT/VIEWPORT so the math stays identical
   regardless of what the on-screen css px happened to be. */
async function confirm() {
  if (!ready.value || !imgRef.value) return;

  const canvas = document.createElement('canvas');
  canvas.width = OUTPUT;
  canvas.height = OUTPUT;
  const ctx = canvas.getContext('2d');
  const ratio = OUTPUT / VIEWPORT;

  ctx.drawImage(
    imgRef.value,
    tx.value * ratio,
    ty.value * ratio,
    dispW.value * ratio,
    dispH.value * ratio,
  );

  // PNG for anything that might have transparency (or already was
  // PNG/GIF), JPEG otherwise — keeps photo uploads from ballooning in
  // size while not flattening a transparent PNG's edges to black.
  const keepAlpha = props.file.type === 'image/png' || props.file.type === 'image/gif';
  const outType = keepAlpha ? 'image/png' : 'image/jpeg';
  const outExt = keepAlpha ? 'png' : 'jpg';

  canvas.toBlob(
    (blob) => {
      if (!blob) {
        errorMsg.value = 'Could not process that image — try again.';
        return;
      }
      const croppedFile = new File([blob], `avatar.${outExt}`, { type: outType });
      emit('cropped', croppedFile);
    },
    outType,
    outType === 'image/jpeg' ? 0.92 : undefined,
  );
}
</script>

<style scoped>
.crop-overlay {
  position: fixed;
  inset: 0;
  z-index: 1000;
  display: grid;
  place-items: center;
  background: rgba(8, 8, 12, 0.72);
  backdrop-filter: blur(3px);
  padding: 20px;
}

.crop-modal {
  width: min(360px, 100%);
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 20px;
  border-radius: 22px;
  background: #16161c;
  border: 1px solid rgba(255, 255, 255, 0.1);
  box-shadow: 0 24px 60px rgba(0, 0, 0, 0.5);
}

.crop-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-family: var(--font);
  color: #f0f0f0;
}

.crop-close {
  background: none;
  border: none;
  color: rgba(240, 240, 240, 0.6);
  cursor: pointer;
  font-size: 1rem;
  line-height: 1;
  padding: 4px;
}
.crop-close:hover { color: #fff; }

.crop-viewport {
  position: relative;
  width: 260px;
  height: 260px;
  margin: 0 auto;
  overflow: hidden;
  border-radius: 24px;
  background: repeating-conic-gradient(#222 0% 25%, #1a1a1a 0% 50%) 50% / 20px 20px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  cursor: grab;
  touch-action: none;
}
.crop-viewport:active { cursor: grabbing; }

.crop-image {
  position: absolute;
  top: 0;
  left: 0;
  max-width: none;
  user-select: none;
  pointer-events: none;
}

.crop-hint {
  font-family: var(--font2);
  font-size: 0.78rem;
  color: rgba(240, 240, 240, 0.55);
  text-align: center;
}

.crop-zoom-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.crop-zoom-label {
  font-family: var(--font);
  font-size: 0.7rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(240, 240, 240, 0.55);
  flex-shrink: 0;
}

.crop-zoom-slider {
  flex: 1;
  accent-color: var(--orange);
}

.crop-error {
  font-size: 0.8rem;
  color: #ffb0b0;
  text-align: center;
}

.crop-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}
</style>
