// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct User {
        string name;
        string userId;
        uint256 contentCount;
        string[] contentIds;
        uint256 copyrightStrikes;
        uint256 copyrightStrikesWon;
        uint256 copyrightStrikesLost;
        uint256 copyrightClaims;
        uint256 copyrightClaimsWon;
        uint256 copyrightClaimsLost;
    }

    struct Content {
        string ipfsHash;
        string name;
        string description;
        address owner;
    }

    struct Copyright {
        string copyrightId;
        string contentId; // Add this line
        address claimant;
        address accused;
        address validator;
        bool resolved;
        bool claimantWon;
    }

    mapping(address => User) private users;
    mapping(string => Content) private contents;
    mapping(string => Copyright) private copyrights;

    address[] private userAddresses;
    string[] private contentIds;
    string[] private copyrightIds;

    uint256 private userCount;
    uint256 private contentCount;
    uint256 private copyrightCount;

    mapping(string => bool) private usernameExists;

    
function registerUser(string memory _name) public {
    require(bytes(users[msg.sender].userId).length == 0, "User already registered");
    require(!usernameExists[_name], "Username already taken");

    string memory userId = string(abi.encodePacked("HashClaim-", _name));
    users[msg.sender] = User(_name, userId, 0, new string[](0), 0, 0, 0, 0, 0, 0);
    userAddresses.push(msg.sender);
    userCount++;
    
    usernameExists[_name] = true;
}

    function createContent(
        string memory _ipfsHash,
        string memory _name,
        string memory _description
    ) public {
        require(
            bytes(users[msg.sender].userId).length > 0,
            "User not registered"
        );

        contentCount++;
        string memory contentId = string(
            abi.encodePacked(
                "HashClaim-",
                users[msg.sender].name,
                "-",
                toString(contentCount)
            )
        );
        contents[contentId] = Content(
            _ipfsHash,
            _name,
            _description,
            msg.sender
        );
        users[msg.sender].contentIds.push(contentId);
        users[msg.sender].contentCount++;
        contentIds.push(contentId);
    }

    function getUserDetails(address _userAddress)
        public
        view
        returns (
            string memory userId,
            uint256 contentCount,
            string[] memory contentIds,
            uint256 copyrightStrikes,
            uint256 copyrightStrikesWon,
            uint256 copyrightStrikesLost,
            uint256 copyrightClaims,
            uint256 copyrightClaimsWon,
            uint256 copyrightClaimsLost
        )
    {
        User storage user = users[_userAddress];
        return (
            user.userId,
            user.contentCount,
            user.contentIds,
            user.copyrightStrikes,
            user.copyrightStrikesWon,
            user.copyrightStrikesLost,
            user.copyrightClaims,
            user.copyrightClaimsWon,
            user.copyrightClaimsLost
        );
    }

    function getAllUsers() public view returns (address[] memory) {
        return userAddresses;
    }

    function fileCopyrightClaim(string memory _contentId, address _accused)
        public
    {
        require(
            bytes(users[msg.sender].userId).length > 0,
            "Claimant not registered"
        );
        require(
            bytes(users[_accused].userId).length > 0,
            "Accused not registered"
        );
        require(
            contents[_contentId].owner == _accused,
            "Accused is not the content owner"
        );
        require(msg.sender != _accused, "Claimant cannot be the accused");

        copyrightCount++;
        string memory copyrightId = string(
            abi.encodePacked("HashClaim-copyright-", toString(copyrightCount))
        );
        address validator = getRandomValidator(msg.sender, _accused);
        require(validator != address(0), "No eligible validator found");

        copyrights[copyrightId] = Copyright(
            copyrightId,
            _contentId,
            msg.sender,
            _accused,
            validator,
            false,
            false
        );
        copyrightIds.push(copyrightId);

        users[msg.sender].copyrightClaims++;
        users[_accused].copyrightStrikes++;
    }

    function getRandomValidator(address _claimant, address _accused)
        private
        view
        returns (address)
    {
        require(userAddresses.length > 2, "Not enough users for validation");

        uint256[] memory eligibleIndices = new uint256[](userAddresses.length);
        uint256 count = 0;

        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (userAddresses[i] != _claimant && userAddresses[i] != _accused) {
                eligibleIndices[count] = i;
                count++;
            }
        }

        if (count == 0) return address(0);

        uint256 randomIndex = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty))
        ) % count;
        return userAddresses[eligibleIndices[randomIndex]];
    }

    function resolveCopyrightClaim(
        string memory _copyrightId,
        bool _claimantWins
    ) public {
        Copyright storage copyright = copyrights[_copyrightId];
        require(
            msg.sender == copyright.validator,
            "Only validator can resolve"
        );
        require(!copyright.resolved, "Copyright claim already resolved");

        copyright.resolved = true;
        copyright.claimantWon = _claimantWins;

        if (_claimantWins) {
            users[copyright.claimant].copyrightClaimsWon++;
            users[copyright.accused].copyrightStrikesLost++;
            this.transferContent(
                copyright.accused,
                copyright.claimant,
                copyright.contentId
            );
        } else {
            users[copyright.claimant].copyrightClaimsLost++;
            users[copyright.accused].copyrightStrikesWon++;
        }
    }

    function transferContent(
        address _from,
        address _to,
        string memory _contentId
    ) public {
        require(
            msg.sender == _from || msg.sender == address(this),
            "Unauthorized transfer"
        );
        require(
            contents[_contentId].owner == _from,
            "Sender does not own the content"
        );

        contents[_contentId].owner = _to;

        // Remove content from sender
        for (uint256 i = 0; i < users[_from].contentIds.length; i++) {
            if (
                keccak256(bytes(users[_from].contentIds[i])) ==
                keccak256(bytes(_contentId))
            ) {
                users[_from].contentIds[i] = users[_from].contentIds[
                    users[_from].contentIds.length - 1
                ];
                users[_from].contentIds.pop();
                break;
            }
        }
        users[_from].contentCount--;

        // Add content to receiver
        users[_to].contentIds.push(_contentId);
        users[_to].contentCount++;
    }

    function getCopyrightIds(address _userAddress)
        public
        view
        returns (string[] memory)
    {
        string[] memory userCopyrightIds = new string[](copyrightIds.length);
        uint256 count = 0;

        for (uint256 i = 0; i < copyrightIds.length; i++) {
            Copyright storage copyright = copyrights[copyrightIds[i]];
            if (
                copyright.claimant == _userAddress ||
                copyright.accused == _userAddress
            ) {
                userCopyrightIds[count] = copyrightIds[i];
                count++;
            }
        }

        // Resize the array to remove empty elements
        assembly {
            mstore(userCopyrightIds, count)
        }

        return userCopyrightIds;
    }

    function getCopyrightDetails(string memory _copyrightId)
    public
    view
    returns (
        string memory copyrightId,
        string memory contentId,
        address claimant,
        address accused,
        address validator,
        bool resolved,
        bool claimantWon
    )
{
    Copyright storage copyright = copyrights[_copyrightId];
    return (
        copyright.copyrightId,
        copyright.contentId,
        copyright.claimant,
        copyright.accused,
        copyright.validator,
        copyright.resolved,
        copyright.claimantWon
    );
}


    function getPlatformStats()
        public
        view
        returns (
            uint256 totalUsers,
            uint256 totalContentProviders,
            uint256 totalContent,
            uint256 totalCopyrightClaims
        )
    {
        return (userCount, userCount, contentCount, copyrightCount);
    }

    function getUserStats(address _userAddress)
        public
        view
        returns (
            uint256 userContentCount,
            uint256 userCopyrightStrikes,
            uint256 userCopyrightClaims
        )
    {
        User storage user = users[_userAddress];
        return (user.contentCount, user.copyrightStrikes, user.copyrightClaims);
    }

    function getContentDetails(string memory _contentId)
        public
        view
        returns (
            string memory ipfsHash,
            string memory name,
            string memory description,
            address owner
        )
    {
        Content storage content = contents[_contentId];
        require(bytes(content.ipfsHash).length > 0, "Content does not exist");

        return (
            content.ipfsHash,
            content.name,
            content.description,
            content.owner
        );
    }


function getAllContentIds() public view returns (string[] memory) {
    return contentIds;
}

function getUserCopyrightInvolvement(address _userAddress) public view returns (
    string[] memory claimantCopyrights,
    string[] memory accusedCopyrights
) {
    uint256 claimantCount = 0;
    uint256 accusedCount = 0;

    // First, count the number of copyrights for each category
    for (uint256 i = 0; i < copyrightIds.length; i++) {
        Copyright storage copyright = copyrights[copyrightIds[i]];
        if (copyright.claimant == _userAddress) {
            claimantCount++;
        }
        if (copyright.accused == _userAddress) {
            accusedCount++;
        }
    }

    // Create arrays of the correct size
    claimantCopyrights = new string[](claimantCount);
    accusedCopyrights = new string[](accusedCount);

    // Reset counters for populating arrays
    claimantCount = 0;
    accusedCount = 0;

    // Populate the arrays
    for (uint256 i = 0; i < copyrightIds.length; i++) {
        Copyright storage copyright = copyrights[copyrightIds[i]];
        if (copyright.claimant == _userAddress) {
            claimantCopyrights[claimantCount] = copyrightIds[i];
            claimantCount++;
        }
        if (copyright.accused == _userAddress) {
            accusedCopyrights[accusedCount] = copyrightIds[i];
            accusedCount++;
        }
    }

    return (claimantCopyrights, accusedCopyrights);
}

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
