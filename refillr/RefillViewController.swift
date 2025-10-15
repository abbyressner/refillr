//
//  RefillViewController.swift
//  refillr
//
//  Created by Abby Ressner on 8/6/25.
//

import UIKit

final class RefillViewController: UITableViewController, RefillCellDelegate {
    
    private var sections: [[RefillItem]] = RefillViewController.emptySections()
    private let sectionTitles = RefillItem.TimeOfDay.allCases.map { $0.title }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "refill"
        tableView.keyboardDismissMode = .onDrag
        Task { [weak self] in
            await self?.reloadFromStore()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            await self?.reloadFromStore()
        }
    }
    
    @MainActor
    private func reloadFromStore() async {
        do {
            let all = try await DataManager.shared.fetchAll()
            sections = RefillViewController.groupedSections(for: all)
        } catch {
#if DEBUG
            print("Local store load error:", error)
#endif
            sections = RefillViewController.emptySections()
        }
        tableView.reloadData()
    }
    
    // MARK: - RefillCellDelegate
    func refillCellDidToggle(_ cell: RefillCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        sections[indexPath.section][indexPath.row].checked.toggle()
        let item = sections[indexPath.section][indexPath.row]
        
        Task {
            do {
                try await DataManager.shared.upsert(item)
            } catch {
#if DEBUG
                print("Local store save error:", error)
#endif
                // Optional: revert UI or show a lightweight error
            }
        }
    }
    
    // MARK: - Table Data Source
    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sectionTitles[section] }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].count }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section][indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "RefillCell", for: indexPath) as! RefillCell
#if DEBUG
        print("Dequeued:", type(of: cell),
              "title nil?", cell.titleLabel == nil,
              "subtitle nil?", cell.subtitleLabel == nil,
              "btn nil?", cell.checkboxButton == nil)
#endif
        let subtitleBits = [item.brand, item.doseText].compactMap { $0 }.filter { !$0.isEmpty }
        cell.configure(title: item.name,
                       subtitle: subtitleBits.isEmpty ? nil : subtitleBits.joined(separator: " • "),
                       checked: item.checked)
        cell.delegate = self
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section][indexPath.row]
        pushDetail(for: item)
    }
    
    private func pushDetail(for item: RefillItem) {
        let sb = storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "ItemDetailViewController") as! ItemDetailViewController
        vc.prefilledTitle = item.name
        vc.labelID = item.labelID ?? ""
        vc.prefilledBrand = item.brand
        vc.prefilledServing = item.doseText
        vc.prefilledType = item.timeOfDay.title
        vc.refillItem = item
        navigationController?.pushViewController(vc, animated: true)
    }
    
//    @IBAction func resetTapped(_ sender: UIBarButtonItem) {
//        for s in 0..<sections.count {
//            for r in 0..<sections[s].count {
//                sections[s][r].checked = false
//            }
//        }
//        // CloudKit-only: persist each change
//        Task {
//            for group in sections {
//                for item in group {
//                    try? await DataManager.shared.upsert(item)
//                }
//            }
//        }
//        tableView.reloadData()
//    }
}

private extension RefillViewController {
    static func emptySections() -> [[RefillItem]] {
        RefillItem.TimeOfDay.allCases.map { _ in [] }
    }
    
    static func groupedSections(for items: [RefillItem]) -> [[RefillItem]] {
        RefillItem.TimeOfDay.allCases.map { tod in
            items
                .filter { $0.timeOfDay == tod }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}
