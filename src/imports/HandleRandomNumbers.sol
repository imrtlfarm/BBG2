// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IUniswapV2Pair.sol";

library HandleRandomNumbers {

  function _getRandom(uint supply, address lpPair) internal view returns (uint) {
      (uint token0, uint token1) = _getRandomNumbers(lpPair);
      return uint(keccak256(abi.encodePacked(
          token0, token1, msg.sender, supply
      )));
  }

  function _getRandomNumbers(address lpPair) internal view returns (uint, uint) {
      (uint token0, uint token1,) = IUniswapV2Pair(lpPair).getReserves();
      return (token0, token1);
  }

}