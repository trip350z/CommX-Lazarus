{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit CommXLCL;

{$warn 5023 off : no warning about unused units}
interface

uses
  CommX, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('CommX', @CommX.Register);
end;

initialization
  RegisterPackage('CommXLCL', @Register);
end.
