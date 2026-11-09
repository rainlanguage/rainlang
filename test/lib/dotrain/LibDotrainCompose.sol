// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    CMASK_WHITESPACE,
    CMASK_VERTICAL_TAB,
    CMASK_FORM_FEED,
    CMASK_IDENTIFIER_HEAD,
    CMASK_IDENTIFIER_TAIL,
    CMASK_NUMERIC_0_9,
    CMASK_LESS_THAN_SIGN,
    CMASK_GREATER_THAN_SIGN,
    CMASK_LEFT_PAREN,
    CMASK_RIGHT_PAREN,
    CMASK_COMMA,
    CMASK_SEMICOLON,
    CMASK_COLON
} from "rain-string-0.3.9/src/lib/parse/LibParseCMask.sol";
import {PRAGMA_KEYWORD_BYTES} from "../../../src/lib/parse/LibParsePragma.sol";

/// @dev Rust `char::is_whitespace`, `str::trim` and regex `\s` within the ASCII dotrain accepts.
uint256 constant CMASK_TRIM = CMASK_WHITESPACE | CMASK_VERTICAL_TAB | CMASK_FORM_FEED;

/// @dev Ends a bare word: dotrain splits on `( ) < >` and whitespace within a line.
uint256 constant CMASK_WORD_DELIMITER = CMASK_WHITESPACE | CMASK_LEFT_PAREN | CMASK_RIGHT_PAREN | CMASK_LESS_THAN_SIGN
    | CMASK_GREATER_THAN_SIGN | CMASK_COMMA | CMASK_SEMICOLON | CMASK_COLON;

uint256 constant DOTRAIN_KIND_EXPRESSION = 0;
uint256 constant DOTRAIN_KIND_LITERAL = 1;
uint256 constant DOTRAIN_KIND_ELIDED = 2;

/// @dev Wraps the entrypoint name in the header `rain dotrain compose` emits.
string constant DOTRAIN_COMPOSE_HEADER_OPEN = "/* 0. ";
string constant DOTRAIN_COMPOSE_HEADER_CLOSE = " */ \n";

/// A binding found in the dotrain, as offsets into the source.
struct DotrainParsedBinding {
    uint256 nameStart;
    uint256 nameEnd;
    uint256 contentStart;
    uint256 contentEnd;
    uint256 kind;
    bool bound;
    bytes32 value;
}

/// An entrypoint being composed: `source` before `copied` is already in `out`.
struct DotrainComposeState {
    bytes source;
    bytes blanked;
    DotrainParsedBinding[] bindings;
    bytes out;
    uint256 copied;
}

/// A `-b name=value` binding as passed to `rain dotrain compose`.
/// @param name The dotrain binding name to rebind.
/// @param value The value, rendered as a 64 digit hex literal.
struct DotrainBinding {
    string name;
    bytes32 value;
}

/// The dotrain has no `---` front matter delimiter.
error DotrainMissingFrontMatter();

/// The requested entrypoint is not a binding in the dotrain.
/// @param name The entrypoint name.
error DotrainEntrypointNotFound(string name);

/// The requested entrypoint is not an expression binding.
/// @param name The entrypoint name.
error DotrainEntrypointNotExpression(string name);

/// The entrypoint references an elided binding that was not given a value.
/// @param name The binding name.
error DotrainElidedBinding(string name);

/// The entrypoint references a binding that is not a literal.
/// @param name The binding name.
error DotrainNotALiteralBinding(string name);

/// An LHS name in the entrypoint shadows a binding name.
/// @param name The binding name.
error DotrainAliasShadowsBinding(string name);

/// Input outside the supported dotrain subset (imports, quotes, namespace
/// paths, identifiers inside operands).
/// @param offset Byte offset into the dotrain source.
error DotrainUnsupported(uint256 offset);

/// A binding name does not match `^[a-z][0-9a-z-]*$`.
/// @param offset Byte offset into the dotrain source.
error DotrainInvalidBindingName(uint256 offset);

/// Two bindings in the dotrain share a name.
/// @param name The binding name.
error DotrainDuplicateBinding(string name);

/// A `-b` binding names no binding in the dotrain.
/// @param name The binding name.
error DotrainBindingNotFound(string name);

/// A `-b` binding names an expression binding.
/// @param name The binding name.
error DotrainBindingNotRebindable(string name);

/// Composes one entrypoint of a dotrain into rainlang, matching
/// `rain dotrain compose -e <entrypoint> -b <name>=<hexLiteral(value)>...`.
library LibDotrainCompose {
    /// Renders `value` as `0x` followed by 64 lowercase hex digits.
    /// @param value The value to render.
    /// @return The hex literal.
    function hexLiteral(bytes32 value) internal pure returns (string memory) {
        bytes memory out = new bytes(66);
        out[0] = "0";
        out[1] = "x";
        bytes16 digits = "0123456789abcdef";
        for (uint256 i = 0; i < 32; i++) {
            uint8 b = uint8(value[i]);
            out[2 + i * 2] = digits[b >> 4];
            out[3 + i * 2] = digits[b & 0x0f];
        }
        return string(out);
    }

    /// Returns `source` with every `/*...*/` comment replaced by spaces, so
    /// offsets into it are offsets into `source`.
    /// @param source The dotrain body.
    /// @param start Offset to start blanking from.
    /// @return The blanked copy.
    function blankComments(bytes memory source, uint256 start) internal pure returns (bytes memory) {
        bytes memory blanked = bytes.concat(source);
        uint256 i = start;
        while (i + 1 < blanked.length) {
            if (blanked[i] == "/" && blanked[i + 1] == "*") {
                uint256 open = i;
                i += 2;
                while (i + 1 < blanked.length && !(blanked[i] == "*" && blanked[i + 1] == "/")) {
                    i++;
                }
                if (i + 1 >= blanked.length) revert DotrainUnsupported(open);
                for (uint256 j = open; j < i + 2; j++) {
                    blanked[j] = " ";
                }
                i += 2;
            } else {
                i++;
            }
        }
        return blanked;
    }

    /// Splits the dotrain body into bindings and classifies each.
    /// @param source The dotrain.
    /// @param blanked `source` with front matter and comments blanked.
    /// @param bodyStart Offset of the first byte after the first `---`.
    /// @return bindings The bindings in source order.
    function parseBindings(bytes memory source, bytes memory blanked, uint256 bodyStart)
        internal
        pure
        returns (DotrainParsedBinding[] memory)
    {
        uint256 count = 0;
        for (uint256 i = bodyStart; i < blanked.length; i++) {
            if (blanked[i] == "@") revert DotrainUnsupported(i);
            if (blanked[i] == "#") count++;
        }
        DotrainParsedBinding[] memory bindings = new DotrainParsedBinding[](count);
        uint256 cursor = bodyStart;
        while (cursor < blanked.length && blanked[cursor] != "#") {
            if (charMask(blanked, cursor) & CMASK_TRIM == 0) revert DotrainUnsupported(cursor);
            cursor++;
        }
        for (uint256 b = 0; b < count; b++) {
            cursor = parseBinding(source, blanked, cursor + 1, bindings[b]);
            bytes memory name = slice(source, bindings[b].nameStart, bindings[b].nameEnd);
            for (uint256 i = 0; i < b; i++) {
                if (sameName(source, bindings[i], name, 0, name.length)) revert DotrainDuplicateBinding(string(name));
            }
        }
        return bindings;
    }

    /// @notice Parses the binding whose name starts at `nameStart` into `binding`.
    /// @param source The dotrain.
    /// @param blanked `source` with front matter and comments blanked.
    /// @param nameStart Offset of the first byte after the binding's `#`.
    /// @param binding Receives the binding's offsets and kind.
    /// @return Offset of the next `#`, or the end of the source.
    function parseBinding(
        bytes memory source,
        bytes memory blanked,
        uint256 nameStart,
        DotrainParsedBinding memory binding
    ) internal pure returns (uint256) {
        uint256 end = nameStart;
        while (end < blanked.length && blanked[end] != "#") {
            end++;
        }
        uint256 nameEnd = nameStart;
        while (nameEnd < end && charMask(blanked, nameEnd) & CMASK_WHITESPACE == 0) {
            nameEnd++;
        }
        if (nameEnd == nameStart || charMask(blanked, nameStart) & CMASK_IDENTIFIER_HEAD == 0) {
            revert DotrainInvalidBindingName(nameStart);
        }
        for (uint256 i = nameStart + 1; i < nameEnd; i++) {
            if (charMask(blanked, i) & CMASK_IDENTIFIER_TAIL == 0) revert DotrainInvalidBindingName(i);
        }
        binding.nameStart = nameStart;
        binding.nameEnd = nameEnd;
        (uint256 contentStart, uint256 contentEnd) = trim(blanked, nameEnd, end);
        if (contentStart == contentEnd) revert DotrainUnsupported(nameEnd);
        binding.kind = classify(blanked, contentStart, contentEnd);
        // A literal's value is its comment-blanked text; other content keeps comments.
        if (binding.kind != DOTRAIN_KIND_LITERAL) (contentStart, contentEnd) = trim(source, nameEnd, end);
        binding.contentStart = contentStart;
        binding.contentEnd = contentEnd;
        return end;
    }

    /// Classifies a binding by its comment-blanked, trimmed content.
    function classify(bytes memory blanked, uint256 start, uint256 end) internal pure returns (uint256) {
        bytes1 head = blanked[start];
        if (head == "!") return DOTRAIN_KIND_ELIDED;
        if (head == "'") revert DotrainUnsupported(start);
        if (head == "\"" || head == "[") return DOTRAIN_KIND_LITERAL;
        if (charMask(blanked, start) & CMASK_NUMERIC_0_9 != 0) {
            for (uint256 i = start; i < end; i++) {
                if (charMask(blanked, i) & CMASK_TRIM != 0) return DOTRAIN_KIND_EXPRESSION;
            }
            return DOTRAIN_KIND_LITERAL;
        }
        return DOTRAIN_KIND_EXPRESSION;
    }

    /// Narrows `[start, end)` past leading and trailing whitespace.
    function trim(bytes memory s, uint256 start, uint256 end) internal pure returns (uint256, uint256) {
        while (start < end && charMask(s, start) & CMASK_TRIM != 0) {
            start++;
        }
        while (end > start && charMask(s, end - 1) & CMASK_TRIM != 0) {
            end--;
        }
        return (start, end);
    }

    function charMask(bytes memory s, uint256 i) internal pure returns (uint256) {
        return uint256(1) << uint256(uint8(s[i]));
    }

    function slice(bytes memory s, uint256 start, uint256 end) internal pure returns (bytes memory) {
        bytes memory out = new bytes(end - start);
        for (uint256 i = 0; i < out.length; i++) {
            out[i] = s[start + i];
        }
        return out;
    }

    function sameName(
        bytes memory source,
        DotrainParsedBinding memory binding,
        bytes memory other,
        uint256 start,
        uint256 end
    ) internal pure returns (bool) {
        return keccak256(slice(source, binding.nameStart, binding.nameEnd)) == keccak256(slice(other, start, end));
    }

    /// Finds a binding by name.
    /// @return found Whether a binding has the name.
    /// @return index Its index when found.
    function findBinding(bytes memory source, DotrainParsedBinding[] memory bindings, bytes memory name)
        internal
        pure
        returns (bool, uint256)
    {
        uint256 i = 0;
        while (i < bindings.length && !sameName(source, bindings[i], name, 0, name.length)) {
            i++;
        }
        return (i < bindings.length, i);
    }

    /// Composes `entrypoint` of `dotrain` with `bound` applied as `-b`
    /// bindings. Returns exactly the stdout of `rain dotrain compose`, minus
    /// its trailing newline.
    /// @param dotrain The dotrain source.
    /// @param entrypoint The expression binding to compose.
    /// @param bound Values for literal or elided bindings; the last wins.
    /// @return The composed rainlang.
    function compose(string memory dotrain, string memory entrypoint, DotrainBinding[] memory bound)
        internal
        pure
        returns (string memory)
    {
        bytes memory source = bytes(dotrain);
        uint256 bodyStart = frontMatterEnd(source);
        bytes memory blanked = blankComments(source, bodyStart);
        DotrainParsedBinding[] memory bindings = parseBindings(source, blanked, bodyStart);
        for (uint256 i = 0; i < bound.length; i++) {
            (bool found, uint256 index) = findBinding(source, bindings, bytes(bound[i].name));
            if (!found) revert DotrainBindingNotFound(bound[i].name);
            if (bindings[index].kind == DOTRAIN_KIND_EXPRESSION) revert DotrainBindingNotRebindable(bound[i].name);
            bindings[index].bound = true;
            bindings[index].value = bound[i].value;
        }
        (bool entryFound, uint256 entryIndex) = findBinding(source, bindings, bytes(entrypoint));
        if (!entryFound) revert DotrainEntrypointNotFound(entrypoint);
        DotrainParsedBinding memory entry = bindings[entryIndex];
        if (entry.kind != DOTRAIN_KIND_EXPRESSION) revert DotrainEntrypointNotExpression(entrypoint);
        return string.concat(
            DOTRAIN_COMPOSE_HEADER_OPEN,
            entrypoint,
            DOTRAIN_COMPOSE_HEADER_CLOSE,
            string(transform(source, blanked, bindings, entry.contentStart, entry.contentEnd))
        );
    }

    /// Offset of the first byte after the first `---` anywhere in `source`.
    function frontMatterEnd(bytes memory source) internal pure returns (uint256) {
        for (uint256 i = 0; i + 2 < source.length; i++) {
            if (source[i] == "-" && source[i + 1] == "-" && source[i + 2] == "-") return i + 3;
        }
        revert DotrainMissingFrontMatter();
    }

    /// Copies the entrypoint content, substituting binding values into the
    /// pragma and bare RHS words.
    function transform(
        bytes memory source,
        bytes memory blanked,
        DotrainParsedBinding[] memory bindings,
        uint256 start,
        uint256 end
    ) internal pure returns (bytes memory) {
        DotrainComposeState memory state = DotrainComposeState(source, blanked, bindings, new bytes(0), start);
        transformLines(state, transformPragma(state, start, end), end);
        return bytes.concat(state.out, slice(source, state.copied, end));
    }

    /// @notice Substitutes binding values into a leading `using-words-from` pragma.
    /// @return Offset where the lines after the pragma start.
    function transformPragma(DotrainComposeState memory state, uint256 start, uint256 end)
        internal
        pure
        returns (uint256)
    {
        bytes memory blanked = state.blanked;
        uint256 cursor = skipWhitespace(blanked, start, end);
        bytes memory keyword = PRAGMA_KEYWORD_BYTES;
        uint256 keywordEnd = cursor + keyword.length;
        if (
            keywordEnd > end || keccak256(slice(blanked, cursor, keywordEnd)) != keccak256(keyword)
                || (keywordEnd < end && charMask(blanked, keywordEnd) & CMASK_TRIM == 0)
        ) return cursor;
        cursor = keywordEnd;
        while (true) {
            cursor = skipWhitespace(blanked, cursor, end);
            if (cursor == end) break;
            uint256 tokenEnd = cursor;
            while (tokenEnd < end && charMask(blanked, tokenEnd) & CMASK_TRIM == 0) {
                tokenEnd++;
            }
            bytes memory token = slice(blanked, cursor, tokenEnd);
            (bool found, uint256 index) = findBinding(state.source, state.bindings, token);
            if (found) {
                substitute(state, cursor, tokenEnd, index, token);
            } else if (charMask(blanked, cursor) & CMASK_NUMERIC_0_9 == 0) {
                break;
            }
            cursor = tokenEnd;
        }
        return cursor;
    }

    /// Substitutes binding values into bare RHS words from `cursor` to `end`.
    function transformLines(DotrainComposeState memory state, uint256 cursor, uint256 end) internal pure {
        bytes memory blanked = state.blanked;
        bool rhs = false;
        while (cursor < end) {
            bytes1 c = blanked[cursor];
            if (c == ":") {
                rhs = true;
                cursor++;
            } else if (c == "," || c == ";") {
                rhs = false;
                cursor++;
            } else if (c == "\"") {
                cursor = closeAt(blanked, cursor + 1, end, "\"") + 1;
            } else if (c == "[") {
                cursor = closeAt(blanked, cursor + 1, end, "]") + 1;
            } else if (c == "<") {
                uint256 close = closeAt(blanked, cursor + 1, end, ">");
                checkOperandArgs(blanked, cursor + 1, close);
                cursor = close + 1;
            } else if (c == "'") {
                revert DotrainUnsupported(cursor);
            } else if (charMask(blanked, cursor) & (CMASK_IDENTIFIER_HEAD | CMASK_NUMERIC_0_9) != 0) {
                cursor = transformWord(state, cursor, end, rhs);
            } else {
                cursor++;
            }
        }
    }

    /// @notice Substitutes the value of the binding a bare word at `cursor` names.
    /// @return Offset of the end of the word.
    function transformWord(DotrainComposeState memory state, uint256 cursor, uint256 end, bool rhs)
        internal
        pure
        returns (uint256)
    {
        bytes memory blanked = state.blanked;
        uint256 tokenEnd = cursor;
        while (tokenEnd < end && charMask(blanked, tokenEnd) & CMASK_WORD_DELIMITER == 0) {
            tokenEnd++;
        }
        tokenEnd = trimItemEnd(blanked, cursor, tokenEnd, end);
        if (charMask(blanked, cursor) & CMASK_IDENTIFIER_HEAD == 0) return tokenEnd;
        for (uint256 i = cursor; i < tokenEnd; i++) {
            if (blanked[i] == ".") revert DotrainUnsupported(i);
        }
        bytes memory token = slice(blanked, cursor, tokenEnd);
        (bool found, uint256 index) = findBinding(state.source, state.bindings, token);
        if (!found) return tokenEnd;
        if (!rhs) revert DotrainAliasShadowsBinding(string(token));
        // Opcodes share the namespace but are never substituted.
        if (tokenEnd < end && (blanked[tokenEnd] == "(" || blanked[tokenEnd] == "<")) return tokenEnd;
        substitute(state, cursor, tokenEnd, index, token);
        return tokenEnd;
    }

    /// End of the word at `[cursor, tokenEnd)`: dotrain trims a VT/FF run that
    /// reaches `,`, `;` or `end`; rain refuses any other VT/FF in a word.
    function trimItemEnd(bytes memory blanked, uint256 cursor, uint256 tokenEnd, uint256 end)
        internal
        pure
        returns (uint256)
    {
        uint256 i = cursor;
        while (i < tokenEnd && charMask(blanked, i) & CMASK_TRIM == 0) {
            i++;
        }
        if (i == tokenEnd) return tokenEnd;
        uint256 next = skipWhitespace(blanked, i, end);
        if (next < end && charMask(blanked, next) & (CMASK_COMMA | CMASK_SEMICOLON) == 0) revert DotrainUnsupported(i);
        return i;
    }

    /// Appends `source[copied:start]` and the value of `bindings[index]` to
    /// the output and resumes copying at `end`.
    function substitute(DotrainComposeState memory state, uint256 start, uint256 end, uint256 index, bytes memory name)
        internal
        pure
    {
        state.out = bytes.concat(
            state.out, slice(state.source, state.copied, start), resolve(state.blanked, state.bindings[index], name)
        );
        state.copied = end;
    }

    /// The text a reference to `binding` composes to.
    function resolve(bytes memory blanked, DotrainParsedBinding memory binding, bytes memory name)
        internal
        pure
        returns (bytes memory)
    {
        if (binding.bound) return bytes(hexLiteral(binding.value));
        if (binding.kind == DOTRAIN_KIND_LITERAL) return slice(blanked, binding.contentStart, binding.contentEnd);
        if (binding.kind == DOTRAIN_KIND_ELIDED) revert DotrainElidedBinding(string(name));
        revert DotrainNotALiteralBinding(string(name));
    }

    /// Reverts unless every operand arg in `[cursor, end)` is a literal: dotrain
    /// splits args on whitespace, keeps `"…"` and `[…]` whole and copies an
    /// arg only when it starts with a digit, `"` or `[`.
    function checkOperandArgs(bytes memory blanked, uint256 cursor, uint256 end) internal pure {
        cursor = skipWhitespace(blanked, cursor, end);
        while (cursor < end) {
            uint256 argStart = cursor;
            bytes1 head = blanked[cursor];
            uint256 argEnd = skipNonWhitespace(blanked, cursor, end);
            if (head == "\"" || head == "[") {
                bytes1 closer = head == "[" ? bytes1("]") : head;
                bool closed = argEnd - cursor > 1 && blanked[argEnd - 1] == closer;
                while (!closed) {
                    cursor = skipWhitespace(blanked, argEnd, end);
                    if (cursor == end) revert DotrainUnsupported(argStart);
                    argEnd = skipNonWhitespace(blanked, cursor, end);
                    closed = blanked[argEnd - 1] == closer;
                }
            } else if (charMask(blanked, cursor) & CMASK_NUMERIC_0_9 == 0) {
                revert DotrainUnsupported(argStart);
            }
            cursor = skipWhitespace(blanked, argEnd, end);
        }
    }

    function skipNonWhitespace(bytes memory s, uint256 cursor, uint256 end) internal pure returns (uint256) {
        while (cursor < end && charMask(s, cursor) & CMASK_TRIM == 0) {
            cursor++;
        }
        return cursor;
    }

    function skipWhitespace(bytes memory s, uint256 cursor, uint256 end) internal pure returns (uint256) {
        while (cursor < end && charMask(s, cursor) & CMASK_TRIM != 0) {
            cursor++;
        }
        return cursor;
    }

    /// Offset of the first `close` at or after `cursor`.
    function closeAt(bytes memory s, uint256 cursor, uint256 end, bytes1 close) internal pure returns (uint256) {
        while (cursor < end && s[cursor] != close) {
            cursor++;
        }
        if (cursor == end) revert DotrainUnsupported(cursor);
        return cursor;
    }
}
