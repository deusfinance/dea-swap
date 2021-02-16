// Be name Khoda
// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

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

interface AutomaticMarketMaker {
	function buy(uint256 _tokenAmount) external payable;
	function sell(uint256 tokenAmount, uint256 _etherAmount) external;
	function calculatePurchaseReturn(uint256 etherAmount) external returns (uint256);
	function calculateSaleReturn(uint256 tokenAmount) external returns (uint256);
	function withdrawPayments(address payable payee) external;
}


contract MultiSwap is Ownable {
	using SafeMath for uint;
	
	uint256 MAX_INT = type(uint256).max;
	
	address public DEUS = 0x3b62F3820e0B035cc4aD602dECe6d796BC325325;
 	address public DEA = 0x80aB141F324C3d6F2b18b030f1C4E95d4d658778;
	address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
	address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
	address public WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

	AutomaticMarketMaker public AMM;
	IUniswapV2Router02 public uniswapRouter;
	
	event swap(address fromToken, address toToken, uint amountIn, uint amountOut);

	constructor(address _uniswapRouter, address _AMM) {
		uniswapRouter = IUniswapV2Router02(_uniswapRouter);
		AMM = AutomaticMarketMaker(_AMM);
		IERC20(DEUS).approve(address(uniswapRouter), MAX_INT);
		IERC20(DEA).approve(address(uniswapRouter), MAX_INT);
		IERC20(USDC).approve(address(uniswapRouter), MAX_INT);
		IERC20(DAI).approve(address(uniswapRouter), MAX_INT);
		IERC20(WBTC).approve(address(uniswapRouter), MAX_INT);
	}

	function setAMM(address _amm) public onlyOwner {
		AMM = AutomaticMarketMaker(_amm);
	}

	function approveToken(address token, address _where) public onlyOwner {
		IERC20(token).approve(_where, MAX_INT);
	}


	function collectTokens(address token, uint amount, address to) external onlyOwner {
	    IERC20(token).transfer(to, amount);
	}

	receive() external payable {
		// receive ether
	}


	///////////////////////////////////////////////////////////////


	function EthDeusUni(
		address[] memory path,
		uint minAmountOut
	) external payable {
		uint estimatedDeus = AMM.calculatePurchaseReturn(msg.value);
		AMM.buy{value: msg.value}(estimatedDeus);
	
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(address(0), path[path.length - 1], msg.value, amounts[amounts.length - 1]);
	}
	
	function uniEthDeusUni(
		uint amountIn,
		address[] memory path1,
		address[] memory path2,
		uint minAmountOut
	) external {
		IERC20(address(path1[0])).transferFrom(msg.sender, address(this), amountIn);

		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, 1, path1, address(this), block.timestamp);
		uint amountOfEthOut = amounts[amounts.length - 1];

		uint outputAmount = AMM.calculatePurchaseReturn(amountOfEthOut);
		if(path2.length > 1) {
			AMM.buy{value: amountOfEthOut}(outputAmount);
			
			amounts = uniswapRouter.swapExactTokensForTokens(outputAmount, minAmountOut, path2, msg.sender, block.timestamp);
			emit swap(path1[0], path2[path2.length - 1], amountIn, amounts[amounts.length - 1]);
		} else {
			AMM.buy{value: amountOfEthOut}(minAmountOut);
			IERC20(DEUS).transfer(msg.sender, outputAmount);
			emit swap(path1[0], DEUS, amountIn, outputAmount);
		}	
	}


	function uniDeusEth(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).transferFrom(msg.sender, address(this), amountIn);
		
		if(path.length > 1) {
			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path, address(this), block.timestamp);
			amountIn = amounts[amounts.length - 1];
		}
		
		uint ethOut = AMM.calculateSaleReturn(amountIn);
		AMM.sell(amountIn, minAmountOut);
		AMM.withdrawPayments(payable(address(this)));
		payable(msg.sender).transfer(ethOut);

		emit swap(path[0], address(0), amountIn, ethOut);
	}


	function uniDeusEthUni(
		uint amountIn,
		address[] memory path1,
		address[] memory path2,
		uint minAmountOut
	) external {
		IERC20(address(path1[0])).transferFrom(msg.sender, address(this), amountIn);
		
		uint[] memory amounts;
		
		if(path1.length > 1) {
			amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, address(this), block.timestamp);
			amountIn = amounts[amounts.length - 1];
		}

		uint ethOut = AMM.calculateSaleReturn(amountIn);
		AMM.sell(amountIn, ethOut);
		AMM.withdrawPayments(payable(address(this)));

		amounts = uniswapRouter.swapExactETHForTokens{value: ethOut}(minAmountOut, path2, msg.sender, block.timestamp);

		emit swap(path1[0], path2[path2.length - 1], amountIn, amounts[amounts.length - 1]);
	}

	///////////////////////////////////////////////////////////////

	function tokensToEthOnUni(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).transferFrom(msg.sender, address(this), amountIn);
		    
		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(path[0], address(0), amountIn, amounts[amounts.length - 1]);
	}

	function tokensToTokensOnUni(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).transferFrom(msg.sender, address(this), amountIn);
		    
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
	}
}

// Dar panah Khoda