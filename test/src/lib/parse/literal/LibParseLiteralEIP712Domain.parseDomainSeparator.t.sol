// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.7.0/utils/cryptography/MessageHashUtils.sol";
import {Strings} from "@openzeppelin-contracts-5.7.0/utils/Strings.sol";
import {LibBytes, Pointer} from "rain-solmem-0.1.28/src/lib/LibBytes.sol";
import {LibConformString} from "rain-string-0.3.9/src/lib/mut/LibConformString.sol";
import {
    CMASK_QUOTATION_MARK,
    CMASK_RIGHT_SQUARE_BRACKET,
    CMASK_STRING_LITERAL_TAIL
} from "rain-string-0.3.9/src/lib/parse/LibParseCMask.sol";
import {
    ParseDecimalPrecisionLoss,
    MalformedExponentDigits,
    MalformedDecimalPoint
} from "rain-math-float-0.3.11/src/error/ErrParse.sol";
import {
    ExponentOverflow,
    FixedDecimalOverflow,
    LossyConversionToFloat
} from "rain-math-float-0.3.11/src/error/ErrDecimalFloat.sol";
import {ParseState, LibParseState} from "../../../../../src/lib/parse/LibParseState.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";
import {
    LibParseLiteralEIP712Domain,
    EIP712_DOMAIN_KEYWORD_NAME,
    EIP712_DOMAIN_KEYWORD_VERSION,
    EIP712_DOMAIN_KEYWORD_CHAIN_ID,
    EIP712_DOMAIN_KEYWORD_VERIFYING_CONTRACT,
    EIP712_DOMAIN_KEYWORD_SALT,
    EIP712_DOMAIN_CHAIN_ID_CURRENT,
    EIP712_DOMAIN_VERIFYING_CONTRACT_HEX_DIGITS,
    EIP712_DOMAIN_SALT_HEX_DIGITS,
    CMASK_EIP712_DOMAIN_TOKEN,
    EIP712_DOMAIN_FIELD_NAME,
    EIP712_DOMAIN_FIELD_VERSION,
    EIP712_DOMAIN_FIELD_CHAIN_ID,
    EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT,
    EIP712_DOMAIN_FIELD_SALT
} from "../../../../../src/lib/parse/literal/LibParseLiteralEIP712Domain.sol";
import {
    UnknownEIP712DomainField,
    EIP712DomainFieldOutOfOrder,
    MalformedEIP712DomainValue,
    EIP712DomainNoFields
} from "../../../../../src/error/ErrParse.sol";

/// @dev Fuzzed `EIP712Domain` field values.
struct DomainValues {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
    bytes32 salt;
}

/// @dev Fuzzed body layout: whitespace and address spelling.
struct DomainLayout {
    string separator;
    string leading;
    string trailing;
    bool checksumAddress;
}

/// @dev The `{name: "prices", version: "1"}` separator st0x signs prices under.
bytes32 constant PRICES_V1_DOMAIN_SEPARATOR = 0x7fcea108f1d99ecebbc296ddbd0cb92b55c1f11c5124d455748e1d8a4345a5b3;

uint256 constant FIELD_COUNT = EIP712_DOMAIN_FIELD_SALT + 1;

contract LibParseLiteralEIP712DomainParseDomainSeparatorTest is Test {
    using LibBytes for bytes;

    /// @dev Any body char that can be part of a field keyword token.
    uint256 constant TOKEN_MASK = CMASK_EIP712_DOMAIN_TOKEN & ~CMASK_RIGHT_SQUARE_BRACKET;

    function openZeppelinSeparator(
        bytes1 fields,
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract,
        bytes32 salt
    ) internal pure returns (bytes32) {
        return MessageHashUtils.toDomainSeparator(fields, name, version, chainId, verifyingContract, salt);
    }

    function chainIdSeparator(uint256 chainId) internal pure returns (bytes32) {
        return openZeppelinSeparator(bytes1(0x04), "", "", chainId, address(0), 0);
    }

    function parseDomainSeparatorExternal(bytes memory body) external view returns (bytes32) {
        ParseState memory state = LibParseState.newState(body, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        return LibParseLiteralEIP712Domain.parseDomainSeparator(state, cursor, cursor + body.length);
    }

    function checkRevert(bytes memory body, bytes memory err) internal {
        vm.expectRevert(err);
        this.parseDomainSeparatorExternal(body);
    }

    function checkRefusal(bytes memory body, bytes4 selector, uint256 offset) internal {
        checkRevert(body, abi.encodeWithSelector(selector, LibParseError.tagErrorOffset(offset)));
    }

    function keyword(uint256 field) internal pure returns (bytes memory) {
        if (field == EIP712_DOMAIN_FIELD_NAME) return EIP712_DOMAIN_KEYWORD_NAME;
        if (field == EIP712_DOMAIN_FIELD_VERSION) return EIP712_DOMAIN_KEYWORD_VERSION;
        if (field == EIP712_DOMAIN_FIELD_CHAIN_ID) return EIP712_DOMAIN_KEYWORD_CHAIN_ID;
        if (field == EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT) return EIP712_DOMAIN_KEYWORD_VERIFYING_CONTRACT;
        return EIP712_DOMAIN_KEYWORD_SALT;
    }

    function quote(bytes memory value) internal pure returns (bytes memory) {
        return bytes.concat("\"", value, "\"");
    }

    function conformWhitespace(string memory str, bool nonEmpty) internal pure returns (bytes memory) {
        LibConformString.conformStringToWhitespace(str);
        if (nonEmpty && bytes(str).length == 0) {
            return " ";
        }
        return bytes(str);
    }

    function int224Max() internal pure returns (uint256) {
        return uint256(int256(type(int224).max));
    }

    /// The body text of every field in `mask`, in canonical order.
    function domainBody(uint256 mask, bytes[FIELD_COUNT] memory values, bytes memory separator)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory body;
        for (uint256 field = EIP712_DOMAIN_FIELD_NAME; field < FIELD_COUNT; field++) {
            //forge-lint: disable-next-line(incorrect-shift)
            if (mask & (1 << field) == 0) continue;
            if (body.length > 0) {
                body = bytes.concat(body, separator);
            }
            body = bytes.concat(body, keyword(field), separator, values[field]);
        }
        return body;
    }

    function validValues() internal pure returns (bytes[FIELD_COUNT] memory) {
        bytes[FIELD_COUNT] memory values;
        values[EIP712_DOMAIN_FIELD_NAME] = "\"x\"";
        values[EIP712_DOMAIN_FIELD_VERSION] = "\"x\"";
        values[EIP712_DOMAIN_FIELD_CHAIN_ID] = "1";
        values[EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT] = "0x0000000000000000000000000000000000000000";
        values[EIP712_DOMAIN_FIELD_SALT] = "0x0000000000000000000000000000000000000000000000000000000000000000";
        return values;
    }

    /// Every one of the 31 non-empty field masks hashes to OpenZeppelin's
    /// separator for the same mask and values, for any Rainlang string
    /// contents, address case and whitespace between, before and after the
    /// fields.
    function testDomainSeparatorEveryMaskMatchesOpenZeppelin(DomainValues memory values, DomainLayout memory layout)
        external
        view
    {
        LibConformString.conformStringToMask(values.name, CMASK_STRING_LITERAL_TAIL);
        LibConformString.conformStringToMask(values.version, CMASK_STRING_LITERAL_TAIL);
        values.chainId = bound(values.chainId, 0, int224Max());
        bytes memory separator = conformWhitespace(layout.separator, true);
        bytes memory leading = conformWhitespace(layout.leading, false);
        bytes memory trailing = conformWhitespace(layout.trailing, false);

        bytes[FIELD_COUNT] memory spelled;
        spelled[EIP712_DOMAIN_FIELD_NAME] = quote(bytes(values.name));
        spelled[EIP712_DOMAIN_FIELD_VERSION] = quote(bytes(values.version));
        spelled[EIP712_DOMAIN_FIELD_CHAIN_ID] = bytes(vm.toString(values.chainId));
        spelled[EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT] = bytes(
            layout.checksumAddress
                ? vm.toString(values.verifyingContract)
                : Strings.toHexString(values.verifyingContract)
        );
        spelled[EIP712_DOMAIN_FIELD_SALT] = bytes(vm.toString(values.salt));

        for (uint256 mask = 1; mask < 2 ** FIELD_COUNT; mask++) {
            bytes memory body = bytes.concat(leading, domainBody(mask, spelled, separator), trailing);
            assertEq(
                this.parseDomainSeparatorExternal(body),
                openZeppelinSeparator(
                    //forge-lint: disable-next-line(unsafe-typecast)
                    bytes1(uint8(mask)),
                    values.name,
                    values.version,
                    values.chainId,
                    values.verifyingContract,
                    values.salt
                ),
                string(body)
            );
        }
    }

    /// Every non-empty mask writes nothing past the memory it allocates.
    function testDomainSeparatorWritesInsideItsAllocation() external view {
        bytes[FIELD_COUNT] memory values = validValues();
        for (uint256 mask = 1; mask < 2 ** FIELD_COUNT; mask++) {
            bytes memory body = domainBody(mask, values, " ");
            ParseState memory state = LibParseState.newState(body, "", "", "");
            uint256 cursor = Pointer.unwrap(body.dataPointer());
            uint256 sentinelEnd;
            assembly ("memory-safe") {
                let start := mload(0x40)
                sentinelEnd := add(start, 0x400)
                for { let p := start } lt(p, sentinelEnd) { p := add(p, 0x20) } { mstore(p, not(0)) }
            }
            LibParseLiteralEIP712Domain.parseDomainSeparator(state, cursor, cursor + body.length);
            bool writtenPastAllocation;
            assembly ("memory-safe") {
                for { let p := mload(0x40) } lt(p, sentinelEnd) { p := add(p, 0x20) } {
                    if iszero(eq(mload(p), not(0))) { writtenPastAllocation := 1 }
                }
            }
            assertFalse(writtenPastAllocation, string(body));
        }
    }

    /// Every non-empty mask with `chain-id current` uses the parsing chain's
    /// id, whether `current` ends the body or whitespace and a later field
    /// follow it.
    function testDomainSeparatorChainIdCurrentIsBlockChainId(
        uint64 chainId,
        address verifyingContract,
        bytes32 salt,
        string memory separator,
        string memory trailing
    ) external {
        vm.chainId(chainId);
        bytes memory sep = conformWhitespace(separator, true);
        bytes memory trail = conformWhitespace(trailing, false);
        bytes[FIELD_COUNT] memory spelled;
        spelled[EIP712_DOMAIN_FIELD_NAME] = "\"prices\"";
        spelled[EIP712_DOMAIN_FIELD_VERSION] = "\"1\"";
        spelled[EIP712_DOMAIN_FIELD_CHAIN_ID] = EIP712_DOMAIN_CHAIN_ID_CURRENT;
        spelled[EIP712_DOMAIN_FIELD_VERIFYING_CONTRACT] = bytes(vm.toString(verifyingContract));
        spelled[EIP712_DOMAIN_FIELD_SALT] = bytes(vm.toString(salt));
        for (uint256 mask = 2 ** EIP712_DOMAIN_FIELD_CHAIN_ID; mask < 2 ** FIELD_COUNT; mask++) {
            if (mask & 2 ** EIP712_DOMAIN_FIELD_CHAIN_ID == 0) continue;
            bytes memory body = bytes.concat(domainBody(mask, spelled, sep), trail);
            assertEq(
                this.parseDomainSeparatorExternal(body),
                //forge-lint: disable-next-line(unsafe-typecast)
                openZeppelinSeparator(bytes1(uint8(mask)), "prices", "1", chainId, verifyingContract, salt),
                string(body)
            );
        }
    }

    /// An explicit `chain-id` is that value, not the parsing chain's.
    function testDomainSeparatorExplicitChainIdIgnoresBlockChainId(uint64 blockChainId, uint256 chainId) external {
        vm.chainId(blockChainId);
        chainId = bound(chainId, 0, int224Max());
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("chain-id ", bytes(vm.toString(chainId)))),
            chainIdSeparator(chainId)
        );
    }

    /// Every decimal literal spelling of `coefficient * 10^exponent` is that
    /// integer, up to the largest that fits uint256.
    function testDomainSeparatorChainIdDecimalForms(uint256 coefficient, uint256 exponent) external view {
        exponent = bound(exponent, 0, 77);
        uint256 maxCoefficient = type(uint256).max / 10 ** exponent;
        coefficient = bound(coefficient, 0, maxCoefficient < int224Max() ? maxCoefficient : int224Max());
        bytes32 expected = chainIdSeparator(coefficient * 10 ** exponent);
        bytes memory c = bytes(vm.toString(coefficient));
        bytes memory e = bytes(vm.toString(exponent));
        bytes memory eMinusOne = exponent == 0 ? bytes("-1") : bytes(vm.toString(exponent - 1));
        bytes[7] memory forms = [
            bytes(vm.toString(coefficient * 10 ** exponent)),
            bytes.concat(c, "e", e),
            bytes.concat(c, "E", e),
            bytes.concat(c, "e+", e),
            bytes.concat("00", c, "e", e),
            bytes.concat(c, ".0e", e),
            bytes.concat(c, "0e", eMinusOne)
        ];
        for (uint256 i = 0; i < forms.length; i++) {
            bytes memory body = bytes.concat("chain-id ", forms[i]);
            assertEq(this.parseDomainSeparatorExternal(body), expected, string(body));
        }
    }

    /// Known decimal literals: plain, e-notation, zeros, integer-valued
    /// fractions, and the largest spellable values.
    function testDomainSeparatorChainIdKnownDecimals() external view {
        assertEq(this.parseDomainSeparatorExternal("chain-id 137"), chainIdSeparator(137));
        assertEq(this.parseDomainSeparatorExternal("chain-id 1e3"), chainIdSeparator(1000));
        assertEq(this.parseDomainSeparatorExternal("chain-id 1E3"), chainIdSeparator(1000));
        assertEq(this.parseDomainSeparatorExternal("chain-id 1e+3"), chainIdSeparator(1000));
        assertEq(this.parseDomainSeparatorExternal("chain-id 0"), chainIdSeparator(0));
        assertEq(this.parseDomainSeparatorExternal("chain-id 000"), chainIdSeparator(0));
        assertEq(this.parseDomainSeparatorExternal("chain-id 0.0"), chainIdSeparator(0));
        assertEq(this.parseDomainSeparatorExternal("chain-id 0e-5"), chainIdSeparator(0));
        assertEq(this.parseDomainSeparatorExternal("chain-id 007"), chainIdSeparator(7));
        assertEq(this.parseDomainSeparatorExternal("chain-id 1.0"), chainIdSeparator(1));
        assertEq(this.parseDomainSeparatorExternal("chain-id 10e-1"), chainIdSeparator(1));
        assertEq(this.parseDomainSeparatorExternal("chain-id 1.5e1"), chainIdSeparator(15));
        assertEq(this.parseDomainSeparatorExternal("chain-id 1e77"), chainIdSeparator(1e77));
        assertEq(this.parseDomainSeparatorExternal("chain-id 11e76"), chainIdSeparator(11e76));
        assertEq(
            this.parseDomainSeparatorExternal(
                "chain-id 13479973333575319897333507543509815336818572211270286240551805124607"
            ),
            chainIdSeparator(int224Max())
        );
        assertEq(
            this.parseDomainSeparatorExternal(
                "chain-id 11579208923731619542357098500868790785326998466564056403945758400791e10"
            ),
            chainIdSeparator(type(uint256).max / 1e10 * 1e10)
        );
    }

    /// A decimal literal with a non-zero fraction refuses at its start.
    function testDomainSeparatorChainIdFractionRefuses(uint256 coefficient, uint256 shift) external {
        shift = bound(shift, 1, 77);
        coefficient = bound(coefficient, 1, int224Max());
        vm.assume(coefficient % 10 ** shift != 0);
        checkRefusal(
            bytes.concat("chain-id ", bytes(vm.toString(coefficient)), "e-", bytes(vm.toString(shift))),
            MalformedEIP712DomainValue.selector,
            9
        );
    }

    /// Known fractions, including after other fields.
    function testDomainSeparatorChainIdFractionKnown() external {
        checkRefusal("chain-id 1.5", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id 0.5", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id 1.01", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id 1e-1", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id 15e-1", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id 1e-100", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("name \"x\" version \"1\" chain-id 1.5", MalformedEIP712DomainValue.selector, 30);
    }

    /// A chain id too large for uint256 or not exactly a Float reverts the
    /// decimal float library's own error.
    function testDomainSeparatorChainIdOutOfRangeRefuses() external {
        checkRevert("chain-id 1e78", abi.encodeWithSelector(FixedDecimalOverflow.selector, int256(1), int256(78), 0));
        checkRevert("chain-id 12e76", abi.encodeWithSelector(FixedDecimalOverflow.selector, int256(12), int256(76), 0));
        checkRevert(
            "chain-id 11579208923731619542357098500868790785326998466564056403945758400792e10",
            abi.encodeWithSelector(
                FixedDecimalOverflow.selector,
                int256(11579208923731619542357098500868790785326998466564056403945758400792),
                int256(10),
                0
            )
        );
        checkRefusal(
            "chain-id 115792089237316195423570985008687907853269984665640564039457584007913129639935",
            ParseDecimalPrecisionLoss.selector,
            87
        );
        checkRevert(
            "chain-id 13479973333575319897333507543509815336818572211270286240551805124608",
            abi.encodeWithSelector(LossyConversionToFloat.selector, int256(1 << 223), int256(0))
        );
        checkRevert(
            "chain-id 1e-9999999999",
            abi.encodeWithSelector(LossyConversionToFloat.selector, int256(1), int256(-9999999999))
        );
        checkRefusal("chain-id 1e9999999999", ExponentOverflow.selector, 21);
    }

    /// A malformed decimal literal reverts the decimal parser's own error;
    /// chars straight after a decimal literal refuse where they start.
    function testDomainSeparatorChainIdMalformedDecimalRefuses() external {
        checkRefusal("chain-id 1.", MalformedDecimalPoint.selector, 11);
        checkRefusal("chain-id 1.e3", MalformedDecimalPoint.selector, 11);
        checkRefusal("chain-id 1e", MalformedExponentDigits.selector, 11);
        checkRefusal("chain-id 1e-", MalformedExponentDigits.selector, 12);
        checkRefusal("chain-id 1e+", MalformedExponentDigits.selector, 12);
        checkRefusal("chain-id 1a", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("chain-id 0x01", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("chain-id 1\"", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("chain-id 1-", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("chain-id 1e3x", MalformedEIP712DomainValue.selector, 12);
    }

    /// A `chain-id` value that does not start with a digit and is not
    /// exactly `current` refuses at its start.
    function testDomainSeparatorChainIdNonDigitNonCurrentRefuses(string memory token) external {
        LibConformString.conformStringToMask(token, TOKEN_MASK);
        if (bytes(token).length == 0) {
            token = "x";
        }
        if (bytes(token)[0] >= "0" && bytes(token)[0] <= "9") {
            bytes(token)[0] = "x";
        }
        vm.assume(keccak256(bytes(token)) != keccak256(EIP712_DOMAIN_CHAIN_ID_CURRENT));
        checkRefusal(bytes.concat("chain-id ", bytes(token)), MalformedEIP712DomainValue.selector, 9);
        checkRefusal(
            bytes.concat("name \"x\" chain-id ", bytes(token), " ", validValues()[EIP712_DOMAIN_FIELD_SALT]),
            MalformedEIP712DomainValue.selector,
            18
        );
    }

    /// `chain-id` followed by a field keyword refuses at that keyword, with
    /// or without the keyword's own value after it.
    function testDomainSeparatorChainIdKeywordAsValueRefuses() external {
        bytes[FIELD_COUNT] memory values = validValues();
        for (uint256 field = EIP712_DOMAIN_FIELD_NAME; field < FIELD_COUNT; field++) {
            checkRefusal(bytes.concat("chain-id ", keyword(field)), MalformedEIP712DomainValue.selector, 9);
            checkRefusal(
                bytes.concat("chain-id ", keyword(field), " ", values[field]), MalformedEIP712DomainValue.selector, 9
            );
            checkRefusal(
                bytes.concat("name \"x\" chain-id ", keyword(field), " ", values[field]),
                MalformedEIP712DomainValue.selector,
                18
            );
        }
    }

    /// A bare `chain-id`, near misses of `current`, and negative, quoted or
    /// dotted numbers refuse at the value offset; `current` is the whole
    /// value, so a token after it is the next field keyword.
    function testDomainSeparatorChainIdNotCurrentKnown() external {
        checkRefusal("chain-id", MalformedEIP712DomainValue.selector, 8);
        checkRefusal("chain-id \t\n", MalformedEIP712DomainValue.selector, 11);
        checkRefusal("name \"x\" chain-id", MalformedEIP712DomainValue.selector, 17);
        checkRefusal("chain-id currentx", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id Current", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id current\"", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id CURRENT", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id curren", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id current1", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id current-id", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id \"current\"", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id -1", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id \"1\"", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id .5", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chain-id current current", UnknownEIP712DomainField.selector, 17);
        checkRefusal("chain-id current 1", UnknownEIP712DomainField.selector, 17);
        checkRefusal("chain-id 1 2", UnknownEIP712DomainField.selector, 11);
    }

    /// The st0x price domain.
    function testDomainSeparatorPricesV1() external view {
        assertEq(this.parseDomainSeparatorExternal("name \"prices\" version \"1\""), PRICES_V1_DOMAIN_SEPARATOR);
    }

    /// Quotes carry spaces, the empty string, every Rainlang string char and
    /// more than 31 bytes.
    function testDomainSeparatorStringContentsKnown() external view {
        assertEq(
            this.parseDomainSeparatorExternal("name \"two words\" version \"\""),
            openZeppelinSeparator(bytes1(0x03), "two words", "", 0, address(0), 0)
        );
        bytes memory everyChar;
        for (uint256 char = 0x20; char < 0x7f; char++) {
            if (char == 0x22) continue;
            //forge-lint: disable-next-line(unsafe-typecast)
            everyChar = bytes.concat(everyChar, bytes1(uint8(char)));
        }
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("name ", quote(everyChar))),
            openZeppelinSeparator(bytes1(0x01), string(everyChar), "", 0, address(0), 0)
        );
    }

    /// A string value that does not start with `"` refuses at its start.
    function testDomainSeparatorUnquotedStringRefuses(string memory token, bool isVersion) external {
        LibConformString.conformStringToMask(token, TOKEN_MASK);
        if (bytes(token).length == 0) {
            token = "x";
        }
        if (bytes(token)[0] == "\"") {
            bytes(token)[0] = "x";
        }
        bytes memory field = bytes.concat(isVersion ? EIP712_DOMAIN_KEYWORD_VERSION : EIP712_DOMAIN_KEYWORD_NAME, " ");
        checkRefusal(bytes.concat(field, bytes(token)), MalformedEIP712DomainValue.selector, field.length);
        checkRefusal(bytes.concat("name \"x\" version ", bytes(token)), MalformedEIP712DomainValue.selector, 17);
    }

    /// Unquoted `prices` and `1` are not strings.
    function testDomainSeparatorUnquotedStringKnown() external {
        checkRefusal("name prices version \"1\"", MalformedEIP712DomainValue.selector, 5);
        checkRefusal("name \"prices\" version 1", MalformedEIP712DomainValue.selector, 22);
        checkRefusal("name 'prices'", MalformedEIP712DomainValue.selector, 5);
    }

    /// A char that is not a Rainlang string char, such as whitespace other
    /// than a space, ends the string where it is and refuses there.
    function testDomainSeparatorStringNonStringCharRefuses(uint256 index) external {
        index = bound(index, 0, 160);
        uint256 char = index < 0x20 ? index : index == 0x20 ? 0x7f : index - 0x21 + 0x80;
        //forge-lint: disable-next-line(incorrect-shift)
        assertEq((1 << char) & (CMASK_STRING_LITERAL_TAIL | CMASK_QUOTATION_MARK), 0);
        checkRefusal(
            //forge-lint: disable-next-line(unsafe-typecast)
            bytes.concat("name \"a", bytes1(uint8(char)), "b\""),
            MalformedEIP712DomainValue.selector,
            7
        );
    }

    /// After `name` and `version` the next token is the value even when it
    /// is a field keyword: quoted it is that string, unquoted it refuses at
    /// its start.
    function testDomainSeparatorKeywordAsStringValue(uint256 field) external {
        field = bound(field, EIP712_DOMAIN_FIELD_NAME, EIP712_DOMAIN_FIELD_SALT);
        bytes memory value = quote(keyword(field));
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("name ", value)),
            openZeppelinSeparator(bytes1(0x01), string(keyword(field)), "", 0, address(0), 0)
        );
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("version ", value)),
            openZeppelinSeparator(bytes1(0x02), "", string(keyword(field)), 0, address(0), 0)
        );
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("name ", value, " version ", value, " chain-id current")),
            openZeppelinSeparator(
                bytes1(0x07), string(keyword(field)), string(keyword(field)), block.chainid, address(0), 0
            )
        );
        checkRefusal(bytes.concat("name ", keyword(field)), MalformedEIP712DomainValue.selector, 5);
        checkRefusal(bytes.concat("version ", keyword(field)), MalformedEIP712DomainValue.selector, 8);
    }

    /// After `verifying-contract` and `salt` a field keyword is a malformed
    /// value at its offset.
    function testDomainSeparatorKeywordAsHexValueRefuses(uint256 field) external {
        field = bound(field, EIP712_DOMAIN_FIELD_NAME, EIP712_DOMAIN_FIELD_SALT);
        checkRefusal(bytes.concat("verifying-contract ", keyword(field)), MalformedEIP712DomainValue.selector, 19);
        checkRefusal(bytes.concat("salt ", keyword(field)), MalformedEIP712DomainValue.selector, 5);
    }

    /// A field with no value refuses at the body end.
    function testDomainSeparatorValuelessFieldRefuses(uint256 field, string memory trailing) external {
        field = bound(field, EIP712_DOMAIN_FIELD_NAME, EIP712_DOMAIN_FIELD_SALT);
        bytes memory body = bytes.concat(keyword(field), conformWhitespace(trailing, false));
        checkRefusal(body, MalformedEIP712DomainValue.selector, body.length);
        body = bytes.concat("name \"x\" ", body);
        if (field == EIP712_DOMAIN_FIELD_NAME) {
            checkRefusal(body, EIP712DomainFieldOutOfOrder.selector, 9);
        } else {
            checkRefusal(body, MalformedEIP712DomainValue.selector, body.length);
        }
    }

    /// An empty or whitespace-only body refuses at its end.
    function testDomainSeparatorNoFieldsRefuses(string memory whitespace) external {
        bytes memory body = conformWhitespace(whitespace, false);
        checkRefusal(body, EIP712DomainNoFields.selector, body.length);
    }

    /// A token that is not exactly a field keyword refuses at its start.
    function testDomainSeparatorUnknownFieldRefuses(string memory token, string memory leading) external {
        LibConformString.conformStringToMask(token, TOKEN_MASK);
        if (bytes(token).length == 0) {
            token = "x";
        }
        for (uint256 field = EIP712_DOMAIN_FIELD_NAME; field < FIELD_COUNT; field++) {
            vm.assume(keccak256(bytes(token)) != keccak256(keyword(field)));
        }
        bytes memory lead = conformWhitespace(leading, false);
        checkRefusal(bytes.concat(lead, bytes(token), " \"x\""), UnknownEIP712DomainField.selector, lead.length);
        checkRefusal(bytes.concat("name \"x\" ", bytes(token)), UnknownEIP712DomainField.selector, 9);
    }

    /// camelCase and other near misses of the keywords, `=` syntax and a
    /// quoted keyword.
    function testDomainSeparatorUnknownFieldKnown() external {
        checkRefusal("chainId 1", UnknownEIP712DomainField.selector, 0);
        checkRefusal("chainId", UnknownEIP712DomainField.selector, 0);
        checkRefusal(
            "verifyingContract 0x0000000000000000000000000000000000000000", UnknownEIP712DomainField.selector, 0
        );
        checkRefusal("chain_id 1", UnknownEIP712DomainField.selector, 0);
        checkRefusal("chainid 1", UnknownEIP712DomainField.selector, 0);
        checkRefusal("Chain-id 1", UnknownEIP712DomainField.selector, 0);
        checkRefusal("chain-ID 1", UnknownEIP712DomainField.selector, 0);
        checkRefusal("chain-id-1", UnknownEIP712DomainField.selector, 0);
        checkRefusal(
            "verifying_contract 0x0000000000000000000000000000000000000000", UnknownEIP712DomainField.selector, 0
        );
        checkRefusal("name=\"prices\"", UnknownEIP712DomainField.selector, 0);
        checkRefusal("Name \"prices\"", UnknownEIP712DomainField.selector, 0);
        checkRefusal("names \"x\"", UnknownEIP712DomainField.selector, 0);
        checkRefusal("\"name\" \"x\"", UnknownEIP712DomainField.selector, 0);
        checkRefusal("name\"x\"", UnknownEIP712DomainField.selector, 0);
    }

    /// Every repeated or out of order pair refuses at the second keyword.
    function testDomainSeparatorFieldOutOfOrderRefuses() external {
        bytes[FIELD_COUNT] memory values = validValues();
        for (uint256 first = EIP712_DOMAIN_FIELD_NAME; first < FIELD_COUNT; first++) {
            for (uint256 second = EIP712_DOMAIN_FIELD_NAME; second <= first; second++) {
                bytes memory head = bytes.concat(keyword(first), " ", values[first], " ");
                checkRefusal(
                    bytes.concat(head, keyword(second), " ", values[second]),
                    EIP712DomainFieldOutOfOrder.selector,
                    head.length
                );
            }
        }
        checkRefusal("chain-id current chain-id current", EIP712DomainFieldOutOfOrder.selector, 17);
    }

    /// Unterminated quotes refuse at the body end; chars straight after a
    /// string refuse where they start.
    function testDomainSeparatorMalformedStringRefuses() external {
        checkRefusal("name \"abc", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("name \"a b ", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("name \"", MalformedEIP712DomainValue.selector, 6);
        checkRefusal("name \"abc\"def", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("name \"abc\"\"", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("name \"a\"version \"1\"", MalformedEIP712DomainValue.selector, 8);
        checkRefusal("name \"a\tb\"", MalformedEIP712DomainValue.selector, 7);
        checkRefusal("name \"a\nb\"", MalformedEIP712DomainValue.selector, 7);
    }

    /// Hex values need `0x` and exactly 40 (address) or 64 (salt) digits;
    /// anything else refuses at the value start.
    function testDomainSeparatorHexDigitCountRefuses(uint256 digits) external {
        digits = bound(digits, 0, 2 * EIP712_DOMAIN_SALT_HEX_DIGITS);
        bytes memory hexDigits = new bytes(digits);
        for (uint256 i = 0; i < digits; i++) {
            hexDigits[i] = "a";
        }
        bytes memory value = bytes.concat("0x", hexDigits);
        if (digits != EIP712_DOMAIN_VERIFYING_CONTRACT_HEX_DIGITS) {
            checkRefusal(bytes.concat("verifying-contract ", value), MalformedEIP712DomainValue.selector, 19);
        }
        if (digits != EIP712_DOMAIN_SALT_HEX_DIGITS) {
            checkRefusal(bytes.concat("salt ", value), MalformedEIP712DomainValue.selector, 5);
        }
    }

    /// Missing or uppercase prefix, quotes, and trailing non-hex chars.
    function testDomainSeparatorMalformedHexKnown() external {
        checkRefusal("verifying-contract 0", MalformedEIP712DomainValue.selector, 19);
        checkRefusal(
            "verifying-contract 000000000000000000000000000000000000000000", MalformedEIP712DomainValue.selector, 19
        );
        checkRefusal(
            "verifying-contract 0X0000000000000000000000000000000000000000", MalformedEIP712DomainValue.selector, 19
        );
        checkRefusal(
            "verifying-contract \"0x0000000000000000000000000000000000000000\"", MalformedEIP712DomainValue.selector, 19
        );
        checkRefusal(
            "verifying-contract 0x0000000000000000000000000000000000000000g", MalformedEIP712DomainValue.selector, 61
        );
        checkRefusal(
            "salt 0x000000000000000000000000000000000000000000000000000000000000000g",
            MalformedEIP712DomainValue.selector,
            5
        );
        checkRefusal(
            "salt 0x0000000000000000000000000000000000000000000000000000000000000000x",
            MalformedEIP712DomainValue.selector,
            71
        );
    }

    /// Uppercase hex digits parse.
    function testDomainSeparatorUppercaseHexDigits() external view {
        bytes memory saltTail = "ABCDEF";
        bytes memory saltZeros = new bytes(EIP712_DOMAIN_SALT_HEX_DIGITS - saltTail.length);
        for (uint256 i = 0; i < saltZeros.length; i++) {
            saltZeros[i] = "0";
        }
        assertEq(
            this.parseDomainSeparatorExternal(
                bytes.concat(
                    "verifying-contract 0xABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCD salt 0x", saltZeros, saltTail
                )
            ),
            openZeppelinSeparator(
                bytes1(0x18),
                "",
                "",
                0,
                address(uint160(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD)),
                bytes32(uint256(0xABCDEF))
            )
        );
    }
}
