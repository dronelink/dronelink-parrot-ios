//
//  Extensions.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
extension String {
    private static let LocalizationMissing = "MISSING STRING LOCALIZATION"
    
    var localized: String {
        let value = DronelinkParrot.bundle.localizedString(forKey: self, value: String.LocalizationMissing, table: nil)
        assert(value != String.LocalizationMissing, "String localization missing: \(self)")
        return value
    }
}
