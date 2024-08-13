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

	uint256 public totalReceivedFunds;
	mapping(address => uint256) public unclaimedFunds;

	event ContributorSigned(address indexed contributor);
	event AttestationActivated();
	event CoPublisherAdded(address indexed coPublisher);
	event Upvoted(address indexed upvoter);
	event FundsReceived(address indexed sender, uint256 amount);
	event FundsClaimed(address indexed claimer, uint256 amount);
	event AffiliationRevoked(address indexed contributor);
	event CoPublishThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

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
		// Automatically sign the contract for the first author
		_sign(authors[0]);
	}

	function _sign(address author) internal {
		require(!hasSigned[author], "Author has already signed.");
		hasSigned[author] = true;
		emit ContributorSigned(author);
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

	//missing amount for donation (and if the fund > threshold => co-publisher ?)
	// Creditation as a co-publisher, no rights attached to it !!
	function donate(uint256 amount) external payable {
		require(
			msg.value == amount,
			"Sent value does not match specified amount"
		);
		require(amount > 0, "No funds sent");

		distributeFunds(amount);

		emit FundsReceived(msg.sender, amount);

		// Check if the donation amount meets the co-publishing threshold
		if (amount >= coPublishThreshold && !isCoPublisher[msg.sender]) {
			isCoPublisher[msg.sender] = true;
			coPublishers.push(msg.sender);
			emit CoPublisherAdded(msg.sender);
		}
	}

	function setCoPublishThreshold(uint256 newThreshold) external {
		require(isAuthor(msg.sender), "Not an Author");
		require(newThreshold > 0, "Threshold must be greater than zero");
		uint256 oldThreshold = coPublishThreshold;
		coPublishThreshold = newThreshold;
		emit CoPublishThresholdUpdated(oldThreshold, newThreshold);
	}

	function upvote() external {
		require(!hasUpvoted[msg.sender], "Already upvoted");
		hasUpvoted[msg.sender] = true;
		upvoteCount++;

		emit Upvoted(msg.sender);
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

		totalReceivedFunds = totalReceivedFunds.add(amount);
	}

	function isAuthor(address _address) public view returns (bool) {
		for (uint i = 0; i < authors.length; i++) {
			if (authors[i] == _address) {
				return true;
			}
		}
		return false;
	}

	//Contributors here are author+co-authors+contributors
	function isContributor(address _address) public view returns (bool) {
		// Check in the contributors array
		for (uint i = 0; i < contributors.length; i++) {
			if (contributors[i] == _address) {
				return true;
			}
		}

		// Check if the address is an author
		return isAuthor(_address);
	}

	//Any contributor can revoke his/her affiliation (only if not signed)
	function revokeAffiliation() external {
		require(isContributor(msg.sender), "Not a contributor or author");
		require(!hasSigned[msg.sender], "Cannot revoke after signing");

		bool found = false;

		// Remove from contributors array
		for (uint i = 0; i < contributors.length; i++) {
			if (contributors[i] == msg.sender) {
				contributors[i] = contributors[contributors.length - 1];
				contributors.pop();
				found = true;
				break;
			}
		}

		// If not found in contributors, check in authors array
		if (!found) {
			for (uint i = 0; i < authors.length; i++) {
				if (authors[i] == msg.sender) {
					authors[i] = authors[authors.length - 1];
					authors.pop();
					break;
				}
			}
		}

		// Clear any unclaimed funds
		unclaimedFunds[msg.sender] = 0;

		emit AffiliationRevoked(msg.sender);
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
