// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

//hhh look for AsssetDefinition-xxx
class TbmlStoreCoordinator: Coordinator {
    private class WeakRef<T: AnyObject> {
        weak var object: T?
        init(object: T) {
            self.object = object
        }
    }

    private static var inboxDirectory: URL? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        guard let documentDirectory = paths.first else { return nil }
        return documentDirectory.appendingPathComponent("Inbox")
    }
    private static var overridesDirectory: URL? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        guard let documentDirectory = paths.first else { return nil }
        return documentDirectory.appendingPathComponent(TbmlDiskBackingStoreWithOverrides.overridesDirectoryName)
    }
    var coordinators: [Coordinator] = []
    private var directoryWatcher: DirectoryContentsWatcherProtocol?
    //Holds an array of weak references. This exists basically because we didn't implement a way to detect when view controllers in this list are destroyed
    //hhh should we continue to use this VC class? Maybe rename it then. Also title of VC is wrong
    private var viewControllers: [WeakRef<AssetDefinitionsOverridesViewController>] = []

    deinit {
        try? directoryWatcher?.stop()
    }

    func createOverridesViewController() -> AssetDefinitionsOverridesViewController {
        let vc = AssetDefinitionsOverridesViewController()
        //hhh localize
        vc.title = "TBML Overrides"
        vc.delegate = self
        configure(overridesViewController: vc)
        viewControllers.append(WeakRef(object: vc))
        return vc
    }

    func configure(overridesViewController: AssetDefinitionsOverridesViewController) {
        if let contents = overrides() {
            overridesViewController.configure(overriddenURLs: contents)
        } else {
            overridesViewController.configure(overriddenURLs: [])
        }
    }

    func start() {
        deleteInboxContents()
        watchDirectoryContents {
            for each in self.viewControllers {
                if let viewController = each.object {
                    self.configure(overridesViewController: viewController)
                }
            }
        }
    }

    private func deleteInboxContents() {
        guard let contents = inboxContents() else { return }
        for each in contents {
            try? FileManager.default.removeItem(at: each)
         }
    }

    private func inboxContents() -> [URL]? {
        guard let inboxDirectory = TbmlStoreCoordinator.inboxDirectory else { return nil }
        return try? FileManager.default.contentsOfDirectory(at: inboxDirectory, includingPropertiesForKeys: nil)
    }

    private func overrides() -> [URL]? {
        guard let overridesDirectory = TbmlStoreCoordinator.overridesDirectory else { return nil }
        let urls = try? FileManager.default.contentsOfDirectory(at: overridesDirectory, includingPropertiesForKeys: nil).filter { TbmlDiskBackingStore.isValidFileName(forPath: $0) }
        if let urls = urls {
            return urls.sorted { $0.path.caseInsensitiveCompare($1.path) == .orderedAscending }
        } else {
            return nil
        }
    }

    ///For development
    private func printInboxContents() {
        guard let contents = inboxContents() else { return }
        NSLog("Contents of inbox:")
        for each in contents {
            NSLog("  In inbox: \(each)")
        }
    }

    /// Return true if handled
    func handleOpen(url: URL) -> Bool {
        //hhh Fix. check for .tbml
//        guard TbmlDefinitionDiskBackingStore.isValidAssetDefinitionFilename(forPath: url) else { return false }
        guard let overridesDirectory = TbmlStoreCoordinator.overridesDirectory else { return false }

        let filename = url.lastPathComponent.lowercased()
        let destinationFileName = filename.replacingOccurrences(of: ".tbml", with: ".xsl")
        let absoluteDestinationFileName = overridesDirectory.appendingPathComponent(destinationFileName)
        do {
            try? FileManager.default.removeItem(at: absoluteDestinationFileName )
            try FileManager.default.moveItem(at: url, to: absoluteDestinationFileName )
        } catch {
            NSLog("Error moving asset definition file from \(url.path) to: \(absoluteDestinationFileName.path): \(error)")
        }
        return true
    }

    private func watchDirectoryContents(changeHandler: @escaping () -> Void) {
        guard directoryWatcher == nil else { return }
        guard let directory = TbmlStoreCoordinator.overridesDirectory else { return }
        directoryWatcher = DirectoryContentsWatcher.Local(path: directory.path)
        do {
            try directoryWatcher?.start { [weak self] results in
                guard self != nil else { return }
                switch results {
                case .noChanges:
                    break
                case .updated:
                    changeHandler()
                }
            }
        } catch {
        }
    }
}

extension TbmlStoreCoordinator: AssetDefinitionsOverridesViewControllerDelegate {
    func didDelete(overrideFileForContract file: URL, in viewController: AssetDefinitionsOverridesViewController) {
        try? FileManager.default.removeItem(at: file)
        configure(overridesViewController: viewController)
    }
}
