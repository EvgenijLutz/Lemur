//
//  GraphicsView.swift
//  Lemur
//
//  Created by Evgenij Lutz on 27.01.24.
//

import SwiftUI
import Metal
import OSLog

#if os(macOS)

import AppKit

public typealias AppleWindow = NSWindow
public typealias AppleViewController = NSViewController
public typealias AppleView = NSView
public typealias AppleRect = NSRect

#elseif os(iOS)

import UIKit

public typealias AppleWindow = UIWindow
public typealias AppleViewController = UIViewController
public typealias AppleView = UIView
public typealias AppleRect = CGRect

#endif

#if os(macOS)
class CustomWindowDelegate: NSObject, NSWindowDelegate {
    var performingFullScreenAnimation = false
    var lastFrame: AppleRect = .zero
    
    
#if true
    func customWindowsToEnterFullScreen(for window: NSWindow) -> [NSWindow]? {
        [window]
    }
    
    func window(_ window: NSWindow, startCustomAnimationToEnterFullScreenOn screen: NSScreen, withDuration duration: TimeInterval) {
        lastFrame = window.frame
        
        if #available(macOS 15.0, *) {
            //let animation = SwiftUI.Animation.spring(duration: duration)
            //let animation = SwiftUI.Animation.interpolatingSpring
            //let animation = SwiftUI.Animation.easeInOut(duration: duration)
            let animation = SwiftUI.Animation.easeOut(duration: duration * 0.9)
            //window.styleMask.remove(.titled)
            //window.styleMask.insert(.borderless)
            //window.hasShadow = false
            NSAnimationContext.animate(animation) {
                window.setFrame(.init(origin: .zero, size: screen.frame.size), display: true)
            } completion: {
                //if window.contentView?.isInFullScreenMode ?? false {
                //    window.styleMask.remove(.titled)
                //}
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        //window.styleMask.insert(.titled)
        //window.styleMask.remove(.borderless)
    }
#endif
    
    
#if true
    func customWindowsToExitFullScreen(for window: NSWindow) -> [NSWindow]? {
        [window]
    }
    
    func window(_ window: NSWindow, startCustomAnimationToExitFullScreenWithDuration duration: TimeInterval) {
        if #available(macOS 15.0, *) {
            //window.styleMask.insert(.titled)
            
            //let animation = SwiftUI.Animation.spring(duration: duration)
            //let animation = SwiftUI.Animation.interpolatingSpring
            //let animation = SwiftUI.Animation.easeInOut(duration: duration)
            let animation = SwiftUI.Animation.easeOut(duration: duration * 0.9)
            NSAnimationContext.animate(animation) {
                window.setFrame(lastFrame, display: true)
            } completion: {
                //window.styleMask.remove(.borderless)
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    func windowDidFailToExitFullScreen(_ window: NSWindow) {
        //window.styleMask.remove(.titled)
    }
#endif
    
    
    func windowWillEnterFullScreen(_ notification: Notification) {
        performingFullScreenAnimation = true
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        performingFullScreenAnimation = false
    }
    
    
    func windowWillExitFullScreen(_ notification: Notification) {
        performingFullScreenAnimation = true
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        performingFullScreenAnimation = false
    }
}
#endif


fileprivate let logger = Logger(subsystem: "Graphics", category: "Graphics view")

internal func log(_ message: Any?) {
    guard let message else {
        print("nil")
        return
    }
    
    //print(String(describing: message))
    logger.log("\(String(describing: message))")
}


// MARK: Extensions

internal extension AppleWindow {
    var scaleFactor: CGFloat {
#if os(macOS)
        backingScaleFactor
#elseif os(iOS)
        screen.nativeScale
#endif
    }
}


// MARK: Update link

@MainActor
class UpdateLink {
    weak var targetView: GraphicsView? {
        didSet {
            updateLinkSettings()
        }
    }
    
    private var caDisplayLink: CADisplayLink? = nil
    
    private var metalDisplayLink: CAMetalDisplayLink? = nil
    
    
    var usingCADisplayLink: Bool = false {
        didSet {
            updateLinkSettings()
        }
    }
    
    private var _paused: Bool = false
    var paused: Bool {
        get {
            _paused
        }
        
        set {
            _paused = newValue
            caDisplayLink?.isPaused = newValue
            metalDisplayLink?.isPaused = newValue
        }
    }
    
    
    @MainActor
    private class DisplayLinkDelegate: NSObject {
        weak var updateLink: UpdateLink?
        
        @objc func invoke() {
            guard let caDisplayLink = updateLink?.caDisplayLink else {
                return
            }
            
            guard let targetView = updateLink?.targetView else {
                return
            }
            
            guard let drawable = targetView.metalLayer?.nextDrawable() else {
                return
            }
            
            targetView.withOrWithoutTransaction {
                targetView.render(to: drawable, timestamp: caDisplayLink.timestamp, presentationTimestamp: nil, targetTimestamp: caDisplayLink.targetTimestamp, forceWait: false)
            }
        }
    }
    private let wrapper = DisplayLinkDelegate()
    
    init() {
        wrapper.updateLink = self
    }
    
    func updateIfEmpty() {
        if caDisplayLink == nil && metalDisplayLink == nil {
            updateLinkSettings()
        }
    }
    
    func updateLinkSettings() {
        logger.log("update link settings")
        
        // Reset display link
        caDisplayLink?.isPaused = true
        caDisplayLink?.remove(from: .main, forMode: .common)
        //caDisplayLink?.remove(from: .main, forMode: RunLoop.current.currentMode)
        caDisplayLink = nil
        
        metalDisplayLink?.isPaused = true
        metalDisplayLink?.remove(from: .main, forMode: .common)
        //metalDisplayLink?.remove(from: .main, forMode: .eventTracking)
        metalDisplayLink = nil
        
        
        // Setup display link and start it
        if usingCADisplayLink {
#if os(macOS)
            caDisplayLink = targetView?.displayLink(target: wrapper, selector: #selector(DisplayLinkDelegate.invoke))
#else
            caDisplayLink = targetView?.window?.screen.displayLink(withTarget: wrapper, selector: #selector(DisplayLinkDelegate.invoke))
#endif
            caDisplayLink?.add(to: .main, forMode: .common)
            caDisplayLink?.isPaused = _paused
        }
        else if let metalLayer = targetView?.metalLayer {
            let link = CAMetalDisplayLink(metalLayer: metalLayer)
            link.delegate = self
            link.add(to: RunLoop.main, forMode: .common)
            //link.add(to: RunLoop.main, forMode: .eventTracking)
            link.isPaused = _paused
            metalDisplayLink = link
        }
    }
}


extension UpdateLink: CAMetalDisplayLinkDelegate {
    nonisolated func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update) {
        MainActor.assumeIsolated {
            targetView?.metalDisplayLink(link, needsUpdate: update)
        }
    }
}


// MARK: Graphics view

@MainActor
public protocol GraphicsViewDelegate: AnyObject {
    func canvasRendererUpdate(frame: CGSize, timestamp: CFTimeInterval, presentationTimestamp: CFTimeInterval?)
}


public class GraphicsView: AppleView {
    /// Update link
    ///
    /// - Warning: Don't control the ``updateLink.paused-property`` state. Instead, use the ``paused-property`` property of this class.
    private let updateLink = UpdateLink()
    
    /// Controls ``updateLink.paused-property``'s state
    public var paused: Bool {
        get {
            updateLink.paused
        }
        
        set {
            updateLink.paused = newValue
            updatePausedState()
        }
    }
    
    
    fileprivate var metalLayer: CAMetalLayer? {
        return layer as? CAMetalLayer
    }
    
    public var inputManager: InputManager? = nil
    
    let renderer = try? CanvasRenderer()
    
    public var canvas: Canvas? {
        get {
            renderer?.canvas
        }
        
        set {
            renderer?.canvas = newValue
            
            setNeedsDisplay(bounds)
        }
    }
    
    public weak var delegate: GraphicsViewDelegate?
    
    
    
    
    
    override init(frame: AppleRect) {
        super.init(frame: frame)
        
        initGraphicsView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        initGraphicsView()
    }
    
    deinit {
        log("♻️ Destroy graphics view")
    }
    
#if os(macOS)
    
    override public func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }
    
#elseif os(iOS)
    
    public override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
#endif // os(iOS)
    
    
#if os(macOS)
    private let customWindowDelegate = CustomWindowDelegate()
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLink.updateIfEmpty()
        
        //if let window {
        //    window.hasTitleBar
        //}
        window?.animationBehavior = .none
        window?.delegate = customWindowDelegate
    }
#elseif os(iOS)
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        updateLink.updateIfEmpty()
    }
#endif
    
    
    private func updatePausedState() {
#if true
        if paused {
#if os(macOS)
            layerContentsPlacement = .center
            layerContentsRedrawPolicy = .duringViewResize
            //layerContentsRedrawPolicy = .onSetNeedsDisplay
#endif
        }
        else {
#if os(macOS)
            layerContentsPlacement = .center
            layerContentsRedrawPolicy = .never
#endif
        }
#else
        layerContentsPlacement = .center
        layerContentsRedrawPolicy = .never
#endif
    }
    
    
    private func updateDrawableSize(for size: CGSize) {
        guard let metalLayer else {
            return
        }
        
        autoreleasepool {
            //CATransaction.begin()
            //CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            
            let scaleFactor = window?.scaleFactor ?? 1
            metalLayer.contentsScale = scaleFactor
            metalLayer.drawableSize = .init(width: size.width * scaleFactor, height: size.height * scaleFactor)
            
            //CATransaction.commit()
            
            //setNeedsDisplay(bounds)
        }
    }
    
    
    //public override var bounds: AppleRect {
    //    get {
    //        return super.bounds
    //    }
    //
    //    set {
    //        if paused {
    //            updateDrawableSize(for: newValue.size)
    //            super.bounds = newValue
    //        }
    //        else {
    //            super.bounds = newValue
    //            updateDrawableSize(for: newValue.size)
    //            render()
    //        }
    //    }
    //}

    
    override public var frame: AppleRect {
        get {
            return super.frame
        }
        
        set {
            if paused {
                updateDrawableSize(for: newValue.size)
                super.frame = newValue
            }
            else {
                withOrWithoutTransaction {
                    super.frame = newValue
                    updateDrawableSize(for: newValue.size)
                    render()
                }
            }
        }
    }
}


extension GraphicsView {
    private func initGraphicsView() {
        log("🌇 Create graphics view")
        
#if os(macOS)
        wantsLayer = true
        layer?.delegate = self
        layer?.isOpaque = false
#elseif os(iOS)
        layer.isOpaque = false
        //backgroundColor = .systemGroupedBackground
#endif
        //layerContentsPlacement = .scaleAxesIndependently
        
        
        updateRendererData()
    }
    
    private func updateRendererData() {
        // Reset metal layer
        metalLayer?.device = nil
        //metalLayer?.pixelFormat = .invalid
        
        // Safety check
        guard let renderer, let metalLayer else {
            return
        }
        
        // Setup metal layer
        metalLayer.device = renderer.device
        metalLayer.pixelFormat = .bgra10_xr
        //metalLayer.pixelFormat = .bgra10_xr_srgb
        
        //metalLayer.autoresizingMask = CAAutoresizingMask(arrayLiteral: [.layerHeightSizable, .layerWidthSizable])
        //metalLayer.needsDisplayOnBoundsChange = true
        
#if false
        updateLink.usingCADisplayLink = true
        metalLayer.presentsWithTransaction = true
        metalLayer.allowsNextDrawableTimeout = false
#else
        updateLink.usingCADisplayLink = false
        metalLayer.presentsWithTransaction = false
        metalLayer.allowsNextDrawableTimeout = false
#endif
        
        updateLink.targetView = self
        
        updatePausedState()
    }
    
    
    private func setNeedsDisplayIfPaused() {
        if paused {
            withOrWithoutTransaction {
                //setNeedsDisplay(bounds)
                //displayIfNeeded()
                render()
            }
        }
    }
    
    
    
    fileprivate func withOrWithoutTransaction(ignoringLayerOption: Bool = false, action: () -> Void) {
#if true
        if metalLayer?.presentsWithTransaction == true || ignoringLayerOption {
            CATransaction.begin()
            CATransaction.disableActions()
            action()
            CATransaction.commit()
        }
        else {
            action()
        }
#else
        action()
#endif
    }
}


// MARK: macOS

#if os(macOS)
extension GraphicsView {
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize(for: frame.size)
    }
}
#endif


// MARK: Rendering

extension GraphicsView {
    private func render() {
        guard let metalLayer else {
            return
        }
        
        if updateLink.usingCADisplayLink, let drawable = metalLayer.nextDrawable() {
//            let drawableSize = metalLayer.drawableSize
//            let width = drawableSize.width / metalLayer.contentsScale
//            let height = drawableSize.height / metalLayer.contentsScale
//            assert(width == bounds.width && height == bounds.height)
            
            render(to: drawable, timestamp: CACurrentMediaTime(), presentationTimestamp: nil, targetTimestamp: nil, forceWait: true)
        }
    }
    
    
    func render(to drawable: CAMetalDrawable, timestamp: CFTimeInterval, presentationTimestamp: CFTimeInterval?, targetTimestamp: CFTimeInterval?, forceWait: Bool) {
        // Notify delegate about update
        if let delegate {
            delegate.canvasRendererUpdate(frame: frame.size, timestamp: timestamp, presentationTimestamp: presentationTimestamp)
        }
        
        withOrWithoutTransaction {
            autoreleasepool {
                renderer?.render(to: drawable, timestamp: timestamp, presentationTimestamp: presentationTimestamp, targetTimestamp: targetTimestamp, forceWait: forceWait)
            }
        }
    }
}


// MARK: Draw with Metal display link data

extension GraphicsView {
    fileprivate func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update) {
        let targetTimestamp = update.targetTimestamp
        let presentationTimestamp = update.targetPresentationTimestamp
        
        // Notify delegate about update
        if let delegate {
            delegate.canvasRendererUpdate(frame: frame.size, timestamp: targetTimestamp, presentationTimestamp: presentationTimestamp)
        }
        
        withOrWithoutTransaction {
            renderer?.render(to: update.drawable, timestamp: targetTimestamp, presentationTimestamp: presentationTimestamp, targetTimestamp: nil, forceWait: false)
        }
    }
}


// MARK: - Layer delegate

#if os(macOS)
extension GraphicsView: CALayerDelegate {
    public func display(_ layer: CALayer) {
        withOrWithoutTransaction {
            render()
        }
    }
}
#endif


// MARK: - User input

extension GraphicsView {
#if os(macOS)
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
//    public override var isFlipped: Bool {
//        return true
//    }
    
    public override func mouseDown(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        inputManager?.add(.pointerDown(type: .mouse(buttonType: .left), localPoint: localPoint))
    }
    
    public override func mouseUp(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        inputManager?.add(.pointerDown(type: .mouse(buttonType: .left), localPoint: localPoint))
    }
    
    public override func mouseDragged(with event: NSEvent) {
        let delta = CGPoint(x: event.deltaX, y: event.deltaY)
        inputManager?.add(.pointerDrag(type: .mouse(buttonType: .left), delta: delta))
        
        setNeedsDisplayIfPaused()
    }
    
    
    public override func rightMouseDragged(with event: NSEvent) {
        let delta = CGPoint(x: event.deltaX, y: event.deltaY)
        inputManager?.add(.pointerDrag(type: .mouse(buttonType: .right), delta: delta))
        
        setNeedsDisplayIfPaused()
    }
    
    
    public override func otherMouseDragged(with event: NSEvent) {
        //if ((NSEvent.pressedMouseButtons & (1 << 2)) != 0) {
        //    print("It's a middle button!")
        //}
        let delta = CGPoint(x: event.deltaX, y: event.deltaY)
        inputManager?.add(.pointerDrag(type: .mouse(buttonType: .other), delta: delta))
        
        setNeedsDisplayIfPaused()
    }
    
    
    public override func scrollWheel(with event: NSEvent) {
        let delta = CGPoint(x: event.scrollingDeltaX, y: event.scrollingDeltaY)
        //print(delta)
        inputManager?.add(.scroll(delta: delta))
    }
    
    
//    public override func magnify(with event: NSEvent) {
//        //
//    }
    
    
    public override func keyDown(with event: NSEvent) {
        //print("Key \(event.keyCode) down")
        inputManager?.add(.keyDown(keyCode: event.keyCode))
    }
    
    public override func keyUp(with event: NSEvent) {
        //print("Key \(event.keyCode) up")
        inputManager?.add(.keyUp(keyCode: event.keyCode))
    }
#elseif os(iOS)
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let previousLocation = touch.previousLocation(in: self)
            let currentLocation = touch.location(in: self)
            let delta = CGPoint(x: (currentLocation.x - previousLocation.x) * 2,
                                y: (currentLocation.y - previousLocation.y) * 2)
            inputManager?.add(.pointerDrag(type: .mouse(buttonType: .left), delta: delta))
        }
    }
#endif
}


// MARK: GraphicsViewController


public class GraphicsViewController: AppleViewController {
    let graphicsView = GraphicsView()
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        initVC()
    }
    
    
#if os(macOS)
    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initVC()
    }
#elseif os(iOS)
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initVC()
    }
#endif
    
    
    private func initVC() {
        view = graphicsView
    }
}


// MARK: - SwiftUI port

#if os(macOS)

public struct SwiftUIGraphicsView: NSViewControllerRepresentable {
    public var canvas: Canvas?
    public weak var delegate: GraphicsViewDelegate?
    public var inputManager: InputManager?
    
    public init(canvas: Canvas?, delegate: GraphicsViewDelegate? = nil, inputManager: InputManager? = nil) {
        self.canvas = canvas
        self.delegate = delegate
        self.inputManager = inputManager
    }
    
    public func makeNSViewController(context: Context) -> GraphicsViewController {
        let vc = GraphicsViewController()
        let view = vc.graphicsView
        view.canvas = canvas
        view.delegate = delegate
        view.inputManager = inputManager
        return vc
    }
    
    public func updateNSViewController(_ nsViewController: GraphicsViewController, context: Context) {
        log("🔄 Update graphics view")
        let nsView = nsViewController.graphicsView
        nsView.canvas = canvas
        nsView.delegate = delegate
        nsView.inputManager = inputManager
    }
}

#elseif os(iOS)

public struct SwiftUIGraphicsView: UIViewControllerRepresentable {
    public var canvas: Canvas?
    public weak var delegate: GraphicsViewDelegate?
    public var inputManager: InputManager?
    
    public init(canvas: Canvas?, delegate: GraphicsViewDelegate? = nil, inputManager: InputManager? = nil) {
        self.canvas = canvas
        self.delegate = delegate
        self.inputManager = inputManager
    }
    
    public func makeUIViewController(context: Context) -> GraphicsViewController {
        let vc = GraphicsViewController()
        let view = vc.graphicsView
        view.canvas = canvas
        view.delegate = delegate
        view.inputManager = inputManager
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: GraphicsViewController, context: Context) {
        log("🔄 Update graphics view")
        let uiView = uiViewController.graphicsView
        uiView.canvas = canvas
        uiView.delegate = delegate
        uiView.inputManager = inputManager
    }
}

#endif


// MARK: - Preview

#Preview {
    SwiftUIGraphicsView(canvas: nil)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
