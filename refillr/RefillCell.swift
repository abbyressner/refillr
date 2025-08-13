import UIKit

protocol RefillCellDelegate: AnyObject {
    func refillCellDidToggle(_ cell: RefillCell)
}

final class RefillCell: UITableViewCell {
    
    // MARK: - Outlets
    @IBOutlet weak var checkboxButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    weak var delegate: RefillCellDelegate?
    private var isChecked: Bool = false
    
//    override func awakeFromNib() {
//        super.awakeFromNib()
//        selectionStyle = .default
//        accessoryType = .disclosureIndicator
//        
//        checkboxButton.setPreferredSymbolConfiguration(.init(pointSize: 20, weight: .regular), forImageIn: .normal)
//        checkboxButton.tintColor = tintColor
//        checkboxButton.accessibilityLabel = "toggle item"
//        updateCheckboxImage()
//    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        isChecked = false
        updateCheckboxImage()
    }
    
    func configure(title: String, subtitle: String?, checked: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        isChecked = checked
        updateCheckboxImage()
    }
    
    private func updateCheckboxImage() {
        let name = isChecked ? "checkmark.circle.fill" : "circle"
        checkboxButton.setImage(UIImage(systemName: name), for: .normal)
    }
    
    // MARK: - Actions
    @IBAction func checkboxTapped(_ sender: UIButton) {
        isChecked.toggle()
        updateCheckboxImage()
        delegate?.refillCellDidToggle(self)
    }
}
