unit simba.script_compiler_onterminate;

{$mode objfpc}{$H+}
{$i simba.inc}

interface

uses
  classes, sysutils,
  lpcompiler;

procedure InitializeAddOnTerminate(Compiler: TLapeCompiler);
procedure CallTerminateMethods(Compiler: TLapeCompiler);

implementation

uses
  lptypes, lptree, lpvartypes, lpinterpreter, lpmessages;

type
  TLapeTree_InternalMethod_AddOnTerminate = class(TLapeTree_InternalMethod)
  public
    function Compile(var Offset: Integer): TResVar; override;
  end;

function TLapeTree_InternalMethod_AddOnTerminate.Compile(var Offset: Integer): TResVar;
var
  Param: TResVar;
begin
  Result := NullResVar;
  Dest := NullResVar;

  if (FParams.Count <> 1) or isEmpty(FParams[0]) then
    LapeExceptionFmt(lpeWrongNumberParams, [1], DocPos);

  if (not FParams[0].CompileToTempVar(Offset, Param)) then
    LapeException(lpeInvalidEvaluation, DocPos);

  if (Param.VarType is TLapeType_OverloadedMethod) then
    LapeException('Overloaded methods cannot be passed to AddOnTerminate', DocPos);

  if (Param.VarType.BaseType in LapeStringTypes) then
  begin
    with TLapeTree_Operator.Create(op_AssignPlus, Self) do
    try
      CompilerOptions := CompilerOptions + [lcoAutoObjectify];

      Left := TLapeTree_GlobalVar.Create(FCompiler.getGlobalVar('onterminate_strings'), Self);
      Right := TLapeTree_ResVar.Create(Param.IncLock(), Self);
      Compile(Offset);
    finally
     Free();
    end;
  end else
  if (Param.VarType is TLapeType_Method) then
  begin
    if (TLapeType_Method(Param.VarType).Params.Count <> 0) or (TLapeType_Method(Param.VarType).Res <> nil) then
      LapeException('Only a procedure with no parameters can be passed to AddOnTerminate', Self.DocPos);

    with TLapeTree_Operator.Create(op_AssignPlus, Self) do
    try
      CompilerOptions := CompilerOptions + [lcoAutoObjectify];

      Left := TLapeTree_GlobalVar.Create(FCompiler.getGlobalVar('onterminate_methods'), Self);
      Right := TLapeTree_ResVar.Create(Param.IncLock(), Self);
      Compile(Offset);
    finally
     Free();
    end;
  end else
     LapeException('Method expected', DocPos);
end;

procedure AddInvokeProcedure(Compiler: TLapeCompiler);
var
  Decl: TLapeDeclaration;
begin
  with TStringList.Create() do
  try
    Add('procedure _CallTerminateMethods; override;');
    Add('var i: Int32;');
    Add('begin');
    Add('  for i := 0 to High(onterminate_methods) do');
    Add('    if (@onterminate_methods[i] <> nil) then onterminate_methods[i]()');
    Add('');
    Add('  for i := 0 to High(onterminate_strings) do');
    Add('    case UpperCase(onterminate_strings[i]) of');
    for Decl in Compiler.GlobalDeclarations.getByClass(TLapeGlobalVar, bTrue) do
    begin
      if (TLapeGlobalVar(Decl).VarType.ClassType = TLapeType_Method) then
        with TLapeType_Method(TLapeGlobalVar(Decl).VarType) do
        begin
          if (Params.Count > 0) or (Res <> nil) then
            Continue;

          Add('      "' + UpperCase(Name) + '": ' + Name + '();');
        end;
    end;
    Add('    else raise "Only a procedure with no parameters can be passed to AddOnTerminate"');
    Add('  end;');
    Add('end;');

    Compiler.addDelayedCode(Text, '!_CallTerminateMethods');
  finally
    Free();
  end;
end;

procedure InitializeAddOnTerminate(Compiler: TLapeCompiler);
begin
  Compiler.AfterParsing.AddProc(@AddInvokeProcedure);
  Compiler.addDelayedCode('{$H-} procedure _CallTerminateMethods; begin end;');
  Compiler.addGlobalVar('array of procedure of object', nil, 'onterminate_methods');
  Compiler.addGlobalVar('array of string', nil, 'onterminate_strings');

  Compiler.InternalMethodMap['AddOnTerminate'] := TLapeTree_InternalMethod_AddOnTerminate;
end;

procedure CallTerminateMethods(Compiler: TLapeCompiler);
var
  Method: TLapeGlobalVar;
begin
  Method := Compiler['_CallTerminateMethods'];
  if (Method <> nil) then
    RunCode(Compiler.Emitter.Code, Compiler.Emitter.CodeLen, [], PCodePos(Method.Ptr)^);
end;

end.

