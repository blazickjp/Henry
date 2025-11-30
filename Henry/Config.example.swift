import Foundation

/// Configuration file for API keys
/// To use:
/// 1. Copy this file to Config.swift
/// 2. Replace the placeholder with your actual Anthropic API key
/// 3. Config.swift is git-ignored for security

struct Config {
    /// Your Anthropic API key from https://console.anthropic.com
    static let anthropicAPIKey: String = "YOUR_ANTHROPIC_API_KEY_HERE"
}
