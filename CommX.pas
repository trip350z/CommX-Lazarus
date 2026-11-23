unit CommX;

{$mode objfpc}{$H+}
{$codepage utf8}

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 trip350z
// New LCL implementation of the CommX 1.05 API; legacy author エックス (KYY06770).
// Transport: bundled SynaSer. Component methods are called on the LCL main thread.
interface

uses
  Classes, SysUtils, SyncObjs, ExtCtrls, synaser;

type
  TCommParityBits = (cpbNone, cpbOdd, cpbEven);
  TCommStopBits = (csb1, csb1p5, csb2);
  TCommFlowCtrls = (cfcRtsCts, cfcDtrDsr, cfcXonXoff,
    cfcHalfHigh, cfcHalfLow, cfcNone);
  ECommError = class(Exception);
  TCommReceiveEvent = procedure(Sender: TObject; ReceiveSize: Integer) of object;
  TCommBreakEvent = procedure(Sender: TObject) of object;
  TCommErrEvent = procedure(Sender: TObject; ErrorState: Integer) of object;
  TCustomCommX = class;

  TCommWorker = class(TThread)
  private
    FOwner: TCustomCommX;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TCustomCommX);
  end;

  TCustomCommX = class(TComponent)
  private
    FSerial: TBlockSerial;
    FWorker: TCommWorker;
    FLock, FIOLock: SyncObjs.TCriticalSection;
    FTimer: TTimer;
    FRx, FTx: RawByteString;
    FActive, FFaulted: Boolean;
    FPendingError: Integer;
    FLastErrorText: string;
    FPortNo, FBitRate, FCharSize: Integer;
    FDeviceName: string;
    FParityBit: TCommParityBits;
    FStopBit: TCommStopBits;
    FFlowCtrl: TCommFlowCtrls;
    FTimeOutTrans, FTimeOutReceive, FHoffDelay: Integer;
    FBufLenTrans, FBufLenReceive: Integer;
    FXonChar, FXoffChar: Char;
    FOnReceive: TCommReceiveEvent;
    FOnBreak: TCommBreakEvent;
    FOnError: TCommErrEvent;
    procedure RequireClosed;
    procedure RequireOpen;
    procedure CheckSerial;
    procedure RawSetSignal(RtsLine, Value: Boolean);
    function OutputCount: Integer;
    procedure PollEvents(Sender: TObject);
    procedure WorkerStep;
    procedure RecordError(Code: Integer; const Description: string);
    function GetHandle: THandle;
    function GetLastErrorText: string;
    function SignalState(Index: Integer): Boolean;
    procedure SetDeviceName(const Value: string);
    procedure SetPortNo(Value: Integer);
    procedure SetBitRate(Value: Integer);
    procedure SetCharSize(Value: Integer);
    procedure SetParityBit(Value: TCommParityBits);
    procedure SetStopBit(Value: TCommStopBits);
    procedure SetFlowCtrl(Value: TCommFlowCtrls);
    procedure SetTimeOutTrans(Value: Integer);
    procedure SetTimeOutReceive(Value: Integer);
    procedure SetHoffDelay(Value: Integer);
    procedure SetBufLenTrans(Value: Integer);
    procedure SetBufLenReceive(Value: Integer);
    procedure SetXonChar(Value: Char);
    procedure SetXoffChar(Value: Char);
    procedure PurgeDirection(ReceiveSide: Boolean);
  protected
    property PortNo: Integer read FPortNo write SetPortNo default 1;
    property DeviceName: string read FDeviceName write SetDeviceName;
    property BitRate: Integer read FBitRate write SetBitRate default 9600;
    property CharSize: Integer read FCharSize write SetCharSize default 8;
    property ParityBit: TCommParityBits read FParityBit write SetParityBit default cpbNone;
    property StopBit: TCommStopBits read FStopBit write SetStopBit default csb1;
    property FlowCtrl: TCommFlowCtrls read FFlowCtrl write SetFlowCtrl default cfcRtsCts;
    property TimeOutTrans: Integer read FTimeOutTrans write SetTimeOutTrans default 3000;
    property TimeOutReceive: Integer read FTimeOutReceive write SetTimeOutReceive default 3000;
    property BufLenTrans: Integer read FBufLenTrans write SetBufLenTrans default 2048;
    property BufLenReceive: Integer read FBufLenReceive write SetBufLenReceive default 2048;
    property XonChar: Char read FXonChar write SetXonChar default #17;
    property XoffChar: Char read FXoffChar write SetXoffChar default #19;
    property HoffDelay: Integer read FHoffDelay write SetHoffDelay default 20;
    property OnReceive: TCommReceiveEvent read FOnReceive write FOnReceive;
    property OnBreak: TCommBreakEvent read FOnBreak write FOnBreak;
    property OnError: TCommErrEvent read FOnError write FOnError;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure PortOpen;
    procedure PortClose;
    function TransChar(const C: Char): Boolean;
    function TransString(const S: string): Boolean;
    function TransBlock(const Data; BufSize: Integer): Boolean; virtual;
    function ReceiveChar: Integer;
    function ReceiveBlock(Buf: PChar; const MaxSize: Integer): Integer; virtual;
    procedure ClearTransBuf;
    procedure ClearReceiveBuf;
    function GetTransLength: Integer;
    function GetReceiveLength: Integer;
    procedure SetRtsSignal(const Signal: Boolean);
    procedure SetDtrSignal(const Signal: Boolean);
    function IsCtsSignal: Boolean;
    function IsDsrSignal: Boolean;
    function IsRingSignal: Boolean;
    function IsRlsdSignal: Boolean;
    procedure SendBreak;
    property Active: Boolean read FActive;
    property Handle: THandle read GetHandle;
    property LastErrorText: string read GetLastErrorText;
  end;

  TCommX = class(TCustomCommX)
  published
    property PortNo;
    property DeviceName;
    property BitRate;
    property CharSize;
    property ParityBit;
    property StopBit;
    property FlowCtrl;
    property HoffDelay;
    property TimeOutTrans;
    property TimeOutReceive;
    property XonChar;
    property XoffChar;
    property BufLenTrans;
    property BufLenReceive;
    property OnReceive;
    property OnBreak;
    property OnError;
  end;

procedure Register;

implementation

uses
  Math
  {$IFDEF MSWINDOWS}, Windows{$ENDIF}
  {$IFDEF UNIX}, BaseUnix, Termio{$ENDIF};

constructor TCommWorker.Create(AOwner: TCustomCommX);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
end;

procedure TCommWorker.Execute;
begin
  while not Terminated do begin
    try
      FOwner.WorkerStep;
    except
      on E: Exception do begin
        FOwner.RecordError(-1, E.Message);
        Exit;
      end;
    end;
    Sleep(5);
  end;
end;

constructor TCustomCommX.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLock := SyncObjs.TCriticalSection.Create;
  FIOLock := SyncObjs.TCriticalSection.Create;
  FSerial := TBlockSerial.Create;
  // Avoid requiring access to /var/lock, including on macOS.
  FSerial.LinuxLock := False;
  FPortNo := 1;
  FBitRate := 9600;
  FCharSize := 8;
  FFlowCtrl := cfcRtsCts;
  FTimeOutTrans := 3000;
  FTimeOutReceive := 3000;
  FBufLenTrans := 2048;
  FBufLenReceive := 2048;
  FHoffDelay := 20;
  FXonChar := #17;
  FXoffChar := #19;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 20;
  FTimer.OnTimer := @PollEvents;
end;

destructor TCustomCommX.Destroy;
begin
  PortClose;
  FSerial.Free;
  FIOLock.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TCustomCommX.RequireClosed;
begin
  if FActive then raise ECommError.Create('Close the port before changing settings');
end;

procedure TCustomCommX.RequireOpen;
begin
  if not FActive then raise ECommError.Create('Port is not open');
end;

procedure TCustomCommX.CheckSerial;
begin
  if FSerial.LastError <> 0 then
    raise ECommError.CreateFmt('Serial error %d: %s',
      [FSerial.LastError, FSerial.LastErrorDesc]);
end;

// Caller holds FIOLock, or no worker exists yet during PortOpen.
procedure TCustomCommX.RawSetSignal(RtsLine, Value: Boolean);
var
  Bits, Mask: Integer;
begin
  {$IFDEF MSWINDOWS}
  if RtsLine then begin
    if Value then Bits := SETRTS else Bits := CLRRTS;
  end else begin
    if Value then Bits := SETDTR else Bits := CLRDTR;
  end;
  if not EscapeCommFunction(FSerial.Handle, Bits) then
    raise ECommError.Create(SysErrorMessage(GetLastError));
  {$ELSE}
  if fpIoctl(FSerial.Handle, TIOCMGET, @Bits) <> 0 then
    raise ECommError.Create(SysErrorMessage(fpGetErrno));
  if RtsLine then Mask := TIOCM_RTS else Mask := TIOCM_DTR;
  if Value then Bits := Bits or Mask else Bits := Bits and not Mask;
  if fpIoctl(FSerial.Handle, TIOCMSET, @Bits) <> 0 then
    raise ECommError.Create(SysErrorMessage(fpGetErrno));
  {$ENDIF}
end;

function TCustomCommX.OutputCount: Integer;
begin
  {$IFDEF MSWINDOWS}
  Result := FSerial.SendingData;
  CheckSerial;
  {$ELSE}
  Result := 0;
  if fpIoctl(FSerial.Handle, TIOCOUTQ, @Result) <> 0 then
    raise ECommError.Create(SysErrorMessage(fpGetErrno));
  {$ENDIF}
end;

procedure TCustomCommX.PortOpen;
const
  Parities: array[TCommParityBits] of Char = ('N', 'O', 'E');
var
  Device: string;
  {$IFDEF UNIX}Flags: Integer;{$ENDIF}
begin
  RequireClosed;
  if csDesigning in ComponentState then Exit;
  Device := FDeviceName;
  if Device = '' then begin
    {$IFDEF MSWINDOWS}Device := 'COM' + IntToStr(FPortNo);{$ENDIF}
    {$IFDEF LINUX}Device := '/dev/ttyS' + IntToStr(FPortNo - 1);{$ENDIF}
    {$IFDEF DARWIN}
    raise ECommError.Create('Set DeviceName to an actual /dev/cu.* device on macOS');
    {$ENDIF}
  end;
  if Device = '' then raise ECommError.Create('DeviceName is required');
  {$IFDEF UNIX}
  if FStopBit = csb1p5 then
    raise ECommError.Create('1.5 stop bits are not supported by this POSIX backend');
  if FFlowCtrl = cfcDtrDsr then
    raise ECommError.Create('DTR/DSR automatic handshake is Windows-only in this port');
  // SynaSer would silently translate unknown POSIX rates to B0 (hang up).
  Flags := 0;
  while (Flags <= High(Rates)) and (Rates[Flags, 0] <> Cardinal(FBitRate)) do
    Inc(Flags);
  if Flags > High(Rates) then raise ECommError.Create('Unsupported POSIX baud rate');
  {$ENDIF}
  try
    FSerial.Connect(Device);
    CheckSerial;
    FSerial.Config(FBitRate, FCharSize, Parities[FParityBit], Ord(FStopBit),
      FFlowCtrl = cfcXonXoff, FFlowCtrl = cfcRtsCts);
    CheckSerial;
    FSerial.DCB.XonChar := FXonChar;
    FSerial.DCB.XoffChar := FXoffChar;
    {$IFDEF MSWINDOWS}
    if FFlowCtrl = cfcDtrDsr then begin
      FSerial.DCB.Flags := FSerial.DCB.Flags and not dcb_DtrControlMask;
      FSerial.DCB.Flags := FSerial.DCB.Flags or dcb_OutxDsrFlow or dcb_DtrControlHandshake;
    end;
    if FFlowCtrl in [cfcHalfHigh, cfcHalfLow] then begin
      FSerial.DCB.Flags := FSerial.DCB.Flags and not dcb_RtsControlMask;
      if FFlowCtrl = cfcHalfLow then
        FSerial.DCB.Flags := FSerial.DCB.Flags or dcb_RtsControlEnable;
    end;
    {$ENDIF}
    FSerial.SetCommState;
    CheckSerial;
    {$IFDEF UNIX}
    FSerial.TermiosStruc.c_cc[VSTART] := Ord(FXonChar);
    FSerial.TermiosStruc.c_cc[VSTOP] := Ord(FXoffChar);
    if TCSetAttr(FSerial.Handle, TCSANOW, FSerial.TermiosStruc) <> 0 then
      raise ECommError.Create(SysErrorMessage(fpGetErrno));
    {$ENDIF}
    if FFlowCtrl in [cfcHalfHigh, cfcHalfLow] then
      RawSetSignal(True, FFlowCtrl = cfcHalfLow);
    FSerial.DeadlockTimeout := FTimeOutTrans;
    {$IFDEF UNIX}
    Flags := fpFcntl(FSerial.Handle, F_GETFL, 0);
    if (Flags < 0) or (fpFcntl(FSerial.Handle, F_SETFL, Flags or O_NONBLOCK) < 0) then
      raise ECommError.Create('Cannot configure nonblocking serial I/O');
    {$ENDIF}
    FRx := '';
    FTx := '';
    FFaulted := False;
    FPendingError := 0;
    FLastErrorText := '';
    FActive := True;
    FWorker := TCommWorker.Create(Self);
    FWorker.Start;
    FTimer.Enabled := True;
  except
    PortClose;
    raise;
  end;
end;

procedure TCustomCommX.PortClose;
begin
  if Assigned(FTimer) then FTimer.Enabled := False;
  FActive := False;
  if Assigned(FWorker) then begin
    FWorker.Terminate;
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
  if Assigned(FSerial) then FSerial.CloseSocket;
  FRx := '';
  FTx := '';
  FPendingError := 0;
end;

procedure TCustomCommX.RecordError(Code: Integer; const Description: string);
begin
  FLock.Acquire;
  try
    FPendingError := Code;
    FLastErrorText := Description;
    FFaulted := True;
  finally
    FLock.Release;
  end;
end;

procedure TCustomCommX.WorkerStep;
var
  Data: RawByteString;
  N, Count, Available: Integer;
  Started: QWord;
begin
  FIOLock.Acquire;
  try
    FLock.Acquire;
    try
      if FFaulted then Exit;
      Data := Copy(FTx, 1, 256);
    finally
      FLock.Release;
    end;
    if Data <> '' then begin
      if FFlowCtrl in [cfcHalfHigh, cfcHalfLow] then begin
        RawSetSignal(True, FFlowCtrl = cfcHalfHigh);
        Sleep(1);
      end;
      Started := GetTickCount64;
      Count := 0;
      try
        while Count < Length(Data) do begin
          if FWorker.Terminated then Exit;
          N := FSerial.SendBuffer(@Data[Count + 1], Length(Data) - Count);
          {$IFDEF UNIX}
          if (N < 0) and (fpGetErrno in [ESysEAGAIN, ESysEINTR]) then N := 0
          else CheckSerial;
          {$ELSE}CheckSerial;{$ENDIF}
          if N > 0 then Inc(Count, N);
          if Count = Length(Data) then Break;
          if GetTickCount64 - Started >= QWord(FTimeOutTrans) then
            raise ECommError.Create('Transmit timeout; unsent bytes remain queued');
          Sleep(1);
        end;
        if FFlowCtrl in [cfcHalfHigh, cfcHalfLow] then begin
          repeat
            N := OutputCount;
            if N = 0 then Break;
            if FWorker.Terminated then Exit;
            if GetTickCount64 - Started >= QWord(FTimeOutTrans) then
              raise ECommError.Create('Half duplex drain timeout');
            Sleep(1);
          until False;
          Sleep(FHoffDelay);
        end;
      finally
        FLock.Acquire;
        try
          Delete(FTx, 1, Count);
        finally
          FLock.Release;
        end;
        if FFlowCtrl in [cfcHalfHigh, cfcHalfLow] then
          RawSetSignal(True, FFlowCtrl = cfcHalfLow);
      end;
    end;
    N := FSerial.WaitingData;
    CheckSerial;
    if N > 0 then begin
      FLock.Acquire;
      try
        Available := FBufLenReceive - Length(FRx);
      finally
        FLock.Release;
      end;
      // Leave excess in the OS queue until the application consumes bytes.
      N := Min(Min(N, Available), 4096);
      if N > 0 then begin
        SetLength(Data, N);
        N := FSerial.RecvBuffer(@Data[1], N);
        {$IFDEF UNIX}
        if (N < 0) and (fpGetErrno in [ESysEAGAIN, ESysEINTR]) then N := 0
        else CheckSerial;
        {$ELSE}CheckSerial;{$ENDIF}
        if N > 0 then begin
          SetLength(Data, N);
          FLock.Acquire;
          try
            FRx := FRx + Data;
          finally
            FLock.Release;
          end;
        end;
      end;
    end;
  finally
    FIOLock.Release;
  end;
end;

procedure TCustomCommX.PollEvents(Sender: TObject);
var
  Code, Count: Integer;
begin
  FLock.Acquire;
  try
    Code := FPendingError;
    FPendingError := 0;
    Count := Length(FRx);
  finally
    FLock.Release;
  end;
  // No component access after a callback: handlers may close/free the component.
  if Code <> 0 then begin
    if Assigned(FOnError) then FOnError(Self, Code);
    Exit;
  end;
  if (Count > 0) and Assigned(FOnReceive) then FOnReceive(Self, Count);
end;

function TCustomCommX.TransBlock(const Data; BufSize: Integer): Boolean;
var
  S: RawByteString;
begin
  if BufSize < 0 then raise ECommError.Create('Negative buffer size');
  if BufSize = 0 then Exit(True);
  if not FActive then Exit(False);
  FLock.Acquire;
  try
    Result := not FFaulted and (BufSize <= FBufLenTrans - Length(FTx));
    if not Result then Exit;
    SetLength(S, BufSize);
    Move(Data, S[1], BufSize);
    FTx := FTx + S;
  finally
    FLock.Release;
  end;
end;

function TCustomCommX.TransChar(const C: Char): Boolean;
begin
  Result := TransBlock(C, 1);
end;

function TCustomCommX.TransString(const S: string): Boolean;
begin
  if S = '' then Exit(True);
  Result := TransBlock(S[1], Length(S));
end;

function TCustomCommX.ReceiveBlock(Buf: PChar; const MaxSize: Integer): Integer;
begin
  if (MaxSize < 0) or ((MaxSize > 0) and (Buf = nil)) then
    raise ECommError.Create('Invalid receive buffer');
  FLock.Acquire;
  try
    Result := Min(MaxSize, Length(FRx));
    if Result > 0 then begin
      Move(FRx[1], Buf^, Result);
      Delete(FRx, 1, Result);
    end;
  finally
    FLock.Release;
  end;
end;

function TCustomCommX.ReceiveChar: Integer;
var
  C: Char;
begin
  if ReceiveBlock(@C, 1) = 1 then Result := Ord(C) else Result := -1;
end;

function TCustomCommX.GetTransLength: Integer;
begin
  FLock.Acquire;
  try Result := Length(FTx); finally FLock.Release; end;
end;

function TCustomCommX.GetReceiveLength: Integer;
begin
  FLock.Acquire;
  try Result := Length(FRx); finally FLock.Release; end;
end;

procedure TCustomCommX.PurgeDirection(ReceiveSide: Boolean);
var
  R: Integer;
begin
  RequireOpen;
  FIOLock.Acquire;
  try
    {$IFDEF MSWINDOWS}
    if ReceiveSide then R := PURGE_RXABORT or PURGE_RXCLEAR
    else R := PURGE_TXABORT or PURGE_TXCLEAR;
    if not PurgeComm(FSerial.Handle, R) then
      raise ECommError.Create(SysErrorMessage(GetLastError));
    {$ELSE}
    if ReceiveSide then R := TCIFLUSH else R := TCOFLUSH;
    if TCFlush(FSerial.Handle, R) <> 0 then
      raise ECommError.Create(SysErrorMessage(fpGetErrno));
    {$ENDIF}
    FLock.Acquire;
    try
      if ReceiveSide then FRx := '' else FTx := '';
    finally
      FLock.Release;
    end;
  finally
    FIOLock.Release;
  end;
end;

procedure TCustomCommX.ClearTransBuf;
begin
  if FActive then PurgeDirection(False);
end;

procedure TCustomCommX.ClearReceiveBuf;
begin
  if FActive then PurgeDirection(True);
end;

procedure TCustomCommX.SetRtsSignal(const Signal: Boolean);
begin
  RequireOpen;
  if FFlowCtrl in [cfcRtsCts, cfcHalfHigh, cfcHalfLow] then
    raise ECommError.Create('RTS is managed by the selected flow control');
  FIOLock.Acquire;
  try RawSetSignal(True, Signal); finally FIOLock.Release; end;
end;

procedure TCustomCommX.SetDtrSignal(const Signal: Boolean);
begin
  RequireOpen;
  if FFlowCtrl = cfcDtrDsr then
    raise ECommError.Create('DTR is managed by the selected flow control');
  FIOLock.Acquire;
  try RawSetSignal(False, Signal); finally FIOLock.Release; end;
end;

function TCustomCommX.SignalState(Index: Integer): Boolean;
begin
  Result := False;
  if not FActive then Exit;
  FIOLock.Acquire;
  try
    case Index of
      0: Result := FSerial.CTS;
      1: Result := FSerial.DSR;
      2: Result := FSerial.Ring;
      3: Result := FSerial.Carrier;
    end;
    CheckSerial;
  finally
    FIOLock.Release;
  end;
end;

function TCustomCommX.IsCtsSignal: Boolean;
begin Result := SignalState(0); end;
function TCustomCommX.IsDsrSignal: Boolean;
begin Result := SignalState(1); end;
function TCustomCommX.IsRingSignal: Boolean;
begin Result := SignalState(2); end;
function TCustomCommX.IsRlsdSignal: Boolean;
begin Result := SignalState(3); end;

procedure TCustomCommX.SendBreak;
begin
  RequireOpen;
  FIOLock.Acquire;
  try
    {$IFDEF MSWINDOWS}
    if not SetCommBreak(FSerial.Handle) then
      raise ECommError.Create(SysErrorMessage(GetLastError));
    try Sleep(300); finally ClearCommBreak(FSerial.Handle); end;
    {$ELSE}
    if fpIoctl(FSerial.Handle, TIOCSBRK, nil) <> 0 then
      raise ECommError.Create(SysErrorMessage(fpGetErrno));
    try Sleep(300); finally fpIoctl(FSerial.Handle, TIOCCBRK, nil); end;
    {$ENDIF}
  finally
    FIOLock.Release;
  end;
end;

function TCustomCommX.GetHandle: THandle;
begin
  if FActive then Result := FSerial.Handle else Result := THandle(-1);
end;

function TCustomCommX.GetLastErrorText: string;
begin
  FLock.Acquire;
  try Result := FLastErrorText; finally FLock.Release; end;
end;

procedure TCustomCommX.SetDeviceName(const Value: string);
begin RequireClosed; FDeviceName := Value; end;
procedure TCustomCommX.SetPortNo(Value: Integer);
begin
  RequireClosed;
  if Value < 1 then raise ECommError.Create('PortNo must be positive');
  FPortNo := Value;
end;
procedure TCustomCommX.SetBitRate(Value: Integer);
begin
  RequireClosed;
  if Value <= 0 then raise ECommError.Create('BitRate must be positive');
  FBitRate := Value;
end;
procedure TCustomCommX.SetCharSize(Value: Integer);
begin
  RequireClosed;
  if not (Value in [5..8]) then raise ECommError.Create('CharSize must be 5..8');
  FCharSize := Value;
end;
procedure TCustomCommX.SetParityBit(Value: TCommParityBits);
begin RequireClosed; FParityBit := Value; end;
procedure TCustomCommX.SetStopBit(Value: TCommStopBits);
begin RequireClosed; FStopBit := Value; end;
procedure TCustomCommX.SetFlowCtrl(Value: TCommFlowCtrls);
begin RequireClosed; FFlowCtrl := Value; end;
procedure TCustomCommX.SetTimeOutTrans(Value: Integer);
begin
  RequireClosed;
  if Value < 1 then raise ECommError.Create('TimeOutTrans must be positive');
  FTimeOutTrans := Value;
end;
procedure TCustomCommX.SetTimeOutReceive(Value: Integer);
begin
  RequireClosed;
  if Value < 0 then raise ECommError.Create('TimeOutReceive must not be negative');
  FTimeOutReceive := Value;
end;
procedure TCustomCommX.SetHoffDelay(Value: Integer);
begin
  RequireClosed;
  if Value < 0 then raise ECommError.Create('HoffDelay must not be negative');
  FHoffDelay := Value;
end;
procedure TCustomCommX.SetBufLenTrans(Value: Integer);
begin
  RequireClosed;
  if Value < 1 then raise ECommError.Create('BufLenTrans must be positive');
  FBufLenTrans := Value;
end;
procedure TCustomCommX.SetBufLenReceive(Value: Integer);
begin
  RequireClosed;
  if Value < 1 then raise ECommError.Create('BufLenReceive must be positive');
  FBufLenReceive := Value;
end;
procedure TCustomCommX.SetXonChar(Value: Char);
begin RequireClosed; FXonChar := Value; end;
procedure TCustomCommX.SetXoffChar(Value: Char);
begin RequireClosed; FXoffChar := Value; end;

procedure Register;
begin
  RegisterComponents('LIB-X', [TCommX]);
end;

end.
