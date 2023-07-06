// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * Store addresses and quotas of multi owners.
 * Here 1 'quota' denotes 1% of the ownership of the royalty in the following.
 * To reduce the complexity, NOT support float value of the quota.
 */
contract MultiOwnable {

    uint constant public MAX_OWNER_SIZE = 100;
    address[MAX_OWNER_SIZE] _ownerAddresses;
    uint _ownerSize;

    mapping(address => uint) _ownedQuotas;

    mapping(bytes32 => address[]) _pendingOperations;

    event PendingOperation(string opName, address indexed who, uint requireQuota, uint confirmedQuota);
    event ConfirmOperation(string opName, address indexed who, uint requireQuota, uint confirmedQuota);

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
        require(sum == 100);
        _ownerSize = initOwners.length;
    }

    modifier quotaAtLeast(uint requireQuota, bytes32 operation, string memory opName) {
        require(0 < requireQuota && requireQuota <= 100);
        if (checkWhetherConfirm(msg.sender, requireQuota, operation, opName)) {
            _;
        }
    }

    function checkWhetherConfirm(address who, uint requireQuota, bytes32 operation, string memory opName) internal returns(bool) {

        require(_ownedQuotas[who] > 0);           // Otherwise, not owner

        address[] memory participants = _pendingOperations[operation];  // copy storage to memory, saving gas in iteration
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

        if (confirmedQuota >= requireQuota) {
            delete _pendingOperations[operation];
            emit ConfirmOperation(opName, who, requireQuota, confirmedQuota);
            return true;
        }
        else {
            emit PendingOperation(opName, who, requireQuota, confirmedQuota);
            return false;
        }
    }

    // Return integer. 0 means not-owner
    function getOwnedQuota(address who) public view returns(uint) {
        return _ownedQuotas[who];
    }
}

