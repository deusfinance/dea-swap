// Be name Khoda
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.1/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.1/contracts/access/Ownable.sol";
import "https://github.com/itinance/openzeppelin-solidity/blob/escrow-exploration/contracts/token/ERC20/SafeERC20.sol";	


interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
        
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
}

interface IAutomaticMarketMaker {
	function calculatePurchaseReturn(uint256 wethAmount) external view returns (uint256, uint256);
	function buyFor(address user, uint256 _dbEthAmount, uint256 _wethAmount) external;
	function calculateSaleReturn(uint256 dbEthAmount) external view returns (uint256, uint256);
	function sellFor(address user, uint256 dbEthAmount, uint256 _wethAmount) external;
}

interface IWethProxy {
	function sell(uint256 dbEthAmount, uint256 _wethAmount) external;
	function buy(uint256 _dbEthAmount, uint256 _wethAmount) external payable;
}

contract MultiSwap is Ownable {
	using SafeERC20 for IERC20;
	uint256 MAX_INT = type(uint256).max;

	IAutomaticMarketMaker public automaticMarketMaker;
	IWethProxy public wethProxy;
	IUniswapV2Router02 public uniswapRouter;
	
	event swap(address user, address fromToken, address toToken, uint amountIn, uint amountOut);

	constructor(address _uniswapRouter, address _automaticMarketMaker, address _wethProxy) {
		uniswapRouter = IUniswapV2Router02(_uniswapRouter);
		automaticMarketMaker = IAutomaticMarketMaker(_automaticMarketMaker);
		wethProxy = IWethProxy(_wethProxy);

		// IERC20(DEUS).safeApprove(address(uniswapRouter), MAX_INT);
		// IERC20(DEA).safeApprove(address(uniswapRouter), MAX_INT);
		// IERC20(USDC).safeApprove(address(uniswapRouter), MAX_INT);
		// IERC20(DAI).safeApprove(address(uniswapRouter), MAX_INT);
		// IERC20(WBTC).safeApprove(address(uniswapRouter), MAX_INT);
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


	///////////////////////////////////////////////////////////////


	function EthDeusUni(
		address[] memory path,
		uint minAmountOut
	) external payable {
		uint estimatedDeus = automaticMarketMaker.calculatePurchaseReturn(msg.value);
		automaticMarketMaker.buy{value: msg.value}(estimatedDeus);
	
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(msg.sender, address(0), path[path.length - 1], msg.value, amounts[amounts.length - 1]);
	}
	
	function uniEthDeusUni(
		uint amountIn,
		address[] memory path1,
		address[] memory path2,
		uint minAmountOut
	) external {
		IERC20(address(path1[0])).safeTransferFrom(msg.sender, address(this), amountIn);

		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, 1, path1, address(this), block.timestamp);
		uint amountOfEthOut = amounts[amounts.length - 1];

		uint outputAmount = automaticMarketMaker.calculatePurchaseReturn(amountOfEthOut);
		if(path2.length > 1) {
			automaticMarketMaker.buy{value: amountOfEthOut}(outputAmount);
			
			amounts = uniswapRouter.swapExactTokensForTokens(outputAmount, minAmountOut, path2, msg.sender, block.timestamp);
			emit swap(msg.sender, path1[0], path2[path2.length - 1], amountIn, amounts[amounts.length - 1]);
		} else {
			automaticMarketMaker.buy{value: amountOfEthOut}(minAmountOut);
			IERC20(DEUS).safeTransfer(msg.sender, outputAmount);
			emit swap(msg.sender, path1[0], DEUS, amountIn, outputAmount);
		}	
	}


	function uniDeusEth(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		
		if(path.length > 0) {
			IERC20(address(path[0])).safeTransferFrom(msg.sender, address(this), amountIn);
			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path, address(this), block.timestamp);
			amountIn = amounts[amounts.length - 1];
		} else {
			IERC20(DEUS).safeTransferFrom(msg.sender, address(this), amountIn);
		}
		
		uint ethOut = automaticMarketMaker.calculateSaleReturn(amountIn);
		automaticMarketMaker.sell(amountIn, minAmountOut);
		automaticMarketMaker.withdrawPayments(payable(address(this)));
		payable(msg.sender).safeTransfer(ethOut);

		emit swap(msg.sender, path[0], address(0), amountIn, ethOut);
	}


	function uniDeusEthUni(
		uint amountIn,
		address[] memory path1,
		address[] memory path2,
		uint minAmountOut
	) external {
		IERC20(address(path1[0])).safeTransferFrom(msg.sender, address(this), amountIn);
		
		uint[] memory amounts;
		
		if(path1.length > 1) {
			amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, address(this), block.timestamp);
			amountIn = amounts[amounts.length - 1];
		}

		uint ethOut = automaticMarketMaker.calculateSaleReturn(amountIn);
		automaticMarketMaker.sell(amountIn, ethOut);
		automaticMarketMaker.withdrawPayments(payable(address(this)));

		amounts = uniswapRouter.swapExactETHForTokens{value: ethOut}(minAmountOut, path2, msg.sender, block.timestamp);

		emit swap(msg.sender, path1[0], path2[path2.length - 1], amountIn, amounts[amounts.length - 1]);
	}

	///////////////////////////////////////////////////////////////

	function tokensToEthOnUni(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).safeTransferFrom(msg.sender, address(this), amountIn);
		    
		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(msg.sender, path[0], address(0), amountIn, amounts[amounts.length - 1]);
	}

	function tokensToTokensOnUni(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).safeTransferFrom(msg.sender, address(this), amountIn);
		    
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(msg.sender, path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
	}

	receive() external payable {
		// receive ether
	}
}

// Dar panah Khoda