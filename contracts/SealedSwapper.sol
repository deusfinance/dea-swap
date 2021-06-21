// Be Name KHODA
// Bime Abolfazl

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";


interface IBPool {
	function totalSupply() external view returns (uint);
	function exitPool(uint poolAmountIn, uint[] calldata minAmountsOut) external;
	function exitswapPoolAmountIn(address tokenOut, uint256 poolAmountIn, uint256 minAmountOut) external returns (uint256 tokenAmountOut);
	function transferFrom(address src, address dst, uint256 amt) external returns (bool);
}

interface IERC20 {
	function approve(address dst, uint256 amt) external returns (bool);
	function totalSupply() external view returns (uint);
	function burn(address from, uint256 amount) external;
	function transfer(address recipient, uint256 amount) external returns (bool);
	function transferFrom(address src, address dst, uint256 amt) external returns (bool);
	function balanceOf(address owner) external view returns (uint);
}

interface Vault {
	function lockFor(uint256 amount, address _user) external returns (uint256);
}

interface IUniswapV2Pair {
	function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
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
	function calculateSaleReturn(uint256 tokenAmount) external view returns (uint256);
	function calculatePurchaseReturn(uint256 etherAmount) external returns (uint256);
	function buy(uint256 _tokenAmount) external payable;
	function sell(uint256 tokenAmount, uint256 _etherAmount) external;
	function withdrawPayments(address payable payee) external;
}

contract SealedSwapper is AccessControl {

	bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
	bytes32 public constant ADMIN_SWAPPER_ROLE = keccak256("ADMIN_SWAPPER_ROLE");

	IBPool public bpt;
	IUniswapV2Router02 public uniswapRouter;
	AutomaticMarketMaker public AMM;
	Vault public sdeaVault;
	IERC20 public sdeus;
	IERC20 public sdea;
	IERC20 public sUniDD;
	IERC20 public sUniDE;
	IERC20 public sUniDU;
	IERC20 public dea;
	IERC20 public deus;
	IERC20 public usdc;
	IERC20 public uniDD;
	IERC20 public uniDU;
	IERC20 public uniDE;

	address[] public usdc2wethPath =  [0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2];
	address[] public deus2deaPath =  [0x3b62F3820e0B035cc4aD602dECe6d796BC325325, 0x80aB141F324C3d6F2b18b030f1C4E95d4d658778];
	

	uint256 public MAX_INT = type(uint256).max;
	uint256 public scale = 1e18;
	uint256 public DDRatio;
	uint256 public DERatio;
	uint256 public DURatio;
	uint256 public deusRatio;

	event Swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

	constructor (
			address _uniswapRouter,
			address _bpt,
			address _amm,
			address _sdeaVault
		) {

		uniswapRouter = IUniswapV2Router02(_uniswapRouter);
		bpt = IBPool(_bpt);
		AMM = AutomaticMarketMaker(_amm);

		sdeaVault = Vault(_sdeaVault);
	}
	
	function init(
		address[] memory tokens
	) external {
		require(hasRole(OPERATOR_ROLE, msg.sender), "Caller is not an operator");
		sdea = IERC20(tokens[0]);
		sdeus = IERC20(tokens[1]);
		sUniDD = IERC20(tokens[2]);
		sUniDE = IERC20(tokens[3]);
		sUniDU = IERC20(tokens[4]);
		dea = IERC20(tokens[5]);
		deus = IERC20(tokens[6]);
		usdc = IERC20(tokens[7]);
		uniDD = IERC20(tokens[8]);
		uniDU = IERC20(tokens[9]);
		uniDE = IERC20(tokens[10]);
		dea.approve(address(uniswapRouter), MAX_INT);
		deus.approve(address(uniswapRouter), MAX_INT);
		usdc.approve(address(uniswapRouter), MAX_INT);
		uniDD.approve(address(uniswapRouter), MAX_INT);
		uniDE.approve(address(uniswapRouter), MAX_INT);
		uniDU.approve(address(uniswapRouter), MAX_INT);
		dea.approve(address(sdeaVault), MAX_INT);
	}

	function setRatios(uint256 _DERatio, uint256 _DURatio, uint256 _DDRatio, uint256 _deusRatio) external {
		require(hasRole(OPERATOR_ROLE, msg.sender), "Caller is not an operator");
		DDRatio = _DDRatio;
		DURatio = _DURatio;
		DERatio = _DERatio;
		deusRatio = _deusRatio;
	}

	function setRoutes(address[] memory _usdc2weth, address[] memory _deus2dea) external {
		require(hasRole(OPERATOR_ROLE, msg.sender), "Caller is not an operator");
		usdc2wethPath = _usdc2weth;
		deus2deaPath = _deus2dea;
	}
	
	function setBPT(address _bpt) external {
		require(hasRole(OPERATOR_ROLE, msg.sender), "Caller is not an operator");
		bpt = IBPool(_bpt);
	}

	function approve(address token, address recipient, uint256 amount) external {
		require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
		IERC20(token).approve(recipient, amount);
	}

	function bpt2eth(address tokenOut, uint256 poolAmountIn, uint256[] memory minAmountsOut) public {
		bpt.transferFrom(msg.sender, address(this), poolAmountIn);
		uint256 deaAmount = bpt.exitswapPoolAmountIn(tokenOut, poolAmountIn, minAmountsOut[0]);
		uint256 deusAmount = uniswapRouter.swapExactTokensForTokens(deaAmount, minAmountsOut[1], deus2deaPath, address(this), block.timestamp + 1 days)[1];
		uint256 ethAmount = AMM.calculateSaleReturn(deusAmount);
		AMM.sell(deusAmount, minAmountsOut[2]);
		AMM.withdrawPayments(payable(address(this)));
		payable(msg.sender).transfer(ethAmount);
	}

	function deus2dea(uint256 amountIn) internal returns(uint256) {
		return  uniswapRouter.swapExactTokensForTokens(amountIn, 1, deus2deaPath, address(this), block.timestamp + 1 days)[1];
	}

	function bpt2sdea(address tokenOut, uint256 poolAmountIn, uint256 minAmountOut) public {
		bpt.transferFrom(msg.sender, address(this), poolAmountIn);

		uint256 deaAmount = bpt.exitswapPoolAmountIn(tokenOut, poolAmountIn, minAmountOut);
		uint256 sdeaAmount = sdeaVault.lockFor(deaAmount, address(this));

		sdea.transfer(msg.sender, sdeaAmount);
		emit Swap(address(bpt), address(sdea), poolAmountIn, sdeaAmount);
	}

	function sdea2dea(uint256 amount, address recipient) external {
		require(hasRole(ADMIN_SWAPPER_ROLE, msg.sender), "Caller is not an ADMIN_SWAPPER_ROLE");
		sdea.burn(msg.sender, amount);
		dea.transfer(recipient, amount);
		
		emit Swap(address(sdea), address(dea), amount, amount);
	}

	function sdeus2deus(uint256 amount, address recipient) external {
		require(hasRole(ADMIN_SWAPPER_ROLE, msg.sender), "Caller is not an ADMIN_SWAPPER_ROLE");
		sdeus.burn(msg.sender, amount);
		dea.transfer(recipient, amount);

		emit Swap(address(sdeus), address(deus), amount, amount);
	}

	function sUniDE2UniDE(uint256 amount, address recipient) external {
		require(hasRole(ADMIN_SWAPPER_ROLE, msg.sender), "Caller is not an ADMIN_SWAPPER_ROLE");
		sUniDE.burn(msg.sender, amount);
		uniDE.transfer(recipient, amount);

		emit Swap(address(sUniDE), address(uniDE), amount, amount);
	}

	function sUniDD2UniDD(uint256 amount, address recipient) external {
		require(hasRole(ADMIN_SWAPPER_ROLE, msg.sender), "Caller is not an ADMIN_SWAPPER_ROLE");
		sUniDD.burn(msg.sender, amount);
		uniDD.transfer(recipient, amount);

		emit Swap(address(sUniDD), address(uniDD), amount, amount);
	}

	function sUNIDU2UniDU(uint256 amount, address recipient) external {
		require(hasRole(ADMIN_SWAPPER_ROLE, msg.sender), "Caller is not an ADMIN_SWAPPER_ROLE");
		sUniDU.burn(msg.sender, amount);
		uniDU.transfer(recipient, amount/1e5);

		emit Swap(address(sUniDU), address(uniDU), amount, amount/1e5);
	}

	function deaExitAmount(uint256 Predeemed) public view returns(uint256) {
		uint256 Psupply = bpt.totalSupply();
		uint256 Bk = dea.balanceOf(address(bpt));
		return (1 - ((Psupply - Predeemed) / Psupply)) * Bk;
	}

	function bpt2sdea(
		uint256 poolAmountIn,
		uint256[] memory balancerMinAmountsOut,
		uint256 minAmountOut
	) external {
		bpt.transferFrom(msg.sender, address(this), poolAmountIn);
		uint256 deaAmount = deaExitAmount(poolAmountIn);

		bpt.exitPool(poolAmountIn, balancerMinAmountsOut);

		uint256 sdeusAmount = sdeus.balanceOf(address(this));
		sdeus.burn(address(this), sdeusAmount);
		deaAmount += deus2dea(sdeusAmount * deusRatio / scale);

		uint256 sUniDDAmount = sUniDD.balanceOf(address(this));
		sUniDD.burn(address(this), sUniDDAmount);
		deaAmount += uniDD2sdea(sUniDDAmount * DDRatio / scale);

		uint256 sUniDEAmount = sUniDE.balanceOf(address(this));
		sUniDE.burn(address(this), sUniDEAmount);
		deaAmount += uniDE2sdea(sUniDEAmount * DERatio / scale);
		
		uint256 sUniDUAmount = sUniDU.balanceOf(address(this));
		sUniDU.burn(address(this), sUniDUAmount);
		deaAmount += uniDU2sdea(sUniDUAmount * DURatio / scale);

		require(deaAmount >= minAmountOut, "INSUFFICIENT_OUTPUT_AMOUNT");

		sdeaVault.lockFor(deaAmount, address(this));
		sdea.transfer(msg.sender, deaAmount);

		emit Swap(address(bpt), address(sdea), poolAmountIn, deaAmount);
	}

	function uniDD2sdea(uint256 sUniDDAmount) internal returns(uint256) {
		(uint256 deusAmount, uint256 deaAmount) = uniswapRouter.removeLiquidity(address(deus), address(dea), sUniDDAmount, 1, 1, address(this), block.timestamp + 1 days);

		uint256 deaAmount2 = uniswapRouter.swapExactTokensForTokens(deusAmount, 1, deus2deaPath, address(this), block.timestamp + 1 days)[1];

		return deaAmount + deaAmount2;
	}

	function sUniDD2sdea(uint256 sUniDDAmount, uint256 minAmountOut) public {
		sUniDD.burn(msg.sender, sUniDDAmount);

		uint256 deaAmount = uniDD2sdea(sUniDDAmount / DDRatio * scale);

		require(deaAmount >= minAmountOut, "INSUFFICIENT_OUTPUT_AMOUNT");
		sdeaVault.lockFor(deaAmount, address(this));
		sdea.transfer(msg.sender, deaAmount);

		emit Swap(address(uniDD), address(sdea), sUniDDAmount, deaAmount);
	}

	function uniDU2sdea(uint256 sUniDUAmount) internal returns(uint256) {
		(uint256 deaAmount, uint256 usdcAmount) = uniswapRouter.removeLiquidity(address(dea), address(usdc), (sUniDUAmount/1e5), 1, 1, address(this), block.timestamp + 1 days);

		uint256 ethAmount = uniswapRouter.swapExactTokensForETH(usdcAmount, 1, usdc2wethPath, address(this), block.timestamp + 1 days)[1];

		uint256 deusAmount = AMM.calculatePurchaseReturn(ethAmount);
		AMM.buy{value: ethAmount}(deusAmount);
		
		uint256 deaAmount2 = uniswapRouter.swapExactTokensForTokens(deusAmount, 1, deus2deaPath, address(this), block.timestamp + 1 days)[1];

		return deaAmount + deaAmount2;
	}
	

	function sUniDU2sdea(uint256 sUniDUAmount, uint256 minAmountOut) public {
		sUniDU.burn(msg.sender, sUniDUAmount);

		uint256 deaAmount = uniDU2sdea(sUniDUAmount * DURatio / scale);

		require(deaAmount >= minAmountOut, "INSUFFICIENT_OUTPUT_AMOUNT");
		sdeaVault.lockFor(deaAmount, address(this));
		sdea.transfer(msg.sender, deaAmount);
		
		emit Swap(address(uniDU), address(sdea), sUniDUAmount, deaAmount);
	}

	function uniDE2sdea(uint256 sUniDEAmount) internal returns(uint256) {
		(uint256 deusAmount, uint256 ethAmount) = uniswapRouter.removeLiquidityETH(address(deus), sUniDEAmount, 1, 1, address(this), block.timestamp + 1 days);
		uint256 deusAmount2 = AMM.calculatePurchaseReturn(ethAmount);
		AMM.buy{value: ethAmount}(deusAmount2);
		uint256 deaAmount = uniswapRouter.swapExactTokensForTokens(deusAmount + deusAmount2, 1, deus2deaPath, address(this), block.timestamp + 1 days)[1];
		return deaAmount;
	}

	function sUniDE2sdea(uint256 sUniDEAmount, uint256 minAmountOut) public {
		sUniDE.burn(msg.sender, sUniDEAmount);

		uint256 deaAmount = uniDE2sdea(sUniDEAmount * DERatio / scale);

		require(deaAmount >= minAmountOut, "INSUFFICIENT_OUTPUT_AMOUNT");
		sdeaVault.lockFor(deaAmount, address(this));
		sdea.transfer(msg.sender, deaAmount);

		emit Swap(address(uniDE), address(sdea), sUniDEAmount, deaAmount);
	}

	function withdraw(address token, uint256 amount, address to) public {
		require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an operator");
		IERC20(token).transfer(to, amount);
	}

	receive() external payable {}
}

// Dar panahe Khoda