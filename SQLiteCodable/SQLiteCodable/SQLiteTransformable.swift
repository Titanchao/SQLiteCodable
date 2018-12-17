//
//  SQLiteTransformable.swift
//  BrcIot
//
//  Created by tian on 2018/12/11.
//  Copyright © 2018 tian. All rights reserved.
//

import Foundation

public protocol SQLiteTransformable: SQLiteMeasurable {}

extension SQLiteTransformable {
    static func sqlTransform(from object: Any) -> Self? {
        if let typedObject = object as? Self {
            return typedObject
        }
        switch self {
        case let type as _SQLiteCustomBasicType.Type:
            return type._sqlTransform(from: object) as? Self
        case let type as _BuiltInBridgeType.Type:
            return type._sqlTransform(from: object) as? Self
        case let type as _SQLiteBasicType.Type:
            return type._sqlTransform(from: object) as? Self
        case let type as SQLiteCodable.Type:
            return type._sqlTransform(from: object) as? Self
        default:
            return nil
        }
    }

    func sqlPlainValue() -> Any? {
        switch self {
        case let rawValue as _SQLiteCustomBasicType:
            return rawValue._sqlPlainValue()
        case let rawValue as _BuiltInBridgeType:
            return rawValue._sqlPlainValue()
        case let rawValue as _SQLiteBasicType:
            return rawValue._sqlPlainValue()
        case let rawValue as SQLiteCodable:
            return rawValue._sqlPlainValue()
        default:
            return nil
        }
    }
}

public protocol _SQLiteCustomBasicType: SQLiteTransformable {
    static func _sqlTransform(from object: Any) -> Self?
    func _sqlPlainValue() -> Any?
}

protocol _SQLiteBasicType: SQLiteTransformable {
    static func _sqlTransform(from object: Any) -> Self?
    func _sqlPlainValue() -> Any?
}

protocol SQLiteIntegerPropertyProtocol: FixedWidthInteger, _SQLiteBasicType {
    init?(_ text: String, radix: Int)
    init(_ number: NSNumber)
}

extension SQLiteIntegerPropertyProtocol {
    static func _sqlTransform(from object: Any) -> Self? {
        switch object {
        case let str as String:
            return Self(str, radix: 10)
        case let num as NSNumber:
            return Self(num)
        default:
            return nil
        }
    }
    
    func _sqlPlainValue() -> Any? {
        return self
    }
}

extension Int: SQLiteIntegerPropertyProtocol {}
extension UInt: SQLiteIntegerPropertyProtocol {}
extension Int8: SQLiteIntegerPropertyProtocol {}
extension Int16: SQLiteIntegerPropertyProtocol {}
extension Int32: SQLiteIntegerPropertyProtocol {}
extension Int64: SQLiteIntegerPropertyProtocol {}
extension UInt8: SQLiteIntegerPropertyProtocol {}
extension UInt16: SQLiteIntegerPropertyProtocol {}
extension UInt32: SQLiteIntegerPropertyProtocol {}
extension UInt64: SQLiteIntegerPropertyProtocol {}

extension Bool: _SQLiteBasicType {
    static func _sqlTransform(from object: Any) -> Bool? {
        switch object {
        case let str as NSString:
            let lowerCase = str.lowercased
            if ["0", "false"].contains(lowerCase) {
                return false
            }
            if ["1", "true"].contains(lowerCase) {
                return true
            }
            return nil
        case let num as NSNumber:
            return num.boolValue
        default:
            return nil
        }
    }
    
    func _sqlPlainValue() -> Any? {
        return self
    }
}

protocol SQLiteFloatPropertyProtocol: _SQLiteBasicType, LosslessStringConvertible {
    init(_ number: NSNumber)
}

extension SQLiteFloatPropertyProtocol {
    static func _sqlTransform(from object: Any) -> Self? {
        switch object {
        case let str as String:
            return Self(str)
        case let num as NSNumber:
            return Self(num)
        default:
            return nil
        }
    }
    
    func _sqlPlainValue() -> Any? {
        return self
    }
}

extension Float: SQLiteFloatPropertyProtocol {}
extension Double: SQLiteFloatPropertyProtocol {}
//extension CGFloat: SQLiteFloatPropertyProtocol {}

fileprivate let formatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.usesGroupingSeparator = false
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 16
    return formatter
}()

extension String: _SQLiteBasicType {
    static func _sqlTransform(from object: Any) -> String? {
        switch object {
        case let str as String:
            return str
        case let num as NSNumber:
            if NSStringFromClass(type(of: num)) == "__NSCFBoolean" {
                if num.boolValue {
                    return "true"
                } else {
                    return "false"
                }
            }
            return formatter.string(from: num)
        case _ as NSNull:
            return nil
        default:
            return "\(object)"
        }
    }
    
    func _sqlPlainValue() -> Any? {
        return self
    }
}

extension Optional: _SQLiteBasicType {
    static func _sqlTransform(from object: Any) -> Optional? {
        if let value = (Wrapped.self as? SQLiteTransformable.Type)?.sqlTransform(from: object) as? Wrapped {
            return Optional(value)
        } else if let value = object as? Wrapped {
            return Optional(value)
        }
        return nil
    }
    
    func _getWrappedValue() -> Any? {
        return self.map( { (wrapped) -> Any in
            return wrapped as Any
        })
    }
    
    func _sqlPlainValue() -> Any? {
        if let value = _getWrappedValue() {
            if let transformable = value as? SQLiteTransformable {
                return transformable.sqlPlainValue()
            } else {
                return value
            }
        }
        return nil
    }
}

extension Collection {
    static func _collectionTransform(from object: Any) -> [Iterator.Element]? {
        guard let arr = object as? [Any] else {
            return nil
        }
        typealias Element = Iterator.Element
        var result: [Element] = [Element]()
        arr.forEach { (each) in
            if let element = (Element.self as? SQLiteTransformable.Type)?.sqlTransform(from: each) as? Element {
                result.append(element)
            } else if let element = each as? Element {
                result.append(element)
            }
        }
        return result
    }
    
    func _collectionPlainValue() -> Any? {
        typealias Element = Iterator.Element
        var result: [Any] = [Any]()
        self.forEach { (each) in
            if let transformable = each as? SQLiteTransformable, let transValue = transformable.sqlPlainValue() {
                result.append(transValue)
            }
        }
        return result
    }
}

extension Array: _SQLiteBasicType {
    static func _sqlTransform(from object: Any) -> [Element]? {
        return self._collectionTransform(from: object)
    }
    
    func _sqlPlainValue() -> Any? {
        return self._collectionPlainValue()
    }
}

extension Set: _SQLiteBasicType {
    static func _sqlTransform(from object: Any) -> Set<Element>? {
        if let arr = self._collectionTransform(from: object) {
            return Set(arr)
        }
        return nil
    }
    
    func _sqlPlainValue() -> Any? {
        return self._collectionPlainValue()
    }
}

extension Dictionary: _SQLiteBasicType {
    static func _sqlTransform(from object: Any) -> [Key: Value]? {
        guard let dict = object as? [String: Any] else {
            return nil
        }
        var result = [Key: Value]()
        for (key, value) in dict {
            if let sKey = key as? Key {
                if let nValue = (Value.self as? SQLiteTransformable.Type)?.sqlTransform(from: value) as? Value {
                    result[sKey] = nValue
                } else if let nValue = value as? Value {
                    result[sKey] = nValue
                }
            }
        }
        return result
    }
    
    func _sqlPlainValue() -> Any? {
        var result = [String: Any]()
        for (key, value) in self {
            if let key = key as? String {
                if let transformable = value as? SQLiteTransformable {
                    if let transValue = transformable.sqlPlainValue() {
                        result[key] = transValue
                    }
                }
            }
        }
        return result
    }
}

protocol _BuiltInBridgeType: SQLiteTransformable {
    static func _sqlTransform(from object: Any) -> _BuiltInBridgeType?
    func _sqlPlainValue() -> Any?
}

extension NSString: _BuiltInBridgeType {
    static func _sqlTransform(from object: Any) -> _BuiltInBridgeType? {
        if let str = String.sqlTransform(from: object) {
            return NSString(string: str)
        }
        return nil
    }
    
    func _sqlPlainValue() -> Any? {
        return self
    }
}

extension NSNumber: _BuiltInBridgeType {
    static func _sqlTransform(from object: Any) -> _BuiltInBridgeType? {
        switch object {
        case let num as NSNumber:
            return num
        case let str as NSString:
            let lowercase = str.lowercased
            if lowercase == "true" {
                return NSNumber(booleanLiteral: true)
            } else if lowercase == "false" {
                return NSNumber(booleanLiteral: false)
            } else {
                // normal number
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                return formatter.number(from: str as String)
            }
        default:
            return nil
        }
    }
    
    func _sqlPlainValue() -> Any? {
        return self
    }
}

extension NSArray: _BuiltInBridgeType {
    static func _sqlTransform(from object: Any) -> _BuiltInBridgeType? {
        return object as? NSArray
    }
    
    func _sqlPlainValue() -> Any? {
        return (self as? Array<Any>)?.sqlPlainValue()
    }
}

extension NSDictionary: _BuiltInBridgeType {
    static func _sqlTransform(from object: Any) -> _BuiltInBridgeType? {
        return object as? NSDictionary
    }
    
    func _sqlPlainValue() -> Any? {
        return (self as? Dictionary<String, Any>)?.sqlPlainValue()
    }
}

