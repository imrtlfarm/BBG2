// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

struct Terms {
    uint shares;
    uint term;
}

interface IElasticLGE {
    function terms(address input) external returns(Terms memory);
}