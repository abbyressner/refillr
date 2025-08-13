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
    private let fileName = "items.json"
    
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var itemsFileURL: URL { documentsURL.appendingPathComponent(fileName) }
        
    func loadRefillItems() -> [RefillItem] {
        do {
            let url = itemsFileURL
            if !FileManager.default.fileExists(atPath: url.path) {
                try saveRefillItems([])
                return []
            }
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([RefillItem].self, from: data)
            return items
        } catch {
#if DEBUG
            print("DataManager load error:", error)
#endif
            return []
        }
    }
    
    func saveRefillItems(_ items: [RefillItem]) {
        do {
            let data = try JSONEncoder.pretty.encode(items)
            try data.write(to: itemsFileURL, options: [.atomic])
        } catch {
#if DEBUG
            print("DataManager save error:", error)
#endif
        }
    }
    
    
    func upsert(_ item: RefillItem) {
        var all = loadRefillItems()
        if let idx = all.firstIndex(where: { $0.id == item.id }) {
            all[idx] = item
        } else {
            all.append(item)
        }
        saveRefillItems(all)
    }
    
    func delete(id: String) {
        var all = loadRefillItems()
        all.removeAll { $0.id == id }
        saveRefillItems(all)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }
}
