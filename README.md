# DSON
Simple Delphi JSON Serializer
Tested on Delphi 10.2

**How to Use**

###To Json
```pascal
uses
  uDSON;

type
  TMyRecordType = (rtFoo, rtBar);
  
  TMyRecord = record
    recNo: Integer;
    recType: TMyRecordType;
  end;
  
  TMyObject = class
  private
    FFoo: string;
    FRec: TMyRecord;
    FRecord: TArray<TMyRecord>;
    FVal: Boolean;
  public
    property foo: string read FFoo write FFoo;
    property rec: TMyRecord read FRec write FRec;
    property records: TArray<TMyRecord> read FRecord write FRecord;
    [SerializedName('value_b')]
    property val: Boolean read FVal write FVal;
  end;
  
procedure test();
var
  myObj: TMyObject;
  myRec: TMyRecord;
  s: string;
begin
  myObj := TMyObject.Create();
  myObj.foo := 'Hello';

  myRec.recNo := 20;
  myRec.recType := rtBar;
  myObj.rec := myRec;

  myObj.records := [myRec];
  myObj.val := False;

  s := DSON().toJson<TMyObject>(myObj);
  end;
```
###Result
```json
{
  "foo": "Hello",
  "rec": {
    "recNo": 20,
    "recType": "rtBar"
  },
  "records": [
    {
      "recNo": 20,
      "recType": "rtBar"
    }
  ],
  "value_b": false
}
```

###From Json
```json
{
  "foo": "World",
  "rec": {
    "recNo": 26,
    "recType": "rtBar"
  },
  "records": [
    {
      "recNo": 20,
      "recType": "rtBar"
    },
    {
      "recNo": 21,
      "recType": "rtFoo"
    },
    {
      "recNo": 22,
      "recType": "rtBar"
    },
    {
      "recNo": 25,
      "recType": "rtFoo"
    }
  ],
  "value_b": true
}
```
```pascal
procedure test();
var
  myObj: TMyObject;
begin
  myObj := DSON().fromJson<TMyObject>(json);
  Writeln(myObj.foo);
  Writeln(myObj.rec.recNo);
  Writeln(Length(myObj.records));
  Writeln(myObj.records[2].recNo);
end;
```
###Result
```
World
26
4
22
```


**Supported type:**
Integer, Enumeration, Float, String, Class, Record, Array

*Use only public or published fields/property*
