unit uTypeInfo;
{$I Defines}
{$IFDEF FPC}
{$Mode delphi}
{$ENDIF}
interface
uses
  {$IFDEF DCC}
  System.SysUtils,System.TypInfo,System.Generics.Collections;
  {$ELSE}
  SysUtils,TypInfo,Generics.Collections;
  {$ENDIF}
const
  NullDateTime = -328716;
var
  TypeInfoDictionary : TDictionary<Pointer,Pointer>;
  BooleanTypeInfo    ,
  DateTimeTypeInfo   ,
  DateTypeInfo       ,
  TimeTypeInfo       ,
  BytesTypeInfo      : PTypeInfo;
  NullDateTimeString ,
  ZeroFloatString    : string;

procedure RegisterCustomTypeInfo(CustomType,BaseType:PTypeInfo);
function  BaseTypeInfo(CustomType:PTypeInfo):PTypeInfo;
procedure UnregisterCustomTypeInfo(CustomType:PTypeInfo);
function  ISO8601ToDateTime(Value:string):TDateTime;
function  DateTimeToISO8601(Value:TDateTime;const Info:PTypeInfo):string;
function  EncodeBytes(const Bytes:TBytes):string;
function  DecodeToBytes(const Value:string):TBytes;
function  HashString(const Value:string):UInt32;

implementation

uses
  {$IFDEF DCC}
  System.NetEncoding,System.DateUtils,
  {$ELSE}
  IdGlobal,IdCoder,IdCoderMIME,DateUtils,
  {$ENDIF}
  IdHashCRC;

procedure RegisterCustomTypeInfo(CustomType,BaseType:PTypeInfo);
begin
  TypeInfoDictionary.AddOrSetValue(CustomType,BaseType);
end;

function BaseTypeInfo(CustomType:PTypeInfo):PTypeInfo;
begin
  if not TypeInfoDictionary.TryGetValue(CustomType,Pointer(Result)) then Result := CustomType;
end;

procedure UnregisterCustomTypeInfo(CustomType:PTypeInfo);
begin
  TypeInfoDictionary.Remove(CustomType);
end;

function ISO8601ToDateTime(Value:string):TDateTime;
begin
  Value := Trim(Value);
  if Value='' then Exit(NullDateTime);
  if Pos('-',Value)=0 then Value := '2000-01-01T'+Value;
  Result := ISO8601ToDate(Value);
end;

function DateTimeToISO8601(Value:TDateTime;const Info:PTypeInfo):string;
begin
  if Info=TimeTypeInfo then Result := FormatDateTime('hh:nn:ss.zzz',Value) else
  begin
    Result := DateToISO8601(Value);
    if Info=DateTypeInfo then Result := Copy(Result,1,Pos('T',Result)-1);
  end;
end;

function EncodeBytes(const Bytes:TBytes):string;
begin
  {$IFDEF DCC}
  Result := TNetEncoding.Base64.EncodeBytesToString(Bytes);
  {$ELSE}
  Result := TIdEncoderMIME.EncodeBytes(Bytes);
  {$ENDIF}
end;

function DecodeToBytes(const Value:string):TBytes;
begin
  {$IFDEF DCC}
  try
    Result := TNetEncoding.Base64.DecodeStringToBytes(Value);
  except
    Result := nil;
  end;
  {$ELSE}
  try
    Result := TIdDecoderMIME.DecodeBytes(Value);
  except
    Result := nil;
  end;
  {$ENDIF}
end;

function HashString(const Value:string):UInt32;
var
  MessageDigest : TIdHashCRC32;
begin
  MessageDigest := TIdHashCRC32.Create;
  try
    Result := MessageDigest.HashValue(Value);
  finally
    MessageDigest.Free;
  end;
end;

initialization
  TypeInfoDictionary := TDictionary<Pointer,Pointer>.Create;
  BooleanTypeInfo    := TypeInfo(Boolean);
  DateTimeTypeInfo   := TypeInfo(TDateTime);
  DateTypeInfo       := TypeInfo(TDate);
  TimeTypeInfo       := TypeInfo(TTime);
  BytesTypeInfo      := TypeInfo(TBytes);
  NullDateTimeString := FloatToStr(NullDateTime);
  ZeroFloatString    := FloatToStr(0);
finalization
  FreeAndNil(TypeInfoDictionary);
end.
