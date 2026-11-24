module Generation

import ParseTree;
import IO;
import ReducedJavaGrammar;
import String;
import List;
import util::Math;


alias Grammar = map[Symbol, Production];

// Generate is the main function of this script. In the cmd, you can call the following code:
// =================
// import ParseTree;
// cfg = genConfig(seed=-1, maxDepth=10);
// <seed, t> = generate(config=cfg);
// unparse(t);
// =================
// Choices can be steered with rules and a forced order:
// =================
// cfg = genConfig(
//     seed = 42,
//     rules = (
//         "if":    rule(maxUses = 2),     // at most 2 if-statements in the whole tree
//         "mul":   rule(weight = 4),      // 4x as likely as an alternative with weight 1
//         "float": rule(veto = true)      // never chosen (same as weight = 0)
//     ),
//     forcedOrder = ["exprStm", "if"]     // first exprStm appears before the first if
// );
// <seed, t> = generate(config=cfg);
// usage();                                // how often each production was chosen
// =================
// Rule keys are production labels ("if", "mul", "int", ...). Use "Sort.label" (e.g. "Expr.exprName")
// to target one sort when several sorts share a label; the qualified key takes precedence.
// Unlabeled productions are addressed as "Sort.Child", e.g. "BlockStm.Stm" or "BlockStm.LocalVarDecStm".
// Inside the generate function, MethodDec can be replaced with any syntax from the ReducedJavaGrammar.

data Rule = rule(
    int weight = 1,
    int maxUses = -1,       // -1 = unlimited
    bool veto = false
);

data getConfig = genConfig(
    int seed = -1,
    int maxDepth = 10,
    map[str, Rule] rules = (),
    list[str] forcedOrder = [],
    int forcedBoost = 10,   // weight multiplier for the next key in forcedOrder
    bool debug = false      // print the options and choice at every nonterminal
);

// Generation state, reset by every call to generate.
private getConfig cfg = genConfig();
private map[str, int] useCount = ();
private int orderIdx = 0;
private map[Symbol, set[str]] reach = ();   // production keys reachable from each nonterminal

tuple[int, Tree] generate(getConfig config = genConfig()){
    type[MethodDec] t = #MethodDec;

    int seed = config.seed >= 0 ? config.seed : arbInt(1000000);
    arbSeed(seed);

    cfg = config;
    useCount = ();
    orderIdx = 0;
    reach = config.forcedOrder == [] ? () : reachableKeys(t.definitions);

    Tree tree = gen(t.symbol, t.definitions, config.maxDepth);

    if(orderIdx < size(config.forcedOrder))
        println("Warning: forcedOrder not completed, never reached: <config.forcedOrder[orderIdx..]>");

    return <seed, tree>;
}

// Shapes of all methods generated in this main() run. Identifiers are replaced by "ID", and layout is
// always single spaces, so two methods with the same shape are Type-1/2 clones of each other.
private set[str] seen = {};
str shape(Tree t) {
    return unparse(visit (t) {
        case Tree x: appl(prod(label(_, sort("Id")), _, _), _) => appl(x.prod, [char(73), char(68)]) // "ID"
    });
}

// Writes one Java file of generated methods, wrapped in a class, to CustomDataSet/default/.
// Every method gets its own seed: with a fixed seed, method k uses seed + k, so the methods differ
// but the whole file is reproducible. Returns the seeds used.

list[int] writeGenFile(str name, int methods, getConfig config = genConfig()) {
    loc file = |cwd:///CustomDataSet/default/| + "<name>.java";
    str body = "";
    list[int] seeds = [];
    for (k <- [0..methods]) {
        getConfig c = config;
        if (config.seed >= 0) c.seed = config.seed + k;
        <seed, t> = generate(config = c);
        while (shape(t) in seen) {                     // clone of an earlier method: try again
            if (c.seed >= 0) c.seed += 1000;           // fixed seed: move to a fresh one
            <seed, t> = generate(config = c);
        }
        seen += {shape(t)};
        seeds += [seed];
        body += "   <unparse(t)>\n\n";
    }
    writeFile(file, "class <name> {\n\n<body>}\n");
    println("wrote <file> (seeds <seeds>)");
    return seeds;
}

// Writes Gen1.java .. Gen<files>.java. In the REPL:
// 1. Method size vs. detector thresholds
// small = genConfig(seed = 1, maxDepth = 2);   // tiny methods, ~10 to 15 tokens
// large = genConfig(seed = 1, maxDepth = 8);   // long mul-chains, nested ifs

void main(int files = 20, int methods = 3, getConfig cfg = genConfig(seed = 42, maxDepth = 10)) {
    seen = {};
    for (i <- [1..files + 1]) {
        getConfig c = cfg;
        if (cfg.seed >= 0) c.seed = cfg.seed + (i - 1) * methods;
        writeGenFile("Gen<i>", methods, config = c);
    }
}

// How often each production key was chosen during the last generate call.
map[str, int] usage() = useCount;

Tree gen(Symbol currentSymbol, Grammar symbolGrammar, int depth){
    switch(currentSymbol){
        case \sort(_): return createNonTerminal(currentSymbol, symbolGrammar, depth);
        case \lit(str x): return createLiteral(currentSymbol, x);
        case \char-class(list[CharRange] r): return createLiteral(currentSymbol, genChar(r));
        case \layouts(_): return spaceLayout(currentSymbol, symbolGrammar);
        case \iter-star-seps(Symbol s, list[Symbol] l):
            return createSepCycles(currentSymbol, s, l, symbolGrammar, depth, 3);
        case \iter-seps(Symbol s, list[Symbol] l):
            return createSepCycles(currentSymbol, s, l, symbolGrammar, depth, 4);
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
  <b, e> = pick(ok);
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

// Rough "size" of an alternative, used to force termination when the depth budget runs out.
int cost(Production p) = size([x | x <- p.symbols, x is sort || x is lex]);

Tree createNonTerminal(Symbol currentSymbol, Grammar symbolGrammar, int depth) {
    list[Production] candidates = options(symbolGrammar[currentSymbol]);

    list[Production] l = [p | p <- candidates, blockReason(p) == ""];
    if(l == []){
        str reasons = intercalate(", ", ["<prodKey(p)> (<blockReason(p)>)" | p <- candidates]);
        throw "No allowed production for <symName(currentSymbol)>: <reasons>";
    }

    if(depth <= 0){
        cheapest = min([cost(x) | x <- l]);
        l = [p | p <- l, cost(p) == cheapest];
    }

    Production p = weightedPick(l, [choiceWeight(q) | q <- l]);
    if(cfg.debug){
        println("Options: <[prodKey(q) | q <- l]>");
        println("Choice: <prodKey(p)>");
    }
    record(p);

    return appl(p, [gen(x, symbolGrammar, depth-1) | x <- p.symbols]);
}

// ---------- rules ----------

str symName(Symbol s) = (s has name) ? s.name : "<s>";

str symKey(Symbol s) {
    switch(s){
        case \lit(str x): return "\"<x>\"";
        case \conditional(Symbol c, _): return symKey(c);
        case \iter-seps(Symbol c, _): return "{<symKey(c)>}+";
        case \iter-star-seps(Symbol c, _): return "{<symKey(c)>}*";
        case \layouts(_): return "";
        default: return symName(s);
    }
}

str sortOf(Production p) = p.def is label ? symName(p.def.symbol) : symName(p.def);

// Key used to address a production in rules and forcedOrder: its label, or "Sort.Child" when unlabeled.
str prodKey(Production p)
    = p.def is label ? p.def.name
    : "<sortOf(p)>.<intercalate(" ", [k | x <- p.symbols, k := symKey(x), k != ""])>";

// "Sort.label" for labeled productions; identical to prodKey for unlabeled ones.
str qualifiedKey(Production p) = p.def is label ? "<sortOf(p)>.<p.def.name>" : prodKey(p);

// The key a rule is stored under for this production: qualified wins over bare.
str ruleKey(Production p) {
    str q = qualifiedKey(p);
    return q in cfg.rules ? q : prodKey(p);
}

Rule ruleFor(Production p) {
    str k = ruleKey(p);
    return k in cfg.rules ? cfg.rules[k] : rule();
}

bool matchesKey(Production p, str k) = k == prodKey(p) || k == qualifiedKey(p);

bool isNextForced(Production p)
    = orderIdx < size(cfg.forcedOrder) && matchesKey(p, cfg.forcedOrder[orderIdx]);

// Non-empty string = the reason this production may not be chosen right now.
str blockReason(Production p) {
    Rule r = ruleFor(p);
    if(r.veto) return "vetoed";
    if(r.weight <= 0) return "weight 0";
    if(r.maxUses >= 0 && (useCount[ruleKey(p)] ? 0) >= r.maxUses) return "maxUses <r.maxUses> reached";
    // Keys later in forcedOrder stay locked until everything before them has appeared.
    if(!isNextForced(p) && any(k <- cfg.forcedOrder[orderIdx..], matchesKey(p, k)))
        return "locked by forcedOrder";
    return "";
}

// Boost the next forced production itself, and any alternative whose subtree can still produce it,
// so generation steers towards it (e.g. BlockStm.Stm over BlockStm.LocalVarDecStm when "if" is next).
int choiceWeight(Production p)
    = ruleFor(p).weight * ((isNextForced(p) || leadsToNextForced(p)) ? cfg.forcedBoost : 1);

bool leadsToNextForced(Production p)
    = orderIdx < size(cfg.forcedOrder)
    && any(x <- p.symbols, s <- childSorts(x), cfg.forcedOrder[orderIdx] in (reach[s] ? {}));

// Nonterminals that a symbol in a production's right-hand side expands to.
set[Symbol] childSorts(Symbol s) {
    switch(s){
        case \sort(_): return {s};
        case \lex(_): return {s};
        case \conditional(Symbol c, _): return childSorts(c);
        case \opt(Symbol c): return childSorts(c);
        case \iter(Symbol c): return childSorts(c);
        case \iter-star(Symbol c): return childSorts(c);
        case \iter-seps(Symbol c, list[Symbol] seps): return {*childSorts(x) | x <- [c, *seps]};
        case \iter-star-seps(Symbol c, list[Symbol] seps): return {*childSorts(x) | x <- [c, *seps]};
        default: return {};
    }
}

// Fixpoint: for every nonterminal, the keys (bare and qualified) of all productions reachable from it.
map[Symbol, set[str]] reachableKeys(Grammar g) {
    map[Symbol, set[str]] r = (s : {} | s <- g);
    solve(r) {
        for(s <- g, p <- options(g[s]))
            r[s] += {prodKey(p), qualifiedKey(p)} + {*(r[c] ? {}) | x <- p.symbols, c <- childSorts(x)};
    }
    return r;
}

void record(Production p) {
    bool forced = isNextForced(p);
    for(k <- {prodKey(p), qualifiedKey(p)})
        useCount[k] ? 0 += 1;
    if(forced) orderIdx += 1;
}

// ---------- helpers ----------

list[Production] options(Production p){
    switch(p) {
        case choice(_, set[Production] prods): return [*options(q) | q <- prods];
        case priority(_, list[Production] prods): return [*options(q) | q <- prods];
        case associativity(_, _, set[Production] prods): return [*options(q) | q <- prods];
        case \prod(_, _, _): return [p];
        default: throw "Unknown production: <p>";
    }
}

// List::getOneFrom uses Prelude's own unseeded Random, so arbSeed doesn't affect it.
// arbInt does use the Random that arbSeed resets, so pick through that instead.
&T pick(list[&T] xs) = xs[arbInt(size(xs))];

&T weightedPick(list[&T] xs, list[int] ws) {
    int r = arbInt(sum(ws));
    for(i <- index(xs)) {
        if(r < ws[i]) return xs[i];
        r -= ws[i];
    }
    return xs[-1];
}