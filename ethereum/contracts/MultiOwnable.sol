// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * Store addresses and percents of co-owners
 */
contract MultiOwnable {

    // Current royalties
    uint constant internal CO_OWNER_MAX = 10;
    uint internal co_owner_num;
    address[CO_OWNER_MAX + 1] internal owners;
    uint256[CO_OWNER_MAX + 1] internal percents;

    // TaleDAO official shares 1% royalty of this verse constantly
    address constant internal taleDaoTreasury = 0xE4B33BF97A9f4D7CF0766a38CB767bE757462065;

	constructor(address[] memory _owners, uint256[] memory _percents) {

	    require(_owners.length == _percents.length);
	    require(_owners.length <= CO_OWNER_MAX);

	    uint totalPercent = 0;

	    for (uint i=0; i<_percents.length; ++i) {
	        totalPercent += _percents[i];
	        owners[i] = _owners[i];
	        percents[i] = _percents[i];
        }
        totalPercent += 1;
        owners[_owners.length] = taleDaoTreasury;
        percents[_owners.length] = 1;

        // After init, all percerts should be 100%
        require(totalPercent == 100);

        co_owner_num = _owners.length + 1;
	}

	modifier primaryOwner() {
	    // tx.origin is always wallet address, msg.sender can be both wallet address and another contract address
        require(msg.sender == owners[0]);
        _;
    }
}

