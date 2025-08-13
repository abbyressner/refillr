//
//  ItemsViewController.swift
//  refillr
//
//  Created by Abby Ressner on 8/7/25.
//

import UIKit

// MARK: - Models
struct LabelItem: Decodable {
    let id: String
    let fullName: String?
    let brandName: String?
    let entryDate: String?
    // productType in DSLD search is an object
    let productType: String?  // will usually be nil
}

private struct SearchResponse: Decodable {
    let items: [LabelItem]
    let total: Int
}

final class ItemsViewController: UITableViewController {
    
    // MARK: - Outlets from Storyboard
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var brandButton: UIBarButtonItem!
    @IBOutlet weak var sortButton: UIBarButtonItem!
    @IBOutlet weak var statusButton: UIBarButtonItem!
    
    // MARK: - State
    private var results: [LabelItem] = []
    private var debounceTimer: Timer?
    private var isLoading = false
    
    private var currentQuery: String = ""
    private var currentBrand: String?
    private var currentStatus: String = "1" // default to on-market only
    private var sortBy: String = "_score"
    private var sortOrder: String = "desc"
    
    private let baseURL: URL = AppConfig.proxyBaseURL
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("proxy base:", AppConfig.proxyBaseURL.absoluteString)
        title = "search"
        
        tableView.keyboardDismissMode = .onDrag
        searchBar.delegate = self
        searchBar.returnKeyType = .search
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        currentQuery = ""
        results = []
        tableView.reloadData()
        searchBar.resignFirstResponder()
    }
    
    // MARK: - IBActions (wired from Storyboard)
    @IBAction func refreshPulled(_ sender: UIRefreshControl) {
        guard !currentQuery.isEmpty else {
            sender.endRefreshing()
            return
        }
        runSearch(query: currentQuery, brand: currentBrand)
    }
    
    @IBAction func brandTapped(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "brand filter", message: "optional", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "e.g., “olly”"
            tf.autocapitalizationType = .words
            tf.text = self.currentBrand
        }
        alert.addAction(UIAlertAction(title: "clear", style: .destructive) { _ in
            self.currentBrand = nil
            if !self.currentQuery.isEmpty {
                self.runSearch(query: self.currentQuery,
                               brand: nil)
            }
        })
        alert.addAction(UIAlertAction(title: "apply", style: .default) { _ in
            self.currentBrand = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            if !self.currentQuery.isEmpty {
                self.runSearch(query: self.currentQuery,
                               brand: self.currentBrand)
            }
        })
        present(alert, animated: true)
    }
    
    @IBAction func sortTapped(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "sort", message: nil, preferredStyle: .actionSheet)
        func add(_ title: String, _ by: String, _ order: String) {
            let isCurrent = (by == sortBy && order == sortOrder)
            alert.addAction(UIAlertAction(title: title + (isCurrent ? " ✓" : ""), style: .default) { _ in
                self.sortBy = by
                self.sortOrder = order
                if !self.currentQuery.isEmpty {
                    self.runSearch(query: self.currentQuery,
                                   brand: self.currentBrand)
                }
            })
        }
        add("Best match", "_score", "desc")
        add("Newest", "entryDate", "desc")
        add("Name A→Z", "fullName.keyword", "asc")
        add("Name Z→A", "fullName.keyword", "desc")
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @IBAction func statusTapped(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "status", message: "which labels to include", preferredStyle: .actionSheet)
        let set: [(String, String)] = [("All", "2"), ("On-market", "1"), ("Off-market", "0")]
        for (title, value) in set {
            alert.addAction(UIAlertAction(title: title + (value == currentStatus ? " ✓" : ""), style: .default) { _ in
                self.currentStatus = value
                if !self.currentQuery.isEmpty {
                    self.runSearch(query: self.currentQuery,
                                   brand: self.currentBrand)
                }
            })
        }
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Networking
    private func buildQuery(from raw: String) -> String {
        var parts: [String] = []
        
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let tokens = trimmed
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        
        // dose pattern: 600mg, 200 mcg, 10,000 iu, etc.
        let dosePattern = try! NSRegularExpression(
            pattern: #"^\d{1,3}(?:,\d{3})*(?:\.\d+)?\s?(?:mg|mcg|iu|g|ug|μg)$"#,
            options: .caseInsensitive
        )
        
        func isDose(_ t: String) -> Bool {
            let ns = t as NSString
            return dosePattern.firstMatch(in: t, options: [], range: NSRange(location: 0, length: ns.length)) != nil
        }
        
        // 1) original string as a quoted phrase to help exact phrase hits
        if trimmed.contains(" ") {
            parts.append("\"\(trimmed)\"")
        } else {
            parts.append(trimmed)
        }
        
        // 2) keep dose tokens explicit (helps relevance)
        for t in tokens where isDose(t) {
            parts.append(t)
        }
        
        // De-dupe while preserving order
        var seen = Set<String>()
        let dedup = parts.filter { seen.insert($0).inserted }
        
        return dedup.joined(separator: " ")
    }
    
    private func runSearch(query raw: String, brand: String? = nil) {
        let q = buildQuery(from: raw)
        currentQuery = raw
        guard !q.isEmpty else { results = []; tableView.reloadData(); return }
        
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.path = baseURL.appendingPathComponent("api/labels").path   // <- IMPORTANT
        var items: [URLQueryItem] = [
            .init(name: "q", value: q),
            .init(name: "size", value: "20"),
            .init(name: "status", value: currentStatus),   // "1" for on‑market
            .init(name: "sort_by", value: sortBy),
            .init(name: "sort_order", value: sortOrder),
        ]
        if let b = brand, !b.isEmpty { items.append(.init(name: "brand", value: b)) }
        comps.queryItems = items
        
#if DEBUG
        print("SEARCH URL:", comps.url?.absoluteString ?? "")
#endif
        
        isLoading = true
        let req = URLRequest(url: comps.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        URLSession.shared.dataTask(with: req) { [weak self] data, response, err in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                self.refreshControl?.endRefreshing()
            }
            if let err = err {
#if DEBUG
                print("SEARCH ERROR:", err)
#endif
                return
            }
            guard let data = data else { return }
            do {
                let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                DispatchQueue.main.async { self.results = decoded.items; self.tableView.reloadData() }
            } catch {
#if DEBUG
                print("DECODING ERROR:", error)
                print(String(data: data, encoding: .utf8) ?? "<non-utf8>")
#endif
            }
        }.resume()
    }
    
    
    // MARK: - Table
    
    private func makeMessageCell(_ tableView: UITableView, _ text: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ItemCell")
        cell.textLabel?.text = text
        cell.textLabel?.textAlignment = .center
        cell.detailTextLabel?.text = nil
        cell.selectionStyle = .none
        cell.accessoryType = .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading { return max(results.count, 1) }
        if results.isEmpty {
            return currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1
        }
        return results.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading && results.isEmpty {
            return makeMessageCell(tableView, "searching…")
        }
        if results.isEmpty {
            let emptyQuery = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return makeMessageCell(tableView, emptyQuery ? "start a search" : "no results")
        }
        
        let item = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
        cell.textLabel?.text = item.fullName ?? "(unknown)"
        let subtitleBits = [item.brandName, item.productType].compactMap { $0 }.filter { !$0.isEmpty }
        cell.detailTextLabel?.text = subtitleBits.isEmpty ? nil : subtitleBits.joined(separator: " • ")
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !results.isEmpty else { return }
        let item = results[indexPath.row]
        
        let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "ItemDetailViewController") as! ItemDetailViewController
        vc.labelID = item.id
        vc.prefilledTitle = item.fullName
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UISearchBarDelegate (debounce typing)
extension ItemsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentQuery = searchText
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
            self.runSearch(query: searchText,
                           brand: self.currentBrand)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        debounceTimer?.invalidate()
        runSearch(query: currentQuery,
                  brand: currentBrand)
        searchBar.resignFirstResponder()
    }
}
