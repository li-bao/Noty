import SwiftUI

/// 輕量應用程式內操作反饋吐司通知
@Observable
public final class ToastService {
    public static let shared = ToastService()
    
    public struct ToastItem: Identifiable, Equatable {
        public let id = UUID()
        public let message: String
        public let icon: String?
        public let isSuccess: Bool
        
        public static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    public var currentToast: ToastItem? = nil
    private var dismissTask: Task<Void, Never>? = nil
    
    private init() {}
    
    @MainActor
    public func show(_ message: String, icon: String? = "checkmark.circle.fill", isSuccess: Bool = true, durationSeconds: Double = 2.5) {
        dismissTask?.cancel()
        currentToast = ToastItem(message: message, icon: icon, isSuccess: isSuccess)
        
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(durationSeconds * 1_000_000_000))
            if !Task.isCancelled {
                self.currentToast = nil
            }
        }
    }
    
    @MainActor
    public func dismiss() {
        dismissTask?.cancel()
        currentToast = nil
    }
}
