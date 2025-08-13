//
//  RefillViewController.swift
//  refillr
//
//  Created by Abby Ressner on 8/6/25.
//

import UIKit

struct RefillItem: Codable {
    let name: String
    var checked: Bool
}

enum RefillPeriod: Int, CaseIterable {
    case morning, afternoon, evening
    var title: String {
        ["morning","afternoon","evening"][rawValue]
    }
}

class RefillViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    var itemsByPeriod = DataManager.shared.loadItems()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate   = self
    }
    
    @objc func toggleCheck(_ sender: UIButton) {
        let section = sender.tag / 100
        let row     = sender.tag % 100
        
        // toggle in-memory
        itemsByPeriod[section][row].checked.toggle()
        
        // persist immediately
        DataManager.shared.saveItems(itemsByPeriod)
        
        // update UI
        tableView.reloadRows(
            at: [IndexPath(row: row, section: section)],
            with: .automatic
        )
    }
}

extension RefillViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        RefillPeriod.allCases.count
    }
    
    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        itemsByPeriod[section].count
    }
    
    func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        RefillPeriod(rawValue: section)?.title
    }
    
    func tableView(_ tv: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "RefillCell",
                                          for: indexPath) as! RefillCell
        let item = itemsByPeriod[indexPath.section][indexPath.row]
        cell.nameLabel.text = item.name
        let symbol = item.checked ? "☑︎" : "☐"
        cell.checkButton.setTitle(symbol, for: .normal)
        cell.checkButton.tag = indexPath.section * 100 + indexPath.row
        cell.checkButton.addTarget(self,
                                   action: #selector(toggleCheck(_:)),
                                   for: .touchUpInside)
        return cell
    }
}

extension RefillViewController: UITableViewDelegate {
    // optional: styling, row height, etc.
}
