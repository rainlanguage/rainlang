# Known False Positives

Audit findings that have been triaged and dismissed. Documented here so
future audits do not re-flag the same issues.

## LibOpGet — read-only key persistence (gas tradeoff)

**File:** `src/lib/op/store/LibOpGet.sol`

When `get` has a cache miss it writes the fetched value into the in-memory
`stateKV` so that subsequent reads hit the cache. Because `stateKV` is
persisted at the end of eval, read-only keys pay an unnecessary `SSTORE`.

This is a deliberate design tradeoff: caching repeated reads saves more gas
than the extra `SSTORE` costs for read-only keys. Documented inline and in
commit `25c7c56f`.

## ERC20 float opcodes — `decimals()` is optional

**Files:** `src/lib/op/erc20/LibOpERC20Allowance.sol`,
`LibOpERC20BalanceOf.sol`, `LibOpERC20TotalSupply.sol`

The float ERC20 opcodes call `IERC20Metadata.decimals()` which is an optional
extension of the ERC20 standard. Tokens that do not implement `decimals()` will
cause these opcodes to revert.

This is by design. The `uint256-erc20-*` variants exist as alternatives for
non-compliant tokens. It is the Rainlang author's responsibility to ensure
tokens are compliant when using the float variants. Documented inline in each
opcode's source.
