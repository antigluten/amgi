# AmgiReader

Three modules, split along one line: which of them touches C++.

| Module | Holds | Cxx |
|---|---|---|
| `Reader` | Pure-Swift reader domain types, plus `Resources/LookupExtraction.js` (`LookupExtractionScript.source`) — the tap-to-lookup extractor every lookup-capable web view injects, driven by `ReaderTests` in a real `WKWebView` | no |
| `ReaderEPUB` | EPUB parsing over the vendored `EPUBKit` (`Libraries/EPUBKit`, MIT) | no |
| `ReaderDictionary` | Wrapper around `hoshidicts`, the Yomitan-compatible offline dictionary | yes |

## Keep the C++ import in one file

`import CHoshiDicts` lives in exactly one place: `DictionaryLookupRuntime.swift`,
an internal actor inside `ReaderDictionary`. The public `+Live.swift` imports no
Cxx — it constructs the runtime and delegates.

That containment is what keeps `.interoperabilityMode(.Cxx)` scoped to this
module. Every target that imports a Cxx-mode module inherits the setting and
loses compilation caching with it, so `ReaderDictionary` is the wall: importing
`Reader` or `ReaderEPUB` stays Cxx-free, and only `ReaderFeature` pays. See the
Cxx-chain section of `AmgiFeatures/AGENTS.md` before widening that.
