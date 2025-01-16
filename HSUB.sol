// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SubscriptionToken is ERC20, Ownable {
    uint256 public tokenPrice = 1 ether; // Price per token in ETH

    constructor(uint256 initialSupply) ERC20("HashSubscribe Token", "HSUB") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply* 10**decimals());
    }

    function sellTokens(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Token amount must be greater than 0");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");

        uint256 ethToReturn = (tokenAmount * tokenPrice) / 10**decimals();
        uint256 commission = (ethToReturn * 1) / 100; // 1% commission
        uint256 ethAfterCommission = ethToReturn - commission;

        require(address(this).balance >= ethAfterCommission, "Contract has insufficient ETH");

        _transfer(msg.sender, owner(), tokenAmount);
        payable(owner()).transfer(commission);
        payable(msg.sender).transfer(ethAfterCommission);
    }

    function setTokenPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be greater than 0");
        tokenPrice = newPrice;
    }

    function buySpecificTokens(uint256 tokenAmount) external payable {
    require(tokenAmount > 0, "Token amount must be greater than 0");
    uint256 requiredETH = (tokenAmount * tokenPrice) / 10**decimals();
    require(msg.value >= requiredETH, "Insufficient ETH sent");

    require(balanceOf(owner()) >= tokenAmount, "Not enough tokens available for sale");

    _transfer(owner(), msg.sender, tokenAmount);

    // Refund excess ETH if sent more than required
    if (msg.value > requiredETH) {
        payable(msg.sender).transfer(msg.value - requiredETH);
    }
}


    // Allow the owner to withdraw any ETH held by the contract
    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    
}
// Base Sepolia
// 0x80e4ecB3C5AD98779be25Cd65B1aDEA4D6b94CEe
// 0x313A159De2a549d7e21ae7325A274649d13579Ab
