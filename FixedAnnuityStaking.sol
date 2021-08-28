// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

struct Account {
    uint256 stakedAmount;
    uint256 blockHeight;
    uint256 withdrawAmountPerBlock;
    int status;
}
 
contract FixedAnnuityStaking is ERC20 {
    
    mapping(address => Account) private _accounts;

    constructor(uint256 initialSupply) ERC20("FixedAnnuityStaking", "FAS") {
        _mint(msg.sender, initialSupply);
        approve(msg.sender, initialSupply);
    }
    

    function getStakedAmount(address addr) public view returns (uint256)  {
        return _accounts[addr].stakedAmount;
    }
    
    function getStakedBlockHeight(address addr) public view returns (uint256) {
        return _accounts[addr].blockHeight;
    }
    
    function getWithdrawAmountPerBlock(address addr) public view returns (uint256) {
        return _accounts[addr].withdrawAmountPerBlock;
    }
    
    function getStakedStatus(address addr) public view returns (int) {
        return _accounts[addr].status;
    }
    
    function IncreaseStake(uint256 amount) public {
      require(transferFrom(msg.sender, address(this), amount));
      int status = _accounts[msg.sender].status;
      if (status == 0) {
        CollectPayout();
        _accounts[msg.sender].status = 1;
      } else {
         calcStake();
      }
      _accounts[msg.sender].stakedAmount += amount;
    }
    
    function BeginStake() public {
      int status = _accounts[msg.sender].status;
      if (status == 0) {
        CollectPayout();
        _accounts[msg.sender].status = 1;
      }
    }
    
    //////////////// DEBUG FUNCTIONS BEGIN //////////////////////////////
    function IncreaseBlockHeight() public returns (uint256) {
        int a = 1+1;
        return block.number;
    }
    
    function ViewBlockHeight() public view returns (uint256) {
        return block.number;
    }
     //////////////// DEBUG FUNCTIONS END //////////////////////////////
    
    function calcStake() private {
      uint256 lastBlockHeight = _accounts[msg.sender].blockHeight;
      uint256 blocksStakedNorm = block.number - lastBlockHeight;
      uint256 blocksStaked = PRBMathUD60x18.fromUint(blocksStakedNorm);
      uint256 blockNumber = block.number;
      
      // Annual interest of 363% continuous compounding.
      // approx. 1% daily compounding.
      // Interest represented as 60.18-decimal fixed-point number
      uint256 interest = 3630000000000000000;
      // Euler's number represented as 60.18-decimal fixed-point number
      uint256 euler = 2718281828459045235;
      uint256 time = PRBMathUD60x18.div(blocksStaked, PRBMathUD60x18.fromUint(1000));
      uint256 currStakedNorm = _accounts[msg.sender].stakedAmount;
      uint256 currStaked = PRBMathUD60x18.fromUint(currStakedNorm);
    
      uint256 rateMulTime = PRBMathUD60x18.mul(interest, time);
      uint256 totalInterest = PRBMathUD60x18.pow(euler, rateMulTime);
      uint256 newAmount = PRBMathUD60x18.mul(currStaked, totalInterest);
      uint256 newAmountNorm = PRBMathUD60x18.toUint(newAmount);

      _accounts[msg.sender].stakedAmount = newAmountNorm;
      _accounts[msg.sender].blockHeight = block.number;
    }
    
    function BeginPayout() public {
      int status = _accounts[msg.sender].status;
      if (status == 1) {
        calcStake();
        _accounts[msg.sender].status = 0;
      }
    }
    
    function CollectPayout() public {
        
      int status = _accounts[msg.sender].status;
      
      if (status == 1) {
        calcStake();
      }
      
      uint256 currStakedNorm = _accounts[msg.sender].stakedAmount;
      uint256 currStaked = PRBMathUD60x18.fromUint(currStakedNorm);
      uint256 withdrawAmountPerBlock;
      
      if (status == 1){
          _accounts[msg.sender].status = 0;
          uint256 withdrawWindowInBlocksNorm = 10000;
          uint256 withdrawWindowInBlocks = PRBMathUD60x18.fromUint(withdrawWindowInBlocksNorm);
          // Set Withdraw Amount Per Block
          withdrawAmountPerBlock = PRBMathUD60x18.div(currStaked, withdrawWindowInBlocks);
          uint256 withdrawAmountPerBlockNorm = PRBMathUD60x18.toUint(withdrawAmountPerBlock);
          
        _accounts[msg.sender].withdrawAmountPerBlock = withdrawAmountPerBlockNorm;
      } else {
        withdrawAmountPerBlock = PRBMathUD60x18.fromUint(_accounts[msg.sender].withdrawAmountPerBlock);
      }
        
      uint256 lastBlockHeight = _accounts[msg.sender].blockHeight;
      uint256 blocksStakedNorm = block.number - lastBlockHeight;
      uint256 blocksStaked = PRBMathUD60x18.fromUint(blocksStakedNorm);
      uint256 blockNumber = block.number;
      uint256 maxPayoutAmount = PRBMathUD60x18.mul(withdrawAmountPerBlock, blocksStaked);
      uint256 maxPayoutAmountNorm = PRBMathUD60x18.toUint(maxPayoutAmount);
    
      uint256 payoutAmount;
      if (currStakedNorm < maxPayoutAmountNorm) {
          payoutAmount = currStakedNorm;
      } else {
        payoutAmount = maxPayoutAmountNorm;
      }
      
      _sendAmount(msg.sender, payoutAmount);
      _accounts[msg.sender].blockHeight = block.number;
      _accounts[msg.sender].stakedAmount -= payoutAmount;
    }
    
    function _sendAmount(address addr, uint256 amount) private {
        _mint(msg.sender, amount);
        increaseAllowance(msg.sender, amount);
    }
    

}
