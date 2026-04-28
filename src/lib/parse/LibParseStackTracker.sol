// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ParseStackUnderflow, ParseStackOverflow} from "../../error/ErrParse.sol";

/// @dev Tracks the current and high-water stack heights during parsing. The
/// low 128 bits hold the current stack height; the high 128 bits hold the
/// maximum height seen so far (used to size the runtime stack allocation).
type ParseStackTracker is uint256;

/// @title LibParseStackTracker
/// @notice Tracks current and high-water stack heights during parsing to
/// size the runtime stack allocation.
library LibParseStackTracker {
    using LibParseStackTracker for ParseStackTracker;

    /// @notice Pushing inputs requires special handling as the inputs need to be tallied
    /// separately and in addition to the regular stack pushes. The `inputs`
    /// addition is unchecked and relies on both `inputs` and `n` being ≤ 0xFF
    /// so that their sum cannot wrap a `uint256`.
    /// @param tracker The current stack tracker state.
    /// @param n The number of inputs to push. MUST be ≤ 0xFF.
    /// @return The updated stack tracker.
    function pushInputs(ParseStackTracker tracker, uint256 n) internal pure returns (ParseStackTracker) {
        unchecked {
            tracker = tracker.push(n);
            uint256 inputs = (ParseStackTracker.unwrap(tracker) >> 8) & 0xFF;
            inputs += n;
            if (inputs > 0xFF) {
                revert ParseStackOverflow();
            }
            return ParseStackTracker.wrap((ParseStackTracker.unwrap(tracker) & ~uint256(0xFF00)) | (inputs << 8));
        }
    }

    /// @notice Pushes n items onto the tracked stack, updating the current height
    /// and the high watermark if the new height exceeds it.
    /// The addition `current += n` is unchecked. This is safe only because
    /// `current` is masked to 8 bits and all callers pass `n` ≤ 0xFF, so
    /// the sum cannot exceed 0x1FE and cannot wrap a `uint256`. If `n`
    /// could be large, the `> 0xFF` overflow check would be ineffective
    /// after a wrapping addition.
    /// @param tracker The current stack tracker state.
    /// @param n The number of items to push. MUST be ≤ 0xFF.
    /// @return The updated stack tracker.
    function push(ParseStackTracker tracker, uint256 n) internal pure returns (ParseStackTracker) {
        unchecked {
            uint256 current = ParseStackTracker.unwrap(tracker) & 0xFF;
            uint256 inputs = (ParseStackTracker.unwrap(tracker) >> 8) & 0xFF;
            uint256 max = ParseStackTracker.unwrap(tracker) >> 0x10;
            current += n;
            if (current > 0xFF) {
                revert ParseStackOverflow();
            }
            if (current > max) {
                max = current;
            }
            return ParseStackTracker.wrap(current | (inputs << 8) | (max << 0x10));
        }
    }

    /// @notice Pops n items from the tracked stack. Reverts with
    /// `ParseStackUnderflow` if the current stack height is less than n.
    ///
    /// Unlike `push`, this subtracts `n` directly from the packed word
    /// rather than extracting, modifying, and repacking. This is safe
    /// because `n <= current <= 0xFF`, so the subtraction cannot borrow
    /// into the `inputs` byte (bits 8-15) or `max` byte (bits 16+).
    /// `push` cannot use this shortcut because it must also update `max`.
    /// @param tracker The current stack tracker state.
    /// @param n The number of items to pop.
    /// @return The updated stack tracker.
    function pop(ParseStackTracker tracker, uint256 n) internal pure returns (ParseStackTracker) {
        unchecked {
            uint256 current = ParseStackTracker.unwrap(tracker) & 0xFF;
            if (current < n) {
                revert ParseStackUnderflow();
            }
            return ParseStackTracker.wrap(ParseStackTracker.unwrap(tracker) - n);
        }
    }
}
