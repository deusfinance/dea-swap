// Be name Khoda
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

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

interface IPOAutomaticMarketMaker {
	function buyFor(address _user, uint256 coinbaseTokenAmount, uint256 deusAmount) external;
	function sellFor(address _user, uint256 coinbaseTokenAmount, uint256 deusAmount) external;
	function calculatePurchaseReturn(uint256 deusAmount) external returns (uint256, uint256);
	function calculateSaleReturn(uint256 coinbaseTokenAmount) external returns (uint256, uint256);
}


contract MultiSwap is Ownable {
	using SafeMath for uint;
	
	uint256 MAX_INT = uint256(-1);
	
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
	}

	function changeAMM(address _amm) public onlyOwner {
		AMM = AutomaticMarketMaker(_amm);
	}

	function initialize() public {
		IERC20(DEUS).approve(address(uniswapRouter), MAX_INT);
		IERC20(DEA).approve(address(uniswapRouter), MAX_INT);
		IERC20(USDC).approve(address(uniswapRouter), MAX_INT);
// 		IERC20(DAI).approve(address(uniswapRouter), MAX_INT);
// 		IERC20(WBTC).approve(address(uniswapRouter), MAX_INT);
	}

	function approveToken(address token, address _where) public onlyOwner {
		IERC20(token).approve(_where, MAX_INT);
	}

	function swapEthForTokens(
		address[] memory path,
		uint minAmountOut
	) external payable {
		require(msg.value > 0, "no ether");

		uint estimatedDeus = AMM.calculatePurchaseReturn(msg.value);
		AMM.buy{value: msg.value}(estimatedDeus);
		
		uint amountOfTokenOut = estimatedDeus;
	
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(address(0), path[path.length - 1], msg.value, amounts[amounts.length - 1]);
	}
	

	function swapTokensForEth(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).transferFrom(msg.sender, address(this), amountIn);
		
		uint amountOfDeusOut = amountIn;
		if(path.length > 1) {
			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path, address(this), block.timestamp);
			amountOfDeusOut = amounts[amounts.length - 1];
		}
		
		uint ethOut = AMM.calculateSaleReturn(amountOfDeusOut);
		AMM.sell(amountOfDeusOut, ethOut);
		AMM.withdrawPayments(address(this));
		(msg.sender).transfer(ethOut);

		require(ethOut >= minAmountOut, "Price changed");

		emit swap(path[0], address(0), amountIn, ethOut);
	}

	function swapTokensForEthOnUniswap(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).transferFrom(msg.sender, address(this), amountIn);
		    
		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(path[0], address(0), amountIn, amounts[amounts.length - 1]);
	}

	function swapTokensForTokensByBuyDeus(
		uint amountIn,
		address[] memory path1,
		address[] memory path2,
		uint minAmountOut
	) external {
		IERC20(address(path1[0])).transferFrom(msg.sender, address(this), amountIn);

		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, 1, path1, address(this), block.timestamp);
		uint amountOfEthOut = amounts[amounts.length - 1];

		uint estimatedDeus = AMM.calculatePurchaseReturn(amountOfEthOut);
		AMM.buy{value: amountOfEthOut}(estimatedDeus);
		
		uint amountOfTokenOut = estimatedDeus;
		if(path2.length > 1) {
			amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, minAmountOut, path2, msg.sender, block.timestamp);
			amountOfTokenOut = amounts[amounts.length - 1];
		} else {
			IERC20(DEUS).transfer(msg.sender, estimatedDeus);
			require(estimatedDeus >= minAmountOut, "Price changed");
		}

		emit swap(path1[0], path2[path2.length - 1], amountIn, amountOfTokenOut);
	}

	function swapTokensForTokensBySellDeus(
		uint amountIn,
		address[] memory path1,
		address[] memory path2,
		uint minAmountOut
	) external {
		IERC20(address(path1[0])).transferFrom(msg.sender, address(this), amountIn);
		
		uint amountOfDeusOut = amountIn;
		uint[] memory amounts;
		
		if(path1.length > 1) {
			amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, address(this), block.timestamp);
			amountOfDeusOut = amounts[amounts.length - 1];
		}

		uint ethOut = AMM.calculateSaleReturn(amountOfDeusOut);
		AMM.sell(amountOfDeusOut, ethOut);
		AMM.withdrawPayments(address(this));

		amounts = uniswapRouter.swapExactETHForTokens{value: ethOut}(minAmountOut, path2, msg.sender, block.timestamp);

		emit swap(path1[0], path2[path2.length - 1], amountIn, amounts[amounts.length - 1]);
	}

	function swapTokensForTokensOnUniswap(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).transferFrom(msg.sender, address(this), amountIn);
		    
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
	}
	
	function collectTokens(address _token, uint amount) external onlyOwner {
	    IERC20(_token).transfer(msg.sender, amount);
	}

	receive() external payable {
		// receive ether
	}

}

// Dar panah Khoda