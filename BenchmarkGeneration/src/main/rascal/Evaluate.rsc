module Evaluate

import IO;
import List;
import String;

alias Frag = tuple[str dir, str file, int s, int e];
alias Pair = tuple[Frag a, Frag b];

// NiCad pairs XML -> list of pairs (each <clone> has two <source .../> lines)
list[Pair] readNicad(loc xml) {
    list[Frag] srcs = [];
    for (/\<source file="<p:[^"]*>" startline="<s:[0-9]+>" endline="<e:[0-9]+>"/ := readFile(xml)) {
        list[str] parts = split("/", p);
        srcs += [<parts[size(parts)-2], parts[size(parts)-1], toInt(s), toInt(e)>];
    }
    return [<srcs[i], srcs[i+1]> | i <- [0, 2 .. size(srcs) - 1]];
}

// Pairs in BigCloneEval column layout
void writePairs(list[Pair] ps, loc csv) {
    str rows = "DIR1,FILE1,START1,END1,DIR2,FILE2,START2,END2\n";
    for (Pair p <- ps) {
        Frag a = p.a;
        Frag b = p.b;
        rows += "<a.dir>,<a.file>,<a.s>,<a.e>,<b.dir>,<b.file>,<b.s>,<b.e>\n";
    }
    writeFile(csv, rows);
    println("wrote <size(ps)> pairs to <csv>");
}

// functions.csv + clones.csv -> ground-truth pairs
list[Pair] readTruth(loc dataset) {
    map[int, Frag] frags = ();
    for (line <- tail(readFileLines(dataset + "functions.csv"))) {
        list[str] c = split(",", line);   // NAME,TYPE,STARTLINE,ENDLINE,ID,...
        frags[toInt(c[4])] = <c[1], c[0], toInt(c[2]), toInt(c[3])>;
    }
    return [<frags[toInt(c[0])], frags[toInt(c[1])]>
           | line <- tail(readFileLines(dataset + "clones.csv")), list[str] c := split(",", line)];
}

// Same file and line ranges intersect
bool overlaps(Frag x, Frag y) = x.file == y.file && x.s <= y.e && y.s <= x.e;
bool matches(Pair t, Pair r) =
    (overlaps(t.a, r.a) && overlaps(t.b, r.b)) || (overlaps(t.a, r.b) && overlaps(t.b, r.a));

str show(Pair p) = "<p.a.file>:<p.a.s>-<p.a.e> \<-\> <p.b.file>:<p.b.s>-<p.b.e>";

// Recall of reported pairs against the ground truth in dataset
void evaluate(loc dataset, list[Pair] reported) {
    list[Pair] truth = readTruth(dataset);
    list[Pair] missed = [t | t <- truth, !any(r <- reported, matches(t, r))];
    // Not necessarily false positives: random generated methods can be real clones by accident
    list[Pair] extra  = [r | r <- reported, !any(t <- truth, matches(t, r))];
    int hit = size(truth) - size(missed);
    println("ground truth pairs: <size(truth)>");
    println("reported pairs:     <size(reported)>");
    println("recall:             <hit>/<size(truth)> = <size(truth) == 0 ? 0 : hit * 100 / size(truth)>%");
    for (m <- missed) println("  missed <show(m)>");
    println("reported pairs not in ground truth: <size(extra)>");
    for (x <- extra) println("  extra  <show(x)>");
}
