import std.stdio;
import std.file;
import std.path;
import std.process;
import std.array;
import std.regex;
import std.algorithm;

import info;

string baseWithoutExtension(string s) {
    return s.stripExtension.baseName;
}

const importSuggestions = regex(`import (\S+?);`);
const undefinedIndentifiers =  regex(r"(?:undefined identifier `|no property '|template ')(\w+)(' is not defined)?");
const brokenExpectations = regex(r"found `(.+?)` when expecting `(.+?)`");
bool tryCompile(string base, string outFileName, string content, string[] libs) {
    auto outFile = File(outFileName, "w");
    outFile.write("module " ~ base ~ ";\n");
    foreach(lib; libs) {
        outFile.write("import " ~ lib ~ ";\n");
    }
    outFile.write("void main(string[] argv) {\n");
    outFile.write(content);
    outFile.write("\n;}");
    outFile.close;

    auto dmd = execute(["dmd", outFileName, "-wi"]);
    if(dmd.status != 0) {
        bool changed = false;
        // auto import
        // 1. scrape all "import <>;" suggestions
        foreach(suggestion; dmd.output.matchAll(importSuggestions)) {
            string name = suggestion[1];
            libs ~= name;
            stderr.writeln("Implicitly added ", name);
            changed = true;
        }
        // 2. scrape all " undefined identifier"
        foreach(suggestion; dmd.output.matchAll(undefinedIndentifiers)) {
            string name = suggestion[1];
            if(name !in identifierMap) {
                stderr.writeln("Uncatalogued identifier: ", name);
                continue;
            }
            string lib = identifierMap[name];
            libs ~= lib;
            changed = true;
        }

        if(changed) {
            /* writeln("ASDADASDSA:", dmd.output); */
            return tryCompile(base, outFileName, content, libs);
        }
        else {
            writeln("Unresolved Errors:\n", dmd.output);
            return false;
        }
    }
    return true;
}

void main(string[] argv) {
    string source = argv[1];
    string base = source.baseWithoutExtension;

    string content = source.readText;
    string outFileName = base ~ ".out";

    if(tryCompile(base, outFileName ~ ".d", content, [])) {
        stderr.writeln("Executable successfully generated.");
        spawnProcess("./" ~ outFileName ~ ".exe");
    }
    else {
        stderr.writeln("Unable to generate executable.");
    }
}
