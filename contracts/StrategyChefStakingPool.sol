// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./common/Context.sol";
import "./common/Ownable.sol";
import "./common/SafeMath.sol";
import "./common/Address.sol";
import "./common/ERC20.sol";
import "./common/SafeERC20.sol";
import "./common/Pausable.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/IStrategy.sol";

contract StrategyChefStakingPool is Ownable, Pausable, IStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public token;
    address public yieldroutetoken;
    address public yieldtoken;
    address public feetoken;

    address public unirouter;
    address public masterchef;
    address public vault;
    address public strategist;
    address public treasury;

    uint constant public PERFORMANCE_FEE = 20; // 2% performance fees
    uint constant public TREASURY_FEE    = 500; // 50% of performance fee goes to treasury
    uint constant public STRATEGIST_FEE  = 500; // 50% of performance fee goes to strategist
    uint constant public MAX_FEE         = 1000;

    address[] public tokenToFeeRoute;
    address[] public tokenToYieldRoute;

    constructor(address _router, address _token, address _masterchef, address _yieldtoken, address _yieldroutetoken, address _feetoken, address _vault, address _strategist, address _treasury) {
        unirouter = _router;
        token = _token;
        masterchef = _masterchef;
        yieldtoken = _yieldtoken;
        yieldroutetoken = _yieldroutetoken;
        feetoken = _feetoken;
        vault = _vault;
        strategist = _strategist;
        treasury = _treasury;
        
        tokenToFeeRoute = [_token, _feetoken];
        if (_yieldroutetoken != address(0)) {
           tokenToYieldRoute = [_token, _yieldroutetoken, _yieldtoken];
        } else {
           tokenToYieldRoute = [_token, _yieldtoken];
        }

        IERC20(token).safeApprove(unirouter, uint256(-1));
        IERC20(feetoken).safeApprove(unirouter, uint256(-1));
        IERC20(yieldtoken).safeApprove(unirouter, uint256(-1));
    }
    
    function want() public override view returns (address) {
        return address(token);
    }

    function convertDepositedIntoEarnable() public override {
    }

    function convertEarnableIntoDeposited() public override {
    }

    function internal_deposit() internal {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        if (tokenBalance > 0) {
            IERC20(token).safeApprove(masterchef, 0);
            IERC20(token).safeApprove(masterchef, tokenBalance);
            IMasterChef(masterchef).enterStaking(tokenBalance);
        }
    }

    function pendingYield(uint256 _amount) view external returns (uint256) {
        uint256 balanceBefore = balanceOf().add(_amount);

        if (balanceBefore == 0) return 0;
        uint256 ratio = _amount.mul(1e18).div(balanceBefore);
        uint yieldBalance = balanceOfYieldToken();
        uint256 pendingyield = yieldBalance.mul(ratio).div(1e18);
        return pendingyield;
    }
    
    function distributeYield(uint256 _amount, uint256 _yield) internal {
        IERC20(token).safeTransfer(msg.sender, _amount);
        IERC20(yieldtoken).safeTransfer(msg.sender, _yield);
    }
    
    function internal_withdraw(uint256 _amount) internal {
        uint256 balanceBefore = balanceOfToken();
        IMasterChef(masterchef).leaveStaking(_amount);
        uint256 balanceReceived = balanceOfToken().sub(balanceBefore);
        uint256 yieldReceived = balanceReceived.sub(_amount);
        distributeYield(_amount, yieldReceived);
    }

    function internal_harvest() internal whenNotPaused {
        uint256 balanceBefore = balanceOfToken();
        IMasterChef(masterchef).leaveStaking(0);
        uint256 harvested = balanceOfToken().sub(balanceBefore);
        chargeFees(harvested);
        internal_deposit();
    }

    function deposit() public override whenNotPaused {
        internal_deposit();
        internal_harvest();
    }

    function withdraw(uint256 _amount) override external {
        require(msg.sender == vault, "!vault");
        if (!this.paused()) internal_harvest();
        internal_withdraw(_amount);
    }

    function harvest() external override whenNotPaused {
        require(!Address.isContract(msg.sender), "!contract");
        internal_harvest();
    }

    function chargeFees(uint256 _harvested) internal {        
        uint256 toFee = _harvested.mul(PERFORMANCE_FEE).div(MAX_FEE);
        IRouter(unirouter).swapExactTokensForTokens(toFee, 0, tokenToFeeRoute, address(this), block.timestamp.add(600));
        
        uint256 feeBalance = IERC20(feetoken).balanceOf(address(this));
        uint256 treasuryFee = feeBalance.mul(TREASURY_FEE).div(MAX_FEE);
        IERC20(feetoken).safeTransfer(treasury, treasuryFee);

        uint256 strategistFee = feeBalance.mul(STRATEGIST_FEE).div(MAX_FEE);
        IERC20(feetoken).safeTransfer(strategist, strategistFee);
        
        uint256 toYield = _harvested.sub(toFee);
        IRouter(unirouter).swapExactTokensForTokens(toYield, 0, tokenToYieldRoute, address(this), block.timestamp.add(600));
    }

    function balanceOf() public override view returns (uint256) {
        return balanceOfToken().add(balanceOfPool());
    }

    function balanceOfToken() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint256) {
        (uint256 _amount, ) = IMasterChef(masterchef).userInfo(0, address(this));
        return _amount;
    }

    function balanceOfYieldToken() public override view returns (uint256) {
        return IERC20(yieldtoken).balanceOf(address(this));
    }

    function withdrawAll() override external onlyOwner {
        panic();

        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(vault, tokenBalance);
    }

    function panic() public onlyOwner {
        _pause();
        IMasterChef(masterchef).emergencyWithdraw(0);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}