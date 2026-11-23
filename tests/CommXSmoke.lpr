program CommXSmoke;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, CommX;

procedure Trace(const MessageText: string);
begin
  WriteLn(MessageText);
  Flush(Output);
end;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
end;

procedure Transfer(A, B: TCommX);
var
  Payload, Received: RawByteString;
  Buffer: array[0..255] of Char;
  N, I: Integer;
  Started: QWord;
begin
  // Includes NUL, high bytes, and all possible byte values.
  SetLength(Payload, 256);
  for I := 0 to 255 do Payload[I + 1] := Char(I);
  Check(A.TransBlock(Payload[1], Length(Payload)), 'Queue rejected payload');
  Received := '';
  Started := GetTickCount64;
  repeat
    // This test polls byte queues; Cocoa GUI event dispatch needs a running
    // application and is not needed for the transport test.
    CheckSynchronize(0);
    N := B.ReceiveBlock(@Buffer[0], SizeOf(Buffer));
    if N > 0 then begin
      I := Length(Received);
      SetLength(Received, I + N);
      Move(Buffer[0], Received[I + 1], N);
    end;
    if Length(Received) >= Length(Payload) then Break;
    Sleep(5);
  until GetTickCount64 - Started > 5000;
  Check(Received = Payload, 'Binary transfer mismatch or timeout');
end;

var
  A, B: TCommX;
  I: Integer;
  Raised: Boolean;
begin
  try
  Application.Initialize;
  A := TCommX.Create(nil);
  B := TCommX.Create(nil);
  try
    Check(not A.Active, 'New component is active');
    Check(A.ReceiveChar = -1, 'Closed receive must return -1');
    Check(not A.TransString('test'), 'Closed transmit accepted data');
    A.PortClose;
    A.PortClose;
    A.FlowCtrl := cfcNone;
    A.DeviceName := 'CommX_NONEXISTENT_TEST_DEVICE';
    for I := 1 to 3 do begin
      Raised := False;
      try A.PortOpen; except on E: ECommError do Raised := True; end;
      Check(Raised and not A.Active, 'Failed open did not clean up');
    end;
    if ParamCount = 2 then begin
      A.DeviceName := ParamStr(1);
      B.DeviceName := ParamStr(2);
      B.FlowCtrl := cfcNone;
      Trace('Opening test port A');
      A.PortOpen;
      Trace('Opening test port B');
      B.PortOpen;
      Trace('Transferring A -> B');
      Transfer(A, B);
      Trace('Transferring B -> A');
      Transfer(B, A);
      Trace('Clearing and reopening test port A');
      A.ClearReceiveBuf;
      A.ClearTransBuf;
      A.PortClose;
      A.PortOpen;
      Transfer(A, B);
    end;
    WriteLn('PASS: lifecycle / failed-open cleanup',
      {$IFDEF MSWINDOWS}' (Windows)'{$ELSE}' (POSIX)'{$ENDIF});
    if ParamCount = 2 then WriteLn('PASS: bidirectional binary transfer and reopen');
  finally
    Trace('Closing test ports');
    B.Free;
    A.Free;
  end;
  except
    on E: Exception do begin
      WriteLn(StdErr, 'FAIL: ', E.ClassName, ': ', E.Message);
      Flush(StdErr);
      Halt(1); // Avoid an unattended Cocoa/LCL exception dialog in CI.
    end;
  end;
end.
