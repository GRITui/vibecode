import Foundation
import TelegramBot

/// The AI coding CLI the bot should invoke for `/task` prompts.
/// Selected via the `/provider` inline keyboard; defaults to `.claude`.
public enum AIProvider: String, CaseIterable {
    case claude
    case cline
    case opencode

    public var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .cline: return "Cline"
        case .opencode: return "opencode"
        }
    }

    public var cliBinary: String {
        switch self {
        case .claude: return "claude"
        case .cline: return "cline"
        case .opencode: return "opencode"
        }
    }

    // MARK: - Create Provider Keyboard

    public static func createProviderKeyboard() -> InlineKeyboardMarkup {
        let buttons = AIProvider.allCases.map { provider in
            InlineKeyboardButton(
                text: provider.displayName,
                callbackData: "provider:\(provider.rawValue)"
            )
        }

        return InlineKeyboardMarkup(inlineKeyboard: [buttons])
    }
}
