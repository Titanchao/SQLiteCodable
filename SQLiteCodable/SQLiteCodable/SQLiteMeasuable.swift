//
//  SQLiteMeasuable.swift
//  BrcIot
//
//  Created by tian on 2018/12/11.
//  Copyright © 2018 tian. All rights reserved.
//

import Foundation

public protocol SQLiteMeasurable {}

extension SQLiteMeasurable {
    mutating func headPointerOfStruct() -> UnsafeMutablePointer<Int8> {
        return withUnsafeMutablePointer(to: &self) {
            return UnsafeMutableRawPointer($0).bindMemory(to: Int8.self, capacity: MemoryLayout<Self>.stride)
        }
    }

    mutating func headPointerOfClass() -> UnsafeMutablePointer<Int8> {
        let opaquePointer = Unmanaged.passUnretained(self as AnyObject).toOpaque()
        let mutableTypedPointer = opaquePointer.bindMemory(to: Int8.self, capacity: MemoryLayout<Self>.stride)
        return UnsafeMutablePointer<Int8>(mutableTypedPointer)
    }

    mutating func headPointer() -> UnsafeMutablePointer<Int8> {
        if Self.self is AnyClass {
            return self.headPointerOfClass()
        } else {
            return self.headPointerOfStruct()
        }
    }

    func isNSObjectType() -> Bool {
        return (type(of: self) as? NSObject.Type) != nil
    }

    func getBridgedAttributeList() -> Set<String> {
        if let anyClass = type(of: self) as? AnyClass {
            return _getBridgedAttributeList(anyClass: anyClass)
        }
        return []
    }

    func _getBridgedAttributeList(anyClass: AnyClass) -> Set<String> {
        if !(anyClass is SQLiteCodable.Type) {
            return []
        }
        var propertyList = Set<String>()
        if let superClass = class_getSuperclass(anyClass), superClass != NSObject.self {
            propertyList = propertyList.union(_getBridgedAttributeList(anyClass: superClass))
        }
        let count = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        if let props = class_copyPropertyList(anyClass, count) {
            for i in 0 ..< count.pointee {
                let name = String(cString: property_getName(props.advanced(by: Int(i)).pointee))
                propertyList.insert(name)
            }
            free(props)
        }
        count.deallocate()
        return propertyList
    }

    static func size() -> Int {
        return MemoryLayout<Self>.size
    }

    static func align() -> Int {
        return MemoryLayout<Self>.alignment
    }

    static func offsetToAlignment(value: Int, align: Int) -> Int {
        let m = value % align
        return m == 0 ? 0 : (align - m)
    }
}

