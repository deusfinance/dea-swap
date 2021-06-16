// Be name Khoda
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";	


interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);
        
    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        returns (uint256[] memory amounts);

    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
}

interface IAutomaticMarketMaker {
	function calculatePurchaseReturn(uint256 wethAmount) external view returns (uint256, uint256);
	function buyFor(address user, uint256 _dbEthAmount, uint256 _wethAmount) external;
	function calculateSaleReturn(uint256 dbEthAmount) external view returns (uint256, uint256);
	function sellFor(address user, uint256 dbEthAmount, uint256 _wethAmount) external;
}

interface IWethProxy {
	function sell(address user, uint256 dbEthAmount, uint256 _wethAmount) external;
	function buy(address user, uint256 _dbEthAmount, uint256 _wethAmount) external payable;
}

contract MultiSwap is Ownable {
	using SafeERC20 for IERC20;
	uint256 MAX_INT = type(uint256).max;

	IAutomaticMarketMaker public automaticMarketMaker;
	IWethProxy public wethProxy;
	IUniswapV2Router02 public uniswapRouter;
	address public dbETH;
	
	event swap(address user, address fromToken, address toToken, uint256 amountIn, uint256 amountOut);

	constructor(
		address _uniswapRouter,
		address _automaticMarketMaker,
		address _wethProxy,
		address _dbETH,
		address _dea,
		address _usdc,
		address _dai,
		address _wbtc,
		address _usdt) {

		uniswapRouter = IUniswapV2Router02(_uniswapRouter);
		automaticMarketMaker = IAutomaticMarketMaker(_automaticMarketMaker);
		wethProxy = IWethProxy(_wethProxy);

		dbETH = _dbETH;
		IERC20(dbETH).safeApprove(address(uniswapRouter), MAX_INT);
		IERC20(_dea).safeApprove(address(uniswapRouter), MAX_INT);
		IERC20(_usdc).safeApprove(address(uniswapRouter), MAX_INT);
		IERC20(_dai).safeApprove(address(uniswapRouter), MAX_INT);
		IERC20(_wbtc).safeApprove(address(uniswapRouter), MAX_INT);
		IERC20(_usdt).safeApprove(address(uniswapRouter), MAX_INT);
	}

	function setAutomaticMarketMaker(address _automaticMarketMaker) public onlyOwner {
		automaticMarketMaker = IAutomaticMarketMaker(_automaticMarketMaker);
	}

	function setWethProxy(address _wethProxy) public onlyOwner {
		wethProxy = IWethProxy(_wethProxy);
	}

	function safeApprove(address token, address _where) public onlyOwner {
		IERC20(token).safeApprove(_where, MAX_INT);
	}

	
	function ETH_dbETH_UNI(
		address[] memory path,
		uint256 minAmountOut
	) external payable {
		uint256 calcMinAmountOut = Calc_ETH_dbETH_UNI(msg.value, path);
        require(minAmountOut >= calcMinAmountOut, "Price Changed");

		(uint256 dbEthAmount, ) = automaticMarketMaker.calculatePurchaseReturn(msg.value);
		wethProxy.buy{value: msg.value}(address(this), dbEthAmount, msg.value);

		uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(dbEthAmount, minAmountOut, path, msg.sender, block.timestamp + 5 days);

		emit swap(msg.sender, address(0), path[path.length - 1], msg.value, amounts[amounts.length - 1]);
	}

    function Calc_ETH_dbETH_UNI(
        uint256 amountIn,
		address[] memory path
	) public view returns(uint256) {
		(uint256 dbEthAmount, ) = automaticMarketMaker.calculatePurchaseReturn(amountIn);

		uint256[] memory amounts = uniswapRouter.getAmountsOut(dbEthAmount, path);

		return amounts[amounts.length - 1];
	}
	
	function UNI_ETH_dbETH_UNI(
		uint256 amountIn,
		address[] memory path1,
		address[] memory path2,
		uint256 minAmountOut
	) external {
		uint256 calcMinAmountOut = Calc_UNI_ETH_dbETH_UNI(amountIn, path1, path2);
        require(minAmountOut >= calcMinAmountOut, "Price Changed");


		IERC20(address(path1[0])).safeTransferFrom(msg.sender, address(this), amountIn);

		uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, address(this), block.timestamp + 5 days);
		uint256 wethAmount = amounts[amounts.length - 1];

		(uint256 dbEthAmount, ) = automaticMarketMaker.calculatePurchaseReturn(wethAmount);
		if(path2.length > 1) {
			automaticMarketMaker.buyFor(address(this), dbEthAmount, wethAmount);
			
			amounts = uniswapRouter.swapExactTokensForTokens(dbEthAmount, minAmountOut, path2, msg.sender, block.timestamp + 5 days);
			emit swap(msg.sender, path1[0], path2[path2.length - 1], amountIn, amounts[amounts.length - 1]);
		} else {
			automaticMarketMaker.buyFor(msg.sender, dbEthAmount, wethAmount);
			emit swap(msg.sender, path1[0], dbETH, amountIn, dbEthAmount);
		}	
	}

    function Calc_UNI_ETH_dbETH_UNI(
		uint256 amountIn,
		address[] memory path1,
		address[] memory path2
	) public view returns(uint256) {

		uint256[] memory amounts = uniswapRouter.getAmountsOut(amountIn, path1);
		uint256 wethAmount = amounts[amounts.length - 1];

		(uint256 dbEthAmount, ) = automaticMarketMaker.calculatePurchaseReturn(wethAmount);
		if(path2.length > 1) {
			amounts = uniswapRouter.getAmountsOut(dbEthAmount, path2);
			return amounts[amounts.length - 1];
		} else {
			return dbEthAmount;
		}	
	}


	function UNI_dbETH_ETH(
		uint256 amountIn,
		address[] memory path,
		uint256 minAmountOut
	) external {
		uint256 calcMinAmountOut = Calc_UNI_dbETH_ETH(amountIn, path);
        require(minAmountOut >= calcMinAmountOut, "Price Changed");
		
		IERC20(address(path[0])).safeTransferFrom(msg.sender, address(this), amountIn);
		uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path, address(this), block.timestamp + 5 days);
		amountIn = amounts[amounts.length - 1];
		
		(uint256 wethAmount, ) = automaticMarketMaker.calculateSaleReturn(amountIn);
		wethProxy.sell(msg.sender, amountIn, wethAmount);

		emit swap(msg.sender, path[0], address(0), amountIn, wethAmount);
	}

    function Calc_UNI_dbETH_ETH(
		uint256 amountIn,
		address[] memory path
	) public view returns(uint256) {
		
		uint256[] memory amounts = uniswapRouter.getAmountsOut(amountIn, path);
		amountIn = amounts[amounts.length - 1];
		
		(uint256 wethAmount, ) = automaticMarketMaker.calculateSaleReturn(amountIn);
        return wethAmount;
	}

	function UNI_dbETH_ETH_UNI(
		uint256 amountIn,
		address[] memory path1,
		address[] memory path2,
		uint256 minAmountOut
	) external {
		uint256 calcMinAmountOut = Calc_UNI_dbETH_ETH_UNI(amountIn, path1, path2);
        require(minAmountOut >= calcMinAmountOut, "Price Changed");

		IERC20(address(path1[0])).safeTransferFrom(msg.sender, address(this), amountIn);
		
		uint256[] memory amounts;
		
		if(path1.length > 1) {
			amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, address(this), block.timestamp + 5 days);
			amountIn = amounts[amounts.length - 1];
		}

		(uint256 wethAmount, ) = automaticMarketMaker.calculateSaleReturn(amountIn);
		automaticMarketMaker.sellFor(address(this), amountIn, wethAmount);

		amounts = uniswapRouter.swapExactTokensForTokens(wethAmount, minAmountOut, path2, msg.sender, block.timestamp + 5 days);

		emit swap(msg.sender, path1[0], path2[path2.length - 1], amountIn, amounts[amounts.length - 1]);
	}

    function Calc_UNI_dbETH_ETH_UNI(
		uint256 amountIn,
		address[] memory path1,
		address[] memory path2
	) public view returns(uint256) {		
		uint256[] memory amounts;
		
		if(path1.length > 1) {
			amounts = uniswapRouter.getAmountsOut(amountIn, path1);
			amountIn = amounts[amounts.length - 1];
		}

		(uint256 wethAmount, ) = automaticMarketMaker.calculateSaleReturn(amountIn);

		amounts = uniswapRouter.getAmountsOut(wethAmount, path2);
        return amounts[amounts.length - 1];
	}

	receive() external payable {
		// receive ether
	}
}

// Dar panah Khoda