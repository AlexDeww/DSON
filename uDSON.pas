unit uDSON;

//Delphi JSON Serializer

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.JSON;

type
  SerializedNameAttribute = class(TCustomAttribute)
  strict private
    FName: string;
  public
    constructor Create(const name: string);
    property name: string read FName;
  end;

  EDSONException = class(Exception);

  TDSON = record
  public
    class function fromJson<T>(const json: string): T; static;
    class function toJson<T>(const value: T; const ignoreUnknownTypes: Boolean = False): string; static;
  end;

type
  TDSONBase = class
  private class var
    booleanTi: Pointer;
  protected
    FRttiContext: TRttiContext;
    function getObjInstance(const value: TValue): Pointer;
  public
    constructor Create();
    destructor Destroy(); override;
  end;

  TDSONValueReader = class(TDSONBase)
  strict private
    function readIntegerValue(const rttiType: TRttiType; const jv: TJSONValue): TValue;
    function readInt64Value(const rttiType: TRttiType; const jv: TJSONValue): TValue;
    function readFloatValue(const rttiType: TRttiType; const jv: TJSONValue): TValue;
    function readStringValue(const rttiType: TRttiType; const jv: TJSONValue): TValue;
    function readEnumValue(const rttiType: TRttiType; const jv: TJSONValue): TValue;
    function readClassValue(const rttiType: TRttiType; const jv: TJSONValue): TValue;
    function readRecordValue(const rttiType: TRttiType; const jv: TJSONValue): TValue;
    function readDynArrayValue(const rttiType: TRttiType; const jv: TJSONValue): TValue;
    function readDynArrayValues(const rttiType: TRttiType; const jv: TJSONValue): TArray<TValue>;

    procedure setObjValue(const instance: TValue; const rttiMember: TRttiMember;
      const jv: TJSONValue);
    procedure fillObjectValue(const instance: TValue; const jo: TJSONObject);
    function tryReadValueFromJson(const rttiType: TRttiType; const jv: TJSONValue;
      var outV: TValue): Boolean;
  public
    function processRead(const _typeInfo: PTypeInfo; const jv: TJSONValue): TValue;
  end;

  TDSONValueWriter = class(TDSONBase)
  strict private
    FIgnoreUnknownTypes: Boolean;
    function writeIntegerValue(const rttiType: TRttiType; const value: TValue): TJSONValue;
    function writeInt64Value(const rttiType: TRttiType; const value: TValue): TJSONValue;
    function writeFloatValue(const rttiType: TRttiType; const value: TValue): TJSONValue;
    function writeStringValue(const rttiType: TRttiType; const value: TValue): TJSONValue;
    function writeEnumValue(const rttiType: TRttiType; const value: TValue): TJSONValue;
    function writeClassValue(const rttiType: TRttiType; const value: TValue): TJSONValue;
    function writeDynArrayValue(const rttiType: TRttiType; const value: TValue): TJSONValue;

    function getObjValue(const instance: TValue; const rttiMember: TRttiMember): TJSONValue;
    function writeObject(const instance: TValue): TJSONObject;
    function tryWriteJsonValue(const value: TValue; var jv: TJSONValue): Boolean;
  public
    function processWrite(const value: TValue; const ignoreUnknownTypes: Boolean): TJSONValue;
  end;

function DSON(): TDSON;

resourcestring
  rsNotSupportedType = 'Not supported type %s, type kind: %s';
  rsInvalidJsonArray = 'Json value is not array.';
  rsInvalidJsonObject = 'Json value is not object.';

implementation

function DSON(): TDSON;
begin
end;

type
  TRttiMemberHelper = class helper for TRttiMember
  private
    function hasAttribute<A: TCustomAttribute>(var attr: A): Boolean; overload;
  public
    procedure setValue(const instance: Pointer; const value: TValue);
    function getValue(const instance: Pointer): TValue;
    function getType(): TRttiType;
    function canWrite(): Boolean;
    function canRead(): Boolean;
    function getName(): string;
  end;

{ TDSONValueReader }

procedure TDSONValueReader.fillObjectValue(const instance: TValue;
  const jo: TJSONObject);

  procedure processReadRttiMember(const rttiMember: TRttiMember);
  var
    propertyName: string;
    jv: TJSONValue;
  begin
    if not ((rttiMember.Visibility in [mvPublic, mvPublished]) and rttiMember.canWrite()) then
      Exit();

    propertyName := rttiMember.getName();
    jv := jo.GetValue(propertyName);
    setObjValue(instance, rttiMember, jv);
  end;

var
  rttiType: TRttiType;
  rttiMember: TRttiMember;
begin
  rttiType := FRttiContext.GetType(instance.TypeInfo);
  for rttiMember in rttiType.GetDeclaredProperties() do
    processReadRttiMember(rttiMember);
  for rttiMember in rttiType.GetDeclaredFields() do
    processReadRttiMember(rttiMember);
end;

function TDSONValueReader.readEnumValue(const rttiType: TRttiType;
  const jv: TJSONValue): TValue;
var
  enumItemName: string;
  i: Int64;
begin
  if rttiType.Handle = booleanTi then
    Result := jv.GetValue<Boolean>()
  else
  begin
    enumItemName := jv.Value;
    i := GetEnumValue(rttiType.Handle, enumItemName);
    Result := TValue.FromOrdinal(rttiType.Handle, i);
  end;
end;

function TDSONValueReader.readClassValue(const rttiType: TRttiType;
  const jv: TJSONValue): TValue;
var
  ret: TValue;
begin
  if not (jv is TJSONObject) then
    raise EDSONException.Create(rsInvalidJsonObject);

  ret := rttiType.GetMethod('Create').Invoke(rttiType.AsInstance.MetaclassType, []);
  try
    fillObjectValue(ret, jv as TJSONObject);
    Result := ret;
  except
    ret.AsObject.Free();
    raise;
  end;
end;

function TDSONValueReader.readDynArrayValue(const rttiType: TRttiType;
  const jv: TJSONValue): TValue;
begin
  Result := TValue.FromArray(rttiType.Handle, readDynArrayValues(rttiType, jv));
end;

function TDSONValueReader.readDynArrayValues(const rttiType: TRttiType;
  const jv: TJSONValue): TArray<TValue>;
var
  ja: TJSONArray;
  jav: TJSONValue;
  i: Integer;
  values: TArray<TValue>;
  elementType: TRttiType;
begin
  if not (jv is TJSONArray) then
    raise EDSONException.Create(rsInvalidJsonArray);

  ja := jv as TJSONArray;
  elementType := (rttiType as TRttiDynamicArrayType).ElementType;
  SetLength(values, ja.Count);
  for i := 0 to ja.Count - 1 do
  begin
    values[i] := TValue.Empty;
    jav := ja.Items[i];
    tryReadValueFromJson(elementType, jav, values[i])
  end;
  Result := values;
end;

function TDSONValueReader.readFloatValue(const rttiType: TRttiType;
  const jv: TJSONValue): TValue;
var
  rft: TRttiFloatType;
begin
  rft := rttiType as TRttiFloatType;
  case rft.FloatType of
    ftSingle: Result := jv.GetValue<Single>();
    ftDouble: Result := jv.GetValue<Double>();
    ftExtended: Result := jv.GetValue<Extended>();
    ftComp: Result := jv.GetValue<Comp>();
    ftCurr: Result := jv.GetValue<Currency>();
  end;
end;

function TDSONValueReader.readInt64Value(const rttiType: TRttiType;
  const jv: TJSONValue): TValue;
begin
  Result := jv.GetValue<Int64>();
end;

function TDSONValueReader.readIntegerValue(const rttiType: TRttiType;
  const jv: TJSONValue): TValue;
begin
  Result := jv.GetValue<Integer>();
end;

function TDSONValueReader.readRecordValue(const rttiType: TRttiType;
  const jv: TJSONValue): TValue;
var
  ret: TValue;
  rttiRecord: TRttiRecordType;
begin
  if not (jv is TJSONObject) then
    raise EDSONException.Create(rsInvalidJsonObject);

  rttiRecord := rttiType as TRttiRecordType; 
  TValue.Make(nil, rttiRecord.Handle, ret);
  fillObjectValue(ret, jv as TJSONObject);
  Result := ret;
end;

function TDSONValueReader.readStringValue(const rttiType: TRttiType;
  const jv: TJSONValue): TValue;
var
  rst: TRttiStringType;
begin
  rst := rttiType as TRttiStringType;
  case rst.StringKind of
    skShortString: Result := TValue.From(jv.GetValue<ShortString>());
    skAnsiString: Result := TValue.From(jv.GetValue<AnsiString>());
    skWideString: Result := TValue.From(jv.GetValue<WideString>());
    skUnicodeString: Result := jv.GetValue<string>();
  end;
end;

procedure TDSONValueReader.setObjValue(const instance: TValue;
  const rttiMember: TRttiMember; const jv: TJSONValue);
var
  value: TValue;
  rttiType: TRttiType;
  instanceP: Pointer;
begin
  instanceP := getObjInstance(instance);
  value := rttiMember.getValue(instanceP);
  rttiType := rttiMember.getType();
  if value.IsObject then
    value.AsObject.Free();

  if not tryReadValueFromJson(rttiType, jv, value) then
    Exit();

  rttiMember.setValue(instanceP, value);
end;

function TDSONValueReader.processRead(const _typeInfo: PTypeInfo; const jv: TJSONValue): TValue;
begin
  Result := TValue.Empty;
  tryReadValueFromJson(FRttiContext.GetType(_typeInfo), jv, Result)
end;

function TDSONValueReader.tryReadValueFromJson(const rttiType: TRttiType;
  const jv: TJSONValue; var outV: TValue): Boolean;
var
  tk: TTypeKind;
begin
  Result := False;
  if (jv = nil) or jv.Null then
    Exit();

  tk := rttiType.TypeKind;
  case tk of
    tkInteger: outV := readIntegerValue(rttiType, jv);
    tkInt64: outV := readInt64Value(rttiType, jv);
    tkEnumeration: outV := readEnumValue(rttiType, jv);
    tkFloat: outV := readFloatValue(rttiType, jv);
    tkString, tkLString, tkWString, tkUString: outV := readStringValue(rttiType, jv);
    tkClass: outV := readClassValue(rttiType, jv);
    tkDynArray, tkArray: outV := readDynArrayValue(rttiType, jv);
    tkRecord: outV := readRecordValue(rttiType, jv);
  else
    raise EDSONException.CreateFmt(rsNotSupportedType, [rttiType.Name]);
  end;
  Result := True;
end;

{ TDSON }

class function TDSON.fromJson<T>(const json: string): T;
var
  dvr: TDSONValueReader;
  jv: TJSONValue;
begin
  jv := nil;
  dvr := TDSONValueReader.Create();
  try
    jv := TJSONObject.ParseJSONValue(json);
    Result := dvr.processRead(TypeInfo(T), jv).AsType<T>();
  finally
    jv.Free();
    dvr.Free();
  end;
end;

class function TDSON.toJson<T>(const value: T;
  const ignoreUnknownTypes: Boolean): string;
var
  dvw: TDSONValueWriter;
  jv: TJSONValue;
begin
  Result := '';
  jv := nil;
  dvw := TDSONValueWriter.Create();
  try
    jv := dvw.processWrite(TValue.From(value), ignoreUnknownTypes);
    if jv <> nil then
      Result := jv.ToJSON;
  finally
    jv.Free();
    dvw.Free();
  end;
end;

{ TDSONBase }

constructor TDSONBase.Create();
begin
  FRttiContext := TRttiContext.Create();
end;

destructor TDSONBase.Destroy();
begin
  FRttiContext.Free();
  inherited;
end;

function TDSONBase.getObjInstance(const value: TValue): Pointer;
begin
  if value.Kind = tkRecord then
    Result := value.GetReferenceToRawData()
  else if value.Kind = tkClass then
    Result := value.AsObject
  else
    Result := nil;
end;

{ TDSONValueWriter }

function TDSONValueWriter.getObjValue(const instance: TValue;
  const rttiMember: TRttiMember): TJSONValue;
var
  value: TValue;
  instanceP: Pointer;
begin
  Result := nil;
  instanceP := getObjInstance(instance);
  value := rttiMember.GetValue(instanceP);
  tryWriteJsonValue(value, Result);
end;

function TDSONValueWriter.processWrite(const value: TValue;
  const ignoreUnknownTypes: Boolean): TJSONValue;
begin
  Result := nil;
  FIgnoreUnknownTypes := ignoreUnknownTypes;
  tryWriteJsonValue(value, Result);
end;

function TDSONValueWriter.tryWriteJsonValue(const value: TValue;
  var jv: TJSONValue): Boolean;
var
  tk: TTypeKind;
  rttiType: TRttiType;
begin
  Result := False;
  if value.IsEmpty then
    Exit();

  rttiType := FRttiContext.GetType(value.TypeInfo);
  tk := rttiType.TypeKind;
  case tk of
    tkInteger: jv := writeIntegerValue(rttiType, value);
    tkInt64: jv := writeInt64Value(rttiType, value);
    tkEnumeration: jv := writeEnumValue(rttiType, value);
    tkFloat: jv := writeFloatValue(rttiType, value);
    tkString, tkLString, tkWString, tkUString: jv := writeStringValue(rttiType, value);
    tkClass, tkRecord: jv := writeClassValue(rttiType, value);
    tkDynArray, tkArray: jv := writeDynArrayValue(rttiType, value);
  else
    if FIgnoreUnknownTypes then
      Exit(False)
    else
      raise EDSONException.CreateFmt(rsNotSupportedType, [rttiType.Name, TRttiEnumerationType.GetName(tk)]);
  end;
  Result := True;
end;

function TDSONValueWriter.writeClassValue(const rttiType: TRttiType;
  const value: TValue): TJSONValue;
begin
  Result := writeObject(value);
end;

function TDSONValueWriter.writeDynArrayValue(const rttiType: TRttiType;
  const value: TValue): TJSONValue;
var
  ret: TJSONArray;
  jv: TJSONValue;
  i: Integer;
begin
  ret := TJSONArray.Create();
  try
    for i := 0 to value.GetArrayLength() - 1 do
    begin
      if tryWriteJsonValue(value.GetArrayElement(i), jv) then
        ret.AddElement(jv);
    end;
  except
    ret.Free();
    raise;
  end;
  Result := ret;
end;

function TDSONValueWriter.writeEnumValue(const rttiType: TRttiType;
  const value: TValue): TJSONValue;
var
  enumItemName: string;
begin
  if rttiType.Handle = booleanTi then
    Result := TJSONBool.Create(value.AsBoolean)
  else
  begin
    enumItemName := GetEnumName(value.TypeInfo, value.AsOrdinal);
    Result := TJSONString.Create(enumItemName);
  end;
end;

function TDSONValueWriter.writeFloatValue(const rttiType: TRttiType;
  const value: TValue): TJSONValue;
begin
  Result := TJSONNumber.Create(value.AsExtended);
end;

function TDSONValueWriter.writeInt64Value(const rttiType: TRttiType;
  const value: TValue): TJSONValue;
begin
  Result := TJSONNumber.Create(value.AsInt64);
end;

function TDSONValueWriter.writeIntegerValue(const rttiType: TRttiType;
  const value: TValue): TJSONValue;
begin
  Result := TJSONNumber.Create(value.AsInteger);
end;

function TDSONValueWriter.writeObject(const instance: TValue): TJSONObject;
var
  ret: TJSONObject;

  procedure processRttiMember(const rttiMember: TRttiMember);
  var
    propertyName: string;
    jv: TJSONValue;
  begin
    if not ((rttiMember.Visibility in [mvPublic, mvPublished]) and rttiMember.canRead()) then
      Exit();

    propertyName := rttiMember.getName();
    jv := getObjValue(instance, rttiMember);
    if jv <> nil then
      ret.AddPair(propertyName, jv);
  end;
  
var
  rttiType: TRttiType;
  rttiMember: TRttiMember;
begin
  Result := nil;
  if instance.IsEmpty then
    Exit();

  rttiType := FRttiContext.GetType(instance.TypeInfo);
  ret := TJSONObject.Create();
  try
    for rttiMember in rttiType.GetDeclaredProperties() do
      processRttiMember(rttiMember);
    for rttiMember in rttiType.GetDeclaredFields() do
      processRttiMember(rttiMember);
      
    Result := ret;
  except
    ret.Free();
    raise;
  end;
end;

function TDSONValueWriter.writeStringValue(const rttiType: TRttiType;
  const value: TValue): TJSONValue;
begin
  Result := TJSONString.Create(value.AsString);
end;

{ TRttiMemberHelper }

function TRttiMemberHelper.getName(): string;
var
  attr: SerializedNameAttribute;
begin
  if hasAttribute<SerializedNameAttribute>(attr) then
    Result := attr.name
  else
    Result := Self.Name;
end;

function TRttiMemberHelper.getType(): TRttiType;
begin
  if Self is TRttiProperty then
    Result := (Self as TRttiProperty).PropertyType
  else if Self is TRttiField then
    Result := (Self as TRttiField).FieldType
  else
    Result := nil;
end;

function TRttiMemberHelper.getValue(const instance: Pointer): TValue;
begin
  if Self is TRttiProperty then
    Result := (Self as TRttiProperty).GetValue(instance)
  else if Self is TRttiField then
    Result := (Self as TRttiField).GetValue(instance)
  else
    Result := TValue.Empty;
end;

function TRttiMemberHelper.hasAttribute<A>(var attr: A): Boolean;
var
  attribute: TCustomAttribute;
begin
  attr := nil;
  Result := False;
  for attribute in self.GetAttributes() do
  begin
    if attribute is A then
    begin
      attr := A(attribute);
      Result := True;
      Break;
    end;
  end;
end;

function TRttiMemberHelper.canRead(): Boolean;
begin
  if Self is TRttiProperty then
    Result := (Self as TRttiProperty).IsReadable
  else if Self is TRttiField then
    Result := True
  else
    Result := False;
end;

function TRttiMemberHelper.canWrite(): Boolean;
begin
  if Self is TRttiProperty then
    Result := (Self as TRttiProperty).IsWritable
  else if Self is TRttiField then
    Result := True
  else
    Result := False;
end;

procedure TRttiMemberHelper.setValue(const instance: Pointer;
  const value: TValue);
begin
  if Self is TRttiProperty then
    (Self as TRttiProperty).SetValue(instance, value)
  else if Self is TRttiField then
    (Self as TRttiField).SetValue(instance, value)
end;

{ SerializedNameAttribute }

constructor SerializedNameAttribute.Create(const name: string);
begin
  FName := name;
end;

initialization
  TDSONBase.booleanTi := TypeInfo(Boolean);

end.
