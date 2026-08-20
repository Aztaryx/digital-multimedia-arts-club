/* rank-color.js — shared white → orange → gold interpolation.
   Takes a percentile (0 = bottom of the board, 1 = #1) and returns an
   rgb() string. Pulled out on its own so ProfileView.vue and
   about/MembersView.vue's MemberCard usage compute the exact same
   color for the exact same rank, instead of two copies drifting. */
export function colorForPercentile(p) {
  const clamp = Math.max(0, Math.min(1, p));
  const stops = [
    { at: 0, c: [176, 176, 176] },   // floor — dim white/grey
    { at: 0.5, c: [249, 115, 22] },  // mid pack — house orange
    { at: 1, c: [255, 215, 0] },     // #1 — gold
  ];
  const [a, b] = clamp > 0.5 ? [stops[1], stops[2]] : [stops[0], stops[1]];
  const t = a.at === b.at ? 0 : (clamp - a.at) / (b.at - a.at);
  const mix = a.c.map((v, i) => Math.round(v + (b.c[i] - v) * t));
  return `rgb(${mix[0]}, ${mix[1]}, ${mix[2]})`;
}
