# Audit 2026-03-23-01 Triage (External Report)

Source: Report_rain.interpreter_2.0_mar_2026.pdf

## External: Security

- [FIXED] H01: (HIGH) Off-by-one in MAX_STACK_RHS_OFFSET causes LHS item count corruption — 63rd RHS item writes into LHS counter byte at offset 0x5F. Path: src/lib/parse/LibParseState.sol
- [FIXED] M01: (MEDIUM) Out-of-bounds second-byte read causes valid decimals to revert — look-ahead past buffer boundary when literal ends with single digit. Path: src/lib/parse/literal/LibParseLiteral.sol. Fix at line 110, test: LibParseLiteral.dispatch.t.sol testTryParseLiteralOOBSecondBytePoison
- [FIXED] M02: (MEDIUM) Out-of-bounds memory read and garbage literal parsing in pragma — tryParseLiteral called when cursor == end after trailing whitespace. Path: src/lib/parse/LibParsePragma.sol. Fix at line 88, test: LibParsePragma.keyword.t.sol testParsePragmaOOBAfterInterstitial
- [FIXED] M03: (MEDIUM) Silent truncation of sub-parser dispatch length — dispatchLength >0xFFFF silently truncated to 16 bits during packing. Path: src/lib/parse/LibSubParse.sol. Fix at line 363, test: LibSubParse.subParseLiteral.t.sol testSubParseLiteralDispatchLengthOverflow
- [FIXED] M04: (MEDIUM) LHS item count overflow causes bitwise carry-over and parser state corruption — 256 LHS items overflows packed byte in unchecked block. Path: src/lib/parse/LibParse.sol. Fix at line 182, test: LibParse.lhsOverflow.t.sol testLHSItemCountOverflow256
- [FIXED] M05: (MEDIUM) Unbounded LHS count in endLine() for empty-RHS lines — lineLHSItems added to totalRHSTopLevel without bounds check. Path: src/lib/parse/LibParseState.sol
- [FIXED] M06: (MEDIUM) Semantic manipulation and implicit validation via malicious extern contracts — LibOpExtern.integrity() blindly trusts external externIntegrity() return values. Path: src/lib/op/00/LibOpExtern.sol
- [FIXED] L01: (LOW) Uppercase hexadecimal prefix bypasses hex parser and fails confusingly — 0X not recognized, routed to decimal parser. Path: src/lib/parse/literal/LibParseLiteral.sol. Fix at line 121, test: LibParseLiteral.dispatch.t.sol testTryParseLiteralUppercaseXReverts
- [FIXED] L02: (LOW) Missing bitwise mask on outputs in LibOpCall — unmasked right shift relies on upstream truncation. Path: src/lib/op/call/LibOpCall.sol
- [FIXED] L03: (LOW) Implicit operand/bytecode synchronisation in LibOpCall — integrity() ignores operand-encoded inputs, relies on external integrityCheck2. Path: src/lib/op/call/LibOpCall.sol

## External: Informational

- [PENDING] I01: (INFO) Dead code: MalformedHexLiteral error is unreachable after boundHex filtering. Path: src/lib/parse/literal/LibParseLiteralHex.sol. Status in report: Acknowledged
- [PENDING] I02: (INFO) Unused ParseState parameter in boundHex. Path: src/lib/parse/literal/LibParseLiteralHex.sol. Status in report: Acknowledged
- [PENDING] I03: (INFO) Misleading documentation comment regarding non-ASCII characters — behavior is actually deterministic revert, not undefined. Path: src/lib/parse/literal/LibParseLiteralSubParseable.sol. Status in report: Fixed in 441e9b5b
- [PENDING] I04: (INFO) Missing explicit constants index bounds check in LibOpExtern.integrity(). Path: src/lib/op/00/LibOpExtern.sol
- [PENDING] I05: (INFO) Architectural fragility: hardcoded InterpreterState memory layout — mload(state) assumes stackBottoms is first struct field. Path: src/lib/op/00/LibOpStack.sol
- [PENDING] I06: (INFO) Float identity testing relies on implicit referenceFn() divergence in EVM block opcodes. Path: src/lib/op/evm/LibOpBlockNumber.sol, LibOpBlockTimestamp.sol, LibOpChainId.sol
- [PENDING] I07: (INFO) Asymmetry between integrity() and run() bounds in variable-length logic opcodes — min-input clamp not duplicated in run(). Path: src/lib/op/logic/LibOpAny.sol, LibOpEvery.sol, LibOpConditions.sol
- [PENDING] I08: (INFO) Missing internal enforcement of memory bounds in parser — checkParseMemoryOverflow() never called by LibParse.parse(). Path: src/lib/parse/LibParse.sol, src/lib/parse/LibParseState.sol
