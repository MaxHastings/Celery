//SPDX-License-Identifier: GPL-3.0

// Locked to specific version
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TokenSale {
    IERC20Metadata public immutable tokenContract; // the token being sold

    uint256 public immutable tokenPrice; // the price, in wei, per token

    uint256 public tokensSold = 0; // How many tokens have been sold in the lifetime of this contract

    bool public saleActive = false; // True if you can buy tokens, false if not

    address private immutable _owner; // Keep track of owner (TokenSale creator) to be able to start/stop sale, collect remaining tokens/currency, etc.

    constructor(IERC20Metadata _contract, uint256 price) {
        // Setup contract and how much currency per token
        _owner = msg.sender;
        tokenContract = _contract;
        tokenPrice = price;
    }

    /*** Public write functions ***/

    /// @notice Buy tokens from the contract
    /// @param amount number of tokens to purchase
    function buyTokens(uint256 amount) external payable {
        require(saleActive, "Sale has ended");

        // Force user to send exact currency for exact tokens requesting, so there is some validation
        // Prevents users from sending too much currency on accident, etc.
        require(msg.value == (amount * tokenPrice), "Incorrect token value ratio");

        // Take into account decimals (you can only buy whole tokens with this contract)
        uint256 scaledAmount = amount * (uint256(10)**tokenContract.decimals());

        require(scaledAmount <= tokenContract.balanceOf(address(this)), "Out of tokens");

        // Add to tokens sold and transfer to caller
        tokensSold += amount;
        tokenContract.transfer(msg.sender, scaledAmount);

        emit SoldEvent(msg.sender, amount);
    }

    /// @notice For owner to start sale.
    function startSale() external _ownerCheck {
        require(!saleActive, "Sale already started");

        saleActive = true;
        emit StartSaleEvent();
    }

    /// @notice For owner to end sale and collect proceeds.
    function endSale() external _ownerCheck {
        require(saleActive, "Sale already ended");

        saleActive = false;
        emit EndSaleEvent();

        // Send unsold tokens to the owner.
        tokenContract.transfer(_owner, tokenContract.balanceOf(address(this)));

        // Transfer currency to the owner.
        _sendValue(payable(msg.sender), address(this).balance);
    }

    /*** ***/

    /*** Modifiers ***/

    modifier _ownerCheck {
        require(msg.sender == _owner, "You must be the owner");
        _;
    }

    // Substitatute obsolete 'transfer' and 'send' functions, pulled from internal function at
    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/87326f7313e851a603ef430baa33823e4813d977/contracts/utils/Address.sol#L37-L59
    function _sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Unable to send value");
    }

    /*** ***/

    /*** Events ***/

    event SoldEvent(address buyer, uint256 amount);
    event StartSaleEvent();
    event EndSaleEvent();

    /*** ***/
}
