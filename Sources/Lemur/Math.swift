//
//  Math.swift
//  Lemur
//
//  Created by Evgenij Lutz on 29.01.24.
//

import Foundation
import simd


public extension matrix_float4x4 {
    static func translation(_ vector: SIMD3<Float>) -> matrix_float4x4 {
        let col0 = SIMD4<Float>(1, 0, 0, 0)
        let col1 = SIMD4<Float>(0, 1, 0, 0)
        let col2 = SIMD4<Float>(0, 0, 1, 0)
        let col3 = SIMD4<Float>(vector, 1)
        return .init(col0, col1, col2, col3)
    }
    
    static func wadRotation(_ vector: SIMD3<Float>) -> matrix_float4x4 {
        let qx = Transform.quaternionFromEuler(.init(vector.x, 0, 0))
        let qy = Transform.quaternionFromEuler(.init(0, vector.y, 0))
        let qz = Transform.quaternionFromEuler(.init(0, 0, vector.z))
        return (qy * (qx * qz)).matrix
    }
}


public extension simd_quatf {
    var matrix: matrix_float4x4 {
        let xx = vector.x * vector.x
        let xy = vector.x * vector.y
        let xz = vector.x * vector.z
        let xw = vector.x * vector.w
        let yy = vector.y * vector.y
        let yz = vector.y * vector.z
        let yw = vector.y * vector.w
        let zz = vector.z * vector.z
        let zw = vector.z * vector.w
        
        // indices are m<column><row>
        let m00 = 1 - 2 * (yy + zz)
        let m10 = 2 * (xy - zw)
        let m20 = 2 * (xz + yw)
        
        let m01 = 2 * (xy + zw)
        let m11 = 1 - 2 * (xx + zz)
        let m21 = 2 * (yz - xw)
        
        let m02 = 2 * (xz - yw)
        let m12 = 2 * (yz + xw)
        let m22 = 1 - 2 * (xx + yy)
        
        let col0 = SIMD4<Float>(m00, m01, m02, 0)
        let col1 = SIMD4<Float>(m10, m11, m12, 0)
        let col2 = SIMD4<Float>(m20, m21, m22, 0)
        let col3 = SIMD4<Float>(0, 0, 0, 1)
        return .init(col0, col1, col2, col3)
    }
}


public enum Transform {
    public static func translationMatrix(_ translation: SIMD3<Float>) -> simd_float4x4 {
        let col0 = SIMD4<Float>(1, 0, 0, 0)
        let col1 = SIMD4<Float>(0, 1, 0, 0)
        let col2 = SIMD4<Float>(0, 0, 1, 0)
        let col3 = SIMD4<Float>(translation, 1)
        return .init(col0, col1, col2, col3)
    }
    
    
    public static func rotationMatrix(radians: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        let normalizedAxis = simd_normalize(axis)
        
        let ct = cosf(radians)
        let st = sinf(radians)
        let ci = 1 - ct
        let x = normalizedAxis.x
        let y = normalizedAxis.y
        let z = normalizedAxis.z
        
        let col0 = SIMD4<Float>(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0)
        let col1 = SIMD4<Float>(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0)
        let col2 = SIMD4<Float>(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0)
        let col3 = SIMD4<Float>(0, 0, 0, 1)
        
        return .init(col0, col1, col2, col3)
    }
    
    
    public static func quaternionFromEuler(_ euler: SIMD3<Float>) -> simd_quatf {
        let cx = cos(euler.x / 2)
        let cy = cos(euler.y / 2)
        let cz = cos(euler.z / 2)
        let sx = sin(euler.x / 2)
        let sy = sin(euler.y / 2)
        let sz = sin(euler.z / 2)
        
        let w = cx * cy * cz + sx * sy * sz
        let x = sx * cy * cz - cx * sy * sz
        let y = cx * sy * cz + sx * cy * sz
        let z = cx * cy * sz - sx * sy * cz
        
        return .init(ix: x, iy: y, iz: z, r: w);
    }
    
    
    public static func perspectiveProjection_rightHand(_ fovyRadians: Float,
                                                       _ aspectRatio: Float,
                                                       _ nearZ: Float,
                                                       _ farZ: Float) -> simd_float4x4 {
        let ys = 1 / tanf(fovyRadians * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (nearZ - farZ)
        let tz = nearZ * zs;
        
        let col0 = SIMD4<Float>(xs, 0, 0, 0)
        let col1 = SIMD4<Float>(0, ys, 0, 0)
        let col2 = SIMD4<Float>(0, 0, zs, -1)
        let col3 = SIMD4<Float>(0, 0, tz, 0)
        
        return .init(col0, col1, col2, col3)
    }
}
