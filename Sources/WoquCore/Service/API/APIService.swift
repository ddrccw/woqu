//
//  File.swift
//  woqu
//
//  Created by ddrccw on 2025/2/7.
//

import Foundation

protocol APIService {
    func getCompletion(prompt: String) async throws -> CommandSuggestion
}

