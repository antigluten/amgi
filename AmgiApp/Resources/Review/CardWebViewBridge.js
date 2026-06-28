<!DOCTYPE html>
<html class="__AMGI_HTML_CLASS__" data-bs-theme="__AMGI_COLOR_SCHEME__">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
__AMGI_BASE_TAG__
<style>
    :root {
        color-scheme: __AMGI_COLOR_SCHEME__;
        --amgi-default-card-bg: __AMGI_DEFAULT_CARD_BG__;
        --amgi-default-card-fg: __AMGI_TEXT_COLOR__;
    }
    html, body {
        background: transparent;
        overflow-x: hidden;
        -webkit-text-size-adjust: 100%;
        text-size-adjust: 100%;
    }
    body {
        font-family: -apple-system, system-ui;
        font-size: 18px; line-height: 1.5;
        color: var(--amgi-default-card-fg); background: var(--amgi-default-card-bg);
        padding: 0 0 var(--amgi-body-padding-bottom, 16px);
        margin: 20px; min-height: calc(100vh - 40px); box-sizing: border-box; text-align: center;
        overflow-wrap: break-word;
        background-size: cover;
        background-repeat: no-repeat;
        background-position: top;
        background-attachment: fixed;
    }
    body.amgi-centered { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 40px); }
    .card-frame {
        width: 100%; box-sizing: border-box;
        padding-bottom: var(--amgi-card-padding-bottom, 0px);
    }
    hr { border: none; border-top: 1px solid __AMGI_HR_COLOR__; margin: 16px 0; }
    ruby {
        ruby-position: over;
        line-height: normal;
    }
    ruby rt {
        font-size: 0.58em;
        line-height: 1;
    }
    img { max-width: 100%; max-height: 95vh; height: auto; border-radius: 8px; }
    li { text-align: start; }
    pre { text-align: left; }
    .sound-btn { display: inline-flex; align-items: center; justify-content: center; margin: 4px; }
    .sound-btn audio { display: none; }
    #typeans {
        width: 100%; box-sizing: border-box; line-height: 1.75;
        padding: 10px 12px; border-radius: 10px;
        border: 1px solid __AMGI_TYPE_BORDER_COLOR__; background: __AMGI_TYPE_BG_COLOR__;
        color: inherit; outline: none;
    }
    #typeans:focus {
        border-color: __AMGI_TYPE_FOCUS_BORDER__;
        box-shadow: 0 0 0 3px __AMGI_TYPE_FOCUS_SHADOW__;
    }
    code#typeans {
        display: inline-block; white-space: pre-wrap;
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        font-size: 0.95em; line-height: 1.75; padding: 10px 12px;
        font-variant-ligatures: none;
        border-radius: 10px; background: __AMGI_TYPE_CODE_BG__;
    }
    .typeGood { background: #afa; color: black; }
    .typeBad { color: black; background: #faa; }
    .typeMissed { color: black; background: #ccc; }
    #typearrow { opacity: 0.7; }
    .replay-button {
        text-decoration: none; display: inline-flex; vertical-align: middle; margin: 3px;
    }
    .replay-btn {
        background: transparent; border: none; color: inherit; padding: 0;
        line-height: 0; cursor: pointer; display: inline-flex;
        align-items: center; justify-content: center;
        flex: 0 0 auto; min-width: 40px; min-height: 40px;
        box-shadow: none; outline: none;
        -webkit-tap-highlight-color: transparent; appearance: none;
    }
    .replay-btn:active { opacity: 0.7; }
    .replay-btn .amgi-inline-icon {
        width: 28px; height: 28px; display: block;
        max-width: none; max-height: none;
        margin: 0; padding: 0;
        border: 0 !important; border-radius: 0 !important;
        background: transparent !important; box-shadow: none !important;
        object-fit: contain;
    }
    video { max-width: 100%; height: auto; border-radius: 8px; margin: 8px 0; }
    .drawing { zoom: 50%; }
    .cloze:not([data-shape]) { display: inline !important; font-weight: 600; color: #1565c0; }
    .cloze-inactive:not([data-shape]),
    .cloze-highlight:not([data-shape]) { display: inline !important; }
    .cloze[data-shape], .cloze-inactive[data-shape], .cloze-highlight[data-shape] { display: none; }
    #image-occlusion-container { position: relative; display: inline-block; line-height: 0; }
    #image-occlusion-canvas {
        position: absolute; top: 0; left: 0;
        pointer-events: auto; cursor: pointer; border-radius: 8px;
    }
    .missing-media {
        display: inline-block; background: rgba(255,60,60,0.15);
        border: 1px dashed rgba(255,60,60,0.5); border-radius: 6px;
        padding: 6px 10px; margin: 4px; font-size: 13px;
        color: __AMGI_MISSING_MEDIA_COLOR__;
    }
    body.nightMode,
    body.night_mode,
    .nightMode.card,
    .night_mode.card,
    .nightMode .card,
    .night_mode .card {
        color: #f5f5f5;
        background-color: #111111;
    }
    .nightMode .latex, .night_mode .latex { filter: invert(100%); }
    .nightMode img.drawing, .night_mode img.drawing { filter: invert(1) hue-rotate(180deg); }
    .nightMode .cloze:not([data-shape]) { color: #8fb8ff; }
    .night_mode .cloze:not([data-shape]) { color: #8fb8ff; }
    .nightMode a, .nightMode a:visited, .nightMode a:active { color: #8fb8ff; }
    .night_mode a, .night_mode a:visited, .night_mode a:active { color: #8fb8ff; }
</style>
<style id="amgi-card-css"></style>
<script>
// ── Globals ──────────────────────────────────────────────────────────
var PLAY_ICON_HTML = __AMGI_PLAY_ICON_LITERAL__;
var PAUSE_ICON_HTML = __AMGI_PAUSE_ICON_LITERAL__;
var MATHJAX_CONFIG_SCRIPT_URL = __AMGI_MATHJAX_CONFIG_URL__;
var MATHJAX_CORE_SCRIPT_URL = __AMGI_MATHJAX_CORE_URL__;
window.__amgiAudioPlaying = false;
window.onUpdateHook = [];
window.onShownHook = [];
window.__amgiUpdateQueue = Promise.resolve();
window.__amgiMathJaxLoadPromise = null;
var amgiPreloadTemplate = document.createElement('template');
var amgiPreloadDoc = document.implementation.createHTMLDocument('');
var amgiFontURLPattern = /url\s*\(\s*(["']?)(\S.*?)\1\s*\)/g;
var amgiCachedFonts = new Set();

// ── Card state ──────────────────────────────────────────────────────
window.__amgiCardState = {};

function amgiCardState() { return window.__amgiCardState || {}; }
function amgiAutoplayEnabled() { return !!(amgiCardState().autoplayEnabled); }
function amgiIsAnswerSide() { return !!(amgiCardState().isAnswerSide); }
function amgiLookupPopupEnabled() { return !!(amgiCardState().lookupPopupEnabled); }
function amgiReplayModeValue() { return amgiCardState().replayMode || 'question'; }
function amgiPrefetchHTMLValue() { return amgiCardState().prefetchHTML || ''; }
function amgiIsLookupFuriganaNode(node) {
    var element = node && node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
    return !!(element && element.closest('rt, rp'));
}
function amgiLookupContainerForNode(node) {
    var element = node && node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
    return (element && element.closest('p, li, div, section, article, td, th')) || document.getElementById('qa') || document.body;
}
function amgiLookupTextWalker(root) {
    return document.createTreeWalker(root || document.body, NodeFilter.SHOW_TEXT, {
        acceptNode: function(node) {
            return amgiIsLookupFuriganaNode(node) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
        }
    });
}
function amgiPointInRange(range, x, y) {
    var rects = range.getClientRects ? Array.from(range.getClientRects()) : [];
    if (!rects.length) rects = [range.getBoundingClientRect()];
    return rects.some(function(rect) {
        return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom;
    });
}
function amgiLookupCharacterAtPoint(x, y) {
    var range = document.caretRangeFromPoint ? document.caretRangeFromPoint(x, y) : null;
    if (!range && document.caretPositionFromPoint) {
        var position = document.caretPositionFromPoint(x, y);
        if (position) {
            range = document.createRange();
            range.setStart(position.offsetNode, position.offset);
        }
    }
    var node = range && range.startContainer;
    if (!node || node.nodeType !== Node.TEXT_NODE || amgiIsLookupFuriganaNode(node)) return null;

    var text = node.textContent || '';
    for (var i = 0, offsets = [range.startOffset, range.startOffset - 1, range.startOffset + 1]; i < offsets.length; i++) {
        var offset = offsets[i];
        if (offset < 0 || offset >= text.length) continue;
        var charRange = document.createRange();
        charRange.setStart(node, offset);
        charRange.setEnd(node, offset + 1);
        if (amgiPointInRange(charRange, x, y)) {
            return { node: node, offset: offset };
        }
    }
    return null;
}
function amgiLookupNodesInContainer(root, hitNode) {
    var walker = amgiLookupTextWalker(root);
    var nodes = [];
    var hitIndex = -1;
    var node;
    while (node = walker.nextNode()) {
        if (node === hitNode) hitIndex = nodes.length;
        nodes.push(node);
    }
    return { nodes: nodes, hitIndex: hitIndex };
}
function amgiIsLatinLookupChar(character) {
    return /^[A-Za-z0-9]$/.test(character || '');
}
function amgiFlattenedLookupItems(root) {
    var walker = amgiLookupTextWalker(root);
    var items = [];
    var node;
    while (node = walker.nextNode()) {
        var content = node.textContent || '';
        for (var index = 0; index < content.length; index++) {
            items.push({ node: node, offset: index, character: content[index] });
        }
    }
    return items;
}
function amgiLatinWordPayloadAt(nodeInfo, hit, maxLength) {
    var items = amgiFlattenedLookupItems(amgiLookupContainerForNode(hit.node));
    var hitIndex = -1;
    for (var i = 0; i < items.length; i++) {
        if (items[i].node === hit.node && items[i].offset === hit.offset) {
            hitIndex = i;
            break;
        }
    }
    if (hitIndex < 0) return '';

    var start = hitIndex;
    var end = hitIndex;
    while (start > 0 && end - (start - 1) + 1 <= maxLength && amgiIsLatinLookupChar(items[start - 1].character)) {
        start--;
    }
    while (end + 1 < items.length && (end + 1) - start + 1 <= maxLength && amgiIsLatinLookupChar(items[end + 1].character)) {
        end++;
    }

    return items.slice(start, end + 1).map(function(item) { return item.character; }).join('').trim();
}
function amgiLookupRangeRect(node, start, end) {
    var range = document.createRange();
    range.setStart(node, start);
    range.setEnd(node, end);
    var rects = range.getClientRects ? Array.from(range.getClientRects()).filter(function(rect) {
        return rect.width > 0 && rect.height > 0;
    }) : [];
    return rects[0] || null;
}
function amgiSameVisualLine(rect, reference) {
    var rectMidY = rect.top + rect.height / 2;
    var referenceMidY = reference.top + reference.height / 2;
    return Math.abs(rectMidY - referenceMidY) <= Math.max(rect.height, reference.height) * 0.65;
}
function amgiVisualLatinWordPayloadAt(nodeInfo, hit, maxLength) {
    var chars = [];

    for (var nodeIndex = 0; nodeIndex < nodeInfo.nodes.length; nodeIndex++) {
        var node = nodeInfo.nodes[nodeIndex];
        var content = node.textContent || '';
        for (var index = 0; index < content.length; index++) {
            var character = content[index];
            if (!amgiIsLatinLookupChar(character)) continue;
            var rect = amgiLookupRangeRect(node, index, index + 1);
            if (!rect) continue;
            chars.push({ node: node, offset: index, character: character, rect: rect });
        }
    }

    var hitIndex = -1;
    for (var i = 0; i < chars.length; i++) {
        if (chars[i].node === hit.node && chars[i].offset === hit.offset) {
            hitIndex = i;
            break;
        }
    }
    if (hitIndex < 0) return '';

    var reference = chars[hitIndex].rect;
    var maxGap = Math.max(6, Math.min(18, reference.width * 1.4));
    var start = hitIndex;
    var end = hitIndex;

    for (var beforeIndex = hitIndex - 1; beforeIndex >= 0 && end - beforeIndex + 1 <= maxLength; beforeIndex--) {
        var currentBefore = chars[beforeIndex];
        var next = chars[beforeIndex + 1];
        if (!amgiSameVisualLine(currentBefore.rect, reference)) break;
        if (next.rect.left - currentBefore.rect.right > maxGap) break;
        start = beforeIndex;
    }

    for (var afterIndex = hitIndex + 1; afterIndex < chars.length && afterIndex - start + 1 <= maxLength; afterIndex++) {
        var currentAfter = chars[afterIndex];
        var previous = chars[afterIndex - 1];
        if (!amgiSameVisualLine(currentAfter.rect, reference)) break;
        if (currentAfter.rect.left - previous.rect.right > maxGap) break;
        end = afterIndex;
    }

    return chars.slice(start, end + 1).map(function(item) { return item.character; }).join('');
}
function amgiForwardLookupTextAt(nodeInfo, hit, maxLength, delimiters) {
    var selected = '';

    for (var forwardIndex = nodeInfo.hitIndex; forwardIndex < nodeInfo.nodes.length && selected.length < maxLength; forwardIndex++) {
        var forwardText = nodeInfo.nodes[forwardIndex].textContent || '';
        var forwardOffset = forwardIndex === nodeInfo.hitIndex ? hit.offset : 0;
        for (var f = forwardOffset; f < forwardText.length && selected.length < maxLength; f++) {
            var forwardChar = forwardText[f];
            if (delimiters.indexOf(forwardChar) !== -1) {
                forwardIndex = nodeInfo.nodes.length;
                break;
            }
            selected += forwardChar;
        }
    }

    return selected.trim();
}

function amgiApplyCardState(state) {
    window.__amgiCardState = Object.assign({}, window.__amgiCardState || {}, state || {});
    var s = amgiCardState();
    var qa = document.getElementById('qa');
    document.body.className = s.bodyClass || document.body.className;
    document.body.style.setProperty('--amgi-body-padding-bottom', (s.bodyPaddingBottom || 16) + 'px');
    document.body.classList.toggle('amgi-centered', !s.alignTop);
    if (qa) qa.style.setProperty('--amgi-card-padding-bottom', (s.cardPaddingBottom || 0) + 'px');
}

// ===== Lookup (text selection → amgiLookupText) =====
function amgiCardLookupPayloadAt(x, y, scanLength) {
    if (!amgiLookupPopupEnabled()) return null;
    var target = document.elementFromPoint(x, y);
    if (!target) return null;
    if (target.closest('a, button, input, textarea, select, option, [contenteditable], .replay-button, .replay-btn, .sound-btn, #image-occlusion-canvas')) {
        return null;
    }
    if (target.closest('rt, rp')) return null;

    var hit = amgiLookupCharacterAtPoint(x, y);
    if (!hit) return null;

    var maxLength = Math.max(1, scanLength || 16);
    var delimiters = ' \t\n\r。、！？…‥「」『』（）()【】〈〉《》〔〕｛｝{}［］[]・：；:;，,.─';
    var container = amgiLookupContainerForNode(hit.node);
    var nodeInfo = amgiLookupNodesInContainer(container, hit.node);
    if (nodeInfo.hitIndex < 0) return null;

    var hitText = hit.node.textContent || '';
    var hitChar = hitText[hit.offset] || '';
    var selected = amgiIsLatinLookupChar(hitChar)
        ? amgiLatinWordPayloadAt(nodeInfo, hit, maxLength)
        : amgiForwardLookupTextAt(nodeInfo, hit, maxLength, delimiters);
    if (amgiIsLatinLookupChar(hitChar) && selected.length === 1) {
        var bodyNodeInfo = amgiLookupNodesInContainer(document.body, hit.node);
        selected = amgiVisualLatinWordPayloadAt(nodeInfo, hit, maxLength)
            || (bodyNodeInfo.hitIndex >= 0 ? amgiVisualLatinWordPayloadAt(bodyNodeInfo, hit, maxLength) : '')
            || selected;
    }
    if (!selected) return null;
    return {
        text: selected,
        sentence: (container.textContent || '').trim(),
        x: x,
        y: y
    };
}

document.addEventListener('click', function(event) {
    var state = amgiCardState();
    if (state.renderedAt && Date.now() - state.renderedAt < 300) return;
    var payload = amgiCardLookupPayloadAt(event.clientX, event.clientY, 16);
    if (!payload) return;
    window.webkit.messageHandlers.amgiLookupText.postMessage(payload);
}, false);

function amgiSetCardCSS(cssText) {
    var style = document.getElementById('amgi-card-css');
    if (!style) return;
    var next = cssText || '';
    if (style.textContent === next) return;
    style.textContent = next;
}

// ── Resource preloading ──────────────────────────────────────────────
function amgiLoadPreloadResource(element) {
    return new Promise(function(resolve) {
        function finish() { resolve(); if (element.parentNode) element.parentNode.removeChild(element); }
        element.addEventListener('load', finish);
        element.addEventListener('error', finish);
        document.head.appendChild(element);
    });
}
function amgiCreatePreloadLink(href, asType) {
    var link = document.createElement('link');
    link.rel = 'preload'; link.href = href; link.as = asType;
    if (asType === 'font') link.crossOrigin = '';
    return link;
}
function amgiPreloadImage(img) {
    if (!img.getAttribute('decoding')) img.decoding = 'async';
    return img.complete ? Promise.resolve() : new Promise(function(resolve) {
        img.addEventListener('load', function() { resolve(); });
        img.addEventListener('error', function() { resolve(); });
    });
}
function amgiPreloadImages(fragment) {
    return Array.from(fragment.querySelectorAll('img[src]')).map(function(existing) {
        try {
            var img = new Image();
            img.src = new URL(existing.getAttribute('src') || '', document.baseURI).toString();
            return amgiPreloadImage(img);
        } catch(e) { return Promise.resolve(); }
    });
}
function amgiAllImagesLoaded() {
    return Promise.all(Array.from(document.getElementsByTagName('img')).map(amgiPreloadImage));
}
function amgiPreloadStyleSheets(fragment) {
    return Array.from(fragment.querySelectorAll('style, link')).filter(function(css) {
        return (css.tagName === 'STYLE' && (css.innerHTML || '').includes('@import'))
            || (css.tagName === 'LINK' && css.rel === 'stylesheet');
    }).map(function(css) { css.media = 'print'; return amgiLoadPreloadResource(css); });
}
function amgiExtractFontURLs(style) {
    amgiPreloadDoc.head.innerHTML = '';
    amgiPreloadDoc.head.appendChild(style);
    var urls = [];
    try {
        if (style.sheet) {
            Array.from(style.sheet.cssRules || []).forEach(function(rule) {
                if (typeof CSSFontFaceRule !== 'undefined' && rule instanceof CSSFontFaceRule) {
                    var src = rule.style.getPropertyValue('src');
                    var matches = src.matchAll(amgiFontURLPattern);
                    for (var m of matches) { if (m[2]) urls.push(m[2]); }
                }
            });
        }
    } catch(e) {}
    return urls;
}
function amgiPreloadFonts(fragment) {
    var fontURLs = [];
    Array.from(fragment.querySelectorAll('style')).forEach(function(s) {
        fontURLs.push.apply(fontURLs, amgiExtractFontURLs(s));
    });
    return fontURLs.filter(function(url) {
        if (!url || amgiCachedFonts.has(url)) return false;
        amgiCachedFonts.add(url);
        return true;
    }).map(function(url) { return amgiLoadPreloadResource(amgiCreatePreloadLink(url, 'font')); });
}
async function amgiPreloadResources(html) {
    try {
        amgiPreloadTemplate.innerHTML = html || '';
        var fragment = amgiPreloadTemplate.content;
        var styleSheets = amgiPreloadStyleSheets(fragment.cloneNode(true));
        var images = amgiPreloadImages(fragment.cloneNode(true));
        var fonts = amgiPreloadFonts(fragment.cloneNode(true));
        var timeout = fonts.length ? 800 : styleSheets.length ? 500 : images.length ? 200 : 0;
        if (!timeout) return;
        await Promise.race([
            Promise.all(styleSheets.concat(images, fonts)),
            new Promise(function(resolve) { window.setTimeout(resolve, timeout); })
        ]);
    } catch(e) { console.error('Preload failed', e); }
}

// ===== MathJax loader =====
function amgiTrimMathJaxText(text) {
    return (text || '')
        .replace(/<br[ ]*\/?>/gi, '\n')
        .replace(/^\n*/, '')
        .replace(/\n*$/, '');
}

function amgiNormalizeMathJaxMarkup(html) {
    return (html || '').replace(
        /<anki-mathjax(?:[^>]*?block="(.*?)")?[^>]*?>([\s\S]*?)<\/anki-mathjax>/gi,
        function(_match, block, text) {
            var trimmed = amgiTrimMathJaxText(text);
            return (typeof block === 'string' && block !== 'false')
                ? '\\[' + trimmed + '\\]'
                : '\\(' + trimmed + '\\)';
        }
    );
}

function amgiContainsMathJaxMarkup(html) {
    var source = html || '';
    return source.includes('\\(') || source.includes('\\[');
}

function amgiLoadMathJaxScript(kind, src) {
    return new Promise(function(resolve) {
        var existing = document.querySelector('script[data-amgi-mathjax="' + kind + '"]');
        if (existing) {
            if (existing.dataset.amgiLoaded === '1') {
                resolve();
                return;
            }
            existing.addEventListener('load', function() {
                existing.dataset.amgiLoaded = '1';
                resolve();
            }, { once: true });
            existing.addEventListener('error', function() {
                resolve();
            }, { once: true });
            return;
        }

        var script = document.createElement('script');
        script.src = src;
        script.async = false;
        script.setAttribute('data-amgi-mathjax', kind);
        script.addEventListener('load', function() {
            script.dataset.amgiLoaded = '1';
            resolve();
        }, { once: true });
        script.addEventListener('error', function() {
            resolve();
        }, { once: true });
        document.head.appendChild(script);
    });
}

async function amgiWaitForMathJax(timeout) {
    var deadline = Date.now() + (timeout || 0);
    while (Date.now() <= deadline) {
        var mathJax = window.MathJax;
        if (mathJax
            && mathJax.startup
            && mathJax.startup.promise
            && typeof mathJax.typesetPromise === 'function') {
            try {
                await mathJax.startup.promise;
            } catch (error) {
                console.error('MathJax startup failed', error);
                return null;
            }
            return mathJax;
        }
        await new Promise(function(resolve) { window.setTimeout(resolve, 25); });
    }
    return null;
}

async function amgiEnsureMathJaxReady(timeout) {
    var readyMathJax = await amgiWaitForMathJax(0);
    if (readyMathJax) {
        return readyMathJax;
    }

    if (!window.__amgiMathJaxLoadPromise) {
        window.__amgiMathJaxLoadPromise = (async function() {
            await amgiLoadMathJaxScript('config', MATHJAX_CONFIG_SCRIPT_URL);
            await amgiLoadMathJaxScript('core', MATHJAX_CORE_SCRIPT_URL);
            return await amgiWaitForMathJax(timeout || 1500);
        })().catch(function(error) {
            console.error('MathJax load failed', error);
            window.__amgiMathJaxLoadPromise = null;
            return null;
        });
    }

    return await window.__amgiMathJaxLoadPromise;
}

// ── Hooks ────────────────────────────────────────────────────────────
function amgiRunHooks(hooks) {
    if (!Array.isArray(hooks)) return Promise.resolve([]);
    var promises = [];
    hooks.forEach(function(hook) {
        try { if (typeof hook === 'function') promises.push(hook()); }
        catch(e) { console.error('Hook failed', e); }
    });
    return Promise.allSettled(promises);
}

// ===== Theme color =====
// Read the visible card/template background first. Do not add an
// isDarkMode-only DOM background fallback before this function runs,
// or the reported chrome color will come from the wrapper instead of
// the card template itself.
function amgiResolveCardBackground() {
    var candidates = [
        document.querySelector('.card'),
        document.getElementById('qa'),
        document.body,
        document.documentElement,
    ];
    for (var i = 0; i < candidates.length; i++) {
        var el = candidates[i];
        if (!el) continue;
        var bg = window.getComputedStyle(el).backgroundColor;
        if (bg && bg !== 'transparent' && bg !== 'rgba(0, 0, 0, 0)') {
            return bg;
        }
    }
    return window.getComputedStyle(document.body).backgroundColor || 'rgba(0, 0, 0, 0)';
}

function amgiParseCssColor(color) {
    if (!color) return null;
    var rgba = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/i);
    if (!rgba) return null;
    return {
        r: parseInt(rgba[1], 10) || 0,
        g: parseInt(rgba[2], 10) || 0,
        b: parseInt(rgba[3], 10) || 0,
        a: rgba[4] == null ? 1 : (parseFloat(rgba[4]) || 0),
    };
}

function amgiReportCardTheme() {
    try {
        var bg = amgiResolveCardBackground();
        var parsed = amgiParseCssColor(bg);
        // Transparent cards have no explicit surface color to sample, so
        // keep the toolbar scheme aligned with the current page theme.
        var isDark = document.documentElement.getAttribute('data-bs-theme') === 'dark';
        if (parsed && parsed.a > 0) {
            var r = parsed.r || 0;
            var g = parsed.g || 0;
            var b = parsed.b || 0;
            var luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
            isDark = luminance < 0.55;
        }
        window.webkit.messageHandlers.amgiCardTheme.postMessage({
            backgroundColor: bg,
            isDark: isDark,
        });
    } catch(e) {
        console.error('Theme report failed', e);
    }
}

function amgiScheduleCardThemeReport() {
    amgiReportCardTheme();
    window.requestAnimationFrame(function() {
        amgiReportCardTheme();
    });
    window.setTimeout(function() {
        amgiReportCardTheme();
    }, 120);
    amgiAllImagesLoaded().then(function() {
        window.requestAnimationFrame(function() {
            amgiReportCardTheme();
        });
    });
}

// ── Script re-execution (mirrors upstream replaceScript) ─────────────
function amgiReplaceScript(oldScript) {
    return new Promise(function(resolve) {
        var newScript = document.createElement('script');
        var mustWaitForNetwork = !!oldScript.getAttribute('src');
        oldScript.getAttributeNames().forEach(function(name) {
            if (name === 'type' || name === 'data-amgi-card-script') return;
            var v = oldScript.getAttribute(name);
            if (v !== null) newScript.setAttribute(name, v);
        });
        newScript.addEventListener('load', function() { resolve(); });
        newScript.addEventListener('error', function() { resolve(); });
        newScript.appendChild(document.createTextNode(oldScript.textContent || ''));
        oldScript.replaceWith(newScript);
        if (!mustWaitForNetwork) resolve();
    });
}
function amgiClearDynamicHeadResources() {
    document.head.querySelectorAll('[data-amgi-card-head-resource="1"]').forEach(function(node) {
        node.remove();
    });
}
function amgiHoistDynamicHeadResources(element) {
    amgiClearDynamicHeadResources();
    Array.from(element.querySelectorAll('style, link[rel~="stylesheet"]')).forEach(function(resource) {
        var clone = resource.cloneNode(true);
        clone.setAttribute('data-amgi-card-head-resource', '1');
        document.head.appendChild(clone);
        resource.remove();
    });
}
async function amgiSetInnerHTML(element, html) {
    // Pause & drain video elements first (mirrors upstream setInnerHTML)
    Array.from(element.getElementsByTagName('video')).forEach(function(v) {
        v.pause();
        while (v.firstChild) v.removeChild(v.firstChild);
        v.load();
    });
    element.innerHTML = html;
    amgiHoistDynamicHeadResources(element);
    for (var script of Array.from(element.getElementsByTagName('script'))) {
        await amgiReplaceScript(script);
    }
}

// ===== Audio replay =====
function setAudioButtonState(btn, state) {
    if (!btn) return;
    btn.innerHTML = state === 'pause' ? PAUSE_ICON_HTML : PLAY_ICON_HTML;
}
function notifyAudioState(isPlaying) {
    window.__amgiAudioPlaying = !!isPlaying;
    try { window.webkit.messageHandlers.amgiAudioState.postMessage(window.__amgiAudioPlaying); } catch(e) {}
}
function amgiStopTts() {
    try { window.webkit.messageHandlers.amgiStopTts.postMessage(null); } catch(e) {}
}
window.amgiStopTts = amgiStopTts;
function stopAllSystemAudio() {
    amgiStopTts();
    document.querySelectorAll('.anki-sound-audio').forEach(function(a) {
        if (!a.paused) a.pause();
        a.currentTime = 0;
        setAudioButtonState(a.nextElementSibling, 'play');
        a.onended = null;
    });
    notifyAudioState(false);
}
window.amgiStopAllAudio = stopAllSystemAudio;
function collectAudioQueue(mode) {
    var all = Array.from(document.querySelectorAll('.anki-sound-audio'));
    if (mode === 'question') return all;
    var marker = document.getElementById('answer');
    if (!marker) return all;
    var after = all.filter(function(a) {
        return !!(marker.compareDocumentPosition(a) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    return after.length > 0 ? after : all;
}
function splitAudioQueue() {
    var all = Array.from(document.querySelectorAll('.anki-sound-audio'));
    var marker = document.getElementById('answer');
    if (!marker) return { question: all, answer: all };
    var answer = all.filter(function(a) {
        return !!(marker.compareDocumentPosition(a) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    var question = all.filter(function(a) {
        return !(marker.compareDocumentPosition(a) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    return {
        question: question.length ? question : all,
        answer: answer.length ? answer : all
    };
}
function replaySequential(queue) {
    stopAllSystemAudio();
    if (!queue || !queue.length) return;
    var idx = 0;
    notifyAudioState(true);
    function playNext() {
        if (idx >= queue.length) { notifyAudioState(false); return; }
        var audio = queue[idx];
        var btn = audio.nextElementSibling;
        audio.currentTime = 0;
        audio.play().catch(function() { idx++; playNext(); });
        setAudioButtonState(btn, 'pause');
        audio.onended = function() { setAudioButtonState(btn, 'play'); idx++; playNext(); };
    }
    playNext();
}
function amgiReplayAll(mode) {
    if (document.querySelector('audio:not(.anki-sound-audio), video')) return;
    replaySequential(collectAudioQueue(mode));
}
window.amgiReplayAll = amgiReplayAll;
function amgiPlayAudioElement(audio) {
    if (!audio) return false;
    var btn = audio.nextElementSibling;
    // Toggle: if this element is currently playing, pause it and flip icon.
    // Diverges from fork's replay-only behavior so the pause icon is functional.
    if (!audio.paused) {
        audio.pause();
        setAudioButtonState(btn, 'play');
        notifyAudioState(false);
        return false;
    }
    stopAllSystemAudio(); notifyAudioState(true);
    audio.currentTime = 0;
    audio.play().catch(function() { setAudioButtonState(btn, 'play'); notifyAudioState(false); });
    setAudioButtonState(btn, 'pause');
    audio.onended = function() { setAudioButtonState(btn, 'play'); notifyAudioState(false); };
    return false;
}
function playSound(btn) { return amgiPlayAudioElement(btn ? btn.previousElementSibling : null); }
window.playSound = playSound; globalThis.playSound = playSound;

// ── pycmd (compat shim) ──────────────────────────────────────────────
function pycmd(command) {
    if (!command || typeof command !== 'string') return false;
    if (command === 'replay') { amgiReplayAll(amgiReplayModeValue()); return false; }
    if (command.startsWith('play:')) {
        var parts = command.split(':');
        var side = parts[1];
        var index = parseInt(parts[2] || '0', 10);
        if (Number.isNaN(index) || index < 0) return false;
        var queues = splitAudioQueue();
        return amgiPlayAudioElement((side === 'a' ? queues.answer : queues.question)[index]);
    }
    return false;
}
globalThis.pycmd = pycmd; window.pycmd = pycmd;

// ===== Link interceptor =====
function postOpenLink(rawHref) {
    if (!rawHref) return;
    var resolved = rawHref;
    try { resolved = new URL(rawHref, document.baseURI).toString(); } catch(e) {}
    try { window.webkit.messageHandlers.amgiOpenLink.postMessage(resolved); } catch(e) {}
}
document.addEventListener('click', function(event) {
    var anchor = event.target && event.target.closest ? event.target.closest('a[href]') : null;
    if (!anchor) return;
    var href = anchor.getAttribute('href');
    if (!href || href.startsWith('#') || href.startsWith('javascript:')) return;
    event.preventDefault();
    postOpenLink(anchor.href || href);
});
window.open = function(url) { postOpenLink(url); return null; };

// ===== TTS =====
function amgiSpeakTts(btn) {
    if (!btn) return false;
    stopAllSystemAudio();
    try {
        window.webkit.messageHandlers.amgiSpeakTts.postMessage({
            text: btn.dataset.ttsText || '',
            lang: btn.dataset.ttsLang || '',
            voices: btn.dataset.ttsVoices || '',
            speed: btn.dataset.ttsSpeed || ''
        });
    } catch(e) {}
    return false;
}
window.amgiSpeakTts = amgiSpeakTts; globalThis.amgiSpeakTts = amgiSpeakTts;

// ===== Typed-answer reader =====
function amgiGetTypedAnswer() {
    var input = document.getElementById('typeans');
    return input ? input.value : null;
}
window.amgiGetTypedAnswer = amgiGetTypedAnswer;
window.getTypedAnswer = amgiGetTypedAnswer;
globalThis.getTypedAnswer = amgiGetTypedAnswer;
function amgiSubmitTypedAnswer() {
    try { window.webkit.messageHandlers.amgiSubmitTypedAnswer.postMessage(amgiGetTypedAnswer()); } catch(e) {}
}
window.amgiSubmitTypedAnswer = amgiSubmitTypedAnswer;
function amgiEnsureTypedAnswerVisible() {
    var input = document.getElementById('typeans');
    if (!input) return;
    try { input.scrollIntoView({ block: 'center', inline: 'nearest' }); }
    catch(e) { input.scrollIntoView(); }
}
window.amgiEnsureTypedAnswerVisible = amgiEnsureTypedAnswerVisible;
window._typeAnsPress = function() {
    var e = window.event || null;
    if (e && e.key === 'Enter') { e.preventDefault(); amgiSubmitTypedAnswer(); return false; }
    return true;
};
globalThis._typeAnsPress = window._typeAnsPress;

// ── Browser classes ──────────────────────────────────────────────────
function amgiAddBrowserClasses() {
    var ua = navigator.userAgent.toLowerCase();
    function add(c) { if (c) document.documentElement.classList.add(c); }
    if (/ipad/.test(ua)) add('ipad');
    else if (/iphone/.test(ua)) add('iphone');
    else if (/android/.test(ua)) add('android');
    if (/ipad|iphone|ipod/.test(ua)) add('ios');
    if (/ipad|iphone|ipod|android/.test(ua)) add('mobile');
    else if (/linux/.test(ua)) add('linux');
    else if (/windows/.test(ua)) add('win');
    else if (/mac/.test(ua)) add('mac');
    if (/firefox\//.test(ua)) add('firefox');
    else if (/chrome\//.test(ua)) add('chrome');
    else if (/safari\//.test(ua)) add('safari');
}
window.ankiPlatform = /iphone|ipad|ipod/.test(navigator.userAgent.toLowerCase()) ? 'ios' : 'other';
globalThis.ankiPlatform = window.ankiPlatform;

// ===== IO masks =====
function amgiExtractIOShapes(selector) {
    return Array.from(document.querySelectorAll(selector)).map(function(el) {
        var pointsRaw = el.dataset.points;
        var points = null;
        if (pointsRaw) {
            var nums = pointsRaw.trim().split(/[\s,]+/).map(Number).filter(function(v) { return !Number.isNaN(v); });
            points = [];
            for (var i = 0; i + 1 < nums.length; i += 2) points.push({ x: nums[i], y: nums[i+1] });
        }
        return {
            type: el.dataset.shape,
            left: parseFloat(el.dataset.left||'0'), top: parseFloat(el.dataset.top||'0'),
            width: parseFloat(el.dataset.width||'0'), height: parseFloat(el.dataset.height||'0'),
            rx: parseFloat(el.dataset.rx||'0'), ry: parseFloat(el.dataset.ry||'0'),
            angle: parseFloat(el.dataset.angle||'0'),
            text: el.dataset.text||'',
            scale: parseFloat(el.dataset.scale||'1'),
            fontSize: parseFloat(el.dataset.fontSize||'0'),
            fill: el.dataset.fill||'#000000',
            occludeInactive: (el.dataset.occludeInactive||el.dataset.occludeinactive||'')==='1',
            points: points
        };
    });
}
function amgiDrawIOShape(ctx, shape, size, fill, stroke) {
    if (shape.type === 'text') {
        var fontSize = shape.fontSize > 0 ? shape.fontSize * size.height : 40;
        var scale = shape.scale > 0 ? shape.scale : 1;
        ctx.save(); ctx.font = fontSize + 'px Arial'; ctx.textBaseline = 'top'; ctx.scale(scale, scale);
        var lines = (shape.text || '').split('\n');
        var bm = ctx.measureText('M');
        var fh = bm.actualBoundingBoxAscent + bm.actualBoundingBoxDescent;
        var lh = 1.5 * fh; var maxW = 0;
        var sl = shape.left * size.width / scale, st = shape.top * size.height / scale;
        var angle = shape.angle * Math.PI / 180;
        lines.forEach(function(l) { var w = ctx.measureText(l).width; if (w > maxW) maxW = w; });
        if (angle) { ctx.translate(sl, st); ctx.rotate(angle); ctx.translate(-sl, -st); }
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(sl, st, maxW + 5, lines.length * lh + 5);
        ctx.fillStyle = shape.fill || '#000000';
        lines.forEach(function(l, i) { ctx.fillText(l, sl, st + i * lh); });
        ctx.restore(); return;
    }
    if (shape.type === 'polygon' && shape.points && shape.points.length >= 2) {
        ctx.save(); ctx.beginPath();
        ctx.moveTo(shape.points[0].x * size.width, shape.points[0].y * size.height);
        for (var pi = 1; pi < shape.points.length; pi++)
            ctx.lineTo(shape.points[pi].x * size.width, shape.points[pi].y * size.height);
        ctx.closePath(); ctx.fillStyle = fill; ctx.fill();
        if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke(); }
        ctx.restore(); return;
    }
    var left = shape.left * size.width, top = shape.top * size.height;
    var angle = shape.angle * Math.PI / 180;
    ctx.save(); ctx.translate(left, top); ctx.rotate(angle);
    if (shape.type === 'rect') {
        var sw = shape.width * size.width, sh = shape.height * size.height;
        ctx.fillStyle = fill; ctx.fillRect(0, 0, sw, sh);
        if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.strokeRect(0, 0, sw, sh); }
    } else if (shape.type === 'ellipse') {
        var rx = shape.rx * size.width, ry = shape.ry * size.height;
        ctx.beginPath(); ctx.ellipse(rx, ry, rx, ry, 0, 0, 2 * Math.PI);
        ctx.fillStyle = fill; ctx.fill();
        if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1; ctx.stroke(); }
    }
    ctx.restore();
}
function amgiHitTestShape(shape, px, py, size) {
    if (shape.type === 'polygon' && shape.points && shape.points.length >= 3) {
        var inside = false;
        for (var i = 0, j = shape.points.length - 1; i < shape.points.length; j = i++) {
            var xi = shape.points[i].x * size.width, yi = shape.points[i].y * size.height;
            var xj = shape.points[j].x * size.width, yj = shape.points[j].y * size.height;
            if (((yi > py) !== (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) inside = !inside;
        }
        return inside;
    }
    var angle = shape.angle * Math.PI / 180;
    var ox = shape.left * size.width, oy = shape.top * size.height;
    var dx = px - ox, dy = py - oy;
    var lx = dx * Math.cos(-angle) - dy * Math.sin(-angle);
    var ly = dx * Math.sin(-angle) + dy * Math.cos(-angle);
    if (shape.type === 'rect') {
        return lx >= 0 && lx <= shape.width * size.width && ly >= 0 && ly <= shape.height * size.height;
    } else if (shape.type === 'ellipse') {
        var rx = shape.rx * size.width, ry = shape.ry * size.height;
        var ex = lx - rx, ey = ly - ry;
        return (rx > 0 && ry > 0) ? ((ex*ex)/(rx*rx) + (ey*ey)/(ry*ry)) <= 1 : false;
    }
    return false;
}
var amgiIOOneTimeSetupDone = false;
function amgiSetupImageOcclusion() {
    var container = document.getElementById('image-occlusion-container');
    if (!container) return;
    var img = container.querySelector('img');
    if (!img) return;
    var canvas = document.getElementById('image-occlusion-canvas');
    if (!canvas) {
        canvas = document.createElement('canvas');
        canvas.id = 'image-occlusion-canvas';
        container.appendChild(canvas);
    }
    if (!amgiIOOneTimeSetupDone) {
        window.addEventListener('resize', function() { window.requestAnimationFrame(amgiSetupImageOcclusion); });
        amgiIOOneTimeSetupDone = true;
    }
    function waitForImg(cb) {
        if (!img || img.complete) { cb(); return; }
        var fn = function() { img.removeEventListener('load', fn); img.removeEventListener('error', fn); cb(); };
        img.addEventListener('load', fn); img.addEventListener('error', fn);
    }
    waitForImg(function() {
        window.requestAnimationFrame(function() {
            var canvasRef = document.getElementById('image-occlusion-canvas');
            if (!canvasRef) return;
            var dpr = window.devicePixelRatio || 1;
            var width = img.offsetWidth, height = img.offsetHeight;
            if (!width || !height) return;
            canvasRef.style.width = width + 'px'; canvasRef.style.height = height + 'px';
            canvasRef.width = width * dpr; canvasRef.height = height * dpr;
            function collectShapes() {
                var shapes = [];
                ['cloze-inactive','cloze','cloze-highlight'].forEach(function(cls) {
                    amgiExtractIOShapes('.' + cls + '[data-shape]').forEach(function(s) {
                        s._cls = cls; s._revealed = false; shapes.push(s);
                    });
                });
                container._amgiIOShapes = shapes;
            }
            function visibleShapes() {
                return (container._amgiIOShapes || []).filter(function(s) {
                    if (s._revealed) return false;
                    if (container._amgiMasksHidden) return false;
                    if (s._cls === 'cloze-inactive') return !!s.occludeInactive;
                    return true;
                });
            }
            function redraw() {
                var ctx = canvasRef.getContext('2d');
                if (!ctx) return;
                ctx.setTransform(1, 0, 0, 1, 0, 0);
                ctx.clearRect(0, 0, canvasRef.width, canvasRef.height);
                ctx.scale(dpr, dpr);
                var masksHidden = !!container._amgiMasksHidden;
                canvasRef.style.pointerEvents = amgiIsAnswerSide() && !masksHidden ? 'auto' : 'none';
                canvasRef.style.cursor = amgiIsAnswerSide() && !masksHidden ? 'pointer' : 'default';
                var style = getComputedStyle(document.documentElement);
                var inactiveColor = style.getPropertyValue('--inactive-shape-color').trim() || '#ffeba2';
                var activeColor = style.getPropertyValue('--active-shape-color').trim() || '#ff8e8e';
                var highlightColor = style.getPropertyValue('--highlight-shape-color').trim() || 'rgba(255,142,142,0)';
                var border = '#212121';
                var size = { width: width, height: height };
                visibleShapes().forEach(function(s) {
                    var fill = s._cls === 'cloze-inactive' ? inactiveColor : s._cls === 'cloze' ? activeColor : highlightColor;
                    amgiDrawIOShape(ctx, s, size, fill, border);
                });
            }
            container._amgiRedrawIO = redraw;
            collectShapes();
            if (!canvasRef.dataset.amgiRevealBound) {
                canvasRef.addEventListener('click', function(event) {
                    if (!amgiIsAnswerSide() || container._amgiMasksHidden) return;
                    var rect = canvasRef.getBoundingClientRect();
                    var px = event.clientX - rect.left, py = event.clientY - rect.top;
                    var size = { width: img.offsetWidth, height: img.offsetHeight };
                    var shapes = container._amgiIOShapes || [];
                    for (var i = shapes.length - 1; i >= 0; i--) {
                        if (amgiHitTestShape(shapes[i], px, py, size)) {
                            shapes[i]._revealed = !shapes[i]._revealed;
                            redraw(); break;
                        }
                    }
                });
                canvasRef.dataset.amgiRevealBound = '1';
            }
            var toggleBtn = document.getElementById('toggle') || document.querySelector('.toggle');
            var hasInactiveMasks = !!document.querySelector('[data-occludeinactive="1"], [data-occludeInactive="1"]');
            container._amgiToggleMasks = function(event) {
                if (event) { event.preventDefault(); event.stopPropagation(); }
                container._amgiMasksHidden = !container._amgiMasksHidden;
                if (!container._amgiMasksHidden)
                    (container._amgiIOShapes || []).forEach(function(s) { s._revealed = false; });
                if (toggleBtn) toggleBtn.setAttribute('aria-pressed', container._amgiMasksHidden ? 'true' : 'false');
                redraw();
            };
            if (toggleBtn) {
                toggleBtn.type = 'button';
                toggleBtn.setAttribute('aria-pressed', container._amgiMasksHidden ? 'true' : 'false');
                if (!amgiIsAnswerSide() || !hasInactiveMasks) { toggleBtn.style.display = 'none'; }
                else {
                    toggleBtn.style.display = '';
                    if (!toggleBtn.dataset.amgiToggleBound) {
                        toggleBtn.addEventListener('click', function(e) { if (container._amgiToggleMasks) container._amgiToggleMasks(e); });
                        toggleBtn.dataset.amgiToggleBound = '1';
                    }
                }
            }
            redraw();
        });
    });
}
window.amgiSetupImageOcclusion = amgiSetupImageOcclusion;

// anki.imageOcclusion / anki.setupImageCloze compat shims
var anki = globalThis.anki || {};
globalThis.anki = anki; window.anki = anki;
anki.addBrowserClasses = amgiAddBrowserClasses;
anki.imageOcclusion = anki.imageOcclusion || {};
anki.imageOcclusion.setup = amgiSetupImageOcclusion;
anki.imageOcclusion.drawShape = amgiDrawIOShape;
anki.imageOcclusion.Shape = anki.imageOcclusion.Shape || function Shape() {};
anki.imageOcclusion.Text = anki.imageOcclusion.Text || function Text() {};
anki.imageOcclusion.Rectangle = anki.imageOcclusion.Rectangle || function Rectangle() {};
anki.imageOcclusion.Ellipse = anki.imageOcclusion.Ellipse || function Ellipse() {};
anki.imageOcclusion.Polygon = anki.imageOcclusion.Polygon || function Polygon() {};
anki.setupImageCloze = function() { amgiSetupImageOcclusion(); };
amgiAddBrowserClasses();

// ── Core QA update (mirrors upstream _updateQA) ──────────────────────
async function amgiUpdateQA(html, state, onupdate, onshown) {
    window.onUpdateHook = [];
    window.onShownHook = [];
    if (typeof onupdate === 'function') window.onUpdateHook.push(onupdate);
    if (typeof onshown === 'function') window.onShownHook.push(onshown);

    var qa = document.getElementById('qa');
    if (!qa) return;

    stopAllSystemAudio();
    var normalizedHTML = amgiNormalizeMathJaxMarkup(html || '');
    var needsMathJax = amgiContainsMathJaxMarkup(normalizedHTML);
    var preloadPromise = amgiPreloadResources(normalizedHTML);
    var mathJaxPromise = needsMathJax ? amgiEnsureMathJaxReady(1500) : Promise.resolve(null);

    try {
        await preloadPromise;
        // Keep the previous card visible while resources warm, and only
        // hide right before swapping the DOM to avoid blank-frame flashes.
        qa.style.transition = 'none';
        qa.style.opacity = '0';
        amgiApplyCardState(state || {});

        try { await amgiSetInnerHTML(qa, normalizedHTML); }
        catch(e) { qa.innerHTML = '<div>Error: ' + String(e).replace(/\n/g,'<br>') + '</div>'; }

        await amgiRunHooks(window.onUpdateHook);

        if (needsMathJax) {
            try {
                var mathJax = await mathJaxPromise;
                if (mathJax) {
                    if (typeof mathJax.typesetClear === 'function') {
                        mathJax.typesetClear();
                    }
                    await mathJax.typesetPromise([qa])
                        .catch(function(error) { console.error('MathJax failed', error); });
                }
            } catch (error) {
                console.error('MathJax unavailable', error);
            }
        }

        // Detect missing media
        document.querySelectorAll('img').forEach(function(img) {
            img.onerror = function() {
                var hint = document.createElement('span');
                hint.className = 'missing-media';
                hint.textContent = '⚠ ' + (img.getAttribute('src') || 'image');
                img.replaceWith(hint);
            };
            if (img.complete && img.naturalWidth === 0 && img.src) img.onerror();
        });
        document.querySelectorAll('.sound-btn').forEach(function(span) {
            var audio = span.querySelector('audio');
            if (!audio) return;
            audio.onerror = function() {
                var hint = document.createElement('span');
                hint.className = 'missing-media';
                hint.textContent = '⚠ ' + (audio.getAttribute('src') || 'audio');
                span.replaceWith(hint);
            };
        });

        var typeInput = document.getElementById('typeans');
        if (typeInput) {
            var ensureVisible = function() { window.setTimeout(amgiEnsureTypedAnswerVisible, 180); };
            typeInput.addEventListener('focus', ensureVisible);
            typeInput.addEventListener('click', ensureVisible);
            typeInput.addEventListener('input', ensureVisible);
            typeInput.focus(); ensureVisible();
        }

        amgiSetupImageOcclusion();
        await amgiRunHooks(window.onShownHook);
    } finally {
        // Avoid a forced fade-in on every flip/next-card update; it reads
        // as a content reload once MathJax and scripts are involved.
        qa.style.transition = 'none';
        qa.style.opacity = '1';
        amgiScheduleCardThemeReport();
    }
}

// ── Serial queue (mirrors upstream _queueAction) ─────────────────────
function amgiQueueAction(action) {
    window.__amgiUpdateQueue = (window.__amgiUpdateQueue || Promise.resolve()).then(action);
}

// ── Public API called from Swift via evaluateJavaScript ───────────────
function _showQuestion(html, prefetchHTML, bodyclass, autoplay, replayMode, alignTop, bodyPaddingBottom, cardPaddingBottom, lookupPopupEnabled) {
    amgiQueueAction(function() {
        return amgiUpdateQA(
            html,
            {
                isAnswerSide: false,
                lookupPopupEnabled: !!lookupPopupEnabled,
                bodyClass: bodyclass,
                autoplayEnabled: !!autoplay,
                replayMode: replayMode || 'question',
                alignTop: !!alignTop,
                bodyPaddingBottom: bodyPaddingBottom || 16,
                cardPaddingBottom: cardPaddingBottom || 0,
                renderedAt: Date.now(),
                prefetchHTML: prefetchHTML || ''
            },
            function() {
                window.scrollTo(0, 0);
            },
            function() {
                var typeans = document.getElementById('typeans');
                if (typeans) typeans.focus();
                var hasTemplateManagedMedia = document.querySelector('audio:not(.anki-sound-audio), video') !== null;
                if (amgiAutoplayEnabled() && !hasTemplateManagedMedia) amgiReplayAll(amgiReplayModeValue());
                var ph = amgiPrefetchHTMLValue();
                if (amgiContainsMathJaxMarkup(html || '') || amgiContainsMathJaxMarkup(ph || '')) {
                    void amgiEnsureMathJaxReady(1500);
                }
                if (ph) amgiAllImagesLoaded().then(function() { return amgiPreloadResources(ph); });
            }
        );
    });
}

function _showAnswer(html, bodyclass, autoplay, replayMode, alignTop, bodyPaddingBottom, cardPaddingBottom, lookupPopupEnabled) {
    amgiQueueAction(function() {
        return amgiUpdateQA(
            html,
            {
                isAnswerSide: true,
                lookupPopupEnabled: !!lookupPopupEnabled,
                bodyClass: bodyclass,
                autoplayEnabled: !!autoplay,
                replayMode: replayMode || 'answerOnly',
                alignTop: !!alignTop,
                bodyPaddingBottom: bodyPaddingBottom || 16,
                cardPaddingBottom: cardPaddingBottom || 0,
                renderedAt: Date.now(),
                prefetchHTML: ''
            },
            function() {
                // scroll to answer after images load
                amgiAllImagesLoaded().then(function() {
                    var marker = document.getElementById('answer');
                    if (marker) marker.scrollIntoView();
                });
            },
            function() {
                var hasTemplateManagedMedia = document.querySelector('audio:not(.anki-sound-audio), video') !== null;
                if (amgiAutoplayEnabled() && !hasTemplateManagedMedia) amgiReplayAll(amgiReplayModeValue());
            }
        );
    });
}

window._showQuestion = _showQuestion;
window._showAnswer = _showAnswer;
</script>
</head>
<body><div id="qa" class="card-frame"></div></body>
</html>
