//
//  VaultModelContainerFactory.swift
//  iVault
//
//  Created by Tu on 28/7/26.
//

import Foundation
import SwiftData

nonisolated enum VaultModelContainerFactory {
    static func make(inMemory: Bool = false) throws -> ModelContainer{
        let schema = Schema(
            versionedSchema: VaultSchemaV1.self
        )

        let configuration = ModelConfiguration(
            "iVaultLocal",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: VaultMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
