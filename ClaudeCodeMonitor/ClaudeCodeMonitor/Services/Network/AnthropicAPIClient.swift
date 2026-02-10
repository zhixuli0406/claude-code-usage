import Foundation

/// Base API client for Anthropic API
@available(macOS 14.0, *)
final class AnthropicAPIClient {
    private let baseURL = "https://api.anthropic.com/v1"
    private let session: URLSession
    private let keychainService: KeychainServiceProtocol
    private let anthropicVersion = "2023-06-01"

    init(keychainService: KeychainServiceProtocol) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        self.keychainService = keychainService
    }

    /// Make a generic async request
    @available(macOS 14.0, *)
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: String]? = nil,
        body: Data? = nil
    ) async throws -> T {
        // Load API key
        guard let apiKey = try keychainService.loadAPIKey() else {
            throw AppError.noAPIKey
        }

        // Build URL
        var urlComponents = URLComponents(string: baseURL + endpoint)!
        if let parameters = parameters {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("ClaudeCodeMonitor/1.0.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        // Retry logic with exponential backoff
        var lastError: Error?
        for attempt in 1...3 {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                // Handle HTTP status codes
                switch httpResponse.statusCode {
                case 200...299:
                    // Success - decode response
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        decoder.dateDecodingStrategy = .iso8601
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        throw APIError.decodingError(error)
                    }

                case 401:
                    throw APIError.unauthorized

                case 429:
                    // Rate limit exceeded
                    let retryAfter = parseRetryAfter(from: httpResponse)
                    throw APIError.rateLimitExceeded(retryAfter: retryAfter)

                case 500...599:
                    // Server error - retry
                    lastError = APIError.serverError(httpResponse.statusCode)
                    if attempt < 3 {
                        let delay = pow(2.0, Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }

                default:
                    throw APIError.httpError(httpResponse.statusCode)
                }
            } catch let error as APIError {
                throw error
            } catch let error as AppError {
                throw error
            } catch {
                lastError = APIError.networkError(error)
                if attempt < 3 {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
            }
        }

        throw lastError ?? APIError.unknown
    }

    /// Parse Retry-After header
    @available(macOS 14.0, *)
    private func parseRetryAfter(from response: HTTPURLResponse) -> Date? {
        guard let retryAfterString = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }

        // Try parsing as seconds (integer)
        if let seconds = Int(retryAfterString) {
            return Date().addingTimeInterval(TimeInterval(seconds))
        }

        // Try parsing as HTTP date
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: retryAfterString)
    }
}

/// HTTP methods
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
