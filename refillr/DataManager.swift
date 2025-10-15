//
//  DataManager.swift
//  refillr
//
//  Created by Abby Ressner on 8/7/25.
//

import Foundation

actor DataManager {
    static let shared = DataManager()
    private init() {}
    
    private lazy var storeURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).first!
        return docs.appendingPathComponent("refill-items.json",
                                           isDirectory: false)
    }()
    
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return enc
    }()
    
    private var cache: [RefillItem]?
    
    enum StoreError: LocalizedError {
        case failedToLoad(Error)
        case failedToDecode(Error)
        case failedToSave(Error)
        
        var errorDescription: String? {
            switch self {
            case .failedToLoad(let err): return "Failed to load items: \(err.localizedDescription)"
            case .failedToDecode(let err): return "Failed to decode items: \(err.localizedDescription)"
            case .failedToSave(let err): return "Failed to save items: \(err.localizedDescription)"
            }
        }
    }
    
    // MARK: - Public API
    
    func fetchAll() async throws -> [RefillItem] {
        if let cached = cache { return cached }
        let items = try loadFromDiskOrSeed()
        cache = items
        return items
    }
    
    func upsert(_ item: RefillItem) async throws {
        var items = try await fetchAll()
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        try persist(items)
        cache = items
    }
    
    func delete(id: String) async throws {
        var items = try await fetchAll()
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: idx)
        try persist(items)
        cache = items
    }
    
    func replaceAll(with items: [RefillItem]) async throws {
        try persist(items)
        cache = items
    }
    
    // MARK: - Persistence Helpers
    
    private func loadFromDiskOrSeed() throws -> [RefillItem] {
        let fm = FileManager.default
        if !fm.fileExists(atPath: storeURL.path) {
            let seeded = seedDefaults()
            try persist(seeded)
            return seeded
        }
        do {
            let data = try Data(contentsOf: storeURL)
            do {
                return try decoder.decode([RefillItem].self, from: data)
            } catch {
                throw StoreError.failedToDecode(error)
            }
        } catch {
            throw StoreError.failedToLoad(error)
        }
    }
    
    private func persist(_ items: [RefillItem]) throws {
        do {
            let data = try encoder.encode(items)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            throw StoreError.failedToSave(error)
        }
    }
    
    private func seedDefaults() -> [RefillItem] {
        [
            RefillItem.make(name: "multivitamin",
                            brand: "ritual",
                            dose: "2 capsules",
                            time: .morning,
                            checked: false),
            RefillItem.make(name: "vitamin d",
                            brand: "thorne",
                            dose: "10,000 IU",
                            time: .morning,
                            checked: false),
            RefillItem.make(name: "adderall xr",
                            dose: "25 mg",
                            time: .afternoon,
                            checked: false),
            RefillItem.make(name: "magnesium glycinate",
                            dose: "400 mg",
                            time: .evening,
                            checked: false)
        ]
    }
}
