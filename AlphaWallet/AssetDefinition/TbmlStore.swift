// Copyright © 2018 Stormbird PTE. LTD.

import Alamofire
import BRCybertron

//hhh remove things that are only for asset definitions, but not TBML like downloading (maybe?)
/// Manage access to and cache TBML files
class TbmlStore {
    enum Result {
        case cached
        case updated
        case unmodified
        case error
    }

    static let defaultTokenFilename = "default-token.xsl"

    private var httpHeaders: HTTPHeaders = {
        guard let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return [:] }
        return [
            "Accept": "text/xml; charset=UTF-8",
            "X-Client-Name": Constants.repoClientName,
            "X-Client-Version": appVersion,
            "X-Platform-Name": Constants.repoPlatformName,
            "X-Platform-Version": UIDevice.current.systemVersion
        ]
    }()
    private var lastModifiedDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "E, dd MMM yyyy HH:mm:ss z"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
    private var subscribers: [(String) -> Void] = []
    private var backingStore: TbmlBackingStore
    private var standardTokenTbmlCss: String {
        return """
               <style type="text/css">
               @font-face {
               font-family: 'SourceSansPro-Light';
               src: local('SourceSansPro-Light'),url('SourceSansPro-Light.otf') format('opentype');
               font-weight: lighter;
               }
               @font-face {
               font-family: 'SourceSansPro-Regular';
               src: local('SourceSansPro-Regular'),url('SourceSansPro-Regular.otf') format('opentype');
               font-weight: normal;
               }
               @font-face {
               font-family: 'SourceSansPro-Semibold';
               src: local('SourceSansPro-Semibold'),url('SourceSansPro-Semibold.otf') format('opentype');
               font-weight: bold;
               }
               @font-face {
               font-family: 'SourceSansPro-Bold';
               src: local('SourceSansPro-Bold'),url('SourceSansPro-Bold.otf') format('opentype');
               font-weight: boldedr;
               }
               .tbml-count {
               font-family: "SourceSansPro-Bold";
               font-weight: bolder;
               font-size: 21px;
               color: rgb(117, 185, 67);
               }
               .tbml-category {
               font-family: "X";
               font-weight: normal;
               font-size: 21px;
               color: rgb(67, 67, 67);
               }
               .tbml-venue {
               font-family: "SourceSansPro-Light";
               font-weight: lighter;
               font-size: 16px;
               color: rgb(67, 67, 67);
               }
               .tbml-date {
               font-family: "SourceSansPro-Semibold";
               font-weight: bold;
               font-size: 16px;
               color: rgb(112, 112, 112);
               }
               .tbml-time {
               font-family: "SourceSansPro-Light";
               font-weight: lighter;
               font-size: 16px;
               color: rgb(112, 112, 112);
               }
               html {
               }

               body {
               padding: 0px;
               margin: 0px;
               }

               div {
               margin: 0px;
               padding: 0px;
               }
               </style>
               """
    }

    init(backingStore: TbmlBackingStore = TbmlDiskBackingStoreWithOverrides()) {
        self.backingStore = backingStore
        self.backingStore.delegate = self
    }

    func fetchFiles(forContracts contracts: [String]) {
        for each in contracts {
            fetchFile(forContract: each)
        }
    }

    subscript(contract: String) -> String? {
        get {
            return backingStore[contract]
        }
        set(contents) {
            backingStore[contract] = contents
        }
    }

    func isOfficial(contract: String) -> Bool {
        return backingStore.isOfficial(contract: contract)
    }

    func subscribe(_ subscribe: @escaping (_ contract: String) -> Void) {
        subscribers.append(subscribe)
    }

    /// useCacheAndFetch: when true, the completionHandler will be called immediately and a second time if an updated XML is fetched. When false, the completionHandler will only be called up fetching an updated XML
    ///
    /// IMPLEMENTATION NOTE: Current implementation will fetch the same XML multiple times if this function is called again before the previous attempt has completed. A check (which requires tracking completion handlers) hasn't been implemented because this doesn't usually happen in practice
    func fetchFile(forContract contract: String, useCacheAndFetch: Bool = false, completionHandler: ((Result) -> Void)? = nil) {
        //hhh fetch TBMLs. We don't have repo servers yet, will we ever?
    }

    private func urlToFetch(contract: String) -> URL? {
        let name = backingStore.standardizedName(ofContract: contract)
        return URL(string: Constants.repoServer)?.appendingPathComponent(name)
    }

    private func lastModifiedDateOfCachedFile(forContract contract: String) -> Date? {
        return backingStore.lastModifiedDateOfCachedFile(forContract: contract)
    }

    private func httpHeadersWithLastModifiedTimestamp(forContract contract: String) -> HTTPHeaders {
        var result = httpHeaders
        if let lastModified = lastModifiedDateOfCachedFile(forContract: contract) {
            result["IF-Modified-Since"] = string(fromLastModifiedDate: lastModified)
            return result
        } else {
            return result
        }
    }

    func string(fromLastModifiedDate date: Date) -> String {
        return lastModifiedDateFormatter.string(from: date)
    }

    func forEachContractWithTbml(_ body: (String) -> Void) {
        backingStore.forEachContractWithTbml(body)
    }

    //hhh can we cache?
    func tokenXslFromTbml(forContract contract: String) -> CYTemplate? {
        guard backingStore.isTbmlAvailable(forContract: contract) else { return nil }

        let xslStringToGenerateTbmlHtml = """
                                          <?xml version="1.0" encoding="UTF-8"?>
                                          <xsl:stylesheet version="1.0" id="card" xml:id="card"
                                              xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

                                              <xsl:import href="\(TbmlStore.defaultTokenFilename)"/>
                                              <xsl:include href="\(contract.lowercased()).xsl"/>
                                              <xsl:output method="text"/>

                                              <xsl:template match="/">
                                                  <![CDATA[
                                                  \(standardTokenTbmlCss)
                                                  ]]>
                                                  <xsl:call-template name="library"/>
                                                  <xsl:call-template name="token"/>
                                                  <xsl:call-template name="tokenRendering"/>
                                              </xsl:template>
                                          </xsl:stylesheet>
                                          """
        guard let xslData = xslStringToGenerateTbmlHtml.data(using: .utf8) else { return nil }

        let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
        let directory = documentsDirectory.appendingPathComponent("tbmlOverrides")

        //TODO Instead of basePath, use CYBundleInputSourceResolver (and set it with xslt.inputSourceResolver)
//        let xslt = CYTemplate(data: xslData)
//        xslt.inputSourceResolver = xxx
        //Doesn't matter what is the filename, only the directory name is used
        let basePath = directory.appendingPathComponent("dummy.xml").path
        let xslInputSource = CYDataInputSource(data: xslData, basePath: basePath, options: .init(rawValue: 0))
        return CYTemplate(inputSource: xslInputSource)
    }
}

extension TbmlStore: TbmlBackingStoreDelegate {
    func invalidate(forContract contract: String) {
        subscribers.forEach { $0(contract) }
        fetchFile(forContract: contract)
    }
}
