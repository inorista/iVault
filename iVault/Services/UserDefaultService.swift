//
//  UserDefaultService.swift
//  iVault
//
//  Created by Tu on 26/7/26.
//

import Foundation

protocol UserDefaultServiceProtocol {
    func load<T>(forKey key: String, as type: T.Type) -> T?
    func save<T>(_ value: T, forKey key: String)
    func update<T>(_ value: T, forKey key: String) -> Bool
    func delete(forKey key: String) -> Bool
}

class UserDefaultService: UserDefaultServiceProtocol {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    static let shared = UserDefaultService() // -> Singleton

    func load<T>(forKey key: String, as type: T.Type) -> T? {
        return userDefaults.object(forKey: key) as? T
    }

    func save<T>(_ value: T, forKey key: String) {
        return userDefaults.set(value, forKey: key)
    }

    func update<T>(_ value: T, forKey key: String) -> Bool {
        guard userDefaults.object(forKey: key) != nil else {
            return false
        }

        userDefaults.set(value, forKey: key)
        return true
    }

    func delete(forKey key: String) -> Bool {
        guard userDefaults.object(forKey: key) != nil else {
            return false
        }

        userDefaults.removeObject(forKey: key)
        return true
    }
}
