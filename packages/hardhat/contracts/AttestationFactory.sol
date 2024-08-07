//SPDX-License-Identifier: MIT
//--# to be tested (& deployed)

/**
 * @title AttestationFactory
 * @dev Decoland Dev Team
 * @notice
 *      The AttestationFactory contract is responsible for creating new attestation contracts.
 *      It interacts with the UserRegistry to ensure that all contributors are registered users.
 *      When a new attestation is created, it registers any new contributors and links the attestation to their profiles.
 *      The contract emits events for the creation of attestations and for adding attestations to user profiles.
 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MainRegistry.sol";

// #ATTESTATION CONTRACT
/**
 *      The Attestation contract represents an individual attestation (a "knowledge production").
 *      It holds the details of the attestation, including title, URL, IPFS hash, previous/related/quoted attestation ID (work/knwoledge production), tags, authors, and contributors
 *      Contributors must sign the attestation to activate it.
 *      The contract also handles contributions (donations or co-publishing 'donations'), upvotes, and the distribution (equally) of funds among contributors.
 */
contract Attestation is ReentrancyGuard {
	using SafeMath for uint256;

	address[] public authors;
	address[] public contributors;
	string public ipfsHash;
	uint256[] public quotedAttestationId; //related/quoted previous work/attestationID to create links
	string[] public tags;
	uint256 public coPublishThreshold;

	mapping(address => bool) public hasSigned;
	uint256 public signatureCount;
	bool public isActivated;

	mapping(address => bool) public isCoPublisher;
	address[] public coPublishers;

	uint256 public upvoteCount;
	mapping(address => bool) public hasUpvoted;

	uint256 public totalFunds;
	mapping(address => uint256) public unclaimedFunds;

	event ContributorSigned(address indexed contributor);
	event AttestationActivated();
	event CoPublished(address indexed coPublisher);
	event Upvoted(address indexed upvoter);
	event FundsReceived(address indexed sender, uint256 amount);
	event FundsClaimed(address indexed claimer, uint256 amount);

	constructor(
		address[] memory _authors,
		address[] memory _contributors,
		string memory _ipfsHash,
		uint256[] memory _quotedAttestationId,
		string[] memory _tags,
		uint256 _coPublishThreshold
	) {
		authors = _authors;
		contributors = _contributors;
		ipfsHash = _ipfsHash;
		quotedAttestationId = _quotedAttestationId;
		tags = _tags;
		coPublishThreshold = _coPublishThreshold;
	}

	function sign() external {
		require(!isActivated, "Attestation already activated");
		require(isContributor(msg.sender), "Not a contributor");
		require(!hasSigned[msg.sender], "Already signed");

		hasSigned[msg.sender] = true;
		signatureCount++;

		if (signatureCount == contributors.length + authors.length) {
			isActivated = true;
			emit AttestationActivated();
		}

		emit ContributorSigned(msg.sender);
	}

	function coPublish() external payable {
		require(msg.value >= coPublishThreshold, "Insufficient funds");
		require(!isCoPublisher[msg.sender], "Already a co-publisher");

		isCoPublisher[msg.sender] = true;
		coPublishers.push(msg.sender);

		distributeFunds(msg.value);

		emit CoPublished(msg.sender);
	}

	function upvote() external {
		require(!hasUpvoted[msg.sender], "Already upvoted");
		hasUpvoted[msg.sender] = true;
		upvoteCount++;

		emit Upvoted(msg.sender);
	}

	function donate() external payable {
		require(msg.value > 0, "No funds sent");
		distributeFunds(msg.value);

		emit FundsReceived(msg.sender, msg.value);
	}

	function claimFunds() external nonReentrant {
		require(isContributor(msg.sender), "Not a contributor or author");
		uint256 amount = unclaimedFunds[msg.sender];
		require(amount > 0, "No funds to claim");

		unclaimedFunds[msg.sender] = 0;
		payable(msg.sender).transfer(amount);

		emit FundsClaimed(msg.sender, amount);
	}

	function distributeFunds(uint256 amount) internal {
		uint256 totalRecipients = contributors.length + authors.length;
		uint256 sharePerRecipient = amount.div(totalRecipients);

		for (uint256 i = 0; i < contributors.length; i++) {
			unclaimedFunds[contributors[i]] = unclaimedFunds[contributors[i]]
				.add(sharePerRecipient);
		}

		for (uint256 i = 0; i < authors.length; i++) {
			unclaimedFunds[authors[i]] = unclaimedFunds[authors[i]].add(
				sharePerRecipient
			);
		}

		totalFunds = totalFunds.add(amount);
	}

	//Contributors here are author+co-authors+contributors
	function isContributor(address _address) public view returns (bool) {
		// Check in the first array (contributors)
		for (uint i = 0; i < contributors.length; i++) {
			if (contributors[i] == _address) {
				return true;
			}
		}
		// Check in the second array (authors)
		for (uint i = 0; i < authors.length; i++) {
			if (authors[i] == _address) {
				return true;
			}
		}
		return false;
	}

	// Getter functions for arrays
	function getAuthors() external view returns (address[] memory) {
		return authors;
	}

	function getContributors() external view returns (address[] memory) {
		return contributors;
	}

	function getTags() external view returns (string[] memory) {
		return tags;
	}

	function getCoPublishers() external view returns (address[] memory) {
		return coPublishers;
	}

	function getQuotesAttestationIds()
		external
		view
		returns (uint256[] memory)
	{
		return quotedAttestationId;
	}
}

// #ATTESTATION FACTORY CONTRACT
contract AttestationFactory {
	MainRegistry public mainRegistry;

	event AttestationCreated(
		address indexed attestationAddress,
		address[] authors,
		address[] contributors
	);

	constructor(address _mainRegistryAddress) {
		mainRegistry = MainRegistry(_mainRegistryAddress);
	}

	function createAttestation(
		address[] memory _authors,
		address[] memory _contributors,
		string memory _ipfsHash, //contains in a json format all the metadata
		uint256[] memory _quotedAttestationId, //related/quoted previous work/attestationID to create links
		string[] memory _tags,
		uint256 _coPublishThreshold //min amount in native currency of donation to be added as co-publisher
	) external returns (address) {
		Attestation newAttestation = new Attestation(
			_authors,
			_contributors,
			_ipfsHash,
			_quotedAttestationId,
			_tags,
			_coPublishThreshold
		);

		address attestationAddress = address(newAttestation);

		address[] memory allParticipants = new address[](
			_authors.length + _contributors.length
		);
		for (uint i = 0; i < _authors.length; i++) {
			allParticipants[i] = _authors[i];
		}
		for (uint i = 0; i < _contributors.length; i++) {
			allParticipants[_authors.length + i] = _contributors[i];
		}

		mainRegistry.addAttestation(attestationAddress, allParticipants);
		emit AttestationCreated(attestationAddress, _authors, _contributors);
		return attestationAddress;
	}
}
