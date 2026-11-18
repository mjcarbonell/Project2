module Type1Mutator
import ParseTree;
import IO;
import List;
import String;
import util::Math;
import vis::Text; 
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
    str before = substring(b, 0, cut); // gets everything between indices 0 and 6090 
    str after = substring(b, cut); // gets everything between 6090 and last index of the file. 
    int s = countLines(before) + 2; // one blank line, then the mutant
    int e = s + countLines(mutant);
    return <before + "\n    " + mutant + "\n" + after, s, e>;
}

// One injection = one clone class (functionalityID) with one reference pair
void injectT1(loc src, loc out, str a, str name, str b, int functionalityID) {
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
    // Dataset files, laid out like ijadataset/bcb_reduced/<functionality>/default/
    loc dst = out + "<functionalityID>/default/"; 
    writeFile(dst + a, readFile(src + a));
    writeFile(dst + b, r.text);

    int idA = 2 * functionalityID - 1;
    int idB = 2 * functionalityID;
    // rows for our bcb.h2.db, in BigCloneBench column order https://www.rascal-mpl.org/docs/Library/IO/#IO-writeFile
    // Only the columns BigCloneEval reads by default are filled; sizes, tokens and judges are 0
    // (they are only read with filters like -mil, -mit, -mij).
    // functions.csv: NAME,TYPE,STARTLINE,ENDLINE,ID,NORMALIZED_SIZE,PROJECT,TOKENS,INTERNAL
    appendToFile(out + "functions.csv","<a>,default,<s1>,<e1>,<idA>,0,custom,0,FALSE\n");
    appendToFile(out + "functions.csv","<b>,default,<r.s>,<r.e>,<idB>,0,custom,0,FALSE\n");
    
    appendToFile(out + "clones.csv","<idA>,<idB>,<functionalityID>,original-mutant,1,1.0,1.0,0,0,0,0,0,0,0,0,FALSE\n"); // only record id of fragments, functionality (classID), Type, Syntactic Type, Sim line, Sim token, 
    appendToFile(out + "functionalities.csv","<a>:<name>,T1 injection of <name> from <a> into <b>,<functionalityID>,generated\n");
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

void main() {
    loc src = |cwd:///CustomDataSet/default/|; // https://www.rascal-mpl.org/docs/Rascal/Locations/
    loc out = |cwd:///CustomDataSet_T1/|;
    // CSV headers (CSVREAD uses the first line as column names)
    writeFile(out + "functions.csv", "NAME,TYPE,STARTLINE,ENDLINE,ID,NORMALIZED_SIZE,PROJECT,TOKENS,INTERNAL\n");
    writeFile(out + "clones.csv", "FUNCTION_ID_ONE,FUNCTION_ID_TWO,FUNCTIONALITY_ID,TYPE,SYNTACTIC_TYPE,SIMILARITY_LINE,SIMILARITY_TOKEN,MIN_SIZE,MAX_SIZE,MIN_PRETTY_SIZE,MAX_PRETTY_SIZE,MIN_JUDGES,MIN_CONFIDENCE,MIN_TOKENS,MAX_TOKENS,INTERNAL\n");
    writeFile(out + "functionalities.csv", "NAME,DESCRIPTION,ID,SEARCH_HEURISTIC\n");

    // str fileA = pickFileAtRandom(src);
    str fileA = "85.java"; 
    // str methodA = pickMethodAtRandom(src + fileA);
    str methodA = "exit"; 
    // str fileB = pickFileAtRandom(src);
    str fileB = "85.java"; 
    injectT1(src, out, fileA, methodA, fileB, 1);
}
