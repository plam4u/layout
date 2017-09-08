//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit
import Layout
import ObjectiveC

private let validClasses: [String] = {
    var classCount: UInt32 = 0
    let classes = objc_copyClassList(&classCount)
    var names = [String]()
    for cls in UnsafeBufferPointer(start: classes, count: Int(classCount)) {
        if let cls = cls, class_getSuperclass(cls) != nil,
            class_conformsToProtocol(cls, NSObjectProtocol.self),
            cls.isSubclass(of: UIView.self) || cls.isSubclass(of: UIViewController.self) {
            let name = "\(cls)"
            if !name.hasPrefix("_") {
                names.append(name)
            }
        }
    }
    names = names.sorted()
    return names
}()

protocol EditViewControllerDelegate: class {
    func didUpdateClass(_ viewOrControllerClass: NSObject.Type, for node: LayoutNode)
    func didUpdateExpression(_ expression: String, for name: String, in node: LayoutNode)
}

class EditViewController: UIViewController, UITextFieldDelegate {
    weak var delegate: EditViewControllerDelegate?
    var node: LayoutNode! {
        didSet {
            guard rootNode != nil else { return }
            if oldValue.view.classForCoder != node.view.classForCoder ||
                oldValue.viewController?.classForCoder != node.viewController?.classForCoder {
                updateUI()
            } else {
                updateFieldValues()
            }
        }
    }

    var rootNode: LayoutNode!
    var classField: UITextField?
    var expressionFields = [String: UITextField]()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        preferredContentSize = CGSize(width: 320, height: 400)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }

    override func viewDidLayoutSubviews() {
        rootNode.update()
    }

    private func updateFieldValues() {
        for (name, field) in expressionFields {
            field.text = node.expressions[name]
        }
    }

    private func updateUI() {
        let cls: AnyClass = node.viewController?.classForCoder ?? node.view.classForCoder
        var children = [
            LayoutNode(
                view: UITextField(),
                outlet: #keyPath(classField),
                expressions: [
                    "top": "10",
                    "left": "10",
                    "width": "100% - 20",
                    "height": "auto",
                    "borderStyle": "roundedRect",
                    "autocorrectionType": "no",
                    "autocapitalizationType": "none",
                    "placeholder": "Class",
                    "editingChanged": "didUpdateText",
                    "editingDidEnd": "didUpdateClass",
                    "text": "\(cls)",
                ]
            ),
        ]
        expressionFields.removeAll()
        func filterTypes(_ key: String, _ type: RuntimeType) -> String? {
            switch type.type {
            case let .any(subtype):
                switch subtype {
                case is CGFloat.Type,
                     is Double.Type,
                     is Float.Type,
                     is Int.Type,
                     is NSNumber.Type,
                     is Bool.Type,
                     is String.Type,
                     is NSString.Type,
                     is NSAttributedString.Type,
                     is UIColor.Type,
                     is UIImage.Type,
                     is UIFont.Type:
                    return key
                default:
                    return nil
                }
            case .enum, .class, .pointer("{CGImage=}"), .pointer("{CGColor=}"):
                return key
            case .struct, .pointer, .protocol:
                return nil
            }
        }
        let fieldNames = ["top", "left", "width", "height", "bottom", "right"]
            + node.viewControllerExpressionTypes.flatMap(filterTypes).sorted()
            + node.viewExpressionTypes.flatMap(filterTypes).sorted {
                switch ($0.hasPrefix("layer."), $1.hasPrefix("layer.")) {
                case (true, true), (false, false):
                    return $0 < $1
                case (true, false):
                    return false
                case (false, true):
                    return true
                }
            }

        let start = CACurrentMediaTime()
        for name in fieldNames {
            children.append(
                LayoutNode(
                    view: UILabel(),
                    expressions: [
                        "top": "previous.bottom + 5",
                        "left": "10",
                        "width": "100% - 20",
                        "height": "auto",
                        "text": name,
                        "font": "10",
                    ]
                )
            )

            let field = UITextField()
            field.borderStyle = .roundedRect
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.text = node.expressions[name]
            expressionFields[name] = field

            children.append(
                LayoutNode(
                    view: field,
                    expressions: [
                        "top": "previous.bottom",
                        "left": "10",
                        "width": "100% - 20",
                        "height": "auto",
                        "borderStyle": "roundedRect",
                        "placeholder": name,
                        "editingDidEnd": "didUpdateField:",
                    ]
                )
            )
        }

        rootNode = LayoutNode(
            view: UIScrollView(),
            expressions: [
                "width": "100%",
                "height": "100%",
            ],
            children: [
                LayoutNode(
                    view: UIView(),
                    expressions: [
                        "width": "100%",
                        "height": "auto + 10",
                    ],
                    children: children
                ),
            ]
        )
        print("nodes:", children.count)
        print("creation:", round((CACurrentMediaTime() - start) * 1000))

        for view in view.subviews {
            view.removeFromSuperview()
        }
        try! rootNode.mount(in: self)

        print("creation + mount:", round((CACurrentMediaTime() - start) * 1000))
    }

    func didUpdateText() {
        classField?.backgroundColor = .white
        guard let classField = classField,
            let textRange = classField.textRange(from: classField.beginningOfDocument, to: classField.selectedTextRange?.start ?? classField.endOfDocument),
            let text = classField.text(in: textRange) else {
            return
        }
        var match = ""
        for name in validClasses {
            if match.isEmpty || name.characters.count < match.characters.count,
                name.lowercased().hasPrefix(text.lowercased()) {
                match = name
            }
        }
        if !match.isEmpty {
            let string = NSMutableAttributedString(string: match.substring(to: text.endIndex),
                                                   attributes: [NSForegroundColorAttributeName: UIColor.black])
            string.append(NSMutableAttributedString(string: match.substring(from: text.endIndex),
                                                    attributes: [NSForegroundColorAttributeName: UIColor.lightGray]))
            classField.attributedText = string
            classField.selectedTextRange = classField.textRange(from: textRange.end, to: textRange.end)
            return
        }
        let string = NSAttributedString(string: text,
                                        attributes: [NSForegroundColorAttributeName: UIColor.black])
        classField.attributedText = string
        classField.selectedTextRange = classField.textRange(from: textRange.end, to: textRange.end)
    }

    func didUpdateClass() {
        guard let text = classField?.text else {
            classField?.text = "UIView"
            delegate?.didUpdateClass(UIView.self, for: node)
            return
        }
        classField?.attributedText = NSAttributedString(string: text, attributes: [NSForegroundColorAttributeName: UIColor.black])
        guard let cls = NSClassFromString(text) as? NSObject.Type,
            cls is UIView.Type || cls is UIViewController.Type else {
            classField?.backgroundColor = UIColor(red: 1, green: 0.5, blue: 0.5, alpha: 1)
            return
        }
        delegate?.didUpdateClass(cls, for: node)
    }

    func didUpdateField(_ textField: UITextField) {
        for (name, field) in expressionFields where field === textField {
            if (node.expressions[name] ?? "") != (field.text ?? "") {
                delegate?.didUpdateExpression(field.text ?? "", for: name, in: node)
            }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
