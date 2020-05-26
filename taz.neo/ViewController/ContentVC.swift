//
//  ContentVC.swift
//
//  Created by Norbert Thies on 25.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib


// A ContentUrl provides a WebView URL for Articles and Sections
public class ContentUrl: WebViewUrl, DoesLog {
  
  public var content: Content
  public var path: String
  public lazy var url: URL = URL(fileURLWithPath: path + "/" + content.html.fileName)

  private var availableClosure: (()->())?
  private var loadClosure: (ContentUrl)->()
  private var _isAvailable = false
  public var isAvailable: Bool {
    get {
      guard !_isAvailable else { return true }
      for f in content.files {
        if !f.fileNameExists(inDir: path) { self.loadClosure(self); return false }
      }
      _isAvailable = true
      return true
    }
    set {
      _isAvailable = true
      if let closure = availableClosure { closure() }
    }
  }
  public func whenAvailable(closure: @escaping ()->()) { availableClosure = closure }

  public func waitingView() -> UIView? {
    let view = LoadingView()
    view.topText = content.title ?? ""
    view.bottomText = "wird geladen..."
    return view
  }
  
  public init(path: String, issue: Issue, content: Content, load: @escaping (ContentUrl)->()) {
    self.content = content
    self.path = path
    self.loadClosure = load
  }
  
} // ContentUrl

/// The ContentToolBar consists of a ToolBar and an encompassing view to position
/// the toolbar with enough distance to the bottom safe area
open class ContentToolbar: UIView {
  
  static let ToolbarHeight: CGFloat = 44
  private var toolbar = Toolbar()
  private var heightConstraint: NSLayoutConstraint?

  public var totalHeight: CGFloat {
    return ContentToolbar.ToolbarHeight + UIWindow.bottomInset
  }
  
  public override var backgroundColor: UIColor? {
    didSet { toolbar.backgroundColor = self.backgroundColor }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(toolbar)
    pin(toolbar.top, to: self.top)
    pin(toolbar.left, to: self.left)
    pin(toolbar.right, to: self.right)
    toolbar.pinHeight(ContentToolbar.ToolbarHeight)
    self.clipsToBounds = true
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  public func pinTo(_ view: UIView) {
    view.addSubview(self)
    pin(self.left, to: view.left)
    pin(self.right, to: view.right)
    pin(self.bottom, to: view.bottom)
    heightConstraint = self.pinHeight(totalHeight)
  }
  
  public func hide(_ isHide: Bool = true) {
    if isHide {
      UIView.animate(withDuration: 0.5) { [weak self] in
        self?.heightConstraint?.isActive = false
        self?.heightConstraint = self?.pinHeight(0)
        self?.layoutIfNeeded()
      }
    }
    else {
      UIView.animate(withDuration: 0.5) { [weak self] in
        self?.heightConstraint?.isActive = false
        self?.heightConstraint = self?.pinHeight(self!.totalHeight)
        self?.layoutIfNeeded()
      }   
    }
  }
  
  public func addButton(_ button: ButtonControl, direction: Toolbar.Direction) {
    toolbar.addButton(button, direction: direction)
  }
  
  public func setButtonColor(_ color: UIColor) { toolbar.setButtonColor(color) }

}

/**
 A ContentVC is a view controller that displays an array of Articles or Sections 
 in a collection of WebViews
 */
open class ContentVC: WebViewCollectionVC {

  /// CSS Margins for Articles and Sections
  public static let TopMargin: CGFloat = 65
  public static let BottomMargin: CGFloat = 34

  public var contentTable: ContentTableVC?
  public var contents: [Content] = []
  public var feeder: Feeder { return contentTable!.feeder! }
  public var issue: Issue { return contentTable!.issue! }
  public var feed: Feed { return issue.feed }
  public var dloader: Downloader!
  lazy var slider = ButtonSlider(slider: contentTable!, into: self)

  public var toolBar = ContentToolbar()
  private var toolBarConstraint: NSLayoutConstraint?
  public var backButton = Button<LeftArrowView>()  
//  public var backButton = Button<ImageView>()
  private var backClosure: ((ContentVC)->())?
  public var homeButton = Button<ImageView>()
  private var homeClosure: ((ContentVC)->())?
  public var shareButton = Button<ImageView>()
  private var shareClosure: ((ContentVC)->())?
  
  public var header = HeaderView()
  public var isLargeHeader = false
  
  private static var _tazApiCss: File? = nil
  public var tazApiCss: File {
    if ContentVC._tazApiCss == nil 
    { ContentVC._tazApiCss = File(dir: feeder.resourcesDir.path, fname: "tazApi.css") }
    return ContentVC._tazApiCss!
  }
  private static var _tazApiJs: File? = nil
  public var tazApiJs: File {
    if ContentVC._tazApiJs == nil 
    { ContentVC._tazApiJs = File(dir: feeder.resourcesDir.path, fname: "tazApi.js") }
    return ContentVC._tazApiJs!
  }

  /// Write tazApi.css to resource directory
  public func writeTazApiCss(topMargin: CGFloat = TopMargin, bottomMargin: CGFloat = BottomMargin) {
    let dfl = Defaults.singleton
    let textSize = Int(dfl["articleTextSize"]!)!
    let colorMode = dfl["colorMode"]
    let textAlign = dfl["textAlign"]
    var colorModeImport: String = ""
    if colorMode == "dark" { colorModeImport = "@import \"themeNight.css\";" }
    let cssContent = """
      \(colorModeImport)
      @import "scroll.css";
      html, body { 
        font-size: \((CGFloat(textSize)*18)/100)px; 
      }
      body {
        padding-top: \(topMargin+UIWindow.topInset/2)px;
        padding-bottom: \(bottomMargin+UIWindow.bottomInset/2)px;
      } 
      p {
        text-align: \(textAlign!);
      }
    """
    File.open(path: tazApiCss.path, mode: "w") { f in f.writeline(cssContent) }
  }
  
  /// Write tazApi.js to resource directory
  public func writeTazApiJs() {
    guard let path = Bundle.main.path(forResource: "NativeBridge", ofType: "js")
      else { error("Can't find NativeBridge.js"); return }
    let bridge = File(path)
    tazApiJs.data = bridge.data
    File.open(path: tazApiJs.path, mode: "a") { f in
      f.writeline("var tazApi = new NativeBridge(\"tazApi\")")
      f.writeline("tazApi.openUrl = function (url) { window.location.href = url }")
    }
  }
  
  /// Define the closure to call when the back button is tapped
  public func onBack(closure: @escaping (ContentVC)->()) 
    { backClosure = closure }
  
  /// Define the closure to call when the home button is tapped
  public func onHome(closure: @escaping (ContentVC)->()) 
    { homeClosure = closure }
  /// Define the closure to call when the home button is tapped
  
  public func onShare(closure: @escaping (ContentVC)->()) 
  { shareClosure = closure; shareButton.isHidden = false }
  
  func setupToolbar() {
    backButton.onPress { [weak self] _ in 
      guard let self = self else { return }
      self.backClosure?(self)
    }
    homeButton.onPress { [weak self] _ in 
      guard let self = self else { return }
      self.homeClosure?(self)
    }
    shareButton.onPress { [weak self] _ in 
      guard let self = self else { return }
      self.shareClosure?(self)
    }
    backButton.pinWidth(40)
    backButton.pinHeight(40)
    backButton.vinset = 0.43
    backButton.isBistable = false
    backButton.lineWidth = 0.06
    homeButton.pinWidth(40)
    homeButton.pinHeight(40)
    homeButton.inset = 0.20
    homeButton.buttonView.name = "home"
    shareButton.pinWidth(40)
    shareButton.pinHeight(40)
    shareButton.inset = 0.16
    if #available(iOS 13.0, *) {
//      backButton.buttonView.symbol = "chevron.left"
      shareButton.buttonView.symbol = "square.and.arrow.up"
    }
    else {
//      backButton.buttonView.name = "leftArrow"
//      backButton.inset = 0.3
      shareButton.buttonView.name = "share"
    }
    shareButton.isHidden = true
    toolBar.addButton(backButton, direction: .left)
    toolBar.addButton(homeButton, direction: .right)
    toolBar.addButton(shareButton, direction: .center)
    toolBar.setButtonColor(AppColors.darkTintColor)
    toolBar.backgroundColor = AppColors.darkToolbar
    toolBar.pinTo(self.view)
  }
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    writeTazApiCss()
    writeTazApiJs()
    setupToolbar()
    header.installIn(view: self.view, isLarge: isLargeHeader, isMini: true)
    whenScrolled { [weak self] ratio in
      if (ratio < 0) { self?.toolBar.hide(); self?.header.hide(true) }
      else { self?.toolBar.hide(false); self?.header.hide(false) }
    }
    let img = UIImage.init(named: "logo")
    slider.image = img
    slider.buttonAlpha = 1.0
    header.leftIndent = 8 + slider.visibleButtonWidth
    let path = feeder.issueDir(issue: issue).path
    let curls: [ContentUrl] = contents.map { cnt in
      ContentUrl(path: path, issue: issue, content: cnt) { [weak self] curl in
        guard let this = self else { return }
        this.dloader.downloadIssueData(issue: this.issue, files: curl.content.files) { err in
          if err == nil { curl.isAvailable = true }
        }
      }
    }
    displayUrls(urls: curls)
  }

  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }
  
  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    slider.close()
  }

  public override init() {
    self.contentTable = ContentTableVC.loadFromNib()
    super.init()
  }
  
  public func setup(feeder: Feeder, issue: Issue, contents: [Content],
                    dloader: Downloader, isLargeHeader: Bool) {
    self.contents = contents
    self.dloader = dloader
    self.isLargeHeader = isLargeHeader
    self.contentTable!.feeder = feeder
    self.contentTable!.issue = issue
    self.contentTable!.image = feeder.momentImage(issue: issue)
    self.baseDir = feeder.baseDir.path
    onBack { [weak self] _ in
      self?.debug("*** Action: <Back> pressed")
      self?.navigationController?.popViewController(animated: true)
    }
    onHome { [weak self] _ in
      self?.debug("*** Action: <Home> pressed")
      self?.navigationController?.popToRootViewController(animated: true)
    }
  }
  
  public convenience init(feeder: Feeder, issue: Issue, contents: [Content],
                          dloader: Downloader, isLargeHeader: Bool) {
    self.init()
    setup(feeder: feeder, issue: issue, contents: contents, dloader: dloader,
          isLargeHeader: isLargeHeader)
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
}
