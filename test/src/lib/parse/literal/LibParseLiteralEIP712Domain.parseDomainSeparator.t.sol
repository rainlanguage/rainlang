// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.7.0/utils/cryptography/MessageHashUtils.sol";
import {Strings} from "@openzeppelin-contracts-5.7.0/utils/Strings.sol";
import {LibBytes, Pointer} from "rain-solmem-0.1.28/src/lib/LibBytes.sol";
import {LibConformString} from "rain-string-0.3.9/src/lib/mut/LibConformString.sol";
import {
    CMASK_PRINTABLE,
    CMASK_WHITESPACE,
    CMASK_QUOTATION_MARK,
    CMASK_RIGHT_SQUARE_BRACKET
} from "rain-string-0.3.9/src/lib/parse/LibParseCMask.sol";
import {ParseState, LibParseState} from "../../../../../src/lib/parse/LibParseState.sol";
import {LibParseError} from "../../../../../src/lib/parse/LibParseError.sol";
import {LibParseLiteralEIP712Domain} from "../../../../../src/lib/parse/literal/LibParseLiteralEIP712Domain.sol";
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

/// @dev Fuzzed body layout: whitespace and value spellings.
struct DomainLayout {
    string separator;
    string leading;
    string trailing;
    bool quoteName;
    bool quoteVersion;
    bool checksumAddress;
}

/// @dev The `{name: "prices", version: "1"}` separator st0x signs prices under.
bytes32 constant PRICES_V1_DOMAIN_SEPARATOR = 0x7fcea108f1d99ecebbc296ddbd0cb92b55c1f11c5124d455748e1d8a4345a5b3;

contract LibParseLiteralEIP712DomainParseDomainSeparatorTest is Test {
    using LibBytes for bytes;

    /// @dev Any body char that can sit between `"` quotes.
    uint256 constant QUOTED_CONTENT_MASK =
        (CMASK_PRINTABLE | CMASK_WHITESPACE) & ~CMASK_QUOTATION_MARK & ~CMASK_RIGHT_SQUARE_BRACKET;
    /// @dev Any body char that can be part of an unquoted token.
    uint256 constant TOKEN_MASK = CMASK_PRINTABLE & ~CMASK_WHITESPACE & ~CMASK_RIGHT_SQUARE_BRACKET;

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

    function parseDomainSeparatorExternal(bytes memory body) external view returns (bytes32) {
        ParseState memory state = LibParseState.newState(body, "", "", "");
        uint256 cursor = Pointer.unwrap(state.data.dataPointer());
        return LibParseLiteralEIP712Domain.parseDomainSeparator(state, cursor, cursor + body.length);
    }

    function checkRefusal(bytes memory body, bytes4 selector, uint256 offset) internal {
        vm.expectRevert(abi.encodeWithSelector(selector, LibParseError.tagErrorOffset(offset)));
        this.parseDomainSeparatorExternal(body);
    }

    function keyword(uint256 field) internal pure returns (bytes memory) {
        if (field == 0) return "name";
        if (field == 1) return "version";
        if (field == 2) return "chainId";
        if (field == 3) return "verifyingContract";
        return "salt";
    }

    /// Conforms `str` to a string value the body can spell quoted or unquoted.
    function conformStringValue(string memory str, bool quoted) internal pure returns (string memory) {
        if (quoted) {
            LibConformString.conformStringToMask(str, QUOTED_CONTENT_MASK);
            return str;
        }
        if (bytes(str).length == 0) {
            return "a";
        }
        LibConformString.conformStringToMask(str, TOKEN_MASK);
        if (bytes(str)[0] == "\"") {
            bytes(str)[0] = "'";
        }
        return str;
    }

    function conformWhitespace(string memory str, bool nonEmpty) internal pure returns (bytes memory) {
        LibConformString.conformStringToWhitespace(str);
        if (nonEmpty && bytes(str).length == 0) {
            return " ";
        }
        return bytes(str);
    }

    function spellString(string memory value, bool quoted) internal pure returns (bytes memory) {
        return quoted ? bytes.concat("\"", bytes(value), "\"") : bytes(value);
    }

    /// The body text of every field in `mask`, in canonical order. An empty
    /// value spells the field bare.
    function domainBody(uint256 mask, bytes[5] memory values, bytes memory separator)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory body;
        for (uint256 field = 0; field < 5; field++) {
            //forge-lint: disable-next-line(incorrect-shift)
            if (mask & (1 << field) == 0) continue;
            if (body.length > 0) {
                body = bytes.concat(body, separator);
            }
            body = bytes.concat(body, keyword(field));
            if (values[field].length > 0) {
                body = bytes.concat(body, separator, values[field]);
            }
        }
        return body;
    }

    /// Every one of the 31 non-empty field masks hashes to OpenZeppelin's
    /// separator for the same mask and values, for any quoting, address case
    /// and whitespace between, before and after the fields.
    function testDomainSeparatorEveryMaskMatchesOpenZeppelin(DomainValues memory values, DomainLayout memory layout)
        external
        view
    {
        values.name = conformStringValue(values.name, layout.quoteName);
        values.version = conformStringValue(values.version, layout.quoteVersion);
        bytes memory separator = conformWhitespace(layout.separator, true);
        bytes memory leading = conformWhitespace(layout.leading, false);
        bytes memory trailing = conformWhitespace(layout.trailing, false);

        bytes[5] memory spelled = [
            spellString(values.name, layout.quoteName),
            spellString(values.version, layout.quoteVersion),
            bytes(vm.toString(values.chainId)),
            bytes(
                layout.checksumAddress
                    ? vm.toString(values.verifyingContract)
                    : Strings.toHexString(values.verifyingContract)
            ),
            bytes(vm.toString(values.salt))
        ];

        for (uint256 mask = 1; mask < 32; mask++) {
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

    /// Every non-empty mask with a bare `chainId` uses the parsing chain's id,
    /// whether `chainId` ends the body or a later field keyword follows it.
    function testDomainSeparatorBareChainIdIsBlockChainId(uint64 chainId, address verifyingContract, bytes32 salt)
        external
    {
        vm.chainId(chainId);
        bytes[5] memory spelled =
            [bytes("prices"), bytes("1"), bytes(""), bytes(vm.toString(verifyingContract)), bytes(vm.toString(salt))];
        for (uint256 mask = 4; mask < 32; mask++) {
            if (mask & 4 == 0) continue;
            assertEq(
                this.parseDomainSeparatorExternal(domainBody(mask, spelled, " ")),
                //forge-lint: disable-next-line(unsafe-typecast)
                openZeppelinSeparator(bytes1(uint8(mask)), "prices", "1", chainId, verifyingContract, salt)
            );
        }
    }

    /// An explicit decimal `chainId` is that value, not the parsing chain's.
    function testDomainSeparatorExplicitChainIdIgnoresBlockChainId(uint64 blockChainId, uint256 chainId) external {
        vm.chainId(blockChainId);
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("chainId ", bytes(vm.toString(chainId)))),
            openZeppelinSeparator(bytes1(0x04), "", "", chainId, address(0), 0)
        );
    }

    /// Known decimal spellings: zero, leading zeros, the uint256 max.
    function testDomainSeparatorExplicitChainIdDecimals() external view {
        bytes32 zero = openZeppelinSeparator(bytes1(0x04), "", "", 0, address(0), 0);
        assertEq(this.parseDomainSeparatorExternal("chainId 0"), zero);
        assertEq(this.parseDomainSeparatorExternal("chainId 000"), zero);
        assertEq(
            this.parseDomainSeparatorExternal("chainId 007"),
            openZeppelinSeparator(bytes1(0x04), "", "", 7, address(0), 0)
        );
        assertEq(
            this.parseDomainSeparatorExternal(
                "chainId 115792089237316195423570985008687907853269984665640564039457584007913129639935"
            ),
            openZeppelinSeparator(bytes1(0x04), "", "", type(uint256).max, address(0), 0)
        );
    }

    /// The st0x price domain.
    function testDomainSeparatorPricesV1() external view {
        assertEq(this.parseDomainSeparatorExternal("name prices version 1"), PRICES_V1_DOMAIN_SEPARATOR);
        assertEq(this.parseDomainSeparatorExternal("name \"prices\" version \"1\""), PRICES_V1_DOMAIN_SEPARATOR);
    }

    /// An unquoted token without `"` and the same token quoted are the same
    /// value.
    function testDomainSeparatorQuotedEqualsUnquoted(string memory value) external view {
        vm.assume(bytes(value).length > 0);
        LibConformString.conformStringToMask(value, TOKEN_MASK & ~CMASK_QUOTATION_MARK);
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("name ", bytes(value), " version ", bytes(value))),
            this.parseDomainSeparatorExternal(
                bytes.concat("name \"", bytes(value), "\" version \"", bytes(value), "\"")
            )
        );
    }

    /// Quotes carry whitespace and the empty string; an unquoted token may
    /// hold a `"` after its first char.
    function testDomainSeparatorQuotedAndUnquotedKnown() external view {
        assertEq(
            this.parseDomainSeparatorExternal("name \"two words\" version \"\""),
            openZeppelinSeparator(bytes1(0x03), "two words", "", 0, address(0), 0)
        );
        assertEq(
            this.parseDomainSeparatorExternal("name \" \t\n\r\""),
            openZeppelinSeparator(bytes1(0x01), " \t\n\r", "", 0, address(0), 0)
        );
        assertEq(
            this.parseDomainSeparatorExternal("name a\"b\" version 1"),
            openZeppelinSeparator(bytes1(0x03), "a\"b\"", "1", 0, address(0), 0)
        );
    }

    /// After `name` and `version` the next token is the value even when it
    /// is a field keyword, quoted or not.
    function testDomainSeparatorKeywordAsStringValue(uint256 field, bool quoted) external view {
        field = bound(field, 0, 4);
        bytes memory value = spellString(string(keyword(field)), quoted);
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("name ", value)),
            openZeppelinSeparator(bytes1(0x01), string(keyword(field)), "", 0, address(0), 0)
        );
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("version ", value)),
            openZeppelinSeparator(bytes1(0x02), "", string(keyword(field)), 0, address(0), 0)
        );
        assertEq(
            this.parseDomainSeparatorExternal(bytes.concat("name ", value, " version ", value, " chainId")),
            openZeppelinSeparator(
                bytes1(0x07), string(keyword(field)), string(keyword(field)), block.chainid, address(0), 0
            )
        );
    }

    /// After `verifyingContract` and `salt` a field keyword is a malformed
    /// value at its offset.
    function testDomainSeparatorKeywordAsHexValueRefuses(uint256 field) external {
        field = bound(field, 0, 4);
        checkRefusal(bytes.concat("verifyingContract ", keyword(field)), MalformedEIP712DomainValue.selector, 18);
        checkRefusal(bytes.concat("salt ", keyword(field)), MalformedEIP712DomainValue.selector, 5);
    }

    /// A field other than `chainId` with no value refuses at the body end.
    function testDomainSeparatorValuelessFieldRefuses(uint256 field, string memory trailing) external {
        field = bound(field, 0, 4);
        vm.assume(field != 2);
        bytes memory body = bytes.concat(keyword(field), conformWhitespace(trailing, false));
        checkRefusal(body, MalformedEIP712DomainValue.selector, body.length);
        body = bytes.concat("name x ", body);
        if (field == 0) {
            checkRefusal(body, EIP712DomainFieldOutOfOrder.selector, 7);
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
        vm.assume(bytes(token).length > 0);
        for (uint256 field = 0; field < 5; field++) {
            vm.assume(keccak256(bytes(token)) != keccak256(keyword(field)));
        }
        bytes memory lead = conformWhitespace(leading, false);
        checkRefusal(bytes.concat(lead, bytes(token), " x"), UnknownEIP712DomainField.selector, lead.length);
        checkRefusal(bytes.concat("name x ", bytes(token)), UnknownEIP712DomainField.selector, 7);
    }

    /// Near misses of the keywords, `=` syntax, a quoted keyword, and a
    /// non-digit token after a bare `chainId`.
    function testDomainSeparatorUnknownFieldKnown() external {
        checkRefusal("name=prices", UnknownEIP712DomainField.selector, 0);
        checkRefusal("Name prices", UnknownEIP712DomainField.selector, 0);
        checkRefusal("chainid", UnknownEIP712DomainField.selector, 0);
        checkRefusal("names x", UnknownEIP712DomainField.selector, 0);
        checkRefusal("\"name\" x", UnknownEIP712DomainField.selector, 0);
        checkRefusal("name\"x\"", UnknownEIP712DomainField.selector, 0);
        checkRefusal("chainId foo", UnknownEIP712DomainField.selector, 8);
        checkRefusal("chainId \"1\"", UnknownEIP712DomainField.selector, 8);
        checkRefusal("chainId -1", UnknownEIP712DomainField.selector, 8);
        checkRefusal("chainId 1 2", UnknownEIP712DomainField.selector, 10);
    }

    /// Every repeated or out of order pair refuses at the second keyword.
    function testDomainSeparatorFieldOutOfOrderRefuses() external {
        bytes[5] memory values = [
            bytes("x"),
            bytes("x"),
            bytes("1"),
            bytes("0x0000000000000000000000000000000000000000"),
            bytes("0x0000000000000000000000000000000000000000000000000000000000000000")
        ];
        for (uint256 first = 0; first < 5; first++) {
            for (uint256 second = 0; second <= first; second++) {
                bytes memory head = bytes.concat(keyword(first), " ", values[first], " ");
                checkRefusal(
                    bytes.concat(head, keyword(second), " ", values[second]),
                    EIP712DomainFieldOutOfOrder.selector,
                    head.length
                );
            }
        }
        checkRefusal("chainId name x", EIP712DomainFieldOutOfOrder.selector, 8);
    }

    /// Unterminated quotes refuse at the body end; chars straight after a
    /// value refuse where they start.
    function testDomainSeparatorMalformedStringRefuses() external {
        checkRefusal("name \"abc", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("name \"a b ", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("name \"", MalformedEIP712DomainValue.selector, 6);
        checkRefusal("name \"abc\"def", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("name \"abc\"\"", MalformedEIP712DomainValue.selector, 10);
        checkRefusal("name \"a\"version 1", MalformedEIP712DomainValue.selector, 8);
    }

    /// Decimals refuse past uint256 max at their start and on trailing
    /// non-digits where those start.
    function testDomainSeparatorMalformedDecimalRefuses() external {
        checkRefusal(
            "chainId 115792089237316195423570985008687907853269984665640564039457584007913129639936",
            MalformedEIP712DomainValue.selector,
            8
        );
        checkRefusal(
            "chainId 1157920892373161954235709850086879078532699846656405640394575840079131296399350",
            MalformedEIP712DomainValue.selector,
            8
        );
        checkRefusal("chainId 1a", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chainId 0x01", MalformedEIP712DomainValue.selector, 9);
        checkRefusal("chainId 1\"", MalformedEIP712DomainValue.selector, 9);
    }

    /// Hex values need `0x` and exactly 40 (address) or 64 (salt) digits;
    /// anything else refuses at the value start.
    function testDomainSeparatorHexDigitCountRefuses(uint256 digits) external {
        digits = bound(digits, 0, 80);
        bytes memory hexDigits = new bytes(digits);
        for (uint256 i = 0; i < digits; i++) {
            hexDigits[i] = "a";
        }
        bytes memory value = bytes.concat("0x", hexDigits);
        if (digits != 40) {
            checkRefusal(bytes.concat("verifyingContract ", value), MalformedEIP712DomainValue.selector, 18);
        }
        if (digits != 64) {
            checkRefusal(bytes.concat("salt ", value), MalformedEIP712DomainValue.selector, 5);
        }
    }

    /// Missing or uppercase prefix, quotes, and trailing non-hex chars.
    function testDomainSeparatorMalformedHexKnown() external {
        checkRefusal("verifyingContract 0", MalformedEIP712DomainValue.selector, 18);
        checkRefusal(
            "verifyingContract 000000000000000000000000000000000000000000", MalformedEIP712DomainValue.selector, 18
        );
        checkRefusal(
            "verifyingContract 0X0000000000000000000000000000000000000000", MalformedEIP712DomainValue.selector, 18
        );
        checkRefusal(
            "verifyingContract \"0x0000000000000000000000000000000000000000\"", MalformedEIP712DomainValue.selector, 18
        );
        checkRefusal(
            "verifyingContract 0x0000000000000000000000000000000000000000g", MalformedEIP712DomainValue.selector, 60
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
        bytes memory saltZeros = new bytes(58);
        for (uint256 i = 0; i < 58; i++) {
            saltZeros[i] = "0";
        }
        assertEq(
            this.parseDomainSeparatorExternal(
                bytes.concat(
                    "verifyingContract 0xABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCD salt 0x", saltZeros, "ABCDEF"
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
