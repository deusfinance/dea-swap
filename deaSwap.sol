pragma solidity ^0.6.12;

import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/payment/PullPayment.sol";


interface AutomaticMarketMaker {
	function buy(uint256 _tokenAmount) external payable;
	function sell(uint256 tokenAmount, uint256 _etherAmount) external;
	function calculatePurchaseReturn(uint256 etherAmount) external returns (uint256);
	function calculateSaleReturn(uint256 tokenAmount) external returns (uint256);
	function withdrawPayments(address payable payee) external;
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
	function transfer(address recipient, uint256 amount) external returns (bool);
}


contract DeaSwap is PullPayment {
	using SafeMath for uint;
	
	uint256 MAX_INT = uint256(-1);

	address internal constant uniswapRouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
	address internal constant AutomaticMarketMakerAddress = 0x6D3459E48C5D106e97FeC08284D56d43b00C2AB4;

	AutomaticMarketMaker public AMM;
	IUniswapV2Router02 public uniswapRouter;
	
	event swap(address fromToken, address toToken, uint amountIn, uint amountOut);

	constructor() public {
		uniswapRouter = IUniswapV2Router02(uniswapRouterAddress);
		AMM = AutomaticMarketMaker(AutomaticMarketMakerAddress);
	}

	function approve() public {
		IERC20(DEUS).approve(address(uniswapRouter), MAX_INT);
		IERC20(DEA).approve(address(uniswapRouter), MAX_INT);
		IERC20(USDC).approve(address(uniswapRouter), MAX_INT);
		IERC20(DEUS).approve(address(AMM), MAX_INT);
	}


	function swapEthForTokens(
		address[] path,
		uint type
	) external payable {
		require(type >= 0 && type <= 1, "Invalid Type");
		if(type == 0) {
			uint estimatedDeus = AMM.calculatePurchaseReturn(msg.value);
        	AMM.buy{value: msg.value}(estimatedDeus);
			
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, 1, path, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(address(0), path[path.length - 1], msg.value, amountOfTokenOut);
		} else {
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: msg.value}(1, path, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(address(0), path[path.length - 1], msg.value, amountOfTokenOut);
		}
	}

	function swapTokensForEth(
		uint amountIn,
		int type,
		address[] path
	) external {
		require(type >= 0 && type <= 1, "Invalid Type");
		if(type == 0) {
			uint ethOut = AMM.calculateSaleReturn(amountIn);

			AMM.sell(amountIn, ethOut);
			AMM.withdrawPayments(address(this));
			(msg.sender).transfer(ethOut);

			emit swap(path[path.length - 1], address(0), amountIn, ethOut);
		} else {
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, 1, path, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(path[path.length - 1], address(0), amountIn, amountOfTokenOut);
		}
	}

	function swapTokensForTokens(
		uint amountIn,
		uint type,
		address[] path1,
		address[] path2
	) external {
		require(type >= 0 && type <= 2, "Invalid Type");
		if(type == 0) {
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, 1, path1, address(this), deadline);
			uint amountOfEthOut = amounts[amounts.length - 1];

			uint estimatedDeus = AMM.calculatePurchaseReturn(amountOfEthOut);
        	AMM.buy{value: amountOfEthOut}(estimatedDeus);
			
			deadline = block.timestamp + 5;

			amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, 1, path2, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(path1[0], path2[path2.length - 1], amountIn, amountOfTokenOut);
		} else if (type == 1) {
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, address(this), deadline);
			uint amountOfDeusOut = amounts[amounts.length - 1];

			uint ethOut = AMM.calculateSaleReturn(amountOfDeusOut);
			AMM.sell(amountIn, ethOut);
			AMM.withdrawPayments(address(this));
			
			deadline = block.timestamp + 5;

			amounts = uniswapRouter.swapExactETHForTokens{value: ethOut}(1, path2, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(path1[0], path2[path2.length - 1], amountIn, amountOfTokenOut);
		} else {
			uint deadline = block.timestamp + 5;
			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, address(this), deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(path1[0], path1[path1.length - 1], amountIn, amountOfTokenOut);
		}
	}

	receive() external payable {
		// receive ether
	}

}