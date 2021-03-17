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
import "./interfaces/IOracle.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IShareRewardPool.sol";

contract StrategyBACDAIPool is Ownable, Pausable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public constant DOLLAR_PARITY = 1e18;
    uint256 public constant DEADLINE = 6000;

    IERC20 public constant dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 public constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public constant bac = IERC20(0x3449FC1Cd036255BA1EB19d65fF4BA2b8903A69a);
    address public lpPair;
    address public lpToken0;
    address public lpToken1;

    IRouter public unirouter;
    address constant public shareRewardPool = address(0x7E7aE8923876955d6Dcb7285c04065A1B9d6ED8c);
    uint8 public poolId;

    address constant public treasury = address(0xA80cADB934A4AbeF1f6Ea7D0407DB4EA41294ed8);
    address public vault;
    address public strategist;
    IOracle public bacOracle;

    uint constant public PERFORMANCE_FEE = 200; // 2% performance fees
    uint constant public TREASURY_FEE    = 500; // 50% of performance fee goes to treasury
    uint constant public STRATEGIST_FEE  = 500; // 50% of performance fee goes to strategist
    uint constant public MAX_FEE         = 1000;

    address[] public bacToDaiRoute = [address(bac), address(dai)];
    address[] public daiToBacRoute = [address(dai), address(bac)];
    address[] public daiTowethRoute = [address(dai), address(dai), address(weth)];
    address[] public daiToLp0Route;
    address[] public daiToLp1Route;

    event StrategyHarvest(address indexed harvester);

    constructor(address _router, address _lpPair, uint8 _poolId, address _vault, address _strategist, address _oracle) {
        unirouter = IRouter(_router);
        lpPair = _lpPair;
        lpToken0 = IPair(lpPair).token0();
        lpToken1 = IPair(lpPair).token1();
        poolId = _poolId;
        vault = _vault;
        strategist = _strategist;
        bacOracle = IOracle(_oracle);

        if (lpToken0 == address(dai)) {
            daiToLp0Route = [address(dai), address(dai)];
        } else if (lpToken0 != address(dai)) {
            daiToLp0Route = [address(dai), address(dai), lpToken0];
        }

        if (lpToken1 == address(dai)) {
            daiToLp1Route = [address(dai), address(dai)];
        } else if (lpToken1 != address(dai)) {
            daiToLp1Route = [address(dai), address(dai), lpToken1];
        }
        
        
        
        IERC20(lpPair).safeApprove(shareRewardPool, uint(-1));
        IERC20(bac).safeApprove(address(unirouter), uint(-1));
        IERC20(dai).safeApprove(address(unirouter), uint(-1));
        IERC20(weth).safeApprove(address(unirouter), uint(-1));

        IERC20(lpToken0).safeApprove(address(unirouter), 0);
        IERC20(lpToken0).safeApprove(address(unirouter), uint(-1));

        IERC20(lpToken1).safeApprove(address(unirouter), 0);
        IERC20(lpToken1).safeApprove(address(unirouter), uint(-1));
    }

    function convertDepositedIntoEarnable() public whenNotPaused {
        uint256 _deposited = bac.balanceOf(address(this));        
        if (_deposited > 0) {
            uint256 bacPrice = bacOracle.price();
        // swap to deposit token to stable in ratio according to price difference (f.e. $1.02 price results in 2% of deposited tokens swapped to stable)
            uint256 toStable = bacPrice.sub(DOLLAR_PARITY).mul(_deposited).div(DOLLAR_PARITY);
            unirouter.swapExactTokensForTokens(toStable, 0, bacToDaiRoute, address(this), block.timestamp.add(DEADLINE));
        // add earnable LP tokens (wanted tokens)
           uint256 daiBalance = dai.balanceOf(address(this));
           unirouter.addLiquidity(address(bac), address(dai), toStable, daiBalance, 1, 1, address(this), block.timestamp.add(DEADLINE));
        }
    }

    function convertEarnableIntoDeposited() public whenNotPaused {
        // decompose earnable LP tokens
           uint256 _wanted = IERC20(lpPair).balanceOf(address(this));
           if (_wanted > 0) {
               unirouter.removeLiquidity(address(bac),address(dai), _wanted, 0, 0, address(this), block.timestamp.add(DEADLINE));
               // swap stable back to deposited tokens
               uint256 toDeposited = dai.balanceOf(address(this));
               unirouter.swapExactTokensForTokens(toDeposited, 0, daiToBacRoute, address(this), block.timestamp.add(DEADLINE));
           }
    }
        
    function deposit() public whenNotPaused {
        uint256 pairBal = IERC20(lpPair).balanceOf(address(this));

        if (pairBal > 0) {
            IShareRewardPool(shareRewardPool).deposit(poolId, pairBal);
        }
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 pairBal = IERC20(lpPair).balanceOf(address(this));

        if (pairBal < _amount) {   
            IShareRewardPool(shareRewardPool).withdraw(poolId, _amount.sub(pairBal));
            pairBal = IERC20(lpPair).balanceOf(address(this));
        }

        if (pairBal > _amount) {
            pairBal = _amount;    
        }
        
        if (!this.paused()) this.harvest();
    }

    function harvest() external whenNotPaused {
        require(!Address.isContract(msg.sender), "!contract");
        IShareRewardPool(shareRewardPool).deposit(poolId, 0);
        chargeFees();
        addLiquidity();
        deposit();

        emit StrategyHarvest(msg.sender);
    }

    function chargeFees() internal {
        uint256 toweth = IERC20(dai).balanceOf(address(this)).mul(PERFORMANCE_FEE).div(MAX_FEE);
        IRouter(unirouter).swapExactTokensForTokens(toweth, 0, daiTowethRoute, address(this), block.timestamp.add(600));
        
        uint256 wethBal = IERC20(weth).balanceOf(address(this));
        uint256 treasuryFee = wethBal.mul(TREASURY_FEE).div(MAX_FEE);
        IERC20(weth).safeTransfer(treasury, treasuryFee);

        uint256 strategistFee = wethBal.mul(STRATEGIST_FEE).div(MAX_FEE);
        IERC20(weth).safeTransfer(strategist, strategistFee);
    }

    function addLiquidity() internal {   
        uint256 daiHalf = IERC20(dai).balanceOf(address(this)).div(2);
        
        if (lpToken0 != address(dai)) {
            IRouter(unirouter).swapExactTokensForTokens(daiHalf, 0, daiToLp0Route, address(this), block.timestamp.add(600));
        }

        if (lpToken1 != address(dai)) {
            IRouter(unirouter).swapExactTokensForTokens(daiHalf, 0, daiToLp1Route, address(this), block.timestamp.add(600));
        }

        uint256 lp0Bal = IERC20(lpToken0).balanceOf(address(this));
        uint256 lp1Bal = IERC20(lpToken1).balanceOf(address(this));
        IRouter(unirouter).addLiquidity(lpToken0, lpToken1, lp0Bal, lp1Bal, 1, 1, address(this), block.timestamp.add(600));
    }

    function balanceOf() public view returns (uint256) {
        return balanceOfLpPair().add(balanceOfPool());
    }

    function balanceOfLpPair() public view returns (uint256) {
        return IERC20(lpPair).balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint256) {
        (uint256 _amount, ) = IShareRewardPool(shareRewardPool).userInfo(poolId, address(this));
        return _amount;
    }

    function withdrawAll() external {
        require(msg.sender == vault, "!vault");

        IShareRewardPool(shareRewardPool).emergencyWithdraw(poolId);

        uint256 pairBal = IERC20(lpPair).balanceOf(address(this));
        IERC20(lpPair).transfer(vault, pairBal);
    }

    function panic() public onlyOwner {
        pause();
        IShareRewardPool(shareRewardPool).emergencyWithdraw(poolId);
    }

    function pause() public onlyOwner {
        _pause();

        IERC20(lpPair).safeApprove(shareRewardPool, 0);
        IERC20(bac).safeApprove(address(unirouter), 0);
        IERC20(weth).safeApprove(address(unirouter), 0);
        IERC20(dai).safeApprove(address(unirouter), 0);
        IERC20(lpToken0).safeApprove(address(unirouter), 0);
        IERC20(lpToken1).safeApprove(address(unirouter), 0);
    }

    function unpause() external onlyOwner {
        _unpause();

        IERC20(lpPair).safeApprove(shareRewardPool, uint(-1));
        IERC20(bac).safeApprove(address(unirouter), uint(-1));
        IERC20(dai).safeApprove(address(unirouter), uint(-1));
        IERC20(weth).safeApprove(address(unirouter), uint(-1));

        IERC20(lpToken0).safeApprove(address(unirouter), 0);
        IERC20(lpToken0).safeApprove(address(unirouter), uint(-1));

        IERC20(lpToken1).safeApprove(address(unirouter), 0);
        IERC20(lpToken1).safeApprove(address(unirouter), uint(-1));
    }
}