import Foundation

public final class CallbackQueryHandler {
    public typealias ApprovalCallback = (String, Int) async -> Bool
    
    private var pendingApprovals: [String: ApprovalCallback] = [:]
    
    public init() {}
    
    // MARK: - Register Approval Request
    
    public func registerApproval(
        requestId: String,
        callback: @escaping ApprovalCallback
    ) {
        pendingApprovals[requestId] = callback
    }
    
    // MARK: - Handle Callback Query
    
    public func handleCallbackQuery(_ callbackQuery: TelegramCallbackQuery) async throws -> String? {
        guard let data = callbackQuery.data else {
            return "No callback data"
        }
        
        // Parse callback data: "approve:requestId" or "reject:requestId"
        let parts = data.split(separator: ":")
        guard parts.count == 2 else {
            return "Invalid callback format"
        }
        
        let action = String(parts[0])
        let requestId = String(parts[1])
        
        guard let callback = pendingApprovals[requestId] else {
            return "Approval request not found or expired"
        }
        
        let approved = (action == "approve")
        let result = await callback(requestId, callbackQuery.from.id)
        
        // Clean up after handling
        pendingApprovals.removeValue(forKey: requestId)
        
        if result {
            return approved ? "✅ Approved" : "❌ Rejected"
        } else {
            return "Failed to process \(action)"
        }
    }
    
    // MARK: - Create Approval Keyboard
    
    public static func createApprovalKeyboard(requestId: String) -> InlineKeyboardMarkup {
        let approveButton = InlineKeyboardButton(
            text: "✅ Approve",
            callbackData: "approve:\(requestId)"
        )
        let rejectButton = InlineKeyboardButton(
            text: "❌ Reject",
            callbackData: "reject:\(requestId)"
        )
        
        return InlineKeyboardMarkup(inlineKeyboard: [[approveButton, rejectButton]])
    }
    
    // MARK: - Cleanup Expired Requests
    
    public func cleanupOlderThan(_ seconds: TimeInterval) {
        // In a production system, you'd track timestamps
        // For now, this is a placeholder
    }
}
