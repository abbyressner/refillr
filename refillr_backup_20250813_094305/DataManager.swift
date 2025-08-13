//
//  DataManager.swift
//  refillr
//
//  Created by Abby Ressner on 8/7/25.
//

import Foundation

final class DataManager {
    static let shared = DataManager()
    private init() {}
    
    // file URL in the app’s Documents directory
    private var itemsURL: URL {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        return docs.appendingPathComponent("items.json")
    }
    
    // load either saved items or defaults
    func loadItems() -> [[RefillItem]] {
        do {
            let data = try Data(contentsOf: itemsURL)
            let decoded = try JSONDecoder().decode([[RefillItem]].self, from: data)
            return decoded
        } catch {
            return defaultItems()
        }
    }
    
    // save the current items to disk
    func saveItems(_ items: [[RefillItem]]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: itemsURL, options: .atomic)
        } catch {
            print("Failed to save items:", error)
        }
    }
    
    // your initial sample data
    private func defaultItems() -> [[RefillItem]] {
        return [
            [ RefillItem(name: "zyrtec 10mg", checked: false),
              RefillItem(name: "adderall xr 25mg", checked: false) ],
            [ RefillItem(name: "wellbutrin xl 300mg", checked: false) ],
            [ RefillItem(name: "vitamin d 10,000 iu", checked: false) ]
        ]
    }
}
