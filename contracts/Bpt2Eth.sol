// Be Name KHODA
// Bime Abolfazl

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';


interface IBPool {
	function exitswapPoolAmountIn(address tokenOut, uint256 poolAmountIn, uint256 minAmountOut) external returns (uint256 tokenAmountOut);
	function transferFrom(address src, address dst, uint256 amt) external returns (bool);
}

interface IERC20 {
	function approve(address dst, uint256 amt) external returns (bool);
	function transfer(address recipient, uint256 amount) external returns (bool);
	function totalSupply() external view returns (uint);
}

interface Vault {
	function lockFor(uint256 amount, address _user) external returns (uint256);
}

interface SealedToken {
	function burn(address from, uint256 amount) external;
	function transfer(address recipient, uint256 amount) external returns (bool);
	function transferFrom(address src, address dst, uint256 amt) external returns (bool);
}

interface IUniswapV2Pair {
	function getReserves() external returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IUniswapV2Router02 {
	function removeLiquidityETH(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	) external returns (uint256 amountToken, uint256 amountETH);

	function removeLiquidity(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline
	) external returns (uint256 amountA, uint256 amountB);

	function swapExactTokensForTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapExactTokensForETH(
		uint amountIn,
		uint amountOutMin,
		address[] calldata path,
		address to,
		uint deadline
	) external returns (uint[] memory amounts);

	function getAmountsOut(uint256 amountIn, address[] memory path) external  returns (uint256[] memory amounts);
}

interface AutomaticMarketMaker {
	function calculatePurchaseReturn(uint256 etherAmount) external returns (uint256);
	function buy(uint256 _tokenAmount) external payable;
	function sell(uint256 tokenAmount, uint256 _etherAmount) external;
	function withdrawPayments(address payable payee) external;
}

contract SealdUniSwapper is Ownable {

	IBPool public bpt;
	IUniswapV2Router02 public uniswapRouter;
	AutomaticMarketMaker public AMM;
	Vault public sdeaVault;
	SealedToken public sdeus;
	SealedToken public sdea;
	SealedToken public sUniDD;
	SealedToken public sUniDE;
	SealedToken public sUniDU;
	address dea;
	address deus;
	address usdc;
	address uniDD;
	address uniDU;
	address uniDE;
	
	uint256 MAX_INT = type(uint256).max;

	constructor (
			address _uniswapRouter,
			address _bpt,
			address _amm,
			address _sdeaVault,
			address _sdea,
			address _sdeus,
			address _dea,
			address _deus,
			address _usdc,
			address _uniDD,
			address _uniDE,
			address _uniDU,
			address _sUniDD,
			address _sUniDE,
			address _sUniDU
		) {
		require(_uniswapRouter != address(0) &&
				_bpt != address(0) &&
				_amm !=  address(0) &&
				_sdeaVault !=  address(0) &&
				_sdea !=  address(0) &&
				_sdeus !=  address(0) &&
				_dea !=  address(0) &&
				_deus !=  address(0) &&
				_usdc !=  address(0) &&
				_uniDD !=  address(0) &&
				_uniDE !=  address(0) &&
				_uniDU !=  address(0) &&
				_sUniDD !=  address(0) &&
				_sUniDE !=  address(0) &&
				_sUniDU != address(0), "Wrong arguments");

		uniswapRouter = IUniswapV2Router02(_uniswapRouter);
		bpt = IBPool(_bpt);
		AMM = AutomaticMarketMaker(_amm);

		sdeaVault = Vault(_sdeaVault);

		dea = _dea;
		deus = _deus;
		usdc = _usdc;
		uniDD = _uniDD;
		uniDU = _uniDU;
		uniDE = _uniDE;

		sdea = SealedToken(_sdea);
		sdeus = SealedToken(_sdeus);
		sUniDD = SealedToken(_sUniDD);
		sUniDE = SealedToken(_sUniDE);
		sUniDU = SealedToken(_sUniDU);
		
		IERC20(_dea).approve(_uniswapRouter, MAX_INT);
		IERC20(_deus).approve(_uniswapRouter, MAX_INT);
		IERC20(_usdc).approve(_uniswapRouter, MAX_INT);
		IERC20(_uniDD).approve(_uniswapRouter, MAX_INT);
		IERC20(_uniDE).approve(_uniswapRouter, MAX_INT);
		IERC20(_uniDU).approve(_uniswapRouter, MAX_INT);
	}

	function approve(address token, address recipient, uint256 amount) external onlyOwner {
		IERC20(token).approve(recipient, amount);
	}

	function changeBPT(address _bpt) external onlyOwner {
		bpt = IBPool(_bpt);
	}

	function changeAMM(address _amm) external onlyOwner {
		AMM = AutomaticMarketMaker(_amm);
	}

	function bpt2eth(address tokenOut, uint256 poolAmountIn, uint256[] memory minAmountsOut, address[] memory path) external {
		bpt.transferFrom(msg.sender, address(this), poolAmountIn);
		uint256 deaAmount = bpt.exitswapPoolAmountIn(tokenOut, poolAmountIn, minAmountsOut[0]);
		uint256 deusAmount = uniswapRouter.swapExactTokensForTokens(deaAmount, minAmountsOut[1], path, address(this), block.timestamp + 1 days)[1];
		AMM.sell(deusAmount, minAmountsOut[2]);
		AMM.withdrawPayments(payable(msg.sender));
	}

	function bpt2Uni(address tokenOut, uint256 poolAmountIn, uint256[] memory minAmountsOut, address[] memory path) external {
		bpt.transferFrom(msg.sender, address(this), poolAmountIn);
		uint256 deaAmount = bpt.exitswapPoolAmountIn(tokenOut, poolAmountIn, minAmountsOut[0]);
		uniswapRouter.swapExactTokensForTokens(deaAmount, minAmountsOut[1], path, msg.sender, block.timestamp + 1 days);
	}

	function sdeus2sdea(uint256 amountIn, uint256 minAmountOut, address[] memory path) external {
		sdeus.burn(msg.sender, amountIn);
		uint256 deaAmount = uniswapRouter.swapExactTokensForTokens(amountIn, minAmountOut, path, address(this), block.timestamp + 1 days)[1];
		uint256 sdeaAmount = sdeaVault.lockFor(deaAmount, msg.sender);
		sdea.transfer(msg.sender, sdeaAmount);
	}

	function bpt2sdea(address tokenOut, uint256 poolAmountIn, uint256 minAmountOut) external {
		bpt.transferFrom(msg.sender, address(this), poolAmountIn);

		uint256 deaAmount = bpt.exitswapPoolAmountIn(tokenOut, poolAmountIn, minAmountOut);
		uint256 sdeaAmount = sdeaVault.lockFor(deaAmount, msg.sender);

		sdea.transfer(msg.sender, sdeaAmount);
	}

	function bpt2sdea(address tokenOut, uint256 poolAmountIn, uint256 minAmountOut, address[] memory path) external {

	}

	function sUniDD2sdea(uint256 sUniDDAmount, uint256 minAmountOut, address[] memory path) external {
		sUniDD.transferFrom(msg.sender, address(this), sUniDDAmount);

		uint256 totalSupply = IERC20(uniDD).totalSupply();
		(uint256 deusReserve, uint256 deaReserve, ) = IUniswapV2Pair(uniDD).getReserves();

		(uint256 deusAmount, uint256 deaAmount) = uniswapRouter.removeLiquidity(deus, dea, sUniDDAmount, (sUniDDAmount / totalSupply * deusReserve) * 95 / 100, (sUniDDAmount / totalSupply * deaReserve) * 95 / 100, address(this), block.timestamp + 1 days);

		uint256 deaAmount2 = uniswapRouter.swapExactTokensForTokens(deusAmount, minAmountOut, path, address(this), block.timestamp + 1 days)[1];

		uint256 sdeaAmount = sdeaVault.lockFor(deaAmount + deaAmount2, msg.sender);

		sdea.transfer(msg.sender, sdeaAmount);
	}

	function sUniDU2sdea() external {
		
	}

	function sUniDU2sdea(uint256 sUniDUAmount, uint256[] memory minAmountsOut, address[] memory path1, address[] memory path2) external {
		sUniDU.transferFrom(msg.sender, address(this), sUniDUAmount);

		uint256 totalSupply = IERC20(uniDU).totalSupply();
		(uint256 deaReserve, uint256 usdcReserve, ) = IUniswapV2Pair(uniDU).getReserves();

		(uint256 deaAmount, uint256 usdcAmount) = uniswapRouter.removeLiquidity(dea, usdc, (sUniDUAmount/1e5), ((sUniDUAmount/1e5) /  totalSupply * deaReserve) * 95 / 100, ((sUniDUAmount/1e5) / totalSupply * usdcReserve) * 95 / 100, address(this), block.timestamp + 1 days);


		uint256 ethAmount = uniswapRouter.swapExactTokensForETH(usdcAmount, minAmountsOut[0], path1, address(this), block.timestamp + 1 days)[1];

		uint256 deusAmount = AMM.calculatePurchaseReturn(ethAmount);
		AMM.buy{value: ethAmount}(deusAmount);
		
		uint256 deaAmount2 = uniswapRouter.swapExactTokensForTokens(deusAmount, minAmountsOut[1], path2, address(this), block.timestamp + 1 days)[1];

		uint256 sdeaAmount = sdeaVault.lockFor(deaAmount + deaAmount2, msg.sender);

		sdea.transfer(msg.sender, sdeaAmount);
	}

	function sUniDE2sdea() external {
		
	}

	function sUniDE2sdea(uint256 sUniDEAmount, uint256[] memory minAmountsOut, address[] memory path) external {
		sUniDE.transferFrom(msg.sender, address(this), sUniDEAmount);

		uint256 totalSupply = IERC20(uniDE).totalSupply();
		(uint256 deusReserve, uint256 wethReserve, ) = IUniswapV2Pair(uniDE).getReserves();
		(uint256 deusAmount, uint256 ethAmount) = uniswapRouter.removeLiquidityETH(deus, sUniDEAmount, (sUniDEAmount / totalSupply * deusReserve) * 95 / 100, (sUniDEAmount / totalSupply * wethReserve) * 95 / 100, address(this), block.timestamp + 1 days);
		uint256 deusAmount2 = AMM.calculatePurchaseReturn(ethAmount);
		AMM.buy{value: ethAmount}(deusAmount2);
		uint256 deaAmount = uniswapRouter.swapExactTokensForTokens(deusAmount + deusAmount2, minAmountsOut[0], path, address(this), block.timestamp + 1 days)[1];

		uint256 sdeaAmount = sdeaVault.lockFor(deaAmount, msg.sender);

		sdea.transfer(msg.sender, sdeaAmount);
	}

	function withdraw(address token, uint256 amount, address to) external onlyOwner {
		IERC20(token).transfer(to, amount);
	}

	receive() external payable {}
}

// Dar panahe Khoda