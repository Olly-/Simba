unit simba.script_compiler_debugger;

{$mode objfpc}{$H+}
{$i simba.inc}

interface

uses
  classes, sysutils,
  lptypes, lpcompiler;

type
  PStringArray = ^TStringArray;

  TLapeEnterMethod = procedure(Index: Int32) of object;
  TLapeLeaveMethod = procedure(Index: Int32; Exception: Boolean) of object;

procedure InitializeDebugger(Compiler: TLapeCompiler; Methods: PStringArray; OnEnterMethod: TLapeEnterMethod; OnLeaveMethod: TLapeLeaveMethod);

implementation

uses
  lptree, lpvartypes;

procedure AddDebuggingMethods(Compiler: TLapeCompiler);
var
  EnterMethod, LeaveMethod: TLapeTree_Invoke;
  Statement: TLapeTree_Try;
  IsException: TLapeTree_Operator;
  I: Int32;
  Name: String;
  Method: TLapeTree_Method;
  Methods: ^TStringArray;
begin
  with Compiler do
  begin
    Methods := Globals['_DebuggingMethods'].Ptr;

    for I := 0 to DelayedTree.Statements.Count - 1 do
      if DelayedTree.Statements[i] is TLapeTree_Method then
      begin
        Method := TLapeTree_Method(DelayedTree.Statements[I]);

        Name := UpperCase(Method.Method.Name);
        if (Name = '') or (Name[1] = '!') or (Name = '_ENTERMETHOD') or (Name = '_LEAVEMETHOD') then
          Continue;
        if (Method.Method.VarType is TLapeType_MethodOfType) then
          Name := UpperCase(TLapeType_MethodOfType(Method.Method.VarType).ObjectType.Name) + '.' + Name;

        IsException := TLapeTree_Operator.Create(op_cmp_NotEqual, Method);
        IsException.Left := TLapeTree_InternalMethod_GetExceptionMessage.Create(Method);
        IsException.Right := TLapeTree_String.Create('', IsException);

        EnterMethod := TLapeTree_Invoke.Create('_EnterMethod', Method);
        EnterMethod.addParam(TLapeTree_Integer.Create(Length(Methods^), EnterMethod));

        LeaveMethod := TLapeTree_Invoke.Create('_LeaveMethod', Method);
        LeaveMethod.addParam(TLapeTree_Integer.Create(Length(Methods^), LeaveMethod));
        LeaveMethod.addParam(IsException);

        Method.Statements.addStatement(EnterMethod, True);

        Statement := TLapeTree_Try.Create(Method);
        Statement.Body := Method.Statements;
        Statement.FinallyBody := LeaveMethod;

        Method.Statements := TLapeTree_StatementList.Create(Method);
        Method.Statements.addStatement(Statement);

        Methods^ += [Name];
      end;
  end;
end;

procedure Lape_EnterMethod(const Params: PParamArray); {$IFDEF Lape_CDECL}cdecl;{$ENDIF}
begin
  TLapeEnterMethod(PMethod(Params^[0])^)(PInt32(Params^[1])^);
end;

procedure Lape_LeaveMethod(const Params: PParamArray); {$IFDEF Lape_CDECL}cdecl;{$ENDIF}
begin
  TLapeLeaveMethod(PMethod(Params^[0])^)(PInt32(Params^[1])^, PBoolean(Params^[2])^);
end;

procedure InitializeDebugger(Compiler: TLapeCompiler; Methods: PStringArray; OnEnterMethod: TLapeEnterMethod; OnLeaveMethod: TLapeLeaveMethod);
var
  EnterMethod, LeaveMethod: TLapeGlobalVar;
begin
  EnterMethod := TLapeGlobalVar(Compiler.addManagedVar(TLapeGlobalVar.Create(Compiler.getGlobalType('TMethod'))));
  LeaveMethod := TLapeGlobalVar(Compiler.addManagedVar(TLapeGlobalVar.Create(Compiler.getGlobalType('TMethod'))));

  PMethod(EnterMethod.Ptr)^ := TMethod(OnEnterMethod);
  PMethod(LeaveMethod.Ptr)^ := TMethod(OnLeaveMethod);

  Compiler.AfterParsing.AddProc(@AddDebuggingMethods);
  Compiler.addGlobalVar('array of String', Methods, '_DebuggingMethods');
  Compiler.addGlobalMethod('procedure _EnterMethod(constref Index: Int32);', @Lape_EnterMethod, EnterMethod.Ptr);
  Compiler.addGlobalMethod('procedure _LeaveMethod(constref Index: Int32; Exception: Boolean);', @Lape_LeaveMethod, LeaveMethod.Ptr);
end;

end.

