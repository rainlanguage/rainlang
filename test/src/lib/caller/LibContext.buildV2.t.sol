// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, stdError} from "forge-std-1.17.0/src/Test.sol";
import {IERC1271} from "@openzeppelin-contracts-5.7.0/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin-contracts-5.7.0/utils/cryptography/ECDSA.sol";
import {
    LibContext,
    MessageHashUtils,
    InvalidSignature,
    CONTEXT_BASE_COLUMN,
    CONTEXT_BASE_ROWS,
    CONTEXT_BASE_ROW_SENDER,
    CONTEXT_BASE_ROW_CALLING_CONTRACT
} from "../../../../src/lib/caller/LibContext.sol";
import {SignedContextV2} from "../../../../src/interface/IInterpreterCallerV5.sol";
import {LibSignedContextV2TypedData, EIP712Domain} from "test/lib/caller/LibSignedContextV2TypedData.sol";
import {ERC1271WalletMock} from "test/lib/caller/ERC1271WalletMock.sol";
import {LibContextSlow} from "./LibContextSlow.sol";

contract LibContextBuildV2Test is Test {
    uint256 constant SIGNER_PK = 0x5163;
    uint256 constant OTHER_PK = 0xB0B;
    /// Keeps the EIP-712 JSON the oracle digests come from small.
    uint256 constant MAX_WORDS = 16;

    function buildV2External(bytes32[][] memory baseContext, SignedContextV2[] memory signedContexts)
        external
        view
        returns (bytes32[][] memory)
    {
        return LibContext.buildV2(baseContext, signedContexts);
    }

    function domain() internal pure returns (EIP712Domain memory) {
        return EIP712Domain("LibContextBuildV2Test", "1", 1, 0x1234567890123456789012345678901234567890);
    }

    function otherDomain() internal pure returns (EIP712Domain memory) {
        return EIP712Domain("LibContextBuildV2TestOther", "2", 137, 0xabCDEF1234567890ABcDEF1234567890aBCDeF12);
    }

    function signingDomainSeparator() internal pure returns (bytes32) {
        return LibSignedContextV2TypedData.domainSeparator(domain());
    }

    function bounded(bytes32[] memory words) internal pure returns (bytes32[] memory) {
        if (words.length > MAX_WORDS) {
            assembly ("memory-safe") {
                mstore(words, MAX_WORDS)
            }
        }
        return words;
    }

    /// One signed context from `pk` presenting `context` under
    /// `signingDomain` with a signature over `signedWords`.
    function signedContextsFor(
        uint256 pk,
        EIP712Domain memory signingDomain,
        bytes32[] memory context,
        bytes32[] memory signedWords
    ) internal pure returns (SignedContextV2[] memory) {
        SignedContextV2[] memory signedContexts = new SignedContextV2[](1);
        signedContexts[0] = SignedContextV2({
            signer: vm.addr(pk),
            domainSeparator: LibSignedContextV2TypedData.domainSeparator(signingDomain),
            context: context,
            signature: LibSignedContextV2TypedData.sign(pk, signingDomain, signedWords)
        });
        return signedContexts;
    }

    function signedContextsFor(uint256 pk, bytes32[] memory context) internal pure returns (SignedContextV2[] memory) {
        return signedContextsFor(pk, domain(), context, context);
    }

    function words1(bytes32 x) internal pure returns (bytes32[] memory) {
        bytes32[] memory words = new bytes32[](1);
        words[0] = x;
        return words;
    }

    function words2(bytes32 x, bytes32 y) internal pure returns (bytes32[] memory) {
        bytes32[] memory words = new bytes32[](2);
        words[0] = x;
        words[1] = y;
        return words;
    }

    function addressWord(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function assertEqContext(bytes32[][] memory expected, bytes32[][] memory actual) internal pure {
        assertEq(expected.length, actual.length, "column count");
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(expected[i], actual[i]);
        }
    }

    /// forge-config: default.fuzz.runs = 100
    function testBuildV2ValidSignatureBuilds(bytes32[][] memory base, bytes32[] memory words) external view {
        words = bounded(words);
        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, words);

        bytes32[][] memory actual = LibContext.buildV2(base, signedContexts);
        assertEqContext(LibContextSlow.buildStructureSlow(base, signedContexts), actual);

        assertEq(actual.length, 1 + base.length + 3);
        assertEq(actual[1 + base.length], words1(addressWord(vm.addr(SIGNER_PK))));
        assertEq(actual[2 + base.length], words1(signingDomainSeparator()));
        assertEq(actual[3 + base.length], words);
    }

    function testBuildV2SeveralSignedContextsBuild(bytes32 x, bytes32 y, bytes32 z) external view {
        SignedContextV2[] memory signedContexts = new SignedContextV2[](2);
        signedContexts[0] = signedContextsFor(SIGNER_PK, words2(x, y))[0];
        signedContexts[1] = signedContextsFor(OTHER_PK, words1(z))[0];

        bytes32[][] memory actual = LibContext.buildV2(new bytes32[][](0), signedContexts);
        assertEqContext(LibContextSlow.buildStructureSlow(new bytes32[][](0), signedContexts), actual);

        assertEq(actual.length, 5);
        assertEq(actual[1], words2(addressWord(vm.addr(SIGNER_PK)), addressWord(vm.addr(OTHER_PK))));
        assertEq(actual[2], words2(signingDomainSeparator(), signingDomainSeparator()));
        assertEq(actual[3], words2(x, y));
        assertEq(actual[4], words1(z));
    }

    /// Each signed context verifies under its own signer's domain, and the
    /// domain separators column holds each one at its signer's row.
    /// forge-config: default.fuzz.runs = 100
    function testBuildV2DifferentDomainsBuild(bytes32[][] memory base, bytes32 x, bytes32 y, bytes32 z) external view {
        bytes32 domainSeparatorA = signingDomainSeparator();
        bytes32 domainSeparatorB = LibSignedContextV2TypedData.domainSeparator(otherDomain());
        assertNotEq(domainSeparatorA, domainSeparatorB);

        SignedContextV2[] memory signedContexts = new SignedContextV2[](2);
        signedContexts[0] = signedContextsFor(SIGNER_PK, domain(), words2(x, y), words2(x, y))[0];
        signedContexts[1] = signedContextsFor(OTHER_PK, otherDomain(), words1(z), words1(z))[0];

        bytes32[][] memory actual = LibContext.buildV2(base, signedContexts);
        assertEqContext(LibContextSlow.buildStructureSlow(base, signedContexts), actual);
        assertEq(actual.length, 1 + base.length + 4);
        assertEq(actual[CONTEXT_BASE_COLUMN].length, CONTEXT_BASE_ROWS);
        for (uint256 i = 0; i < base.length; i++) {
            assertEq(actual[1 + i], base[i]);
        }
        assertEq(actual[1 + base.length], words2(addressWord(vm.addr(SIGNER_PK)), addressWord(vm.addr(OTHER_PK))));
        assertEq(actual[2 + base.length], words2(domainSeparatorA, domainSeparatorB));
        assertEq(actual[3 + base.length], words2(x, y));
        assertEq(actual[4 + base.length], words1(z));
    }

    /// The domain separators column is aligned with the signers column: row
    /// `i` of both is signed context `i`.
    /// forge-config: default.fuzz.runs = 50
    function testBuildV2DomainSeparatorsAlignedWithSigners(uint256 n, uint32 chainIdSeed) external view {
        n = bound(n, 1, 5);
        SignedContextV2[] memory signedContexts = new SignedContextV2[](n);
        for (uint256 i = 0; i < n; i++) {
            EIP712Domain memory signingDomain = domain();
            signingDomain.chainId = uint256(chainIdSeed) + i;
            signedContexts[i] =
                signedContextsFor(SIGNER_PK + i, signingDomain, words1(bytes32(i)), words1(bytes32(i)))[0];
        }

        bytes32[][] memory actual = LibContext.buildV2(new bytes32[][](0), signedContexts);
        assertEq(actual.length, 3 + n);
        assertEq(actual[1].length, n);
        assertEq(actual[2].length, n);
        for (uint256 i = 0; i < n; i++) {
            assertEq(actual[1][i], addressWord(signedContexts[i].signer));
            assertEq(actual[2][i], signedContexts[i].domainSeparator);
            assertEq(actual[3 + i], words1(bytes32(i)));
        }
    }

    /// With no signed contexts there are no signers or domain separators
    /// columns.
    /// forge-config: default.fuzz.runs = 100
    function testBuildV2ZeroSignedContexts(bytes32[][] memory base) external view {
        SignedContextV2[] memory signedContexts = new SignedContextV2[](0);

        bytes32[][] memory actual = LibContext.buildV2(base, signedContexts);
        assertEqContext(LibContextSlow.buildStructureSlow(base, signedContexts), actual);
        assertEq(actual.length, 1 + base.length);
        assertEq(actual[0].length, CONTEXT_BASE_ROWS);
    }

    function testBaseV2() external view {
        bytes32[] memory baseV2 = LibContext.baseV2();

        assertEq(CONTEXT_BASE_COLUMN, 0);
        assertEq(baseV2.length, CONTEXT_BASE_ROWS);
        assertEq(baseV2.length, 2);
        assertEq(baseV2[CONTEXT_BASE_ROW_SENDER], addressWord(msg.sender));
        assertEq(baseV2[CONTEXT_BASE_ROW_CALLING_CONTRACT], addressWord(address(this)));
        assertTrue(msg.sender != address(this));
    }

    function testBaseV2Allocates() external view {
        uint256 freeMemoryPointerBefore;
        assembly ("memory-safe") {
            freeMemoryPointerBefore := mload(0x40)
        }
        bytes32[] memory baseV2 = LibContext.baseV2();
        uint256 freeMemoryPointerAfter;
        uint256 baseV2Pointer;
        assembly ("memory-safe") {
            freeMemoryPointerAfter := mload(0x40)
            baseV2Pointer := baseV2
        }
        assertEq(baseV2Pointer, freeMemoryPointerBefore);
        assertEq(freeMemoryPointerAfter, freeMemoryPointerBefore + 0x20 * (1 + CONTEXT_BASE_ROWS));
    }

    function testBuildV2DomainSeparatorsColumnIsTheVerifyingSeparator(
        bytes32[] memory words,
        uint64 chainId,
        address verifyingContract
    ) external view {
        words = bounded(words);
        EIP712Domain memory signingDomain = EIP712Domain("LibContextBuildV2Test", "1", chainId, verifyingContract);
        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, signingDomain, words, words);

        bytes32[][] memory actual = LibContext.buildV2(new bytes32[][](0), signedContexts);
        assertEq(actual[2], words1(LibSignedContextV2TypedData.domainSeparator(signingDomain)));
        assertEq(actual[3], words);
    }

    /// The signers column shows the ERC-1271 account, not its owner key.
    function testBuildV2ERC1271SignerBuilds(bytes32[] memory words) external {
        words = bounded(words);
        ERC1271WalletMock wallet = new ERC1271WalletMock(vm.addr(SIGNER_PK));

        SignedContextV2[] memory signedContexts = new SignedContextV2[](1);
        signedContexts[0] = SignedContextV2({
            signer: address(wallet),
            domainSeparator: signingDomainSeparator(),
            context: words,
            signature: LibSignedContextV2TypedData.signFor(SIGNER_PK, domain(), address(wallet), words)
        });

        bytes32[][] memory actual = this.buildV2External(new bytes32[][](0), signedContexts);
        assertEq(actual.length, 4);
        assertEq(actual[1], words1(addressWord(address(wallet))));
        assertEq(actual[2], words1(signingDomainSeparator()));
        assertEq(actual[3], words);
    }

    function testBuildV2ERC1271RevokedReverts(bytes32[] memory words) external {
        words = bounded(words);
        ERC1271WalletMock wallet = new ERC1271WalletMock(vm.addr(SIGNER_PK));

        SignedContextV2[] memory signedContexts = new SignedContextV2[](1);
        signedContexts[0] = SignedContextV2({
            signer: address(wallet),
            domainSeparator: signingDomainSeparator(),
            context: words,
            signature: LibSignedContextV2TypedData.signFor(SIGNER_PK, domain(), address(wallet), words)
        });
        assertEq(this.buildV2External(new bytes32[][](0), signedContexts).length, 4);

        wallet.revoke();
        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    /// Two ERC-1271 accounts sharing an owner key accept the same digests, so
    /// only `signer` being signed over stops A's signature verifying as B's.
    function testBuildV2ERC1271SharedOwnerDoesNotCrossAccounts(bytes32[] memory words) external {
        words = bounded(words);
        ERC1271WalletMock walletA = new ERC1271WalletMock(vm.addr(SIGNER_PK));
        ERC1271WalletMock walletB = new ERC1271WalletMock(vm.addr(SIGNER_PK));
        bytes memory signatureForA = LibSignedContextV2TypedData.signFor(SIGNER_PK, domain(), address(walletA), words);

        bytes32 digestForA = LibSignedContextV2TypedData.digest(domain(), address(walletA), words);
        assertEq(walletB.isValidSignature(digestForA, signatureForA), IERC1271.isValidSignature.selector);

        SignedContextV2[] memory signedContexts = new SignedContextV2[](1);
        signedContexts[0] = SignedContextV2({
            signer: address(walletA),
            domainSeparator: signingDomainSeparator(),
            context: words,
            signature: signatureForA
        });
        assertEq(this.buildV2External(new bytes32[][](0), signedContexts).length, 4);

        signedContexts[0].signer = address(walletB);
        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function testBuildV2InvalidSignatureSecondIndexReverts(bytes32 x) external {
        SignedContextV2[] memory signedContexts = new SignedContextV2[](2);
        signedContexts[0] = signedContextsFor(SIGNER_PK, words1(x))[0];
        signedContexts[1] = SignedContextV2({
            signer: address(0xdead),
            domainSeparator: signingDomainSeparator(),
            context: words1(x),
            signature: new bytes(65)
        });

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(1)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function testBuildV2WrongWordReverts(bytes32 x, bytes32 y) external {
        vm.assume(x != y);
        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, domain(), words1(y), words1(x));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function testBuildV2AppendedWordReverts(bytes32 x, bytes32 y) external {
        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, domain(), words2(x, y), words1(x));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function testBuildV2AppendedZeroReverts(bytes32 x) external {
        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, domain(), words2(x, 0), words1(x));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function testBuildV2TruncatedReverts(bytes32 x, bytes32 y) external {
        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, domain(), words1(x), words2(x, y));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function testBuildV2EmptiedReverts(bytes32 x) external {
        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, domain(), new bytes32[](0), words1(x));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function testBuildV2WrongSignerReverts(bytes32[] memory words, uint256 otherPk) external {
        words = bounded(words);
        otherPk = bound(otherPk, 1, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140);
        vm.assume(otherPk != SIGNER_PK);

        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, words);
        signedContexts[0].signer = vm.addr(otherPk);

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function testBuildV2EmptySignatureReverts(bytes32[] memory words) external {
        SignedContextV2[] memory signedContexts = new SignedContextV2[](1);
        signedContexts[0] = SignedContextV2({
            signer: vm.addr(SIGNER_PK), domainSeparator: signingDomainSeparator(), context: words, signature: ""
        });

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    /// A signature under domain A presented with domain separator B does not
    /// verify.
    function testBuildV2PresentedDomainSeparatorMismatchReverts(bytes32[] memory words, bytes32 otherDomainSeparator)
        external
    {
        words = bounded(words);
        vm.assume(otherDomainSeparator != signingDomainSeparator());
        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, words);
        signedContexts[0].domainSeparator = otherDomainSeparator;

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    /// Each signed context is verified under its own domain separator, so a
    /// second context presenting the first's domain separator reverts at its
    /// own index.
    function testBuildV2SecondDomainSeparatorMismatchReverts(bytes32 x, bytes32 y) external {
        SignedContextV2[] memory signedContexts = new SignedContextV2[](2);
        signedContexts[0] = signedContextsFor(SIGNER_PK, domain(), words1(x), words1(x))[0];
        signedContexts[1] = signedContextsFor(OTHER_PK, otherDomain(), words1(y), words1(y))[0];
        signedContexts[1].domainSeparator = signedContexts[0].domainSeparator;

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(1)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function testBuildV2DifferentDomainFieldsRevert(
        bytes32[] memory words,
        uint64 otherChainId,
        address otherVerifyingContract
    ) external {
        words = bounded(words);
        EIP712Domain memory signingDomain = domain();
        vm.assume(otherChainId != signingDomain.chainId);
        vm.assume(otherVerifyingContract != signingDomain.verifyingContract);
        SignedContextV2[] memory signedContexts = signedContextsFor(SIGNER_PK, words);

        EIP712Domain memory otherContract = domain();
        otherContract.verifyingContract = otherVerifyingContract;
        signedContexts[0].domainSeparator = LibSignedContextV2TypedData.domainSeparator(otherContract);
        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);

        EIP712Domain memory otherChain = domain();
        otherChain.chainId = otherChainId;
        signedContexts[0].domainSeparator = LibSignedContextV2TypedData.domainSeparator(otherChain);
        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    /// A `personal_sign` signature over the packed words, the pre-EIP-712
    /// signed context scheme, does not verify.
    function testBuildV2PersonalSignSignatureReverts(bytes32[] memory words) external {
        bytes32 personalSignDigest = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encodePacked(words)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, personalSignDigest);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(ECDSA.recover(personalSignDigest, signature), vm.addr(SIGNER_PK));

        SignedContextV2[] memory signedContexts = new SignedContextV2[](1);
        signedContexts[0] = SignedContextV2({
            signer: vm.addr(SIGNER_PK), domainSeparator: signingDomainSeparator(), context: words, signature: signature
        });

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
        this.buildV2External(new bytes32[][](0), signedContexts);
    }

    function word(bytes memory data, uint256 offset) internal pure returns (bytes32) {
        bytes32 w;
        assembly ("memory-safe") {
            w := mload(add(add(data, 0x20), offset))
        }
        return w;
    }

    function setWord(bytes memory data, uint256 offset, bytes32 w) internal pure {
        assembly ("memory-safe") {
            mstore(add(add(data, 0x20), offset), w)
        }
    }

    /// Calldata for `buildV2External` with no base context and one signed
    /// context from `SIGNER_PK` presenting `context` under a signature over
    /// `signedWords`.
    function buildV2Calldata(bytes32[] memory context, bytes32[] memory signedWords)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            this.buildV2External, (new bytes32[][](0), signedContextsFor(SIGNER_PK, domain(), context, signedWords))
        );
    }

    /// Byte offset in `payload` of the single signed context's
    /// `context.length` word, found by following the ABI offsets.
    function contextLengthOffset(bytes memory payload) internal pure returns (uint256) {
        uint256 headStart = 4;
        uint256 signedContextsStart = headStart + uint256(word(payload, headStart + 0x20));
        assertEq(uint256(word(payload, signedContextsStart)), 1, "one signed context");
        uint256 elementsStart = signedContextsStart + 0x20;
        uint256 structStart = elementsStart + uint256(word(payload, elementsStart));
        return structStart + uint256(word(payload, structStart + 0x40));
    }

    /// The decoder bounds an array by the end of calldata, so a
    /// `context.length` up to this many words decodes.
    function contextWordsToEnd(bytes memory payload, uint256 lengthOffset) internal pure returns (uint256) {
        return (payload.length - lengthOffset - 0x20) / 0x20;
    }

    function testBuildV2CalldataUnpatchedSucceeds() external {
        bytes32 x = bytes32(uint256(42));
        bytes memory payload = buildV2Calldata(words1(x), words1(x));
        assertEq(uint256(word(payload, contextLengthOffset(payload))), 1, "context length");

        (bool success, bytes memory returnData) = address(this).call(payload);
        assertTrue(success);
        bytes32[][] memory context = abi.decode(returnData, (bytes32[][]));
        assertEq(context.length, 4);
        assertEq(context[1], words1(addressWord(vm.addr(SIGNER_PK))));
        assertEq(context[2], words1(signingDomainSeparator()));
        assertEq(context[3], words1(x));
    }

    /// Bounded at 2^58 so the decoder's `32 * (length + 1)` byte reservation
    /// stays under the 2^64 - 1 allocation limit.
    function testBuildV2CalldataContextLengthBeyondCalldataReverts(uint256 length) external {
        bytes32 x = bytes32(uint256(42));
        bytes memory payload = buildV2Calldata(words1(x), words1(x));
        uint256 lengthOffset = contextLengthOffset(payload);
        length = bound(length, contextWordsToEnd(payload, lengthOffset) + 1, 1 << 58);
        setWord(payload, lengthOffset, bytes32(length));

        (bool success, bytes memory returnData) = address(this).call(payload);
        assertFalse(success);
        assertEq(returnData.length, 0);
    }

    function testBuildV2CalldataContextLengthUnallocatableReverts(uint256 length) external {
        bytes32 x = bytes32(uint256(42));
        bytes memory payload = buildV2Calldata(words1(x), words1(x));
        uint256 lengthOffset = contextLengthOffset(payload);
        length = bound(length, 1 << 59, type(uint256).max);
        setWord(payload, lengthOffset, bytes32(length));

        (bool success, bytes memory returnData) = address(this).call(payload);
        assertFalse(success);
        assertEq(returnData, stdError.memOverflowError);
    }

    /// An overstated length within calldata reads the signature tail as
    /// context words, which the signature does not cover.
    function testBuildV2CalldataContextLengthOverstatedWithinCalldataReverts(uint256 length) external {
        bytes32 x = bytes32(uint256(42));
        bytes memory payload = buildV2Calldata(words1(x), words1(x));
        uint256 lengthOffset = contextLengthOffset(payload);
        uint256 wordsToEnd = contextWordsToEnd(payload, lengthOffset);
        assertGe(wordsToEnd, 4, "signature tail behind the context word");
        length = bound(length, 2, wordsToEnd);
        setWord(payload, lengthOffset, bytes32(length));

        (bool success, bytes memory returnData) = address(this).call(payload);
        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
    }

    function testBuildV2CalldataContextLengthUnderstatedSignatureOverLongerReverts() external {
        bytes32 x = bytes32(uint256(42));
        bytes memory payload = buildV2Calldata(words1(x), words1(x));
        setWord(payload, contextLengthOffset(payload), bytes32(0));

        (bool success, bytes memory returnData) = address(this).call(payload);
        assertFalse(success);
        assertEq(returnData, abi.encodeWithSelector(InvalidSignature.selector, uint256(0)));
    }

    /// The signed column is the context the decoder presented, not the
    /// longer one still encoded behind it.
    function testBuildV2CalldataContextLengthUnderstatedPresentsShorterContext() external {
        bytes32 x = bytes32(uint256(42));
        bytes memory payload = buildV2Calldata(words1(x), new bytes32[](0));
        setWord(payload, contextLengthOffset(payload), bytes32(0));

        (bool success, bytes memory returnData) = address(this).call(payload);
        assertTrue(success);
        bytes32[][] memory context = abi.decode(returnData, (bytes32[][]));
        assertEq(context.length, 4);
        assertEq(context[3].length, 0);
    }
}
