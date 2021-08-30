//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

struct Account {
    uint256 stakedAmount;
    uint256 time;
    uint256 payoutAmountSnapshot;
    int status;
}
 
contract Celery is ERC20 {
    
    mapping(address => Account) private _accounts;

    constructor(uint256 initialSupply) ERC20("Celery", "CLY") {
        _mint(msg.sender, initialSupply);
        approve(msg.sender, initialSupply);
    }
    
    function getStakedAmount(address addr) public view returns (uint256)  {
        return _accounts[addr].stakedAmount;
    }
    
    function getStakedTime(address addr) public view returns (uint256) {
        return _accounts[addr].time;
    }
    
    function getPayoutAmountSnapshot(address addr) public view returns (uint256) {
        return _accounts[addr].payoutAmountSnapshot;
    }
    
    function getStakedStatus(address addr) public view returns (int) {
        return _accounts[addr].status;
    }
    
    function IncreaseStake(uint256 amount) public {
      _transfer(msg.sender, address(this), amount);
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

    function calcStake() private {
      uint256 lastTime = _accounts[msg.sender].time;
      uint256 timeStamp = block.timestamp;
      uint256 secondsStakedNorm = timeStamp - lastTime;
      uint256 secondsStaked = PRBMathUD60x18.fromUint(secondsStakedNorm);
      
      // Annual interest of 50% continuous compounding.
      // Interest represented as 60.18-decimal fixed-point number
      uint256 interest = 500000000000000000;
      // Euler's number represented as 60.18-decimal fixed-point number
      uint256 euler = 2718281828459045235;
      uint256 secondsPerYear = 31536000;
      uint256 percentageYearStaked = PRBMathUD60x18.div(secondsStaked, PRBMathUD60x18.fromUint(secondsPerYear));
      uint256 currStakedNorm = _accounts[msg.sender].stakedAmount;
      uint256 currStaked = PRBMathUD60x18.fromUint(currStakedNorm);
    
      uint256 rateTime = PRBMathUD60x18.mul(interest, percentageYearStaked);
      uint256 compoundedRate = PRBMathUD60x18.pow(euler, rateTime);
      uint256 newAmount = PRBMathUD60x18.mul(currStaked, compoundedRate);
      uint256 newAmountNorm = PRBMathUD60x18.toUint(newAmount);

      _accounts[msg.sender].stakedAmount = newAmountNorm;
      _accounts[msg.sender].time = timeStamp;
    }
    
    function BeginPayout() public {
      int status = _accounts[msg.sender].status;
      if (status == 1) {
        calcStake();
        _accounts[msg.sender].status = 0;
        
        uint256 currStakedNorm = _accounts[msg.sender].stakedAmount;
        _accounts[msg.sender].payoutAmountSnapshot = currStakedNorm;
      }
    }
    
    function CollectPayout() public {
        
      BeginPayout();
      
      uint256 payoutAmountSnapshotNorm = _accounts[msg.sender].payoutAmountSnapshot;
      uint256 payoutAmountSnapshot = PRBMathUD60x18.fromUint(payoutAmountSnapshotNorm);
      // 2 year payout period in Seconds
      uint256 payoutPeriodInSecondsNorm = 63072000;
      uint256 payoutPeriodInSeconds = PRBMathUD60x18.fromUint(payoutPeriodInSecondsNorm);
        
      uint256 timeStamp = block.timestamp;
      uint256 lastTime = _accounts[msg.sender].time;
      uint256 timePassedInSecondsNorm = timeStamp - lastTime;
      uint256 timePassedInSeconds = PRBMathUD60x18.fromUint(timePassedInSecondsNorm);
      uint256 payoutPeriodPercentage = PRBMathUD60x18.div(timePassedInSeconds, payoutPeriodInSeconds);
      
      uint256 maxPayoutAmount = PRBMathUD60x18.mul(payoutPeriodPercentage, payoutAmountSnapshot);
      uint256 maxPayoutAmountNorm = PRBMathUD60x18.toUint(maxPayoutAmount);
      uint256 currStakedNorm = _accounts[msg.sender].stakedAmount;
      uint256 currStaked = PRBMathUD60x18.fromUint(currStakedNorm);
    
      uint256 payoutAmount;
      if (currStakedNorm < maxPayoutAmountNorm) {
        payoutAmount = currStakedNorm;
      } else {
        payoutAmount = maxPayoutAmountNorm;
      }
      
      if(payoutAmount != 0) {
        _sendAmount(payoutAmount);
        _accounts[msg.sender].stakedAmount -= payoutAmount;
      }
      
      _accounts[msg.sender].time = timeStamp;
    }
    
    function _sendAmount(uint256 amount) private {
        
        uint256 contractTokenHoldings = balanceOf(address(this));
        
        if(amount > contractTokenHoldings) {
            _mint(msg.sender, amount);
            increaseAllowance(msg.sender, amount);
        } else {
            _transfer(address(this), msg.sender, amount);
        }
    }
    

}
