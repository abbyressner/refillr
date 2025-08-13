//
//  ItemsViewController.swift
//  refillr
//
//  Created by Abby Ressner on 8/7/25.
//

import Foundation
import UIKit

class ItemsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func scanTapped(_ sender: UIBarButtonItem) {
        startScan()
    }
    private var labels: [DSLDLabel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
    }
    
    @objc private func startScan() {
        let scanner = BarcodeScannerViewController()
        scanner.delegate = self
        present(scanner, animated: true)
    }
    
    private func fetchLabel(for barcode: String) {
        let apiKey = "3zpXiKbop0Roxp76goEND2VRQqKhB5erJELAAV9M"
        let urlStr = "https://dsld-dev-web.app.cloud.gov/api/labels?barcode=\(barcode)&api_key=\(apiKey)"
        guard let url = URL(string: urlStr) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data else { return }
            do {
                let response = try JSONDecoder().decode([DSLDLabel].self, from: data)
                DispatchQueue.main.async {
                    self.labels = response
                    self.tableView.reloadData()
                }
            } catch {
                print("DSLD parse error:", error)
            }
        }.resume()
    }
}

extension ItemsViewController: BarcodeScannerDelegate {
    func scanner(_ controller: BarcodeScannerViewController, didScan code: String) {
        controller.dismiss(animated: true) {
            self.fetchLabel(for: code)
        }
    }
}

extension ItemsViewController: UITableViewDataSource {
    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        labels.count
    }
    
    func tableView(_ tv: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "LabelCell")
        ?? UITableViewCell(style: .subtitle, reuseIdentifier: "LabelCell")
        let label = labels[indexPath.row]
        cell.textLabel?.text = label.productName
        cell.detailTextLabel?.text = label.manufacturer
        return cell
    }
}
