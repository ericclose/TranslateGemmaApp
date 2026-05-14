import Foundation
import NaturalLanguage

public enum LanguageManager {
    public static let supportedLanguages: [String] = [
        "Arabic (Egypt)", "Arabic (Saudi Arabia)", "Bulgarian (Bulgaria)", "Bengali (Bangladesh)",
        "Bengali (India)", "Catalan (Spain)", "Czech (Czechia)", "Danish (Denmark)",
        "German (Germany)", "Greek (Greece)", "Spanish (Mexico)", "Estonian (Estonia)",
        "Persian (Farsi)", "Finnish (Finland)", "Filipino (Tagalog)", "French (Canada)",
        "French (France)", "Gujarati (India)", "Hebrew (Israel)", "Hindi (India)",
        "Croatian (Croatia)","Hungarian (Hungary)", "Indonesian (Indonesia)", "Icelandic (Iceland)",
        "Italian (Italy)", "Japanese (Japan)", "Kannada (India)", "Korean (South Korea)",
        "Lithuanian (Lithuania)", "Latvian (Latvia)", "Malayalam (India)", "Marathi (India)",
        "Dutch (Netherlands)", "Norwegian (Norway)", "Punjabi (India)", "Polish (Poland)",
        "Portuguese (Brazil)", "Portuguese (Portugal)", "Romanian (Romania)", "Russian (Russia)",
        "Slovak (Slovakia)", "Slovenian (Slovenia)", "Serbian (Serbia)", "Swedish (Sweden)",
        "Swahili (Kenya)", "Swahili (Tanzania)", "Tamil (India)", "Telugu (India)",
        "Thai (Thailand)", "Turkish (Turkey)", "Ukrainian (Ukraine)", "Urdu (Pakistan)",
        "Vietnamese (Vietnam)", "Chinese (Simplified)", "Chinese (Traditional)", "Zulu (South Africa)",
        "English"
    ].sorted()

    private static let nameToCode: [String: String] = [
        "Arabic (Egypt)": "ar_EG",
        "Arabic (Saudi Arabia)": "ar_SA",
        "Bulgarian (Bulgaria)": "bg_BG",
        "Bengali (Bangladesh)": "bn_BD",
        "Bengali (India)": "bn_IN",
        "Catalan (Spain)": "ca_ES",
        "Czech (Czechia)": "cs_CZ",
        "Danish (Denmark)": "da_DK",
        "German (Germany)": "de_DE",
        "Greek (Greece)": "el_GR",
        "Spanish (Mexico)": "es_MX",
        "Estonian (Estonia)": "et_EE",
        "Persian (Farsi)": "fa_IR",
        "Finnish (Finland)": "fi_FI",
        "Filipino (Tagalog)": "fil_PH",
        "French (Canada)": "fr_CA",
        "French (France)": "fr_FR",
        "Gujarati (India)": "gu_IN",
        "Hebrew (Israel)": "he_IL",
        "Hindi (India)": "hi_IN",
        "Croatian (Croatia)": "hr_HR",
        "Hungarian (Hungary)": "hu_HU",
        "Indonesian (Indonesia)": "id_ID",
        "Icelandic (Iceland)": "is_IS",
        "Italian (Italy)": "it_IT",
        "Japanese (Japan)": "ja_JP",
        "Kannada (India)": "kn_IN",
        "Korean (South Korea)": "ko_KR",
        "Lithuanian (Lithuania)": "lt_LT",
        "Latvian (Latvia)": "lv_LV",
        "Malayalam (India)": "ml_IN",
        "Marathi (India)": "mr_IN",
        "Dutch (Netherlands)": "nl_NL",
        "Norwegian (Norway)": "no_NO",
        "Punjabi (India)": "pa_IN",
        "Polish (Poland)": "pl_PL",
        "Portuguese (Brazil)": "pt_BR",
        "Portuguese (Portugal)": "pt_PT",
        "Romanian (Romania)": "ro_RO",
        "Russian (Russia)": "ru_RU",
        "Slovak (Slovakia)": "sk_SK",
        "Slovenian (Slovenia)": "sl_SI",
        "Serbian (Serbia)": "sr_RS",
        "Swedish (Sweden)": "sv_SE",
        "Swahili (Kenya)": "sw_KE",
        "Swahili (Tanzania)": "sw_TZ",
        "Tamil (India)": "ta_IN",
        "Telugu (India)": "te_IN",
        "Thai (Thailand)": "th_TH",
        "Turkish (Turkey)": "tr_TR",
        "Ukrainian (Ukraine)": "uk_UA",
        "Urdu (Pakistan)": "ur_PK",
        "Vietnamese (Vietnam)": "vi_VN",
        "Chinese (Simplified)": "zh_CN",
        "Chinese (Traditional)": "zh_TW",
        "Zulu (South Africa)": "zu_ZA",
        "English": "en"
    ]

    private static let shortMapping: [String: String] = [
        "Chinese (Simplified)": "zh",
        "Chinese (Traditional)": "zh-tw",
        "English": "en",
        "Japanese (Japan)": "ja",
        "Korean (South Korea)": "ko",
        "French (France)": "fr",
        "German (Germany)": "de",
        "Spanish (Mexico)": "es",
        "Russian (Russia)": "ru"
    ]

    public static func getCode(for name: String) -> String {
        return nameToCode[name] ?? name.lowercased()
    }

    public static func getShortCode(for name: String) -> String {
        return shortMapping[name] ?? String(name.prefix(2)).lowercased()
    }

    public static func getName(for code: String) -> String? {
        if code == "zh-Hant" || code == "zh_TW" { return "Chinese (Traditional)" }
        if code.hasPrefix("zh") { return "Chinese (Simplified)" }
        if code.hasPrefix("en") { return "English" }
        
        let locale = Locale(identifier: "en")
        return locale.localizedString(forLanguageCode: code)?.capitalized
    }

    public static func detectLanguage(for text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let languageCode = recognizer.dominantLanguage?.rawValue else { return nil }
        return getName(for: languageCode)
    }

    public static func detectLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        if let languageCode = recognizer.dominantLanguage?.rawValue {
            if languageCode == "zh-Hant" { return "zh_TW" }
            if languageCode.hasPrefix("zh") { return "zh_CN" }
            return languageCode
        }
        
        return "en"
    }
}
