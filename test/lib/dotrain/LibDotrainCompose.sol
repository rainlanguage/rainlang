// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    CMASK_WHITESPACE,
    CMASK_VERTICAL_TAB,
    CMASK_FORM_FEED,
    CMASK_IDENTIFIER_HEAD,
    CMASK_IDENTIFIER_TAIL,
    CMASK_NUMERIC_0_9
} from "rain-string-0.3.9/src/lib/parse/LibParseCMask.sol";

/// @dev Rust `str::trim` whitespace within the ASCII dotrain accepts.
uint256 constant CMASK_TRIM = CMASK_WHITESPACE | CMASK_VERTICAL_TAB | CMASK_FORM_FEED;

uint256 constant DOTRAIN_KIND_EXPRESSION = 0;
uint256 constant DOTRAIN_KIND_LITERAL = 1;
uint256 constant DOTRAIN_KIND_ELIDED = 2;

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
            if (charMask(blanked, cursor) & CMASK_WHITESPACE == 0) revert DotrainUnsupported(cursor);
            cursor++;
        }
        for (uint256 b = 0; b < count; b++) {
            uint256 nameStart = cursor + 1;
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
            DotrainParsedBinding memory binding = bindings[b];
            binding.nameStart = nameStart;
            binding.nameEnd = nameEnd;
            (binding.contentStart, binding.contentEnd) = trim(source, nameEnd, end);
            (uint256 classStart, uint256 classEnd) = trim(blanked, nameEnd, end);
            if (classStart == classEnd) revert DotrainUnsupported(nameEnd);
            binding.kind = classify(blanked, classStart, classEnd);
            for (uint256 i = 0; i < b; i++) {
                if (sameName(source, bindings[i], source, nameStart, nameEnd)) {
                    revert DotrainDuplicateBinding(string(slice(source, nameStart, nameEnd)));
                }
            }
            cursor = end;
        }
        return bindings;
    }

    /// Classifies a binding by its comment-blanked, trimmed content.
    function classify(bytes memory blanked, uint256 start, uint256 end) internal pure returns (uint256) {
        bytes1 head = blanked[start];
        if (head == "!") return DOTRAIN_KIND_ELIDED;
        if (head == "'") revert DotrainUnsupported(start);
        if (head == "\"" || head == "[") return DOTRAIN_KIND_LITERAL;
        if (charMask(blanked, start) & CMASK_NUMERIC_0_9 != 0) {
            for (uint256 i = start; i < end; i++) {
                if (charMask(blanked, i) & CMASK_WHITESPACE != 0) return DOTRAIN_KIND_EXPRESSION;
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
        for (uint256 i = 0; i < bindings.length; i++) {
            if (sameName(source, bindings[i], name, 0, name.length)) return (true, i);
        }
        return (false, 0);
    }
}
