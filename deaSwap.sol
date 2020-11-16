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
}


contract DeaSwap is PullPayment {
	using SafeMath for uint;
	
	uint256 MAX_INT = uint256(-1);
	
    address DEUS = 0xf025DB474fcF9bA30844e91A54bC4747d4FC7842;
    address DEA = 0x02b7a1AF1e9c7364Dd92CdC3b09340Aea6403934;

	address internal constant uniswapRouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
	address internal constant AutomaticMarketMakerAddress = 0x6D3459E48C5D106e97FeC08284D56d43b00C2AB4;

	AutomaticMarketMaker public AMM;
	IUniswapV2Router02 public uniswapRouter;
	
	event DeaToEth(uint deaIn, uint deusIn, uint ethOut);

	constructor() public {
		uniswapRouter = IUniswapV2Router02(uniswapRouterAddress);
		AMM = AutomaticMarketMaker(AutomaticMarketMakerAddress);
	}
	
	function testEthToDeusAMM () external payable {
	    uint deusIn = AMM.calculatePurchaseReturn(msg.value);
        AMM.buy{value: msg.value}(deusIn);
	}

	function testDeusToEthAMM (uint deusIn) external {
		IERC20(DEUS).transferFrom(msg.sender, address(this), deusIn);

		uint ethOut = AMM.calculateSaleReturn(deusIn);
        AMM.sell(deusIn, ethOut);
		AMM.withdrawPayments(address(this));
		(msg.sender).transfer(ethOut);
	}

	function approve() public {
		IERC20(DEUS).approve(address(uniswapRouter), MAX_INT);
		IERC20(DEA).approve(address(uniswapRouter), MAX_INT);
		IERC20(DEUS).approve(address(AMM), MAX_INT);
	}


	function swapEthToDea () external payable returns (uint[] memory) {
        
		uint deusIn = AMM.calculatePurchaseReturn(msg.value);

        AMM.buy{value: msg.value}(deusIn);
        
        IERC20(DEUS).approve(address(uniswapRouter), deusIn.mul(1000)); // TODO: delete after tests
        
    	address[] memory path = new address[](2);
        path[0] = DEUS;
		path[1] = DEA;
        
		uint deadline = block.timestamp + 5;
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(deusIn, 0, path, msg.sender, deadline);
		return amounts;
	}

	function swapDeaToEth (
		uint deaIn
	) external {
		IERC20(DEA).transferFrom(msg.sender, address(this), deaIn);
        IERC20(DEA).approve(address(uniswapRouter), deaIn.mul(1000)); // TODO: delete after tests

		address[] memory path = new address[](2);
        path[0] = DEA;
		path[1] = DEUS;
		
		uint deadline = block.timestamp + 5;
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(deaIn, 0, path, address(this), deadline);

		uint deusIn = amounts[1];
        
		uint ethOut = AMM.calculateSaleReturn(deusIn);

		emit DeaToEth(deaIn, deusIn, ethOut);
		
        AMM.sell(deusIn, ethOut);
		AMM.withdrawPayments(address(this));
		(msg.sender).transfer(ethOut);
	}
	
	receive() external payable {
		// receive ether
	}

}