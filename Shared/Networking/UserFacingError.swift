import Foundation

/// Why data couldn't be loaded, in terms of what the user can do about it.
enum LoadFailure: String, Equatable {
    case offline
    case serverUnreachable
    case serverError

    var title: String {
        switch self {
        case .offline: return "You're offline"
        case .serverUnreachable: return "Can't reach Spoiled"
        case .serverError: return "Something went wrong"
        }
    }

    var message: String {
        switch self {
        case .offline: return "Check your connection and try again."
        case .serverUnreachable: return "Spoiled isn't responding right now. Try again in a moment."
        case .serverError: return "That's a problem on our end. Try again in a moment."
        }
    }
}

extension Error {
    var loadFailure: LoadFailure {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff, .callIsActive:
                return .offline
            default:
                return .serverUnreachable
            }
        }
        if let apiError = self as? APIError, case .tokenUnavailable = apiError {
            return .serverUnreachable
        }
        return .serverError
    }

    /// A load that was abandoned rather than one that failed.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        return (self as? URLError)?.code == .cancelled
    }

    /// What to show the user. Technical details like status codes and request IDs belong in logs.
    var userFacingMessage: String {
        if let urlError = self as? URLError, urlError.code != .badURL {
            return loadFailure.message
        }
        if let apiError = self as? APIError {
            switch apiError {
            case let .http(status, code, message, _, _) where (400..<500).contains(status) && !code.hasPrefix("HTTP_"):
                return message
            case .tokenUnavailable, .sessionOver:
                return apiError.errorDescription ?? LoadFailure.serverError.message
            default:
                return LoadFailure.serverError.message
            }
        }
        return "Something went wrong. Please try again."
    }
}
