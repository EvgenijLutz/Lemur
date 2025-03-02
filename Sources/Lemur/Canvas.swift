//
//  Canvas.swift
//  Lemur
//
//  Created by Evgenij Lutz on 27.01.24.
//

import Foundation
import Metal
import simd


// xp147 1:55 -> 6:25


public class LMMesh {
    let vertexBuffer: MTLBuffer
    let numVertices: Int
    let texture: MTLTexture
    
    public init(vertexBuffer: MTLBuffer, numVertices: Int, texture: MTLTexture) {
        self.vertexBuffer = vertexBuffer
        self.numVertices = numVertices
        self.texture = texture
    }
}


public class Camera {
    //public var location = SIMD3<Float>(0, 0, 1.5)
    public var location = SIMD3<Float>(0, 0.5, 1.5)
    
    public var rotation = SIMD3<Float>(0, 0, 0)
    public var qRotation = simd_quatf()
    
    public var viewportWidth: Float = 1
    public var viewportHeight: Float = 1
    public var fovy: Float = 45
    
    
    public var fovyRadians: Float {
        fovy * .pi / 180
    }
    
    public var aspectRatio: Float {
        return viewportWidth / viewportHeight
    }
    
    public var view: simd_float4x4 {
        return Transform.rotationMatrix(radians: -rotation.z, axis: .init(x: 0, y: 0, z: 1)) *
        Transform.rotationMatrix(radians: -rotation.x, axis: .init(x: 1, y: 0, z: 0)) *
        Transform.rotationMatrix(radians: -rotation.y, axis: .init(x: 0, y: 1, z: 0)) *
        Transform.translationMatrix(-location)
    }
    
    public var projection: simd_float4x4 {
        return Transform.perspectiveProjection_rightHand(fovyRadians, aspectRatio, 0.01, 1000)
    }
    
    public var viewProjection: simd_float4x4 {
        return projection * view
    }
    
    
    public func rotate(around center: SIMD3<Float> = .zero, x rotationX: Float, y rotationY: Float) {
        let transform =
        Transform.rotationMatrix(radians: rotation.y + rotationY, axis: .init(x: 0, y: 1, z: 0)) *
        Transform.rotationMatrix(radians: rotationX, axis: .init(x: 1, y: 0, z: 0)) *
        Transform.rotationMatrix(radians: -rotation.y, axis: .init(x: 0, y: 1, z: 0))
        
        rotation.x += rotationX
        rotation.y += rotationY
        
        let transformed = transform * simd_float4(location, 1)
        location.x = transformed.x
        location.y = transformed.y
        location.z = transformed.z
    }
    
    public func magnify(around center: SIMD3<Float> = .zero, _ value: Float) {
        let locationToCenter = center - location
        let direction = simd_normalize(locationToCenter)
        let distance = simd_length(locationToCenter)
        
        let targetValue = distance * value
        
        // Prevent camera to be closer than 0.1
        if distance - targetValue < 0.1 {
            location = center - direction * 0.1
            return
        }
        
        // Prevent camera to be further than 500
        if distance - targetValue > 500 {
            location = center - direction * 500
            return
        }
        
        location += direction * targetValue
    }
    
    public func drag(relativeTo origin: SIMD3<Float>, by delta: Point) {
        //
    }
}


public class LMMeshInstance {
    public var mesh: LMMesh
    public var transform: matrix_float4x4 = matrix_identity_float4x4
    public var transform1: matrix_float4x4 = matrix_identity_float4x4
    
    
    public init(mesh: LMMesh) {
        self.mesh = mesh
    }
}


public class Canvas {
    public var opaqueMeshes: [LMMeshInstance] = []
    public var shadedMeshes: [LMMeshInstance] = []
    public var weightedMeshes: [LMMeshInstance] = []
    
    public let camera = Camera()
    
    
    internal var rotation: Float = 0
    
    
    public init() {
        //
    }
}
