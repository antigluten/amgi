// EPUBReaderInjection.js
//
// Injected at document-end into every EPUB chapter the paginated reader
// loads. Responsibilities:
//   1. Wrap text-node runs in <span class="amgi-tok"> tokens. Tokenisation
//      uses three regimes:
//        - Hangul runs (consecutive Hangul codepoints = one token)
//        - CJK + kana per-codepoint
//        - Latin word boundaries (\b\w+\b)
//   2. Report page count = Math.ceil(documentElement.scrollWidth /
//      window.innerWidth). <html> is the multi-column container and the
//      WKWebView's scrollable root; we never mutate body.style.width.
//   3. On scroll-end (debounced 250ms), report current pageIndex +
//      progressFraction (pageIndex / max(pageCount-1, 1)).
//   4. On click of a tokenised span, capture the surrounding sentence
//      (split on [.!?。！？\n]) and post a wordTap message.
//
// Posts to three message handlers: pageInfo, progress, wordTap.

(function () {
  'use strict';

  function isHangul(cp) {
    return (cp >= 0xAC00 && cp <= 0xD7AF) ||
           (cp >= 0x1100 && cp <= 0x11FF);
  }
  function isCJK(cp) {
    return (cp >= 0x3040 && cp <= 0x309F) || // Hiragana
           (cp >= 0x30A0 && cp <= 0x30FF) || // Katakana
           (cp >= 0x3000 && cp <= 0x303F) || // CJK Symbols
           (cp >= 0x3400 && cp <= 0x9FFF);   // CJK Unified Ideographs
  }
  function isWordChar(ch) {
    return /[A-Za-z0-9_À-ɏЀ-ӿ]/.test(ch);
  }

  function segmentText(text) {
    const out = [];
    let buf = '';
    let bufKind = null;

    function flush() {
      if (buf.length === 0) return;
      out.push({ text: buf, isToken: bufKind === 'latin' || bufKind === 'hangul' });
      buf = '';
      bufKind = null;
    }

    for (let i = 0; i < text.length; ) {
      const cp = text.codePointAt(i);
      const ch = String.fromCodePoint(cp);
      const step = ch.length;

      if (isHangul(cp)) {
        if (bufKind !== 'hangul') flush();
        bufKind = 'hangul';
        buf += ch;
      } else if (isCJK(cp)) {
        flush();
        out.push({ text: ch, isToken: true });
      } else if (isWordChar(ch)) {
        if (bufKind !== 'latin') flush();
        bufKind = 'latin';
        buf += ch;
      } else {
        if (bufKind !== 'other') flush();
        bufKind = 'other';
        buf += ch;
      }
      i += step;
    }
    flush();
    return out;
  }

  function tokenise(root) {
    const skipTags = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1 };
    const walker = document.createTreeWalker(
      root,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode(node) {
          let p = node.parentNode;
          while (p && p !== root) {
            if (p.nodeType === 1) {
              if (skipTags[p.tagName]) return NodeFilter.FILTER_REJECT;
              if (p.classList && p.classList.contains('amgi-tok')) return NodeFilter.FILTER_REJECT;
            }
            p = p.parentNode;
          }
          if (!node.nodeValue || !node.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
          return NodeFilter.FILTER_ACCEPT;
        }
      }
    );

    const queue = [];
    let n;
    while ((n = walker.nextNode())) queue.push(n);

    for (const textNode of queue) {
      const segments = segmentText(textNode.nodeValue);
      if (segments.length === 1 && !segments[0].isToken) continue;
      const frag = document.createDocumentFragment();
      for (const seg of segments) {
        if (seg.isToken) {
          const span = document.createElement('span');
          span.className = 'amgi-tok';
          span.setAttribute('data-token', seg.text);
          span.textContent = seg.text;
          frag.appendChild(span);
        } else {
          frag.appendChild(document.createTextNode(seg.text));
        }
      }
      textNode.parentNode.replaceChild(frag, textNode);
    }
  }

  function sentenceAround(span) {
    const TERMINATORS = /[.!?。！？\n]/;
    const text = (span.closest('p, li, div, section, body') || document.body).innerText || '';
    const tokenText = span.textContent || '';
    const idx = text.indexOf(tokenText);
    if (idx < 0) return tokenText;

    let start = idx;
    while (start > 0 && !TERMINATORS.test(text[start - 1])) {
      start--;
      if (idx - start > 300) break;
    }
    let end = idx + tokenText.length;
    while (end < text.length && !TERMINATORS.test(text[end])) {
      end++;
      if (end - idx > 300) break;
    }
    return text.substring(start, end + 1).trim();
  }

  // Ensures a viewport meta tag is present so WKWebView uses
  // device-width as the CSS viewport. Without this, .mobile content mode
  // defaults to a ~980px viewport which breaks our column-width math
  // (we'd get 2+ columns per physical page).
  function ensureViewportMeta() {
    var meta = document.querySelector('meta[name="viewport"][data-amgi="reader"]');
    if (meta) return;
    meta = document.createElement('meta');
    meta.setAttribute('name', 'viewport');
    meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
    meta.setAttribute('data-amgi', 'reader');
    var head = document.head || document.documentElement;
    head.insertBefore(meta, head.firstChild);
  }

  // JS owns --page-width / --page-height. Reading from window directly
  // means we always agree with the CSS viewport the browser is using,
  // regardless of what Swift thinks the scrollView bounds are.
  function syncPageVars() {
    var r = document.documentElement;
    var w = window.innerWidth || r.clientWidth || 0;
    var h = window.innerHeight || r.clientHeight || 0;
    if (w > 0) r.style.setProperty('--page-width', w + 'px');
    if (h > 0) r.style.setProperty('--page-height', h + 'px');
  }

  // <html> is the scroll container after the CSS rebuild — read scroll
  // offsets and widths from documentElement, not window.
  function measurePages() {
    const w = window.innerWidth || document.documentElement.clientWidth || 1;
    const scrollW = document.documentElement.scrollWidth || w;
    return Math.max(1, Math.ceil(scrollW / w));
  }

  function reportPageInfo() {
    const w = window.innerWidth || document.documentElement.clientWidth || 1;
    const pageCount = measurePages();
    const scrollLeft = document.documentElement.scrollLeft || 0;
    const pageIndex = Math.round(scrollLeft / w);
    try {
      window.webkit.messageHandlers.pageInfo.postMessage({
        pageIndex: pageIndex,
        pageCount: pageCount
      });
    } catch (e) { /* host detached */ }
    return { pageIndex, pageCount };
  }

  let progressTimer = null;
  // Emits progress only. UIScrollView is the single source of truth for
  // pageIndex / pageCount during a swipe; emitting pageInfo from here too
  // causes the host page counter to flicker (1 → 4 → 2) mid-gesture.
  function reportProgress() {
    if (progressTimer) clearTimeout(progressTimer);
    progressTimer = setTimeout(function () {
      const w = window.innerWidth || document.documentElement.clientWidth || 1;
      const pageCount = measurePages();
      const scrollLeft = document.documentElement.scrollLeft || 0;
      const pageIndex = Math.round(scrollLeft / w);
      const denom = Math.max(1, pageCount - 1);
      const fraction = Math.min(1, Math.max(0, pageIndex / denom));
      try {
        window.webkit.messageHandlers.progress.postMessage({
          pageIndex: pageIndex,
          pageCount: pageCount,
          progressFraction: fraction
        });
      } catch (e) { /* host detached */ }
    }, 250);
  }

  function installTapHandler() {
    document.addEventListener('click', function (e) {
      const target = e.target;
      if (!target || !target.classList || !target.classList.contains('amgi-tok')) return;
      const token = target.getAttribute('data-token') || target.textContent || '';
      const sentence = sentenceAround(target);
      try {
        window.webkit.messageHandlers.wordTap.postMessage({
          token: token,
          sentence: sentence
        });
      } catch (e) { /* host detached */ }
    }, true);
  }

  function installScrollHandler() {
    // <html> is the scroll container; document-level scroll fires for it.
    document.addEventListener('scroll', reportProgress, { passive: true });
    window.addEventListener('scroll', reportProgress, { passive: true });
  }

  function boot() {
    ensureViewportMeta();
    syncPageVars();
    try { tokenise(document.body); } catch (e) { /* ignore */ }
    installTapHandler();
    installScrollHandler();
    window.addEventListener('resize', function () {
      ensureViewportMeta();
      syncPageVars();
    });
    // Allow layout to settle before measuring; columns aren't laid out
    // synchronously on first paint in some EPUBs.
    setTimeout(reportPageInfo, 50);
    setTimeout(reportPageInfo, 300);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot, { once: true });
  } else {
    boot();
  }

  // Host-callable API for restoring a saved progress position.
  window.__amgiScrollToFraction = function (fraction) {
    const w = window.innerWidth || document.documentElement.clientWidth || 1;
    const scrollW = document.documentElement.scrollWidth || w;
    const target = Math.max(0, Math.min(scrollW - w, Math.round(scrollW * fraction)));
    const pageIndex = Math.round(target / w);
    document.documentElement.scrollLeft = pageIndex * w;
    reportPageInfo();
  };

  window.__amgiScrollToPage = function (pageIndex) {
    const w = window.innerWidth || document.documentElement.clientWidth || 1;
    document.documentElement.scrollLeft = pageIndex * w;
    reportPageInfo();
  };

  // Host-callable: re-measure column layout after the viewport has been
  // resized or CSS custom properties have changed. Returns the freshly
  // computed page count so Swift can re-snap synchronously after the
  // evaluateJavaScript callback fires.
  window.__amgiRelayout = function () {
    ensureViewportMeta();
    syncPageVars();
    var pageCount = 1;
    try { pageCount = measurePages(); } catch (e) { /* ignore */ }
    reportPageInfo();
    return pageCount;
  };
})();
