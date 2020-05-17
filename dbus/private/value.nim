import tables
import sequtils

type
  FD* = cint

  DbusValue* = ref object
    case kind*: DbusTypeChar:
      of dtArray:
        arrayValueType*: DbusType
        arrayValue*: seq[DbusValue]
      of dtBool:
        boolValue*: bool
      of dtDictEntry:
        dictKey*, dictValue*: DbusValue
      of dtDouble:
        doubleValue*: float64
      of dtSignature:
        signatureValue*: Signature
      of dtUnixFd:
        fdValue*: FD
      of dtInt32:
        int32Value*: int32
      of dtInt16:
        int16Value*: int16
      of dtObjectPath:
        objectPathValue*: ObjectPath
      of dtUint16:
        uint16Value*: uint16
      of dtString:
        stringValue*: string
      of dtStruct:
        structValues*: seq[DbusValue]
      of dtUint64:
        uint64Value*: uint64
      of dtUint32:
        uint32Value*: uint32
      of dtInt64:
        int64Value*: int64
      of dtByte:
        byteValue*: uint8
      of dtVariant:
        variantType*: DbusType
        variantValue*: DbusValue
      else:
        discard

proc `$`*(val: DbusValue): string =
  result.add("<DbusValue " & $val.kind & " ")
  case val.kind
  of dtArray:
    result.add($val.arrayValueType & " " & $val.arrayValue)
  of dtBool:
    result.add($val.boolValue)
  of dtDictEntry:
    result.add($val.dictKey & " " & $val.dictValue)
  of dtDouble:
    result.add($val.doubleValue)
  of dtSignature:
    result.add($cast[string](val.signatureValue))
  of dtUnixFd:
    result.add($val.fdValue)
  of dtInt32:
    result.add($val.int32Value)
  of dtInt16:
    result.add($val.int16Value)
  of dtObjectPath:
    result.add($cast[string](val.objectPathValue))
  of dtUint16:
    result.add($val.uint16Value)
  of dtString:
    result.add($val.stringValue)
  of dtStruct:
    result.add($val.structValues)
  of dtUint64:
    result.add($val.uint64Value)
  of dtUint32:
    discard
    # result.add(system.$(val.uint32Value))
  of dtInt64:
    result.add($val.int64Value)
  of dtByte:
    result.add($val.byteValue)
  of dtVariant:
    result.add($val.variantType & " " & $val.variantValue)
  of dtNull:
    discard
  of dtDict:
    discard
  result.add(">")

type DbusNativePrimitive = bool | float64 | int32 | int16 | uint16 | uint64 | uint32 | int64 | uint8

proc getPrimitive(val: var DbusValue): pointer =
  case val.kind:
    of dtBool:
      return addr val.boolValue
    of dtDouble:
      return addr val.doubleValue
    of dtInt32:
      return addr val.int32Value
    of dtInt16:
      return addr val.int16Value
    of dtUint16:
      return addr val.uint16Value
    of dtUint64:
      return addr val.uint64Value
    of dtUint32:
      return addr val.uint32Value
    of dtInt64:
      return addr val.int64Value
    of dtByte:
      return addr val.byteValue
    else:
      raise newException(ValueError, "value is not primitive")

proc getString(val: DbusValue): var string =
  case val.kind:
    of dtString:
      return val.stringValue
    of dtSignature:
      return val.signatureValue.string
    of dtObjectPath:
      return val.objectPathValue.string
    else:
      raise newException(ValueError, "value is not string")

proc createStringDbusValue(kind: DbusTypeChar, val: string): DbusValue =
  case kind
  of dtString:
    result = DbusValue(kind: kind, stringValue: val)
  of dtSignature:
    result = DbusValue(kind: kind, signatureValue: val.Signature)
  of dtObjectPath:
    result = DbusValue(kind: kind, objectPathValue: val.ObjectPath)
  else:
    raise newException(ValueError, "value is not string")

proc createScalarDbusValue(kind: DbusTypeChar): tuple[value: DbusValue, scalarPtr: pointer] =
  var value = DBusValue(kind: kind)
  (value, getPrimitive(value))

proc createDictEntryDbusValue(key, val: DbusValue): DbusValue =
  DbusValue(kind: dtDictEntry, dictKey: key, dictValue: val)

proc asDbusValue*(val: bool): DbusValue =
  DbusValue(kind: dtBool, boolValue: val)

proc asDbusValue*(val: float64): DbusValue =
  DbusValue(kind: dtDouble, doubleValue: val)

proc asDbusValue*(val: int16): DbusValue =
  DbusValue(kind: dtInt16, int16Value: val)

proc asDbusValue*(val: int32): DbusValue =
  DbusValue(kind: dtInt32, int32Value: val)

proc asDbusValue*(val: int64): DbusValue =
  DbusValue(kind: dtInt64, int64Value: val)

proc asDbusValue*(val: uint16): DbusValue =
  DbusValue(kind: dtUint16, uint16Value: val)

proc asDbusValue*(val: uint32): DbusValue =
  DbusValue(kind: dtUint32, uint32Value: val)

proc asDbusValue*(val: uint64): DbusValue =
  DbusValue(kind: dtUint64, uint64Value: val)

proc asDbusValue*(val: uint8): DbusValue =
  DbusValue(kind: dtByte, byteValue: val)

proc asDbusValue*(val: string): DbusValue =
  DbusValue(kind: dtString, stringValue: val)

proc asDbusValue*(val: ObjectPath): DbusValue =
  DbusValue(kind: dtObjectPath, objectPathValue: val)

proc asDbusValue*(val: Signature): DbusValue =
  DbusValue(kind: dtSignature, signatureValue: val)

proc asDbusValue*(val: DbusValue): DbusValue =
  val

proc getDbusType*(val: DbusValue): DbusType =
  case val.kind
  of dbusScalarTypes:
    return val.kind
  of dbusStringTypes:
    return val.kind
  of dtArray:
    return DbusType(kind: dtArray, itemType: val.arrayValueType)
  of dtNull:
    return dtNull
  of dtDictEntry:
    return DbusType(kind: dtDictEntry,
                    keyType: getDbusType(val.dictKey),
                    valueType: getDbusType(val.dictValue))
  of dtUnixFd:
    return dtUnixFd
  of dtStruct:
    return DbusType(kind: dtStruct,
                    itemTypes: val.structValues.mapIt(getDbusType(it)))
  of dtVariant:
    return DbusType(kind: dtVariant, variantType: val.variantType)
  of dtDict:
    return val.kind

proc getAnyDbusType*(val: DbusValue): DbusType =
  getDbusType(val)

proc asDbusValue*[T](val: seq[T]): DbusValue =
  result = DbusValue(kind: dtArray, arrayValueType: getAnyDbusType(T))
  for x in val:
    result.arrayValue.add x.asDbusValue

proc asDbusValue*[K, V](val: Table[K, V]): DbusValue =
  result = DbusValue(kind: dtArray,
                     arrayValueType: DbusType(kind: dtDictEntry,
                                              keyType: getAnyDbusType(K),
                                              valueType: getAnyDbusType(V)))
  for k, v in val:
    result.arrayValue.add(
      createDictEntryDbusValue(asDbusValue(k), asDbusValue(v)))

proc asDbusValue*(val: Variant[DbusValue]): DbusValue =
  DbusValue(kind: dtVariant, variantType: getDbusType(val.value),
            variantValue: val.value)

proc asDbusValue*[T](val: Variant[T]): DbusValue =
  DbusValue(kind: dtVariant, variantType: getAnyDbusType(T),
            variantValue: asDbusValue(val.value))

proc asNative*(value: DbusValue, native: typedesc[bool]): bool =
  value.boolValue

proc asNative*(value: DbusValue, native: typedesc[float64]): float64 =
  value.doubleValue

proc asNative*(value: DbusValue, native: typedesc[int16]): int16 =
  value.int16Value

proc asNative*(value: DbusValue, native: typedesc[int32]): int32 =
  value.int32Value

proc asNative*(value: DbusValue, native: typedesc[int64]): int64 =
  value.int64Value

proc asNative*(value: DbusValue, native: typedesc[uint16]): uint16 =
  value.uint16Value

proc asNative*(value: DbusValue, native: typedesc[uint32]): uint32 =
  value.uint32Value

proc asNative*(value: DbusValue, native: typedesc[uint64]): uint64 =
  value.uint64Value

proc asNative*(value: DbusValue, native: typedesc[uint8]): uint8 =
  value.byteValue

proc asNative*(value: DbusValue, native: typedesc[string]): string =
  value.stringValue

proc asNative*(value: DbusValue, native: typedesc[ObjectPath]): ObjectPath =
  value.objectPathValue

proc asNative*(value: DbusValue, native: typedesc[Signature]): Signature =
  value.signatureValue

proc add*(dict: DbusValue, key: DbusValue, value: DbusValue) =
  doAssert dict.kind == dtArray
  dict.arrayValue.add(
    createDictEntryDbusValue(asDbusValue(key), asDbusValue(value)))
  