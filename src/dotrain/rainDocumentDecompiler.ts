import { RainDocument } from "./rainDocument";
import { MetaRecord, MetaStore } from "./metaStore";
import { TextDocument } from "../rainLanguageTypes";
import { ExpressionConfig } from "../rainLanguageTypes";
import { Equation, Expression, parse } from "@nohns/algebra.js";
import { arrayify, BigNumber, CONSTANTS, isBytesLike, extractByBits, getRandomInt } from "../utils";
import { OpMeta, InputMeta, OutputMeta, OperandArgs, metaFromBytes, MAGIC_NUMBERS, toOpMeta } from "@rainprotocol/meta";


/**
 * @public 
 * RainDocument (dotrain) decompiler, decompiles ExpressionConfig (bytes) to a valid RainDocument instance
 * 
 * @param expressionConfig - ExpressionConfig to decompile
 * @param metaHash - The meta hash
 * @param metaStore - (optional) MetaStore object instance
 * @returns A promise that resolves with a RainDocument
 */
export async function dotraind(
    expressionConfig: ExpressionConfig, 
    metaHash: string, 
    metaStore = new MetaStore(),
): Promise<RainDocument> {

    // /**
    //  * @public
    //  * Format a minified Rain document
    //  *
    //  * @remarks
    //  * If the string is already indentend, the method will wrongly generate the string
    //  *
    //  * @param _text - A minified Raain document
    //  * @returns A formatted output
    //  */
    // function rainFormat(_text: string): string {
    //     const n = 4;
    //     const space = " ";
    //     let counter = 0;
    //     const _expressions: string[] = [];

    //     // extract individual expression (sources expressions) that are separated by semi
    //     while (_text.length) {
    //         const _index = _text.search(/;/i);
    //         if (_index > -1) {
    //             _expressions.push(_text.slice(0, _index + 1));
    //             _text = _text.slice(_index + 1);
    //         } 
    //     }

    //     // start prettifying
    //     for (let j = 0; j < _expressions.length; j++) {
    //         const _lhsIndex = _expressions[j].search(/:/i);
    //         for (let i = _lhsIndex + 2; i < _expressions[j].length; i++) {
    //             if ( _expressions[j][i] === " " && counter > 0) {
    //                 _expressions[j] =
    //                 _expressions[j].slice(0, i + 1) +
    //                 "\n" +
    //                 space.repeat(counter * n) +
    //                 _expressions[j].slice(i + 1);
    //                 i += (counter * n) + 2;
    //             }
    //             if (_expressions[j][i] === "(") {
    //                 counter++;
    //                 _expressions[j] =
    //                 _expressions[j].slice(0, i + 1) +
    //                 "\n" +
    //                 space.repeat(counter * n) +
    //                 _expressions[j].slice(i + 1);
    //                 i += (counter * n) + 2;
    //             }
    //             if (_expressions[j][i] === ")") {
    //                 counter--;
    //                 _expressions[j] =
    //                 _expressions[j].slice(0, i) +
    //                 "\n" +
    //                 space.repeat(counter * n) +
    //                 _expressions[j].slice(i);
    //                 i += (counter * n) + 1;
    //             }
    //         }
    //     }
    //     return _expressions.join("\n");
    // }


    /**
     * Method to calculate number of inputs
     */
    function calcInputs(inputMeta: InputMeta, operand: number): number {
        if (inputMeta === 0) return 0;
        else {
            if ("bits" in inputMeta) {
                return extractByBits(operand, inputMeta.bits!, inputMeta.computation);
            }
            else return inputMeta.parameters.length;
        }
    }

    /**
     * Method to calculate number of outputs
     */
    function calcOutputs(outputMeta: OutputMeta, operand: number): number {
        if (typeof outputMeta === "number") return outputMeta;
        else {
            return extractByBits(operand, outputMeta.bits!, outputMeta.computation);
        }
    }

    /**
     * Method deconstruct operand to separated arguments
     */
    function deconstructByBits(value: number, args: {
        bits: [number, number], 
        computation?: string
    }[]): number[] {
        const result: number[] = [];
        for (let i = 0; i < args.length; i++) {
            let _val = extractByBits(value, args[i].bits);
            const _comp = args[i].computation;
            if (_comp) {
                const _lhs = parse(_comp);
                const _eq = new Equation(_lhs as Expression, _val);
                const _res = _eq.solveFor("arg")?.toString();
                if (_res !== undefined) _val = Number(_res);
                else throw new Error("invalid/corrupt operand or operand arguments in opmeta");
            }
            result.push(_val);
        }
        return result;
    }


    let _opmeta: OpMeta[];
    if (isBytesLike(metaHash)) {
        let _metaRecord: MetaRecord | null | undefined;
        if (metaHash.match(/^0x[a-fA-F0-9]{64}$/)) {
            _metaRecord = metaStore.getRecord(metaHash);
            if (!_metaRecord) {
                await metaStore.updateStore(metaHash);
                _metaRecord = metaStore.getRecord(metaHash);
                if (!_metaRecord) throw new Error(`cannot find settlement for hash: ${metaHash}`);
            }
        }
        else throw new Error("invalid meta hash, must be 32 bytes");
        try {
            const _hasOpmeta = _metaRecord.sequence.find(
                v => v.magicNumber === MAGIC_NUMBERS.OPS_META_V1
            );
            if (_hasOpmeta) {
                _opmeta = toOpMeta(metaFromBytes(_hasOpmeta.content));
            }
            else throw new Error("provided hash doesn't include an opmeta");
        }
        catch (err) {
            return Promise.reject(err);
        }
    }
    else return Promise.reject("invalid meta hash, must be in hex string");

    const _constants: string[] = [];
    for (const item of expressionConfig.constants) {
        _constants.push(BigNumber.from(item).toHexString());
    }
    let _stack: string[] = [];
    const _finalStack: string[] = [];

    // start formatting
    for (let i = 0; i < expressionConfig.sources.length; i++) {
        const _lhs: string[] = [];
        const _src = arrayify(expressionConfig.sources[i], { allowMissingPrefix: true });
        let _zeroOpCounter = 0;
        let _multiOpCounter = 0;
        for (let j = 0; j < _src.length; j += 4) {
            const _op = (_src[j] << 8) + _src[j + 1];
            const _operand = (_src[j + 2] << 8) + _src[j + 3];
            const _index = _op;

            // error if an opcode not found in opmeta
            if (_index > _opmeta.length) return Promise.reject(
                `opcode with enum "${_op}" does not exist on OpMeta`
            );
            else {
                if (
                    _op === _opmeta.findIndex(v => v.name === "read-memory") && 
                    (_operand & 1) === 1
                ) {
                    _stack.push(
                        BigNumber.from(
                            _constants[_operand >> 1]
                        ).eq(CONSTANTS.MaxUint256)
                            ? "max-uint256"
                            : _constants[_operand >> 1]
                    );
                }
                else {
                    let _operandArgs = "";
                    const _inputs = calcInputs(_opmeta[_index].inputs, _operand);
                    const _outputs = calcOutputs(_opmeta[_index].outputs, _operand);

                    // count zero output ops
                    if (_outputs === 0) _zeroOpCounter++;

                    // count multi output ops
                    if (_outputs > 1) _multiOpCounter += _outputs - 1;

                    // construct operand arguments
                    if (typeof _opmeta[_index].operand !== "number") {
                        let _args;
                        try {
                            _args = deconstructByBits(
                                _operand, 
                                (_opmeta[_index].operand as OperandArgs).map((v) => {
                                    return {
                                        bits: v.bits,
                                        computation: v.computation
                                    };
                                })
                            );
                        }
                        catch (err) {
                            return Promise.reject(`${err} of opcode ${_opmeta[_index].name}`);
                        }   
                        if (
                            _args.length === (_opmeta[_index].operand as OperandArgs).length
                        ) {
                            const _i = (_opmeta[_index].operand as OperandArgs).findIndex(
                                v => v.name === "inputs"
                            );
                            if (_i > -1) _args.splice(_i, 1);
                            if (_args.length) _operandArgs = "<" + _args.join(" ") + ">";
                        }
                        else return Promise.reject(
                            `decoder of opcode with enum "${
                                _opmeta[_index].name
                            }" does not match with its operand arguments`
                        );
                    }

                    // update formatter stack with new formatted opcode i.e.
                    // take some items based on the formatted opcode and then
                    // push the appended string with the opcode back into the stack
                    _stack.push(
                        // ..._multiOutputs,
                        _opmeta[_index].name +
                        _operandArgs +
                        "(" +
                        (_inputs > 0 ? _stack.splice(-_inputs).join(" ") : "") +
                        ")"
                    );
                }
            }
        }
        
        // cache the LHS elements
        for (let j = 0; j < _stack.length + _multiOpCounter - _zeroOpCounter; j++) _lhs.push("_");

        // construct the source expression at current index, both LHS and RHS
        _finalStack.push(
            `#expression-${i + 1}\n` +
            _lhs.join(" ") + 
            " : " + 
            _stack.join(" ") +
            ";"
        );
        _stack = [];
    }
    return Promise.resolve(
        await RainDocument.create(
            TextDocument.create(
                "untitled-" + getRandomInt(1000000000).toString() + ".rain", 
                "rainlang", 
                1, 
                `@${metaHash}\n` + _finalStack.join("\n\n")
            ),
            metaStore
        )
    );
}