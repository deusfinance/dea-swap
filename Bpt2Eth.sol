// Be Name KHODA

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.1/contracts/access/Ownable.sol';


interface IBPool {
	function exitswapPoolAmountIn(address tokenOut, uint poolAmountIn, uint minAmountOut) external returns (uint tokenAmountOut);
	function transferFrom(address src, address dst, uint amt) external returns (bool);
}

interface IERC20 {
	function approve(address dst, uint amt) external returns (bool);
	function transfer(address recipient, uint256 amount) external returns (bool);
}

interface Vault {
	function lockFor(uint256 amount, address _user) external returns (uint256);
}

interface SealdToken {
	function burn(address from, uint256 amount) external;
	function transfer(address recipient, uint256 amount) external returns (bool);
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

contract ExitLock is Ownable {

	IBPool public bpt;
	IUniswapV2Router02 public uniswapRouter;
	AutomaticMarketMaker public AMM;
	Vault public sdeaVault;
	SealdToken public sdeus;
	SealdToken public sdea;
	
	uint256 MAX_INT = type(uint256).max;

	constructor (address _uniswapRouter, address _bpt, address _amm, address _sdeaVault, address _sdea, address _sdeus, address dea, address deus) {
		uniswapRouter = IUniswapV2Router02(_uniswapRouter);
		bpt = IBPool(_bpt);
		AMM = AutomaticMarketMaker(_amm);

		sdeaVault = Vault(_sdeaVault);

		sdea = SealdToken(_sdea);
		sdeus = SealdToken(_sdeus);
		
		IERC20(dea).approve(_uniswapRouter, MAX_INT);
		IERC20(deus).approve(_uniswapRouter, MAX_INT);
	}

	function approve(address token, address recipient, uint amount) external onlyOwner {
		IERC20(token).approve(recipient, amount);
	}

	function changeBPT(address _bpt) onlyOwner {
		bpt = IBPool(_bpt);
	}

	function changeAMM(address _amm) onlyOwner {
		AMM = AutomaticMarketMaker(_amm);
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

	function sdeus2sdea(uint256 amountIn, uint minAmountsOut, address[] memory path) external {
		sdeus.burn(msg.sender, amountIn);
		uint deaAmount = uniswapRouter.swapExactTokensForTokens(amountIn, minAmountsOut, path, address(this), block.timestamp + 1 days)[1];
		uint sdeaAmount = sdeaVault.lockFor(deaAmount, msg.sender);
		sdea.transfer(msg.sender, sdeaAmount);
	}

	function bpt2sdea(address tokenOut, uint poolAmountIn, uint minAmountsOut, address[] memory path) external {
		bpt.transferFrom(msg.sender, address(this), poolAmountIn);
		uint deaAmount = bpt.exitswapPoolAmountIn(tokenOut, poolAmountIn, minAmountsOut);
		uint sdeaAmount = sdeaVault.lockFor(deaAmount, msg.sender);
		sdea.transfer(msg.sender, sdeaAmount);
	}


	function withdraw(address token, uint amount, address to) onlyOwner {
		IERC20(token).transfer(to, amount);
	}

}