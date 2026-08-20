/* simple-markdown.js — deliberately tiny markdown → HTML renderer.
   Covers what an admin actually needs for a newsletter/announcement
   body (headers, bold/italic, links, lists, line breaks) without
   pulling in a new npm dependency (marked/markdown-it) for four
   patterns. If richer markdown ever becomes worth it, swap this
   module's internals for a real library — every call site here only
   imports `renderMarkdown`, so the swap is one file.

   Escapes HTML FIRST, then applies formatting on top of the escaped
   text — this is what keeps a body like "<script>alert(1)</script>"
   inert instead of executing: it becomes visible text, not markup. */

function escapeHtml(str) {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function renderMarkdown(raw) {
  const text = escapeHtml(raw || '');
  const lines = text.split('\n');
  const htmlLines = [];
  let inList = false;

  for (const line of lines) {
    const headerMatch = line.match(/^(#{1,3})\s+(.*)$/);
    const listMatch = line.match(/^[-*]\s+(.*)$/);

    if (listMatch) {
      if (!inList) { htmlLines.push('<ul>'); inList = true; }
      htmlLines.push(`<li>${inlineFormat(listMatch[1])}</li>`);
      continue;
    }
    if (inList) { htmlLines.push('</ul>'); inList = false; }

    if (headerMatch) {
      const level = headerMatch[1].length;
      htmlLines.push(`<h${level + 2}>${inlineFormat(headerMatch[2])}</h${level + 2}>`);
    } else if (line.trim() === '') {
      htmlLines.push('');
    } else {
      htmlLines.push(`<p>${inlineFormat(line)}</p>`);
    }
  }
  if (inList) htmlLines.push('</ul>');

  return htmlLines.filter((l) => l !== '').join('\n');
}

function inlineFormat(str) {
  return str
    // [label](https://...) — http(s) only, so this can't be used to
    // smuggle a javascript: link past the escaping above.
    .replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\*([^*]+)\*/g, '<em>$1</em>');
}

export default { renderMarkdown };
