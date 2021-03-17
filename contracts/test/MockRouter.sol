// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "../common/SafeMath.sol";
import "../common/SafeERC20.sol";

contract MockRouter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public  returns (uint amountA, uint amountB, uint liquidity) {
        return (uint(0), uint(0), uint(0));
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public  payable returns (uint amountToken, uint amountETH, uint liquidity) {
        return (uint(0), uint(0), uint(0));
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public  returns (uint amountA, uint amountB) {
        return (uint(0), uint(0));
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public  returns (uint amountToken, uint amountETH) {
        return (uint(0), uint(0));
    }

    function swapExactTokensForTokens(
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline
    ) public  returns (uint[] memory amounts) {
        IERC20(path[0]).safeTransferFrom(msg.sender,address(this), amountIn);
        IERC20(path[path.length-1]).safeTransfer(msg.sender, amountIn);        
        uint[] memory results = new uint[](2);
        results[0] = uint(0);
        results[1] = uint(0);
        return results;
    }

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        public 
        payable
        returns (uint[] memory amounts) {
        uint[] memory results = new uint[](2);
        results[0] = uint(0);
        results[1] = uint(0);
        return results;
    }
    
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        public 
        returns (uint[] memory amounts) {
        uint[] memory results = new uint[](2);
        results[0] = uint(0);
        results[1] = uint(0);
        return results;
    }
}
