import SwiftUI
import LocalAuthentication

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // First check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            DispatchQueue.main.async {
                self.alertMessage = error?.localizedDescription ?? "Biometric authentication not available"
                self.showingAlert = true
                completion(false)
            }
            return
        }
        
        // Check which biometry type is available
        let biometryType = context.biometryType
        let reason = biometryType == .faceID ? 
            "Log in with Face ID" : 
            "Log in with Touch ID"
        
        // Start authentication on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true)
                    } else {
                        // Handle different authentication errors
                        if let error = error as? LAError {
                            switch error.code {
                            case .userCancel:
                                self.alertMessage = "Authentication cancelled"
                            case .userFallback:
                                self.alertMessage = "Please use email/password instead"
                            case .biometryNotAvailable:
                                self.alertMessage = "Face ID/Touch ID not available"
                            case .biometryNotEnrolled:
                                self.alertMessage = "Face ID/Touch ID not set up"
                            case .biometryLockout:
                                self.alertMessage = "Face ID/Touch ID is locked. Please use passcode to unlock"
                            default:
                                self.alertMessage = error.localizedDescription
                            }
                        } else {
                            self.alertMessage = "Authentication failed"
                        }
                        self.showingAlert = true
                        completion(false)
                    }
                }
            }
        }
    }
    
    func login(completion: @escaping (Bool) -> Void) {
        // TODO: Implement actual login logic
        if !email.isEmpty && !password.isEmpty {
            completion(true)
        } else {
            alertMessage = "Please enter both email and password"
            showingAlert = true
            completion(false)
        }
    }
} 