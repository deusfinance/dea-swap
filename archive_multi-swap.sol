// Be name Khoda

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

	constructor(address _uniswapRouter, address _AMM, address _IPOAMM) public {
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
		IERC20(DAI).approve(address(uniswapRouter), MAX_INT);
		IERC20(Coinbase).approve(address(uniswapRouter), MAX_INT);
		IERC20(WBTC).approve(address(uniswapRouter), MAX_INT);
	}

	function approveToken(address token, address _where) public onlyOwner {
		IERC20(token).approve(_where, MAX_INT);
	}


	function swapEthForTokens(
		address[] memory path,
	) external payable {
		require(msg.value > 0, "no ether");

		uint estimatedDeus = AMM.calculatePurchaseReturn(msg.value);
		AMM.buy{value: msg.value}(estimatedDeus);
		
		uint amountOfTokenOut = estimatedDeus;
		if(path.length > 1) {
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, 1, path, msg.sender, deadline);
			amountOfTokenOut = amounts[amounts.length - 1];
		} else {
			IERC20(DEUS).transfer(msg.sender, estimatedDeus);
		}

		emit swap(address(0), path[path.length - 1], msg.value, amountOfTokenOut);
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

		emit swap(path[0], address(0), amountIn, ethOut);
	}

	function swapTokensForEthOnUniswap(
		uint amountIn,
		address[] memory path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).transferFrom(msg.sender, address(this), amountIn);
		    
		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, 1, path, msg.sender, block.timestamp);
		uint amountOfTokenOut = amounts[amounts.length - 1];

		emit swap(path[0], address(0), amountIn, amountOfTokenOut);
	}

	function swapTokensForTokens(
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
			amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, 1, path2, msg.sender, block.timestamp);
			amountOfTokenOut = amounts[amounts.length - 1];
		} else {
			IERC20(DEUS).transfer(msg.sender, estimatedDeus);
		}

		emit swap(path1[0], path2[path2.length - 1], amountIn, amountOfTokenOut);

	}

	function swapDeusForTokens(
		uint amountIn,
		address[] path,
		uint minAmountOut
	) external {
		IERC20(address(DEUS)).transferFrom(msg.sender, address(this), amountIn);

		uint ethOut = AMM.calculateSaleReturn(amountIn);
		AMM.sell(amountIn, ethOut);
		AMM.withdrawPayments(address(this));

		uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: ethOut}(1, path, msg.sender, block.timestamp);

		emit swap(path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
	}

	function swapTokensForTokensOnUniswap(
		uint amountIn,
		address[] path,
		uint minAmountOut
	) external {
		IERC20(address(path[0])).transferFrom(msg.sender, address(this), amountIn);
		    
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, minAmountOut, path, msg.sender, block.timestamp);

		emit swap(path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
	}

	receive() external payable {
		// receive ether
	}

}

// Dar panah Khoda