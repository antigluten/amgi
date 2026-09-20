//
//  ReviewPreferences.swift
//  AppCore
//
//  Created by Vladimir Gusev on 08.08.2026.
//

import AnkiKit
public import Foundation

public enum ReaderThemeMode: String, CaseIterable, Identifiable {
    case system
    case eyeCare
    case sepia
    case custom

    public var id: String { rawValue }
}

public enum ReviewPreferences {
    public enum Keys {
        public static let playAudioInSilentMode = "review_pref_play_audio_in_silent_mode"
        public static let showCorrectnessSymbols = "review_pref_show_correctness_symbols"
        public static let showAnswerButtons = "review_pref_show_answer_buttons"
        public static let cardRenderEngine = "review_pref_card_render_engine"
        public static let templateRenderOverrides = "review_pref_template_render_overrides"
        public static let showRemainingDays = "review_pref_show_remaining_days"
        public static let showNextReviewTime = "review_pref_show_next_review_time"
        public static let openLinksExternally = "review_pref_open_links_externally"
        public static let lookupPopupEnabled = "review_pref_lookup_popup_enabled"
        public static let lookupPopupFrontEnabled = "review_pref_lookup_popup_front_enabled"
        public static let lookupPopupBackEnabled = "review_pref_lookup_popup_back_enabled"
        public static let cardContentAlignment = "review_pref_card_content_alignment"
        public static let glassAnswerButtons = "review_pref_glass_answer_buttons"
        public static let autoMatchCardBackground = "review_pref_auto_match_card_background"
    }
}

public enum ReaderPreferences {
    public enum Keys {
        public static let showTab = "reader_pref_show_tab"
        public static let tapLookup = "reader_pref_tap_lookup"
        public static let deckID = "reader_pref_deck_id"
        public static let notetypeID = "reader_pref_notetype_id"
        public static let bookIDField = "reader_pref_book_id_field"
        public static let bookTitleField = "reader_pref_book_title_field"
        public static let bookCoverField = "reader_pref_book_cover_field"
        public static let chapterTitleField = "reader_pref_chapter_title_field"
        public static let chapterOrderField = "reader_pref_chapter_order_field"
        public static let contentField = "reader_pref_content_field"
        public static let languageField = "reader_pref_language_field"
        public static let bookshelfColumns = "reader_pref_bookshelf_columns"
        public static let bookshelfSortMode = "reader_pref_bookshelf_sort_mode"
        public static let verticalLayout = "reader_pref_vertical_layout"
        public static let selectedFont = "reader_pref_selected_font"
        public static let fontSize = "reader_pref_font_size"
        public static let hideFurigana = "reader_pref_hide_furigana"
        public static let horizontalPadding = "reader_pref_horizontal_padding"
        public static let verticalPadding = "reader_pref_vertical_padding"
        public static let avoidPageBreak = "reader_pref_avoid_page_break"
        public static let justifyText = "reader_pref_justify_text"
        public static let layoutAdvanced = "reader_pref_layout_advanced"
        public static let lineHeight = "reader_pref_line_height"
        public static let characterSpacing = "reader_pref_character_spacing"
        public static let showTitle = "reader_pref_show_title"
        public static let showPercentage = "reader_pref_show_percentage"
        public static let showProgressTop = "reader_pref_show_progress_top"
        public static let themeMode = "reader_pref_theme_mode"
        public static let customContentColor = "reader_pref_custom_content_color"
        public static let customBackgroundColor = "reader_pref_custom_background_color"
        public static let customTextColor = "reader_pref_custom_text_color"
        public static let customHintColor = "reader_pref_custom_hint_color"
        public static let popupWidth = "reader_pref_popup_width"
        public static let popupHeight = "reader_pref_popup_height"
        public static let popupFontSize = "reader_pref_popup_font_size"
        public static let popupFrequencyFontSize = "reader_pref_popup_frequency_font_size"
        public static let popupContentFontSize = "reader_pref_popup_content_font_size"
        public static let popupDictionaryNameFontSize = "reader_pref_popup_dictionary_name_font_size"
        public static let popupKanaFontSize = "reader_pref_popup_kana_font_size"
        public static let popupFullWidth = "reader_pref_popup_full_width"
        public static let popupSwipeToDismiss = "reader_pref_popup_swipe_to_dismiss"
        public static let popupCollapseDictionaries = "reader_pref_popup_collapse_dictionaries"
        public static let popupCompactGlossaries = "reader_pref_popup_compact_glossaries"
        public static let popupAudioSourceTemplate = "reader_pref_popup_audio_source_template"
        public static let popupLocalAudioEnabled = "reader_pref_popup_local_audio_enabled"
        public static let popupAudioAutoplay = "reader_pref_popup_audio_autoplay"
        public static let popupAudioPlaybackMode = "reader_pref_popup_audio_playback_mode"
        public static let popupDebugInfoEnabled = "reader_pref_popup_debug_info_enabled"
        public static let dictionaryMaxResults = "reader_pref_dictionary_max_results"
        public static let dictionaryScanLength = "reader_pref_dictionary_scan_length"
        public static let lookupNoteTemplate = "reader_pref_lookup_note_template"
        public static let popupSearchHistory = "reader_pref_popup_search_history"
        public static let popupCollapsedDictionaries = "reader_pref_popup_collapsed_dictionaries"
    }
}

public enum AppearancePreferences {
    public enum Keys {
        public static let appFont = "appFont"
        public static let showProfileInToolbar = "appearance_show_profile_in_toolbar"
    }
}

public enum CodeEditorPreferences {
    public enum Keys {
        public static let fontSize = "codeEditor_fontSize"
        public static let fontFamily = "codeEditor_fontFamily"
    }

    public static let defaultFontSize: Double = 14
    public static let defaultFontFamily = "Menlo"
}

public enum SyncPreferences {
    public enum Keys {
        public static let modeBase = "syncMode"
        public static let syncMediaBase = "sync_pref_sync_media"
        public static let ioTimeoutSecsBase = "sync_pref_io_timeout_secs"
        public static let mediaLastLogBase = "sync_pref_media_last_log"
        public static let mediaLastSyncedAtBase = "sync_pref_media_last_synced_at"
        public static let lastCollectionSyncedAtBase = "sync_pref_collection_last_synced_at"
        public static let needsFullSyncBase = "sync_pref_needs_full_sync"

        public static func modeForCurrentUser() -> String {
            scoped(modeBase)
        }

        public static func syncMediaForCurrentUser() -> String {
            scoped(syncMediaBase)
        }

        public static func ioTimeoutSecsForCurrentUser() -> String {
            scoped(ioTimeoutSecsBase)
        }

        public static func mediaLastLogForCurrentUser() -> String {
            scoped(mediaLastLogBase)
        }

        public static func mediaLastSyncedAtForCurrentUser() -> String {
            scoped(mediaLastSyncedAtBase)
        }

        public static func lastCollectionSyncedAtForCurrentUser() -> String {
            scoped(lastCollectionSyncedAtBase)
        }

        public static func needsFullSyncForCurrentUser() -> String {
            scoped(needsFullSyncBase)
        }
    }

    public enum Mode: String, CaseIterable, Identifiable {
        case official
        case custom
        case local

        public var id: String { rawValue }
    }

    public enum Timeout: Int, CaseIterable, Identifiable {
        case seconds15 = 15
        case seconds30 = 30
        case seconds60 = 60
        case seconds120 = 120

        public static let defaultValue = seconds60.rawValue

        public var id: Int { rawValue }
    }

    public static let officialServerLabel = "AnkiWeb"

    public static func resolvedMode(_ rawValue: String) -> Mode {
        Mode(rawValue: rawValue) ?? .local
    }

    public static func resolvedTimeout(_ rawValue: Int) -> Timeout {
        Timeout(rawValue: rawValue) ?? .seconds60
    }

    public static func recordMediaSyncLog(_ message: String, date: Date = .now) {
        UserDefaults.standard.set(message, forKey: Keys.mediaLastLogForCurrentUser())
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Keys.mediaLastSyncedAtForCurrentUser())
    }
}

private extension SyncPreferences.Keys {
    static func scoped(_ base: String) -> String {
        "\(base)__\(SyncPreferences.currentProfileID())"
    }
}

private extension SyncPreferences {
    static func currentProfileID() -> String {
        let selectedUser = ProfileScope.current()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = selectedUser.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let profile = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return profile.isEmpty ? "default" : profile
    }
}
