// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing the DAO.sol contract from the aragon osx library
import "@aragon/osx/core/dao/DAO.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Token.sol";

// Defining our voter contract that inherits from DAO
contract Voter is DAO {
  // Defining the token used for voting
  Token public votingToken;

  // Defining the voting parameters
  uint256 public constant quorum = 50; // 50%
  uint256 public constant passRate = 60; // 60%
  uint256 public constant voteDuration = 24 hours; // 24 hours

  // Defining the events emitted by the contract
  event ProposalCreated(uint256 proposalId, address proposer, string description);
  event VoteCast(uint256 proposalId, address voter, uint256 amount, bool support);
  event VoteWithdrawn(uint256 proposalId, address voter, uint256 amount);
  event ProposalExecuted(uint256 proposalId, bool result);
  event DelegateChanged(address voter, address delegate);

  // Defining the structure of a proposal
  struct Proposal {
    address proposer; // The address that created the proposal
    string description; // A short description of the proposal
    uint256 startTime; // The timestamp when the proposal was created
    uint256 endTime; // The timestamp when the voting period ends
    uint256 forVotes; // The total amount of tokens voted in favor of the proposal
    uint256 againstVotes; // The total amount of tokens voted against the proposal
    bool executed; // A flag indicating whether the proposal has been executed or not
    bool result; // The result of the proposal (true = passed, false = failed)
  }

  // Defining the structure of a vote
  struct Vote {
    uint256 amount; // The amount of tokens voted by the voter
    bool support; // The support flag of the vote (true = for, false = against)
  }

  // Defining an array to store all the proposals
  Proposal[] public proposals;

  // Defining a mapping to store the votes cast by each address for each proposal
  mapping(uint256 => mapping(address => Vote)) public votes;

  // Defining a mapping to store the delegation status of each address
  mapping(address => address) public delegates;

  // Defining a modifier to check if the caller is a valid voter (has some voting tokens)
  modifier onlyVoter() {
    require(votingToken.balanceOf(msg.sender) > 0, "Voter: not a valid voter");
    _;
  }

  // Defining a modifier to check if a proposal exists
  modifier proposalExists(uint256 proposalId) {
    require(proposalId < proposals.length, "Voter: proposal does not exist");
    _;
  }

  // Defining a modifier to check if a proposal is active (voting period is not over)
  modifier proposalActive(uint256 proposalId) {
    require(block.timestamp < proposals[proposalId].endTime, "Voter: proposal not active");
    _;
  }

  // Defining a modifier to check if a proposal is inactive (voting period is over)
  modifier proposalInactive(uint256 proposalId) {
    require(block.timestamp >= proposals[proposalId].endTime, "Voter: proposal not inactive");
    _;
  }

  // Defining a modifier to check if a proposal is pending (not executed yet)
  modifier proposalPending(uint256 proposalId) {
    require(!proposals[proposalId].executed, "Voter: proposal already executed");
    _;
  }

  // Defining a constructor to initialize the contract with the voting token address
  constructor(address _votingToken) {
    votingToken = Token(_votingToken);
  }

  // Defining a function to create a new proposal
  function createProposal(string memory _description) public onlyVoter returns (uint256) {
    // Creating a new proposal with the given description and current time
    Proposal memory newProposal = Proposal({
      proposer: msg.sender,
      description: _description,
      startTime: block.timestamp,
      endTime: block.timestamp + voteDuration,
      forVotes: 0,
      againstVotes: 0,
      executed: false,
      result: false
    });

    // Pushing the new proposal to the proposals array and getting its id
    uint256 proposalId = proposals.length;
    proposals.push(newProposal);

    // Emitting an event to notify the creation of the new proposal
    emit ProposalCreated(proposalId, msg.sender, _description);

    // Returning the id of the new proposal
    return proposalId;
  }

  // Defining a function to vote on a proposal
  function vote(
    uint256 proposalId,
    bool support
  ) public onlyVoter proposalExists(proposalId) proposalActive(proposalId) {
    // Getting the amount of tokens held by the voter
    uint256 amount = votingToken.balanceOf(msg.sender);

    // Checking if the voter has already voted on this proposal
    Vote memory previousVote = votes[proposalId][msg.sender];
    if (previousVote.amount > 0) {
      // If yes, then withdraw the previous vote first
      withdrawVote(proposalId);
    }

    // Checking if the voter has delegated their vote to another address
    address _delegate = delegates[msg.sender];
    if (_delegate != address(0)) {
      // If yes, then revoke the delegation first
      revokeDelegate();
    }

    // Updating the proposal's forVotes or againstVotes according to the support flag
    Proposal storage proposal = proposals[proposalId];
    if (support) {
      proposal.forVotes += amount;
    } else {
      proposal.againstVotes += amount;
    }

    // Storing the vote cast by the voter for this proposal
    votes[proposalId][msg.sender] = Vote({amount: amount, support: support});

    // Emitting an event to notify the vote cast by the voter
    emit VoteCast(proposalId, msg.sender, amount, support);
  }

  // Defining a function to withdraw a vote from a proposal
  function withdrawVote(uint256 proposalId) public onlyVoter proposalExists(proposalId) proposalActive(proposalId) {
    // Getting the vote cast by the voter for this proposal
    Vote memory _vote = votes[proposalId][msg.sender];

    // Checking if the voter has voted on this proposal
    require(_vote.amount > 0, "Voter: no vote to withdraw");

    // Updating the proposal's forVotes or againstVotes according to the vote's support flag
    Proposal storage proposal = proposals[proposalId];
    if (_vote.support) {
      proposal.forVotes -= _vote.amount;
    } else {
      proposal.againstVotes -= _vote.amount;
    }

    // Deleting the vote cast by the voter for this proposal
    delete votes[proposalId][msg.sender];

    // Emitting an event to notify the vote withdrawal by the voter
    emit VoteWithdrawn(proposalId, msg.sender, _vote.amount);
  }

  // Defining a function to execute a proposal
  function executeProposal(
    uint256 proposalId
  ) public onlyVoter proposalExists(proposalId) proposalInactive(proposalId) proposalPending(proposalId) {
    // Getting the total supply of tokens at the end of the voting period
    uint256 totalSupply = votingToken.totalSupplyAt(proposals[proposalId].endTime);

    // Calculating the quorum and pass rate achieved by the proposal
    Proposal storage proposal = proposals[proposalId];
    uint256 quorumAchieved = ((proposal.forVotes + proposal.againstVotes) * 100) / totalSupply;
    uint256 passRateAchieved = (proposal.forVotes * 100) / (proposal.forVotes + proposal.againstVotes);

    // Checking if the quorum and pass rate requirements are met by the proposal
    require(quorumAchieved >= quorum, "Voter: quorum not met");
    require(passRateAchieved >= passRate, "Voter: pass rate not met");

    // Setting the executed flag and result of the proposal to true
    proposal.executed = true;
    proposal.result = true;

    // Emitting an event to notify the execution of the proposal
    emit ProposalExecuted(proposalId, true);
  }

  // Defining a function to delegate votes to another address
  function delegate(address delegatee) public onlyVoter {
    // Checking if the delegatee is a valid voter
    require(votingToken.balanceOf(delegatee) > 0, "Voter: not a valid delegatee");

    // Checking if the delegatee is not the same as the caller
    require(delegatee != msg.sender, "Voter: cannot delegate to self");

    // Checking if the caller has already delegated their vote to someone else
    require(delegates[msg.sender] == address(0), "Voter: already delegated");

    // Storing the delegation status of the caller
    delegates[msg.sender] = delegatee;

    // Emitting an event to notify the delegation change by the caller
    emit DelegateChanged(msg.sender, delegatee);
  }

  // Defining a function to revoke delegation from another address
  function revokeDelegate() public onlyVoter {
    // Checking if the caller has delegated their vote to someone else
    require(delegates[msg.sender] != address(0), "Voter: no delegate to revoke");

    // Deleting the delegation status of the caller
    delete delegates[msg.sender];

    // Emitting an event to notify the delegation change by the caller
    emit DelegateChanged(msg.sender, address(0));
  }
}
