//SPDX-License-Identifier: MIT

//--# to be modified
/*
To integrate Push Protocol, you'll need to implement event listeners and use the Push Protocol SDK. 
Here's a basic example of how you might emit events in your contracts:
You'll need to set up a Push channel and implement server-side logic to handle these events and send notifications through the Push Protocol.
*/

pragma solidity ^0.8.0;

// import "@pushprotocol/restapi/contracts/IPUSHCommInterface.sol";

contract PushNotifier {
	IPUSHCommInterface public pushComm;
	address public PUSH_CHANNEL_ADDRESS;

	constructor(address _pushCommAddress, address _pushChannelAddress) {
		pushComm = IPUSHCommInterface(_pushCommAddress);
		PUSH_CHANNEL_ADDRESS = _pushChannelAddress;
	}

	function _sendPushNotification(
		address _recipient,
		string memory _message
	) internal {
		pushComm.sendNotification(
			PUSH_CHANNEL_ADDRESS,
			_recipient,
			bytes(
				string(
					abi.encodePacked(
						"0",
						"+",
						"3",
						"+",
						"Notification",
						"+",
						_message
					)
				)
			)
		);
	}
}

contract MainRegistry is PushNotifier {
	// ... previous MainRegistry code ...

	function addAttestation(
		string memory _ipfsContentHash
	) external returns (uint256) {
		// ... previous addAttestation code ...
		_sendPushNotification(msg.sender, "Your attestation has been created!");
	}

	function distributeFunds(uint256 _attestationId) external payable {
		// ... previous distributeFunds code ...
		_sendPushNotification(
			attestations[_attestationId].creator,
			"You have received funds for your attestation!"
		);
	}
}
