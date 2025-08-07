//
//  Models.swift
//  refillr
//
//  Created by Abby Ressner on 8/7/25.
//

import Foundation

struct DSLDLabel: Codable {
    let id: Int
    let productName: String
    let manufacturer: String
    // add other fields you need
    enum CodingKeys: String, CodingKey {
        case id, manufacturer
        case productName = "product_name"
    }
}
