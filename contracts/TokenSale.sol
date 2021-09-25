//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TokenSale {
  IERC20Metadata public tokenContract; // the token being sold
  uint256 public tokenPrice; // the price, in wei, per token
  uint256 public tokensSold = 0;
  bool public saleActive = false;
  address private _owner;

  constructor(IERC20Metadata _contract, uint256 price) {
    _owner = msg.sender;
    tokenContract = _contract;
    tokenPrice = price;
  }

  /// @notice Buy tokens from the contract
  /// @param amount number of tokens to purchase
  function buyTokens(uint256 amount) public payable {
    require(saleActive, "Sale has ended");
    require(msg.value == (amount * tokenPrice), "Incorrect token value ratio");

    uint256 scaledAmount = amount * (uint256(10)**tokenContract.decimals());

    require(
      scaledAmount <= tokenContract.balanceOf(address(this)),
      "Out of tokens"
    );

    tokensSold += amount;
    tokenContract.transfer(msg.sender, scaledAmount);

    emit SoldEvent(msg.sender, amount);
  }

  /// @notice For owner to start sale.
  function startSale() public {
    _ownerCheck();
    saleActive = true;
    emit StartSaleEvent();
  }

  /// @notice For owner to end sale and collect proceeds.
  function endSale() public {
    _ownerCheck();
    saleActive = false;
    emit EndSaleEvent();
    // Send unsold tokens to the owner.
	tokenContract.transfer(_owner, tokenContract.balanceOf(address(this)));

    // Transfer currency to the owner.
    payable(msg.sender).transfer(address(this).balance);
  }

  function _ownerCheck() private view {
    require(msg.sender == _owner, "You must be the owner");
  }

  /*** Events ***/
  event SoldEvent(address buyer, uint256 amount);
  event StartSaleEvent();
  event EndSaleEvent();
  /*** ***/
}
