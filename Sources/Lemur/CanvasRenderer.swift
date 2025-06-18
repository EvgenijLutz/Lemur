//
//  CanvasRenderer.swift
//  Lemur
//
//  Created by Evgenij Lutz on 27.01.24.
//

import QuartzCore
@preconcurrency import Metal
import OSLog
import LemurC


//fileprivate let logger = Logger(subsystem: "Graphics", category: "canvas renderer")


public class AccessSemaphore {
    private let accessSemaphore = DispatchSemaphore(value: 1)
    
    
    public init() {
        //
    }
    
    public func access(_ action: () -> Void) {
        accessSemaphore.wait()
        action()
        accessSemaphore.signal()
    }
    
    public func value<DataType>(_ action: () -> DataType) -> DataType {
        accessSemaphore.wait()
        let value = action()
        accessSemaphore.signal()
        return value
    }
}


fileprivate let numSemaphores = 3


enum RendererError: Error {
    case renderEngineNotReady
    
    case noMetalDeviceAvailable
    case cannotCreateCommandQueue
    
    case failedToLoadMetalLibrary(name: String)
    
    case failedToCreateDepthStencilState(name: String)
    case failedToCreateSamplerState(name: String)
}


fileprivate struct RenderDataSettings: Hashable {
    let pixelFormat: MTLPixelFormat
    let depthStencilPixelFormat: MTLPixelFormat
}


@MainActor
fileprivate class RenderDataHolder {
    fileprivate(set) var data: RenderData?
    fileprivate(set) var error: Error?
}


/// Render data for specific pixel format
@MainActor
class RenderData {
    let device: MTLDevice
    let renderQueue: MTLCommandQueue
    
    let pixelFormat: MTLPixelFormat
    let depthStencilPixelFormat: MTLPixelFormat
    
    let opaqueMeshRPS: MTLRenderPipelineState
    let shadedMeshRPS: MTLRenderPipelineState
    let weightedMeshRPS: MTLRenderPipelineState
    
    
    init(device: MTLDevice, renderQueue: MTLCommandQueue, pixelFormat: MTLPixelFormat, depthStencilPixelFormat: MTLPixelFormat) async throws {
        self.device = device
        self.renderQueue = renderQueue
        
        self.pixelFormat = pixelFormat
        self.depthStencilPixelFormat = depthStencilPixelFormat
        
        
        // Mesh rendering state
        let library = try device.makeDefaultLibrary(bundle: Bundle.module)
        //guard let library = device.makeDefaultLibrary() else {
        //    throw RendererError.failedToLoadMetalLibrary(name: "default")
        //}
        
        // Opaque meshes
        do {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "mesh_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "mesh_fragment")
            if let attachment = descriptor.colorAttachments[0] {
                attachment.pixelFormat = pixelFormat
                attachment.isBlendingEnabled = false
            }
            
            descriptor.depthAttachmentPixelFormat = depthStencilPixelFormat
            descriptor.stencilAttachmentPixelFormat = depthStencilPixelFormat
            
            descriptor.isAlphaToCoverageEnabled = true
            
            if let vd = descriptor.vertexDescriptor {
                // Position
                vd.attributes[0].format = .float3
                vd.attributes[0].bufferIndex = 0
                vd.attributes[0].offset = 0
                
                // UV
                vd.attributes[1].format = .float2
                vd.attributes[1].bufferIndex = 0
                vd.attributes[1].offset = 12
                
                // Normal
                vd.attributes[2].format = .float3
                vd.attributes[2].bufferIndex = 0
                vd.attributes[2].offset = 20
                
                vd.layouts[0].stride = 32
                vd.layouts[0].stepFunction = .perVertex
            }
            
            opaqueMeshRPS = try await device.makeRenderPipelineState(descriptor: descriptor)
        }
        
        // Shaded meshes
        do {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "shadedMesh_vf")
            descriptor.fragmentFunction = library.makeFunction(name: "shadedMesh_ff")
            if let attachment = descriptor.colorAttachments[0] {
                attachment.pixelFormat = pixelFormat
                attachment.isBlendingEnabled = false
            }
            
            descriptor.depthAttachmentPixelFormat = depthStencilPixelFormat
            descriptor.stencilAttachmentPixelFormat = depthStencilPixelFormat
            
            descriptor.isAlphaToCoverageEnabled = true
            
            if let vd = descriptor.vertexDescriptor {
                // Position
                vd.attributes[0].format = .float3
                vd.attributes[0].bufferIndex = 0
                vd.attributes[0].offset = 0
                
                // UV
                vd.attributes[1].format = .float2
                vd.attributes[1].bufferIndex = 0
                vd.attributes[1].offset = 12
                
                // Shade
                vd.attributes[2].format = .float
                vd.attributes[2].bufferIndex = 0
                vd.attributes[2].offset = 20
                
                vd.layouts[0].stride = 24
                vd.layouts[0].stepFunction = .perVertex
            }
            
            shadedMeshRPS = try await device.makeRenderPipelineState(descriptor: descriptor)
        }
        
        // Weighted meshes
        do {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "weightedMesh_vf")
            descriptor.fragmentFunction = library.makeFunction(name: "weightedMesh_ff")
            if let attachment = descriptor.colorAttachments[0] {
                attachment.pixelFormat = pixelFormat
                attachment.isBlendingEnabled = false
            }
            
            descriptor.depthAttachmentPixelFormat = depthStencilPixelFormat
            descriptor.stencilAttachmentPixelFormat = depthStencilPixelFormat
            
            descriptor.isAlphaToCoverageEnabled = true
            
            if let vd = descriptor.vertexDescriptor {
                // Position
                vd.attributes[0].format = .float3
                vd.attributes[0].bufferIndex = 0
                vd.attributes[0].offset = 0
                
                // UV
                vd.attributes[1].format = .float2
                vd.attributes[1].bufferIndex = 0
                vd.attributes[1].offset = 12
                
                // Normal
                vd.attributes[2].format = .float3
                vd.attributes[2].bufferIndex = 0
                vd.attributes[2].offset = 20
                
                // Offset
                vd.attributes[3].format = .float3
                vd.attributes[3].bufferIndex = 0
                vd.attributes[3].offset = 32
                
                // Weight 0
                vd.attributes[4].format = .float
                vd.attributes[4].bufferIndex = 0
                vd.attributes[4].offset = 44
                
                // Weight 1
                vd.attributes[5].format = .float
                vd.attributes[5].bufferIndex = 0
                vd.attributes[5].offset = 48
                
                vd.layouts[0].stride = 52
                vd.layouts[0].stepFunction = .perVertex
            }
            
            weightedMeshRPS = try await device.makeRenderPipelineState(descriptor: descriptor)
        }
        
    }
}


// MARK: - Render engine

@MainActor
public class RenderEngine {
    public let device: MTLDevice
    
    let renderQueue: MTLCommandQueue
    
    let writeIfLessDepthStencilState: MTLDepthStencilState
    
    let anisotropicSamplerState: MTLSamplerState
    let nearestNeighborSamplerState: MTLSamplerState
    
    // Different versions of render data distincted by output pixel formats
    fileprivate var renderData: [RenderDataSettings: RenderDataHolder] = [:]
    
    
    init() throws {
        let startTime = CACurrentMediaTime()
        
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            throw RendererError.noMetalDeviceAvailable
        }
        device = metalDevice
        
        guard let metalRenderQueue = device.makeCommandQueue() else {
            throw RendererError.cannotCreateCommandQueue
        }
        renderQueue = metalRenderQueue
        
        // Depth/stencil state
        do {
            let depthStencilDescriptor = MTLDepthStencilDescriptor()
            depthStencilDescriptor.isDepthWriteEnabled = true
            depthStencilDescriptor.depthCompareFunction = .less
            depthStencilDescriptor.frontFaceStencil = nil
            depthStencilDescriptor.backFaceStencil = nil
            depthStencilDescriptor.label = "depth/stencil"
            guard let state = device.makeDepthStencilState(descriptor: depthStencilDescriptor) else {
                throw RendererError.failedToCreateDepthStencilState(name: "depth/stencil")
            }
            
            writeIfLessDepthStencilState = state
        }
        
        // Sampler state
        do {
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.label = "Anisotropic sampler"
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            samplerDescriptor.mipFilter = .linear
            samplerDescriptor.sAddressMode = .repeat
            samplerDescriptor.tAddressMode = .repeat
            samplerDescriptor.maxAnisotropy = 16
            
            guard let state = device.makeSamplerState(descriptor: samplerDescriptor) else {
                throw RendererError.failedToCreateSamplerState(name: "Anisotropic sampler")
            }
            
            anisotropicSamplerState = state
        }
        
        
        do {
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.label = "Nearest neighbor sampler"
            samplerDescriptor.minFilter = .nearest
            samplerDescriptor.magFilter = .nearest
            samplerDescriptor.mipFilter = .nearest
            samplerDescriptor.sAddressMode = .repeat
            samplerDescriptor.tAddressMode = .repeat
            samplerDescriptor.maxAnisotropy = 1
            
            guard let state = device.makeSamplerState(descriptor: samplerDescriptor) else {
                throw RendererError.failedToCreateSamplerState(name: "Nearest neighbor sampler")
            }
            
            nearestNeighborSamplerState = state
        }
        
        let elapsed = CACurrentMediaTime() - startTime
        logger.log("Render engine initialized in \(elapsed) seconds")
    }
    
    
    fileprivate func getRenderDataHolder(for pixelFormat: MTLPixelFormat, depthStencilPixelFormat: MTLPixelFormat) -> RenderDataHolder? {
        let key = RenderDataSettings(pixelFormat: pixelFormat, depthStencilPixelFormat: depthStencilPixelFormat)
        if let value = renderData[key] {
            return value
        }
        
        let value = RenderDataHolder()
        renderData[key] = value
        Task {
            do {
                value.data = try await RenderData(device: device, renderQueue: renderQueue, pixelFormat: pixelFormat, depthStencilPixelFormat: depthStencilPixelFormat)
            }
            catch {
                value.error = error
                print(error)
            }
        }

        return value
    }
    
    
    public func createTexture(from data: borrowing Data, width: Int, height: Int) async throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .bgra8Unorm
        descriptor.width = width
        descriptor.height = height
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
    
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            print("Could not create a texture")
            throw LemurError.cannotCreateTexture
        }
    
        try data.withUnsafeBytes { pointer in
            guard let baseAddress = pointer.baseAddress else {
                throw LemurError.couldNotGetTextureContentsToCopy
            }
            texture.replace(region: MTLRegionMake2D(0, 0, width, height),
                            mipmapLevel: 0,
                            withBytes: baseAddress,
                            bytesPerRow: width * 4)
        }
    
        return texture
    }
    
    
    public func createBuffer(from data: borrowing Data) async throws -> MTLBuffer {
        // TODO: These two code blocks produce the same result, but whyyyyy does the code in the first block crash in the RELEASE mode
#if false
        guard let buffer = device.makeBuffer(length: data.count, options: .storageModeShared) else {
            throw LemurError.cannotCreateBuffer
        }
        
        try data.withUnsafeBytes { pointer in
            guard let baseAddress = pointer.baseAddress else {
                throw LemurError.couldNotGetTextureContentsToCopy
            }
            // FIXME: Crashes here on RELEASE. Why does it not crash if the print statement is uncommented?
            //print("Contents: \(buffer.length), base address: \(baseAddress), count: \(data.count), pointer: \(pointer)")
            // This will also work
            //_ = "Contents: \(buffer.length), base address: \(baseAddress), count: \(data.count), pointer: \(pointer)"
            buffer.contents().copyMemory(from: baseAddress, byteCount: data.count)
        }
#else
        let buffer = try data.withUnsafeBytes { pointer in
            guard let baseAddress = pointer.baseAddress else {
                throw LemurError.couldNotGetTextureContentsToCopy
            }
            
            return device.makeBuffer(bytes: baseAddress, length: pointer.count, options: .storageModeShared)
        }
        
        guard let buffer else {
            throw LemurError.cannotCreateBuffer
        }
#endif
        
        return buffer
    }
}


@MainActor fileprivate(set) public var renderEngineCreationError: Error? = nil


@MainActor
public let renderEngine: RenderEngine? = {
    do {
        return try RenderEngine()
    }
    catch {
        renderEngineCreationError = error
        return nil
    }
}()


class SharedCounter {
    let maxValue: Int
    private(set) var currentValue: Int
    
    init(maxValue: Int = 3) {
        self.maxValue = maxValue
        self.currentValue = 0
    }
    
    func tick() {
        currentValue = (currentValue + 1) % maxValue
    }
}


/// Dynamically resizable uniform buffer
class UniformBufferChain<UniformType> {
    public let itemStride = MemoryLayout<UniformType>.stride
    
    private let counter: SharedCounter
    
    private let device: MTLDevice
    private var buffers: [MTLBuffer]
    
    private let capacityStep: Int
    private var capacity: Int
    
    var currentBuffer: MTLBuffer {
        reallocateIfNeeded(for: 0)
        return buffers[counter.currentValue]
    }
    
    func offsetForItem(at index: Int) -> Int {
        reallocateIfNeeded(for: index)
        return itemStride * index
    }
    
    
    init(counter: SharedCounter, device: MTLDevice, capacityStep: Int = 512) {
        self.counter = counter
        
        self.device = device
        self.buffers = []
        
        self.capacityStep = max(4, capacityStep)
        self.capacity = 0
    }
    
    
    func reallocateIfNeeded(for index: Int) {
        // Check if we really need to do it
        guard index >= capacity else {
            return
        }
        
        // Calculate new capacity
        let newCapacity = (index / capacityStep + 1) * capacityStep
        
        // Allocate buffers
        for index in 0 ..< counter.maxValue {
            guard let buffer = device.makeBuffer(length: itemStride * newCapacity, options: .storageModeShared) else {
                fatalError("Cannot allocate buffer")
            }
            
            // Copy previous contents and replace with the new version
            if index < buffers.count {
                let oldBuffer = buffers[index]
                buffer.contents().copyMemory(from: oldBuffer.contents(), byteCount: oldBuffer.length)
                buffers[index] = buffer
            }
            // Or append buffer if it's created for the first time
            else {
                buffers.append(buffer)
            }
        }
        
        // Apply new capacity
        capacity = newCapacity
    }
    
    
    func setValue(_ value: UniformType, at index: Int) {
        reallocateIfNeeded(for: index)
        
        let buffer = buffers[counter.currentValue]
        buffer.contents().advanced(by: itemStride * index).storeBytes(of: value, as: UniformType.self)
    }
}


@MainActor
/// Renderer that caches render data
public class CanvasRenderer {
    public let device: MTLDevice
    private let depthStencilPixelFormat: MTLPixelFormat = .depth32Float_stencil8
    
    /// Reusable render pass descriptor
    private let renderPassDescriptor = MTLRenderPassDescriptor()
    

    public var canvas: LMCanvas? = nil
    
    
    // TODO: Make part of sharedCounter?
    private var frameSemaphore = DispatchSemaphore(value: numSemaphores)
    private let sharedCounter = SharedCounter(maxValue: numSemaphores)
    
    
    // TODO: Move to canvas
    private let standardMeshUniforms: UniformBufferChain<MeshUniform>
    private let shadedMeshUniforms: UniformBufferChain<MeshUniform>
    private let weightedMeshUniforms: UniformBufferChain<WeightedMeshUniform>
    private let sceneUniformChain: UniformBufferChain<SceneUniform>
    
    
    public init() throws {
        guard let device = renderEngine?.device else {
            throw RendererError.renderEngineNotReady
        }
        
        self.device = device
        
        standardMeshUniforms = .init(counter: sharedCounter, device: device)
        shadedMeshUniforms = .init(counter: sharedCounter, device: device)
        weightedMeshUniforms = .init(counter: sharedCounter, device: device)
        sceneUniformChain = .init(counter: sharedCounter, device: device, capacityStep: 4)
        
        
        if let finalColorAttachment = renderPassDescriptor.colorAttachments[0] {
            finalColorAttachment.loadAction = .clear
            //finalColorAttachment.clearColor = .init(red: 0.33, green: 0.33, blue: 0.33, alpha: 1.0)
            finalColorAttachment.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0.0)
            finalColorAttachment.storeAction = .store
        }
        
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        
        renderPassDescriptor.stencilAttachment.loadAction = .clear
        renderPassDescriptor.stencilAttachment.clearStencil = 0
        renderPassDescriptor.stencilAttachment.storeAction = .dontCare
    }
    
    private var depthStencilTarget: MTLTexture? = nil
    
    private func updateRenderTargets(_ width: Int, _ height: Int) {
        if let depthStencilTarget, depthStencilTarget.width == width, depthStencilTarget.height == height {
            return
        }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = depthStencilPixelFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.storageMode = .memoryless
        descriptor.usage = .renderTarget
        depthStencilTarget = device.makeTexture(descriptor: descriptor)
    }
    
}


extension CanvasRenderer: Renderable {
    public func render(to drawable: CAMetalDrawable, timestamp: CFTimeInterval, presentationTimestamp: CFTimeInterval?, targetTimestamp: CFTimeInterval?, forceWait: Bool) {
#if os(macOS)
        if let mode = RunLoop.current.currentMode, mode.rawValue != RunLoop.Mode.default.rawValue, mode.rawValue != RunLoop.Mode.eventTracking.rawValue {
            print("Current loop mode: \(mode.rawValue)")
        }
#endif
        
        guard let renderEngine else {
            // Render engine is not available
            return
        }
        
        let renderDataHolder = renderEngine.getRenderDataHolder(for: drawable.texture.pixelFormat, depthStencilPixelFormat: depthStencilPixelFormat)
        
        guard let canvas else {
            // No canvas set - draw empty screen
            return
        }
        
        
        let renderQueue = renderEngine.renderQueue
        
        frameSemaphore.wait()
        
        sharedCounter.tick()
        
        let currentMeshUniformBuffer = standardMeshUniforms.currentBuffer
        let currentShadedMeshUniformBuffer = shadedMeshUniforms.currentBuffer
        let currentWeightedMeshUniformBuffer = weightedMeshUniforms.currentBuffer
        
        let meshUniformsStride = standardMeshUniforms.itemStride
        let weightedMeshUniformsStride = weightedMeshUniforms.itemStride
        
        // Update opaque mesh uniforms
        for (index, mesh) in canvas.opaqueMeshes.enumerated() {
            var meshUniforms = MeshUniform()
            meshUniforms.model = mesh.transform
            standardMeshUniforms.setValue(meshUniforms, at: index)
        }
        
        // Update shaded mesh uniforms
        for (index, mesh) in canvas.shadedMeshes.enumerated() {
            var meshUniforms = MeshUniform()
            meshUniforms.model = mesh.transform
            shadedMeshUniforms.setValue(meshUniforms, at: index)
        }
        
        // Update weighted mesh uniforms
        for (index, mesh) in canvas.weightedMeshes.enumerated() {
            var meshUniforms = WeightedMeshUniform()
            meshUniforms.model0 = mesh.transform
            meshUniforms.model1 = mesh.transform1
            weightedMeshUniforms.setValue(meshUniforms, at: index)
        }
        
        //rotation += 0.01
        
        
        // Update the camera uniform
        var sceneUniforms = SceneUniform()
//        let radians = Float(60) * .pi / 180
//        let aspect = Float(drawable.texture.width) / Float(drawable.texture.height)
//        sceneUniforms.viewProjection =
//        Transform.perspectiveProjection_rightHand(radians, aspect, 0.05, 1000) *
//        Transform.translationMatrix(.init(x: 0, y: 0, z: -0.2)) *
//        Transform.rotationMatrix(radians: rotation, axis: .init(x: 0, y: 1, z: 0))
        
        sceneUniforms.viewProjection = canvas.camera.viewProjection
        
        sceneUniformChain.setValue(sceneUniforms, at: 0)
        let currentSceneUniformBuffer = sceneUniformChain.currentBuffer
        
        guard let commandBuffer = renderQueue.makeCommandBuffer() else {
            print("no command buffer")
            frameSemaphore.signal()
            return
        }
        
        updateRenderTargets(drawable.texture.width, drawable.texture.height)
        
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.depthAttachment.texture = depthStencilTarget
        renderPassDescriptor.stencilAttachment.texture = depthStencilTarget
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("no encoder")
            frameSemaphore.signal()
            return
        }
        
        commandBuffer.addCompletedHandler { _ in
            self.frameSemaphore.signal()
        }
        
        if let renderData = renderDataHolder?.data {
            encoder.setFrontFacing(.counterClockwise)
            encoder.setDepthStencilState(renderEngine.writeIfLessDepthStencilState)
            encoder.setCullMode(.back)
            
            encoder.setVertexBuffer(currentSceneUniformBuffer, offset: 0, index: 2)
            encoder.setFragmentBuffer(currentSceneUniformBuffer, offset: 0, index: 0)
            
            encoder.setFragmentSamplerState(renderEngine.nearestNeighborSamplerState, index: 0)
            
            
            if !canvas.opaqueMeshes.isEmpty {
                encoder.setRenderPipelineState(renderData.opaqueMeshRPS)
                for (index, instance) in canvas.opaqueMeshes.enumerated() {
                    let mesh = instance.mesh
                    encoder.setVertexBuffer(currentMeshUniformBuffer, offset: meshUniformsStride * index, index: 1)
                    encoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
                    encoder.setFragmentTexture(mesh.texture, index: 0)
                    
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.numVertices)
                }
            }
            
            if !canvas.shadedMeshes.isEmpty {
                encoder.setRenderPipelineState(renderData.shadedMeshRPS)
                for (index, instance) in canvas.shadedMeshes.enumerated() {
                    let mesh = instance.mesh
                    encoder.setVertexBuffer(currentShadedMeshUniformBuffer, offset: meshUniformsStride * index, index: 1)
                    encoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
                    encoder.setFragmentTexture(mesh.texture, index: 0)
                    
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.numVertices)
                }
            }
            
            if !canvas.weightedMeshes.isEmpty {
                encoder.setRenderPipelineState(renderData.weightedMeshRPS)
                for (index, instance) in canvas.weightedMeshes.enumerated() {
                    let mesh = instance.mesh
                    encoder.setVertexBuffer(currentWeightedMeshUniformBuffer, offset: weightedMeshUniformsStride * index, index: 1)
                    encoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
                    encoder.setFragmentTexture(mesh.texture, index: 0)
                    
                    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.numVertices)
                }
            }
        }
        
        encoder.endEncoding()
        
        if let targetTimestamp, !forceWait {
            commandBuffer.present(drawable, atTime: targetTimestamp)
        }
        else {
            commandBuffer.present(drawable)
        }
        
        
        commandBuffer.commit()
        
        if targetTimestamp != nil || forceWait {
            commandBuffer.waitUntilScheduled()
            //commandBuffer.waitUntilCompleted()
        }
    }
}
