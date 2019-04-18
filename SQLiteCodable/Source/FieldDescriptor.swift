
import Foundation

enum FieldDescriptorKind : UInt16 {
    
    case Struct = 0
    case Class
    case Enum
    case MultiPayloadEnum
    case `Protocol`
    case ClassProtocol
    case ObjCProtocol
    case ObjCClass
}

struct FieldDescriptor: SQLPointerType {
    
    var pointer: UnsafePointer<_FieldDescriptor>
    
    var fieldRecordSize: Int {
        return Int(pointer.pointee.fieldRecordSize)
    }
    
    var numFields: Int {
        return Int(pointer.pointee.numFields)
    }
    
    var fieldRecords: [FieldRecord] {
        return (0..<numFields).map({ (i) -> FieldRecord in
            return FieldRecord(pointer: UnsafePointer<_FieldRecord>(pointer: pointer + 1) + i)
        })
    }
}

struct _FieldDescriptor {
    var mangledTypeNameOffset: Int32
    var superClassOffset: Int32
    var fieldDescriptorKind: FieldDescriptorKind
    var fieldRecordSize: Int16
    var numFields: Int32
}

struct FieldRecord: SQLPointerType {
    
    var pointer: UnsafePointer<_FieldRecord>
    
    var fieldRecordFlags: Int {
        return Int(pointer.pointee.fieldRecordFlags)
    }
    
    var mangledTypeName: UnsafePointer<UInt8>? {
        let address = Int(bitPattern: pointer) + 1 * 4
        let offset = Int(pointer.pointee.mangledTypeNameOffset)
        let cString = UnsafePointer<UInt8>(bitPattern: address + offset)
        return cString
    }
    
    var fieldName: String {
        let address = Int(bitPattern: pointer) + 2 * 4
        let offset = Int(pointer.pointee.fieldNameOffset)
        if let cString = UnsafePointer<UInt8>(bitPattern: address + offset) {
            return String(cString: cString)
        }
        return ""
    }
}

struct _FieldRecord {
    var fieldRecordFlags: Int32
    var mangledTypeNameOffset: Int32
    var fieldNameOffset: Int32
}

