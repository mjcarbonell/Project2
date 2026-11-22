module Evaluate

import IO;
import List;
import String;

alias Frag = tuple[str dir, str file, int s, int e];
alias Pair = tuple[Frag a, Frag b];


// NiCad pairs XML -> list of pairs (each <clone> has two <source .../> lines)
list[Pair] readNicad(loc xml) {
    list[Frag] srcs = [];
    // <Name: Regex> pattern https://www.rascal-mpl.org/docs/Rascal/Patterns/Regular/
    for (/\<source file="<p:[^"]*>" startline="<s:[0-9]+>" endline="<e:[0-9]+>"/ := readFile(xml)) { 
        list[str] parts = split("/", p);
        srcs += [<parts[size(parts)-2], parts[size(parts)-1], toInt(s), toInt(e)>];  // lists concatenate in rascal [] + [x]  → [x] 
    }
    return [<srcs[i], srcs[i+1]> | i <- [0, 2 .. size(srcs) - 1]]; // 0, 2,... 19 ... Thus, it stops at 18. This is because gen20.java does not have another file to be paired with 
}

// PMD CPD XML -> list of pairs. Each <duplication> lists 2 or more <file .../> tags
// (attribute order varies), so every combination of its files becomes one pair.
list[Pair] readCpd(loc xml) {
    list[Pair] out = [];
    for (str dup <- tail(split("\<duplication ", readFile(xml)))) { 
        // Grab each duplicate... With 2 <file> tags (usually the case), you get 2 fragments, which make 1 pair.
        // With 3 <file> tags, the same code is in 3 places, which make 3 pairs (A–B, A–C, B–C). That's what line 35 is for.
        list[Frag] fs = [];
        for (/\<file <attrs:[^\>]*>\/\>/ := dup) {
            str at = " " + attrs;
            // <Name: Regex> pattern https://www.rascal-mpl.org/docs/Rascal/Patterns/Regular/
            if (/ path="<p:[^"]*>"/ := at, / line="<s:[0-9]+>"/ := at, / endline="<e:[0-9]+>"/ := at) {
                list[str] parts = split("/", p);
                fs += [<parts[size(parts)-2], parts[size(parts)-1], toInt(s), toInt(e)>];
            }
        }
        out += [<fs[i], fs[j]> | i <- [0..size(fs)], j <- [i+1..size(fs)]];
    }
    return out;
}

// functions.csv + clones.csv -> ground-truth pairs
list[Pair] readTruth(loc dataset) {
    map[int, Frag] frags = ();
    for (line <- tail(readFileLines(dataset + "functions.csv"))) { // each function. 
        list[str] c = split(",", line);   // NAME,TYPE,STARTLINE,ENDLINE,ID,...
        frags[toInt(c[4])] = <c[1], c[0], toInt(c[2]), toInt(c[3])>;
    }
    // The 0th index of c is the first fragment, 1th index is the second fragment. 
    // We then convert these indices to Ints and search the valid functions by their ID.  
    return [<frags[toInt(c[0])], frags[toInt(c[1])]>| 
    line <- tail(readFileLines(dataset + "clones.csv")), list[str] c := split(",", line)];
}

// Same file and line ranges intersect
bool overlaps(Frag x, Frag y){
    return x.file == y.file && x.s <= y.e && y.s <= x.e;
} 
bool matches(Pair t, Pair r){
    return (overlaps(t.a, r.a) && overlaps(t.b, r.b)) || (overlaps(t.a, r.b) && overlaps(t.b, r.a));
}
    
str show(Pair p) = "<p.a.file>:<p.a.s>-<p.a.e> \<-\> <p.b.file>:<p.b.s>-<p.b.e>";

// Recall of reported pairs against the ground truth in dataset.
// Prints the report and returns the same text, so main can also save it to results.txt.
str evaluate(loc dataset, list[Pair] reported) {
    list[Pair] truth = readTruth(dataset);
    list[Pair] missed = [t | t <- truth, !any(r <- reported, matches(t, r))]; // False negatives (FN). Under the assumption "anything not injected counts as a non-clone."
    // Not necessarily false positives: random generated methods can be real clones by accident
    list[Pair] extra  = [r | r <- reported, !any(t <- truth, matches(t, r))]; // False positives (FP). Injected clones that the CCD did not report.  
    int hit = size(truth) - size(missed); // True positives (TP) amount. 
    // Recall. Of the real clones how many were found ? 
    str report = "ground truth pairs: <size(truth)>\n"
               + "reported pairs:     <size(reported)>\n"
               + "recall:             <hit>/<size(truth)> = <size(truth) == 0 ? 0 : hit * 100 / size(truth)>%\n";
    for (m <- missed){ // Need to show every false positive (FP) pair. 
        report += "  missed <show(m)>\n";
    }
    report += "reported pairs not in ground truth: <size(extra)>\n";
    for (x <- extra){ // Need to show every false negative (FN) pair. 
        report += "  extra  <show(x)>\n";
    } 
    print(report);
    return report;
}
