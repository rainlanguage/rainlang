// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

library LibCamelToKebab {
    /// @notice Converts a CamelCase string to kebab-case.
    /// Rules (applied per character, matching sed behaviour):
    /// 1. Insert hyphen between a run of uppercase and an uppercase followed
    ///    by lowercase (e.g. "HTMLParser" → "HTML-Parser").
    /// 2. Insert hyphen between a lowercase/digit and an uppercase
    ///    (e.g. "camelCase" → "camel-Case").
    /// All characters are lowercased in the output.
    function camelToKebab(string memory input) internal pure returns (string memory) {
        bytes memory src = bytes(input);
        // Worst case: every char gets a hyphen before it.
        bytes memory buf = new bytes(src.length * 2);
        uint256 len;

        for (uint256 i; i < src.length; i++) {
            uint8 c = uint8(src[i]);

            if (i > 0 && isUpper(c)) {
                uint8 prev = uint8(src[i - 1]);
                // Rule 2: lowercase/digit followed by uppercase.
                if (isLower(prev) || isDigit(prev)) {
                    // Casting "-" to bytes1 is safe because it is a single ASCII byte.
                    //forge-lint: disable-next-line(unsafe-typecast)
                    buf[len++] = bytes1("-");
                }
                // Rule 1: uppercase followed by uppercase+lowercase
                // (split before the last uppercase in a run).
                else if (isUpper(prev) && i + 1 < src.length && isLower(uint8(src[i + 1]))) {
                    // Casting "-" to bytes1 is safe because it is a single ASCII byte.
                    //forge-lint: disable-next-line(unsafe-typecast)
                    buf[len++] = bytes1("-");
                }
            }

            buf[len++] = bytes1(toLower(c));
        }

        // Truncate buf to actual length.
        assembly ("memory-safe") {
            mstore(buf, len)
        }
        return string(buf);
    }

    function isUpper(uint8 c) private pure returns (bool) {
        return c >= 0x41 && c <= 0x5A;
    }

    function isLower(uint8 c) private pure returns (bool) {
        return c >= 0x61 && c <= 0x7A;
    }

    function isDigit(uint8 c) private pure returns (bool) {
        return c >= 0x30 && c <= 0x39;
    }

    function toLower(uint8 c) private pure returns (uint8) {
        if (isUpper(c)) return c + 0x20;
        return c;
    }
}
