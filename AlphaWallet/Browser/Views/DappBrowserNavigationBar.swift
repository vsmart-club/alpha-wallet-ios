// Copyright DApps Platform Inc. All rights reserved.

import UIKit

protocol DappBrowserNavigationBarDelegate: class {
    func didTyped(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didEnter(text: String, inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapHome(inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapBack(inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapForward(inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapMore(sender: UIView, inNavigationBar navigationBar: DappBrowserNavigationBar)
    func didTapClose(inNavigationBar navigationBar: DappBrowserNavigationBar)
}

fileprivate enum State {
    case editingURLTextField
    case notEditingURLTextField
    case browserOnly
}

fileprivate struct Layout {
    static let width: CGFloat = 34
    static let moreButtonWidth: CGFloat = 24
}

final class DappBrowserNavigationBar: UINavigationBar {
    private let moreButton = UIButton()
    private let homeButton = UIButton()
    private let cancelEditingButton = UIButton()
    private let closeButton = UIButton()

    private let textField = UITextField()
    private let domainNameLabel = UILabel()
    private let backButton = UIButton()
    private let forwardButton = UIButton()
    private var viewsToShowWhenNotEditing = [UIView]()
    private var viewsToShowWhenEditing = [UIView]()
    private var viewsToShowWhenBrowserOnly = [UIView]()
    private var state = State.notEditingURLTextField {
        didSet {
            var show: [UIView]
            var hide: [UIView]
            switch state {
            case .editingURLTextField:
                hide = viewsToShowWhenNotEditing + viewsToShowWhenBrowserOnly - viewsToShowWhenEditing
                show = viewsToShowWhenEditing
            case .notEditingURLTextField:
                hide = viewsToShowWhenEditing + viewsToShowWhenBrowserOnly - viewsToShowWhenNotEditing
                show = viewsToShowWhenNotEditing
            case .browserOnly:
                hide = viewsToShowWhenEditing + viewsToShowWhenNotEditing - viewsToShowWhenBrowserOnly
                show = viewsToShowWhenBrowserOnly
            }
            hide.hideAll()
            show.showAll()
        }
    }
    var isBrowserOnly: Bool {
        return state == .browserOnly
    }

    weak var navigationBarDelegate: DappBrowserNavigationBarDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        textField.backgroundColor = .white
        textField.layer.cornerRadius = 5
        textField.layer.borderWidth = 0.5
        textField.layer.borderColor = Colors.lightGray.cgColor
        textField.autocapitalizationType = .none
        textField.autoresizingMask = .flexibleWidth
        textField.delegate = self
        textField.autocorrectionType = .no
        textField.returnKeyType = .go
        textField.clearButtonMode = .whileEditing
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 6, height: 30))
        textField.leftViewMode = .always
        textField.placeholder = R.string.localizable.browserUrlTextfieldPlaceholder()
        textField.keyboardType = .webSearch

        domainNameLabel.isHidden = true

        moreButton.setImage(R.image.toolbarMenu(), for: .normal)
        moreButton.addTarget(self, action: #selector(moreAction(_:)), for: .touchUpInside)

        closeButton.isHidden = true
        closeButton.setTitle(R.string.localizable.done(), for: .normal)
        closeButton.addTarget(self, action: #selector(closeAction(_:)), for: .touchUpInside)
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        homeButton.setImage(R.image.browserHome()?.withRenderingMode(.alwaysTemplate), for: .normal)
        homeButton.addTarget(self, action: #selector(homeAction(_:)), for: .touchUpInside)

        backButton.setImage(R.image.toolbarBack(), for: .normal)
        backButton.addTarget(self, action: #selector(goBackAction), for: .touchUpInside)

        forwardButton.setImage(R.image.toolbarForward(), for: .normal)
        forwardButton.addTarget(self, action: #selector(goForwardAction), for: .touchUpInside)

        //compression and hugging priority required to make cancel button appear reliably yet not be too wide
        cancelEditingButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        cancelEditingButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        cancelEditingButton.addTarget(self, action: #selector(cancelEditing), for: .touchUpInside)

        let spacer0 = UIView.spacerWidth()
        let spacer1 = UIView.spacerWidth()
        let spacer2 = UIView.spacerWidth()
        viewsToShowWhenNotEditing.append(contentsOf: [spacer0, spacer1, backButton, forwardButton, textField, homeButton, spacer2, moreButton])
        viewsToShowWhenEditing.append(contentsOf: [textField, cancelEditingButton])
        viewsToShowWhenBrowserOnly.append(contentsOf: [spacer0, backButton, forwardButton, domainNameLabel, spacer1, closeButton, spacer2, moreButton])

        cancelEditingButton.isHidden = true

        let stackView = UIStackView(arrangedSubviews: [
            spacer0,
            backButton,
            forwardButton,
            textField,
            domainNameLabel,
            spacer1,
            homeButton,
            closeButton,
            spacer2,
            moreButton,
            cancelEditingButton,
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.spacing = 4

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor, constant: -10),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            homeButton.widthAnchor.constraint(equalToConstant: Layout.width),
            backButton.widthAnchor.constraint(equalToConstant: Layout.width),
            forwardButton.widthAnchor.constraint(equalToConstant: Layout.width),
            moreButton.widthAnchor.constraint(equalToConstant: Layout.moreButtonWidth),
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        let color = Colors.appWhite
        backButton.imageView?.tintColor = color
        forwardButton.imageView?.tintColor = color
        homeButton.imageView?.tintColor = color
        moreButton.imageView?.tintColor = color

        domainNameLabel.textColor = color
        domainNameLabel.textAlignment = .center

        cancelEditingButton.setTitle(R.string.localizable.cancel(), for: .normal)
    }

    @objc private func goBackAction() {
        cancelEditing()
        navigationBarDelegate?.didTapBack(inNavigationBar: self)
    }

    @objc private func goForwardAction() {
        cancelEditing()
        navigationBarDelegate?.didTapForward(inNavigationBar: self)
    }

    @objc private func moreAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapMore(sender: sender, inNavigationBar: self)
    }

    @objc private func homeAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapHome(inNavigationBar: self)
    }

    @objc private func closeAction(_ sender: UIView) {
        cancelEditing()
        navigationBarDelegate?.didTapClose(inNavigationBar: self)
    }

    //TODO this might get triggered immediately if we use a physical keyboard. Verify
    @objc func cancelEditing() {
        dismissKeyboard()
        switch state {
        case .editingURLTextField:
            UIView.animate(withDuration: 0.3) {
                self.state = .notEditingURLTextField
            }
        case .notEditingURLTextField, .browserOnly:
            //We especially don't want to switch (and animate) to .notEditingURLTextField when we are closing .browserOnly mode
            break
        }
    }

    func display(url: URL) {
        textField.text = url.absoluteString
        domainNameLabel.text = URL(string: url.absoluteString)?.host ?? ""
    }

    func display(string: String) {
        textField.text = string
    }

    func clearDisplay() {
        display(string: "")
    }

    private func dismissKeyboard() {
        endEditing(true)
    }

    func makeBrowserOnly() {
        state = .browserOnly
    }

    func disableButtons() {
        backButton.isEnabled = false
        forwardButton.isEnabled = false
        homeButton.isEnabled = false
        moreButton.isEnabled = false
        textField.isEnabled = false
        cancelEditingButton.isEnabled = false
        closeButton.isEnabled = false
    }

    func enableButtons() {
        backButton.isEnabled = true
        forwardButton.isEnabled = true
        homeButton.isEnabled = true
        moreButton.isEnabled = true
        textField.isEnabled = true
        cancelEditingButton.isEnabled = true
        closeButton.isEnabled = true
    }
}

extension DappBrowserNavigationBar: UITextFieldDelegate {
    private func queue(typedText text: String) {
        navigationBarDelegate?.didTyped(text: text, inNavigationBar: self)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        navigationBarDelegate?.didEnter(text: textField.text ?? "", inNavigationBar: self)
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String
    ) -> Bool {
        if let text = textField.text, let range = Range(range, in: text) {
            queue(typedText: textField.text?.replacingCharacters(in: range, with: string) ?? "")
        } else {
            queue(typedText: "")
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        queue(typedText: "")
        return true
    }

    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        UIView.animate(withDuration: 0.3) {
            self.state = .editingURLTextField
        }
        return true
    }
}
