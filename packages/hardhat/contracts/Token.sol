// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing some useful aragon/osx contracts

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// Defining our DAO token contract
contract Token is ERC20, ERC20Snapshot, AccessControl, Pausable {
  // Defining some constants for our token

  // Defining some roles for our token
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // The role that can mint new tokens
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE"); // The role that can pause the token transfers
  bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE"); // The role that can take snapshots of the token balances

  // Defining the constructor for our token
  constructor() ERC20("AI DAO Token", "AID") {
    // Granting the deployer all the roles
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MINTER_ROLE, msg.sender);
    _setupRole(PAUSER_ROLE, msg.sender);
    _setupRole(SNAPSHOT_ROLE, msg.sender);

    // Minting some initial tokens for the deployer
    _mint(msg.sender, 1000000 * uint8(10) ** decimals());
  }

  // Required override from multiple inheritances
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20, ERC20Snapshot) {
    super._beforeTokenTransfer(from, to, amount);
    // Custom logic can be added here
  }

  // Defining a function to mint new tokens
  function mint(address to, uint256 amount) public {
    // Only allowing minters to call this function
    require(hasRole(MINTER_ROLE, msg.sender), "Token: must have minter role to mint");
    // Minting the tokens to the recipient
    _mint(to, amount);
  }

  // Defining a function to pause the token transfers
  function pause() public {
    // Only allowing pausers to call this function
    require(hasRole(PAUSER_ROLE, msg.sender), "Token: must have pauser role to pause");
    // Pausing the token transfers
    _pause();
  }

  // Defining a function to unpause the token transfers
  function unpause() public {
    // Only allowing pausers to call this function
    require(hasRole(PAUSER_ROLE, msg.sender), "Token: must have pauser role to unpause");
    // Unpausing the token transfers
    _unpause();
  }

  // Defining a function to take a snapshot of the token balances
  function snapshot() public returns (uint256) {
    // Only allowing snapshoters to call this function
    require(hasRole(SNAPSHOT_ROLE, msg.sender), "Token: must have snapshot role to snapshot");
    // Taking a snapshot of the token balances and returning the snapshot id
    return _snapshot();
  }

  // Overriding some functions from the ERC20 contract to add the pausable modifier
  function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
    return super.transfer(recipient, amount);
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override whenNotPaused returns (bool) {
    return super.transferFrom(sender, recipient, amount);
  }

  function approve(address spender, uint256 amount) public override whenNotPaused returns (bool) {
    return super.approve(spender, amount);
  }

  function increaseAllowance(address spender, uint256 addedValue) public override whenNotPaused returns (bool) {
    return super.increaseAllowance(spender, addedValue);
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public override whenNotPaused returns (bool) {
    return super.decreaseAllowance(spender, subtractedValue);
  }
}
