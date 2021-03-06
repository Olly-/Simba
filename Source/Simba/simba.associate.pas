unit simba.associate;

{$mode objfpc}{$H+}

interface

uses
  classes, sysutils;

procedure Associate;

implementation

{$IFDEF WINDOWS}
uses
  registry, shlobj;
{$ENDIF}

procedure Associate;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create();

  try
    Reg.RootKey := HKEY_CLASSES_ROOT;
    Reg.OpenKey('.simba', True);
    Reg.WriteString('', 'simbafile');
    Reg.CloseKey();
    Reg.CreateKey('simbafile');
    Reg.OpenKey('simbafile\DefaultIcon', True);
    Reg.WriteString('', ParamStr(0) + ',0');
    Reg.CloseKey();
    Reg.OpenKey('simbafile\shell\Open\command', True);
    Reg.WriteString('', ParamStr(0) + ' "%1"');
    Reg.CloseKey();
    Reg.OpenKey('simbafile\shell\Run\command', True);
    Reg.WriteString('', ParamStr(0) + ' --open --run "%1"');
    Reg.CloseKey();
    Reg.OpenKey('simbafile\shell\Run (Headless)\command', True);
    Reg.WriteString('', ParamStr(0) + ' --run "%1"');
    Reg.CloseKey();
  finally
    Reg.Free();
  end;

  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nil, nil);
end;
{$ELSE}
begin
end;
{$ENDIF}

end.

