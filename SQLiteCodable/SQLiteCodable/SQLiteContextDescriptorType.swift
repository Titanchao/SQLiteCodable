//
//  SQLiteContextDescriptorType.swift
//  BrcIot
//
//  Created by tian on 2018/12/11.
//  Copyright © 2018 tian. All rights reserved.
//

protocol SQLiteContextDescriptorType : MetadataType {
    var contextDescriptorOffsetLocation: Int { get }
}

extension SQLiteContextDescriptorType {
    var contextDescriptor: SQLiteContextDescriptorProtocol? {
        let pointer = UnsafePointer<Int>(p: self.pointer)
        let base = pointer.advanced(by: contextDescriptorOffsetLocation)
        if base.pointee == 0 {
            return nil
        }
        if self.kind == .class {
            return SQLiteContextDescriptor<_SQLiteClassContextDescriptor>(pointer: sqlRelativePointer(base: base, offset: base.pointee - Int(bitPattern: base)))
        } else {
            return SQLiteContextDescriptor<_SQLiteStructContextDescriptor>(pointer: sqlRelativePointer(base: base, offset: base.pointee - Int(bitPattern: base)))
        }
    }

    var numberOfFields: Int {
        return contextDescriptor?.numberOfFields ?? 0
    }

    var fieldOffsets: [Int]? {
        guard let contextDescriptor = self.contextDescriptor else {
            return nil
        }
        let vectorOffset = contextDescriptor.fieldOffsetVector
        guard vectorOffset != 0 else {
            return nil
        }
        if self.kind == .class {
            return (0 ..< contextDescriptor.numberOfFields).map {
                return UnsafePointer<Int>(p: pointer)[vectorOffset + $0]
            }
        } else {
            return (0 ..< contextDescriptor.numberOfFields).map {
                return Int(UnsafePointer<Int32>(p: pointer)[vectorOffset * (is64BitPlatform ? 2 : 1) + $0])
            }
        }
    }
}

protocol SQLiteContextDescriptorProtocol {
    var numberOfFields: Int { get }
    var fieldOffsetVector: Int { get }
}

struct SQLiteContextDescriptor<T: _SQLiteContextDescriptorProtocol>: SQLiteContextDescriptorProtocol, SQLitePointerType {

    var pointer: UnsafePointer<T>

    var numberOfFields: Int {
        return Int(pointer.pointee.numberOfFields)
    }

    var fieldOffsetVector: Int {
        return Int(pointer.pointee.fieldOffsetVector)
    }
}

protocol _SQLiteContextDescriptorProtocol {
    var mangledName: Int32 { get }
    var numberOfFields: Int32 { get }
    var fieldOffsetVector: Int32 { get }
    var fieldTypesAccessor: Int32 { get }
}

struct _SQLiteStructContextDescriptor: _SQLiteContextDescriptorProtocol {
    var flags: Int32
    var parent: Int32
    var mangledName: Int32
    var fieldTypesAccessor: Int32
    var numberOfFields: Int32
    var fieldOffsetVector: Int32
}

struct _SQLiteClassContextDescriptor: _SQLiteContextDescriptorProtocol {
    var flags: Int32
    var parent: Int32
    var mangledName: Int32
    var fieldTypesAccessor: Int32
    var superClsRef: Int32
    var reservedWord1: Int32
    var reservedWord2: Int32
    var numImmediateMembers: Int32
    var numberOfFields: Int32
    var fieldOffsetVector: Int32
}

protocol SQLitePointerType : Equatable {
    associatedtype Pointee
    var pointer: UnsafePointer<Pointee> { get set }
}

extension SQLitePointerType {
    init<T>(pointer: UnsafePointer<T>) {
        func cast<T, U>(_ value: T) -> U {
            return unsafeBitCast(value, to: U.self)
        }
        self = cast(UnsafePointer<Pointee>(p: pointer))
    }
}
