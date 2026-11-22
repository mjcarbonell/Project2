module Type1Mutator
import ParseTree;
import IO;
import List;
import String;
import util::Math;
import vis::Text;
import util::ShellExec;
import Evaluate;
import lang::java::\syntax::Java15;



// Layout node: an appl whose production defines layout. https://www.rascal-mpl.org/docs/Rascal/Expressions/Values/Boolean/Match/
// pattern matching https://www.rascal-mpl.org/docs/Rascal/Expressions/Values/Boolean/Match/
bool isLayout(Tree t) = appl(prod(\layouts(_), _, _), _) := t; // isLayout https://www.rascal-mpl.org/docs/Library/analysis/grammars/LOC/

// Replace a layout node with a random choice; appl(rule, chars) builds the new node.
Tree mutateLayout(Tree t) {
    str old = "<t>";
    if (old == "") return t; // keep empty gaps, so ++ isn't split into + +
    list[str] choices = [old + "  ", old + "/* t1 */ ", old]; // widen, add comment, keep; never removes a line break
    // Creating a replacement node. t.prod is the rule we want, namely LAYOUTLIST. 
    // chars gives us something like [32, 47, 42, 32, 116, 49, 32, 42, 47, 32]
    // grabbing each integer representation and making a list  [char(32), char(47), char(42), …] for the tree node 
    return appl(t.prod, [char(c) | c <- chars(choices[arbInt(size(choices))])]);  // https://www.rascal-mpl.org/docs/Library/ParseTree/
}

// Method name = the Id that is a direct child of the header
str methodName(MethodDec m) {
    for (/MethodDecHead h := m) {
        for (Tree t <- h.args){
            if (Id i := t){
                return "<i>"; // going through the header's children i.e. methodDecHead: (Anno | MethodMod)* TypeParams? ResultType Id "(" {FormalParam ","}* ")" Throws? 
            }
        }
    }
    return "";
}

MethodDec findMethod(Tree cu, str name) {
    for (/MethodDec m := cu){ 
        // Descendant pattern on a tree with a condition. For every method declaration within the tree, if it matches the name  
        if (methodName(m) == name){ // https://www.rascal-mpl.org/docs/Rascal/Patterns/Descendant/
            return m;
        }
    } 
    throw "method <name> not found";
}

// findAll https://www.rascal-mpl.org/docs/Library/String/#String-findAll
int countLines(str s){
    return size(findAll(s, "\n")); // size https://www.rascal-mpl.org/docs/Library/List/#List-size
} 
// Insert mutant before the class's last "}" (other ranges stay valid); return text, start, end line.
tuple[str text, int s, int e] injectBeforeLastBrace(str b, str mutant) {
    int cut = findLast(b, "}"); // Find the index of the last closing bracket. For 85.java this is 6090. https://www.rascal-mpl.org/docs/Library/String/#String-findLast
    str before = substring(b, 0, cut); // gets everything between indices 0 and 6090 https://www.rascal-mpl.org/docs/Library/String/#String-substring
    str after = substring(b, cut); // gets everything between 6090 and last index of the file. 
    int s = countLines(before) + 2; // we want a newline before and after the mutant.  "\n" + mutant + "\n"
    int e = s + countLines(mutant); // In special cases s and e will be equal. This is if the mutant itself has no line breaks e.g. void /* t1 */ iys ( char   qtc /* t1 */ ,   char /* t1 */ gij , /* t1 */ short   yel ) {   int   lbc /* t1 */ ; }
    return <before + "\n    " + mutant + "\n" + after, s, e>;
}

// One injection = one reference pair. out is the run folder (CustomDataSet_T1/<runName>/)
void injectT1(loc src, loc out, str a, str name, str b, int idA, int idB) {
    Tree cuA = parse(#start[CompilationUnit], src + a, allowAmbiguity=true); // Parse Tree https://www.rascal-mpl.org/docs/Library/ParseTree/#ParseTree-parse
    MethodDec m = findMethod(cuA, name); // Checks every node. returns the node with the given name 
    // println(prettyTree(m, \layout=true, literals=true));  // "in between the Symbols that define a syntax non-terminal the locally defined layout non-terminal will be interleaved." https://www.rascal-mpl.org/docs/Rascal/Declarations/SyntaxDefinition/
    Tree mutated = visit (m) {
        case Tree t => mutateLayout(t) when isLayout(t) // Use of when https://www.rascal-mpl.org/docs/Rascal/Patterns/Concrete
    };
    // println(prettyTree(m, \layout=true, literals=true));
    str mutant = unparse(mutated); // Unparse https://www.rascal-mpl.org/docs/Library/ParseTree/#ParseTree-unparse
    int s1 = m.src.begin.line; // src  https://www.rascal-mpl.org/docs/Library/ParseTree/
    int e1 = m.src.end.line; // Start and end line https://www.rascal-mpl.org/docs/Rascal/Locations/
    tuple[str text, int s, int e] r = injectBeforeLastBrace(readFile(src + b), mutant); // Reading a file https://www.rascal-mpl.org/docs/Library/IO/#IO-readFile
    // Java files go in their own subfolder: NiCad writes its output next to the folder it scans
    loc dst = out + "dataset/";
    writeFile(dst + a, readFile(src + a));
    writeFile(dst + b, r.text);

    // rows for our bcb.h2.db, in BigCloneBench column order https://www.rascal-mpl.org/docs/Library/IO/#IO-writeFile
    // Only the columns BigCloneEval reads by default are filled; sizes, tokens and judges are 0
    // (they are only read with filters like -mil, -mit, -mij).
    // functions.csv: NAME,TYPE,STARTLINE,ENDLINE,ID,NORMALIZED_SIZE,PROJECT,TOKENS,INTERNAL
    appendToFile(out + "functions.csv","<a>,default,<s1>,<e1>,<idA>,0,custom,0,FALSE\n");
    appendToFile(out + "functions.csv","<b>,default,<r.s>,<r.e>,<idB>,0,custom,0,FALSE\n");
    
    // By definition similarity line and similarity token are equal to 1. After normalising layout and comments, and a Type-1 mutation only changes layout and comments.
    // So the original and the mutant are 100% similar on both measures. FunctionalityID is always zero.  
    // 0, original-mutant,1,1.0,1.0 means functionalityID, type, syntactic type, similartiy line, similarity token
    appendToFile(out + "clones.csv","<idA>,<idB>,0,original-mutant,1,1.0,1.0,0,0,0,0,0,0,0,0,FALSE\n"); // only record id of fragments, functionality (classID), Type, Syntactic Type, Sim line, Sim token, 
    println("injected <name> from <a> (<s1>-<e1>) into <b> (<r.s>-<r.e>)");
}
// Pick a random .java file from the folder
str pickFileAtRandom(loc dir) {
    // endsWith https://www.rascal-mpl.org/docs/Library/String/#String-endsWith
    list[str] files = [f | f <- listEntries(dir), endsWith(f, ".java")]; // listEntries https://www.rascal-mpl.org/docs/Library/IO/#IO-listEntries
    return files[arbInt(size(files))];
}

// Pick a random method name from a file
str pickMethodAtRandom(loc file) {
    // descendant pattern https://www.rascal-mpl.org/docs/Rascal/Patterns/Descendant/ where we specify a node by type 
    list[str] names = [methodName(m) | /MethodDec m := parse(#start[CompilationUnit], file, allowAmbiguity=true)]; 
    return names[arbInt(size(names))];
}

void main(str runName = "NewDataset", int cpdMinTokens = 10) { // CPD reports duplicated runs of at least this many tokens
    loc src = |cwd:///CustomDataSet/default/|; // https://www.rascal-mpl.org/docs/Rascal/Locations/
    loc run = |cwd:///CustomDataSet_T1/| + "<runName>/";
    // Clean previous run with the same name: the whole run folder
    if (exists(run)) remove(run, recursive=true);
    if (exists(|cwd:///nicad_pairs.csv|)){
        remove(|cwd:///nicad_pairs.csv|);
    }
    // CSV headers (CSVREAD uses the first line as column names)
    writeFile(run + "functions.csv", "NAME,TYPE,STARTLINE,ENDLINE,ID,NORMALIZED_SIZE,PROJECT,TOKENS,INTERNAL\n");
    writeFile(run + "clones.csv", "FUNCTION_ID_ONE,FUNCTION_ID_TWO,FUNCTIONALITY_ID,TYPE,SYNTACTIC_TYPE,SIMILARITY_LINE,SIMILARITY_TOKEN,MIN_SIZE,MAX_SIZE,MIN_PRETTY_SIZE,MAX_PRETTY_SIZE,MIN_JUDGES,MIN_CONFIDENCE,MIN_TOKENS,MAX_TOKENS,INTERNAL\n");

    // Pairs Gen1->Gen2, Gen3->Gen4, ...: a random method from the odd file is mutated into the even file
    int files = 20;
    for (i <- [1..files/2 + 1]) {
        str fileA = "Gen<2*i - 1>.java";
        str fileB = "Gen<2*i>.java";
        str methodA = pickMethodAtRandom(src + fileA);
        injectT1(src, run, fileA, methodA, fileB, 2*i - 1, 2*i);
    }
    // NiCad in WSL (Type-1 config with minsize=1); it writes dataset_functions* next to dataset/
    println(exec("wsl", args=["bash", "-lc","cd ~/NiCad-6.2 && ./nicad6 functions java /mnt/e/CloneBenchmarks/BenchmarkGeneration/CustomDataSet_T1/<runName>/dataset t1small"]));
    list[Pair] ps = readNicad(run + "dataset_functions-clones/dataset_functions-clones-0.00.xml");

    // PMD CPD in WSL (token based, skips whitespace and comments); duplications land in <run>/cpd.xml
    // --no-fail-on-violation: CPD exits non-zero when it finds clones; stderr is dropped so exec can't hang
    println(exec("wsl", args=["bash", "-lc","~/pmd/bin/pmd cpd --language java --minimum-tokens <cpdMinTokens> --dir /mnt/e/CloneBenchmarks/BenchmarkGeneration/CustomDataSet_T1/<runName>/dataset 
    --format xml --no-fail-on-violation \> /mnt/e/CloneBenchmarks/BenchmarkGeneration/CustomDataSet_T1/<runName>/cpd.xml 2\>/dev/null"]));
    list[Pair] cp = readCpd(run + "cpd.xml");

    println("\n== NiCad ==");
    str nicadReport = evaluate(run, ps);
    println("\n== CPD ==");
    str cpdReport = evaluate(run, cp);

    // Same report, saved next to clones.csv so each run folder documents itself
    writeFile(run + "results.txt",
        "run: <runName>\n"
        + "NiCad: type-1 config (t1small, minsize=1)\n"
        + "CPD: minimum tokens <cpdMinTokens>\n"
        + "\n== NiCad ==\n" + nicadReport
        + "\n== CPD ==\n" + cpdReport);
    println("\nwrote <run + "results.txt">");
}
