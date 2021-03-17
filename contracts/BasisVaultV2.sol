// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;
import "./common/Ownable.sol";
import "./common/Strategist.sol";
import "./common/Address.sol";
import "./common/SafeMath.sol";
import "./common/ERC20.sol";
import "./common/SafeERC20.sol";
import "./common/MintableERC20.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IAutomatedStrategist.sol";

import "hardhat/console.sol";

contract BasisVaultV2 is Ownable, Strategist {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public constant DOLLAR_PARITY = 1e18;
    uint256 public constant PERCENT = 100;
    uint256 public constant MAX_PCT = 10000;
    uint256 public constant DEADLINE = 6000;

    // User Info
    struct UserInfo {
        uint256 deposited;
        uint256 withdrawn;
        uint256 claimed;
    }
    mapping(address => UserInfo) public userInfo;
    
    // Strategies
    mapping(address => bool) public allowedStrategy;
    event AddedAllowedStrategy(address implementation);
    event SwitchedStrategy(address implementation, uint256 timestamp);

    // Strategy Info
    struct StrategyInfo {
        uint256 sentToStrategy;
        uint256 keptReserve;
    }
    mapping(IStrategy => StrategyInfo) public strategyInfo;

    // Strategy Config
    struct StrategyConfig {
        IERC20 wanttoken; // The token the strategy wants and the vault looks to maximize.
        IERC20 yieldtoken; // The token the strategy yields.
        uint256 reservePct; // percentage of wanttoken to hold instead of deposit into strategy
    }   
    mapping(IStrategy => StrategyConfig) public strategyConfig;

    // Vault Info
    struct VaultInfo {
        uint256 deposited;
        uint256 withdrawn;
        uint256 cumulativeClaimablePerShare;
    }
    VaultInfo public vault;

    // Vault Tokens
    struct VaultTokens {
        IERC20 deposittoken; // The token which is deposited in the vault.
        MintableERC20 sharetoken; // The vault's own share token which is minted when someone does a deposit
        IERC20 yieldtoken; // The extra token the vault yields.
    }
    VaultTokens public vaultTokens;
    
    // Vault Config
    struct VaultConfig {
        IAutomatedStrategist automatedStrategist; // The automated strategist selecting the active strategy
        IStrategy activeStrategy; // The strategy currently in use by the vault.
        bool configured; // Boolean which gets set after vault configuration
    }
    VaultConfig public vaultConfig;

    modifier isConfigured() {
        require(vaultConfig.configured, 'Vault not yet configured!');
        _;
    }

    // configuration function    
    function configureVault(
        address _deposittoken,
        address _yieldtoken,
        address _strategy,
        address _automatedStrategist,
        string memory _sharename,
        string memory _sharesymbol
    ) public onlyOwner {
        require(!vaultConfig.configured, 'Vault is already configured!');
        vaultTokens = VaultTokens({
            deposittoken: IERC20(_deposittoken),
            sharetoken: new MintableERC20(string(_sharename), string(_sharesymbol)),
            yieldtoken: IERC20(_yieldtoken)
        });

        vaultConfig = VaultConfig({
            activeStrategy: IStrategy(_strategy),
            automatedStrategist: IAutomatedStrategist(_automatedStrategist),
            configured: true
        });
    }

    function totalSupply() isConfigured() public view returns (uint) {
        return vaultTokens.sharetoken.totalSupply();
    }
    
    function balance() public view returns (uint) {
        return strategyConfig[vaultConfig.activeStrategy].wanttoken.balanceOf(address(this)).add(vaultConfig.activeStrategy.balanceOf());
    }

    function yieldBalance() public view returns (uint) {
        return vaultTokens.yieldtoken.balanceOf(address(this)).add(vaultConfig.activeStrategy.balanceOfYieldToken());
    }

    function available() public view returns (uint256) {
        return strategyConfig[vaultConfig.activeStrategy].wanttoken.balanceOf(address(this));
    }

    function yieldAvailable() public view returns (uint256) {
        return vaultTokens.yieldtoken.balanceOf(address(this));
    }

    function getPricePerFullShare() public view returns (uint256) {
        return balance().mul(1e18).div(vaultTokens.sharetoken.totalSupply());
    }

    function getYieldPerFullShare() public view returns (uint256) {
        return yieldBalance().mul(1e18).div(vaultTokens.sharetoken.totalSupply());
    }

    function depositAll() isConfigured external {
        deposit(vaultTokens.deposittoken.balanceOf(msg.sender));
    }

    function _addDeposit(uint256 _vaultDepositTokenBalanceBeforeDeposit, uint256 _amount) internal {
        vaultTokens.deposittoken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = vaultTokens.deposittoken.balanceOf(address(this));
        _amount = _after.sub(_vaultDepositTokenBalanceBeforeDeposit); // Additional check for deflationary tokens
        userInfo[msg.sender].deposited = userInfo[msg.sender].deposited.add(_amount);
        vault.deposited = vault.deposited.add(_amount);
    }

    function _mintShares(uint256 _vaultBalanceBeforeDeposit, uint256 _amount) internal {
        uint256 shares = 0;
        if (vaultTokens.sharetoken.totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(vaultTokens.sharetoken.totalSupply())).div(_vaultBalanceBeforeDeposit);
        }
        console.log('** Minting %s vault tokens', shares);
        vaultTokens.sharetoken.mint(msg.sender, shares);
    }

    function _convertDepositedIntoEarnable() internal {
        IStrategy _strategy = vaultConfig.activeStrategy;
        uint256 toEarnable = vaultTokens.deposittoken.balanceOf(address(this));
        if (toEarnable > 0) {
            console.log('** Deposit tokens to convert to Earnable = %s', toEarnable);
            vaultTokens.deposittoken.safeTransfer(address(vaultConfig.activeStrategy), toEarnable);
            vaultConfig.activeStrategy.convertDepositedIntoEarnable();
        }
    }
    
    function deposit(uint _amount) isConfigured public {
        console.log('** deposit %s',_amount);
        uint256 _vaultDepositTokenBalanceBeforeDeposit = vaultTokens.deposittoken.balanceOf(address(this));
        console.log('** Vault deposit token balance before deposit = %s',_vaultDepositTokenBalanceBeforeDeposit);
        
        _addDeposit(_vaultDepositTokenBalanceBeforeDeposit, _amount);
        _mintShares(_vaultDepositTokenBalanceBeforeDeposit, _amount);

        chooseStrategy();
        earn();
    }

    function earn() isConfigured public {
        _convertDepositedIntoEarnable();
        
        IStrategy _strategy = vaultConfig.activeStrategy;
        uint256 availableAssets = strategyConfig[_strategy].wanttoken.balanceOf(address(this));
        uint256 desiredReserve = availableAssets.add(_strategy.balanceOf()).mul(strategyConfig[_strategy].reservePct).div(MAX_PCT);
        if (availableAssets > desiredReserve) {
           uint256 toEarn = availableAssets.sub(desiredReserve);
           console.log('** Earnable = %s', toEarn);
           strategyConfig[_strategy].wanttoken.safeTransfer(address(_strategy), toEarn);
           _strategy.deposit();
           strategyInfo[_strategy].sentToStrategy = strategyInfo[_strategy].sentToStrategy.add(toEarn);
        }
        strategyInfo[_strategy].keptReserve = available();
    }

    function withdrawAll() isConfigured external {
        withdraw(vaultTokens.sharetoken.balanceOf(msg.sender));
    }


    function withdraw(uint256 _shares) isConfigured public {
        console.log('** ENTER withdraw %s', _shares);
        uint256 r = (balance().mul(_shares)).div(vaultTokens.sharetoken.totalSupply());
        vaultTokens.sharetoken.burn(msg.sender, _shares);
        console.log('** withdraw burned %s', _shares);

        IStrategy _strategy = vaultConfig.activeStrategy;
        uint b = strategyConfig[_strategy].wanttoken.balanceOf(address(this));
        if (b < r) {
            uint _withdraw = r.sub(b);
            uint _yieldBefore = yieldBalance();
            console.log('** calling strategy.withdraw %s', _withdraw);
            _strategy.withdraw(_withdraw);
            console.log('** called strategy.withdraw %s', _withdraw);
            uint _yield = yieldBalance().sub(_yieldBefore);
            uint _after = strategyConfig[_strategy].wanttoken.balanceOf(address(this));
            uint _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
            console.log('** transferring %s yield', _yield);
            strategyConfig[_strategy].yieldtoken.safeTransfer(msg.sender, _yield);
            console.log('** transferred %s yield', _yield);
        }
        console.log('** transferring %s token', r);
        userInfo[msg.sender].withdrawn = userInfo[msg.sender].withdrawn.add(r);
        vault.withdrawn = vault.withdrawn.add(r);
        strategyConfig[_strategy].wanttoken.safeTransfer(msg.sender, r);
        console.log('** transferred %s token', r);

        console.log('** EXIT withdraw %s', _shares);
    }

    /*** Strategies ***/
    function upgradeAutomatedStrategist(address _automatedStrategist) public onlyOwner {
        vaultConfig.activeStrategy.withdrawAll();
        vaultConfig.automatedStrategist = IAutomatedStrategist(_automatedStrategist);
        chooseStrategy();
        earn();
    }
    
    function _switchStrategy(address _strategy) internal {
        if (address(vaultConfig.activeStrategy) == _strategy) return;
        vaultConfig.activeStrategy.withdrawAll();
        vaultConfig.activeStrategy.convertEarnableIntoDeposited();
        vaultConfig.activeStrategy = IStrategy(_strategy);
        emit SwitchedStrategy(_strategy, block.timestamp);
    }

    function chooseStrategy() isConfigured public {
        address _chosenStrategy = vaultConfig.automatedStrategist.chooseStrategy();
        if (_chosenStrategy != address(vaultConfig.activeStrategy) && allowedStrategy[_chosenStrategy]) {
           _switchStrategy(_chosenStrategy);
        }
    }

    function configureStrategy(address _strategy, address _wanttoken, address _yieldtoken, uint256 _reservePct) public onlyOwner {
        strategyConfig[IStrategy(_strategy)] = StrategyConfig({
            wanttoken: IERC20(_wanttoken),
            yieldtoken: IERC20(_yieldtoken),
            reservePct: _reservePct
        });
    }
    
    function allowStrategy(address _strategy) public onlyOwner {
        allowedStrategy[_strategy] = true;
        emit AddedAllowedStrategy(_strategy);
    }

    function disallowStrategy(address _strategy) public onlyOwner {
        allowedStrategy[_strategy] = false;
        emit AddedAllowedStrategy(_strategy);
    }

    function switchStrategy(address _strategy) public onlyOwner {
        _switchStrategy(_strategy);
    }
    
    function panic() public onlyStrategist {
        vaultConfig.activeStrategy.withdrawAll();
        vaultConfig.automatedStrategist.panic();
    }

}