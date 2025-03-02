//
//  InputEvent.swift
//  Lemur
//
//  Created by Evgenij Lutz on 16.02.24.
//

import Foundation


public enum MouseButtonType {
    case left
    case right
    case other/*(buttonIndex: Int)*/
}


public enum PointerType {
    case mouse(buttonType: MouseButtonType)
    case touch(index: Int)
}


public enum InputEventData {
    case pointerDown(type: PointerType, localPoint: CGPoint)
    case pointerUp(type: PointerType, localPoint: CGPoint)
    case pointerDrag(type: PointerType, delta: CGPoint)
    
    case scroll(delta: CGPoint)
    
    case keyDown(keyCode: UInt16)
    case keyUp(keyCode: UInt16)
}

public struct InputEvent {
    public let timestamp: TimeInterval
    public let data: InputEventData
}


public extension [InputEvent] {
    func mouseDrag(_ mouseButtonType: MouseButtonType) -> CGPoint? {
        reduce(CGPoint?(nil)) { partialResult, value in
            guard case let .pointerDrag(type, delta) = value.data, case let .mouse(buttonType) = type, case buttonType = mouseButtonType else {
                return partialResult
            }
            
            guard let partialResult else {
                return .init(x: delta.x, y: delta.y)
            }
            
            return .init(x: partialResult.x + delta.x, y: partialResult.y + delta.y)
        }
    }
    
    
    func scroll() -> CGPoint? {
        reduce(CGPoint?(nil)) { partialResult, value in
            guard case let .scroll(delta) = value.data else {
                return partialResult
            }
            
            guard let partialResult else {
                return .init(x: delta.x, y: delta.y)
            }
            
            return .init(x: partialResult.x + delta.x, y: partialResult.y + delta.y)
        }
    }
    
    
    func isKeyDown(_ key: UInt16) -> Bool {
        contains(where: {
            guard case .keyDown(let keyCode) = $0.data else {
                return false
            }
            
            return keyCode == key
        })
    }
}


public class InputManager {
    private let access = AccessSemaphore()
    private var inputEvents: [InputEvent] = []
    
    
    public init() {
        //
    }
    
    public func add(_ eventData: InputEventData) {
        access.access {
            inputEvents.append(
                .init(
                    timestamp: Date.now.timeIntervalSince1970,
                    data: eventData
                )
            )
            
            // Remove events older than 5 seconds
            inputEvents.removeAll { $0.timestamp < Date.now.timeIntervalSince1970 - 1 }
        }
    }
    
    public func fetch(until deadline: TimeInterval = Date.now.timeIntervalSince1970) -> [InputEvent] {
        return access.value {
            let events: [InputEvent] = inputEvents.filter { $0.timestamp <= deadline }
            inputEvents.removeAll { $0.timestamp <= deadline }
            return events
        }
    }
}
