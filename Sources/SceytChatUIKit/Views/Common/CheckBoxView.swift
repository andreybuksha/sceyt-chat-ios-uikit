//
//  CheckBoxView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class CheckBoxView: UIControl {
    open override var isSelected: Bool {
        didSet {
            updateState()
        }
    }
    
    open var unselectedImage: UIImage = .radio
    open var selectedImage: UIImage = .radioSelected
    open var contentInsets: UIEdgeInsets = .init(top: 10, left: 10, bottom: 10, right: 10) {
        didSet {
            imageView.removeFromSuperview()
            setup()
        }
    }
    
    private let imageView = {
        $0.isUserInteractionEnabled = false
        return $0.withoutAutoresizingMask
    }(UIImageView())
    
    required public init() {
        super.init(frame: .zero)
        setup()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        addSubview(imageView)
        imageView.pin(to: self, anchors: [
            .leading(contentInsets.left),
            .trailing(-contentInsets.right),
            .top(contentInsets.top),
            .bottom(-contentInsets.bottom)
        ])
        updateState()
    }
    
    private func updateState() {
        imageView.image = isSelected ? selectedImage : unselectedImage
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        isSelected.toggle()
        sendActions(for: .valueChanged)
    }
    
}
