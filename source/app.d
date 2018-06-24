import std.stdio;
import std.file;
import std.path;
import std.process;
import std.array;
import std.regex;

import info;

string baseWithoutExtension(string s) {
    return s.stripExtension.baseName;
}

const AUTO_IMPORTS = [
    "algorithm", "array", "ascii", "base64", "bigint", "bitmanip",
    "compiler", "complex", "concurrency", "container", "conv", "csv",
    "datetime", "demangle", "digest", "encoding", "exception", "experimental",
    "file", "format", "functional", "getopt", "json", "math", "mathspecial",
    "meta", "mmfile", "net", "numeric", "outbuffer", "parallelism", "path",
    "process", "random", "range", "regex", "signals", "socket", "stdint",
    "stdio", "string", "system", "traits", "typecons", "uni", "uri", "utf",
    "uuid", "variant", "windows", "xml", "zip", "zlib"
];

const importSuggestions = regex(`import (\S+?);`);
const undefinedIndentifiers =  regex(r"(?:undefined identifier `|no property ')(\w+)");
bool tryCompile(string base, string outFileName, string content, string[] libs) {
    auto outFile = File(outFileName, "w");
    outFile.write("module " ~ base ~ ";\n");
    foreach(lib; libs) {
        outFile.write("import " ~ lib ~ ";\n");
    }
    outFile.write("void main(string[] argv) {\n");
    outFile.write(content);
    outFile.write("\n}");
    outFile.close;

    auto dmd = execute(["dmd", outFileName]);
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
            writeln("ASDADASDSA:", dmd.output);
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
