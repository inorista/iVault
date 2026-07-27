import SwiftUI

struct PassVaultColorToken: Identifiable {
    let name: String
    let hex: String
    let color: Color

    var id: String { name }
}
