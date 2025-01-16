// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PasswordManager {
    // Mapping from user address to their username
    mapping(address => string) public users;

    // Mapping from user address to mapping of website to password hash
    mapping(address => mapping(string => string)) private passwordHashes;

    // Mapping from user address to array of websites
    mapping(address => string[]) private userWebsites;

    // Event to log password storage
    event PasswordStored(address indexed user, string website, string hash);

    // Event to log password retrieval
    event PasswordRetrieved(address indexed user, string website, string hash);

    // Register a user with a unique name
    function register(string memory _name) public {
        require(bytes(users[msg.sender]).length == 0, "User already registered.");
        require(bytes(_name).length != 0, "Name cannot be empty.");
        users[msg.sender] = _name;
    }

    // Store a password hash for a specific website
    function storePassword(string memory _website, string memory _hash) public {
        require(bytes(users[msg.sender]).length != 0, "User not registered.");
        require(bytes(_website).length != 0, "Website cannot be empty.");
        require(bytes(_hash).length != 0, "Hash cannot be empty.");

        string memory websiteLower = toLower(_website);
        address user = msg.sender;
        if (bytes(passwordHashes[user][websiteLower]).length == 0) {
            userWebsites[user].push(websiteLower);
        }
        passwordHashes[user][websiteLower] = _hash;
        emit PasswordStored(user, websiteLower, _hash);
    }

    // Retrieve all websites for a user
    function getWebsites() public view returns (string[] memory) {
        require(bytes(users[msg.sender]).length != 0, "User not registered.");
        return userWebsites[msg.sender];
    }

    // Retrieve password hash for a specific website
    function getPasswordHash(string memory _website) public view returns (string memory) {
        require(bytes(users[msg.sender]).length != 0, "User not registered.");
        string memory websiteLower = toLower(_website);
        return passwordHashes[msg.sender][websiteLower];
    }

    // Optional: Update password hash for a specific website
    function updatePasswordHash(string memory _website, string memory _newHash) public {
        require(bytes(users[msg.sender]).length != 0, "User not registered.");
        require(bytes(_newHash).length != 0, "Hash cannot be empty.");
        string memory websiteLower = toLower(_website);
        require(bytes(passwordHashes[msg.sender][websiteLower]).length != 0, "Website not found.");
        passwordHashes[msg.sender][websiteLower] = _newHash;
        emit PasswordStored(msg.sender, websiteLower, _newHash);
    }

    // Optional: Delete a website and its password hash
    function deleteWebsite(string memory _website) public {
        require(bytes(users[msg.sender]).length != 0, "User not registered.");
        string memory websiteLower = toLower(_website);
        require(bytes(passwordHashes[msg.sender][websiteLower]).length != 0, "Website not found.");

        // Delete the password hash
        delete passwordHashes[msg.sender][websiteLower];

        // Remove the website from the userWebsites array
        string[] storage websites = userWebsites[msg.sender];
        uint256 length = websites.length;
        for (uint256 i = 0; i < length; i++) {
            if (keccak256(abi.encodePacked(websites[i])) == keccak256(abi.encodePacked(websiteLower))) {
                // Swap with the last element and remove
                websites[i] = websites[length - 1];
                websites.pop();
                break;
            }
        }
    }

    // Function to check if a user is registered
    function isRegistered() public view returns (bool) {
        return bytes(users[msg.sender]).length != 0;
    }

    // Helper function to convert string to lowercase
    function toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
}
