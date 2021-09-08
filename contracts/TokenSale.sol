//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract TokenSale {
    IERC20Metadata public TokenContract; // the token being sold
    uint256 public TokenPrice; // the price, in wei, per token
    uint256 public TokensSold = 0;
    bool public SaleActive = false;
    address private _owner;

    constructor(IERC20Metadata tokenContract, uint256 price) {
        _owner = msg.sender;
        TokenContract = tokenContract;
        TokenPrice = price;
    }

    /// @notice Buy tokens from the contract
    /// @param amount number of tokens to purchase
    function BuyTokens(uint256 amount) public payable {
        require(SaleActive, "The Celery token sale has ended");
        require(
            msg.value == (amount * TokenPrice),
            "Your BCH and Celery ratio amounts must match per the price"
        );

        uint256 scaledAmount = amount *
            (uint256(10)**TokenContract.decimals());

        require(
            scaledAmount <= TokenContract.balanceOf(address(this)),
            "Token sale contract does not have enough Celery"
        );

        TokensSold += amount;
        require(TokenContract.transfer(msg.sender, scaledAmount));

        emit SoldEvent(msg.sender, amount);
    }

    /// @notice For owner to start sale.
    function StartSale() public {
        _ownerCheck();
        SaleActive = true;
        emit StartSaleEvent();
    }


    /// @notice For owner to end sale and collect proceeds.
    function EndSale() public {
        _ownerCheck();
        
        // Send unsold tokens to the owner.
        require(
            TokenContract.transfer(
                _owner,
                TokenContract.balanceOf(address(this))
            )
        );

        // Transfer currency to the owner. 
        payable(msg.sender).transfer(address(this).balance);

        SaleActive = false;
        emit EndSaleEvent();
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
