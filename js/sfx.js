/* ═══════════════════════════════════════════════════
   sfx.js — audio sprite playback engine
   ═══════════════════════════════════════════════════
   Plays named sound effects out of the combined sprite files
   described in js/sfx-data.js (load that file first).

   NOT WIRED INTO ANY PAGE YET. This is just the engine + a way
   to call it manually — nothing on the live site triggers a sound
   on its own. See dev/sfx-test.html to browse/preview every sound
   before deciding what plays where. When you're ready to wire one
   up, it's just: SFX.play('menuclick') inside whatever event
   handler you want to trigger it.

   USAGE
   ------------------------------------------------------
   SFX.play('menuclick');
   SFX.play('victory', { volume: 0.6 });
   const handle = SFX.play('thunder5');   // long one — maybe cut it off early
   handle.stop();

   SFX.setMasterVolume(0.5);              // 0–1, affects everything after this call
   SFX.preload('common');                 // optional — fetch+decode ahead of first play
   SFX.listSounds();                      // [{ name, sprite, duration }, ...] — for browsing

   HOW IT WORKS
   ------------------------------------------------------
   Uses the Web Audio API rather than <audio>.currentTime seeking:
   each sprite's file is fetched + decoded ONCE into an AudioBuffer,
   cached, then every SFX.play() call spins up a fresh
   AudioBufferSourceNode sliced to [start, end) via
   source.start(0, start, duration). That means overlapping sounds
   (e.g. two combo sounds firing close together) just work — no
   fighting over one shared <audio> element's playhead.

   Format choice per sprite follows the priority order in each
   sprite's `sources` array (webm/opus → m4a/aac → mp3), picked via
   canPlayType() the same way the data file's own instructions
   describe, then fetched as an arrayBuffer and decoded.

   Browsers block audio until a user gesture. Nothing here plays
   automatically, so as long as SFX.play() is only ever called from
   inside a click/keydown/etc. handler (which is the plan — see
   above), the AudioContext unlocks itself naturally on first use.
   No manual "unlock" step needed.
   ═══════════════════════════════════════════════════ */

const SFX = (() => {

  let ctx = null;
  let masterGain = null;

  /* Per-sprite state, keyed by sprite name (e.g. 'common'):
       { bufferPromise: Promise<AudioBuffer> | null }
     Populated lazily on first play()/preload() for that sprite. */
  const spriteCache = {};

  /* Every currently-playing source node, so stopAll() can reach them. */
  const activeSources = new Set();

  function ensureContext() {
    if (!ctx) {
      ctx = new (window.AudioContext || window.webkitAudioContext)();
      masterGain = ctx.createGain();
      masterGain.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') {
      ctx.resume();
    }
    return ctx;
  }

  /* ── FORMAT SELECTION ───────────────────────────────
     Walks a sprite's `sources` array in priority order and returns
     the first one a throwaway <audio> element reports as playable.
     Falls back to the first entry if canPlayType is unavailable or
     nothing reports support (better to try and fail than not try). */
  function pickSource(sprite) {
    const probe = document.createElement('audio');
    if (probe.canPlayType) {
      for (const src of sprite.sources) {
        const support = probe.canPlayType(src.type);
        if (support === 'probably' || support === 'maybe') return src;
      }
    }
    return sprite.sources[0];
  }

  /* ── SPRITE LOADING ─────────────────────────────────
     Fetch + decode a sprite's audio file exactly once, cache the
     resulting AudioBuffer (well, the promise for it, so concurrent
     calls before it resolves share the same in-flight fetch). */
  function loadSprite(spriteName) {
    if (!spriteCache[spriteName]) {
      spriteCache[spriteName] = { bufferPromise: null };
    }
    const entry = spriteCache[spriteName];
    if (entry.bufferPromise) return entry.bufferPromise;

    const sprite = SFX_DATA[spriteName];
    if (!sprite) {
      return Promise.reject(new Error(`SFX: no sprite named "${spriteName}"`));
    }

    const context = ensureContext();
    const source = pickSource(sprite);

    entry.bufferPromise = fetch(source.url)
      .then(res => {
        if (!res.ok) throw new Error(`SFX: fetch failed for sprite "${spriteName}" (${res.status})`);
        return res.arrayBuffer();
      })
      .then(arrayBuffer => context.decodeAudioData(arrayBuffer))
      .catch(err => {
        entry.bufferPromise = null; // allow retrying on a later play() call
        throw err;
      });

    return entry.bufferPromise;
  }

  /* ── SOUND LOOKUP ───────────────────────────────────
     Finds which sprite a sound name lives in. If `spriteName` is
     given, only that sprite is checked. Otherwise searches every
     sprite in SFX_DATA — if the name turns up in more than one
     (not true of anything today, but the data file doesn't
     guarantee it stays that way), this throws rather than silently
     guessing, since which sprite you meant genuinely isn't knowable
     from the name alone. */
  function findSound(name, spriteName) {
    if (spriteName) {
      const sprite = SFX_DATA[spriteName];
      const def = sprite && sprite.sounds[name];
      if (!def) throw new Error(`SFX: no sound "${name}" in sprite "${spriteName}"`);
      return { spriteName, def };
    }

    const matches = Object.keys(SFX_DATA).filter(s => SFX_DATA[s].sounds[name]);
    if (matches.length === 0) {
      throw new Error(`SFX: no sound named "${name}" in any sprite`);
    }
    if (matches.length > 1) {
      throw new Error(`SFX: "${name}" exists in multiple sprites (${matches.join(', ')}) — pass { sprite: '...' } to disambiguate`);
    }
    return { spriteName: matches[0], def: SFX_DATA[matches[0]].sounds[name] };
  }

  /* ── PLAYBACK ───────────────────────────────────────
     Fire-and-forget by default — call it from an event handler and
     don't worry about the promise. It still returns a handle
     ({ stop }) synchronously so you can cut a long sound short
     (e.g. a thunder rumble) even while it's mid-decode; stop()
     just becomes a no-op if the sound never ends up playing (load
     failure, etc). */
  function play(name, opts = {}) {
    const { sprite: spriteName, volume, playbackRate } = opts;
    let stopped = false;
    let liveSource = null;

    const handle = {
      stop() {
        stopped = true;
        if (liveSource) {
          try { liveSource.stop(); } catch (_) { /* already stopped/ended */ }
        }
      }
    };

    let found;
    try {
      found = findSound(name, spriteName);
    } catch (err) {
      console.error(err.message);
      return handle;
    }

    const context = ensureContext();

    loadSprite(found.spriteName).then(buffer => {
      if (stopped) return;

      const src = context.createBufferSource();
      src.buffer = buffer;
      if (playbackRate) src.playbackRate.value = playbackRate;

      const gain = context.createGain();
      gain.gain.value = volume != null ? volume : 1;

      src.connect(gain);
      gain.connect(masterGain);

      const duration = found.def.end - found.def.start;
      activeSources.add(src);
      src.addEventListener('ended', () => activeSources.delete(src));

      liveSource = src;
      src.start(0, found.def.start, duration);
    }).catch(err => {
      console.error(`SFX: couldn't play "${name}" —`, err.message || err);
    });

    return handle;
  }

  function stopAll() {
    activeSources.forEach(src => {
      try { src.stop(); } catch (_) { /* already stopped/ended */ }
    });
    activeSources.clear();
  }

  function setMasterVolume(v) {
    ensureContext();
    masterGain.gain.value = Math.max(0, Math.min(1, v));
  }

  function preload(spriteName) {
    return loadSprite(spriteName);
  }

  /* Flat list of every sound across every sprite — handy for
     building a browsing/preview UI (see dev/sfx-test.html). */
  function listSounds(spriteName) {
    const spriteNames = spriteName ? [spriteName] : Object.keys(SFX_DATA);
    const out = [];
    spriteNames.forEach(s => {
      const sprite = SFX_DATA[s];
      if (!sprite) return;
      Object.keys(sprite.sounds).forEach(name => {
        const def = sprite.sounds[name];
        out.push({ name, sprite: s, duration: +(def.end - def.start).toFixed(3) });
      });
    });
    return out;
  }

  return { play, stopAll, setMasterVolume, preload, listSounds, findSound };
})();
