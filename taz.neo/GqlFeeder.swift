//
//  GqlFeeder.swift
//
//  Created by Norbert Thies on 12.09.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// A protocol defining methods to use by GraphQL objects
protocol GQLObject: Decodable, ToString {
  /// A String listing the GraphQL field names of an GraphQL object
  static var fields: String { get }
}

/// Authentication status
enum GqlAuthStatus: Decodable {  
  case valid         /// valid authentication token provided
  case invalid       /// invalid token
  case expired       /// account provided by token is expired (ISO-Date in message)
  case unlinked      /// ID not linked to subscription
  case notValidMail  /// AboId exists but PW is wrong (mail addr in message)
  case alreadyLinked /// AboId already linked to tazId
  case unknown       /// unknown authentication status    
  
  func toString() -> String {
    switch self {
    case .valid:         return "valid"
    case .invalid:       return "invalid"
    case .expired:       return "expired"
    case .unlinked:      return "unlinked"
    case .notValidMail:  return "notValidMail"
    case .alreadyLinked: return "alreadyLinked"
    case .unknown:       return "unknown"
    }
  }
  
  init(from decoder: Decoder) throws {
    let s = try decoder.singleValueContainer().decode(String.self)
    switch s {
    case "valid"   :       self = .valid
    case "notValid":       self = .invalid
    case "elapsed" :       self = .expired
    case "tazIdNotLinked": self = .unlinked
    case "notValidMail":   self = .notValidMail
    case "alreadyLinked":  self = .alreadyLinked
    default:               self = .unknown
    }
  }  
} // GqlAuthStatus

/// A GqlAuthInfo describes an GqlAuthStatus with an optional message
struct GqlAuthInfo: GQLObject {  
  /// Authentication status
  var status:  GqlAuthStatus
  /// Optional message in case of !valid
  var message: String?
  
  static var fields = "status message"
  
  func toString() -> String {
    var ret = status.toString()
    if let msg = message { ret += ": (\(msg))" }
    return ret
  }  
} // GqlAuthInfo

/// A GqlAuthToken is returned upon an Authentication request
struct GqlAuthToken: GQLObject {  
  /// Authentication token (to use for further authentication)  
  var token: String?
  /// Authentication info
  var authInfo: GqlAuthInfo
  
  static var fields = "token authInfo{\(GqlAuthInfo.fields)}"
  
  func toString() -> String {
    var ret: String
    if let str = token { 
      ret = authInfo.toString() + ": \(str.prefix(20))..." 
    }
    else { ret = authInfo.toString() }
    return ret
  }  
} // GqlAuthToken


/// GqlFile as defined by server
class GqlFile: FileEntry, GQLObject {
  /// name of file relative to base URL
  var name: String
  /// Storage type of file
  var storageType: FileStorageType
  /// Modification time as String of seconds since 1970-01-01 00:00:00 UTC
  var sMoTime: String
  /// SHA256 of files' contents
  var sha256: String
  /// File size in bytes
  var sSize: String
  
  /// Modification time as Date
  var moTime: Date { return UsTime(sMoTime).date }
  
  /// Size as Int64
  var size: Int64 { return Int64(sSize)! }
  
  static var fields =  "name storageType sMoTime:moTime sha256 sSize:size"
} // GqlFile

/// A file storing an Image
class GqlImage: ImageEntry, GQLObject {
  /// Resolution of Image
  var resolution: ImageResolution  
  /// Type of Image
  var type: ImageType
  /// Tranparency
  var alpha: Float?
  /// Name of file relative to base URL
  var name: String
  /// Storage type of file
  var storageType: FileStorageType
  /// Modification time as String of seconds since 1970-01-01 00:00:00 UTC
  var sMoTime: String
  /// SHA256 of files' contents
  var sha256: String
  /// File size in bytes
  var sSize: String
  
  /// Modification time as Date
  var moTime: Date { return UsTime(sMoTime).date }
  
  /// Size as Int64
  var size: Int64 { return Int64(sSize)! }
  
  //static var fields = "resolution type alpha \(GqlFile.fields)"
  static var fields = "resolution type alpha \(GqlFile.fields)"  
} // GqlImage

/// A list of resource files
class GqlResources: Resources, GQLObject {  
  /// Current resource version
  var resourceVersion: Int
  /// Base URL of resource files
  var resourceBaseUrl: String
  /// List of files
  var files: [GqlFile]
  var resourceFiles: [FileEntry] { return files }
  
  static var fields = """
  resourceVersion resourceBaseUrl 
  files: resourceList { \(GqlFile.fields) }
  """    
} //  GqlResources

/// The author of an article
class GqlAuthor: Author, GQLObject {
  /// Name of author
  var name: String?
  /// Photo (if any)
  var image: GqlImage?
  var photo: ImageEntry? { return image }
  
  static var fields = "name image: imageAuthor { \(GqlImage.fields) }"
}

/// One Article of an Issue
class GqlArticle: Article, GQLObject {
  /// File storing article HTML
  var articleHtml: GqlFile
  var html: FileEntry { return articleHtml }
  /// File storing article MP3 (if any)
  var audioFile: GqlFile?
  var audio: FileEntry? { return audioFile }
  /// Article title
  var title: String?
  /// Article teaser
  var teaser: String?
  /// Link to online version of this article
  var onlineLink: String?
  /// List of PDF page (-file) names containing this article
  var pageNames: [String]?
  /// List of Images (photos)
  var imageList: [GqlImage]?
  var images: [ImageEntry]? { return imageList }
  /// List of authors
  var authorList: [GqlAuthor]?
  var authors: [Author]? { return authorList }

  static var fields = """
  articleHtml { \(GqlFile.fields) }
  audioFile { \(GqlFile.fields) }
  title
  teaser
  onlineLink
  pageNames: pageNameList
  imageList { \(GqlImage.fields) }
  authorList { \(GqlAuthor.fields) }
  """  
}

/// A Section of an Issue
class GqlSection: Section, GQLObject {
  /// File storing section HTML
  var sectionHtml: GqlFile
  var html: FileEntry { return sectionHtml }
  /// Name of section
  var name: String
  /// Optional title (not to display in table of contents)
  var extendedTitle: String?
  /// Type of section
  var type: SectionType
  /// List of articles
  var articleList: [GqlArticle]?
  var articles: [Article]? { return articleList }
  /// List of Images
  var imageList: [GqlImage]?
  var images: [ImageEntry]? { return imageList }
  /// Optional list of Authors in this section (currently empty)
  var authors: [Author]? { return nil }
  /// Navigation button
  var sectionNavButton: GqlImage?
  var navButton: ImageEntry? { return sectionNavButton }
  
  static var fields = """
  sectionHtml { \(GqlFile.fields) }
  name: title
  extendedTitle
  type
  sectionNavButton: navButton { \(GqlImage.fields) }
  articleList { \(GqlArticle.fields) }
  imageList { \(GqlImage.fields) }
  """
} // GqlSection

/// A Frame represents one frame of an article or other
/// box on a PDF page
class GqlFrame: Frame, GQLObject {
  /// Coordinates of frame
  var x1: Float
  var y1: Float
  var x2: Float
  var y2: Float
  /// Link to either local file (eg. Article) or to remote object
  var link: String?
  
  static var fields = "x1 y1 x2 y2 link"
} // Frame

/// A PDF page of an Issue
class GqlPage: Page, GQLObject {
  /// File storing PDF
  var pagePdf: GqlFile
  var pdf: FileEntry { return pagePdf }
  /// Page title (if any)
  var title: String?
  /// Page number (or some String numbering the page in some way)
  var pagina: String?
  /// Type of page
  var type: PageType
  /// Frames in page
  var frameList: [GqlFrame]?
  var frames: [Frame]? { return frameList }
  
  static var fields = """
  pagePdf { \(GqlFile.fields) }
  title
  pagina
  type
  frameList { \(GqlFrame.fields) }
  """
} // GqlPage

/// The Moment is a list of Images identifying an Issue
class GqlMoment: Moment, GQLObject {
  /// The images in different resolutions
  public var imageList: [GqlImage]
  public var images: [ImageEntry] { return imageList }
  
  static var fields = "imageList { \(GqlImage.fields) }"
} // GqlMoment

/// One Issue of a Feed
class GqlIssue: Issue, GQLObject {  
  /// Reference to Feed providing this Issue
  var feedRef: GqlFeed?
  /// Return a non nil Feed
  var feed: Feed { 
    get { return feedRef! }
    set { feedRef = newValue as? GqlFeed }
  }
  /// Issue date
  var sDate: String 
  var date: Date { return UsTime(iso: sDate, tz: GqlFeeder.tz).date }
  /// Modification time as String of seconds since 1970-01-01 00:00:00 UTC
  var sMoTime: String?
  /// Modification time as Date
  var moTime: Date { 
    guard let mtime = sMoTime else { return date }
    return UsTime(mtime).date 
  }
  /// Is this Issue a week end edition?
  var isWeekend: Bool?
  /// Issue defining images
  var gqlMoment: GqlMoment
  var moment: Moment { return gqlMoment }
  /// persistent Issue key
  var key: String?
  /// Base URL of all files of this Issue
  var baseUrl: String
  /// Issue status
  var status: IssueStatus
  /// Minimal resource version for this issue
  var minResourceVersion: Int
  /// Name of zip file with all data minus PDF
  var zipName: String?
  /// List of files in this Issue without PDF
  var fileList: [String]?
  /// Name of zip file with all data plus PDF
  var zipNamePdf: String?
  /// List of files in this Issue with PDF
  var fileListPdf: [String]?
  /// Issue imprint
  var gqlImprint: GqlArticle?
  var imprint: Article? { return gqlImprint }
  /// List of sections in this Issue
  var sectionList: [GqlSection]?
  var sections: [Section]? { return sectionList }
  /// List of PDF pages (if any)
  var pageList : [GqlPage]?
  var pages: [Page]? { return pageList }
  
  static var ovwFields = """
  sDate: date 
  sMoTime: moTime
  isWeekend
  gqlMoment: moment { \(GqlMoment.fields) } 
  baseUrl 
  status
  minResourceVersion
  """
  
  static var fields = """
  \(ovwFields)
  key 
  zipName
  fileList
  zipNamePdf: zipPdfName
  fileListPdf
  gqlImprint: imprint { \(GqlArticle.fields) }
  sectionList { \(GqlSection.fields) }
  pageList { \(GqlPage.fields) }
  """  
} // GqlIssue

/// A Feed of publication issues and articles
class GqlFeed: Feed, GQLObject {  
  /// Name of Feed
  var name: String
  /// Publication cycle
  var cycle: PublicationCycle
  /// width/height of "Moment"-Image
  var momentRatio: Float
  /// Number of issues available
  var issueCnt: Int
  /// Date of last issue available (newest)
  var sLastIssue: String
  var lastIssue: Date { return UsTime(iso: sLastIssue, tz: GqlFeeder.tz).date }
  /// Date of first issue available (oldest)
  var sFirstIssue: String  
  var firstIssue: Date { return UsTime(iso: sFirstIssue, tz: GqlFeeder.tz).date }
  /// The Issues requested of this Feed
  var gqlIssues: [GqlIssue]?
  var issues: [Issue]? { return gqlIssues }
  
  static var fields = """
      name cycle momentRatio issueCnt
      sLastIssue: issueMaxDate
      sFirstIssue: issueMinDate
    """
} // class GqlFeed

/// GqlFeederStatus stores some Feeder specific data
class GqlFeederStatus: GQLObject {  
  /// Authentication Info
  var authInfo: GqlAuthInfo
  /// Current resource version
  var resourceVersion: Int
  /// Base URL of resource files
  var resourceBaseUrl: String
  /// Base URL of global files
  var globalBaseUrl: String
  /// Feeds this Feeder provides
  var feeds: [GqlFeed]
  
  static var fields = """
  authInfo{\(GqlAuthInfo.fields)}
  resourceVersion
  resourceBaseUrl
  globalBaseUrl
  feeds: feedList { \(GqlFeed.fields) }
  """
  
  func toString() -> String {
    var ret = """
      authentication:  \(authInfo.toString())
      resourceVersion: \(resourceVersion)
      resourceBaseUrl: \(resourceBaseUrl)
      globalBaseUrl:   \(globalBaseUrl)
      Feeds:
    """
    for f in feeds {
      ret += "\n\(f.toString().indent(by: 4))"
    }
    return ret
  }  
} // GqlFeederStatus

/**
 The GqlFeeder implements the Feeder protocol to manage the communication
 with a Feeder providing data feeds (publications).
 
 This class provides the necessary functionality to handle all data transfer 
 operations with the taz/lmd GraphQL server.
 */
open class GqlFeeder: Feeder, DoesLog {  

  /// Time zone Feeder lives in ;-(
  public static var tz = "Europe/Berlin"
  public var timeZone: String { return GqlFeeder.tz }

  /// URL of GraphQL server
  public var baseUrl: String
  /// Authentication token got from server
  public var authToken: String? { didSet { gqlSession?.authToken = authToken } }
  /// title/name of Feeder
  public var title: String
  /// The last time feeds have been requested
  public var lastUpdated: Date?
  /// The next time to ask for Feed updates
  public var validUntil: Date?
  /// Current resource version
  public var resourceVersion: Int {
    guard let st = status else { return -1 }
    return st.resourceVersion
  }
  /// base URL of global files
  public var globalBaseUrl: String {
    guard let st = status else { return "" }
    return st.globalBaseUrl
  }
  /// The Feeds this Feeder is providing
  public var feeds: [Feed] {
    guard let st = status else { return [] }
    return st.feeds
  }
  /// The GraphQL server delivering the Feeds
  public var gqlSession: GraphQlSession?
  
  // The FeederStatus
  var status: GqlFeederStatus?
  
  public func toString() -> String {
    guard let st = status else { return "Error: No Feeder status available" }
    return "Feeder (\(lastUpdated?.isoTime() ?? "unknown time")):\n" + 
      "  title:           \(title)\n" +
      "  baseUrl:         \(baseUrl)\n" +
      "  token:           \((authToken ?? "undefined").prefix(20))...\n" +
      st.toString()
  }
  
  /// Initilialize with name/title and URL of GraphQL server
  required public init(title: String, url: String,
    closure: @escaping(Result<Int,Error>)->()) {
    self.baseUrl = url
    self.title = title
    self.gqlSession = GraphQlSession(url)
    self.feederStatus { [weak self] (res) in
      var ret: Result<Int,Error>
      switch res {
      case .success(let st):   
        ret = .success(st.feeds.count)
        self?.status = st
        self?.lastUpdated = Date()
      case .failure(let err):  
        ret = .failure(err)
      }
      self?.lastUpdated = UsTime.now().date
      closure(ret)
    }
  }
  
  /// Requests an GqlAuthToken object from server
  public func authenticate(account: String, password: String, 
    closure: @escaping(Result<String,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      authToken: authentificationToken(user:"\(account)", password: "\(password)") {
        \(GqlAuthToken.fields)
      }
    """
    gqlSession.query(graphql: request, type: [String:GqlAuthToken].self) { [weak self] (res) in
      var ret: Result<String,Error>
      switch res {
      case .success(let auth): 
        let atoken = auth["authToken"]!
        self?.status?.authInfo = atoken.authInfo
        switch atoken.authInfo.status {
        case .expired: 
          ret = .failure(FeederError.expiredAccount(atoken.authInfo.message))
        case .invalid, .unlinked, .alreadyLinked, .notValidMail, .unknown:
          ret = .failure(FeederError.invalidAccount(atoken.authInfo.message)) 
        case .valid:
          self?.authToken = atoken.token!
          ret = .success(atoken.token!)
        }
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  /// Return device info as specifi server
  public func deviceInfo() -> (type: String, format: String) {
    var deviceFormat: String
    switch Device.singleton {
    case .iPad :  deviceFormat = "tablet"
    case .iPhone: deviceFormat = "mobile"
    default: deviceFormat = "desktop"
    }
    return ("apple", deviceFormat)
  }
  
  /// Send server notification/device/user infos after successful authentication
  public func notification(pushToken: String?, oldToken: String?, 
    isTextNotification: Bool, closure: @escaping(Result<Bool,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let (deviceType, deviceFormat) = deviceInfo()
    let pToken = (pushToken == nil) ? "" : "pushToken: \"\(pushToken!)\","
    let oToken = (oldToken == nil) ? "" : "oldToken: \"\(oldToken!)\","
    let request = """
      notification(\(pToken), \(oToken) 
                   textNotification: \(isTextNotification ? "true" : "false"),
                   deviceType: \(deviceType), 
                   deviceFormat: \(deviceFormat), 
                   appVersion: "\(App.bundleVersion)-\(App.buildNumber)")
    """
    gqlSession.mutation(graphql: request, type: [String:Bool].self) { (res) in
      var ret: Result<Bool,Error>
      switch res {
      case .success(let dict):   
        let status = dict["notification"]!
        ret = .success(status)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
    
  /// Request push notification from server (test purpose)
  public func testNotification(pushToken: String?, request: NotificationType, 
                               closure: @escaping(Result<Bool,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    guard let pushToken = pushToken else { 
      closure(.failure(error("Notification not allowed"))); return
    }
    let (deviceType, _) = deviceInfo()
    let request = """
      testNotification(
        pushToken: "\(pushToken)",
        sendRequest: \(request.encoded),
        deviceType: \(deviceType),
        isSilent: true
      )
    """
    gqlSession.mutation(graphql: request, type: [String:Bool].self) { (res) in
      var ret: Result<Bool,Error>
      switch res {
      case .success(let dict):   
        let status = dict["testNotification"]!
        ret = .success(status)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }

  /// Requests a ResourceList object from the server
  public func resources(closure: @escaping(Result<Resources,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      resources: product {
        \(GqlResources.fields)
      }
    """
    gqlSession.query(graphql: request, type: [String:GqlResources].self) { (res) in
      var ret: Result<Resources,Error>
      switch res {
      case .success(let str):   ret = .success(str["resources"]!)
      case .failure(let err):   ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  // Get GqlFeederStatus
  func feederStatus(closure: @escaping(Result<GqlFeederStatus,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      feederStatus: product {
        \(GqlFeederStatus.fields)
      }
    """
    gqlSession.query(graphql: request, type: [String:GqlFeederStatus].self) { (res) in
      var ret: Result<GqlFeederStatus,Error>
      switch res {
      case .success(let fs):   
        let fst = fs["feederStatus"]!
        ret = .success(fst)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }
  
  // Get Issue overview
  public func overview(feed: Feed, count: Int = 20, from: Date? = nil,
                       closure: @escaping(Result<[Issue],Error>)->()) { 
    struct OvwRequest: Decodable {
      var authInfo: GqlAuthInfo
      var feeds: [GqlFeed]
      static func request(feedName: String, count: Int = 20, from: Date? = nil) -> String {
        var dateArg = ""
        if let date = from {
          dateArg = ",issueDate:\"\(date.isoDate(tz: GqlFeeder.tz))\""
        }
        return """
        ovwRequest: product {
          authInfo { \(GqlAuthInfo.fields) }
          feeds: feedList(name:"\(feedName)") {
            \(GqlFeed.fields)
            gqlIssues: issueList(limit:\(count)\(dateArg)) {
              \(GqlIssue.ovwFields)
            }
          }
        }
        """
      }
    }
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let wasAuthenticated: Bool = authToken != nil
    let request = OvwRequest.request(feedName: feed.name, count: count, from: from)
    gqlSession.query(graphql: request,
      type: [String:OvwRequest].self) { (res) in
      var ret: Result<[Issue],Error>? = nil
      switch res {
      case .success(let ovw):  
        let req = ovw["ovwRequest"]!
        if wasAuthenticated {
          if req.authInfo.status != .valid {
            self.authToken = nil
            ret = .failure(FeederError.changedAccount(req.authInfo.message))
          }
        }
        if ret == nil { 
          if let issues = req.feeds[0].issues, issues.count > 0 {
            for var issue in issues { issue.feed = feed }
            ret = .success(issues) 
          }
          else {
            ret = .failure(FeederError.unexpectedResponse(
              "Server didn't return issues"))
          }
        }
      case .failure(let err):
        ret = .failure(err)
      }
      closure(ret!)
    }
  }
  
  // Get Issue
  public func issue(feed: Feed, date: Date? = nil, key: String? = nil,
                    closure: @escaping(Result<Issue,Error>)->()) { 
    struct FeedRequest: Decodable {
      var authInfo: GqlAuthInfo
      var feeds: [GqlFeed]
      static func request(feedName: String, date: Date? = nil, key: String? = nil) -> String {
        var dateArg = ""
        if let date = date {
          dateArg = ",issueDate:\"\(date.isoDate(tz: GqlFeeder.tz))\""
        }
        var keyArg = ""
        if let key = key {
          keyArg = ",key:\"\(key)\""
        }
        return """
        feedRequest: product {
          authInfo { \(GqlAuthInfo.fields) }
          feeds: feedList(name:"\(feedName)") {
            \(GqlFeed.fields)
            gqlIssues: issueList(limit:1\(dateArg)\(keyArg)) {
              \(GqlIssue.fields)
            }
          }
        }
        """
      }
    }
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let wasAuthenticated: Bool = authToken != nil
    let request = FeedRequest.request(feedName: feed.name, date: date, key: key)
    gqlSession.query(graphql: request,
      type: [String:FeedRequest].self) { (res) in
      var ret: Result<Issue,Error>? = nil
      switch res {
      case .success(let frq):  
        let req = frq["feedRequest"]!
        if wasAuthenticated {
          if req.authInfo.status != .valid {
            ret = .failure(FeederError.changedAccount(req.authInfo.message))
          }
        }
        if ret == nil { 
          if var issues = req.feeds[0].issues, issues.count > 0 {
            issues[0].feed = feed
            ret = .success(issues[0]) 
          }
          else {
            ret = .failure(FeederError.unexpectedResponse(
              "Server didn't return issues"))
          }
        }
      case .failure(let err):
        ret = .failure(err)
      }
      closure(ret!)
    }
  }
  
  /// Signal server that download has been started
  public func startDownload(feed: Feed, issue: Issue, isPush: Bool,
                            closure: @escaping(Result<String,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let (deviceType, deviceFormat) = deviceInfo()
    let request = """
    downloadStart(
      feedName: "\(feed.name)", 
      issueDate: "\(self.date2a(issue.date))",
      deviceName: "\(Utsname.machine) (\(UIDevice.current.name))",
      deviceVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
      appVersion: "\(App.bundleVersion)-\(App.buildNumber)",
      isPush: \(isPush ? "true" : "false"),
      installationId: "\(App.installationId)",
      deviceFormat: \(deviceFormat), 
      deviceType: \(deviceType)
    )
    """
    gqlSession.mutation(graphql: request, type: [String:String].self) { (res) in
      var ret: Result<String,Error>
      switch res {
      case .success(let dict):   
        let status = dict["downloadStart"]!
        ret = .success(status)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }

  /// Signal server that download has been finished
  public func stopDownload(dlId: String, seconds: Double, 
                    closure: @escaping(Result<Bool,Error>)->()) {
    guard let gqlSession = self.gqlSession else { 
      closure(.failure(fatal("Not connected"))); return
    }
    let request = """
      downloadStop(downloadId: "\(dlId)", downloadTime: \(seconds))
    """
    gqlSession.mutation(graphql: request, type: [String:Bool].self) { (res) in
      var ret: Result<Bool,Error>
      switch res {
      case .success(let dict):   
        let status = dict["downloadStop"]!
        ret = .success(status)
      case .failure(let err):  ret = .failure(err)
      }
      closure(ret)
    }
  }

} // GqlFeeder
