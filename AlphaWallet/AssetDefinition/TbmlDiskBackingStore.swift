// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class TbmlDiskBackingStore: TbmlBackingStore {
    private static let officialDirectoryName = "tbml"

    private let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    private let directoryName: String
    lazy var directory = documentsDirectory.appendingPathComponent(directoryName)
    private let isOfficial: Bool
    weak var delegate: TbmlBackingStoreDelegate?
    private var directoryWatcher: DirectoryContentsWatcherProtocol?
    private let defaultTokenXslString = """
                                        <?xml version="1.0" encoding="UTF-8"?>
                                        <xsl:stylesheet version="1.0" id="card" xml:id="card"
                                        xmlns:tb="http://attestation.id/ns/tbml"
                                        xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

                                        <xsl:template name="library">
                                        <![CDATA[
                                        <!-- Script tags in a XSL template with the name "library" if you want to import libraries. Not recommended -->
                                        ]]>
                                        </xsl:template>

                                        <xsl:template name="token">
                                        <![CDATA[
                                        <p>Missing XSLT template:</p>
                                        <code>&lt;xsl:template name="token"/&gt; </code>
                                        ]]>
                                        </xsl:template>

                                        <xsl:template name="tokenRendering">
                                        <![CDATA[
                                        <p>Missing XSLT template:</p>
                                        <code>&lt;xsl:template name="tokenRendering"/&gt; </code>
                                        ]]>
                                        </xsl:template>
                                        </xsl:stylesheet>
                                        """

    init(directoryName: String = officialDirectoryName) {
        self.directoryName = directoryName
        self.isOfficial = directoryName == TbmlDiskBackingStore.officialDirectoryName

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        createDefaultTokenFile()
    }

    deinit {
        try? directoryWatcher?.stop()
    }

    private func createDefaultTokenFile() {
        let url = directory.appendingPathComponent(TbmlStore.defaultTokenFilename)
        try? defaultTokenXslString.write(to: url, atomically: true, encoding: .utf8)
    }

    private func localURLOfFile(for contract: String) -> URL {
        return directory.appendingPathComponent(filename(fromContract: contract))
    }

    private func filename(fromContract contract: String) -> String {
        let name = standardizedName(ofContract: contract)
        //hhh should probably use this. But need to change file watcher to handle it since file watcher only handles a specific directory. Might be complicated
//        return "\(name)/token.xsl"
        return "\(name).xsl"
    }

    static func contract(fromPath path: URL) -> String? {
        guard path.lastPathComponent.hasPrefix("0x") else { return nil }
        //hhh should be a constant. Possible?
        guard path.pathExtension == "xsl" else { return nil }
        return path.deletingPathExtension().lastPathComponent
    }

    static func isValidFileName(forPath path: URL) -> Bool {
        return contract(fromPath: path) != nil
    }

    subscript(contract: String) -> String? {
        get {
            let path = localURLOfFile(for: contract)
            return try? String(contentsOf: path)
        }
        set(contents) {
            guard let contents = contents else {
                return
            }
            let path = localURLOfFile(for: contract)
            try? contents.write(to: path, atomically: true, encoding: .utf8)
        }
    }

    func isOfficial(contract: String) -> Bool {
        return isOfficial
    }

    func lastModifiedDateOfCachedFile(forContract contract: String) -> Date? {
        let path = localURLOfFile(for: contract)
        guard let lastModified = try? path.resourceValues(forKeys: [.contentModificationDateKey]) else {
            return nil
        }
        return lastModified.contentModificationDate
    }

    func forEachContractWithTbml(_ body: (String) -> Void) {
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            let contracts = files.compactMap { TbmlDiskBackingStore.contract(fromPath: $0) }
            for each in contracts {
                body(each)
            }
        }
    }

    func watchDirectoryContents(changeHandler: @escaping (String) -> Void) {
        guard directoryWatcher == nil else { return }
        directoryWatcher = DirectoryContentsWatcher.Local(path: directory.path)
        do {
            try directoryWatcher?.start { [weak self] results in
                guard self != nil else { return }
                switch results {
                case .noChanges:
                    break
                case .updated(let filenames):
                    for each in filenames {
                        if let url = URL(string: each), let contract = TbmlDiskBackingStore.contract(fromPath: url) {
                            changeHandler(contract)
                        }
                    }
                }
            }
        } catch {
        }
    }
}
