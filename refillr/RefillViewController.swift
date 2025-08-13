//
//  RefillViewController.swift
//  refillr
//
//  Created by Abby Ressner on 8/6/25.
//

import UIKit

final class RefillViewController: UITableViewController, RefillCellDelegate {
    
    private var sections: [[RefillItem]] = []
    private let sectionTitles = RefillItem.TimeOfDay.allCases.map { $0.title }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "refill"
        tableView.keyboardDismissMode = .onDrag
        reloadFromStore()
    }
    
    private func reloadFromStore() {
        //let all: [RefillItem] = DataManager.shared.loadRefillItems()
        let seed: [RefillItem] = [
            .make(name: "Turmeric", brand: "Himalaya", dose: "500 mg", time: .morning, labelID: "40405"),
            .make(name: "Vitamin D3", brand: "NOW Foods", dose: "2000 IU", time: .morning, labelID: "12245"),
            .make(name: "Magnesium L-Threonate", brand: "Life Extension", dose: "750 mg", time: .evening),
            .make(name: "Ashwagandha", brand: "KSM-66", dose: "600 mg", time: .evening, labelID: "33501"),
            .make(name: "Fish Oil", brand: "Nordic Naturals", dose: "1000 mg", time: .afternoon, labelID: "21004")
        ]
        sections = RefillItem.TimeOfDay.allCases.map { tod in
            seed.filter { $0.timeOfDay == tod }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        tableView.reloadData()
    }
    
    // MARK: - RefillCellDelegate
    func refillCellDidToggle(_ cell: RefillCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        sections[indexPath.section][indexPath.row].checked.toggle()
        DataManager.shared.saveRefillItems(sections.flatMap { $0 })
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
        navigationController?.pushViewController(vc, animated: true)
    }
    
//    @IBAction func resetTapped(_ sender: UIBarButtonItem) {
//        for s in 0..<sections.count {
//            for r in 0..<sections[s].count {
//                sections[s][r].checked = false
//            }
//        }
//        DataManager.shared.saveRefillItems(sections.flatMap { $0 })
//        tableView.reloadData()
//    }
}
