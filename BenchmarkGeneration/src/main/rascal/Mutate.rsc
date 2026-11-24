module Mutate
// Helpers shared by the mutators (Type1Mutator, Type2Mutator, ...)
import ParseTree;
import IO;
import List;
import String;
import util::Math;
import lang::java::\syntax::Java15;

// Layout node: an appl whose production defines layout. https://www.rascal-mpl.org/docs/Rascal/Expressions/Values/Boolean/Match/
// pattern matching https://www.rascal-mpl.org/docs/Rascal/Expressions/Values/Boolean/Match/
bool isLayout(Tree t) = appl(prod(\layouts(_), _, _), _) := t; // isLayout https://www.rascal-mpl.org/docs/Library/analysis/grammars/LOC/

// Replace a layout node with a random choice; appl(rule, chars) builds the new node.
Tree mutateLayout(Tree t) { // make sure every option of a layout e.g. removinng a space
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
