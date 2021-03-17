const Weth = artifacts.require("Weth");
const BetaDollar = artifacts.require("BetaDollar");
const BetaShare = artifacts.require("BetaShare");
const BetaStable = artifacts.require("BetaStable");
const StrategyHodl = artifacts.require("StrategyHodl");
const BasisVault = artifacts.require("BasisVaultV2");
const AutomatedStrategist = artifacts.require("AutomatedStrategist");
const StrategyChefStakingPool = artifacts.require("StrategyChefStakingPool");
const MockMasterChef = artifacts.require("MockMasterChef");
const MockRouter = artifacts.require("MockRouter");
const MockOracle = artifacts.require("MockOracle");

const BigNumber = require('bignumber.js');

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// test
describe("TestSuite: Test", function() {
      let provider;
      let signer;
      let first_account;
      let test_account;
      
      before(async function() {
          provider = ethers.provider;
          signer = await provider.getSigner()
          let accounts = await ethers.getSigners();
          first_account = accounts[0].address;
          console.log("your account = "+first_account);
          
          
      });
      try { 
          it("Contract: BasisVault", async function() {
          var dollar = await BetaDollar.new();
          await dollar.setBalanceTo(first_account, new BigNumber(1000*1e18).toFixed());
          console.log('BetaDollar contract : '+dollar.address);
          var share = await BetaDollar.new();
          await share.setBalanceTo(first_account, new BigNumber(1000*1e18).toFixed());
          console.log('BetaShare contract : '+share.address);
          var stable = await BetaStable.new();
          await stable.setBalanceTo(first_account, new BigNumber(1000*1e18).toFixed());
          console.log('BetaStable contract : '+stable.address);
          
          var strategyHodl = await StrategyHodl.new(dollar.address);
          console.log('StrategyHodl : '+strategyHodl.address);
          
          var automatedStrategist = await AutomatedStrategist.new();
          console.log('AutomatedStrategist contract : '+ automatedStrategist.address);
                    
          var vault = await BasisVault.new(dollar.address, dollar.address, strategyHodl.address, 'BasisVault', 'BV', 0);
          console.log('BasisVault contract : '+vault.address);
          vault.configureStrategy(strategyHodl.address, await strategyHodl.want(), share.address, 0);
          vault.allowStrategy(strategyHodl.address);
          vault.configureVault(dollar.address, share.address, strategyHodl.address, automatedStrategist.address, "BAC VaultShare", "BACvs");

          strategyHodl.transferOwnership(vault.address);
          var oracle = await MockOracle.new();
          console.log('MockOracle contract : '+oracle.address);
          
          var abovePegThreshold = new BigNumber(105 * 1e16).toFixed();
          var belowPegThreshold =  new BigNumber(95 * 1e16).toFixed();
          automatedStrategist.configure(vault.address, oracle.address, strategyHodl.address, strategyHodl.address, strategyHodl.address, strategyHodl.address, abovePegThreshold, belowPegThreshold);
          
          await dollar.approve(vault.address, new BigNumber(1000*1e18));
          console.log('*** Approved 1000 BAC to vault');
          
          var vault_tvl;
          var vault_bal;
          var strategy_bal;
          vault_tvl = await vault.totalSupply();
          console.log('Vault TVL = '+vault_tvl);
          vault_bal = await vault.balance();
          console.log('Vault BAL = '+vault_bal);
          strategy_bal = await strategyHodl.balanceOf();
          console.log('StrategyHodl BAL = '+strategy_bal);
          await vault.depositAll();
          console.log('*** Deposited all BAC into vault');
          vault_tvl = await vault.totalSupply();
          console.log('Vault TVL = '+vault_tvl);
          vault_bal = await vault.balance();
          console.log('Vault BAL = '+vault_bal);
          strategy_bal = await strategyHodl.balanceOf();
          console.log('StrategyHodl BAL = '+strategy_bal);
          
          var router = await MockRouter.new();
          var mock_masterchef = await MockMasterChef.new(dollar.address, dollar.address);
          console.log('MockMasterChef contract : '+mock_masterchef.address);
          var masterchef_dollar = mock_masterchef.address;
          var bac = dollar.address;
          var weth = await Weth.new();
          var route_token = weth.address;
          var fee_token = weth.address;
          var strategist = '0x066419EaEf5DE53cc5da0d8702b990c5bc7D1AB3';
          var treasury = '0x066419EaEf5DE53cc5da0d8702b990c5bc7D1AB3';
          await dollar.setBalanceTo(masterchef_dollar, new BigNumber(10000*1e18).toFixed());
          await dollar.setBalanceTo(router.address, new BigNumber(10000*1e18).toFixed());
          await dollar.setBalanceTo(router.address, new BigNumber(10000*1e18).toFixed());
          await weth.setBalanceTo(router.address, new BigNumber(10000*1e18).toFixed());
          var strategyChefStakingPool = await StrategyChefStakingPool.new(router.address, dollar.address, masterchef_dollar, bac, route_token, fee_token, vault.address, strategist, treasury);
          console.log('StrategyChefStakingPool contract : '+strategyChefStakingPool.address);
          vault.configureStrategy(strategyChefStakingPool.address, dollar.address, share.address, 0);
          vault.allowStrategy(strategyChefStakingPool.address);
          strategyChefStakingPool.transferOwnership(vault.address);
          
          strategy_bal = await strategyChefStakingPool.balanceOf();
          console.log('StrategyChefStakingPool BAL = '+strategy_bal);

          await vault.allowStrategy(strategyChefStakingPool.address);
          console.log('*** proposed strategyChefStakingPool for vault');
          await sleep(100);
          await vault.switchStrategy(strategyChefStakingPool.address);
          console.log('*** switched strategy in vault to strategyChefStakingPool');
          strategy_bal = await strategyHodl.balanceOf();
          console.log('StrategyHodl BAL = '+strategy_bal);
          strategy_bal = await strategyChefStakingPool.balanceOf();
          console.log('StrategyChefStakingPool BAL = '+strategy_bal);
          
          await dollar.setBalanceTo(first_account, new BigNumber(100*1e18).toFixed());
          await dollar.approve(vault.address, new BigNumber(100*1e18));
          console.log('*** Approved 100 BAC to vault');

          vault_tvl = await vault.totalSupply();
          console.log('Vault TVL = '+vault_tvl);
          vault_bal = await vault.balance();
          console.log('Vault BAL = '+vault_bal);
          await vault.depositAll();
          console.log('*** Deposited all BAC into vault');
          
          vault_tvl = await vault.totalSupply();
          console.log('Vault TVL = '+vault_tvl);
          vault_bal = await vault.balance();
          console.log('Vault BAL = '+vault_bal);
          strategy_bal = await strategyChefStakingPool.balanceOf();
          console.log('StrategyChefStakingPool BAL = '+strategy_bal);

          console.log('*** Calling withdraw from test');
          await vault.withdraw(new BigNumber(1050*1e18).toFixed());
          console.log('*** Withdrawn 1050 BAC from vault');
          vault_tvl = await vault.totalSupply();
          console.log('Vault TVL = '+vault_tvl);
          vault_bal = await vault.balance();
          console.log('Vault BAL = '+vault_bal);
          strategy_bal = await strategyChefStakingPool.balanceOf();
          console.log('StrategyChefStakingPool BAL = '+strategy_bal);
       });
          
      } catch(err) {
          console.log("ERROR: "+err);
          throw err;
      }
      console.log("[DONE]");
});

