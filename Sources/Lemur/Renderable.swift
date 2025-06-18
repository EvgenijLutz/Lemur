//
//  Renderable.swift
//  Lemur
//
//  Created by Evgenij Lutz on 27.01.24.
//

import Metal
import QuartzCore


@MainActor
/// Generalized interface for a renderable object
public protocol Renderable: AnyObject {
    var device: MTLDevice { get }
    var canvas: LMCanvas? { get set }
    func render(to drawable: CAMetalDrawable, timestamp: CFTimeInterval, presentationTimestamp: CFTimeInterval?, targetTimestamp: CFTimeInterval?, forceWait: Bool)
}
