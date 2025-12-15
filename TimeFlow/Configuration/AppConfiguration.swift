//
//  AppConfiguration.swift
//  TimeFlow
//
//  Created during code cleanup
//

import Foundation

/// App-wide configuration and API endpoints
enum AppConfiguration {
    // MARK: - Firebase Configuration
    
    static var firebaseConfigured: Bool {
        // Firebase is configured in TimeFlowApp.init()
        return true
    }
    
    // MARK: - API Endpoints
    
    enum API {
        static let chatWithAI = "https://us-central1-timeflow-31890.cloudfunctions.net/chatWithAI"
    }
    
    // MARK: - AI Model Configuration
    
    enum AIModel {
        static let defaultModel = "o4-mini"
        static let scheduleModel = "o4-mini"
        static let chatModel = "gpt-4o"
    }
    
    // MARK: - History Configuration
    
    enum History {
        static let maxDailyLogs = 30 // Keep last 30 days of history
    }
}

