//
//  SQLiteExtensions.swift
//  BrcIot
//
//  Created by tian on 2018/12/11.
//  Copyright © 2018 tian. All rights reserved.
//

import UIKit

@_silgen_name("swift_getFieldAt")
func _getFieldAt(
    _ type: Any.Type,
    _ index: Int,
    _ callback: @convention(c) (UnsafePointer<CChar>, UnsafeRawPointer, UnsafeMutableRawPointer) -> Void,
    _ ctx: UnsafeMutableRawPointer
)

extension UnsafePointer {
    init<T>(p: UnsafePointer<T>) {
        self = UnsafeRawPointer(p).assumingMemoryBound(to: Pointee.self)
    }
}

func sqlRelativePointer<T, U, V>(base: UnsafePointer<T>, offset: U) -> UnsafePointer<V> where U : FixedWidthInteger {
    return UnsafeRawPointer(base).advanced(by: Int(integerV: offset)).assumingMemoryBound(to: V.self)
}

extension Int {
    fileprivate init<T : FixedWidthInteger>(integerV: T) {
        switch integerV {
        case let value as Int: self = value
        case let value as Int32: self = Int(value)
        case let value as Int16: self = Int(value)
        case let value as Int8: self = Int(value)
        default: self = 0
        }
    }
}


protocol SQLiteExtensions {}

extension SQLiteExtensions {
    public static func write(_ value: Any, to storage: UnsafeMutableRawPointer) {
        guard let this = value as? Self else {
            return
        }
        storage.assumingMemoryBound(to: self).pointee = this
    }
    
    public static func takeValue(from anyValue: Any) -> Self? {
        return anyValue as? Self
    }
}

func sqlExtensions(of type: Any.Type) -> SQLiteExtensions.Type {
    struct Extensions: SQLiteExtensions {}
    var extensions: SQLiteExtensions.Type = Extensions.self
    withUnsafeMutablePointer(to: &extensions) { pointer in
        UnsafeMutableRawPointer(mutating: pointer).assumingMemoryBound(to: Any.Type.self).pointee = type
    }
    return extensions
}
