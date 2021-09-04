//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TokenSale {
    
    IERC20Metadata public tokenContract;  // the token being sold
    uint256 public price;              // the price, in wei, per token
    address owner;

    constructor(IERC20Metadata _tokenContract, uint256 _price) {
        owner = msg.sender;
        tokenContract = _tokenContract;
        price = _price;
    }
    
    uint256 public tokensSold;

    event Sold(address buyer, uint256 amount);
    
    function buyTokens(uint256 numberOfTokens) public payable {
        require(msg.value == (numberOfTokens * price));
    
        uint256 scaledAmount = numberOfTokens * (uint256(10) ** tokenContract.decimals());
    
        require(tokenContract.balanceOf(address(this)) >= scaledAmount);
    
        emit Sold(msg.sender, numberOfTokens);
        tokensSold += numberOfTokens;
    
        require(tokenContract.transfer(msg.sender, scaledAmount));
    }
    
    function endSale() public {
        require(msg.sender == owner);
    
        // Send unsold tokens to the owner.
        require(tokenContract.transfer(owner, tokenContract.balanceOf(address(this))));
    
        payable(msg.sender).transfer(address(this).balance);
    }


}
