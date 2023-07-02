// SPDX-License-Identifier: MIT
// Solidity compiler to compile only from [v0.8.13, v0.9.0)
pragma solidity ^0.8.13;

import "./SafeMath.sol";
import "./MultiOwnable.sol";

/**
 * The Main Contract
 */
contract TaleDaoRoyalty is MultiOwnable {

    using SafeMath for uint256;

    // Serve for which tale verse
    bytes8 public verseCode;

    // On sale episode with its price
    bytes8 public episodeCode;
    uint256 public episodePrice;

    // Events
    // if _broker is null, it means _buyer purchased the compensable epicode in the contract directly
    event Purchase(address indexed _buyer, bytes8 _episode, address _broker);

	constructor(bytes8 _verseCode, address[] memory _owners, uint256[] memory _percents)
	    MultiOwnable(_owners, _percents) {

        verseCode = _verseCode;
	}

    function onSaleEpisode(bytes8 _episodeCode, uint256 _episodePrice) primaryOwner public {
        require(_episodePrice > 0);
        episodeCode = _episodeCode;
        episodePrice = _episodePrice;
    }

    function offSaleEpisode() primaryOwner public returns (bool) {
        if (episodePrice > 0) {
            episodeCode = "";
            episodePrice = 0;
            return true;
        }
        else {
            return false;
        }
    }

    // Called by the reader for the compensable epicode
    function buy() payable public {
        require(episodePrice > 0);
        require(msg.value >= episodePrice);

        // Refund excess money if more than a threshold
        uint256 excessAmount = msg.value - episodePrice;
        if (excessAmount > 0.01 ether) {
            payable(msg.sender).transfer(excessAmount);   // Prevent using call() or send()
        }

        // TaleDAO deamon listens the event, and would let the player pass after receiving
        emit Purchase(msg.sender, episodeCode, address(0x0));
    }

    // Called by the broker who writes back the purchased incomes & events in batches every day
    function buyRollUps(address[] memory buyers) payable public {
        require(buyers.length > 0);
        require(msg.value >= episodePrice * buyers.length);
        for (uint i=0; i<buyers.length; ++i) {
            emit Purchase(buyers[i], episodeCode, msg.sender);
        }
    }

    // Send the income to co-owners by their ratios
    function divvy() primaryOwner public {
        uint256 balanceTotal = address(this).balance;
        uint256 balanceRemain = balanceTotal;
        for (uint i=0; i<co_owner_num - 1; ++i) {
            uint256 income = balanceTotal.mul(percents[i]).div(100);
            payable(owners[i]).transfer(income);
            balanceRemain -= income;
        }
        // The income of last owner do not use the value computed by multiply & divide,
        // preventing from latent exceptions caused by accuracy loss
        payable(owners[co_owner_num - 1]).transfer(balanceRemain);
    }
}
