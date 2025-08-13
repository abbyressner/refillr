//
//  RefillItem.swift
//  refillr
//
//  Created by Abby Ressner on 8/12/25.
//

import Foundation

struct RefillItem: Codable, Equatable {
    var id: String
    var labelID: String?
    var name: String
    var brand: String?
    var doseText: String?
    var timeOfDay: TimeOfDay
    var checked: Bool
    
    enum TimeOfDay: String, Codable, CaseIterable {
        case morning, afternoon, evening
        var title: String { rawValue }
    }
}

extension RefillItem {
    static func make(name: String,
                     brand: String? = nil,
                     dose: String? = nil,
                     time: TimeOfDay,
                     labelID: String? = nil,
                     checked: Bool = false) -> RefillItem {
        .init(id: UUID().uuidString,
              labelID: labelID,
              name: name,
              brand: brand,
              doseText: dose,
              timeOfDay: time,
              checked: checked)
    }
}
