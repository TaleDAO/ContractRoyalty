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

    mapping(address => uint) _allowedQuotas;

    event AllowQuota(address indexed who, uint previous, uint current);

    event RemoveOwner(address indexed who);
    event AppendOwner(address indexed who);
    event MoveQuota(address indexed fromOwner, address indexed toOwner, uint quotaToMove, uint fromOwnerRemains, uint toOwnerRemains);

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

        // validate fromOwner
        uint fromOwnerQuota = _ownedQuotas[fromOwner];
        uint fromOwnerAllowed = _allowedQuotas[fromOwner];
        require(fromOwnerQuota >= quotaToMove, "LACK_OF_QUOTA");
        require(fromOwnerAllowed >= quotaToMove, "LACK_OF_ALLOW");

        // reduce amount from fromOwner
        if (fromOwnerQuota == quotaToMove) {
            // remove fromOwner when it would reduce all its quotas
            delete _ownedQuotas[fromOwner];
            delete _allowedQuotas[fromOwner];

            // use last one to replace it in the table of addresses
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
            // reduce fromOwner's quota
            _ownedQuotas[fromOwner] = fromOwnerQuota - quotaToMove;
            _allowedQuotas[fromOwner] = fromOwnerAllowed - quotaToMove;
        }

        // add amount to toOwner
        uint toOwnerQuota = _ownedQuotas[toOwner];
        if (toOwnerQuota == 0) {
            // append a position for the new owner
            _ownerAddresses[_ownerSize] = toOwner;
            _ownerSize ++;
            _ownedQuotas[toOwner] = quotaToMove;
            _allowedQuotas[toOwner] = 0;     // this step can be ignored for saving gas.

            emit AppendOwner(toOwner);
        }
        else {
            // if not new, plus amount
            _ownedQuotas[toOwner] += quotaToMove;
        }

        emit MoveQuota(fromOwner, toOwner, quotaToMove, _ownedQuotas[fromOwner], _ownedQuotas[toOwner]);
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

            // move quotas
            moveQuota(sellerAddress, buyerAddress, dealQuota);

            // compute remain
            wantQuotaRemain -= dealQuota;
            boughtQuota += dealQuota;
        }

        // remain budget as buyer's compensated
        _accountLedgers[buyerAddress].compensated += msg.value - pricePerQuota * boughtQuota;

        return boughtQuota;
    }
}
