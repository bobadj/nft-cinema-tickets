// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

library Block {
    /**
    * Gets chain name by chainID
    *
    * @param _chainID - ID of a chain
    *
    * @return chain name (string)
    */
    function chainName(uint256 _chainID) internal pure returns (string memory) {
        string memory name = "undefined";
        if (_chainID == 5)
            name = "goerli";
        return name;
    }
}
