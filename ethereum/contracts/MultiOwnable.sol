// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * Store addresses and quotas of multi owners.
 * Here 1 'quota' denotes 1% of the ownership of the royalty in the following.
 * To reduce the complexity, NOT support float value of the quota.
 *
 * In 'voteAtLeast', once an operation is confirmed, all historical pending operations, including other 'labels', would be cleared.
 */
contract MultiOwnable {

    uint constant public MAX_OWNER_SIZE = 100;
    address[MAX_OWNER_SIZE] _ownerAddresses;
    uint _ownerSize;

    mapping(address => uint) _ownedQuotas;

    mapping(bytes32 => address[]) _pendingOperations;
    bytes32[] _operationKeys;

    event PendingOperation(string label, address indexed who, uint requireQuota, uint confirmedQuota);
    event ConfirmOperation(string label, address indexed who, uint requireQuota, uint confirmedQuota);

    constructor(address[] memory initOwners, uint[] memory initQuotas) {
        require(0 < initOwners.length && initOwners.length <= MAX_OWNER_SIZE);
        require(initOwners.length == initQuotas.length);

        uint sum = 0;
        for (uint i=0; i<initOwners.length; i++) {
            address a = initOwners[i];
            _ownerAddresses[i] = a;
            _ownedQuotas[a] = initQuotas[i];
            sum += initQuotas[i];
        }
        require(sum == 100, "SUN_NOT_100_PERCENT");
        _ownerSize = initOwners.length;
    }

    modifier voteAtLeast(uint requireQuota, bytes32 operation, string memory label) {
        require(0 < requireQuota && requireQuota <= 100);
        if (checkVotedQuotas(msg.sender, requireQuota, operation, label)) {
            _;
        }
    }

    function checkVotedQuotas(address who, uint requireQuota, bytes32 operation, string memory label) internal returns(bool) {

        require(_ownedQuotas[who] > 0);           // Otherwise, not owner

        address[] memory participants = _pendingOperations[operation];  // copy storage to memory, saving gas in iteration
        if (participants.length == 0) {
            _operationKeys.push(operation);
        }

        // Summarize quotas
        uint confirmedQuota = 0;
        bool isMyConfirmed = false;
        for (uint i=0; i<participants.length; i++) {
            address p = participants[i];
            if (p == who) {
                isMyConfirmed = true;
            }
            confirmedQuota += _ownedQuotas[p];
        }
        if (! isMyConfirmed) {
            _pendingOperations[operation].push(who);
            confirmedQuota += _ownedQuotas[who];
        }

        // Judge
        if (confirmedQuota >= requireQuota) {

            for (uint i=0; i<_operationKeys.length; i++) {
                delete _pendingOperations[_operationKeys[i]];
            }
            delete _operationKeys;

            emit ConfirmOperation(label, who, requireQuota, confirmedQuota);
            return true;
        }
        else {
            emit PendingOperation(label, who, requireQuota, confirmedQuota);
            return false;
        }
    }

    // Return integer. 0 means not-owner
    function getOwnedQuota(address who) public view returns(uint) {
        return _ownedQuotas[who];
    }
}

