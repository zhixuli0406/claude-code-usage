import Foundation

/// API-specific errors
@available(macOS 14.0, *)
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimitExceeded(retryAfter: Date?)
    case serverError(Int)
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized. Check your Admin API key."
        case .rateLimitExceeded(let retryAfter):
            if let date = retryAfter {
                let formatter = DateComponentsFormatter()
                formatter.unitsStyle = .short
                let timeString = formatter.string(from: Date(), to: date) ?? "shortly"
                return "Rate limit exceeded. Retry after \(timeString)"
            }
            return "Rate limit exceeded. Please wait before retrying."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .httpError(let code):
            return "HTTP error (\(code))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

/// Application-level errors
enum AppError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case apiError(APIError)
    case storageError(Error)
    case configurationError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "尚未設定 API 金鑰，請在設定中新增您的 Admin API 金鑰。"
        case .invalidAPIKey:
            return "API 金鑰格式無效，Admin 金鑰應以 'sk-ant-admin-' 開頭。"
        case .apiError(let error):
            return error.localizedDescription
        case .storageError(let error):
            return "儲存錯誤：\(error.localizedDescription)"
        case .configurationError(let message):
            return "設定錯誤：\(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noAPIKey:
            return "請開啟設定並輸入您從 console.anthropic.com 取得的 Admin API 金鑰"
        case .invalidAPIKey:
            return "請確認您的 API 金鑰格式，應以 'sk-ant-admin-' 開頭"
        case .apiError(let error):
            if case .rateLimitExceeded = error {
                return "請增加更新間隔以減少 API 呼叫次數"
            }
            if case .unauthorized = error {
                return "請確認您的 Admin API 金鑰是否有效且具有適當的權限"
            }
            return "請檢查您的網路連線並重試"
        case .storageError:
            return "請嘗試在設定中清除快取"
        case .configurationError:
            return "請檢查您的應用程式設定"
        }
    }
}
