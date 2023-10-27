//
//  MentioningUserListVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

open class MentioningUserListVC: ViewController,
                                            UITableViewDelegate,
                                            UITableViewDataSource {

    open var viewModel: MentioningUserListVM!

    open var didSelectMember: ((ChatChannelMember) -> Void)?

    open lazy var tableView = IntrinsicTableView()
        .withoutAutoresizingMask
    
    open lazy var shadowsView = UIView()

    open override func setup() {
        super.setup()
        
        tableView.register(Components.mentioningUserViewCell)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.clipsToBounds = true
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        tableView.transform = .init(scaleX: 1, y: -1)
        
        viewModel.$event
            .compactMap { $0 }
            .sink { [weak self] in
                self?.onEvent($0)
            }.store(in: &subscriptions)
        
        viewModel.startDatabaseObserver()
        viewModel.loadMembers()
    }
    
    func keykoardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        UIView.animate(withDuration: duration, delay: 0, options: .init(rawValue: curve)) { [weak self] in
            guard let self else { return }
            shadowsView.top -= keyboardFrame.height - (view.window?.safeAreaInsets.bottom ?? 0)
        } completion: { [weak self] _ in
            guard let self else { return }
            updateShadows()
        }
    }

    open override func setupLayout() {
        super.setupLayout()
        
        view.addSubview(shadowsView)
        view.addSubview(tableView)
        tableView.pin(to: view, anchors: [
            .leading(Layouts.horizontalPadding),
            .trailing(-Layouts.horizontalPadding),
            .top(0),
            .bottom(-Layouts.bottomPadding)
        ])
        
        shadowsView.layer.cornerRadius = Layouts.cornerRadius
        shadowsView.layer.maskedCorners = Layouts.maskedCorners
        if Layouts.shadowRadius > 0 {
            shadowsView.layer.shadowRadius = Layouts.shadowRadius
            shadowsView.layer.masksToBounds = false
            shadowsView.layer.shadowOpacity = 1
            shadowsView.layer.shadowOffset = .zero
            shadowsView.layer.shouldRasterize = true
        }
    }

    open override func setupAppearance() {
        super.setupAppearance()

        shadowsView.backgroundColor = appearance.tableViewBackgroundColor
        if Layouts.shadowRadius > 0 {
            shadowsView.layer.shadowColor = appearance.shadowColor?.cgColor
        }
        
        tableView.backgroundColor = .clear
        
        view.backgroundColor = appearance.backgroundColor
    }
    
    private var firstLayout = true
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let cellHeight = Components.mentioningUserViewCell.Layouts.cellHeight
        let newHeight = round(tableView.height - cellHeight * 4 - 4 * 2 - view.safeAreaInsets.bottom)
        if tableView.frame.height != 0,
           tableView.contentInset.bottom != newHeight {
            tableView.contentInset.bottom = newHeight
            if firstLayout {
                tableView.scrollToBottom()
            } else {
                updateShadows(animated: true)
            }
            firstLayout = false
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateShadows()
    }
    
    func updateShadows(animated: Bool = false) {
        tableView.sendSubviewToBack(shadowsView)
        
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let last = tableView.visibleCells.last
            else { return }
            let top = last.frameRelativeTo(view: view).minY
            
            func perform() {
                shadowsView.frame = .init(
                    x: tableView.left,
                    y: top,
                    width: tableView.width,
                    height: tableView.bottom - top
                )
                shadowsView.layer.shadowPath = UIBezierPath(roundedRect: shadowsView.bounds,
                                                            cornerRadius: Layouts.cornerRadius).cgPath
            }
            if animated {
                UIView.animate(withDuration: 0.25) {
                    perform()
                }
            } else {
                perform()
            }
        }
    }

    open func onEvent(_ event: MentioningUserListVM.Event) {
        switch event {
        case let .change(paths):
            if tableView.numberOfSections == 0 || tableView.numberOfRows(inSection: 0) == 0 {
                tableView.alpha = 0
                tableView.performBatchUpdates {
                } completion: { [weak self] _ in
                    self?.tableView.alpha = 1
                    self?.tableView.scrollToBottom()
                }
            } else {
//                tableView.performBatchUpdates {
//                    tableView.insertRows(at: paths.inserts, with: .none)
//                    tableView.reloadRows(at: paths.updates, with: .none)
//                    tableView.deleteRows(at: paths.deletes, with: .none)
//                    paths.moves.forEach {
//                        tableView.moveRow(at: $0.from, to: $0.to)
//                    }
//                } completion: { [weak self] _ in
//                    let indexPaths = paths.moves.map(\.to)
//                    if !indexPaths.isEmpty {
//                        self?.tableView.reloadRows(at: indexPaths, with: .none)
//                    }
//                }
                tableView.reloadData()
            }
        case .reload:
            tableView.alpha = 0
            tableView.reloadData()
            tableView.performBatchUpdates {
            } completion: { [weak self] _ in
                self?.tableView.alpha = 1
                self?.tableView.scrollToBottom()
            }
        }
        view.alpha = viewModel.numberOfMembers == 0 ? 0 : 1
    }

    open func filter(text: String?) {
        viewModel.setPredicate(query: text ?? "")
    }

    // MARK: UITableView delegate, datasource
    open func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let m = viewModel.member(at: indexPath) else { return }
        didSelectMember?(m)
    }

    open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        viewModel.numberOfMembers
    }

    open func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath, cellType: Components.mentioningUserViewCell)
        cell.transform = .init(scaleX: 1, y: -1)
        guard let item = viewModel.member(at: indexPath)
        else { return cell }
        cell.data = item
//        if indexPath.row > indexPath.row - 10 {
//            viewModel.loadMembers()
//        }
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 || indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1 {
            return Components.mentioningUserViewCell.Layouts.cellHeight + 4 * 2
        } else {
            return Components.mentioningUserViewCell.Layouts.cellHeight
        }
    }
    
    open func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        if indexPath.row == 0 {
            cell.separatorInset.left = tableView.width
        } else {
            cell.separatorInset.left = Components.mentioningUserViewCell.Layouts.avatarSize + Components.mentioningUserViewCell.Layouts.avatarLeftPaddding
        }
    }
}

private extension UITableView {
    func scrollToBottom(animated: Bool = false, duration: CGFloat = 0.25) {
        let lastRow = numberOfRows(inSection: 0) - 1
        if lastRow > 0 {
            scrollToRow(at: .init(row: lastRow, section: 0), at: .bottom, animated: animated)
        }
    }
}

public extension MentioningUserListVC {
    enum Layouts {
        public static var horizontalPadding: CGFloat = 8
        public static var bottomPadding: CGFloat = 8
        public static var shadowRadius: CGFloat = 24
        public static var cornerRadius: CGFloat = 16
        public static var maskedCorners: CACornerMask = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]
    }
}
