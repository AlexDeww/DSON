unit uDSON;

//Delphi Json Serializer

interface

uses
  {$IFDEF DCC}
  System.SysUtils,System.Rtti,System.TypInfo,System.Json,
  System.Generics.Collections,System.Classes,
  {$ELSE}
  SysUtils,Rtti,TypInfo,Json,
  Generics.Collections,Classes
  {$ENDIF}
  uTypeInfo;
type
  SerializedNameAttribute = class(TCustomAttribute)
  strict private
    FName : string;
  public
    constructor Create(const Name:string);
    property Name:string read FName;
  end;

  DefValueAttribute = class(TCustomAttribute)
  strict private
    FValue : TValue;
  public
    constructor Create(const DefValue:Integer);overload;
    constructor Create(const DefValue:string);overload;
    constructor Create(const DefValue:Single);overload;
    constructor Create(const DefValue:Double);overload;
    constructor Create(const DefValue:Extended);overload;
    constructor Create(const DefValue:Currency);overload;
    constructor Create(const DefValue:Int64);overload;
    constructor Create(const DefValue:Boolean);overload;
  public
    property DefVal : TValue read FValue;
  end;

  EDSONException     = class(Exception);

  TDSONWriterOption  = (IgnoreUnknownTypes,ForceDefault);
  TDSONWriterOptions = set of TDSONWriterOption;

  TDSON =
  record
  public
    class function FromJson<T>(const Json:string):T;overload;static;
    class function FromJson<T>(const JsonStream:TStream):T;overload;static;
    class function ToJson<T>(const Value:T;const Options:TDSONWriterOptions=[IgnoreUnknownTypes]):string;static;
  end;

  IMap<K, V> = interface
  ['{830D3690-DAEF-40D1-A186-B6B105462D89}']
    function GetKeys   : TEnumerable<K>;
    function GetValues : TEnumerable<V>;

    procedure Add(const key:K; const Value:V);
    procedure remove(const key: K);
    function  ExtractPair(const key:K):TPair<K,V>;
    procedure Clear;
    function  GetValue(const key:K):V;
    function  TryGetValue(const key:K;out Value:V):Boolean;
    procedure AddOrSetValue(const key:K;const Value:V);
    function  ContainsKey(const key:K):Boolean;
    function  ContainsValue(const Value:V):Boolean;
    function  ToArray:TArray<TPair<K, V>>;
    function  GetCount:Integer;

    function GetEnumerator:TEnumerator<TPair<K, V>>;
    property Keys:TEnumerable<K> read GetKeys;
    property Values:TEnumerable<V> read GetValues;

    property Items[const key:K]:V read GetValue write AddOrSetValue;
    property Count:Integer read GetCount;
  end;

  TMapClass<K,V>=class(TInterfacedObject,IMap<K,V>)
  private
    FMap : TDictionary<K,V>;
  public
    constructor Create;
    destructor Destroy;override;

    function GetKeys:TEnumerable<K>;
    function GetValues:TEnumerable<V>;

    procedure Add(const key:K;const Value:V);
    procedure Remove(const key:K);
    function  ExtractPair(const key:K):TPair<K,V>;
    procedure Clear;
    function  GetValue(const key: K): V;
    function  TryGetValue(const key: K; out Value:V):Boolean;
    procedure AddOrSetValue(const key:K;const Value:V);
    function  ContainsKey(const key: K):Boolean;
    function  ContainsValue(const Value:V):Boolean;
    function  ToArray:TArray<TPair<K, V>>;
    function  GetCount:Integer;

    function  GetEnumerator:TEnumerator<TPair<K,V>>;
  public
    property Keys               : TEnumerable<K> read GetKeys;
    property Values             : TEnumerable<V> read GetValues;
    property Items[const key:K] : V read GetValue write AddOrSetValue;
    property Count              : Integer read GetCount;
  end;

  TMap<K,V> = record
  private
    FMapIntf : IMap<K,V>;
    {$HINTS OFF}
    FValueType : V;
    FKeyType   : K;
    {$HINTS ON}
    function getMap(): IMap<K, V>;
  public
    function getKeys(): TEnumerable<K>;
    function getValues(): TEnumerable<V>;

    procedure add(const key: K; const Value: V);
    procedure remove(const key: K);
    function extractPair(const key: K): TPair<K, V>;
    procedure clear;
    function getValue(const key: K): V;
    function tryGetValue(const key: K; out Value: V): Boolean;
    procedure addOrSetValue(const key: K; const Value: V);
    function containsKey(const key: K): Boolean;
    function containsValue(const Value: V): Boolean;
    function toArray(): TArray<TPair<K, V>>;
    function getCount(): Integer;

    function getEnumerator: TEnumerator<TPair<K, V>>;
    property keys: TEnumerable<K> read getKeys;
    property values: TEnumerable<V> read getValues;

    property items[const key: K]: V read getValue write addOrSetValue;
    property count: Integer read getCount;
  end;

type
  TDSONBase = class
  protected
    FRttiContext : TRttiContext;
    function GetObjInstance(const Value:TValue):Pointer;
  public
    constructor Create;virtual;
    destructor Destroy;override;
  end;

  TDSONValueReader = class(TDSONBase)
  strict private
    function ReadIntegerValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
    function ReadFloatValue(const RttiType: TRttiType;const JsonValue:TJSONValue):TValue;
    function ReadCharValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
    function ReadStringValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
    function ReadEnumValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
    function ReadClassValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
    function ReadRecordValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
    function ReadDynArrayValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
    function ReadDynArrayValues(const RttiType: TRttiType;const JsonValue:TJSONValue):TArray<TValue>;
    function ReadSetValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;

    procedure SetObjValue(const Instance:TValue;const RttiMember:TRttiMember;const JsonValue:TJSONValue);
    procedure FillObjectValue(const Instance:TValue;const jo:TJSONObject);
    procedure FillMapValue(const Instance:TValue;const jo:TJSONObject);
    function  TryReadValueFromJson(const RttiType:TRttiType;const JsonValue:TJSONValue;out OutValue:TValue):Boolean;
  public
    function ProcessRead(const ATypeInfo:PTypeInfo;const JsonValue:TJSONValue):TValue;
  end;

  TDSONValueWriter   = class(TDSONBase)
  strict private
    FOptions : TDSONWriterOptions;
    function IgnoreDefault:Boolean;
    function WriteIntegerValue(const RttiType:TRttiType; const Value: TValue): TJSONValue;
    function WriteFloatValue(const RttiType: TRttiType; const Value: TValue): TJSONValue;
    function WriteStringValue(const RttiType: TRttiType; const Value: TValue): TJSONValue;
    function WriteEnumValue(const RttiType: TRttiType; const Value: TValue): TJSONValue;
    function WriteClassValue(const RttiType: TRttiType; const Value: TValue): TJSONValue;
    function WriteDynArrayValue(const RttiType: TRttiType; const Value: TValue): TJSONValue;
    function WriteSetValue(const RttiType: TRttiType; const Value: TValue): TJSONValue;

    function GetObjValue(const Instance: TValue; const RttiMember: TRttiMember): TJSONValue;
    function WriteObject(const Instance: TValue): TJSONObject;
    function WriteMap(const Instance: TValue): TJSONObject;
    function TryWriteJsonValue(const Value: TValue; var JsonValue: TJSONValue): Boolean;
  public
    function ProcessWrite(const Value:TValue;const Options:TDSONWriterOptions):TJSONValue;
  end;

resourcestring
  rsNotSupportedType = 'Not supported type %s, type kind: %s';
  rsInvalidJsonArray = 'Json Value is not array.';
  rsInvalidJsonObject = 'Json Value is not object.';
  rsInvalidJsonDateTime = 'Json Value is not DateTime: %s';

implementation
const
  MAP_PREFIX   = 'TMap<';
  NullDateTime = -328716;
type
  TRttiMemberHelper = class helper for TRttiMember
  private
    function HasAttribute<A:TCustomAttribute>(var Attribute:A):Boolean;overload;
  public
    procedure SetValue(const Instance:Pointer;const Value:TValue);
    function  GetValue(const Instance: Pointer):TValue;
    function  GetType:TRttiType;
    function  CanWrite:Boolean;
    function  CanRead:Boolean;
    function  GetName:string;
  end;

{ TDSONValueReader }

procedure TDSONValueReader.FillMapValue(const Instance:TValue;const jo:TJSONObject);
var
  RttiType  : TRttiType;
  addMethod : TRttiMethod;
  valueType : TRttiType;
  keyType   : TRttiType;
  jp        : TJSONPair;

  key       : TValue;
  Value     : TValue;
begin
  RttiType := FRttiContext.GetType(Instance.TypeInfo);

  addMethod := RttiType.GetMethod('addOrSetValue');
  keyType   := RttiType.GetField('FKeyType').FieldType;
  valueType := RttiType.GetField('FValueType').FieldType;
  for jp in jo do
  begin
    if TryReadValueFromJson(keyType,jp.JsonString,key) and TryReadValueFromJson(valueType,jp.JsonValue,Value) then
      addMethod.Invoke(Instance,[key,Value])
  end;
end;

procedure TDSONValueReader.FillObjectValue(const Instance: TValue;
  const jo: TJSONObject);

  procedure processReadRttiMember(const RttiMember: TRttiMember);
  var
    propertyName: string;
    JsonValue: TJSONValue;
  begin
    if not ((RttiMember.Visibility in [mvPublic, mvPublished]) and RttiMember.canWrite()) then
      Exit();

    propertyName := RttiMember.getName();
    JsonValue := jo.GetValue(propertyName);
    SetObjValue(Instance, RttiMember, JsonValue);
  end;

var
  RttiType: TRttiType;
  RttiMember: TRttiMember;
begin
  RttiType := FRttiContext.GetType(Instance.TypeInfo);
  for RttiMember in RttiType.GetDeclaredProperties() do
    processReadRttiMember(RttiMember);
  for RttiMember in RttiType.GetDeclaredFields() do
    processReadRttiMember(RttiMember);
end;

function TDSONValueReader.ReadEnumValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
var
  LEnum  : string;
  LValue : Int64;
begin
  if BaseTypeInfo(RttiType.Handle)=BooleanTypeInfo then
  begin
    Result := TValue.From(JsonValue.AsType<Boolean>);
  end
  else
  begin
    LEnum  := JsonValue.Value;
    LValue := GetEnumValue(RttiType.Handle,LEnum);
    Result := TValue.FromOrdinal(RttiType.Handle,LValue);
  end;
end;

function TDSONValueReader.ReadClassValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
var
  ret: TValue;
begin
  if not (JsonValue is TJSONObject) then raise EDSONException.Create(rsInvalidJsonObject);

  ret := RttiType.GetMethod('Create').Invoke(RttiType.AsInstance.MetaclassType, []);
  try
    FillObjectValue(ret, JsonValue as TJSONObject);
    Result := ret;
  except
    ret.AsObject.Free();
    raise;
  end;
end;

function TDSONValueReader.ReadDynArrayValues(const RttiType:TRttiType;const JsonValue:TJSONValue):TArray<TValue>;
var
  ja: TJSONArray;
  jav: TJSONValue;
  i: Integer;
  values: TArray<TValue>;
  elementType: TRttiType;
begin
  if not (JsonValue is TJSONArray) then raise EDSONException.Create(rsInvalidJsonArray);
  ja := JsonValue as TJSONArray;
  elementType := (RttiType as TRttiDynamicArrayType).ElementType;
  SetLength(values, ja.Count);
  for i := 0 to ja.Count - 1 do
  begin
    values[i] := TValue.Empty;
    jav := ja.Items[i];
    TryReadValueFromJson(elementType, jav, values[i])
  end;
  Result := values;
end;

function TDSONValueReader.ReadDynArrayValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
var
  Bytes : TBytes;
begin
  if BaseTypeInfo(RttiType.Handle)=BytesTypeInfo then
  begin
    Bytes  := DecodeToBytes(JsonValue.Value);
    Result := TValue.From(Bytes);
  end
  else Result := TValue.FromArray(RttiType.Handle,ReadDynArrayValues(RttiType,JsonValue));
end;

function TDSONValueReader.ReadFloatValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
var
  FloatType : TRttiFloatType;
function ReadDateTimeValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
var
  DateTime : Extended;
begin
  DateTime := ISO8601ToDateTime(JsonValue.Value);
  Result   := TValue.From(DateTime);
end;
begin
  if (BaseTypeInfo(RttiType.Handle)=DateTimeTypeInfo) or
     (BaseTypeInfo(RttiType.Handle)=DateTypeInfo)     or
     (BaseTypeInfo(RttiType.Handle)=TimeTypeInfo)     then
  begin
    Exit(ReadDateTimeValue(RttiType,JsonValue));
  end;
  FloatType := RttiType as TRttiFloatType;
  case FloatType.FloatType of
    ftSingle   : Result := JsonValue.GetValue<Single>;
    ftDouble   : Result := JsonValue.GetValue<Double>;
    ftExtended : Result := JsonValue.GetValue<Extended>;
    ftComp     : Result := JsonValue.GetValue<Comp>;
    ftCurr     : Result := JsonValue.GetValue<Currency>;
  end;
end;

function TDSONValueReader.ReadIntegerValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
begin
  Result := JsonValue.GetValue<Int64>;
end;

function TDSONValueReader.ReadRecordValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
var
  LValue     : TValue;
  RttiRecord : TRttiRecordType;
begin
  if not (JsonValue is TJSONObject) then raise EDSONException.Create(rsInvalidJsonObject);
  RttiRecord := RttiType as TRttiRecordType;
  TValue.Make(nil,RttiRecord.Handle,LValue);
  if RttiType.Name.StartsWith(MAP_PREFIX) then FillMapValue(LValue,JsonValue as TJSONObject)
                                          else FillObjectValue(LValue,JsonValue as TJSONObject);
  Result := LValue;
end;

function TDSONValueReader.ReadSetValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
begin
  TValue.Make(nil,RttiType.Handle,Result);
  StringToSet(RttiType.Handle,JsonValue.GetValue<string>,Result.GetReferenceToRawData);
end;

function TDSONValueReader.ReadCharValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
begin
  if JsonValue.Value<>'' then Result := TValue.From<Char>(JsonValue.Value[1])
                         else Result := TValue.From<Char>(#0);
end;

function TDSONValueReader.ReadStringValue(const RttiType:TRttiType;const JsonValue:TJSONValue):TValue;
var
  StringType : TRttiStringType;
begin
  StringType := RttiType as TRttiStringType;
  case StringType.StringKind of
    skShortString   : Result := TValue.From(JsonValue.GetValue<ShortString>);
    skAnsiString    : Result := TValue.From(JsonValue.GetValue<AnsiString>);
    skWideString    : Result := TValue.From(JsonValue.GetValue<WideString>);
    skUnicodeString : Result := JsonValue.GetValue<string>;
  end;
end;

procedure TDSONValueReader.SetObjValue(const Instance:TValue;const RttiMember:TRttiMember;const JsonValue:TJSONValue);
var
  Value      : TValue;
  RttiType   : TRttiType;
  LIinstance : Pointer;
  ValueAttr  : DefValueAttribute;
begin
  LIinstance := GetObjInstance(Instance);
  Value      := RttiMember.GetValue(LIinstance);
  RttiType   := RttiMember.GetType;
  if Value.IsObject then Value.AsObject.Free;
  if TryReadValueFromJson(RttiType,JsonValue,Value) then RttiMember.SetValue(LIinstance,Value) else
  begin
    if RttiMember.hasAttribute<DefValueAttribute>(ValueAttr) then
    begin
      RttiMember.SetValue(LIinstance,ValueAttr.DefVal);
    end;
  end;
end;

function TDSONValueReader.ProcessRead(const ATypeInfo:PTypeInfo;const JsonValue:TJSONValue):TValue;
begin
  Result := TValue.Empty;
  TryReadValueFromJson(FRttiContext.GetType(ATypeInfo),JsonValue,Result);
end;

function TDSONValueReader.TryReadValueFromJson(const RttiType:TRttiType;const JsonValue:TJSONValue;out OutValue:TValue):Boolean;
var
  tk: TTypeKind;
begin
  Result := False;
  if (JsonValue = nil) or JsonValue.Null then Exit;
  tk := RttiType.TypeKind;
  case tk of
    tkInteger     ,
    tkInt64       : OutValue := ReadIntegerValue(RttiType,JsonValue);
    tkEnumeration : OutValue := ReadEnumValue(RttiType,JsonValue);
    tkFloat       : OutValue := ReadFloatValue(RttiType,JsonValue);
    tkString      ,
    tkLString     ,
    tkWString     ,
    tkUString     : OutValue := ReadStringValue(RttiType, JsonValue);
    tkClass       : OutValue := ReadClassValue(RttiType, JsonValue);
    tkDynArray    ,
    tkArray       : OutValue := ReadDynArrayValue(RttiType,JsonValue);
    tkRecord      : OutValue := ReadRecordValue(RttiType,JsonValue);
    tkSet         : OutValue := ReadSetValue(RttiType,JsonValue);
    tkChar        ,
    tkWChar       : OutValue := ReadCharValue(RttiType,JsonValue);
  else
    raise EDSONException.CreateFmt(rsNotSupportedType,[RttiType.Name]);
  end;
  Result := True;
end;

{ TDSON }

class function TDSON.FromJson<T>(const Json:string):T;
var
  ValueReader : TDSONValueReader;
  JsonValue   : TJSONValue;
begin
  JsonValue   := nil;
  ValueReader := TDSONValueReader.Create;
  try
    JsonValue := TJSONObject.ParseJSONValue(Json);
    Result    := ValueReader.ProcessRead(TypeInfo(T),JsonValue).AsType<T>;
  finally
    if Assigned(JsonValue) then JsonValue.Free;
    ValueReader.Free;
  end;
end;

class function TDSON.FromJson<T>(const JsonStream:TStream):T;
var
  ValueReader : TDSONValueReader;
  JsonValue   : TJSONValue;
  JsonData    : TArray<Byte>;
begin
  JsonValue   := nil;
  ValueReader := TDSONValueReader.Create;
  try
    JsonStream.Position := 0;
    SetLength(JsonData,JsonStream.Size);
    JsonStream.ReadBuffer(Pointer(JsonData)^,JsonStream.Size);
    JsonValue := TJSONObject.ParseJSONValue(JsonData,0);
    Result    := ValueReader.ProcessRead(TypeInfo(T),JsonValue).AsType<T>;
  finally
    if Assigned(JsonValue) then JsonValue.Free;
    ValueReader.Free;
  end;
end;

class function TDSON.ToJson<T>(const Value:T;const Options:TDSONWriterOptions):string;
var
  ValueWriter : TDSONValueWriter;
  JsonValue   : TJSONValue;
begin
  Result      := '';
  JsonValue   := nil;
  ValueWriter := TDSONValueWriter.Create;
  try
    JsonValue := ValueWriter.ProcessWrite(TValue.From(Value),Options);
    if JsonValue<>nil then Result := JsonValue.ToJSON;
  finally
    if Assigned(JsonValue) then JsonValue.Free;
    ValueWriter.Free;
  end;
end;

{ TDSONBase }

constructor TDSONBase.Create;
begin
  FRttiContext := TRttiContext.Create;
end;

destructor TDSONBase.Destroy;
begin
  FRttiContext.Free;
  inherited;
end;

function TDSONBase.GetObjInstance(const Value:TValue):Pointer;
begin
  if Value.Kind=tkRecord then Result := Value.GetReferenceToRawData else
  if Value.Kind=tkClass  then Result := Value.AsObject              else
     Result := nil;
end;

{ TDSONValueWriter }

function TDSONValueWriter.GetObjValue(const Instance:TValue;const RttiMember:TRttiMember):TJSONValue;
var
  Value     : TValue;
  LInstance : Pointer;
begin
  Result    := nil;
  LInstance := GetObjInstance(Instance);
  Value     := RttiMember.GetValue(LInstance);
  TryWriteJsonValue(Value,Result);
end;

function TDSONValueWriter.IgnoreDefault: Boolean;
begin
  Result := not(ForceDefault in FOptions);
end;

function TDSONValueWriter.ProcessWrite(const Value:TValue;const Options:TDSONWriterOptions):TJSONValue;
begin
  Result   := nil;
  FOptions := Options;
  TryWriteJsonValue(Value,Result);
end;

function TDSONValueWriter.TryWriteJsonValue(const Value:TValue;var JsonValue:TJSONValue):Boolean;
var
  tk       : TTypeKind;
  RttiType : TRttiType;
begin
  Result := False;
  if Value.IsEmpty then Exit;
  RttiType := FRttiContext.GetType(Value.TypeInfo);
  tk       := RttiType.TypeKind;
  case tk of
    tkInteger     ,
    tkInt64       : JsonValue := WriteIntegerValue(RttiType,Value);
    tkEnumeration : JsonValue := WriteEnumValue(RttiType,Value);
    tkFloat       : JsonValue := WriteFloatValue(RttiType,Value);
    tkString      ,
    tkLString     ,
    tkWString     ,
    tkUString     : JsonValue := WriteStringValue(RttiType,Value);
    tkClass       ,
    tkRecord      : JsonValue := WriteClassValue(RttiType,Value);
    tkDynArray    ,
    tkArray       : JsonValue := WriteDynArrayValue(RttiType,Value);
    tkSet         : JsonValue := WriteSetValue(RttiType,Value);
    tkChar        ,
    tkWChar       : JsonValue := WriteStringValue(RttiType,Value);
  else
    if IgnoreUnknownTypes in FOptions then Exit(False) else
    begin
      raise EDSONException.CreateFmt(rsNotSupportedType,[RttiType.Name,TRttiEnumerationType.GetName(tk)]);
    end;
  end;
  Result := True;
end;

function TDSONValueWriter.WriteClassValue(const RttiType:TRttiType;const Value:TValue):TJSONValue;
begin
  if RttiType.Name.StartsWith(MAP_PREFIX) then Result := WriteMap(Value)
                                          else Result := WriteObject(Value);
end;

function TDSONValueWriter.WriteDynArrayValue(const RttiType:TRttiType;const Value:TValue):TJSONValue;
var
  LArray      : TJSONArray;
  JsonValue   : TJSONValue;
  i           : Integer;
  ArrayLength : Integer;
begin
  if BaseTypeInfo(Value.TypeInfo)=BytesTypeInfo then
  begin
    TryWriteJsonValue(Value.From(EncodeBytes(Value.AsType<TBytes>)),Result);
  end
  else
  begin
    ArrayLength := Value.GetArrayLength;
    if ArrayLength=0 then Exit(nil);
    LArray := TJSONArray.Create;
    try
      for i := 0 to ArrayLength-1 do
      begin
        if TryWriteJsonValue(Value.GetArrayElement(i),JsonValue) then LArray.AddElement(JsonValue);
      end;
    except
      LArray.Free;
      raise;
    end;
    Result := LArray;
  end;
end;

function TDSONValueWriter.WriteEnumValue(const RttiType:TRttiType;const Value:TValue):TJSONValue;
var
  LEnum    : string;
  LValue   : string;
  TypeData : PTypeData;
begin
  Result   := nil;
  TypeData := Value.TypeInfo.TypeData;
  LValue   := GetEnumName(Value.TypeInfo,Value.AsOrdinal);
  if (TypeData.MinValue=0)                                 and
     (TypeData.MaxValue=1)                                 and
     (SameText(LValue,'True') or SameText(LValue,'False')) then
  begin
    if SameText(LValue,'True') or (ForceDefault in FOptions)  then
    begin
      Result := TJSONBool.Create(Value.AsBoolean);
    end;
  end
  else
  begin
    LEnum := GetEnumName(Value.TypeInfo,TypeData.MinValue);
    if (LValue<>LEnum) or (ForceDefault in FOptions) then
    begin
      Result := TJSONString.Create(LValue);
    end;
  end;
end;

function TDSONValueWriter.WriteFloatValue(const RttiType:TRttiType;const Value:TValue):TJSONValue;
var
  LValue  : TDateTime;
  LString : string;
  LType   : PTypeInfo;
  LFloat  : string;
begin
  Result := nil;
  LType  := BaseTypeInfo(RttiType.Handle);
  if (LType=DateTimeTypeInfo) or (LType=DateTypeInfo) or (LType=TimeTypeInfo)then
  begin
    LValue := Value.AsExtended;
    LFloat := FloatToStr(LValue);
    if ((LFloat=ZeroFloatString) or (LFloat=NullDateTimeString)) and IgnoreDefault then Exit;
    LString := DateTimeToISO8601(LValue,LType);
    Result  := TJSONString.Create(LString);
  end
  else
  begin
    LValue := Value.AsExtended;
    LFloat := FloatToStr(LValue);
    if (FloatToStr(LValue)<>ZeroFloatString) or (ForceDefault in FOptions) then
    begin
      Result := TJSONNumber.Create(LValue);
    end;
  end;
end;

function TDSONValueWriter.WriteIntegerValue(const RttiType: TRttiType;const Value:TValue):TJSONValue;
var
  LValue : Int64;
begin
  LValue := Value.AsInt64;
  if (LValue>0) or (ForceDefault in FOptions) then Result := TJSONNumber.Create(LValue)
                                              else Result := nil;
end;

function TDSONValueWriter.WriteMap(const Instance: TValue): TJSONObject;
var
  ret: TJSONObject;
  RttiType: TRttiType;
  toArrayMethod: TRttiMethod;
  pairsArray: TValue;
  arrayType: TRttiDynamicArrayType;
  paitType: TRttiType;
  keyField: TRttiField;
  valueField: TRttiField;
  pair: TValue;
  i, c: Integer;
  key: string;
begin
  RttiType := FRttiContext.GetType(Instance.TypeInfo);

  toArrayMethod := RttiType.GetMethod('toArray');
  pairsArray := toArrayMethod.Invoke(Instance, []);
  arrayType := FRttiContext.GetType(pairsArray.TypeInfo) as TRttiDynamicArrayType;
  paitType := arrayType.ElementType;
  keyField := paitType.GetField('Key');
  valueField := paitType.GetField('Value');

  ret := TJSONObject.Create();
  try
    c := pairsArray.GetArrayLength();
    for i := 0 to c - 1 do
    begin
      pair := pairsArray.GetArrayElement(i);
      key := keyField.getValue(pair.GetReferenceToRawData()).ToString;
      ret.AddPair(TJSONPair.Create(key, GetObjValue(pair, valueField)));
    end;
    Result := ret;
  except
    ret.Free();
    raise;
  end;
end;

function TDSONValueWriter.WriteObject(const Instance: TValue): TJSONObject;
var
  LObject : TJSONObject;

  procedure ProcessRttiMember(const RttiMember: TRttiMember);
  var
    PropertyName : string;
    JsonValue    : TJSONValue;
  begin
    if not ((RttiMember.Visibility in [mvPublic,mvPublished]) and RttiMember.CanRead) then Exit;
    PropertyName := RttiMember.getName;
    JsonValue    := GetObjValue(Instance,RttiMember);
    if JsonValue<>nil then LObject.AddPair(PropertyName,JsonValue);
  end;

var
  RttiType   : TRttiType;
  RttiMember : TRttiMember;
begin
  Result := nil;
  if Instance.IsEmpty then Exit;
  RttiType := FRttiContext.GetType(Instance.TypeInfo);
  LObject  := TJSONObject.Create;
  try
    for RttiMember in RttiType.GetDeclaredProperties do ProcessRttiMember(RttiMember);
    for RttiMember in RttiType.GetDeclaredFields do ProcessRttiMember(RttiMember);
    Result := LObject;
  except
    LObject.Free;
    raise;
  end;
end;

function TDSONValueWriter.WriteSetValue(const RttiType:TRttiType;const Value:TValue):TJSONValue;
begin
  Result := TJSONString.Create(SetToString(RttiType.Handle,Value.GetReferenceToRawData,True));
end;

function TDSONValueWriter.WriteStringValue(const RttiType:TRttiType;const Value:TValue):TJSONValue;
var
  LValue : string;
begin
  LValue := Value.AsString;
  if (LValue>#0) or (ForceDefault in FOptions) then Result := TJSONString.Create(LValue)
                                               else Result := nil;
end;

{ TRttiMemberHelper }

function TRttiMemberHelper.GetName:string;
var
  Attribute : SerializedNameAttribute;
begin
  if HasAttribute<SerializedNameAttribute>(Attribute) then Result := Attribute.Name
                                                      else Result := Self.Name;
end;

function TRttiMemberHelper.GetType:TRttiType;
begin
  if Self is TRttiProperty then Result := (Self as TRttiProperty).PropertyType else
  if Self is TRttiField    then Result := (Self as TRttiField).FieldType       else
     Result := nil;
end;

function TRttiMemberHelper.GetValue(const Instance:Pointer):TValue;
begin
  if Self is TRttiProperty then Result := (Self as TRttiProperty).GetValue(Instance) else
  if Self is TRttiField    then Result := (Self as TRttiField).GetValue(Instance)    else
     Result := TValue.Empty;
end;

function TRttiMemberHelper.HasAttribute<A>(var Attribute:A):Boolean;
var
  LAttribute : TCustomAttribute;
begin
  Attribute := nil;
  Result    := False;
  for LAttribute in Self.GetAttributes do
  begin
    if LAttribute is A then
    begin
      Attribute := A(LAttribute);
      Result    := True;
      Break;
    end;
  end;
end;

function TRttiMemberHelper.CanRead: Boolean;
begin
  if Self is TRttiProperty then Result := (Self as TRttiProperty).IsReadable else
  if Self is TRttiField    then Result := True                               else
     Result := False;
end;

function TRttiMemberHelper.CanWrite:Boolean;
begin
  if Self is TRttiProperty then Result := (Self as TRttiProperty).IsWritable else
  if Self is TRttiField    then Result := True                               else
     Result := False;
end;

procedure TRttiMemberHelper.SetValue(const Instance:Pointer;const Value:TValue);
begin
  if Self is TRttiProperty then (Self as TRttiProperty).SetValue(Instance,Value) else
  if Self is TRttiField    then (Self as TRttiField).SetValue(Instance,Value);
end;

{ SerializedNameAttribute }

constructor SerializedNameAttribute.Create(const Name: string);
begin
  FName := Name;
end;

{ DefValueAttribute }

constructor DefValueAttribute.Create(const DefValue: Integer);
begin
  FValue := DefValue;
end;

constructor DefValueAttribute.Create(const DefValue: Double);
begin
  FValue := DefValue;
end;

constructor DefValueAttribute.Create(const DefValue: Extended);
begin
  FValue := DefValue;
end;

constructor DefValueAttribute.Create(const DefValue: string);
begin
  FValue := DefValue;
end;

constructor DefValueAttribute.Create(const DefValue: Single);
begin
  FValue := DefValue;
end;

constructor DefValueAttribute.Create(const DefValue: Boolean);
begin
  FValue := DefValue;
end;

constructor DefValueAttribute.Create(const DefValue: Currency);
begin
  FValue := DefValue;
end;

constructor DefValueAttribute.Create(const DefValue: Int64);
begin
  FValue := DefValue;
end;

{ TMapClass<K, V> }

procedure TMapClass<K, V>.Add(const key: K; const Value: V);
begin
  FMap.Add(key, Value);
end;

procedure TMapClass<K, V>.AddOrSetValue(const key: K; const Value: V);
begin
  FMap.AddOrSetValue(key, Value);
end;

procedure TMapClass<K, V>.Clear();
begin
  FMap.Clear();
end;

function TMapClass<K, V>.ContainsKey(const key: K): Boolean;
begin
  Result := FMap.ContainsKey(key);
end;

function TMapClass<K, V>.ContainsValue(const Value: V): Boolean;
begin
  Result := FMap.ContainsValue(Value);
end;

constructor TMapClass<K, V>.Create();
begin
  FMap := TDictionary<K, V>.Create();
end;

destructor TMapClass<K, V>.Destroy();
begin
  FMap.Free();
  inherited;
end;

function TMapClass<K, V>.ExtractPair(const key: K): TPair<K, V>;
begin
  Result := FMap.ExtractPair(key);
end;

function TMapClass<K, V>.GetCount(): Integer;
begin
  Result := FMap.Count;
end;

function TMapClass<K, V>.GetEnumerator(): TEnumerator<TPair<K, V>>;
begin
  Result := FMap.GetEnumerator;
end;

function TMapClass<K, V>.GetKeys(): TEnumerable<K>;
begin
  Result := FMap.Keys;
end;

function TMapClass<K, V>.GetValue(const key: K): V;
begin
  Result := FMap[key];
end;

function TMapClass<K, V>.GetValues(): TEnumerable<V>;
begin
  Result := FMap.Values;
end;

procedure TMapClass<K, V>.Remove(const key: K);
begin
  FMap.Remove(key);
end;

function TMapClass<K, V>.ToArray(): TArray<TPair<K, V>>;
begin
  Result := FMap.ToArray;
end;

function TMapClass<K, V>.TryGetValue(const key: K; out Value: V): Boolean;
begin
  Result := FMap.TryGetValue(key, Value);
end;

{ TMap<K, V> }

procedure TMap<K, V>.add(const key: K; const Value: V);
begin
  getMap().Add(key, Value);
end;

procedure TMap<K, V>.addOrSetValue(const key: K; const Value: V);
begin
  getMap().Items[key] := Value;
end;

procedure TMap<K, V>.clear();
begin
  getMap().Clear();
end;

function TMap<K, V>.containsKey(const key: K): Boolean;
begin
  Result := getMap().ContainsKey(key);
end;

function TMap<K, V>.containsValue(const Value: V): Boolean;
begin
  Result := getMap().ContainsValue(Value);
end;

function TMap<K, V>.extractPair(const key: K): TPair<K, V>;
begin
  Result := getMap().ExtractPair(key);
end;

function TMap<K, V>.getCount(): Integer;
begin
  Result := getMap().Count;
end;

function TMap<K, V>.getEnumerator(): TEnumerator<TPair<K, V>>;
begin
  Result := getMap().GetEnumerator();
end;

function TMap<K, V>.getKeys(): TEnumerable<K>;
begin
  Result := getMap().Keys;
end;

function TMap<K, V>.getMap(): IMap<K, V>;
begin
  if FMapIntf = nil then
    FMapIntf := TMapClass<K, V>.Create();
  Result := FMapIntf;
end;

function TMap<K, V>.getValue(const key: K): V;
begin
  Result := getMap().Items[key];
end;

function TMap<K, V>.getValues(): TEnumerable<V>;
begin
  Result := getMap().Values;
end;

procedure TMap<K, V>.remove(const key: K);
begin
  getMap().remove(key);
end;

function TMap<K, V>.toArray(): TArray<TPair<K, V>>;
begin
  Result := getMap().ToArray();
end;

function TMap<K, V>.tryGetValue(const key: K; out Value: V): Boolean;
begin
  Result := getMap().TryGetValue(key, Value);
end;

end.
