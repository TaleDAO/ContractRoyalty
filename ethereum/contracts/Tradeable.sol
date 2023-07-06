// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Profitable.sol";


contract Tradeable is Profitable {

    // Use this value to approximately estimate the price of ownerships when buying
    // Why the value is very lower by default? Because:
    // Different from traditional PER, the EARNING in this value summarize all historical profits, not ONE year.
    uint public priceEarningRatio = 2;

    uint256 public minPricePerQuota = 0.01 ether;

	constructor(address[] memory initOwners, uint[] memory initQuotas)
	    Profitable(initOwners, initQuotas) {
	}

    // Randomly select allowed quotes to trade until budget is used up
    // Return how many quotes bought.
    function buyQuota() payable public returns(uint) {

        // some preparations
        address buyerAddress = msg.sender;
        uint boughtQuota = 0;

        // select all addresses having quotas on sales into memory
        address[MAX_OWNER_SIZE] memory candidateAddresses;
        uint[MAX_OWNER_SIZE] memory candidateQuotas;
        uint candidateSize = 0;
        for (uint i=0; i<_ownerSize; i++) {
            address a = _ownerAddresses[i];
            uint q = _allowedQuotas[a];
            if (q > 0) {
                candidateAddresses[candidateSize] = a;
                candidateQuotas[candidateSize] = q;
                candidateSize ++;
            }
        }

        // if no portion on sales: 1.stop execution  2.revert the ETH sent  3.return remaining gas
        require(candidateSize > 0, "NO_QUOTA_AVAILABLE");

        // compute the current price for each portion
        uint256 totalBalance = address(this).balance + _totalWithdrawn;
        uint256 pricePerQuota = totalBalance * priceEarningRatio / 100;
        if (pricePerQuota < minPricePerQuota) {
            pricePerQuota = minPricePerQuota;
        }
        uint wantQuotaRemain = uint(msg.value / pricePerQuota);

        // begin the main loop
        uint randomIndex = block.timestamp;
        uint loops = 0;
        while (loops < candidateSize && wantQuotaRemain > 0) {
            loops ++;

            // no-repeat & approximate-random selection of the one of candidateAddresses
            randomIndex = (randomIndex + 997) % candidateSize;   // 997 is an any prime bigger than MAX_OWNER_SIZE

            address sellerAddress = candidateAddresses[randomIndex];
            uint sellerQuota = candidateQuotas[randomIndex];
            uint dealQuota = (wantQuotaRemain > sellerQuota ? sellerQuota : wantQuotaRemain);
            assert(dealQuota > 0);

            // settle profile correspond to trading quotas
            settleProfit(sellerAddress, buyerAddress, dealQuota);

            // settle payment of trading quotas
            _accountLedgers[sellerAddress].compensated += pricePerQuota * dealQuota;

            // allocate quotas
            allocateQuota(sellerAddress, buyerAddress, dealQuota);

            // compute remain
            wantQuotaRemain -= dealQuota;
            boughtQuota += dealQuota;
        }

        // remain budget as buyer's compensated
        _accountLedgers[buyerAddress].compensated += msg.value - pricePerQuota * boughtQuota;

        return boughtQuota;
    }
}
