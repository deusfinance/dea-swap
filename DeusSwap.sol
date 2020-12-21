// Be name Khoda

pragma solidity >=0.7.0 <0.8.0;

// import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/payment/PullPayment.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/SafeERC20.sol";
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

interface StaticPriceSale { // this is AutomaticMarketMaker! for coinbase
	function buyFor(address _user, uint256 coinbaseTokenAmount, uint256 deusAmount) external;
	function sellFor(address _user, uint256 coinbaseTokenAmount, uint256 deusAmount) external;
	function calculatePurchaseReturn(uint256 deusAmount) external returns (uint256, uint256);
	function calculateSaleReturn(uint256 coinbaseTokenAmount) external returns (uint256, uint256);
}


contract DeusSwap is PullPayment, Ownable {
	using SafeMath for uint;
	using SafeERC20 for IERC20;
	
	uint256 MAX_INT = uint256(-1);

	// address public uniswapRouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
	// address public AutomaticMarketMakerAddress = 0x6D3459E48C5D106e97FeC08284D56d43b00C2AB4;
	// address public StaticPriceSale = 0xFC2Da1De6c48b75D8a275835F7c14abe4125F8C4;
	
	// for initialize (mainnet)
// 	address public DEUS = 0x3b62F3820e0B035cc4aD602dECe6d796BC325325;
//  address public DEA = 0x80aB141F324C3d6F2b18b030f1C4E95d4d658778;
// 	address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
// 	address public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
// 	address public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
// 	address public Coinbase = 0x4185cf99745B2a20727B37EE798193DD4a56cDfa;
// 	address public WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

	// for initialize (rinkeby)
	address public DEUS = 0xf025DB474fcF9bA30844e91A54bC4747d4FC7842;
    address public DEA = 0x02b7a1AF1e9c7364Dd92CdC3b09340Aea6403934;
	address public USDC = 0x259F784f5b96B3f761b0f9B1d74F820C393ebd36;
	address public USDT = 0xA0953584886d983333D8Ca9844D0372F0c6F850D;
	address public DAI = 0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735;
	address public Coinbase = 0xFD104902617231e053049044E3e51C1D37fE12D3;
	address public WBTC = 0x577D296678535e4903D59A4C929B718e1D575e0A;


	AutomaticMarketMaker public AMM;
	IUniswapV2Router02 public uniswapRouter;
	StaticPriceSale public SPS;
	
	event swap(address fromToken, address toToken, uint amountIn, uint amountOut);

	constructor(address _uniswapRouter, address _AMM, address _SPS) public {
		uniswapRouter = IUniswapV2Router02(_uniswapRouter);
		AMM = AutomaticMarketMaker(_AMM);
		SPS = StaticPriceSale(_SPS);
	}

	function changeSPS(address _sps) public onlyOwner {
		SPS = StaticPriceSale(_sps);
	}

	function changeAMM(address _amm) public onlyOwner {
		AMM = AutomaticMarketMaker(_amm);
	}


	function initialize() public {
		IERC20(DEUS).approve(address(AMM), MAX_INT);
		IERC20(DEUS).approve(address(SPS), MAX_INT);
		IERC20(DEUS).approve(address(uniswapRouter), MAX_INT);
		IERC20(DEA).approve(address(uniswapRouter), MAX_INT);
		IERC20(USDC).approve(address(uniswapRouter), MAX_INT);
		IERC20(USDT).safeApprove(address(uniswapRouter), MAX_INT);
		IERC20(DAI).approve(address(uniswapRouter), MAX_INT);
		IERC20(Coinbase).approve(address(uniswapRouter), MAX_INT);
		IERC20(Coinbase).approve(address(SPS), MAX_INT);
		IERC20(WBTC).approve(address(uniswapRouter), MAX_INT);
	}

	function approveToken(address token, address _where) public onlyOwner {
		IERC20(token).approve(_where, MAX_INT);
	}

	function safeApproveToken(address token, address _where) public onlyOwner {
		IERC20(token).safeApprove(_where, MAX_INT);
	}


	function swapEthForTokens(
		address[] memory path,
		uint swapType
	) external payable {
		require(swapType >= 0 && swapType <= 2, "Invalid swapType");
		require(msg.value > 0, "no ether");

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
		} else if (swapType == 1) {
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: msg.value}(1, path, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(address(0), path[path.length - 1], msg.value, amountOfTokenOut);
		} else {
			uint estimatedDeus = AMM.calculatePurchaseReturn(msg.value);
        	AMM.buy{value: msg.value}(estimatedDeus);
            
			(uint256 estimatedCoinbase, ) = SPS.calculatePurchaseReturn(estimatedDeus);

			SPS.buyFor(msg.sender, estimatedCoinbase, estimatedDeus);
			IERC20(Coinbase).transfer(msg.sender, estimatedCoinbase);
			emit swap(address(0), Coinbase, msg.value, estimatedCoinbase);
		}
	}

	function swapTokensForEth(
		uint amountIn,
		uint swapType,
		address[] memory path
	) external {
		require(swapType >= 0 && swapType <= 2, "Invalid swapType");
		
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
		} else if (swapType == 1) {
			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, 1, path, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(path[path.length - 1], address(0), amountIn, amountOfTokenOut);
		} else {
			IERC20(Coinbase).transferFrom(msg.sender, address(this), amountIn);

			(uint256 amountOfDeusOut, ) = SPS.calculateSaleReturn(amountIn);

			SPS.sellFor(msg.sender, amountIn, amountOfDeusOut);

		    uint ethOut = AMM.calculateSaleReturn(amountOfDeusOut);

			AMM.sell(amountOfDeusOut, ethOut);
			AMM.withdrawPayments(address(this));
			(msg.sender).transfer(ethOut);

			emit swap(Coinbase, address(0), amountIn, ethOut);
		}
	}

	function swapTokensForTokens(
		uint amountIn,
		uint swapType,
		address[] memory path1,
		address[] memory path2
	) external {
		require(swapType >= 0 && swapType <= 8, "Invalid swapType");
		
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
		} else if (swapType == 2) {
			uint deadline = block.timestamp + 5;
			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(path1[0], path1[path1.length - 1], amountIn, amountOfTokenOut);
		} else if (swapType == 3) {
			IERC20(Coinbase).transferFrom(msg.sender, address(this), amountIn);
			
			(uint256 estimatedDeus, ) = SPS.calculateSaleReturn(amountIn);
			SPS.sellFor(msg.sender, amountIn, estimatedDeus);

			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(estimatedDeus, 1, path1, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(Coinbase, path1[path1.length - 1], amountIn, amountOfTokenOut);

		} else if (swapType == 4) {
			IERC20(Coinbase).transferFrom(msg.sender, address(this), amountIn);
			
			(uint256 estimatedDeus, ) = SPS.calculateSaleReturn(amountIn);
			SPS.sellFor(msg.sender, amountIn, estimatedDeus);

			uint ethOut = AMM.calculateSaleReturn(estimatedDeus);
			AMM.sell(estimatedDeus, ethOut);
			AMM.withdrawPayments(address(this));

			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: ethOut}(1, path1, msg.sender, deadline);
			uint amountOfTokenOut = amounts[amounts.length - 1];

			emit swap(Coinbase, path1[path1.length - 1], amountIn, amountOfTokenOut);

		} else if (swapType == 5) {
			IERC20(path1[0]).transferFrom(msg.sender, address(this), amountIn);

			uint deadline = block.timestamp + 5;
			uint[] memory amounts = uniswapRouter.swapExactTokensForETH(amountIn, 1, path1, address(this), deadline);
			uint amountOfEthOut = amounts[amounts.length - 1];

			uint estimatedDeus = AMM.calculatePurchaseReturn(amountOfEthOut);
        	AMM.buy{value: amountOfEthOut}(estimatedDeus);

			(uint256 estimatedCoinbase, ) = SPS.calculatePurchaseReturn(estimatedDeus);
			SPS.buyFor(msg.sender, estimatedCoinbase, estimatedDeus);

			IERC20(Coinbase).transfer(msg.sender, estimatedCoinbase);
			emit swap(path1[0], Coinbase, amountIn, estimatedCoinbase);

		} else if (swapType == 6) {
			IERC20(path1[0]).transferFrom(msg.sender, address(this), amountIn);

			uint deadline = block.timestamp + 5;

			uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, 1, path1, msg.sender, deadline);
			uint amountOfDeusOut = amounts[amounts.length - 1];

			(uint256 estimatedCoinbase, ) = SPS.calculatePurchaseReturn(amountOfDeusOut);
			SPS.buyFor(msg.sender, estimatedCoinbase, amountOfDeusOut);
			IERC20(Coinbase).transfer(msg.sender, estimatedCoinbase);

			emit swap(path1[0], Coinbase, amountIn, estimatedCoinbase);

		} else if (swapType == 7) {
			IERC20(DEUS).transferFrom(msg.sender, address(this), amountIn);

			(uint256 estimatedCoinbase, ) = SPS.calculatePurchaseReturn(amountIn);
			SPS.buyFor(msg.sender, estimatedCoinbase, amountIn);
			IERC20(Coinbase).transfer(msg.sender, estimatedCoinbase);

			emit swap(DEUS, Coinbase, amountIn, estimatedCoinbase);

		} else {
			IERC20(Coinbase).transferFrom(msg.sender, address(this), amountIn);

			(uint256 estimatedDeus, ) = SPS.calculateSaleReturn(amountIn);
			SPS.sellFor(msg.sender, amountIn, estimatedDeus);
			IERC20(DEUS).transfer(msg.sender, estimatedDeus);

			emit swap(Coinbase, DEUS, amountIn, estimatedDeus);

		}
	}

	receive() external payable {
		// receive ether
	}

}

// Dar panah Khoda