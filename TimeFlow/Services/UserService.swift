//
//  UserService.swift
//  TimeFlow
//
//  Created during code cleanup
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import SwiftUI

/// Service responsible for user authentication and user data management
@MainActor
class UserService: ObservableObject {
    let db = Firestore.firestore()
    
    // MARK: - Authentication
    
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func createAccount(email: String, name: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        try await db
            .collection("users")
            .document(result.user.uid)
            .setData([
                "email": email,
                "name": name,
                "new_user": true,
                "accountCreated": Timestamp(date: Date()),
                "agreedToEULA": false
            ])
    }
    
    func googleSignIn(windowScene: UIWindowScene?) async throws {
        guard let rootVC = windowScene?.windows.first?.rootViewController else {
            throw URLError(.badServerResponse)
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)
        let authUser = authResult.user
        
        if authResult.additionalUserInfo?.isNewUser == true {
            let doc = db.collection("users").document(authUser.uid)
            
            try await doc.setData([
                "email": authUser.email ?? "",
                "name": authUser.displayName ?? "",
                "new_user": true,
                "accountCreated": Timestamp(date: Date()),
                "agreedToEULA": false
            ])
        }
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
        Logger.info("✅ Password reset email sent to \(email)", category: .auth)
    }
    
    func checkIfEmailExists(email: String, completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: "TemporaryPassword123") { authResult, error in
            if let error = error as NSError? {
                // Check if the error indicates the email is already in use
                if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    completion(true, nil) // Email exists
                } else {
                    completion(false, error) // Other error (e.g., invalid email, network issue)
                }
            } else {
                // User was created successfully, but we don't want a new user
                // Delete the temporary user to avoid cluttering Firebase
                if let user = authResult?.user {
                    user.delete { deletionError in
                        if let deletionError = deletionError {
                            Logger.error("Failed to delete temporary user: \(deletionError.localizedDescription)", category: .auth)
                        }
                        completion(false, nil) // Email does not exist
                    }
                } else {
                    completion(false, nil) // Email does not exist
                }
            }
        }
    }
    
    // MARK: - User Data Management
    
    func fetchUser() async throws -> User {
        Logger.info("🔄 Fetching user data...", category: .auth)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "UserService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey : "Not signed in"])
        }

        let snapshot = try await db
            .collection("users")
            .document(uid)
            .getDocument()

        guard snapshot.exists else {
            Logger.warning("❌ User document does not exist", category: .auth)
            throw NSError(domain: "UserService", code: 404,
                          userInfo: [NSLocalizedDescriptionKey : "User document not found"])
        }

        Logger.info("✅ User document found, decoding...", category: .auth)

        do {
            var user = try snapshot.data(as: User.self)
            Logger.info("✅ User decoded successfully with \(user.currentSchedule.count) events", category: .auth)
            
            // Ensure name and email are properly populated from the database
            if let name = snapshot.get("name") as? String {
                user.name = name
            }
            if let email = snapshot.get("email") as? String {
                user.email = email
            }
            
            Logger.info("✅ User fetch complete - currentSchedule has \(user.currentSchedule.count) events", category: .auth)
            
            return user
        } catch {
            Logger.error("❌ Failed to decode user with Codable: \(error.localizedDescription)", category: .auth)
            throw error
        }
    }
    
    func saveUserInfo(user: User) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "UserService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey : "Not signed in"])
        }
        
        var updatedUser = user
        updatedUser.email = Auth.auth().currentUser?.email ?? user.email
        updatedUser.name = Auth.auth().currentUser?.displayName ?? user.name
        
        try db.collection("users").document(uid).setData(from: updatedUser, merge: true)
    }
    
    func checkNewUser() async throws -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw URLError(.userAuthenticationRequired)
        }

        let snapshot = try await db
            .collection("users")
            .document(uid)
            .getDocument()

        let flag = snapshot.get("new_user") as? Bool ?? false
        return flag
    }
    
    func onboardingComplete() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "UserService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey : "Not signed in"])
        }

        try await db
            .collection("users")
            .document(uid)
            .updateData(["new_user": false])
    }
    
    func deleteUserAccount() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "UserService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey : "Not signed in"])
        }
        
        // Delete user data from Firestore
        try await db.collection("users").document(uid).delete()
        
        // Delete the Firebase Auth account
        try await Auth.auth().currentUser?.delete()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.cachedUserData)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.generatedSchedule)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.scheduleGeneratedAt)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.autoScheduleEnabled)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasSetAutoSchedule)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.notificationMorningEnabled)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.notificationEveningEnabled)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasSetupNotificationDefaults)
        
        Logger.info("✅ User account deleted successfully", category: .auth)
    }
    
    // MARK: - Helpers
    
    func currentUID() -> String? {
        Auth.auth().currentUser?.uid
    }
    
    func isSignedIn() -> Bool {
        Auth.auth().currentUser != nil
    }
}

