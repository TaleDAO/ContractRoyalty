// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Allocatable.sol";

/**
 * Users can purchase the chargeable tale-episodes on the contract
 * Owners can withdraw earnings by their quotas from the contract
 */
contract Profitable is Allocatable {

    uint256 public purchasePrice = 0.01 ether;
    uint256 public minWithdraw = 0.01 ether;
    uint256 public minRefund = 0.005 ether;

    struct Ledger {
        // the ETH already withdrawn by this owner
        uint withdrawn;

        // All quotas sold have corresponding profits, the total amount appears here.
        uint compensated;

        // Assume this owner bought quotas at time T1, the profit made before T1 belongs to its previous owner.
        // the new owner can never take those profit into account. The total amount is blocked here.
        uint silenced;
    }
    mapping(address => Ledger) _accountLedgers;
    uint256 _totalWithdrawn;

    event Purchase(address indexed who, uint256 value, address broker);
    event Withdraw(address indexed who, uint256 value);

	constructor(address[] memory initOwners, uint[] memory initQuotas)
	    Allocatable(initOwners, initQuotas) {
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

    // According to quotas owned, an owner can withdraw his whole profits in current time.
    // Not support withdraw a part of profits
    // Replace previous function named 'divvy'
    function withdraw() external returns(bool) {
        address who = msg.sender;
        uint256 totalBalance = address(this).balance + _totalWithdrawn;

        uint myQuota = _ownedQuotas[who];
        require(1 <= myQuota && myQuota <= 100);

        uint256 myProfits = totalBalance * myQuota / 100;
        Ledger storage l = _accountLedgers[who];
        uint256 myBalance = myProfits - l.withdrawn + l.compensated - l.silenced;

        if (myBalance >= minWithdraw) {
            // Note: 这里不可以设置 l.compensated = 0;
            l.withdrawn += myBalance;              // 这里需要测试一下
            _totalWithdrawn += myBalance;

            payable(who).transfer(myBalance);
            emit Withdraw(who, myBalance);

            return true;
        }
        else {
            return false;
        }
    }

    function settleProfit(address sellerAddress, address buyerAddress, uint dealQuota) internal {

        uint256 totalBalance = address(this).balance + _totalWithdrawn;
        uint256 profitToSettle = totalBalance * dealQuota / 100;

        Ledger storage sellerLedger = _accountLedgers[sellerAddress];
        sellerLedger.compensated += profitToSettle;    // No matter whether seller has withdrawn or not. The record should be ledged.

        Ledger storage buyerLedger = _accountLedgers[buyerAddress];
        buyerLedger.silenced += profitToSettle;
    }
}

