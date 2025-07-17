//
//  ContentView.swift
//  tava
//
//  Created by dilan on 7/17/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var supabase = SupabaseClient.shared
    
    var body: some View {
        Group {
            if supabase.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .preferredColorScheme(.dark)
        .environmentObject(supabase)
    }
        
}

struct AuthView: View {
    @EnvironmentObject var supabase: SupabaseClient
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Logo/Title
            VStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Tava")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Share what you're eating")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Auth Form
            VStack(spacing: 16) {
                if isSignUp {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    
                    TextField("Display Name (optional)", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            
            // Auth Buttons
            VStack(spacing: 12) {
                Button(action: performAuth) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isSignUp ? "Sign Up" : "Sign In")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && username.isEmpty))
                
                Button(action: {
                    isSignUp.toggle()
                    errorMessage = ""
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    private func performAuth() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                if isSignUp {
                    try await supabase.signUp(
                        email: email,
                        password: password,
                        username: username,
                        displayName: displayName.isEmpty ? nil : displayName
                    )
                } else {
                    try await supabase.signIn(email: email, password: password)
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
