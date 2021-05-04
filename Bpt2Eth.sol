// Be Name KHODA

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol';


interface IBPool {
	function exitswapPoolAmountIn(address tokenOut, uint poolAmountIn, uint minAmountOut) external returns (uint tokenAmountOut);
	function transferFrom(address src, address dst, uint amt) external returns (bool);
}

interface IERC20 {
	function approve(address dst, uint amt) external returns (bool);
}

interface IUniswapV2Router02 {
	function swapExactTokensForTokens(
	uint amountIn,
	uint amountOutMin,
	address[] calldata path,
	address to,
	uint deadline
	) external returns (uint[] memory amounts);
}

interface AutomaticMarketMaker {
	function sell(uint256 tokenAmount, uint256 _etherAmount) external;
	function withdrawPayments(address payable payee) external;
}

contract ExitBalancer is Ownable {

	IBPool public bpt;
	IUniswapV2Router02 public uniswapRouter;
	AutomaticMarketMaker public AMM;
	uint256 MAX_INT = type(uint256).max;

	constructor (address _uniswapRouter, address _bpt, address _amm, address deaToken) {
		uniswapRouter = IUniswapV2Router02(_uniswapRouter);
		bpt = IBPool(_bpt);
		AMM = AutomaticMarketMaker(_amm);
		
		IERC20(deaToken).approve(_uniswapRouter, MAX_INT);
	}

	function approve(address token, address recipient, uint amount) external onlyOwner {
		IERC20(token).approve(recipient, amount);
	}

	function bpt2Eth(address tokenOut, uint poolAmountIn, uint[] memory minAmountsOut, address[] memory path) external {
		bpt.transferFrom(msg.sender, address(this), poolAmountIn);
		uint deaAmount = bpt.exitswapPoolAmountIn(tokenOut, poolAmountIn, minAmountsOut[0]);
		uint deusAmount = uniswapRouter.swapExactTokensForTokens(deaAmount, minAmountsOut[1], path, address(this), block.timestamp + 1 days)[1];
		AMM.sell(deusAmount, minAmountsOut[2]);
		AMM.withdrawPayments(payable(msg.sender));
	}

	function bpt2Uni(address tokenOut, uint poolAmountIn, uint[] memory minAmountsOut, address[] memory path) external {
		bpt.transferFrom(msg.sender, address(this), poolAmountIn);
		uint deaAmount = bpt.exitswapPoolAmountIn(tokenOut, poolAmountIn, minAmountsOut[0]);
		uniswapRouter.swapExactTokensForTokens(deaAmount, minAmountsOut[1], path, msg.sender, block.timestamp + 1 days);
	}
}