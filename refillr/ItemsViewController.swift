import UIKit

// MARK: - Supplement Models
struct LabelItem: Decodable {
    let id: String
    let fullName: String?
    let brandName: String?
    let entryDate: String?
    let productType: String?
}

private struct SearchResponse: Decodable {
    let items: [LabelItem]
    let total: Int
}

// MARK: - Medication Models
private struct DrugAPIResponse: Decodable {
    let results: [DrugAPIItem]?
}

private struct DrugAPIItem: Decodable {
    let set_id: String
    let openfda: OpenFDAInfo?
    let dosage_and_administration: [String]?
    let indications_and_usage: [String]?
    let description: [String]?
    let purpose: [String]?
    let warnings: [String]?
    let precautions: [String]?
    let stop_use: [String]?
    
    func toResult() -> DrugResult {
        let brand = openfda?.brand_name?.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let generic = openfda?.generic_name?.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let manufacturer = openfda?.manufacturer_name?.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let route = openfda?.route?.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let substance = openfda?.substance_name?.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let title = [brand, generic, substance].compactMap { $0 }.first ?? "Medication"
        let dosage = dosage_and_administration?.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        var summary: [String] = []
        if let generic, generic.caseInsensitiveCompare(title) != .orderedSame {
            summary.append("generic: \(generic)")
        }
        if let manufacturer, !manufacturer.isEmpty {
            summary.append("manufacturer: \(manufacturer)")
        }
        if let route, !route.isEmpty {
            summary.append("route: \(route)")
        }
        
        var detailCandidates: [String] = []
        if let purpose { detailCandidates.append(contentsOf: purpose) }
        if let indications_and_usage { detailCandidates.append(contentsOf: indications_and_usage) }
        if let description { detailCandidates.append(contentsOf: description) }
        if let warnings { detailCandidates.append(contentsOf: warnings) }
        if let precautions { detailCandidates.append(contentsOf: precautions) }
        if let stop_use { detailCandidates.append(contentsOf: stop_use) }
        let detail = detailCandidates
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        
        var notesComponents: [String] = summary
        if let detail, !detail.isEmpty {
            notesComponents.append(detail)
        }
        let notes = notesComponents.isEmpty ? nil : notesComponents.joined(separator: "\n\n")
        
        return DrugResult(id: set_id,
                          title: title,
                          brand: brand,
                          generic: generic,
                          manufacturer: manufacturer,
                          route: route,
                          dosage: dosage,
                          notes: notes)
    }
}

private struct OpenFDAInfo: Decodable {
    let brand_name: [String]?
    let generic_name: [String]?
    let manufacturer_name: [String]?
    let route: [String]?
    let substance_name: [String]?
}

private struct DrugResult {
    let id: String
    let title: String
    let brand: String?
    let generic: String?
    let manufacturer: String?
    let route: String?
    let dosage: String?
    let notes: String?
}

// MARK: - ItemsViewController
final class ItemsViewController: UITableViewController {
    
    // MARK: - Outlets
    @IBOutlet var searchBar: UISearchBar!
    @IBOutlet weak var brandButton: UIBarButtonItem?
    @IBOutlet weak var sortButton: UIBarButtonItem?
    @IBOutlet weak var statusButton: UIBarButtonItem?
    
    // MARK: - Types
    private enum Mode {
        case browse
        case add
    }
    
    private enum Section: Int, CaseIterable {
        case supplements = 0
        case medications = 1
    }
    
    // MARK: - Constants
    private let baseURL: URL = AppConfig.proxyBaseURL
    private let openFDAKey = "TXm9X1zEjZEcMtvjauSdB3q44XPzUksN8elnZAEw"
    private let openFDABaseURL = URL(string: "https://api.fda.gov/drug/label.json")!
    
    // MARK: - State
    private var mode: Mode = .browse {
        didSet {
            guard mode != oldValue else { return }
            configureForMode(animated: true)
        }
    }
    
    private var localItems: [RefillItem] = []
    private var supplementResults: [LabelItem] = []
    private var drugResults: [DrugResult] = []
    
    private var debounceTimer: Timer?
    private var isLoadingSupplements = false {
        didSet { if mode == .add { updateBackgroundView() } }
    }
    private var isLoadingDrugs = false {
        didSet { if mode == .add { updateBackgroundView() } }
    }
    private var isLoadingAny: Bool { isLoadingSupplements || isLoadingDrugs }
    
    private var currentQuery: String = ""
    private var currentBrand: String?
    private var currentStatus: String = "1"
    private var sortBy: String = "_score"
    private var sortOrder: String = "desc"
    
    private var trimmedQuery: String {
        currentQuery.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    // MARK: - UI Helpers
    private lazy var addBarButton = UIBarButtonItem(barButtonSystemItem: .add,
                                                    target: self,
                                                    action: #selector(addTapped))
    private lazy var cancelBarButton = UIBarButtonItem(barButtonSystemItem: .close,
                                                       target: self,
                                                       action: #selector(cancelTapped))
    private lazy var createCustomBarButton = UIBarButtonItem(title: "Custom",
                                                             style: .plain,
                                                             target: self,
                                                             action: #selector(createCustomTapped))
    private lazy var addPlaceholderView: UIView = ItemsViewController.makeBackgroundView(
        text: "Create a custom item or search for it above."
    )
    private lazy var emptyBrowseView: UIView = ItemsViewController.makeBackgroundView(
        text: "No items yet. Tap + to add one."
    )
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "items"
        tableView.keyboardDismissMode = .onDrag
        searchBar.delegate = self
        searchBar.returnKeyType = .search
        searchBar.showsCancelButton = false
        searchBar.showsBookmarkButton = false
        searchBar.showsSearchResultsButton = false
        removeSearchHeader()
        navigationItem.rightBarButtonItem = addBarButton
        configureForMode(animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            await self?.refreshLocalItems()
        }
    }
    
    // MARK: - Mode Handling
    private func configureForMode(animated: Bool) {
        let updates = {
            switch self.mode {
            case .browse:
                self.navigationItem.rightBarButtonItem = self.addBarButton
                self.navigationItem.leftBarButtonItem = nil
                self.brandButton?.isEnabled = false
                self.sortButton?.isEnabled = false
                self.statusButton?.isEnabled = false
                self.removeSearchHeader()
                self.resetSearchState()
            case .add:
                self.navigationItem.rightBarButtonItem = self.cancelBarButton
                self.navigationItem.leftBarButtonItem = self.createCustomBarButton
                self.brandButton?.isEnabled = true
                self.sortButton?.isEnabled = true
                self.statusButton?.isEnabled = true
                self.addSearchHeader()
                self.resetSearchState()
            }
            self.tableView.reloadData()
            self.updateBackgroundView()
        }
        
        if animated {
            UIView.performWithoutAnimation {
                updates()
                self.tableView.layoutIfNeeded()
            }
        } else {
            updates()
        }
        
        if mode == .add {
            DispatchQueue.main.async { [weak self] in
                self?.searchBar.becomeFirstResponder()
            }
        } else {
            searchBar.resignFirstResponder()
        }
    }
    
    private func resetSearchState() {
        supplementResults = []
        drugResults = []
        isLoadingSupplements = false
        isLoadingDrugs = false
        currentQuery = ""
        currentBrand = nil
        searchBar.text = ""
        searchBar.showsCancelButton = (mode == .add)
    }
    
    private func updateBackgroundView() {
        switch mode {
        case .browse:
            tableView.backgroundView = localItems.isEmpty ? emptyBrowseView : nil
        case .add:
            let trimmed = trimmedQuery
            if trimmed.isEmpty && !isLoadingAny && supplementResults.isEmpty && drugResults.isEmpty {
                tableView.backgroundView = addPlaceholderView
            } else {
                tableView.backgroundView = nil
            }
        }
    }
    
    private func addSearchHeader() {
        guard tableView.tableHeaderView !== searchBar else { return }
        searchBar.sizeToFit()
        tableView.tableHeaderView = searchBar
    }
    
    private func removeSearchHeader() {
        if tableView.tableHeaderView != nil {
            tableView.tableHeaderView = nil
        }
    }
    
    // MARK: - Data Loading
    @MainActor
    private func refreshLocalItems() async {
        do {
            let items = try await DataManager.shared.fetchAll()
            localItems = items.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } catch {
#if DEBUG
            print("Local store load error:", error)
#endif
            localItems = []
        }
        if mode == .browse {
            tableView.reloadData()
            updateBackgroundView()
        }
    }
    
    // MARK: - Actions
    @objc private func addTapped() {
        mode = .add
    }
    
    @objc private func cancelTapped() {
        mode = .browse
    }
    
    @objc private func createCustomTapped() {
        guard mode == .add else { return }
        let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "ItemDetailViewController") as! ItemDetailViewController
        vc.configureForNewItem(defaultTimeOfDay: RefillItem.TimeOfDay.morning,
                                labelID: nil,
                                title: nil,
                                brand: nil,
                                dosage: nil,
                                notes: nil,
                                timeOfDayTitle: RefillItem.TimeOfDay.morning.title) { [weak self] (_: RefillItem) in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                await self.refreshLocalItems()
                await MainActor.run {
                    self.mode = .browse
                }
            }
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        resetSearchState()
        tableView.reloadData()
        mode = .browse
    }
    
    @IBAction func refreshPulled(_ sender: UIRefreshControl) {
        guard mode == .add, !trimmedQuery.isEmpty else {
            sender.endRefreshing()
            return
        }
        runSearch(query: currentQuery, brand: currentBrand)
    }
    
    @IBAction func brandTapped(_ sender: UIBarButtonItem) {
        guard mode == .add else { return }
        let alert = UIAlertController(title: "brand filter", message: "optional", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "e.g., “olly”"
            tf.autocapitalizationType = .words
            tf.text = self.currentBrand
        }
        alert.addAction(UIAlertAction(title: "clear", style: .destructive) { _ in
            self.currentBrand = nil
            if !self.trimmedQuery.isEmpty {
                self.runSearch(query: self.currentQuery, brand: nil)
            }
        })
        alert.addAction(UIAlertAction(title: "apply", style: .default) { _ in
            self.currentBrand = alert.textFields?.first?.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !self.trimmedQuery.isEmpty {
                self.runSearch(query: self.currentQuery, brand: self.currentBrand)
            }
        })
        present(alert, animated: true)
    }
    
    @IBAction func sortTapped(_ sender: UIBarButtonItem) {
        guard mode == .add else { return }
        let alert = UIAlertController(title: "sort", message: nil, preferredStyle: .actionSheet)
        func addAction(_ title: String, by: String, order: String) {
            let isCurrent = (by == sortBy && order == sortOrder)
            alert.addAction(UIAlertAction(title: title + (isCurrent ? " ✓" : ""), style: .default) { _ in
                self.sortBy = by
                self.sortOrder = order
                if !self.trimmedQuery.isEmpty {
                    self.runSearch(query: self.currentQuery, brand: self.currentBrand)
                }
            })
        }
        addAction("Best match", by: "_score", order: "desc")
        addAction("Newest", by: "entryDate", order: "desc")
        addAction("Name A→Z", by: "fullName.keyword", order: "asc")
        addAction("Name Z→A", by: "fullName.keyword", order: "desc")
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @IBAction func statusTapped(_ sender: UIBarButtonItem) {
        guard mode == .add else { return }
        let options: [(String, String)] = [("All", "2"), ("On-market", "1"), ("Off-market", "0")]
        let alert = UIAlertController(title: "status", message: "which labels to include", preferredStyle: .actionSheet)
        for (title, value) in options {
            alert.addAction(UIAlertAction(title: title + (value == currentStatus ? " ✓" : ""), style: .default) { _ in
                self.currentStatus = value
                if !self.trimmedQuery.isEmpty {
                    self.runSearch(query: self.currentQuery, brand: self.currentBrand)
                }
            })
        }
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Networking
    private func buildQuery(from raw: String) -> String {
        var parts: [String] = []
        
        let trimmed = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let tokens = trimmed
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        
        let dosePattern = try! NSRegularExpression(
            pattern: #"^\d{1,3}(?:,\d{3})*(?:\.\d+)?\s?(?:mg|mcg|iu|g|ug|μg)$"#,
            options: .caseInsensitive
        )
        
        func isDose(_ t: String) -> Bool {
            let ns = t as NSString
            return dosePattern.firstMatch(in: t, options: [], range: NSRange(location: 0, length: ns.length)) != nil
        }
        
        if trimmed.contains(" ") {
            parts.append("\"\(trimmed)\"")
        } else {
            parts.append(trimmed)
        }
        
        for token in tokens where isDose(token) {
            parts.append(token)
        }
        
        var seen = Set<String>()
        return parts.filter { seen.insert($0).inserted }.joined(separator: " ")
    }
    
    private func runSearch(query raw: String, brand: String? = nil) {
        guard mode == .add else { return }
        currentQuery = raw
        let trimmed = trimmedQuery
        
        if trimmed.isEmpty {
            resetSearchState()
            tableView.reloadData()
            updateBackgroundView()
            return
        }
        
        let supplementQuery = buildQuery(from: raw)
        supplementResults = []
        drugResults = []
        tableView.reloadData()
        
        if supplementQuery.isEmpty {
            isLoadingSupplements = false
        } else {
            isLoadingSupplements = true
            performSupplementSearch(query: supplementQuery, brand: brand)
        }
        
        isLoadingDrugs = true
        performDrugSearch(rawQuery: trimmed)
        updateBackgroundView()
    }
    
    private func performSupplementSearch(query q: String, brand: String?) {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.path = baseURL.appendingPathComponent("api/labels").path
        var items: [URLQueryItem] = [
            .init(name: "q", value: q),
            .init(name: "size", value: "20"),
            .init(name: "status", value: currentStatus),
            .init(name: "sort_by", value: sortBy),
            .init(name: "sort_order", value: sortOrder)
        ]
        if let brand, !brand.isEmpty {
            items.append(.init(name: "brand", value: brand))
        }
        comps.queryItems = items
        
        guard let url = comps.url else {
            DispatchQueue.main.async {
                self.isLoadingSupplements = false
                self.refreshControl?.endRefreshing()
            }
            return
        }
        
#if DEBUG
        print("SUPPLEMENT SEARCH URL:", url.absoluteString)
#endif
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoadingSupplements = false
                self.refreshControl?.endRefreshing()
            }
            if let error {
#if DEBUG
                print("Supplement search error:", error)
#endif
                return
            }
            guard let data else { return }
            do {
                let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                DispatchQueue.main.async {
                    self.supplementResults = decoded.items
                    self.tableView.reloadData()
                    self.updateBackgroundView()
                }
            } catch {
#if DEBUG
                print("Supplement decoding error:", error)
                print(String(data: data, encoding: .utf8) ?? "<non-utf8>")
#endif
                DispatchQueue.main.async {
                    self.supplementResults = []
                    self.tableView.reloadData()
                    self.updateBackgroundView()
                }
            }
        }.resume()
    }
    
    private func performDrugSearch(rawQuery: String) {
        var comps = URLComponents(url: openFDABaseURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "api_key", value: openFDAKey),
            .init(name: "search", value: "\"\(rawQuery)\""),
            .init(name: "limit", value: "15")
        ]
        
        guard let url = comps.url else {
            DispatchQueue.main.async {
                self.isLoadingDrugs = false
                self.refreshControl?.endRefreshing()
            }
            return
        }
        
#if DEBUG
        print("OPENFDA SEARCH URL:", url.absoluteString)
#endif
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                DispatchQueue.main.async {
                    self.isLoadingDrugs = false
                    self.drugResults = []
                    self.tableView.reloadData()
                    self.updateBackgroundView()
                }
                return
            }
            if let error {
#if DEBUG
                print("Medication search error:", error)
#endif
                DispatchQueue.main.async {
                    self.isLoadingDrugs = false
                    self.updateBackgroundView()
                }
                return
            }
            guard let data else {
                DispatchQueue.main.async {
                    self.isLoadingDrugs = false
                    self.updateBackgroundView()
                }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(DrugAPIResponse.self, from: data)
                let mapped = decoded.results?.map { $0.toResult() } ?? []
                DispatchQueue.main.async {
                    self.isLoadingDrugs = false
                    self.drugResults = mapped
                    self.tableView.reloadData()
                    self.updateBackgroundView()
                }
            } catch {
#if DEBUG
                print("Medication decoding error:", error)
                print(String(data: data, encoding: .utf8) ?? "<non-utf8>")
#endif
                DispatchQueue.main.async {
                    self.isLoadingDrugs = false
                    self.drugResults = []
                    self.tableView.reloadData()
                    self.updateBackgroundView()
                }
            }
        }.resume()
    }
    
    // MARK: - Table View Data Source
    override func numberOfSections(in tableView: UITableView) -> Int {
        switch mode {
        case .browse:
            return 1
        case .add:
            return Section.allCases.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard mode == .add, let sectionKind = Section(rawValue: section) else { return nil }
        let hasQuery = !trimmedQuery.isEmpty
        switch sectionKind {
        case .supplements:
            if !supplementResults.isEmpty || isLoadingSupplements || hasQuery {
                return "supplements"
            }
            return nil
        case .medications:
            if !drugResults.isEmpty || isLoadingDrugs || hasQuery {
                return "medications"
            }
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch mode {
        case .browse:
            return localItems.count
        case .add:
            let trimmed = trimmedQuery
            guard let sectionKind = Section(rawValue: section) else { return 0 }
            if trimmed.isEmpty {
                return 0
            }
            switch sectionKind {
            case .supplements:
                if isLoadingSupplements && supplementResults.isEmpty { return 1 }
                if supplementResults.isEmpty { return 1 }
                return supplementResults.count
            case .medications:
                if isLoadingDrugs && drugResults.isEmpty { return 1 }
                if drugResults.isEmpty { return 1 }
                return drugResults.count
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch mode {
        case .browse:
            let item = localItems[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
            cell.textLabel?.text = item.name
            var details: [String] = []
            if let brand = item.brand, !brand.isEmpty { details.append(brand) }
            if let dose = item.doseText, !dose.isEmpty { details.append(dose) }
            details.append(item.timeOfDay.title)
            cell.detailTextLabel?.text = details.joined(separator: " • ")
            cell.accessoryType = .disclosureIndicator
            return cell
        case .add:
            guard let sectionKind = Section(rawValue: indexPath.section) else {
                return makeMessageCell(tableView, "—")
            }
            let trimmed = trimmedQuery
            switch sectionKind {
            case .supplements:
                if isLoadingSupplements && supplementResults.isEmpty {
                    return makeMessageCell(tableView, "searching…")
                }
                if supplementResults.isEmpty {
                    let message = trimmed.isEmpty ? "start a search" : "no supplement matches"
                    return makeMessageCell(tableView, message)
                }
                let item = supplementResults[indexPath.row]
                let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
                cell.textLabel?.text = item.fullName ?? "(unknown)"
                let subtitleBits = [item.brandName, item.productType].compactMap { $0 }.filter { !$0.isEmpty }
                cell.detailTextLabel?.text = subtitleBits.isEmpty ? nil : subtitleBits.joined(separator: " • ")
                cell.accessoryType = .disclosureIndicator
                return cell
            case .medications:
                if isLoadingDrugs && drugResults.isEmpty {
                    return makeMessageCell(tableView, "searching…")
                }
                if drugResults.isEmpty {
                    let message = trimmed.isEmpty ? "start a search" : "no medication matches"
                    return makeMessageCell(tableView, message)
                }
                let item = drugResults[indexPath.row]
                let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
                cell.textLabel?.text = item.title
                var subtitle: [String] = []
                if let brand = item.brand, !brand.isEmpty { subtitle.append(brand) }
                if let generic = item.generic, !generic.isEmpty, generic.caseInsensitiveCompare(item.title) != .orderedSame {
                    subtitle.append(generic)
                }
                if let route = item.route, !route.isEmpty { subtitle.append(route) }
                cell.detailTextLabel?.text = subtitle.isEmpty ? item.manufacturer : subtitle.joined(separator: " • ")
                cell.accessoryType = .disclosureIndicator
                return cell
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch mode {
        case .browse:
            let item = localItems[indexPath.row]
            let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
            let vc = sb.instantiateViewController(withIdentifier: "ItemDetailViewController") as! ItemDetailViewController
            vc.prefilledTitle = item.name
            vc.prefilledBrand = item.brand
            vc.prefilledServing = item.doseText
            vc.prefilledType = item.timeOfDay.title
            vc.labelID = item.labelID ?? ""
            vc.refillItem = item
            navigationController?.pushViewController(vc, animated: true)
        case .add:
            guard let sectionKind = Section(rawValue: indexPath.section) else { return }
            switch sectionKind {
            case .supplements:
                guard !supplementResults.isEmpty else { return }
                let item = supplementResults[indexPath.row]
                let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
                let vc = sb.instantiateViewController(withIdentifier: "ItemDetailViewController") as! ItemDetailViewController
                let notes = item.entryDate.flatMap { $0.isEmpty ? nil : "entry date: \($0)" }
                vc.configureForNewItem(defaultTimeOfDay: RefillItem.TimeOfDay.morning,
                                        labelID: item.id,
                                        title: item.fullName,
                                        brand: item.brandName,
                                        dosage: nil,
                                        notes: notes,
                                        timeOfDayTitle: RefillItem.TimeOfDay.morning.title) { [weak self] (_: RefillItem) in
                    guard let self else { return }
                    Task { [weak self] in
                        guard let self else { return }
                        await self.refreshLocalItems()
                        await MainActor.run {
                            self.mode = .browse
                        }
                    }
                }
                navigationController?.pushViewController(vc, animated: true)
            case .medications:
                guard !drugResults.isEmpty else { return }
                let item = drugResults[indexPath.row]
                let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
                let vc = sb.instantiateViewController(withIdentifier: "ItemDetailViewController") as! ItemDetailViewController
                let brand = item.brand ?? item.manufacturer ?? item.generic
                vc.configureForNewItem(defaultTimeOfDay: RefillItem.TimeOfDay.morning,
                                        labelID: nil,
                                        title: item.title,
                                        brand: brand,
                                        dosage: item.dosage,
                                        notes: item.notes,
                                        timeOfDayTitle: RefillItem.TimeOfDay.morning.title) { [weak self] (_: RefillItem) in
                    guard let self else { return }
                    Task { [weak self] in
                        guard let self else { return }
                        await self.refreshLocalItems()
                        await MainActor.run {
                            self.mode = .browse
                        }
                    }
                }
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    // MARK: - Helpers
    private func makeMessageCell(_ tableView: UITableView, _ text: String) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ItemCell")
        cell.textLabel?.text = text
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = nil
        cell.selectionStyle = .none
        cell.accessoryType = .none
        return cell
    }
    
    private static func makeBackgroundView(text: String) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
        ])
        return container
    }
}

// MARK: - UISearchBarDelegate
extension ItemsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard mode == .add else { return }
        currentQuery = searchText
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.runSearch(query: searchText, brand: self.currentBrand)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard mode == .add else { return }
        debounceTimer?.invalidate()
        runSearch(query: currentQuery, brand: currentBrand)
        searchBar.resignFirstResponder()
    }
}
