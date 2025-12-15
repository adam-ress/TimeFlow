//
//  LaunchView.swift
//  TimeFlow
//
//  Created by Adam Ress on 6/11/25.
//

import SwiftUI
import FirebaseAuth

struct LaunchView: View {
    @Environment(ContentModel.self) var contentModel

    var body: some View {
        Group {
            if !contentModel.loggedIn {
                SignInLandingView()

            } else {
                switch contentModel.newUser {
                case nil:
                    ProgressView()

                case true?:
                    OnBoardingView()

                case false?:
                    ContentView()
                }
            }
        }

        .task(id: contentModel.loggedIn) {
            contentModel.checkLogin()

            if contentModel.loggedIn {
                do {
                    try await contentModel.checkNewUser()
                    try await contentModel.fetchUser()
                } catch {
                    Logger.error("Error getting user information: \(error.localizedDescription)", category: .auth)
                }
            } else {
                contentModel.newUser = nil
            }
        }
    }
}

#Preview {
    LaunchView()
        .environment(ContentModel())
}