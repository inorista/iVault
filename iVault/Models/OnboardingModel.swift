//
//  OnboardingModel.swift
//  iVault
//
//  Created by Tu on 26/7/26.
//

import Foundation

struct OnboardingModel: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let imagePath: String

    init(title: String, description: String, imagePath: String) {
        self.title = title
        self.description = description
        self.imagePath = imagePath
    }
}
