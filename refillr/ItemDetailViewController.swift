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
    var prefilledBrand: String?
    var prefilledType: String?
    var prefilledServing: String?
    var prefilledNotes: String?
    var refillItem: RefillItem?
    var isNewItem: Bool = false
    var defaultTimeOfDay: RefillItem.TimeOfDay = .morning
    var onSaveNewItem: ((RefillItem) -> Void)?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var brandLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var dosageLabel: UILabel!
    @IBOutlet weak var servingLabel: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var notesTextView: UITextView!
    @IBOutlet weak var editButton: UIButton?
    
    private let baseURL: URL = AppConfig.proxyBaseURL
    private var detail: LabelDetail?
    private var isEditingFields = false
    private var notesDefaultBackground: UIColor?
    private var hasActivatedInitialEditing = false
    private var isSavingNewItem = false
    private lazy var editBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(title: "edit", style: .plain, target: self, action: #selector(editBarTapped))
    }()
    private lazy var cancelCreationBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelCreation))
    }()
    
    private lazy var titleEditor: UITextField = makeEditor(mirroring: titleLabel)
    private lazy var brandEditor: UITextField = makeEditor(mirroring: brandLabel)
    private lazy var typeEditor: UITextField = makeEditor(mirroring: typeLabel)
    private lazy var dosageEditor: UITextField = makeEditor(mirroring: dosageLabel)
    
    private var editorOrder: [UITextField] {
        [titleEditor, brandEditor, typeEditor, dosageEditor]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "item"
        configureInitialUI()
        setupEditors()
        navigationItem.rightBarButtonItem = editBarButtonItem
        if isNewItem {
            navigationItem.leftBarButtonItem = cancelCreationBarButtonItem
        }
        fetchDetail()
        //setupNavBarButtons()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isNewItem && !hasActivatedInitialEditing {
            hasActivatedInitialEditing = true
            toggleEditing(true)
        }
    }
    
    func configureForNewItem(defaultTimeOfDay: RefillItem.TimeOfDay,
                             labelID: String?,
                             title: String?,
                             brand: String?,
                             dosage: String?,
                             notes: String?,
                             timeOfDayTitle: String? = nil,
                             onSave: @escaping (RefillItem) -> Void) {
        self.isNewItem = true
        self.defaultTimeOfDay = defaultTimeOfDay
        self.labelID = labelID ?? ""
        self.prefilledTitle = title
        self.prefilledBrand = brand
        self.prefilledServing = dosage
        self.prefilledNotes = notes
        self.prefilledType = (timeOfDayTitle?.isEmpty == false ? timeOfDayTitle : defaultTimeOfDay.title)
        self.onSaveNewItem = onSave
        self.refillItem = nil
    }
    
    private func configureInitialUI() {
        if let item = refillItem {
            if prefilledTitle == nil { prefilledTitle = item.name }
            if prefilledBrand == nil { prefilledBrand = item.brand }
            if prefilledServing == nil { prefilledServing = item.doseText }
            if prefilledType == nil { prefilledType = item.timeOfDay.title }
        }
        let baseTitle = prefilledTitle ?? "item"
        titleLabel.text = baseTitle
        title = baseTitle
        brandLabel.text = prefilledBrand
        if prefilledType == nil {
            prefilledType = (refillItem?.timeOfDay ?? defaultTimeOfDay).title
        }
        typeLabel.text = prefilledType
        dosageLabel.text = prefilledServing
        servingLabel.text = nil
        notesTextView.text = prefilledNotes ?? ""
        if notesDefaultBackground == nil {
            notesDefaultBackground = notesTextView.backgroundColor
        }
        notesTextView.backgroundColor = notesDefaultBackground
        notesTextView.isEditable = false
        notesTextView.isSelectable = false
        editButton?.isHidden = true
        editButton?.isEnabled = false
        updateEditButtonTitle(editing: false)
        
        if labelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            spinner.stopAnimating()
        } else {
            spinner.startAnimating()
        }
    }
    
    private func setupEditors() {
        editorOrder.forEach { _ = $0 } // force lazy creation
        editorOrder.forEach {
            $0.delegate = self
            $0.returnKeyType = .next
            $0.isHidden = true
            $0.alpha = 0
            $0.isEnabled = false
        }
        titleEditor.autocapitalizationType = .words
        brandEditor.autocapitalizationType = .words
        typeEditor.autocapitalizationType = .words
        dosageEditor.autocapitalizationType = .sentences
        dosageEditor.returnKeyType = .done
        notesTextView.inputAccessoryView = makeToolbar()
        syncEditorsFromLabels()
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
        let trimmed = labelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/label"),
                                  resolvingAgainstBaseURL: false)!
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
    
    @IBAction private func editTapped(_ sender: Any) {
        if isEditingFields {
            let shouldExit = persistChangesIfNeeded()
            if shouldExit {
                toggleEditing(false)
            }
        } else {
            toggleEditing(true)
        }
    }
    
    @objc private func editBarTapped() {
        editTapped(editBarButtonItem)
    }
    
    @objc private func cancelCreation() {
        guard !isSavingNewItem else { return }
        navigationController?.popViewController(animated: true)
    }
    
    private func updateUI(with d: LabelDetail) {
        let titleText = d.fullName ?? prefilledTitle ?? "label"
        titleLabel.text = titleText
        self.title = titleText
        
        brandLabel.text = d.brandName ?? prefilledBrand
        if !isNewItem {
            if let type = d.productType?.langualCodeDescription, !type.isEmpty {
                typeLabel.text = type
            } else if let fallbackType = prefilledType {
                typeLabel.text = fallbackType
            } else {
                typeLabel.text = nil
            }
        }
        
        if let s = d.servingSizes?.first {
            servingLabel.text = formatServing(s)
        } else {
            servingLabel.text = nil
        }
        if (dosageLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
           let servingText = servingLabel.text, !servingText.isEmpty {
            dosageLabel.text = servingText
            prefilledServing = servingText
        }
        
        let shouldOverwriteNotes = !isNewItem || (notesTextView.text?.isEmpty ?? true)
        if shouldOverwriteNotes {
            if let upc = d.upcSku, !upc.isEmpty {
                notesTextView.text = "upc/sku: \(upc)\nentry date: \(d.entryDate ?? "—")"
            } else {
                if let entry = d.entryDate, !entry.isEmpty {
                    notesTextView.text = "entry date: \(entry)"
                } else if let fallback = prefilledNotes {
                    notesTextView.text = fallback
                } else {
                    notesTextView.text = ""
                }
            }
        }
        syncEditorsFromLabels()
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

extension ItemDetailViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let index = editorOrder.firstIndex(of: textField) else {
            return true
        }
        if index < editorOrder.count - 1 {
            editorOrder[index + 1].becomeFirstResponder()
        } else {
            notesTextView.becomeFirstResponder()
        }
        return true
    }
}

private extension ItemDetailViewController {
    func toggleEditing(_ editing: Bool) {
        isEditingFields = editing
        updateEditButtonTitle(editing: editing)
        
        if editing {
            syncEditorsFromLabels()
            editorOrder.forEach { $0.isHidden = false }
        }
        
        UIView.transition(with: view, duration: 0.18, options: .transitionCrossDissolve, animations: {
            self.editorOrder.forEach { field in
                field.alpha = editing ? 1 : 0
                field.isEnabled = editing
            }
            [self.titleLabel, self.brandLabel, self.typeLabel, self.dosageLabel].forEach {
                $0?.alpha = editing ? 0 : 1
            }
            self.notesTextView.isEditable = editing
            self.notesTextView.isSelectable = editing
            self.notesTextView.backgroundColor = editing ? UIColor.secondarySystemBackground : self.notesDefaultBackground
        }, completion: { _ in
            if !editing {
                self.editorOrder.forEach { field in
                    field.isHidden = true
                    field.isEnabled = false
                }
            }
        })
        
        if editing {
            titleEditor.becomeFirstResponder()
        } else {
            view.endEditing(true)
        }
    }
    
    func persistChangesIfNeeded() -> Bool {
        let newTitle = trimmedOrNil(titleEditor.text)
        guard let titleText = newTitle, !titleText.isEmpty else {
            showValidationAlert("Title can't be empty.")
            titleEditor.becomeFirstResponder()
            return false
        }
        let newBrand = trimmedOrNil(brandEditor.text)
        let newDosage = trimmedOrNil(dosageEditor.text)
        let newTypeRaw = trimmedOrNil(typeEditor.text)
        let newNotes = trimmedOrNil(notesTextView.text)
        
        titleLabel.text = titleText
        brandLabel.text = newBrand
        dosageLabel.text = newDosage
        typeLabel.text = newTypeRaw
        notesTextView.text = newNotes ?? ""
        
        prefilledTitle = titleText
        prefilledBrand = newBrand
        prefilledServing = newDosage
        prefilledType = newTypeRaw
        prefilledNotes = newNotes
        
        let resolvedTimeOfDay: RefillItem.TimeOfDay
        if let typeRaw = newTypeRaw, let tod = RefillItem.TimeOfDay(rawValue: typeRaw.lowercased()) {
            resolvedTimeOfDay = tod
        } else if let existing = refillItem?.timeOfDay {
            resolvedTimeOfDay = existing
        } else {
            resolvedTimeOfDay = defaultTimeOfDay
        }
        let timeTitle = resolvedTimeOfDay.title
        typeLabel.text = timeTitle
        typeEditor.text = timeTitle
        prefilledType = timeTitle
        
        if refillItem == nil || isNewItem {
            isSavingNewItem = true
            editBarButtonItem.isEnabled = false
            navigationItem.leftBarButtonItem?.isEnabled = false
            let newItem = RefillItem.make(name: titleText,
                                          brand: newBrand,
                                          dose: newDosage,
                                          time: resolvedTimeOfDay,
                                          labelID: labelID.isEmpty ? nil : labelID,
                                          checked: false)
            Task {
                do {
                    try await DataManager.shared.upsert(newItem)
                    await MainActor.run {
                        self.isSavingNewItem = false
                        self.editBarButtonItem.isEnabled = true
                        self.navigationItem.leftBarButtonItem?.isEnabled = true
                        self.refillItem = newItem
                        self.isNewItem = false
                        self.labelID = newItem.labelID ?? ""
                        self.syncEditorsFromLabels()
                        self.onSaveNewItem?(newItem)
                        self.navigationController?.popViewController(animated: true)
                    }
                } catch {
#if DEBUG
                    print("Local store save error:", error)
#endif
                    await MainActor.run {
                        self.isSavingNewItem = false
                        self.editBarButtonItem.isEnabled = true
                        self.navigationItem.leftBarButtonItem?.isEnabled = true
                        self.showError("couldn't save item")
                    }
                }
            }
            return false
        }
        
        if var item = refillItem {
            item.name = titleText
            item.brand = newBrand
            item.doseText = newDosage
            item.timeOfDay = resolvedTimeOfDay
            refillItem = item
            Task {
                do {
                    try await DataManager.shared.upsert(item)
                } catch {
#if DEBUG
                    print("Local store save error:", error)
#endif
                }
            }
        }
        
        syncEditorsFromLabels()
        return true
    }
    
    func makeEditor(mirroring label: UILabel) -> UITextField {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = label.font
        field.textColor = label.textColor
        field.textAlignment = label.textAlignment
        field.borderStyle = .roundedRect
        field.backgroundColor = UIColor.secondarySystemBackground
        field.text = label.text
        label.superview?.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: label.trailingAnchor),
            field.topAnchor.constraint(equalTo: label.topAnchor),
            field.bottomAnchor.constraint(equalTo: label.bottomAnchor)
        ])
        return field
    }
    
    func syncEditorsFromLabels() {
        titleEditor.text = titleLabel.text
        brandEditor.text = brandLabel.text
        typeEditor.text = typeLabel.text
        dosageEditor.text = dosageLabel.text
    }
    
    func trimmedOrNil(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
    
    func showValidationAlert(_ message: String) {
        let alert = UIAlertController(title: "edit item", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ok", style: .default))
        present(alert, animated: true)
    }
    
    func makeToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let done = UIBarButtonItem(title: "done", style: .done, target: self, action: #selector(endEditingFromToolbar))
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), done], animated: false)
        return toolbar
    }
    
    @objc func endEditingFromToolbar() {
        view.endEditing(true)
    }
    
    func updateEditButtonTitle(editing: Bool) {
        editBarButtonItem.title = editing ? "save" : "edit"
        editBarButtonItem.style = editing ? .done : .plain
        guard let button = editButton else { return }
        if var config = button.configuration {
            config.title = editing ? "save" : "edit"
            button.configuration = config
        } else {
            button.setTitle(editing ? "save" : "edit", for: .normal)
        }
    }
}
