//
//  iVaultTests.swift
//  iVaultTests
//
//  Created by Tu on 26/7/26.
//

import Testing
@testable import iVault

struct iVaultTests {

    @Test
    @MainActor
    func spacingScaleIsStrictlyIncreasing() {
        #expect(PassVaultSpacing.xSmall < PassVaultSpacing.small)
        #expect(PassVaultSpacing.small < PassVaultSpacing.medium)
        #expect(PassVaultSpacing.medium < PassVaultSpacing.large)
        #expect(PassVaultSpacing.large < PassVaultSpacing.xLarge)
    }

    @Test
    func tabBarContainsTheFiveDocumentedDestinations() {
        #expect(PassVaultTab.allCases.count == 5)
    }

}
