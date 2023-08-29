#!/usr/bin/env node

const path = require("path");
const { Command } = require("commander");
const { execSync } = require("child_process");
const { version } = require("../package.json");
const { dotrainc, dotraind } = require("../cjs.js");
const { readFileSync, writeFileSync } = require("fs");


const getOptions = async args => new Command("dotrain")
    .description("CLI command to compile/decompile a source file.")
    .option("-c, --compile <expressions...>", "Use compiling mode with specified expression names, to compile a .rain file to ExpressionConfig output in a .json")
    .option("-d, --decompile <op meta hash>", "Use decompiling mode with a specific opmeta hash, to decompile an ExpressionConfig in a .json to a .rain")
    .option("-i, --input <path>", "Path to input file, either a .rain file for compiling or .json for decompiling")
    .option("-o, --output <path>", "Path to output file, will output .json for compile mode and .rain for decompile mode")
    .option("-b, --batch-compile <path>", "Path to a json file of mappings of dotrain files paths, expression names and output json files paths to batch compile")
    .option("-s, --stdout", "Log the result in terminal")
    .version(version)
    .parse(args)
    .opts();

const main = async args => {
    const options = await getOptions(args);
    const parentDir = execSync("pwd").toString().trim();

    if (options.batchCompile) {
        if (options.compile || options.decompile) throw "cannot use -c or -d in batch compile mode";
        if (options.input || options.output) throw "cannot use -i or -o in batch compile mode";
        const EXP_PATTERN = /^[a-z][0-9a-z-]*$/;
        const JSON_PATH_PATTERN = /^(\.?\/)(\.\/|\.\.\/|[^]*\/)*[^]+\.json$/;
        const DOTRAIN_PATH_PATTERN = /^(\.?\/)(\.\/|\.\.\/|[^]*\/)*[^]+\.rain$/;
        const mappingContent = JSON.parse(
            readFileSync(
                path.resolve(parentDir, options.batchCompile)
            ).toString()
        );
        if (
            Array.isArray(mappingContent) 
            && mappingContent.length 
            && mappingContent.every(v => typeof v.dotrain === "string"
                && v.dotrain
                && DOTRAIN_PATH_PATTERN.test(v.dotrain)
                && typeof v.json === "string"
                && v.json
                && JSON_PATH_PATTERN.test(v.json)
                && Array.isArray(v.expressions)
                && v.expressions.length
                && v.expressions.every(name => 
                    typeof name === "string"
                    && name
                    && EXP_PATTERN.test(name)
                )
            )
        ) {
            for (let i = 0; i < mappingContent.length; i++) {
                const dotrainContent = readFileSync(
                    path.resolve(parentDir, mappingContent[i].dotrain)
                ).toString();
                const result = await dotrainc(dotrainContent, mappingContent[i].expressions);
                const text = JSON.stringify(result, null, 2);
                writeFileSync(
                    path.resolve(parentDir, mappingContent[i].json) ,
                    text
                );
                if (options.stdout) console.log("\x1b[90m%s\x1b[0m", text);
                console.log("\n");
            }
            console.log("\x1b[32m%s\x1b[0m", "Compiled all files successfully!");
        }
        else throw "invalid mapping file content";
    }
    else {
        if (options.compile && options.decompile) throw "cannot use -c and -d simultanously!";
        else {
            if (options.compile) {
                if (Array.isArray(options.compile) && options.compile.length > 0) {
                    if (!options.input.endsWith(".rain")) throw "invalid input file!";
                    else {
                        const content = readFileSync(
                            path.resolve(parentDir, options.input)
                        ).toString();
                        const result = await dotrainc(content, options.compile);
                        const text = JSON.stringify(result, null, 2);
                        writeFileSync(
                            options.output.endsWith(".json") 
                                ? path.resolve(parentDir, options.output) 
                                : path.resolve(parentDir, options.output) + ".json", 
                            text
                        );
                        if (options.stdout) console.log("\x1b[90m%s\x1b[0m", text);
                        console.log("\n");
                        console.log("\x1b[32m%s\x1b[0m", "Compiled successfully!");
                    }
                }
                else throw "invalid expressions!";
            }
            if (options.decompile) {
                if (!options.input.endsWith(".json")) throw "invalid input file!";
                else {
                    const content = readFileSync(
                        path.resolve(parentDir, options.input)
                    ).toString();
                    const result = await dotraind(JSON.parse(content), options.decompile);
                    const text = result.getText();
                    writeFileSync(
                        options.output.endsWith(".json") 
                            ? path.resolve(parentDir, options.output) 
                            : path.resolve(parentDir, options.output) + ".rain", 
                        text
                    );
                    if (options.stdout) console.log("\x1b[90m%s\x1b[0m", text);
                    console.log("\n");
                    console.log("\x1b[32m%s\x1b[0m", "Decompiled successfully!");
                }
            }
        }
    }
};

main(
    process.argv
).then(
    () => { 
        process.exit(0); 
    }
).catch(
    v => {
        console.log("\x1b[31m%s\x1b[0m", "An error occured during execution: ");
        console.log(v);
        process.exit(1);
    }
);