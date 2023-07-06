// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./MultiOwnable.sol";


contract Allocatable is MultiOwnable {

    mapping(address => uint) _allowedQuotas;

    event UpdateQuota(address indexed who, uint previous, uint current);

    event RemoveOwner(address indexed who);
    event AppendOwner(address indexed who);
    event AllocateQuota(address indexed fromOwner, address indexed toOwner, uint quotaToAllocate, uint fromOwnerRemains, uint toOwnerRemains);

	constructor(address[] memory initOwners, uint[] memory initQuotas)
	    MultiOwnable(initOwners, initQuotas) {
	}

    // Any owner can set how many its quotas can be allocated
    function setAllowedQuota(uint allowedQuota) public {
        address who = msg.sender;
        require(0 < allowedQuota && allowedQuota <= 100);
        require(_ownedQuotas[who] >= allowedQuota);

        uint previousQuota = _allowedQuotas[who];
        _allowedQuotas[who] = allowedQuota;

        emit UpdateQuota(who, previousQuota, allowedQuota);
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
    function allocateQuota(address fromOwner, address toOwner, uint quotaToAllocate) internal {
        require(fromOwner != toOwner);
        require(0 < quotaToAllocate && quotaToAllocate <= 100);

        // validate fromOwner
        uint fromOwnerQuota = _ownedQuotas[fromOwner];
        uint fromOwnerAllowed = _allowedQuotas[fromOwner];
        require(fromOwnerQuota >= quotaToAllocate);
        require(fromOwnerAllowed >= quotaToAllocate);

        // reduce amount from fromOwner
        if (fromOwnerQuota == quotaToAllocate) {
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
            _ownedQuotas[fromOwner] = fromOwnerQuota - quotaToAllocate;
            _allowedQuotas[fromOwner] = fromOwnerAllowed - quotaToAllocate;
        }

        // add amount to toOwner
        uint toOwnerQuota = _ownedQuotas[toOwner];
        if (toOwnerQuota == 0) {
            // append a position for the new owner
            _ownerAddresses[_ownerSize] = toOwner;
            _ownerSize ++;
            _ownedQuotas[toOwner] = quotaToAllocate;
            _allowedQuotas[toOwner] = 0;     // this step can be ignored for saving gas.

            emit AppendOwner(toOwner);
        }
        else {
            // if not new, plus amount
            _ownedQuotas[toOwner] += quotaToAllocate;
        }

        emit AllocateQuota(fromOwner, toOwner, quotaToAllocate, _ownedQuotas[fromOwner], _ownedQuotas[toOwner]);
    }
}



