pragma solidity 0.5.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./standard_bounties/StandardBounties.sol";

contract Fantastic12 {
  using SafeMath for uint256;

  // Constants
  uint8 public constant MAX_MEMBERS = 12;
  uint8 public constant BLOCKING_THRESHOLD = 4; // More than 1 / `BLOCKING_THRESHOLD` of members need to not consent to block consensus

  // Instance variables
  mapping(address => bool) public isMember;
  uint8 public memberCount;
  uint256 public nonce; // How many function calls have happened. Used for signature security.
  IERC20 public DAI;
  StandardBounties public BOUNTIES;
  address payable[] public issuersOrFulfillers;
  address[] public approvers;

  // Modifiers
  modifier onlyMember {
    require(isMember[msg.sender], "Not member");
    _;
  }

  modifier withConsensus(
    bytes4           _funcSelector,
    bytes     memory _funcParams,
    address[] memory _members,
    bytes[]   memory _signatures
  ) {
    require(
      _consensusReached(
        _funcSelector,
        _funcParams,
        _members,
        _signatures
      ), "No consensus");
    _;
  }

  // Events
  event Shout(string message);
  event PostBounty(uint256 bountyID);

  // Constructor
  constructor(
    address _summoner,
    address _DAI_ADDR,
    address _BOUNTIES_ADDR
  ) public {
    memberCount = 1;
    nonce = 0;
    DAI = IERC20(_DAI_ADDR);
    BOUNTIES = StandardBounties(_BOUNTIES_ADDR);
    issuersOrFulfillers = new address payable[](1);
    issuersOrFulfillers[0] = address(this);
    approvers = new address[](1);
    approvers[0] = address(this);

    // Add `_summoner` as the first member
    isMember[_summoner] = true;
  }

  // Functions

  function shout(string memory _message) public onlyMember {
    emit Shout(_message);
  }

  /**
    Member management
   */

  function addMember(
    address _newMember,
    uint256 _tribute,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.addMember.selector,
      abi.encode(_newMember, _tribute),
      _members,
      _signatures
    )
  {
    require(_newMember != address(0), "Member cannot be zero address");
    require(!isMember[_newMember], "Member cannot be added twice");
    require(memberCount < MAX_MEMBERS, "Max member count reached");

    // Receive tribute from `_newMember`
    require(DAI.transferFrom(_newMember, address(this), _tribute), "Tribute transfer failed");

    // Add `_newMember` to squad
    isMember[_newMember] = true;
    memberCount += 1;
  }

  function rageQuit() public onlyMember {
    // Give `msg.sender` their portion of the squad funds
    uint256 withdrawAmount = DAI.balanceOf(address(this)).div(memberCount);
    require(DAI.transfer(msg.sender, withdrawAmount), "Withdraw failed");

    // Remove `msg.sender` from squad
    isMember[msg.sender] = false;
    memberCount -= 1;
  }

  /**
    Posting bounties
   */

  function postBounty(
    string memory _dataIPFSHash,
    uint256 _deadline,
    uint256 _reward,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.postBounty.selector,
      abi.encode(_dataIPFSHash, _deadline, _reward),
      _members,
      _signatures
    )
    returns (uint256 _bountyID)
  {
    return _postBounty(_dataIPFSHash, _deadline, _reward);
  }

  function _postBounty(
    string memory _dataIPFSHash,
    uint256 _deadline,
    uint256 _reward
  )
    internal
    returns (uint256 _bountyID)
  {
    // Approve DAI reward to bounties contract
    require(DAI.approve(address(BOUNTIES), 0), "Failed to clear DAI approval");
    require(DAI.approve(address(BOUNTIES), _reward), "Failed to approve bounty reward");

    _bountyID = BOUNTIES.issueAndContribute(
      address(this),
      issuersOrFulfillers,
      approvers,
      _dataIPFSHash,
      _deadline,
      address(DAI),
      20, // ERC20
      _reward
    );
    emit PostBounty(_bountyID);
  }

  function addBountyReward(
    uint256 _bountyID,
    uint256 _reward,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.addBountyReward.selector,
      abi.encode(_bountyID, _reward),
      _members,
      _signatures
    )
  {
    // Approve DAI reward to bounties contract
    require(DAI.approve(address(BOUNTIES), 0), "Failed to clear DAI approval");
    require(DAI.approve(address(BOUNTIES), _reward), "Failed to approve bounty reward");

    BOUNTIES.contribute(
      address(this),
      _bountyID,
      _reward
    );
  }

  function refundBountyReward(
    uint256 _bountyID,
    uint256[] memory _contributionIDs,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.refundBountyReward.selector,
      abi.encode(_bountyID, _contributionIDs),
      _members,
      _signatures
    )
  {
    BOUNTIES.refundMyContributions(
      address(this),
      _bountyID,
      _contributionIDs
    );
  }

  function changeBountyData(
    uint256 _bountyID,
    string memory _dataIPFSHash,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.changeBountyData.selector,
      abi.encode(_bountyID, _dataIPFSHash),
      _members,
      _signatures
    )
  {
    BOUNTIES.changeData(
      address(this),
      _bountyID,
      0, // issuerId
      _dataIPFSHash
    );
  }

  function changeBountyDeadline(
    uint256 _bountyID,
    uint256 _deadline,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.changeBountyDeadline.selector,
      abi.encode(_bountyID, _deadline),
      _members,
      _signatures
    )
  {
    BOUNTIES.changeDeadline(
      address(this),
      _bountyID,
      0, // issuerId
      _deadline
    );
  }

  function acceptBountySubmission(
    uint256 _bountyID,
    uint256 _fulfillmentID,
    uint256[] memory _tokenAmounts,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.acceptBountySubmission.selector,
      abi.encode(_bountyID, _fulfillmentID, _tokenAmounts),
      _members,
      _signatures
    )
  {
    BOUNTIES.acceptFulfillment(
      address(this),
      _bountyID,
      _fulfillmentID,
      0, // approverId
      _tokenAmounts
    );
  }

  /**
    Working on bounties
   */

  function performBountyAction(
    uint256 _bountyID,
    string memory _dataIPFSHash,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.performBountyAction.selector,
      abi.encode(_bountyID, _dataIPFSHash),
      _members,
      _signatures
    )
  {
    BOUNTIES.performAction(
      address(this),
      _bountyID,
      _dataIPFSHash
    );
  }

  function fulfillBounty(
    uint256 _bountyID,
    string memory _dataIPFSHash,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.fulfillBounty.selector,
      abi.encode(_bountyID, _dataIPFSHash),
      _members,
      _signatures
    )
  {
    BOUNTIES.fulfillBounty(
      address(this),
      _bountyID,
      issuersOrFulfillers,
      _dataIPFSHash
    );
  }

  function updateBountyFulfillment(
    uint256 _bountyID,
    uint256 _fulfillmentID,
    string memory _dataIPFSHash,
    address[] memory _members,
    bytes[]   memory _signatures
  )
    public
    withConsensus(
      this.updateBountyFulfillment.selector,
      abi.encode(_bountyID, _fulfillmentID, _dataIPFSHash),
      _members,
      _signatures
    )
  {
    BOUNTIES.updateFulfillment(
      address(this),
      _bountyID,
      _fulfillmentID,
      issuersOrFulfillers,
      _dataIPFSHash
    );
  }

  /**
    Consensus
   */

  function naiveMessageHash(
    bytes4       _funcSelector,
    bytes memory _funcParams
  ) public view returns (bytes32) {
    return keccak256(abi.encodeWithSelector(_funcSelector, _funcParams, nonce, address(this)));
  }

  function consensusThreshold() public view returns (uint8) {
    uint8 blockingThresholdMemberCount = memberCount / BLOCKING_THRESHOLD;
    return memberCount - blockingThresholdMemberCount;
  }

  function _consensusReached(
    bytes4           _funcSelector,
    bytes     memory _funcParams,
    address[] memory _members,
    bytes[]   memory _signatures
  ) internal returns (bool) {
    // Hash of _funcSelector + _funcParams + nonce + address(this)
    bytes32 msgHash = ECDSA.toEthSignedMessageHash(naiveMessageHash(_funcSelector, _funcParams));

    // Check if the number of signatures exceed the consensus threshold
    if (_members.length != _signatures.length || _members.length < consensusThreshold()) {
      return false;
    }
    // Check if each signature is valid and signed by a member
    for (uint256 i = 0; i < _members.length; i = i.add(1)) {
      address recoveredAddress = ECDSA.recover(msgHash, _signatures[i]);
      if (recoveredAddress != _members[i] || !isMember[recoveredAddress]) {
        // Invalid signature
        return false;
      }
    }

    // Increment the nonce
    nonce = nonce.add(1);

    return true;
  }

  function() external payable {
    revert("Doesn't support receiving Ether");
  }
}