//       ╟╗                                                                      ╔╬
//       ╞╬╬                                                                    ╬╠╬
//      ╔╣╬╬╬                                                                  ╠╠╠╠╦
//     ╬╬╬╬╬╩                                                                  ╘╠╠╠╠╬
//    ║╬╬╬╬╬                                                                    ╘╠╠╠╠╬
//    ╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬      ╒╬╬╬╬╬╬╬╜   ╠╠╬╬╬╬╬╬╬         ╠╬╬╬╬╬╬╬    ╬╬╬╬╬╬╬╬╠╠╠╠╠╠╠╠
//    ╙╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╕    ╬╬╬╬╬╬╬╜   ╣╠╠╬╬╬╬╬╬╬╬        ╠╬╬╬╬╬╬╬   ╬╬╬╬╬╬╬╬╬╠╠╠╠╠╠╠╩
//     ╙╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬  ╔╬╬╬╬╬╬╬    ╔╠╠╠╬╬╬╬╬╬╬╬        ╠╬╬╬╬╬╬╬ ╣╬╬╬╬╬╬╬╬╬╬╬╠╠╠╠╝╙
//               ╘╣╬╬╬╬╬╬╬╬╬╬╬╬╬╬    ╒╠╠╠╬╠╬╩╬╬╬╬╬╬       ╠╬╬╬╬╬╬╬╣╬╬╬╬╬╬╬╙
//                 ╣╬╬╬╬╬╬╬╬╬╬╠╣     ╣╬╠╠╠╬╩ ╚╬╬╬╬╬╬      ╠╬╬╬╬╬╬╬╬╬╬╬╬╬╬
//                  ╣╬╬╬╬╬╬╬╬╬╣     ╣╬╠╠╠╬╬   ╣╬╬╬╬╬╬     ╠╬╬╬╬╬╬╬╬╬╬╬╬╬╬
//                   ╟╬╬╬╬╬╬╬╩      ╬╬╠╠╠╠╬╬╬╬╬╬╬╬╬╬╬     ╠╬╬╬╬╬╬╬╠╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬     ╒╬╬╠╠╬╠╠╬╬╬╬╬╬╬╬╬╬╬╬    ╠╬╬╬╬╬╬╬ ╣╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬     ╬╬╬╠╠╠╠╝╝╝╝╝╝╝╠╬╬╬╬╬╬   ╠╬╬╬╬╬╬╬  ╚╬╬╬╬╬╬╬╬
//                    ╬╬╬╬╬╬╬    ╣╬╬╬╬╠╠╩       ╘╬╬╬╬╬╬╬  ╠╬╬╬╬╬╬╬   ╙╬╬╬╬╬╬╬╬
//

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interface/IGmxVault.sol";
import "../interface/IGlpManager.sol";
import "../interface/IGmxRewardRouter.sol";
import "../interface/IERC20.sol";
import "../lib/SafeERC20.sol";
import "../YakAdapter.sol";

contract GLPAdapter is YakAdapter {
    using SafeERC20 for IERC20;

    address internal constant GLP = 0x01234181085565ed162a948b6a5e88758CD7c7b8;
    address internal constant fsGLP = 0x9e295B5B976a184B14aD8cd72413aD846C299660;
    address internal constant sGLP = 0x0b82a1aD2138E9f62454ac41b702B64e0b73d57b;

    uint256 public constant BASIS_POINTS_DIVISOR = 1e4;
    uint256 public constant PRICE_PRECISION = 1e30;

    address public immutable usdg;
    address public immutable vault;
    address public immutable rewardRouter;
    address public immutable glpManager;
    address public immutable vaultUtils;

    constructor(
        string memory _name,
        uint256 _swapGasEstimate,
        address _gmxRewardRouter
    ) YakAdapter(_name, _swapGasEstimate) {
        address gmxGLPManager = IGmxRewardRouter(_gmxRewardRouter).glpManager();
        address gmxVault = IGlpManager(gmxGLPManager).vault();
        usdg = IGmxVault(gmxVault).usdg();
        vaultUtils = address(IGmxVault(gmxVault).vaultUtils());
        rewardRouter = _gmxRewardRouter;
        vault = gmxVault;
        glpManager = gmxGLPManager;
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view override returns (uint256 amountOut) {
        return (_tokenOut == sGLP) ? _quoteBuyGLP(_tokenIn, _amountIn) : _quoteSellGLP(_tokenOut, _amountIn);
    }

    function _quoteBuyGLP(address _tokenIn, uint256 _amountIn) internal view returns (uint256 amountOut) {
        uint256 aumInUsdg = IGlpManager(glpManager).getAumInUsdg(true);
        uint256 glpSupply = IERC20(GLP).totalSupply();
        uint256 price = IGmxVault(vault).getMinPrice(_tokenIn);
        uint256 usdgAmount = _calculateBuyUsdg(_amountIn, price, _tokenIn);
        amountOut = aumInUsdg == 0 ? usdgAmount : (usdgAmount * glpSupply) / aumInUsdg;
    }

    function _calculateBuyUsdg(
        uint256 _amountIn,
        uint256 _price,
        address _tokenIn
    ) internal view returns (uint256 amountOut) {
        amountOut = (_amountIn * _price) / PRICE_PRECISION;
        amountOut = IGmxVault(vault).adjustForDecimals(amountOut, _tokenIn, usdg);
        uint256 feeBasisPoints = IGmxVaultUtils(vaultUtils).getBuyUsdgFeeBasisPoints(_tokenIn, amountOut);
        uint256 amountAfterFees = (_amountIn * (BASIS_POINTS_DIVISOR - feeBasisPoints)) / BASIS_POINTS_DIVISOR;
        amountOut = (amountAfterFees * _price) / PRICE_PRECISION;
        amountOut = IGmxVault(vault).adjustForDecimals(amountOut, _tokenIn, usdg);
    }

    function _quoteSellGLP(address _tokenOut, uint256 _amountIn) internal view returns (uint256 amountOut) {
        uint256 aumInUsdg = IGlpManager(glpManager).getAumInUsdg(false);
        uint256 glpSupply = IERC20(GLP).totalSupply();
        uint256 price = IGmxVault(vault).getMaxPrice(_tokenOut);
        uint256 usdgAmount = (_amountIn * aumInUsdg) / glpSupply;
        uint256 redemptionAmount = (usdgAmount * PRICE_PRECISION) / price;
        uint256 feeBasisPoints = IGmxVaultUtils(vaultUtils).getSellUsdgFeeBasisPoints(_tokenOut, usdgAmount);
        amountOut = (redemptionAmount * (BASIS_POINTS_DIVISOR - feeBasisPoints)) / BASIS_POINTS_DIVISOR;
    }

    function _swap(
        uint256 _amountIn,
        uint256 _amountOut,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal override {}

    function swap(
        uint256 _amountIn,
        uint256 _amountOut,
        address _fromToken,
        address _toToken,
        address _to
    ) external override {
        address toToken = _toToken == sGLP ? fsGLP : _toToken;
        uint256 toBalanceBefore = IERC20(toToken).balanceOf(_to);
        if (_toToken == sGLP) {
            IERC20(_fromToken).approve(glpManager, _amountIn);
            uint256 amount = IGmxRewardRouter(rewardRouter).mintAndStakeGlp(_fromToken, _amountIn, 0, _amountOut);
            _returnTo(sGLP, amount, _to);
        } else {
            IGmxRewardRouter(rewardRouter).unstakeAndRedeemGlp(_toToken, _amountIn, _amountOut, address(this));
            _returnTo(_toToken, _amountOut, _to);
        }
        uint256 diff = IERC20(toToken).balanceOf(_to) - toBalanceBefore;
        require(diff >= _amountOut, "Insufficient amount-out");
        emit YakAdapterSwap(_fromToken, toToken, _amountIn, _amountOut);
    }
}
