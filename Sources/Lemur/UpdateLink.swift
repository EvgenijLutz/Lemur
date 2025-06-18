//
//  UpdateLink.swift
//  Lemur
//
//  Created by Evgenij Lutz on 17.06.25.
//

import SwiftUI
@preconcurrency import QuartzCore


// MARK: UpdateLink

@MainActor
protocol UpdateLink: AnyObject {
    var targetView: GraphicsView? { get set }
    var paused: Bool { get set }
    
    func updateIfEmpty()
}


@MainActor
extension UpdateLink {
    var isCoreAnimationUpdateLink: Bool {
        return self is CoreAnimationUpdateLink
    }
}


@MainActor
func createUpdateLink() -> UpdateLink {
    if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
        return MetalUpdateLink()
    }
    
    return CoreAnimationUpdateLink()
}


// MARK: CADisplayLink

fileprivate class CoreAnimationUpdateLink: UpdateLink {
    var targetView: GraphicsView?
    
    private var _paused: Bool = false
    var paused: Bool {
        get {
            _paused
        }
        
        set {
            _paused = newValue
            caDisplayLink?.isPaused = newValue
        }
    }
    
    private var caDisplayLink: CADisplayLink? = nil
    
    @MainActor
    private class DisplayLinkDelegate: NSObject {
        weak var updateLink: CoreAnimationUpdateLink?
        
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
        if caDisplayLink == nil {
            updateLinkSettings()
        }
    }
    
    
    func updateLinkSettings() {
        logger.log("update link settings")
        
        // Reset display link
        caDisplayLink?.isPaused = true
        caDisplayLink?.remove(from: .main, forMode: .common)
        //caDisplayLink?.remove(from: .main, forMode: .eventTracking)
        caDisplayLink = nil
        
        // Setup display link and start it
#if os(macOS)
        caDisplayLink = targetView?.displayLink(target: wrapper, selector: #selector(DisplayLinkDelegate.invoke))
#else
        caDisplayLink = targetView?.window?.screen.displayLink(withTarget: wrapper, selector: #selector(DisplayLinkDelegate.invoke))
#endif
        caDisplayLink?.add(to: .main, forMode: .common)
        //caDisplayLink?.add(to: RunLoop.main, forMode: .eventTracking)
        caDisplayLink?.isPaused = _paused
    }
}


// MARK: CAMetalDisplayLink

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
fileprivate class MetalUpdateLink: UpdateLink {
    weak var targetView: GraphicsView? {
        didSet {
            updateLinkSettings()
        }
    }
    
    private var metalDisplayLink: CAMetalDisplayLink? = nil
    
    
    private var _paused: Bool = false
    var paused: Bool {
        get {
            _paused
        }
        
        set {
            _paused = newValue
            metalDisplayLink?.isPaused = newValue
        }
    }
    
    
    init() {
        //
    }
    
    func updateIfEmpty() {
        if metalDisplayLink == nil {
            updateLinkSettings()
        }
    }
    
    func updateLinkSettings() {
        logger.log("update link settings")
        
        // Reset display link
        metalDisplayLink?.isPaused = true
        metalDisplayLink?.remove(from: .main, forMode: .common)
        //metalDisplayLink?.remove(from: .main, forMode: .eventTracking)
        metalDisplayLink = nil
        
        
        // Setup display link and start it
        if let metalLayer = targetView?.metalLayer {
            let link = CAMetalDisplayLink(metalLayer: metalLayer)
            link.delegate = self
            link.add(to: RunLoop.main, forMode: .common)
            //link.add(to: RunLoop.main, forMode: .eventTracking)
            link.isPaused = _paused
            metalDisplayLink = link
        }
    }
    
    // bs to bypass compiler warnings
    class UpdateContainer: @unchecked Sendable {
        var update: CAMetalDisplayLink.Update? = nil
    }
    let updateContainer = UpdateContainer()
}


@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
extension MetalUpdateLink: CAMetalDisplayLinkDelegate {
    nonisolated func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update) {
        // Set update container
        updateContainer.update = update
        
        MainActor.assumeIsolated {
            guard let targetView else {
                return
            }
            
            guard let update = updateContainer.update else {
                print("This should never happen")
                return
            }
            
            targetView.adjustDrawableSize()
            //targetView.metalDisplayLink(link, needsUpdate: update)
            //renderer?.render(to: update.drawable, timestamp: targetTimestamp, presentationTimestamp: presentationTimestamp, targetTimestamp: nil, forceWait: false)
            targetView.render(to: update.drawable, timestamp: update.targetTimestamp, presentationTimestamp: update.targetPresentationTimestamp, targetTimestamp: nil, forceWait: false)
        }
        
        // Clean up
        updateContainer.update = nil
    }
}
