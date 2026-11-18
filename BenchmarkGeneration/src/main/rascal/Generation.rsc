module Generation

import ParseTree;
import IO;
import ReducedJavaGrammar;
import String;
import util::Math;


alias Grammar = map[Symbol, Production];

// Generate is the main function of this script. In the cmd, you can call the following code:
// =================
// import ParseTree;
// t = generate();
// unparse(t);
// =================
// Inside the generate function, MethodDec can be replaced with any syntax from the ReducedJavaGrammar. 
// The code is barebones, so errors could appear. Let me know when this occurs.
// Depth is hardcoded for now. Adjustments will be added later.

Tree generate(){
    type[MethodDec] t = #MethodDec;
    return gen(t.symbol, t.definitions, 10);
}

// Writes one Java file of generated methods, wrapped in a class, to CustomDataSet/default/.
// In the REPL: main();  or  main(name="Gen2", methods=8);
void main() {
    str name = "Gen2";
    int methods = 5; 
    loc file = |cwd:///CustomDataSet/default/| + "<name>.java";
    str body = ""; 
    for (_ <- [0..methods]){
        t = generate(); 
        body += "   <unparse(t)>\n\n"; 
    }
    writeFile(file, "class <name> {\n\n<body>}\n");
    println("wrote <file>");
}

Tree gen(Symbol currentSymbol, Grammar symbolGrammar, int depth){
    switch(currentSymbol){
        case \sort(_): return createNonTerminal(currentSymbol, symbolGrammar, depth);
        case \lit(str x): return createLiteral(currentSymbol, x);
        case \char-class(list[CharRange] r): return createLiteral(currentSymbol, genChar(r));
        case \layouts(_): return spaceLayout(currentSymbol, symbolGrammar);
        case \iter-star-seps(Symbol s, list[Symbol] l):
            return createSepCycles(currentSymbol, s, l, symbolGrammar, depth, 3);
        case \iter-seps(Symbol s, list[Symbol] l):
            return createSepCycles(currentSymbol, s, l, symbolGrammar, depth, 1);
        case \conditional(Symbol s, _): return gen(s, symbolGrammar, depth);
        default: throw "Unkown symbol: <currentSymbol>";
    }
}

Tree createSepCycles(Symbol listSym, Symbol s, list[Symbol] seps, Grammar g, int depth, int cycles){
    list[Tree] args = [];
    for(i <- [0..cycles]) {
        if(i > 0)
            args += [gen(x, g, depth) | x <- seps];
        args += [gen(s, g, depth-1)];
    }
    return appl(regular(listSym), args);
}

Tree createLiteral(Symbol s, str x){
    list[int] c = chars(x);
    return appl(prod(s, [\char-class([range(r, r)]) | r <- c], {}), [char(r) | r <- c]);
}

str genChar(list[CharRange] rs) {
  // restrict to printable ASCII so negated classes don't give you exotic code points
  list[tuple[int,int]] ok = [<max(b, 32), min(e, 126)> | range(b, e) <- rs, max(b, 32) <= min(e, 126)];
  if (ok == []) return "a";
  <b, e> = getOneFrom(ok);
  return "<for(_ <- [0..3]) {><stringChar(b + arbInt(e - b + 1))><}>";
}

Tree spaceLayout(Symbol s, Grammar g){
    Production lp = options(g[s])[0];

    // Grammar without a layout definition: layouts("$default$") = ε
    if(lp.symbols == []) return appl(lp, []);
    
    Symbol star = lp.symbols[0] is conditional ? lp.symbols[0].symbol : lp.symbols[0];
    Production charProd = [q | q <- options(g[lex("LAYOUT")]), q.symbols[0] is \char-class][0];
    return appl(lp, [appl(regular(star), [appl(charProd, [char(32)])])]);
}

int weight(Production p) = size([x | x <- p.symbols, x is sort || x is lex]);

Tree createNonTerminal(Symbol currentSymbol, Grammar symbolGrammar, int depth) {
    l = options(symbolGrammar[currentSymbol]);
    if(depth <= 0){
        cheapest = min([weight(x) | x <- l]);
        l = [p | p <- l, weight(p) == cheapest];
    }
    Production p = getOneFrom(l);
    return appl(p, [gen(x, symbolGrammar, depth-1) | x <- p.symbols]); 
}

list[Production] options(Production p){
    // if(p is \prod) println(p);
    switch(p) {
        case choice(_, set[Production] prods): return [*options(q) | q <- prods]; 
        case priority(_, list[Production] prods): return [*options(q) | q <- prods];
        case associativity(_, _, set[Production] prods): return [*options(q) | q <- prods];
        case \prod(_, _, _): return [p];
        // default: return [];
        default: throw "Unknown production: <p>";
    }
}
