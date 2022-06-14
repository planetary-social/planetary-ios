import Foundation
import UIKit

struct DebugTableViewCellModel {

    var title: String
    var cellReuseIdentifier: String

    // IMPORTANT!
    // Be sure to use [unowned self] if your closure uses 'self'
    // otherwise a retain cycle will be created.
    var valueClosure: (@MainActor (_ cell: UITableViewCell) async -> Void)?
    var actionClosure: (@MainActor (_ cell: UITableViewCell) async -> Void)?

    init(title: String? = nil,
         cellReuseIdentifier: String = DebugValueTableViewCell.className,
         valueClosure: ((_ cell: UITableViewCell) async -> Void)? = nil,
         actionClosure: ((_ cell: UITableViewCell) async -> Void)? = nil) {
        self.title = title ?? ""
        self.cellReuseIdentifier = cellReuseIdentifier
        self.valueClosure = valueClosure
        self.actionClosure = actionClosure
    }
}

class DebugValueTableViewCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.textLabel?.text = nil
        self.detailTextLabel?.text = nil
        self.accessoryType = .none
        self.accessoryView = nil
        self.removeSubviewsFromContentView()
    }

    private func removeSubviewsFromContentView() {
        for (_, subview) in self.contentView.subviews.enumerated() {
            subview.removeFromSuperview()
        }
    }
}

class DebugSubtitleTableViewCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.textLabel?.text = nil
        self.detailTextLabel?.text = nil
        self.accessoryType = .none
        self.accessoryView = nil
    }
}

class DebugImageTableViewCell: UITableViewCell {

    let contentImageView: UIImageView = {
        let view = UIImageView.forAutoLayout()
        view.contentMode = .scaleAspectFit
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        Layout.fill(view: self.contentView, with: self.contentImageView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.contentImageView.image = nil
        self.textLabel?.text = nil
        self.detailTextLabel?.text = nil
        self.accessoryType = .none
        self.accessoryView = nil
    }
}

/// A cell with a title and editable text field.
class DebugTextFieldTableViewCell: UITableViewCell, UITextFieldDelegate {

    var text: String = ""

    var textField: UITextField
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.textField = UITextField(frame: CGRect.zero)
        super.init(style: UITableViewCell.CellStyle.value1, reuseIdentifier: reuseIdentifier)
        
        guard let textLabel = textLabel else {
            return
        }
        textField.useAutoLayout()
        contentView.addSubview(textField)
        textField.constrainLeading(toTrailingOf: textLabel)
        textField.constrainTrailingToSuperview()
        textField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        setNeedsLayout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.text = ""
    }
}
