// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";

import {AuthoringMetaV2} from "../../../../src/interface/IParserV2.sol";
import {FINGERPRINT_MASK, LibParseMeta} from "../../../../src/lib/parse/LibParseMeta.sol";
import {DuplicateFingerprint, LibGenParseMeta} from "../../../../src/lib/codegen/LibGenParseMeta.sol";
import {LibParseMetaFingerprint} from "test/lib/meta/LibParseMetaFingerprint.sol";

/// @title LibGenParseMetaDuplicateFingerprintTest
/// @notice Pins the `DuplicateFingerprint` revert as intended behaviour for a
/// word set that cannot be represented, using the exact fuzz counterexample
/// that flaked `rainix-sol / test` run 36937526403 on `main`. Two distinct
/// random words landed on the same expansion bit with the same 3 byte
/// fingerprint, which is the ~2^-32 per pair coincidence the 4 byte meta item
/// is documented to tolerate. Nothing in the library is wrong for such a set;
/// generation has to fail and a real word set is fixed by renaming a word.
/// The fuzz tests therefore exclude colliding sets up front, and this suite
/// checks that the guard they use really does exclude this one.
contract LibGenParseMetaDuplicateFingerprintTest is Test {
    /// @dev The seed `findBestExpander` picks for `CI_COUNTEREXAMPLE_WORDS`
    /// under which the two colliding words become indistinguishable.
    uint256 internal constant COLLIDING_SEED = 59;

    /// @dev Index of the first colliding word in `CI_COUNTEREXAMPLE_WORDS`.
    uint256 internal constant COLLIDING_INDEX_A = 30;

    /// @dev Index of the second colliding word in `CI_COUNTEREXAMPLE_WORDS`.
    uint256 internal constant COLLIDING_INDEX_B = 66;

    /// @dev The build depth the fuzz test used for 114 words, i.e.
    /// `expanderDepth(114)`.
    uint8 internal constant COUNTEREXAMPLE_DEPTH = 3;

    /// @dev The 114 words from the counterexample, packed 32 bytes per word,
    /// one word per line in order. The authoring meta descriptions are dropped
    /// because only the words affect generation.
    bytes internal constant CI_COUNTEREXAMPLE_WORDS = hex"8c7967e85e26a97eefbd97bc509fe956cd8a433db3133b81adcc6ed08aff798e"
        hex"cc81717ddde84be6487f7cbdcd24957986fa63f26efc62977e8a523480c376de"
        hex"201dafa3262c1bfbe1586ace0053928cda63aff779d2212cb3b10bd87c134eb8"
        hex"3d60dfb583f9938e3d39bf4e414f4a421e3e8c2b31f8504bac6893b1564628db"
        hex"c011d807b4795a2a51e21a716eed5820cc99455e2b10d388a3b9b3b9704b8d82"
        hex"43741a280455c9c8d8939221f460e516e76849b43a1ebba650a4c5e749d453b9"
        hex"cdf811339397e32c97dea1e9c6d937cf26e0b384ac27e9a01f715b15c6ce567f"
        hex"11a122c7aed6d087e5b16c2573c0a34e338216b94c05db2490e2168130fb1783"
        hex"5b1ac67acb9e97085cd2d6c1043d9c5c5f2b7fae74c47b1bdf18698dce03291c"
        hex"cdc18e82d8534fb8cd37bb38a9583a7f203e6ce8f7e6772bb762fae30ff8a5cd"
        hex"1f39a3451d289253bb49ef6d191aae57ac6788bf437d9d30a2abbe46794f4e42"
        hex"7592c0510bf4fe3c8e283bda4e8ae9e8cd24053ac0153ba94aeb4dc8a5256944"
        hex"6d4e32f2fb314d74128207ba375d84b208fcf6c622d73f73fa827fe8eab0bb92"
        hex"48c8c34d3a026635fdc9cb813589bbbd9f39efa741df2c39975211412c7288cf"
        hex"a1703a62939096fd29c2c2536af5c5b67a9295e1385f57e34b7ef0b49d7965c4"
        hex"7f957f30e75efdc9568c61fff8aec3916443ae9ae3fe1d5e23b29e4fdfc4aea3"
        hex"b72ee05b7aa95237c28fcb176ce4003589617bb06a32822e3c81d104c39e00b9"
        hex"7a382fb13e43481fb1841bfdcc1032cb15ccd94989e1d1ff31b1e60be05cafc6"
        hex"e5100e7b664d8fa0e6af310f625dbaa15406214f069f03754e72a79de0ef4511"
        hex"ebd20961b99af5936e9b4d879310da158fd700305fae5bfc150ca872006c6497"
        hex"61f7ed51c22f55295be696e6f096f19eb5b7dd8529c4c8775732d9346fa6fae6"
        hex"3531609e802569ca903747fbbcd76248af74636d3f327c98cd37b598dde19353"
        hex"a43ef74cf8a451954839e92d42954ad6d1214194c7690787886b26c202f15f7e"
        hex"c4dd1b384d9307abd9991df07887aa098f5b589aca9a2032be40076a7e32a802"
        hex"62e62b8dfd2d55eb1d793c2e27ea369677afabd2b8c27543339832ba6fc8d1ed"
        hex"e461c452b6abc97e6afb64bad5e0588da1740cbce35cedf1997e892008b0cf0c"
        hex"ee3dc7dcc5b2c3f1fb323309a1528bdddc201dfcbaa77413d1af9b3dd4cb1ec4"
        hex"18bb4d497ac57991d87afb37da9bb6e60b199fe0edc97809086d44d1e93b7744"
        hex"43666cc93a6910c2a77bc3e85aa6323799015e306bd6cbfb26b25280bc3756c1"
        hex"8cf38ee463ad186431887ecb7a33200e6ee7c274d288bba89bf173964a6c1a17"
        hex"86e6c750812268cb7a787a9a61914291a7c4b826dec7121ce18513e36360548c"
        hex"3cfad283cd4f31605880761583f2af3252418644368ca275c859dd316d0e02e8"
        hex"c071557fc875a9a64689bf4c117bd57438f47cfb12b5df951a179a6d9507af76"
        hex"6371a63beffab4adbb68877d07688793981ebc0ed3284a38fadb653d2bd96607"
        hex"2f15567e818bffe1811bace59ed95bd936ee4990e068eb19cd3528c9ee1d4ef1"
        hex"57304cd32a2dee07f581a1eadab13d1cf1bb5dc471a46b0f05279ec8e052be0d"
        hex"2a494e937a84ccbc21c987c192a8f467ef1cc0961b479c3c7d9524389f6ad9b4"
        hex"4b2c2d576ce3d39534575b7ba6d1bb50dc1a8324c2b5c9a1fddd32090cf77d1d"
        hex"754fccd47de8b0aa0d47fd928fdc513ca70acd992dbe244c699cc12f01ad8b97"
        hex"3fc632a1ac93844b4806618a610b72285828519dab3dac0a177588d385c061bd"
        hex"41f115b19a55391c9f9006bf411919bdd534fd8f93ed7b12b7c8c5fc5c56069c"
        hex"2cd6f3774c95f3e661340bee90b6799f4056e643b57b12f0a1382d68a6334520"
        hex"10b5df7eb3c4da6d5145309c942e362b7ecfde8ca305463c74a710a119309a22"
        hex"d19cf532ba39abcb6345f69841ad4f2973b598beb1c40c9ef41773b1a5a98728"
        hex"6341e8a42987be6c14e3d5fab430114efcc440ccb955173b4399e6516c46fef1"
        hex"b69197b69e6538bb4e39c8acf6df9ebac6f71a1027d59ae461788242ee024fcd"
        hex"da52ced042224b31c642cf8696b8d0df190376edd92063cbea2e72d55709874a"
        hex"364f0257bc8925663335b97ffc18dd2e0bf020af21c7f7a50c215979cb04dd1a"
        hex"4e5faacfd74edb7f502555a4eb7986a9eef449b7e93cba2a188e521529f940bc"
        hex"e57a348058277bf636447d2e9d9d2dc7c80007e820f00746b3f69d104b7b813f"
        hex"e196eafdfb1f7fb57d6aa931eee7b5847114d7c249916f3c15fd9b4817bc3f8b"
        hex"740b2317bd39dbccf3579a55c6a4ccf7a30816a8b44eec7d2bbb6a07007ca3a7"
        hex"fa98a12196b3e76c6c789ec808a70e0a877fbeddaf68fe99e2fdd8b7153ed823"
        hex"83a28594775618f4d42872c98fecbf3a71038546d3bd04d943268f995200959a"
        hex"424b0218a83bfe3294ebe082707ca6a7fae1b24901f397ac536cbaab94422bc0"
        hex"6f473eb3013d71de7f64b1dff53548b55e768161c78df9fb27d622a77bac1013"
        hex"7f090e2114a8a351f80d0108f8a110b6fdc9fd6afc1a90bd34c70071147acb9b"
        hex"bd35763370978dfe9d068772ff5e6c21aa62b2bd4c1750c2917945a57ecfb4b8"
        hex"3dd80ca86c4e778010459ab88094e7ae5430e4d5af8b61d4451246b3b1ef2485"
        hex"add1f56a454d096ecd4fb6263ee2ea10bdf56c6a91605edb154652eb0ca2396d"
        hex"9c19ff80468804a61f2bc1f91ac3abf78aff65549cc3b90983158bfd75c89e4c"
        hex"6a80bf6a61f222aa35d4840188d3851ec60a9bee75df89ea9f9221aa42a8a6c4"
        hex"e4568ee90e5939f78c56ec78b1a4e1af38a358d0f0af6d38ec439ad45c907cab"
        hex"17f4fabf90a538824176756a261ec957d1cdb85aef916d79072b3fc7ef80868b"
        hex"e5f11fc1a3f70071dbb9d07d8fa9723975ecd2482f7f602cabcc2a6a76972c62"
        hex"aba3b4978b985f2bdf152b97f69888747c9049326dc8906f48de7a3e48eec21d"
        hex"25ef4d0911347dbb91e5246ed252343ffa319f560604eef7ae52b89555e8088c"
        hex"b158caf854aef834d95969c5f10deabfbb4f90263269815e9fc725443f1a5337"
        hex"0e159cccfab2687f67fcc1f97c129abe25d5c3c72a837780fadcce81d7343f63"
        hex"950ed28c84fe450a2a8bc921c75ed2f9323cd8ba94c815608706c5848a3b1f39"
        hex"27fbe19674b0a5da6f9dfc86716d2238aa7f2dd1c6a258239b58be6ce1aa26bd"
        hex"b1af56abcf554c054fbc6e3e5e6a6b35a9786a08bdff620f3d497a5fe52f4828"
        hex"3cd8bf2eea41d0b233504cc47b6c3ed4b5993e79e63a1e438893d264c710147b"
        hex"a437c614a500587256e49763728dee6e73989912ba7b5e0e8202693ee2610b28"
        hex"c3f4c49dc0a064e23a23aa2977a002789e2e62748c35f12c8938ae11b8f5a953"
        hex"b7cd4f26fa27a621c1051a69336278cef788427eb5acca0d167afa7d9275e611"
        hex"836ad6e03759aca419a71497921a8605a2e18a1af7f65e789e145ebb983cde65"
        hex"80bfd3f7980e516cfd6f0e4722c265e00dd27e8ca9c836c198fa1f6fb306faaa"
        hex"943eed5e647836f66e8ad46a4e4852574c866d0c8597ea25ea4e0f0e7637c829"
        hex"61f0193e095379965ff06df7f1d20683cfe99e8c6f6b8c0c0a0a29a662ce0599"
        hex"7785d5fe13330054c6894ab326d89e676ef29aabfd300e949678270e8090ec16"
        hex"dd031e8d5a08952fdd589b1701ba728425dcf60d4593938c3e76c8d06e50b4e3"
        hex"d9c4f8bd4aeeabade3999385b1f1d1659360c12cfb29d3cccc26a126336b5fa6"
        hex"b4fbbd559a54825965ba97eb2b055374127686d1fab5f113b0a20f220e4340c6"
        hex"afa3490385639b71129c7735c28a0e32aa3b56e7d7f57373ef97ab5de89a4087"
        hex"3a665cab02551a7053115fb661711a0d917b88ca3493ddd9745a30913797ccbb"
        hex"66b5d116e836c1cf753418c093b906697ca06f19b3e37983b45bdb1514400b26"
        hex"30ff84c5a1782c1815286d776a217d061531c6bd8487204d4c0c68d5d45b466e"
        hex"39cc14085bd3526f7554d6fdca5b156ae1fb1f56497713a18aa8b090f10fcea6"
        hex"0fcd1f5f267f6254e8082bf34673b5f4ad2eb47049f637a9b62dab529f282972"
        hex"b708c9e9d33fe9563c7f8b8122a885ad3648b0d03eb5a1cf0114e8f3f828bc2e"
        hex"c5f5ad09bdac9274004a94c9817dbbb6b804315b1a025c97aaf78e3f29bd5ffe"
        hex"1fc30df96f56c57807efe79952fbbcf46f2e639792d2b5d66cd77100613f6096"
        hex"c18b6e141c67b76454090dce742bbb60110d4f20d693e06cf755c4f8df0f9f5b"
        hex"47e739ce1bb7926c371988b59d4c9943ded1a4d590af7e2072e4148f3510403a"
        hex"41641261bd7bbd24405042b35871589d7ca28fb0df3f2492c80ef6eac3a7cd5a"
        hex"ff82e01a3f628b87e601abe04fa8a3f087512b91ddd7747ad63027478006e649"
        hex"e374c8e191b3eec60c4c138b32fe0d6edc1780546e07307c8e4db4567f5d18e4"
        hex"fd682e4a9274156a27e2a911d6c224e7c2fb7f3e7aff5d9eb32119e594041453"
        hex"79fc9394d34315aab2a2e7b9910861eb1842afb343074c3aac11282ee8fe549f"
        hex"cf20cabd2f1d8ce79f9f80871fd4f6005df7b02ca3297087d2d4283c0d406b08"
        hex"56e7c8d918f71056b95a8ccad256ffa95b8a61d1177512d7701551b949a1f323"
        hex"1ab03a9c16083f3d909fa6949416789caefaca95b37082bdf39b7a57e7109e47"
        hex"849afb4d9f0244adfee7f75316e47110487d1fb82841aa43eb64d80ba1c97483"
        hex"3d5a1717126d6aedc8acea0cf5ad82bc9bcd004e4a5cff0792a09d64cf8887de"
        hex"d3d13189c170e3a6e3a0d50386d305b709d3c02c7696b842127f90aa3d009cb2"
        hex"4addc33db36281ba3272ac504c64cb0a97d1e63135709e91c876a40bd28ca91d"
        hex"9b85a41ca90160af15f31d00d4c7de6573d8ba95fad343beb6fd6111a9842c79"
        hex"967d1cca6b3e361eb3885894ef36cb818cb6fa535c32bced6153d6c0032b8ca4"
        hex"5419e1055c54806f3a5af93de799450705c6de8c14fcb0aa683f672742115741"
        hex"81816aca27e8137921a6fa958c1a726668a3e3e226789c7ef742143e62eeb4b8"
        hex"e7389ec6f288cf33448d3a9d10a90c510cad7dbd89ad7649d283745c1d0cb67d"
        hex"d9281bc62937a61cb3aebc81a48e04414f6a6122b13e77af2322232b08076e4f"
        hex"7296ecce405b3c307b5277dd3d0e9d1a4ebfe2c89d44b578810fe6e0dcb99907";

    /// Unpacks `CI_COUNTEREXAMPLE_WORDS` into the fuzzed word list.
    function ciCounterexampleWords() internal pure returns (bytes32[] memory words) {
        bytes memory packed = CI_COUNTEREXAMPLE_WORDS;
        words = new bytes32[](packed.length / 0x20);
        for (uint256 i = 0; i < words.length; i++) {
            bytes32 word;
            assembly ("memory-safe") {
                word := mload(add(packed, add(0x20, mul(0x20, i))))
            }
            words[i] = word;
        }
    }

    /// Wraps `ciCounterexampleWords` as authoring meta with empty descriptions.
    function ciCounterexampleMetas() internal pure returns (AuthoringMetaV2[] memory metas) {
        bytes32[] memory words = ciCounterexampleWords();
        metas = new AuthoringMetaV2[](words.length);
        for (uint256 i = 0; i < words.length; i++) {
            metas[i] = AuthoringMetaV2({word: words[i], description: ""});
        }
    }

    /// `buildParseMetaV2` is internal, so reverts need an external boundary.
    function buildParseMetaV2External(AuthoringMetaV2[] memory authoringMeta, uint8 maxDepth)
        external
        pure
        returns (bytes memory)
    {
        return LibGenParseMeta.buildParseMetaV2(authoringMeta, maxDepth);
    }

    /// The pinned blob must still be the 114 word counterexample. Guards
    /// against the blob being edited to something that no longer collides,
    /// which would silently void every other test here.
    function testCiCounterexampleShape() external pure {
        bytes32[] memory words = ciCounterexampleWords();
        assertEq(words.length, 114, "word count");
        assertTrue(COLLIDING_INDEX_A < words.length, "index a in range");
        assertTrue(COLLIDING_INDEX_B < words.length, "index b in range");
    }

    /// The root cause, in two words: the pair is distinct, yet under
    /// `COLLIDING_SEED` both the expansion bit and the fingerprint match, so a
    /// single 4 byte meta item would have to stand for both of them.
    function testCiCounterexamplePairIsIndistinguishable() external pure {
        bytes32[] memory words = ciCounterexampleWords();
        bytes32 wordA = words[COLLIDING_INDEX_A];
        bytes32 wordB = words[COLLIDING_INDEX_B];
        assertTrue(wordA != wordB, "words are distinct");

        (uint256 bitmapA, uint256 hashedA) = LibParseMeta.wordBitmapped(COLLIDING_SEED, wordA);
        (uint256 bitmapB, uint256 hashedB) = LibParseMeta.wordBitmapped(COLLIDING_SEED, wordB);
        assertEq(bitmapA, bitmapB, "same expansion bit");
        assertEq(hashedA & FINGERPRINT_MASK, hashedB & FINGERPRINT_MASK, "same fingerprint");
    }

    /// The pair only collides under `COLLIDING_SEED`. Under the first seed it
    /// is representable, which is why the collision depends on which seeds
    /// `findBestExpander` happens to pick for the whole set.
    function testCiCounterexamplePairDistinguishableUnderSeedZero() external pure {
        bytes32[] memory words = ciCounterexampleWords();
        (uint256 bitmapA, uint256 hashedA) = LibParseMeta.wordBitmapped(0, words[COLLIDING_INDEX_A]);
        (uint256 bitmapB, uint256 hashedB) = LibParseMeta.wordBitmapped(0, words[COLLIDING_INDEX_B]);
        assertTrue(
            bitmapA != bitmapB || (hashedA & FINGERPRINT_MASK) != (hashedB & FINGERPRINT_MASK),
            "distinguishable under seed 0"
        );
    }

    /// Generation for the counterexample must revert with
    /// `DuplicateFingerprint`. This is the assertion the flaking fuzz test
    /// tripped over, recorded here as the intended outcome.
    function testCiCounterexampleBuildReverts() external {
        AuthoringMetaV2[] memory metas = ciCounterexampleMetas();
        vm.expectRevert(abi.encodeWithSelector(DuplicateFingerprint.selector));
        this.buildParseMetaV2External(metas, COUNTEREXAMPLE_DEPTH);
    }

    /// The guard the fuzz tests use must reject the counterexample.
    function testCiCounterexampleIsGuarded() external pure {
        assertTrue(LibParseMetaFingerprint.findsDupes(ciCounterexampleWords()), "guard must flag");
    }

    /// Dropping one of the two colliding words makes the set representable.
    /// This discriminates the guard from one that simply rejects every large
    /// set: 113 of the same 114 words pass, build, and round trip.
    function testCiCounterexampleBuildsWithoutCollidingWord() external pure {
        bytes32[] memory words = ciCounterexampleWords();
        bytes32[] memory reduced = new bytes32[](words.length - 1);
        uint256 j = 0;
        for (uint256 i = 0; i < words.length; i++) {
            if (i != COLLIDING_INDEX_B) {
                reduced[j] = words[i];
                j++;
            }
        }

        assertFalse(LibParseMetaFingerprint.findsDupes(reduced), "reduced set must pass the guard");

        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](reduced.length);
        for (uint256 i = 0; i < reduced.length; i++) {
            metas[i] = AuthoringMetaV2({word: reduced[i], description: ""});
        }
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, COUNTEREXAMPLE_DEPTH);
        for (uint256 i = 0; i < reduced.length; i++) {
            (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, reduced[i]);
            assertTrue(exists, "word should exist");
            assertEq(index, i, "index mismatch");
        }
    }
}
