module Type2Mutator
import ParseTree;
import IO;
import Set;
import Map;
import String;
import util::Math;
import util::ShellExec;
import Evaluate;
import Mutate;
import lang::java::\syntax::Java15;

// Type-2: syntactically identical, except for identifier names, literal values, white space, layout and comments.
// The generator makes no literals, so only identifiers are renamed. Types (boolean, int, ...) are keywords, not Ids, so they stay.

// A random 3-letter lowercase name, like the generator's names
str randomName() {
    str s = "";
    for (_ <- [0..3]) s += stringChar(97 + arbInt(26)); // 97 = 'a'
    return s;
}

// A name not in taken that parses as an Id (so it is not a keyword like "int" or "for")
str freshName(set[str] taken) {
    while (true) {
        str s = randomName();
        if (s in taken) continue;
        try { parse(#Id, s); return s; }
        catch: continue;
    }
}

// Consistent renaming: every occurrence of the same identifier gets the same new name
tuple[Tree tree, map[str, str] ren] renameIds(MethodDec m, set[str] taken) {
    map[str, str] ren = ();
    Tree t = visit (m) {
        case Id i: {
            str old = "<i>";
            if (old notin ren) ren[old] = freshName(taken + range(ren));
            insert parse(#Id, ren[old]);
        }
    };
    return <t, ren>;
}

// One injection = one Type-2 reference pair. out is the run folder (CustomDataSet_T2/<runName>/)
void injectT2(loc src, loc out, str a, str name, str b, int idA, int idB, bool withLayout) {
    Tree cuA = parse(#start[CompilationUnit], src + a, allowAmbiguity=true);
    MethodDec m = findMethod(cuA, name);
    // names already used in file B: the mutant must not collide with them
    set[str] taken = {"<i>" | /Id i := parse(#start[CompilationUnit], src + b, allowAmbiguity=true)};
    <mutated, ren> = renameIds(m, taken);
    if (withLayout) {
        mutated = visit (mutated) { case Tree t => mutateLayout(t) when isLayout(t) };
    }
    str mutant = unparse(mutated);
    int s1 = m.src.begin.line;
    int e1 = m.src.end.line;
    tuple[str text, int s, int e] r = injectBeforeLastBrace(readFile(src + b), mutant);
    loc dst = out + "dataset/";
    writeFile(dst + a, readFile(src + a));
    writeFile(dst + b, r.text);
    appendToFile(out + "functions.csv", "<a>,default,<s1>,<e1>,<idA>,0,custom,0,FALSE\n");
    appendToFile(out + "functions.csv", "<b>,default,<r.s>,<r.e>,<idB>,0,custom,0,FALSE\n");
    // syntactic type 2; similarity is 1.0 after Type-2 normalisation (identifiers and layout normalised)
    appendToFile(out + "clones.csv", "<idA>,<idB>,0,original-mutant,2,1.0,1.0,0,0,0,0,0,0,0,0,FALSE\n");
    println("injected <name> from <a> (<s1>-<e1>) into <b> (<r.s>-<r.e>), renamed <ren>");
}

void main(str runName = "NewDataset", int cpdMinTokens = 10, bool withLayout = true) {
    loc src = |cwd:///CustomDataSet/default/|;
    loc run = |cwd:///CustomDataSet_T2/| + "<runName>/";
    // Clean previous run with the same name: the whole run folder
    if (exists(run)) remove(run, recursive=true);
    writeFile(run + "functions.csv", "NAME,TYPE,STARTLINE,ENDLINE,ID,NORMALIZED_SIZE,PROJECT,TOKENS,INTERNAL\n");
    writeFile(run + "clones.csv", "FUNCTION_ID_ONE,FUNCTION_ID_TWO,FUNCTIONALITY_ID,TYPE,SYNTACTIC_TYPE,SIMILARITY_LINE,SIMILARITY_TOKEN,MIN_SIZE,MAX_SIZE,MIN_PRETTY_SIZE,MAX_PRETTY_SIZE,MIN_JUDGES,MIN_CONFIDENCE,MIN_TOKENS,MAX_TOKENS,INTERNAL\n");

    // Pairs Gen1->Gen2, Gen3->Gen4, ...: a random method from the odd file is mutated into the even file
    int files = 20;
    for (i <- [1..files/2 + 1]) {
        str fileA = "Gen<2*i - 1>.java";
        str fileB = "Gen<2*i>.java";
        injectT2(src, run, fileA, pickMethodAtRandom(src + fileA), fileB, 2*i - 1, 2*i, withLayout);
    }
    str wsl = "/mnt/e/CloneBenchmarks/BenchmarkGeneration/CustomDataSet_T2/<runName>";
    // NiCad Type-2 config with consistent renaming and minsize=1 (t2small)
    println(exec("wsl", args=["bash", "-lc", "cd ~/NiCad-6.2 && ./nicad6 functions java <wsl>/dataset t2small"]));
    list[Pair] ps = readNicad(run + "dataset_functions-consistent-clones/dataset_functions-consistent-clones-0.00.xml"); // rename=consistent adds "-consistent" to NiCad's output names
    // CPD: --ignore-identifiers, otherwise renamed code counts as different
    println(exec("wsl", args=["bash", "-lc", "~/pmd/bin/pmd cpd --language java --minimum-tokens <cpdMinTokens> --ignore-identifiers --dir <wsl>/dataset --format xml --no-fail-on-violation \> <wsl>/cpd.xml 2\>/dev/null"]));
    list[Pair] cp = readCpd(run + "cpd.xml");

    println("\n== NiCad ==");
    str nicadReport = evaluate(run, ps);
    println("\n== CPD ==");
    str cpdReport = evaluate(run, cp);
    // Same report, saved next to clones.csv so each run folder documents itself
    writeFile(run + "results.txt",
        "run: <runName>\n"
        + "Type-2, layout changes: <withLayout>\n"
        + "NiCad: type-2c config (t2small, minsize=1)\n"
        + "CPD: minimum tokens <cpdMinTokens>, ignore identifiers\n"
        + "\n== NiCad ==\n" + nicadReport
        + "\n== CPD ==\n" + cpdReport);
    println("\nwrote <run + "results.txt">");
}
