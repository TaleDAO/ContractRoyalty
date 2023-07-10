// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./MultiOwnable.sol";

/**
 * Users can purchase the chargeable tale-episodes on the contract
 * Owners can withdraw earnings by their quotas from the contract
 */
contract Profitable is MultiOwnable {

    uint256 public purchasePrice = 0.01 ether;
    uint256 public minWithdraw = 0.01 ether;
    uint256 public minRefund = 0.005 ether;

    struct Ledger {
        // The ETH already withdrawn by this owner
        uint withdrawn;

        // All quotas sold have corresponding profits, the total amount appears here.
        uint compensated;

        // Assume a new owner buy quotas at time T1, the profit made before T1 belongs to its previous owner.
        // The new owner can never take those profit into account. The total amount is blocked here.
        uint silenced;
    }
    mapping(address => Ledger) _accountLedgers;

    uint256 public totalWithdrawn;

    // The amount cannot be treated as profits. (e.g. income from traded-quotas, which only belongs to one certain owner)
    uint256 public totalInvested;

    event Purchase(address indexed who, uint256 value, address broker);
    event Withdraw(address indexed who, uint256 value);

	constructor(address[] memory initOwners, uint[] memory initQuotas)
	    MultiOwnable(initOwners, initQuotas) {
	}

	function sumProfit() public view returns(uint256) {
	    uint256 profitComputed = address(this).balance + totalWithdrawn - totalInvested;
	    return profitComputed;
	}

	receive() payable external {
        require(msg.value >= purchasePrice);

        address who = msg.sender;

        // Refund excess money if more than a threshold
        uint256 excessAmount = msg.value - purchasePrice;
        if (excessAmount >= minRefund) {
            payable(who).transfer(excessAmount);   // Prevent using call() or send()
        }

        emit Purchase(who, msg.value, address(0x0));
    }

    // Called by the broker who writes back the purchased incomes & events in batches every day
    // Replace previous function named 'buyRollUps'
    function receiveFrom(address[] memory buyers) payable public {
        address brokerAddress = msg.sender;
        require(buyers.length > 0);
        require(purchasePrice * buyers.length <= msg.value && msg.value < purchasePrice * buyers.length + minRefund);

        for (uint i=0; i<buyers.length; ++i) {
            emit Purchase(buyers[i], purchasePrice, brokerAddress);
        }
    }

    function getBalance(address who) public view returns(uint256) {
        uint256 profitComputed = sumProfit();
        uint myQuota = _ownedQuotas[who];

        uint256 myProfits = profitComputed * myQuota / 100;
        Ledger storage l = _accountLedgers[who];
        uint256 myBalance = myProfits + l.compensated - l.withdrawn - l.silenced;

        return myBalance;
    }

    // According to ledgers, an owner(or previous owner) can withdraw his whole profits
    // Not support withdraw a part of profits
    // Replace previous function named 'divvy'
    function withdraw() external returns(bool) {
        address who = msg.sender;

        uint myQuota = _ownedQuotas[who];

        // All depend the amount of computed balance.
        uint256 myBalance = getBalance(who);

        // Should be the owner in current, or previous owner but something remained.
        require(myQuota > 0 || myBalance > 0, "NOTHING_WITHDRAW");

        if (myBalance >= minWithdraw) {
            Ledger storage l = _accountLedgers[who];
            // Caution that here cannot set l.compensated = 0 ! need more testcases
            l.withdrawn += myBalance;
            totalWithdrawn += myBalance;

            payable(who).transfer(myBalance);
            emit Withdraw(who, myBalance);

            return true;
        }
        else {
            return false;
        }
    }

    function settleProfit(address sellerAddress, address buyerAddress, uint dealQuota) internal {

        uint256 profitComputed = sumProfit();
        uint256 profitToSettle = profitComputed * dealQuota / 100;

        Ledger storage sellerLedger = _accountLedgers[sellerAddress];
        sellerLedger.compensated += profitToSettle;    // No matter whether seller has withdrawn or not. The amount should be ledged.

        Ledger storage buyerLedger = _accountLedgers[buyerAddress];
        buyerLedger.silenced += profitToSettle;
    }
}

