import Foundation

print("🚀 VibeCode - Swift AI Coding Bot")
print("================================")

// Load configuration from environment
guard let botToken = ProcessInfo.processInfo.environment["TELEGRAM_BOT_TOKEN"] else {
    print("❌ Error: TELEGRAM_BOT_TOKEN environment variable not set")
    print("\nPlease set your Telegram bot token:")
    print("  export TELEGRAM_BOT_TOKEN='your-bot-token-here'")
    print("\nGet a token from @BotFather on Telegram")
    exit(1)
}

guard let chatIdString = ProcessInfo.processInfo.environment["TELEGRAM_CHAT_ID"],
      let chatId = Int(chatIdString) else {
    print("❌ Error: TELEGRAM_CHAT_ID environment variable not set")
    print("\nPlease set your Telegram chat ID:")
    print("  export TELEGRAM_CHAT_ID='your-chat-id-here'")
    print("\nSend a message to your bot, then check the updates to find your chat ID")
    exit(1)
}

print("✅ Configuration loaded")
print("   Bot Token: \(String(botToken.prefix(10)))...")
print("   Chat ID: \(chatId)")

// Create and start the bot
let bot = AIBotOrchestrator(
    botToken: botToken,
    authorizedChatId: chatId
)

// Handle graceful shutdown
signal(SIGINT) { _ in
    print("\n🛑 Shutting down...")
    exit(0)
}

// Start the bot
do {
    try await bot.start()
} catch {
    print("❌ Fatal error: \(error)")
    exit(1)
}

