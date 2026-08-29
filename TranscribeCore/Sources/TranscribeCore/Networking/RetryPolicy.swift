import Foundation

public struct RetryPolicy: Sendable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var maxDelay: TimeInterval
    public var jitter: TimeInterval

    public init(maxAttempts: Int = 4, baseDelay: TimeInterval = 2, maxDelay: TimeInterval = 60, jitter: TimeInterval = 1) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = max(0, jitter)
    }

    /// Seconds to wait before retrying after `attempt` (1-based) failed with `error`; nil means give up.
    public func delay(afterAttempt attempt: Int, error: TranscriptionError) -> TimeInterval? {
        guard error.isRetryable, attempt < maxAttempts else { return nil }
        if case .rateLimited(let retryAfter?) = error {
            return min(maxDelay, max(1, retryAfter))
        }
        let backoff = min(maxDelay, baseDelay * pow(2, Double(attempt - 1)))
        let floor: TimeInterval = { if case .rateLimited = error { return 5 } else { return 0 } }()
        let random = jitter > 0 ? Double.random(in: 0...jitter) : 0
        return max(backoff, floor) + random
    }
}
