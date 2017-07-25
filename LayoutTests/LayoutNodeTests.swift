//  Copyright © 2017 Schibsted. All rights reserved.

import XCTest
@testable import Layout

class LayoutNodeTests: XCTestCase {

    // MARK: Expression errors

    func testInvalidExpression() {
        let node = LayoutNode(expressions: ["foobar": "5"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.description.contains("Unknown expression") == true)
        XCTAssertTrue(errors.first?.description.contains("foobar") == true)
    }

    func testCircularReference1() {
        let node = LayoutNode(expressions: ["top": "top"])
        let errors = node.validate()
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors.first?.description.contains("Circular reference") == true)
        XCTAssertTrue(errors.first?.description.contains("top") == true)
    }

    func testCircularReference2() {
        let node = LayoutNode(expressions: ["top": "bottom", "bottom": "top"])
        let errors = node.validate()
        XCTAssertGreaterThanOrEqual(errors.count, 2)
        for error in errors {
            let description = error.description
            XCTAssertTrue(description.contains("Circular reference"))
            XCTAssertTrue(description.contains("top") || description.contains("bottom"))
        }
    }

    // MARK: State/constant shadowing

    func testExpressionShadowsConstant() {
        let node = LayoutNode(constants: ["top": 10], expressions: ["top": "top"])
        let errors = node.validate()
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "top"), 10)
    }

    func testExpressionShadowsVariable() {
        let node = LayoutNode(state: ["top": 10], expressions: ["top": "top"])
        let errors = node.validate()
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "top"), 10)
    }

    func testStateShadowsConstant() {
        let node = LayoutNode(state: ["foo": 10], constants: ["foo": 5], expressions: ["top": "foo"])
        XCTAssertTrue(node.validate().isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "foo"), 10)
        XCTAssertEqual(try node.doubleValue(forSymbol: "top"), 10)
    }

    func testConstantShadowsViewProperty() {
        let view = UIView()
        view.tag = 10
        let node = LayoutNode(view: view, constants: ["tag": 5])
        XCTAssertTrue(node.validate().isEmpty)
        XCTAssertEqual(try node.doubleValue(forSymbol: "tag"), 5)
    }

    func testStateShadowsInheritedConstant() {
        let child = LayoutNode(state: ["foo": 10], expressions: ["top": "foo"])
        let parent = LayoutNode(constants: ["foo": 5], children: [child])
        XCTAssertTrue(parent.validate().isEmpty)
        XCTAssertEqual(try child.doubleValue(forSymbol: "foo"), 10)
        XCTAssertEqual(try child.doubleValue(forSymbol: "top"), 10)
    }

    func testConstantShadowsInheritedState() {
        let child = LayoutNode(constants: ["foo": 10], expressions: ["top": "foo"])
        let parent = LayoutNode(state: ["foo": 5], children: [child])
        XCTAssertTrue(parent.validate().isEmpty)
        XCTAssertEqual(try child.doubleValue(forSymbol: "foo"), 10)
        XCTAssertEqual(try child.doubleValue(forSymbol: "top"), 10)
    }

    // MARK: update(with:)

    func testUpdateViewWithSameClass() {
        let node = LayoutNode(view: UIView())
        let oldView = node.view
        XCTAssertTrue(oldView.classForCoder == UIView.self)
        let layout = Layout(node)
        try! node.update(with: layout)
        XCTAssertTrue(oldView === node.view)
    }

    func testUpdateViewWithSubclass() {
        let node = LayoutNode(view: UIView())
        XCTAssertTrue(node.view.classForCoder == UIView.self)
        XCTAssertEqual(node.viewExpressionTypes, UIView.cachedExpressionTypes)
        let layout = Layout(LayoutNode(view: UILabel()))
        try! node.update(with: layout)
        XCTAssertEqual(node.viewExpressionTypes, UILabel.cachedExpressionTypes)
    }

    func testUpdateViewWithSuperclass() {
        let node = LayoutNode(view: UILabel())
        let layout = Layout(LayoutNode(view: UIView()))
        XCTAssertThrowsError(try node.update(with: layout))
    }

    func testUpdateViewControllerWithSameClass() {
        let node = LayoutNode(viewController: UIViewController())
        let oldViewController = node.viewController
        XCTAssertTrue(oldViewController?.classForCoder == UIViewController.self)
        let layout = Layout(node)
        try! node.update(with: layout)
        XCTAssertTrue(oldViewController === node.viewController)
    }

    func testUpdateViewControllerWithSubclass() {
        let node = LayoutNode(viewController: UIViewController())
        XCTAssertTrue(node.viewController?.classForCoder == UIViewController.self)
        XCTAssertEqual(node.viewControllerExpressionTypes, UIViewController.cachedExpressionTypes)
        let layout = Layout(LayoutNode(viewController: UITabBarController()))
        try! node.update(with: layout)
        XCTAssertEqual(node.viewControllerExpressionTypes, UITabBarController.cachedExpressionTypes)
    }

    func testUpdateViewControllerWithSuperclass() {
        let node = LayoutNode(viewController: UITabBarController())
        let layout = Layout(LayoutNode(viewController: UIViewController()))
        XCTAssertThrowsError(try node.update(with: layout))
    }
}
