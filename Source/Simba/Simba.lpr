{
	This file is part of the Mufasa Macro Library (MML)
	Copyright (c) 2009 by Raymond van Venetië and Merlijn Wajer

    MML is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    MML is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with MML.  If not, see <http://www.gnu.org/licenses/>.

	See the file COPYING, included in this distribution,
	for details about the copyright.

    Simba for the Mufasa Macro Library
}
program Simba;

{$mode objfpc}{$H+}

{$IFDEF DARWIN}
  {$modeswitch objectivec2}
{$ENDIF}

{$R Simba.res}

uses
  {$IFDEF UNIX}
  cthreads, cmem,
  {$ENDIF}
  {$IFDEF LINUX}
  simba.linux_initialization,
  {$ENDIF}
  {$IFDEF DARWIN}
  simba.darwin_initialization, cocoaint,
  {$ENDIF}
  {$IFDEF WINDOWS}
  windows,
  {$ENDIF}
  classes, interfaces, forms, sysutils,
  simba.main, simba.aboutform, simba.debugimage, simba.bitmapconv, simba.functionlistform,
  simba.scripttabsform, simba.debugform, simba.filebrowserform, simba.notesform,
  simba.package_form, simba.colorpicker_historyform, simba.settingsform, simba.associate,
  simba.script, simba.script_dump;

type
  TApplicationHelper = class helper for TApplication
    procedure CreateForm(InstanceClass: TComponentClass; out Reference);
    procedure Terminate(Sender: TObject);
  end;

procedure TApplicationHelper.CreateForm(InstanceClass: TComponentClass; out Reference);
begin
  WriteLn('Creating ' + InstanceClass.ClassName);

  inherited CreateForm(InstanceClass, Reference);
end;

procedure TApplicationHelper.Terminate(Sender: TObject);
{$IFDEF WINDOWS}
var
  PID: UInt32;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  GetWindowThreadProcessId(GetConsoleWindow(), PID);
  if (PID = GetCurrentProcessID()) then
  begin
    WriteLn('Press enter to exit');

    ReadLn();
  end;
  {$ENDIF}

  inherited Terminate();

  if (WakeMainThread <> nil) then
    WakeMainThread(Self);

  {$IFDEF DARWIN}
  CocoaWidgetSet.NSApp.Terminate(nil);  // MacOS needs extra help
  {$ENDIF}
end;

begin
  {$IF DECLARED(SetHeapTraceOutput)}
  SetHeapTraceOutput('memory-leaks.trc');
  {$ENDIF}

  FormatSettings.DecimalSeparator := '.';

  Application.Title := 'Simba';
  Application.Scaled := True;
  Application.ShowMainForm := False;
  Application.Initialize();

  if Application.HasOption('dump') then
  begin
    with DumpPlugin(Application.GetOptionValue('dump')) do
      SaveToFile(Application.Params[Application.ParamCount]);

    Halt();
  end;

  if Application.HasOption('associate') then
  begin
    Associate();

    Halt();
  end;

  if not Application.HasOption('open') and Application.HasOption('run') or Application.HasOption('compile') then
  begin
    SimbaScript := TSimbaScript.Create();
    SimbaScript.OnTerminate := @Application.Terminate;

    SimbaScript.ScriptName := Application.GetOptionValue('scriptname');
    SimbaScript.ScriptFile := Application.Params[Application.ParamCount];

    SimbaScript.AppPath     := Application.GetOptionValue('apppath');
    SimbaScript.DataPath    := Application.GetOptionValue('datapath');
    SimbaScript.PluginPath  := Application.GetOptionValue('pluginpath');
    SimbaScript.FontPath    := Application.GetOptionValue('fontpath');
    SimbaScript.IncludePath := Application.GetOptionValue('includepath');
    SimbaScript.ScriptPath  := Application.GetOptionValue('scriptpath');

    SimbaScript.Debugging                := Application.HasOption('debugging');
    SimbaScript.CompileOnly              := Application.HasOption('compile');
    SimbaScript.SimbaCommunicationServer := Application.GetOptionValue('simbacommunication');
    SimbaScript.Target                   := Application.GetOptionValue('target');

    SimbaScript.Start();
  end else
  begin
    Application.CreateForm(TSimbaForm, SimbaForm);
    Application.CreateForm(TSimbaFunctionListForm, SimbaFunctionListForm);
    Application.CreateForm(TSimbaDebugImageForm, SimbaDebugImageForm);
    Application.CreateForm(TSimbaNotesForm, SimbaNotesForm);
    Application.CreateForm(TSimbaScriptTabsForm, SimbaScriptTabsForm);
    Application.CreateForm(TSimbaDebugForm, SimbaDebugForm);
    Application.CreateForm(TSimbaFileBrowserForm, SimbaFileBrowserForm);
    Application.CreateForm(TSimbaAboutForm, SimbaAboutForm);
    Application.CreateForm(TSimbaSettingsForm, SimbaSettingsForm);
    Application.CreateForm(TSimbaBitmapConversionForm, SimbaBitmapConversionForm);
    Application.CreateForm(TSimbaPackageForm, SimbaPackageForm);
    Application.CreateForm(TSimbaColorHistoryForm, SimbaColorHistoryForm);

    Application.QueueASyncCall(@SimbaForm.Setup, 0);
  end;

  Application.Run();
end.
