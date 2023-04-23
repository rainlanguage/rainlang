import { RainDocument } from "../parser/rainDocument";
import { 
    Range, 
    Position,
    MarkupKind,  
    TextDocument, 
    CompletionItem, 
    CompletionItemKind, 
    LanguageServiceParams 
} from "../rainLanguageTypes";


/**
 * @public Provides completion items 
 * 
 * @param document - The TextDocuemnt
 * @param position - Position of the textDocument to get the completion items for
 * @param setting - (optional) Language service params
 * @returns A promise that resolves with Completion items or null if no completion 
 * items were available for that position
 */
export async function getRainlangCompletion(
    document: TextDocument, 
    position: Position,
    setting?: LanguageServiceParams
): Promise<CompletionItem[] | null>

/**
 * @public Provides completion items
 * 
 * @param document - The RainDocument object instance
 * @param position - Position of the textDocument to get the completion items for
 * @param setting - (optional) Language service params
  * @returns A promise that resolves with Completion items or null if no completion 
 * items were available for that position
 */
export async function getRainlangCompletion(
    document: RainDocument, 
    position: Position,
    setting?: LanguageServiceParams
): Promise<CompletionItem[] | null>

export async function getRainlangCompletion(
    document: TextDocument | RainDocument,
    position: Position,
    setting?: LanguageServiceParams 
): Promise<CompletionItem[] | null> {
    let _documentionType: MarkupKind = "plaintext";
    let _rd: RainDocument;
    let _td: TextDocument;
    if (document instanceof RainDocument) {
        _rd = document;
        _td = _rd.getTextDocument();
        if (setting?.metaStore) _rd.getMetaStore().updateStore(setting.metaStore);
    }
    else {
        _td = document;
        _rd = await RainDocument.create(document, setting?.metaStore);
    }
    const format = setting
        ?.clientCapabilities
        ?.textDocument
        ?.completion
        ?.completionItem
        ?.documentationFormat;
    if (format && format[0]) _documentionType = format[0];

    const _prefixText = _td.getText(
        Range.create(Position.create(position.line, 0), position)
    );

    try {
        if (
            _prefixText.includes(":") && 
            !_td.getText(
                Range.create(
                    position, 
                    { line: position.line, character: position.character + 1 }
                )
            ).match(/[a-zA-Z0-9-]/)
        ) {
            const _offset = _td.offsetAt(position);
            const _result = _rd.getOpMeta().map(v => {
                const _following = v.operand === 0 
                    ? "()" 
                    : v.operand.find(i => i.name !== "inputs") 
                        ? "<>()" 
                        : "()";
                return {
                    label: v.name,
                    labelDetails: {
                        detail: _following,
                        description: "opcode"
                    },
                    kind: CompletionItemKind.Function,
                    detail: "opcode " + v.name + _following,
                    documentation: {
                        kind: _documentionType,
                        value: v.desc
                    },
                    insertText: v.name + _following
                } as CompletionItem;
            });
            _rd.getOpMeta().forEach(v => {
                v.aliases?.forEach(e => {
                    const _following = v.operand === 0 
                        ? "()" 
                        : v.operand.find(i => i.name !== "inputs") 
                            ? "<>()" 
                            : "()";
                    _result.push({
                        label: e,
                        labelDetails: {
                            detail: _following, 
                            description: "opcode (alias)"
                        },
                        kind: CompletionItemKind.Function,
                        detail: "opcode " + e + _following,
                        documentation: {
                            kind: _documentionType,
                            value: v.desc
                        },
                        insertText: v.name + _following
                    });
                });
            });
            const _tree = _rd.getParseTree();
            let _currentSource = 0;
            for (let i = 0; i < _tree.length; i++) {
                if (_tree[i].position[0] <= _offset && _tree[i].position[1] >= _offset) {
                    _currentSource = i;
                    break;
                }
            }
            let _pos: [number, number] | undefined;
            _rd.getLHSAliases()[_currentSource]
                ?.filter(v => v.name !== "_")
                .forEach(v => {
                    let _text = "";
                    _pos = _tree[_currentSource].tree.find(e => {
                        if (e.lhs){
                            if (Array.isArray(e.lhs)) {
                                if (e.lhs.find(i => i.name === v.name)) return true; 
                                else return false;
                            }
                            else {
                                if (e.lhs.name === v.name) return true;
                                else return false;
                            }
                        }
                        else return false;
                    })?.position;
                    if (_pos) _text = `${
                        _rd!.getTextDocument().getText(
                            Range.create(
                                _td.positionAt(_pos[0]),
                                _td.positionAt(_pos[1] + 1)
                            )
                        )
                    }`;
                    _result.unshift({
                        label: v.name,
                        labelDetails: {
                            description: "alias"
                        },
                        kind: CompletionItemKind.Variable,
                        detail: v.name,
                        documentation: {
                            kind: _documentionType,
                            value: _documentionType === "markdown" 
                                ? [
                                    "LHS alias for:",
                                    "```rainlang",
                                    _text,
                                    "```"
                                ].join("\n")
                                : `LHS alias for: ${_text}`
                        }
                    });
                });
            
            // filter the items based on previous characters
            let _prefixMatch = "";
            for (let i = 0; i < _prefixText.length; i++) {
                if (_prefixText[_prefixText.length - i - 1].match(/[a-zA-Z0-9-]/)) {
                    _prefixMatch = _prefixText[_prefixText.length - i - 1] + _prefixMatch;
                }
                else break;
            }
            return _result.filter(v => v.label.includes(_prefixMatch));
        }
        else return null;
    }
    catch (err) {
        console.log(err);
        return null;
    }
}