import Foundation

nonisolated extension Error {
    var userMessage: String {
        if let vaultError = self as? VaultError {
            switch vaultError {
            case .locked: return "The vault is locked. Authenticate and try again."
            case .authenticationCancelled: return "Authentication was cancelled."
            case .authenticationFailed: return "Authentication failed. Please try again."
            case .keyUnavailable: return "The vault key is unavailable on this device."
            case .invalidDraft(let validationError): return validationError.userMessage
            case .corruptedPayload: return "This encrypted item could not be verified."
            default: return "Something went wrong. Please try again."
            }
        }
        if let backupError = self as? BackupError {
            switch backupError {
            case .cloudAccountUnavailable:
                return "Sign in to iCloud and enable iCloud Drive to use backups."
            case .cloudConfigurationInvalid:
                return "CloudKit is not configured for this app. Verify the iCloud capability and the iCloud.com.dev.ivault container."
            case .networkUnavailable:
                return "iCloud is currently unavailable. Check your connection and try again."
            case .quotaExceeded:
                return "Your iCloud storage is full. Manage storage in Settings > Apple Account > iCloud, then try again."
            case .uploadFailed:
                return "The encrypted backup could not be uploaded to iCloud."
            case .exportFailed:
                return "The local vault could not be prepared for backup."
            case .recoveryKeyRequired: return "Enter the recovery code for this backup."
            case .invalidRecoveryKey: return "That recovery code is invalid."
            case .integrityCheckFailed: return "The backup did not pass its integrity check."
            default: return "The backup could not be completed. Please try again."
            }
        }
        return "Something went wrong. Please try again."
    }
}

nonisolated extension VaultValidationError {
    var userMessage: String {
        switch self {
        case .requiredField(let field): "\(field.label) is required."
        case .invalidWebsite: "Enter a valid website address."
        case .imageExceedsSizeLimit(let maximumBytes):
            "Choose an image smaller than \(maximumBytes / 1_024 / 1_024) MB."
        }
    }
}

nonisolated extension VaultField {
    var label: String {
        switch self {
        case .title: "Title"
        case .password: "Password"
        case .noteBody: "Note"
        case .imageData: "Image"
        }
    }
}
