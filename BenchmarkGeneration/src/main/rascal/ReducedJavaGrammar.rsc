module ReducedJavaGrammar

layout Layout = LAYOUT* !>> [\ \t\n\r];
lexical LAYOUT = [\ \t\n\r];

syntax MethodDec =
   methodDec: MethodDecHead MethodBody 
;

syntax MethodDecHead =
    methodDecHead: ResultType Id "(" {FormalParam ","}* ")"
;

syntax MethodBody =
    Block 
;

syntax Block =
   block: "{" BlockStm+ "}" 
;

syntax BlockStm =
  Stm 
  | LocalVarDecStm 
;

syntax LocalVarDecStm =
  localVarDecStm: LocalVarDec ";" 
;

syntax LocalVarDec =
  localVarDec: Type {VarDec ","}+ 
;

syntax VarDec =
    varDec: VarDecId 
;

syntax VarDecId =
    Id 
;

syntax Stm =
//    \continue: "continue"  Id? ";" 
//   |  forEach: "for"  "(" FormalParam ":" Expr ")" Stm 
//   |  \try: "try" Block CatchClause* "finally"  Block 
//   |  \throw: "throw"  Expr ";" 
//   | Block 
//   |  assertStm: "assert"  Expr ":" Expr ";" 
//   |  \for: "for" "(" {Expr ","}* ";" Expr? ";" {Expr ","}* ")" Stm 
//   |  \try: "try"  Block CatchClause+ 
//   |  labeled: Id ":" Stm 
//   |  \for: "for"  "(" LocalVarDec ";" Expr? ";" {Expr ","}* ")" Stm 
//   |  \switch: "switch"  "(" Expr ")" SwitchBlock 
//   |  \if: "if" "(" Expr ")" Stm "else"  Stm 
//   |  doWhile: "do"  Stm "while"  "(" Expr ")" ";" 
//   |  synchronized: "synchronized"  "(" Expr ")" Block 
//   | @prefer \if: "if"  "(" Expr ")" Stm 
//   |  empty: ";" 
//   |  \while: "while"  "(" Expr ")" Stm 
//   |  assertStm: "assert"  Expr ";" 
//   |  \return: "return"  Expr? ";" 
//   |  \break: "break" Id? ";" 
//   |  exprStm: Expr ";"
      exprStm: Expr ";"
    | @prefer \if: "if"  "(" Expr ")" Stm 
  ;

syntax Expr =
    // castPrim: "(" PrimType ")" Expr 
    // > left 
    // ( left div: Expr "/" !>> [/] Expr 
    // | left remain: Expr "%" Expr 
    // | left mul: Expr "*" Expr 
    // )

    mul: Expr "*" Expr 
;

syntax Expr =
  exprName: ExprName 
  ;

syntax ExprName =
  exprName: Id 
;

syntax ResultType =
   \void: "void"  
//   | Type 
;

// The creation of Id should be replaced by generated ones, preferrably excluding the Keywords and 'null', 'true', and 'false'.
syntax Id =
//    id: [$ A-Z _ a-z] !<< ID \ IDKeywords !>> [$ 0-9 A-Z _ a-z]
    id: [a-z]     
;

syntax FormalParam =
   param: Type Id 
  ;

syntax Type =
  PrimType
;

syntax PrimType =
    boolean: "boolean"  
    | NumType 
;

syntax NumType =
  FloatType 
  | IntType 
;

syntax FloatType =
   float: "float"  
  |  double: "double"  
;

syntax IntType =
   long: "long"  
  |  short: "short"  
  |  char: "char"  
  |  \int: "int"  
  |  byte: "byte"  
;