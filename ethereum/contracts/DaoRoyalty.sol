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

    constructor(
        address[] memory initOwners,
        uint[] memory initQuotas,
        string memory initTaleCode,
        uint256 initPurchasePrice,              // if 0, use default 0.01 ether;
        uint initPriceEarningRatio              // if 0, use default 2;
    ) Tradeable(initOwners, initQuotas) {
	    taleCode = initTaleCode;
	    if (initPurchasePrice > 0) {
	        validatePurchasePrice(initPurchasePrice);
	        purchasePrice = initPurchasePrice;
	    }
        if (initPriceEarningRatio > 0) {
            validatePriceEarningRatio(initPriceEarningRatio);
            priceEarningRatio = initPriceEarningRatio;
        }
	}

	function validatePurchasePrice(uint256 price) internal pure {
	    require(0 < price && price <= 100 ether);
	}

	function validatePriceEarningRatio(uint ratio) internal pure {
	    require(2 <= ratio && ratio <= 100);
	}

    // Require approval % > 1/2
    function setPurchasePrice(uint256 price) voteAtLeast(51, keccak256(msg.data), string("SET_PURCHASE_PRICE")) external {
        validatePurchasePrice(price);
        purchasePrice = price;
    }

    // Require approval % > 2/3
    function setPriceEarningRatio(uint ratio) voteAtLeast(67, keccak256(msg.data), string("SET_PRICE_EARNING_RATIO")) external {
        validatePriceEarningRatio(ratio);
        priceEarningRatio = ratio;
    }

}


