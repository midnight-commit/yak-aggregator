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
//

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../interface/IStargatePool.sol";
import "../YakAdapter.sol";
import "./../lib/SafeCast.sol";

contract StargateAdapter is YakAdapter {
    mapping(address => mapping(address => address)) public tokensToPool;
    mapping(address => uint256) public poolToConvertRate;

    constructor(uint256 _swapGasEstimate) YakAdapter("StargateAdapter", _swapGasEstimate) {}

    function addPool(address _pool) public onlyMaintainer {
        address underlying = IStargatePool(_pool).token();
        address lpToken = IStargatePool(_pool).lpToken();
        tokensToPool[underlying][lpToken] = _pool;
        tokensToPool[lpToken][underlying] = _pool;
        poolToConvertRate[_pool] = 10 ** (IERC20(underlying).decimals() - IStargatePool(_pool).sharedDecimals());
        IERC20(underlying).approve(_pool, type(uint256).max);
        IERC20(lpToken).approve(_pool, type(uint256).max);
    }

    function removePool(address _pool) public onlyMaintainer {
        address underlying = IStargatePool(_pool).token();
        address lpToken = IStargatePool(_pool).lpToken();
        tokensToPool[underlying][lpToken] = address(0);
        tokensToPool[lpToken][underlying] = address(0);
        poolToConvertRate[_pool] = 0;
        IERC20(underlying).approve(_pool, 0);
        IERC20(lpToken).approve(_pool, 0);
    }

    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view override returns (uint256 amountOut) {
        address pool = tokensToPool[_tokenIn][_tokenOut];
        if (pool > address(0)) {
            uint256 convertRate = poolToConvertRate[pool];
            uint64 amountSD = _ld2sd(_amountIn, convertRate);
            amountOut = _sd2ld(amountSD, convertRate);
        }
    }

    /// @notice Translate an amount in SD to LD
    /// @dev Since SD <= LD by definition, convertRate >= 1, so there is no rounding errors in this function.
    /// @param _amountSD The amount in SD
    /// @return amountLD The same value expressed in LD
    function _sd2ld(uint64 _amountSD, uint256 _convertRate) internal pure returns (uint256 amountLD) {
        unchecked {
            amountLD = _amountSD * _convertRate;
        }
    }

    /// @notice Translate an value in LD to SD
    /// @dev Since SD <= LD by definition, convertRate >= 1, so there might be rounding during the cast.
    /// @param _amountLD The value in LD
    /// @return amountSD The same value expressed in SD
    function _ld2sd(uint256 _amountLD, uint256 _convertRate) internal pure returns (uint64 amountSD) {
        unchecked {
            amountSD = SafeCast.toUint64(_amountLD / _convertRate);
        }
    }

    function _swap(uint256 _amountIn, uint256, address _tokenIn, address _tokenOut, address _to) internal override {
        address pool = tokensToPool[_tokenIn][_tokenOut];
        address underlying = IStargatePool(pool).token();
        if (underlying == _tokenIn) {
            IStargatePool(pool).deposit(_to, _amountIn);
        } else {
            IStargatePool(pool).redeem(_amountIn, _to);
        }
    }
}
