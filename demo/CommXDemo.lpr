program CommXDemo;
{$mode objfpc}{$H+}
{$codepage utf8}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, Controls, StdCtrls, ExtCtrls, CommX;
type
  TDemo = class(TForm)
  private
    Port: TCommX;
    DeviceEdit, SendEdit: TEdit;
    Log: TMemo;
    OpenButton: TButton;
    procedure TogglePort(Sender: TObject);
    procedure SendData(Sender: TObject);
    procedure Received(Sender: TObject; ReceiveSize: Integer);
    procedure Failed(Sender: TObject; ErrorState: Integer);
  public
    constructor Create(AOwner: TComponent); override;
  end;
constructor TDemo.Create(AOwner: TComponent);
var Bar: TPanel; B: TButton;
begin
  inherited CreateNew(AOwner);
  Caption := 'CommX: 9600 / 8N1 / no flow control';
  SetBounds(100, 100, 780, 430);
  Port := TCommX.Create(Self);
  Port.FlowCtrl := cfcNone;
  Port.OnReceive := @Received;
  Port.OnError := @Failed;
  Bar := TPanel.Create(Self);
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 80;
  DeviceEdit := TEdit.Create(Self);
  DeviceEdit.Parent := Bar;
  DeviceEdit.SetBounds(8, 8, 430, 26);
  {$IFDEF MSWINDOWS}DeviceEdit.Text := 'COM1';{$ENDIF}
  {$IFDEF LINUX}DeviceEdit.Text := '/dev/ttyUSB0';{$ENDIF}
  {$IFDEF DARWIN}DeviceEdit.Text := '/dev/cu.usbserial-REPLACE';{$ENDIF}
  OpenButton := TButton.Create(Self);
  OpenButton.Parent := Bar;
  OpenButton.SetBounds(450, 8, 120, 28);
  OpenButton.Caption := 'Open';
  OpenButton.OnClick := @TogglePort;
  SendEdit := TEdit.Create(Self);
  SendEdit.Parent := Bar;
  SendEdit.SetBounds(8, 44, 430, 26);
  SendEdit.Text := 'Hello';
  B := TButton.Create(Self);
  B.Parent := Bar;
  B.SetBounds(450, 44, 120, 28);
  B.Caption := 'Send';
  B.OnClick := @SendData;
  Log := TMemo.Create(Self);
  Log.Parent := Self;
  Log.Align := alClient;
  Log.ReadOnly := True;
  Log.ScrollBars := ssAutoBoth;
end;
procedure TDemo.TogglePort(Sender: TObject);
begin
  try
    if Port.Active then begin
      Port.PortClose;
      OpenButton.Caption := 'Open';
      DeviceEdit.Enabled := True;
      Log.Lines.Add('Closed');
    end else begin
      Port.DeviceName := DeviceEdit.Text;
      Port.PortOpen;
      OpenButton.Caption := 'Close';
      DeviceEdit.Enabled := False;
      Log.Lines.Add('Opened ' + DeviceEdit.Text);
    end;
  except
    on E: Exception do Log.Lines.Add('ERROR: ' + E.Message);
  end;
end;
procedure TDemo.SendData(Sender: TObject);
begin
  if Port.TransString(SendEdit.Text) then Log.Lines.Add('TX queued')
  else Log.Lines.Add('TX rejected: closed, faulted, or queue full');
end;
procedure TDemo.Received(Sender: TObject; ReceiveSize: Integer);
var S, Hex: string; I, N: Integer;
begin
  SetLength(S, ReceiveSize);
  N := Port.ReceiveBlock(PChar(S), Length(S));
  Hex := '';
  for I := 1 to N do Hex := Hex + IntToHex(Ord(S[I]), 2) + ' ';
  Log.Lines.Add('RX: ' + Hex);
end;
procedure TDemo.Failed(Sender: TObject; ErrorState: Integer);
begin
  Log.Lines.Add('ERROR: ' + Port.LastErrorText + ' (close and reopen to recover)');
end;
var MainForm: TDemo;
begin
  Application.Initialize;
  Application.CreateForm(TDemo, MainForm);
  Application.Run;
end.
