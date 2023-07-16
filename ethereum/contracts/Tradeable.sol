// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Profitable.sol";


contract Tradeable is Profitable {

    // Use this value to approximately estimate the price of ownerships when buying.
    // Why the value is very lower by default ?
    // Because different from traditional PER, the EARNING in this value summarize all historical profits, not ONE year.
    uint public priceEarningRatio = 2;

    // At the very begin, no one paid. The balance of contract is zero.
    // Preventing the price computed for 1 quota is zero too, this value is used as a minimum value.
    uint256 public minPricePerQuota = 0.01 ether;

    // The quotas (allowed by current owners) are on sales to latent new owners by investing ETHs
    mapping(address => uint) _allowedQuotas;

    event AllowQuota(address indexed who, uint previous, uint current);

    event RemoveOwner(address indexed who);
    event AppendOwner(address indexed who);
    event MoveQuota(address indexed fromOwner, address indexed toOwner, uint quotaToMove, uint fromOwnerQuota, uint toOwnerQuota);

	constructor(address[] memory initOwners, uint[] memory initQuotas)
	    Profitable(initOwners, initQuotas) {
	}

    // Any owner can set how many its quotas can be traded
    function setAllowedQuota(uint allowedQuota) public {
        address who = msg.sender;
        require(0 < allowedQuota && allowedQuota <= 100);
        require(_ownedQuotas[who] >= allowedQuota, "NOT_ENOUGH");

        uint previousQuota = _allowedQuotas[who];
        _allowedQuotas[who] = allowedQuota;

        emit AllowQuota(who, previousQuota, allowedQuota);
    }

    function getAllowedQuota(address who) public view returns(uint) {
        return _allowedQuotas[who];
    }

    // Total quotas now allocatable.
    function sumAllowedQuota() public view returns(uint) {
        uint sum = 0;
        for (uint i=0; i<_ownerSize; i++) {
            sum += _allowedQuotas[_ownerAddresses[i]];
        }
        assert(sum <= 100);
        return sum;
    }

    // Transfer the part or whole of quotas from A to B, based on the amount allowed by A.
    // The function is expected to be called internally by sub-class contracts, not externally.
    function moveQuota(address fromOwner, address toOwner, uint quotaToMove) internal {
        require(fromOwner != toOwner);
        require(0 < quotaToMove && quotaToMove <= 100);

        // Validate fromOwner
        uint fromOwnerQuota = _ownedQuotas[fromOwner];
        require(fromOwnerQuota >= quotaToMove, "LACK_OF_QUOTA");

        // Reduce amount from fromOwner
        if (fromOwnerQuota == quotaToMove) {
            // Remove fromOwner when it would reduce all its quotas
            delete _ownedQuotas[fromOwner];

            // Use last one to replace it in the table of addresses
            uint fromOwnerIndex = _ownerSize;
            for (uint i=0; i<_ownerSize; i++) {
                if (_ownerAddresses[i] == fromOwner) {
                    fromOwnerIndex = i;
                    break;
                }
            }
            assert(fromOwnerIndex < _ownerSize);
            _ownerSize --;
            if (fromOwnerIndex != _ownerSize)   {
                _ownerAddresses[fromOwnerIndex] = _ownerAddresses[_ownerSize];
            }
            _ownerAddresses[_ownerSize] = address(0x0);

            emit RemoveOwner(fromOwner);
        }
        else {
            // Reduce fromOwner's quota
            _ownedQuotas[fromOwner] = fromOwnerQuota - quotaToMove;
        }

        // Add amount to toOwner
        uint toOwnerQuota = _ownedQuotas[toOwner];
        if (toOwnerQuota == 0) {
            // Append a position for the new owner
            _ownerAddresses[_ownerSize] = toOwner;
            _ownerSize ++;
            _ownedQuotas[toOwner] = quotaToMove;

            emit AppendOwner(toOwner);
        }
        else {
            // If not new, plus amount
            _ownedQuotas[toOwner] += quotaToMove;
        }

        emit MoveQuota(fromOwner, toOwner, quotaToMove, _ownedQuotas[fromOwner], _ownedQuotas[toOwner]);
    }

    // Compute the current price for each portion
    function getPricePerQuota() public view returns(uint256) {
        uint256 profitComputed = sumProfit();
        uint256 pricePerQuota = profitComputed * priceEarningRatio / 100;
        if (pricePerQuota < minPricePerQuota) {
            pricePerQuota = minPricePerQuota;
        }
        return pricePerQuota;
    }

    // To fairness, RANDOMLY select allowed quotes to trade until the budget is used up
    // Return how many quotes acquired.
    function investForQuota() payable external returns(uint) {

        require(! isTerminated, "TERMINATED");

        // Before calling this function, EVM has already added the value(ETH) of this transaction on the contract balance.
        // Because investment cannot be treated as profits in following computing,
        // the value should be counted at the beginning then excluded in the following.
        totalSilenced += msg.value;

        // Some preparations
        address investorAddress = msg.sender;
        uint acquiredQuota = 0;

        // Select all addresses having quotas on sales into memory
        address[MAX_OWNER_SIZE] memory candidateAddresses;
        uint[MAX_OWNER_SIZE] memory candidateAllowedQuotas;
        uint candidateSize = 0;
        for (uint i=0; i<_ownerSize; i++) {
            address a = _ownerAddresses[i];
            uint q = _allowedQuotas[a];
            if (q > 0) {
                candidateAddresses[candidateSize] = a;
                candidateAllowedQuotas[candidateSize] = q;
                candidateSize ++;
            }
        }

        // If no portion on sales: 1.stop execution  2.revert the ETH sent  3.return remaining gas
        require(candidateSize > 0, "NO_QUOTA_AVAILABLE");

        // Compute the new owner can buy how many quotas by his budget
        uint256 pricePerQuota = getPricePerQuota();
        uint wantQuotaRemain = uint(msg.value / pricePerQuota);

        // Begin the main loop
        uint randomIndex = block.timestamp;
        uint loops = 0;
        while (loops < candidateSize && wantQuotaRemain > 0) {
            loops ++;

            // No-repeat & approximate-random selection of the one of candidateAddresses
            randomIndex = (randomIndex + 997) % candidateSize;   // 997 is an any prime bigger than MAX_OWNER_SIZE

            address sellerAddress = candidateAddresses[randomIndex];
            uint sellerAllowedQuota = candidateAllowedQuotas[randomIndex];
            uint dealQuota = (wantQuotaRemain > sellerAllowedQuota ? sellerAllowedQuota : wantQuotaRemain);
            assert(dealQuota > 0);

            // Settle profile correspond to trading quotas
            settleProfit(sellerAddress, investorAddress, dealQuota);

            // Settle payment of trading quotas
            _accountLedgers[sellerAddress].compensated += pricePerQuota * dealQuota;

            // Deliver quotas
            moveQuota(sellerAddress, investorAddress, dealQuota);
            _allowedQuotas[sellerAddress] = sellerAllowedQuota - dealQuota;

            // Compute remain
            wantQuotaRemain -= dealQuota;
            acquiredQuota += dealQuota;
        }

        // Save the budget remained into investor's compensated
        _accountLedgers[investorAddress].compensated += msg.value - pricePerQuota * acquiredQuota;

        return acquiredQuota;
    }

    // The caller who gives 'dealQuota' to the 'newOwner' freely should have enough quota (>= dealQuota)
    function giftAwayQuota(address newOwner, uint dealQuota) external {
        require(! isTerminated, "TERMINATED");
        require(0 < dealQuota);
        address senderAddress = msg.sender;
        uint oq = _ownedQuotas[senderAddress];
        require(oq >= dealQuota);

        // Settle profile correspond to trading quotas
        settleProfit(senderAddress, newOwner, dealQuota);

        // Deliver quotas
        moveQuota(senderAddress, newOwner, dealQuota);

        // Gift does NOT cost the amount of allowed quotas.
        // But need to ensure the allowed quota would not exceed the new owned quota
        oq -= dealQuota;
        assert(oq == _ownedQuotas[senderAddress]);
        uint aq = _allowedQuotas[senderAddress];
        if (aq > oq) {
            _allowedQuotas[senderAddress] = oq;
        }

    }

}

