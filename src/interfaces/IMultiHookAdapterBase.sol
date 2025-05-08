// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

/// @title IMultiHookAdapterBase
/// @notice An interface for the MultiHookAdapterBase contract
interface IMultiHookAdapterBase {
    /// @notice The Uniswap v4 PoolManager contract
    function poolManager() external view returns (IPoolManager);
    function multiHookAdapter() external view returns (address);
}
