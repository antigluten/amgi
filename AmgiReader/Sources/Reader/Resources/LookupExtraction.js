// LookupExtraction.js
//
// The tap-to-lookup extractor shared by every Amgi web view that offers
// dictionary lookup (the EPUB reader, the reviewer card). Injected as a
// WKUserScript; callers read the tap coordinates off a click event and post
// the payload to their own message handler.
//
// The dictionary engine anchors at the START of the query and tries
// progressively shorter prefixes, so the text handed to it must begin at the
// tapped character and run forward from there. Scripts with delimited words
// (Latin, Cyrillic, Hangul) are the exception: a tap mid-word expands back to
// the word start, because "uick" matches nothing.
//
//   window.amgiLookup.payloadAt(x, y, scanLength)
//       -> { text, sentence, x, y } | null
//   window.amgiLookup.highlightMatched(utf16Length)
//       CSS Custom Highlight over the first N UTF-16 units of the last
//       extraction — the span the engine actually matched.
//   window.amgiLookup.clearHighlight()
//   window.amgiLookup.isWordChar(character)
//       -> true for a delimited-script word character (the WORD_CHAR test),
//       shared so other injected scripts don't keep their own copy.
(function () {
  'use strict';

  var DELIMITERS = ' \t\n\r　。、！？…‥「」『』（）()【】〈〉《》〔〕｛｝{}［］[]・：；:;，,.─';
  var SENTENCE_TERMINATORS = '。！？.!?\n';
  var SENTENCE_LIMIT = 300;
  var HIGHLIGHT_NAME = 'amgi-lookup';
  var WORD_CHAR = /[A-Za-z0-9_À-ɏЀ-ӿ가-힯ᄀ-ᇿ]/;

  // Items of the last extraction ({ node, offset, character, length }), one per
  // code point, kept so a later highlightMatched() can build a Range over
  // exactly those characters. `length` is the item's UTF-16 unit count.
  var lastItems = null;

  function isExcluded(node) {
    var element = node && node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
    return !!(element && element.closest('rt, rp, script, style, noscript'));
  }

  function containerFor(node) {
    var element = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
    return (element && element.closest('p, li, div, section, article, td, th, blockquote')) || document.body;
  }

  function textWalker(root) {
    return document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        return isExcluded(node) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
      }
    });
  }

  function pointInRange(range, x, y) {
    var rects = range.getClientRects ? Array.from(range.getClientRects()) : [];
    if (!rects.length) rects = [range.getBoundingClientRect()];
    return rects.some(function (rect) {
      return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom;
    });
  }

  function caretRangeAt(x, y) {
    if (document.caretRangeFromPoint) return document.caretRangeFromPoint(x, y);
    if (document.caretPositionFromPoint) {
      var position = document.caretPositionFromPoint(x, y);
      if (!position) return null;
      var range = document.createRange();
      range.setStart(position.offsetNode, position.offset);
      return range;
    }
    return null;
  }

  function codePointLength(text, offset) {
    return text.codePointAt(offset) > 0xFFFF ? 2 : 1;
  }

  // An offset can land on the trailing half of a surrogate pair; the character
  // it belongs to starts one unit back.
  function snapToLead(text, offset) {
    var code = text.charCodeAt(offset);
    return code >= 0xDC00 && code <= 0xDFFF && offset > 0 ? offset - 1 : offset;
  }

  // The caret lands on a boundary between characters; the tapped character
  // is the one whose box contains the point, on either side of the caret.
  function characterAtPoint(x, y) {
    var range = caretRangeAt(x, y);
    var node = range && range.startContainer;
    if (!node || node.nodeType !== Node.TEXT_NODE || isExcluded(node)) return null;

    var text = node.textContent || '';
    var offsets = [range.startOffset, range.startOffset - 1, range.startOffset + 1];
    for (var i = 0; i < offsets.length; i++) {
      if (offsets[i] < 0 || offsets[i] >= text.length) continue;
      var offset = snapToLead(text, offsets[i]);
      var charRange = document.createRange();
      charRange.setStart(node, offset);
      charRange.setEnd(node, offset + codePointLength(text, offset));
      if (pointInRange(charRange, x, y)) return { node: node, offset: offset };
    }
    return null;
  }

  function codePointItems(node, text, from, to) {
    var items = [];
    var offset = from;
    while (offset < to) {
      var length = codePointLength(text, offset);
      items.push({ node: node, offset: offset, character: text.substr(offset, length), length: length });
      offset += length;
    }
    return items;
  }

  // The code points around the hit, at most SENTENCE_LIMIT UTF-16 units either
  // side, walking into neighbouring text nodes only while that budget lasts.
  // Bounds a tap to ~600 units however large the enclosing block is.
  function windowAround(hit) {
    var text = hit.node.textContent || '';
    var from = snapToLead(text, Math.max(0, hit.offset - SENTENCE_LIMIT));
    var to = Math.min(text.length, hit.offset + SENTENCE_LIMIT);
    var before = codePointItems(hit.node, text, from, hit.offset);
    var after = codePointItems(hit.node, text, hit.offset, to);
    var backBudget = SENTENCE_LIMIT - (hit.offset - from);
    var forwardBudget = SENTENCE_LIMIT - (to - hit.offset);

    var walker = textWalker(containerFor(hit.node));
    var node;
    var content;
    walker.currentNode = hit.node;
    while (backBudget > 0 && (node = walker.previousNode())) {
      content = node.textContent || '';
      var start = snapToLead(content, Math.max(0, content.length - backBudget));
      before = codePointItems(node, content, start, content.length).concat(before);
      backBudget -= content.length - start;
    }
    walker.currentNode = hit.node;
    while (forwardBudget > 0 && (node = walker.nextNode())) {
      content = node.textContent || '';
      var end = Math.min(content.length, forwardBudget);
      after = after.concat(codePointItems(node, content, 0, end));
      forwardBudget -= end;
    }
    return { items: before.concat(after), hitIndex: before.length };
  }

  function isWordChar(character) {
    return WORD_CHAR.test(character || '');
  }

  function isDelimiter(character) {
    return DELIMITERS.indexOf(character) !== -1;
  }

  // Delimited-script word: expand back to the word start, then forward.
  function wordSpanAt(items, hitIndex, maxLength) {
    var start = hitIndex;
    var end = hitIndex;
    while (start > 0 && end - start + 2 <= maxLength && isWordChar(items[start - 1].character)) start--;
    while (end + 1 < items.length && end - start + 2 <= maxLength && isWordChar(items[end + 1].character)) end++;
    return { start: start, end: end };
  }

  // Everything else: forward from the tapped character to a delimiter.
  function forwardSpanAt(items, hitIndex, maxLength) {
    var end = hitIndex;
    while (end + 1 < items.length && end - hitIndex + 2 <= maxLength && !isDelimiter(items[end + 1].character)) end++;
    return { start: hitIndex, end: end };
  }

  function sentenceAt(items, hitIndex) {
    var start = hitIndex;
    while (start > 0 && hitIndex - start < SENTENCE_LIMIT && SENTENCE_TERMINATORS.indexOf(items[start - 1].character) === -1) start--;
    var end = hitIndex;
    while (end < items.length - 1 && end - hitIndex < SENTENCE_LIMIT && SENTENCE_TERMINATORS.indexOf(items[end].character) === -1) end++;
    return items.slice(start, end + 1).map(function (item) { return item.character; }).join('').trim();
  }

  function payloadAt(x, y, scanLength) {
    var hit = characterAtPoint(x, y);
    if (!hit) return null;

    var maxLength = Math.max(1, scanLength || 16);
    var view = windowAround(hit);
    var items = view.items;
    var hitIndex = view.hitIndex;

    var character = items[hitIndex].character;
    if (isDelimiter(character)) return null;

    var span = isWordChar(character)
      ? wordSpanAt(items, hitIndex, maxLength)
      : forwardSpanAt(items, hitIndex, maxLength);
    var selected = items.slice(span.start, span.end + 1);
    var text = selected.map(function (item) { return item.character; }).join('').trim();
    if (!text) return null;

    lastItems = selected;
    return { text: text, sentence: sentenceAt(items, hitIndex), x: x, y: y };
  }

  function highlightsSupported() {
    return !!(window.CSS && CSS.highlights && typeof Highlight === 'function');
  }

  function ensureHighlightStyle() {
    if (document.getElementById('amgi-lookup-highlight-style')) return;
    var style = document.createElement('style');
    style.id = 'amgi-lookup-highlight-style';
    style.textContent = '::highlight(' + HIGHLIGHT_NAME + ') { background-color: rgba(255, 204, 0, 0.45); }';
    (document.head || document.documentElement).appendChild(style);
  }

  function clearHighlight() {
    if (highlightsSupported()) CSS.highlights.delete(HIGHLIGHT_NAME);
  }

  function highlightMatched(utf16Length) {
    clearHighlight();
    if (!lastItems || !highlightsSupported()) return;
    var target = Math.max(0, utf16Length | 0);
    var count = 0;
    var units = 0;
    while (count < lastItems.length && units < target) {
      units += lastItems[count].length;
      count++;
    }
    if (!count) return;
    var first = lastItems[0];
    var last = lastItems[count - 1];
    var range = document.createRange();
    range.setStart(first.node, first.offset);
    range.setEnd(last.node, last.offset + last.length);
    ensureHighlightStyle();
    CSS.highlights.set(HIGHLIGHT_NAME, new Highlight(range));
  }

  window.amgiLookup = {
    payloadAt: payloadAt,
    highlightMatched: highlightMatched,
    clearHighlight: clearHighlight,
    isWordChar: isWordChar
  };
})();
