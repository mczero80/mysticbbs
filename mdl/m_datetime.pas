Unit m_DateTime;

{$I M_OPS.PAS}

Interface

Procedure WaitMS            (MS: Word);
Function  TimerMinutes      : LongInt;
Function  TimerSeconds      : LongInt;
Function  CurDateDos        : LongInt;
Function  CurDateJulian     : LongInt;
Function  DateDos2Str       (Date: LongInt; Format: Byte) : String;
Function  DateJulian2Str    (Date: LongInt; Format: Byte) : String;
Function  DateStr2Dos       (Str: String) : LongInt;
Function  DateStr2Julian    (Str: String) : LongInt;
Procedure DateG2J           (Year, Month, Day: LongInt; Var Julian: LongInt);
Procedure DateJ2G           (Julian: LongInt; Var Year, Month, Day: SmallInt);
Function  DateValid         (Str: String) : Boolean;
Function  TimeDos2Str       (Date: LongInt; Twelve: Boolean) : String;
Function  DayOfWeek         : Byte;
Function  DaysAgo           (Date: LongInt) : LongInt;
Function  TimeSecToStr      (Secs: LongInt) : String;

Implementation

Uses
{$IFDEF WINDOWS}
  Windows,
{$ENDIF}
{$IFDEF UNIX}
  BaseUnix,
{$ENDIF}
  DOS,
  m_Strings;

Const
  JulianDay0 = 1461;
  JulianDay1 = 146097;
  JulianDay2 = 1721119;

Function TimeSecToStr (Secs: LongInt) : String;
Var
  Mins,
  Hours : LongInt;
Begin
  Mins  := Secs DIV 60;
  Hours := Mins DIV 60;
  Mins  := Mins MOD 60;

  Result := strZero(Hours) + ':' + strZero(Mins);
End;

Procedure WaitMS (MS: Word);
Begin
  {$IFDEF WIN32}
    Sleep(MS);
  {$ENDIF}

  {$IFDEF UNIX}
    fpSelect(0, Nil, Nil, Nil, MS);
  {$ENDIF}
End;

Procedure DateG2J (Year, Month, Day: LongInt; Var Julian: LongInt);
Var
  Century : LongInt;
  XYear   : LongInt;
Begin
  If Month <= 2 Then Begin
    Dec(Year);
    Inc(Month, 12);
  End;
  Dec(Month, 3);
  Century := Year DIV 100;
  XYear   := Year MOD 100;
  Century := (Century * JulianDay1) SHR 2;
  XYear   := (XYear * JulianDay0) SHR 2;
  Julian  := ((((Month * 153) + 2) DIV 5) + Day) + JulianDay2 + XYear + Century;
End;

Procedure DateJ2G (Julian: LongInt; Var Year, Month, Day: SmallInt);
Var
  Temp   : LongInt;
  XYear  : LongInt;
  YYear  : LongInt;
  YMonth : LongInt;
  YDay   : LongInt;
Begin
  Temp   := (((Julian - JulianDay2) SHL 2) - 1);
  XYear  := (Temp MOD JulianDay1) OR 3;
  Julian := Temp DIV JulianDay1;
  YYear  := (XYear DIV JulianDay0);
  Temp   := ((((XYear MOD JulianDay0) + 4) SHR 2) * 5) - 3;
  YMonth := Temp DIV 153;

  If YMonth >= 10 Then Begin
    YYear  := YYear + 1;
    YMonth := YMonth - 12;
  End;

  YMonth := YMonth + 3;
  YDay   := Temp MOD 153;
  YDay   := (YDay + 5) DIV 5;
  Year   := YYear + (Julian * 100);
  Month  := YMonth;
  Day    := YDay;
End;

Function CurDateDos : LongInt;
Var
  DT    : DateTime;
  Temp  : Word;
  Temp2 : LongInt;
Begin
  GetDate  (DT.Year, DT.Month, DT.Day, Temp);
  GetTime  (DT.Hour, DT.Min, DT.Sec, Temp);
  PackTime (DT, Temp2);

  Result := Temp2;
End;

Function CurDateJulian : LongInt;
Var
  Date : DateTime;
  Temp : Word;
Begin
  GetDate (Date.Year, Date.Month, Date.Day, Temp);

  Date.Hour := 0;
  Date.Min  := 0;
  Date.Sec  := 0;

  DateG2J(Date.Year, Date.Month, Date.Day, Result);
End;

Function TimerSeconds : LongInt;
Var
  Hour,
  Minute,
  Second,
  Sec100  : Word;
Begin
  GetTime (Hour, Minute, Second, Sec100);
  Result := (Hour * 3600) + (Minute * 60) + Second;
End;

Function TimerMinutes : LongInt;
Var
  Hour,
  Min,
  Sec,
  Sec100 : Word;
Begin
  GetTime (Hour, Min, Sec, Sec100);
  Result := (Hour * 60) + Min;
End;

Function DateDos2Str (Date: LongInt; Format: Byte) : String;
{1 = MM/DD/YY  2 = DD/MM/YY  3 = YY/DD/MM}
Var
  DT : DateTime;
  M,
  D,
  Y  : String[2];
Begin
  UnPackTime (Date, DT);

  M := strZero(DT.Month);
  D := strZero(DT.Day);
  Y := Copy(strI2S(DT.Year), 3, 2);

  Case Format of
    1 : Result := M + '/' + D + '/' + Y;
    2 : Result := D + '/' + M + '/' + Y;
    3 : Result := Y + '/' + M + '/' + D;
  End;
End;

Function DateJulian2Str (Date: LongInt; Format: Byte) : String;
{1 = MM/DD/YY  2 = DD/MM/YY  3 = YY/DD/MM}
Var
  M     : String[2];
  D     : String[2];
  Y     : String[2];
  Temp1 : Real;
  Temp2 : Real;
  Temp3 : Real;
  Temp4 : Real;
  Temp5 : Real;
Begin
  Temp1 := Date + 68569.0;
  Temp2 := Trunc(4 * Temp1 / 146097.0);
  Temp1 := Temp1 - Trunc((146097.0 * Temp2 + 3) / 4);
  Temp3 := Trunc(4000.0 * (Temp1 + 1) / 1461001.0);
  Temp1 := Temp1 - Trunc(1461.0 * Temp3 / 4.0) + 31.0;
  Temp4 := Trunc(80 * Temp1 / 2447.0);
  Temp5 := Temp1 - Trunc(2447.0 * Temp4 / 80.0);
  Temp1 := Trunc(Temp4 / 11);
  Temp4 := Temp4 + 2 - 12 * Temp1;
  Temp3 := 100 * (Temp2 - 49) + Temp3 + Temp1;

  Y := Copy(strI2S(Trunc(Temp3)), 3, 2);
  M := strZero(Trunc(Temp4));
  D := strZero(Trunc(Temp5));

  Case Format of
    1 : Result := M + '/' + D + '/' + Y;
    2 : Result := D + '/' + M + '/' + Y;
    3 : Result := Y + '/' + M + '/' + D;
  End;
End;

Function DateStr2Julian (Str: String) : LongInt; {MM/DD/YY to Julian Date}
Var
  Month,
  Day,
  Year  : Integer;
  Temp  : Real;
  Temp2 : Real;
Begin
  Month := strS2I(Copy(Str, 1, 2));
  Day   := strS2I(Copy(Str, 4, 2));
  Year  := strS2I(Copy(Str, 7, 2));

  If Year < 20 Then
    Inc(Year, 2000)
  Else
    Inc(Year, 1900);

  Temp2  := (Month - 14) DIV 12;
  Temp   := Day - 32075 + Trunc(1461 * (Year + 4800 + Temp2) / 4);
  Temp   := Temp + Trunc(367 * (Month - 2 - Temp2 * 12) / 12);
  Temp   := Temp - Trunc(3 * Trunc((Year + 4900 + Temp2) / 100) / 4);
//  Temp   := Temp - (3 * (Year + 4900 + Temp2) DIV 100) DIV 4;
  Result := Trunc(Temp);
End;

Function DateStr2Dos (Str: String) : LongInt; {MM/DD/YY to Dos Date}
Var
  DT : DateTime;
Begin
  DT.Year := strS2I(Copy(Str, 7, 2));

  If Dt.Year < 80 Then
    Inc(DT.Year, 2000)
  Else
    Inc(DT.Year, 1900);

  DT.Month := strS2I(Copy(Str, 1, 2));
  DT.Day   := strS2I(Copy(Str, 4, 2));
  DT.Hour  := 0;
  DT.Min   := 0;
  DT.Sec   := 0;

  PackTime (DT, Result);
End;

Function DateValid (Str: String) : Boolean;
Var
  M,
  D : Byte;
Begin
  M := strS2I(Copy(Str, 1, 2));
  D := strS2I(Copy(Str, 4, 2));

  Result := (M > 0) and (M < 13) and (D > 0) and (D < 32);
End;

Function TimeDos2Str (Date: LongInt; Twelve: Boolean) : String;
Var
  DT : DateTime;
Begin
  UnPackTime (Date, DT);

  If Twelve Then Begin
    If DT.Hour > 11 Then Begin
      If DT.Hour = 12 Then Inc(DT.Hour, 12);
      Result := strZero(DT.Hour - 12) + ':' + strZero(DT.Min) + 'p'
    End Else Begin
      If DT.Hour = 0 Then Inc(DT.Hour, 12);
      Result := strZero(DT.Hour) + ':' + strZero(DT.Min) + 'a';
    End;
  End Else
    Result := strZero(DT.Hour) + ':' + strZero(DT.Min);
End;

Function DayOfWeek : Byte;
Var
  Temp : Word;
  DOW  : Word;
Begin
  GetDate (Temp, Temp, Temp, DOW);
  Result := DOW;
End;

Function DaysAgo (Date: LongInt) : LongInt;
Begin
  Result := DateStr2Julian(DateDos2Str(CurDateDos, 1)) - Date;
End;

End.