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
	
    address DEUS = 0xf025DB474fcF9bA30844e91A54bC4747d4FC7842;
    address DEA = 0x02b7a1AF1e9c7364Dd92CdC3b09340Aea6403934;
	address USDC = 0xAedAb46B9dca7EE3Ab303B088eCCB83443db24A1;

	address internal constant uniswapRouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
	address internal constant AutomaticMarketMakerAddress = 0x6D3459E48C5D106e97FeC08284D56d43b00C2AB4;

	AutomaticMarketMaker public AMM;
	IUniswapV2Router02 public uniswapRouter;
	
	event swap(address from, address to, uint amountIn, uint amountOut);

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
	) {
		require(type >= 0 && type <= 1, "Invalid Type");
		
	}

	function swapTokensForEth(
		uint amountIn,
		int type,
		address[] path
	) {
		require(type >= 0 && type <= 1, "Invalid Type");

	}

	function swapTokensForTokens(
		uint amountIn,
		uint type,
		address[] path1,
		address[] paht2
	) {
		require(type >= 0 && type <= 2, "Invalid Type");

	}


	function swapEthToDea () external payable {
        
		uint deusIn = AMM.calculatePurchaseReturn(msg.value);

        AMM.buy{value: msg.value}(deusIn);
        
    	address[] memory path = new address[](2);
        path[0] = DEUS;
		path[1] = DEA;
        
		uint deadline = block.timestamp + 5;

		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(deusIn, 0, path, msg.sender, deadline);
		uint deaOut = amounts[amounts.length - 1];

		emit EthToDea(msg.value, deaOut);
	}

	function swapDeaToEth (
		uint deaIn
	) external {
		IERC20(DEA).transferFrom(msg.sender, address(this), deaIn);

		address[] memory path = new address[](2);
        path[0] = DEA;
		path[1] = DEUS;
		
		uint deadline = block.timestamp + 5;
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(deaIn, 0, path, address(this), deadline);

		uint deusIn = amounts[amounts.length - 1];
        
		uint ethOut = AMM.calculateSaleReturn(deusIn);

        AMM.sell(deusIn, ethOut);
		AMM.withdrawPayments(address(this));
		(msg.sender).transfer(ethOut);

		emit DeaToEth(deaIn, ethOut);
	}

	function swapDeaToUsdc (
		uint deaIn
	) external {
		IERC20(DEA).transferFrom(msg.sender, address(this), deaIn);

		address[] memory path = new address[](2);
        path[0] = DEA;
		path[1] = DEUS;
		
		uint deadline = block.timestamp + 5;
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(deaIn, 0, path, address(this), deadline);

		uint deusIn = amounts[amounts.length - 1];
        
		uint ethOut = AMM.calculateSaleReturn(deusIn);

        AMM.sell(deusIn, ethOut);
		AMM.withdrawPayments(address(this));
		
        path[0] = uniswapRouter.WETH();
		path[1] = USDC;
		deadline = block.timestamp + 5;

		amounts = uniswapRouter.swapExactETHForTokens{value: ethOut}(0, path, msg.sender, deadline);
		uint usdcOut = amounts[amounts.length - 1];

		emit DeaToUsdc(deaIn, usdcOut);
	}

	function swapDeaToDeus (
		uint deaIn
	) external {
		IERC20(DEA).transferFrom(msg.sender, address(this), deaIn);

		address[] memory path = new address[](2);
        path[0] = DEA;
		path[1] = DEUS;
		
		uint deadline = block.timestamp + 5;
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(deaIn, 0, path, msg.sender, deadline);
		uint deusOut = amounts[amounts.length - 1];

		emit DeaToDeus(deaIn, deusOut);
	}


	function swapUsdcToDea (
		uint usdcIn
	) external {
		IERC20(USDC).transferFrom(msg.sender, address(this), usdcIn);
	    
		address[] memory path = new address[](2);
        path[0] = USDC;
		path[1] = uniswapRouter.WETH();

		uint deadline = block.timestamp + 5;

		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(usdcIn, 0, path, address(this), deadline);

		uint ethIn = amounts[amounts.length - 1];

		uint deusOut = AMM.calculatePurchaseReturn(ethIn);

        AMM.buy{value: ethIn}(deusOut);

        path[0] = DEUS;
		path[1] = DEA;
        
		deadline = block.timestamp + 5;
		amounts = uniswapRouter.swapExactTokensForTokens(deusOut, 0, path, msg.sender, deadline);
		uint deaOut = amounts[amounts.length - 1];
		
		emit UsdcToDea(usdcIn, deaOut);
	}
	
	function swapDeusToUsdc (
		uint deusIn
	) external {
	    IERC20(DEUS).transferFrom(msg.sender, address(this), deusIn);
	    
		uint ethOut = AMM.calculateSaleReturn(deusIn);

        AMM.sell(deusIn, ethOut);
		AMM.withdrawPayments(address(this));

		address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
		path[1] = USDC;
		uint deadline = block.timestamp + 5;

		uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: ethOut}(0, path, msg.sender, deadline);
		uint usdcOut = amounts[amounts.length - 1];

		emit DeusToUsdc(deusIn, usdcOut);
	}

	function swapDeusToDea (
		uint deusIn
	) external {
		IERC20(DEUS).transferFrom(msg.sender, address(this), deusIn);

		address[] memory path = new address[](2);
        path[0] = DEUS;
		path[1] = DEA;
		
		uint deadline = block.timestamp + 5;
		uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(deusIn, 0, path, msg.sender, deadline);
		uint deaOut = amounts[amounts.length - 1];

		emit DeusToDea(deusIn, deaOut);
	}


	function swapUsdcToDeus (
		uint usdcIn
	) external {
	    IERC20(USDC).transferFrom(msg.sender, address(this), usdcIn);
	    
		address[] memory path = new address[](2);
        path[0] = USDC;
		path[1] = uniswapRouter.WETH();

		uint deadline = block.timestamp + 5;

		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(usdcIn, 0, path, address(this), deadline);

		uint ethIn = amounts[amounts.length - 1];

		uint deusOut = AMM.calculatePurchaseReturn(ethIn);

        AMM.buy{value: ethIn}(deusOut);

		IERC20(DEUS).transfer(msg.sender, deusOut);

		emit UsdcToDeus(usdcIn, deusOut);
	}

	function swapEthToUsdc () external payable {
		address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
		path[1] = USDC;
		uint deadline = block.timestamp + 5;

		uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: msg.value}(0, path, msg.sender, deadline);
		uint usdcOut = amounts[amounts.length - 1];

		emit EthToUsdc(msg.value, usdcOut);
	}

	function swapUsdcToEth (
		uint usdcIn
	) external {
		IERC20(DEA).transferFrom(msg.sender, address(this), usdcIn);

		address[] memory path = new address[](2);
        path[0] = DEA;
		path[1] = uniswapRouter.WETH();
		uint deadline = block.timestamp + 5;

		uint[] memory amounts = uniswapRouter.swapExactTokensForETH(usdcIn, 0, path, msg.sender, deadline);
		uint ethOut = amounts[amounts.length - 1];

		emit UsdcToEth(usdcIn, ethOut);
	}


	receive() external payable {
		// receive ether
	}

}