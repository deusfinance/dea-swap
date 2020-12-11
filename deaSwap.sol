pragma solidity ^0.6.12;

import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/payment/PullPayment.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/SafeERC20.sol";

interface AutomaticMarketMaker {
	function buy(uint256 _tokenAmount) external payable;
	function sell(uint256 tokenAmount, uint256 _etherAmount) external;
	function calculatePurchaseReturn(uint256 etherAmount) external returns (uint256);
	function calculateSaleReturn(uint256 tokenAmount) external returns (uint256);
	function withdrawPayments(address payable payee) external;
}


contract DeaSwap is PullPayment {
	using SafeMath for uint;
	using SafeERC20 for IERC20;
	
	uint256 MAX_INT = uint256(-1);

	address internal constant uniswapRouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
	address internal constant AutomaticMarketMakerAddress = 0x6D3459E48C5D106e97FeC08284D56d43b00C2AB4;
	
	//delete after test
	address DEUS = 0xf025DB474fcF9bA30844e91A54bC4747d4FC7842;
    address DEA = 0x02b7a1AF1e9c7364Dd92CdC3b09340Aea6403934;
	address USDC = 0x259F784f5b96B3f761b0f9B1d74F820C393ebd36;
	address USDT = 0xA0953584886d983333D8Ca9844D0372F0c6F850D;

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
		IERC20(USDT).safeApprove(address(uniswapRouter), MAX_INT);
	}

	function approveToken(address token) public {
		IERC20(token).approve(address(uniswapRouter), MAX_INT);
	}


	function swapEthForTokens(
		address[] memory path,
		uint swapType
	) external payable {
		require(swapType >= 0 && swapType <= 1, "Invalid swapType");
		if(swapType == 0) {
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
		} else {
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: msg.value}(1, path, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(address(0), path[path.length - 1], msg.value, amountOfTokenOut);
		}
	}

	function swapTokensForEth(
		uint amountIn,
		uint swapType,
		address[] memory path
	) external {
		require(swapType >= 0 && swapType <= 1, "Invalid swapType");
		
		IERC20(address(path[0])).transferFrom(msg.sender, address(this), amountIn);
		
		if(swapType == 0) {
		    uint amountOfDeusOut = amountIn;
		    if(path.length > 1) {
    		    uint deadline = block.timestamp + 5;
                
    			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path, address(this), deadline);
    			amountOfDeusOut = amounts[amounts.length - 1];
		    }
		    
		    uint ethOut = AMM.calculateSaleReturn(amountOfDeusOut);
			AMM.sell(amountOfDeusOut, ethOut);
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
		uint swapType,
		address[] memory path1,
		address[] memory path2
	) external {
		require(swapType >= 0 && swapType <= 2, "Invalid swapType");
		
		IERC20(address(path1[0])).transferFrom(msg.sender, address(this), amountIn);
		
		if(swapType == 0) {
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, 1, path1, address(this), deadline);
			uint amountOfEthOut = amounts[amounts.length - 1];

			uint estimatedDeus = AMM.calculatePurchaseReturn(amountOfEthOut);
        	AMM.buy{value: amountOfEthOut}(estimatedDeus);
			
			deadline = block.timestamp + 5;
			
			uint amountOfTokenOut = estimatedDeus;
			if(path2.length > 1) {
    			amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, 1, path2, msg.sender, deadline);
    			amountOfTokenOut = amounts[amounts.length - 1];
			} else {
			    IERC20(DEUS).transfer(msg.sender, estimatedDeus);
			}

			emit swap(path1[0], path2[path2.length - 1], amountIn, amountOfTokenOut);
		} else if (swapType == 1) {
			uint deadline = block.timestamp + 5;
            
            uint amountOfDeusOut = amountIn;
            uint[] memory amounts;
            
            if(path1.length > 1) {
    			amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, address(this), deadline);
    			amountOfDeusOut = amounts[amounts.length - 1];
            }

			uint ethOut = AMM.calculateSaleReturn(amountOfDeusOut);
			AMM.sell(amountIn, ethOut);
			AMM.withdrawPayments(address(this));
			
			deadline = block.timestamp + 5;

			amounts = uniswapRouter.swapExactETHForTokens{value: ethOut}(1, path2, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(path1[0], path2[path2.length - 1], amountIn, amountOfTokenOut);
		} else {
			uint deadline = block.timestamp + 5;
			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(path1[0], path1[path1.length - 1], amountIn, amountOfTokenOut);
		}
	}

	receive() external payable {
		// receive ether
	}

}