// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {DotrainBinding} from "../../src/interface/IParserDotrainV1.sol";

uint256 constant NAME_COUNT = 8;
uint256 constant KIND_ABSENT = 0;
uint256 constant KIND_NUMERIC = 1;
uint256 constant KIND_STRING = 2;
uint256 constant KIND_SUB_PARSER = 3;
uint256 constant KIND_ELIDED = 4;
uint256 constant KIND_EXPRESSION = 5;
uint256 constant KIND_COUNT = 6;

/// The dotrain inputs checked against `rain dotrain compose`, fixed and
/// generated, run through `checkCase`.
abstract contract DotrainComposeCasesTest is Test {
    struct Rng {
        uint256 state;
    }

    function checkCase(string memory dotrain, string memory entrypoint, DotrainBinding[] memory bound) internal virtual;

    function testFixedShape(bytes32 subParser, bytes32 signer, bytes32 x, bytes32 maxPrice, bool bindMaxPrice)
        external
    {
        string memory dotrain = "# License: LicenseRef-DCL-1.0\n" "# Front matter # with @ is dropped.\n" "---\n"
            "#sub-parser !Sub parser address.\n\n" "#signer !Signer.\n" "#source \"alpaca\"\n"
            "#x !A value also called as a word.\n" "#max-price 1000\n\n" "#helper _: 1;\n\n" "#weighting\n"
            "using-words-from sub-parser\n\n" "/* x signer */\n" ":ensure(\n" "  binary-equal-to(lead() signer)\n"
            "  \"x signer\"\n" "),\n\n" "_ _: x(x) x<0 0x1f>(max-price) [x signer],\n" "price: max-price;\n\n"
            "/* second source */\n" "_: source x;\n";
        DotrainBinding[] memory bound = new DotrainBinding[](bindMaxPrice ? 4 : 3);
        bound[0] = DotrainBinding("sub-parser", subParser);
        bound[1] = DotrainBinding("signer", signer);
        bound[2] = DotrainBinding("x", x);
        if (bindMaxPrice) bound[3] = DotrainBinding("max-price", maxPrice);
        checkCase(dotrain, "weighting", bound);
    }

    function testRepeatedBindingLastWins(bytes32 first, bytes32 last) external {
        DotrainBinding[] memory bound = new DotrainBinding[](2);
        bound[0] = DotrainBinding("x", first);
        bound[1] = DotrainBinding("x", last);
        checkCase("---\n#x 5\n#e\n_: x;", "e", bound);
    }

    function testCommentedLiteralBinding() external {
        checkCase(
            "---\n#x /* a */ 5 /* b */\n#y \"a /* c */ b\"\n#z [s /* d */ t]\n#e\n_ _ _: x y z;",
            "e",
            new DotrainBinding[](0)
        );
    }

    function testUnclosedCommentInFrontMatter() external {
        checkCase("/* a\n---\n#x 5\n#e\n_: x; /* b */", "e", new DotrainBinding[](0));
    }

    function testCommentClosesAtFirstStarSlash() external {
        checkCase("---\n#x 5\n#e\n/*/ a / x */\n_: x;", "e", new DotrainBinding[](0));
    }

    function testSlashOutsideComment() external {
        checkCase("---\n#y \"a/b\"\n#z [a/b]\n#e\n_ _: y z;", "e", new DotrainBinding[](0));
    }

    function testVerticalTabAndFormFeedTrim() external {
        checkCase("---\n#x \x0b5\x0c\n#y \x0c\"a\"\x0b\n#e\n_ _: x y;", "e", new DotrainBinding[](0));
    }

    function testVerticalTabAndFormFeedBeforeFirstBinding() external {
        checkCase("---\n\x0b#e _: 1;", "e", new DotrainBinding[](0));
        checkCase("---\n\x0c#e _: 1;", "e", new DotrainBinding[](0));
    }

    function testPragmaKeywordPrefixIsNotPragma() external {
        checkCase("---\n#x 5\n#e\nusing-words-fromx _: 1 2;", "e", new DotrainBinding[](0));
    }

    function testNumericWordTailIsNotABinding() external {
        checkCase("---\n#x1f 5\n#e18 6\n#e\n_ _ _ _: 0x1f x1f 1e18 e18;", "e", new DotrainBinding[](0));
    }

    function testVerticalTabEndsPragmaKeyword() external {
        checkCase("---\n#x 0x01\n#e using-words-from\x0bx\n_: 1;", "e", new DotrainBinding[](0));
    }

    function testVerticalTabBeforePragma() external {
        checkCase("---\n#x 0x01\n#e /* c */\x0busing-words-from x\n_: 1;", "e", new DotrainBinding[](0));
    }

    function testVerticalTabAndFormFeedSplitPragmaTokens() external {
        checkCase("---\n#x 0x01\n#e using-words-from 0x02\x0cx\n_: 1;", "e", new DotrainBinding[](0));
        checkCase("---\n#x 0x01\n#e using-words-from x\x0b0x02\n_: 1;", "e", new DotrainBinding[](0));
    }

    function testTrailingVerticalTabAndFormFeedEndWord() external {
        checkCase("---\n#x 0x01\n#e _: x\x0b;", "e", new DotrainBinding[](0));
        checkCase("---\n#x 0x01\n#e _: x\x0c, _: x;", "e", new DotrainBinding[](0));
        checkCase("---\n#x 0x01\n#e _: x\x0b \x0c;", "e", new DotrainBinding[](0));
        checkCase("---\n#x 0x01\n#e _ _: x 2\x0b;", "e", new DotrainBinding[](0));
    }

    function testOperandLiterals() external {
        checkCase("---\n#x 0x01\n#ab 2\n#e _: foo<0xab1f>(x);", "e", new DotrainBinding[](0));
        checkCase("---\n#x 0x01\n#e _: foo<12>(x);", "e", new DotrainBinding[](0));
        checkCase("---\n#x 0x01\n#e18 2\n#e _: foo<1e18>(x);", "e", new DotrainBinding[](0));
        checkCase("---\n#x 0x01\n#ab 2\n#e _: foo<\"x\" \"ab-c\">(x);", "e", new DotrainBinding[](0));
        checkCase("---\n#x 0x01\n#ab 2\n#e _: foo<[x] [ab]>(x);", "e", new DotrainBinding[](0));
        checkCase("---\n#e _: foo<0xABcd>();", "e", new DotrainBinding[](0));
        checkCase("---\n#e _: foo<1e18 \"a b\">();", "e", new DotrainBinding[](0));
        checkCase("---\n#e _: foo<[a b]>();", "e", new DotrainBinding[](0));
    }

    function testOperandArgWhitespace() external {
        checkCase("---\n#e _: foo< 1>();", "e", new DotrainBinding[](0));
        checkCase("---\n#e _: foo<1 >();", "e", new DotrainBinding[](0));
        checkCase("---\n#e _: foo<1\x0b2>();", "e", new DotrainBinding[](0));
    }

    function testOperandGroupArgsSpanWhitespace() external {
        checkCase("---\n#e _: foo<\" a\">();", "e", new DotrainBinding[](0));
        checkCase("---\n#e _: foo<[ a]>();", "e", new DotrainBinding[](0));
        checkCase("---\n#e _: foo<\"a b c\">();", "e", new DotrainBinding[](0));
        checkCase("---\n#e _: foo<[a b c]>();", "e", new DotrainBinding[](0));
        checkCase("---\n#e _: foo<\"\">();", "e", new DotrainBinding[](0));
    }

    function testGeneratedDotrain(uint256 seed) external {
        (string memory dotrain, DotrainBinding[] memory bound) = generate(seed);
        checkCase(dotrain, "weighting", bound);
    }

    function draw(Rng memory rng, uint256 n) internal pure returns (uint256) {
        rng.state = uint256(keccak256(abi.encode(rng.state)));
        return rng.state % n;
    }

    function pick(Rng memory rng, string[5] memory options) internal pure returns (string memory) {
        return options[draw(rng, 5)];
    }

    function bindingName(uint256 i) internal pure returns (string memory) {
        string[NAME_COUNT] memory names = [string("x"), "x-1", "add", "max", "max-price", "w2", "lead-signer", "e1"];
        return names[i];
    }

    function space(Rng memory rng) internal pure returns (string memory) {
        return pick(rng, [string(" "), "  ", "\t", "\n  ", "\r\n"]);
    }

    function comment(Rng memory rng) internal pure returns (string memory) {
        return
            string.concat(
                "/* ", pick(rng, [string("x"), "add max-price", "# @ , ; : '", "lead-signer", "*/ /*"]), " */"
            );
    }

    function numericLiteral(Rng memory rng) internal pure returns (string memory) {
        return pick(rng, [string("5"), "0x1f", "0xABcd", "1e18", "007"]);
    }

    function text(Rng memory rng) internal pure returns (string memory) {
        string memory out = "";
        uint256 words = draw(rng, 4);
        for (uint256 i = 0; i < words; i++) {
            out = string.concat(out, i == 0 ? "" : " ", pick(rng, [string("x"), "add", "max-price", "z9", "1"]));
        }
        return out;
    }

    function literalText(Rng memory rng, string memory open, string memory close)
        internal
        pure
        returns (string memory)
    {
        string memory inner = draw(rng, 3) == 0
            ? string.concat(text(rng), " ", comment(rng), " ", text(rng))
            : text(rng);
        return string.concat(open, inner, close);
    }

    function bindingContent(Rng memory rng, uint256 kind) internal pure returns (string memory) {
        string memory content;
        if (kind == KIND_NUMERIC) {
            content = numericLiteral(rng);
        } else if (kind == KIND_STRING) {
            content = literalText(rng, "\"", "\"");
        } else if (kind == KIND_SUB_PARSER) {
            content = literalText(rng, "[", "]");
        } else if (kind == KIND_ELIDED) {
            return pick(rng, [string("!Lead signer."), "!", "!x add", "!A value: x.", "! max-price"]);
        } else {
            return pick(rng, [string("_: 1;"), "_ _: 1 2;", ":foo();", "_: x();", "_:\n  0x01;"]);
        }
        if (draw(rng, 4) == 0) content = string.concat(comment(rng), " ", content);
        if (draw(rng, 4) == 0) content = string.concat(content, " ", comment(rng));
        return content;
    }

    function resolvable(uint256 kind) internal pure returns (bool) {
        return kind != KIND_ABSENT && kind != KIND_EXPRESSION;
    }

    function bindingReference(Rng memory rng, uint256[NAME_COUNT] memory kinds) internal pure returns (string memory) {
        uint256 start = draw(rng, NAME_COUNT);
        for (uint256 j = 0; j < NAME_COUNT; j++) {
            uint256 i = (start + j) % NAME_COUNT;
            if (resolvable(kinds[i])) return bindingName(i);
        }
        return numericLiteral(rng);
    }

    function rhsItem(Rng memory rng, uint256[NAME_COUNT] memory kinds, uint256 depth)
        internal
        pure
        returns (string memory)
    {
        uint256 k = draw(rng, depth < 2 ? 6 : 4);
        if (k == 0) return bindingReference(rng, kinds);
        if (k == 1) return numericLiteral(rng);
        if (k == 2) return string.concat("\"", text(rng), "\"");
        if (k == 3) return string.concat("[", text(rng), "]");
        string memory word = k == 4
            ? pick(rng, [string("foo"), "binary-equal-to", "ensure", "lead", "now"])
            : bindingName(draw(rng, NAME_COUNT));
        if (draw(rng, 3) == 0) {
            word = string.concat(
                word, "<", numericLiteral(rng), draw(rng, 2) == 0 ? "" : string.concat(" ", numericLiteral(rng)), ">"
            );
        }
        string memory inputs = "";
        uint256 inputCount = draw(rng, 3);
        for (uint256 i = 0; i < inputCount; i++) {
            inputs = string.concat(inputs, i == 0 ? "" : space(rng), rhsItem(rng, kinds, depth + 1));
        }
        return string.concat(word, "(", inputs, ")");
    }

    function line(Rng memory rng, uint256[NAME_COUNT] memory kinds, uint256 aliases)
        internal
        pure
        returns (string memory, uint256)
    {
        string memory out = draw(rng, 4) == 0 ? string.concat(comment(rng), space(rng)) : "";
        uint256 lhsCount = draw(rng, 3);
        for (uint256 i = 0; i < lhsCount; i++) {
            string memory item = "_";
            if (draw(rng, 2) == 0) {
                item = string.concat("v", vm.toString(aliases));
                aliases++;
            }
            out = string.concat(out, i == 0 ? "" : " ", item);
        }
        out = string.concat(out, ":", pick(rng, [string(""), " ", " ", "\n  ", "\t"]));
        uint256 rhsCount = 1 + draw(rng, 3);
        for (uint256 i = 0; i < rhsCount; i++) {
            out = string.concat(out, i == 0 ? "" : space(rng), rhsItem(rng, kinds, 0));
        }
        return (out, aliases);
    }

    function entrypointBody(Rng memory rng, uint256[NAME_COUNT] memory kinds) internal pure returns (string memory) {
        string memory out = draw(rng, 4) == 0 ? string.concat(comment(rng), "\n") : "";
        if (draw(rng, 2) == 0) {
            out = string.concat(out, "using-words-from");
            uint256 tokens = 1 + draw(rng, 2);
            for (uint256 i = 0; i < tokens; i++) {
                string memory token = draw(rng, 2) == 0
                    ? bindingReference(rng, kinds)
                    : vm.toString(address(uint160(uint256(keccak256(abi.encode(rng.state))))));
                out = string.concat(out, " ", token);
            }
            out = string.concat(out, draw(rng, 3) == 0 ? string.concat(" ", comment(rng)) : "", "\n");
        }
        uint256 aliases = 0;
        uint256 sources = 1 + draw(rng, 2);
        for (uint256 s = 0; s < sources; s++) {
            uint256 lines = 1 + draw(rng, 3);
            for (uint256 l = 0; l < lines; l++) {
                string memory lineText;
                (lineText, aliases) = line(rng, kinds, aliases);
                out = string.concat(out, lineText, l + 1 == lines ? ";" : ",", space(rng));
            }
        }
        if (draw(rng, 3) == 0) out = string.concat(out, comment(rng));
        return out;
    }

    function generate(uint256 seed) internal pure returns (string memory, DotrainBinding[] memory) {
        Rng memory rng = Rng(seed);
        uint256[NAME_COUNT] memory kinds;
        for (uint256 i = 0; i < NAME_COUNT; i++) {
            kinds[i] = draw(rng, KIND_COUNT);
        }

        string memory dotrain = string.concat(
            pick(rng, [string(""), "# SPDX # front matter\n", "a @ b - c\n", "#e\n", "--\n"]),
            "---",
            draw(rng, 3) == 0 ? string.concat("\n", comment(rng)) : "",
            "\n"
        );
        uint256 entryAt = draw(rng, NAME_COUNT + 1);
        for (uint256 i = 0; i <= NAME_COUNT; i++) {
            if (i == entryAt) {
                dotrain = string.concat(dotrain, "#weighting", space(rng), entrypointBody(rng, kinds), space(rng));
            }
            if (i < NAME_COUNT && kinds[i] != KIND_ABSENT) {
                dotrain = string.concat(
                    dotrain,
                    "#",
                    bindingName(i),
                    pick(rng, [string(" "), " ", "\n", "\t", "  "]),
                    bindingContent(rng, kinds[i]),
                    pick(rng, [string("\n"), "\n\n", " ", "\r\n", "\n\n\n"])
                );
            }
        }

        DotrainBinding[] memory all = new DotrainBinding[](NAME_COUNT * 2);
        uint256 count = 0;
        for (uint256 i = 0; i < NAME_COUNT; i++) {
            if (kinds[i] == KIND_ELIDED || (resolvable(kinds[i]) && draw(rng, 2) == 0)) {
                if (draw(rng, 4) == 0) {
                    all[count++] = DotrainBinding(bindingName(i), keccak256(abi.encode(seed, "decoy", i)));
                }
                all[count++] = DotrainBinding(bindingName(i), keccak256(abi.encode(seed, "value", i)));
            }
        }
        DotrainBinding[] memory bound = new DotrainBinding[](count);
        for (uint256 i = 0; i < count; i++) {
            bound[i] = all[i];
        }
        return (dotrain, bound);
    }
}
