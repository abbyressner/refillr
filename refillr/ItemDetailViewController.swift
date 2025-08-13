//
//  ItemDetailViewController.swift
//  refillr
//
//  Created by Abby Ressner on 8/8/25.
//

import UIKit

// MARK: - Models
struct LabelDetail: Decodable {
    let id: Int?
    let fullName: String?
    let brandName: String?
    let upcSku: String?
    let entryDate: String?
    let productType: ProductType?
    let pdf: String?
    let thumbnail: String?
    let servingSizes: [ServingSize]?
    
    struct ProductType: Decodable {
        let langualCodeDescription: String?
    }
    struct ServingSize: Decodable {
        let minQuantity: Double?
        let maxQuantity: Double?
        let unit: String?
        let notes: String?
    }
}

final class ItemDetailViewController: UIViewController {
    
    var labelID: String = ""
    var prefilledTitle: String?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var brandLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var servingLabel: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var notesTextView: UITextView!
    
    private let baseURL: URL = AppConfig.proxyBaseURL
    private var detail: LabelDetail?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "item"
        configureInitialUI()
        fetchDetail()
        //setupNavBarButtons()
    }
    
    private func configureInitialUI() {
        titleLabel.text = prefilledTitle ?? "loading…"
        brandLabel.text = nil
        typeLabel.text = nil
        servingLabel.text = nil
        notesTextView.text = nil
        spinner.startAnimating()
    }
    
//    private func setupNavBarButtons() {
//        let addBtn = UIBarButtonItem(systemItem: .add)
//        addBtn.target = self
//        addBtn.action = #selector(addTapped)
//        navigationItem.rightBarButtonItem = addBtn
//    }
    
//    @objc private func addTapped() {
//        // TODO: create item in local JSON / favorites, etc.
//        let alert = UIAlertController(
//            title: "coming soon",
//            message: "add to favorites / create item",
//            preferredStyle: .alert
//        )
//        alert.addAction(UIAlertAction(title: "ok", style: .default))
//        present(alert, animated: true)
//    }
    
    private func fetchDetail() {
        guard !labelID.isEmpty else { return }
        
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.path = baseURL.appendingPathComponent("/api/label").path
        comps.queryItems = [URLQueryItem(name: "id", value: labelID)]
        guard let url = comps.url else { return }
        
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async { self.spinner.stopAnimating() }
            
            if let error = error {
                print("detail fetch error:", error)
                DispatchQueue.main.async { self.showError("network error") }
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
#if DEBUG
                print("HTTP \(http.statusCode)")
#endif
                DispatchQueue.main.async { self.showError("server error (\(http.statusCode))") }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.showError("no data") }
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(LabelDetail.self, from: data)
                DispatchQueue.main.async {
                    self.detail = decoded
                    self.updateUI(with: decoded)
                }
            } catch {
                if let arr = try? JSONDecoder().decode([LabelDetail].self, from: data), let first = arr.first {
                    DispatchQueue.main.async {
                        self.detail = first
                        self.updateUI(with: first)
                    }
                } else {
#if DEBUG
                    print("decoding error:", error)
                    print(String(data: data, encoding: .utf8) ?? "<non-utf8>")
#endif
                    DispatchQueue.main.async { self.showError("couldn't read label") }
                }
            }
        }.resume()
    }
    
    private func updateUI(with d: LabelDetail) {
        let titleText = d.fullName ?? prefilledTitle ?? "label"
        titleLabel.text = titleText
        self.title = titleText
        
        brandLabel.text = d.brandName
        typeLabel.text  = d.productType?.langualCodeDescription
        
        if let s = d.servingSizes?.first {
            servingLabel.text = formatServing(s)
        } else {
            servingLabel.text = nil
        }
        
        if let upc = d.upcSku, !upc.isEmpty {
            notesTextView.text = "upc/sku: \(upc)\nentry date: \(d.entryDate ?? "—")"
        } else {
            notesTextView.text = d.entryDate.map { "entry date: \($0)" } ?? ""
        }
    }
    
    private func formatServing(_ s: LabelDetail.ServingSize) -> String? {
        var parts: [String] = []
        if let min = s.minQuantity {
            if let max = s.maxQuantity, max != min {
                parts.append("\(trim(min))–\(trim(max))")
            } else {
                parts.append(trim(min))
            }
        }
        if let unit = s.unit { parts.append(unit) }
        if let notes = s.notes, !notes.isEmpty { parts.append("(\(notes))") }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
    
    private func trim(_ v: Double) -> String {
        let s = String(format: "%.2f", v)
        if s.hasSuffix(".00") { return String(s.dropLast(3)) }
        if s.hasSuffix("0")   { return String(s.dropLast(1)) }
        return s
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ok", style: .default))
        present(alert, animated: true)
    }
}
