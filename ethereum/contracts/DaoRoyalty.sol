// SPDX-License-Identifier: MIT
// Solidity compiler to compile only from [v0.8.13, v0.9.0)
// https://docs.soliditylang.org/en/v0.8.19/style-guide.html
pragma solidity ^0.8.13;

import "./Tradeable.sol";

/**
 * The Main Contract
 */
contract DaoRoyalty is Tradeable {

    string public taleCode;

    constructor(string memory initTaleCode, address[] memory initOwners, uint[] memory initQuotas)
	    Tradeable(initOwners, initQuotas) {
	    taleCode = initTaleCode;
	}

    // Require approval % > 1/2
    function setPurchasePrice(uint256 price) quotaAtLeast(51, keccak256(msg.data), string("SET_PURCHASE_PRICE")) external {
        require(0 < price && price <= 100 ether);
        purchasePrice = price;
    }

    // Require approval % > 2/3
    function setPriceEarningRatio(uint ratio) quotaAtLeast(67, keccak256(msg.data), string("SET_PRICE_EARNING_RATIO")) external {
        require(2 <= ratio && ratio <= 100);
        priceEarningRatio = ratio;
    }

}


