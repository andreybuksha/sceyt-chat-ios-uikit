//
//  DocumentPickerController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class DocumentPickerController: NSObject, UIDocumentPickerDelegate {

    private static var retain: DocumentPickerController?

    open lazy var documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)

    open var callback: (([URL]) -> Void)?

    public override init() {
        super.init()
    }

    public weak var presenter: UIViewController?
    public convenience init(presenter: UIViewController) {
        self.init()
        self.presenter = presenter
    }

    open func showPicker(callback: @escaping ([URL]) -> Void) {
        if let p = presenter {
            DocumentPickerController.retain = self
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = true
            self.callback = callback
            p.present(documentPicker, animated: true)
        } else {
            callback([])
        }
    }

    open func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let storedUrls = urls.compactMap { Components.storage.copyFile($0) }
        callback?(storedUrls)
        DocumentPickerController.retain = nil
    }

    open func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        callback?([])
        DocumentPickerController.retain = nil
    }
}
