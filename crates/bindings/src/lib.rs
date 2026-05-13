//! Alloy Solidity contract bindings for rainlang.

use alloy::sol;

sol!(
    #![sol(all_derives = true)]
    IInterpreterV4,
    "../abi/IInterpreterV4.json"
);

sol!(
    #![sol(all_derives = true)]
    IInterpreterStoreV3,
    "../abi/IInterpreterStoreV3.json"
);

sol!(
    #![sol(all_derives = true)]
    IParserV2, "../abi/IParserV2.json"
);

sol!(
    #![sol(all_derives = true)]
    IParserPragmaV1, "../abi/IParserPragmaV1.json"
);

sol!(
    #![sol(all_derives = true)]
    IExpressionDeployerV3,
    "../abi/IExpressionDeployerV3.json"
);

sol!(
    #![sol(all_derives = true)]
    Rainlang,
    "../abi/Rainlang.json"
);
