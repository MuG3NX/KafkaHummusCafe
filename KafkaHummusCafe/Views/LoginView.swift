import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @Binding var isLoggedIn: Bool
    @State private var isAuthenticating = false
    
    var body: some View {
        ZStack {
            ThemeColors.gradient
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Kafka Hummus Café Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeColors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 60)
                
                Spacer()
                
                // Biometric Login Button
                Button {
                    isAuthenticating = true
                    viewModel.authenticateWithBiometrics { success in
                        isAuthenticating = false
                        isLoggedIn = success
                    }
                } label: {
                    HStack {
                        if isAuthenticating {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "faceid")
                            Text("Login with Face ID")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ThemeColors.accent)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .disabled(isAuthenticating)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                    Text("or")
                        .foregroundColor(ThemeColors.secondary)
                    Rectangle()
                        .frame(height: 1)
                }
                .foregroundColor(ThemeColors.secondary.opacity(0.3))
                .padding(.horizontal)
                
                // Email/Password Fields
                VStack(spacing: 20) {
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    Button("Forgot Password?") {
                        // Handle forgot password
                    }
                    .font(.footnote)
                    .foregroundColor(ThemeColors.accent)
                }
                .padding(.horizontal)
                
                // Login Button
                Button {
                    viewModel.login { success in
                        isLoggedIn = success
                    }
                } label: {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ThemeColors.accent)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .alert("Authentication Error", isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { 
                isAuthenticating = false
            }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(ThemeColors.cardBackground)
            .cornerRadius(12)
            .foregroundColor(ThemeColors.secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ThemeColors.accent.opacity(0.3), lineWidth: 1)
            )
    }
} 