pragma solidity ^0.8.0;

import "@aragon/os/contracts/apps/AragonApp.sol";
contract HashDAO is AragonApp {
    using SafeMath for uint256;

    bytes32 constant public INCREMENT_ROLE = keccak256("INCREMENT_ROLE");
    bytes32 constant public DECREMENT_ROLE = keccak256("DECREMENT_ROLE");


    function initialize(uint256 _initValue) public onlyInit {
        value = _initValue;

        initialized();
    }

    function increment(uint256 step) auth(INCREMENT_ROLE) external {
        // ...
        value = value.add(step);
        emit Increment(msg.sender, step);
    }

    function decrement(uint256 step) auth(DECREMENT_ROLE) external {
        // ...
        value = value.sub(step);
        emit Decrement(msg.sender, step);
    }

}